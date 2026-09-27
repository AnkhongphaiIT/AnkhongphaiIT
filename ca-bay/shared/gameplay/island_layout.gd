class_name IslandLayout
extends RefCounted
## Bố cục 3 đảo (địa hình hàm độ cao + vị trí vùng, NPC, sạp, bến, cọc boss, tổ cò).
## Dùng chung client (dựng hình) và room server (mô phỏng, kiểm tầm) để hai bên khớp tuyệt đối.
## Mặt nước y = 0. Không dùng RNG runtime: mọi giá trị là hằng số hoặc hàm xác định.

const WATER_Y := 0.0
const DEEP_Y := -3.2
const PIER_DECK_Y := 0.55

## Tham số từng đảo. Góc theo radian, vị trí theo mét (x, z).
const LAYOUTS := {
	"isl_01_cu_lao": {
		"radius": 34.0, "wobble": [[3, 3.5, 0.3], [5, 2.0, 1.7], [7, 1.1, 0.9]], "hill": 1.6, "hill_freq": 0.11,
		"palette": "cu_lao",
		"spawn": {"zone_01_spawn": Vector2(0, 16)},
		"pier": {"from": Vector2(0, 26), "to": Vector2(0, 46), "width": 3.0},
		"fishing": {"zone_01_ben_do": [Vector2(0, 50), 11.0], "zone_01_bai_bun": [Vector2(45, 4), 11.0]},
		"boss": {"zone_01_boss_spot": {"water": Vector2(-46, -8), "radius": 9.0, "arena": Vector2(-20, -5), "arena_radius": 12.0, "post": Vector2(-29, -7)}},
		"shop": {"zone_01_shop": {"shop_id": "shop_co_ba", "pos": Vector2(-9, 20), "npc_id": "npc_co_ba"}},
		"npcs": {"npc_co_ba": Vector2(-9, 18.4), "npc_ong_tu": Vector2(6, 22)},
		"nest": Vector2(4, -20),
		"props": {"palm": [[-18, 6], [14, -8], [-6, -14], [22, 12], [-26, 14], [10, 4], [-14, -24], [26, -16]],
			"hut": [[-12, 26, 0.3], [12, -2, 2.1]], "rock": [[30, -18], [-30, 20], [18, 24]]},
	},
	"isl_02_rung_dua": {
		"radius": 38.0, "wobble": [[2, 4.0, 1.1], [4, 3.0, 0.2], [9, 1.3, 2.4]], "hill": 1.0, "hill_freq": 0.09,
		"palette": "rung_dua",
		"spawn": {"zone_02_spawn": Vector2(-4, 18)},
		"pier": {"from": Vector2(-4, 30), "to": Vector2(-4, 52), "width": 3.0},
		"fishing": {"zone_02_ben_do": [Vector2(-4, 56), 11.0], "zone_02_bai_bun": [Vector2(-8, -10), 7.0]},
		"pond": {"center": Vector2(-8, -10), "radius": 8.0},
		"boss": {"zone_02_boss_spot": {"water": Vector2(52, 10), "radius": 9.0, "arena": Vector2(30, 8), "arena_radius": 12.0, "post": Vector2(42, 11)}},
		"shop": {"zone_02_shop": {"shop_id": "shop_bay_cho", "pos": Vector2(-16, 22), "npc_id": "npc_bay_cho"}},
		"npcs": {"npc_bay_cho": Vector2(-16, 20.4), "npc_nam_sau": Vector2(6, 24)},
		"nest": Vector2(20, -22),
		"props": {"nipa": [[-24, 8], [-20, -2], [-26, -14], [2, -24], [12, -18], [24, 18], [-2, 4], [16, 2], [-12, 8], [4, 10],
			[-12, 31], [5, 32], [-19, 30], [11, 30], [-9, 35], [3, 36]],
			"hut": [[-20, 28, 0.2], [14, -6, 1.2]], "rock": [[28, -20]]},
	},
	"isl_03_mui_da": {
		"radius": 36.0, "wobble": [[3, 2.5, 0.7], [6, 3.0, 2.2], [11, 1.2, 0.3]], "hill": 3.0, "hill_freq": 0.08,
		"palette": "mui_da",
		"spawn": {"zone_03_spawn": Vector2(2, 16)},
		"pier": {"from": Vector2(2, 28), "to": Vector2(2, 50), "width": 3.0},
		"fishing": {"zone_03_ben_do": [Vector2(2, 54), 11.0], "zone_03_bai_bun": [Vector2(-46, 6), 11.0]},
		"boss": {"zone_03_boss_spot": {"water": Vector2(10, -50), "radius": 9.0, "arena": Vector2(8, -24), "arena_radius": 12.0, "post": Vector2(9, -35)}},
		"shop": {"zone_03_shop": {"shop_id": "shop_co_tam", "pos": Vector2(-10, 20), "npc_id": "npc_co_tam"}},
		"npcs": {"npc_co_tam": Vector2(-10, 18.4), "npc_chi_lan": Vector2(10, 22)},
		"nest": Vector2(-16, -10),
		"props": {"palm": [[-18, 8], [20, 6], [-4, -8]], "rock": [[24, -10], [-24, -16], [28, 14], [-28, 4], [14, -14], [-10, -24], [30, -2],
			[-9, 30], [12, 29], [16, 24], [-16, 32]],
			"stack": [[11, 42, 3.2], [-8, 46, 2.6], [20, 50, 3.8], [-18, 40, 2.2]],
			"lighthouse": [[20, -24]], "hut": [[-14, 26, 0.4]]},
	},
}


