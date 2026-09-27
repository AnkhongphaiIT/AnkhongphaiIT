extends Node
## Chạy kịch bản nhiều bot qua protocol thật.
##   godot --headless --path . res://tests/bots/bot_runner.tscn -- --scenario=<tên> --bots=4 [--api=..] [--ws=..]
## In "BOTRESULT {json}" rồi thoát (0 = đạt).

const Bot := preload("res://tests/bots/bot.gd")

var bots: Array = []
var endpoints: Dictionary
var result := {"scenario": "", "ok": false, "checks": {}, "notes": []}


func _ready() -> void:
	var scenario := "connect4"
	var n := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):
			scenario = a.substr(11)
		elif a.begins_with("--bots="):
			n = int(a.substr(7))
	endpoints = Endpoints.load_endpoints()
	result["scenario"] = scenario
	get_tree().create_timer(600.0).timeout.connect(func(): _finish(false, "timeout toàn kịch bản"))
	for i in n:
		var b: Node = Bot.new(i, endpoints)
		add_child(b)
		bots.append(b)
	var ok := false
	match scenario:
		"connect4":
			ok = await sc_connect(n)
		"fish_loop":
			ok = await sc_connect(n) and await sc_fish_loop()
		"reconnect":
			ok = await sc_connect(n) and await sc_reconnect()
		"negative":
			ok = await sc_connect(1) and await sc_negative()
		"quest_boss":
			ok = await sc_connect(n) and await sc_quest_boss()
		_:
			result["notes"].append("không có kịch bản " + scenario)
	_finish(ok, "")


func check(name: String, cond: bool, detail: Variant = null) -> bool:
	result["checks"][name] = {"ok": cond, "detail": detail}
	print("CHECK %s %s %s" % ["PASS" if cond else "FAIL", name, "" if detail == null else str(detail)])
	return cond


func _finish(ok: bool, note: String) -> void:
	if note != "":
		result["notes"].append(note)
	result["ok"] = ok and result["checks"].values().all(func(c): return c["ok"])
	print("BOTRESULT " + JSON.stringify(result))
	get_tree().quit(0 if result["ok"] else 1)


# ------------------------------------------------------------------ kịch bản

func sc_connect(n: int) -> bool:
	for b in bots:
		if not await b.register_and_login():
			return check("register", false)
	if not await bots[0].create_room():
		return check("create_room", false)
	var code: String = bots[0].invite_code
	for i in range(1, n):
		var r: Dictionary = await bots[i].join_by_code(code)
		if not r["ok"]:
			return check("join_%d" % i, false, r["error_code"])
	for b in bots:
		if not await b.connect_room():
			return check("connect_bot%d" % b.index, false, b.closed_reason)
	var all_see: bool = await bots[0].wait_until(func():
		for b in bots:
			if b.snapshot.get("players", []).size() != n:
				return false
		return true, 10.0)
	check("all_bots_see_%d_players" % n, all_see, bots.map(func(b): return b.snapshot.get("players", []).size()))
	return all_see


func sc_fish_loop() -> bool:
	var done: Array = []
	for b in bots:
		done.append(false)
	# chạy song song: mỗi bot một coroutine; chờ tất cả
	for i in bots.size():
		_run_fish(bots[i], done, i)
	var ok: bool = await bots[0].wait_until(func(): return done.all(func(x): return typeof(x) == TYPE_DICTIONARY), 400.0)
	var sold := 0
	for i in bots.size():
		if done[i] is Dictionary and done[i].get("sold", false):
			sold += 1
	check("fish_loop_all_bots_sold", sold == bots.size(), done)
	# Mỗi bot thấy sự kiện câu của bot khác (đồng bộ room)
	var cross := true
	for b in bots:
		var actors := {}
		for e in b.events:
			if String(e["name"]).begins_with("fishing.") and e["actor_player_id"] != null:
				actors[e["actor_player_id"]] = true
		cross = cross and actors.size() >= bots.size()
	check("fishing_events_replicated_to_all", cross)
	return ok and sold == bots.size()


func _run_fish(b, done: Array, i: int) -> void:
	var r: Dictionary = await fish_catch_and_sell(b)
	done[i] = r


