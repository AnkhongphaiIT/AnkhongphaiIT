extends RefCounted
## Trận boss co-op (04 §4, bosses.json). HP khóa theo số người lúc bắt đầu:
## HP = ceil(base_hp × (1 + 0.45 × (n − 1))). Đồng hồ không rút ngắn khi thêm bạn.
## Thắng: mỗi người đủ điều kiện nhận thưởng riêng đúng một lần. Không thắng: hoàn mồi cho người gọi đúng một lần.

const ARRIVE_S := 1.6


static func start(room, p: Dictionary, boss_id: String, encounter_id: String) -> void:
	var boss: Dictionary = ContentDB.bosses[boss_id]
	var cre: Dictionary = ContentDB.creatures[boss["creature_id"]]
	var spot = IslandLayout.boss_spot(room.island_id)
	var participants := {}
	for aid in room.players:
		var q: Dictionary = room.players[aid]
		if q["mode"] != "disconnected":
			participants[aid] = {"damage": 0.0}
	var n := clampi(participants.size(), 1, int(boss["cooperative"]["max_players"]))
	var hp := ceili(float(cre["hp"]) * (1.0 + float(boss["cooperative"]["hp_per_extra_player_mult"]) * (n - 1)))
	var timer := float(boss["escape_timer_s"]["solo"]) * pow(float(boss["escape_timer_s"]["per_extra_player_mult"]), n - 1)
	var uid := Protocol.uuid4()
	var water: Vector2 = spot["water"]
	var arena: Vector2 = spot["arena"]
	room.boss_state = {
		"boss_id": boss_id, "creature_id": boss["creature_id"], "encounter_id": encounter_id, "summoner": p["account_id"],
		"uid": uid, "hp": float(hp), "max_hp": float(hp), "n": n, "participants": participants,
		"start_tick": room.tick_count, "end_tick": room.tick_count + room.secs(timer), "warned": false, "phase": 1,
		"state": "arriving", "state_until": room.tick_count + room.secs(ARRIVE_S), "stunned_until": -1,
		"from": Vector3(water.x, 0.0, water.y), "arena": IslandLayout.v3(room.island_id, arena), "arena_radius": float(spot["arena_radius"]),
		"move": {}, "outside": {}, "projectiles": [], "hit_once": {},
	}
	room.entities[uid] = {"uid": uid, "kind": "boss", "def_id": boss["creature_id"], "state": "arriving", "pos": Vector3(water.x, 0.0, water.y), "yaw": 0.0, "owner": p["account_id"]}
	room.emit("boss.summoned", p["account_id"], {"boss_id": boss_id, "creature_uid": uid, "position": [water.x, 0.0, water.y],
		"hp": float(hp), "max_hp": float(hp), "end_in_s": timer})
	room.emit("creature.spawned", p["account_id"], {"creature_uid": uid, "creature_def_id": boss["creature_id"], "variant_id": null, "is_boss": true})


static func resync_to(room, aid: String) -> void:
	var b: Dictionary = room.boss_state
	if not b.has("uid"):
		return
	var e: Dictionary = room.entities.get(b["uid"], {})
	room.emit_to(aid, "boss.summoned", b["summoner"], {"boss_id": b["boss_id"], "creature_uid": b["uid"], "position": _arr(e.get("pos", b["arena"])),
		"hp": float(b["hp"]), "max_hp": float(b["max_hp"]), "end_in_s": maxf(0.0, (int(b["end_tick"]) - room.tick_count) * room.dt)})
	room.emit_to(aid, "boss.phase_changed", null, {"boss_id": b["boss_id"], "phase": b["phase"]})


static func is_participant(room, aid: String) -> bool:
	var b: Dictionary = room.boss_state
	if not b.has("uid") or not b["participants"].has(aid):
		return false
	var p: Dictionary = room.players.get(aid, {})
	return not p.is_empty() and (p["pos"] as Vector3).distance_to(b["arena"]) <= float(b["arena_radius"]) + 6.0


static func on_player_left(room, aid: String) -> void:
	pass  # kiểm tra có mặt diễn ra mỗi tick; người rời không làm giảm HP tối đa


