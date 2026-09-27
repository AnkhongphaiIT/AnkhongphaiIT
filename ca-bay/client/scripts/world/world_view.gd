class_name WorldView
extends Node3D
## Dựng cảnh một đảo từ IslandLayout (cùng hàm độ cao với server): địa hình, nước, bến, cây, nhà,
## sạp, NPC, cọc boss, tổ cò, trời và nắng. Chỉ trình bày; không quyết định gameplay.

const EXTENT := 84.0
const STEP := 2.0

var island_id: String = ""
var npc_nodes: Dictionary = {}   # npc_id -> Node3D
var sun: DirectionalLight3D
var env: WorldEnvironment
var water: MeshInstance3D

static var _water_shader: Shader

const PALETTES := {
	"cu_lao": {"sand": Color("#E9C98B"), "grass": Color("#7CC24A"), "grass2": Color("#8FCB55"), "mud": Color("#9C8455"), "shallow": Color("#56B6A6"), "deep": Color("#2A7F86"), "bed": Color("#9C8455")},
	"rung_dua": {"sand": Color("#C9B07A"), "grass": Color("#5FAE45"), "grass2": Color("#4E9A3A"), "mud": Color("#8D6A4A"), "shallow": Color("#4FA88C"), "deep": Color("#26766E"), "bed": Color("#6B5A3A")},
	"mui_da": {"sand": Color("#E6D3A3"), "grass": Color("#86B85A"), "grass2": Color("#9AA890"), "mud": Color("#8E8E86"), "shallow": Color("#3FB8C4"), "deep": Color("#1F6F9C"), "bed": Color("#7A8A8E")},
}


func build(isl: String) -> void:
	for c in get_children():
		c.queue_free()
	npc_nodes.clear()
	island_id = isl
	var L := IslandLayout.layout(isl)
	var pal: Dictionary = PALETTES.get(L.get("palette", "cu_lao"), PALETTES["cu_lao"])
	_build_environment(L)
	_build_terrain(pal)
	_build_water(pal)
	_build_pier(L)
	_build_props(L)
	_build_shop(L)
	_build_npcs(L)
	_build_boss_post(L)
	var nest := Models.nest()
	nest.position = IslandLayout.v3(isl, L["nest"], 0.02)
	add_child(nest)
	var boat := Models.boat()
	var pf: Vector2 = L["pier"]["from"]
	var pt: Vector2 = L["pier"]["to"]
	boat.position = Vector3(pt.x + 4.0, 0.05, lerpf(pf.y, pt.y, 0.7))
	boat.rotation.y = 0.15
	add_child(boat)
	_build_zone_signs(L)


func _build_environment(L: Dictionary) -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color("#5EC8F2")
	mat.sky_horizon_color = Color("#CDEFF7")
	mat.ground_horizon_color = Color("#CDEFF7")
	mat.ground_bottom_color = Color("#3FB8AF")
	mat.sun_angle_max = 20.0
	sky.sky_material = mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.fog_enabled = true
	e.fog_light_color = Color("#CDEFF7")
	e.fog_density = 0.0012
	e.fog_sky_affect = 0.0
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.light_color = Color("#FFF1D6")
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.shadow_enabled = String(Settings.get_value("quality", "low")) != "low"
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


func _color_at(pal: Dictionary, x: float, z: float, h: float) -> Color:
	if h < -0.4:
		return (pal["bed"] as Color).darkened(clampf(-h / 6.0, 0.0, 0.4))
	if h < 0.35:
		return pal["sand"]
	var n := sin(x * 0.37) * cos(z * 0.29)
	if L_is_mud(x, z):
		return pal["mud"]
	return (pal["grass"] as Color).lerp(pal["grass2"], 0.5 + 0.5 * n)


func L_is_mud(x: float, z: float) -> bool:
	var L := IslandLayout.layout(island_id)
	for zid in L["fishing"]:
		var f: Array = L["fishing"][zid]
		if String(zid).ends_with("bai_bun") and Vector2(x, z).distance_to(f[0]) < float(f[1]) + 7.0:
			return true
	return false


func _build_terrain(pal: Dictionary) -> void:
	var k := MeshKit.new()
	var n := int(EXTENT * 2.0 / STEP)
	var hs: Array = []
	for i in n + 1:
		var row: Array = []
		for j in n + 1:
			var x := -EXTENT + i * STEP
			var z := -EXTENT + j * STEP
			row.append(IslandLayout.terrain_height(island_id, x, z))
		hs.append(row)
	for i in n:
		for j in n:
			var x0 := -EXTENT + i * STEP
			var z0 := -EXTENT + j * STEP
			var h00: float = hs[i][j]
			var h10: float = hs[i + 1][j]
			var h01: float = hs[i][j + 1]
			var h11: float = hs[i + 1][j + 1]
			if maxf(maxf(h00, h10), maxf(h01, h11)) < IslandLayout.DEEP_Y + 0.05:
				continue  # đáy sông phẳng: nước che, bỏ để nhẹ
			var a := Vector3(x0, h00, z0)
			var b := Vector3(x0 + STEP, h10, z0)
			var c := Vector3(x0 + STEP, h11, z0 + STEP)
			var d := Vector3(x0, h01, z0 + STEP)
			var avg1 := (h00 + h10 + h11) / 3.0
			var avg2 := (h00 + h11 + h01) / 3.0
			k.tri(a, c, b, _color_at(pal, x0 + STEP * 0.66, z0 + STEP * 0.33, avg1))
			k.tri(a, d, c, _color_at(pal, x0 + STEP * 0.33, z0 + STEP * 0.66, avg2))
	var mi := k.instance("Terrain")
	add_child(mi)


