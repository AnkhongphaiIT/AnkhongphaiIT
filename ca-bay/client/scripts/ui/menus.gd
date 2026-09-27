class_name Menus
extends RefCounted
## Các bảng menu trong game. Mọi thao tác có giá trị gửi lệnh bền vững; UI chỉ hiển thị kết quả server.


static func _title(text: String) -> Label:
	return UIKit.label(text, 28, UIKit.C_GOLD)


static func _scroll(child: Control, h := 420) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = Vector2(640, h)
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func item_value(it: Dictionary) -> int:
	var v := int(it["base_value"]) * int(it["trick_mult_milli"]) / 1000
	if it.get("cook_level", "raw") == "burnt":
		v = v * int(round(float(ContentDB.balance["cooking"]["burnt_mult"]) * 1000)) / 1000
	return v


# ------------------------------------------------------------------ tạm dừng

static func pause(s) -> Control:
	var v := UIKit.vbox([], 10)
	v.add_child(_title(Loc.t("ui.pause.title")))
	v.add_child(UIKit.label(Loc.t("ui.pause.online_notice"), 16, UIKit.C_MUTED))
	v.add_child(UIKit.label("%s: %s" % [Loc.t("ui.coop.room_code"), s.room.get("invite_code", "?")], 18))
	for pair in [["ui.pause.resume", func(): s.close_menu()], ["ui.hud.bag", func(): s.open_menu("bag")],
			["ui.dex.title", func(): s.open_menu("dex")], ["ui.menu.lootbox", func(): s.open_menu("lootbox")],
			["ui.menu.travel", func(): s.open_menu("travel")], ["ui.menu.settings", func(): s.open_menu("settings")],
			["ui.coop.leave", func(): s.leave_room()]]:
		v.add_child(UIKit.button(Loc.t(pair[0]), pair[1], 360))
	return v


# ------------------------------------------------------------------ sạp

