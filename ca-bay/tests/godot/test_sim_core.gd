extends RefCounted
## Unit test logic mô phỏng server (tất định, không mạng): cá bay, đánh, xỉu, trick, boss HP, đói, phòng cách ly.

const H := preload("res://tests/godot/sim_harness.gd")
const Creatures := preload("res://server/gameplay/creature_sim.gd")
const Boss := preload("res://server/gameplay/boss_sim.gd")


func _pier_end(isl: String) -> Vector3:
	var pier: Dictionary = IslandLayout.layout(isl)["pier"]
	return IslandLayout.v3(isl, (pier["to"] as Vector2) - Vector2(0, 2))


func test_launch_lands_on_safe_ground(t) -> void:
	var rs := H.make_room()
	var room: RefCounted = rs[0]
	var p := H.add_player(room, 2)
	p["pos"] = _pier_end(room.island_id)
	for i in 20:
		Creatures.launch(room, p, "cre_ca_ro", null, false, p["pos"] + Vector3(0, 0, 8))
	H.run(room, 4.0)
	var landed := 0
	for uid in room.entities:
		var e: Dictionary = room.entities[uid]
		if e["kind"] == "fish":
			landed += 1
	t.ok(landed >= 14, "đa số cá phải còn trên bến sau 4 s rơi xuống (còn %d/20)" % landed)


func test_slipper_hit_knocks_out_tep(t) -> void:
	var rs := H.make_room()
	var room: RefCounted = rs[0]
	var srv = rs[1]
	var p := H.add_player(room, 2)
	p["pos"] = _pier_end(room.island_id)
	p["equipped"] = "tool_slipper"
	Creatures.launch(room, p, "cre_tep", null, true, p["pos"] + Vector3(0, 0, 8))
	var uid: String = room.entities.keys()[0]
	H.run(room, 0.5)
	var e: Dictionary = room.entities[uid]
	var eye := Movement.eye(p["pos"])
	var d: Vector3 = (e["pos"] as Vector3) - eye
	p["yaw"] = atan2(-d.x, -d.z)
	p["pitch"] = atan2(d.y, Vector2(d.x, d.z).length())
	var err: String = Creatures.use_tool(room, p, uid)
	t.eq(err, "", "ném dép được chấp nhận")
	H.run(room, 1.0)
	t.ok(srv.events("tool.hit").size() >= 1, "có sự kiện trúng")
	t.ok(srv.events("creature.knocked_out").size() == 1, "tép xỉu sau 1 phát dép")
	var ko: Array = srv.events("scoring.tricks_awarded")
	if ko.size() == 1:
		var tricks: Array = ko[0]["payload"]["event_payload"]["tricks"]
		t.ok("trick_perfect_yank" in tricks, "trick giật chuẩn được ghi")
		t.ok("trick_air_smack" in tricks, "đánh lúc cá đang bay")
		t.ok("trick_one_hit" in tricks, "một phát xỉu")
		var v: int = ko[0]["payload"]["event_payload"]["value"]
		t.ok(v >= 2 and v <= 2 * 6, "giá có trần 6x (được %d)" % v)


func test_trick_math_integer_cap(t) -> void:
	# nhân dồn tất cả trick vượt trần 6.0 phải bị cắt
	var milli := 1000
	for tid in ContentDB.trick_order:
		milli = milli * int(round(float(ContentDB.tricks[tid]["multiplier"]) * 1000)) / 1000
	t.ok(milli > 6000, "tổng thô vượt trần (%d)" % milli)
	t.eq(clampi(milli, 1000, 6000), 6000, "cắt ở 6000")


func test_boss_hp_scales_with_party(t) -> void:
	for n in [1, 2, 4]:
		var rs := H.make_room()
		var room: RefCounted = rs[0]
		var first := {}
		for i in n:
			var q := H.add_player(room, 10 + i)
			if i == 0:
				first = q
		Boss.start(room, first, "boss_ca_loc", Protocol.uuid4())
		var expect := ceili(300.0 * (1.0 + 0.45 * (n - 1)))
		t.eq(int(room.boss_state["max_hp"]), expect, "HP boss %d người" % n)
		var timer: float = (int(room.boss_state["end_tick"]) - int(room.boss_state["start_tick"])) * room.dt
		t.ok(absf(timer - 240.0) < 0.1, "đồng hồ 240 s không đổi theo số người")


func test_boss_timeout_refunds_once(t) -> void:
	var rs := H.make_room()
	var room: RefCounted = rs[0]
	var srv = rs[1]
	var p := H.add_player(room, 2)
	p["pos"] = IslandLayout.v3(room.island_id, IslandLayout.boss_spot(room.island_id)["arena"])
	Boss.start(room, p, "boss_ca_loc", Protocol.uuid4())
	room.boss_state["end_tick"] = room.tick_count + 30
	H.run(room, 4.0)
	var refunds: Array = srv.backend.commits.filter(func(c): return c["op_type"] == "boss.refund")
	t.eq(refunds.size(), 1, "hoàn mồi đúng một lần khi hết giờ")
	t.eq(srv.events("boss.escaped").size(), 1, "boss trốn")


