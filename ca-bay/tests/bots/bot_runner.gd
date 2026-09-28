extends Node
## Chạy kịch bản nhiều bot qua protocol thật.
##   godot --headless --path . res://tests/bots/bot_runner.tscn -- --scenario=<tên> --bots=4 [--api=..] [--ws=..]
##       [--timeout=giây] [--from-island=1..3 --user=<tên> --password=<mk>] [--all-species]
## Kịch bản: connect4, fish_loop, reconnect, negative, quest_boss, content_all, takeover, restart, two_rooms,
##   summon_replay, kick_cleanup, pickup_blink. Chạy kèm stack: tests/integration/run_bots.py (cổng 8797/8920).
## WP-12: net_outage (NET-03 mất mạng 10/60/100 s), net_halfopen (mất mạng không FIN/RST), fish_net (NET-05 cắt ngẫu nhiên,
##   tự nối lại), boss_coop (CONTENT-02), room_kill_boss (SAVE-03 phần room), owner_leave (NET-04). Các kịch bản này điều
##   phối proxy/room server/DB test qua BOTSIGNAL có JSON (ipc) — chỉ chạy được qua run_bots.py.
## In "BOTRESULT {json}" rồi thoát (0 = đạt). Kịch bản cần điều phối bên ngoài (restart) in "BOTSIGNAL <tên>".

const Bot := preload("res://tests/bots/bot.gd")

var bots: Array = []
var endpoints: Dictionary
var result := {"scenario": "", "ok": false, "checks": {}, "notes": [], "timings": {}}
var opts := {"timeout": 600.0, "from_island": 1, "user": "", "password": "", "all_species": false,
	"ipc_dir": "", "direct_ws": "", "via_proxy": false, "max_fps": 0, "net_cuts": false, "outages": "10,60,100",
	"auto_reconnect": false, "ping": 0.0, "rounds": 2, "afk": true, "watch_s": 0.0, "cut_inflight": false}
var _t0 := 0
var _mark_t := 0
var _finished := false
var last_summon_op := {}


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
		elif a == "--all-species":
			opts["all_species"] = true
		elif a.begins_with("--ipc-dir="):
			opts["ipc_dir"] = a.substr(10)
		elif a.begins_with("--direct-ws="):
			opts["direct_ws"] = a.substr(12)
		elif a == "--via-proxy":
			opts["via_proxy"] = true
		elif a.begins_with("--max-fps="):
			opts["max_fps"] = int(a.substr(10))
		elif a == "--net-cuts":
			opts["net_cuts"] = true
		elif a.begins_with("--outages="):
			opts["outages"] = a.substr(10)
		elif a == "--auto-reconnect":
			opts["auto_reconnect"] = true
		elif a.begins_with("--ping="):
			opts["ping"] = float(a.substr(7))
		elif a.begins_with("--rounds="):
			opts["rounds"] = int(a.substr(9))
		elif a == "--no-afk":
			opts["afk"] = false
		elif a.begins_with("--watch-s="):
			opts["watch_s"] = float(a.substr(10))
		elif a == "--cut-inflight":
			opts["cut_inflight"] = true
	endpoints = Endpoints.load_endpoints()
	result["scenario"] = scenario
	result["bots"] = n
	_t0 = Time.get_ticks_msec()
	_mark_t = _t0
	get_tree().create_timer(float(opts["timeout"])).timeout.connect(func(): _finish(false, "timeout toàn kịch bản (%ds)" % int(opts["timeout"])))
	if int(opts["max_fps"]) > 0:
		Engine.max_fps = int(opts["max_fps"])
	result["network"] = {"ws": endpoints["ws_url"], "via_proxy": opts["via_proxy"]}
	for i in n:
		var b: Node = Bot.new(i, endpoints.duplicate())
		add_child(b)
		bots.append(b)
		b.ping_interval = float(opts["ping"])
		b.auto_reconnect = bool(opts["auto_reconnect"]) or bool(opts["net_cuts"])
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
		"pickup_blink":
			ok = await sc_connect(1) and await sc_pickup_blink()
		"summon_replay":
			ok = await sc_summon_replay()
		"kick_cleanup":
			ok = await sc_connect(2) and await sc_kick_cleanup()
		"net_outage":
			ok = await sc_connect(n) and await sc_net_outage()
		"net_halfopen":
			ok = await sc_connect(n) and await sc_net_halfopen()
		"fish_net":
			ok = await sc_connect(n) and await sc_fish_net()
		"boss_coop":
			ok = await sc_boss_coop()
		"room_kill_boss":
			ok = await sc_connect(n) and await sc_room_kill_boss()
		"owner_leave":
			ok = await sc_connect(n) and await sc_owner_leave()
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
	var net := {}
	for b in bots:
		if not b.rtt_ms.is_empty() or not b.reconnect_log.is_empty() or b.resent_ops > 0:
			net["bot%d" % b.index] = {"rtt_ms": b.rtt_stats(), "reconnects": b.reconnect_log, "resent_ops": b.resent_ops}
	if not net.is_empty():
		result["net"] = net
	result["ok"] = ok and not result["checks"].is_empty() and result["checks"].values().all(func(c): return c["ok"])
	print("BOTRESULT " + JSON.stringify(result))
	get_tree().quit(0 if result["ok"] else 1)


# ------------------------------------------------------------------ điều phối ngoài (run_bots.py)

var _ipc_seq := 0


## Nhờ runner (run_bots.py) làm việc ngoài tiến trình bot: proxy (cắt/đóng băng kết nối), room server (SIGKILL/bật lại),
## đọc DB test, lùi created_at trận boss trong DB test + maintenance_once(), commit nội bộ bằng epoch cũ.
## In "BOTSIGNAL <tên> {json}" rồi chờ file <ipc-dir>/<id>.json.
func ipc(sig_name: String, args: Dictionary = {}, timeout_s: float = 90.0) -> Dictionary:
	if String(opts["ipc_dir"]) == "":
		return {"ok": false, "error": "không có --ipc-dir (chạy qua tests/integration/run_bots.py)"}
	_ipc_seq += 1
	var id := "%d_%d" % [Time.get_ticks_msec(), _ipc_seq]
	var a := args.duplicate(true)
	a["id"] = id
	print("BOTSIGNAL %s %s" % [sig_name, JSON.stringify(a)])
	var path := "%s/%s.json" % [opts["ipc_dir"], id]
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_s * 1000.0:
		if FileAccess.file_exists(path):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(d) == TYPE_DICTIONARY:
				return d
		await get_tree().create_timer(0.05).timeout
	return {"ok": false, "error": "ipc_timeout %s" % sig_name}


func op_rowid() -> int:
	var r: Dictionary = await ipc("db", {"q": "max_op_rowid"})
	return int(r.get("rowid", 0))


## Sổ op của backend (bảng operations) cho một tài khoản sau rowid: [{op_id, op_type, status, error_code, save_version}].
func ops_since(aid: String, rowid: int) -> Array:
	var r: Dictionary = await ipc("db", {"q": "ops_since", "account_id": aid, "rowid": rowid})
	return r.get("rows", [])


func committed_ops(rows: Array) -> Array:
	return rows.filter(func(x): return str(x.get("status", "")) == "committed")


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
	# NET-06: NaN / vô cực trong input không được lọt vào mô phỏng (vị trí phải còn là số hữu hạn)
	var env5 := Protocol.make_envelope("player.input", {"move_x": 0.5, "move_z": 0, "look_yaw_rad": 0.25, "look_pitch_rad": 0, "jump": false}, b.conn.connection_id, b.conn.room_id, b.conn.seq + 1)
	b.conn.seq += 1
	var nan_text := JSON.stringify(env5).replace("\"move_x\":0.5", "\"move_x\":NaN")
	b.conn.send_raw(nan_text)
	var env6 := Protocol.make_envelope("player.input", {"move_x": 0.5, "move_z": 0, "look_yaw_rad": 0.25, "look_pitch_rad": 0, "jump": false}, b.conn.connection_id, b.conn.room_id, b.conn.seq + 1)
	b.conn.seq += 1
	var inf_text := JSON.stringify(env6).replace("\"move_x\":0.5", "\"move_x\":1e999").replace("\"look_yaw_rad\":0.25", "\"look_yaw_rad\":-1e999")
	b.conn.send_raw(inf_text)
	await b.get_tree().create_timer(1.0).timeout
	var me: Dictionary = b.player_of(b.api.account_id)
	var pos: Array = me.get("position", [])
	var finite := pos.size() == 3 and pos.all(func(v): return is_finite(float(v))) and is_finite(float(me.get("yaw_rad", 0.0)))
	# không bắt buộc có phản hồi (input không có kết quả riêng; NaN không phải JSON hợp lệ nên server không đọc được request_id)
	base_ok = check("nan_inf_input_not_in_simulation", nan_text.contains("NaN") and inf_text.contains("1e999") and finite and b.conn.is_live(),
		{"position": pos, "inf_reply": b.results.get(env6["request_id"], {}).get("error_code", "no_reply"), "nan_reply": b.results.get(env5["request_id"], {}).get("error_code", "no_reply")}) and base_ok
	# gói quá lớn (> max_client_payload_bytes) bị bỏ, không làm sập server và không ngắt người chơi
	var env7 := Protocol.make_envelope("tool.use", {"target_uid": "x".repeat(9000)}, b.conn.connection_id, b.conn.room_id, b.conn.seq + 1)
	b.conn.seq += 1
	b.conn.send_raw(JSON.stringify(env7))
	var after_big: Dictionary = await b.durable("inventory.pickup", {"item_uid": Protocol.uuid4()})
	base_ok = check("oversized_packet_dropped_session_kept", b.conn.is_live() and after_big.get("status", "") == "rejected" and not b.results.has(env7["request_id"]),
		{"live": b.conn.is_live(), "next_command": after_big.get("status"), "big_reply": b.results.get(env7["request_id"], {}).get("error_code", "no_reply")}) and base_ok
	# vẫn chơi tiếp được sau khi bị từ chối
	base_ok = check("still_connected", b.conn.is_live()) and base_ok
	# AUTH-02: socket mở nhưng không xác thực bị server ngắt sau websocket_auth_timeout_s (5 s)
	var raw := WebSocketPeer.new()
	var ws_url: String = String(opts["direct_ws"]) if String(opts["direct_ws"]) != "" else String(endpoints["ws_url"])
	raw.connect_to_url(ws_url)
	var t0 := Time.get_ticks_msec()
	var opened_ms := -1
	var closed_ms := -1
	while Time.get_ticks_msec() - t0 < 15000:
		raw.poll()
		var rs := raw.get_ready_state()
		if rs == WebSocketPeer.STATE_OPEN and opened_ms < 0:
			opened_ms = Time.get_ticks_msec() - t0
		if rs == WebSocketPeer.STATE_CLOSED:
			closed_ms = Time.get_ticks_msec() - t0
			break
		await b.get_tree().process_frame
	var auth_limit_ms := int(float(ContentDB.limit("websocket_auth_timeout_s", 5)) * 1000.0)
	base_ok = check("unauthenticated_socket_closed_after_auth_timeout", opened_ms >= 0 and closed_ms > 0
		and closed_ms - opened_ms >= auth_limit_ms - 1000 and closed_ms - opened_ms <= auth_limit_ms + 2500,
		{"opened_ms": opened_ms, "closed_ms": closed_ms, "limit_ms": auth_limit_ms}) and base_ok
	# NET-06: bản client lệch nội dung / giao thức bị từ chối với mã rõ ràng (client hiện "Cần phiên bản game mới")
	var real_hash: String = ContentDB.content_hash
	b.conn.disconnect_now()
	ContentDB.content_hash = "0".repeat(64)
	var ok_bad_hash: bool = await b.reconnect(8.0)
	var reason_hash: String = b.closed_reason
	ContentDB.content_hash = real_hash
	var real_proto: String = String(ContentDB.network["protocol_version"])
	b.conn.disconnect_now()
	ContentDB.network["protocol_version"] = "0.0.1"
	var ok_bad_proto: bool = await b.reconnect(8.0)
	var reason_proto: String = b.closed_reason
	ContentDB.network["protocol_version"] = real_proto
	b.conn.disconnect_now()
	var ok_back: bool = await b.reconnect(15.0)
	base_ok = check("content_and_protocol_mismatch_rejected", not ok_bad_hash and reason_hash == "CONTENT_MISMATCH" and not ok_bad_proto
		and reason_proto in ["PROTOCOL_MISMATCH", "BAD_TICKET"] and ok_back,
		{"content": reason_hash, "protocol": reason_proto, "reconnect_with_real_build": ok_back}) and base_ok
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
		last_summon_op = summon_op
		await summoner.wait_until(func(): return not summoner.last_event("boss.summoned", "", bases[0]).is_empty(), 6.0)
		var ev: Dictionary = summoner.last_event("boss.summoned", "", bases[0])
		if ev.is_empty():
			check("%s_boss_summoned_event" % tag, false, "không có boss.summoned sau khi commit")
			return false
		summoned = ev["event_payload"]
		var uid: String = summoned["creature_uid"]
		var tmo := float(boss["escape_timer_s"]["solo"]) + 30.0
		if bool(opts["net_cuts"]) and attempt == 0:
			_cut_later(bots[0], 5.0, "%s_boss_fight" % tag)
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
		# quay lại cọc (trong tầm gọi) để lần gửi lại thật sự tới backend, không bị room server chặn vì xa cọc
		await summoner.nav_to(post + dir * 2.0 + perp * -1.5, 0.6, 30.0)
		await summoner.sleep(1.0)
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
		check("%s_replay_summon_reached_backend" % tag, str(rr.get("error_code", "")) not in ["OUT_OF_RANGE", "COOLDOWN"] and rr.get("status", "") in ["committed", "rejected"], rr)
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


