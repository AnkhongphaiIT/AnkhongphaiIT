extends Node
## Chạy test GDScript headless: godot --headless --path . res://tests/godot/test_runner.tscn [-- --only=<tên>]
## Mỗi file tests/godot/test_*.gd có các hàm test_*(t) nhận đối tượng T để assert. Thoát mã 1 nếu có lỗi.

class T:
	var failures: Array[String] = []
	var current := ""
	func ok(cond: bool, msg: String) -> void:
		if not cond:
			failures.append("%s: %s" % [current, msg])
	func eq(a: Variant, b: Variant, msg: String = "") -> void:
		if a != b:
			failures.append("%s: %s (được %s, cần %s)" % [current, msg, str(a), str(b)])


func _ready() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var t := T.new()
	var count := 0
	var dir := DirAccess.open("res://tests/godot")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_runner.gd":
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/godot/" + f)
		if script == null or not script.can_instantiate():
			t.failures.append("%s: không nạp được script (lỗi cú pháp?)" % f)
			continue
		var inst: Object = script.new()
		if inst is Node:
			add_child(inst)
		for m in inst.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			if only != "" and not (f + ":" + name).contains(only):
				continue
			t.current = f + ":" + name
			var res: Variant = inst.call(name, t)
			if res is Signal:
				await res
			count += 1
		if inst is Node:
			inst.queue_free()
	for fl in t.failures:
		printerr("FAIL ", fl)
	print("GODOT_TESTS run=%d failures=%d" % [count, t.failures.size()])
	get_tree().quit(1 if t.failures.size() > 0 else 0)
