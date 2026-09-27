extends RefCounted
## Một phòng 1–4 người trên một đảo: mô phỏng authoritative, snapshot, sự kiện, lệnh bền vững.
## Không tin giá trị client. Mọi thay đổi tiền/đồ/tiến trình đi qua backend commit (op ledger).

const Fishing := preload("res://server/gameplay/fishing_sim.gd")
const Creatures := preload("res://server/gameplay/creature_sim.gd")
const Boss := preload("res://server/gameplay/boss_sim.gd")
const Thief := preload("res://server/gameplay/thief_sim.gd")

const INTERACT_RANGE := 4.0
const PICKUP_RANGE := 3.2
const BOSS_POST_RANGE := 7.0
const EMPTY_CLOSE_S := 300.0

var server  # Node room_server hoặc server giả trong test
var room_id: String
var island_id: String
var owner_account_id: String
var tick_count: int = 0
var dt: float = 1.0 / 30.0
var rng := RandomNumberGenerator.new()

var players: Dictionary = {}     # account_id -> Dictionary
var join_order: Array = []       # account_id theo thứ tự vào (chuyển chủ phòng)
var entities: Dictionary = {}    # uid -> Dictionary
var boss_state: Dictionary = {}  # rỗng nếu không có trận
var thief_state: Dictionary = {}
var votes: Dictionary = {}       # {"island_id": .., "approve": {account: bool}, "expires": tick}
var pending_hits: Array = []    # cú ném/bắn đang bay
var empty_since_tick: int = -1
var closed := false
var _snapshot_counter := 0


func _init(srv, rid: String, isl: String, owner: String) -> void:
	server = srv
	room_id = rid
	island_id = isl
	owner_account_id = owner
	rng.randomize()
	dt = 1.0 / float(ContentDB.limit("simulation_hz", 30))


func now_s() -> float:
	return tick_count * dt


func secs(t: float) -> int:
	return int(round(t / dt))


# ------------------------------------------------------------------ vòng đời người chơi

func is_full_for(account_id: String) -> bool:
	if players.has(account_id):
		return false
	return players.size() >= int(ContentDB.limit("players_per_room", 4))


func attach_player(peer_id: int, s: Dictionary) -> void:
	var aid: String = s["account_id"]
	var p: Dictionary = players.get(aid, {})
	var resumed := not p.is_empty()
	if p.is_empty():
		var save: Dictionary = s["save"]
		var spawn := IslandLayout.spawn_point(island_id)
		spawn.x += rng.randf_range(-1.5, 1.5)
		p = {
			"account_id": aid, "display_name": s["display_name"], "slot": _free_slot(),
			"pos": spawn, "vel_y": 0.0, "on_ground": true, "yaw": PI, "pitch": 0.0,
			"input": {"move_x": 0.0, "move_z": 0.0, "jump": false}, "last_input_seq": 0,
			"last_active_tick": tick_count, "mode": "active", "menu": false,
			"hp": float(save["player"]["hp"]), "hunger": float(save["player"]["hunger"]),
			"hurt_tick": -100000, "ko_until": -1, "playtime_accum": 0.0,
			"fishing": {"state": "IDLE"}, "cooldowns": {}, "slipper_back": [],
			"yaw_hist": [], "last_ko_tick": -100000, "checkpoint_tick": tick_count,
			"joined_tick": tick_count,
		}
		players[aid] = p
		join_order.append(aid)
		if owner_account_id == "" or not players.has(owner_account_id):
			owner_account_id = aid
	p["peer_id"] = peer_id
	p["connection_id"] = s["connection_id"]
	p["lease_epoch"] = s["lease_epoch"]
	p["save"] = s["save"]
	p["equipped"] = s["save"]["inventory"]["equipped_id"]
	p["disconnected_tick"] = -1
	p["mode"] = "active"
	p["menu"] = false
	p["last_active_tick"] = tick_count
	empty_since_tick = -1
	server.send(peer_id, "session.accepted", {
		"connection_id": s["connection_id"], "room_id": room_id, "account_id": aid,
		"lease_epoch": s["lease_epoch"], "protocol_version": ContentDB.protocol_version(),
		"content_hash": ContentDB.content_hash,
	})
	_broadcast_room_changed()
	emit("room.player_joined", aid, {"player_id": aid})
	# Người mới vào: gửi metadata các thực thể đang sống (chủ cá, giá trị) để hiển thị đúng.
	for uid in entities:
		var e: Dictionary = entities[uid]
		if e["kind"] in ["fish", "item"]:
			emit_to(aid, "creature.spawned", e.get("owner", null), {"creature_uid": uid, "creature_def_id": e["def_id"], "variant_id": e.get("variant", null), "is_boss": false})
			if e.has("value"):
				emit_to(aid, "creature.knocked_out", e.get("owner", null), _ko_payload(e))
	if not boss_state.is_empty():
		Boss.resync_to(self, aid)
	send_snapshot_to(aid)
	_push_view(p)
	if resumed:
		print("CABAY_RESUME %s" % aid)


