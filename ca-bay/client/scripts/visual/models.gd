class_name Models
extends RefCounted
## Thư viện mô hình low-poly nguyên bản (self_made): 15 loài + 3 boss, người, công cụ, đồ vật, môi trường.
## Hướng: đầu cá về -Z (trục "forward" của Godot). Đơn vị mét. Mesh được cache theo khóa.

static var _cache: Dictionary = {}

## Màu từ Art Bible §3
const C_SAND := Color("#E9C98B")
const C_MUD := Color("#8D6A4A")
const C_GRASS := Color("#7CC24A")
const C_LEAF := Color("#3E8E3A")
const C_WOOD := Color("#9C6B3F")
const C_WOOD_D := Color("#6B4428")
const C_WOOD_L := Color("#C8A160")
const C_RED := Color("#E4473C")
const C_GOLD := Color("#FFC93C")
const C_OK := Color("#6CC24A")
const C_SILVER := Color("#B8C4C8")
const C_SILVER_L := Color("#E8ECE8")
const C_BAMBOO := Color("#B8A05A")
const C_HAT := Color("#D9C27A")
const SKINS := [Color("#F1C27D"), Color("#D9A066"), Color("#A86B3C")]
const CLOTHES := [Color("#B79AD9"), Color("#9FB7C9"), Color("#8A5A3C"), Color("#2B2B2B")]

## Hình dáng/màu theo loài: [kiểu, màu lưng, màu bụng, màu vây, cao/dài, rộng/dài, đặc điểm]
const SPECIES := {
	"cre_tep": ["shrimp", Color("#F2B8A0"), Color("#FBE3D6"), Color("#E88E7A"), 0.22, 0.18, {}],
	"cre_ca_ro": ["fish", Color("#6E7D3A"), Color("#C9C58A"), Color("#4F5A2A"), 0.42, 0.22, {"spiny": true}],
	"cre_cua_dong": ["crab", Color("#6B5B3A"), Color("#B59B6A"), Color("#4B3F28"), 0.45, 1.3, {}],
	"cre_ca_tre": ["fish", Color("#4A4A55"), Color("#B9B3A8"), Color("#34343C"), 0.22, 0.22, {"barbels": true, "flat_head": true}],
	"cre_ca_me": ["fish", Color("#9AA8AE"), Color("#E8ECE8"), Color("#7E8D93"), 0.38, 0.2, {"deep": true}],
	"cre_ca_thoi_loi": ["fish", Color("#7A6A4E"), Color("#CDBB94"), Color("#5A7A8A"), 0.22, 0.24, {"top_eyes": true, "spots": true}],
	"cre_luon": ["eel", Color("#8A6A2E"), Color("#D9B85A"), Color("#6E5424"), 0.07, 0.07, {}],
	"cre_ca_doi": ["fish", Color("#7F8C93"), Color("#DDE3E3"), Color("#687479"), 0.26, 0.2, {}],
	"cre_cua_bun": ["crab", Color("#3F5A44"), Color("#9FA86A"), Color("#2E4332"), 0.45, 1.35, {"big_claws": true}],
	"cre_tom_cang": ["shrimp", Color("#4F7FA8"), Color("#C9D8E4"), Color("#2F5F9A"), 0.2, 0.18, {"long_claws": true}],
	"cre_ca_nuc": ["fish", Color("#3F8C8C"), Color("#E3EAE6"), Color("#E0B640"), 0.28, 0.2, {"stripe": Color("#E6C24A")}],
	"cre_ca_chuon": ["fish", Color("#2F6FA8"), Color("#E6EEF3"), Color("#7FB4E0"), 0.24, 0.2, {"wings": true}],
	"cre_ca_trich": ["fish", Color("#5A86A8"), Color("#EEF2F4"), Color("#7C98AE"), 0.24, 0.18, {}],
	"cre_muc_ong": ["squid", Color("#E6A0A8"), Color("#FBE6E6"), Color("#D98890"), 0.2, 0.2, {}],
	"cre_ca_hong": ["fish", Color("#D9504A"), Color("#F6C3B6"), Color("#C0403A"), 0.4, 0.2, {"spiny": true}],
	"cre_boss_ca_loc": ["fish", Color("#3B3F2E"), Color("#A9A58A"), Color("#2A2D20"), 0.2, 0.2, {"mottled": true, "flat_head": true}],
	"cre_boss_cua_bun": ["crab", Color("#34503A"), Color("#95A262"), Color("#243828"), 0.42, 1.35, {"big_claws": true}],
	"cre_boss_ca_bop": ["fish", Color("#4A3A2C"), Color("#E6DCCB"), Color("#3A2C20"), 0.2, 0.2, {"stripe": Color("#F2EBDD"), "flat_head": true}],
}


static func cached(key: String, builder: Callable) -> Mesh:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


static func mesh_instance(key: String, builder: Callable) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = cached(key, builder)
	return mi


# ------------------------------------------------------------------ sinh vật

static func creature(def_id: String, variant: Variant = null) -> Node3D:
	var root := Node3D.new()
	root.name = def_id
	var key := def_id + ("_" + String(variant) if variant != null else "")
	var mi := mesh_instance(key, func(): return _build_creature(def_id, variant))
	mi.name = "Body"
	root.add_child(mi)
	return root


