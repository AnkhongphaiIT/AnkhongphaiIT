extends RefCounted
## Máy trạng thái cần câu authoritative (07 §6.1):
## IDLE → CHARGING → CASTING → WAITING → BITING → REELING → LAUNCHED → IDLE; mọi hủy đi qua cancel() một lần.
## Server giữ thời điểm cắn, strain, loài; client chỉ báo giữ/thả/giật/kéo.

const Creatures := preload("res://server/gameplay/creature_sim.gd")


static func fb() -> Dictionary:
	return ContentDB.balance["fishing"]


static func equipped_rod(p: Dictionary) -> Dictionary:
	var inv: Dictionary = p["save"]["inventory"]
	return ContentDB.rods.get(inv["equipped_rod_id"], ContentDB.rods["rod_bamboo"])


static func on_action(room, p: Dictionary, action: String, aim: Vector3) -> String:
	var f: Dictionary = p["fishing"]
	var inv: Dictionary = p["save"]["inventory"]
	match action:
		"charge_start":
			if f["state"] != "IDLE":
				return "COOLDOWN"
			if not String(p.get("equipped", inv["equipped_id"])).begins_with("rod_"):
				return "ITEM_NOT_OWNED"
			var bait: Dictionary = ContentDB.baits.get(inv["selected_bait_id"], {})
			if bait.has("summons_boss_id"):
				room.emit_to(p["account_id"], "ui.popup_requested", p["account_id"], {"kind": "warning", "text_key": "ui.popup.boss_bait_wrong_place", "args": {}})
				return "INVALID_PAYLOAD"
			p["fishing"] = {"state": "CHARGING", "start": room.tick_count}
			room.emit("fishing.cast_charge_started", p["account_id"], {"rod_id": inv["equipped_rod_id"]})
		"cast_release":
			if f["state"] != "CHARGING":
				return "COOLDOWN"
			var rod := equipped_rod(p)
			var ratio = clampf((room.tick_count - int(f["start"])) * room.dt / float(rod["charge_time_s"]), 0.0, 1.0)
			var dir := Vector2(aim.x, aim.z)
			if dir.length() < 0.2:
				dir = Vector2(-sin(p["yaw"]), -cos(p["yaw"]))
			dir = dir.normalized()
			var facing := Vector2(-sin(p["yaw"]), -cos(p["yaw"]))
			if rad_to_deg(absf(dir.angle_to(facing))) > 40.0:
				dir = facing  # hướng quăng không tin client quá mức: bám theo hướng nhìn server biết
			var dist := lerpf(float(rod["cast_distance_m"]["min"]), float(rod["cast_distance_m"]["max"]), ratio)
			var from: Vector3 = Movement.eye(p["pos"])
			var target := Vector3(p["pos"].x + dir.x * dist, 0.0, p["pos"].z + dir.y * dist)
			target.y = maxf(IslandLayout.ground_height(room.island_id, target.x, target.z), IslandLayout.WATER_Y)
			var flight := 0.35 + dist * 0.04
			var uid := Protocol.uuid4()
			room.entities[uid] = {"uid": uid, "kind": "prop", "def_id": "lure", "state": "lure_s%d_flying" % int(p["slot"]),
				"pos": from, "yaw": 0.0, "owner": p["account_id"]}
			p["fishing"] = {"state": "CASTING", "lure": uid, "from": from, "to": target, "t0": room.tick_count, "t1": room.tick_count + room.secs(flight)}
			room.emit("fishing.cast_released", p["account_id"], {"rod_id": rod["id"], "charge_ratio": ratio, "target_point": [target.x, target.y, target.z]})
		"hook_set":
			match f["state"]:
				"BITING":
					var reaction = (room.tick_count - int(f["bite_tick"])) * room.dt
					_hook(room, p, reaction <= float(fb()["perfect_window_s"]), false, reaction)
				"WAITING":
					# giật sớm: cá hoảng, lùi thời điểm cắn (thân thiện, không mất mồi)
					f["bite_tick"] = int(f["bite_tick"]) + room.secs(1.0)
					f["nibbles"] = []
				_:
					return "COOLDOWN"
		"reel_start":
			if f["state"] == "REELING":
				if not f["reeling"]:
					f["reeling"] = true
					room.emit_to(p["account_id"], "fishing.reel_state_changed", p["account_id"], {"reeling": true})
			elif f["state"] in ["WAITING", "CASTING"]:
				cancel(room, p, "retracted")
		"reel_stop":
			if f["state"] == "REELING" and f["reeling"]:
				f["reeling"] = false
				room.emit_to(p["account_id"], "fishing.reel_state_changed", p["account_id"], {"reeling": false})
		"cancel":
			cancel(room, p, "player")
	return ""