static func shop(s, shop_id: String) -> Control:
	var shop: Dictionary = ContentDB.shops[shop_id]
	var save: Dictionary = s.save
	var inv: Dictionary = save["inventory"]
	var v := UIKit.vbox([], 8)
	v.add_child(_title(Loc.t("ui.shop.title", {"name": Loc.name_of(shop["npc_id"])})))
	v.add_child(UIKit.label("%d %s" % [int(save["currencies"]["money"]), Loc.t("ui.currency.name")], 20, UIKit.C_GOLD))
	# bán cả túi
	var sellable: Array = []
	var total := 0
	for it in inv["bag"]:
		var flags: Array = it.get("flags", [])
		if it["def_kind"] == "item":
			flags = flags + ContentDB.items.get(it["def_id"], {}).get("flags", [])
		if "no_sell" in flags:
			continue
		sellable.append(it["uid"])
		total += item_value(it)
	var sell := UIKit.button(Loc.t("ui.prompt.sell_bag", {"count": sellable.size(), "value": total}), func(): s.durable("inventory.sell", {"item_uids": sellable, "shop_id": shop_id}))
	sell.disabled = sellable.is_empty()
	v.add_child(sell)
	# mua
	var list := UIKit.vbox([], 6)
	for e in shop["entries"]:
		var g: Dictionary = e["grant"]
		var name := Loc.name_of(g["id"])
		if g["kind"] == "upgrade":
			name = "%s %d" % [Loc.name_of(g["id"]), int(g["level"])]
		if int(g.get("amount", 1)) > 1:
			name += " ×%d" % int(g["amount"])
		var owned := false
		match String(g["kind"]):
			"tool":
				owned = g["id"] in inv["tools_owned"] and ContentDB.tools[g["id"]].get("ammo", {}).get("recover", "") != "buy"
			"rod":
				owned = g["id"] in inv["rods_owned"]
			"upgrade":
				owned = int(inv["upgrades"].get(g["id"], 0)) >= int(g["level"])
		var price: int = int(e["price"])
		var label := "%s — %s" % [name, Loc.t("ui.shop.free") if price == 0 else "%d %s" % [price, Loc.t("ui.currency.name")]]
		var b := UIKit.button(Loc.t("ui.shop.owned") if owned else Loc.t("ui.shop.buy"), func(): s.durable("shop.buy", {"shop_id": shop_id, "entry_id": e["entry_id"], "quantity": 1}))
		b.disabled = owned or (price > int(save["currencies"]["money"]))
		var nm_lbl := UIKit.label(label, 17)
		nm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := UIKit.hbox([UIKit.icon(String(g["id"]), 36), nm_lbl, b])
		list.add_child(row)
	v.add_child(_scroll(list, 260))
	# nướng cá
	v.add_child(UIKit.label(Loc.t("ui.shop.cook"), 20, UIKit.C_GOLD))
	if s.cooking_uid != "" and s.cooking_station == shop_id:
		var ck: Dictionary = ContentDB.balance["cooking"]
		var el: float = s.cooking_elapsed()
		var collect := UIKit.button(Loc.t("ui.shop.collect"), func(): s.durable("cooking.collect", {"item_uid": s.cooking_uid, "station_id": shop_id}))
		if el >= 0.0 and el < float(ck["cook_time_s"]):
			collect.text = Loc.t("ui.cook.progress", {"s": int(ceil(float(ck["cook_time_s"]) - el))})
			collect.disabled = true
		elif el >= 0.0 and el <= float(ck["burn_time_s"]):
			collect.text = Loc.t("ui.shop.collect_ready", {"s": int(ceil(float(ck["burn_time_s"]) - el))})
		v.add_child(collect)
	else:
		if s.cooking_uid != "":
			v.add_child(UIKit.label(Loc.t("ui.cook.elsewhere"), 15, UIKit.C_MUTED))
		var cookrow := UIKit.hbox([], 6)
		for it in inv["bag"]:
			if it["def_kind"] == "creature" and it.get("cook_level", "raw") == "raw":
				cookrow.add_child(UIKit.button(Loc.name_of(it["def_id"]), func(): s.durable("cooking.start", {"item_uid": it["uid"], "station_id": shop_id})))
		if cookrow.get_child_count() == 0:
			cookrow.add_child(UIKit.label(Loc.t("ui.shop.cook_hint"), 15, UIKit.C_MUTED))
		v.add_child(cookrow)
	v.add_child(UIKit.button(Loc.t("ui.menu.close"), func(): s.close_menu()))
	return v


# ------------------------------------------------------------------ NPC nhiệm vụ

static func quest_npc(s, npc_id: String) -> Control:
	var v := UIKit.vbox([], 10)
	v.add_child(_title(Loc.name_of(npc_id)))
	if s.last_dialogue.get("npc_id", "") == npc_id:
		v.add_child(UIKit.label(Loc.t(s.last_dialogue["text_key"]), 19))
	var save: Dictionary = s.save
	var npc: Dictionary = ContentDB.npcs[npc_id]
	for qid in npc.get("quest_ids", []):
		var q: Dictionary = ContentDB.quests[qid]
		var st: Dictionary = save["progress"]["quests"].get(qid, {})
		if st.is_empty() or st["state"] == "completed":
			continue
		v.add_child(UIKit.label(Loc.t(q["name_key"]), 22, UIKit.C_GOLD))
		if st["state"] == "available":
			v.add_child(UIKit.button(Loc.t("ui.quest.accept"), func(): s.durable("quest.accept", {"quest_id": qid, "npc_id": npc_id})))
			continue
		var idx := int(st["step_index"])
		if idx >= q["steps"].size():
			v.add_child(UIKit.button(Loc.t("ui.quest.claim"), func(): s.durable("quest.claim", {"quest_id": qid})))
			continue
		var step: Dictionary = q["steps"][idx]
		var have := int(st["counts"].get(step["step_id"], 0))
		v.add_child(UIKit.label("%s (%d/%d)" % [Loc.t(step["objective_key"]), have, int(step["count"])], 18))
		if String(step["type"]).begins_with("deliver") and step.get("deliver_to_npc_id", "") == npc_id:
			var uids: Array = []
			for it in save["inventory"]["bag"]:
				if it["def_id"] == step["target_id"] and uids.size() < int(step["count"]) - have:
					uids.append(it["uid"])
			if uids.is_empty():
				v.add_child(UIKit.label(Loc.t("ui.quest.need_item", {"name": Loc.name_of(step["target_id"])}), 16, UIKit.C_MUTED))
			else:
				v.add_child(UIKit.button(Loc.t("ui.prompt.deliver", {"count": uids.size(), "name": Loc.name_of(step["target_id"])}), func():
					s.durable("quest.deliver", {"quest_id": qid, "step_id": step["step_id"], "npc_id": npc_id, "item_uids": uids})))
		elif step["type"] == "defeat_boss":
			var bait: String = ContentDB.bosses[step["target_id"]]["summon"]["bait_id"]
			v.add_child(UIKit.label(Loc.t("ui.quest.boss_hint", {"bait": Loc.name_of(bait), "count": int(save["inventory"]["bait_counts"].get(bait, 0)), "key": Settings.key_label("interact")}), 16, UIKit.C_MUTED))
	v.add_child(UIKit.button(Loc.t("ui.dialogue.skip") if s.last_dialogue.get("npc_id", "") == npc_id else Loc.t("ui.menu.close"), func(): s.close_menu()))
	return v


