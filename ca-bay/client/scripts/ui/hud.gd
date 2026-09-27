class_name Hud
extends Control
## HUD theo Art Bible §10. Chỉ hiển thị dữ liệu từ server; không tính tiền/giá ở client.

var hp_bar: ProgressBar
var hunger_bar: ProgressBar
var hunger_label: Label
var objective: Label
var money: Label
var tickets: Label
var room_label: Label
var team: VBoxContainer
var net_label: Label
var crosshair: Label
var charge_bar: ProgressBar
var strain_bar: ProgressBar
var center_msg: Label
var prompt: Label
var hotbar: HBoxContainer
var bait_label: Label
var bag_label: Label
var popups: VBoxContainer
var subtitle: PanelContainer
var subtitle_label: Label
var keys_hint: Label
var boss_bar: VBoxContainer
var boss_label: Label
var boss_hp: ProgressBar
var boss_timer: Label
var _center_until := 0.0
var _sub_until := 0.0


func _ready() -> void:
	# set_anchors_preset trong _ready không tự co giãn lại kích thước (đo được size=0): đặt cả offset.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIKit.theme()
	# Bố cục bằng container (không đặt position tuyệt đối: kích thước khung chưa biết lúc _ready).
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var rows := UIKit.vbox([], 6)
	margin.add_child(rows)
	# hàng trên: trái (máu/đói/mục tiêu) · giữa (boss) · phải (tiền/đội/mạng)
	var top := UIKit.hbox([], 12)
	rows.add_child(top)
	var left := UIKit.vbox([], 6)
	hp_bar = UIKit.bar(Color("#E4473C"), 220, 16)
	hunger_bar = UIKit.bar(Color("#FFC93C"), 220, 16)
	hunger_label = UIKit.label("", 16)
	objective = UIKit.wrap(UIKit.label("", 17, UIKit.C_TEXT), 380)
	left.add_child(UIKit.hbox([UIKit.label("♥", 18, Color("#E4473C")), hp_bar]))
	left.add_child(UIKit.hbox([UIKit.label("●", 18, Color("#FFC93C")), hunger_bar, hunger_label]))
	left.add_child(objective)
	top.add_child(left)
	top.add_child(_expand())
	boss_bar = UIKit.vbox([], 4)
	boss_bar.custom_minimum_size = Vector2(440, 0)
	boss_label = UIKit.label("", 22, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	boss_hp = UIKit.bar(Color("#E4473C"), 440, 18)
	boss_timer = UIKit.label("", 16, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	for c in [boss_label, boss_hp, boss_timer]:
		boss_bar.add_child(c)
	boss_bar.visible = false
	top.add_child(boss_bar)
	top.add_child(_expand())
	var right := UIKit.vbox([], 4)
	right.custom_minimum_size = Vector2(260, 0)
	money = UIKit.label("", 22, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	tickets = UIKit.label("", 16, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	room_label = UIKit.label("", 15, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	team = UIKit.vbox([], 2)
	net_label = UIKit.label("", 15, UIKit.C_GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	for c in [money, tickets, room_label, team, net_label]:
		right.add_child(c)
	top.add_child(right)
	# giữa: khoảng trống + popup trick/giá bên phải
	var middle := UIKit.hbox([], 0)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(_expand())
	popups = UIKit.vbox([], 4)
	popups.custom_minimum_size = Vector2(360, 0)
	popups.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_child(popups)
	rows.add_child(middle)
	# phụ đề + thanh dưới
	subtitle_label = UIKit.wrap(UIKit.label("", 20), 620)
	subtitle = UIKit.panel(subtitle_label)
	subtitle.visible = false
	var sub_row := UIKit.hbox([_expand(), subtitle, _expand()])
	rows.add_child(sub_row)
	hotbar = UIKit.hbox([], 8)
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	bait_label = UIKit.label("", 16, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	bag_label = UIKit.label("", 16, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	keys_hint = UIKit.wrap(UIKit.label("", 13, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	rows.add_child(hotbar)
	var info := UIKit.hbox([bait_label, bag_label], 24)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_child(info)
	rows.add_child(keys_hint)
	# tâm màn hình: tâm ngắm; phía dưới tâm: thanh nạp/căng dây, thông báo, gợi ý
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	crosshair = UIKit.label("+", 28, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	cc.add_child(crosshair)
	var cc2 := CenterContainer.new()
	cc2.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc2)
	var mid := UIKit.vbox([], 6)
	mid.custom_minimum_size = Vector2(560, 330)
	mid.add_child(UIKit.spacer(190))
	charge_bar = UIKit.bar(Color("#FFC93C"), 320, 12)
	strain_bar = UIKit.bar(Color("#6CC24A"), 320, 12)
	charge_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	strain_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_msg = UIKit.wrap(UIKit.label("", 30, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	prompt = UIKit.wrap(UIKit.label("", 19, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	for c in [charge_bar, strain_bar, center_msg, prompt]:
		mid.add_child(c)
	cc2.add_child(mid)
	charge_bar.visible = false
	strain_bar.visible = false
	keys_hint.text = Loc.t("ui.keys.hint")
	_ignore_mouse(self)


static func _expand() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _ignore_mouse(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(c)


func _shadow(c: Control) -> Control:
	return c


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if center_msg.text != "" and t > _center_until:
		center_msg.text = ""
	if subtitle.visible and t > _sub_until:
		subtitle.visible = false


func show_center(text: String, seconds := 1.4, color := UIKit.C_GOLD) -> void:
	center_msg.text = text
	center_msg.add_theme_color_override("font_color", color)
	_center_until = Time.get_ticks_msec() / 1000.0 + seconds


func show_subtitle(speaker: String, text: String, seconds := 5.0) -> void:
	if not Settings.get_value("subtitles", true):
		return
	subtitle_label.text = "%s: %s" % [speaker, text] if speaker != "" else text
	subtitle.visible = true
	_sub_until = Time.get_ticks_msec() / 1000.0 + seconds


var _recent_popups: Dictionary = {}


func popup(text: String, color := UIKit.C_TEXT, seconds := 3.0, size := 20) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_recent_popups.get(text, -100.0)) < 1.5 and not text.begins_with("-") and not text.begins_with("+"):
		return  # cùng một thông báo liên tiếp: chỉ hiện một lần
	_recent_popups[text] = now
	var l := UIKit.label(text, size, color, HORIZONTAL_ALIGNMENT_RIGHT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popups.add_child(l)
	if popups.get_child_count() > int(ContentDB.balance["scoring"]["popup_max_lines"]) + 3:
		popups.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func update_vitals(hp: float, hunger: float) -> void:
	hp_bar.value = hp
	hunger_bar.value = hunger
	var low := float(ContentDB.hunger["low_threshold"])
	hunger_label.text = Loc.t("ui.hud.hunger") + (" ⚠" if hunger < low else "")
	hunger_label.add_theme_color_override("font_color", UIKit.C_GOLD if hunger < low else UIKit.C_TEXT)


func update_save(save: Dictionary, equipped: String) -> void:
	var cur: Dictionary = save.get("currencies", {})
	money.text = "%d %s" % [int(cur.get("money", 0)), Loc.t("ui.currency.name")]
	tickets.text = "%s: %d · %s: %d" % [Loc.t("ui.currency.ticket"), int(cur.get("festival_ticket", 0)), Loc.t("ui.currency.dust"), int(cur.get("cosmetic_dust", 0))]
	var inv: Dictionary = save.get("inventory", {})
	var bait_id: String = inv.get("selected_bait_id", "bait_bread")
	var bait: Dictionary = ContentDB.baits.get(bait_id, {})
	var count := "∞" if bait.get("infinite", false) else str(int(inv.get("bait_counts", {}).get(bait_id, 0)))
	bait_label.text = "[B] " + Loc.t("ui.hotbar.bait", {"name": Loc.name_of(bait_id), "count": count})
	bag_label.text = "   %s %d/%d" % [Loc.t("ui.hud.bag"), (inv.get("bag", []) as Array).size(), int(inv.get("capacity", 3))]
	UIKit.clear(hotbar)
	var slots := hotbar_items(save)
	for i in slots.size():
		var id: String = slots[i]
		var txt := "%d  %s" % [i + 1, Loc.name_of(id)]
		var ammo: Variant = _ammo_text(inv, id)
		if ammo != null:
			txt += " (%s)" % ammo
		var b := UIKit.label(txt, 16, UIKit.C_GOLD if id == equipped else UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		var p := UIKit.panel(UIKit.hbox([UIKit.icon(id, 34), b], 4))
		if id == equipped:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.12, 0.48, 0.55, 0.9)
			sb.border_color = UIKit.C_GOLD
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(8)
			sb.set_content_margin_all(8)
			p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotbar.add_child(p)


func _ammo_text(inv: Dictionary, id: String) -> Variant:
	var tool: Dictionary = ContentDB.tools.get(id, {})
	if tool.get("ammo", {}).get("recover", "") == "buy":
		return str(int(inv.get("tool_ammo", {}).get(id, 0)))
	return null


## Thanh công cụ riêng với túi (DEC-030): ô 1 cần câu, các ô sau công cụ đã sở hữu (tối đa 4 ô).
static func hotbar_items(save: Dictionary) -> Array:
	var inv: Dictionary = save.get("inventory", {})
	var out: Array = [inv.get("equipped_rod_id", "rod_bamboo")]
	var order := ["tool_slipper", "tool_broom", "tool_swatter", "tool_slingshot", "tool_coconut_bomb", "tool_hand"]
	for t in order:
		if t in inv.get("tools_owned", []) and out.size() < int(ContentDB.balance["inventory"]["hotbar_slots"]):
			out.append(t)
	return out


func update_team(players: Array, my_id: String, colors: Array) -> void:
	UIKit.clear(team)
	var i := 0
	for p in players:
		var mode: String = p["mode"]
		var mark: String = {"active": "●", "menu": "…", "afk": "zZ", "disconnected": "✖", "knocked_out": "✶"}.get(mode, "●")
		var l := UIKit.label("%s %s%s" % [mark, p["display_name"], " (%s)" % Loc.t("ui.hud.you") if p["account_id"] == my_id else ""], 15, colors[i % 4].lightened(0.3), HORIZONTAL_ALIGNMENT_RIGHT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		team.add_child(l)
		i += 1


func set_net(ok: bool, text: String) -> void:
	net_label.text = text
	net_label.add_theme_color_override("font_color", UIKit.C_GREEN if ok else UIKit.C_RED)
