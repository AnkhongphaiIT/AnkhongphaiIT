extends RefCounted
## Bố cục đảo: điểm gameplay phải nằm đúng đất/nước để không có vùng câu hỏng hoặc NPC dưới sông.

func test_all_islands_have_layout(t) -> void:
	for isl in ContentDB.islands:
		t.ok(IslandLayout.has_island(isl), "thiếu layout " + isl)
		var L := IslandLayout.layout(isl)
		for z in ContentDB.islands[isl]["zones"]:
			var zid: String = z["zone_id"]
			match z["kind"]:
				"player_spawn":
					t.ok(L["spawn"].has(zid), "spawn " + zid)
				"fishing":
					t.ok(L["fishing"].has(zid), "fishing " + zid)
				"boss_spot":
					t.ok(L["boss"].has(zid), "boss " + zid)
				"shop":
					t.ok(L["shop"].has(zid), "shop " + zid)


func test_points_on_land_or_water(t) -> void:
	for isl in IslandLayout.LAYOUTS:
		var L: Dictionary = IslandLayout.LAYOUTS[isl]
		for zid in L["spawn"]:
			var p: Vector2 = L["spawn"][zid]
			t.ok(IslandLayout.terrain_height(isl, p.x, p.y) > 0.2, "%s spawn dưới nước" % isl)
		for zid in L["fishing"]:
			var c: Vector2 = L["fishing"][zid][0]
			t.ok(IslandLayout.is_water(isl, c.x, c.y), "%s %s tâm vùng câu không phải nước (h=%.2f)" % [isl, zid, IslandLayout.terrain_height(isl, c.x, c.y)])
		for zid in L["boss"]:
			var b: Dictionary = L["boss"][zid]
			t.ok(IslandLayout.is_water(isl, b["water"].x, b["water"].y), "%s boss water" % isl)
			t.ok(IslandLayout.terrain_height(isl, b["arena"].x, b["arena"].y) > 0.2, "%s arena trên đất" % isl)
			var post: Vector2 = b["post"]
			t.ok(absf(IslandLayout.terrain_height(isl, post.x, post.y)) < 1.2, "%s cọc boss sát bờ (h=%.2f)" % [isl, IslandLayout.terrain_height(isl, post.x, post.y)])
		var shop: Dictionary = IslandLayout.shop_zone(isl)
		t.ok(IslandLayout.terrain_height(isl, shop["pos"].x, shop["pos"].y) > 0.2, "%s sạp trên đất" % isl)
		for npc in L["npcs"]:
			var q: Vector2 = L["npcs"][npc]
			t.ok(IslandLayout.terrain_height(isl, q.x, q.y) > 0.2, "%s %s trên đất" % [isl, npc])
			t.eq(ContentDB.npcs[npc]["island_id"], isl, "NPC đúng đảo")
		t.ok(IslandLayout.terrain_height(isl, L["nest"].x, L["nest"].y) > 0.2, "%s tổ cò trên đất" % isl)
		var pier: Dictionary = L["pier"]
		t.ok(IslandLayout.terrain_height(isl, pier["from"].x, pier["from"].y) > -0.3, "%s gốc bến ở bờ (h=%.2f)" % [isl, IslandLayout.terrain_height(isl, pier["from"].x, pier["from"].y)])
		var end: Vector2 = pier["to"]
		t.ok(IslandLayout.terrain_height(isl, end.x, end.y) < -0.5, "%s đầu bến ở nước" % isl)
		t.ok(IslandLayout.on_pier(isl, end.x, end.y - 0.5), "%s đầu bến đi được" % isl)
		# từ đầu bến quăng 10 m về phía trước phải vào vùng bến đò
		var ahead: Vector2 = end + (end - (pier["from"] as Vector2)).normalized() * 6.0
		t.ok(IslandLayout.zone_at(isl, ahead.x, ahead.y).get("kind", "") == "fishing", "%s trước đầu bến là vùng câu" % isl)


func test_walk_path_spawn_to_pier_end(t) -> void:
	for isl in IslandLayout.LAYOUTS:
		var L: Dictionary = IslandLayout.LAYOUTS[isl]
		var a: Vector2 = L["spawn"].values()[0]
		var b: Vector2 = L["pier"]["from"]
		var c: Vector2 = L["pier"]["to"] - (L["pier"]["to"] - L["pier"]["from"]).normalized() * 0.5
		var ok := true
		for i in 41:
			var p := a.lerp(b, i / 40.0)
			ok = ok and IslandLayout.walkable(isl, p.x, p.y)
			var q := b.lerp(c, i / 40.0)
			ok = ok and IslandLayout.walkable(isl, q.x, q.y)
		t.ok(ok, "%s đi bộ từ spawn ra đầu bến" % isl)