# ------------------------------------------------------------------ Sổ Cá

static func dex(s, tab := "species") -> Control:
	var v := UIKit.vbox([], 8)
	v.add_child(_title(Loc.t("ui.dex.title")))
	v.add_child(UIKit.hbox([UIKit.button(Loc.t("ui.dex.tab_species"), func(): s.open_menu("dex")), UIKit.button(Loc.t("ui.dex.tab_tricks"), func(): s.open_menu("dex_tricks"))]))
	var list := UIKit.vbox([], 4)
	var col: Dictionary = s.save["collection"]
	if tab == "species":
		var n := 0
		for cid in ContentDB.dex_order:
			var c: Dictionary = ContentDB.creatures[cid]
			var got: Dictionary = col["species"].get(cid, {})
			if not got.is_empty():
				n += 1
			var isl := ", ".join(c["island_ids"].map(func(i): return Loc.name_of(i)))
			var txt := "%02d  %s — %s" % [int(c["dex_order"]), Loc.name_of(cid) if not got.is_empty() else Loc.t("ui.dex.unknown"), isl]
			if not got.is_empty():
				txt += "  ·  " + Loc.t("ui.dex.caught", {"n": int(got["caught"])}) + "  ·  " + Loc.t("ui.dex.best", {"value": int(got["best_value"])})
				if not (got["variants_seen"] as Array).is_empty():
					txt += "  ·  " + Loc.name_of("var_boba")
			if c.get("is_boss", false):
				txt += "  [" + Loc.t("ui.dex.boss") + "]"
			var lbl := UIKit.label(txt, 16, UIKit.C_TEXT if not got.is_empty() else UIKit.C_MUTED)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var ic := UIKit.icon(cid, 36)
			if got.is_empty():
				ic.modulate = Color(0, 0, 0, 0.55)  # bóng đen khi chưa gặp
			list.add_child(UIKit.hbox([ic, lbl], 6))
		v.add_child(UIKit.label(Loc.t("ui.dex.progress", {"n": n, "total": ContentDB.dex_order.size()}), 18, UIKit.C_GOLD))
	else:
		for tid in ContentDB.trick_order:
			var t: Dictionary = ContentDB.tricks[tid]
			var seen: bool = tid in col["tricks_seen"]
			var desc := Loc.t(t["desc_key"], {"value": t.get("display_value", "")})
			list.add_child(UIKit.label("×%.2f  %s — %s" % [float(t["multiplier"]), Loc.t(t["name_key"]), desc], 16, UIKit.C_TEXT if seen else UIKit.C_MUTED))
		list.add_child(UIKit.label(Loc.t("ui.dex.trick_cap", {"cap": ContentDB.balance["scoring"]["max_total_multiplier"]}), 15, UIKit.C_MUTED))
	v.add_child(_scroll(list, 400))
	v.add_child(UIKit.button(Loc.t("ui.menu.close"), func(): s.close_menu()))
	return v