## Một bot: bắt đủ các loài thường của vùng bến đảo idx (bảng spawn thật). Loài cần cần câu bậc cao hơn → mua ở sạp đảo
## (tiền kiếm từ nhiệm vụ/bán cá), trang bị rồi câu tiếp. Túi đầy → bán cá ở sạp. Chỉ ghi nhận qua save server (collection).
func collect_species(b, idx: int) -> Dictionary:
	var isl: String = ContentDB.island_order[idx]
	var out := {"ok": false, "bot": b.index, "casts": 0, "skipped": 0, "sold": 0, "bought": [], "new": []}
	var t0 := Time.get_ticks_msec()
	var table: Dictionary = {}
	for z in ContentDB.islands[isl]["zones"]:
		if z.get("kind", "") == "fishing" and String(z["zone_id"]).ends_with("ben_do"):
			table = ContentDB.spawn_tables[z["spawn_table_id"]]
	var tier_of := {}
	for e in table.get("entries", []):
		tier_of[e["creature_id"]] = int(e["min_rod_tier"])
	var shop := IslandLayout.shop_zone(isl)
	for guard in 60:
		var missing: Array = tier_of.keys().filter(func(cid): return not b.save["collection"]["species"].has(cid))
		if missing.is_empty():
			break
		var rod_tier := int(ContentDB.rods[b.save["inventory"]["equipped_rod_id"]]["tier"])
		var need := 0
		for cid in missing:
			need = maxi(need, int(tier_of[cid]))
		if need > rod_tier:
			for en in ContentDB.shops[shop["shop_id"]]["entries"]:
				var g: Dictionary = en["grant"]
				if g["kind"] == "rod" and int(ContentDB.rods[g["id"]]["tier"]) >= need and g["id"] not in b.save["inventory"]["rods_owned"]:
					await b.goto_shop()
					var rb: Dictionary = await b.dur("shop.buy", {"shop_id": shop["shop_id"], "entry_id": en["entry_id"], "quantity": 1})
					out["bought"].append([en["entry_id"], rb.get("status"), rb.get("error_code")])
					break
			for rid in b.save["inventory"]["rods_owned"]:
				if int(ContentDB.rods[rid]["tier"]) > rod_tier:
					await b.dur("equipment.equip", {"equipment_id": rid})
					rod_tier = int(ContentDB.rods[rid]["tier"])
			missing = missing.filter(func(cid): return int(tier_of[cid]) <= rod_tier)
			if missing.is_empty():
				out["error"] = "không mua được cần bậc %d" % need
				return out
		if b.bag_free() == 0:
			await b.goto_shop()
			var uids: Array = []
			for it in b.save["inventory"]["bag"]:
				if it["def_kind"] == "creature":
					uids.append(it["uid"])
			if uids.is_empty():
				out["error"] = "túi đầy đồ không bán được"
				return out
			var rs: Dictionary = await b.dur("inventory.sell", {"item_uids": uids, "shop_id": shop["shop_id"]})
			if rs.get("status", "") == "committed":
				out["sold"] += uids.size()
		var c: Dictionary = await b.catch_one(missing, 40)
		out["casts"] += int(c.get("casts", 0))
		out["skipped"] += int(c.get("skipped", 0))
		if not c.get("ok", false):
			out["error"] = "câu %s thất bại: %s" % [str(missing), str(c.get("error", ""))]
			return out
		out["new"].append(c.get("species", ""))
	var left: Array = tier_of.keys().filter(func(cid): return not b.save["collection"]["species"].has(cid))
	out["missing"] = left
	out["t_s"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1)
	out["ok"] = left.is_empty()
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
	if bool(opts["net_cuts"]):
		# NET-05 biến thể: proxy cắt kết nối của bot cuối giữa lúc làm nhiệm vụ, và của bot0 giữa trận boss; bot tự nối lại
		_cut_later(bots[bots.size() - 1], 40.0, "isl1_prep")
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
	if bool(opts["net_cuts"]):
		var cut_ok := net_cut_log.size() >= 2
		for c in net_cut_log:
			var cb = bots[int(c["bot"])]
			cut_ok = cut_ok and bool(c["ok"]) and cb.reconnect_log.any(func(x): return x["ok"])
		replay_ok = check("net_cuts_mid_prep_and_mid_boss_bots_reconnected", cut_ok, {"cuts": net_cut_log, "reconnects": bots.map(func(b): return b.reconnect_log),
			"resent_ops": bots.map(func(b): return b.resent_ops)}) and replay_ok
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
		# phiên chơi cũ (lần chạy trước, room server đã tắt) còn giữ lease → dùng đúng luồng sản phẩm: chuyển phiên sang đây
		var sv0: Dictionary = await b.api.get_save()
		var lease: Dictionary = sv0["data"].get("lease", {}) if sv0["ok"] else {}
		if lease.get("active", false) and not lease.get("this_session", false):
			var tk: Dictionary = await b.api.takeover()
			note("tài khoản còn lease của phiên trước → POST /v1/account/takeover: %s" % str(tk["ok"]))
		var isl0: String = ContentDB.island_order[start_idx]
		if not check("from_island_unlocked_legitimately", isl0 in b.save["progress"]["islands_unlocked"], b.save["progress"]["islands_unlocked"]):
			return false
		var r: Dictionary = await b.api.create_room(isl0)
		for i in 12:
			# phòng của lần chạy trước còn "sống" tới khi mất nhịp tim 30 s (giới hạn initial_concurrent_rooms)
			if r["ok"] or r["error_code"] != "SERVER_BUSY":
				break
			await b.sleep(5.0)
			r = await b.api.create_room(isl0)
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
		if opts["all_species"]:
			var col: Array = await all_bots(func(b): return await collect_species(b, idx))
			for i in col.size():
				ok = check("%s_bot%d_all_species_of_island" % [tag, i], typeof(col[i]) == TYPE_DICTIONARY and col[i].get("ok", false), col[i]) and ok
			mark("%s_species" % tag)
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
		if opts["all_species"]:
			var tn := 0
			for cid in ContentDB.creatures:
				if not ContentDB.creatures[cid].get("is_boss", false):
					tn += 1
			all_ok = check("bot%d_all_normal_species_caught" % i, normal == tn, {"caught": normal, "total": tn}) and all_ok
		all_ok = check("bot%d_all_bosses_quests_islands" % i, bosses_ok and quests_ok and sv["progress"]["islands_unlocked"].size() == ContentDB.island_order.size(),
			{"bosses": sv["progress"]["bosses_defeated"], "islands": sv["progress"]["islands_unlocked"], "money": sv["currencies"]["money"],
			"normal_species_caught": normal, "species": sv["collection"]["species"].keys()}) and all_ok
		var total_normal := 0
		for cid in ContentDB.creatures:
			if not ContentDB.creatures[cid].get("is_boss", false):
				total_normal += 1
		if not opts["all_species"]:
			note("bot%d bắt %d/%d loài thường (CONTENT-01 đầy đủ cần đủ loài: chạy thêm --all-species)" % [i, normal, total_normal])
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
	await b.sleep(2.0)  # để các server op phụ (tutorial.done do sự kiện nhặt) commit xong trước khi chụp save
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
	# hợp đồng: "Same op_id and same payload returns original result" → client gửi lại đúng payload cũ phải nhận lại receipt committed
	check("replay_pickup_same_op_returns_original_result", rp.get("status", "") == "committed", {"status": rp.get("status"), "error": rp.get("error_code")})
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
	if not check("create_room_B_second_concurrent_room", okB, "ok" if okB else "backend từ chối phòng thứ hai (CABAY_MAX_ROOMS / initial_concurrent_rooms=%d)" % int(ContentDB.limit("initial_concurrent_rooms", 1))):
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
	# dép của Cô Ba (để đập xỉu cá) — mỗi bot tự nhận trong phòng của mình
	var gifts: Array = await all_bots(func(b):
		await b.goto_npc("npc_co_ba")
		await b.talk("npc_co_ba")
		return await b.wait_until(func(): return "tool_slipper" in b.save["inventory"]["tools_owned"], 5.0), 60.0)
	check("all_got_slipper", gifts.all(func(g): return g == true), gifts)
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


# ================================================================== server tự ngắt phiên (rate_limit) phải dọn người chơi

## bot1 gửi >40 player.input sai schema → server gửi session.closed rate_limit và ngắt. Người còn lại (bot0) phải thấy
## bot1 chuyển sang "disconnected" (giữ chỗ trong grace) rồi vào lại được như mất mạng thường.
func sc_kick_cleanup() -> bool:
	var a = bots[0]
	var k = bots[1]
	var aid: String = k.api.account_id
	k.keepalive = false
	for i in 45:
		var env := Protocol.make_envelope("player.input", {"move_x": 1.0001, "move_z": 0.0, "look_yaw_rad": 0.0, "look_pitch_rad": 0.0, "jump": false},
			k.conn.connection_id, k.conn.room_id, k.conn.seq + 1)
		k.conn.seq += 1
		k.conn.send_raw(JSON.stringify(env))
		await k.sleep(0.06)
	await k.wait_until(func(): return "rate_limit" in k.session_closed, 5.0)
	check("invalid_spam_gets_session_closed_rate_limit", "rate_limit" in k.session_closed, k.session_closed)
	await k.wait_until(func(): return k.conn.state == "closed", 5.0)
	check("kicked_client_connection_closed", k.conn.state == "closed", k.conn.state)
	var seen_mode := [""]
	var ok: bool = await a.wait_until(func():
		for pl in a.snapshot.get("players", []):
			if pl["account_id"] == aid:
				seen_mode[0] = pl["mode"]
				return pl["mode"] == "disconnected"
		seen_mode[0] = "gone"
		return true, 6.0)
	check("kicked_player_detached_by_room_server", ok, {"mode_seen_by_other_player_6s_after_kick": seen_mode[0]})
	k.session_closed = []
	var back: bool = await k.reconnect(15.0)
	check("kicked_player_can_reconnect", back, k.closed_reason)
	return ok and back


# ================================================================== nhặt cá đang nhấp nháy sắp tỉnh

## Cá xỉu ko_duration_s; ko_blink_before_wake_s cuối chuyển "stunned_waking" (vẫn xỉu, chỉ nhấp nháy báo sắp tỉnh).
## Nhặt trong khoảng đó phải được như lúc "stunned".
func sc_pickup_blink() -> bool:
	var b = bots[0]
	await b.goto_npc("npc_co_ba")
	await b.talk("npc_co_ba")
	await b.wait_until(func(): return "tool_slipper" in b.save["inventory"]["tools_owned"], 5.0)
	var cre_ko := 15.0
	for cid in ContentDB.creatures:
		if not ContentDB.creatures[cid].get("is_boss", false):
			cre_ko = minf(cre_ko, float(ContentDB.creatures[cid]["ko_duration_s"]))
	var blink := float(ContentDB.balance["creature"]["ko_blink_before_wake_s"])
	# catch_one chờ 1.2 s sau khi xỉu + hold; nhặt rơi vào giữa cửa sổ nhấp nháy
	b.hold_before_pickup_s = cre_ko - blink - 1.2 + 0.8
	var c: Dictionary = await b.catch_one([], 4)
	check("blinking_fish_can_be_picked_up", c.get("ok", false), {"pickup_state": c.get("pickup_state"), "errors": c.get("pickup_errors", []), "hold_s": b.hold_before_pickup_s, "casts": c.get("casts"), "error": c.get("error", "")})
	return c.get("ok", false)


# ================================================================== gửi lại boss.summon: người mới có nhận thưởng "miễn phí"?

