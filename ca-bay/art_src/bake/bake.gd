extends Node
## Bake tài nguyên procedural ra đúng đường dẫn asset registry (nguồn tái tạo; chạy lại được bất cứ lúc nào):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://art_src/bake/bake.tscn -- [--models] [--icons] [--misc]
## - mô hình: .tscn (mesh nhúng) + đo số tam giác/AABB → art_src/bake/bake_report.json
## - icon: PNG 256×256 RGBA render từ chính mô hình (không vẽ tay, không chữ)
## - môi trường/vật liệu/theme UI: .tres
## Không chạm dữ liệu gameplay; không ghi đè file âm thanh/font.

const REG := "res://data/contracts/asset_registry.json"
var report := {"models": {}, "icons": {}, "misc": {}, "errors": []}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var all := args.is_empty()
	UIKit.theme()
	var reg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REG))
	# gộp với báo cáo cũ (chạy lại một phần không xóa kết quả phần khác)
	var old: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/bake/bake_report.json")) if FileAccess.file_exists("res://art_src/bake/bake_report.json") else null
	if typeof(old) == TYPE_DICTIONARY:
		for k in ["models", "icons", "misc"]:
			report[k] = old.get(k, {})
	if all or "--models" in args:
		for a in reg["assets"]:
			if a["type"] == "model":
				_bake_model(a["id"], a["path"])
	if all or "--misc" in args:
		_bake_misc(reg)
	if all or "--icons" in args:
		for a in reg["assets"]:
			if a["type"] == "icon":
				await _bake_icon(a["id"], a["path"])
	var f := FileAccess.open("res://art_src/bake/bake_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  ", true))
	f.close()
	print("BAKE_DONE models=%d icons=%d misc=%d errors=%d" % [report["models"].size(), report["icons"].size(), report["misc"].size(), report["errors"].size()])
	for e in report["errors"]:
		printerr("BAKE_ERROR ", e)
	get_tree().quit(1 if not report["errors"].is_empty() else 0)


# ------------------------------------------------------------------ mô hình

func model_for(id: String) -> Node3D:
	var rest := id.trim_prefix("mdl_")
	match id:
		"mdl_env_isl01_terrain": return _island_ground("isl_01_cu_lao")
		"mdl_env_isl02_terrain": return _island_ground("isl_02_rung_dua")
		"mdl_env_isl03_terrain": return _island_ground("isl_03_mui_da")
		"mdl_env_pier":
			var wv := WorldView.new()
			add_child(wv)
			wv.build("isl_01_cu_lao")
			var pier: Node3D = wv.get_node("Pier").duplicate()
			wv.queue_free()
			return _wrap(pier)
		"mdl_env_vendor_stall": return _wrap(Models.stall())
		"mdl_env_ferry_boat": return _wrap(Models.boat())
		"mdl_env_palm_coconut": return _wrap(Models.palm(6.0, 0.15))
		"mdl_env_nipa_palm": return _wrap(Models.nipa(1.0))
		"mdl_env_rock_set":
			var r := Node3D.new()
			for i in 3:
				var m := Models.rock(0.8 + i * 0.5)
				m.position = Vector3(i * 1.4 - 1.4, 0, (i % 2) * 0.8)
				r.add_child(m)
			return r
		"mdl_env_boss_spot_post": return _wrap(Models.boss_post())
		"mdl_env_sign_board": return _wrap(Models.sign_board())
		"mdl_env_grill": return _wrap(Models.grill())
		"mdl_chr_npc_co_ba", "mdl_chr_npc_ong_tu":
			var look: Array = WorldView.NPC_LOOK[rest.trim_prefix("chr_")]
			return Models.person(Models.SKINS[look[0]], Models.CLOTHES[look[1]], Models.CLOTHES[look[2]], look[3])
		"mdl_chr_player_remote": return Models.person(Models.SKINS[0], Color("#E4473C"), Models.CLOTHES[3], "non_la")
		"mdl_fp_hands": return _wrap(Models.fp_hand(Models.SKINS[0], Color("#2F6FA8")))
		"mdl_tool_bobber": return _wrap(Models.bobber())
		"mdl_tool_rod_bamboo", "mdl_tool_rod_carbon": return _wrap(Models.tool_model(rest.trim_prefix("tool_")))
		"mdl_cre_egret": return _wrap(Models.heron())
		"mdl_item_milk_tea": return _wrap(Models.bait("bait_milk_tea"))
		"mdl_item_worm_jar": return _wrap(Models.bait("bait_worm"))
		"mdl_item_backpack_display": return _wrap(Models.backpack_display())
		"mdl_item_reel_display": return _wrap(Models.reel_display())
		"mdl_proj_boba_pearl": return _wrap(Models.water_blob())
		"mdl_acc_boba_pearls": return _wrap(Models.silver_scales())
	if rest.begins_with("tool_"):
		return _wrap(Models.tool_model(rest))
	if rest.begins_with("cre_"):
		return Models.creature(rest)
	if rest.begins_with("item_"):
		return _wrap(Models.item(rest))
	return null


