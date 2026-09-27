extends Node
## Điều phối client: Khởi động → Tài khoản → Sảnh → Trong game. Token chỉ trong bộ nhớ phiên.

const ApiClient := preload("res://client/scripts/net/api_client.gd")
const GameConnection := preload("res://client/scripts/net/game_connection.gd")
const GameSession := preload("res://client/scripts/game/game_session.gd")

var api: Node
var conn: Node
var endpoints: Dictionary
var ui: CanvasLayer
var root_ui: Control
var session: Node
var save: Dictionary = {}
var current_room: Dictionary = {}
var _busy := false
var _status: Label


func _ready() -> void:
	endpoints = Endpoints.load_endpoints()
	api = ApiClient.new()
	api.base_url = endpoints["api_base"]
	add_child(api)
	api.session_expired.connect(_on_session_expired)
	conn = GameConnection.new()
	add_child(conn)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	root_ui = Control.new()
	root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Gốc UI không tự nhận chuột (nền của từng màn hình tự chặn); nếu không, lúc vào game nó nuốt
	# mọi cú nhấp và _unhandled_input của phiên chơi không bao giờ nhận được chuột.
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.theme = UIKit.theme()
	ui.add_child(root_ui)
	Loc.locale_changed.connect(func(_l): _rebuild_current())
	show_boot()


var _current_screen := ""


func _rebuild_current() -> void:
	match _current_screen:
		"boot": show_boot()
		"auth": show_auth(_auth_tab)
		"lobby": show_lobby()


func _set_screen(name: String, content: Control) -> void:
	_current_screen = name
	UIKit.clear(root_ui)
	var bg := ColorRect.new()
	bg.color = Color("#1F7A8C")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(bg)
	var waves := ColorRect.new()
	waves.color = Color("#3FB8AF")
	waves.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	waves.custom_minimum_size = Vector2(0, 180)
	waves.offset_top = -180
	root_ui.add_child(waves)
	root_ui.add_child(UIKit.centered(content))


func _lang_switch() -> HBoxContainer:
	var h := UIKit.hbox([UIKit.label(Loc.t("ui.settings.language") + ":", 16),
		UIKit.button("Tiếng Việt", func(): Settings.set_value("locale", "vi")),
		UIKit.button("English", func(): Settings.set_value("locale", "en"))])
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	return h


# ------------------------------------------------------------------ khởi động