static func has_island(island_id: String) -> bool:
	return LAYOUTS.has(island_id)


static func layout(island_id: String) -> Dictionary:
	return LAYOUTS.get(island_id, {})


## Bán kính bờ theo góc (hình đảo không tròn đều).
static func shore_radius(island_id: String, angle: float) -> float:
	var L: Dictionary = LAYOUTS[island_id]
	var r: float = L["radius"]
	for w in L["wobble"]:
		r += float(w[1]) * sin(float(w[0]) * angle + float(w[2]))
	return r


## Độ cao địa hình (m). >0 là đất; <0 là nước.
static func terrain_height(island_id: String, x: float, z: float) -> float:
	var L: Dictionary = LAYOUTS[island_id]
	var d := sqrt(x * x + z * z)
	var ang := atan2(z, x)
	var r := shore_radius(island_id, ang)
	# chuyển tiếp bờ: trong bờ 7 m là đất cao dần, ngoài bờ 9 m xuống đáy sông
	var t := clampf((r + 9.0 - d) / 16.0, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var h := lerpf(DEEP_Y, 1.2, t)
	var inner := clampf((r - 6.0 - d) / 10.0, 0.0, 1.0)
	var f: float = L["hill_freq"]
	h += float(L["hill"]) * inner * (0.55 + 0.45 * sin(x * f + 0.7) * cos(z * f * 1.3 - 0.4))
	if L.has("pond"):
		var pc: Vector2 = L["pond"]["center"]
		var pr: float = L["pond"]["radius"]
		var pd := Vector2(x, z).distance_to(pc)
		if pd < pr + 3.0:
			var pt := clampf((pd - pr + 3.0) / 6.0, 0.0, 1.0)
			pt = pt * pt * (3.0 - 2.0 * pt)
			h = minf(h, lerpf(-1.6, h, pt))
	return h


static func on_pier(island_id: String, x: float, z: float) -> bool:
	var p: Dictionary = LAYOUTS[island_id]["pier"]
	var a: Vector2 = p["from"]
	var b: Vector2 = p["to"]
	var w: float = p["width"] * 0.5
	var ab := b - a
	var t := (Vector2(x, z) - a).dot(ab) / ab.length_squared()
	if t < 0.0 or t > 1.0:
		return false
	return (a + ab * t).distance_to(Vector2(x, z)) <= w


## Mặt đứng được cho người/sinh vật: đất hoặc sàn bến.
static func ground_height(island_id: String, x: float, z: float) -> float:
	var h := terrain_height(island_id, x, z)
	if on_pier(island_id, x, z):
		return maxf(h, PIER_DECK_Y)
	return h


static func is_water(island_id: String, x: float, z: float) -> bool:
	return terrain_height(island_id, x, z) < -0.25 and not on_pier(island_id, x, z)


## Người chơi đi được: đất (kể cả lội nông tới -0.35 m) hoặc sàn bến.
static func walkable(island_id: String, x: float, z: float) -> bool:
	if on_pier(island_id, x, z):
		return true
	return terrain_height(island_id, x, z) > -0.35


static func v3(island_id: String, p: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(p.x, ground_height(island_id, p.x, p.y) + lift, p.y)


static func spawn_point(island_id: String, zone_id: String = "") -> Vector3:
	var sp: Dictionary = LAYOUTS[island_id]["spawn"]
	var key: String = zone_id if sp.has(zone_id) else sp.keys()[0]
	return v3(island_id, sp[key])


static func spawn_zone_id(island_id: String) -> String:
	return LAYOUTS[island_id]["spawn"].keys()[0]


## Vùng câu chứa điểm (x,z) trong nước: {"zone_id":..., "kind": "fishing"|"boss_spot"} hoặc {}.
static func zone_at(island_id: String, x: float, z: float) -> Dictionary:
	var L: Dictionary = LAYOUTS[island_id]
	var p := Vector2(x, z)
	for zid in L["boss"]:
		var b: Dictionary = L["boss"][zid]
		if p.distance_to(b["water"]) <= float(b["radius"]):
			return {"zone_id": zid, "kind": "boss_spot"}
	for zid in L["fishing"]:
		var f: Array = L["fishing"][zid]
		if p.distance_to(f[0]) <= float(f[1]):
			return {"zone_id": zid, "kind": "fishing"}
	return {}


static func shop_zone(island_id: String) -> Dictionary:
	var L: Dictionary = LAYOUTS[island_id]
	var zid: String = L["shop"].keys()[0]
	var s: Dictionary = L["shop"][zid]
	return {"zone_id": zid, "shop_id": s["shop_id"], "pos": s["pos"], "npc_id": s["npc_id"]}


## Đảo có NPC này ("" nếu không có).
static func island_of_npc(npc_id: String) -> String:
	for isl in LAYOUTS:
		if (LAYOUTS[isl]["npcs"] as Dictionary).has(npc_id):
			return isl
	return ""


static func npc_position(island_id: String, npc_id: String) -> Vector3:
	var npcs: Dictionary = LAYOUTS[island_id]["npcs"]
	if not npcs.has(npc_id):
		return Vector3.INF
	return v3(island_id, npcs[npc_id])


static func boss_spot(island_id: String) -> Dictionary:
	var L: Dictionary = LAYOUTS[island_id]
	var zid: String = L["boss"].keys()[0]
	var out: Dictionary = (L["boss"][zid] as Dictionary).duplicate()
	out["zone_id"] = zid
	return out


## Hướng ra nước gần nhất (dùng cho cá chạy về sông).
## Điểm hồi sinh khi bị KO giữa trận boss: trên đất, trong bãi, giữa tâm bãi và cọc cờ (cọc đứng ở mép nước).
static func boss_respawn_point(island_id: String) -> Vector3:
	var b := boss_spot(island_id)
	return v3(island_id, (b["arena"] as Vector2).lerp(b["post"], 0.6))


static func toward_water(island_id: String, x: float, z: float) -> Vector2:
	var p := Vector2(x, z)
	if p.length() < 0.01:
		return Vector2(0, 1)
	var dir := p.normalized()
	if LAYOUTS[island_id].has("pond"):
		var pc: Vector2 = LAYOUTS[island_id]["pond"]["center"]
		if p.distance_to(pc) < 14.0:
			return (pc - p).normalized() if p.distance_to(pc) > 0.01 else Vector2(1, 0)
	return dir


## Tìm điểm đất gần nhất theo tia từ p về phía tâm đảo (dùng khi cá cần điểm đáp an toàn).
static func nearest_land(island_id: String, p: Vector2) -> Vector2:
	if walkable(island_id, p.x, p.y) and terrain_height(island_id, p.x, p.y) > 0.0 or on_pier(island_id, p.x, p.y):
		return p
	var q := p
	for i in 80:
		q = q.move_toward(Vector2.ZERO, 0.75)
		if (terrain_height(island_id, q.x, q.y) > 0.05) or on_pier(island_id, q.x, q.y):
			return q
	return Vector2.ZERO
