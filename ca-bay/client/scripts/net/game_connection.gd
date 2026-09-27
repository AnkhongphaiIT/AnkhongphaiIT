extends Node
## Kết nối WebSocket tới room server: auth bằng ticket trong auth message đầu tiên (không đặt
## ticket trong URL), sau đó gửi/nhận envelope JSON qua RPC cố định Game/Network.
## Có thể đặt dưới một gốc multiplayer riêng (bot kiểm thử nhiều client trong một tiến trình).

signal accepted(payload: Dictionary)
signal message(type: String, payload: Dictionary, env: Dictionary)
signal closed(reason: String, reconnect_allowed: bool)
signal auth_failed(error_code: String)

var mp: SceneMultiplayer
var peer: WebSocketMultiplayerPeer
var network: Node
var root_node: Node
var state: String = "idle"   # idle, connecting, authenticating, live, closed
var connection_id: String = ""
var room_id: String = ""
var account_id: String = ""
var lease_epoch: int = 0
var seq: int = 0
var _ticket: String = ""
var _close_reason: String = ""
var _chunks: Dictionary = {}
var validate_incoming: bool = true
var stats := {"sent": 0, "received": 0, "invalid_in": 0}


## root: nút gốc cho SceneMultiplayer (phải có con "Game/Network"). url: ws(s)://...
func connect_to(url: String, ticket: String, root: Node) -> void:
	disconnect_now()
	root_node = root
	network = root.get_node("Game/Network")
	if not network.server_message.is_connected(_on_text):
		network.server_message.connect(_on_text)
	_ticket = ticket
	_close_reason = ""
	seq = 0
	connection_id = ""  # id của kết nối cũ không còn hợp lệ; chờ session.accepted cấp id mới
	mp = SceneMultiplayer.new()
	mp.allow_object_decoding = false
	mp.auth_timeout = float(ContentDB.limit("websocket_auth_timeout_s", 5)) + 2.0
	mp.auth_callback = _on_auth_reply
	peer = WebSocketMultiplayerPeer.new()
	peer.inbound_buffer_size = 262144
	var err := peer.create_client(url)
	if err != OK:
		state = "closed"
		closed.emit("connect_failed", true)
		return
	mp.multiplayer_peer = peer
	# Gốc là cây chính: dùng multiplayer mặc định; gốc riêng (bot trong một tiến trình): đường dẫn riêng.
	get_tree().set_multiplayer(mp, NodePath() if root == get_tree().root else root.get_path())
	mp.peer_authenticating.connect(_on_authenticating)
	mp.peer_authentication_failed.connect(func(_id): _fail("auth_timeout"))
	mp.connected_to_server.connect(func(): state = "live")
	mp.connection_failed.connect(func(): _fail("connect_failed"))
	mp.server_disconnected.connect(func(): _fail(_close_reason if _close_reason != "" else "disconnected"))
	state = "connecting"


func _on_authenticating(id: int) -> void:
	state = "authenticating"
	var body := {"ticket": _ticket, "protocol_version": ContentDB.protocol_version(), "content_hash": ContentDB.content_hash}
	mp.send_auth(id, JSON.stringify(body).to_utf8_buffer())
	_ticket = ""


func _on_auth_reply(id: int, data: PackedByteArray) -> void:
	var d: Variant = JSON.parse_string(data.get_string_from_utf8())
	if typeof(d) == TYPE_DICTIONARY and d.get("ok", false):
		mp.complete_auth(id)
	else:
		var code: String = String(d.get("error_code", "BAD_TICKET")) if typeof(d) == TYPE_DICTIONARY else "BAD_TICKET"
		_close_reason = code
		auth_failed.emit(code)


func _fail(reason: String) -> void:
	if state == "closed":
		return
	state = "closed"
	closed.emit(reason, reason not in ["takeover", "revoked", "protocol_mismatch", "PROTOCOL_MISMATCH", "CONTENT_MISMATCH"])


func disconnect_now() -> void:
	if mp and mp.multiplayer_peer:
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null
	state = "idle"


func is_live() -> bool:
	return state == "live" and connection_id != ""


## Gửi một lệnh; trả request_id để đối chiếu command.result.
func send(type: String, payload: Dictionary) -> String:
	if not is_live():
		return ""
	seq += 1
	var env := Protocol.make_envelope(type, payload, connection_id, room_id, seq)
	network.rpc_id(1, "c2s", JSON.stringify(env))
	stats["sent"] += 1
	return env["request_id"]


## Gửi chuỗi thô (chỉ dùng trong test âm tính).
func send_raw(text: String) -> void:
	if state == "live":
		network.rpc_id(1, "c2s", text)


func next_seq_peek() -> int:
	return seq


func _on_text(text: String) -> void:
	stats["received"] += 1
	var env: Dictionary
	if validate_incoming:
		var res := Protocol.parse_and_validate(text, "server_to_client")
		if not res["ok"]:
			stats["invalid_in"] += 1
			push_warning("Gói server không hợp lệ: %s" % res.get("detail", ""))
			return
		env = res["env"]
	else:
		var v: Variant = JSON.parse_string(text)
		if typeof(v) != TYPE_DICTIONARY:
			return
		env = v
	var type: String = env["type"]
	var payload: Dictionary = env["payload"]
	match type:
		"session.accepted":
			connection_id = payload["connection_id"]
			room_id = payload["room_id"]
			account_id = payload["account_id"]
			lease_epoch = int(payload["lease_epoch"])
			accepted.emit(payload)
		"session.closed":
			_close_reason = payload["reason"]
		"state.snapshot_chunk":
			_on_chunk(payload)
			return
	message.emit(type, payload, env)


func _on_chunk(p: Dictionary) -> void:
	var sid: String = p["snapshot_id"]
	var entry: Dictionary = _chunks.get(sid, {"parts": {}, "count": int(p["chunk_count"])})
	entry["parts"][int(p["chunk_index"])] = p["data_b64"]
	_chunks[sid] = entry
	if entry["parts"].size() == entry["count"]:
		var buf := PackedByteArray()
		for i in entry["count"]:
			buf.append_array(Marshalls.base64_to_raw(entry["parts"][i]))
		_chunks.erase(sid)
		var snap: Variant = JSON.parse_string(buf.get_string_from_utf8())
		if typeof(snap) == TYPE_DICTIONARY:
			message.emit("state.snapshot", snap, {})
