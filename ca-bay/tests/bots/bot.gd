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
	conn.closed.connect(func(r, _a): closed_reason = r)
	conn.auth_failed.connect(func(c): closed_reason = c)


func say(msg: String) -> void:
	var line := "[bot%d] %s" % [index, msg]
	log_lines.append(line)
	print(line)


func _on_message(type: String, payload: Dictionary, _env: Dictionary) -> void:
	match type:
		"state.snapshot":
			snapshot = payload
			for pl in payload["players"]:
				seen_players[pl["account_id"]] = pl["display_name"]
		"command.result":
			results[payload["request_id"]] = payload
			var rec: Variant = payload.get("receipt")
			if typeof(rec) == TYPE_DICTIONARY and rec.has("view"):
				if int(rec["view"]["save_version"]) >= save_version:
					save = rec["view"]
					save_version = int(save["save_version"])
		"domain.event":
			events.append(payload)
		"session.accepted":
			pass


func _process(delta: float) -> void:
	if not conn.is_live():
		return
	_input_t += delta
	if _input_t >= 0.05:
		_input_t = 0.0
		conn.send("player.input", {"move_x": move.x, "move_z": move.y, "look_yaw_rad": wrapf(yaw, -PI, PI), "look_pitch_rad": clampf(pitch, -1.5, 1.5), "jump": false})


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
	var r: Dictionary = await api.register(uname, "Bot %d" % index, "bot-password-%d-xyz" % index)
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
	return conn.send(type, payload)


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