static func cancel(room, p: Dictionary, reason: String) -> void:
	var f: Dictionary = p["fishing"]
	if f["state"] == "IDLE" or f["state"] == "LOCK":
		return
	if f.has("lure"):
		room.entities.erase(f["lure"])
	if f["state"] in ["BITING", "REELING"] and f.has("creature"):
		room.emit("fishing.escaped", p["account_id"], {"creature_def_id": f["creature"], "reason": reason, "position": _pos_arr(p["pos"])})
	room.emit("fishing.cancelled", p["account_id"], {"reason": reason})
	p["fishing"] = {"state": "IDLE"}


static func _pos_arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func tick_all(room) -> void:
	for aid in room.players:
		var p: Dictionary = room.players[aid]
		_tick(room, p)


static func _tick(room, p: Dictionary) -> void:
	var f: Dictionary = p["fishing"]
	var now: int = room.tick_count
	match f["state"]:
		"CASTING":
			var lure: Dictionary = room.entities.get(f["lure"], {})
			var t := clampf(float(now - int(f["t0"])) / maxf(1.0, float(int(f["t1"]) - int(f["t0"]))), 0.0, 1.0)
			var pos: Vector3 = (f["from"] as Vector3).lerp(f["to"], t)
			pos.y += sin(t * PI) * float(fb()["lure_apex_m"])
			if not lure.is_empty():
				lure["pos"] = pos
			if now >= int(f["t1"]):
				_land(room, p)
		"WAITING":
			var nib: Array = f["nibbles"]
			if not nib.is_empty() and now >= int(nib[0]):
				nib.pop_front()
				f["nibble_index"] = int(f.get("nibble_index", 0)) + 1
				room.emit("fishing.nibble", p["account_id"], {"index": f["nibble_index"], "position": _pos_arr(room.entities[f["lure"]]["pos"])})
			if now >= int(f["bite_tick"]):
				_bite(room, p)
			elif f.get("no_fish", false) and now >= int(f["retract_tick"]):
				cancel(room, p, "no_fish")
		"GROUND":
			if now >= int(f["retract_tick"]):
				cancel(room, p, "ground")
		"BITING":
			if now > int(f["window_end"]):
				var cre: Dictionary = ContentDB.creatures[f["creature"]]
				if int(cre["tier"]) == 0:
					_hook(room, p, false, true, float(fb()["hook_window_s"]))
				else:
					cancel(room, p, "missed")
		"REELING":
			_reel(room, p)
		"LOCK":
			if now >= int(f["until"]):
				p["fishing"] = {"state": "IDLE"}