static func _build_creature(def_id: String, variant: Variant) -> Mesh:
	var cre: Dictionary = ContentDB.creatures.get(def_id, {})
	var sp: Array = SPECIES.get(def_id, ["fish", Color.GRAY, Color.WHITE, Color.DIM_GRAY, 0.3, 0.2, {}])
	var L: float = float(cre.get("length_m", 0.3))
	if cre.get("is_boss", false):
		L *= 1.0
	var k := MeshKit.new()
	var top: Color = sp[1]
	var belly: Color = sp[2]
	var finc: Color = sp[3]
	if variant != null:
		# biến thể Ánh Bạc: mảng vảy bạc tự nhiên (không hạt trân châu)
		top = top.lerp(C_SILVER, 0.55)
		belly = belly.lerp(C_SILVER_L, 0.6)
	match String(sp[0]):
		"fish":
			_fish(k, L, sp[4], sp[5], top, belly, finc, sp[6])
		"crab":
			_crab(k, L, top, belly, finc, sp[6])
		"shrimp":
			_shrimp(k, L, top, belly, finc, sp[6])
		"squid":
			_squid(k, L, top, belly, finc)
		"eel":
			_eel(k, L, top, belly, finc)
	return k.commit_mesh()


static func _fish(k: MeshKit, L: float, h_ratio: float, w_ratio: float, top: Color, belly: Color, finc: Color, f: Dictionary) -> void:
	var h := L * h_ratio * (1.35 if f.get("deep", false) else 1.0)
	var w := L * w_ratio
	var hy := h * 0.5
	# thân: elip kéo dài theo Z, lưng đậm bụng nhạt
	k.ellipsoid(Vector3(0, hy, 0), Vector3(w * 0.5, h * 0.5, L * 0.42), 8, 6, top, belly, Basis(Vector3.RIGHT, 0))
	if f.get("flat_head", false):
		k.ellipsoid(Vector3(0, hy * 0.9, -L * 0.33), Vector3(w * 0.62, h * 0.42, L * 0.14), 8, 4, top.darkened(0.1), belly)
	if f.has("stripe"):
		k.box(Vector3(w * 0.26, hy * 1.05, 0), Vector3(0.01, h * 0.12, L * 0.62), f["stripe"])
		k.box(Vector3(-w * 0.26, hy * 1.05, 0), Vector3(0.01, h * 0.12, L * 0.62), f["stripe"])
	if f.get("mottled", false) or f.get("spots", false):
		for i in 6:
			var z := -L * 0.25 + L * 0.1 * i
			var s := 1 if i % 2 == 0 else -1
			k.ellipsoid(Vector3(s * w * 0.44, hy * (1.0 + 0.2 * (i % 3)), z), Vector3(0.01, h * 0.12, L * 0.05), 5, 3, top.darkened(0.35))
	# đuôi
	var tz := L * 0.40
	k.fin(Vector3(0, hy, tz), Vector3(0, hy + h * 0.55, tz + L * 0.2), Vector3(0, hy + h * 0.05, tz + L * 0.12), finc)
	k.fin(Vector3(0, hy, tz), Vector3(0, hy - h * 0.05, tz + L * 0.12), Vector3(0, hy - h * 0.5, tz + L * 0.2), finc)
	# vây lưng
	var dh := h * (0.75 if f.get("spiny", false) else 0.45)
	k.fin(Vector3(0, hy + h * 0.45, -L * 0.12), Vector3(0, hy + h * 0.45 + dh, L * 0.02), Vector3(0, hy + h * 0.42, L * 0.2), finc)
	# vây ngực / cánh cá chuồn
	var pl := L * (0.45 if f.get("wings", false) else 0.14)
	for s in [-1, 1]:
		k.fin(Vector3(s * w * 0.45, hy * 0.8, -L * 0.18), Vector3(s * (w * 0.45 + pl), hy * 0.7, -L * 0.02 + (pl * 0.3 if f.get("wings", false) else 0.0)), Vector3(s * w * 0.4, hy * 0.7, -L * 0.02), finc.lightened(0.1))
	# mắt lớn có tròng trắng (Art Bible)
	var er := maxf(0.018, L * 0.07)
	if f.get("top_eyes", false):
		for s in [-1, 1]:
			k.eye(Vector3(s * w * 0.18, h * 1.05, -L * 0.3), er * 1.2, Vector3(s * 0.4, 0.6, -0.6))
	else:
		for s in [-1, 1]:
			k.eye(Vector3(s * w * 0.4, hy * 1.12, -L * 0.3), er, Vector3(s, 0.1, -0.3))
	# râu cá trê
	if f.get("barbels", false):
		for s in [-1, 1]:
			for j in 2:
				k.cylinder(Vector3(s * w * 0.2, hy * (0.8 - 0.3 * j), -L * 0.44), Vector3(s * (w * 0.5 + L * 0.12), hy * (0.4 - 0.4 * j), -L * 0.52), 0.006, 0.003, 4, Color("#2B2B2B"), false)
	# miệng
	k.box(Vector3(0, hy * 0.85, -L * 0.43), Vector3(w * 0.35, h * 0.06, 0.01), Color("#3A2020"))