# ------------------------------------------------------------------ hộp quà

static func lootbox(s) -> Control:
	var box: Dictionary = ContentDB.lootboxes["records"][0]
	var save: Dictionary = s.save
	var cur: Dictionary = save["currencies"]
	var v := UIKit.vbox([], 8)
	v.add_child(_title(Loc.name_of(box["id"])))
	v.add_child(UIKit.label(Loc.t("ui.lootbox.explain"), 16))
	v.add_child(UIKit.label(Loc.t("ui.lootbox.version", {"version": box["table_version"]}), 14, UIKit.C_MUTED))
	var odds := UIKit.vbox([], 2)
	var total := float(box["total_weight"])
	for e in box["entries"]:
		var cos: Dictionary = ContentDB.cosmetics[e["cosmetic_id"]]
		var owned: bool = e["cosmetic_id"] in save["cosmetics"]["owned"]
		var sw := ColorRect.new()
		sw.color = Color(cos["color_hex"])
		sw.custom_minimum_size = Vector2(22, 22)
		odds.add_child(UIKit.hbox([sw, UIKit.label("%s — %s%s" % [Loc.t(cos["name_key"]), Loc.t("ui.lootbox.odds", {"chance": UIKit.percent(float(e["weight"]) * 100.0 / total)}), "  ✓" if owned else ""], 16)]))
	v.add_child(odds)
	v.add_child(UIKit.label("%s: %d · %s: %d" % [Loc.t("ui.currency.ticket"), int(cur["festival_ticket"]), Loc.t("ui.currency.dust"), int(cur["cosmetic_dust"])], 18, UIKit.C_GOLD))
	var open := UIKit.button(Loc.t("ui.lootbox.open", {"count": int(box["ticket_cost"])}), func(): s.durable("lootbox.open", {"box_id": box["id"], "table_version": box["table_version"]}))
	open.disabled = int(cur["festival_ticket"]) < int(box["ticket_cost"])
	v.add_child(open)
	if open.disabled:
		v.add_child(UIKit.label(Loc.t("ui.lootbox.no_tickets"), 15, UIKit.C_MUTED))
	if not s.last_lootbox.is_empty():
		var r: Dictionary = s.last_lootbox
		if not r.get("_revealed", false) and ResourceLoader.exists("res://assets/vfx/vfx_lootbox_reveal.tscn"):
			r["_revealed"] = true  # chỉ nổ pháo giấy một lần cho mỗi lần mở
			var fx: Control = load("res://assets/vfx/vfx_lootbox_reveal.tscn").instantiate()
			fx.position = Vector2(320, 40)
			v.add_child(fx)
		var cos2: Dictionary = ContentDB.cosmetics.get(r["cosmetic_id"], {})
		var txt := Loc.t(cos2.get("name_key", ""))
		if r["outcome"] == "duplicate":
			txt += " — " + Loc.t("ui.lootbox.duplicate", {"count": int(r["dust_granted"])})
		v.add_child(UIKit.label(txt, 22, UIKit.C_GREEN))
	# chọn trực tiếp bằng bụi + trang bị
	var list := UIKit.vbox([], 4)
	for cid in ContentDB.cosmetics:
		var cos3: Dictionary = ContentDB.cosmetics[cid]
		var owned2: bool = cid in save["cosmetics"]["owned"]
		var row := UIKit.hbox([UIKit.label(Loc.t(cos3["name_key"]) + " (" + Loc.name_of(cos3["target_id"]) + ")", 15)])
		if not owned2:
			var b := UIKit.button(Loc.t("ui.lootbox.direct", {"count": int(cos3["direct_dust_cost"])}), func(): s.durable("cosmetic.buy", {"cosmetic_id": cid}))
			b.disabled = int(cur["cosmetic_dust"]) < int(cos3["direct_dust_cost"])
			row.add_child(b)
		elif cos3["target_id"] in save["inventory"]["tools_owned"] + save["inventory"]["rods_owned"]:
			row.add_child(UIKit.button(Loc.t("ui.lootbox.equip"), func(): s.durable("cosmetic.equip", {"equipment_id": cos3["target_id"], "cosmetic_id": cid})))
		list.add_child(row)
	v.add_child(_scroll(list, 160))
	v.add_child(UIKit.button(Loc.t("ui.menu.close"), func(): s.close_menu()))
	return v


