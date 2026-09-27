class_name EntityView
extends Node3D
## Hiển thị người chơi khác và thực thể từ snapshot server (nội suy lùi 100 ms).
## Chỉ trình bày: trạng thái, chủ sở hữu, giá trị đều đến từ server.

const INTERP_MS := 100.0

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
		var body: Node3D = n.get_node("Avatar")
		body.rotation.z = lerpf(body.rotation.z, (PI * 0.5 if pb["mode"] == "knocked_out" else 0.0), 8 * delta)
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
	var lbl := WorldView._label3d(p["display_name"], 0.5)
	lbl.name = "Name"
	lbl.modulate = player_colors[slot % 4].lightened(0.4)
	lbl.position = Vector3(0, 2.35, 0)
	root.add_child(lbl)
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
			var info := WorldView._label3d("", 0.4)
			info.name = "Info"
			info.position = Vector3(0, 0.95, 0)
			info.visible = false
			root.add_child(info)
		"boss":
			var bm := Models.creature(def_id)
			bm.name = "Model"
			bm.scale = Vector3.ONE * 3.2
			root.add_child(bm)
			var hb := WorldView._label3d("", 0.8)
			hb.name = "Info"
			hb.position = Vector3(0, 3.6, 0)
			root.add_child(hb)
		"prop":
			match def_id:
				"lure":
					root.add_child(Models.bobber())
				"boss_projectile":
					root.add_child(Models.water_blob())
				"thief_bird":
					var h := Models.heron()
					h.name = "Model"
					root.add_child(h)
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
			stars.visible = ko
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
			if ko and m.has("value"):
				var nm: String = players_meta.get(owner, {}).get("name", "?")
				info.text = "%s · %d %s\n%s" % [Loc.name_of(e["def_id"]), int(m["value"]), Loc.t("ui.currency.name"), Loc.t("ui.coop.loot_owner", {"name": nm})]
				info.modulate = Color("#FFF8E7") if owner == my_account_id else Color("#B8C4C8")
				info.visible = true
			else:
				info.visible = false
		"boss":
			var info2: Label3D = n.get_node("Info")
			var bm: Node3D = n.get_node("Model")
			var hp: float = meta.get(uid, {}).get("hp_ratio", 1.0)
			info2.text = "%s\n%s" % [Loc.name_of(e["def_id"]), "█".repeat(int(round(hp * 20))) + "░".repeat(20 - int(round(hp * 20)))]
			var t := Time.get_ticks_msec() / 1000.0
			match state:
				"telegraph_tail_slam", "telegraph_belly_charge", "telegraph_water_splash":
					bm.position.y = 0.15 + absf(sin(t * 14.0)) * 0.25
					bm.scale = Vector3.ONE * (3.2 + sin(t * 20.0) * 0.12)
				"stunned":
					bm.rotation.z = lerpf(bm.rotation.z, 0.6, 6 * delta)
				"defeated":
					bm.rotation.z = lerpf(bm.rotation.z, PI * 0.5, 4 * delta)
				_:
					bm.position.y = 0.0
					bm.scale = Vector3.ONE * 3.2
					bm.rotation.z = lerpf(bm.rotation.z, 0.0, 6 * delta)
		"prop":
			if e["def_id"] == "lure":
				n.position.y += sin(Time.get_ticks_msec() / 200.0) * 0.03 * (3.0 if state.ends_with("biting") else 1.0)


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
			lines[key].queue_free()
			lines.erase(key)


func _draw_line(key: String, a: Vector3, b: Vector3, taut: bool) -> void:
	var mi: MeshInstance3D = lines.get(key)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.95, 0.95, 0.9)
		mi.material_override = mat
		mi.top_level = true
		add_child(mi)
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