static func _crab(k: MeshKit, L: float, top: Color, belly: Color, finc: Color, f: Dictionary) -> void:
	var w := L * 1.35
	var d := L
	var h := L * 0.42
	k.ellipsoid(Vector3(0, h * 0.7, 0), Vector3(w * 0.5, h * 0.45, d * 0.45), 10, 5, top, belly)
	var claw := 1.6 if f.get("big_claws", false) else 1.0
	for s in [-1, 1]:
		# chân
		for i in 3:
			var z := -d * 0.15 + d * 0.18 * i
			k.cylinder(Vector3(s * w * 0.42, h * 0.6, z), Vector3(s * w * 0.75, h * 0.1, z + d * 0.08), L * 0.035, L * 0.02, 4, finc, false)
		# càng
		var base := Vector3(s * w * 0.35, h * 0.75, -d * 0.4)
		var elbow := Vector3(s * w * 0.55, h * 0.9, -d * 0.6)
		k.cylinder(base, elbow, L * 0.05, L * 0.05, 5, finc, false)
		k.ellipsoid(elbow + Vector3(0, 0, -d * 0.12 * claw), Vector3(L * 0.1 * claw, L * 0.08 * claw, L * 0.16 * claw), 6, 4, top.lightened(0.05), belly)
		k.cone(elbow + Vector3(s * L * 0.03, L * 0.02, -d * 0.2 * claw), elbow + Vector3(s * L * 0.02, L * 0.02, -d * 0.36 * claw), L * 0.04 * claw, 4, finc.darkened(0.2))
		# mắt trên cuống
		k.cylinder(Vector3(s * w * 0.12, h * 1.0, -d * 0.35), Vector3(s * w * 0.14, h * 1.35, -d * 0.4), 0.008, 0.008, 4, finc, false)
		k.eye(Vector3(s * w * 0.14, h * 1.4, -d * 0.4), maxf(0.016, L * 0.06), Vector3(s * 0.3, 0.2, -1))


static func _shrimp(k: MeshKit, L: float, top: Color, belly: Color, finc: Color, f: Dictionary) -> void:
	var segs := 6
	var r := L * 0.11
	for i in segs:
		var t := float(i) / segs
		var z := -L * 0.35 + L * 0.75 * t
		var y := r * 1.4 + sin(t * PI) * r * 0.8 - t * t * r * 0.8
		var rr := r * (1.0 - 0.55 * t)
		k.ellipsoid(Vector3(0, y, z), Vector3(rr, rr * 0.95, L * 0.09), 7, 4, top, belly)
	# quạt đuôi
	var tz := L * 0.42
	k.fin(Vector3(0, r * 0.6, tz - L * 0.05), Vector3(-L * 0.12, r * 0.3, tz + L * 0.1), Vector3(L * 0.12, r * 0.3, tz + L * 0.1), finc)
	# râu
	for s in [-1, 1]:
		k.cylinder(Vector3(s * r * 0.3, r * 1.8, -L * 0.42), Vector3(s * L * 0.3, r * 2.5, -L * 1.0), 0.004, 0.002, 3, finc, false)
		k.eye(Vector3(s * r * 0.6, r * 2.1, -L * 0.36), maxf(0.012, L * 0.045), Vector3(s * 0.4, 0.2, -1))
		for j in 4:
			k.cylinder(Vector3(s * r * 0.5, r * 0.9, -L * 0.15 + L * 0.08 * j), Vector3(s * r * 1.3, 0.0, -L * 0.12 + L * 0.08 * j), 0.004, 0.003, 3, finc, false)
	if f.get("long_claws", false):
		for s in [-1, 1]:
			k.cylinder(Vector3(s * r * 0.8, r * 1.2, -L * 0.3), Vector3(s * r * 2.0, r * 1.0, -L * 0.95), L * 0.03, L * 0.025, 5, finc, false)
			k.ellipsoid(Vector3(s * r * 2.1, r * 1.0, -L * 1.05), Vector3(L * 0.04, L * 0.035, L * 0.12), 5, 3, finc.lightened(0.1))


static func _squid(k: MeshKit, L: float, top: Color, belly: Color, finc: Color) -> void:
	var r := L * 0.13
	# thân áo (mantle) hình nón tới -Z
	k.cylinder(Vector3(0, r * 1.1, -L * 0.05), Vector3(0, r * 1.1, L * 0.45), r, r * 0.25, 8, top)
	k.fin(Vector3(0, r * 1.1, L * 0.3), Vector3(-r * 1.8, r * 1.1, L * 0.45), Vector3(0, r * 1.1, L * 0.47), finc)
	k.fin(Vector3(0, r * 1.1, L * 0.3), Vector3(0, r * 1.1, L * 0.47), Vector3(r * 1.8, r * 1.1, L * 0.45), finc)
	k.ellipsoid(Vector3(0, r * 1.1, -L * 0.1), Vector3(r * 0.9, r * 0.85, r * 0.8), 7, 4, belly, belly)
	for s in [-1, 1]:
		k.eye(Vector3(s * r * 0.75, r * 1.25, -L * 0.1), maxf(0.02, r * 0.4), Vector3(s, 0.1, -0.3))
	for i in 8:
		var a := TAU * i / 8.0
		var off := Vector3(cos(a) * r * 0.5, r * 1.1 + sin(a) * r * 0.5, -L * 0.15)
		k.cylinder(off, off + Vector3(cos(a) * r * 0.4, sin(a) * r * 0.3 - r * 0.4, -L * 0.45), L * 0.018, L * 0.008, 4, finc, false)


static func _eel(k: MeshKit, L: float, top: Color, belly: Color, finc: Color) -> void:
	var n := 10
	var r := L * 0.05
	for i in n:
		var t := float(i) / (n - 1)
		var z := -L * 0.5 + L * t
		var x := sin(t * TAU * 1.2) * L * 0.08
		k.ellipsoid(Vector3(x, r, z), Vector3(r * (1.0 - 0.4 * t), r * (1.0 - 0.4 * t), L * 0.07), 7, 3, top, belly)
	for s in [-1, 1]:
		k.eye(Vector3(s * r * 0.7, r * 1.4, -L * 0.47), maxf(0.012, r * 0.45), Vector3(s, 0.2, -0.4))


# ------------------------------------------------------------------ người