## bot0 làm nhiệm vụ + hạ boss đảo 1 một mình. Sau đó bot1 (tài khoản mới, không tốn mồi, chưa làm nhiệm vụ) vào phòng;
## bot0 gửi lại đúng op boss.summon cũ. Đúng: không có trận mới, bot1 không nhận gì. Nếu có trận → ghi thưởng bot1 nhận được.
func sc_summon_replay() -> bool:
	if bots.size() != 2:
		return check("summon_replay_needs_2_bots", false, "--bots=2")
	var a = bots[0]
	var c = bots[1]
	if not await a.register_and_login() or not await a.create_room() or not await a.connect_room():
		return check("a_connect", false)
	var all_bots_saved := bots
	bots = [a]
	var prep: Dictionary = await island_prep(a, 0)
	if not check("a_prep_quest", prep.get("ok", false), prep):
		return false
	var won: bool = await island_boss(0, false)
	bots = all_bots_saved
	if not check("a_solo_boss_defeated", won):
		return false
	mark("a_quest_and_boss")
	if not await c.register_and_login():
		return check("c_register", false)
	var rj: Dictionary = await c.join_by_code(a.invite_code)
	if not check("c_join", rj["ok"] and await c.connect_room(), rj.get("error_code")):
		return false
	var info := island_info(0)
	var boss_id: String = info["boss_id"]
	var boss: Dictionary = ContentDB.bosses[boss_id]
	var spot := IslandLayout.boss_spot(a.island())
	var post: Vector2 = spot["post"]
	var dir := (Vector2(spot["arena"]) - post).normalized()
	var perp := Vector2(-dir.y, dir.x)
	await all_bots(func(b): return await b.nav_to(post + dir * 2.0 + perp * (-1.5 + 1.0 * b.index), 0.6, 60.0))
	await a.wait_until(func():
		for e in a.snapshot.get("entities", []):
			if e["kind"] == "boss":
				return false
		return true, 10.0)
	var a0: Dictionary = await a.server_save()
	var c0: Dictionary = await c.server_save()
	var bases: Array = bots.map(func(b): return b.events.size())
	var rr: Dictionary = await a.durable_raw("boss.summon", {"boss_id": boss_id, "zone_id": spot["zone_id"]}, last_summon_op["op_id"], int(last_summon_op["esv"]))
	await a.wait_until(func(): return not a.last_event("boss.summoned", "", bases[0]).is_empty(), 4.0)
	var ev: Dictionary = a.last_event("boss.summoned", "", bases[0])
	check("replayed_summon_starts_no_encounter", ev.is_empty(), {"replay_status": rr.get("status"), "boss_summoned": not ev.is_empty(), "encounter_id": last_summon_op.get("encounter_id")})
	if ev.is_empty():
		return true
	var uid: String = ev["event_payload"]["creature_uid"]
	var fights: Array = await all_bots(func(b): return await b.fight_boss(uid, bases[b.index], 260.0), 290.0)
	print("[boss] replay: %s" % JSON.stringify(fights))
	await c.wait_until(func(): return boss_id in c.save["progress"]["bosses_defeated"], 10.0)
	await a.sleep(1.5)
	var a1: Dictionary = await a.server_save()
	var c1: Dictionary = await c.server_save()
	var bait: String = boss["summon"]["bait_id"]
	var det := {"fight": fights.map(func(f): return f.get("result") if typeof(f) == TYPE_DICTIONARY else null),
		"newcomer_money_delta": int(c1["currencies"]["money"]) - int(c0["currencies"]["money"]),
		"newcomer_drops": _count_items(c1, boss["drops"][0]["id"]) - _count_items(c0, boss["drops"][0]["id"]),
		"newcomer_bosses_defeated": c1["progress"]["bosses_defeated"],
		"newcomer_bait_spent": 0,
		"summoner_money_delta": int(a1["currencies"]["money"]) - int(a0["currencies"]["money"]),
		"summoner_bait_delta": int(a1["inventory"]["bait_counts"].get(bait, 0)) - int(a0["inventory"]["bait_counts"].get(bait, 0))}
	check("newcomer_gets_no_reward_from_replayed_summon", det["newcomer_money_delta"] == 0 and det["newcomer_drops"] == 0, det)
	check("summoner_no_second_reward", det["summoner_money_delta"] == 0 and det["summoner_bait_delta"] == 0, det)
	return false


# ================================================================== WP-12 · tiện ích chung

func _player_index(viewer, aid: String) -> int:
	var pls: Array = viewer.snapshot.get("players", [])
	for i in pls.size():
		if pls[i]["account_id"] == aid:
			return i
	return -1


func _count_player(viewer, aid: String) -> int:
	return viewer.snapshot.get("players", []).filter(func(pl): return pl["account_id"] == aid).size()


func _uids(arr: Array) -> Array:
	return arr.map(func(it): return it["uid"])


func _copies(sv: Dictionary, uid: String) -> int:
	var n := 0
	for it in sv["inventory"]["bag"] + sv["inventory"]["recovery_inbox"]:
		if it["uid"] == uid:
			n += 1
	return n


func _bait(sv: Dictionary, bait: String) -> int:
	return int(sv["inventory"]["bait_counts"].get(bait, 0))


func _money(sv: Dictionary) -> int:
	return int(sv["currencies"]["money"])


func _claims(enc: String) -> Array:
	var r: Dictionary = await ipc("db", {"q": "reward_claims", "claim_key": enc})
	return r.get("rows", [])


func _claim_count(rows: Array, aid: String, kind: String) -> int:
	return rows.filter(func(x): return x["account_id"] == aid and x["reward_kind"] == kind).size()


func _attempt(enc: String) -> Dictionary:
	var r: Dictionary = await ipc("db", {"q": "boss_attempts", "encounter_id": enc})
	var rows: Array = r.get("rows", [])
	return rows[0] if not rows.is_empty() else {}


## Cắt kết nối của một bot ở proxy sau delay_s giây (chạy nền, không chặn kịch bản).
var net_cut_log: Array = []


func _cut_later(b, delay_s: float, tag: String) -> void:
	await get_tree().create_timer(delay_s).timeout
	var r: Dictionary = await ipc("proxy", {"op": "cut", "account_id": b.api.account_id})
	net_cut_log.append({"tag": tag, "bot": b.index, "ok": r.get("ok", false), "conns": r.get("cut", []), "t_s": snappedf((Time.get_ticks_msec() - _t0) / 1000.0, 0.1)})
	note("%s: proxy cắt kết nối bot%d → %s" % [tag, b.index, str(r.get("cut", r.get("error", "")))])


# ================================================================== WP-12 · NET-03 mất mạng 10 / 60 / 100 s

## A và B cùng phòng (qua proxy điều khiển được). B có F1 trong túi, F2 đã thả xuống đất (escrow). Mỗi chu kỳ: một lệnh
## bền vững của B đang bay (mất kết quả / không tới server) → proxy cắt đứt kết nối của B → B im lặng D giây → B nối lại.
## Trong grace (90 s): A thấy B "disconnected", B về đúng chỗ, túi/tiền/version chỉ đổi đúng bởi lệnh đang bay (một lần),
## gửi lại cùng op_id không nhân đôi, connection_id cũ / lease_epoch cũ bị từ chối. Quá grace: room gỡ B, trả lease,
## F2 về recovery inbox đúng một lần, B vào lại như người mới ở bến mà không mất đồ. Độ no/giờ chơi không chạy khi mất mạng.
func sc_net_outage() -> bool:
	if bots.size() != 2:
		return check("net_outage_needs_2_bots", false, "--bots=2")
	if not bool(opts["via_proxy"]) or String(opts["ipc_dir"]) == "":
		return check("net_outage_needs_proxy", false, "chạy qua run_bots.py --proxy (proxy điều khiển được để cắt mạng của một bot)")
	var A = bots[0]
	var B = bots[1]
	var grace := float(ContentDB.limit("reconnect_grace_s", 90))
	mark("connect")
	var gifts: Array = await all_bots(func(b):
		await b.goto_npc("npc_co_ba")
		await b.talk("npc_co_ba")
		return await b.wait_until(func(): return "tool_slipper" in b.save["inventory"]["tools_owned"], 5.0), 60.0)
	if not check("both_got_slipper", gifts.all(func(g): return g == true), gifts):
		return false
	var f1: Dictionary = await B.catch_one([], 30)
	var f2: Dictionary = {}
	if f1.get("ok", false):
		f2 = await B.catch_one([], 30)
	if not check("B_caught_two_fish", f1.get("ok", false) and f2.get("ok", false), [f1.get("error", ""), f2.get("error", "")]):
		return false
	mark("B_catch_2")
	await all_bots(func(b): return await b.goto_shop(), 60.0)
	var dr: Dictionary = await B.dur("inventory.drop", {"item_uid": f2["uid"]})
	await B.wait_until(func(): return not B.entity(f2["uid"]).is_empty(), 3.0)
	var it_db: Dictionary = await ipc("db", {"q": "item", "item_uid": f2["uid"]})
	if not check("B_dropped_F2_escrow_in_world_and_db", dr.get("status", "") == "committed" and not B.entity(f2["uid"]).is_empty()
			and str(it_db.get("row", {}).get("state", "")) == "escrow", {"drop": dr.get("status"), "error": dr.get("error_code"), "db": it_db.get("row")}):
		return false
	# A đứng sát con cá thả để xua cò (B mất mạng thì không tính là có người)
	var e2: Dictionary = B.entity(f2["uid"])
	await A.nav_to(Vector2(float(e2["position"][0]) - 1.0, float(e2["position"][2])), 0.5, 20.0)
	mark("setup")
	var ok := true
	var durs: Array = Array(String(opts["outages"]).split(",")).map(func(x): return float(x))
	for i in durs.size():
		var kind := "result_lost" if i % 2 == 0 else "not_delivered"
		var r: bool = await _outage_cycle(A, B, float(durs[i]), kind, f1["uid"], f2["uid"], grace)
		ok = r and ok
		mark("outage_%ds" % int(durs[i]))
	# F2 về túi đúng một bản (từ inbox nếu đã quá grace, còn trên đất thì nhặt tại chỗ)
	await B.refresh_save()
	var in_inbox: bool = f2["uid"] in _uids(B.save["inventory"]["recovery_inbox"])
	if not in_inbox and not B.entity(f2["uid"]).is_empty():
		var e3: Dictionary = B.entity(f2["uid"])
		await B.nav_to(Vector2(float(e3["position"][0]), float(e3["position"][2]) + 0.8), 0.5, 20.0)
	var pk: Dictionary = await B.dur("inventory.pickup", {"item_uid": f2["uid"]})
	var sv: Dictionary = await B.server_save()
	ok = check("F2_back_in_bag_exactly_once", pk.get("status", "") == "committed" and _copies(sv, f2["uid"]) == 1 and f2["uid"] in _uids(sv["inventory"]["bag"])
			and f1["uid"] in _uids(sv["inventory"]["bag"]), {"from": "recovery_inbox" if in_inbox else "world", "pickup": pk.get("status"), "error": pk.get("error_code"),
			"copies": _copies(sv, f2["uid"])}) and ok
	return ok


