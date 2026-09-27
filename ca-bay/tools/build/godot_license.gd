extends SceneTree
## In giấy phép Godot + thành phần bên thứ ba của chính engine đang dùng (bắt buộc kèm bản phát hành).
## godot --headless --script tools/build/godot_license.gd -- <file_ra>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := "user://GODOT_LICENSES.txt" if args.is_empty() else args[0]
	var t := "Godot Engine %s\n\n%s\n\n==== Thành phần bên thứ ba trong Godot Engine ====\n" % [Engine.get_version_info()["string"], Engine.get_license_text()]
	for info in Engine.get_copyright_info():
		t += "\n- %s\n" % info["name"]
		for part in info["parts"]:
			t += "  files: %s\n  license: %s\n" % [", ".join(part["files"]), part["license"]]
			for c in part["copyright"]:
				t += "  © %s\n" % c
	var lic := Engine.get_license_info()
	t += "\n==== Văn bản giấy phép ====\n"
	for k in lic:
		t += "\n---- %s ----\n%s\n" % [k, lic[k]]
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(t)
	f.close()
	print("GODOT_LICENSE_OK %s %d" % [out, t.length()])
	quit(0)