func fish_catch_and_sell(b) -> Dictionary:
	var out := {"sold": false}
	var isl: String = b.snapshot["island_id"]
	# quà dép của Cô Ba (gift lần đầu nói chuyện)
	var shop := IslandLayout.shop_zone(isl)
	var npc_pos := IslandLayout.npc_position(isl, "npc_co_ba")
	await b.walk_to(npc_pos + Vector3(0, 0, 1.5), 0.8)
	b.command("npc.interact", {"npc_id": "npc_co_ba"})
	await b.wait_until(func(): return "tool_slipper" in b.save["inventory"]["tools_owned"], 8.0)
	out["got_slipper"] = "tool_slipper" in b.save["inventory"]["tools_owned"]
	var pier: Dictionary = IslandLayout.layout(isl)["pier"]
	var end: Vector2 = pier["to"]
	var root2: Vector2 = pier["from"]
	var stand := IslandLayout.v3(isl, end - Vector2(0, 2.0) + Vector2(-1.1 + 0.73 * b.index, 0))
	await b.walk_to(IslandLayout.v3(isl, root2 - Vector2(0, 3.0)), 0.6)
	await b.walk_to(IslandLayout.v3(isl, root2 + Vector2(-1.1 + 0.73 * b.index, 1.0)), 0.4)
	await b.walk_to(stand, 0.35)
	var start_money: int = int(b.save["currencies"]["money"])
	for attempt in 8:
		if b.my_pos().distance_to(stand) > 1.0:
			await b.walk_to(IslandLayout.v3(isl, root2 - Vector2(0, 3.0)), 0.6)
			await b.walk_to(IslandLayout.v3(isl, root2 + Vector2(-1.1 + 0.73 * b.index, 1.0)), 0.4)
			await b.walk_to(stand, 0.35)
		var eq: Dictionary = await b.durable("equipment.equip", {"equipment_id": "rod_bamboo"})
		b.yaw = PI
		b.pitch = -0.1
		await b.get_tree().create_timer(0.2).timeout
		var ev_base: int = b.events.size()
		b.command("fishing.action", {"action": "charge_start", "aim_direction": [0, 0, 1]})
		await b.get_tree().create_timer(0.55).timeout
		b.command("fishing.action", {"action": "cast_release", "aim_direction": [0, 0, 1]})
		var bit: bool = await b.wait_until(func(): return not b.last_event("fishing.bite", b.api.account_id, ev_base).is_empty() or not b.last_event("fishing.cancelled", b.api.account_id, ev_base).is_empty(), 15.0)
		if not bit or b.last_event("fishing.bite", b.api.account_id, ev_base).is_empty():
			var mine: Array = []
			for k in range(ev_base, b.events.size()):
				if b.events[k]["actor_player_id"] == b.api.account_id:
					mine.append("%s %s" % [b.events[k]["name"], JSON.stringify(b.events[k]["event_payload"]).left(120)])
			b.say("không cắn (lần %d) pos=%s events=%s eq=%s" % [attempt, str(b.my_pos()), str(mine), str(eq.get("status", "")) + "/" + str(eq.get("error_code", ""))])
			continue
		await b.get_tree().create_timer(0.15).timeout
		b.command("fishing.action", {"action": "hook_set", "aim_direction": [0, 0, 1]})
		await b.wait_until(func(): return not b.last_event("fishing.hook_set", b.api.account_id, ev_base).is_empty() or not b.last_event("fishing.cancelled", b.api.account_id, ev_base).is_empty(), 3.0)
		if b.last_event("fishing.hook_set", b.api.account_id, ev_base).is_empty():
			continue
		out["perfect"] = b.last_event("fishing.hook_set", b.api.account_id, ev_base)["event_payload"]["perfect"]
		# kéo, thả tay khi cá quẫy
		var launched := false
		var t0 := Time.get_ticks_msec()
		b.command("fishing.action", {"action": "reel_start", "aim_direction": [0, 0, 1]})
		var reeling := true
		while Time.get_ticks_msec() - t0 < 25000:
			if not b.last_event("fishing.launched", b.api.account_id, ev_base).is_empty():
				launched = true
				break
			if not b.last_event("fishing.cancelled", b.api.account_id, ev_base).is_empty():
				break
			var th_s: Dictionary = b.last_event("fishing.thrash_started", b.api.account_id, ev_base)
			var th_e: Dictionary = b.last_event("fishing.thrash_ended", b.api.account_id, ev_base)
			var thrashing: bool = not th_s.is_empty() and (th_e.is_empty() or int(th_e["server_tick"]) < int(th_s["server_tick"]))
			if thrashing and reeling:
				b.command("fishing.action", {"action": "reel_stop", "aim_direction": [0, 0, 1]})
				reeling = false
			elif not thrashing and not reeling:
				b.command("fishing.action", {"action": "reel_start", "aim_direction": [0, 0, 1]})
				reeling = true
			await b.get_tree().process_frame
		if not launched:
			b.say("không giật lên được (lần %d)" % attempt)
			continue
		var cuid: String = b.last_event("fishing.launched", b.api.account_id, ev_base)["event_payload"]["creature_uid"]
		out["species"] = b.last_event("fishing.launched", b.api.account_id, ev_base)["event_payload"]["creature_def_id"]
		b.durable("equipment.equip", {"equipment_id": "tool_slipper"})
		var ko := false
		await b.wait_until(func(): return not b.entity(cuid).is_empty(), 2.0)
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 12000:
			var e: Dictionary = b.entity(cuid)
			if e.is_empty():
				break
			if String(e["state"]).begins_with("stunned"):
				ko = true
				break
			var ep := Vector3(e["position"][0], e["position"][1], e["position"][2])
			b.look_at_point(ep)
			await b.get_tree().create_timer(0.12).timeout
			var trid: String = b.command("tool.use", {"target_uid": cuid})
			await b.get_tree().create_timer(0.45).timeout
			if b.results.has(trid):
				b.say("tool.use bị từ chối: %s (khoảng cách %.1f)" % [b.results[trid]["error_code"], b.my_pos().distance_to(ep)])
		if not ko:
			var seq: Array = []
			for ev in b.events:
				if ev["event_payload"].get("creature_uid", "") == cuid or ev["event_payload"].get("target_uid", "") == cuid:
					seq.append("%s@%d" % [ev["name"], int(ev["server_tick"])])
			b.say("cá thoát trước khi xỉu (lần %d) %s" % [attempt, str(seq)])
			continue
		var ev_ko: Dictionary = b.last_event("scoring.tricks_awarded", b.api.account_id)
		out["tricks"] = ev_ko.get("event_payload", {}).get("tricks", [])
		var e2: Dictionary = b.entity(cuid)
		if e2.is_empty():
			continue
		await b.get_tree().create_timer(1.2).timeout  # chờ cá rơi xuống đất
		e2 = b.entity(cuid)
		if e2.is_empty():
			continue
		var fish_pos := Vector3(e2["position"][0], e2["position"][1], e2["position"][2])
		await b.walk_to(fish_pos, 1.0, 10.0)
		var pk: Dictionary = await b.durable("inventory.pickup", {"item_uid": cuid})
		if pk.get("error_code", "") == "OUT_OF_RANGE":
			b.say("nhặt xa: bot %s cá %s" % [str(b.my_pos()), str(fish_pos)])
		if pk.get("status", "") != "committed":
			b.say("nhặt lỗi %s" % pk.get("error_code"))
			continue
		out["picked"] = true
		await b.walk_to(IslandLayout.v3(isl, root2 + Vector2(0, 1.0)), 0.6, 30.0)
		await b.walk_to(IslandLayout.v3(isl, root2 - Vector2(0, 3.0)), 0.8, 20.0)
		await b.walk_to(IslandLayout.v3(isl, shop["pos"]) + Vector3(0, 0, 2.0), 1.0, 40.0)
		var bag: Array = b.save["inventory"]["bag"].map(func(it): return it["uid"])
		var sell: Dictionary = await b.durable("inventory.sell", {"item_uids": bag, "shop_id": shop["shop_id"]})
		out["sell"] = sell.get("status", "")
		out["money_delta"] = int(b.save["currencies"]["money"]) - start_money
		out["sold"] = sell.get("status", "") == "committed" and out["money_delta"] > 0
		return out
	return out


