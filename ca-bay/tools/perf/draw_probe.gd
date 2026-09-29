extends Node
## Đếm chi phí vẽ của một đảo (PERF-01, P-047): dựng WorldView như trong game, đặt camera ở điểm hồi sinh, quay 8 hướng,
## in số draw call / vật thể / tam giác mỗi hướng (Performance monitor) + số MeshInstance3D. Cần cửa sổ có GPU (không headless):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tools/perf/draw_probe.tscn -- --island=isl_01_cu_lao

var island := "isl_01_cu_lao"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--island="):
			island = a.substr(9)
	get_viewport().scaling_3d_scale = 0.75
	var wv := WorldView.new()
	add_child(wv)
	wv.build(island)
	var cam := Camera3D.new()
	cam.fov = 75.0
	add_child(cam)
	cam.position = IslandLayout.spawn_point(island) + Vector3(0, 1.6, 0)
	for i in 10:
		await get_tree().process_frame
	var meshes := wv.find_children("*", "MeshInstance3D", true, false).size()
	var labels := wv.find_children("*", "Label3D", true, false).size()
	var total := 0
	var worst := 0
	for k in 8:
		cam.rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(45.0 * k), 0.0)
		for i in 4:
			await get_tree().process_frame
		var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		total += dc
		worst = maxi(worst, dc)
		print("DRAW_PROBE %s yaw=%d draw_calls=%d objects=%d primitives=%d" % [island, 45 * k, dc,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	print("DRAW_PROBE_SUMMARY %s mesh_instances=%d label3d=%d nodes=%d draw_calls_mean=%d draw_calls_max=%d" % [island, meshes, labels,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), total / 8, worst])
	get_tree().quit()
