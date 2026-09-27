class_name EntityView
extends Node3D
## Hiển thị người chơi khác và thực thể từ snapshot server (nội suy lùi 100 ms).
## Chỉ trình bày: trạng thái, chủ sở hữu, giá trị đều đến từ server.

const INTERP_MS := 100.0
const WIGGLE := preload("res://assets/shaders/shd_creature_wiggle.gdshader")
const HIT_FLASH := preload("res://assets/shaders/shd_hit_flash.gdshader")
const BOSS_CLIPS := {"arriving": "land", "idle": "idle", "recover": "idle", "attack_slam": "slam", "charging": "charge",
	"attack_spit": "spit", "stunned": "stunned", "defeated": "defeat", "escaping": "escape"}

var my_account_id: String = ""
var snaps: Array = []                 # [{t, players:{}, entities:{}}]
var nodes: Dictionary = {}            # uid/account_id -> Node3D
var meta: Dictionary = {}             # uid -> {owner, variant, value, tricks}
var players_meta: Dictionary = {}     # account_id -> {name, slot, mode, hp}
var slot_of: Dictionary = {}          # slot index -> account_id
var lines: Dictionary = {}            # account_id -> MeshInstance3D dây câu
var player_colors := [Color("#E4473C"), Color("#2F6FA8"), Color("#6CC24A"), Color("#B79AD9")]
var local_rod_tip: Node3D


func push_snapshot(s: Dictionary) -> void:
	var t := Time.get_ticks_msec()
	var pl := {}
	var i := 0
	for p in s["players"]:
		pl[p["account_id"]] = p
		players_meta[p["account_id"]] = {"name": p["display_name"], "mode": p["mode"], "hp": p["hp"], "slot": i}
		slot_of[i] = p["account_id"]
		i += 1
	var en := {}
	for e in s["entities"]:
		en[e["uid"]] = e
	snaps.append({"t": t, "players": pl, "entities": en})
	while snaps.size() > 8:
		snaps.pop_front()
	# xóa nút không còn
	for key in nodes.keys():
		if not pl.has(key) and not en.has(key):
			nodes[key].queue_free()
			nodes.erase(key)
			if lines.has(key):
				lines[key].queue_free()
				lines.erase(key)


func latest_entities() -> Dictionary:
	return snaps[-1]["entities"] if not snaps.is_empty() else {}


func entity_pos(uid: String) -> Vector3:
	if nodes.has(uid):
		return nodes[uid].global_position
	var e: Dictionary = latest_entities().get(uid, {})
	if e.is_empty():
		return Vector3.INF
	return Vector3(e["position"][0], e["position"][1], e["position"][2])


func _process(delta: float) -> void:
	if snaps.is_empty():
		return
	var render_t := Time.get_ticks_msec() - INTERP_MS
	var a: Dictionary = snaps[0]
	var b: Dictionary = snaps[-1]
	for i in range(snaps.size() - 1):
		if snaps[i]["t"] <= render_t and snaps[i + 1]["t"] >= render_t:
			a = snaps[i]
			b = snaps[i + 1]
			break
	var span: float = maxf(1.0, float(b["t"] - a["t"]))
	var f := clampf((render_t - a["t"]) / span, 0.0, 1.0)
	for aid in b["players"]:
		if aid == my_account_id:
			continue
		var pb: Dictionary = b["players"][aid]
		var pa: Dictionary = a["players"].get(aid, pb)
		var n := _player_node(aid, pb)
		var p0 := _v(pa["position"])
		var p1 := _v(pb["position"])
		n.global_position = p0.lerp(p1, f)
		n.rotation.y = lerp_angle(float(pa["yaw_rad"]), float(pb["yaw_rad"]), f)
		n.visible = pb["mode"] != "disconnected"
		var spd := p0.distance_to(p1) / maxf(0.05, span / 1000.0)
		_animate_player(aid, n, pb, spd, b)
	for uid in b["entities"]:
		var eb: Dictionary = b["entities"][uid]
		var ea: Dictionary = a["entities"].get(uid, eb)
		var n2 := _entity_node(uid, eb)
		n2.global_position = _v(ea["position"]).lerp(_v(eb["position"]), f)
		n2.rotation.y = lerp_angle(float(ea["yaw_rad"]), float(eb["yaw_rad"]), f)
		_update_entity_visual(n2, uid, eb, delta)
	_update_lines(b)


