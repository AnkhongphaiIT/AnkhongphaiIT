extends Node
## Bản dịch VI/EN từ res://data/loc/strings.csv (cột keys,en,vi).
## Không nhúng chữ vào ảnh; mọi chuỗi UI/thoại đi qua Loc.t().

signal locale_changed(locale: String)

const CSV_PATH := "res://data/loc/strings.csv"
const SUPPORTED: PackedStringArray = ["vi", "en"]

var locale: String = "vi"
var _table: Dictionary = {}  # key -> {"en": String, "vi": String}
var missing_keys: Dictionary = {}


func _ready() -> void:
	_load_csv()


func _load_csv() -> void:
	_table.clear()
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		push_error("Loc: không mở được %s" % CSV_PATH)
		return
	var header := f.get_csv_line()
	var i_key := header.find("keys")
	var i_en := header.find("en")
	var i_vi := header.find("vi")
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() <= max(i_key, max(i_en, i_vi)):
			continue
		_table[row[i_key]] = {"en": row[i_en], "vi": row[i_vi]}


func has_key(key: String) -> bool:
	return _table.has(key)


func set_locale(value: String) -> void:
	if value not in SUPPORTED:
		value = "en"
	if value == locale:
		return
	locale = value
	TranslationServer.set_locale(value)
	locale_changed.emit(value)


## Tra khóa và thay {placeholder}. Thiếu khóa: trả về chính khóa và ghi nhận để test bắt được.
func t(key: String, args: Dictionary = {}) -> String:
	var row: Dictionary = _table.get(key, {})
	var s: String = row.get(locale, "")
	if s == "":
		s = row.get("en", "")
	if s == "":
		missing_keys[key] = true
		s = key
	for k in args:
		s = s.replace("{" + String(k) + "}", str(args[k]))
	return s


func name_of(id: String) -> String:
	return t(id + ".name")