func detach_player(account_id: String, peer_id: int) -> void:
	var p: Dictionary = players.get(account_id, {})
	if p.is_empty() or p.get("peer_id", 0) != peer_id:
		return
	p["peer_id"] = 0
	p["mode"] = "disconnected"
	p["disconnected_tick"] = tick_count
	Fishing.cancel(self, p, "disconnected")
	_checkpoint(p)
	_broadcast_room_changed()


func remove_player_now(account_id: String, release_lease: bool = true) -> void:
	var p: Dictionary = players.get(account_id, {})
	if p.is_empty():
		return
	Fishing.cancel(self, p, "left")
	if release_lease:
		server.queue_release(account_id, int(p["lease_epoch"]), room_id, "left")
	_remove_owned_entities(account_id)
	players.erase(account_id)
	join_order.erase(account_id)
	Boss.on_player_left(self, account_id)
	if owner_account_id == account_id:
		owner_account_id = join_order[0] if not join_order.is_empty() else ""
	emit("room.player_left", account_id, {"player_id": account_id})
	_broadcast_room_changed()
	if players.is_empty():
		empty_since_tick = tick_count


func _remove_owned_entities(account_id: String) -> void:
	# Cá chưa nhặt không bền vững → biến mất; đồ đã thả (escrow) backend trả về inbox khi release lease.
	for uid in entities.keys():
		var e: Dictionary = entities[uid]
		if e.get("owner", "") == account_id:
			entities.erase(uid)
			emit("item.despawned", account_id, {"item_uid": uid, "reason": "owner_left"})


func _free_slot() -> int:
	var used: Array = []
	for p in players.values():
		used.append(p["slot"])
	for i in 4:
		if i not in used:
			return i
	return 3


func should_close() -> bool:
	return players.is_empty() and empty_since_tick >= 0 and (tick_count - empty_since_tick) * dt > EMPTY_CLOSE_S


func close() -> void:
	closed = true
	Boss.abort(self, "room_closed")


func status_entry() -> Dictionary:
	var members: Array = []
	for aid in players:
		if players[aid]["mode"] != "disconnected":
			members.append(aid)
	return {"room_id": room_id, "status": "closed" if closed else "ready", "island_id": island_id,
		"owner_account_id": owner_account_id if owner_account_id != "" else null, "members": members}


# ------------------------------------------------------------------ tick

func tick(delta: float) -> void:
	tick_count += 1
	for aid in players.keys():
		var p: Dictionary = players[aid]
		_tick_player(p)
	Fishing.tick_all(self)
	Creatures.tick_all(self)
	Boss.tick(self)
	Thief.tick(self)
	_tick_votes()
	_snapshot_counter += 1
	var every := int(round(float(ContentDB.limit("simulation_hz", 30)) / float(ContentDB.limit("snapshot_hz", 10))))
	if _snapshot_counter >= every:
		_snapshot_counter = 0
		for aid in players:
			if players[aid]["peer_id"] != 0:
				send_snapshot_to(aid)