func _outage_cycle(A, B, dur_s: float, kind: String, f1: String, f2: String, grace: float) -> bool:
	var tag := "out%ds" % int(dur_s)
	var aidB: String = B.api.account_id
	var over := dur_s > grace
	B.move = Vector2.ZERO
	await B.sleep(1.0)
	await B.refresh_save()
	var s0: Dictionary = await B.server_save()
	var t_s0 := Time.get_ticks_msec()
	var row0: int = await op_rowid()
	var p0: Vector3 = B.my_pos()
	var idx0: int = _player_index(A, aidB)
	var cid_old: String = B.conn.connection_id
	var epoch_old: int = B.conn.lease_epoch
	var room: String = B.room_id
	var hunger0 := float(A.player_of(aidB).get("hunger", -1.0))
	# --- lệnh bền vững đang bay khi mất mạng: đổi dép ↔ cần câu (chỉ đổi equipped_id + version)
	var eq_to := "rod_bamboo" if String(s0["inventory"]["equipped_id"]) == "tool_slipper" else "tool_slipper"
	var op := Protocol.uuid4()
	var esv := int(s0["save_version"])
	var rm: Dictionary = await ipc("proxy", {"op": "mute", "dir": "s2c" if kind == "result_lost" else "c2s", "account_id": aidB})
	var rid_x: String = B.conn.send("equipment.equip", {"equipment_id": eq_to, "op_id": op, "expected_save_version": esv})
	await B.sleep(1.5 if kind == "result_lost" else 0.5)
	var got_before_cut: bool = B.results.has(rid_x)
	var rc: Dictionary = await ipc("proxy", {"op": "cut", "account_id": aidB})
	var t_cut := Time.get_ticks_msec()
	check("%s_cut_with_%s_command_in_flight" % [tag, kind], rm.get("ok", false) and rc.get("ok", false) and rid_x != "" and not got_before_cut,
		{"mute": rm.get("conns"), "cut": rc.get("cut"), "result_seen_before_cut": got_before_cut})
	await B.wait_until(func(): return not B.conn.is_live(), 5.0)
	# --- mất mạng: B im lặng; A quan sát B trong snapshot
	var seen_disc := -1
	var removed_at := -1
	var hunger_b: Array = []
	var modes := {}
	var a_h0 := float(A.me().get("hunger", 0.0))
	while Time.get_ticks_msec() - t_cut < dur_s * 1000.0:
		var el := Time.get_ticks_msec() - t_cut
		var pl: Dictionary = A.player_of(aidB)
		if pl.is_empty():
			if removed_at < 0 and not A.snapshot.is_empty():
				removed_at = el
		else:
			modes[pl["mode"]] = true
			if pl["mode"] == "disconnected":
				if seen_disc < 0:
					seen_disc = el
				hunger_b.append(float(pl["hunger"]))
		await A.sleep(0.5)
	var a_h1 := float(A.me().get("hunger", 0.0))
	var lease_mid: Dictionary = (await ipc("db", {"q": "lease", "account_id": aidB})).get("row", {})
	var item_mid: Dictionary = (await ipc("db", {"q": "item", "item_uid": f2})).get("row", {})
	# --- B có mạng lại: vé mới, kết nối mới
	B.session_closed = []
	var t_back := Time.get_ticks_msec()
	var back: bool = await B.reconnect(40.0)
	var reconnect_ms := Time.get_ticks_msec() - t_back
	if not check("%s_B_reconnected" % tag, back, {"closed_reason": B.closed_reason, "outage_s": (t_back - t_cut) / 1000.0}):
		return false
	await B.wait_until(func(): return not B.me().is_empty(), 3.0)
	await A.wait_until(func(): return A.player_of(aidB).get("mode", "") == "active", 5.0)
	await B.sleep(1.0)
	var ok := true
	if over:
		ok = check("%s_A_saw_B_disconnected_then_removed_after_grace" % tag, seen_disc >= 0 and seen_disc <= 3000
				and removed_at >= int((grace - 2.0) * 1000.0) and removed_at <= int((grace + 6.0) * 1000.0),
				{"disconnected_after_ms": seen_disc, "removed_after_ms": removed_at, "grace_s": grace, "modes_seen": modes.keys()}) and ok
		ok = check("%s_lease_released_and_escrow_to_inbox_before_return" % tag, int(lease_mid.get("active", 1)) == 0 and str(item_mid.get("state", "")) == "inbox",
				{"lease": lease_mid, "F2": item_mid}) and ok
	else:
		ok = check("%s_A_saw_B_disconnected_slot_kept" % tag, seen_disc >= 0 and seen_disc <= 3000 and removed_at < 0,
				{"disconnected_after_ms": seen_disc, "removed_after_ms": removed_at, "modes_seen": modes.keys()}) and ok
		ok = check("%s_lease_and_escrow_kept_during_grace" % tag, int(lease_mid.get("active", 0)) == 1 and str(item_mid.get("state", "")) == "escrow",
				{"lease": lease_mid, "F2": item_mid}) and ok
	var hb_span := 0.0
	if not hunger_b.is_empty():
		hb_span = float(hunger_b.max()) - float(hunger_b.min())
	ok = check("%s_B_hunger_frozen_while_disconnected" % tag, hunger_b.size() >= 2 and hb_span < 0.001,
			{"samples": hunger_b.size(), "B_span": hb_span, "B_at_cut": hunger0, "A_delta_same_time(active)": snappedf(a_h1 - a_h0, 0.01)}) and ok
	var p1: Vector3 = B.my_pos()
	var idx1: int = _player_index(A, aidB)
	var accepted: Dictionary = B.accepted_log[-1] if not B.accepted_log.is_empty() else {}
	if over:
		var sp := IslandLayout.spawn_point(B.island())
		ok = check("%s_B_rejoined_as_new_player_at_spawn" % tag, Vector2(p1.x - sp.x, p1.z - sp.z).length() <= 2.5 and _count_player(A, aidB) == 1
				and B.conn.room_id == room and String(B.me().get("mode", "")) == "active",
				{"pos": [snappedf(p1.x, 0.01), snappedf(p1.z, 0.01)], "spawn": [sp.x, sp.z], "pos_before": [snappedf(p0.x, 0.01), snappedf(p0.z, 0.01)], "reconnect_ms": reconnect_ms}) and ok
	else:
		ok = check("%s_B_same_room_same_position_and_slot" % tag, p1.distance_to(p0) <= 0.5 and idx1 == idx0 and _count_player(A, aidB) == 1
				and B.conn.room_id == room and String(B.me().get("mode", "")) == "active",
				{"moved_m": snappedf(p1.distance_to(p0), 0.01), "slot_index": [idx0, idx1], "players": A.snapshot.get("players", []).size(), "reconnect_ms": reconnect_ms}) and ok
	ok = check("%s_new_connection_new_lease_epoch" % tag, B.conn.connection_id != cid_old and int(B.conn.lease_epoch) == epoch_old + 1,
			{"epoch": [epoch_old, B.conn.lease_epoch], "accepted": accepted}) and ok
	# --- save sau khi vào lại (trước khi gửi lại lệnh đang bay): chỉ lệnh đã tới server được ghi, đúng một lần
	var s1: Dictionary = await B.server_save()
	var ops1: Array = committed_ops(await ops_since(aidB, row0))
	var eq_rows: Array = ops1.filter(func(x): return x["op_type"] == "equipment.equip")
	var esc_rows: Array = ops1.filter(func(x): return x["op_type"] == "inventory.recover_escrow")
	var want_eq := 1 if kind == "result_lost" else 0
	ok = check("%s_in_flight_command_applied_%s" % [tag, "once" if want_eq == 1 else "zero_times_before_resend"],
			eq_rows.size() == want_eq and (want_eq == 0 or str(eq_rows[0]["op_id"]) == op) and esc_rows.size() == (1 if over else 0)
			and int(s1["save_version"]) == int(s0["save_version"]) + ops1.size(),
			{"kind": kind, "committed_ops_since_cut": ops1.map(func(x): return x["op_type"]), "version": [s0["save_version"], s1["save_version"]]}) and ok
	if kind == "result_lost":
		# Chẩn đoán client web (game_session._pump_queue): khi gửi lại, expected_save_version được lấy lại từ bản xem ĐÃ làm mới
		# sau khi nối lại → payload khác lần đầu → backend trả OP_PAYLOAD_MISMATCH thay vì kết quả gốc (không nhân đôi, nhưng báo lỗi sai).
		var rcs: Dictionary = await B.durable_raw("equipment.equip", {"equipment_id": eq_to}, op, int(s1["save_version"]))
		var diag := {"cycle": tag, "resend_esv": int(s1["save_version"]), "original_esv": esv, "status": rcs.get("status"), "error": rcs.get("error_code")}
		result["client_style_resend"] = result.get("client_style_resend", []) + [diag]
		note("%s: gửi lại cùng op_id nhưng expected_save_version mới (như client web) → %s/%s" % [tag, str(rcs.get("status")), str(rcs.get("error_code"))])
	# gửi lại đúng lệnh cũ (cùng op_id + expected_save_version) như client thật sau khi nối lại
	var rr: Dictionary = await B.durable_raw("equipment.equip", {"equipment_id": eq_to}, op, esv)
	await B.sleep(0.5)
	var s2: Dictionary = await B.server_save()
	var ops2: Array = committed_ops(await ops_since(aidB, row0))
	var eq2: Array = ops2.filter(func(x): return x["op_type"] == "equipment.equip")
	ok = check("%s_resend_same_op_id_exactly_once" % tag, rr.get("status", "") == "committed" and eq2.size() == 1 and str(eq2[0]["op_id"]) == op
			and String(s2["inventory"]["equipped_id"]) == eq_to and int(s2["save_version"]) == int(s0["save_version"]) + ops2.size(),
			{"resend": rr.get("status"), "resend_error": rr.get("error_code"), "equip_ops_committed": eq2.size(), "version": [s0["save_version"], s1["save_version"], s2["save_version"]]}) and ok
	# túi / tiền / hộp thư: không đổi ngoài lệnh bay dở và (quá grace) F2 về inbox
	var bag0: Array = _uids(s0["inventory"]["bag"])
	var bag2: Array = _uids(s2["inventory"]["bag"])
	var inbox_ok: bool = (_uids(s2["inventory"]["recovery_inbox"]).count(f2) == 1) if over else (f2 not in _uids(s2["inventory"]["recovery_inbox"]))
	ok = check("%s_bag_money_intact%s" % [tag, "_F2_in_inbox_once" if over else "_F2_still_on_ground"], _money(s2) == _money(s0) and bag2 == bag0 and f1 in bag2
			and f2 not in bag2 and inbox_ok and _copies(s2, f2) == (1 if over else 0) and (B.entity(f2).is_empty() if over else not B.entity(f2).is_empty()),
			{"money": [_money(s0), _money(s2)], "bag": [bag0.size(), bag2.size()], "F2_copies_bag+inbox": _copies(s2, f2), "F2_in_world": not B.entity(f2).is_empty()}) and ok
	# giờ chơi (active_playtime_s) không cộng thời gian mất mạng (không thưởng AFK/offline)
	var pt_bound := (t_cut - t_s0) / 1000.0 + float(ContentDB.limit("checkpoint_interval_s", 15)) + 3.0
	var pt_delta := float(s1.get("active_playtime_s", 0.0)) - float(s0.get("active_playtime_s", 0.0))
	ok = check("%s_no_playtime_or_hunger_drain_while_offline" % tag, pt_delta <= pt_bound and absf(float(s1["player"]["hunger"]) - hunger0) < 0.6,
			{"playtime_delta_s": snappedf(pt_delta, 0.1), "bound_s": snappedf(pt_bound, 0.1), "outage_s": dur_s, "save_hunger": s1["player"]["hunger"], "hunger_at_cut": hunger0}) and ok
	# connection_id cũ (trên kết nối mới) → bị từ chối, không ghi gì
	var env := Protocol.make_envelope("equipment.equip", {"equipment_id": "rod_bamboo" if eq_to == "tool_slipper" else "tool_slipper", "op_id": Protocol.uuid4(),
		"expected_save_version": int(s2["save_version"])}, cid_old, B.conn.room_id, B.conn.seq + 1)
	B.conn.seq += 1
	B.conn.send_raw(JSON.stringify(env))
	await B.wait_until(func(): return B.results.has(env["request_id"]), 3.0)
	var rej: Dictionary = B.results.get(env["request_id"], {})
	var s3: Dictionary = await B.server_save()
	ok = check("%s_old_connection_id_rejected" % tag, rej.get("status", "") == "rejected" and str(rej.get("error_code", "")) == "INVALID_PAYLOAD"
			and int(s3["save_version"]) == int(s2["save_version"]), {"status": rej.get("status"), "error": rej.get("error_code")}) and ok
	# lease_epoch cũ (phiên room server cũ commit hộ) → backend chặn
	var cm: Dictionary = await ipc("commit", {"account_id": aidB, "lease_epoch": epoch_old, "room_id": room, "op_type": "equipment.equip",
		"payload": {"equipment_id": "rod_bamboo" if eq_to == "tool_slipper" else "tool_slipper"}, "expected_save_version": int(s3["save_version"])})
	var s4: Dictionary = await B.server_save()
	ok = check("%s_old_lease_epoch_commit_rejected" % tag, str(cm.get("result", {}).get("status", "")) == "rejected"
			and str(cm.get("result", {}).get("error_code", "")) == "SESSION_TAKEN_OVER" and int(s4["save_version"]) == int(s3["save_version"]),
			{"http": cm.get("http"), "result": cm.get("result"), "epoch_old": epoch_old, "epoch_now": B.conn.lease_epoch}) and ok
	await B.refresh_save()
	return ok


# ================================================================== WP-12 · NET-03 mất mạng không có FIN/RST (half-open)

