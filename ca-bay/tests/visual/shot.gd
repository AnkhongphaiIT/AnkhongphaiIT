extends Node3D
## Chụp ảnh kiểm hình (chạy có render, vd xvfb-run): --island=<id> --out=<png> --cam=x,y,z --look=x,y,z [--models]

func _ready() -> void:
	var isl := "isl_01_cu_lao"
	var out := "/tmp/shot.png"
	var cam_pos := Vector3(0, 6, 40)
	var look := Vector3(0, 1, 10)
	var models := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--island="): isl = a.substr(9)
		elif a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--cam="):
			var p := a.substr(6).split(","); cam_pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
		elif a.begins_with("--look="):
			var q := a.substr(7).split(","); look = Vector3(float(q[0]), float(q[1]), float(q[2]))
		elif a == "--models": models = true
	get_viewport().size = Vector2i(1280, 720)
	var wv := WorldView.new()
	add_child(wv)
	wv.build(isl)
	if models:
		var i := 0
		for cid in ContentDB.dex_order:
			var m := Models.creature(cid)
			var s := 1.0 if ContentDB.creatures[cid].get("is_boss", false) else 2.2
			m.scale = Vector3.ONE * s
			m.position = look + Vector3((i % 6 - 2.5) * 1.3, 0.4 + int(i / 6) * 0.9, 0)
			m.rotation.y = -PI / 2.0
			add_child(m)
			i += 1
	var cam := Camera3D.new()
	cam.fov = 70
	add_child(cam)
	cam.look_at_from_position(cam_pos, look, Vector3.UP)
	cam.current = true
	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out)
	get_tree().quit()
