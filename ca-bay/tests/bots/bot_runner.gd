extends Node
## Chạy kịch bản nhiều bot qua protocol thật.
##   godot --headless --path . res://tests/bots/bot_runner.tscn -- --scenario=<tên> --bots=4 [--api=..] [--ws=..]
##       [--timeout=giây] [--from-island=1..3 --user=<tên> --password=<mk>]
## In "BOTRESULT {json}" rồi thoát (0 = đạt). Kịch bản cần điều phối bên ngoài (restart) in "BOTSIGNAL <tên>".

const Bot := preload("res://tests/bots/bot.gd")

var bots: Array = []
var endpoints: Dictionary
var result := {"scenario": "", "ok": false, "checks": {}, "notes": [], "timings": {}}
var opts := {"timeout": 600.0, "from_island": 1, "user": "", "password": ""}
var _t0 := 0
var _mark_t := 0
var _finished := false


func _ready() -> void:
	var scenario := "connect4"
	var n := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):
			scenario = a.substr(11)
		elif a.begins_with("--bots="):
			n = int(a.substr(7))
		elif a.begins_with("--timeout="):
			opts["timeout"] = float(a.substr(10))
		elif a.begins_with("--from-island="):
			opts["from_island"] = int(a.substr(14))
		elif a.begins_with("--user="):
			opts["user"] = a.substr(7)
		elif a.begins_with("--password="):
			opts["password"] = a.substr(11)
	endpoints = Endpoints.load_endpoints()
	result["scenario"] = scenario
	result["bots"] = n
	_t0 = Time.get_ticks_msec()
	_mark_t = _t0
	get_tree().create_timer(float(opts["timeout"])).timeout.connect(func(): _finish(false, "timeout toàn kịch bản (%ds)" % int(opts["timeout"])))
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
		"content_all":
			ok = await sc_content_all(n)
		"takeover":
			ok = await sc_takeover()
		"restart":
			ok = await sc_connect(1) and await sc_restart()
		"two_rooms":
			ok = await sc_two_rooms()
		_:
			result["notes"].append("không có kịch bản " + scenario)
	_finish(ok, "")


func mark(stage: String) -> void:
	var now := Time.get_ticks_msec()
	var dt := (now - _mark_t) / 1000.0
	result["timings"][stage] = snappedf(dt, 0.1)
	_mark_t = now
	print("TIMING %s %.1fs (tổng %.1fs)" % [stage, dt, (now - _t0) / 1000.0])


func note(msg: String) -> void:
	result["notes"].append(msg)
	print("NOTE " + msg)


func check(name: String, cond: bool, detail: Variant = null) -> bool:
	result["checks"][name] = {"ok": cond, "detail": detail}
	print("CHECK %s %s %s" % ["PASS" if cond else "FAIL", name, "" if detail == null else str(detail)])
	return cond


func _finish(ok: bool, why: String) -> void:
	if _finished:
		return
	_finished = true
	if why != "":
		result["notes"].append(why)
	result["timings"]["total"] = snappedf((Time.get_ticks_msec() - _t0) / 1000.0, 0.1)
	result["ok"] = ok and not result["checks"].is_empty() and result["checks"].values().all(func(c): return c["ok"])
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




# ================================================================== tiện ích nhiều bot

## Chạy fn(bot) song song cho các bot trong `group` (mặc định tất cả) rồi chờ xong. Trả kết quả theo thứ tự.
func all_bots(fn: Callable, timeout_s: float = 900.0, group: Array = []) -> Array:
	var g: Array = group if not group.is_empty() else bots
	var out: Array = []
	out.resize(g.size())
	var done := [0]
	for i in g.size():
		_run_one(fn, g[i], i, out, done)
	var t0 := Time.get_ticks_msec()
	while done[0] < g.size() and Time.get_ticks_msec() - t0 < timeout_s * 1000.0:
		await get_tree().process_frame
	return out


func _run_one(fn: Callable, b, i: int, out: Array, done: Array) -> void:
	out[i] = await fn.call(b)
	done[0] += 1


func _ok_all(arr: Array, key: String = "ok") -> bool:
	return arr.all(func(x): return typeof(x) == TYPE_DICTIONARY and bool(x.get(key, false)))


## Chuỗi nội dung của đảo thứ idx (0-based) đọc từ ContentDB, không chép số liệu vào test.
func island_info(idx: int) -> Dictionary:
	var isl: String = ContentDB.island_order[idx]
	var info := {"island": isl}
	for qid in ContentDB.quests:
		var q: Dictionary = ContentDB.quests[qid]
		var giver: String = q["giver_npc_id"]
		if ContentDB.npcs[giver]["island_id"] != isl:
			continue
		info["giver"] = giver
		var is_boss := false
		for st in q["steps"]:
			if st["type"] == "defeat_boss":
				is_boss = true
		if is_boss:
			info["boss_quest"] = qid
			for st in q["steps"]:
				if st["type"] == "defeat_boss":
					info["boss_id"] = st["target_id"]
				elif st["type"] == "deliver_item":
					info["boss_item"] = st["target_id"]
					info["boss_item_step"] = st["step_id"]
		else:
			info["prep_quest"] = qid
			for st in q["steps"]:
				if st["type"] == "deliver_creature":
					info["species"] = st["target_id"]
					info["count"] = int(st["count"])
					info["deliver_step"] = st["step_id"]
	if idx + 1 < ContentDB.island_order.size():
		info["next_island"] = ContentDB.island_order[idx + 1]
	return info