func _tick_player(p: Dictionary) -> void:
	var aid: String = p["account_id"]
	if p["mode"] == "disconnected":
		if (tick_count - int(p["disconnected_tick"])) * dt > float(ContentDB.limit("reconnect_grace_s", 90)):
			remove_player_now(aid)
		return
	# KO người chơi → hồi sinh ở bến an toàn
	if p["mode"] == "knocked_out":
		if tick_count >= int(p["ko_until"]):
			p["mode"] = "active"
			p["hp"] = float(ContentDB.balance["player"]["max_hp"])
			p["pos"] = IslandLayout.spawn_point(island_id)
			p["vel_y"] = 0.0
			p["last_active_tick"] = tick_count
			emit("player.respawned", aid, {"spawn_zone_id": IslandLayout.spawn_zone_id(island_id)})
		return
	var afk_s := float(ContentDB.limit("afk_timeout_s", 120))
	if p["mode"] == "active" and (tick_count - int(p["last_active_tick"])) * dt > afk_s:
		p["mode"] = "afk"
		Fishing.cancel(self, p, "afk")
	var can_move: bool = p["mode"] == "active"
	var inp: Dictionary = p["input"]
	var st := Movement.step(island_id, {"pos": p["pos"], "vel_y": p["vel_y"], "on_ground": p["on_ground"]},
		inp["move_x"] if can_move else 0.0, inp["move_z"] if can_move else 0.0, p["yaw"], inp["jump"] and can_move, dt)
	if st["on_ground"] and not p["on_ground"]:
		pass
	p["pos"] = st["pos"]
	p["vel_y"] = st["vel_y"]
	p["on_ground"] = st["on_ground"]
	inp["jump"] = false
	# lịch sử yaw cho trick xoay 360
	var hist: Array = p["yaw_hist"]
	hist.append([tick_count, float(p["yaw"])])
	while hist.size() > 0 and (tick_count - int(hist[0][0])) * dt > float(ContentDB.balance["scoring"]["trick_window_s"]) + 0.2:
		hist.pop_front()
	# hồi máu
	var pb: Dictionary = ContentDB.balance["player"]
	if p["hp"] < float(pb["max_hp"]) and (tick_count - int(p["hurt_tick"])) * dt > float(pb["regen_delay_s"]):
		p["hp"] = minf(float(pb["max_hp"]), p["hp"] + float(pb["regen_per_s"]) * dt)
	_tick_hunger(p)
	if (tick_count - int(p["checkpoint_tick"])) * dt >= float(ContentDB.limit("checkpoint_interval_s", 15)):
		_checkpoint(p)


func hunger_paused(p: Dictionary) -> bool:
	var pause: Array = ContentDB.hunger.get("pause_during", [])
	var mode: String = p["mode"]
	if mode == "afk" and "afk" in pause: return true
	if mode == "disconnected" and "disconnected" in pause: return true
	if (mode == "menu" or p["menu"]) and "menu" in pause: return true
	if mode == "knocked_out": return true
	if "boss_encounter" in pause and Boss.is_participant(self, p["account_id"]): return true
	return false


func _tick_hunger(p: Dictionary) -> void:
	if hunger_paused(p):
		return
	p["playtime_accum"] += dt
	var prev: float = p["hunger"]
	var drain := float(ContentDB.hunger["drain_per_active_minute"]) / 60.0 * dt
	p["hunger"] = clampf(prev - drain, float(ContentDB.hunger["clamp_min"]), float(ContentDB.hunger["clamp_max"]))
	if int(ceil(prev)) != int(ceil(p["hunger"])):
		var low := float(ContentDB.hunger["low_threshold"])
		emit_to(p["account_id"], "hunger.changed", p["account_id"], {"value": p["hunger"], "previous": prev, "player_id": p["account_id"], "band": "low" if p["hunger"] < low else "ok"})


func _checkpoint(p: Dictionary) -> void:
	p["checkpoint_tick"] = tick_count
	if p.get("lease_epoch", 0) == 0:
		return
	var delta: float = p["playtime_accum"]
	p["playtime_accum"] = 0.0
	var body := {
		"account_id": p["account_id"], "lease_epoch": p["lease_epoch"], "room_id": room_id,
		"hunger": p["hunger"], "hp": maxf(1.0, p["hp"]), "safe_island_id": island_id,
		"safe_spawn_zone_id": IslandLayout.spawn_zone_id(island_id), "active_playtime_delta_s": delta,
	}
	server.backend.call_api(HTTPClient.METHOD_POST, "/internal/accounts/checkpoint", body)


func reel_speed_mult(p: Dictionary) -> float:
	var m := 1.0
	var lvl := int(p["save"]["inventory"]["upgrades"].get("upg_reel_speed", 0))
	for l in ContentDB.upgrades["upg_reel_speed"]["levels"]:
		if int(l["level"]) == lvl:
			m = float(l["value"])
	if p["hunger"] < float(ContentDB.hunger["low_threshold"]):
		m *= float(ContentDB.hunger["low_reel_speed_multiplier"])
	return m


func damage_player(p: Dictionary, amount: float, source: String) -> void:
	if p["mode"] in ["knocked_out", "disconnected"]:
		return
	p["hp"] = maxf(0.0, p["hp"] - amount)
	p["hurt_tick"] = tick_count
	emit("player.damaged", p["account_id"], {"amount": amount, "source": source, "hp": p["hp"]})
	if p["hp"] <= 0.0:
		p["mode"] = "knocked_out"
		p["ko_until"] = tick_count + secs(float(ContentDB.balance["player"]["respawn_delay_s"]))
		Fishing.cancel(self, p, "player_ko")
		emit("player.knocked_out", p["account_id"], {})


