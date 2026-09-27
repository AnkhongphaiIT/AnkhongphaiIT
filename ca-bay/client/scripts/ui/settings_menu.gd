class_name SettingsMenu
extends CenterContainer
## Cài đặt máy này (ngôn ngữ, âm lượng, phụ đề, chuột, góc nhìn, chất lượng, kiểu kéo cần)
## và thao tác tài khoản (đổi mật khẩu, xóa tài khoản, đăng xuất). Tùy chọn lưu cục bộ; tài khoản qua API.

signal closed

var api: Node
var app: Node
var _status: Label
var _body: VBoxContainer


static func open(parent: Control, a: Node, ap: Node) -> SettingsMenu:
	var m := SettingsMenu.new()
	m.api = a
	m.app = ap
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(m)
	m._build()
	return m


func _build() -> void:
	UIKit.clear(self)
	_body = UIKit.vbox([], 8)
	_body.add_child(UIKit.label(Loc.t("ui.menu.settings"), 28, UIKit.C_GOLD))
	# ngôn ngữ
	var lang := UIKit.hbox()
	lang.add_child(UIKit.label(Loc.t("ui.settings.language"), 18))
	for pair in [["vi", "Tiếng Việt"], ["en", "English"]]:
		var b := UIKit.button(pair[1], func():
			Settings.set_value("locale", pair[0])
			_build())
		b.disabled = Loc.locale == pair[0]
		lang.add_child(b)
	_body.add_child(lang)
	# âm lượng
	_body.add_child(_slider("ui.settings.master", "volume_master", 0.0, 1.0, 0.05))
	_body.add_child(_slider("ui.settings.music", "volume_music", 0.0, 1.0, 0.05))
	_body.add_child(_slider("ui.settings.sfx", "volume_sfx", 0.0, 1.0, 0.05))
	_body.add_child(_slider("ui.settings.voice", "volume_voice", 0.0, 1.0, 0.05))
	_body.add_child(_toggle("ui.settings.subtitles", "subtitles"))
	# điều khiển
	_body.add_child(_slider("ui.settings.sensitivity", "mouse_sensitivity", 0.2, 3.0, 0.1))
	_body.add_child(_toggle("ui.settings.invert_y", "invert_y"))
	_body.add_child(_slider("ui.settings.fov", "fov_deg", 60.0, 100.0, 1.0))
	_body.add_child(_toggle("ui.settings.camera_shake", "camera_shake"))
	_body.add_child(_toggle("ui.settings.auto_swap", "auto_swap_after_launch"))
	var reel := UIKit.hbox()
	reel.add_child(UIKit.label(Loc.t("ui.settings.reel_mode"), 18))
	for pair2 in [["hold", "ui.settings.reel_hold"], ["toggle", "ui.settings.reel_toggle"]]:
		var b2 := UIKit.button(Loc.t(pair2[1]), func():
			Settings.set_value("reel_mode", pair2[0])
			_build())
		b2.disabled = Settings.get_value("reel_mode", "hold") == pair2[0]
		reel.add_child(b2)
	_body.add_child(reel)
	var q := UIKit.hbox()
	q.add_child(UIKit.label(Loc.t("ui.settings.quality"), 18))
	for pair3 in [["low", "ui.settings.quality_low"], ["high", "ui.settings.quality_high"]]:
		var b3 := UIKit.button(Loc.t(pair3[1]), func():
			Settings.set_value("quality", pair3[0])
			_build())
		b3.disabled = Settings.get_value("quality", "low") == pair3[0]
		q.add_child(b3)
	_body.add_child(q)
	if not Settings.persisted:
		_body.add_child(UIKit.label(Loc.t("ui.web.private_mode_warning"), 14, UIKit.C_MUTED))
	# tài khoản
	if api and api.is_logged_in():
		_body.add_child(UIKit.label(Loc.t("ui.settings.account") + ": " + String(api.display_name), 20, UIKit.C_GOLD))
		var acc := UIKit.hbox()
		acc.add_child(UIKit.button(Loc.t("ui.account.change_password"), _show_change_password))
		acc.add_child(UIKit.button(Loc.t("ui.account.delete"), _show_delete))
		_body.add_child(acc)
	_status = UIKit.label("", 16, UIKit.C_GOLD)
	_body.add_child(_status)
	_body.add_child(UIKit.button(Loc.t("ui.menu.close"), _close, 320))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	add_child(UIKit.panel(scroll))


func _close() -> void:
	closed.emit()
	queue_free()


