extends Node
## Trong game: dựng đảo, người chơi cục bộ, thực thể từ snapshot, HUD, menu; chuyển ý định người chơi
## thành lệnh gửi server; mọi tiền/đồ/tiến trình chỉ cập nhật từ bản xem (view) server gửi về.

const TUTORIAL_ORDER := ["cast", "reel", "thrash", "smack", "throw_air", "pickup", "sell"]
const DURABLE_TIMEOUT_S := 12.0
const RECONNECT_GRACE_S := 85.0

var app: Node                      # client_app
var conn: Node                     # GameConnection
var api: Node                      # ApiClient
var room: Dictionary = {}
var save: Dictionary = {}
var my_id := ""
var island_id := ""

var world: Node3D
var world_view: WorldView
var entities: EntityView
var player: LocalPlayer
var ui_layer: CanvasLayer
var hud: Hud
var menu_root: Control
var menu_name := ""
var menu_arg := ""
var overlay: Control               # màn chờ kết nối lại

var cooking_uid := ""
var last_dialogue: Dictionary = {}
var last_lootbox: Dictionary = {}
var my_hunger := 100.0
var my_hp := 100.0
var my_mode := "active"

var _queue: Array = []             # lệnh bền vững chờ gửi (tuần tự để expected_save_version đúng)
var _inflight: Dictionary = {}     # request_id -> {type, payload, op_id, t, retried}
var _requests: Dictionary = {}     # request_id -> {type, payload} cho lệnh không bền vững
var _got_first_snapshot := false
var _want_capture := false
var _was_captured := false
var _primary_down := false
var _reel_toggled := false
var _thrashing := false
var _strain := 0.0
var _charge_t0 := -1.0
var _boss := {}                    # {uid, boss_id, hp, max_hp, end_t, hide_t}
var _hunger_warned := false
var _reconnecting := false
var _closing := false
var _pings: Array = []
var _last_view_version := -1
var server_pos := Vector3.ZERO
var snap_count := 0
var _team_n := 0
var _rtt_ms := -1
var _next_ping := 0.0


func start(c: Node, a: Node, r: Dictionary, s: Dictionary) -> void:
	conn = c
	api = a
	room = r
	save = s
	my_id = api.account_id
	island_id = String(r.get("island_id", "isl_01_cu_lao"))
	conn.message.connect(_on_message)
	conn.closed.connect(_on_closed)
	conn.auth_failed.connect(_on_auth_failed)
	conn.accepted.connect(_on_accepted)
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	world_view = WorldView.new()
	world.add_child(world_view)
	entities = EntityView.new()
	entities.my_account_id = my_id
	world.add_child(entities)
	player = LocalPlayer.new()
	player.session = self
	world.add_child(player)
	entities.local_rod_tip = player.rod_tip
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	hud = Hud.new()
	ui_layer.add_child(hud)
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.theme = UIKit.theme()
	ui_layer.add_child(menu_root)
	AudioDirector.world_root = world
	_apply_render_scale()
	_build_island(island_id)
	player.set_equipped(String(save.get("inventory", {}).get("equipped_id", "rod_bamboo")) if not save.is_empty() else "rod_bamboo")
	hud.set_net(false, Loc.t("ui.lobby.connecting"))
	_refresh_hud()
	Loc.locale_changed.connect(func(_l): _on_locale())
	Settings.changed.connect(func(k):
		if k == "quality" and world_view.sun:
			world_view.sun.shadow_enabled = String(Settings.get_value("quality", "low")) != "low"
			_apply_render_scale())


## Độ phân giải 3D: chất lượng thấp 75 %, cao 100 %; chế độ autotest 50 % (GPU phần mềm trong CI).
func _apply_render_scale() -> void:
	var sc := 1.0 if String(Settings.get_value("quality", "low")) == "high" else 0.75
	if Endpoints.autotest:
		sc = 0.5
	if Endpoints.render_scale_override > 0.0:
		sc = Endpoints.render_scale_override
	get_viewport().scaling_3d_scale = sc


func _exit_tree() -> void:
	AudioDirector.stop_all()
	AudioDirector.world_root = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_island(isl: String) -> void:
	island_id = isl
	world_view.build(isl)
	AudioDirector.set_island(isl)
	for uid in entities.nodes.keys():
		entities.nodes[uid].queue_free()
	entities.nodes.clear()
	entities.snaps.clear()
	entities.meta.clear()
	_boss = {}
	hud.boss_bar.visible = false
	_got_first_snapshot = false


func _on_locale() -> void:
	hud.keys_hint.text = Loc.t("ui.keys.hint")
	_refresh_hud()
	if menu_name != "" and menu_name != "settings":
		_render_menu()


# ------------------------------------------------------------------ API cho menu/người chơi

func gameplay_input_enabled() -> bool:
	return menu_name == "" and not _reconnecting and conn != null and conn.is_live()


func open_menu(name: String, arg := "") -> void:
	var was_open := menu_name != ""
	menu_name = name
	menu_arg = arg
	_want_capture = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_primary_down = false
	if not was_open:
		send_cmd("menu.active", {"active": true})
		player.fishing_state = "IDLE"
	hud.subtitle.visible = false  # lời thoại đã hiện trong bảng menu
	_render_menu()
	AudioDirector.play_ui("sfx_ui_open")


func close_menu() -> void:
	if menu_name == "":
		return
	menu_name = ""
	UIKit.clear(menu_root)
	menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	send_cmd("menu.active", {"active": false})
	_capture_mouse()
	AudioDirector.play_ui("sfx_ui_close")


func _render_menu() -> void:
	UIKit.clear(menu_root)
	if menu_name == "":
		return
	menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(dim)
	if menu_name == "settings":
		var sm := SettingsMenu.open(menu_root, api, app)
		sm.closed.connect(func(): open_menu("pause"))
		return
	var content: Control
	match menu_name:
		"pause": content = Menus.pause(self)
		"shop": content = Menus.shop(self, menu_arg)
		"quest": content = Menus.quest_npc(self, menu_arg)
		"dex": content = Menus.dex(self, "species")
		"dex_tricks": content = Menus.dex(self, "tricks")
		"lootbox": content = Menus.lootbox(self)
		"bag": content = Menus.bag(self)
		"travel": content = Menus.travel(self)
		_: content = Menus.pause(self)
	var p := UIKit.panel(content)
	p.custom_minimum_size = Vector2(680, 0)
	menu_root.add_child(UIKit.centered(p))


func leave_room() -> void:
	_closing = true
	menu_name = ""
	app.leave_game(true)


