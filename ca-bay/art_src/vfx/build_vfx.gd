extends SceneTree
## Dựng 19 cảnh VFX theo asset registry (assets/vfx/*.tscn) bằng CPUParticles3D (chạy được trên web Compatibility).
## Gốc mỗi cảnh dùng client/scripts/visual/vfx_player.gd (tự hủy/lặp). Mọi hình là khối low-poly tự dựng, không texture ngoài.
## godot --headless --path . --script art_src/vfx/build_vfx.gd

const OUT := "res://assets/vfx/"
const PLAYER := preload("res://client/scripts/visual/vfx_player.gd")
const WHITE := Color("#F4F1DE")
const WATER := Color("#BFEAF0")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var n := 0
	var failed := 0
	for id in VFX.keys():
		var root: Node3D = VFX[id].call()
		root.name = id
		for c in root.get_children():
			c.owner = root
		var ps := PackedScene.new()
		var err := ps.pack(root)
		if err == OK:
			err = ResourceSaver.save(ps, OUT + id + ".tscn")
		if err != OK:
			failed += 1
			printerr("VFX_ERROR %s %d" % [id, err])
		else:
			n += 1
		root.free()
	# vfx_lootbox_reveal: bảng hộp quà là UI 2D → CPUParticles2D
	var ui := Control.new()
	ui.name = "vfx_lootbox_reveal"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p2 := CPUParticles2D.new()
	p2.name = "Burst"
	p2.amount = 32
	p2.one_shot = true
	p2.explosiveness = 1.0
	p2.lifetime = 1.0
	p2.direction = Vector2(0, -1)
	p2.spread = 180.0
	p2.initial_velocity_min = 120.0
	p2.initial_velocity_max = 260.0
	p2.gravity = Vector2(0, 380)
	p2.scale_amount_min = 4.0
	p2.scale_amount_max = 8.0
	var grad := Gradient.new()
	grad.set_color(0, Color("#FFC93C"))
	grad.set_color(1, Color("#E4473C"))
	p2.color_initial_ramp = grad
	ui.add_child(p2)
	p2.owner = ui
	var ps2 := PackedScene.new()
	ps2.pack(ui)
	if ResourceSaver.save(ps2, OUT + "vfx_lootbox_reveal.tscn") == OK:
		n += 1
	else:
		failed += 1
	ui.free()
	print("VFX_BUILD scenes=%d failed=%d" % [n, failed])
	quit(1 if failed else 0)


# ------------------------------------------------------------------ khối hình dùng chung

static func mat(c: Color, billboard := false, unshaded := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.vertex_color_use_as_albedo = true
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func sphere(r: float, c: Color) -> Mesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 6
	s.rings = 3
	s.material = mat(c, false, false)
	return s


static func quad(size: float, c: Color) -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat(c, true)
	return q


static func ring(r: float, w: float, c: Color) -> Mesh:
	var t := TorusMesh.new()
	t.inner_radius = r - w
	t.outer_radius = r
	t.rings = 24
	t.ring_segments = 4
	t.material = mat(c)
	return t


static func star_mesh(c: Color) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var a0 := TAU * i / 5.0
		var a1 := a0 + TAU / 10.0
		var a2 := a0 - TAU / 10.0
		var tip := Vector3(sin(a0), cos(a0), 0) * 0.12
		var l := Vector3(sin(a1), cos(a1), 0) * 0.05
		var r := Vector3(sin(a2), cos(a2), 0) * 0.05
		for v in [Vector3.ZERO, tip, l, Vector3.ZERO, r, tip]:
			st.set_color(c)
			st.add_vertex(v)
	var m := st.commit()
	var sm := mat(c)
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, sm)
	return m


static func coin_mesh() -> Mesh:
	var cy := CylinderMesh.new()
	cy.top_radius = 0.06
	cy.bottom_radius = 0.06
	cy.height = 0.015
	cy.radial_segments = 10
	cy.material = mat(Color("#FFC93C"), false, false)
	return cy