static func _arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func tick(room) -> void:
	var b: Dictionary = room.boss_state
	if not b.has("uid"):
		return
	var boss: Dictionary = ContentDB.bosses[b["boss_id"]]
	var e: Dictionary = room.entities.get(b["uid"], {})
	if e.is_empty():
		room.boss_state = {}
		return
	var now: int = room.tick_count
	_tick_projectiles(room, b)
	match String(b["state"]):
		"arriving":
			var t = clampf(1.0 - float(int(b["state_until"]) - now) / float(room.secs(ARRIVE_S)), 0.0, 1.0)
			var pos: Vector3 = (b["from"] as Vector3).lerp(b["arena"], t)
			pos.y += sin(t * PI) * 4.0
			e["pos"] = pos
			if now >= int(b["state_until"]):
				b["state"] = "idle"
				b["state_until"] = now + room.secs(1.2)
				e["state"] = "idle"
				room.emit("creature.landed", b["summoner"], {"creature_uid": b["uid"], "surface": "ground", "position": _arr(pos)})
			return
		"defeated", "escaping":
			if now >= int(b["state_until"]):
				room.entities.erase(b["uid"])
				room.boss_state = {}
			else:
				var water: Vector3 = b["from"]
				e["pos"] = (e["pos"] as Vector3).move_toward(water, 6.0 * room.dt)
			return
	# đồng hồ trốn
	var remaining = (int(b["end_tick"]) - now) * room.dt
	if remaining <= float(boss["escape_warning_s"]) and not b["warned"]:
		b["warned"] = true
		room.emit("boss.escape_warning", b["summoner"], {"boss_id": b["boss_id"], "remaining_s": remaining})
	if remaining <= 0.0:
		_escape(room, "timeout")
		return
	# có người tham gia còn trong bãi không
	var anyone := false
	for aid in b["participants"]:
		var q: Dictionary = room.players.get(aid, {})
		if q.is_empty() or q["mode"] in ["disconnected"]:
			continue
		if (q["pos"] as Vector3).distance_to(b["arena"]) <= float(b["arena_radius"]) + 4.0:
			anyone = true
			b["outside"].erase(aid)
	if not anyone:
		if not b.has("all_out_tick"):
			b["all_out_tick"] = now
		elif (now - int(b["all_out_tick"])) * room.dt > float(boss["leave_arena_grace_s"]):
			_escape(room, "abandoned")
			return
	else:
		b.erase("all_out_tick")
	# pha
	var ratio: float = float(b["hp"]) / float(b["max_hp"])
	var phase := 1
	for ph in boss["phases"]:
		if ratio < float(ph["hp_below"]) and int(ph["phase"]) > phase:
			phase = int(ph["phase"])
	if phase != int(b["phase"]):
		b["phase"] = phase
		room.emit("boss.phase_changed", b["summoner"], {"boss_id": b["boss_id"], "phase": phase})
	_tick_ai(room, b, boss, e, now)


static func _targets(room, b: Dictionary) -> Array:
	var out: Array = []
	for aid in room.players:
		var q: Dictionary = room.players[aid]
		if q["mode"] in ["disconnected", "knocked_out"]:
			continue
		if (q["pos"] as Vector3).distance_to(b["arena"]) <= float(b["arena_radius"]) + 4.0:
			out.append(q)
	return out


static func _tick_ai(room, b: Dictionary, boss: Dictionary, e: Dictionary, now: int) -> void:
	var st: String = b["state"]
	if st == "idle":
		var tgts := _targets(room, b)
		if not tgts.is_empty():
			var tp: Vector3 = tgts[0]["pos"]
			var d := Vector2(tp.x - e["pos"].x, tp.z - e["pos"].z)
			e["yaw"] = atan2(-d.x, -d.y)
		if now < int(b["state_until"]) or tgts.is_empty():
			return
		var phase_def: Dictionary = {}
		for ph in boss["phases"]:
			if int(ph["phase"]) == int(b["phase"]):
				phase_def = ph
		var weights: Dictionary = phase_def.get("move_weights", {})
		var total := 0.0
		for k in weights:
			total += float(weights[k])
		var r: float = room.rng.randf() * total
		var chosen := ""
		for k in weights:
			r -= float(weights[k])
			if r <= 0.0:
				chosen = k
				break
		if chosen == "":
			chosen = weights.keys()[0]
		var move: Dictionary = {}
		for m in boss["moves"]:
			if m["move_id"] == chosen:
				move = m
		var target: Dictionary = tgts[room.rng.randi_range(0, tgts.size() - 1)]
		b["move"] = move
		b["target_pos"] = target["pos"]
		b["state"] = "telegraph"
		b["state_until"] = now + room.secs(float(move["telegraph_s"]))
		e["state"] = "telegraph_" + String(move["move_id"]).trim_prefix("move_")
		room.emit("boss.telegraph", b["summoner"], {"boss_id": b["boss_id"], "move_id": move["move_id"], "duration_s": float(move["telegraph_s"]), "position": _arr(target["pos"])})
	elif st == "telegraph":
		if now >= int(b["state_until"]):
			_execute(room, b, e, now)
	elif st == "charging":
		var dir: Vector3 = b["charge_dir"]
		var step: Vector3 = dir * float(b["move"]["speed_mps"]) * room.dt
		var np: Vector3 = e["pos"] + step
		var center: Vector3 = b["arena"]
		if Vector2(np.x - center.x, np.z - center.z).length() > float(b["arena_radius"]) or now >= int(b["state_until"]):
			_recover(room, b, e, now)
		else:
			np.y = IslandLayout.ground_height(room.island_id, np.x, np.z)
			e["pos"] = np
			for q in _targets(room, b):
				if not b["hit_once"].has(q["account_id"]) and (q["pos"] as Vector3).distance_to(np) <= 1.6:
					b["hit_once"][q["account_id"]] = true
					room.damage_player(q, float(b["move"]["damage"]), "boss")
	elif st == "recover":
		if now >= int(b["state_until"]):
			b["state"] = "idle"
			b["state_until"] = now + room.secs(0.8)
			e["state"] = "idle"