## So save trước/sau khi nhận thưởng nhiệm vụ với rewards trong quests.json (đúng một lần).
func reward_check(qid: String, before: Dictionary, after: Dictionary) -> Dictionary:
	var q: Dictionary = ContentDB.quests[qid]
	var errs: Array = []
	var want_money := 0
	for rw in q["rewards"]:
		match String(rw["type"]):
			"money":
				want_money += int(rw["amount"])
			"bait":
				var id: String = rw["id"]
				var d := int(after["inventory"]["bait_counts"].get(id, 0)) - int(before["inventory"]["bait_counts"].get(id, 0))
				if d != int(rw["amount"]):
					errs.append("mồi %s +%d (cần +%d)" % [id, d, int(rw["amount"])])
			"tool":
				if rw["id"] not in after["inventory"]["tools_owned"]:
					errs.append("thiếu công cụ %s" % rw["id"])
	var dm := int(after["currencies"]["money"]) - int(before["currencies"]["money"])
	if dm != want_money:
		errs.append("tiền +%d (cần +%d)" % [dm, want_money])
	var first: bool = qid not in before["lootbox_progress"]["quest_ticket_awarded_ids"]
	var want_t: int = int(ContentDB.lootboxes["earning"]["tickets_per_first_quest_completion"]) if first else 0
	var dt := int(after["currencies"]["festival_ticket"]) - int(before["currencies"]["festival_ticket"])
	if dt != want_t:
		errs.append("vé +%d (cần +%d)" % [dt, want_t])
	var st: Dictionary = after["progress"]["quests"].get(qid, {})
	if st.get("state", "") != "completed" or not st.get("reward_claimed", false):
		errs.append("trạng thái quest %s" % str(st))
	return {"ok": errs.is_empty(), "errors": errs, "money_delta": dm, "ticket_delta": dt}


func _count_items(sv: Dictionary, def_id: String) -> int:
	var n := 0
	for it in sv["inventory"]["bag"] + sv["inventory"]["recovery_inbox"]:
		if it["def_id"] == def_id:
			n += 1
	return n


# ================================================================== chặng một đảo

## Một bot: quà dép (đảo 1) → nhiệm vụ chuẩn bị (nhận/nói chuyện/câu đúng loài/giao/nhận thưởng) → nhận nhiệm vụ boss.
func island_prep(b, idx: int) -> Dictionary:
	var info := island_info(idx)
	var giver: String = info["giver"]
	var qa: String = info["prep_quest"]
	var out := {"ok": false, "bot": b.index, "casts": 0, "skipped": 0}
	var t0 := Time.get_ticks_msec()
	if idx == 0:
		await b.goto_npc("npc_co_ba")
		await b.talk("npc_co_ba")
		await b.wait_until(func(): return "tool_slipper" in b.save["inventory"]["tools_owned"], 5.0)
		out["slipper"] = "tool_slipper" in b.save["inventory"]["tools_owned"]
		if not out["slipper"]:
			out["error"] = "không nhận được dép Cô Ba"
			return out
	var st: Dictionary = b.quest_state(qa)
	if st.is_empty():
		out["error"] = "save không có %s" % qa
		return out
	if st["state"] == "available":
		await b.goto_npc(giver)
		var ra: Dictionary = await b.dur("quest.accept", {"quest_id": qa, "npc_id": giver})
		out["accept"] = ra.get("status", "")
		if ra.get("status", "") != "committed":
			out["error"] = "quest.accept %s: %s" % [qa, ra.get("error_code")]
			return out
	var q: Dictionary = ContentDB.quests[qa]
	if int(b.quest_state(qa)["step_index"]) == 0 and q["steps"][0]["type"] == "talk":
		await b.goto_npc(giver)
		var rt: Dictionary = await b.talk(giver)
		await b.wait_until(func(): return int(b.quest_state(qa)["step_index"]) >= 1, 5.0)
		out["talk"] = int(b.quest_state(qa)["step_index"]) >= 1
		if not out["talk"]:
			out["error"] = "nói chuyện %s không qua bước (%s/%s)" % [giver, str(rt.get("status")), str(rt.get("error_code"))]
			return out
	out["t_intro_s"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1)
	var species: String = info["species"]
	var step_id: String = info["deliver_step"]
	var guard := 0
	while b.quest_state(qa)["state"] == "active" and int(b.quest_state(qa)["step_index"]) < q["steps"].size():
		guard += 1
		if guard > 40:
			out["error"] = "quá nhiều vòng câu/giao"
			return out
		var need: int = int(info["count"]) - int(b.quest_state(qa)["counts"].get(step_id, 0))
		var have: Array = b.bag_of(species)
		if have.size() >= need or (b.bag_free() == 0 and have.size() > 0):
			await b.goto_npc(giver)
			var rd: Dictionary = await b.dur("quest.deliver", {"quest_id": qa, "step_id": step_id, "npc_id": giver, "item_uids": have.slice(0, need)})
			if rd.get("status", "") != "committed":
				out["error"] = "quest.deliver: %s" % str(rd.get("error_code"))
				return out
			out["deliveries"] = int(out.get("deliveries", 0)) + 1
			continue
		if b.bag_free() == 0:
			out["error"] = "túi đầy đồ khác loài"
			return out
		var c: Dictionary = await b.catch_one([species], 40)
		out["casts"] += int(c.get("casts", 0))
		out["skipped"] += int(c.get("skipped", 0))
		if not c["ok"]:
			out["error"] = "câu %s thất bại: %s" % [species, str(c.get("error", ""))]
			return out
	out["t_fish_s"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1)
	var before: Dictionary = await b.server_save()
	var rc: Dictionary = await b.dur("quest.claim", {"quest_id": qa})
	var after: Dictionary = await b.server_save()
	out["claim"] = rc.get("status", "")
	out["reward"] = reward_check(qa, before, after)
	var qb: String = info["boss_quest"]
	await b.wait_until(func(): return b.quest_state(qb).get("state", "") != "", 3.0)
	if b.quest_state(qb).get("state", "") == "available":
		var rb: Dictionary = await b.dur("quest.accept", {"quest_id": qb, "npc_id": giver})
		out["boss_quest_accept"] = rb.get("status", "")
	out["boss_quest_state"] = b.quest_state(qb).get("state", "")
	out["ok"] = out["claim"] == "committed" and out["reward"]["ok"] and out["boss_quest_state"] == "active"
	return out


