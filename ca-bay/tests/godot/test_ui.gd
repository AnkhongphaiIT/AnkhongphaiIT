extends Node
## UI dựng bằng code: HUD phải phủ kín khung nhìn (lỗi cũ: size=0 → HUD dồn về góc trái trên),
## mọi khóa chuỗi dùng trong UI phải có bản dịch, menu dựng được với save mẫu.


func test_hud_fills_viewport(t) -> Signal:
	var cl := CanvasLayer.new()
	add_child(cl)
	var h := Hud.new()
	cl.add_child(h)
	await get_tree().process_frame
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	t.eq(h.size, vp, "HUD phải phủ kín khung nhìn")
	t.ok(h.crosshair.get_global_rect().get_center().distance_to(vp * 0.5) < 24.0, "tâm ngắm phải ở giữa màn hình")
	cl.queue_free()
	return get_tree().process_frame


func test_hotbar_from_save(t) -> void:
	var save := {"inventory": {"equipped_rod_id": "rod_bamboo", "tools_owned": ["tool_hand", "tool_slipper"]}}
	var items := Hud.hotbar_items(save)
	t.eq(items[0], "rod_bamboo", "ô 1 là cần câu")
	t.ok("tool_slipper" in items and "tool_hand" in items, "công cụ đã có nằm trên thanh")
	t.ok(items.size() <= int(ContentDB.balance["inventory"]["hotbar_slots"]), "không vượt số ô")


func test_ui_keys_translated(t) -> void:
	var dir := "res://client/scripts/"
	var re := RegEx.new()
	re.compile("\"((?:ui|tutorial)\\.[a-z0-9_.]+[a-z0-9_])\"")
	for sub in ["ui", "game", "world"]:
		for f in DirAccess.get_files_at(dir + sub):
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir + sub + "/" + f)
			for m in re.search_all(src):
				var key := m.get_string(1)
				if key == "ui.popup_requested" or key.ends_with("_"):
					continue  # tên sự kiện / tiền tố khóa động (kiểm riêng bên dưới)
				t.ok(Loc.has_key(key), "%s: thiếu bản dịch %s" % [f, key])


func test_dynamic_keys_translated(t) -> void:
	for lvl in ["cooked", "burnt"]:
		t.ok(Loc.has_key("ui.cook.level_" + lvl), "thiếu ui.cook.level_" + lvl)
	for e in ["wave", "thanks", "cheer", "sorry"]:
		t.ok(Loc.has_key("ui.emote." + e), "thiếu ui.emote." + e)
	for k in ["here", "fish", "help", "ready"]:
		t.ok(Loc.has_key("ui.ping." + k), "thiếu ui.ping." + k)
	for isl in IslandLayout.LAYOUTS:
		for zid in IslandLayout.LAYOUTS[isl]["fishing"]:
			t.ok(Loc.has_key("zone.%s.name" % zid), "thiếu tên vùng " + zid)