func show_boot() -> void:
	var v := UIKit.vbox([], 16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UIKit.label("CÁ BAY", 64, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(Loc.t("ui.boot.subtitle"), 22, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var start := UIKit.button(Loc.t("ui.audio.enable"), _on_boot_click, 420)
	start.custom_minimum_size.y = 64
	v.add_child(start)
	v.add_child(_lang_switch())
	v.add_child(UIKit.label(Loc.t("ui.boot.notice"), 14, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var p := UIKit.panel(v)
	p.custom_minimum_size = Vector2(560, 0)
	_set_screen("boot", p)


func _on_boot_click() -> void:
	# Cử chỉ người dùng: trình duyệt cho phép bật AudioContext; phát âm bấm để mở khóa âm thanh.
	AudioDirector.unlock()
	AudioDirector.play_ui("sfx_ui_click")
	show_auth("login")


# ------------------------------------------------------------------ tài khoản

var _auth_tab := "login"


func show_auth(tab: String) -> void:
	_auth_tab = tab
	var v := UIKit.vbox([], 12)
	var tabs := UIKit.hbox()
	for t in [["login", "ui.account.login"], ["register", "ui.account.register"], ["recover", "ui.account.recover"]]:
		var b := UIKit.button(Loc.t(t[1]), func(): show_auth(t[0]))
		b.disabled = t[0] == tab
		tabs.add_child(b)
	v.add_child(tabs)
	var user := UIKit.line_edit(Loc.t("ui.account.username"), false, 24)
	v.add_child(user)
	var display := UIKit.line_edit(Loc.t("ui.account.display_name"), false, 32)
	var code := UIKit.line_edit(Loc.t("ui.account.recovery_code"), false, 32)
	var pw := UIKit.line_edit(Loc.t("ui.account.new_password") if tab == "recover" else Loc.t("ui.account.password"), true)
	var pw2 := UIKit.line_edit(Loc.t("ui.account.password_confirm"), true)
	match tab:
		"register":
			v.add_child(display)
			v.add_child(pw)
			v.add_child(pw2)
			v.add_child(UIKit.label(Loc.t("ui.account.rules"), 14, UIKit.C_MUTED))
		"recover":
			v.add_child(code)
			v.add_child(pw)
			v.add_child(pw2)
			v.add_child(UIKit.label(Loc.t("ui.account.recovery_warning"), 14, UIKit.C_MUTED))
		_:
			v.add_child(pw)
	_status = UIKit.label("", 16, UIKit.C_GOLD)
	v.add_child(_status)
	var go := UIKit.button(Loc.t({"login": "ui.account.login", "register": "ui.account.register", "recover": "ui.account.recover"}[tab]), func():
		_submit_auth(tab, user.text, display.text, code.text, pw.text, pw2.text), 320)
	v.add_child(go)
	pw.text_submitted.connect(func(_t): go.pressed.emit())
	v.add_child(_lang_switch())
	var p := UIKit.panel(v)
	p.custom_minimum_size = Vector2(520, 0)
	_set_screen("auth", p)
	user.grab_focus()


func _err_text(code: String) -> String:
	var map := {
		"INVALID_CREDENTIALS": "ui.account.invalid_credentials", "RATE_LIMITED": "ui.account.rate_limited",
		"USERNAME_TAKEN": "ui.account.username_taken", "WEAK_PASSWORD": "ui.account.rules", "INVALID_PAYLOAD": "ui.account.rules",
		"OFFLINE": "ui.network.offline", "SERVER_BUSY": "ui.network.server_busy", "ROOM_FULL": "ui.network.room_full",
		"INVITE_INVALID": "ui.network.invite_invalid", "ROOM_NOT_FOUND": "ui.network.invite_invalid",
		"PROTOCOL_MISMATCH": "ui.network.version_mismatch", "CONTENT_MISMATCH": "ui.network.version_mismatch",
		"AUTH_EXPIRED": "ui.account.session_expired", "AUTH_REQUIRED": "ui.account.session_expired",
		"UNLOCK_REQUIRED": "ui.coop.travel_locked", "LEASE_ACTIVE_ELSEWHERE": "ui.lobby.lease_elsewhere",
		"REAUTH_REQUIRED": "ui.account.reauth_required", "BAD_TICKET": "ui.network.offline",
	}
	return Loc.t(map[code]) if map.has(code) else Loc.t("ui.error.generic", {"code": code})


func _submit_auth(tab: String, user: String, display: String, code: String, pw: String, pw2: String) -> void:
	if _busy:
		return
	if tab != "login" and pw != pw2:
		_status.text = Loc.t("ui.account.password_mismatch")
		return
	_busy = true
	_status.text = Loc.t("ui.lobby.connecting")
	if Endpoints.autotest:
		print("CABAY_AUTH_SUBMIT tab=%s display=%s" % [tab, display])
	var r: Dictionary
	match tab:
		"login":
			r = await api.login(user, pw)
		"register":
			r = await api.register(user, display if display.strip_edges() != "" else user, pw)
		"recover":
			r = await api.recover(user, code, pw)
	_busy = false
	if not r["ok"]:
		_status.text = _err_text(r["error_code"])
		AudioDirector.play_ui("sfx_error_nope")
		return
	if tab == "register" or tab == "recover":
		show_recovery_codes(r["data"]["recovery_codes"], tab == "recover")
	else:
		await enter_lobby()


func show_recovery_codes(codes: Array, after_recover: bool) -> void:
	var v := UIKit.vbox([], 12)
	v.add_child(UIKit.label(Loc.t("ui.account.save_recovery"), 22, UIKit.C_GOLD))
	var box := UIKit.label("\n".join(codes), 24, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(UIKit.panel(box))
	v.add_child(UIKit.label(Loc.t("ui.account.recovery_warning"), 14, UIKit.C_MUTED))
	var text := "CA BAY recovery codes / Ma khoi phuc\n" + "\n".join(codes) + "\n"
	v.add_child(UIKit.button(Loc.t("ui.account.download_codes"), func():
		if OS.has_feature("web"):
			JavaScriptBridge.download_buffer(text.to_utf8_buffer(), "ca-bay-recovery-codes.txt", "text/plain")
		else:
			DisplayServer.clipboard_set(text)))
	v.add_child(UIKit.button(Loc.t("ui.account.codes_saved"), func():
		if after_recover:
			show_auth("login")
		else:
			enter_lobby(), 320))
	var p := UIKit.panel(v)
	p.custom_minimum_size = Vector2(520, 0)
	_set_screen("codes", p)


func _on_session_expired() -> void:
	if session:
		leave_game(false)
	show_auth("login")
	if _status:
		_status.text = Loc.t("ui.account.session_expired")


# ------------------------------------------------------------------ sảnh

func enter_lobby() -> void:
	var r: Dictionary = await api.get_save()
	if r["ok"]:
		save = r["data"]["save"]
		if Endpoints.autotest:
			print("CABAY_LOBBY %s" % save_digest(save))
	show_lobby(r["data"].get("lease", {}) if r["ok"] else {})


## Tóm tắt save do server trả (chỉ để kiểm thử đổi máy SAVE-01; không chứa dữ liệu cá nhân).
static func save_digest(sv: Dictionary) -> String:
	var inv: Dictionary = sv["inventory"]
	var upg: Array = []
	for k in (inv.get("upgrades", {}) as Dictionary).keys():
		upg.append("%s:%d" % [k, int(inv["upgrades"][k])])
	upg.sort()
	var food: Array = []
	for k in (inv.get("food_counts", {}) as Dictionary).keys():
		food.append("%s:%d" % [k, int(inv["food_counts"][k])])
	food.sort()
	var cur: Dictionary = sv["currencies"]
	return "v=%d money=%d tickets=%d dust=%d bag=%d upg=%s food=%s cos=%d islands=%d" % [
		int(sv["save_version"]), int(cur["money"]), int(cur["festival_ticket"]), int(cur.get("cosmetic_dust", 0)),
		(inv["bag"] as Array).size(), ",".join(upg), ",".join(food), (sv["cosmetics"]["owned"] as Array).size(),
		(sv["progress"]["islands_unlocked"] as Array).size()]


func show_lobby(lease: Dictionary = {}) -> void:
	var v := UIKit.vbox([], 12)
	v.add_child(UIKit.label(Loc.t("ui.lobby.welcome", {"name": api.display_name}), 30, UIKit.C_GOLD))
	if not save.is_empty():
		v.add_child(UIKit.label("%s: %d   %s: %d" % [Loc.t("ui.currency.name"), int(save["currencies"]["money"]), Loc.t("ui.currency.ticket"), int(save["currencies"]["festival_ticket"])], 18))
	_status = UIKit.label("", 16, UIKit.C_GOLD)
	if lease.get("active", false) and not lease.get("this_session", false):
		v.add_child(UIKit.label(Loc.t("ui.lobby.lease_elsewhere"), 18, UIKit.C_GOLD))
		v.add_child(UIKit.button(Loc.t("ui.account.takeover"), _on_takeover))
	var islands_row := UIKit.hbox()
	for isl in ContentDB.island_order:
		var unlocked: bool = save.is_empty() or isl in save["progress"]["islands_unlocked"]
		var b := UIKit.button(Loc.t("ui.lobby.create_on", {"island": Loc.name_of(isl)}), func(): _create_room(isl))
		b.disabled = not unlocked
		if not unlocked:
			b.tooltip_text = Loc.t("ui.travel.locked")
		islands_row.add_child(b)
	v.add_child(UIKit.label(Loc.t("ui.coop.create"), 20))
	v.add_child(islands_row)
	var code := UIKit.line_edit(Loc.t("ui.coop.room_code"), false, 8)
	code.custom_minimum_size.x = 180
	var join := UIKit.button(Loc.t("ui.coop.join"), func(): _join_code(code.text))
	code.text_submitted.connect(func(_t): join.pressed.emit())
	v.add_child(UIKit.label(Loc.t("ui.coop.join"), 20))
	v.add_child(UIKit.hbox([code, join]))
	var rooms_box := UIKit.vbox([], 6)
	v.add_child(rooms_box)
	v.add_child(_status)
	var bottom := UIKit.hbox()
	bottom.add_child(UIKit.button(Loc.t("ui.menu.settings"), func(): SettingsMenu.open(root_ui, api, self)))
	bottom.add_child(UIKit.button(Loc.t("ui.account.logout"), _logout))
	v.add_child(bottom)
	v.add_child(_lang_switch())
	var p := UIKit.panel(v)
	p.custom_minimum_size = Vector2(640, 0)
	_set_screen("lobby", p)
	_fill_rooms(rooms_box)


func _fill_rooms(box: VBoxContainer) -> void:
	var r: Dictionary = await api.list_rooms()
	if not r["ok"] or not is_instance_valid(box):
		return
	var rooms: Array = r["data"].get("rooms", [])
	if rooms.is_empty():
		return
	box.add_child(UIKit.label(Loc.t("ui.lobby.my_rooms"), 18))
	for room in rooms:
		box.add_child(UIKit.hbox([
			UIKit.label("%s · %s · %s" % [room["invite_code"], Loc.name_of(room["island_id"]), Loc.t("ui.coop.players", {"count": int(room["players"])})], 16),
			UIKit.button(Loc.t("ui.lobby.rejoin"), func(): _enter_room(room)),
		]))


func _create_room(isl: String) -> void:
	if _busy:
		return
	_busy = true
	_status.text = Loc.t("ui.lobby.connecting")
	var r: Dictionary = await api.create_room(isl)
	_busy = false
	if not r["ok"]:
		_status.text = _err_text(r["error_code"])
		return
	await _enter_room(r["data"])


func _join_code(code: String) -> void:
	if _busy or code.strip_edges().length() < 4:
		return
	_busy = true
	_status.text = Loc.t("ui.lobby.connecting")
	var r: Dictionary = await api.lookup_room(code.strip_edges().to_upper())
	if r["ok"]:
		r = await api.join_room(r["data"]["room_id"], code.strip_edges().to_upper())
	_busy = false
	if not r["ok"]:
		_status.text = _err_text(r["error_code"])
		return
	await _enter_room(r["data"])


func _enter_room(room: Dictionary) -> void:
	current_room = room
	_status.text = Loc.t("ui.lobby.connecting")
	for attempt in 40:
		var t: Dictionary = await api.ticket(room["room_id"])
		if t["ok"]:
			_start_session(t["data"]["ticket"])
			return
		if t["error_code"] != "ROOM_NOT_READY":
			if _status:
				_status.text = _err_text(t["error_code"])
			return
		await get_tree().create_timer(0.35).timeout
	_status.text = Loc.t("ui.network.server_busy")


func _start_session(ticket: String) -> void:
	session = GameSession.new()
	session.name = "Session"
	session.app = self
	add_child(session)
	UIKit.clear(root_ui)
	_current_screen = "game"
	session.start(conn, api, current_room, save)
	# RPC cố định "Game/Network" tính từ gốc multiplayer = cây chính (/root/Game/Network).
	conn.connect_to(endpoints["ws_url"], ticket, get_tree().root)


func reconnect_session() -> bool:
	if current_room.is_empty():
		return false
	var t: Dictionary = await api.ticket(current_room["room_id"])
	if not t["ok"]:
		return false
	conn.connect_to(endpoints["ws_url"], t["data"]["ticket"], get_tree().root)
	return true


func leave_game(send_leave := true) -> void:
	if session:
		if send_leave and conn.is_live():
			conn.send("room.leave", {})
		session.queue_free()
		session = null
	conn.disconnect_now()
	AudioDirector.stop_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await enter_lobby()


## Sau đổi mật khẩu/xóa tài khoản: mọi phiên bị thu hồi, quay về đăng nhập.
func force_relogin(message: String) -> void:
	if session:
		session.queue_free()
		session = null
	conn.disconnect_now()
	AudioDirector.stop_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	api.access_token = ""
	api.refresh_token = ""
	save = {}
	show_auth("login")
	if _status:
		_status.text = message


func _on_takeover() -> void:
	var r: Dictionary = await api.takeover()
	if r["ok"]:
		await enter_lobby()


func _logout() -> void:
	await api.logout()
	save = {}
	show_auth("login")