# ------------------------------------------------------------------ thông điệp

func handle(account_id: String, env: Dictionary) -> void:
	var p: Dictionary = players.get(account_id, {})
	if p.is_empty():
		return
	var t: String = env["type"]
	var pl: Dictionary = env["payload"]
	var rid: String = env["request_id"]
	match t:
		"player.input":
			_on_input(p, pl, int(env["seq"]))
		"menu.active":
			p["menu"] = bool(pl["active"])
			if p["menu"]:
				Fishing.cancel(self, p, "menu")
				if p["mode"] == "active":
					p["mode"] = "menu"
			elif p["mode"] in ["menu", "afk"]:
				p["mode"] = "active"
				p["last_active_tick"] = tick_count
		"fishing.action":
			if not _gameplay_allowed(p, rid):
				return
			_touch(p)
			var err: String = Fishing.on_action(self, p, pl["action"], Vector3(pl["aim_direction"][0], pl["aim_direction"][1], pl["aim_direction"][2]))
			if err != "":
				_reject(p, rid, null, err)
		"tool.use":
			if not _gameplay_allowed(p, rid):
				return
			_touch(p)
			var err2: String = Creatures.use_tool(self, p, pl["target_uid"])
			if err2 != "":
				_reject(p, rid, null, err2)
		"npc.interact":
			_touch(p)
			_on_npc(p, pl["npc_id"], rid)
		"island.vote":
			_touch(p)
			_on_vote(p, pl["island_id"], bool(pl["approve"]), rid)
		"room.leave":
			var pid: int = p["peer_id"]
			remove_player_now(account_id)
			if pid:
				server.send(pid, "session.closed", {"reason": "room_closed", "reconnect_allowed": false})
		"room.ping":
			_touch(p)
			var pos := Vector3(pl["position"][0], pl["position"][1], pl["position"][2])
			if pos.distance_to(p["pos"]) > 60.0:
				_reject(p, rid, null, "OUT_OF_RANGE")
				return
			emit("room.ping", account_id, {"kind": pl["kind"], "position": [pos.x, pos.y, pos.z]})
		"player.emote":
			_touch(p)
			emit("player.emote", account_id, {"emote": pl["emote"]})
		_:
			_durable(p, t, pl, rid)


func _touch(p: Dictionary) -> void:
	p["last_active_tick"] = tick_count
	if p["mode"] == "afk":
		p["mode"] = "menu" if p["menu"] else "active"


func _gameplay_allowed(p: Dictionary, rid: String) -> bool:
	if p["mode"] == "knocked_out" or p["menu"]:
		_reject(p, rid, null, "PLAYER_INACTIVE")
		return false
	return true


func _reject(p: Dictionary, rid: String, op_id: Variant, code: String) -> void:
	if p["peer_id"]:
		server.reply_result(p["peer_id"], rid, op_id, "rejected", code, int(p["save"]["save_version"]), null)


func _on_input(p: Dictionary, pl: Dictionary, seq: int) -> void:
	var inp: Dictionary = p["input"]
	var meaningful: bool = absf(pl["move_x"]) > 0.05 or absf(pl["move_z"]) > 0.05 or bool(pl["jump"]) \
		or absf(angle_difference(float(pl["look_yaw_rad"]), float(p["yaw"]))) > 0.01 or absf(float(pl["look_pitch_rad"]) - float(p["pitch"])) > 0.01
	inp["move_x"] = float(pl["move_x"])
	inp["move_z"] = float(pl["move_z"])
	if pl["jump"]:
		inp["jump"] = true
	p["yaw"] = float(pl["look_yaw_rad"])
	p["pitch"] = float(pl["look_pitch_rad"])
	p["last_input_seq"] = seq
	if meaningful:
		_touch(p)


# ------------------------------------------------------------------ lệnh bền vững

const DURABLE := {
	"inventory.pickup": true, "inventory.drop": true, "inventory.sell": true, "shop.buy": true,
	"food.consume": true, "cooking.start": true, "cooking.collect": true, "equipment.equip": true,
	"bait.select": true, "quest.accept": true, "quest.deliver": true, "quest.claim": true,
	"lootbox.open": true, "cosmetic.buy": true, "cosmetic.equip": true, "boss.summon": true,
}