## Cả nhóm tới cọc boss, bot0 gọi boss (mồi của bot0), mọi bot đánh tới khi thắng; boss trốn thì chờ hoàn mồi và gọi lại.
## Sau khi thắng kiểm từng người: tiền/rơi đồ/sự kiện thưởng đúng một lần. replay_checks: gửi lại cùng op_id của boss.summon.
func island_boss(idx: int, replay_checks: bool) -> bool:
	var info := island_info(idx)
	var isl: String = info["island"]
	var tag := "isl%d" % (idx + 1)
	var boss_id: String = info["boss_id"]
	var boss: Dictionary = ContentDB.bosses[boss_id]
	var bait: String = boss["summon"]["bait_id"]
	var spot := IslandLayout.boss_spot(isl)
	var post: Vector2 = spot["post"]
	var arena: Vector2 = spot["arena"]
	var dir := (arena - post).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var summoner = bots[0]
	var before: Array = await all_bots(func(b): return await b.server_save())
	var won := false
	var summon_op := {}
	var fights: Array = []
	var bases: Array = []
	var summoned: Dictionary = {}
	for attempt in 3:
		await all_bots(func(b): return await b.nav_to(post + dir * 2.0 + perp * (-1.5 + 1.0 * b.index), 0.6, 60.0))
		if int(summoner.save["inventory"]["bait_counts"].get(bait, 0)) <= 0:
			# hết mồi boss (trốn mà chưa kịp hoàn / đã dùng): xin lại ở người giao nhiệm vụ (quest.refill)
			await summoner.goto_npc(info["giver"])
			await summoner.talk(info["giver"])
			await summoner.wait_until(func(): return int(summoner.save["inventory"]["bait_counts"].get(bait, 0)) > 0, 5.0)
			note("%s: bot0 xin lại mồi %s ở %s → còn %d" % [tag, bait, info["giver"], int(summoner.save["inventory"]["bait_counts"].get(bait, 0))])
			await summoner.nav_to(post + dir * 2.0 + perp * -1.5, 0.6, 60.0)
		bases = bots.map(func(b): return b.events.size())
		var rs: Dictionary = await summoner.dur("boss.summon", {"boss_id": boss_id, "zone_id": spot["zone_id"]})
		if rs.get("status", "") != "committed":
			check("%s_boss_summon_committed" % tag, false, {"attempt": attempt, "status": rs.get("status"), "error": rs.get("error_code")})
			return false
		summon_op = {"op_id": rs["op_id_sent"], "esv": rs["esv_sent"], "encounter_id": (rs.get("receipt", {}) if typeof(rs.get("receipt")) == TYPE_DICTIONARY else {}).get("encounter_id", "")}
		await summoner.wait_until(func(): return not summoner.last_event("boss.summoned", "", bases[0]).is_empty(), 6.0)
		var ev: Dictionary = summoner.last_event("boss.summoned", "", bases[0])
		if ev.is_empty():
			check("%s_boss_summoned_event" % tag, false, "không có boss.summoned sau khi commit")
			return false
		summoned = ev["event_payload"]
		var uid: String = summoned["creature_uid"]
		var tmo := float(boss["escape_timer_s"]["solo"]) + 30.0
		fights = await all_bots(func(b): return await b.fight_boss(uid, bases[b.index], tmo), tmo + 30.0)
		var res_list: Array = fights.map(func(f): return f.get("result", "?") if typeof(f) == TYPE_DICTIONARY else "null")
		print("[boss] %s lần %d: %s" % [tag, attempt, JSON.stringify(fights)])
		if res_list.all(func(r): return r == "defeated"):
			won = true
			break
		note("%s: boss %s không hạ được ở lần %d: %s" % [tag, boss_id, attempt, str(res_list)])
		# chờ boss rời bãi và mồi được hoàn (boss.refund) rồi thử lại
		await summoner.wait_until(func(): return int(summoner.save["inventory"]["bait_counts"].get(bait, 0)) > 0, 10.0)
		await summoner.sleep(4.0)
	var n := bots.size()
	var cre: Dictionary = ContentDB.creatures[boss["creature_id"]]
	var want_hp := ceili(float(cre["hp"]) * (1.0 + float(boss["cooperative"]["hp_per_extra_player_mult"]) * (n - 1)))
	check("%s_boss_hp_scaled_for_%d" % [tag, n], int(summoned.get("hp", -1)) == want_hp, {"hp": summoned.get("hp"), "want": want_hp})
	check("%s_boss_defeated" % tag, won, fights)
	if not won:
		return false
	# thưởng riêng từng người, đúng một lần
	await all_bots(func(b): return await b.wait_until(func(): return boss_id in b.save["progress"]["bosses_defeated"], 10.0))
	await summoner.sleep(1.0)
	var after: Array = await all_bots(func(b): return await b.server_save())
	var all_ok := true
	for i in n:
		var b = bots[i]
		var bf: Dictionary = before[i]
		var af: Dictionary = after[i]
		var dm := int(af["currencies"]["money"]) - int(bf["currencies"]["money"])
		var drops := {}
		var drops_ok := true
		for d in boss["drops"]:
			var dn := _count_items(af, d["id"]) - _count_items(bf, d["id"])
			drops[d["id"]] = dn
			drops_ok = drops_ok and dn == int(d["count"])
		var reward_events := 0
		for e in b.events_named("boss.defeated", bases[i], b.api.account_id):
			if not e["event_payload"].has("time_s"):
				reward_events += 1
		var qst: Dictionary = af["progress"]["quests"].get(info["boss_quest"], {})
		var det := {"money_delta": dm, "want_money": int(boss["reward_base_value"]), "drops": drops, "reward_events": reward_events,
			"bosses_defeated": af["progress"]["bosses_defeated"], "quest_step": qst.get("step_index"),
			"hits": (fights[i] if typeof(fights[i]) == TYPE_DICTIONARY else {}).get("hits"), "ko": (fights[i] if typeof(fights[i]) == TYPE_DICTIONARY else {}).get("ko")}
		var ok_i: bool = dm == int(boss["reward_base_value"]) and drops_ok and reward_events == 1 and boss_id in af["progress"]["bosses_defeated"] \
			and int(qst.get("step_index", 0)) == 1
		all_ok = check("%s_bot%d_boss_reward_exactly_once" % [tag, i], ok_i, det) and all_ok
	if replay_checks:
		# Gửi lại đúng op boss.summon cũ (cùng op_id/expected_save_version) sau khi boss đã biến mất:
		# idempotency yêu cầu không gọi thêm trận, không trừ/hoàn mồi, không thưởng thêm.
		await summoner.wait_until(func():
			for e in summoner.snapshot.get("entities", []):
				if e["kind"] == "boss":
					return false
			return true, 10.0)
		var s_before: Dictionary = await summoner.server_save()
		var rb_base: int = summoner.events.size()
		var rr: Dictionary = await summoner.durable_raw("boss.summon", {"boss_id": boss_id, "zone_id": spot["zone_id"]}, summon_op["op_id"], summon_op["esv"])
		await summoner.sleep(3.0)
		var again: Array = summoner.events_named("boss.summoned", rb_base)
		var boss_ent := false
		for e in summoner.snapshot.get("entities", []):
			if e["kind"] == "boss":
				boss_ent = true
		var s_after: Dictionary = await summoner.server_save()
		check("%s_replay_summon_same_op_no_new_encounter" % tag, again.is_empty() and not boss_ent,
			{"replay_status": rr.get("status"), "replay_error": rr.get("error_code"), "boss_summoned_again": again.size(), "boss_entity": boss_ent,
			"encounter_id": summon_op["encounter_id"]})
		check("%s_replay_summon_no_state_change" % tag, int(s_after["save_version"]) == int(s_before["save_version"]) \
			and int(s_after["currencies"]["money"]) == int(s_before["currencies"]["money"]) \
			and int(s_after["inventory"]["bait_counts"].get(bait, 0)) == int(s_before["inventory"]["bait_counts"].get(bait, 0)),
			{"version": [s_before["save_version"], s_after["save_version"]], "money": [s_before["currencies"]["money"], s_after["currencies"]["money"]]})
		if not again.is_empty():
			# boss "ma" từ lần gửi lại: rời bãi để nó trốn (không được hoàn mồi lần hai)
			note("%s: gửi lại boss.summon cùng op_id đã gọi thêm một trận boss (encounter cũ) — lỗi idempotency sản phẩm" % tag)
	return all_ok