static func burst(amount: int, life: float, mesh: Mesh, vel: Vector2, spread: float, gravity := Vector3(0, -9.8, 0), scale_range := Vector2(0.6, 1.2), loop := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Particles"
	p.amount = amount
	p.lifetime = life
	p.one_shot = not loop
	p.explosiveness = 0.0 if loop else 1.0
	p.mesh = mesh
	p.direction = Vector3(0, 1, 0)
	p.spread = spread
	p.initial_velocity_min = vel.x
	p.initial_velocity_max = vel.y
	p.gravity = gravity
	p.scale_amount_min = scale_range.x
	p.scale_amount_max = scale_range.y
	p.local_coords = false
	return p


static func root(life: float, props := {}) -> Node3D:
	var r := Node3D.new()
	r.set_script(PLAYER)
	r.set("life", life)
	for k in props:
		r.set(k, props[k])
	return r


static func label(txt: String, c: Color, size := 64) -> Label3D:
	var l := Label3D.new()
	l.name = "Label"
	l.text = txt
	l.modulate = c
	l.outline_modulate = Color("#1B1B1B")
	l.outline_size = 14
	l.font_size = size
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	return l


# ------------------------------------------------------------------ danh mục (asset_id → dựng cảnh)

static var VFX := {
	"vfx_lure_splash": func():
		var r := root(0.9)
		r.add_child(burst(14, 0.7, sphere(0.035, WATER), Vector2(1.5, 3.0), 35.0))
		return r,
	"vfx_bobber_ripple": func():
		var r := root(0.0, {"grow": 0.0})
		var p := burst(3, 1.6, ring(0.25, 0.03, Color(1, 1, 1, 0.7)), Vector2(0, 0), 0.0, Vector3.ZERO, Vector2(1, 1), true)
		p.scale_amount_curve = _grow_curve()
		p.particle_flag_align_y = false
		r.add_child(p)
		return r,
	"vfx_bite_splash": func():
		var r := root(1.0)
		r.add_child(burst(24, 0.8, sphere(0.045, WATER), Vector2(2.5, 4.5), 30.0))
		return r,
	"vfx_yank_burst": func():
		var r := root(1.0)
		r.add_child(burst(28, 0.9, sphere(0.05, WATER), Vector2(3.0, 6.0), 45.0))
		var s := burst(10, 0.6, quad(0.12, Color("#FFF1B8")), Vector2(1.0, 2.5), 180.0, Vector3.ZERO)
		s.name = "Sparkle"
		r.add_child(s)
		return r,
	"vfx_air_trail": func():
		var r := root(0.0)
		r.add_child(burst(16, 0.5, sphere(0.03, Color(0.85, 0.95, 1.0)), Vector2(0.0, 0.3), 180.0, Vector3(0, -1, 0), Vector2(0.5, 1.0), true))
		return r,
	"vfx_hit_confetti": func():
		var r := root(0.8)
		for c in [Color("#E4473C"), Color("#FFC93C"), Color("#6CC24A")]:
			var p := burst(6, 0.7, quad(0.07, c), Vector2(2.0, 3.5), 70.0, Vector3(0, -6, 0))
			p.name = "Confetti_" + c.to_html()
			r.add_child(p)
		return r,
	"vfx_ko_stars": func():
		var r := root(0.0, {"spin": 4.0})
		for i in 3:
			var m := MeshInstance3D.new()
			m.name = "Star%d" % i
			m.mesh = star_mesh(Color("#FFC93C"))
			var a := TAU * i / 3.0
			m.position = Vector3(cos(a) * 0.3, 0.35, sin(a) * 0.3)
			r.add_child(m)
		return r,
	"vfx_trick_text": func():
		var r := root(1.4, {"rise": 0.8})
		r.add_child(label("", Color("#FFC93C"), 72))
		return r,
	"vfx_coin_burst": func():
		var r := root(1.2)
		r.add_child(burst(12, 1.0, coin_mesh(), Vector2(2.5, 4.5), 40.0))
		return r,
	"vfx_boss_telegraph_ring": func():
		var r := root(1.2, {"grow": -0.6})
		var m := MeshInstance3D.new()
		m.name = "Ring"
		m.mesh = ring(2.0, 0.15, Color(0.89, 0.28, 0.24, 0.85))
		m.position.y = 0.05
		r.add_child(m)
		return r,
	"vfx_escape_bubbles": func():
		var r := root(1.4)
		r.add_child(burst(14, 1.2, sphere(0.05, Color(0.9, 0.97, 1.0, 0.8)), Vector2(0.6, 1.4), 25.0, Vector3(0, 0.5, 0)))
		return r,
	"vfx_bite_indicator": func():
		var r := root(1.2)
		r.add_child(label("!", Color("#E4473C"), 110))
		return r,
	"vfx_attack_warn": func():
		var r := root(0.9)
		r.add_child(label("!", Color("#FF8A3C"), 90))
		return r,
	"vfx_cast_preview": func():
		var r := root(0.0)
		var m := MeshInstance3D.new()
		m.name = "Ring"
		m.mesh = ring(0.6, 0.06, Color(1, 0.79, 0.24, 0.8))
		m.position.y = 0.06
		r.add_child(m)
		return r,
	"vfx_fishing_line": func():
		# dây câu: nút MeshInstance3D rỗng; client/scripts/game/entity_view.gd vẽ đường cong võng theo điểm đầu cần/phao
		var r := root(0.0)
		var m := MeshInstance3D.new()
		m.name = "Line"
		m.mesh = ImmediateMesh.new()
		m.material_override = mat(Color(0.95, 0.95, 0.9))
		r.add_child(m)
		return r,
	"vfx_smoke_grill": func():
		var r := root(0.0)
		r.add_child(burst(10, 2.2, sphere(0.09, Color(0.85, 0.85, 0.82, 0.55)), Vector2(0.3, 0.6), 15.0, Vector3(0, 0.25, 0), Vector2(0.8, 1.6), true))
		return r,
	"vfx_boba_sparkle": func():
		# ID kỹ thuật cũ: ánh bạc lấp lánh quanh biến thể Ánh Bạc
		var r := root(0.0)
		r.add_child(burst(6, 0.8, quad(0.06, Color("#E8ECE8")), Vector2(0.1, 0.4), 180.0, Vector3.ZERO, Vector2(0.5, 1.0), true))
		return r,
	"vfx_confetti_explosion": func():
		var r := root(1.5)
		r.add_child(burst(30, 1.2, sphere(0.06, WATER), Vector2(4.0, 7.0), 60.0))
		for c in [Color("#E4473C"), Color("#FFC93C"), Color("#6CC24A"), Color("#B79AD9")]:
			var p := burst(8, 1.3, quad(0.09, c), Vector2(3.0, 6.0), 90.0, Vector3(0, -5, 0))
			p.name = "Confetti_" + c.to_html()
			r.add_child(p)
		return r,
}


static func _grow_curve() -> Curve:
	var c := Curve.new()
	c.max_value = 6.0
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(1, 6.0))
	return c