static func person(skin: Color, shirt: Color, pants: Color, hat: String = "non_la", scale := 1.0) -> Node3D:
	var key := "person_%s_%s_%s_%s" % [skin.to_html(), shirt.to_html(), pants.to_html(), hat]
	var root := Node3D.new()
	var mi := mesh_instance(key, func():
		var k := MeshKit.new()
		# chân
		for s in [-1, 1]:
			k.box(Vector3(s * 0.11, 0.42, 0), Vector3(0.16, 0.84, 0.18), pants)
			k.box(Vector3(s * 0.11, 0.04, -0.04), Vector3(0.17, 0.08, 0.26), Color("#3A2A20"))
		# thân áo bà ba
		k.box(Vector3(0, 1.08, 0), Vector3(0.5, 0.56, 0.3), shirt)
		k.box(Vector3(0, 0.86, 0), Vector3(0.52, 0.14, 0.32), shirt.darkened(0.1))
		for i in 3:
			k.box(Vector3(0, 1.2 - i * 0.14, -0.155), Vector3(0.03, 0.03, 0.01), Color("#F4F1DE"))
		# tay
		for s in [-1, 1]:
			k.box(Vector3(s * 0.32, 1.08, 0), Vector3(0.14, 0.5, 0.16), shirt.darkened(0.05))
			k.ellipsoid(Vector3(s * 0.32, 0.8, 0), Vector3(0.07, 0.07, 0.07), 6, 4, skin)
		# đầu
		k.ellipsoid(Vector3(0, 1.58, 0), Vector3(0.2, 0.22, 0.2), 10, 6, skin)
		for s in [-1, 1]:
			k.eye(Vector3(s * 0.075, 1.62, -0.175), 0.035, Vector3(0, 0, -1))
		k.box(Vector3(0, 1.5, -0.19), Vector3(0.08, 0.02, 0.01), Color("#7A3A2A"))
		match hat:
			"non_la":
				k.cone(Vector3(0, 1.74, 0), Vector3(0, 2.02, 0), 0.36, 12, C_HAT)
			"scarf":
				k.ellipsoid(Vector3(0, 1.72, 0.02), Vector3(0.22, 0.12, 0.22), 8, 4, Color("#E4473C"))
			"cap":
				k.ellipsoid(Vector3(0, 1.74, 0), Vector3(0.21, 0.1, 0.21), 8, 4, Color("#2F6FA8"))
				k.box(Vector3(0, 1.72, -0.2), Vector3(0.22, 0.02, 0.14), Color("#2F6FA8"))
			_:
				k.ellipsoid(Vector3(0, 1.72, 0.02), Vector3(0.21, 0.1, 0.21), 8, 4, Color("#2B2B2B"))
		return k.commit_mesh())
	mi.name = "Body"
	mi.scale = Vector3.ONE * scale
	root.add_child(mi)
	return root


## Bàn tay góc nhìn thứ nhất: găng 4 ngón hoạt hình + cổ tay áo.
static func fp_hand(skin: Color, sleeve: Color) -> MeshInstance3D:
	return mesh_instance("fp_hand_%s_%s" % [skin.to_html(), sleeve.to_html()], func():
		var k := MeshKit.new()
		k.box(Vector3(0, 0, 0.12), Vector3(0.1, 0.1, 0.18), sleeve)
		k.box(Vector3(0, 0, 0), Vector3(0.1, 0.05, 0.1), skin)
		for i in 4:
			k.box(Vector3(-0.035 + i * 0.024, 0, -0.07), Vector3(0.02, 0.035, 0.06), skin.darkened(0.03 * i))
		k.box(Vector3(0.06, 0, -0.01), Vector3(0.025, 0.03, 0.05), skin)
		return k.commit_mesh())


# ------------------------------------------------------------------ công cụ, mồi, đồ

static func tool_model(tool_id: String, tint: Variant = null) -> MeshInstance3D:
	var key := tool_id + ("_" + (tint as Color).to_html() if tint != null else "")
	return mesh_instance(key, func():
		var k := MeshKit.new()
		var c: Color = tint if tint != null else Color.WHITE
		match tool_id:
			"rod_bamboo", "rod_carbon":
				var rc: Color = tint if tint != null else (C_BAMBOO if tool_id == "rod_bamboo" else Color("#2B3A44"))
				for i in 5:
					k.cylinder(Vector3(0, 0, -i * 0.3), Vector3(0, 0, -(i + 1) * 0.3), 0.018 - i * 0.0025, 0.016 - i * 0.0025, 6, rc if i % 2 == 0 else rc.darkened(0.08), false)
					k.cylinder(Vector3(0, 0, -(i + 1) * 0.3 + 0.01), Vector3(0, 0, -(i + 1) * 0.3 - 0.01), 0.02 - i * 0.0025, 0.02 - i * 0.0025, 6, rc.darkened(0.3), false)
				k.cylinder(Vector3(0.03, -0.01, 0.05), Vector3(0.03, -0.01, -0.02), 0.035, 0.035, 8, Color("#5A5A5A"))
			"tool_slipper":
				var sc: Color = tint if tint != null else Color("#408AC8")
				k.ellipsoid(Vector3(0, 0, 0), Vector3(0.05, 0.012, 0.12), 8, 3, sc)
				k.box(Vector3(0, 0.02, -0.03), Vector3(0.09, 0.012, 0.02), Color("#F4F1DE"))
			"tool_broom":
				var bc: Color = tint if tint != null else Color("#D9B85A")
				k.cylinder(Vector3(0, 0, 0.2), Vector3(0, 0, -0.7), 0.015, 0.015, 6, C_WOOD, false)
				for i in 9:
					var a := -0.5 + i * 0.125
					k.cylinder(Vector3(0, 0, -0.7), Vector3(sin(a) * 0.18, -0.02, -1.05), 0.012, 0.004, 3, bc, false)
			"tool_slingshot":
				k.cylinder(Vector3(0, -0.12, 0), Vector3(0, 0, 0), 0.015, 0.015, 6, C_WOOD_D, false)
				k.cylinder(Vector3(0, 0, 0), Vector3(-0.05, 0.08, -0.02), 0.012, 0.01, 5, C_WOOD_D, false)
				k.cylinder(Vector3(0, 0, 0), Vector3(0.05, 0.08, -0.02), 0.012, 0.01, 5, C_WOOD_D, false)
				k.box(Vector3(0, 0.07, 0.02), Vector3(0.1, 0.006, 0.006), Color("#C0392B"))
			"tool_swatter":
				k.cylinder(Vector3(0, 0, 0.1), Vector3(0, 0, -0.35), 0.01, 0.01, 5, Color("#E4473C"), false)
				k.box(Vector3(0, 0, -0.45), Vector3(0.18, 0.01, 0.2), Color("#FFC93C"))
			"tool_coconut_bomb":
				k.ellipsoid(Vector3.ZERO, Vector3(0.09, 0.09, 0.09), 8, 5, Color("#6B4428"))
				k.cylinder(Vector3(0, 0.09, 0), Vector3(0.01, 0.15, 0), 0.006, 0.004, 3, Color("#D9C27A"), false)
			"tool_hand", _:
				k.box(Vector3.ZERO, Vector3(0.09, 0.05, 0.1), SKINS[0])
		return k.commit_mesh())