func _durable(p: Dictionary, t: String, pl: Dictionary, rid: String) -> void:
	if not DURABLE.has(t):
		_reject(p, rid, null, "INVALID_PAYLOAD")
		return
	var op_id: String = pl["op_id"]
	var esv: int = int(pl["expected_save_version"])
	var payload: Dictionary = pl.duplicate(true)
	payload.erase("op_id")
	payload.erase("expected_save_version")
	var pos: Vector3 = p["pos"]
	match t:
		"equipment.equip":
			var inv0: Dictionary = p["save"]["inventory"]
			if pl["equipment_id"] not in inv0["tools_owned"] and pl["equipment_id"] not in inv0["rods_owned"]:
				_reject(p, rid, op_id, "ITEM_NOT_OWNED")
				return
			# có hiệu lực ngay trong mô phỏng; commit bền vững chạy song song
			if String(pl["equipment_id"]).begins_with("rod_") or String(p.get("equipped", "")).begins_with("rod_"):
				Fishing.cancel(self, p, "swap")
			p["equipped"] = pl["equipment_id"]
		"bait.select":
			p["bait_pending"] = pl["bait_id"]
		"inventory.pickup":
			var e: Dictionary = entities.get(pl["item_uid"], {})
			if e.is_empty():
				# không có trong thế giới: có thể là đồ trong recovery inbox (backend kiểm quyền)
				pass
			else:
				if e.get("owner", "") != p["account_id"]:
					_reject(p, rid, op_id, "ITEM_NOT_OWNED")
					return
				if Vector2(e["pos"].x - pos.x, e["pos"].z - pos.z).length() > PICKUP_RANGE or absf(e["pos"].y - pos.y) > 3.0:
					_reject(p, rid, op_id, "OUT_OF_RANGE")
					return
				if e.get("reserved", "") != "" and e["reserved"] != op_id:
					_reject(p, rid, op_id, "ITEM_ALREADY_CLAIMED")
					return
				if e["kind"] == "fish":
					if e["state"] not in ["stunned", "stolen"]:
						_reject(p, rid, op_id, "COOLDOWN")
						return
					payload["fresh_item"] = {"def_kind": "creature", "def_id": e["def_id"], "variant_id": e.get("variant", null),
						"trick_mult_milli": int(e["value"]["trick_mult_milli"]), "tricks": e["value"]["tricks"]}
				e["reserved"] = op_id
		"inventory.drop":
			payload["room_id"] = room_id
		"inventory.sell", "shop.buy", "cooking.start", "cooking.collect":
			var shop := IslandLayout.shop_zone(island_id)
			var sid: String = pl.get("shop_id", pl.get("station_id", ""))
			if sid != shop["shop_id"]:
				_reject(p, rid, op_id, "OUT_OF_RANGE")
				return
			if IslandLayout.v3(island_id, shop["pos"]).distance_to(pos) > INTERACT_RANGE + 1.5:
				_reject(p, rid, op_id, "OUT_OF_RANGE")
				return
		"quest.accept", "quest.deliver":
			var npos := IslandLayout.npc_position(island_id, pl["npc_id"])
			if npos == Vector3.INF or npos.distance_to(pos) > INTERACT_RANGE + 1.5:
				_reject(p, rid, op_id, "OUT_OF_RANGE")
				return
		"boss.summon":
			var bs := IslandLayout.boss_spot(island_id)
			if bs["zone_id"] != pl["zone_id"] or IslandLayout.v3(island_id, bs["post"]).distance_to(pos) > BOSS_POST_RANGE:
				_reject(p, rid, op_id, "OUT_OF_RANGE")
				return
			if not boss_state.is_empty():
				_reject(p, rid, op_id, "COOLDOWN")
				return
			boss_state = {"pending": true}
	var res: Dictionary = await commit(p, t, payload, esv, op_id, rid)
	# hậu xử lý theo kết quả đã commit
	match t:
		"inventory.pickup":
			var e2: Dictionary = entities.get(pl["item_uid"], {})
			if not e2.is_empty():
				if res["status"] == "committed":
					entities.erase(pl["item_uid"])
					emit("item.picked_up", p["account_id"], {"item_uid": pl["item_uid"], "def_id": e2["def_id"]})
				elif e2.get("reserved", "") == op_id:
					e2["reserved"] = ""
		"inventory.drop":
			if res["status"] == "committed":
				var it: Dictionary = res["receipt"]["item"]
				var dpos: Vector3 = p["pos"] + Movement.look_dir(p["yaw"], 0.0) * 1.0
				dpos.y = IslandLayout.ground_height(island_id, dpos.x, dpos.z)
				entities[it["uid"]] = {"uid": it["uid"], "kind": "item", "def_id": it["def_id"], "owner": p["account_id"],
					"state": "item", "pos": dpos, "yaw": 0.0, "instance": it, "value": {"trick_mult_milli": it["trick_mult_milli"], "tricks": [], "total": Creatures.instance_value(it)},
					"spawn_tick": tick_count, "ground_tick": tick_count}
				emit("item.dropped", p["account_id"], {"item_uid": it["uid"], "position": [dpos.x, dpos.y, dpos.z]})
		"boss.summon":
			if res["status"] == "committed":
				Boss.start(self, p, pl["boss_id"], res["receipt"]["encounter_id"])
			else:
				boss_state = {}
		"equipment.equip":
			if res["status"] == "committed":
				emit("tool.equipped", p["account_id"], {"tool_id": pl["equipment_id"], "slot": 0})
			else:
				p["equipped"] = p["save"]["inventory"]["equipped_id"]