func _slider(label_key: String, key: String, lo: float, hi: float, step: float) -> HBoxContainer:
	var h := UIKit.hbox()
	var l := UIKit.label(Loc.t(label_key), 18)
	l.custom_minimum_size.x = 260
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_value(key, lo))
	s.custom_minimum_size = Vector2(260, 28)
	var val := UIKit.label(_fmt(key, s.value), 16)
	s.value_changed.connect(func(v):
		Settings.set_value(key, v)
		val.text = _fmt(key, v)
		if key == "volume_sfx":
			AudioDirector.play_ui("sfx_ui_click"))
	h.add_child(s)
	h.add_child(val)
	return h


static func _fmt(key: String, v: float) -> String:
	if key.begins_with("volume_"):
		return "%d%%" % int(round(v * 100.0))
	if key == "fov_deg":
		return "%d°" % int(v)
	return "%.1f" % v


func _toggle(label_key: String, key: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = Loc.t(label_key)
	c.button_pressed = bool(Settings.get_value(key, false))
	c.toggled.connect(func(on): Settings.set_value(key, on))
	return c


# ------------------------------------------------------------------ tài khoản

func _show_change_password() -> void:
	UIKit.clear(self)
	var v := UIKit.vbox([], 10)
	v.add_child(UIKit.label(Loc.t("ui.account.change_password"), 26, UIKit.C_GOLD))
	var cur := UIKit.line_edit(Loc.t("ui.account.password"), true)
	var pw := UIKit.line_edit(Loc.t("ui.account.new_password"), true)
	var pw2 := UIKit.line_edit(Loc.t("ui.account.password_confirm"), true)
	for e in [cur, pw, pw2]:
		v.add_child(e)
	v.add_child(UIKit.label(Loc.t("ui.account.rules"), 14, UIKit.C_MUTED))
	_status = UIKit.label("", 16, UIKit.C_GOLD)
	v.add_child(_status)
	v.add_child(UIKit.hbox([
		UIKit.button(Loc.t("ui.account.change_password"), func(): _do_change_password(cur.text, pw.text, pw2.text)),
		UIKit.button(Loc.t("ui.menu.back"), _build),
	]))
	add_child(UIKit.panel(v))
	cur.grab_focus()


func _do_change_password(cur: String, pw: String, pw2: String) -> void:
	if pw != pw2:
		_status.text = Loc.t("ui.account.password_mismatch")
		return
	_status.text = "…"
	var r: Dictionary = await api.change_password(cur, pw)
	if not is_inside_tree():
		return
	if not r["ok"]:
		_status.text = app._err_text(r["error_code"]) if app else r["error_code"]
		return
	# đổi mật khẩu thu hồi mọi phiên: đăng nhập lại
	_status.text = Loc.t("ui.account.password_changed")
	await get_tree().create_timer(1.5).timeout
	if app and is_instance_valid(app):
		app.force_relogin(Loc.t("ui.account.password_changed"))


func _show_delete() -> void:
	UIKit.clear(self)
	var v := UIKit.vbox([], 10)
	v.add_child(UIKit.label(Loc.t("ui.account.delete"), 26, UIKit.C_RED))
	v.add_child(UIKit.label(Loc.t("ui.account.delete_confirm"), 17))
	var pw := UIKit.line_edit(Loc.t("ui.account.password"), true)
	v.add_child(pw)
	var confirm := UIKit.line_edit(Loc.t("ui.account.delete_type"), false, 16)
	v.add_child(confirm)
	_status = UIKit.label("", 16, UIKit.C_GOLD)
	v.add_child(_status)
	v.add_child(UIKit.hbox([
		UIKit.button(Loc.t("ui.account.delete"), func(): _do_delete(pw.text, confirm.text)),
		UIKit.button(Loc.t("ui.menu.back"), _build),
	]))
	add_child(UIKit.panel(v))
	pw.grab_focus()


func _do_delete(pw: String, confirm: String) -> void:
	if confirm.strip_edges().to_upper() not in ["XOA", "XÓA", "DELETE"]:
		_status.text = Loc.t("ui.account.delete_type")
		return
	_status.text = "…"
	var r: Dictionary = await api.reauth(pw)
	if r["ok"]:
		r = await api.delete_account(pw)
	if not is_inside_tree():
		return
	if not r["ok"]:
		_status.text = app._err_text(r["error_code"]) if app else r["error_code"]
		return
	_status.text = Loc.t("ui.account.deleted")
	await get_tree().create_timer(1.5).timeout
	if app and is_instance_valid(app):
		app.force_relogin(Loc.t("ui.account.deleted"))