## Mạng rớt thật (rút dây/wifi mất sóng): không gói nào qua lại, không FIN/RST. Proxy đóng băng kết nối của B.
## Hợp đồng: heartbeat_timeout_s → server phải coi B là mất kết nối (grace bắt đầu). Sau đó B mở kết nối mới trong khi
## kết nối cũ còn treo; khi mạng cũ thông lại, lệnh gửi trên kết nối cũ không được ghi và kết nối cũ bị đóng.
func sc_net_halfopen() -> bool:
	if bots.size() != 2:
		return check("net_halfopen_needs_2_bots", false, "--bots=2")
	if not bool(opts["via_proxy"]) or String(opts["ipc_dir"]) == "":
		return check("net_halfopen_needs_proxy", false, "chạy qua run_bots.py --proxy")
	var A = bots[0]
	var B = bots[1]
	var aidB: String = B.api.account_id
	var hb := float(ContentDB.limit("heartbeat_timeout_s", 15))
	mark("connect")
	await B.sleep(1.0)
	var rf: Dictionary = await ipc("proxy", {"op": "freeze", "account_id": aidB})
	var t0 := Time.get_ticks_msec()
	var seen := -1
	var timeline: Array = []
	var watch_s := float(opts["watch_s"]) if float(opts["watch_s"]) > 0.0 else hb + 10.0
	while Time.get_ticks_msec() - t0 < watch_s * 1000.0:
		var pl: Dictionary = A.player_of(aidB)
		var m: String = String(pl.get("mode", "gone"))
		if timeline.is_empty() or timeline[-1][1] != m:
			timeline.append([Time.get_ticks_msec() - t0, m])
		if m in ["disconnected", "gone"] and seen < 0:
			seen = Time.get_ticks_msec() - t0
		await A.sleep(0.5)
	var cs: Dictionary = await ipc("proxy", {"op": "conns"})
	var held := 0
	for c in cs.get("conns", []):
		if c.get("account_id", "") == aidB and c.get("state", "") == "frozen":
			held = int(c["s2c"]["queued"])
	var ok := check("halfopen_server_detects_dead_connection_within_heartbeat_timeout", rf.get("ok", false) and seen >= 0 and seen <= int((hb + 5.0) * 1000.0),
		{"detected_after_ms": seen, "heartbeat_timeout_s": hb, "watched_s": watch_s, "mode_timeline_ms": timeline,
		"B_client_thinks_live": B.conn.is_live(), "server_bytes_queued_for_B_at_proxy": held})
	mark("freeze_watch")
	# B (client thấy mất mạng) mở kết nối mới trong khi kết nối cũ vẫn treo
	var cid_old: String = B.conn.connection_id
	B.swap_connection()
	var back: bool = await B.connect_room()
	await A.wait_until(func(): return A.player_of(aidB).get("mode", "") == "active", 5.0)
	ok = check("halfopen_B_reconnects_on_new_connection_while_old_hangs", back and B.conn.connection_id != cid_old and _count_player(A, aidB) == 1
		and A.player_of(aidB).get("mode", "") == "active", {"closed_reason": B.closed_reason, "players_seen_by_A": A.snapshot.get("players", []).size()}) and ok
	# kết nối cũ gửi một lệnh bền vững (bị giữ ở proxy); rồi mạng cũ thông lại
	await B.refresh_save()
	var s1: Dictionary = await B.server_save()
	var eq_to := "rod_bamboo" if String(s1["inventory"]["equipped_id"]) == "tool_slipper" else "tool_slipper"
	var old_rid: String = B.old_conn.send("equipment.equip", {"equipment_id": eq_to, "op_id": Protocol.uuid4(), "expected_save_version": int(s1["save_version"])})
	await B.sleep(0.5)
	var rt: Dictionary = await ipc("proxy", {"op": "thaw", "account_id": aidB})
	await B.wait_until(func(): return B.old_conn.state == "closed", 10.0)
	await B.sleep(1.0)
	var s2: Dictionary = await B.server_save()
	var old_res: Dictionary = B.old_results.get(old_rid, {})
	ok = check("halfopen_old_connection_cannot_write", old_rid != "" and old_res.get("status", "") != "committed" and int(s2["save_version"]) == int(s1["save_version"])
		and String(s2["inventory"]["equipped_id"]) == String(s1["inventory"]["equipped_id"]),
		{"old_conn_result": old_res.get("status", "no_result"), "old_conn_error": old_res.get("error_code"), "version": [s1["save_version"], s2["save_version"]], "thaw": rt.get("conns")}) and ok
	ok = check("halfopen_old_connection_closed_when_network_returns", B.old_conn.state == "closed",
		{"old_conn_state": B.old_conn.state, "old_session_closed": B.old_session_closed, "old_closed_reason": B.old_closed_reason, "old_messages_delivered": B.old_messages}) and ok
	ok = check("halfopen_new_connection_unaffected", B.conn.is_live() and B.session_closed.is_empty(), {"session_closed": B.session_closed}) and ok
	return ok


# ================================================================== WP-12 · NET-05 cắt kết nối ngẫu nhiên, bot tự nối lại

## Mỗi bot: nhận dép → câu `rounds` con → bán hết ở sạp, qua proxy mạng xấu có cắt kết nối ngẫu nhiên (--cut-mean-s).
## Bot tự nối lại và gửi lại lệnh bền vững đang chờ bằng cùng op_id như client thật. Kiểm từ sổ op + save + DB:
## không mất giao dịch đã ack, không nhân đôi, tiền = tổng receipt, server không sập.
func sc_fish_net() -> bool:
	for b in bots:
		b.auto_reconnect = true
		if b.ping_interval <= 0.0:
			b.ping_interval = 2.0
	mark("connect")
	var res: Array = await all_bots(func(b): return await _fish_net_bot(b), float(opts["timeout"]) - 60.0)
	mark("fish_and_sell")
	var ok := true
	ok = check("fish_net_all_bots_caught_and_sold", _ok_all(res), res.map(func(r): return {"bot": r.get("bot"), "ok": r.get("ok"), "caught": r.get("caught", []).size(),
		"sold": r.get("sold", []).size(), "error": r.get("error", ""), "casts": r.get("casts")} if typeof(r) == TYPE_DICTIONARY else null)) and ok
	var bonus := int(ContentDB.balance["economy"]["first_catch_bonus"])
	var total_reconnects := 0
	for i in bots.size():
		var b = bots[i]
		var r: Dictionary = res[i] if typeof(res[i]) == TYPE_DICTIONARY else {}
		total_reconnects += b.reconnect_log.size()
		var sv: Dictionary = await b.server_save()
		var ops: Array = await ops_since(b.api.account_id, 0)
		var com: Array = committed_ops(ops)
		var want_money := 0
		var pickups: Array = []
		for o in com:
			var rec: Dictionary = o.get("receipt", {}) if typeof(o.get("receipt")) == TYPE_DICTIONARY else {}
			if o["op_type"] == "inventory.sell":
				want_money += int(rec.get("total", 0))
			elif o["op_type"] == "inventory.pickup":
				pickups.append(str(rec.get("item_uid", "")))
				if rec.get("new_species", false):
					want_money += bonus
		var states := {}
		for u in r.get("caught", []):
			var it: Dictionary = (await ipc("db", {"q": "item", "item_uid": u})).get("row", {})
			states[str(it.get("state", "?"))] = int(states.get(str(it.get("state", "?")), 0)) + 1
		var acked_all_sold: bool = states.get("sold", 0) == r.get("caught", []).size() and not r.get("caught", []).is_empty()
		var dup_pick: bool = pickups.size() != Array(pickups).reduce(func(acc, u): return acc if u in acc else acc + [u], []).size()
		ok = check("fish_net_bot%d_ledger_consistent_no_loss_no_dup" % i, _money(sv) == want_money and int(sv["save_version"]) == 1 + com.size()
			and acked_all_sold and not dup_pick and sv["inventory"]["bag"].filter(func(it): return it["def_kind"] == "creature").is_empty(),
			{"money": _money(sv), "money_from_ledger": want_money, "save_version": sv["save_version"], "committed_ops": com.size(), "caught_item_states": states,
			"reconnects": b.reconnect_log.size(), "resent_ops": b.resent_ops, "rtt_ms": b.rtt_stats()}) and ok
	var cuts: Dictionary = await ipc("proxy", {"op": "stats"})
	var ncuts: int = cuts.get("stats", {}).get("cuts", []).size()
	ok = check("fish_net_cuts_happened_and_bots_reconnected", ncuts > 0 and total_reconnects >= 1,
		{"proxy_cuts": ncuts, "bot_reconnects": total_reconnects}) and ok
	if bool(opts["cut_inflight"]):
		var resent := res.map(func(r): return int(r.get("sell_resends", 0)) if typeof(r) == TYPE_DICTIONARY else 0)
		ok = check("fish_net_sell_cut_in_flight_resent_same_op", resent.all(func(x): return x >= 1), {"sell_resends_per_bot": resent, "cuts": net_cut_log}) and ok
	var alive: Dictionary = await ipc("room", {"op": "alive"})
	ok = check("fish_net_room_server_alive", alive.get("alive", false)) and ok
	return ok


func _fish_net_bot(b) -> Dictionary:
	var out := {"ok": false, "bot": b.index, "caught": [], "sold": [], "casts": 0}
	for t in 3:
		await b.goto_npc("npc_co_ba")
		await b.talk("npc_co_ba")
		if await b.wait_until(func(): return "tool_slipper" in b.save["inventory"]["tools_owned"], 5.0):
			break
	if "tool_slipper" not in b.save["inventory"]["tools_owned"]:
		out["error"] = "không nhận được dép"
		return out
	for r in int(opts["rounds"]):
		var c: Dictionary = await b.catch_one([], 40)
		out["casts"] += int(c.get("casts", 0))
		if not c.get("ok", false):
			out["error"] = "câu: %s" % str(c.get("error", ""))
			return out
		out["caught"].append(c["uid"])
	var shop := IslandLayout.shop_zone(b.island())
	for t in 4:
		await b.goto_shop()
		await b.refresh_save()
		var uids: Array = []
		for it in b.save["inventory"]["bag"]:
			if it["def_kind"] == "creature":
				uids.append(it["uid"])
		if uids.is_empty():
			break
		if bool(opts["cut_inflight"]) and t == 0:
			# cắt kết nối ngay khi lệnh bán đang bay (qua proxy trễ ~75 ms/chiều): mất kết quả hoặc lệnh chưa tới server
			_cut_later(b, 0.05 + 0.04 * b.index, "bot%d_sell_in_flight" % b.index)
		var rs: Dictionary = await b.dur("inventory.sell", {"item_uids": uids, "shop_id": shop["shop_id"]})
		out["sell_status"] = rs.get("status", "")
		out["sell_resends"] = int(rs.get("resends", 0))
		if rs.get("status", "") == "committed":
			out["sold"] += uids
			break
		out["sell_error"] = rs.get("error_code")
	var sold_all := true
	for u in out["caught"]:
		sold_all = sold_all and u in out["sold"]
	out["ok"] = sold_all
	return out


# ================================================================== WP-12 · CONTENT-02 boss co-op nâng cao

func _boss_ctx(isl: String) -> Dictionary:
	var info := island_info(ContentDB.island_order.find(isl))
	var boss_id: String = info["boss_id"]
	var boss: Dictionary = ContentDB.bosses[boss_id]
	var spot := IslandLayout.boss_spot(isl)
	var post: Vector2 = spot["post"]
	var arena: Vector2 = spot["arena"]
	var dir := (arena - post).normalized()
	return {"info": info, "boss_id": boss_id, "boss": boss, "bait": boss["summon"]["bait_id"], "spot": spot, "post": post, "arena": arena,
		"dir": dir, "perp": Vector2(-dir.y, dir.x)}


func _hp_for(boss: Dictionary, n: int) -> int:
	var cre: Dictionary = ContentDB.creatures[boss["creature_id"]]
	return ceili(float(cre["hp"]) * (1.0 + float(boss["cooperative"]["hp_per_extra_player_mult"]) * (n - 1)))


func _to_post(b, bx: Dictionary) -> bool:
	return await b.nav_to(bx["post"] + bx["dir"] * 2.0 + bx["perp"] * (-1.5 + 1.0 * (b.index % 4)), 0.6, 60.0)


## Gọi boss bằng mồi của summoner. Trả {ok, encounter_id, uid, hp, max_hp}.
func _summon(summoner, bx: Dictionary) -> Dictionary:
	await _to_post(summoner, bx)
	var base: int = summoner.events.size()
	var rs: Dictionary = await summoner.dur("boss.summon", {"boss_id": bx["boss_id"], "zone_id": bx["spot"]["zone_id"]})
	if rs.get("status", "") != "committed":
		return {"ok": false, "status": rs.get("status"), "error": rs.get("error_code")}
	var rec: Dictionary = rs.get("receipt", {}) if typeof(rs.get("receipt")) == TYPE_DICTIONARY else {}
	await summoner.wait_until(func(): return not summoner.last_event("boss.summoned", "", base).is_empty(), 6.0)
	var ev: Dictionary = summoner.last_event("boss.summoned", "", base)
	if ev.is_empty():
		return {"ok": false, "error": "không có boss.summoned", "encounter_id": rec.get("encounter_id", "")}
	return {"ok": true, "encounter_id": str(rec.get("encounter_id", "")), "uid": ev["event_payload"]["creature_uid"],
		"hp": int(ev["event_payload"].get("hp", -1)), "max_hp": int(ev["event_payload"].get("max_hp", -1))}