## Một bot: giao vật phẩm boss cho người giao nhiệm vụ, nhận thưởng, kiểm đảo kế tiếp được mở.
func island_finish(b, idx: int) -> Dictionary:
	var info := island_info(idx)
	var giver: String = info["giver"]
	var qb: String = info["boss_quest"]
	var out := {"ok": false, "bot": b.index}
	await b.goto_npc(giver)
	var uids: Array = b.bag_of(info["boss_item"])
	if uids.is_empty():
		out["error"] = "không có %s trong túi" % info["boss_item"]
		return out
	var ev_base: int = b.events.size()
	var rd: Dictionary = await b.dur("quest.deliver", {"quest_id": qb, "step_id": info["boss_item_step"], "npc_id": giver, "item_uids": [uids[0]]})
	out["deliver"] = rd.get("status", "")
	if rd.get("status", "") != "committed":
		out["error"] = "deliver: %s" % str(rd.get("error_code"))
		return out
	var before: Dictionary = await b.server_save()
	var rc: Dictionary = await b.dur("quest.claim", {"quest_id": qb})
	var after: Dictionary = await b.server_save()
	out["claim"] = rc.get("status", "")
	out["claim_op"] = {"op_id": rc.get("op_id_sent", ""), "esv": rc.get("esv_sent", 0)}
	out["reward"] = reward_check(qb, before, after)
	out["ok"] = out["claim"] == "committed" and out["reward"]["ok"]
	if info.has("next_island"):
		var nxt: String = info["next_island"]
		out["unlocked"] = nxt in after["progress"]["islands_unlocked"]
		var evs: Array = b.events_named("progress.island_unlocked", ev_base, b.api.account_id).filter(func(e): return e["event_payload"].get("island_id", "") == nxt)
		out["unlock_events"] = evs.size()
		out["ok"] = out["ok"] and out["unlocked"] and evs.size() == 1
	return out


## Cả phòng bỏ phiếu sang đảo mới; chờ mọi bot thấy snapshot ở đảo đó.
func travel_all(isl: String) -> bool:
	for b in bots:
		b.command("island.vote", {"island_id": isl, "approve": true})
		await b.sleep(0.2)
	return await bots[0].wait_until(func():
		for b in bots:
			if b.island() != isl:
				return false
		return true, 20.0)


# ================================================================== kịch bản nhiệm vụ / boss / nội dung

func sc_quest_boss() -> bool:
	mark("connect")
	var prep: Array = await all_bots(func(b): return await island_prep(b, 0))
	var prep_ok := true
	for i in prep.size():
		prep_ok = check("isl1_bot%d_prep_quest_and_reward" % i, typeof(prep[i]) == TYPE_DICTIONARY and prep[i].get("ok", false), prep[i]) and prep_ok
	mark("isl1_prep_quest")
	if not prep_ok:
		return false
	var boss_ok: bool = await island_boss(0, true)
	mark("isl1_boss")
	var fin: Array = await all_bots(func(b): return await island_finish(b, 0))
	var fin_ok := true
	for i in fin.size():
		fin_ok = check("isl1_bot%d_deliver_scale_unlock_isl2" % i, typeof(fin[i]) == TYPE_DICTIONARY and fin[i].get("ok", false), fin[i]) and fin_ok
	# gửi lại cùng op_id của quest.claim: không nhận thêm tiền/đổi save
	var replay_ok := true
	for i in bots.size():
		var b = bots[i]
		if typeof(fin[i]) != TYPE_DICTIONARY or fin[i].get("claim_op", {}).get("op_id", "") == "":
			continue
		var s0: Dictionary = await b.server_save()
		var ev_base: int = b.events.size()
		var rr: Dictionary = await b.durable_raw("quest.claim", {"quest_id": island_info(0)["boss_quest"]}, fin[i]["claim_op"]["op_id"], int(fin[i]["claim_op"]["esv"]))
		await b.sleep(0.5)
		var s1: Dictionary = await b.server_save()
		var same: bool = int(s1["currencies"]["money"]) == int(s0["currencies"]["money"]) and int(s1["save_version"]) == int(s0["save_version"]) \
			and int(s1["currencies"]["festival_ticket"]) == int(s0["currencies"]["festival_ticket"])
		replay_ok = check("isl1_bot%d_replay_claim_same_op_no_extra_reward" % i, same,
			{"replay_status": rr.get("status"), "money": [s0["currencies"]["money"], s1["currencies"]["money"]], "version": [s0["save_version"], s1["save_version"]]}) and replay_ok
		var dup_ev: int = b.events_named("quest.completed", ev_base, b.api.account_id).size() + b.events_named("economy.money_changed", ev_base, b.api.account_id).size()
		if dup_ev > 0:
			note("bot%d: gửi lại quest.claim (replayed) vẫn phát lại %d domain.event (quest.completed/economy.money_changed/...) dù save không đổi" % [i, dup_ev])
	mark("isl1_finish")
	return prep_ok and boss_ok and fin_ok and replay_ok