func _build_water(pal: Dictionary) -> void:
	if _water_shader == null:
		_water_shader = load("res://assets/shaders/shd_water.gdshader")  # asset shd_water (nguồn duy nhất)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 70
	var ext := 120.0
	var step := ext * 2.0 / n
	for i in n:
		for j in n:
			var quad := [Vector2(-ext + i * step, -ext + j * step), Vector2(-ext + (i + 1) * step, -ext + j * step),
				Vector2(-ext + (i + 1) * step, -ext + (j + 1) * step), Vector2(-ext + i * step, -ext + (j + 1) * step)]
			for idx in [0, 2, 1, 0, 3, 2]:
				var p: Vector2 = quad[idx]
				var h := IslandLayout.terrain_height(island_id, p.x, p.y) if absf(p.x) < 90 and absf(p.y) < 90 else IslandLayout.DEEP_Y
				var depth := clampf(-h / 3.0, 0.0, 1.0)
				st.set_color(Color(depth, 0, 0))
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(p.x, 0.0, p.y))
	var m := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = _water_shader
	mat.set_shader_parameter("shallow", pal["shallow"])
	mat.set_shader_parameter("deep", pal["deep"])
	water = MeshInstance3D.new()
	water.name = "Water"
	water.mesh = m
	water.material_override = mat
	add_child(water)


func _build_pier(L: Dictionary) -> void:
	var p: Dictionary = L["pier"]
	var a: Vector2 = p["from"]
	var b: Vector2 = p["to"]
	var w: float = p["width"]
	var k := MeshKit.new()
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var len := a.distance_to(b)
	var planks := int(len / 0.5)
	for i in planks:
		var c := a + dir * (i * 0.5 + 0.25)
		var col := Models.C_WOOD if i % 3 else Models.C_WOOD_L
		k.box(Vector3(c.x, IslandLayout.PIER_DECK_Y - 0.06, c.y), Vector3(w + (0.1 if i % 2 else 0.0), 0.1, 0.44), col, Basis(Vector3.UP, -atan2(dir.x, dir.y)))
	for i in int(len / 3.0) + 1:
		for s in [-1.0, 1.0]:
			var c2: Vector2 = a + dir * (i * 3.0) + perp * s * (w * 0.5 - 0.1)
			k.box(Vector3(c2.x, -1.2, c2.y), Vector3(0.22, 3.6, 0.22), Models.C_WOOD_D)
			k.box(Vector3(c2.x, IslandLayout.PIER_DECK_Y + 0.45, c2.y), Vector3(0.12, 0.9, 0.12), Models.C_WOOD_D)
	add_child(k.instance("Pier"))


func _build_props(L: Dictionary) -> void:
	var props: Dictionary = L.get("props", {})
	var i := 0
	for p in props.get("palm", []):
		var m := Models.palm(6.0 + (i % 3) * 1.2, 0.6 + 0.3 * (i % 2))
		m.position = IslandLayout.v3(island_id, Vector2(p[0], p[1]), -0.1)
		m.rotation.y = i * 1.3
		add_child(m)
		i += 1
	for p in props.get("nipa", []):
		var m2 := Models.nipa(1.0 + 0.2 * (i % 3))
		m2.position = IslandLayout.v3(island_id, Vector2(p[0], p[1]))
		m2.rotation.y = i * 0.7
		add_child(m2)
		i += 1
	for p in props.get("hut", []):
		var h := Models.hut(p[2])
		h.position = IslandLayout.v3(island_id, Vector2(p[0], p[1]), -0.05)
		h.rotation.y = float(p[2])
		add_child(h)
	for p in props.get("rock", []):
		var r := Models.rock(1.0 + 0.4 * (i % 3))
		r.position = IslandLayout.v3(island_id, Vector2(p[0], p[1]), -0.3)
		r.rotation.y = i
		add_child(r)
		i += 1
	for p in props.get("lighthouse", []):
		var lh := Models.lighthouse()
		lh.position = IslandLayout.v3(island_id, Vector2(p[0], p[1]), -0.2)
		add_child(lh)