static func bobber() -> MeshInstance3D:
	return mesh_instance("bobber", func():
		var k := MeshKit.new()
		k.ellipsoid(Vector3(0, 0.03, 0), Vector3(0.05, 0.035, 0.05), 8, 3, C_RED, C_RED)
		k.ellipsoid(Vector3(0, -0.005, 0), Vector3(0.05, 0.03, 0.05), 8, 3, Color("#F4F1DE"), Color("#F4F1DE"))
		k.cylinder(Vector3(0, 0.05, 0), Vector3(0, 0.12, 0), 0.006, 0.004, 4, C_RED, false)
		return k.commit_mesh())


static func item(def_id: String) -> MeshInstance3D:
	return mesh_instance("item_" + def_id, func():
		var k := MeshKit.new()
		match def_id:
			"item_golden_scale":
				k.ellipsoid(Vector3(0, 0.03, 0), Vector3(0.12, 0.02, 0.1), 10, 3, C_GOLD, C_GOLD.darkened(0.2))
			"item_survey_tag":
				k.box(Vector3(0, 0.03, 0), Vector3(0.16, 0.02, 0.1), Color("#F4F1DE"))
				k.box(Vector3(0, 0.045, 0), Vector3(0.12, 0.005, 0.02), C_RED)
			"item_festival_medal":
				k.cylinder(Vector3(0, 0.02, 0), Vector3(0, 0.04, 0), 0.08, 0.08, 12, C_GOLD)
				k.box(Vector3(0, 0.03, 0.1), Vector3(0.05, 0.01, 0.1), C_RED)
			"item_rice_ball":
				k.cone(Vector3(0, 0, 0), Vector3(0, 0.12, 0), 0.08, 3, Color("#FAFAF2"))
				k.box(Vector3(0, 0.03, 0), Vector3(0.1, 0.05, 0.03), Color("#1E2A20"))
			"item_grilled_fish":
				k.cylinder(Vector3(0, 0.02, 0.2), Vector3(0, 0.02, -0.2), 0.006, 0.006, 4, C_WOOD_L, false)
				k.ellipsoid(Vector3(0, 0.04, 0), Vector3(0.05, 0.035, 0.14), 8, 4, Color("#B0702E"), Color("#E0B070"))
			_:
				k.ellipsoid(Vector3(0, 0.05, 0), Vector3(0.08, 0.05, 0.08), 8, 4, C_GOLD)
		return k.commit_mesh())


# ------------------------------------------------------------------ môi trường

static func palm(height: float, lean: float) -> MeshInstance3D:
	return mesh_instance("palm_%.1f_%.2f" % [height, lean], func():
		var k := MeshKit.new()
		var prev := Vector3.ZERO
		var segs := 6
		for i in segs:
			var t := float(i + 1) / segs
			var p := Vector3(lean * t * t * height * 0.35, t * height, 0)
			k.cylinder(prev, p, 0.16 - 0.015 * i, 0.15 - 0.015 * (i + 1), 6, C_WOOD if i % 2 == 0 else C_WOOD.darkened(0.08), false)
			prev = p
		for j in 7:
			var a := TAU * j / 7.0
			var dir := Vector3(cos(a), 0, sin(a))
			var mid := prev + dir * 1.1 + Vector3(0, 0.25, 0)
			var tip := prev + dir * 2.3 - Vector3(0, 0.7, 0)
			var side := dir.cross(Vector3.UP) * 0.35
			k.fin(prev, mid + side, mid - side, C_LEAF.lightened(0.05 * (j % 2)))
			k.fin(mid + side * 0.8, tip, mid - side * 0.8, C_LEAF.darkened(0.05))
		for c in 3:
			k.ellipsoid(prev + Vector3(cos(c * 2.1) * 0.18, -0.2, sin(c * 2.1) * 0.18), Vector3(0.13, 0.15, 0.13), 6, 4, Color("#7A5A2A"))
		return k.commit_mesh())


static func nipa(size: float) -> MeshInstance3D:
	return mesh_instance("nipa_%.1f" % size, func():
		var k := MeshKit.new()
		for j in 9:
			var a := TAU * j / 9.0 + 0.2
			var dir := Vector3(cos(a), 0, sin(a))
			var tip := dir * 1.6 * size + Vector3(0, 2.4 * size, 0)
			var side := dir.cross(Vector3.UP) * 0.25 * size
			k.fin(Vector3(0, 0.1, 0) + side, tip, Vector3(0, 0.1, 0) - side, Color("#4E9A3A").lightened(0.04 * (j % 3)))
		return k.commit_mesh())


