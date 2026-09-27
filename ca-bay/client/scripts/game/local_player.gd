class_name LocalPlayer
extends Node3D
## Người chơi của máy này: camera góc nhìn thứ nhất, dự đoán di chuyển (Movement.step giống server),
## hiệu chỉnh theo snapshot, tay cầm cần/công cụ, gửi ý định (không gửi vị trí/sát thương).

var session: Node
var island_id := ""
var cam: Camera3D
var viewmodel: Node3D
var tool_holder: Node3D
var anim: AnimationPlayer
var _anim_state := ""
var rod_tip: Node3D
var pos := Vector3.ZERO
var vel_y := 0.0
var on_ground := true
var yaw := PI
var pitch := 0.0
var correction := Vector3.ZERO
var _hist: Dictionary = {}           # seq -> vị trí dự đoán khi gửi
var _input_t := 0.0
var _since_send := 0.0
var _last_sent := {}
var jump_queued := false
var equipped := "rod_bamboo"
var charging_since := -1.0
var fishing_state := "IDLE"          # theo sự kiện server của chính mình
var reel_held := false
var alive := true
var _step_t := 0.0
var _bob := 0.0
var shake := 0.0
var _tip_node: Node3D


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = float(Settings.get_value("fov_deg", 75))
	cam.near = 0.05
	cam.far = 400.0
	add_child(cam)
	viewmodel = Node3D.new()
	viewmodel.position = Vector3(0.28, -0.26, -0.45)
	cam.add_child(viewmodel)
	var hand := Models.fp_hand(Models.SKINS[0], Color("#2F6FA8"))
	hand.material_override = _viewmodel_material()
	hand.position = Vector3(0, -0.02, 0.06)
	viewmodel.add_child(hand)
	tool_holder = Node3D.new()
	tool_holder.name = "ToolHolder"
	viewmodel.add_child(tool_holder)
	# hoạt ảnh tay cầm: thư viện asset anm_lib_fp (art_src/anim/build_anim.gd)
	anim = AnimationPlayer.new()
	viewmodel.add_child(anim)
	if ResourceLoader.exists("res://assets/anim/anm_lib_fp.tres"):
		anim.add_animation_library("fp", load("res://assets/anim/anm_lib_fp.tres"))
		anim.play("fp/anm_fp_idle")
	rod_tip = Node3D.new()
	add_child(rod_tip)
	cam.current = true
	Settings.changed.connect(func(k): if k == "fov_deg": cam.fov = float(Settings.get_value("fov_deg", 75)))


func spawn_at(p: Vector3, isl: String) -> void:
	island_id = isl
	pos = p
	vel_y = 0.0
	correction = Vector3.ZERO
	_hist.clear()


func set_equipped(id: String) -> void:
	equipped = id
	UIKit.clear(tool_holder)
	var tint: Variant = null
	var cos_id: String = session.save.get("cosmetics", {}).get("equipped", {}).get(id, "")
	if cos_id != "" and ContentDB.cosmetics.has(cos_id):
		tint = Color(ContentDB.cosmetics[cos_id]["color_hex"])
	_tip_node = null
	if id == "tool_hand":
		# tay không: chính bàn tay góc nhìn thứ nhất là "công cụ", không gắn thêm mô hình
		tool_holder.position = Vector3.ZERO
		tool_holder.rotation = Vector3.ZERO
		play_fp("anm_fp_equip", true)
		return
	var m := Models.tool_model(id, tint)
	m.material_override = _viewmodel_material()
	tool_holder.add_child(m)
	if id.begins_with("rod_"):
		m.rotation_degrees = Vector3(34, -12, 0)
		m.position = Vector3(0.04, -0.02, 0.02)
		m.scale = Vector3.ONE * 0.85
		# đầu cần thật của mô hình (cần dài 1,5 m theo -Z) → dây câu xuất phát đúng chỗ
		_tip_node = Node3D.new()
		_tip_node.position = Vector3(0, 0, -1.5)
		m.add_child(_tip_node)
	elif id == "tool_broom":
		m.rotation_degrees = Vector3(40, 0, 0)
	else:
		m.rotation_degrees = Vector3(10, 0, 0)
	tool_holder.position = Vector3.ZERO
	tool_holder.rotation = Vector3.ZERO
	play_fp("anm_fp_equip", true)