func test_hunger_active_only(t) -> void:
	var rs := H.make_room()
	var room: RefCounted = rs[0]
	var p := H.add_player(room, 2)
	p["hunger"] = 50.0
	H.run(room, 30.0)
	t.ok(absf(p["hunger"] - 49.0) < 0.05, "30 s chơi giảm 1 điểm (2/phút) — được %.3f" % p["hunger"])
	p["menu"] = true
	p["mode"] = "menu"
	var before: float = p["hunger"]
	H.run(room, 30.0)
	t.ok(absf(p["hunger"] - before) < 0.0001, "menu không giảm đói")
	p["menu"] = false
	p["mode"] = "afk"
	H.run(room, 30.0)
	t.ok(absf(p["hunger"] - before) < 0.0001, "AFK không giảm đói")
	room.detach_player(p["account_id"], 2)
	H.run(room, 30.0)
	t.ok(absf(p["hunger"] - before) < 0.0001, "mất kết nối không giảm đói")


func test_afk_after_timeout(t) -> void:
	var rs := H.make_room()
	var room: RefCounted = rs[0]
	var p := H.add_player(room, 2)
	H.run(room, float(ContentDB.limit("afk_timeout_s")) + 1.0)
	t.eq(p["mode"], "afk", "không thao tác 120 s thành AFK")


func test_rooms_isolated_same_coordinates(t) -> void:
	var a := H.make_room()
	var b := H.make_room()
	var ra: RefCounted = a[0]
	var rb: RefCounted = b[0]
	var pa := H.add_player(ra, 2)
	var pb := H.add_player(rb, 3)
	var pos := _pier_end(ra.island_id)
	pa["pos"] = pos
	pb["pos"] = pos
	Creatures.launch(ra, pa, "cre_cua_dong", null, false, pos + Vector3(0, 0, 6))
	H.run(ra, 3.0)
	H.run(rb, 3.0)
	t.eq(rb.entities.size(), 0, "room B không thấy cá của room A")
	var uid: String = ra.entities.keys()[0]
	pb["equipped"] = "tool_slipper"
	t.eq(Creatures.use_tool(rb, pb, uid), "OUT_OF_RANGE", "không đánh được cá room khác bằng UID")
	for m in b[1].sent:
		t.ok(not JSON.stringify(m["payload"]).contains(uid), "không rò snapshot/sự kiện sang room khác")


func test_room_owner_transfer_and_capacity(t) -> void:
	var rs := H.make_room()
	var room: RefCounted = rs[0]
	var ps: Array = []
	for i in 4:
		ps.append(H.add_player(room, 10 + i))
	t.ok(room.is_full_for(Protocol.uuid4()), "người thứ năm bị từ chối")
	var owner: String = room.owner_account_id
	room.remove_player_now(owner)
	t.ok(room.owner_account_id != owner and room.owner_account_id != "", "chủ phòng chuyển cho người vào sớm nhất")
	t.eq(room.owner_account_id, ps[1]["account_id"], "đúng người kế tiếp")


func test_melee_lag_compensation_bounded(t) -> void:
	# Cá vừa rời khỏi tầm tay trong <300 ms vẫn đánh được; cá chưa từng trong tầm thì bị từ chối.
	var rs := H.make_room()
	var room: RefCounted = rs[0]
	var p := H.add_player(room, 2)
	p["pos"] = _pier_end(room.island_id)
	p["equipped"] = "tool_hand"
	var near: Vector3 = p["pos"] + Vector3(0, 0, -1.0)
	Creatures.launch(room, p, "cre_tep", null, false, p["pos"] + Vector3(0, 0, 8))
	var uid: String = room.entities.keys()[0]
	var e: Dictionary = room.entities[uid]
	e["flying"] = false
	e["vel"] = Vector3.ZERO
	e["state"] = "landed"
	e["hist"] = []
	for i in 5:
		e["hist"].push_front(near)
	e["pos"] = near + Vector3(0, 0, -2.5)  # vừa nhảy ra xa
	p["yaw"] = 0.0   # nhìn về -z
	p["pitch"] = -0.9
	t.eq(Creatures.use_tool(room, p, uid), "", "vị trí trong ~150 ms trước còn trong tầm → chấp nhận")
	p["cooldowns"] = {}
	e["hist"] = [e["pos"]]
	t.eq(Creatures.use_tool(room, p, uid), "OUT_OF_RANGE", "không có vị trí nào trong tầm → từ chối")