## Commit một op (client hoặc server khởi tạo). Trả kết quả backend; tự gửi command.result cho client nếu có request.
func commit(p: Dictionary, op_type: String, payload: Dictionary, expected_version: Variant, op_id: String = "", request_id: String = "") -> Dictionary:
	if op_id == "":
		op_id = Protocol.uuid4()
	var aid: String = p["account_id"]
	var res: Dictionary = await server.backend.commit(aid, int(p["lease_epoch"]), room_id, op_id, op_type, payload, expected_version)
	var cur: Dictionary = players.get(aid, {})
	if res.has("save") and typeof(res["save"]) == TYPE_DICTIONARY and not cur.is_empty():
		if int(res["save"]["save_version"]) >= int(cur["save"]["save_version"]):
			cur["save"] = res["save"]
	var receipt: Variant = res.get("receipt", null)
	if res["status"] == "committed" and not cur.is_empty():
		for ev in res.get("events", []):
			emit(ev["name"], aid, ev["payload"])
	if request_id != "" or DURABLE.has(op_type):
		var pid: int = cur.get("peer_id", 0) if not cur.is_empty() else 0
		if pid:
			var rec: Variant = receipt
			if typeof(rec) == TYPE_DICTIONARY:
				rec = rec.duplicate()
			elif rec == null:
				rec = {}
			if not cur.is_empty():
				rec["view"] = cur["save"]
			server.reply_result(pid, request_id if request_id != "" else _last_request_for(op_id), op_id,
				"committed" if res["status"] == "committed" else "rejected", res.get("error_code", null),
				int(cur["save"]["save_version"]), rec)
	return res


var _op_requests: Dictionary = {}


func _last_request_for(op_id: String) -> String:
	return _op_requests.get(op_id, Protocol.uuid4())


## Op do server khởi tạo (quest.talk, boss.reward, ...) – không có expected_save_version.
func server_op(p: Dictionary, op_type: String, payload: Dictionary) -> Dictionary:
	var res: Dictionary = await server.backend.commit(p["account_id"], int(p["lease_epoch"]), room_id, Protocol.uuid4(), op_type, payload, null)
	var cur: Dictionary = players.get(p["account_id"], {})
	if res.has("save") and typeof(res["save"]) == TYPE_DICTIONARY and not cur.is_empty():
		if int(res["save"]["save_version"]) >= int(cur["save"]["save_version"]):
			cur["save"] = res["save"]
	if res["status"] == "committed" and not cur.is_empty():
		for ev in res.get("events", []):
			emit(ev["name"], p["account_id"], ev["payload"])
		if cur["peer_id"]:
			server.send(cur["peer_id"], "account.updated", {"save_version": int(cur["save"]["save_version"]), "refresh_required": true})
			server.send(cur["peer_id"], "domain.event", _event_env("save.completed", p["account_id"], {"slot": op_type, "bytes": 0, "duration_ms": 0}))
			_push_view(cur)
	return res


func _push_view(p: Dictionary) -> void:
	# Không có message riêng cho view: dùng command.result "accepted" với op_id null, receipt.view.
	if p["peer_id"]:
		server.reply_result(p["peer_id"], Protocol.uuid4(), null, "accepted", null, int(p["save"]["save_version"]), {"view": p["save"]})


# ------------------------------------------------------------------ NPC