func sc_content_all(n: int) -> bool:
	var start_idx: int = clampi(int(opts["from_island"]) - 1, 0, ContentDB.island_order.size() - 1)
	if start_idx == 0 and String(opts["user"]) == "":
		if not await sc_connect(n):
			return false
	else:
		# Tiếp tục tài khoản của lần chạy trước (cùng DB): chỉ đăng nhập + tạo phòng ở đảo đã mở khóa. Không sửa save.
		if n != 1 or String(opts["user"]) == "":
			return check("from_island_requires_user", false, "--from-island>1 cần --user=/--password= của tài khoản đã qua các đảo trước, --bots=1")
		var b = bots[0]
		if not await b.login_as(String(opts["user"]), String(opts["password"])):
			return check("login_existing_account", false)
		var isl0: String = ContentDB.island_order[start_idx]
		if not check("from_island_unlocked_legitimately", isl0 in b.save["progress"]["islands_unlocked"], b.save["progress"]["islands_unlocked"]):
			return false
		var r: Dictionary = await b.api.create_room(isl0)
		if not r["ok"]:
			return check("create_room_on_%s" % isl0, false, r["error_code"])
		b.room_id = r["data"]["room_id"]
		b.invite_code = r["data"]["invite_code"]
		if not check("connect_existing_account", await b.connect_room()):
			return false
	print("CONTENT accounts %s" % str(bots.map(func(b): return b.username)))
	mark("connect")
	for idx in range(start_idx, ContentDB.island_order.size()):
		var tag := "isl%d" % (idx + 1)
		var prep: Array = await all_bots(func(b): return await island_prep(b, idx))
		var ok := true
		for i in prep.size():
			ok = check("%s_bot%d_prep_quest_and_reward" % [tag, i], typeof(prep[i]) == TYPE_DICTIONARY and prep[i].get("ok", false), prep[i]) and ok
		mark("%s_prep_quest" % tag)
		if not ok:
			return false
		if not await island_boss(idx, false):
			mark("%s_boss" % tag)
			return false
		mark("%s_boss" % tag)
		var fin: Array = await all_bots(func(b): return await island_finish(b, idx))
		for i in fin.size():
			ok = check("%s_bot%d_boss_quest_done" % [tag, i], typeof(fin[i]) == TYPE_DICTIONARY and fin[i].get("ok", false), fin[i]) and ok
		mark("%s_finish" % tag)
		if not ok:
			return false
		var info := island_info(idx)
		if info.has("next_island"):
			if not check("%s_travel_to_%s" % [tag, info["next_island"]], await travel_all(info["next_island"]), bots.map(func(b): return b.island())):
				return false
			mark("%s_travel" % tag)
		print("CONTENT xong đảo %d; tài khoản %s" % [idx + 1, str(bots.map(func(b): return b.username))])
	# tổng kết từ save server
	var all_ok := true
	for i in bots.size():
		var sv: Dictionary = await bots[i].server_save()
		var bosses_ok := true
		for bid in ContentDB.bosses:
			bosses_ok = bosses_ok and bid in sv["progress"]["bosses_defeated"]
		var quests_ok := true
		for qid in ContentDB.quests:
			quests_ok = quests_ok and sv["progress"]["quests"].get(qid, {}).get("state", "") == "completed"
		var normal := 0
		for cid in sv["collection"]["species"]:
			if not ContentDB.creatures[cid].get("is_boss", false):
				normal += 1
		all_ok = check("bot%d_all_bosses_quests_islands" % i, bosses_ok and quests_ok and sv["progress"]["islands_unlocked"].size() == ContentDB.island_order.size(),
			{"bosses": sv["progress"]["bosses_defeated"], "islands": sv["progress"]["islands_unlocked"], "money": sv["currencies"]["money"],
			"normal_species_caught": normal, "species": sv["collection"]["species"].keys()}) and all_ok
		var total_normal := 0
		for cid in ContentDB.creatures:
			if not ContentDB.creatures[cid].get("is_boss", false):
				total_normal += 1
		note("bot%d bắt %d/%d loài thường (CONTENT-01 đầy đủ còn yêu cầu đủ 15 loài; kịch bản này chỉ bắt loài nhiệm vụ)" % [i, normal, total_normal])
	return all_ok


# ================================================================== SAVE-02: chuyển phiên sang thiết bị khác