static func hut(rot: float) -> MeshInstance3D:
	return mesh_instance("hut", func():
		var k := MeshKit.new()
		for x in [-1.6, 1.6]:
			for z in [-1.4, 1.4]:
				k.box(Vector3(x, 0.4, z), Vector3(0.18, 0.8, 0.18), C_WOOD_D)
		k.box(Vector3(0, 0.85, 0), Vector3(3.6, 0.12, 3.2), C_WOOD)
		k.box(Vector3(0, 1.8, 1.5), Vector3(3.4, 1.8, 0.1), C_WOOD_L)
		k.box(Vector3(-1.7, 1.8, 0), Vector3(0.1, 1.8, 3.0), C_WOOD_L.darkened(0.05))
		k.box(Vector3(1.7, 1.8, 0), Vector3(0.1, 1.8, 3.0), C_WOOD_L.darkened(0.05))
		k.quad(Vector3(-2.1, 2.7, -1.9), Vector3(2.1, 2.7, -1.9), Vector3(2.1, 3.9, 0), Vector3(-2.1, 3.9, 0), C_HAT.darkened(0.1))
		k.quad(Vector3(-2.1, 3.9, 0), Vector3(2.1, 3.9, 0), Vector3(2.1, 2.7, 1.9), Vector3(-2.1, 2.7, 1.9), C_HAT)
		k.tri(Vector3(-1.7, 2.7, -1.5), Vector3(-1.7, 3.8, 0), Vector3(-1.7, 2.7, 1.5), C_WOOD_L)
		k.tri(Vector3(1.7, 2.7, 1.5), Vector3(1.7, 3.8, 0), Vector3(1.7, 2.7, -1.5), C_WOOD_L)
		return k.commit_mesh())


static func rock(size: float) -> MeshInstance3D:
	return mesh_instance("rock_%.1f" % size, func():
		var k := MeshKit.new()
		k.ellipsoid(Vector3(0, size * 0.35, 0), Vector3(size, size * 0.7, size * 0.85), 7, 4, Color("#9A9A92"), Color("#6E6E68"))
		k.ellipsoid(Vector3(size * 0.6, size * 0.2, size * 0.3), Vector3(size * 0.5, size * 0.4, size * 0.4), 6, 3, Color("#8A8A84"), Color("#6E6E68"))
		return k.commit_mesh())


static func lighthouse() -> MeshInstance3D:
	return mesh_instance("lighthouse", func():
		var k := MeshKit.new()
		for i in 5:
			k.cylinder(Vector3(0, i * 1.6, 0), Vector3(0, (i + 1) * 1.6, 0), 1.3 - i * 0.15, 1.15 - i * 0.15, 10, C_RED if i % 2 == 0 else Color("#F4F1DE"), false)
		k.cylinder(Vector3(0, 8.0, 0), Vector3(0, 9.0, 0), 0.7, 0.7, 10, Color("#FFF1D6"))
		k.cone(Vector3(0, 9.0, 0), Vector3(0, 10.0, 0), 0.85, 10, C_RED.darkened(0.2))
		return k.commit_mesh())


static func stall() -> MeshInstance3D:
	return mesh_instance("stall", func():
		var k := MeshKit.new()
		k.box(Vector3(0, 0.45, 0), Vector3(2.6, 0.9, 1.0), C_WOOD)
		k.box(Vector3(0, 0.92, 0), Vector3(2.8, 0.06, 1.2), C_WOOD_L)
		for x in [-1.3, 1.3]:
			k.box(Vector3(x, 1.4, 0.5), Vector3(0.1, 2.8, 0.1), C_WOOD_D)
			k.box(Vector3(x, 1.2, -0.5), Vector3(0.1, 2.4, 0.1), C_WOOD_D)
		for i in 6:
			k.quad(Vector3(-1.6 + i * 0.53, 2.6, -0.9), Vector3(-1.07 + i * 0.53, 2.6, -0.9), Vector3(-1.07 + i * 0.53, 2.85, 0.8), Vector3(-1.6 + i * 0.53, 2.85, 0.8), C_RED if i % 2 == 0 else Color("#F4F1DE"))
		# thúng bán cá
		k.cylinder(Vector3(1.8, 0, -0.6), Vector3(1.8, 0.45, -0.6), 0.35, 0.45, 10, C_WOOD_L)
		# bếp nướng
		k.box(Vector3(-1.9, 0.35, -0.6), Vector3(0.7, 0.7, 0.6), Color("#8A8A84"))
		k.box(Vector3(-1.9, 0.72, -0.6), Vector3(0.6, 0.04, 0.5), Color("#2B2B2B"))
		return k.commit_mesh())


static func boss_post() -> MeshInstance3D:
	return mesh_instance("boss_post", func():
		var k := MeshKit.new()
		k.cylinder(Vector3(0, -1.0, 0), Vector3(0, 2.6, 0), 0.12, 0.1, 8, C_RED)
		for i in 3:
			k.cylinder(Vector3(0, 0.3 + i * 0.8, 0), Vector3(0, 0.45 + i * 0.8, 0), 0.13, 0.13, 8, Color("#F4F1DE"), false)
		k.quad(Vector3(0, 2.6, 0), Vector3(0.9, 2.45, 0), Vector3(0.9, 2.05, 0), Vector3(0, 2.2, 0), C_RED)
		k.quad(Vector3(0, 2.2, 0), Vector3(0.9, 2.05, 0), Vector3(0.9, 2.45, 0), Vector3(0, 2.6, 0), C_RED.darkened(0.2))
		return k.commit_mesh())