func rod_tip_world() -> Vector3:
	if _tip_node and is_instance_valid(_tip_node) and _tip_node.is_inside_tree():
		return _tip_node.global_position
	# dự phòng: ~1.5 m trước tay theo hướng nhìn
	var base := cam.global_transform * Vector3(0.28, -0.1, -0.5)
	var fwd := -cam.global_transform.basis.z
	return base + fwd * 1.3 + Vector3(0, 0.55, 0)


func look_dir() -> Vector3:
	return Movement.look_dir(yaw, pitch)


func _notification(what: int) -> void:
	# Mất focus cửa sổ/tab: trình duyệt không gửi keyup cho phím đang giữ → nhả hết để không đi/kéo cần mãi.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		for a in InputMap.get_actions():
			if Input.is_action_pressed(a):
				Input.action_release(a)


func _unhandled_input(event: InputEvent) -> void:
	if not session or not session.gameplay_input_enabled():
		return
	if Endpoints.autotest and event is InputEventKey and event.pressed and not event.echo:
		# Theo sự kiện (không theo trạng thái phím) để không lỡ khi FPS thấp.
		print("CABAY_KEY %s fps=%d snaps=%d pos=%s server=%s focus=%s" % [OS.get_keycode_string(event.keycode), Engine.get_frames_per_second(), session.snap_count, str(pos), str(session.server_pos), str(session._focus())])
		match event.physical_keycode:
			KEY_T: _autotest_face_nearest()
			KEY_G: _autotest_face_fishing_zone()
			KEY_N: _autotest_face_nearest_npc()
			KEY_V: _autotest_face_point(IslandLayout.npc_position(island_id, IslandLayout.shop_zone(island_id)["npc_id"]))
			KEY_P: _autotest_face_other_player()
			KEY_U: _autotest_face_point(IslandLayout.v3(island_id, IslandLayout.boss_spot(island_id)["post"], 1.0))
			KEY_Y: _autotest_face_point(IslandLayout.v3(island_id, IslandLayout.boss_spot(island_id)["arena"], 1.0))
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Endpoints.autotest:
		var sens := 0.0025 * float(Settings.get_value("mouse_sensitivity", 1.0))
		yaw = wrapf(yaw - event.relative.x * sens, -PI, PI)
		var inv := -1.0 if Settings.get_value("invert_y", false) else 1.0
		pitch = clampf(pitch - event.relative.y * sens * inv, -1.45, 1.45)


func _physics_process(delta: float) -> void:
	if not session or island_id == "":
		return
	var enabled: bool = session.gameplay_input_enabled() and alive
	var mx := 0.0
	var mz := 0.0
	if enabled and Endpoints.autotest:
		var ky := float(Input.is_physical_key_pressed(KEY_J)) - float(Input.is_physical_key_pressed(KEY_L))
		var kp := float(Input.is_physical_key_pressed(KEY_I)) - float(Input.is_physical_key_pressed(KEY_K))
		yaw = wrapf(yaw + ky * 1.5 * delta, -PI, PI)
		pitch = clampf(pitch + kp * 1.0 * delta, -1.45, 1.45)

	if enabled:
		mx = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		mz = Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
		if Input.is_action_just_pressed("jump") and on_ground:
			jump_queued = true
	var st := Movement.step(island_id, {"pos": pos, "vel_y": vel_y, "on_ground": on_ground}, mx, mz, yaw, jump_queued, delta)
	var was_ground := on_ground
	pos = st["pos"]
	vel_y = st["vel_y"]
	on_ground = st["on_ground"]
	if jump_queued and not on_ground:
		AudioDirector.on_event("player.jumped", {}, {"player_pos": pos})
	if on_ground and not was_ground:
		AudioDirector.on_event("player.landed", {}, {"player_pos": pos})
	# bước chân
	if on_ground and Vector2(mx, mz).length() > 0.1:
		_step_t += delta
		_bob += delta * 9.0
		if _step_t > 0.42:
			_step_t = 0.0
			var surf := "wood" if IslandLayout.on_pier(island_id, pos.x, pos.z) else "sand"
			AudioDirector.on_event("player.footstep", {"surface": surf}, {"player_pos": pos})
	# hiệu chỉnh dần về vị trí server
	var c := correction * minf(1.0, delta * 10.0)
	pos += c
	correction -= c
	global_position = pos
	var bob := sin(_bob) * 0.03 if on_ground else 0.0
	cam.position = Vector3(0, float(ContentDB.balance["player"]["eye_height_m"]) + bob, 0)
	cam.rotation = Vector3(pitch, yaw, 0)
	if shake > 0.0 and Settings.get_value("camera_shake", true):
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.05
		shake = maxf(0.0, shake - delta * 3.0)
	rod_tip.global_position = rod_tip_world()
	_input_t += delta
	_since_send += delta
	if _input_t >= 0.05:
		_input_t = 0.0
		var payload := {"move_x": mx, "move_z": mz, "look_yaw_rad": yaw, "look_pitch_rad": pitch, "jump": jump_queued}
		# gửi khi đổi, và ít nhất mỗi 0,25 s để server biết phím vẫn đang giữ (server bỏ input cũ quá 1 s)
		if payload != _last_sent or _since_send >= 0.25:
			var rid: String = session.conn.send("player.input", payload)
			if rid != "":
				_hist[session.conn.seq] = pos
				_last_sent = payload
				_since_send = 0.0
		jump_queued = false
	_animate_viewmodel(delta)