static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _player_node(aid: String, p: Dictionary) -> Node3D:
	if nodes.has(aid):
		return nodes[aid]
	var slot: int = players_meta.get(aid, {}).get("slot", 0)
	var root := Node3D.new()
	root.name = "P_" + aid.substr(0, 8)
	var av := Models.person(Models.SKINS[slot % 3], player_colors[slot % 4], Models.CLOTHES[3], ["non_la", "cap", "scarf", "hat"][slot % 4])
	av.name = "Avatar"
	av.rotation.y = PI
	root.add_child(av)
	var rod := Models.tool_model("rod_bamboo")
	rod.name = "Rod"
	rod.position = Vector3(0.32, 1.0, -0.2)
	rod.rotation_degrees = Vector3(35, 0, 0)
	root.add_child(rod)
	var tip := Node3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0, 0, -1.5)
	rod.add_child(tip)
	var lbl := WorldView.screen_label(p["display_name"], 24.0)
	lbl.name = "Name"
	lbl.modulate = player_colors[slot % 4].lightened(0.4)
	lbl.position = Vector3(0, 2.35, 0)
	root.add_child(lbl)
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	root.add_child(ap)
	_add_lib(ap, "pl", "res://assets/anim/anm_lib_player_remote.tres")
	add_child(root)
	nodes[aid] = root
	return root


func _entity_node(uid: String, e: Dictionary) -> Node3D:
	if nodes.has(uid):
		return nodes[uid]
	var root := Node3D.new()
	var kind: String = e["kind"]
	var def_id: String = e["def_id"]
	var m: Dictionary = meta.get(uid, {})
	match kind:
		"fish", "item":
			var model: Node3D
			if ContentDB.creatures.has(def_id):
				model = Models.creature(def_id, m.get("variant"))
				model.scale = Vector3.ONE * 1.6
				var sm := ShaderMaterial.new()
				sm.shader = WIGGLE
				(model.get_node("Body") as MeshInstance3D).material_override = sm
			else:
				model = Node3D.new()
				model.add_child(Models.item(def_id))
			model.name = "Model"
			root.add_child(model)
			var stars := Label3D.new()
			stars.name = "Stars"
			stars.text = "★ ★ ★"
			stars.modulate = Color("#FFC93C")
			stars.outline_size = 8
			stars.font_size = 40
			stars.pixel_size = 0.004
			stars.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			stars.position = Vector3(0, 0.55, 0)
			stars.visible = false
			root.add_child(stars)
			var info := WorldView.screen_label("", 22.0)
			info.name = "Info"
			info.position = Vector3(0, 0.95, 0)
			info.visible = false
			root.add_child(info)
		"boss":
			var bm := Models.creature(def_id)
			bm.name = "Model"
			bm.scale = Vector3.ONE * 3.2
			var bsm := ShaderMaterial.new()
			bsm.shader = HIT_FLASH
			(bm.get_node("Body") as MeshInstance3D).material_override = bsm
			var bap := AnimationPlayer.new()
			bap.name = "Anim"
			bm.add_child(bap)
			_add_lib(bap, "boss", "res://assets/anim/anm_lib_%s.tres" % def_id.replace("cre_boss_", "boss_"))
			root.add_child(bm)
			var hb := WorldView._label3d("", 0.8)
			hb.name = "Info"
			hb.position = Vector3(0, 3.6, 0)
			root.add_child(hb)
		"prop":
			match def_id:
				"lure":
					var bob := Models.bobber()
					bob.scale = Vector3.ONE * 2.5  # dễ thấy ở xa (phao cỡ đồ chơi)
					root.add_child(bob)
				"boss_projectile":
					root.add_child(Models.water_blob())
				"thief_bird":
					var h := Models.heron()
					h.name = "Model"
					root.add_child(h)
					var hap := AnimationPlayer.new()
					hap.name = "Anim"
					root.add_child(hap)
					_add_lib(hap, "egret", "res://assets/anim/anm_lib_egret.tres")
				_:
					root.add_child(Models.bobber())
	add_child(root)
	nodes[uid] = root
	return root


