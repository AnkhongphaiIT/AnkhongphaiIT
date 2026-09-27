extends Node
## Âm thanh theo data/contracts/audio_event_map.json + asset_registry.json.
## Chỉ phát file đã có thật (WAV/OGG xuất offline); thiếu file thì im và ghi vào `missing` để báo coverage.
## Không tổng hợp âm runtime (07 §8).

const MAP_PATH := "res://data/contracts/audio_event_map.json"
const REG_PATH := "res://data/contracts/asset_registry.json"
const BUSES := ["Music", "SFX", "UI", "Ambience", "Voice"]

var registry: Dictionary = {}       # asset_id -> {path, variants}
var rules_by_event: Dictionary = {} # event -> [rule]
var missing: Dictionary = {}
var world_root: Node3D
var listener_pos := Vector3.ZERO
var island_id := ""
var _cooldowns: Dictionary = {}
var _voices: Dictionary = {}        # asset_id -> số đang phát
var _music: AudioStreamPlayer
var _music_id := ""
var _amb: AudioStreamPlayer
var _amb_id := ""
var _voice: AudioStreamPlayer
var _duck_until := 0.0
var _duck_db := 0.0
var _cache: Dictionary = {}
var _loops: Dictionary = {}         # key -> AudioStreamPlayer (quay cần, căng dây, nướng)
var unlocked := false


func _ready() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	var reg: Variant = JSON.parse_string(FileAccess.get_file_as_string(REG_PATH))
	if typeof(reg) == TYPE_DICTIONARY:
		for a in reg["assets"]:
			if a["type"] in ["sfx", "music", "ambience", "voice"]:
				registry[a["id"]] = {"path": a["path"], "variants": int(a.get("variants", 0))}
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	if typeof(m) == TYPE_DICTIONARY:
		for r in m["rules"]:
			if not rules_by_event.has(r["event"]):
				rules_by_event[r["event"]] = []
			rules_by_event[r["event"]].append(r)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Ambience"
	add_child(_amb)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)


func unlock() -> void:
	unlocked = true


## Chẩn đoán (chế độ kiểm thử): số nguồn âm đang phát theo loại — dùng để kiểm "không âm trùng sau reconnect".
func debug_playing() -> String:
	var n_music := int(_music.playing)
	var n_amb := int(_amb.playing)
	var n_loops := 0
	for k in _loops:
		if is_instance_valid(_loops[k]) and _loops[k].playing:
			n_loops += 1
	var n_other := 0
	for c in get_children():
		if c != _music and c != _amb and c != _voice and (c is AudioStreamPlayer or c is AudioStreamPlayer3D) and c.playing and c not in _loops.values():
			n_other += 1
	return "music=%d amb=%d loops=%d oneshots=%d music_id=%s" % [n_music, n_amb, n_loops, n_other, _music_id]


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var target := _duck_db if t < _duck_until else 0.0
	var idx := AudioServer.get_bus_index("Music")
	var cur := AudioServer.get_bus_volume_db(idx)
	var base := linear_to_db(maxf(0.0001, float(Settings.get_value("volume_music", 0.5))))
	AudioServer.set_bus_volume_db(idx, move_toward(cur, base + target, 40.0 * delta))


# ------------------------------------------------------------------ nạp file

func _stream_for(asset_id: String) -> AudioStream:
	var reg: Dictionary = registry.get(asset_id, {})
	if reg.is_empty():
		missing[asset_id] = "not_in_registry"
		return null
	var path: String = reg["path"]
	if reg["variants"] > 0:
		path = path.replace("{nn}", "%02d" % randi_range(1, reg["variants"]))
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		missing[asset_id] = "file_missing"
		_cache[path] = null
		return null
	var s: AudioStream = load(path)
	_cache[path] = s
	return s


func has_asset(asset_id: String) -> bool:
	return _stream_for(asset_id) != null


# ------------------------------------------------------------------ phát

func play_ui(asset_id: String, volume_db := 0.0, pitch := 1.0) -> void:
	play(asset_id, "UI", null, volume_db, pitch)


func play(asset_id: String, bus: String, pos: Variant = null, volume_db := 0.0, pitch := 1.0) -> void:
	var s := _stream_for(asset_id)
	if s == null:
		return
	if pos is Vector3 and world_root and is_instance_valid(world_root):
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = s
		p3.bus = bus
		p3.volume_db = volume_db
		p3.pitch_scale = pitch
		p3.unit_size = 6.0
		p3.max_distance = 60.0
		world_root.add_child(p3)
		p3.global_position = pos
		p3.finished.connect(p3.queue_free)
		p3.play()
	else:
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.bus = bus
		p.volume_db = volume_db
		p.pitch_scale = pitch
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()


func play_music(asset_id: String) -> void:
	if asset_id == _music_id and _music.playing:
		return
	var s := _stream_for(asset_id)
	_music_id = asset_id
	if s == null:
		_music.stop()
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_music.stream = s
	_music.play()