func sc_reconnect() -> bool:
	var b = bots[bots.size() - 1]
	var aid: String = b.api.account_id
	var before: int = int(b.save["save_version"])
	b.conn.disconnect_now()
	await b.get_tree().create_timer(2.0).timeout
	# người khác vẫn thấy slot (disconnected) trong grace
	var mode_seen := ""
	for pl in bots[0].snapshot["players"]:
		if pl["account_id"] == aid:
			mode_seen = pl["mode"]
	check("slot_kept_during_grace", mode_seen == "disconnected", mode_seen)
	b.snapshot = {}
	var ok: bool = await b.connect_room()
	check("reconnect_within_grace", ok)
	var back := false
	for pl in bots[0].snapshot.get("players", []):
		if pl["account_id"] == aid and pl["mode"] == "active":
			back = true
	await bots[0].wait_until(func():
		for pl in bots[0].snapshot.get("players", []):
			if pl["account_id"] == aid and pl["mode"] == "active":
				return true
		return false, 5.0)
	for pl in bots[0].snapshot.get("players", []):
		if pl["account_id"] == aid and pl["mode"] == "active":
			back = true
	check("others_see_player_back", back)
	return ok and back


func sc_negative() -> bool:
	var b = bots[0]
	var base_ok := true
	# payload sai kiểu / thừa trường / NaN / quá lớn / seq cũ → bị từ chối, server không sập
	var rid1: String = b.command("fishing.action", {"action": "charge_start", "aim_direction": [0, 0, 1], "extra": 1})
	await b.get_tree().create_timer(0.5).timeout
	base_ok = check("extra_field_rejected", b.results.get(rid1, {}).get("error_code", "") == "INVALID_PAYLOAD") and base_ok
	var env := Protocol.make_envelope("tool.use", {"target_uid": "not-a-uuid"}, b.conn.connection_id, b.conn.room_id, b.conn.seq + 1)
	b.conn.seq += 1
	b.conn.send_raw(JSON.stringify(env))
	await b.get_tree().create_timer(0.5).timeout
	base_ok = check("bad_uuid_rejected", b.results.get(env["request_id"], {}).get("error_code", "") == "INVALID_PAYLOAD") and base_ok
	var env2 := Protocol.make_envelope("player.input", {"move_x": 0, "move_z": 0, "look_yaw_rad": 0, "look_pitch_rad": 0, "jump": false}, b.conn.connection_id, b.conn.room_id, 1)
	b.conn.send_raw(JSON.stringify(env2))
	await b.get_tree().create_timer(0.5).timeout
	base_ok = check("stale_seq_rejected", b.results.get(env2["request_id"], {}).get("error_code", "") == "STALE_SEQUENCE") and base_ok
	var big := "x".repeat(9000)
	b.conn.send_raw(big)
	var env3 := Protocol.make_envelope("inventory.sell", {"op_id": Protocol.uuid4(), "expected_save_version": 1, "item_uids": [Protocol.uuid4()], "shop_id": "shop_co_ba", "money": 99999}, b.conn.connection_id, b.conn.room_id, b.conn.seq + 1)
	b.conn.seq += 1
	b.conn.send_raw(JSON.stringify(env3))
	await b.get_tree().create_timer(0.5).timeout
	base_ok = check("client_money_field_rejected", b.results.get(env3["request_id"], {}).get("error_code", "") == "INVALID_PAYLOAD") and base_ok
	var env4 := Protocol.make_envelope("tool.use", {"target_uid": Protocol.uuid4()}, b.conn.connection_id, "00000000-0000-4000-8000-000000000000", b.conn.seq + 1)
	b.conn.seq += 1
	b.conn.send_raw(JSON.stringify(env4))
	await b.get_tree().create_timer(0.5).timeout
	base_ok = check("wrong_room_rejected", b.results.get(env4["request_id"], {}).get("error_code", "") == "INVALID_PAYLOAD") and base_ok
	# lệnh bền vững giả mạo: nhặt cá không tồn tại / bán đồ không có
	var pk: Dictionary = await b.durable("inventory.pickup", {"item_uid": Protocol.uuid4()})
	base_ok = check("forged_pickup_rejected", pk.get("status", "") == "rejected", pk.get("error_code")) and base_ok
	var sl: Dictionary = await b.durable("inventory.sell", {"item_uids": [Protocol.uuid4()], "shop_id": "shop_co_ba"})
	base_ok = check("forged_sell_rejected", sl.get("status", "") == "rejected", sl.get("error_code")) and base_ok
	# vẫn chơi tiếp được sau khi bị từ chối
	base_ok = check("still_connected", b.conn.is_live()) and base_ok
	return base_ok


func sc_quest_boss() -> bool:
	return check("quest_boss_implemented", false, "chưa viết kịch bản")