## Hiệu chỉnh: so vị trí server (sau input seq N) với vị trí dự đoán lúc gửi N.
func reconcile(server_pos: Vector3, ack_seq: int) -> void:
	if not _hist.has(ack_seq):
		if server_pos.distance_to(pos) > 3.0:
			pos = server_pos
		return
	var predicted: Vector3 = _hist[ack_seq]
	for k in _hist.keys():
		if k <= ack_seq:
			_hist.erase(k)
	var err := server_pos - predicted
	if err.length() > 4.0:
		pos = server_pos
		correction = Vector3.ZERO
	elif err.length() > 0.03:
		correction = err


func _animate_viewmodel(_delta: float) -> void:
	# trạng thái lặp theo máy trạng thái câu của server; hoạt ảnh một lần (quăng, giật, đập) không bị cắt ngang
	var want := "anm_fp_idle"
	match fishing_state:
		"CHARGING": want = "anm_fp_cast_charge"
		"REELING": want = "anm_fp_reel_loop" if reel_held else "anm_fp_idle"
	if anim == null or not anim.has_animation("fp/" + want):
		return
	var cur := anim.current_animation.trim_prefix("fp/")
	var one_shot_playing: bool = anim.is_playing() and cur in ["anm_fp_equip", "anm_fp_cast_release", "anm_fp_yank", "anm_fp_slap", "anm_fp_throw", "anm_fp_sweep", "anm_fp_pickup"]
	if one_shot_playing:
		return
	if cur != want or not anim.is_playing():
		if want == "anm_fp_cast_charge" and cur == want:
			return
		anim.play("fp/" + want, 0.12)
	if fishing_state == "BITING":
		tool_holder.rotation.x += sin(Time.get_ticks_msec() / 25.0) * 0.02


func play_fp(clip: String, force := false) -> void:
	if anim and anim.has_animation("fp/" + clip):
		if force or anim.current_animation != "fp/" + clip:
			anim.play("fp/" + clip, 0.05)
			anim.seek(0.0, true)


func swing() -> void:
	var kind: String = ContentDB.tools.get(equipped, {}).get("kind", "melee")
	var clip := "anm_fp_slap"
	if equipped == "tool_broom":
		clip = "anm_fp_sweep"
	elif kind in ["throwable", "ranged", "explosive"]:
		clip = "anm_fp_throw"
	play_fp(clip, true)


func cast_anim() -> void:
	play_fp("anm_fp_cast_release", true)


func yank_anim() -> void:
	play_fp("anm_fp_yank", true)
	shake = 0.6


func pickup_anim() -> void:
	play_fp("anm_fp_pickup", true)