func _on_npc(p: Dictionary, npc_id: String, rid: String) -> void:
	var npos := IslandLayout.npc_position(island_id, npc_id)
	if npos == Vector3.INF or npos.distance_to(p["pos"]) > INTERACT_RANGE + 1.0:
		_reject(p, rid, null, "OUT_OF_RANGE")
		return
	var npc: Dictionary = ContentDB.npcs[npc_id]
	var lines: Dictionary = npc.get("lines", {})
	var save: Dictionary = p["save"]
	var said := false
	# Quà lần đầu (dép Cô Ba)
	if npc.has("gift") and "gift_given" not in save["progress"]["npc_flags"].get(npc_id, []):
		var r: Dictionary = await server_op(p, "npc.gift", {"npc_id": npc_id})
		if r["status"] == "committed" and lines.has("gift"):
			emit_to(p["account_id"], "dialogue.line_started", p["account_id"], {"npc_id": npc_id, "text_key": lines["gift"]})
			said = true
	# Bước "nói chuyện" của nhiệm vụ
	for qid in save["progress"]["quests"]:
		var st: Dictionary = save["progress"]["quests"][qid]
		var q: Dictionary = ContentDB.quests[qid]
		if st["state"] == "active" and int(st["step_index"]) < q["steps"].size():
			var step: Dictionary = q["steps"][int(st["step_index"])]
			if step["type"] == "talk" and step["target_id"] == npc_id:
				var r2: Dictionary = await server_op(p, "quest.talk", {"npc_id": npc_id})
				if r2["status"] == "committed" and step.has("dialogue_key"):
					emit_to(p["account_id"], "dialogue.line_started", p["account_id"], {"npc_id": npc_id, "text_key": step["dialogue_key"]})
					said = true
				break
			if step["type"] == "defeat_boss" and q["giver_npc_id"] == npc_id and step.has("refill_bait_id"):
				if int(save["inventory"]["bait_counts"].get(step["refill_bait_id"], 0)) == 0 and boss_state.is_empty():
					var r3: Dictionary = await server_op(p, "quest.refill", {"npc_id": npc_id})
					if r3["status"] == "committed" and lines.has("refill"):
						emit_to(p["account_id"], "dialogue.line_started", p["account_id"], {"npc_id": npc_id, "text_key": lines["refill"]})
						said = true
	if not said and lines.has("greet"):
		emit_to(p["account_id"], "dialogue.line_started", p["account_id"], {"npc_id": npc_id, "text_key": lines["greet"]})
	if p["peer_id"]:
		server.reply_result(p["peer_id"], rid, null, "accepted", null, int(p["save"]["save_version"]), {"npc_id": npc_id, "view": p["save"]})


# ------------------------------------------------------------------ chuyển đảo

func _on_vote(p: Dictionary, isl: String, approve: bool, rid: String) -> void:
	if not ContentDB.islands.has(isl) or isl == island_id:
		_reject(p, rid, null, "INVALID_PAYLOAD")
		return
	if not approve:
		votes = {}
		emit("ui.popup_requested", p["account_id"], {"kind": "info", "text_key": "ui.coop.waiting", "args": {}})
		return
	var missing: Array = []
	for aid in players:
		if isl not in players[aid]["save"]["progress"]["islands_unlocked"]:
			missing.append(players[aid]["display_name"])
	if not missing.is_empty():
		emit("ui.popup_requested", p["account_id"], {"kind": "warning", "text_key": "ui.coop.travel_locked", "args": {"names": ", ".join(missing)}})
		_reject(p, rid, null, "UNLOCK_REQUIRED")
		return
	if votes.get("island_id", "") != isl:
		votes = {"island_id": isl, "approve": {}, "expires": tick_count + secs(60.0)}
	votes["approve"][p["account_id"]] = true
	emit("ui.popup_requested", p["account_id"], {"kind": "vote", "text_key": "ui.coop.travel_vote", "args": {"island_id": isl, "yes": votes["approve"].size(), "total": _present_count()}})
	if p["peer_id"]:
		server.reply_result(p["peer_id"], rid, null, "accepted", null, int(p["save"]["save_version"]), {"votes": votes["approve"].size()})


func _present_count() -> int:
	var n := 0
	for aid in players:
		if players[aid]["mode"] != "disconnected":
			n += 1
	return n


func _tick_votes() -> void:
	if votes.is_empty():
		return
	if tick_count > int(votes["expires"]):
		votes = {}
		return
	var all_yes := true
	for aid in players:
		if players[aid]["mode"] != "disconnected" and not votes["approve"].has(aid):
			all_yes = false
	if all_yes:
		travel_to(votes["island_id"])
		votes = {}


