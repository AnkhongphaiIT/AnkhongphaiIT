extends Node
## Room server Godot headless (07 §3, §5). Nhận WebSocket từ trình duyệt, xác thực ticket một lần
## trong auth message của SceneMultiplayer, rồi chuyển envelope JSON đã kiểm cho RoomSim.
## Biến môi trường: CABAY_WS_PORT (8910), CABAY_WS_BIND ("127.0.0.1"), CABAY_BACKEND_URL, CABAY_SERVICE_KEY.

const RoomSim := preload("res://server/gameplay/room_sim.gd")
const BackendClient := preload("res://server/gameplay/backend_client.gd")

var backend: Node
var network: Node
var mp: SceneMultiplayer
var ws: WebSocketMultiplayerPeer
var rooms: Dictionary = {}          # room_id -> RoomSim
var sessions: Dictionary = {}       # peer_id -> Dictionary
var authenticating: Dictionary = {} # peer_id -> true
var live_peers: Dictionary = {}     # peer_id -> true (đã xác thực, đang kết nối)
var known_peers: Dictionary = {}    # peer_id -> true (mọi peer transport còn mở)
var control_cursor: int = 0
var pending_acks: Array = []
var pending_releases: Array = []
var _control_busy := false
var _status_busy := false
var _control_t := 0.0
var _status_t := 0.0
var _heartbeat_t := 0.0
var stats := {"invalid": 0, "rate_limited": 0, "messages": 0, "heartbeat_timeouts": 0}


func _ready() -> void:
	Engine.physics_ticks_per_second = int(ContentDB.limit("simulation_hz", 30))
	Engine.max_fps = 60
	backend = BackendClient.new()
	backend.name = "Backend"
	add_child(backend)
	network = get_node("/root/Game/Network")
	network.client_message.connect(_on_client_message)
	var port := int(OS.get_environment("CABAY_WS_PORT")) if OS.get_environment("CABAY_WS_PORT") != "" else 8910
	var bind := OS.get_environment("CABAY_WS_BIND") if OS.get_environment("CABAY_WS_BIND") != "" else "127.0.0.1"
	mp = SceneMultiplayer.new()
	mp.allow_object_decoding = false
	mp.server_relay = false
	mp.auth_timeout = float(ContentDB.limit("websocket_auth_timeout_s", 5))
	mp.auth_callback = _on_auth_data
	ws = WebSocketMultiplayerPeer.new()
	ws.inbound_buffer_size = 65536
	ws.max_queued_packets = int(ContentDB.limit("max_pending_messages_per_peer", 64)) * 4
	var err := ws.create_server(port, bind)
	if err != OK:
		push_error("Không mở được cổng WebSocket %d (%s)" % [port, error_string(err)])
		get_tree().quit(2)
		return
	mp.multiplayer_peer = ws
	get_tree().set_multiplayer(mp)
	mp.peer_authenticating.connect(func(id): authenticating[id] = true; known_peers[id] = true)
	mp.peer_authentication_failed.connect(func(id): authenticating.erase(id); known_peers.erase(id))
	mp.peer_connected.connect(_on_peer_connected)
	mp.peer_disconnected.connect(_on_peer_disconnected)
	print("CABAY_SERVER listening ws://%s:%d content_hash=%s" % [bind, port, ContentDB.content_hash])


# ------------------------------------------------------------------ xác thực