# ------------------------------------------------------------------ túi

static func bag(s) -> Control:
	var inv: Dictionary = s.save["inventory"]
	var v := UIKit.vbox([], 8)
	v.add_child(_title(Loc.t("ui.hud.bag") + " %d/%d" % [(inv["bag"] as Array).size(), int(inv["capacity"])]))
	if (inv["bag"] as Array).is_empty():
		v.add_child(UIKit.label(Loc.t("ui.bag.empty"), 16, UIKit.C_MUTED))
	for it in inv["bag"]:
		var name := Loc.name_of(it["def_id"])
		if it.get("variant_id") != null:
			name += " · " + Loc.name_of("var_boba")
		if it.get("cook_level", "raw") == "burnt":
			name += " · " + Loc.t("ui.bag.burnt")
		v.add_child(UIKit.hbox([UIKit.icon(it["def_id"], 36), UIKit.label("%s — %d %s" % [name, item_value(it), Loc.t("ui.currency.name")], 17),
			UIKit.button(Loc.t("ui.bag.drop"), func(): s.durable("inventory.drop", {"item_uid": it["uid"]}))]))
	if not (inv["recovery_inbox"] as Array).is_empty():
		v.add_child(UIKit.label(Loc.t("ui.bag.inbox"), 18, UIKit.C_GOLD))
		for it2 in inv["recovery_inbox"]:
			v.add_child(UIKit.hbox([UIKit.label(Loc.name_of(it2["def_id"]), 16),
				UIKit.button(Loc.t("ui.bag.take"), func(): s.durable("inventory.pickup", {"item_uid": it2["uid"]}))]))
	v.add_child(UIKit.label(Loc.t("ui.hud.hunger") + ": %d" % int(s.my_hunger), 18))
	for f in ContentDB.hunger["foods"]:
		var n := int(inv["food_counts"].get(f["item_id"], 0))
		var b := UIKit.button(Loc.t("ui.prompt.eat", {"name": Loc.name_of(f["item_id"])}) + " (%d)" % n, func(): s.durable("food.consume", {"item_id": f["item_id"]}))
		b.disabled = n <= 0
		v.add_child(b)
	# đổi mồi
	var baits := UIKit.hbox([], 6)
	for bid in ContentDB.baits:
		var bait: Dictionary = ContentDB.baits[bid]
		if bait.has("summons_boss_id"):
			continue
		var cnt := int(inv["bait_counts"].get(bid, 0))
		if bait.get("infinite", false) or cnt > 0:
			var bb := UIKit.button("%s (%s)" % [Loc.name_of(bid), "∞" if bait.get("infinite", false) else str(cnt)], func(): s.durable("bait.select", {"bait_id": bid}))
			bb.disabled = inv["selected_bait_id"] == bid
			baits.add_child(bb)
	v.add_child(baits)
	v.add_child(UIKit.button(Loc.t("ui.menu.close"), func(): s.close_menu()))
	return v


# ------------------------------------------------------------------ đi đảo

static func travel(s) -> Control:
	var v := UIKit.vbox([], 8)
	v.add_child(_title(Loc.t("ui.menu.travel")))
	v.add_child(UIKit.label(Loc.t("ui.travel.explain"), 16, UIKit.C_MUTED))
	for isl in ContentDB.island_order:
		var unlocked: bool = isl in s.save["progress"]["islands_unlocked"]
		var b := UIKit.button(Loc.t("ui.coop.travel_vote", {"name": Loc.name_of(isl)}), func(): s.send_cmd("island.vote", {"island_id": isl, "approve": true}))
		b.disabled = not unlocked or isl == s.island_id
		v.add_child(UIKit.hbox([b, UIKit.label("" if unlocked else Loc.t("ui.travel.locked"), 15, UIKit.C_MUTED)]))
	v.add_child(UIKit.button(Loc.t("ui.menu.close"), func(): s.close_menu()))
	return v
