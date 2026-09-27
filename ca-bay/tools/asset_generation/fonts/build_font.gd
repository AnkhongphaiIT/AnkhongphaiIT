extends SceneTree
## Tạo res://assets/fonts/fnt_be_vietnam_pro.tres (asset fnt_be_vietnam_pro trong registry):
## FontVariation tham chiếu Be Vietnam Pro SemiBold (OFL) + font ký hiệu dự phòng. Chạy sau khi đã --import.
## godot --headless --path . --script tools/asset_generation/fonts/build_font.gd

func _init() -> void:
	var base: FontFile = load("res://assets/fonts/BeVietnamPro-SemiBold.ttf")
	var sym: FontFile = load("res://assets/fonts/ui_symbols.ttf")
	var fv := FontVariation.new()
	fv.base_font = base
	fv.fallbacks = [sym]
	var err := ResourceSaver.save(fv, "res://assets/fonts/fnt_be_vietnam_pro.tres")
	print("FONT_BUILD %s" % ("OK" if err == OK else "ERR %d" % err))
	quit(0 if err == OK else 1)