## Gửi lệnh không bền vững (menu.active, npc.interact, island.vote, ...). Trả request_id.
func send_cmd(type: String, payload: Dictionary) -> String:
	if conn == null or not conn.is_live():
		return ""
	var rid: String = conn.send(type, payload)
	if rid != "":
		_requests[rid] = {"type": type, "payload": payload}
	if Endpoints.autotest and type != "player.input":
		print("CABAY_CMD %s sent=%s" % [type, rid != ""])
	return rid


## Lệnh bền vững: thêm op_id + expected_save_version, gửi tuần tự; kết quả cập nhật bản xem.
func durable(type: String, payload: Dictionary) -> void:
	for q in _queue:
		if q["type"] == type and q["payload"] == payload:
			return  # bấm lặp khi đang chờ: bỏ qua, không tạo op mới
	for rid in _inflight:
		if _inflight[rid]["type"] == type and _inflight[rid]["payload"] == payload:
			return
	_queue.append({"type": type, "payload": payload, "op_id": Protocol.uuid4(), "retried": false})
	_pump_queue()


func _pump_queue() -> void:
	if not _inflight.is_empty() or _queue.is_empty() or conn == null or not conn.is_live():
		return
	var q: Dictionary = _queue.pop_front()
	var body: Dictionary = q["payload"].duplicate(true)
	body["op_id"] = q["op_id"]
	body["expected_save_version"] = int(save.get("save_version", 0))
	var rid: String = conn.send(q["type"], body)
	if rid == "":
		_queue.push_front(q)
		return
	q["t"] = Time.get_ticks_msec() / 1000.0
	_inflight[rid] = q
	if q["type"] in ["inventory.sell", "shop.buy", "lootbox.open", "boss.summon", "quest.claim", "quest.deliver"]:
		hud.prompt.text = Loc.t("ui.network.pending_save")


# ------------------------------------------------------------------ nhận message

func _on_accepted(p: Dictionary) -> void:
	print("CABAY_SESSION accepted")
	if Endpoints.autotest:
		print("CABAY_ROOM code=%s" % String(room.get("invite_code", "")))
	my_id = p["account_id"]
	entities.my_account_id = my_id
	_reconnecting = false
	if overlay:
		overlay.queue_free()
		overlay = null
	hud.set_net(true, "")
	# phiên mới trên server luôn bắt đầu ngoài menu
	if menu_name != "":
		send_cmd("menu.active", {"active": true})
	else:
		_capture_mouse()
	# lệnh đang chờ khi mất kết nối: gửi lại cùng op_id (idempotent ở backend)
	for rid in _inflight.keys():
		var q: Dictionary = _inflight[rid]
		_queue.push_front(q)
	_inflight.clear()
	_pump_queue()


func _on_message(type: String, payload: Dictionary, _env: Dictionary) -> void:
	match type:
		"state.snapshot":
			_on_snapshot(payload)
		"domain.event":
			_on_event(payload)
		"command.result":
			_on_result(payload)
		"account.updated":
			if int(payload["save_version"]) > int(save.get("save_version", 0)) and payload.get("refresh_required", false):
				_refresh_save_later(int(payload["save_version"]))
		"room.changed":
			room["island_id"] = payload["island_id"]
			room["members"] = payload["members"]
			room["owner_account_id"] = payload["owner_account_id"]
		"session.closed":
			_on_session_closed(payload)
		"session.pong":
			_rtt_ms = Time.get_ticks_msec() - int(payload["client_monotonic_ms"])


func _on_snapshot(s: Dictionary) -> void:
	snap_count += 1
	if String(s["island_id"]) != island_id:
		_build_island(String(s["island_id"]))
	entities.push_snapshot(s)
	for p in s["players"]:
		if p["account_id"] != my_id:
			continue
		var pos := Vector3(p["position"][0], p["position"][1], p["position"][2])
		server_pos = pos
		if not _got_first_snapshot:
			_got_first_snapshot = true
			player.spawn_at(pos, island_id)
			player.yaw = float(p["yaw_rad"])
		else:
			player.reconcile(pos, int(s["last_ack_input_seq"]))
		my_hp = float(p["hp"])
		my_hunger = float(p["hunger"])
		var prev_mode := my_mode
		my_mode = p["mode"]
		player.alive = my_mode != "knocked_out"
		if prev_mode == "knocked_out" and my_mode != "knocked_out":
			hud.show_center("")
	hud.update_vitals(my_hp, my_hunger)
	hud.update_team(s["players"], my_id, entities.player_colors)
	if Endpoints.autotest and (s["players"] as Array).size() != _team_n:
		_team_n = (s["players"] as Array).size()
		print("CABAY_TEAM n=%d" % _team_n)


func _refresh_save_later(version: int) -> void:
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree() or int(save.get("save_version", 0)) >= version:
		return
	var r: Dictionary = await api.get_save()
	if r["ok"]:
		_apply_view(r["data"]["save"])


func _apply_view(v: Variant) -> void:
	if typeof(v) != TYPE_DICTIONARY or not v.has("save_version"):
		return
	if int(v["save_version"]) < int(save.get("save_version", 0)):
		return
	save = v
	if app:
		app.save = v
	_refresh_hud()
	if menu_name != "" and menu_name not in ["settings", "pause"]:
		_render_menu()


func _on_result(r: Dictionary) -> void:
	var rid: String = r["request_id"]
	var receipt: Dictionary = r["receipt"] if typeof(r["receipt"]) == TYPE_DICTIONARY else {}
	if receipt.has("view"):
		_apply_view(receipt["view"])
	if _inflight.has(rid):
		var q: Dictionary = _inflight[rid]
		_inflight.erase(rid)
		_on_durable_result(q, r, receipt)
		_pump_queue()
		return
	var req: Dictionary = _requests.get(rid, {})
	_requests.erase(rid)
	if r["status"] == "rejected":
		_show_error(String(r["error_code"]), String(req.get("type", "")))
		return
	match String(req.get("type", "")):
		"npc.interact":
			var npc_id: String = receipt.get("npc_id", req["payload"]["npc_id"])
			var npc: Dictionary = ContentDB.npcs.get(npc_id, {})
			if npc.has("shop_id"):
				open_menu("shop", npc["shop_id"])
			else:
				open_menu("quest", npc_id)


