extends RefCounted
## Mọi script GDScript của dự án phải nạp/biên dịch được (bắt lỗi cú pháp/kiểu trước khi chạy thật).

func test_all_scripts_compile(t) -> void:
	var roots := ["res://client", "res://server/gameplay", "res://shared", "res://ui", "res://tests/bots"]
	var files: Array[String] = []
	for r in roots:
		_collect(r, files)
	t.ok(files.size() > 5, "tìm thấy script")
	for f in files:
		var s: Variant = load(f)
		t.ok(s != null and (s as GDScript).can_instantiate(), "không biên dịch được " + f)


func _collect(path: String, out: Array[String]) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(path + "/" + f)
	for sub in d.get_directories():
		_collect(path + "/" + sub, out)