## bots[0] = thiết bị A, bots[1] = thiết bị B (cùng tài khoản). A đang chơi; B đăng nhập, bị chặn vé; A gửi lệnh bền vững X
## ngay trước takeover và Y ngay sau; B gọi POST /v1/account/takeover rồi vào phòng ngay. Kiểm: A nhận session.closed
## takeover, B không bị đá nhầm, Y (epoch cũ) không commit, gửi lại X cùng op_id ở B không nhân đôi, version cũ bị từ chối.
func sc_takeover() -> bool:
	if bots.size() < 2:
		return check("takeover_needs_2_bots", false, "--bots=2")
	var A = bots[0]
	var B = bots[1]
	if not await A.register_and_login() or not await A.create_room() or not await A.connect_room():
		return check("A_connect", false, A.closed_reason)
	mark("A_connect")
	await A.goto_shop()
	var shop := IslandLayout.shop_zone(A.island())
	var buy := {"shop_id": shop["shop_id"], "entry_id": "entry_rice_ball", "quantity": 1}
	if not await B.login_as(A.username, A.password):
		return check("B_login_same_account", false)
	B.room_id = A.room_id
	var t1: Dictionary = await B.api.ticket(B.room_id)
	check("B_ticket_blocked_while_A_plays", not t1["ok"] and t1["error_code"] == "LEASE_ACTIVE_ELSEWHERE", t1["error_code"])
	var s0: Dictionary = await B.server_save()
	var rice0 := int(s0["inventory"]["food_counts"].get("item_rice_ball", 0))
	# X: lệnh bền vững đang chờ khi takeover xảy ra
	var opX := Protocol.uuid4()
	var esvX: int = A.save_version
	var plX := buy.duplicate()
	plX["op_id"] = opX
	plX["expected_save_version"] = esvX
	var ridX: String = A.conn.send("shop.buy", plX)
	var tk: Dictionary = await B.api.takeover()
	check("takeover_api_ok", tk["ok"], tk["error_code"])
	# Y: A (epoch cũ) gửi sau khi backend đã thu hồi phiên
	var opY := Protocol.uuid4()
	var plY := buy.duplicate()
	plY["op_id"] = opY
	plY["expected_save_version"] = A.save_version
	var ridY: String = A.conn.send("shop.buy", plY)
	# B vào phòng ngay như người dùng bấm "chơi trên thiết bị này"
	var b_ok: bool = await B.connect_room()
	var b_live_at := Time.get_ticks_msec()
	check("B_connected_after_takeover", b_ok, B.closed_reason)
	await A.wait_until(func(): return "takeover" in A.session_closed, 8.0)
	check("A_received_session_closed_takeover", "takeover" in A.session_closed, {"A_session_closed": A.session_closed, "A_conn": A.conn.state})
	await A.wait_until(func(): return A.conn.state == "closed", 5.0)
	check("A_connection_closed", A.conn.state == "closed", A.conn.state)
	# B phải còn sống: lệnh kick_account (của phiên A) không được đá nhầm phiên B vừa vào
	await B.wait_until(func(): return not B.conn.is_live(), 4.0)
	var b_alive: bool = B.conn.is_live()
	check("B_not_kicked_by_stale_takeover_control", b_alive, {"B_session_closed": B.session_closed, "B_conn": B.conn.state,
		"kicked_after_ms": -1 if b_alive else Time.get_ticks_msec() - b_live_at})
	if not b_alive:
		note("takeover: phiên mới B bị room server đóng với lý do %s ~%d ms sau khi vào (lệnh kick_account của phiên cũ áp nhầm theo account_id)" % [str(B.session_closed), Time.get_ticks_msec() - b_live_at])
		B.session_closed = []
		if not check("B_reconnect_after_wrong_kick", await B.reconnect(20.0), B.closed_reason):
			return false
	mark("takeover")
	var resX: Dictionary = A.results.get(ridX, {})
	var resY: Dictionary = A.results.get(ridY, {})
	check("A_command_after_takeover_not_committed", resY.get("status", "none") != "committed", resY)
	# A không lấy lại được vé khi B đang giữ phiên
	var ta: Dictionary = await A.api.ticket(A.room_id)
	check("A_ticket_blocked_after_takeover", not ta["ok"] and ta["error_code"] == "LEASE_ACTIVE_ELSEWHERE", ta["error_code"])
	# B gửi lại X cùng op_id + version cũ: chạy nhiều nhất một lần
	await B.goto_shop()
	var rx: Dictionary = await B.durable_raw("shop.buy", buy, opX, esvX)
	var s1: Dictionary = await B.server_save()
	# lệnh mới với expected_save_version cũ (stale) phải bị từ chối SAVE_CONFLICT nếu version đã đổi
	var stale_rej := true
	if int(s1["save_version"]) != esvX:
		var rs: Dictionary = await B.durable_raw("shop.buy", buy, Protocol.uuid4(), esvX)
		stale_rej = rs.get("status", "") == "rejected" and rs.get("error_code", "") == "SAVE_CONFLICT"
		check("stale_expected_version_rejected", stale_rej, rs)
		await B.refresh_save()
	var rz: Dictionary = await B.dur("shop.buy", buy)
	var s2: Dictionary = await B.server_save()
	var rice2 := int(s2["inventory"]["food_counts"].get("item_rice_ball", 0))
	var x_committed: bool = resX.get("status", "") == "committed" or rx.get("status", "") == "committed"
	var z_committed: bool = rz.get("status", "") == "committed"
	var want := rice0 + (1 if x_committed else 0) + (1 if z_committed else 0)
	check("no_duplicate_after_takeover", rice2 == want and z_committed,
		{"rice": [rice0, rice2], "want": want, "X_at_A": resX.get("status", "no_result"), "X_error_at_A": resX.get("error_code"),
		"X_replay_at_B": rx.get("status"), "X_replay_error": rx.get("error_code"), "Y_at_A": resY.get("status", "no_result"),
		"Y_error": resY.get("error_code"), "Z": rz.get("status"), "Z_error": rz.get("error_code")})
	mark("duplicate_checks")
	return true


# ================================================================== restart room server giữa chừng