func _update_entity_visual(n: Node3D, uid: String, e: Dictionary, delta: float) -> void:
	var state: String = e["state"]
	match String(e["kind"]):
		"fish":
			var model: Node3D = n.get_node("Model")
			var stars: Label3D = n.get_node("Stars")
			var info: Label3D = n.get_node("Info")
			var ko := state.begins_with("stunned") or state == "stolen"
			var star_vfx := _ensure_vfx(n, "KoStars", "vfx_ko_stars", ko, Vector3(0, 0.45, 0))
			stars.visible = ko and star_vfx == null
			_ensure_vfx(n, "Trail", "vfx_air_trail", state == "airborne")
			_ensure_vfx(n, "Sparkle", "vfx_boba_sparkle", meta.get(uid, {}).get("variant") != null)
			var wm: ShaderMaterial = (model.get_node("Body") as MeshInstance3D).material_override if model.has_node("Body") else null
			if wm:
				wm.set_shader_parameter("wiggle", 0.0 if ko else (1.0 if state in ["landed", "airborne"] else 0.4))
			if ko:
				stars.rotation.y += delta * 4.0
				model.rotation.z = lerpf(model.rotation.z, PI * 0.5, 10 * delta)  # nằm nghiêng (xỉu)
				if state == "stunned_waking":
					model.visible = int(Time.get_ticks_msec() / 150) % 2 == 0
				else:
					model.visible = true
			else:
				model.visible = true
				model.rotation.z = sin(Time.get_ticks_msec() / 90.0) * 0.35 if state == "landed" else 0.0
				if state == "airborne":
					model.rotation.x += delta * 6.0
				else:
					model.rotation.x = 0.0
			var m: Dictionary = meta.get(uid, {})
			var owner: String = m.get("owner", "")
			var cam := get_viewport().get_camera_3d()
			var near: bool = cam != null and cam.global_position.distance_to(n.global_position) < 14.0
			if ko and m.has("value") and near:
				var nm: String = players_meta.get(owner, {}).get("name", "?")
				info.text = "%s · %d %s" % [Loc.name_of(e["def_id"]), int(m["value"]), Loc.t("ui.currency.name")]
				if owner != my_account_id:
					info.text += "\n" + Loc.t("ui.coop.loot_owner", {"name": nm})
				info.modulate = Color("#FFF8E7") if owner == my_account_id else Color("#B8C4C8")
				info.visible = true
			else:
				info.visible = false
		"boss":
			var info2: Label3D = n.get_node("Info")
			var bm: Node3D = n.get_node("Model")
			var hp: float = meta.get(uid, {}).get("hp_ratio", 1.0)
			info2.text = "%s\n%s" % [Loc.name_of(e["def_id"]), "█".repeat(int(round(hp * 20))) + "░".repeat(20 - int(round(hp * 20)))]
			var bap2: AnimationPlayer = bm.get_node_or_null("Anim")
			if bap2:
				var clip: String = BOSS_CLIPS.get(state, "idle")
				if state.begins_with("telegraph_"):
					clip = "telegraph_spit" if state.contains("splash") or state.contains("spit") else ("telegraph_charge" if state.contains("charge") else "telegraph_slam")
				_play(bap2, "boss", "anm_%s_%s" % [String(e["def_id"]).replace("cre_boss_", "boss_"), clip])
		"prop":
			if e["def_id"] == "lure":
				n.position.y += sin(Time.get_ticks_msec() / 200.0) * 0.03 * (3.0 if state.ends_with("biting") else 1.0)
				_ensure_vfx(n, "Ripple", "vfx_bobber_ripple", not state.ends_with("flying"))
			elif e["def_id"] == "thief_bird":
				var hap2: AnimationPlayer = n.get_node_or_null("Anim")
				if hap2:
					var prev: Vector3 = n.get_meta("prev_pos", n.global_position)
					n.set_meta("prev_pos", n.global_position)
					_play(hap2, "egret", "anm_egret_fly" if prev.distance_to(n.global_position) > 0.02 or state == "leave" else "anm_egret_walk")


func _update_lines(b: Dictionary) -> void:
	for uid in b["entities"]:
		var e: Dictionary = b["entities"][uid]
		if e["def_id"] != "lure":
			continue
		var st: String = e["state"]
		var parts := st.split("_")
		if parts.size() < 3:
			continue
		var slot := int(parts[1].trim_prefix("s"))
		var aid: String = slot_of.get(slot, "")
		if aid == "":
			continue
		var from: Vector3
		if aid == my_account_id:
			if local_rod_tip == null or not is_instance_valid(local_rod_tip):
				continue
			from = local_rod_tip.global_position
		elif nodes.has(aid):
			from = nodes[aid].get_node("Rod/Tip").global_position
		else:
			continue
		var to: Vector3 = nodes[uid].global_position if nodes.has(uid) else _v(e["position"])
		_draw_line(uid, from, to, st.ends_with("reeling"))
	for key in lines.keys():
		if not b["entities"].has(key):
			var holder: Node = lines[key].get_parent()
			(holder if holder is VfxPlayer else lines[key]).queue_free()
			lines.erase(key)


