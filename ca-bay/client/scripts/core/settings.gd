extends Node
## Tùy chọn cục bộ của máy (không phải tiến trình): ngôn ngữ, âm lượng, chuột, chất lượng, phím.
## Lưu ở user://settings.json; lưu thất bại vẫn chơi được và chỉ áp dụng cho phiên này.
## Không bao giờ chứa tiền/túi đồ/tiến trình (08 §5).

signal changed(key: String)

const PATH := "user://settings.json"
const SETTINGS_VERSION := 1

var data: Dictionary = {}
var persisted: bool = true


func _ready() -> void:
	data = defaults()
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY and int(parsed.get("settings_version", 0)) == SETTINGS_VERSION:
			for k in parsed:
				if data.has(k) and typeof(parsed[k]) == typeof(data[k]):
					data[k] = parsed[k]
	if data["locale"] == "auto":
		data["locale"] = "vi" if OS.get_locale_language() == "vi" else "en"
	_apply_input_map()
	_apply_audio()
	Loc.set_locale(data["locale"])


func defaults() -> Dictionary:
	var d: Dictionary = ContentDB.balance.get("settings_defaults", {})
	return {
		"settings_version": SETTINGS_VERSION,
		"locale": String(d.get("language", "auto")),
		"volume_master": 1.0,
		"volume_music": db_to_linear(float(d.get("music_volume_db", -6))),
		"volume_sfx": db_to_linear(float(d.get("sfx_volume_db", 0))),
		"volume_voice": 1.0,
		"subtitles": true,
		"mouse_sensitivity": float(d.get("look_sensitivity", 1.0)),
		"invert_y": bool(d.get("invert_y", false)),
		"fov_deg": float(d.get("fov_deg", 75)),
		"quality": "low" if String(d.get("quality", "auto")) == "auto" else String(d.get("quality")),
		"camera_shake": true,
		"reel_mode": String(d.get("reel_mode", "hold")),
		"auto_swap_after_launch": bool(d.get("auto_swap_after_launch", true)),
		"keybinds": {},
	}


func get_value(key: String, fallback: Variant = null) -> Variant:
	return data.get(key, fallback)


func set_value(key: String, value: Variant) -> void:
	if not data.has(key):
		return
	data[key] = value
	if key == "locale":
		Loc.set_locale(String(value))
	if key.begins_with("volume_"):
		_apply_audio()
	if key == "keybinds":
		_apply_input_map()
	save()
	changed.emit(key)


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		persisted = false
		return
	f.store_string(JSON.stringify(data))
	persisted = true


func _apply_audio() -> void:
	for bus_name in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(data["volume_master"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, float(data["volume_music"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(data["volume_sfx"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(maxf(0.0001, float(data["volume_voice"]))))


## Tạo InputMap từ data/contracts/input_actions.json (desktop), cộng phím người dùng đổi.
func _apply_input_map() -> void:
	var custom: Dictionary = data.get("keybinds", {})
	for a in ContentDB.input_actions:
		var action: String = a["action"]
		if action == "look":
			continue
		if a.get("debug_only", false) and not OS.is_debug_build():
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var binds: Array = custom.get(action, a.get("desktop", []))
		for b in binds:
			var ev := _event_for(String(b))
			if ev:
				InputMap.action_add_event(action, ev)


static func _event_for(name: String) -> InputEvent:
	match name:
		"mouse_left":
			var m := InputEventMouseButton.new(); m.button_index = MOUSE_BUTTON_LEFT; return m
		"mouse_right":
			var m := InputEventMouseButton.new(); m.button_index = MOUSE_BUTTON_RIGHT; return m
		"wheel_up":
			var m := InputEventMouseButton.new(); m.button_index = MOUSE_BUTTON_WHEEL_UP; return m
		"wheel_down":
			var m := InputEventMouseButton.new(); m.button_index = MOUSE_BUTTON_WHEEL_DOWN; return m
		"mouse_motion":
			return null
	var k := InputEventKey.new()
	var code := OS.find_keycode_from_string(name)
	if code == KEY_NONE:
		return null
	k.physical_keycode = code
	return k