## Bot có cá trong túi (chưa gọi boss) → room server bị dừng/bật lại (BOTSIGNAL restart_room) → bot vào lại:
## tiền/túi/save_version còn nguyên; gửi lại op nhặt cũ không nhân đôi; bán cá rồi dừng room server ngay lập tức,
## sau khi vào lại gửi lại cùng op bán: tiền cộng đúng một lần.
func sc_restart() -> bool:
	var b = bots[0]
	mark("connect")
	await b.goto_npc("npc_co_ba")
	await b.talk("npc_co_ba")
	await b.wait_until(func(): return "tool_slipper" in b.save["inventory"]["tools_owned"], 5.0)
	var c: Dictionary = await b.catch_one([], 30)
	if not check("caught_fish_before_restart", c.get("ok", false), c):
		return false
	var s1: Dictionary = await b.server_save()
	var bag1: Array = s1["inventory"]["bag"].map(func(it): return it["uid"])
	check("fish_in_bag_before_restart", c["uid"] in bag1, bag1)
	mark("catch_before_restart")
	# --- lần 1: dừng room server khi đang có cá trong túi
	var n_closed: int = b.session_closed.size()
	print("BOTSIGNAL restart_room")
	var down: bool = await b.wait_until(func(): return not b.conn.is_live(), 30.0)
	check("disconnected_when_room_server_stops", down, {"session_closed": b.session_closed.slice(n_closed), "closed_reason": b.closed_reason})
	var back: bool = await b.reconnect(90.0)
	if not check("reconnected_after_restart_1", back, b.closed_reason):
		return false
	mark("restart_1")
	var s2: Dictionary = await b.server_save()
	var bag2: Array = s2["inventory"]["bag"].map(func(it): return it["uid"])
	check("save_intact_after_restart", int(s2["currencies"]["money"]) == int(s1["currencies"]["money"]) and bag2 == bag1 and int(s2["save_version"]) == int(s1["save_version"]),
		{"money": [s1["currencies"]["money"], s2["currencies"]["money"]], "bag": [bag1, bag2], "version": [s1["save_version"], s2["save_version"]]})
	await b.wait_until(func(): return b.save["inventory"]["bag"].size() == bag1.size(), 3.0)
	check("room_view_after_restart_has_fish", c["uid"] in b.save["inventory"]["bag"].map(func(it): return it["uid"]), b.save["inventory"]["bag"].size())
	check("fish_entity_not_respawned_in_world", b.entity(c["uid"]).is_empty(), b.entity(c["uid"]))
	# gửi lại op nhặt cũ (cùng op_id) sau restart: không có bản thứ hai
	var rp: Dictionary = await b.durable_raw("inventory.pickup", {"item_uid": c["uid"]}, c["pickup_op"]["op_id"], int(c["pickup_op"]["esv"]))
	var s3: Dictionary = await b.server_save()
	var n_fish := 0
	for it in s3["inventory"]["bag"] + s3["inventory"]["recovery_inbox"]:
		if it["uid"] == c["uid"]:
			n_fish += 1
	check("replay_pickup_after_restart_no_duplicate", n_fish == 1 and int(s3["save_version"]) == int(s2["save_version"]),
		{"replay_status": rp.get("status"), "copies": n_fish, "version": [s2["save_version"], s3["save_version"]]})
	# nhặt lại bằng op mới cũng không được
	var rp2: Dictionary = await b.dur("inventory.pickup", {"item_uid": c["uid"]})
	check("pickup_again_new_op_rejected", rp2.get("status", "") == "rejected", rp2.get("error_code"))
	# --- lần 2: bán cá và dừng room server ngay sau khi gửi (giao dịch có thể đang bay)
	await b.goto_shop()
	var sv: Dictionary = await b.server_save()
	var money_before := int(sv["currencies"]["money"])
	var value := 0
	var sell_uids: Array = []
	for it in sv["inventory"]["bag"]:
		sell_uids.append(it["uid"])
		value += int(it["base_value"]) * int(it["trick_mult_milli"]) / 1000
	var shop := IslandLayout.shop_zone(b.island())
	var sell := {"item_uids": sell_uids, "shop_id": shop["shop_id"]}
	var opS := Protocol.uuid4()
	var esvS: int = b.save_version
	var plS := sell.duplicate()
	plS["op_id"] = opS
	plS["expected_save_version"] = esvS
	var ridS: String = b.conn.send("inventory.sell", plS)
	print("BOTSIGNAL restart_room")
	await b.wait_until(func(): return not b.conn.is_live(), 30.0)
	var first_res: Dictionary = b.results.get(ridS, {})
	back = await b.reconnect(90.0)
	if not check("reconnected_after_restart_2", back, b.closed_reason):
		return false
	mark("restart_2")
	await b.goto_shop()
	var rs: Dictionary = await b.durable_raw("inventory.sell", sell, opS, esvS)
	var s4: Dictionary = await b.server_save()
	check("sell_during_restart_exactly_once", int(s4["currencies"]["money"]) == money_before + value and s4["inventory"]["bag"].is_empty(),
		{"money": [money_before, s4["currencies"]["money"]], "value": value, "first_result": first_res.get("status", "no_result"),
		"replay": rs.get("status"), "replay_error": rs.get("error_code"), "bag_left": s4["inventory"]["bag"].size()})
	var rs2: Dictionary = await b.dur("inventory.sell", sell)
	var s5: Dictionary = await b.server_save()
	check("sell_again_new_op_rejected", rs2.get("status", "") == "rejected" and int(s5["currencies"]["money"]) == int(s4["currencies"]["money"]),
		{"status": rs2.get("status"), "error": rs2.get("error_code")})
	return true


# ================================================================== NET-02: hai phòng song song