func _draw_line(key: String, a: Vector3, b: Vector3, taut: bool) -> void:
	var mi: MeshInstance3D = lines.get(key)
	if mi == null:
		# asset vfx_fishing_line: nút Line (ImmediateMesh) vẽ lại mỗi khung
		var holder := VfxPlayer.spawn("vfx_fishing_line", self, Vector3.ZERO)
		if holder and holder.has_node("Line"):
			mi = holder.get_node("Line")
			mi.mesh = ImmediateMesh.new()
		else:
			mi = MeshInstance3D.new()
			mi.mesh = ImmediateMesh.new()
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.95, 0.95, 0.9)
			mi.material_override = mat
			add_child(mi)
		mi.top_level = true
		lines[key] = mi
	var im: ImmediateMesh = mi.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var sag := 0.0 if taut else clampf(a.distance_to(b) * 0.08, 0.0, 1.5)
	for i in 13:
		var t := i / 12.0
		var p := a.lerp(b, t)
		p.y -= sin(t * PI) * sag
		im.surface_add_vertex(p)
	im.surface_end()


## Chớp trắng khi trúng đòn (sự kiện creature.damaged của server).
func flash(uid: String) -> void:
	var n: Node3D = nodes.get(uid)
	if n == null or not n.has_node("Model/Body"):
		return
	var sm: ShaderMaterial = (n.get_node("Model/Body") as MeshInstance3D).material_override
	if sm == null:
		return
	sm.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v): sm.set_shader_parameter("flash", v), 1.0, 0.0, 0.18)


static func _add_lib(ap: AnimationPlayer, lib: String, path: String) -> void:
	if ResourceLoader.exists(path):
		ap.add_animation_library(lib, load(path))


static func _play(ap: AnimationPlayer, lib: String, clip: String, blend := 0.15) -> void:
	var full := lib + "/" + clip
	if ap.has_animation(full) and ap.current_animation != full:
		ap.play(full, blend)


## Hiệu ứng gắn theo thực thể: bật khi `on`, gỡ khi tắt. Trả nút đang có (hoặc null).
func _ensure_vfx(n: Node3D, child: String, vfx_id: String, on: bool, offset := Vector3.ZERO) -> Node3D:
	var cur: Node3D = n.get_node_or_null(child)
	if on and cur == null:
		cur = VfxPlayer.spawn(vfx_id, n, n.global_position + offset)
		if cur:
			cur.name = child
	elif not on and cur != null:
		cur.queue_free()
		cur = null
	return cur


var _player_oneshot: Dictionary = {}   # account_id -> {clip, until}


## Sự kiện của người chơi khác → hoạt ảnh một lần (quăng, dùng công cụ, xỉu, hồi sinh).
func player_event(aid: String, clip: String, seconds: float) -> void:
	_player_oneshot[aid] = {"clip": clip, "until": Time.get_ticks_msec() / 1000.0 + seconds}
	var n: Node3D = nodes.get(aid)
	if n and n.has_node("Anim"):
		var ap: AnimationPlayer = n.get_node("Anim")
		if ap.has_animation("pl/" + clip):
			ap.play("pl/" + clip, 0.08)
			ap.seek(0.0, true)


func _animate_player(aid: String, n: Node3D, p: Dictionary, spd: float, snap: Dictionary) -> void:
	var ap: AnimationPlayer = n.get_node_or_null("Anim")
	if ap == null:
		return
	var os: Dictionary = _player_oneshot.get(aid, {})
	if not os.is_empty() and Time.get_ticks_msec() / 1000.0 < float(os["until"]):
		return
	if p["mode"] == "knocked_out":
		_play(ap, "pl", "anm_player_remote_knocked_out")
		return
	# đang kéo cá: phao của người này ở trạng thái reeling
	var slot: int = players_meta.get(aid, {}).get("slot", -1)
	for uid in snap["entities"]:
		var e: Dictionary = snap["entities"][uid]
		if e["def_id"] == "lure" and String(e["state"]) == "lure_s%d_reeling" % slot:
			_play(ap, "pl", "anm_player_remote_reel")
			return
	_play(ap, "pl", "anm_player_remote_idle" if spd < 0.4 else ("anm_player_remote_walk" if spd < 3.4 else "anm_player_remote_run"))
