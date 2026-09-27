class_name MeshKit
extends RefCounted
## Dựng lưới low-poly bằng code: màu đỉnh, đổ bóng phẳng, gộp nhiều khối vào một ArrayMesh
## (ít draw call, hợp web Compatibility). Không dùng texture.

var st := SurfaceTool.new()
var xf := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []

static var _material: StandardMaterial3D
static var _material_unshaded: StandardMaterial3D


func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.95
		_material.metallic_specular = 0.2
	return _material


static func material_unshaded() -> StandardMaterial3D:
	if _material_unshaded == null:
		_material_unshaded = StandardMaterial3D.new()
		_material_unshaded.vertex_color_use_as_albedo = true
		_material_unshaded.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _material_unshaded


func push(t: Transform3D) -> void:
	_stack.append(xf)
	xf = xf * t


func pop() -> void:
	xf = _stack.pop_back()


func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var pa := xf * a
	var pb := xf * b
	var pc := xf * c
	var n := (pb - pa).cross(pc - pa).normalized()
	# Godot coi mặt trước theo chiều kim đồng hồ: phát đỉnh đảo thứ tự so với pháp tuyến tay phải.
	for p in [pa, pc, pb]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	tri(a, b, c, col)
	tri(a, c, d, col)


func box(center: Vector3, size: Vector3, col: Color, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var c := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	for i in 8:
		c[i] = center + basis * c[i]
	quad(c[0], c[3], c[2], c[1], col.darkened(0.05))  # -Z
	quad(c[4], c[5], c[6], c[7], col)                  # +Z
	quad(c[0], c[4], c[7], c[3], col.darkened(0.08))  # -X
	quad(c[1], c[2], c[6], c[5], col.darkened(0.03))  # +X
	quad(c[3], c[7], c[6], c[2], col.lightened(0.06)) # +Y
	quad(c[0], c[1], c[5], c[4], col.darkened(0.15))  # -Y


## Khối elip low-poly (seg quanh, rings dọc). top/bottom màu cho bụng/lưng.
func ellipsoid(center: Vector3, radii: Vector3, seg: int, rings: int, col_top: Color, col_bottom: Color = Color(-1, 0, 0), basis := Basis.IDENTITY) -> void:
	if col_bottom.r < 0:
		col_bottom = col_top
	var pts: Array = []
	for r in rings + 1:
		var phi := PI * float(r) / rings
		var row: Array = []
		for s in seg:
			var th := TAU * float(s) / seg
			var v := Vector3(sin(phi) * cos(th) * radii.x, cos(phi) * radii.y, sin(phi) * sin(th) * radii.z)
			row.append(center + basis * v)
		pts.append(row)
	for r in rings:
		for s in seg:
			var a: Vector3 = pts[r][s]
			var b: Vector3 = pts[r][(s + 1) % seg]
			var c: Vector3 = pts[r + 1][(s + 1) % seg]
			var d: Vector3 = pts[r + 1][s]
			var t := float(r) / rings
			var col := col_top.lerp(col_bottom, t)
			if r == 0:
				tri(a, c, d, col)
			elif r == rings - 1:
				tri(a, b, d, col)
			else:
				quad(a, b, c, d, col)


## Hình trụ/nón theo trục từ a tới b.
func cylinder(a: Vector3, b: Vector3, ra: float, rb: float, seg: int, col: Color, caps := true) -> void:
	var axis := (b - a)
	var len := axis.length()
	if len < 0.0001:
		return
	var y := axis / len
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var ring_a: Array = []
	var ring_b: Array = []
	for s in seg:
		var th := TAU * float(s) / seg
		var dir := x * cos(th) + z * sin(th)
		ring_a.append(a + dir * ra)
		ring_b.append(b + dir * rb)
	for s in seg:
		var s2 := (s + 1) % seg
		quad(ring_a[s], ring_a[s2], ring_b[s2], ring_b[s], col.darkened(0.04 * float(s % 2)))
		if caps:
			if ra > 0.0001:
				tri(a, ring_a[s2], ring_a[s], col.darkened(0.1))
			if rb > 0.0001:
				tri(b, ring_b[s], ring_b[s2], col.lightened(0.05))


func cone(base: Vector3, tip: Vector3, r: float, seg: int, col: Color) -> void:
	cylinder(base, tip, r, 0.0, seg, col, true)


## Tam giác hai mặt (vây, lá).
func fin(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	tri(a, b, c, col)
	tri(a, c, b, col.darkened(0.1))


func eye(center: Vector3, r: float, look: Vector3) -> void:
	ellipsoid(center, Vector3(r, r, r), 8, 4, Color("#FFFFFF"))
	ellipsoid(center + look.normalized() * r * 0.55, Vector3(r, r, r) * 0.55, 6, 3, Color("#111111"))


func commit_mesh() -> ArrayMesh:
	var m := st.commit()
	if m.get_surface_count() > 0:
		m.surface_set_material(0, material())
	return m


func instance(name: String = "Mesh") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = commit_mesh()
	return mi