## Chọn mục tiêu cho công cụ theo hỗ trợ ngắm (aim_assist trong balance.json).
func pick_target(tool_id: String, entities: EntityView) -> String:
	var tool: Dictionary = ContentDB.tools.get(tool_id, {})
	var aa: Dictionary = ContentDB.balance["aim_assist"]
	var eye := Movement.eye(pos)
	var dir := look_dir()
	var best := ""
	var best_score := INF
	# Cùng giới hạn với server (creature_sim.use_tool): tầm = range + 1.1 m (boss +0.9), góc cận chiến = arc/2 + 25°.
	var cone := float(aa["cone_deg"]) + 10.0 if tool.get("kind", "melee") != "melee" else float(tool.get("arc_deg", 60)) * 0.5 + 20.0
	var max_d := minf(float(tool.get("range_m", 1.2)) + 1.0, float(aa["max_distance_m"]) + 10.0)
	for uid in entities.latest_entities():
		var e: Dictionary = entities.latest_entities()[uid]
		if e["kind"] not in ["fish", "boss"]:
			continue
		var p := entities.entity_pos(uid) + Vector3(0, 0.2 if e["kind"] == "fish" else 1.0, 0)
		var d := eye.distance_to(p)
		if d > max_d + (0.9 if e["kind"] == "boss" else 0.0):
			continue
		var ang := rad_to_deg(dir.angle_to((p - eye).normalized()))
		if ang > cone and d > 1.2:
			continue
		var ko := String(e["state"]).begins_with("stunned")
		var score := ang + d * 0.5 + (30.0 if ko else 0.0)
		if score < best_score:
			best_score = score
			best = uid
	return best


## Chỉ dùng ở chế độ kiểm thử tự động: quay mặt về cá/boss gần nhất (thay cho rê chuột).
func _autotest_face_nearest() -> void:
	var ents: EntityView = session.entities
	var best := Vector3.INF
	for uid in ents.latest_entities():
		var e: Dictionary = ents.latest_entities()[uid]
		if e["kind"] not in ["fish", "boss"]:
			continue
		var p := ents.entity_pos(uid)
		if best == Vector3.INF or p.distance_to(pos) < best.distance_to(pos):
			best = p
	if best == Vector3.INF:
		return
	var d := best + Vector3(0, 0.15, 0) - Movement.eye(pos)
	yaw = atan2(-d.x, -d.z)
	pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.45, 1.45)


## Chỉ dùng ở chế độ kiểm thử tự động: quay mặt về tâm vùng câu gần nhất.
func _autotest_face_fishing_zone() -> void:
	var best := Vector2.INF
	for zid in IslandLayout.layout(island_id)["fishing"]:
		var c: Vector2 = IslandLayout.layout(island_id)["fishing"][zid][0]
		if best == Vector2.INF or c.distance_to(Vector2(pos.x, pos.z)) < best.distance_to(Vector2(pos.x, pos.z)):
			best = c
	if best == Vector2.INF:
		return
	yaw = atan2(-(best.x - pos.x), -(best.y - pos.z))
	pitch = 0.0


## Chỉ dùng ở chế độ kiểm thử tự động: quay mặt về NPC giao nhiệm vụ (không phải người bán).
func _autotest_face_nearest_npc() -> void:
	var best := Vector3.INF
	for npc_id in IslandLayout.layout(island_id)["npcs"]:
		if ContentDB.npcs.get(npc_id, {}).has("shop_id"):
			continue
		var np := IslandLayout.npc_position(island_id, npc_id)
		if best == Vector3.INF or np.distance_to(pos) < best.distance_to(pos):
			best = np
	if best == Vector3.INF:
		return
	yaw = atan2(-(best.x - pos.x), -(best.z - pos.z))
	pitch = -0.1


func _autotest_face_point(p: Vector3) -> void:
	if p == Vector3.INF:
		return
	yaw = atan2(-(p.x - pos.x), -(p.z - pos.z))
	pitch = -0.1


## Chỉ dùng ở chế độ kiểm thử tự động: quay về đồng đội gần nhất.
func _autotest_face_other_player() -> void:
	var ents: EntityView = session.entities
	var best := Vector3.INF
	for aid in ents.players_meta:
		if aid == ents.my_account_id or not ents.nodes.has(aid):
			continue
		var p: Vector3 = ents.nodes[aid].global_position + Vector3(0, 1.5, 0)
		if best == Vector3.INF or p.distance_to(pos) < best.distance_to(pos):
			best = p
	if best != Vector3.INF:
		var d := best - Movement.eye(pos)
		yaw = atan2(-d.x, -d.z)
		pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.45, 1.45)


static var _vm_mat: ShaderMaterial


## asset shd_fp_viewmodel: tay/cần không bị cảnh vật che hay xuyên vào tường/NPC.
static func _viewmodel_material() -> ShaderMaterial:
	if _vm_mat == null:
		_vm_mat = ShaderMaterial.new()
		_vm_mat.shader = load("res://assets/shaders/shd_fp_viewmodel.gdshader")
		_vm_mat.render_priority = 10
	return _vm_mat
