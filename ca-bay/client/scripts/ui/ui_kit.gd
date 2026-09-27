class_name UIKit
extends RefCounted
## Dựng UI bằng code theo bảng màu Art Bible §3 (panel #22313A 85%, chữ #FFF8E7, viền #1B1B1B).
## Mọi chữ lấy từ Loc.t(); không nhúng chữ vào ảnh.

const C_PANEL := Color(0.133, 0.192, 0.227, 0.88)
const C_TEXT := Color("#FFF8E7")
const C_BORDER := Color("#1B1B1B")
const C_GOLD := Color("#FFC93C")
const C_RED := Color("#E4473C")
const C_GREEN := Color("#6CC24A")
const C_WATER := Color("#3FB8AF")
const C_MUTED := Color(1, 0.97, 0.9, 0.65)

static var _theme: Theme
static var font: Font


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	font = _load_font()
	if font:
		t.default_font = font
	t.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = C_PANEL
	panel.border_color = C_BORDER
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("#2F4A57")
	btn.border_color = C_BORDER
	btn.set_border_width_all(2)
	btn.set_corner_radius_all(8)
	btn.set_content_margin_all(10)
	var hover := btn.duplicate()
	hover.bg_color = Color("#3E6272")
	var pressed := btn.duplicate()
	pressed.bg_color = Color("#1F7A8C")
	var disabled := btn.duplicate()
	disabled.bg_color = Color("#2A3338")
	var focus := btn.duplicate()
	focus.border_color = C_GOLD
	focus.draw_center = false
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(k, "Button", {"normal": btn, "hover": hover, "pressed": pressed, "disabled": disabled, "focus": focus}[k])
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", C_MUTED)
	t.set_color("font_color", "Label", C_TEXT)
	var le := StyleBoxFlat.new()
	le.bg_color = Color("#12202A")
	le.border_color = Color("#4A6A7A")
	le.set_border_width_all(2)
	le.set_corner_radius_all(6)
	le.set_content_margin_all(8)
	t.set_stylebox("normal", "LineEdit", le)
	var lef := le.duplicate()
	lef.border_color = C_GOLD
	t.set_stylebox("focus", "LineEdit", lef)
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", C_MUTED)
	t.set_color("caret_color", "LineEdit", C_GOLD)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.45)
	bar_bg.set_corner_radius_all(5)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = C_GREEN
	bar_fill.set_corner_radius_all(5)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", C_TEXT)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	_theme = t
	return t


static func _load_font() -> Font:
	# Be Vietnam Pro (OFL, asset fnt_be_vietnam_pro) + font ký hiệu dự phòng; nguồn/giấy phép: assets/fonts/SOURCES.md.
	# Đặt làm font mặc định toàn cục để cả Label3D trong thế giới cũng dùng.
	if not ResourceLoader.exists("res://assets/fonts/fnt_be_vietnam_pro.tres"):
		return null
	var f: Font = load("res://assets/fonts/fnt_be_vietnam_pro.tres")
	ThemeDB.fallback_font = f
	if ResourceLoader.exists("res://assets/fonts/BeVietnamPro-Bold.ttf"):
		var b: FontFile = load("res://assets/fonts/BeVietnamPro-Bold.ttf")
		font_bold = FontVariation.new()
		font_bold.base_font = b
		font_bold.fallbacks = f.fallbacks
	return f


static var font_bold: FontVariation


static func label(text: String, size: int = 20, color: Color = C_TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", C_BORDER)
	l.add_theme_constant_override("outline_size", 4 if size >= 22 else 0)
	if size >= 26 and font_bold:
		l.add_theme_font_override("font", font_bold)
	l.horizontal_alignment = align
	# Chữ ngắn không tự xuống dòng (trong HBox nhãn tự xuống dòng bị bóp còn một ký tự mỗi dòng).
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if text.length() > 32 else TextServer.AUTOWRAP_OFF
	return l


static func wrap(l: Label, min_w := 0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if min_w > 0:
		l.custom_minimum_size.x = min_w
	return l


static func button(text: String, cb: Callable, min_w := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 44)
	b.pressed.connect(cb)
	return b


static func line_edit(placeholder: String, secret := false, max_len := 128) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.max_length = max_len
	e.custom_minimum_size = Vector2(320, 44)
	return e


static func panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(child)
	return p


static func vbox(children: Array = [], sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	for c in children:
		v.add_child(c)
	return v


static func hbox(children: Array = [], sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	for c in children:
		if c is Label and c.custom_minimum_size.x == 0 and not (c.size_flags_horizontal & Control.SIZE_EXPAND):
			c.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(c)
	return h


static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(child)
	return c


static func bar(color: Color, w := 180, h := 16) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	b.add_theme_stylebox_override("fill", fill)
	return b


static func spacer(h := 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


## Icon 256×256 đã bake từ mô hình (assets/icons/ico_*.png); trả Control rỗng nếu chưa có.
static func icon(def_id: String, px := 40) -> Control:
	var candidates: Array[String] = []
	if def_id.begins_with("rod_"):
		candidates = ["ico_" + def_id, "ico_rod_bamboo"]
	else:
		candidates = ["ico_" + def_id]
	for c in candidates:
		var path := "res://assets/icons/%s.png" % c
		if ResourceLoader.exists(path):
			var tr := TextureRect.new()
			tr.texture = load(path)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(px, px)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return tr
	var empty := Control.new()
	empty.custom_minimum_size = Vector2(px, px)
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return empty