func play_ambience(asset_id: String) -> void:
	if asset_id == _amb_id and _amb.playing:
		return
	var s := _stream_for(asset_id)
	_amb_id = asset_id
	if s == null:
		_amb.stop()
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_amb.stream = s
	_amb.play()


func set_island(isl: String) -> void:
	island_id = isl
	var data: Dictionary = ContentDB.islands.get(isl, {})
	play_music(String(data.get("assets", {}).get("music", "mus_isl01_day_loop")))
	play_ambience(String(data.get("assets", {}).get("ambience", "amb_river_day_loop")))


func stop_all() -> void:
	_music.stop()
	_amb.stop()
	_voice.stop()
	for k in _loops.keys():
		stop_loop(k)


## Âm lặp có vòng đời (quay cần, căng dây, bếp nướng): phải dừng khi kết thúc/mất kết nối.
func start_loop(key: String, asset_id: String, bus := "SFX", volume_db := -4.0) -> void:
	if _loops.has(key):
		return
	var s := _stream_for(asset_id)
	if s == null:
		return
	if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		# File lặp đã có điểm loop (chunk smpl) thì giữ nguyên; chỉ tự đặt khi file không có.
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		s = w
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	add_child(p)
	p.play()
	_loops[key] = p


func stop_loop(key: String) -> void:
	if _loops.has(key):
		var p: AudioStreamPlayer = _loops[key]
		p.stop()
		p.queue_free()
		_loops.erase(key)


# ------------------------------------------------------------------ sự kiện → âm

## ctx: {"own": bool (sự kiện của mình), "player_pos": Vector3}
func on_event(name: String, payload: Dictionary, ctx: Dictionary = {}) -> void:
	for rule in rules_by_event.get(name, []):
		var ok := true
		for k in rule.get("when", {}):
			if payload.get(k) != rule["when"][k]:
				ok = false
				break
		if not ok:
			continue
		var aid: String = rule["asset_id"]
		var now := Time.get_ticks_msec() / 1000.0
		var ck: String = name + ":" + aid
		if rule.has("cooldown_s") and now < float(_cooldowns.get(ck, 0.0)):
			continue
		_cooldowns[ck] = now + float(rule.get("cooldown_s", 0.0))
		if rule.has("music_action"):
			match String(rule["music_action"]):
				"play":
					play_music(aid)
				"restore_island":
					var isl: String = payload.get("island_id", island_id)
					play_music(String(ContentDB.islands.get(isl, {}).get("assets", {}).get("music", aid)))
			continue
		if String(rule.get("bus", "SFX")) == "Ambience":
			play_ambience(aid)
			continue
		if rule.has("duck_music_db"):
			_duck_db = float(rule["duck_music_db"])
			_duck_until = now + float(rule.get("duck_s", 0.6))
		var pos: Variant = null
		match String(rule.get("position", "none")):
			"event_position":
				var pa: Variant = payload.get("position")
				if pa is Array and pa.size() == 3:
					pos = Vector3(pa[0], pa[1], pa[2])
			"player":
				pos = ctx.get("player_pos", null)
		var pr := float(rule.get("pitch_random", 0.0))
		var repeat_field: String = rule.get("repeat_for_field", "")
		var n := 1
		if repeat_field != "" and payload.get(repeat_field) is Array:
			n = max(1, (payload[repeat_field] as Array).size())
		for i in n:
			var pitch := 1.0 + randf_range(-pr, pr) + float(rule.get("pitch_step", 0.0)) * i
			if i > 0:
				await get_tree().create_timer(float(rule.get("repeat_interval_s", 0.1))).timeout
			play(aid, String(rule.get("bus", "SFX")), pos, float(rule.get("volume_db", 0.0)), pitch)


# ------------------------------------------------------------------ thoại

var _packs: Dictionary = {}


## Phát thoại rõ nghĩa theo NPC + ngôn ngữ; thiếu thì dùng gibberish (bản phát triển) và ghi thiếu.
func play_voice(npc_id: String, line_key: String) -> void:
	var loc: String = Loc.locale
	var pack_key := "%s_%s" % [npc_id.trim_prefix("npc_"), loc]
	if not _packs.has(pack_key):
		var path := "res://assets/audio/vo/vo_dialogue_%s.json" % pack_key
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_packs[pack_key] = d if typeof(d) == TYPE_DICTIONARY else {}
	var line: Dictionary = _packs[pack_key].get("lines", {}).get(line_key, {})
	var file: String = line.get("file", "")
	if file != "" and ResourceLoader.exists(file):
		_voice.stream = load(file)
		_voice.play()
		_duck_db = -6.0
		_duck_until = Time.get_ticks_msec() / 1000.0 + _voice.stream.get_length()
		return
	missing["voice:%s:%s" % [pack_key, line_key]] = "line_missing"
	var gib: String = ContentDB.npcs.get(npc_id, {}).get("assets", {}).get("voice", "")
	if gib != "":
		play(gib, "Voice")


func stop_voice() -> void:
	_voice.stop()
