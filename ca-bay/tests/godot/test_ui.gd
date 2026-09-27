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


func test_percent_text_and_no_unsupported_format(t) -> void:
	# Lỗi cũ: bảng tỉ lệ hộp quà hiện "Tỷ lệ: %g%" vì GDScript không hỗ trợ %g.
	var old := Loc.locale
	Loc.locale = "vi"
	t.eq(UIKit.percent(100.0 / 6.0), "16,67", "vi dùng dấu phẩy, 2 chữ số")
	t.eq(UIKit.percent(20.0), "20", "bỏ số 0 thừa")
	Loc.locale = "en"
	t.eq(UIKit.percent(12.5), "12.5", "en dùng dấu chấm")
	Loc.locale = old
	var re := RegEx.new()
	re.compile("\"[^\"\\n]*%[-+ 0#]*[0-9.]*[gGeEiu][^\"\\n]*\"[ \\t]*%")
	var bad: Array = []
	for dir in ["res://client/scripts/", "res://server/gameplay/", "res://shared/"]:
		for f in _gd_files(dir):
			var src := FileAccess.get_file_as_string(f)
			for m in re.search_all(src):
				bad.append("%s: %s" % [f, m.get_string()])
	t.eq(bad, [], "không dùng định dạng printf GDScript không hỗ trợ (%g/%e/%i/%u)")


func _gd_files(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir + d + "/"))
	return out


func test_rebind_keys_swap_and_hints(t) -> void:
	var saved: Dictionary = (Settings.get_value("keybinds", {}) as Dictionary).duplicate(true)
	Settings.reset_keybinds()
	t.eq(Settings.key_label("interact"), "E", "mặc định E")
	t.eq(Settings.rebind("interact", "F"), "", "đổi tương tác sang F")
	t.eq(Settings.binds_of("interact")[0], "F", "phím chính mới")
	var has_f := false
	for ev in InputMap.action_get_events("interact"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_F:
			has_f = true
	t.ok(has_f, "InputMap cập nhật ngay")
	# trùng phím: nhảy lấy F thì tương tác nhận lại phím cũ của nhảy (Space)
	t.eq(Settings.rebind("jump", "F"), "", "gán F cho nhảy")
	t.eq(Settings.binds_of("jump")[0], "F", "nhảy = F")
	t.eq(Settings.binds_of("interact"), ["Space"], "tương tác đổi chỗ sang Space")
	t.eq(Settings.rebind("interact", "Escape"), "reserved", "Esc dành cho menu/nhả chuột")
	t.eq(Settings.rebind("pause", "P"), "not_rebindable", "menu không đổi được")
	# đi tới giữ phím phụ (mũi tên) khi đổi phím chính
	Settings.rebind("move_forward", "Z")
	t.eq(Settings.binds_of("move_forward"), ["Z", "Up"], "giữ phím phụ Up")
	t.ok(Hud.keys_hint_text().contains("Space"), "gợi ý cuối màn hình dùng phím mới")
	Settings.reset_keybinds()
	t.eq(Settings.key_label("interact"), "E", "về mặc định")
	Settings.set_value("keybinds", saved)


func test_loc_whole_floats_render_as_int(t) -> void:
	# JSON của Godot trả số dạng float; chuỗi dịch không được hiện "0.0/4 người"
	var old := Loc.locale
	Loc.locale = "vi"
	t.eq(Loc.t("ui.coop.players", {"count": 0.0}), "0/4 người", "0.0 → 0")
	t.eq(Loc.t("ui.coop.players", {"count": 3.0}), "3/4 người", "3.0 → 3")
	t.ok(Loc.t("ui.coop.players", {"count": 2.5}).begins_with("2.5"), "số lẻ giữ nguyên")
	Loc.locale = old