func _on_durable_result(q: Dictionary, r: Dictionary, receipt: Dictionary) -> void:
	var t: String = q["type"]
	if hud.prompt.text == Loc.t("ui.network.pending_save"):
		hud.prompt.text = ""
	if r["status"] != "committed":
		var code: String = String(r["error_code"])
		if code == "SAVE_CONFLICT" and not q["retried"]:
			# bản xem đã được làm mới trong receipt; thử lại một lần bằng op mới
			q["retried"] = true
			q["op_id"] = Protocol.uuid4()
			_queue.push_front(q)
			return
		if t == "equipment.equip":
			player.set_equipped(String(save["inventory"]["equipped_id"]))
		_show_error(code, t)
		return
	match t:
		"lootbox.open":
			last_lootbox = receipt
			AudioDirector.play_ui("sfx_lootbox_open")
			if menu_name == "lootbox":
				_render_menu()
		"cooking.start":
			cooking_uid = String(q["payload"]["item_uid"])
			AudioDirector.start_loop("cook", "sfx_grill_sizzle_loop", "SFX", -8.0)
		"cooking.collect":
			cooking_uid = ""
			AudioDirector.stop_loop("cook")
			AudioDirector.play_ui("sfx_cook_done")
		"inventory.sell":
			AudioDirector.play_ui("sfx_coin")
		"shop.buy":
			AudioDirector.play_ui("sfx_coin")
		"equipment.equip":
			player.set_equipped(String(q["payload"]["equipment_id"]))
		"cosmetic.equip":
			player.set_equipped(player.equipped)
		"boss.summon":
			close_menu()
		"food.consume":
			hud.popup(Loc.t("ui.prompt.eat", {"name": Loc.name_of(q["payload"]["item_id"])}), UIKit.C_GREEN)


func _show_error(code: String, type: String) -> void:
	print("CABAY_REJ %s %s" % [type, code])
	var key := ""
	match code:
		"INSUFFICIENT_FUNDS": key = "ui.popup.not_enough_money"
		"INVENTORY_FULL": key = "ui.hud.inventory_full"
		"SAVE_CONFLICT": key = "ui.network.save_conflict"
		"ITEM_NOT_OWNED":
			key = "ui.coop.wrong_owner" if type == "inventory.pickup" else "ui.error.not_owned"
		"OUT_OF_RANGE": key = "ui.error.out_of_range"
		"COOLDOWN": key = ""
		"PLAYER_INACTIVE": key = ""
		"FOOD_FULL", "HUNGER_FULL": key = "ui.hunger.full"
		"INSUFFICIENT_TICKETS": key = "ui.lootbox.no_tickets"
		"UNLOCK_REQUIRED": key = "ui.coop.travel_locked"
	if key == "" and code in ["COOLDOWN", "PLAYER_INACTIVE"]:
		return
	if type == "tool.use" and code == "OUT_OF_RANGE":
		return  # cú vung hụt đã có hoạt ảnh; không spam thông báo
	var text: String = Loc.t(key) if key != "" else (app._err_text(code) if app else code)
	hud.popup(text, UIKit.C_GOLD)
	AudioDirector.play_ui("sfx_error_nope")


func _on_session_closed(p: Dictionary) -> void:
	var reason: String = p["reason"]
	if reason in ["takeover", "revoked"]:
		_closing = true
		_show_overlay(Loc.t("ui.account.taken_over"), true)


func _on_auth_failed(code: String) -> void:
	if code in ["PROTOCOL_MISMATCH", "CONTENT_MISMATCH"]:
		_closing = true
		_show_overlay(Loc.t("ui.network.version_mismatch"), true)


func _on_closed(reason: String, reconnect_allowed: bool) -> void:
	AudioDirector.stop_loop("reel")
	AudioDirector.stop_loop("strain")
	hud.set_net(false, Loc.t("ui.coop.reconnecting"))
	if _closing:
		return
	if not reconnect_allowed:
		_show_overlay(app._err_text(reason) if app else reason, true)
		return
	_reconnect_loop()


func _reconnect_loop() -> void:
	if _reconnecting:
		return
	_reconnecting = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_overlay(Loc.t("ui.coop.reconnecting"), false)
	var t0 := Time.get_ticks_msec() / 1000.0
	var wait := 1.0
	while _reconnecting and is_inside_tree() and Time.get_ticks_msec() / 1000.0 - t0 < RECONNECT_GRACE_S:
		var ok: bool = await app.reconnect_session()
		if ok:
			# chờ session.accepted (hoặc thất bại)
			var t1 := Time.get_ticks_msec() / 1000.0
			while is_inside_tree() and conn.state in ["connecting", "authenticating"] and Time.get_ticks_msec() / 1000.0 - t1 < 10.0:
				await get_tree().process_frame
			if conn.is_live():
				return
		await get_tree().create_timer(wait).timeout
		wait = minf(wait * 2.0, 8.0)
	if is_inside_tree() and _reconnecting:
		_show_overlay(Loc.t("ui.network.offline"), true)