func _wrap(n: Node3D) -> Node3D:
	var r := Node3D.new()
	r.add_child(n)
	return r


func _island_ground(isl: String) -> Node3D:
	var wv := WorldView.new()
	add_child(wv)
	wv.build(isl)
	var r := Node3D.new()
	for c in wv.get_children():
		if c.name in ["Terrain", "Water"]:
			r.add_child(c.duplicate())
	wv.queue_free()
	return r


func _own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		_own(c, owner_node)


static func stats(n: Node) -> Dictionary:
	var tris := 0
	var box := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		stack.append_array(c.get_children())
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mesh: Mesh = (c as MeshInstance3D).mesh
			for si in mesh.get_surface_count():
				var arr: Array = mesh.surface_get_arrays(si)
				var idx: Variant = arr[Mesh.ARRAY_INDEX]
				tris += ((idx as PackedInt32Array).size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var ab: AABB = (c as MeshInstance3D).get_aabb()
			var t: Transform3D = (c as Node3D).transform
			var p: Node = c.get_parent()
			while p and p != n and p is Node3D:
				t = (p as Node3D).transform * t
				p = p.get_parent()
			ab = t * ab
			box = ab if first else box.merge(ab)
			first = false
	return {"triangles": tris, "size": [snappedf(box.size.x, 0.01), snappedf(box.size.y, 0.01), snappedf(box.size.z, 0.01)]}


func _bake_model(id: String, path: String) -> void:
	var m := model_for(id)
	if m == null:
		report["errors"].append("không có bộ dựng cho " + id)
		return
	var root := Node3D.new()
	root.name = id
	root.add_child(m)
	m.owner = root
	_own(m, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if err == OK:
		err = ResourceSaver.save(ps, path)
	if err != OK:
		report["errors"].append("%s: lỗi lưu %d" % [id, err])
	else:
		var st := stats(root)
		st["path"] = path
		report["models"][id] = st
	root.free()


# ------------------------------------------------------------------ icon

func icon_model(id: String) -> Node3D:
	var rest := id.trim_prefix("ico_")
	match id:
		"ico_money": return _wrap(Models.coin())
		"ico_health": return _wrap(Models.heart())
		"ico_rod_bamboo": return _wrap(Models.tool_model("rod_bamboo"))
		"ico_bait_milk_tea": return _wrap(Models.bait("bait_milk_tea"))
	if rest.begins_with("tool_"):
		return _wrap(Models.tool_model(rest))
	if rest.begins_with("bait_"):
		return _wrap(Models.bait(rest))
	if rest.begins_with("item_"):
		return _wrap(Models.item(rest))
	if rest.begins_with("cre_"):
		return Models.creature(rest)
	return null


func _bake_icon(id: String, path: String) -> void:
	var m := icon_model(id)
	if m == null:
		report["errors"].append("không có mô hình cho icon " + id)
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var holder := Node3D.new()
	holder.add_child(m)
	vp.add_child(holder)
	# khung hình: xoay 3/4, cân theo AABB
	holder.rotation_degrees = Vector3(0, -125 if id.begins_with("ico_cre_") else -35, 0)
	if id in ["ico_rod_bamboo", "ico_tool_broom"]:
		# vật dài mảnh: đặt chéo khung và làm dày để còn đọc được ở 64 px
		holder.rotation_degrees = Vector3(0, 0, 0)
		m.rotation_degrees = Vector3(0, 90, 45)
		m.scale = Vector3(3.5, 3.5, 1.0)
	var st := stats(holder)
	var sz: Array = st["size"]
	var radius := maxf(0.05, Vector3(sz[0], sz[1], sz[2]).length() * 0.5)
	var center := _center(holder)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = radius * 2.25
	cam.near = 0.01
	cam.far = 100.0
	vp.add_child(cam)
	cam.global_position = center + Vector3(0, radius * 0.9, radius * 3.0)
	cam.look_at(center, Vector3.UP)
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := img.save_png(ProjectSettings.globalize_path(path))
	var used := img.get_used_rect()
	if err != OK:
		report["errors"].append("%s: lỗi lưu PNG %d" % [id, err])
	elif used.size.x < 32 or used.size.y < 32:
		report["errors"].append("%s: icon gần như trống (%s)" % [id, str(used)])
	else:
		report["icons"][id] = {"path": path, "size": [img.get_width(), img.get_height()], "used_rect": [used.position.x, used.position.y, used.size.x, used.size.y], "alpha": img.detect_alpha() != Image.ALPHA_NONE}
	vp.queue_free()


func _center(n: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		stack.append_array(c.get_children())
		if c is MeshInstance3D:
			var ab: AABB = (c as MeshInstance3D).global_transform * (c as MeshInstance3D).get_aabb()
			box = ab if first else box.merge(ab)
			first = false
	return box.get_center()


# ------------------------------------------------------------------ môi trường, vật liệu, theme

func _bake_misc(reg: Dictionary) -> void:
	for a in reg["assets"]:
		var path: String = a["path"]
		var res: Resource = null
		match a["type"]:
			"environment":
				var wv := WorldView.new()
				add_child(wv)
				wv.build({"env_isl01_day": "isl_01_cu_lao", "env_isl02_day": "isl_02_rung_dua", "env_isl03_day": "isl_03_mui_da"}[a["id"]])
				res = wv.env.environment.duplicate(true)
				wv.queue_free()
			"material":
				res = (MeshKit.material() if a["id"] == "mat_palette_lit" else MeshKit.material_unshaded()).duplicate()
			"ui":
				if a["id"] == "ui_theme_main":
					res = UIKit.theme()
			"texture":
				if a["id"] == "tex_palette_main":
					# bảng màu Art Bible §3: mỗi màu một ô 16×16 (UV bảng màu cho mô hình/UI về sau)
					var cols := ["#5EC8F2", "#CDEFF7", "#1F7A8C", "#3FB8AF", "#F4F1DE", "#9C8455", "#E9C98B", "#8D6A4A",
						"#7CC24A", "#3E8E3A", "#9C6B3F", "#6B4428", "#C8A160", "#E4473C", "#FFC93C", "#6CC24A",
						"#B8C4C8", "#E8ECE8", "#F1C27D", "#D9A066", "#A86B3C", "#B79AD9", "#9FB7C9", "#8A5A3C",
						"#2B2B2B", "#FFFFFF", "#111111", "#B8A05A", "#D9C27A", "#22313A", "#FFF8E7", "#1B1B1B"]
					var img := Image.create(128, 64, false, Image.FORMAT_RGBA8)
					for i in cols.size():
						img.fill_rect(Rect2i((i % 8) * 16, int(i / 8) * 16, 16, 16), Color(cols[i]))
					DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
					var e2 := img.save_png(ProjectSettings.globalize_path(path))
					if e2 == OK:
						report["misc"][a["id"]] = {"path": path}
					else:
						report["errors"].append("tex_palette_main: %d" % e2)
					continue
		if res == null:
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var err := ResourceSaver.save(res, path)
		if err != OK:
			report["errors"].append("%s: lỗi lưu %d" % [a["id"], err])
		else:
			report["misc"][a["id"]] = {"path": path}