## (c) thua vì cả nhóm rời bãi → hoàn mồi đúng một lần → gọi lại và thắng; (a) người vào phòng giữa trận: HP giữ mức chốt,
## vào muộn có đánh thì được thưởng, không đánh thì không; (b) một người rời phòng giữa trận (không thưởng), người gọi bị KO
## rồi hồi sinh trong bãi, trận vẫn tiếp tục, người còn lại thắng nhận đúng một lần. Kiểm bằng save + bảng reward_claims.
func sc_boss_coop() -> bool:
	if bots.size() != 4:
		return check("boss_coop_needs_4_bots", false, "--bots=4")
	if String(opts["ipc_dir"]) == "":
		return check("boss_coop_needs_runner", false, "chạy qua run_bots.py (đọc reward_claims/boss_attempts của DB test)")
	var B0 = bots[0]
	var B1 = bots[1]
	var B2 = bots[2]
	var B3 = bots[3]
	for b in bots:
		if not await b.register_and_login():
			return check("register", false)
	if not await B0.create_room():
		return check("create_room", false)
	var rj: Dictionary = await B1.join_by_code(B0.invite_code)
	var c0: bool = await B0.connect_room()
	var c1: bool = await B1.connect_room()
	if not check("B0_B1_in_room", rj["ok"] and c0 and c1, rj.get("error_code")):
		return false
	var pair: Array = [B0, B1]
	mark("connect")
	var prep: Array = await all_bots(func(b): return await island_prep(b, 0), 900.0, pair)
	var bx := _boss_ctx(B0.island())
	var bait: String = bx["bait"]
	var reward := int(bx["boss"]["reward_base_value"])
	var drop_id: String = bx["boss"]["drops"][0]["id"]
	var prep_ok := true
	for i in 2:
		prep_ok = check("bot%d_quest_prep_has_boss_bait" % i, typeof(prep[i]) == TYPE_DICTIONARY and prep[i].get("ok", false) and _bait(pair[i].save, bait) == 1,
			{"ok": prep[i].get("ok") if typeof(prep[i]) == TYPE_DICTIONARY else null, "bait": _bait(pair[i].save, bait), "error": prep[i].get("error", "") if typeof(prep[i]) == TYPE_DICTIONARY else ""}) and prep_ok
	mark("prep_2_bots")
	if not prep_ok:
		return false
	var want2 := _hp_for(bx["boss"], 2)
	var ok := true
	# ------------------------------------------------ E1: cả nhóm rời bãi → boss bỏ đi → hoàn mồi đúng một lần
	await all_bots(func(b): return await _to_post(b, bx), 90.0, pair)
	var sv0: Array = await all_bots(func(b): return await b.server_save(), 30.0, pair)
	var base1: int = B0.events.size()
	var e1: Dictionary = await _summon(B0, bx)
	if not check("e1_summoned", e1.get("ok", false), e1):
		return false
	var spawn2: Vector2 = IslandLayout.layout(B0.island())["spawn"].values()[0]
	await all_bots(func(b): return await b.nav_to(spawn2 + Vector2(-1.0 + 2.0 * b.index, 0.0), 1.0, 60.0), 90.0, pair)
	await B0.wait_until(func(): return not B0.last_event("boss.escaped", "", base1).is_empty(), 45.0)
	var esc: Dictionary = B0.last_event("boss.escaped", "", base1)
	await B0.wait_until(func(): return _bait(B0.save, bait) == 1, 10.0)
	await B0.sleep(1.5)
	var sv1: Array = await all_bots(func(b): return await b.server_save(), 30.0, pair)
	var att1: Dictionary = await _attempt(e1["encounter_id"])
	var cl1: Array = await _claims(e1["encounter_id"])
	ok = check("e1_hp_locked_for_2_players", e1["hp"] == want2 and e1["max_hp"] == want2, {"hp": e1["hp"], "max_hp": e1["max_hp"], "want": want2}) and ok
	ok = check("e1_group_left_arena_boss_escaped", esc.get("event_payload", {}).get("reason", "") == "abandoned", esc.get("event_payload")) and ok
	ok = check("e1_bait_refunded_exactly_once_to_summoner", _bait(sv0[0], bait) == 1 and _bait(sv1[0], bait) == 1 and str(att1.get("status", "")) == "refunded"
		and _claim_count(cl1, B0.api.account_id, "bait_refund") == 1 and cl1.size() == 1,
		{"bait_before_after": [_bait(sv0[0], bait), _bait(sv1[0], bait)], "attempt": att1.get("status"), "claims": cl1.map(func(x): return x["reward_kind"])}) and ok
	ok = check("e1_no_reward_on_loss", _money(sv1[0]) == _money(sv0[0]) and _money(sv1[1]) == _money(sv0[1]) and _bait(sv1[1], bait) == _bait(sv0[1], bait)
		and sv1[0]["progress"]["bosses_defeated"].is_empty() and sv1[1]["progress"]["bosses_defeated"].is_empty(),
		{"money": [[_money(sv0[0]), _money(sv1[0])], [_money(sv0[1]), _money(sv1[1])]]}) and ok
	mark("e1_abandon_refund")
	# ------------------------------------------------ E2: gọi lại (retry) bằng mồi đã hoàn → thắng, thưởng đúng một lần
	await all_bots(func(b): return await _to_post(b, bx), 90.0, pair)
	var bases2: Array = pair.map(func(b): return b.events.size())
	var e2: Dictionary = await _summon(B0, bx)
	if not check("e2_retry_summoned_with_refunded_bait", e2.get("ok", false), e2):
		return false
	var f2: Array = await all_bots(func(b): return await b.fight_boss(e2["uid"], bases2[b.index], 270.0), 300.0, pair)
	await all_bots(func(b): return await b.wait_until(func(): return bx["boss_id"] in b.save["progress"]["bosses_defeated"], 10.0), 20.0, pair)
	await B0.sleep(1.5)
	var sv2: Array = await all_bots(func(b): return await b.server_save(), 30.0, pair)
	var att2: Dictionary = await _attempt(e2["encounter_id"])
	var cl2: Array = await _claims(e2["encounter_id"])
	ok = check("e2_retry_defeated", f2.all(func(f): return typeof(f) == TYPE_DICTIONARY and f.get("result", "") == "defeated") and str(att2.get("status", "")) == "defeated",
		{"fights": f2.map(func(f): return f.get("result") if typeof(f) == TYPE_DICTIONARY else null), "attempt": att2.get("status")}) and ok
	for i in 2:
		var aid: String = pair[i].api.account_id
		ok = check("e2_bot%d_reward_exactly_once" % i, _money(sv2[i]) - _money(sv1[i]) == reward and _count_items(sv2[i], drop_id) - _count_items(sv1[i], drop_id) == 1
			and _claim_count(cl2, aid, "boss_reward") == 1,
			{"money_delta": _money(sv2[i]) - _money(sv1[i]), "drop_delta": _count_items(sv2[i], drop_id) - _count_items(sv1[i], drop_id), "claims": _claim_count(cl2, aid, "boss_reward")}) and ok
	ok = check("e2_bait_consumed_no_refund_on_win", _bait(sv2[0], bait) == 0 and _claim_count(cl2, B0.api.account_id, "bait_refund") == 0,
		{"bait": _bait(sv2[0], bait), "claims": cl2.map(func(x): return [x["account_id"].substr(0, 8), x["reward_kind"]])}) and ok
	mark("e2_retry_win")
	# ------------------------------------------------ E3: B1 gọi (2 người lúc bắt đầu) → B2, B3 vào phòng giữa trận
	await all_bots(func(b): return await _to_post(b, bx), 90.0, pair)
	var pre3: Array = []
	for b in bots:
		pre3.append(await b.server_save())
	var bases3: Array = pair.map(func(b): return b.events.size())
	var e3: Dictionary = await _summon(B1, bx)
	if not check("e3_summoned_by_B1", e3.get("ok", false), e3):
		return false
	var t_sum := Time.get_ticks_msec()
	ok = check("e3_hp_locked_for_2_players_at_start", e3["hp"] == want2 and e3["max_hp"] == want2, {"hp": e3["hp"], "want": want2}) and ok
	B1.boss_tank = true
	B0.boss_max_throws = 6
	var h0 := [null]
	var h1 := [null]
	var h2 := [null]
	var h3 := [null]
	_run_one(func(b): return await b.fight_boss(e3["uid"], bases3[0], 260.0), B0, 0, h0, [0])
	_run_one(func(b): return await b.fight_boss(e3["uid"], bases3[1], 260.0), B1, 0, h1, [0])
	# hai người vào phòng GIỮA TRẬN (tài khoản mới, chưa từng ở phòng): chờ boss đã mất máu rồi mới vào
	await B1.wait_until(func(): return B1.events_named("creature.damaged", bases3[1]).filter(func(e): return e["event_payload"].get("creature_uid", "") == e3["uid"]).size() >= 1, 30.0)
	var dmg_before_join: Array = B1.events_named("creature.damaged", bases3[1]).filter(func(e): return e["event_payload"].get("creature_uid", "") == e3["uid"])
	var hp_at_join: float = float(dmg_before_join[-1]["event_payload"].get("hp", -1)) if not dmg_before_join.is_empty() else -1.0
	var j2: Dictionary = await B2.join_by_code(B0.invite_code)
	var j3: Dictionary = await B3.join_by_code(B0.invite_code)
	var cj2: bool = await B2.connect_room()
	var cj3: bool = await B3.connect_room()
	await B1.wait_until(func(): return B1.snapshot.get("players", []).size() == 4, 5.0)
	ok = check("e3_two_players_joined_mid_fight", j2["ok"] and j3["ok"] and cj2 and cj3 and B1.snapshot.get("players", []).size() == 4 and hp_at_join > 0.0 and hp_at_join < float(want2),
		{"join": [j2.get("error_code"), j3.get("error_code")], "players": B1.snapshot.get("players", []).size(), "fight_age_s": (Time.get_ticks_msec() - t_sum) / 1000.0,
		"boss_hp_when_joining": hp_at_join, "max_hp": want2}) and ok
	await B2.wait_until(func(): return not B2.last_event("boss.summoned").is_empty(), 5.0)
	await B3.wait_until(func(): return not B3.last_event("boss.summoned").is_empty(), 5.0)
	var rs2: Dictionary = B2.last_event("boss.summoned")
	var rs3: Dictionary = B3.last_event("boss.summoned")
	# B3: vào bãi nhưng không đánh; B2: lấy dép ở Cô Ba rồi vào bãi đánh vài phát
	B3.boss_hold_fire = true
	_run_one(func(b): return await b.fight_boss(e3["uid"], 0, 250.0), B3, 0, h3, [0])
	_run_one(func(b):
		await b.goto_npc("npc_co_ba")
		await b.talk("npc_co_ba")
		await b.wait_until(func(): return "tool_slipper" in b.save["inventory"]["tools_owned"], 5.0)
		b.boss_max_throws = 6
		return await b.fight_boss(e3["uid"], 0, 240.0), B2, 0, h2, [0])
	# B0 đánh vài phát rồi RỜI PHÒNG giữa trận
	await B1.wait_until(func(): return B1.events_named("creature.damaged", bases3[1], B0.api.account_id).size() >= 1 and h0[0] == null, 40.0)
	await B0.sleep(1.0)
	var b0_hits: int = B1.events_named("creature.damaged", bases3[1], B0.api.account_id).size()
	B0.boss_stop = true
	await B0.wait_until(func(): return h0[0] != null, 5.0)
	var left: bool = await B0.leave_room()
	await B1.wait_until(func(): return _count_player(B1, B0.api.account_id) == 0, 5.0)
	ok = check("e3_B0_hit_then_left_room_mid_fight", b0_hits >= 1 and left and _count_player(B1, B0.api.account_id) == 0,
		{"B0_hits": b0_hits, "left": left, "B0_session_closed": B0.session_closed}) and ok
	# chờ B1 (người gọi, đứng sát boss) bị KO rồi hồi sinh; B2 có đóng góp
	var ko_ok: bool = await B1.wait_until(func(): return not B1.last_event("player.knocked_out", B1.api.account_id, bases3[1]).is_empty(), maxf(5.0, 110.0 - (Time.get_ticks_msec() - t_sum) / 1000.0))
	B1.boss_tank = false
	B1.boss_hold_fire = true
	await B1.wait_until(func(): return not B1.last_event("player.respawned", B1.api.account_id, bases3[1]).is_empty(), 10.0)
	var resp: Dictionary = B1.last_event("player.respawned", B1.api.account_id, bases3[1])
	await B1.wait_until(func(): return B1.events_named("creature.damaged", bases3[1], B2.api.account_id).size() >= 1, 60.0)
	var boss_alive_after_ko: bool = not B1.entity(e3["uid"]).is_empty()
	# thả cho B1 + B2 hạ boss
	B1.boss_hold_fire = false
	B2.boss_max_throws = -1
	await B1.wait_until(func(): return h1[0] != null and h2[0] != null and h3[0] != null, 240.0)
	await all_bots(func(b): return await b.wait_until(func(): return bx["boss_id"] in b.save["progress"]["bosses_defeated"], 10.0), 20.0, [B1, B2])
	await B1.sleep(2.0)
	var post3: Array = []
	for b in bots:
		post3.append(await b.server_save())
	var cl3: Array = await _claims(e3["encounter_id"])
	var att3: Dictionary = await _attempt(e3["encounter_id"])
	var dmg_max_hp: Array = []
	for ev in B1.events_named("creature.damaged", bases3[1]):
		if ev["event_payload"].get("creature_uid", "") == e3["uid"]:
			var mh := int(ev["event_payload"].get("max_hp", -1))
			if mh not in dmg_max_hp:
				dmg_max_hp.append(mh)
	ok = check("e3_late_joiners_see_locked_hp_no_rescale", int(rs2.get("event_payload", {}).get("max_hp", -1)) == want2 and int(rs3.get("event_payload", {}).get("max_hp", -1)) == want2
		and dmg_max_hp == [want2], {"resync_max_hp": [rs2.get("event_payload", {}).get("max_hp"), rs3.get("event_payload", {}).get("max_hp")], "damage_events_max_hp": dmg_max_hp,
		"want": want2, "hp_if_rescaled_for_4": _hp_for(bx["boss"], 4)}) and ok
	var res1: String = h1[0].get("result", "?") if typeof(h1[0]) == TYPE_DICTIONARY else "null"
	ok = check("e3_defeated_after_leave_ko_and_late_join", res1 == "defeated" and str(att3.get("status", "")) == "defeated",
		{"B1": res1, "B2": h2[0].get("result") if typeof(h2[0]) == TYPE_DICTIONARY else null, "B3": h3[0].get("result") if typeof(h3[0]) == TYPE_DICTIONARY else null, "attempt": att3.get("status")}) and ok
	ok = check("e3_summoner_KO_respawned_in_arena_fight_continued", ko_ok and not resp.is_empty() and str(resp.get("event_payload", {}).get("spawn_zone_id", "")) == str(bx["spot"]["zone_id"])
		and boss_alive_after_ko, {"ko": ko_ok, "respawn_zone": resp.get("event_payload", {}).get("spawn_zone_id"), "boss_alive_after_ko": boss_alive_after_ko}) and ok
	var roles := [["B0_left_room", B0, 0, 0], ["B1_summoner", B1, 1, 1], ["B2_late_with_damage", B2, 2, 1], ["B3_late_no_damage", B3, 3, 0]]
	for rl in roles:
		var b = rl[1]
		var k: int = rl[2]
		var want_n: int = rl[3]
		var dm := _money(post3[k]) - _money(pre3[k])
		var dd := _count_items(post3[k], drop_id) - _count_items(pre3[k], drop_id)
		var hits: int = B1.events_named("creature.damaged", bases3[1], b.api.account_id).size()
		var ncl := _claim_count(cl3, b.api.account_id, "boss_reward")
		ok = check("e3_%s_reward_%s" % [rl[0], "exactly_once" if want_n == 1 else "none"], dm == reward * want_n and dd == want_n and ncl == want_n
			and (hits > 0 if k in [0, 2] else true) and (hits == 0 if k == 3 else true),
			{"money_delta": dm, "drop_delta": dd, "claims": ncl, "hits_seen": hits}) and ok
	ok = check("e3_bait_consumed_once_no_refund", _bait(post3[1], bait) == 0 and _claim_count(cl3, B1.api.account_id, "bait_refund") == 0 and cl3.size() == 2,
		{"bait": _bait(post3[1], bait), "claims": cl3.map(func(x): return [x["account_id"].substr(0, 8), x["reward_kind"]])}) and ok
	# nhìn lại E1/E2: không có thưởng/hoàn trễ nào phát sinh
	var cl1b: Array = await _claims(e1["encounter_id"])
	var cl2b: Array = await _claims(e2["encounter_id"])
	ok = check("earlier_encounters_unchanged", cl1b.size() == 1 and cl2b.size() == 2, {"e1": cl1b.size(), "e2": cl2b.size()}) and ok
	mark("e3_late_join_leave_ko")
	return ok


