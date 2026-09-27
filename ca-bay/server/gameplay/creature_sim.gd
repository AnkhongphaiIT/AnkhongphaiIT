extends RefCounted
## Sinh vật sau khi giật lên bờ: bay theo cung, rơi, chạy về sông, bị công cụ làm "xỉu" (không máu).
## Trick/giá tính ở server bằng số nguyên có trần (07 §6.1, tricks.json, balance.scoring).

const Boss := preload("res://server/gameplay/boss_sim.gd")
const G := 9.8


static func launch(room, p: Dictionary, cre_id: String, variant: Variant, perfect: bool, lure_pos: Vector3) -> void:
	var cre: Dictionary = ContentDB.creatures[cre_id]
	var fb: Dictionary = ContentDB.balance["fishing"]
	var ppos: Vector3 = p["pos"]
	var dir := Vector2(lure_pos.x - ppos.x, lure_pos.z - ppos.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector2(0, 1)
	var perp := Vector2(-dir.y, dir.x)
	# Điểm đáp an toàn: cá bay qua vai, rơi sau lưng người câu (phía đất liền), không rơi xuống nước.
	var spread: float = room.rng.randf_range(-float(fb["launch_land_spread_m"]), float(fb["launch_land_spread_m"]))
	var land2: Vector2 = Vector2(ppos.x, ppos.z) - dir * float(fb["launch_land_before_player_m"]) + perp * spread
	if not _safe_ground(room.island_id, land2):
		land2 = Vector2(ppos.x, ppos.z) - dir * float(fb["launch_land_before_player_m"])
	if not _safe_ground(room.island_id, land2):
		land2 = IslandLayout.nearest_land(room.island_id, Vector2(ppos.x, ppos.z))
	var start := lure_pos + Vector3(0, float(fb["launch_spawn_height_m"]), 0)
	var land_y = IslandLayout.ground_height(room.island_id, land2.x, land2.y)
	var apex: float = room.rng.randf_range(float(cre["launch"]["apex_m"]["min"]), float(cre["launch"]["apex_m"]["max"]))
	if perfect:
		apex += float(fb["perfect_yank_bonus_apex_m"])
	var top := maxf(start.y, land_y) + apex
	var vy := sqrt(2.0 * G * (top - start.y))
	var t_total := vy / G + sqrt(2.0 * (top - land_y) / G)
	var vel := Vector3((land2.x - start.x) / t_total, vy, (land2.y - start.z) / t_total)
	var uid := Protocol.uuid4()
	room.entities[uid] = {
		"uid": uid, "kind": "fish", "def_id": cre_id, "owner": p["account_id"], "variant": variant,
		"hp": float(cre["hp"]), "max_hp": float(cre["hp"]), "state": "airborne", "flying": true, "pos": start, "vel": vel,
		"yaw": atan2(-dir.x, -dir.y), "spin": float(cre["launch"]["spin_rad_s"]), "perfect": perfect,
		"hits": [], "air_hits": 0, "spawn_tick": room.tick_count, "next_act": room.tick_count + room.secs(0.8),
		"attack": {}, "ground_tick": -1,
	}
	room.emit("creature.spawned", p["account_id"], {"creature_uid": uid, "creature_def_id": cre_id, "variant_id": variant, "is_boss": false})
	room.emit("fishing.launched", p["account_id"], {"creature_uid": uid, "creature_def_id": cre_id, "perfect_yank": perfect, "position": [start.x, start.y, start.z]})


static func _safe_ground(isl: String, p: Vector2) -> bool:
	return IslandLayout.walkable(isl, p.x, p.y) and not IslandLayout.is_water(isl, p.x, p.y) and IslandLayout.ground_height(isl, p.x, p.y) > -0.1


static func tick_all(room) -> void:
	var now: int = room.tick_count
	var dt: float = room.dt
	var pending: Array = room.pending_hits
	room.pending_hits = []
	for h in pending:
		if now >= int(h["at"]):
			_apply_hit(room, h)
		else:
			room.pending_hits.append(h)
	for uid in room.entities.keys():
		if not room.entities.has(uid):
			continue
		var e: Dictionary = room.entities[uid]
		if e["kind"] == "fish":
			_tick_fish(room, e, now, dt)
		elif e["kind"] == "item":
			_settle(room, e, dt)


static func _settle(room, e: Dictionary, dt: float) -> void:
	var g = IslandLayout.ground_height(room.island_id, e["pos"].x, e["pos"].z)
	if e["pos"].y > g + 0.01:
		e["pos"].y = maxf(g, e["pos"].y - 6.0 * dt)


static func _tick_fish(room, e: Dictionary, now: int, dt: float) -> void:
	var cre: Dictionary = ContentDB.creatures[e["def_id"]]
	var isl: String = room.island_id
	var ko: bool = e["state"] in ["stunned", "stunned_waking", "stolen"]
	if e["state"] == "stolen":
		return
	# vật lý bay (kể cả cá đã xỉu/đang chờ nhặt vẫn rơi tiếp)
	if e.get("flying", false):
		var v: Vector3 = e["vel"]
		v.y -= G * dt
		var np: Vector3 = e["pos"] + v * dt
		e["yaw"] = wrapf(float(e["yaw"]) + float(e["spin"]) * dt, -PI, PI)
		var g := IslandLayout.ground_height(isl, np.x, np.z)
		if np.y <= g and v.y < 0:
			np.y = g
			e["flying"] = false
			e["vel"] = Vector3.ZERO
			e["ground_tick"] = now
			if IslandLayout.is_water(isl, np.x, np.z):
				if ko:
					var l := IslandLayout.nearest_land(isl, Vector2(np.x, np.z))
					np = IslandLayout.v3(isl, l)
				else:
					_escape(room, e, np)
					return
			if not ko:
				e["state"] = "landed"
				if not e.has("idle_until"):
					e["idle_until"] = now + room.secs(1.5)  # choáng khi vừa rơi xuống lần đầu
			room.emit("creature.landed", e["owner"], {"creature_uid": e["uid"], "surface": "ground", "position": [np.x, np.y, np.z]})
		else:
			e["vel"] = v
		e["pos"] = np
		return
	if e.get("reserved", "") != "":
		return
	if ko:
		if now >= int(e["wake_tick"]):
			e["state"] = "landed"
			e["hp"] = e["max_hp"]
			e["hits"] = []
			e["air_hits"] = 0
			e.erase("value")
			room.emit("creature.woke_up", e["owner"], {"creature_uid": e["uid"]})
		elif now >= int(e["wake_tick"]) - room.secs(float(ContentDB.balance["creature"]["ko_blink_before_wake_s"])):
			e["state"] = "stunned_waking"
		return
	# hành vi trên bờ
	if now < int(e.get("idle_until", 0)):
		return
	var beh: Dictionary = cre["behavior"]
	var pos: Vector3 = e["pos"]
	var to_water := IslandLayout.toward_water(isl, pos.x, pos.z)
	var target := _nearest_player(room, pos, 8.0)
	match String(cre["archetype"]):
		"hopper":
			if now >= int(e["next_act"]):
				_hop(e, Vector3(to_water.x, 0, to_water.y) * 1.3 + Vector3(0, float(beh["hop_impulse"]) * 1.4, 0))
				e["next_act"] = now + room.secs(room.rng.randf_range(float(beh["hop_interval_s"]["min"]), float(beh["hop_interval_s"]["max"])))
		"runner":
			_walk(room, e, to_water, float(beh["run_speed_mps"]), dt)
			if now >= int(e["next_act"]):
				_hop(e, Vector3(to_water.x, 0, to_water.y) * 0.8 + Vector3(0, float(beh["flop_impulse"]) * 1.5, 0))
				e["next_act"] = now + room.secs(room.rng.randf_range(float(beh["flop_interval_s"]["min"]), float(beh["flop_interval_s"]["max"])) * 2.0)
		"flopper":
			if now >= int(e["next_act"]):
				var ang: float = room.rng.randf_range(-0.9, 0.9)
				var d := to_water.rotated(ang)
				_hop(e, Vector3(d.x, 0, d.y) * 0.9 + Vector3(0, float(beh["flop_impulse"]) * 1.6, 0))
				e["next_act"] = now + room.secs(room.rng.randf_range(float(beh["flop_interval_s"]["min"]), float(beh["flop_interval_s"]["max"])))
		"pincher":
			if not target.is_empty():
				var tp: Vector3 = target["pos"]
				var d2 := Vector2(tp.x - pos.x, tp.z - pos.z)
				if d2.length() > float(cre["attack"]["range_m"]) * 0.8:
					_walk(room, e, d2.normalized(), float(beh["chase_speed_mps"]), dt)
				_attack(room, e, cre, target, now)
			else:
				_walk(room, e, to_water, float(beh["chase_speed_mps"]) * 0.7, dt)
		"biter":
			if not target.is_empty():
				var tp2: Vector3 = target["pos"]
				var d3 := Vector2(tp2.x - pos.x, tp2.z - pos.z)
				if now >= int(e["next_act"]) and d3.length() > float(cre["attack"]["range_m"]):
					var n := d3.normalized()
					_hop(e, Vector3(n.x, 0, n.y) * float(beh["lunge_impulse"]) + Vector3(0, 1.8, 0))
					e["next_act"] = now + room.secs(room.rng.randf_range(float(beh["lunge_interval_s"]["min"]), float(beh["lunge_interval_s"]["max"])))
				_attack(room, e, cre, target, now)
			elif now >= int(e["next_act"]):
				_hop(e, Vector3(to_water.x, 0, to_water.y) * 1.0 + Vector3(0, float(beh["flop_impulse"]) * 1.4, 0))
				e["next_act"] = now + room.secs(room.rng.randf_range(float(beh["flop_interval_s"]["min"]), float(beh["flop_interval_s"]["max"])))
	var p2: Vector3 = e["pos"]
	if IslandLayout.is_water(isl, p2.x, p2.z):
		_escape(room, e, p2)


static func _hop(e: Dictionary, v: Vector3) -> void:
	e["vel"] = v
	e["flying"] = true
	e["state"] = "airborne"


static func _walk(room, e: Dictionary, dir: Vector2, speed: float, dt: float) -> void:
	var pos: Vector3 = e["pos"]
	var np := Vector2(pos.x, pos.z) + dir.normalized() * speed * dt
	e["pos"] = Vector3(np.x, IslandLayout.ground_height(room.island_id, np.x, np.y), np.y)
	e["yaw"] = atan2(-dir.x, -dir.y)


static func _nearest_player(room, pos: Vector3, max_d: float) -> Dictionary:
	var best := {}
	var bd := max_d
	for aid in room.players:
		var q: Dictionary = room.players[aid]
		if q["mode"] in ["disconnected", "knocked_out"]:
			continue
		var d: float = (q["pos"] as Vector3).distance_to(pos)
		if d < bd:
			bd = d
			best = q
	return best


static func _attack(room, e: Dictionary, cre: Dictionary, target: Dictionary, now: int) -> void:
	var atk: Dictionary = cre["attack"]
	var a: Dictionary = e["attack"]
	var d: float = (target["pos"] as Vector3).distance_to(e["pos"])
	if a.has("hit_tick"):
		if now >= int(a["hit_tick"]):
			var victim: Dictionary = room.players.get(a["target"], {})
			if not victim.is_empty() and (victim["pos"] as Vector3).distance_to(e["pos"]) <= float(atk["range_m"]) * 1.6 + 0.4:
				room.damage_player(victim, float(atk["damage"]), "creature")
				room.emit("creature.attacked_player", victim["account_id"], {"creature_uid": e["uid"], "damage": float(atk["damage"])})
			e["attack"] = {"ready": now + room.secs(float(atk["cooldown_s"]))}
		return
	if d <= float(atk["range_m"]) + 0.5 and now >= int(a.get("ready", 0)):
		e["attack"] = {"hit_tick": now + room.secs(float(atk["telegraph_s"])), "target": target["account_id"]}
		var p: Vector3 = e["pos"]
		room.emit("creature.attack_started", e["owner"], {"creature_uid": e["uid"], "position": [p.x, p.y, p.z]})


static func _escape(room, e: Dictionary, pos: Vector3) -> void:
	room.entities.erase(e["uid"])
	room.emit("creature.returned_to_water", e["owner"], {"creature_uid": e["uid"], "creature_def_id": e["def_id"], "position": [pos.x, pos.y, pos.z]})


# ------------------------------------------------------------------ công cụ

static func use_tool(room, p: Dictionary, target_uid: String) -> String:
	var inv: Dictionary = p["save"]["inventory"]
	var tool_id: String = p.get("equipped", inv["equipped_id"])
	if not tool_id.begins_with("tool_") or tool_id not in inv["tools_owned"]:
		return "ITEM_NOT_OWNED"
	var tool: Dictionary = ContentDB.tools[tool_id]
	var now: int = room.tick_count
	if now < int(p["cooldowns"].get(tool_id, 0)):
		return "COOLDOWN"
	var target: Dictionary = room.entities.get(target_uid, {})
	var is_boss := false
	if target.is_empty():
		return "OUT_OF_RANGE"
	if target["kind"] == "boss":
		is_boss = true
	elif target["kind"] != "fish":
		return "INVALID_PAYLOAD"
	var eye: Vector3 = Movement.eye(p["pos"])
	var tpos: Vector3 = target["pos"] + Vector3(0, 0.15, 0)
	var dist := eye.distance_to(tpos)
	var reach := float(tool["range_m"]) + (1.4 if is_boss else 0.5) + 0.6
	if dist > reach:
		return "OUT_OF_RANGE"
	var look := Movement.look_dir(p["yaw"], p["pitch"])
	var ang := rad_to_deg(look.angle_to((tpos - eye).normalized()))
	var kind: String = tool["kind"]
	var allowed := (float(tool.get("arc_deg", 60)) * 0.5 + 25.0) if kind == "melee" else (float(ContentDB.balance["aim_assist"]["cone_deg"]) + 14.0)
	if dist > 1.2 and ang > allowed:
		return "OUT_OF_RANGE"
	# đạn/ammo
	if tool.has("ammo"):
		var ammo: Dictionary = tool["ammo"]
		match String(ammo["recover"]):
			"pickup":
				var back: Array = p["slipper_back"]
				back = back.filter(func(t): return t > now)
				p["slipper_back"] = back
				if back.size() >= int(ammo["max"]):
					return "COOLDOWN"
			"buy":
				if int(inv.get("tool_ammo", {}).get(tool_id, 0)) <= 0:
					return "ITEM_NOT_OWNED"
	p["cooldowns"][tool_id] = now + room.secs(float(tool["cooldown_s"]))
	var travel := 0.0
	if kind in ["throwable", "ranged", "explosive"]:
		travel = dist / float(tool.get("throw_speed_mps", 20.0))
	if kind == "explosive":
		travel = maxf(travel, float(tool.get("fuse_s", 0.0)))
	var spin_deg := _spin_deg(room, p)
	var hit = {"at": now + room.secs(travel), "attacker": p["account_id"], "target": target_uid, "tool": tool_id, "kind": kind,
		"distance": dist, "player_airborne": not p["on_ground"], "spin_deg": spin_deg, "eye": eye, "look": look,
		"origin_tick": now}
	if kind == "throwable":
		(p["slipper_back"] as Array).append(now + room.secs(travel * 2.0 + 0.5))
	if kind == "explosive":
		_consume_ammo(room, p, tool_id, hit)
	elif travel <= 0.0:
		_apply_hit(room, hit)
	else:
		room.pending_hits.append(hit)
	room.emit("tool.used", p["account_id"], {"tool_id": tool_id, "position": [eye.x, eye.y, eye.z]})
	return ""


static func _consume_ammo(room, p: Dictionary, tool_id: String, hit: Dictionary) -> void:
	var r: Dictionary = await room.server_op(p, "tool.consume_ammo", {"tool_id": tool_id})
	if r["status"] != "committed":
		return
	room.pending_hits.append(hit)


static func _spin_deg(room, p: Dictionary) -> float:
	var hist: Array = p["yaw_hist"]
	var total := 0.0
	for i in range(1, hist.size()):
		total += angle_difference(float(hist[i - 1][1]), float(hist[i][1]))
	return absf(rad_to_deg(total))


static func _apply_hit(room, h: Dictionary) -> void:
	var tool: Dictionary = ContentDB.tools[h["tool"]]
	if h["kind"] == "explosive":
		var center: Vector3 = room.entities.get(h["target"], {}).get("pos", Vector3.INF)
		if center == Vector3.INF:
			return
		for uid in room.entities.keys():
			var e: Dictionary = room.entities.get(uid, {})
			if e.is_empty() or e["kind"] not in ["fish", "boss"]:
				continue
			if (e["pos"] as Vector3).distance_to(center) <= float(tool["radius_m"]) + (1.0 if e["kind"] == "boss" else 0.0):
				var hh := h.duplicate()
				hh["target"] = uid
				_hit_one(room, hh, tool)
		return
	_hit_one(room, h, tool)


static func _hit_one(room, h: Dictionary, tool: Dictionary) -> void:
	var e: Dictionary = room.entities.get(h["target"], {})
	if e.is_empty():
		return
	var attacker: Dictionary = room.players.get(h["attacker"], {})
	if e["kind"] == "boss":
		Boss.damage(room, attacker, float(tool["damage"]), h["tool"])
		return
	if e.get("reserved", "") != "" or e["state"] == "stolen":
		return
	var airborne: bool = e.get("flying", false)
	var zone := _hit_zone(e, h)
	var pos: Vector3 = e["pos"]
	room.emit("tool.hit", h["attacker"], {"tool_id": h["tool"], "target_uid": e["uid"], "hit_zone": zone, "position": [pos.x, pos.y, pos.z]})
	# đẩy lùi / hất lên (hài), kể cả cá đã xỉu
	var push := Vector3(pos.x, 0, pos.z) - Vector3(h["eye"].x, 0, h["eye"].z)
	push = push.normalized() if push.length() > 0.01 else Vector3(0, 0, 1)
	var kb := float(tool.get("knockback", 1.0))
	var up := float(tool.get("launch_up", 0.0))
	var knockup_min := float(ContentDB.balance["creature"]["knockup_min_mps"])
	if up > 0.0 or airborne:
		var v: Vector3 = e.get("vel", Vector3.ZERO)
		e["vel"] = Vector3(push.x * kb * 0.6, maxf(maxf(v.y, 0.0) + up * 0.6, knockup_min if up > 0.0 else v.y), push.z * kb * 0.6)
		var probe := Vector2(pos.x, pos.z) + Vector2(e["vel"].x, e["vel"].z) * 0.8
		if not _safe_ground(room.island_id, probe):
			e["vel"] = Vector3(0.0, e["vel"].y, 0.0)
		e["flying"] = true
		if e["state"] == "landed":
			e["state"] = "airborne"
	else:
		var np := Vector2(pos.x, pos.z) + Vector2(push.x, push.z) * kb * 0.15
		if _safe_ground(room.island_id, np) or not (e["state"] in ["stunned", "stunned_waking"]):
			e["pos"] = Vector3(np.x, IslandLayout.ground_height(room.island_id, np.x, np.y), np.y)
	if e["state"] in ["stunned", "stunned_waking"]:
		return
	var dmg := float(tool["damage"])
	e["hp"] = float(e["hp"]) - dmg
	if airborne:
		e["air_hits"] = int(e["air_hits"]) + 1
	(e["hits"] as Array).append({"tick": room.tick_count, "attacker": h["attacker"], "tool": h["tool"], "kind": h["kind"], "airborne": airborne,
		"zone": zone, "distance": h["distance"], "player_airborne": h["player_airborne"], "spin_deg": h["spin_deg"]})
	room.emit("creature.damaged", h["attacker"], {"creature_uid": e["uid"], "amount": dmg, "tool_id": h["tool"], "hit_zone": zone, "airborne": airborne, "position": [pos.x, pos.y, pos.z]})
	if tool.has("stun_s"):
		e["next_act"] = room.tick_count + room.secs(float(tool["stun_s"]))
	if float(e["hp"]) <= 0.0:
		_knock_out(room, e, h)


static func _hit_zone(e: Dictionary, h: Dictionary) -> String:
	var cre: Dictionary = ContentDB.creatures[e["def_id"]]
	var half := float(cre["length_m"]) * 0.5
	var fwd := Vector3(-sin(float(e["yaw"])), 0, -cos(float(e["yaw"])))
	var head: Vector3 = e["pos"] + fwd * half * 0.7 + Vector3(0, 0.1, 0)
	var tail: Vector3 = e["pos"] - fwd * half * 0.7 + Vector3(0, 0.1, 0)
	var eye: Vector3 = h["eye"]
	var look: Vector3 = h["look"]
	var dh := _ray_point_dist(eye, look, head)
	var dt2 := _ray_point_dist(eye, look, tail)
	return "head" if dh + 0.02 < dt2 and dh < maxf(0.25, half) else "body"


static func _ray_point_dist(o: Vector3, d: Vector3, p: Vector3) -> float:
	var t := maxf(0.0, (p - o).dot(d))
	return (o + d * t).distance_to(p)


static func _knock_out(room, e: Dictionary, h: Dictionary) -> void:
	var cre: Dictionary = ContentDB.creatures[e["def_id"]]
	var tricks := evaluate_tricks(room, e, h)
	var milli := 1000
	var cap := int(round(float(ContentDB.balance["scoring"]["max_total_multiplier"]) * 1000))
	for t in tricks:
		milli = milli * int(round(float(ContentDB.tricks[t]["multiplier"]) * 1000)) / 1000
	milli = clampi(milli, 1000, cap)
	var base := int(cre["base_value"])
	if e.get("variant") != null:
		for v in cre.get("variants", []):
			if v["variant_id"] == e["variant"]:
				base *= int(v["value_mult"])
	var total := base * milli / 1000
	e["value"] = {"trick_mult_milli": milli, "tricks": tricks, "total": total, "base": base}
	e["state"] = "stunned"
	e["ko_tool"] = h["tool"]
	e["ground_tick"] = room.tick_count
	e["wake_tick"] = room.tick_count + room.secs(float(cre["ko_duration_s"]))
	var att: Dictionary = room.players.get(h["attacker"], {})
	if not att.is_empty():
		att["last_ko_tick"] = room.tick_count
	room.emit("creature.knocked_out", e["owner"], room._ko_payload(e))
	room.emit("scoring.tricks_awarded", e["owner"], {"creature_uid": e["uid"], "creature_def_id": e["def_id"], "tricks": tricks,
		"total_multiplier": float(milli) / 1000.0, "value": total})


## Điều kiện trick theo tricks.json; đánh giá trên cú đánh KO và lịch sử cú đánh của con cá.
static func evaluate_tricks(room, e: Dictionary, h: Dictionary) -> Array:
	var hits: Array = e["hits"]
	var last: Dictionary = hits[-1] if not hits.is_empty() else {}
	var att: Dictionary = room.players.get(h["attacker"], {})
	var ctx := {
		"creature_airborne": bool(last.get("airborne", false)),
		"air_hits": int(e["air_hits"]),
		"hits": hits.size(),
		"zone": String(last.get("zone", "body")),
		"tool_kind": String(h["kind"]),
		"distance": float(h["distance"]),
		"spin": float(h["spin_deg"]),
		"perfect": bool(e.get("perfect", false)),
		"player_airborne": bool(h["player_airborne"]),
		"since_last_ko": (room.tick_count - int(att.get("last_ko_tick", -100000))) * room.dt if not att.is_empty() else 999.0,
	}
	var out: Array = []
	for tid in ContentDB.trick_order:
		if _cond(ContentDB.tricks[tid]["condition"], ctx):
			out.append(tid)
	return out


static func _cond(c: Dictionary, x: Dictionary) -> bool:
	match String(c["type"]):
		"creature_airborne": return x["creature_airborne"]
		"creature_air_hits_min": return x["air_hits"] >= int(c["value"])
		"hits_to_ko_max": return x["hits"] <= int(c["value"])
		"hit_zone": return x["zone"] == c["value"]
		"tool_kind": return x["tool_kind"] == c["value"]
		"distance_min": return x["distance"] >= float(c["value"])
		"distance_max": return x["distance"] <= float(c["value"]) + 0.9  # đo từ mắt, cộng chiều cao mắt
		"yaw_rotation_min": return x["spin"] >= float(c["value"])
		"perfect_yank": return x["perfect"]
		"player_airborne": return x["player_airborne"]
		"chain_window_max": return x["since_last_ko"] <= float(c["value"])
		"all_of":
			for sub in c["conditions"]:
				if not _cond(sub, x):
					return false
			return true
	return false


static func instance_value(it: Dictionary) -> int:
	return int(it["base_value"]) * int(it["trick_mult_milli"]) / 1000