static func _land(room, p: Dictionary) -> void:
	var f: Dictionary = p["fishing"]
	var to: Vector3 = f["to"]
	var lure: Dictionary = room.entities.get(f["lure"], {})
	if not IslandLayout.is_water(room.island_id, to.x, to.z):
		f["state"] = "GROUND"
		f["retract_tick"] = room.tick_count + room.secs(float(fb()["lure_ground_retract_s"]))
		if not lure.is_empty():
			lure["state"] = "lure_s%d_ground" % int(p["slot"])
		room.emit("fishing.lure_landed", p["account_id"], {"surface": "ground", "position": _pos_arr(to), "zone_id": null})
		return
	var zone = IslandLayout.zone_at(room.island_id, to.x, to.z)
	if not lure.is_empty():
		lure["pos"] = Vector3(to.x, IslandLayout.WATER_Y, to.z)
		lure["state"] = "lure_s%d_waiting" % int(p["slot"])
	room.emit("fishing.lure_landed", p["account_id"], {"surface": "water", "position": _pos_arr(to), "zone_id": zone.get("zone_id", null)})
	f["state"] = "WAITING"
	f["nibbles"] = []
	if zone.get("kind", "") != "fishing":
		f["no_fish"] = true
		f["bite_tick"] = 1 << 40
		f["retract_tick"] = room.tick_count + room.secs(2.0)
		room.emit_to(p["account_id"], "ui.popup_requested", p["account_id"], {"kind": "info", "text_key": "ui.popup.no_fish_here", "args": {}})
		return
	f["zone"] = zone["zone_id"]
	var zdef: Dictionary = ContentDB.island_zone(room.island_id, zone["zone_id"])
	var bait := _active_bait(p)
	var bite_s: float = room.rng.randf_range(float(bait["bite_time_s"]["min"]), float(bait["bite_time_s"]["max"])) * float(zdef.get("bite_time_mult", 1.0))
	f["bite_tick"] = room.tick_count + room.secs(bite_s)
	var n: int = room.rng.randi_range(0, int(fb()["max_nibbles"]))
	var last = int(f["bite_tick"]) - room.secs(float(fb()["nibble_before_bite_min_s"]))
	var nibs: Array = []
	for i in n:
		var tnib = last - room.secs(float(fb()["nibble_min_gap_s"])) * (n - 1 - i) - room.rng.randi_range(0, 6)
		if tnib > room.tick_count:
			nibs.append(tnib)
	nibs.sort()
	f["nibbles"] = nibs


static func _active_bait(p: Dictionary) -> Dictionary:
	var inv: Dictionary = p["save"]["inventory"]
	var b: Dictionary = ContentDB.baits.get(inv["selected_bait_id"], ContentDB.baits["bait_bread"])
	if not b.get("infinite", false) and int(inv["bait_counts"].get(b["id"], 0)) <= 0:
		return ContentDB.baits["bait_bread"]
	return b


static func _bite(room, p: Dictionary) -> void:
	var f: Dictionary = p["fishing"]
	var zdef: Dictionary = ContentDB.island_zone(room.island_id, f["zone"])
	var table: Dictionary = ContentDB.spawn_tables[zdef["spawn_table_id"]]
	var bait := _active_bait(p)
	var rod := equipped_rod(p)
	var entries: Array = []
	var total := 0
	for e in table["entries"]:
		if bait["id"] in e["bait_ids"] and int(e["min_rod_tier"]) <= int(rod["tier"]):
			entries.append(e)
			total += int(e["weight"])
	var chosen: String = table["fallback_creature_id"]
	if total > 0:
		var r: int = room.rng.randi_range(0, total - 1)
		var acc := 0
		for e in entries:
			acc += int(e["weight"])
			if r < acc:
				chosen = e["creature_id"]
				break
	var cre: Dictionary = ContentDB.creatures[chosen]
	var variant: Variant = null
	for v in cre.get("variants", []):
		if room.rng.randf() < float(v["chance"]):
			variant = v["variant_id"]
			break
	f["state"] = "BITING"
	f["creature"] = chosen
	f["variant"] = variant
	f["bait"] = bait["id"]
	f["bite_tick"] = room.tick_count
	f["window_end"] = room.tick_count + room.secs(float(fb()["hook_window_s"]))
	var lure: Dictionary = room.entities.get(f["lure"], {})
	if not lure.is_empty():
		lure["state"] = "lure_s%d_biting" % int(p["slot"])
	room.emit("fishing.bite", p["account_id"], {"creature_def_id": chosen, "variant_id": variant, "zone_id": f["zone"], "bait_id": bait["id"], "is_boss": false,
		"position": _pos_arr(lure.get("pos", p["pos"]))})