static func nest() -> MeshInstance3D:
	return mesh_instance("nest", func():
		var k := MeshKit.new()
		for i in 12:
			var a := TAU * i / 12.0
			k.cylinder(Vector3(cos(a) * 0.5, 0.1, sin(a) * 0.5), Vector3(cos(a + 0.9) * 0.55, 0.25, sin(a + 0.9) * 0.55), 0.05, 0.04, 4, C_WOOD.darkened(0.1 * (i % 3)), false)
		k.cylinder(Vector3(0, 0, 0), Vector3(0, 0.05, 0), 0.5, 0.5, 10, C_WOOD_D)
		return k.commit_mesh())


static func heron() -> MeshInstance3D:
	return mesh_instance("heron", func():
		var k := MeshKit.new()
		k.ellipsoid(Vector3(0, 0.6, 0), Vector3(0.18, 0.2, 0.32), 8, 5, Color("#F4F4F0"), Color("#DADAD4"))
		k.cylinder(Vector3(0, 0.72, -0.2), Vector3(0, 1.1, -0.3), 0.05, 0.04, 6, Color("#F4F4F0"), false)
		k.ellipsoid(Vector3(0, 1.14, -0.33), Vector3(0.07, 0.07, 0.09), 6, 4, Color("#F4F4F0"))
		k.cone(Vector3(0, 1.13, -0.4), Vector3(0, 1.1, -0.65), 0.025, 4, C_GOLD.darkened(0.1))
		for s in [-1, 1]:
			k.cylinder(Vector3(s * 0.06, 0.45, 0.02), Vector3(s * 0.07, 0.0, 0.04), 0.012, 0.01, 4, C_GOLD.darkened(0.2), false)
			k.fin(Vector3(s * 0.15, 0.68, -0.15), Vector3(s * 0.75, 0.75, 0.05), Vector3(s * 0.15, 0.66, 0.25), Color("#E8E8E2"))
			k.eye(Vector3(s * 0.05, 1.16, -0.37), 0.018, Vector3(s, 0, -0.5))
		return k.commit_mesh())


static func water_blob() -> MeshInstance3D:
	return mesh_instance("water_blob", func():
		var k := MeshKit.new()
		k.ellipsoid(Vector3.ZERO, Vector3(0.22, 0.18, 0.22), 8, 5, Color("#8FD6E8"), Color("#3FB8AF"))
		return k.commit_mesh())


static func boat() -> MeshInstance3D:
	return mesh_instance("boat", func():
		var k := MeshKit.new()
		k.quad(Vector3(-1.0, 0.1, -3.0), Vector3(1.0, 0.1, -3.0), Vector3(0.6, -0.4, 3.0), Vector3(-0.6, -0.4, 3.0), C_WOOD_D)
		k.quad(Vector3(-1.0, 0.1, -3.0), Vector3(-0.6, -0.4, 3.0), Vector3(-1.1, 0.6, 3.2), Vector3(-1.3, 0.7, -3.0), C_WOOD)
		k.quad(Vector3(1.0, 0.1, -3.0), Vector3(1.3, 0.7, -3.0), Vector3(1.1, 0.6, 3.2), Vector3(0.6, -0.4, 3.0), C_WOOD)
		k.tri(Vector3(-1.3, 0.7, -3.0), Vector3(1.3, 0.7, -3.0), Vector3(0, 1.2, -3.8), C_WOOD_L)
		k.box(Vector3(0, 0.9, 0.5), Vector3(1.8, 0.05, 2.2), C_HAT.darkened(0.1))
		k.eye(Vector3(-0.9, 0.55, -2.6), 0.12, Vector3(-1, 0, -0.3))
		k.eye(Vector3(0.9, 0.55, -2.6), 0.12, Vector3(1, 0, -0.3))
		return k.commit_mesh())


# ------------------------------------------------------------------ vật phẩm/UI bổ sung (khớp asset registry)

## Mồi theo ID (bait_milk_tea là ID kỹ thuật cũ: hộp mồi cá tạp, không phải cốc trà sữa).
static func bait(bait_id: String) -> MeshInstance3D:
	return mesh_instance("bait_" + bait_id, func():
		var k := MeshKit.new()
		match bait_id:
			"bait_bread":
				k.box(Vector3(0, 0.03, 0), Vector3(0.12, 0.06, 0.09), Color("#E8C27A"))
				k.box(Vector3(0.05, 0.045, 0.02), Vector3(0.05, 0.05, 0.05), Color("#F6E6BF"))
				k.box(Vector3(-0.07, 0.02, -0.03), Vector3(0.04, 0.04, 0.04), Color("#D9A85A"))
			"bait_worm":
				k.cylinder(Vector3(0, 0, 0), Vector3(0, 0.14, 0), 0.07, 0.07, 10, Color(0.8, 0.9, 0.95))
				k.cylinder(Vector3(0, 0.14, 0), Vector3(0, 0.17, 0), 0.075, 0.075, 10, C_RED)
				for i in 3:
					k.cylinder(Vector3(-0.04 + i * 0.03, 0.02, 0), Vector3(-0.02 + i * 0.03, 0.1, 0.02), 0.012, 0.01, 5, Color("#C9736A"), false)
			"bait_shrimp_paste":
				k.cylinder(Vector3(0, 0, 0), Vector3(0, 0.08, 0), 0.08, 0.07, 10, Color("#C8744A"))
				k.cylinder(Vector3(0, 0.08, 0), Vector3(0, 0.1, 0), 0.075, 0.075, 10, Color("#F4F1DE"))
			"bait_crab_mix":
				k.box(Vector3(0, 0.05, 0), Vector3(0.16, 0.1, 0.12), Color("#7A5A3A"))
				k.ellipsoid(Vector3(0, 0.11, 0), Vector3(0.05, 0.02, 0.04), 8, 3, Color("#D9533F"))
			"bait_fish_strip":
				k.box(Vector3(0, 0.02, 0), Vector3(0.05, 0.02, 0.18), C_SILVER, Basis(Vector3.UP, 0.4))
				k.box(Vector3(0.05, 0.02, 0.02), Vector3(0.05, 0.02, 0.16), C_SILVER_L, Basis(Vector3.UP, -0.3))
			_:  # bait_milk_tea = hộp mồi cá tạp
				k.box(Vector3(0, 0.05, 0), Vector3(0.14, 0.1, 0.1), Color("#5E8F4E"))
				k.box(Vector3(0, 0.105, 0), Vector3(0.15, 0.015, 0.11), Color("#3E6B35"))
				k.box(Vector3(0, 0.06, 0.051), Vector3(0.08, 0.04, 0.002), Color("#F4F1DE"))
		return k.commit_mesh())


