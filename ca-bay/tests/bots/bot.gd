extends Node
## Một bot chơi qua protocol thật (HTTP + WebSocket + ticket). Dùng GameConnection/ApiClient của client.
## Không phải mock: mọi hành động đi qua room server và backend như người chơi thật.

const ApiClient := preload("res://client/scripts/net/api_client.gd")
const GameConnection := preload("res://client/scripts/net/game_connection.gd")
const NetworkNode := preload("res://shared/protocol/network_node.gd")

var index: int = 0
var api: Node
var conn: Node
var endpoints: Dictionary
var log_lines: Array = []
var snapshot: Dictionary = {}
var save: Dictionary = {}
var save_version: int = 1
var results: Dictionary = {}   # request_id -> command.result payload
var events: Array = []          # domain events đã nhận (name, actor, payload)
var seen_players: Dictionary = {}
var invite_code: String = ""
var room_id: String = ""
var yaw: float = PI
var pitch: float = 0.0
var move := Vector2.ZERO
var _input_t := 0.0
var closed_reason: String = ""
var session_closed: Array = []   # lý do của mọi session.closed đã nhận (theo thứ tự)
var seen_entities: Dictionary = {}  # uid -> def_id của mọi thực thể từng thấy trong snapshot
var snapshot_room_ids: Dictionary = {}  # room_id (từ envelope) của snapshot đã nhận
var event_room_ids: Dictionary = {}
var username: String = ""
var password: String = ""
var slot: int = -1               # ô đứng câu trên bến (-1 = theo index)
var hold_before_pickup_s := 0.0  # giữ cá đã xỉu trên đất trước khi nhặt (test chéo phòng)
var ko_uid: String = ""          # cá vừa đập xỉu, chưa nhặt
var sent_types: Dictionary = {}  # request_id -> loại message (chẩn đoán RATE_LIMITED)
var rejected_counts: Dictionary = {}  # "loại/mã lỗi" -> số lần
var last_snapshot_ms := 0
var keepalive := true            # rung nhẹ góc nhìn định kỳ để không bị AFK khi đứng chờ
var _keep_t := 0.0
var _keep_sign := 1.0


func _init(i: int, ep: Dictionary) -> void:
	index = i
	endpoints = ep
	name = "Bot%d" % i
	var game := Node.new()
	game.name = "Game"
	add_child(game)
	var net := Node.new()
	net.name = "Network"
	net.set_script(NetworkNode)
	game.add_child(net)
	api = ApiClient.new()
	api.base_url = ep["api_base"]
	add_child(api)
	conn = GameConnection.new()
	add_child(conn)
	conn.message.connect(_on_message)
	conn.closed.connect(func(r, _a):
		closed_reason = r
		say("kết nối đóng: %s (session.closed=%s, bị từ chối=%s)" % [r, str(session_closed), str(rejected_counts)]))
	conn.auth_failed.connect(func(c):
		closed_reason = c
		say("auth thất bại: %s" % c))


func say(msg: String) -> void:
	var line := "[bot%d] %s" % [index, msg]
	log_lines.append(line)
	print(line)


func _on_message(type: String, payload: Dictionary, env: Dictionary) -> void:
	match type:
		"state.snapshot":
			snapshot = payload
			last_snapshot_ms = Time.get_ticks_msec()
			for pl in payload["players"]:
				seen_players[pl["account_id"]] = pl["display_name"]
			for e in payload["entities"]:
				seen_entities[e["uid"]] = e["def_id"]
			if env.has("room_id"):
				snapshot_room_ids[env["room_id"]] = true
		"command.result":
			results[payload["request_id"]] = payload
			if payload["status"] == "rejected":
				var key := "%s/%s" % [sent_types.get(payload["request_id"], "?"), str(payload["error_code"])]
				rejected_counts[key] = int(rejected_counts.get(key, 0)) + 1
				if str(payload["error_code"]) == "RATE_LIMITED" and int(rejected_counts[key]) <= 3:
					say("RATE_LIMITED %s" % key)
			var rec: Variant = payload.get("receipt")
			if typeof(rec) == TYPE_DICTIONARY and rec.has("view"):
				if int(rec["view"]["save_version"]) >= save_version:
					save = rec["view"]
					save_version = int(save["save_version"])
		"domain.event":
			events.append(payload)
			event_room_ids[payload["room_id"]] = true
		"session.closed":
			session_closed.append(payload["reason"])
			say("session.closed %s" % payload["reason"])
		"session.accepted":
			pass