# ================================================================== WP-12 · SAVE-03 phần room: giết room server

## SIGKILL room server (tiến trình do runner tạo) (1) giữa trận boss, (2) ngay sau khi gửi lệnh bán, (3) ngay sau khi thả đồ;
## bật lại, bot nối lại. Kiểm: lệnh đã ack còn nguyên; mồi của trận mồ côi được vòng dọn backend (maintenance_once, P-027)
## hoàn đúng một lần (lùi created_at trong DB TEST để khỏi chờ 15 phút); gọi lại được và thắng; bán đúng một lần.
func sc_room_kill_boss() -> bool:
	if bots.size() != 2:
		return check("room_kill_boss_needs_2_bots", false, "--bots=2")
	if String(opts["ipc_dir"]) == "":
		return check("room_kill_boss_needs_runner", false, "chạy qua run_bots.py")
	var B0 = bots[0]
	var B1 = bots[1]
	mark("connect")
	var prep: Array = await all_bots(func(b): return await island_prep(b, 0), 900.0)
	var bx := _boss_ctx(B0.island())
	var bait: String = bx["bait"]
	var giver: String = bx["info"]["giver"]
	if not check("prep_quest_both_have_bait", _ok_all(prep) and _bait(B0.save, bait) == 1, prep.map(func(p): return p.get("ok") if typeof(p) == TYPE_DICTIONARY else null)):
		return false
	var fish: Array = []
	for k in 2:
		var c: Dictionary = await B1.catch_one([], 30)
		if c.get("ok", false):
			fish.append(c["uid"])
	if not check("B1_caught_two_fish_for_sell_and_drop", fish.size() == 2, fish.size()):
		return false
	mark("prep")
	var ok := true
	# ------------------------------------------------ 1) SIGKILL giữa trận boss
	await all_bots(func(b): return await _to_post(b, bx), 90.0)
	var bases: Array = bots.map(func(b): return b.events.size())
	var e1: Dictionary = await _summon(B0, bx)
	if not check("kill1_boss_summoned", e1.get("ok", false), e1):
		return false
	var hold := [[null], [null]]
	for b in bots:
		b.boss_stop = false
		b.boss_max_throws = 6
		_run_one(func(x): return await x.fight_boss(e1["uid"], bases[x.index], 200.0), b, 0, hold[b.index], [0])
	await B0.wait_until(func(): return B0.events_named("creature.damaged", bases[0]).filter(func(e): return e["event_payload"].get("creature_uid", "") == e1["uid"]).size() >= 3, 30.0)
	var dmg_ev: Array = B0.events_named("creature.damaged", bases[0]).filter(func(e): return e["event_payload"].get("creature_uid", "") == e1["uid"])
	var hp_at_kill: float = float(dmg_ev[-1]["event_payload"].get("hp", -1)) if not dmg_ev.is_empty() else -1.0
	var pre: Array = []
	for b in bots:
		pre.append(await b.server_save())
	var rk: Dictionary = await ipc("room", {"op": "kill"})
	for b in bots:
		b.boss_stop = true
	await all_bots(func(b): return await b.wait_until(func(): return not b.conn.is_live(), 10.0), 15.0)
	var rs: Dictionary = await ipc("room", {"op": "start"})
	var back: Array = await all_bots(func(b):
		b.session_closed = []
		return await b.reconnect(60.0), 90.0)
	ok = check("kill1_room_server_sigkilled_mid_boss_and_restarted", rk.get("ok", false) and rs.get("ok", false) and back.all(func(x): return x == true)
		and hp_at_kill > 0.0 and hp_at_kill < float(e1["max_hp"]), {"kill": rk, "start_s": rs.get("startup_s"), "reconnected": back, "boss_hp_at_kill": hp_at_kill, "max_hp": e1["max_hp"]}) and ok
	mark("kill_mid_boss")
	for b in bots:
		b.boss_stop = false
		b.boss_max_throws = -1
	await B0.sleep(2.0)
	var post: Array = []
	for b in bots:
		post.append(await b.server_save())
	var intact := true
	for i in 2:
		intact = intact and _money(post[i]) == _money(pre[i]) and int(post[i]["save_version"]) == int(pre[i]["save_version"]) and _uids(post[i]["inventory"]["bag"]) == _uids(pre[i]["inventory"]["bag"])
	ok = check("kill1_acked_state_intact_after_crash", intact, {"version": [[pre[0]["save_version"], post[0]["save_version"]], [pre[1]["save_version"], post[1]["save_version"]]]}) and ok
	var boss_ent := false
	for e in B0.snapshot.get("entities", []):
		if e["kind"] == "boss":
			boss_ent = true
	var att: Dictionary = await _attempt(e1["encounter_id"])
	var cl0: Array = await _claims(e1["encounter_id"])
	ok = check("kill1_encounter_orphaned_open_bait_spent_no_reward", not boss_ent and str(att.get("status", "")) == "open" and _bait(post[0], bait) == 0 and cl0.is_empty(),
		{"boss_in_new_room": boss_ent, "attempt": att.get("status"), "bait": _bait(post[0], bait), "claims": cl0.size()}) and ok
	# Không được xin lại mồi khi trận mồ côi còn mở (tránh vừa được cấp lại vừa được hoàn)
	await B0.goto_npc(giver)
	await B0.talk(giver)
	await B0.sleep(1.0)
	var sv_r: Dictionary = await B0.server_save()
	ok = check("kill1_no_refill_while_orphan_open", _bait(sv_r, bait) == 0, {"bait": _bait(sv_r, bait)}) and ok
	# Vòng dọn backend (P-027): trận còn mới → chưa đụng; lùi created_at trong DB TEST → hoàn đúng một lần; chạy lại → 0
	var m0: Dictionary = await ipc("maintenance")
	var ag: Dictionary = await ipc("age_boss_attempt", {"encounter_id": e1["encounter_id"], "seconds": 1000})
	var m1: Dictionary = await ipc("maintenance")
	var m2: Dictionary = await ipc("maintenance")
	var sv_m: Dictionary = await B0.server_save()
	var att_m: Dictionary = await _attempt(e1["encounter_id"])
	var cl_m: Array = await _claims(e1["encounter_id"])
	ok = check("kill1_orphan_bait_refunded_exactly_once_by_maintenance", int(m0.get("result", {}).get("refunded", -1)) == 0 and int(ag.get("updated", 0)) == 1
		and int(m1.get("result", {}).get("refunded", -1)) == 1 and int(m2.get("result", {}).get("refunded", -1)) == 0 and _bait(sv_m, bait) == 1
		and str(att_m.get("status", "")) == "refunded" and _claim_count(cl_m, B0.api.account_id, "bait_refund") == 1 and cl_m.size() == 1,
		{"maint_before_age": m0.get("result"), "aged_rows": ag.get("updated"), "maint_1": m1.get("result"), "maint_2": m2.get("result"), "bait": _bait(sv_m, bait),
		"attempt": att_m.get("status"), "claims": cl_m.map(func(x): return x["reward_kind"])}) and ok
	mark("maintenance_refund")
	# gọi lại bằng mồi được hoàn → thắng → thưởng đúng một lần
	await B0.refresh_save()
	await all_bots(func(b): return await _to_post(b, bx), 90.0)
	var s_pre2: Array = []
	for b in bots:
		s_pre2.append(await b.server_save())
	var bases2: Array = bots.map(func(b): return b.events.size())
	var e2: Dictionary = await _summon(B0, bx)
	var f2: Array = []
	if e2.get("ok", false):
		f2 = await all_bots(func(b): return await b.fight_boss(e2["uid"], bases2[b.index], 270.0), 300.0)
	await all_bots(func(b): return await b.wait_until(func(): return bx["boss_id"] in b.save["progress"]["bosses_defeated"], 10.0), 20.0)
	await B0.sleep(1.5)
	var cl2: Array = await _claims(e2.get("encounter_id", ""))
	var s_post2: Array = []
	for b in bots:
		s_post2.append(await b.server_save())
	var rw_ok := true
	for i in 2:
		rw_ok = rw_ok and _money(s_post2[i]) - _money(s_pre2[i]) == int(bx["boss"]["reward_base_value"]) and _claim_count(cl2, bots[i].api.account_id, "boss_reward") == 1
	var cl_e1_after: Array = await _claims(e1["encounter_id"])
	ok = check("kill1_retry_after_refund_defeated_reward_once", e2.get("ok", false) and f2.all(func(f): return typeof(f) == TYPE_DICTIONARY and f.get("result", "") == "defeated") and rw_ok
		and _bait(s_post2[0], bait) == 0 and cl_e1_after.size() == 1,
		{"summon": e2.get("ok"), "fights": f2.map(func(f): return f.get("result") if typeof(f) == TYPE_DICTIONARY else null),
		"money_delta": [_money(s_post2[0]) - _money(s_pre2[0]), _money(s_post2[1]) - _money(s_pre2[1])], "claims_e2": cl2.size(), "claims_e1": cl_e1_after.size()}) and ok
	mark("retry_win")
	# ------------------------------------------------ 2) SIGKILL ngay sau khi gửi lệnh bán (giao dịch có thể đang bay)
	await B1.goto_shop()
	await B1.refresh_save()
	var sv_s: Dictionary = await B1.server_save()
	var sell_uid: String = fish[0]
	var value := 0
	for it in sv_s["inventory"]["bag"]:
		if it["uid"] == sell_uid:
			value = int(it["base_value"]) * int(it["trick_mult_milli"]) / 1000
	var shop := IslandLayout.shop_zone(B1.island())
	var sell := {"item_uids": [sell_uid], "shop_id": shop["shop_id"]}
	var opS := Protocol.uuid4()
	var esvS: int = int(sv_s["save_version"])
	var row_s: int = await op_rowid()
	var plS := sell.duplicate()
	plS["op_id"] = opS
	plS["expected_save_version"] = esvS
	var ridS: String = B1.conn.send("inventory.sell", plS)
	var rk2: Dictionary = await ipc("room", {"op": "kill"})
	var first_res: Dictionary = B1.results.get(ridS, {})
	await all_bots(func(b): return await b.wait_until(func(): return not b.conn.is_live(), 10.0), 15.0)
	var rs2: Dictionary = await ipc("room", {"op": "start"})
	var back2: Array = await all_bots(func(b):
		b.session_closed = []
		return await b.reconnect(60.0), 90.0)
	await B1.goto_shop()
	var rr: Dictionary = await B1.durable_raw("inventory.sell", sell, opS, esvS)
	var sv_s2: Dictionary = await B1.server_save()
	var sells: Array = (await ops_since(B1.api.account_id, row_s)).filter(func(x): return x["op_type"] == "inventory.sell" and x["op_id"] == opS)
	ok = check("kill2_sell_during_room_crash_exactly_once", rk2.get("ok", false) and back2.all(func(x): return x == true) and rr.get("status", "") == "committed"
		and _money(sv_s2) == _money(sv_s) + value and sell_uid not in _uids(sv_s2["inventory"]["bag"]) and sells.size() == 1,
		{"first_result_before_kill": first_res.get("status", "no_result"), "resend": rr.get("status"), "resend_error": rr.get("error_code"),
		"money": [_money(sv_s), _money(sv_s2)], "value": value, "ledger_rows_for_op": sells.size()}) and ok
	var rs3: Dictionary = await B1.dur("inventory.sell", sell)
	var sv_s3: Dictionary = await B1.server_save()
	ok = check("kill2_sell_again_new_op_rejected", rs3.get("status", "") == "rejected" and _money(sv_s3) == _money(sv_s2), {"status": rs3.get("status"), "error": rs3.get("error_code")}) and ok
	mark("kill_mid_sell")
	# ------------------------------------------------ 3) SIGKILL ngay sau khi thả đồ xuống đất (escrow)
	var drop_uid: String = fish[1]
	var dr: Dictionary = await B1.dur("inventory.drop", {"item_uid": drop_uid})
	await B1.wait_until(func(): return not B1.entity(drop_uid).is_empty(), 3.0)
	var seen_before: bool = not B1.entity(drop_uid).is_empty()
	var rk3: Dictionary = await ipc("room", {"op": "kill"})
	await all_bots(func(b): return await b.wait_until(func(): return not b.conn.is_live(), 10.0), 15.0)
	var rs4: Dictionary = await ipc("room", {"op": "start"})
	var back3: Array = await all_bots(func(b):
		b.session_closed = []
		return await b.reconnect(60.0), 90.0)
	await B1.sleep(2.0)
	var it_db: Dictionary = (await ipc("db", {"q": "item", "item_uid": drop_uid})).get("row", {})
	var sv_d: Dictionary = await B1.server_save()
	var visible: bool = not B1.entity(drop_uid).is_empty()
	var in_inbox: bool = drop_uid in _uids(sv_d["inventory"]["recovery_inbox"])
	ok = check("kill3_dropped_item_visible_or_in_inbox_after_room_crash", dr.get("status", "") == "committed" and seen_before and back3.all(func(x): return x == true)
		and (visible or in_inbox), {"db_state": it_db.get("state"), "visible_in_world": visible, "in_recovery_inbox": in_inbox, "kill": rk3.get("ok"), "start": rs4.get("ok")}) and ok
	# dù không thấy trên đất, đồ không mất/không nhân đôi: nhặt theo UID (như client gửi lại) ra đúng một bản
	var pk: Dictionary = await B1.dur("inventory.pickup", {"item_uid": drop_uid})
	var sv_d2: Dictionary = await B1.server_save()
	ok = check("kill3_dropped_item_not_lost_not_duplicated", pk.get("status", "") == "committed" and _copies(sv_d2, drop_uid) == 1,
		{"pickup": pk.get("status"), "error": pk.get("error_code"), "copies": _copies(sv_d2, drop_uid), "db_state_before": it_db.get("state")}) and ok
	mark("kill_after_drop")
	return ok


