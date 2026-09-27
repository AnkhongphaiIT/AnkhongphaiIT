extends Node
## Catalog nội dung dùng chung cho client, room server và (bản Python) backend.
## Nguồn duy nhất: res://data/content/*.json. Không nhân đôi số cân bằng ở chỗ khác.
##
## content_hash = SHA256 của: với mỗi file theo thứ tự tên tăng dần,
##   "<tên file>\n" + <byte gốc của file> + "\n"
## Backend tính y hệt (server/backend/app/content.py) để từ chối client/server lệch dữ liệu.

const CONTENT_DIR := "res://data/content/"
const CONTENT_FILES: PackedStringArray = [
	"baits.json", "balance.json", "bosses.json", "creatures.json", "hunger.json",
	"islands.json", "items.json", "lootboxes.json", "npcs.json", "quests.json",
	"rods.json", "shops.json", "spawn_tables.json", "tools.json", "tricks.json",
	"upgrades.json",
]
const NETWORK_CONTRACT_PATH := "res://data/contracts/network_contract.json"
const INPUT_ACTIONS_PATH := "res://data/contracts/input_actions.json"

var content_hash: String = ""
var load_errors: PackedStringArray = []

var balance: Dictionary = {}
var hunger: Dictionary = {}
var lootboxes: Dictionary = {}
var network: Dictionary = {}
var input_actions: Array = []

## id -> record cho từng loại
var creatures: Dictionary = {}
var baits: Dictionary = {}
var rods: Dictionary = {}
var tools: Dictionary = {}
var items: Dictionary = {}
var islands: Dictionary = {}
var spawn_tables: Dictionary = {}
var quests: Dictionary = {}
var shops: Dictionary = {}
var npcs: Dictionary = {}
var tricks: Dictionary = {}
var bosses: Dictionary = {}
var upgrades: Dictionary = {}
var cosmetics: Dictionary = {}

## Thứ tự hiển thị
var island_order: Array[String] = []
var trick_order: Array[String] = []
var dex_order: Array[String] = []

## name -> message spec trong network_contract
var messages: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	load_errors.clear()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var raw: Dictionary = {}
	for f in CONTENT_FILES:
		var bytes := FileAccess.get_file_as_bytes(CONTENT_DIR + f)
		if bytes.is_empty():
			load_errors.append("Không đọc được %s" % f)
			continue
		ctx.update((f + "\n").to_utf8_buffer())
		ctx.update(bytes)
		ctx.update("\n".to_utf8_buffer())
		var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if typeof(parsed) != TYPE_DICTIONARY:
			load_errors.append("JSON lỗi: %s" % f)
			continue
		raw[f.get_basename()] = parsed
	content_hash = ctx.finish().hex_encode()

	balance = raw.get("balance", {})
	hunger = raw.get("hunger", {})
	lootboxes = raw.get("lootboxes", {})
	creatures = _index(raw, "creatures")
	baits = _index(raw, "baits")
	rods = _index(raw, "rods")
	tools = _index(raw, "tools")
	items = _index(raw, "items")
	islands = _index(raw, "islands")
	spawn_tables = _index(raw, "spawn_tables")
	quests = _index(raw, "quests")
	shops = _index(raw, "shops")
	npcs = _index(raw, "npcs")
	tricks = _index(raw, "tricks")
	bosses = _index(raw, "bosses")
	upgrades = _index(raw, "upgrades")
	cosmetics.clear()
	for c in lootboxes.get("cosmetics", []):
		cosmetics[c["id"]] = c

	island_order.clear()
	var isl: Array = islands.values()
	isl.sort_custom(func(a, b): return int(a["order"]) < int(b["order"]))
	for i in isl:
		island_order.append(i["id"])
	trick_order.clear()
	var tr_list: Array = tricks.values()
	tr_list.sort_custom(func(a, b): return int(a["display_order"]) < int(b["display_order"]))
	for t in tr_list:
		trick_order.append(t["id"])
	dex_order.clear()
	var cr: Array = creatures.values()
	cr.sort_custom(func(a, b): return int(a["dex_order"]) < int(b["dex_order"]))
	for c in cr:
		dex_order.append(c["id"])

	var net_text := FileAccess.get_file_as_string(NETWORK_CONTRACT_PATH)
	var net: Variant = JSON.parse_string(net_text)
	network = net if typeof(net) == TYPE_DICTIONARY else {}
	messages.clear()
	for m in network.get("messages", []):
		messages[m["name"]] = m
	var inp: Variant = JSON.parse_string(FileAccess.get_file_as_string(INPUT_ACTIONS_PATH))
	input_actions = inp.get("actions", []) if typeof(inp) == TYPE_DICTIONARY else []
	if network.is_empty():
		load_errors.append("Không đọc được network_contract.json")


func _index(raw: Dictionary, key: String) -> Dictionary:
	var out: Dictionary = {}
	var doc: Dictionary = raw.get(key, {})
	for r in doc.get("records", []):
		out[r["id"]] = r
	return out


func limit(name: String, default_value: Variant = null) -> Variant:
	return network.get("limits", {}).get(name, default_value)


func protocol_version() -> String:
	return String(network.get("protocol_version", "1.0.0"))


func regular_species() -> Array[String]:
	var out: Array[String] = []
	for id in dex_order:
		if not creatures[id].get("is_boss", false):
			out.append(id)
	return out


func island_zone(island_id: String, zone_id: String) -> Dictionary:
	for z in islands.get(island_id, {}).get("zones", []):
		if z["zone_id"] == zone_id:
			return z
	return {}


func zones_of_kind(island_id: String, kind: String) -> Array:
	var out: Array = []
	for z in islands.get(island_id, {}).get("zones", []):
		if z["kind"] == kind:
			out.append(z)
	return out