func _on_auth_data(peer_id: int, data: PackedByteArray) -> void:
	if not authenticating.has(peer_id) or authenticating[peer_id] is Dictionary:
		return  # đã xử lý / đang xử lý
	authenticating[peer_id] = {"started": Time.get_ticks_msec()}
	if data.size() > 1024:
		_reject_auth(peer_id, "INVALID_PAYLOAD")
		return
	var parsed: Variant = JSON.parse_string(data.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_reject_auth(peer_id, "INVALID_PAYLOAD")
		return
	if parsed.get("protocol_version", "") != ContentDB.protocol_version():
		_reject_auth(peer_id, "PROTOCOL_MISMATCH")
		return
	var err := SchemaLite.validate(parsed, ContentDB.network["authentication_payload"])
	if err != "":
		_reject_auth(peer_id, "INVALID_PAYLOAD")
		return
	if parsed["content_hash"] != ContentDB.content_hash:
		_reject_auth(peer_id, "CONTENT_MISMATCH")
		return
	var connection_id := Protocol.uuid4()
	var r: Dictionary = await backend.call_api(HTTPClient.METHOD_POST, "/internal/tickets/consume", {
		"ticket": parsed["ticket"], "protocol_version": parsed["protocol_version"],
		"content_hash": parsed["content_hash"], "connection_id": connection_id,
	})
	if not authenticating.has(peer_id):
		return  # peer đã rớt trong lúc chờ
	if not r["ok"]:
		_reject_auth(peer_id, r["error_code"] if r["error_code"] != "" else "BAD_TICKET")
		return
	var d: Dictionary = r["data"]
	var room: RefCounted = rooms.get(d["room_id"])
	if room == null:
		# Room server khởi động lại: dựng lại phòng từ thông tin backend (tiến trình đã commit không mất).
		room = _create_room(d["room_id"], String(d.get("island_id", d["save"]["player"]["safe_island_id"])), d["account_id"])
		room.restored = true
	if room.is_full_for(d["account_id"]):
		_reject_auth(peer_id, "ROOM_FULL")
		return
	sessions[peer_id] = {
		"account_id": d["account_id"], "display_name": d["display_name"], "room_id": d["room_id"],
		"connection_id": connection_id, "lease_epoch": int(d["lease_epoch"]), "save": d["save"],
		"last_seq": -1, "buckets": {}, "invalid": 0, "live": false,
	}
	mp.send_auth(peer_id, JSON.stringify({"ok": true}).to_utf8_buffer())
	mp.complete_auth(peer_id)


func _reject_auth(peer_id: int, code: String) -> void:
	if mp.multiplayer_peer == null:
		return
	mp.send_auth(peer_id, JSON.stringify({"ok": false, "error_code": code}).to_utf8_buffer())
	authenticating.erase(peer_id)
	await get_tree().create_timer(0.25).timeout
	if known_peers.has(peer_id):
		mp.disconnect_peer(peer_id)


func _on_peer_connected(peer_id: int) -> void:
	authenticating.erase(peer_id)
	live_peers[peer_id] = true
	known_peers[peer_id] = true
	var s: Dictionary = sessions.get(peer_id, {})
	if s.is_empty():
		mp.disconnect_peer(peer_id)
		return
	# Cùng tài khoản đang ở peer khác: phiên mới thắng (epoch mới), phiên cũ bị đóng.
	for other in sessions.keys():
		if other != peer_id and sessions[other]["account_id"] == s["account_id"]:
			_close_session(other, sessions[other], "takeover", false)
			sessions.erase(other)
	s["live"] = true
	s["last_rx_ms"] = Time.get_ticks_msec()
	var room: RefCounted = rooms[s["room_id"]]
	room.attach_player(peer_id, s)


func _on_peer_disconnected(peer_id: int) -> void:
	authenticating.erase(peer_id)
	live_peers.erase(peer_id)
	known_peers.erase(peer_id)
	var s: Dictionary = sessions.get(peer_id, {})
	sessions.erase(peer_id)
	if s.is_empty() or not s.get("live", false):
		return
	var room: RefCounted = rooms.get(s["room_id"])
	if room:
		room.detach_player(s["account_id"], peer_id)


## Gửi session.closed đúng một lần rồi ngắt sau 0,2 s (để gói tin tới client).
func _close_session(peer_id: int, s: Dictionary, reason: String, reconnect_allowed: bool) -> void:
	if s.get("closing", false):
		return
	s["closing"] = true
	send(peer_id, "session.closed", {"reason": reason, "reconnect_allowed": reconnect_allowed})
	_kick_later(peer_id)


func _kick_later(peer_id: int) -> void:
	await get_tree().create_timer(0.2).timeout
	if known_peers.has(peer_id):
		mp.disconnect_peer(peer_id)
		# SceneMultiplayer không phát peer_disconnected khi chính server ngắt: tự dọn phiên/người chơi
		# (chuyển "disconnected" giữ chỗ như mất mạng), tránh RPC tới peer đã mất.
		_on_peer_disconnected(peer_id)


# ------------------------------------------------------------------ thông điệp

func _on_client_message(peer_id: int, text: String) -> void:
	stats["messages"] += 1
	var s: Dictionary = sessions.get(peer_id, {})
	if s.is_empty() or not s["live"] or s.get("closing", false):
		return
	s["last_rx_ms"] = Time.get_ticks_msec()
	# bộ đếm vi phạm tính theo cửa sổ 60 s: phiên chơi dài không bị ngắt oan vì vài lỗi rải rác
	var now_ms := Time.get_ticks_msec()
	if now_ms - int(s.get("invalid_window_ms", 0)) > 60000:
		s["invalid_window_ms"] = now_ms
		s["invalid"] = 0
	var res := Protocol.parse_and_validate(text, "client_to_server")
	if not res["ok"]:
		_invalid(peer_id, s, res["error"], _peek_request_id(text))
		return
	var env: Dictionary = res["env"]
	if env["connection_id"] != s["connection_id"] or env["room_id"] != s["room_id"]:
		_invalid(peer_id, s, "INVALID_PAYLOAD", env["request_id"])
		return
	if env["seq"] <= s["last_seq"]:
		reply_result(peer_id, env["request_id"], null, "rejected", "STALE_SEQUENCE", _save_version(s), null)
		return
	s["last_seq"] = env["seq"]
	if not _take_token(s, env["type"]):
		stats["rate_limited"] += 1
		reply_result(peer_id, env["request_id"], env["payload"].get("op_id"), "rejected", "RATE_LIMITED", _save_version(s), null)
		s["invalid"] += 1
		if s["invalid"] > 40:
			_close_session(peer_id, s, "rate_limit", true)
		return
	if env["type"] == "session.ping":
		var room0: RefCounted = rooms.get(s["room_id"])
		send(peer_id, "session.pong", {"client_monotonic_ms": env["payload"]["client_monotonic_ms"], "server_tick": room0.tick_count if room0 else 0})
		return
	var room: RefCounted = rooms.get(s["room_id"])
	if room:
		room.handle(s["account_id"], env)


func _invalid(peer_id: int, s: Dictionary, code: String, request_id: String) -> void:
	stats["invalid"] += 1
	s["invalid"] += 1
	if request_id != "":
		reply_result(peer_id, request_id, null, "rejected", code, _save_version(s), null)
	if code == "PROTOCOL_MISMATCH":
		_close_session(peer_id, s, "protocol_mismatch", false)
	elif s["invalid"] > 40:
		_close_session(peer_id, s, "rate_limit", true)


func _peek_request_id(text: String) -> String:
	if text.length() > 8192:
		return ""
	var v: Variant = JSON.parse_string(text)
	if typeof(v) == TYPE_DICTIONARY and typeof(v.get("request_id")) == TYPE_STRING and SchemaLite.is_uuid(v["request_id"]):
		return v["request_id"]
	return ""


func _take_token(s: Dictionary, type: String) -> bool:
	var spec: Dictionary = ContentDB.messages.get(type, {})
	var rate: float = float(spec.get("max_per_second", 10))
	if rate <= 0:
		return true
	var now := Time.get_ticks_msec() / 1000.0
	var b: Dictionary = s["buckets"].get(type, {"tokens": rate * 2.0, "t": now})
	b["tokens"] = minf(rate * 2.0, float(b["tokens"]) + (now - float(b["t"])) * rate)
	b["t"] = now
	s["buckets"][type] = b
	if b["tokens"] < 1.0:
		return false
	b["tokens"] -= 1.0
	return true


func _save_version(s: Dictionary) -> int:
	return int(s.get("save", {}).get("save_version", 1))


# ------------------------------------------------------------------ gửi

func send(peer_id: int, type: String, payload: Dictionary, request_id: String = "") -> void:
	var s: Dictionary = sessions.get(peer_id, {})
	var env := {
		"protocol_version": ContentDB.protocol_version(), "type": type,
		"request_id": request_id if request_id != "" else Protocol.uuid4(),
		"connection_id": s.get("connection_id", "00000000-0000-4000-8000-000000000000"),
		"room_id": s.get("room_id", "00000000-0000-4000-8000-000000000000"),
		"seq": 0, "payload": payload,
	}
	var text := JSON.stringify(env)
	if text.to_utf8_buffer().size() > int(ContentDB.limit("max_server_payload_bytes", 65536)):
		push_warning("Gói %s quá lớn (%d byte), bỏ" % [type, text.length()])
		return
	if live_peers.has(peer_id):
		network.rpc_id(peer_id, "s2c", text)


func reply_result(peer_id: int, request_id: String, op_id: Variant, status: String, error_code: Variant, save_version: int, receipt: Variant) -> void:
	send(peer_id, "command.result", {
		"request_id": request_id, "op_id": op_id, "status": status, "error_code": error_code,
		"save_version": max(0, save_version), "receipt": receipt,
	}, request_id)


func peer_of(account_id: String) -> int:
	for pid in sessions:
		if sessions[pid]["account_id"] == account_id and sessions[pid]["live"]:
			return pid
	return 0


func session_of(account_id: String) -> Dictionary:
	var pid := peer_of(account_id)
	return sessions.get(pid, {})


# ------------------------------------------------------------------ vòng lặp

func _physics_process(delta: float) -> void:
	for room_id in rooms.keys():
		var room: RefCounted = rooms[room_id]
		room.tick(delta)
		if room.should_close():
			room.close()
			rooms.erase(room_id)
	_control_t += delta
	_status_t += delta
	_heartbeat_t += delta
	if _heartbeat_t >= 1.0:
		_heartbeat_t = 0.0
		_check_heartbeats()
	if _control_t >= 1.0 and not _control_busy:
		_control_t = 0.0
		_poll_controls()
	if _status_t >= 2.0 and not _status_busy:
		_status_t = 0.0
		_post_status()


## Kết nối chết im lặng (mất Wi-Fi, máy ngủ, NAT/đường hầm cắt mà không có gói đóng TCP): client thật gửi input
## ≤ 0,25 s và ping 2 s một lần, nên không nhận được gì quá heartbeat_timeout_s (15 s) nghĩa là mất mạng. Đóng phiên
## ("timeout", cho nối lại): người chơi chuyển "disconnected" giữ chỗ reconnect_grace_s như rớt mạng thường, server
## ngừng dồn snapshot cho kết nối chết. Tab trình duyệt bị ẩn quá 15 s cũng vậy — quay lại thì client tự nối lại.
func _check_heartbeats() -> void:
	var limit_ms := int(float(ContentDB.limit("heartbeat_timeout_s", 15)) * 1000.0)
	var now := Time.get_ticks_msec()
	for peer_id in sessions.keys():
		var s: Dictionary = sessions[peer_id]
		if not s.get("live", false) or s.get("closing", false):
			continue
		if now - int(s.get("last_rx_ms", now)) > limit_ms:
			stats["heartbeat_timeouts"] += 1
			print("CABAY_SERVER heartbeat_timeout peer=%d after_ms=%d" % [peer_id, now - int(s["last_rx_ms"])])
			_close_session(peer_id, s, "timeout", true)


func _create_room(room_id: String, island_id: String, owner: String) -> RefCounted:
	if not IslandLayout.has_island(island_id):
		island_id = ContentDB.island_order[0]
	var room: RefCounted = RoomSim.new(self, room_id, island_id, owner)
	rooms[room_id] = room
	print("CABAY_ROOM created %s island=%s" % [room_id, island_id])
	return room


func _poll_controls() -> void:
	_control_busy = true
	var r: Dictionary = await backend.call_api(HTTPClient.METHOD_GET, "/internal/room-controls?after=%d" % control_cursor)
	_control_busy = false
	if not r["ok"]:
		return
	for c in r["data"].get("controls", []):
		control_cursor = max(control_cursor, int(c["control_id"]))
		match c["kind"]:
			"create_room":
				if not rooms.has(c["room_id"]):
					_create_room(c["room_id"], c["payload"]["island_id"], c["payload"]["owner_account_id"])
			"kick_account":
				# Chỉ đá đúng kết nối bị thu hồi (connection_id của lease cũ). Thiết bị mới có thể đã vào trước khi
				# lệnh này được đọc (chu kỳ 1 s): không được đá nhầm phiên mới đó.
				var aid: String = c["payload"]["account_id"]
				var cid: String = String(c["payload"].get("connection_id", ""))
				var pid := peer_of(aid)
				var cur_cid: String = String(sessions[pid]["connection_id"]) if pid and sessions.has(pid) else ""
				if pid == 0 or cid == "" or cur_cid == cid:
					if pid:
						var reason: String = c["payload"].get("reason", "revoked")
						_close_session(pid, sessions[pid], "takeover" if reason == "taken_over" else "revoked", false)
						sessions.erase(pid)
					for room in rooms.values():
						room.remove_player_now(aid, false)
		pending_acks.append(int(c["control_id"]))
	if not pending_acks.is_empty():
		_post_status()


func _post_status() -> void:
	_status_busy = true
	var acks := pending_acks.duplicate()
	var released := pending_releases.duplicate()
	var room_list: Array = []
	for room in rooms.values():
		room_list.append(room.status_entry())
	var r: Dictionary = await backend.call_api(HTTPClient.METHOD_POST, "/internal/room-status", {"acks": acks, "rooms": room_list, "released": released})
	_status_busy = false
	if r["ok"]:
		for a in acks:
			pending_acks.erase(a)
		for x in released:
			pending_releases.erase(x)


func queue_release(account_id: String, lease_epoch: int, room_id: String, reason: String) -> void:
	pending_releases.append({"account_id": account_id, "lease_epoch": lease_epoch, "room_id": room_id, "reason": reason})


func _exit_tree() -> void:
	for pid in sessions.keys():
		send(pid, "session.closed", {"reason": "server_restart", "reconnect_allowed": true})