func _build_shop(L: Dictionary) -> void:
	var s := IslandLayout.shop_zone(island_id)
	var st := Models.stall()
	st.position = IslandLayout.v3(island_id, s["pos"])
	var spawn: Vector3 = IslandLayout.spawn_point(island_id)
	st.look_at_from_position(st.position, Vector3(spawn.x, st.position.y, spawn.z), Vector3.UP)
	st.rotate_y(PI)
	add_child(st)
	# khói bếp nướng (asset vfx_smoke_grill) tại vị trí bếp trên sạp
	var smoke := VfxPlayer.spawn("vfx_smoke_grill", st, st.global_transform * Vector3(-1.9, 0.8, -0.6))
	if smoke:
		smoke.name = "GrillSmoke"
	var lbl := _label3d(Loc.t("shop.%s.sign" % s["shop_id"]) if Loc.has_key("shop.%s.sign" % s["shop_id"]) else Loc.name_of(s["npc_id"]), 0.9)
	lbl.position = st.position + Vector3(0, 3.3, 0)
	add_child(lbl)


const NPC_LOOK := {
	"npc_co_ba": [1, 0, 2, "non_la"], "npc_ong_tu": [2, 1, 3, "cap"], "npc_bay_cho": [0, 1, 2, "scarf"],
	"npc_co_tam": [1, 1, 3, "non_la"], "npc_nam_sau": [2, 2, 3, "non_la"], "npc_chi_lan": [0, 0, 1, "scarf"],
}


func _build_npcs(L: Dictionary) -> void:
	for npc_id in L["npcs"]:
		var look: Array = NPC_LOOK.get(npc_id, [0, 0, 3, "non_la"])
		var node := Models.person(Models.SKINS[look[0]], Models.CLOTHES[look[1]], Models.CLOTHES[look[2]], look[3])
		node.name = npc_id
		node.position = IslandLayout.npc_position(island_id, npc_id)
		var spawn: Vector3 = IslandLayout.spawn_point(island_id)
		var to := Vector2(spawn.x - node.position.x, spawn.z - node.position.z)
		node.rotation.y = atan2(-to.x, -to.y)
		var lbl := _label3d(Loc.name_of(npc_id), 0.55)
		lbl.position = Vector3(0, 2.35, 0)
		node.add_child(lbl)
		# hoạt ảnh NPC: thư viện asset anm_lib_npc_basic (thở/nói/vui/chê)
		var ap := AnimationPlayer.new()
		ap.name = "Anim"
		node.add_child(ap)
		if ResourceLoader.exists("res://assets/anim/anm_lib_npc_basic.tres"):
			ap.add_animation_library("npc", load("res://assets/anim/anm_lib_npc_basic.tres"))
		add_child(node)
		npc_nodes[npc_id] = node
		play_npc(npc_id, "anm_npc_idle")
		ap.seek(randf() * 2.0, true)


## Phát hoạt ảnh NPC; clip một lần (nói/vui/chê) xong tự quay về thở.
func play_npc(npc_id: String, clip: String, seconds := 0.0) -> void:
	var n: Node3D = npc_nodes.get(npc_id)
	if n == null or not n.has_node("Anim"):
		return
	var ap: AnimationPlayer = n.get_node("Anim")
	if not ap.has_animation("npc/" + clip):
		return
	ap.play("npc/" + clip, 0.15)
	if seconds > 0.0:
		var tw := create_tween()
		tw.tween_interval(seconds)
		tw.tween_callback(func():
			if is_instance_valid(ap):
				ap.play("npc/anm_npc_idle", 0.2))


func _build_boss_post(L: Dictionary) -> void:
	var b := IslandLayout.boss_spot(island_id)
	var post := Models.boss_post()
	post.position = IslandLayout.v3(island_id, b["post"])
	add_child(post)


func _build_zone_signs(L: Dictionary) -> void:
	for zid in L["fishing"]:
		var key := "zone.%s.name" % zid
		if not Loc.has_key(key):
			continue
		var f: Array = L["fishing"][zid]
		var c: Vector2 = f[0]
		# biển chỉ dẫn đặt trên bờ gần vùng câu
		var land := IslandLayout.nearest_land(island_id, c)
		var lbl := _label3d(Loc.t(key), 0.7)
		lbl.position = IslandLayout.v3(island_id, land, 2.6)
		add_child(lbl)


## Nhãn cỡ cố định trên màn hình (không phình to khi đứng sát): tên người chơi, giá cá xỉu.
static func screen_label(text: String, px := 26.0) -> Label3D:
	var l := _label3d(text, 1.0)
	l.fixed_size = true
	l.pixel_size = px / 48.0 * 0.0021
	l.no_depth_test = true
	l.render_priority = 5
	return l


static func _label3d(text: String, size: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	UIKit.theme()  # bảo đảm font dự án đã nạp
	if UIKit.font_bold:
		l.font = UIKit.font_bold
	l.pixel_size = 0.009 * size
	l.font_size = 48
	l.outline_size = 12
	l.modulate = Color("#FFF8E7")
	l.outline_modulate = Color("#22313A")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	return l