func travel_to(isl: String) -> void:
	Boss.abort(self, "travel")
	for aid in players:
		Fishing.cancel(self, players[aid], "travel")
	entities.clear()
	thief_state = {}
	island_id = isl
	var i := 0
	for aid in players:
		var p: Dictionary = players[aid]
		var sp := IslandLayout.spawn_point(island_id)
		sp.x += (i - 1.5) * 1.2
		p["pos"] = sp
		p["vel_y"] = 0.0
		i += 1
		emit("world.island_entered", aid, {"island_id": island_id})
		_checkpoint(p)
	_broadcast_room_changed()


# ------------------------------------------------------------------ gửi đi

func _broadcast_room_changed() -> void:
	var members: Array = []
	for aid in join_order:
		members.append(aid)
	var payload := {"owner_account_id": owner_account_id if owner_account_id != "" else join_order[0] if not join_order.is_empty() else "00000000-0000-4000-8000-000000000000",
		"members": members, "island_id": island_id, "status": "playing"}
	for aid in players:
		if players[aid]["peer_id"]:
			server.send(players[aid]["peer_id"], "room.changed", payload)


func _event_env(name: String, actor: Variant, payload: Dictionary) -> Dictionary:
	return {"name": name, "actor_player_id": actor, "room_id": room_id, "event_id": Protocol.uuid4(), "server_tick": tick_count, "event_payload": payload}


func emit(name: String, actor: Variant, payload: Dictionary) -> void:
	var ev := _event_env(name, actor, payload)
	for aid in players:
		if players[aid]["peer_id"]:
			server.send(players[aid]["peer_id"], "domain.event", ev)
	if actor != null and TUTORIAL_EVENTS.has(name):
		var step: String = TUTORIAL_EVENTS[name]
		if name != "creature.damaged" or payload.get("airborne", false):
			_tutorial(actor, step)


## Sự kiện đầu tiên của mỗi bước hướng dẫn → ghi vào save (server op, một lần/bước).
const TUTORIAL_EVENTS := {
	"fishing.cast_released": "cast", "fishing.hook_set": "reel", "fishing.thrash_ended": "thrash",
	"creature.knocked_out": "smack", "creature.damaged": "throw_air", "item.picked_up": "pickup",
	"economy.item_sold": "sell",
}


func _tutorial(account_id: String, step: String) -> void:
	var p: Dictionary = players.get(account_id, {})
	if p.is_empty() or step in p["save"]["progress"]["tutorial_done"]:
		return
	var pend: Dictionary = p.get("tut_pending", {})
	if pend.has(step):
		return
	pend[step] = true
	p["tut_pending"] = pend
	await server_op(p, "tutorial.done", {"step_id": step})
	pend.erase(step)


func emit_to(account_id: String, name: String, actor: Variant, payload: Dictionary) -> void:
	var p: Dictionary = players.get(account_id, {})
	if p.is_empty() or p["peer_id"] == 0:
		return
	server.send(p["peer_id"], "domain.event", _event_env(name, actor, payload))


func send_snapshot_to(account_id: String) -> void:
	var p: Dictionary = players.get(account_id, {})
	if p.is_empty() or p["peer_id"] == 0:
		return
	var plist: Array = []
	for aid in join_order:
		var q: Dictionary = players[aid]
		plist.append({"account_id": aid, "display_name": q["display_name"], "position": [q["pos"].x, q["pos"].y, q["pos"].z],
			"yaw_rad": wrapf(q["yaw"], -PI, PI), "hp": clampf(q["hp"], 0, 100), "hunger": clampf(q["hunger"], 0, 100),
			"mode": "menu" if q["menu"] and q["mode"] == "active" else q["mode"]})
	var elist: Array = []
	for uid in entities:
		var e: Dictionary = entities[uid]
		elist.append({"uid": uid, "def_id": e["def_id"], "kind": e["kind"], "state": e["state"],
			"position": [e["pos"].x, e["pos"].y, e["pos"].z], "yaw_rad": wrapf(float(e.get("yaw", 0.0)), -PI, PI)})
		if elist.size() >= 128:
			break
	server.send(p["peer_id"], "state.snapshot", {"server_tick": tick_count, "snapshot_id": Protocol.uuid4(), "island_id": island_id,
		"last_ack_input_seq": int(p["last_input_seq"]), "players": plist, "entities": elist})


func _ko_payload(e: Dictionary) -> Dictionary:
	return {"creature_uid": e["uid"], "creature_def_id": e["def_id"], "variant_id": e.get("variant", null), "tool_id": e.get("ko_tool", "tool_hand"),
		"item_uid": e["uid"], "value": int(e["value"]["total"]), "total_multiplier": float(e["value"]["trick_mult_milli"]) / 1000.0,
		"position": [e["pos"].x, e["pos"].y, e["pos"].z]}