static func coin() -> MeshInstance3D:
	return mesh_instance("coin", func():
		var k := MeshKit.new()
		k.cylinder(Vector3(0, 0, -0.012), Vector3(0, 0, 0.012), 0.1, 0.1, 16, C_GOLD)
		k.cylinder(Vector3(0, 0, 0.012), Vector3(0, 0, 0.016), 0.07, 0.07, 16, C_GOLD.darkened(0.15), false)
		k.fin(Vector3(-0.03, -0.035, 0.017), Vector3(0.035, 0.0, 0.017), Vector3(-0.03, 0.035, 0.017), Color("#FFF1B8"))
		return k.commit_mesh())


static func heart() -> MeshInstance3D:
	return mesh_instance("heart", func():
		var k := MeshKit.new()
		k.ellipsoid(Vector3(-0.045, 0.03, 0), Vector3(0.055, 0.055, 0.04), 10, 5, C_RED)
		k.ellipsoid(Vector3(0.045, 0.03, 0), Vector3(0.055, 0.055, 0.04), 10, 5, C_RED)
		k.cone(Vector3(0, 0.02, 0), Vector3(0, -0.09, 0), 0.085, 10, C_RED.darkened(0.1))
		return k.commit_mesh())


static func sign_board() -> MeshInstance3D:
	return mesh_instance("sign_board", func():
		var k := MeshKit.new()
		k.box(Vector3(0, 0.7, 0), Vector3(0.1, 1.4, 0.1), C_WOOD_D)
		k.box(Vector3(0, 1.35, 0.06), Vector3(1.2, 0.5, 0.06), C_WOOD_L)
		k.box(Vector3(0, 1.35, 0.095), Vector3(1.05, 0.36, 0.01), C_WOOD)
		return k.commit_mesh())


static func grill() -> MeshInstance3D:
	return mesh_instance("grill", func():
		var k := MeshKit.new()
		k.box(Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.6), Color("#8A8A84"))
		k.box(Vector3(0, 0.72, 0), Vector3(0.6, 0.04, 0.5), Color("#2B2B2B"))
		for i in 5:
			k.box(Vector3(-0.24 + i * 0.12, 0.75, 0), Vector3(0.02, 0.02, 0.5), Color("#555555"))
		k.ellipsoid(Vector3(0, 0.66, 0), Vector3(0.2, 0.03, 0.15), 8, 3, Color("#E4473C"), Color("#FFC93C"))
		return k.commit_mesh())


static func backpack_display() -> MeshInstance3D:
	return mesh_instance("backpack_display", func():
		var k := MeshKit.new()
		k.box(Vector3(0, 0.22, 0), Vector3(0.36, 0.44, 0.22), Color("#3E7FA8"))
		k.box(Vector3(0, 0.12, 0.12), Vector3(0.28, 0.18, 0.04), Color("#2F6FA8"))
		k.box(Vector3(0, 0.46, 0), Vector3(0.3, 0.06, 0.2), Color("#2B5A7A"))
		for x in [-0.12, 0.12]:
			k.box(Vector3(x, 0.25, -0.12), Vector3(0.04, 0.4, 0.02), C_WOOD_D)
		return k.commit_mesh())


static func reel_display() -> MeshInstance3D:
	return mesh_instance("reel_display", func():
		var k := MeshKit.new()
		k.cylinder(Vector3(-0.05, 0.1, 0), Vector3(0.05, 0.1, 0), 0.09, 0.09, 14, Color("#8A8A84"))
		k.cylinder(Vector3(-0.055, 0.1, 0), Vector3(0.055, 0.1, 0), 0.05, 0.05, 14, C_GOLD, false)
		k.box(Vector3(0.09, 0.1, 0.06), Vector3(0.02, 0.02, 0.12), Color("#2B2B2B"))
		k.box(Vector3(0, 0.0, 0), Vector3(0.05, 0.02, 0.18), Color("#5A5A5A"))
		return k.commit_mesh())


## ID kỹ thuật cũ mdl_acc_boba_pearls = mảng vảy Ánh Bạc bám thân (không phải hạt trân châu).
static func silver_scales() -> MeshInstance3D:
	return mesh_instance("silver_scales", func():
		var k := MeshKit.new()
		for i in 5:
			k.ellipsoid(Vector3(-0.04 + i * 0.02, 0.01 + (i % 2) * 0.012, 0), Vector3(0.018, 0.012, 0.004), 6, 2, C_SILVER_L, C_SILVER)
		return k.commit_mesh())