static func _execute(room, b: Dictionary, e: Dictionary, now: int) -> void:
	var move: Dictionary = b["move"]
	var pos: Vector3 = e["pos"]
	match String(move["move_id"]):
		"move_tail_slam":
			e["state"] = "attack_slam"
			for q in _targets(room, b):
				if (q["pos"] as Vector3).distance_to(pos) <= float(move["radius_m"]) + 0.5:
					room.damage_player(q, float(move["damage"]), "boss")
			_recover(room, b, e, now)
		"move_belly_charge":
			var tp: Vector3 = b["target_pos"]
			var d := Vector3(tp.x - pos.x, 0, tp.z - pos.z)
			b["charge_dir"] = d.normalized() if d.length() > 0.1 else Vector3(0, 0, 1)
			b["hit_once"] = {}
			b["state"] = "charging"
			b["state_until"] = now + room.secs(float(move["distance_m"]) / float(move["speed_mps"]))
			e["state"] = "charging"
		"move_water_splash":
			e["state"] = "attack_spit"
			var tp2: Vector3 = b["target_pos"]
			var base := Vector3(tp2.x - pos.x, 0, tp2.z - pos.z).normalized()
			var n := int(move["projectiles"])
			var spread := deg_to_rad(float(move["spread_deg"]))
			for i in n:
				var a := -spread * 0.5 + spread * (float(i) / maxf(1.0, float(n - 1)))
				var dir := base.rotated(Vector3.UP, a)
				var puid := Protocol.uuid4()
				room.entities[puid] = {"uid": puid, "kind": "prop", "def_id": "boss_projectile", "state": "flying", "pos": pos + Vector3(0, 0.8, 0), "yaw": 0.0}
				(b["projectiles"] as Array).append({"uid": puid, "dir": dir, "speed": float(move["projectile_speed_mps"]), "damage": float(move["damage"]), "until": now + room.secs(2.2)})
			_recover(room, b, e, now)


static func _recover(room, b: Dictionary, e: Dictionary, now: int) -> void:
	var move: Dictionary = b["move"]
	b["state"] = "recover"
	b["state_until"] = now + room.secs(float(move["recover_s"]))
	if move.get("stun_on_recover", false):
		b["stunned_until"] = int(b["state_until"])
		e["state"] = "stunned"
	else:
		e["state"] = "recover"


static func _tick_projectiles(room, b: Dictionary) -> void:
	var keep: Array = []
	for pr in b["projectiles"]:
		var ent: Dictionary = room.entities.get(pr["uid"], {})
		if ent.is_empty() or room.tick_count >= int(pr["until"]):
			room.entities.erase(pr["uid"])
			continue
		var np: Vector3 = ent["pos"] + (pr["dir"] as Vector3) * float(pr["speed"]) * room.dt
		ent["pos"] = np
		var hit := false
		for aid in room.players:
			var q: Dictionary = room.players[aid]
			if q["mode"] in ["disconnected", "knocked_out"]:
				continue
			if Vector2(q["pos"].x - np.x, q["pos"].z - np.z).length() <= 0.9:
				room.damage_player(q, float(pr["damage"]), "boss_projectile")
				hit = true
				break
		if hit:
			room.entities.erase(pr["uid"])
		else:
			keep.append(pr)
	b["projectiles"] = keep