func _show_overlay(text: String, to_lobby: bool) -> void:
	if overlay:
		overlay.queue_free()
	var v := UIKit.vbox([], 12)
	v.add_child(UIKit.label(text, 22, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if to_lobby:
		v.add_child(UIKit.button(Loc.t("ui.pause.main_menu"), func():
			_closing = true
			_reconnecting = false
			app.leave_game(false), 320))
	var p := UIKit.panel(v)
	p.custom_minimum_size = Vector2(560, 0)
	overlay = UIKit.centered(p)
	ui_layer.add_child(overlay)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ------------------------------------------------------------------ sự kiện miền

func _name_of_player(aid: Variant) -> String:
	if aid == null:
		return ""
	return String(entities.players_meta.get(aid, {}).get("name", "?"))


func _on_event(ev: Dictionary) -> void:
	var name: String = ev["name"]
	var p: Dictionary = ev["event_payload"]
	var actor: Variant = ev["actor_player_id"]
	var own: bool = actor != null and actor == my_id
	AudioDirector.on_event(name, p, {"own": own, "player_pos": player.pos})
	if Endpoints.autotest and not own and actor != null and name in ["fishing.launched", "creature.knocked_out", "item.picked_up", "room.player_joined", "player.emote", "room.ping"]:
		print("CABAY_OTHER %s by=%s" % [name, _name_of_player(actor)])
	if (Endpoints.autotest or OS.is_debug_build()) and own and not name.begins_with("hunger.") and name != "player.footstep":
		print("CABAY_EV %s pos=(%.1f,%.1f,%.1f) yaw=%.2f pitch=%.2f" % [name, player.pos.x, player.pos.y, player.pos.z, player.yaw, player.pitch])  # nhật ký chẩn đoán (không chứa dữ liệu cá nhân)
	_event_vfx(name, p, actor, own)
	match name:
		# --- câu cá (trạng thái chỉ theo sự kiện server của chính mình)
		"fishing.cast_charge_started":
			if own:
				player.fishing_state = "CHARGING"
				_charge_t0 = Time.get_ticks_msec() / 1000.0
		"fishing.cast_released":
			if own:
				player.fishing_state = "CASTING"
				player.cast_anim()
				_charge_t0 = -1.0
		"fishing.lure_landed":
			if own:
				player.fishing_state = "WAITING"
				if p["surface"] == "ground":
					hud.popup(Loc.t("ui.popup.no_fish_here"), UIKit.C_MUTED)
		"fishing.bite":
			if own:
				player.fishing_state = "BITING"
				hud.show_center("!", 0.8, UIKit.C_RED)
				player.shake = 0.25
		"fishing.hook_set":
			if own:
				player.fishing_state = "REELING"
				if p["perfect"]:
					hud.show_center(Loc.t("ui.fishing.perfect"), 0.8)
				_strain = 0.2
				if _primary_down or _reel_toggled:
					send_cmd("fishing.action", {"action": "reel_start", "aim_direction": _aim()})
		"fishing.reel_state_changed":
			if own:
				player.reel_held = bool(p["reeling"])
				if player.reel_held:
					AudioDirector.start_loop("reel", "sfx_reel_loop")
				else:
					AudioDirector.stop_loop("reel")
		"fishing.thrash_started":
			if own:
				_thrashing = true
				hud.show_center(Loc.t("tutorial.thrash"), 1.0, UIKit.C_RED)
				AudioDirector.start_loop("strain", "sfx_line_strain", "SFX", -6.0)
		"fishing.thrash_ended":
			if own:
				_thrashing = false
				AudioDirector.stop_loop("strain")
		"fishing.strain_warning":
			if own:
				_strain = float(p["strain"])
		"fishing.escaped":
			if own:
				hud.show_center(Loc.t("ui.popup.escaped"), 1.2, UIKit.C_RED)
		"fishing.cancelled":
			if own:
				_end_fishing()
		"fishing.launched":
			if own:
				_end_fishing()
				player.yank_anim()
				if p["perfect_yank"]:
					hud.show_center(Loc.t("trick_perfect_yank.name"), 1.0)
				if Settings.get_value("auto_swap_after_launch", true):
					var slots := Hud.hotbar_items(save)
					if slots.size() > 1:
						_equip(String(slots[1]))
			entities.meta[p["creature_uid"]] = {"owner": actor}
		# --- sinh vật / đồ vật
		"creature.spawned":
			var m: Dictionary = entities.meta.get(p["creature_uid"], {})
			m["owner"] = actor
			m["variant"] = p["variant_id"]
			entities.meta[p["creature_uid"]] = m
			if p["is_boss"]:
				_boss["uid"] = p["creature_uid"]
		"creature.knocked_out":
			var m2: Dictionary = entities.meta.get(p["creature_uid"], {})
			m2["owner"] = actor
			m2["value"] = int(p["value"])
			m2["variant"] = p["variant_id"]
			entities.meta[p["creature_uid"]] = m2
		"creature.damaged":
			entities.flash(String(p["creature_uid"]))
			if _boss.get("uid", "") == p["creature_uid"] and p.has("hp"):
				_boss["hp"] = float(p["hp"])
				_boss["max_hp"] = float(p.get("max_hp", _boss.get("max_hp", 1.0)))
				entities.meta[p["creature_uid"]] = {"hp_ratio": _boss["hp"] / maxf(1.0, _boss["max_hp"])}
			if own:
				hud.popup("-%d" % int(round(float(p["amount"]))), UIKit.C_TEXT, 1.2, 18)
		"scoring.tricks_awarded":
			if own:
				_show_tricks(p)
		"creature.attacked_player", "player.damaged":
			if own:
				player.shake = 0.5
				if name == "player.damaged":
					hud.damage_flash(float(p.get("amount", 10.0)))
		"player.knocked_out":
			if own:
				hud.show_center(Loc.t("ui.player.ko"), 3.0, UIKit.C_RED)
				_end_fishing()
		"item.dropped":
			var m3: Dictionary = entities.meta.get(p["item_uid"], {})
			m3["owner"] = actor
			entities.meta[p["item_uid"]] = m3
		"inventory.full":
			if own:
				hud.popup(Loc.t("ui.hud.inventory_full"), UIKit.C_GOLD)
		"economy.money_changed":
			if own and int(p["delta"]) != 0:
				hud.popup("%+d %s" % [int(p["delta"]), Loc.t("ui.currency.name")], UIKit.C_GOLD if int(p["delta"]) > 0 else UIKit.C_TEXT, 2.5, 22)
		"dex.new_species":
			if own:
				hud.show_center(Loc.t("ui.hud.new_species") + " " + Loc.name_of(p["creature_def_id"]), 2.0)
		"thief.approach_warning":
			if entities.meta.get(p["item_uid"], {}).get("owner", "") == my_id:
				hud.popup(Loc.t("ui.thief.warning"), UIKit.C_RED)
		"thief.item_stolen":
			if actor == my_id:
				hud.popup(Loc.t("ui.thief.stolen"), UIKit.C_RED)
		# --- tiến trình
		"quest.started":
			if own:
				hud.popup(Loc.t("ui.quest.started", {"name": Loc.t(ContentDB.quests[p["quest_id"]]["name_key"])}), UIKit.C_GOLD)
		"quest.step_progressed":
			if own:
				hud.popup("%s %d/%d" % [Loc.t(ContentDB.quests[p["quest_id"]]["name_key"]), int(p["count"]), int(p["required"])], UIKit.C_TEXT)
		"quest.completed":
			if own:
				hud.show_center(Loc.t("ui.quest.completed", {"name": Loc.t(ContentDB.quests[p["quest_id"]]["name_key"])}), 2.5)
		"progress.island_unlocked":
			if own:
				hud.show_center(Loc.t("ui.travel.unlocked", {"name": Loc.name_of(p["island_id"])}), 3.0)
		"cooking.started":
			if own:
				cooking_uid = String(p["item_uid"])
		"cooking.level_changed":
			if own:
				hud.popup(Loc.t("ui.cook.level_" + String(p["level"])), UIKit.C_GOLD)
				if p["level"] == "burnt":
					AudioDirector.stop_loop("cook")
		"hunger.changed":
			if own:
				my_hunger = float(p["value"])
				if p["band"] == "low" and not _hunger_warned:
					_hunger_warned = true
					hud.popup(Loc.t("ui.hunger.low"), UIKit.C_GOLD, 5.0)
				elif p["band"] != "low":
					_hunger_warned = false
		"dialogue.line_started":
			if own:
				last_dialogue = {"npc_id": p["npc_id"], "text_key": p["text_key"]}
				hud.show_subtitle(Loc.name_of(p["npc_id"]), Loc.t(p["text_key"]), 6.0)
				AudioDirector.play_voice(p["npc_id"], p["text_key"])
				if menu_name == "quest" and menu_arg == p["npc_id"]:
					_render_menu()
		# --- boss
		"boss.summoned":
			_boss = {"uid": p["creature_uid"], "boss_id": p["boss_id"], "hp": float(p.get("hp", 1.0)), "max_hp": float(p.get("max_hp", 1.0)),
				"end_t": Time.get_ticks_msec() / 1000.0 + float(p.get("end_in_s", 240.0))}
			hud.boss_bar.visible = true
			hud.boss_label.text = Loc.name_of(ContentDB.bosses[p["boss_id"]]["creature_id"])
			hud.show_center(Loc.t("ui.boss.arrived"), 2.0, UIKit.C_RED)
			world_view.show_arena(true)
		"boss.phase_changed":
			if int(p["phase"]) > 1:
				hud.show_center(Loc.t("ui.boss.angry"), 1.5, UIKit.C_RED)
		"boss.telegraph":
			pass
		"boss.escape_warning":
			if not _boss.is_empty():
				_boss["end_t"] = Time.get_ticks_msec() / 1000.0 + float(p["remaining_s"])
		"boss.defeated":
			hud.show_center(Loc.t("ui.boss.defeated", {"name": Loc.name_of(ContentDB.bosses[p["boss_id"]]["creature_id"])}), 3.5)
			_boss["hide_t"] = Time.get_ticks_msec() / 1000.0 + 3.0
		"boss.escaped":
			hud.show_center(Loc.t("ui.popup.boss_escaped"), 3.0, UIKit.C_RED)
			_boss["hide_t"] = Time.get_ticks_msec() / 1000.0 + 2.0
		# --- phòng
		"room.player_joined":
			if not own:
				hud.popup(Loc.t("ui.coop.joined"), UIKit.C_GREEN)
		"room.player_left":
			if not own:
				hud.popup(Loc.t("ui.coop.left", {"name": _name_of_player(p["player_id"])}), UIKit.C_MUTED)
		"room.ping":
			_add_ping(Vector3(p["position"][0], p["position"][1], p["position"][2]), String(p["kind"]), _name_of_player(actor))
		"player.emote":
			hud.popup("%s: %s" % [_name_of_player(actor), Loc.t("ui.emote." + String(p["emote"]))], UIKit.C_TEXT)
		"ui.popup_requested":
			var args: Dictionary = (p["args"] as Dictionary).duplicate() if typeof(p["args"]) == TYPE_DICTIONARY else {}
			if args.has("island_id"):
				args["name"] = Loc.name_of(String(args["island_id"]))
			var txt := Loc.t(p["text_key"], args)
			if args.has("yes") and args.has("total"):
				txt += " (%d/%d)" % [int(args["yes"]), int(args["total"])]
			hud.popup(txt, UIKit.C_GOLD if p["kind"] != "info" else UIKit.C_TEXT, 5.0)
		"world.island_entered":
			if own:
				close_menu()
				hud.show_center(Loc.name_of(p["island_id"]), 2.5)
		"tool.equipped":
			if own:
				player.set_equipped(String(p["tool_id"]))
		"tool.used":
			if own:
				player.swing()


func _end_fishing() -> void:
	player.fishing_state = "IDLE"
	player.reel_held = false
	_reel_toggled = false
	_thrashing = false
	_strain = 0.0
	_charge_t0 = -1.0
	AudioDirector.stop_loop("reel")
	AudioDirector.stop_loop("strain")


func _show_tricks(p: Dictionary) -> void:
	var tricks: Array = p["tricks"]
	var max_lines := int(ContentDB.balance["scoring"]["popup_max_lines"])
	for i in tricks.size():
		if i >= max_lines:
			hud.popup(Loc.t("ui.popup.more_tricks", {"n": tricks.size() - max_lines}), UIKit.C_TEXT)
			break
		var t: Dictionary = ContentDB.tricks.get(tricks[i], {})
		hud.popup("%s ×%.2f" % [Loc.t(t.get("name_key", String(tricks[i]))), float(t.get("multiplier", 1.0))], UIKit.C_GOLD, 3.0, 22)
	hud.popup("%s: %d %s (×%.2f)" % [Loc.t("ui.popup.total"), int(p["value"]), Loc.t("ui.currency.name"), float(p["total_multiplier"])], UIKit.C_GREEN, 3.5, 24)


func _add_ping(pos: Vector3, kind: String, who: String) -> void:
	var l := WorldView._label3d("▼ %s\n%s" % [Loc.t("ui.ping." + kind), who], 0.7)
	l.modulate = UIKit.C_GOLD
	l.no_depth_test = true
	world.add_child(l)
	l.global_position = pos + Vector3(0, 2.2, 0)
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	hud.popup("%s: %s" % [who, Loc.t("ui.ping." + kind)], UIKit.C_GOLD)


# ------------------------------------------------------------------ nhập liệu

func _aim() -> Array:
	var d := player.look_dir()
	return [clampf(d.x, -1, 1), clampf(d.y, -1, 1), clampf(d.z, -1, 1)]


func _capture_mouse() -> void:
	if Endpoints.autotest:
		return
	_want_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if _reconnecting or conn == null:
		return
	if event.is_action_pressed("pause"):
		if menu_name == "":
			open_menu("pause")
		elif menu_name == "settings":
			open_menu("pause")
		else:
			close_menu()
		get_viewport().set_input_as_handled()
		return
	if menu_name != "":
		if event.is_action_pressed("open_dex") and menu_name.begins_with("dex"):
			close_menu()
			get_viewport().set_input_as_handled()
		return
	# Nhấp để khóa chuột (trình duyệt cần cử chỉ người dùng); cú nhấp này không tính là hành động.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Endpoints.autotest:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_capture_mouse()
			get_viewport().set_input_as_handled()
		return
	if not conn.is_live() or my_mode == "knocked_out":
		return
	if event.is_action_pressed("primary"):
		_primary_down = true
		_on_primary(true)
	elif event.is_action_released("primary"):
		_primary_down = false
		_on_primary(false)
	elif event.is_action_pressed("secondary"):
		if player.equipped.begins_with("rod_") and player.fishing_state != "IDLE":
			send_cmd("fishing.action", {"action": "cancel", "aim_direction": _aim()})
	elif event.is_action_pressed("interact") or event.is_action_pressed("store_item"):
		_interact()
	elif event.is_action_pressed("open_dex"):
		open_menu("dex")
	elif event.is_action_pressed("bait_cycle"):
		_cycle_bait()
	elif event.is_action_pressed("hotbar_next") or event.is_action_pressed("hotbar_prev"):
		var slots := Hud.hotbar_items(save)
		var i := slots.find(player.equipped)
		i = wrapi(i + (1 if event.is_action_pressed("hotbar_next") else -1), 0, slots.size())
		_equip(String(slots[i]))
	else:
		for n in 4:
			if event.is_action_pressed("hotbar_%d" % (n + 1)):
				var slots2 := Hud.hotbar_items(save)
				if n < slots2.size():
					_equip(String(slots2[n]))
				break


func _equip(id: String) -> void:
	if id == player.equipped:
		return
	if player.fishing_state != "IDLE":
		_end_fishing()
	player.set_equipped(id)
	durable("equipment.equip", {"equipment_id": id})
	AudioDirector.play_ui("sfx_ui_click")


func _cycle_bait() -> void:
	var inv: Dictionary = save.get("inventory", {})
	var list: Array = []
	for bid in ContentDB.baits:
		var b: Dictionary = ContentDB.baits[bid]
		if b.has("summons_boss_id"):
			continue
		if b.get("infinite", false) or int(inv.get("bait_counts", {}).get(bid, 0)) > 0:
			list.append(bid)
	if list.size() < 2:
		return
	var i := list.find(inv.get("selected_bait_id", ""))
	durable("bait.select", {"bait_id": list[wrapi(i + 1, 0, list.size())]})


func _on_primary(pressed: bool) -> void:
	if player.equipped.begins_with("rod_"):
		var st := player.fishing_state
		var hold_mode: bool = Settings.get_value("reel_mode", "hold") == "hold"
		if pressed:
			match st:
				"IDLE":
					send_cmd("fishing.action", {"action": "charge_start", "aim_direction": _aim()})
				"WAITING", "BITING":
					send_cmd("fishing.action", {"action": "hook_set", "aim_direction": _aim()})
					if not hold_mode:
						_reel_toggled = true
				"REELING":
					if hold_mode:
						send_cmd("fishing.action", {"action": "reel_start", "aim_direction": _aim()})
					else:
						_reel_toggled = not _reel_toggled
						send_cmd("fishing.action", {"action": "reel_start" if _reel_toggled else "reel_stop", "aim_direction": _aim()})
		else:
			match st:
				"CHARGING":
					send_cmd("fishing.action", {"action": "cast_release", "aim_direction": _aim()})
				"REELING":
					if hold_mode:
						send_cmd("fishing.action", {"action": "reel_stop", "aim_direction": _aim()})
		return
	if not pressed:
		return
	# công cụ: chọn mục tiêu theo hỗ trợ ngắm; server kiểm tầm/góc/hồi chiêu
	var target := player.pick_target(player.equipped, entities)
	player.swing()
	if target != "":
		send_cmd("tool.use", {"target_uid": target})
	else:
		AudioDirector.on_event("tool.used", {"tool_id": player.equipped}, {"own": true, "player_pos": player.pos})


## Mục tương tác gần nhất: cá xỉu/đồ của mình → NPC → cọc boss.
func _focus() -> Dictionary:
	if island_id == "" or not _got_first_snapshot:
		return {}
	# Tầm tương tác do server kiểm theo vị trí của server → dùng vị trí server xác nhận gần nhất
	# (vị trí dự đoán có thể lệch khi FPS thấp).
	var pos := server_pos
	var best := {}
	var best_d := INF
	var ents := entities.latest_entities()
	for uid in ents:
		var e: Dictionary = ents[uid]
		if e["kind"] not in ["fish", "item"]:
			continue
		if e["kind"] == "fish" and String(e["state"]) not in ["stunned", "stolen"]:
			continue
		var ep := entities.entity_pos(uid)
		var d := Vector2(ep.x - pos.x, ep.z - pos.z).length()
		if d > 3.0 or absf(ep.y - pos.y) > 3.0:
			continue
		var m: Dictionary = entities.meta.get(uid, {})
		var mine: bool = m.get("owner", "") == my_id
		var score := d + (0.0 if mine else 100.0)
		if score < best_d:
			best_d = score
			best = {"kind": "pickup", "uid": uid, "def_id": e["def_id"], "mine": mine, "value": int(m.get("value", 0))}
	if not best.is_empty() and best["mine"]:
		return best
	var L := IslandLayout.layout(island_id)
	for npc_id in L["npcs"]:
		var np := IslandLayout.npc_position(island_id, npc_id)
		var d2 := np.distance_to(pos)
		if d2 <= 3.6:
			return {"kind": "npc", "npc_id": npc_id}
	var bs := IslandLayout.boss_spot(island_id)
	if _boss.is_empty() and IslandLayout.v3(island_id, bs["post"]).distance_to(pos) <= 6.0:
		for boss_id in ContentDB.bosses:
			var bd: Dictionary = ContentDB.bosses[boss_id]
			if bd["summon"]["zone_id"] == bs["zone_id"]:
				var have := int(save.get("inventory", {}).get("bait_counts", {}).get(bd["summon"]["bait_id"], 0))
				return {"kind": "boss", "boss_id": boss_id, "zone_id": bs["zone_id"], "bait_id": bd["summon"]["bait_id"], "have": have}
	return best


func _interact() -> void:
	var f := _focus()
	if Endpoints.autotest:
		print("CABAY_INTERACT %s" % str(f.get("kind", "none")))
	match String(f.get("kind", "")):
		"pickup":
			if not f["mine"]:
				hud.popup(Loc.t("ui.coop.wrong_owner"), UIKit.C_GOLD)
				return
			durable("inventory.pickup", {"item_uid": f["uid"]})
		"npc":
			send_cmd("npc.interact", {"npc_id": f["npc_id"]})
		"boss":
			if int(f["have"]) <= 0:
				hud.popup(Loc.t("ui.boss.need_bait", {"bait": Loc.name_of(f["bait_id"])}), UIKit.C_GOLD)
				return
			durable("boss.summon", {"boss_id": f["boss_id"], "zone_id": f["zone_id"]})


# ------------------------------------------------------------------ khung hình

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Trình duyệt tự nhả khóa chuột khi bấm Esc (sự kiện phím không tới trang): coi như mở tạm dừng.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not captured and _want_capture and menu_name == "" and not _reconnecting and OS.has_feature("web"):
		_want_capture = false
		open_menu("pause")
	_was_captured = captured
	# lệnh bền vững quá hạn: trả về chờ gửi lại cùng op_id
	for rid in _inflight.keys():
		if now - float(_inflight[rid]["t"]) > DURABLE_TIMEOUT_S:
			var q: Dictionary = _inflight[rid]
			_inflight.erase(rid)
			_queue.push_front(q)
			_pump_queue()
			break
	_update_cast_preview(now)
	_update_net_perf(now)
	# thanh nạp lực / căng dây
	var rod: Dictionary = ContentDB.rods.get(save.get("inventory", {}).get("equipped_rod_id", "rod_bamboo"), {})
	hud.charge_bar.visible = player.fishing_state == "CHARGING"
	if hud.charge_bar.visible and _charge_t0 > 0:
		hud.charge_bar.value = clampf((now - _charge_t0) / float(rod.get("charge_time_s", 1.2)), 0, 1) * 100.0
	hud.strain_bar.visible = player.fishing_state == "REELING"
	if hud.strain_bar.visible:
		if not _thrashing:
			_strain = maxf(0.0, _strain - _delta * 0.15)
		hud.strain_bar.value = clampf(_strain, 0, 1) * 100.0
		var col := UIKit.C_GREEN if _strain < 0.6 else (UIKit.C_GOLD if _strain < 0.85 else UIKit.C_RED)
		(hud.strain_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = col
	# boss
	if not _boss.is_empty() and _boss.has("end_t"):
		hud.boss_bar.visible = true
		hud.boss_hp.value = 100.0 * float(_boss.get("hp", 1.0)) / maxf(1.0, float(_boss.get("max_hp", 1.0)))
		var left := maxi(0, int(ceil(float(_boss["end_t"]) - now)))
		hud.boss_timer.text = "%s %d:%02d" % [Loc.t("ui.boss.escape"), left / 60, left % 60]
		# ra ngoài vòng phao: boss bỏ đi sau leave_arena_grace_s nếu cả nhóm cùng ra (boss_sim.tick)
		if not _boss.has("hide_t") and player:
			var bs := IslandLayout.boss_spot(island_id)
			var arena := IslandLayout.v3(island_id, bs["arena"])
			var d := Vector2(server_pos.x - arena.x, server_pos.z - arena.z).length()
			if d > float(bs["arena_radius"]) + 2.0 and my_mode != "knocked_out":
				hud.show_center(Loc.t("ui.boss.return_arena"), 0.3, UIKit.C_RED)
		if _boss.has("hide_t") and now > float(_boss["hide_t"]):
			_boss = {}
			hud.boss_bar.visible = false
			world_view.show_arena(false)
	# gợi ý tương tác / hướng dẫn
	if menu_name == "" and hud.prompt.text != Loc.t("ui.network.pending_save"):
		hud.prompt.text = _prompt_text()
	hud.crosshair.visible = menu_name == ""


var _last_focus_key := ""


func _prompt_text() -> String:
	if Endpoints.autotest:
		var fk := _focus()
		var key := "%s %s" % [fk.get("kind", "none"), fk.get("npc_id", fk.get("def_id", ""))]
		if key != _last_focus_key:
			_last_focus_key = key
			print("CABAY_FOCUS %s" % key)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and _got_first_snapshot and not _reconnecting and not Endpoints.autotest:
		return Loc.t("ui.hud.click_to_play")
	if my_mode == "knocked_out":
		return Loc.t("ui.player.ko")
	var f := _focus()
	match String(f.get("kind", "")):
		"pickup":
			if f["mine"]:
				return "[E] " + Loc.t("ui.prompt.pick_up", {"name": Loc.name_of(f["def_id"]), "value": "%d %s" % [int(f["value"]), Loc.t("ui.currency.name")]})
			return Loc.t("ui.coop.wrong_owner")
		"npc":
			return "[E] %s — %s" % [Loc.t("ui.prompt.talk"), Loc.name_of(f["npc_id"])]
		"boss":
			return "[E] " + Loc.t("ui.prompt.summon_boss", {"bait": Loc.name_of(f["bait_id"]), "count": int(f["have"])})
	return _tutorial_hint()


func _tutorial_hint() -> String:
	var done: Array = save.get("progress", {}).get("tutorial_done", [])
	var st := player.fishing_state
	if player.equipped.begins_with("rod_"):
		if st in ["IDLE", "CHARGING"] and "cast" not in done:
			return Loc.t("tutorial.cast")
		if st == "BITING":
			return Loc.t("ui.fishing.bite_hint")
		if st == "REELING" and "reel" not in done:
			return Loc.t("tutorial.reel")
		if st == "REELING" and _thrashing and "thrash" not in done:
			return Loc.t("tutorial.thrash")
	# cá của mình đang bay/đang giãy
	for uid in entities.latest_entities():
		var e: Dictionary = entities.latest_entities()[uid]
		if e["kind"] != "fish" or entities.meta.get(uid, {}).get("owner", "") != my_id:
			continue
		if e["state"] == "airborne" and "throw_air" not in done:
			return Loc.t("tutorial.throw_air")
		if e["state"] in ["landed", "flopping", "attacking"] and "smack" not in done:
			return Loc.t("tutorial.smack") + ("" if not player.equipped.begins_with("rod_") else "  [2]")
		if String(e["state"]).begins_with("stunned") and "pickup" not in done:
			return Loc.t("tutorial.pickup")
	if not (save.get("inventory", {}).get("bag", []) as Array).is_empty() and "sell" not in done:
		return Loc.t("tutorial.sell")
	return ""


# ------------------------------------------------------------------ HUD

func _refresh_hud() -> void:
	if save.is_empty():
		return
	hud.update_save(save, player.equipped)
	hud.objective.text = _objective_text()
	hud.room_label.text = "%s: %s" % [Loc.t("ui.coop.room_code"), String(room.get("invite_code", "?"))]


func _objective_text() -> String:
	var quests: Dictionary = save["progress"]["quests"]
	for qid in quests:
		var st: Dictionary = quests[qid]
		if st["state"] != "active":
			continue
		var q: Dictionary = ContentDB.quests.get(qid, {})
		if q.is_empty():
			continue
		var idx := int(st["step_index"])
		if idx >= q["steps"].size():
			return Loc.t("ui.quest.claim_at", {"name": Loc.name_of(q["giver_npc_id"])})
		var step: Dictionary = q["steps"][idx]
		var txt := Loc.t(step["objective_key"])
		if int(step["count"]) > 1:
			txt += " (%d/%d)" % [int(st["counts"].get(step["step_id"], 0)), int(step["count"])]
		return txt
	for qid in quests:
		if quests[qid]["state"] == "available":
			var q2: Dictionary = ContentDB.quests.get(qid, {})
			if not q2.is_empty():
				return Loc.t("ui.quest.talk_to", {"name": Loc.name_of(q2["giver_npc_id"])})
	if (save["progress"]["bosses_defeated"] as Array).size() >= 3:
		return Loc.t("ui.campaign.complete")
	return Loc.t("ui.hud.objective_none")


# ------------------------------------------------------------------ hiệu ứng hình theo sự kiện server

static func _pos(p: Dictionary) -> Variant:
	var a: Variant = p.get("position")
	if a is Array and (a as Array).size() == 3:
		return Vector3(a[0], a[1], a[2])
	return null


func _event_vfx(name: String, p: Dictionary, actor: Variant, own: bool) -> void:
	var pos: Variant = _pos(p)
	match name:
		"fishing.lure_landed":
			if pos != null and p.get("surface", "") == "water":
				VfxPlayer.spawn("vfx_lure_splash", world, pos)
		"fishing.bite":
			if pos != null:
				VfxPlayer.spawn("vfx_bite_splash", world, pos)
				if own:
					VfxPlayer.spawn("vfx_bite_indicator", world, pos + Vector3(0, 1.0, 0))
		"fishing.launched":
			if pos != null:
				VfxPlayer.spawn("vfx_yank_burst", world, pos)
		"fishing.cast_released":
			if not own and actor != null:
				entities.player_event(String(actor), "anm_player_remote_cast", 0.6)
		"tool.used":
			if not own and actor != null:
				entities.player_event(String(actor), "anm_player_remote_use_tool", 0.35)
		"tool.hit":
			if pos != null and p.get("tool_id", "") == "tool_coconut_bomb":
				VfxPlayer.spawn("vfx_confetti_explosion", world, pos)
		"creature.damaged":
			if pos != null:
				VfxPlayer.spawn("vfx_hit_confetti", world, pos + Vector3(0, 0.2, 0))
		"scoring.tricks_awarded":
			var fp := entities.entity_pos(String(p["creature_uid"]))
			if fp != Vector3.INF:
				VfxPlayer.spawn("vfx_trick_text", world, fp + Vector3(0, 1.0, 0), "+%d" % int(p["value"]))
		"economy.item_sold":
			VfxPlayer.spawn("vfx_coin_burst", world, pos if pos != null else player.pos + Vector3(0, 1.2, 0))
		"boss.telegraph":
			if pos != null:
				VfxPlayer.spawn("vfx_boss_telegraph_ring", world, pos, "", float(p.get("duration_s", 1.2)))
		"boss.phase_changed":
			var bn: Node3D = entities.nodes.get(_boss.get("uid", ""))
			if bn and bn.has_node("Model/Anim"):
				var bap: AnimationPlayer = bn.get_node("Model/Anim")
				var clip := "boss/anm_%s_phase_change" % String(ContentDB.bosses[p["boss_id"]]["creature_id"]).replace("cre_boss_", "boss_")
				if bap.has_animation(clip):
					bap.play(clip)
		"fishing.escaped", "creature.returned_to_water":
			if pos != null:
				VfxPlayer.spawn("vfx_escape_bubbles", world, pos)
		"creature.attack_started":
			if pos != null:
				VfxPlayer.spawn("vfx_attack_warn", world, pos + Vector3(0, 0.9, 0))
		"player.knocked_out":
			if not own and actor != null:
				entities.player_event(String(actor), "anm_player_remote_knocked_out", 3.0)
		"player.respawned":
			if not own and actor != null:
				entities.player_event(String(actor), "anm_player_remote_revive", 0.6)
		"dialogue.line_started":
			world_view.play_npc(String(p["npc_id"]), "anm_npc_talk", 2.5)
		"quest.completed":
			for npc_id in world_view.npc_nodes:
				if ContentDB.quests.get(p["quest_id"], {}).get("giver_npc_id", "") == npc_id:
					world_view.play_npc(npc_id, "anm_npc_happy", 0.8)
		"item.picked_up":
			if own:
				player.pickup_anim()


var _cast_preview: Node3D


## Vòng đích quăng (asset vfx_cast_preview) khi đang nạp lực: ước lượng giống công thức server.
func _update_cast_preview(now: float) -> void:
	var charging := player.fishing_state == "CHARGING" and _charge_t0 > 0.0
	if not charging:
		if _cast_preview:
			_cast_preview.queue_free()
			_cast_preview = null
		return
	var rod: Dictionary = ContentDB.rods.get(save.get("inventory", {}).get("equipped_rod_id", "rod_bamboo"), {})
	if rod.is_empty():
		return
	var ratio := clampf((now - _charge_t0) / float(rod["charge_time_s"]), 0.0, 1.0)
	var dist := lerpf(float(rod["cast_distance_m"]["min"]), float(rod["cast_distance_m"]["max"]), ratio)
	var f := Vector2(-sin(player.yaw), -cos(player.yaw))
	var t := Vector3(player.pos.x + f.x * dist, 0.0, player.pos.z + f.y * dist)
	t.y = maxf(IslandLayout.ground_height(island_id, t.x, t.z), IslandLayout.WATER_Y)
	if _cast_preview == null:
		_cast_preview = VfxPlayer.spawn("vfx_cast_preview", world, t)
	elif is_instance_valid(_cast_preview):
		_cast_preview.global_position = t


## Độ trễ (session.ping/pong mỗi 2 s) + tùy chọn FPS/bộ nhớ để đo trên máy thật (M5).
func _update_net_perf(now: float) -> void:
	if conn == null or not conn.is_live():
		return
	if now >= _next_ping:
		_next_ping = now + 2.0
		send_cmd("session.ping", {"client_monotonic_ms": Time.get_ticks_msec()})
	var txt := "● %d ms" % _rtt_ms if _rtt_ms >= 0 else "●"
	if Settings.get_value("show_perf", false) or (OS.is_debug_build() and Input.is_key_pressed(KEY_F3)):
		txt = "FPS %d · %d MB · %s" % [Engine.get_frames_per_second(), int(OS.get_static_memory_usage() / 1048576), txt]
	hud.set_net(_rtt_ms < 250, txt)