func _process(delta: float) -> void:
	if not conn.is_live():
		return
	_input_t += delta
	_keep_t += delta
	if keepalive and _keep_t >= 20.0:
		_keep_t = 0.0
		_keep_sign = -_keep_sign
		yaw += 0.03 * _keep_sign
	if _input_t >= 0.05:
		_input_t = 0.0
		# schema: move_x/move_z ∈ [-1, 1]; phép tính hướng có thể ra 1.0000001 → server coi là INVALID_PAYLOAD
		var rid_in: String = conn.send("player.input", {"move_x": clampf(move.x, -1.0, 1.0), "move_z": clampf(move.y, -1.0, 1.0), "look_yaw_rad": wrapf(yaw, -PI, PI), "look_pitch_rad": clampf(pitch, -1.5, 1.5), "jump": false})
		sent_types[rid_in] = "player.input"


# ------------------------------------------------------------------ tiện ích bất đồng bộ

func wait_until(cond: Callable, timeout_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > timeout_s * 1000.0:
			return false
		await get_tree().process_frame
	return true


func register_and_login() -> bool:
	var uname := "bot%d_%s" % [index, Protocol.uuid4().substr(0, 8)]
	username = uname
	password = "bot-password-%d-xyz" % index
	var r: Dictionary = await api.register(uname, "Bot %d" % index, password)
	if not r["ok"]:
		say("register lỗi %s" % r["error_code"])
		return false
	var s: Dictionary = await api.get_save()
	save = s["data"]["save"]
	save_version = int(save["save_version"])
	return true


func create_room() -> bool:
	var r: Dictionary = await api.create_room()
	if not r["ok"]:
		say("create_room lỗi %s" % r["error_code"])
		return false
	room_id = r["data"]["room_id"]
	invite_code = r["data"]["invite_code"]
	return true


func join_by_code(code: String) -> Dictionary:
	var r: Dictionary = await api.lookup_room(code)
	if not r["ok"]:
		return r
	room_id = r["data"]["room_id"]
	return await api.join_room(room_id, code)


func connect_room() -> bool:
	for attempt in 30:
		var t: Dictionary = await api.ticket(room_id)
		if t["ok"]:
			conn.connect_to(endpoints["ws_url"], t["data"]["ticket"], self)
			var ok: bool = await wait_until(func(): return conn.is_live() or conn.state == "closed" or closed_reason != "", 10.0)
			if ok and conn.is_live():
				await wait_until(func(): return not snapshot.is_empty(), 5.0)
				return not snapshot.is_empty()
			say("kết nối thất bại: %s" % closed_reason)
			return false
		if t["error_code"] != "ROOM_NOT_READY":
			say("ticket lỗi %s" % t["error_code"])
			return false
		await get_tree().create_timer(0.3).timeout
	return false


func me() -> Dictionary:
	for pl in snapshot.get("players", []):
		if pl["account_id"] == api.account_id:
			return pl
	return {}


func my_pos() -> Vector3:
	var p := me()
	if p.is_empty():
		return Vector3.INF
	return Vector3(p["position"][0], p["position"][1], p["position"][2])


func walk_to(target: Vector3, tol: float = 0.4, timeout_s: float = 30.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_s * 1000.0:
		var p := my_pos()
		if p != Vector3.INF:
			var d := Vector2(target.x - p.x, target.z - p.z)
			if d.length() <= tol:
				move = Vector2.ZERO
				return true
			yaw = atan2(-d.x, -d.y)
			move = Vector2(0, -1 if d.length() > 0.8 else -0.5)
		await get_tree().process_frame
	move = Vector2.ZERO
	return false


func look_at_point(target: Vector3) -> void:
	var eye := my_pos() + Vector3(0, 1.6, 0)
	var d := target - eye
	yaw = atan2(-d.x, -d.z)
	pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.5, 1.5)


## Gửi lệnh bền vững và chờ command.result.
func durable(type: String, payload: Dictionary, timeout_s: float = 10.0) -> Dictionary:
	payload["op_id"] = Protocol.uuid4()
	payload["expected_save_version"] = save_version
	var rid: String = conn.send(type, payload)
	var ok: bool = await wait_until(func(): return results.has(rid), timeout_s)
	if not ok:
		return {"status": "timeout", "error_code": "TIMEOUT"}
	var r: Dictionary = results[rid]
	if r["status"] == "rejected" and r["error_code"] == "SAVE_CONFLICT":
		var s: Dictionary = await api.get_save()
		save = s["data"]["save"]
		save_version = int(save["save_version"])
	return r


func command(type: String, payload: Dictionary) -> String:
	var rid: String = conn.send(type, payload)
	sent_types[rid] = type
	return rid


func last_event(name: String, actor: String = "", after_index: int = 0) -> Dictionary:
	for i in range(events.size() - 1, after_index - 1, -1):
		var e: Dictionary = events[i]
		if e["name"] == name and (actor == "" or e["actor_player_id"] == actor):
			return e
	return {}


func entity(uid: String) -> Dictionary:
	for e in snapshot.get("entities", []):
		if e["uid"] == uid:
			return e
	return {}


# ------------------------------------------------------------------ phiên / lưu

## Đăng nhập tài khoản đã có (thiết bị thứ hai, hoặc tiếp tục tài khoản của lần chạy trước).
func login_as(user: String, pw: String) -> bool:
	username = user
	password = pw
	var r: Dictionary = await api.login(user, pw)
	if not r["ok"]:
		say("login lỗi %s" % r["error_code"])
		return false
	return await refresh_save()


func refresh_save() -> bool:
	var s: Dictionary = await api.get_save()
	if not s["ok"]:
		return false
	save = s["data"]["save"]
	save_version = int(save["save_version"])
	return true


## Save authoritative từ backend (GET /v1/account/save), không đụng biến save cục bộ.
func server_save() -> Dictionary:
	var s: Dictionary = await api.get_save()
	return s["data"].get("save", {}) if s["ok"] else {}


## Nối lại phòng hiện tại (sau khi mất kết nối/room server khởi động lại). Thử tới khi sống hoặc hết giờ.
func reconnect(timeout_s: float = 60.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_s * 1000.0:
		closed_reason = ""
		snapshot = {}
		if await connect_room():
			return true
		conn.disconnect_now()
		await get_tree().create_timer(1.0).timeout
	return false


func money() -> int:
	return int(save["currencies"]["money"])


func bag_of(def_id: String) -> Array:
	var out: Array = []
	for it in save["inventory"]["bag"]:
		if it["def_id"] == def_id:
			out.append(it["uid"])
	return out


func bag_free() -> int:
	return int(save["inventory"]["capacity"]) - save["inventory"]["bag"].size()


func quest_state(qid: String) -> Dictionary:
	return save["progress"]["quests"].get(qid, {})


func island() -> String:
	return String(snapshot.get("island_id", ""))


func mode() -> String:
	return String(me().get("mode", ""))


func sleep(s: float) -> void:
	await get_tree().create_timer(s).timeout


# ------------------------------------------------------------------ lệnh bền vững có thử lại

## Như durable() nhưng tự chọn op_id/expected_save_version hoặc dùng giá trị cho trước (để gửi lại cùng op).
func durable_raw(type: String, payload: Dictionary, op_id: String, esv: int, timeout_s: float = 10.0) -> Dictionary:
	var pl := payload.duplicate(true)
	pl["op_id"] = op_id
	pl["expected_save_version"] = esv
	var rid: String = conn.send(type, pl)
	if rid == "":
		return {"status": "not_sent", "error_code": "NOT_CONNECTED"}
	sent_types[rid] = type
	var ok: bool = await wait_until(func(): return results.has(rid), timeout_s)
	if not ok:
		return {"status": "timeout", "error_code": "TIMEOUT"}
	return results[rid]


## Gửi lệnh bền vững; SAVE_CONFLICT (server op chen vào) → tải lại save và thử lại bằng op mới.
## Trả kết quả cuối kèm "op_id"/"esv" của lần gửi cuối (để test gửi lại cùng op).
func dur(type: String, payload: Dictionary, tries: int = 4, timeout_s: float = 10.0) -> Dictionary:
	var r: Dictionary = {}
	for i in tries:
		var op := Protocol.uuid4()
		var esv := save_version
		r = await durable_raw(type, payload, op, esv, timeout_s)
		r = r.duplicate()
		r["op_id_sent"] = op
		r["esv_sent"] = esv
		if r.get("status", "") == "rejected" and r.get("error_code", "") == "SAVE_CONFLICT":
			await refresh_save()
			await sleep(0.2)
			continue
		break
	return r


func events_named(name: String, after_index: int = 0, actor: String = "") -> Array:
	var out: Array = []
	for i in range(after_index, events.size()):
		var e: Dictionary = events[i]
		if e["name"] == name and (actor == "" or e["actor_player_id"] == actor):
			out.append(e)
	return out


# ------------------------------------------------------------------ di chuyển theo điểm mốc

## Điểm có nằm trên/ sát bến (dải bến mở rộng) không.
func _near_pier(isl: String, q: Vector2) -> bool:
	var pier: Dictionary = IslandLayout.layout(isl)["pier"]
	var a: Vector2 = pier["from"]
	var b: Vector2 = pier["to"]
	var ab := b - a
	var t := (q - a).dot(ab) / ab.length_squared()
	if t < 0.0 or t > 1.15:
		return false
	return (a + ab * clampf(t, 0.0, 1.0)).distance_to(q) <= 3.0


## Đi tới điểm (x,z) trên đảo hiện tại; qua gốc bến nếu điểm đầu/cuối ở trên bến (đường thẳng bờ↔bến có thể cắt nước).
func nav_to(target2: Vector2, tol: float = 0.6, timeout_s: float = 45.0) -> bool:
	var isl := island()
	if isl == "":
		return false
	var pier: Dictionary = IslandLayout.layout(isl)["pier"]
	var a: Vector2 = pier["from"]
	var approach := a - Vector2(0, 3.0)
	var p := my_pos()
	if p == Vector3.INF:
		return false
	var p2 := Vector2(p.x, p.z)
	var me_on := _near_pier(isl, p2)
	var tgt_on := _near_pier(isl, target2)
	var pts: Array = []
	if me_on and not tgt_on:
		pts.append(Vector2(clampf(p2.x, a.x - 1.0, a.x + 1.0), a.y + 1.0))
		pts.append(approach)
	elif tgt_on and not me_on:
		pts.append(approach)
		pts.append(Vector2(clampf(target2.x, a.x - 1.1, a.x + 1.1), a.y + 1.0))
	pts.append(target2)
	var t0 := Time.get_ticks_msec()
	for i in pts.size():
		var left := timeout_s - (Time.get_ticks_msec() - t0) / 1000.0
		if left <= 0.0:
			return false
		var last: bool = i == pts.size() - 1
		if not await walk_to(IslandLayout.v3(isl, pts[i]), tol if last else 0.8, left):
			return false
	return true


func goto_npc(npc_id: String) -> bool:
	var isl := island()
	var npos := IslandLayout.npc_position(isl, npc_id)
	if npos == Vector3.INF:
		say("NPC %s không ở đảo %s" % [npc_id, isl])
		return false
	return await nav_to(Vector2(npos.x + (-0.9 + 0.6 * index), npos.z + 1.6), 0.7)


func goto_shop() -> bool:
	var shop := IslandLayout.shop_zone(island())
	var sp: Vector2 = shop["pos"]
	return await nav_to(sp + Vector2(-0.9 + 0.6 * index, 1.8), 0.8)


## npc.interact và chờ command.result (server làm xong quà/bước nói chuyện rồi mới trả).
func talk(npc_id: String) -> Dictionary:
	var rid: String = command("npc.interact", {"npc_id": npc_id})
	if rid == "":
		return {"status": "not_sent"}
	await wait_until(func(): return results.has(rid), 10.0)
	return results.get(rid, {"status": "timeout"})


## Chuyển động theo hướng thế giới (x,z) trong khi vẫn giữ góc nhìn hiện tại.
func move_world(w: Vector2) -> void:
	if w.length() < 0.01:
		move = Vector2.ZERO
		return
	w = w.normalized()
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	move = Vector2(w.dot(right), -w.dot(fwd))


# ------------------------------------------------------------------ câu cá

## Câu tới khi được một con thuộc `want` (rỗng = loài nào cũng được): quăng từ đầu bến, cá cắn loài khác
## thì thả (cancel), đúng loài thì giật/kéo/đập xỉu bằng dép rồi nhặt vào túi.
## Trả {"ok", "uid", "species", "casts", "skipped", "value"}.
func catch_one(want: Array, max_casts: int = 40) -> Dictionary:
	var out := {"ok": false, "casts": 0, "skipped": 0, "lost": 0}
	var isl := island()
	var pier: Dictionary = IslandLayout.layout(isl)["pier"]
	var end: Vector2 = pier["to"]
	if "tool_slipper" not in save["inventory"]["tools_owned"]:
		out["error"] = "chưa có dép (nói chuyện Cô Ba trước)"
		return out
	var sl: int = slot if slot >= 0 else index % 4
	var stand2: Vector2 = end - Vector2(0, 2.0) + Vector2(-1.1 + 0.73 * sl, 0)
	var stand := IslandLayout.v3(isl, stand2)
	for attempt in max_casts:
		if bag_free() <= 0:
			out["error"] = "bag_full"
			return out
		var p := my_pos()
		if Vector2(p.x - stand.x, p.z - stand.z).length() > 1.0:
			await nav_to(stand2, 0.35)
		var rod: String = save["inventory"]["equipped_rod_id"]
		if String(save["inventory"]["equipped_id"]) != rod:
			await dur("equipment.equip", {"equipment_id": rod})
		yaw = PI
		pitch = -0.1
		await sleep(0.2)
		out["casts"] += 1
		var ev_base: int = events.size()
		var aid: String = api.account_id
		command("fishing.action", {"action": "charge_start", "aim_direction": [0, 0, 1]})
		await sleep(0.55)
		command("fishing.action", {"action": "cast_release", "aim_direction": [0, 0, 1]})
		var bit: bool = await wait_until(func(): return not last_event("fishing.bite", aid, ev_base).is_empty() or not last_event("fishing.cancelled", aid, ev_base).is_empty(), 15.0)
		var bite: Dictionary = last_event("fishing.bite", aid, ev_base)
		if not bit or bite.is_empty():
			if not bit:
				command("fishing.action", {"action": "cancel", "aim_direction": [0, 0, 1]})
				await sleep(0.3)
			continue
		var species: String = bite["event_payload"]["creature_def_id"]
		if not want.is_empty() and species not in want:
			out["skipped"] += 1
			command("fishing.action", {"action": "cancel", "aim_direction": [0, 0, 1]})
			await wait_until(func(): return not last_event("fishing.cancelled", aid, ev_base).is_empty() or not last_event("fishing.hook_set", aid, ev_base).is_empty(), 3.0)
			if not last_event("fishing.hook_set", aid, ev_base).is_empty():
				# cá bậc 0 tự dính khi hết cửa sổ: thả dây
				command("fishing.action", {"action": "cancel", "aim_direction": [0, 0, 1]})
				await wait_until(func(): return not last_event("fishing.cancelled", aid, ev_base).is_empty(), 3.0)
			await sleep(0.2)
			continue
		await sleep(0.15)
		command("fishing.action", {"action": "hook_set", "aim_direction": [0, 0, 1]})
		await wait_until(func(): return not last_event("fishing.hook_set", aid, ev_base).is_empty() or not last_event("fishing.cancelled", aid, ev_base).is_empty(), 3.0)
		if last_event("fishing.hook_set", aid, ev_base).is_empty():
			continue
		var launched := false
		var t0 := Time.get_ticks_msec()
		command("fishing.action", {"action": "reel_start", "aim_direction": [0, 0, 1]})
		var reeling := true
		while Time.get_ticks_msec() - t0 < 25000:
			if not last_event("fishing.launched", aid, ev_base).is_empty():
				launched = true
				break
			if not last_event("fishing.cancelled", aid, ev_base).is_empty():
				break
			var th_s: Dictionary = last_event("fishing.thrash_started", aid, ev_base)
			var th_e: Dictionary = last_event("fishing.thrash_ended", aid, ev_base)
			var thrashing: bool = not th_s.is_empty() and (th_e.is_empty() or int(th_e["server_tick"]) < int(th_s["server_tick"]))
			if thrashing and reeling:
				command("fishing.action", {"action": "reel_stop", "aim_direction": [0, 0, 1]})
				reeling = false
			elif not thrashing and not reeling:
				command("fishing.action", {"action": "reel_start", "aim_direction": [0, 0, 1]})
				reeling = true
			await get_tree().process_frame
		if not launched:
			out["lost"] += 1
			continue
		var cuid: String = last_event("fishing.launched", aid, ev_base)["event_payload"]["creature_uid"]
		out["last_launched_uid"] = cuid
		dur("equipment.equip", {"equipment_id": "tool_slipper"})
		var ko := false
		await wait_until(func(): return not entity(cuid).is_empty(), 2.0)
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 12000:
			var e: Dictionary = entity(cuid)
			if e.is_empty():
				break
			if String(e["state"]).begins_with("stunned"):
				ko = true
				break
			var ep := Vector3(e["position"][0], e["position"][1], e["position"][2])
			look_at_point(ep)
			await sleep(0.12)
			command("tool.use", {"target_uid": cuid})
			await sleep(0.45)
		if not ko:
			out["lost"] += 1
			continue
		ko_uid = cuid
		await sleep(1.2)  # chờ cá rơi hẳn xuống đất
		if hold_before_pickup_s > 0.0:
			await sleep(hold_before_pickup_s)
		var e2: Dictionary = entity(cuid)
		if e2.is_empty():
			out["lost"] += 1
			continue
		# đi theo vị trí hiện tại của cá (có thể còn nảy/rơi) tới trong tầm nhặt
		var t2 := Time.get_ticks_msec()
		var fish_pos := Vector3.INF
		while Time.get_ticks_msec() - t2 < 8000:
			var e3: Dictionary = entity(cuid)
			if e3.is_empty():
				break
			fish_pos = Vector3(e3["position"][0], e3["position"][1], e3["position"][2])
			var mp := my_pos()
			var dd := Vector2(fish_pos.x - mp.x, fish_pos.z - mp.z)
			if dd.length() <= 1.8 and absf(fish_pos.y - mp.y) < 2.0:
				break
			if _near_pier(isl, Vector2(mp.x, mp.z)) != _near_pier(isl, Vector2(fish_pos.x, fish_pos.z)):
				await nav_to(Vector2(fish_pos.x, fish_pos.z), 1.2, 6.0)
				continue
			yaw = atan2(-dd.x, -dd.y)
			move = Vector2(0, -1 if dd.length() > 1.5 else -0.5)
			await get_tree().process_frame
		move = Vector2.ZERO
		if entity(cuid).is_empty():
			out["lost"] += 1
			continue
		out["pickup_state"] = String(entity(cuid).get("state", ""))
		var pk: Dictionary = await dur("inventory.pickup", {"item_uid": cuid})
		if pk.get("status", "") != "committed":
			out["pickup_errors"] = out.get("pickup_errors", []) + ["%s@%s" % [str(pk.get("error_code")), out["pickup_state"]]]
			say("nhặt lỗi %s (cá %s, bot %s)" % [pk.get("error_code"), str(fish_pos), str(my_pos())])
			out["lost"] += 1
			continue
		out["ok"] = true
		out["uid"] = cuid
		out["species"] = species
		out["pickup_op"] = {"op_id": pk["op_id_sent"], "esv": pk["esv_sent"]}
		for it in save["inventory"]["bag"]:
			if it["uid"] == cuid:
				out["value"] = int(it["base_value"]) * int(it["trick_mult_milli"]) / 1000
		return out
	out["error"] = "max_casts"
	return out


# ------------------------------------------------------------------ đánh boss

## Đánh boss đang có trong phòng bằng dép tới khi boss.defeated / boss.escaped / hết giờ.
## Né: khi boss báo đòn (telegraph) nhắm vào vị trí mình thì chạy ngang; giữ khoảng 6–12 m, ở trong bãi.
func fight_boss(boss_uid: String, ev_from: int, timeout_s: float = 230.0) -> Dictionary:
	var out := {"result": "timeout", "throws": 0, "rejects": {}, "ko": 0, "dodges": 0, "hits": 0}
	var isl := island()
	var spot := IslandLayout.boss_spot(isl)
	var arena := IslandLayout.v3(isl, spot["arena"])
	var arena2 := Vector2(arena.x, arena.z)
	await dur("equipment.equip", {"equipment_id": "tool_slipper"})
	var scan := ev_from
	var dodge_until := 0
	var dodge_dir := Vector2.ZERO
	var last_throw := 0
	var pending: Array = []
	var aid: String = api.account_id
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_s * 1000.0:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		# kết quả các lần ném (chỉ bị từ chối mới có command.result)
		for rid in pending.duplicate():
			if results.has(rid):
				var code: String = str(results[rid].get("error_code", ""))
				out["rejects"][code] = int(out["rejects"].get(code, 0)) + 1
				pending.erase(rid)
		var done := ""
		while scan < events.size():
			var ev: Dictionary = events[scan]
			scan += 1
			var nm: String = ev["name"]
			var pl: Dictionary = ev["event_payload"]
			if nm == "boss.defeated" and pl.has("time_s"):
				done = "defeated"
				out["time_s"] = pl["time_s"]
			elif nm == "boss.escaped":
				done = "escaped"
				out["escape_reason"] = pl.get("reason", "")
			elif nm == "creature.damaged" and ev["actor_player_id"] == aid and pl.get("creature_uid", "") == boss_uid:
				out["hits"] += 1
			elif nm == "player.knocked_out" and ev["actor_player_id"] == aid:
				out["ko"] += 1
			elif nm == "boss.telegraph":
				var tp := Vector3(pl["position"][0], pl["position"][1], pl["position"][2])
				var mp := my_pos()
				if mp != Vector3.INF and Vector2(tp.x - mp.x, tp.z - mp.z).length() < 2.5:
					var be: Dictionary = entity(boss_uid)
					var bp := mp + Vector3(0, 0, 1)
					if not be.is_empty():
						bp = Vector3(be["position"][0], be["position"][1], be["position"][2])
					var away := Vector2(mp.x - bp.x, mp.z - bp.z).normalized()
					dodge_dir = Vector2(-away.y, away.x)
					if dodge_dir.dot(arena2 - Vector2(mp.x, mp.z)) < 0.0:
						dodge_dir = -dodge_dir
					var extra := 1.4 if String(pl["move_id"]) == "move_water_splash" else 0.6
					dodge_until = now + int((float(pl["duration_s"]) + extra) * 1000.0)
					out["dodges"] += 1
		if done != "":
			out["result"] = done
			break
		if mode() == "knocked_out":
			move = Vector2.ZERO
			continue
		var e: Dictionary = entity(boss_uid)
		if e.is_empty():
			move = Vector2.ZERO
			continue
		var bpos := Vector3(e["position"][0], e["position"][1], e["position"][2])
		var mpos := my_pos()
		if mpos == Vector3.INF:
			continue
		look_at_point(bpos + Vector3(0, 0.15, 0))
		var to_boss := Vector2(bpos.x - mpos.x, bpos.z - mpos.z)
		var d := to_boss.length()
		var from_center := Vector2(mpos.x, mpos.z).distance_to(arena2)
		if now < dodge_until:
			move_world(dodge_dir)
		elif from_center > 13.0:
			move_world(arena2 - Vector2(mpos.x, mpos.z))
		elif d < 6.0:
			move_world(-to_boss)
		elif d > 12.0:
			move_world(to_boss)
		else:
			move = Vector2.ZERO
		var st: String = String(e["state"])
		if now - last_throw >= 450 and st not in ["arriving", "defeated", "escaping"] and d <= 24.0:
			last_throw = now
			var rid: String = command("tool.use", {"target_uid": boss_uid})
			if rid != "":
				pending.append(rid)
				out["throws"] += 1
	move = Vector2.ZERO
	await sleep(0.6)
	for rid in pending:
		if results.has(rid):
			var code2: String = str(results[rid].get("error_code", ""))
			out["rejects"][code2] = int(out["rejects"].get(code2, 0)) + 1
	return out