# ================================================================== WP-12 · NET-04 chủ phòng rời / menu / AFK

func sc_owner_leave() -> bool:
	if bots.size() < 3:
		return check("owner_leave_needs_3_bots", false, "--bots=3")
	var O = bots[0]
	var B1 = bots[1]
	var B2 = bots[2]
	var room: String = O.room_id
	mark("connect")
	var ok := true
	var r0: Dictionary = await ipc("db", {"q": "room", "room_id": room})
	ok = check("initial_owner_is_creator", str(r0.get("row", {}).get("owner_account_id", "")) == O.api.account_id, r0.get("row")) and ok
	# ------------------------------------------------ 1) chủ phòng mở menu: người khác vẫn chơi, chỉ chủ phòng dừng
	O.command("menu.active", {"active": true})
	await B1.wait_until(func(): return B1.player_of(O.api.account_id).get("mode", "") == "menu", 5.0)
	var t_m := Time.get_ticks_msec()
	var tick0 := int(B1.snapshot.get("server_tick", 0))
	var o_h0 := float(B1.player_of(O.api.account_id).get("hunger", -1.0))
	var b1_h0 := float(B1.me().get("hunger", -1.0))
	var p1_0: Vector3 = B1.my_pos()
	var p2_0: Vector3 = B2.my_pos()
	var rid: String = O.command("fishing.action", {"action": "charge_start", "aim_direction": [0, 0, 1]})
	await O.wait_until(func(): return O.results.has(rid), 3.0)
	var o_rej: Dictionary = O.results.get(rid, {})
	await all_bots(func(b):
		if b.index == 1:
			return await b.goto_shop()
		return await b.goto_npc("npc_ong_tu"), 60.0, [B1, B2])
	while Time.get_ticks_msec() - t_m < 25000:
		await B1.sleep(0.5)
	var o_h1 := float(B1.player_of(O.api.account_id).get("hunger", -1.0))
	var b1_h1 := float(B1.me().get("hunger", -1.0))
	var tick1 := int(B1.snapshot.get("server_tick", 0))
	var secs := (Time.get_ticks_msec() - t_m) / 1000.0
	ok = check("menu_does_not_pause_others", B1.my_pos().distance_to(p1_0) > 3.0 and B2.my_pos().distance_to(p2_0) > 3.0 and (tick1 - tick0) >= int(secs * 30.0 * 0.8),
		{"B1_moved_m": snappedf(B1.my_pos().distance_to(p1_0), 0.1), "B2_moved_m": snappedf(B2.my_pos().distance_to(p2_0), 0.1), "server_ticks": tick1 - tick0, "seconds": snappedf(secs, 0.1)}) and ok
	ok = check("menu_pauses_only_that_players_hunger_and_gameplay", absf(o_h1 - o_h0) < 0.001 and b1_h1 < b1_h0 and str(o_rej.get("error_code", "")) == "PLAYER_INACTIVE",
		{"owner_hunger": [o_h0, o_h1], "B1_hunger": [b1_h0, b1_h1], "owner_fishing_in_menu": o_rej.get("error_code")}) and ok
	O.command("menu.active", {"active": false})
	await O.sleep(0.5)
	mark("menu")
	# ------------------------------------------------ 2) chủ phòng rời phòng → chủ chuyển cho người vào sớm nhất còn lại
	var n_rc1: int = B1.room_changed.size()
	var left: bool = await O.leave_room()
	await B1.wait_until(func(): return B1.room_changed.size() > n_rc1 and str(B1.room_changed[-1].get("owner_account_id", "")) != O.api.account_id, 5.0)
	var rc: Dictionary = B1.room_changed[-1] if not B1.room_changed.is_empty() else {}
	var rc2: Dictionary = B2.room_changed[-1] if not B2.room_changed.is_empty() else {}
	ok = check("owner_left_room_transferred_to_next_member", left and str(rc.get("owner_account_id", "")) == B1.api.account_id and str(rc2.get("owner_account_id", "")) == B1.api.account_id
		and O.api.account_id not in rc.get("members", []), {"left": left, "owner_seen_by_B1": str(rc.get("owner_account_id", "")).substr(0, 8), "B1": B1.api.account_id.substr(0, 8),
		"members": rc.get("members", []).size()}) and ok
	var tk0 := int(B1.snapshot.get("server_tick", 0))
	await B1.sleep(4.0)
	var tk1 := int(B1.snapshot.get("server_tick", 0))
	var eq: Dictionary = await B2.dur("equipment.equip", {"equipment_id": "rod_bamboo"})
	var r1: Dictionary = await ipc("db", {"q": "room", "room_id": room})
	var lo: Dictionary = await ipc("db", {"q": "lease", "account_id": O.api.account_id})
	ok = check("room_keeps_running_after_owner_left", tk1 - tk0 >= 90 and B1.snapshot.get("players", []).size() == 2 and eq.get("status", "") == "committed",
		{"ticks_in_4s": tk1 - tk0, "players": B1.snapshot.get("players", []).size(), "durable_after": eq.get("status")}) and ok
	ok = check("backend_room_owner_updated_and_leaver_lease_released", str(r1.get("row", {}).get("owner_account_id", "")) == B1.api.account_id
		and str(r1.get("row", {}).get("status", "")) == "ready" and int(lo.get("row", {}).get("active", 1)) == 0,
		{"room": r1.get("row"), "leaver_lease": lo.get("row"), "session_closed": O.session_closed}) and ok
	mark("owner_leave")
	# ------------------------------------------------ 3) AFK: đứng im quá afk_timeout_s → "afk", độ no dừng; cử động → active
	if bool(opts["afk"]):
		var afk_s := float(ContentDB.limit("afk_timeout_s", 120))
		B2.keepalive = false
		B2.move = Vector2.ZERO
		# một cử động có nghĩa để đồng hồ AFK của server bắt đầu đúng từ đây (keepalive/đi lại trước đó làm lệch)
		B2.yaw += 0.3
		await B2.sleep(0.4)
		var t_a := Time.get_ticks_msec()
		var afk_at := [-1]
		var h_afk: Array = []
		var tl: Array = []
		while Time.get_ticks_msec() - t_a < (afk_s + 15.0) * 1000.0:
			var pl: Dictionary = B1.player_of(B2.api.account_id)
			var m: String = str(pl.get("mode", "gone"))
			if tl.is_empty() or tl[-1][1] != m:
				tl.append([Time.get_ticks_msec() - t_a, m])
			if m == "afk":
				if afk_at[0] < 0:
					afk_at[0] = Time.get_ticks_msec() - t_a
				h_afk.append(float(pl.get("hunger", -1.0)))
			await B1.sleep(0.5)
		B2.keepalive = true
		B2.yaw += 0.6
		await B1.wait_until(func(): return B1.player_of(B2.api.account_id).get("mode", "") == "active", 5.0)
		var span := 0.0
		if not h_afk.is_empty():
			span = float(h_afk.max()) - float(h_afk.min())
		ok = check("afk_after_timeout_hunger_paused_back_on_input", afk_at[0] >= int((afk_s - 2.0) * 1000.0) and afk_at[0] <= int((afk_s + 5.0) * 1000.0) and h_afk.size() >= 4
			and span < 0.001 and B1.player_of(B2.api.account_id).get("mode", "") == "active",
			{"afk_after_ms": afk_at[0], "afk_timeout_s": afk_s, "hunger_samples_afk": h_afk.size(), "hunger_span": span, "timeline_ms": tl}) and ok
		mark("afk")
	return ok