static func damage(room, attacker: Dictionary, amount: float, tool_id: String) -> void:
	var b: Dictionary = room.boss_state
	if not b.has("uid") or String(b["state"]) in ["arriving", "defeated", "escaping"] or attacker.is_empty():
		return
	var boss: Dictionary = ContentDB.bosses[b["boss_id"]]
	var mult = float(boss["stunned_damage_mult"]) if room.tick_count < int(b["stunned_until"]) else 1.0
	var dmg: float = amount * mult
	b["hp"] = maxf(0.0, float(b["hp"]) - dmg)
	var aid: String = attacker["account_id"]
	if not b["participants"].has(aid):
		b["participants"][aid] = {"damage": 0.0, "late": true}
	b["participants"][aid]["damage"] = float(b["participants"][aid]["damage"]) + dmg
	var pos: Vector3 = room.entities[b["uid"]]["pos"]
	room.emit("creature.damaged", aid, {"creature_uid": b["uid"], "amount": dmg, "tool_id": tool_id, "hit_zone": "body", "airborne": false, "position": _arr(pos),
		"hp": float(b["hp"]), "max_hp": float(b["max_hp"])})
	if float(b["hp"]) <= 0.0:
		_defeat(room)


static func _defeat(room) -> void:
	var b: Dictionary = room.boss_state
	var boss: Dictionary = ContentDB.bosses[b["boss_id"]]
	var e: Dictionary = room.entities[b["uid"]]
	b["state"] = "defeated"
	b["state_until"] = room.tick_count + room.secs(4.0)
	e["state"] = "defeated"
	var time_s = (room.tick_count - int(b["start_tick"])) * room.dt
	room.emit("boss.defeated", b["summoner"], {"boss_id": b["boss_id"], "time_s": time_s, "reward": int(boss["reward_base_value"])})
	for proj in b["projectiles"]:
		room.entities.erase(proj["uid"])
	b["projectiles"] = []
	# Người đủ điều kiện: còn trong phòng, không AFK/mất kết nối, có đóng góp hoặc có mặt trong bãi.
	for aid in b["participants"]:
		var q: Dictionary = room.players.get(aid, {})
		if q.is_empty() or q["mode"] in ["disconnected", "afk"]:
			continue
		var contributed: bool = float(b["participants"][aid]["damage"]) > 0.0
		var present: bool = (q["pos"] as Vector3).distance_to(b["arena"]) <= float(b["arena_radius"]) + 6.0
		if contributed or (present and not b["participants"][aid].get("late", false)):
			room.server_op(q, "boss.reward", {"encounter_id": b["encounter_id"], "boss_id": b["boss_id"]})


static func _escape(room, reason: String) -> void:
	var b: Dictionary = room.boss_state
	if not b.has("uid") or String(b["state"]) in ["defeated", "escaping"]:
		return
	var e: Dictionary = room.entities.get(b["uid"], {})
	b["state"] = "escaping"
	b["state_until"] = room.tick_count + room.secs(2.5)
	if not e.is_empty():
		e["state"] = "escaping"
	for proj in b["projectiles"]:
		room.entities.erase(proj["uid"])
	b["projectiles"] = []
	room.emit("boss.escaped", b["summoner"], {"boss_id": b["boss_id"], "reason": reason})
	_refund(room, b["summoner"], b["encounter_id"])


static func _refund(room, summoner: String, encounter_id: String) -> void:
	# Hoàn mồi cho người gọi, kể cả khi họ đã rời phòng (backend cho phép boss.refund không cần lease).
	var q: Dictionary = room.players.get(summoner, {})
	if not q.is_empty():
		var r: Dictionary = await room.server_op(q, "boss.refund", {"encounter_id": encounter_id})
		if r["status"] == "committed":
			room.emit_to(summoner, "ui.popup_requested", summoner, {"kind": "info", "text_key": "ui.popup.boss_escaped", "args": {}})
	else:
		await room.server.backend.commit(summoner, 0, room.room_id, Protocol.uuid4(), "boss.refund", {"encounter_id": encounter_id}, null)


static func abort(room, reason: String) -> void:
	var b: Dictionary = room.boss_state
	if b.has("uid") and String(b["state"]) not in ["defeated", "escaping"]:
		_escape(room, reason)
	if b.has("uid"):
		room.entities.erase(b["uid"])
	room.boss_state = {}