static func _hook(room, p: Dictionary, perfect: bool, auto: bool, reaction: float) -> void:
	var f: Dictionary = p["fishing"]
	var cre: Dictionary = ContentDB.creatures[f["creature"]]
	f["state"] = "REELING"
	f["perfect"] = perfect
	f["reeling"] = false
	f["strain"] = 0.0
	f["warned"] = false
	f["thrash_until"] = -1
	f["next_thrash"] = _next_thrash(room, cre)
	var lure: Dictionary = room.entities.get(f["lure"], {})
	if not lure.is_empty():
		lure["state"] = "lure_s%d_reeling" % int(p["slot"])
	room.emit("fishing.hook_set", p["account_id"], {"perfect": perfect, "auto": auto, "reaction_s": reaction})
	var bait: Dictionary = ContentDB.baits[f["bait"]]
	if not bait.get("infinite", false) and bait.get("consumed_on", "hook") == "hook":
		var lure_uid: String = f["lure"]
		var r: Dictionary = await room.server_op(p, "bait.consume", {"bait_id": bait["id"]})
		if r["status"] != "committed" and p["fishing"].get("lure", "") == lure_uid:
			cancel(room, p, "no_bait")


static func _next_thrash(room, cre: Dictionary) -> int:
	var rate := float(cre["thrash"]["rate_per_s"])
	if rate <= 0.0:
		return 1 << 40
	var interval = (1.0 / rate) * room.rng.randf_range(float(fb()["thrash_interval_factor_min"]), float(fb()["thrash_interval_factor_max"]))
	return room.tick_count + room.secs(interval)


static func _reel(room, p: Dictionary) -> void:
	var f: Dictionary = p["fishing"]
	var now: int = room.tick_count
	var cre: Dictionary = ContentDB.creatures[f["creature"]]
	var lure: Dictionary = room.entities.get(f["lure"], {})
	if lure.is_empty():
		cancel(room, p, "lost")
		return
	var rod := equipped_rod(p)
	var thrashing := now < int(f["thrash_until"])
	if not thrashing and now >= int(f["next_thrash"]):
		f["thrash_until"] = now + room.secs(float(cre["thrash"]["duration_s"]))
		f["next_thrash"] = int(f["thrash_until"]) + (_next_thrash(room, cre) - now)
		thrashing = true
		room.emit("fishing.thrash_started", p["account_id"], {"creature_def_id": f["creature"]})
		f["was_thrashing"] = true
	elif not thrashing and f.get("was_thrashing", false):
		f["was_thrashing"] = false
		room.emit("fishing.thrash_ended", p["account_id"], {"creature_def_id": f["creature"]})
	if f["reeling"] and thrashing:
		f["strain"] = float(f["strain"]) + float(cre["thrash"]["strain_gain_per_s"]) / float(rod["strain_resist"]) * room.dt
	else:
		f["strain"] = maxf(0.0, float(f["strain"]) - float(fb()["strain_decay_per_s"]) * room.dt)
	if float(f["strain"]) >= float(fb()["strain_warning_threshold"]) and not f["warned"]:
		f["warned"] = true
		room.emit_to(p["account_id"], "fishing.strain_warning", p["account_id"], {"strain": f["strain"]})
	elif float(f["strain"]) < float(fb()["strain_warning_threshold"]) * 0.7:
		f["warned"] = false
	if float(f["strain"]) >= 1.0:
		cancel(room, p, "line_snapped")
		return
	var ppos: Vector3 = p["pos"]
	var lp: Vector3 = lure["pos"]
	var to_player := Vector2(ppos.x - lp.x, ppos.z - lp.z)
	if to_player.length() > float(rod["max_line_length_m"]) + 3.0:
		cancel(room, p, "line_too_long")
		return
	if f["reeling"]:
		var speed: float = float(rod["reel_speed_mps"]) * room.reel_speed_mult(p) * (0.35 if thrashing else 1.0)
		var step = to_player.normalized() * speed * room.dt
		lp.x += step.x
		lp.z += step.y
	lure["pos"] = Vector3(lp.x, IslandLayout.WATER_Y, lp.z)
	if to_player.length() <= float(fb()["launch_trigger_distance_m"]) or not IslandLayout.is_water(room.island_id, lp.x, lp.z):
		room.entities.erase(f["lure"])
		var creature_id: String = f["creature"]
		var variant: Variant = f["variant"]
		var perfect: bool = f["perfect"]
		p["fishing"] = {"state": "LOCK", "until": now + room.secs(float(fb()["post_launch_lock_s"]))}
		Creatures.launch(room, p, creature_id, variant, perfect, Vector3(lp.x, IslandLayout.WATER_Y, lp.z))