## bots 0,1 ở phòng A; bots 2,3 ở phòng B; cùng đảo, cùng tọa độ (bot0≡bot2, bot1≡bot3). Mỗi phòng câu cá, emote, ping.
## Kiểm: snapshot/sự kiện không lẫn phòng; vé/envelope/tool.use/nhặt nhắm vào phòng kia bị từ chối.
func sc_two_rooms() -> bool:
	if bots.size() != 4:
		return check("two_rooms_needs_4_bots", false, "--bots=4")
	for b in bots:
		if not await b.register_and_login():
			return check("register", false)
	var A: Array = [bots[0], bots[1]]
	var Bg: Array = [bots[2], bots[3]]
	if not await bots[0].create_room():
		return check("create_room_A", false)
	var okB: bool = await bots[2].create_room()
	if not check("create_room_B_second_concurrent_room", okB, "backend từ chối phòng thứ hai (CABAY_MAX_ROOMS / initial_concurrent_rooms=%d)" % int(ContentDB.limit("initial_concurrent_rooms", 1))):
		return false
	var rA: Dictionary = await bots[1].join_by_code(bots[0].invite_code)
	var rB: Dictionary = await bots[3].join_by_code(bots[2].invite_code)
	if not check("join_rooms", rA["ok"] and rB["ok"], [rA["error_code"], rB["error_code"]]):
		return false
	for b in bots:
		if not await b.connect_room():
			return check("connect_bot%d" % b.index, false, b.closed_reason)
	var roomA: String = bots[0].room_id
	var roomB: String = bots[2].room_id
	var accA: Array = A.map(func(b): return b.api.account_id)
	var accB: Array = Bg.map(func(b): return b.api.account_id)
	var see2: bool = await bots[0].wait_until(func(): return bots.all(func(b): return b.snapshot.get("players", []).size() == 2), 10.0)
	check("each_room_sees_only_2_players", see2, bots.map(func(b): return b.snapshot.get("players", []).size()))
	mark("connect")
	# cùng tọa độ: bot0≡bot2 (ô bến 0), bot1≡bot3 (ô bến 1)
	for b in bots:
		b.slot = b.index % 2
	# cả 4 câu cùng lúc (2 phòng, cùng ô bến)
	var fished: Array = await all_bots(func(b): return await b.catch_one([], 30), 300.0)
	check("all_four_caught_in_parallel_rooms", _ok_all(fished), fished.map(func(f): return [f.get("ok"), f.get("species"), f.get("casts")] if typeof(f) == TYPE_DICTIONARY else null))
	mark("fish_both_rooms")
	# emote/ping mỗi bot
	for b in bots:
		b.command("player.emote", {"emote": "wave"})
		var p: Vector3 = b.my_pos()
		b.command("room.ping", {"kind": "here", "position": [p.x, p.y, p.z]})
	await bots[0].sleep(1.5)
	# tấn công chéo phòng: vé, envelope sai room_id
	var tk: Dictionary = await bots[0].api.ticket(roomB)
	check("ticket_for_other_room_rejected", not tk["ok"], tk["error_code"])
	var envx := Protocol.make_envelope("player.emote", {"emote": "cheer"}, bots[0].conn.connection_id, roomB, bots[0].conn.seq + 1)
	bots[0].conn.seq += 1
	bots[0].conn.send_raw(JSON.stringify(envx))
	await bots[0].sleep(0.6)
	check("envelope_with_other_room_id_rejected", bots[0].results.get(envx["request_id"], {}).get("error_code", "") == "INVALID_PAYLOAD", bots[0].results.get(envx["request_id"]))
	# phòng B: bot2 câu thêm một con và để cá xỉu nằm 6 s; trong lúc đó bot0 (phòng A, cùng tọa độ) ném dép/nhặt cá đó
	bots[2].ko_uid = ""
	bots[2].hold_before_pickup_s = 6.0
	var holder := [null]
	_run_one(func(b): return await b.catch_one([], 30), bots[2], 0, holder, [0])
	await bots[2].wait_until(func(): return bots[2].ko_uid != "" or holder[0] != null, 120.0)
	var fishB: String = bots[2].ko_uid
	if not check("room_B_fish_knocked_out_and_waiting", fishB != "", holder[0]):
		return false
	var eB: Dictionary = bots[2].entity(fishB)
	if not eB.is_empty():
		bots[0].look_at_point(Vector3(eB["position"][0], eB["position"][1], eB["position"][2]))
	var ev2_base: int = bots[2].events.size()
	await bots[0].sleep(0.2)
	var rid_t: String = bots[0].command("tool.use", {"target_uid": fishB})
	var rp: Dictionary = await bots[0].dur("inventory.pickup", {"item_uid": fishB})
	await bots[0].sleep(0.5)
	check("tool_use_on_other_room_fish_rejected", bots[0].results.get(rid_t, {}).get("status", "") == "rejected", bots[0].results.get(rid_t))
	check("pickup_other_room_fish_rejected", rp.get("status", "") == "rejected", [rp.get("status"), rp.get("error_code")])
	var hitB: Array = bots[2].events.slice(ev2_base).filter(func(e): return e["actor_player_id"] == bots[0].api.account_id)
	check("room_B_saw_no_action_from_room_A", hitB.is_empty(), hitB.map(func(e): return e["name"]))
	await bots[2].wait_until(func(): return holder[0] != null, 30.0)
	check("room_B_owner_still_picks_up_own_fish", holder[0] != null and holder[0].get("ok", false) and holder[0].get("uid", "") == fishB, holder[0])
	mark("cross_room_attacks")
	# rò rỉ: người chơi / thực thể / sự kiện / room_id
	var leak := {}
	var entsA := {}
	var entsB := {}
	for b in A:
		entsA.merge(b.seen_entities)
	for b in Bg:
		entsB.merge(b.seen_entities)
	var shared_ents: Array = entsA.keys().filter(func(u): return entsB.has(u))
	leak["shared_entity_uids"] = shared_ents.size()
	var ok_iso := shared_ents.is_empty()
	for b in bots:
		var mine: Array = accA if b in A else accB
		var other: Array = accB if b in A else accA
		var my_room: String = roomA if b in A else roomB
		var bad_players: Array = b.seen_players.keys().filter(func(a): return a not in mine)
		var bad_actor := 0
		var bad_room := 0
		for e in b.events:
			if e["actor_player_id"] != null and e["actor_player_id"] in other:
				bad_actor += 1
			if e["room_id"] != my_room:
				bad_room += 1
		var own_actors := {}
		for e in b.events:
			if e["actor_player_id"] != null:
				own_actors[e["actor_player_id"]] = true
		leak["bot%d" % b.index] = {"foreign_players": bad_players.size(), "foreign_actor_events": bad_actor, "foreign_room_events": bad_room,
			"entities_seen": b.seen_entities.size(), "events": b.events.size(), "roommate_events": own_actors.size()}
		ok_iso = ok_iso and bad_players.is_empty() and bad_actor == 0 and bad_room == 0 and own_actors.size() == 2
	check("no_cross_room_leak_players_entities_events", ok_iso, leak)
	return ok_iso
