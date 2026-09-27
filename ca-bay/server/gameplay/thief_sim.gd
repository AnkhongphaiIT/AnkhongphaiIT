extends RefCounted
## Cò rình (thief trong balance.json): báo trước, xua được khi đứng gần, không lấy đồ nhiệm vụ,
## đồ bị lấy nằm ở tổ và chủ vẫn nhặt lại được (không mất vĩnh viễn).


static func tick(room) -> void:
	var cfg: Dictionary = ContentDB.balance["thief"]
	var now: int = room.tick_count
	var st: Dictionary = room.thief_state
	if st.is_empty():
		room.thief_state = {"cooldown_until": now + room.secs(float(cfg["cooldown_s"]))}
		return
	if st.has("bird"):
		_tick_bird(room, st, cfg, now)
		return
	if now < int(st["cooldown_until"]):
		return
	var best: Dictionary = {}
	for uid in room.entities:
		var e: Dictionary = room.entities[uid]
		if e.get("reserved", "") != "":
			continue
		var since := -1
		var value := 0
		if e["kind"] == "fish" and e["state"] == "stunned" and e.has("value"):
			since = int(e.get("ground_tick", now))
			value = int(e["value"]["total"])
		elif e["kind"] == "item" and e["state"] == "item":
			var flags: Array = e.get("instance", {}).get("flags", [])
			var def_flags: Array = ContentDB.items.get(e["def_id"], {}).get("flags", [])
			if "no_steal" in flags or "no_steal" in def_flags or "quest" in def_flags:
				continue
			since = int(e.get("ground_tick", now))
			value = int(e["value"]["total"]) if e.has("value") else 0
		else:
			continue
		if value < int(cfg["min_item_value"]) or since < 0 or (now - since) * room.dt < float(cfg["steal_delay_s"]):
			continue
		if best.is_empty() or since < int(best["since"]):
			best = {"uid": uid, "since": since}
	if best.is_empty():
		return
	var nest = IslandLayout.v3(room.island_id, IslandLayout.layout(room.island_id)["nest"], 6.0)
	var buid := Protocol.uuid4()
	room.entities[buid] = {"uid": buid, "kind": "prop", "def_id": "thief_bird", "state": "approach", "pos": nest, "yaw": 0.0}
	var target: Dictionary = room.entities[best["uid"]]
	st["bird"] = buid
	st["target"] = best["uid"]
	st["from"] = nest
	st["t0"] = now
	st["arrive"] = now + room.secs(float(cfg["warning_s"]))
	var tp: Vector3 = target["pos"]
	room.emit("thief.approach_warning", target.get("owner", null), {"item_uid": best["uid"], "position": [tp.x, tp.y, tp.z]})


static func _tick_bird(room, st: Dictionary, cfg: Dictionary, now: int) -> void:
	var bird: Dictionary = room.entities.get(st["bird"], {})
	var target: Dictionary = room.entities.get(st["target"], {})
	if bird.is_empty():
		room.thief_state = {"cooldown_until": now + room.secs(float(cfg["cooldown_s"]))}
		return
	if st.get("leaving", false):
		bird["pos"] = (bird["pos"] as Vector3) + Vector3(0, 5.0 * room.dt, 0)
		if now >= int(st["leave_until"]):
			room.entities.erase(st["bird"])
			room.thief_state = {"cooldown_until": now + room.secs(float(cfg["cooldown_s"]))}
		return
	if target.is_empty() or target.get("reserved", "") != "" or (target["kind"] == "fish" and target["state"] not in ["stunned", "stunned_waking"]):
		_leave(room, st, bird, now)
		return
	var tp: Vector3 = target["pos"]
	var t := clampf(float(now - int(st["t0"])) / maxf(1.0, float(int(st["arrive"]) - int(st["t0"]))), 0.0, 1.0)
	bird["pos"] = (st["from"] as Vector3).lerp(tp + Vector3(0, 0.6, 0), t)
	if now < int(st["arrive"]):
		return
	for aid in room.players:
		var q: Dictionary = room.players[aid]
		if q["mode"] == "disconnected":
			continue
		if (q["pos"] as Vector3).distance_to(tp) <= float(cfg["shoo_radius_m"]):
			room.emit("thief.shooed", aid, {"position": [tp.x, tp.y, tp.z]})
			_leave(room, st, bird, now)
			return
	var nest = IslandLayout.v3(room.island_id, IslandLayout.layout(room.island_id)["nest"], 0.2)
	target["pos"] = nest
	if target["kind"] == "fish":
		target["state"] = "stolen"
	target["ground_tick"] = now
	room.emit("thief.item_stolen", target.get("owner", null), {"item_uid": st["target"]})
	room.emit("thief.item_dropped", target.get("owner", null), {"item_uid": st["target"], "position": [nest.x, nest.y, nest.z]})
	_leave(room, st, bird, now)


static func _leave(room, st: Dictionary, bird: Dictionary, now: int) -> void:
	st["leaving"] = true
	st["leave_until"] = now + room.secs(2.0)
	bird["state"] = "leave"
