extends SceneTree
## Dựng thư viện hoạt ảnh (AnimationLibrary .tres) theo asset registry bằng keyframe procedural.
## Mô hình low-poly là một khối lưới/đối tượng, nên clip điều khiển transform của nút theo quy ước:
##   fp            : AnimationPlayer con của viewmodel → "ToolHolder"
##   npc_basic     : con của nút NPC (Models.person)  → "Body"
##   boss_*        : con của nút "Model" boss          → "Body"
##   egret         : con của nút thực thể cò           → "Model"
##   player_remote : con của nút người chơi khác       → "Avatar/Body", "Rod"
## godot --headless --path . --script art_src/anim/build_anim.gd

const OUT := "res://assets/anim/"


func _init() -> void:
	var libs := {
		"anm_lib_fp": _fp(),
		"anm_lib_npc_basic": _npc(),
		"anm_lib_boss_ca_loc": _boss("ca_loc", 1.0, false),
		"anm_lib_boss_cua_bun": _boss("cua_bun", 0.8, true),
		"anm_lib_boss_ca_bop": _boss("ca_bop", 1.2, false),
		"anm_lib_egret": _egret(),
		"anm_lib_player_remote": _player(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var total := 0
	var failed := 0
	for name in libs:
		var lib: AnimationLibrary = libs[name]
		total += lib.get_animation_list().size()
		var err := ResourceSaver.save(lib, OUT + name + ".tres")
		if err != OK:
			failed += 1
			printerr("ANIM_ERROR %s %d" % [name, err])
	print("ANIM_BUILD libs=%d clips=%d failed=%d" % [libs.size(), total, failed])
	quit(1 if failed else 0)


## tracks: [[đường_dẫn_thuộc_tính, [[t, giá_trị], ...]], ...]
static func clip(length: float, loop: bool, tracks: Array) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for tr in tracks:
		var i := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(i, NodePath(tr[0]))
		a.track_set_interpolation_type(i, Animation.INTERPOLATION_CUBIC)
		a.value_track_set_update_mode(i, Animation.UPDATE_CONTINUOUS)
		for k in tr[1]:
			a.track_insert_key(i, float(k[0]), k[1])
	return a


static func lib_of(clips: Dictionary) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for k in clips:
		lib.add_animation(k, clips[k])
	return lib


static func V(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


# ------------------------------------------------------------------ góc nhìn thứ nhất

func _fp() -> AnimationLibrary:
	var R := "ToolHolder:rotation"
	var P := "ToolHolder:position"
	return lib_of({
		"anm_fp_idle": clip(2.0, true, [[R, [[0, V(0, 0, 0)], [1.0, V(0.03, 0.01, 0)], [2.0, V(0, 0, 0)]]], [P, [[0, V(0, 0, 0)], [1.0, V(0, -0.01, 0)], [2.0, V(0, 0, 0)]]]]),
		"anm_fp_equip": clip(0.25, false, [[P, [[0, V(0, -0.3, 0.05)], [0.25, V(0, 0, 0)]]], [R, [[0, V(0.6, 0, 0)], [0.25, V(0, 0, 0)]]]]),
		"anm_fp_cast_charge": clip(0.4, false, [[R, [[0, V(0, 0, 0)], [0.4, V(-0.6, 0, 0.1)]]], [P, [[0, V(0, 0, 0)], [0.4, V(0, 0.02, 0.06)]]]]),
		"anm_fp_cast_release": clip(0.45, false, [[R, [[0, V(-0.6, 0, 0.1)], [0.12, V(0.9, 0, 0)], [0.45, V(0, 0, 0)]]], [P, [[0, V(0, 0.02, 0.06)], [0.12, V(0, -0.02, -0.08)], [0.45, V(0, 0, 0)]]]]),
		"anm_fp_reel_loop": clip(0.4, true, [[R, [[0, V(0.25, 0, 0)], [0.1, V(0.3, 0, 0.04)], [0.2, V(0.25, 0, 0)], [0.3, V(0.2, 0, -0.04)], [0.4, V(0.25, 0, 0)]]]]),
		"anm_fp_yank": clip(0.35, false, [[R, [[0, V(0.25, 0, 0)], [0.08, V(-1.0, 0, 0)], [0.35, V(0, 0, 0)]]], [P, [[0, V(0, 0, 0)], [0.08, V(0, 0.06, 0.1)], [0.35, V(0, 0, 0)]]]]),
		"anm_fp_slap": clip(0.35, false, [[R, [[0, V(0, 0, 0)], [0.07, V(-1.1, 0.2, 0.3)], [0.17, V(0.7, -0.3, -0.2)], [0.35, V(0, 0, 0)]]]]),
		"anm_fp_throw": clip(0.4, false, [[R, [[0, V(0, 0, 0)], [0.1, V(-0.8, 0, 0)], [0.2, V(0.6, 0, 0)], [0.4, V(0, 0, 0)]]], [P, [[0, V(0, 0, 0)], [0.1, V(0, 0.05, 0.12)], [0.2, V(0, 0, -0.12)], [0.4, V(0, 0, 0)]]]]),
		"anm_fp_sweep": clip(0.45, false, [[R, [[0, V(0, 0, 0)], [0.1, V(0.2, 0.8, 0)], [0.28, V(0.3, -0.8, 0)], [0.45, V(0, 0, 0)]]]]),
		"anm_fp_pickup": clip(0.4, false, [[P, [[0, V(0, 0, 0)], [0.18, V(0, -0.25, -0.1)], [0.4, V(0, 0, 0)]]], [R, [[0, V(0, 0, 0)], [0.18, V(0.5, 0, 0)], [0.4, V(0, 0, 0)]]]]),
	})


# ------------------------------------------------------------------ NPC

func _npc() -> AnimationLibrary:
	var P := "Body:position"
	var R := "Body:rotation"
	var S := "Body:scale"
	return lib_of({
		"anm_npc_idle": clip(2.4, true, [[S, [[0, V(1, 1, 1)], [1.2, V(1.0, 1.02, 1.0)], [2.4, V(1, 1, 1)]]], [R, [[0, V(0, 0, 0)], [1.2, V(0, 0.06, 0)], [2.4, V(0, 0, 0)]]]]),
		"anm_npc_talk": clip(0.6, true, [[R, [[0, V(0, 0, 0)], [0.15, V(0.08, 0.04, 0)], [0.3, V(0, 0, 0)], [0.45, V(0.06, -0.04, 0)], [0.6, V(0, 0, 0)]]]]),
		"anm_npc_happy": clip(0.8, false, [[P, [[0, V(0, 0, 0)], [0.2, V(0, 0.3, 0)], [0.4, V(0, 0, 0)], [0.6, V(0, 0.2, 0)], [0.8, V(0, 0, 0)]]], [S, [[0, V(1, 1, 1)], [0.4, V(1.08, 0.92, 1.08)], [0.8, V(1, 1, 1)]]]]),
		"anm_npc_disgust": clip(0.8, false, [[R, [[0, V(0, 0, 0)], [0.2, V(-0.25, 0, 0)], [0.35, V(-0.25, 0.2, 0)], [0.5, V(-0.25, -0.2, 0)], [0.8, V(0, 0, 0)]]]]),
	})


# ------------------------------------------------------------------ boss (tham số hóa theo loài)

func _boss(key: String, weight: float, sideways: bool) -> AnimationLibrary:
	var P := "Body:position"
	var R := "Body:rotation"
	var S := "Body:scale"
	var w := weight
	var lean := V(0, 0, -0.3) if sideways else V(-0.3, 0, 0)
	var lunge := V(0, 0, 0.25) if sideways else V(0.2, 0, 0)
	var n := "anm_boss_%s_" % key
	return lib_of({
		n + "land": clip(0.8, false, [[P, [[0, V(0, 2.0 * w, 0)], [0.35, V(0, 0, 0)], [0.8, V(0, 0, 0)]]], [S, [[0, V(1, 1, 1)], [0.35, V(1.25, 0.75, 1.25)], [0.6, V(0.95, 1.05, 0.95)], [0.8, V(1, 1, 1)]]]]),
		n + "idle": clip(1.6 * w, true, [[S, [[0, V(1, 1, 1)], [0.8 * w, V(1.04, 0.97, 1.04)], [1.6 * w, V(1, 1, 1)]]]]),
		n + "telegraph_slam": clip(1.0, false, [[P, [[0, V(0, 0, 0)], [0.6, V(0, 0.6, 0)], [0.7, V(0.05, 0.62, 0)], [0.8, V(-0.05, 0.6, 0)], [1.0, V(0, 0.6, 0)]]]]),
		n + "slam": clip(0.4, false, [[P, [[0, V(0, 0.6, 0)], [0.12, V(0, -0.1, 0)], [0.4, V(0, 0, 0)]]], [S, [[0, V(1, 1, 1)], [0.12, V(1.3, 0.7, 1.3)], [0.4, V(1, 1, 1)]]]]),
		n + "telegraph_charge": clip(1.0, false, [[R, [[0, V(0, 0, 0)], [0.5, lean], [0.7, lean + V(0.03, 0.05, 0)], [0.85, lean - V(0.03, 0.05, 0)], [1.0, lean]]]]),
		n + "charge": clip(0.6, false, [[R, [[0, lean], [0.15, lunge], [0.6, V(0, 0, 0)]]]]),
		n + "stunned": clip(1.0, true, [[R, [[0, V(0, 0, 0.25)], [0.5, V(0, 0, -0.25)], [1.0, V(0, 0, 0.25)]]], [P, [[0, V(0, 0, 0)], [0.5, V(0, -0.08, 0)], [1.0, V(0, 0, 0)]]]]),
		n + "telegraph_spit": clip(0.8, false, [[R, [[0, V(0, 0, 0)], [0.6, V(-0.4, 0, 0)], [0.8, V(-0.42, 0, 0)]]], [S, [[0, V(1, 1, 1)], [0.8, V(1.08, 1.08, 1.08)]]]]),
		n + "spit": clip(0.4, false, [[R, [[0, V(-0.4, 0, 0)], [0.1, V(0.2, 0, 0)], [0.4, V(0, 0, 0)]]], [S, [[0, V(1.08, 1.08, 1.08)], [0.1, V(0.92, 0.92, 0.92)], [0.4, V(1, 1, 1)]]]]),
		n + "phase_change": clip(1.0, false, [[R, [[0, V(0, 0, 0)], [1.0, V(0, TAU, 0)]]], [P, [[0, V(0, 0, 0)], [0.5, V(0, 0.8 * w, 0)], [1.0, V(0, 0, 0)]]]]),
		n + "escape": clip(1.5, false, [[P, [[0, V(0, 0, 0)], [0.3, V(0, 0.3, 0)], [1.5, V(0, -2.5, 0)]]], [R, [[0, V(0, 0, 0)], [1.5, V(0.6, 0, 0)]]]]),
		n + "defeat": clip(1.2, false, [[R, [[0, V(0, 0, 0)], [0.8, V(0, 0, PI * 0.5)], [1.2, V(0, 0, PI * 0.5)]]], [P, [[0, V(0, 0, 0)], [0.8, V(0, -0.2, 0)], [1.2, V(0, -0.2, 0)]]]]),
	})


# ------------------------------------------------------------------ cò

func _egret() -> AnimationLibrary:
	var P := "Model:position"
	var R := "Model:rotation"
	return lib_of({
		"anm_egret_walk": clip(0.8, true, [[P, [[0, V(0, 0, 0)], [0.2, V(0, 0.03, 0)], [0.4, V(0, 0, 0)], [0.6, V(0, 0.03, 0)], [0.8, V(0, 0, 0)]]], [R, [[0, V(0.05, 0, 0)], [0.4, V(-0.05, 0, 0)], [0.8, V(0.05, 0, 0)]]]]),
		"anm_egret_fly": clip(0.5, true, [[P, [[0, V(0, 0, 0)], [0.25, V(0, 0.12, 0)], [0.5, V(0, 0, 0)]]], [R, [[0, V(0, 0, 0.12)], [0.25, V(-0.1, 0, -0.12)], [0.5, V(0, 0, 0.12)]]]]),
	})


# ------------------------------------------------------------------ đồng đội (người chơi khác)

func _player() -> AnimationLibrary:
	var P := "Avatar/Body:position"
	var R := "Avatar/Body:rotation"
	var ROD := "Rod:rotation"
	var rod0 := V(deg_to_rad(35), 0, 0)
	return lib_of({
		"anm_player_remote_idle": clip(2.0, true, [[P, [[0, V(0, 0, 0)], [1.0, V(0, 0.015, 0)], [2.0, V(0, 0, 0)]]], [ROD, [[0, rod0], [2.0, rod0]]]]),
		"anm_player_remote_walk": clip(0.5, true, [[P, [[0, V(0, 0, 0)], [0.125, V(0, 0.04, 0)], [0.25, V(0, 0, 0)], [0.375, V(0, 0.04, 0)], [0.5, V(0, 0, 0)]]], [R, [[0, V(0, 0, 0.04)], [0.25, V(0, 0, -0.04)], [0.5, V(0, 0, 0.04)]]]]),
		"anm_player_remote_run": clip(0.35, true, [[P, [[0, V(0, 0, 0)], [0.09, V(0, 0.07, 0)], [0.175, V(0, 0, 0)], [0.26, V(0, 0.07, 0)], [0.35, V(0, 0, 0)]]], [R, [[0, V(0.1, 0, 0.05)], [0.175, V(0.1, 0, -0.05)], [0.35, V(0.1, 0, 0.05)]]]]),
		"anm_player_remote_cast": clip(0.6, false, [[ROD, [[0, rod0], [0.25, V(deg_to_rad(-40), 0, 0)], [0.4, V(deg_to_rad(60), 0, 0)], [0.6, rod0]]]]),
		"anm_player_remote_reel": clip(0.4, true, [[ROD, [[0, V(deg_to_rad(25), 0, 0)], [0.2, V(deg_to_rad(32), 0, 0.05)], [0.4, V(deg_to_rad(25), 0, 0)]]]]),
		"anm_player_remote_use_tool": clip(0.35, false, [[ROD, [[0, rod0], [0.08, V(deg_to_rad(-60), 0, 0)], [0.2, V(deg_to_rad(70), 0, 0)], [0.35, rod0]]], [R, [[0, V(0, 0, 0)], [0.2, V(0.12, 0, 0)], [0.35, V(0, 0, 0)]]]]),
		"anm_player_remote_knocked_out": clip(0.6, false, [[R, [[0, V(0, 0, 0)], [0.4, V(0, 0, PI * 0.5)], [0.6, V(0, 0, PI * 0.5)]]], [P, [[0, V(0, 0, 0)], [0.4, V(0, 0.2, 0)], [0.6, V(0, 0.2, 0)]]]]),
		"anm_player_remote_revive": clip(0.6, false, [[R, [[0, V(0, 0, PI * 0.5)], [0.5, V(0, 0, 0)], [0.6, V(0, 0, 0)]]], [P, [[0, V(0, 0.2, 0)], [0.5, V(0, 0, 0)], [0.6, V(0, 0, 0)]]]]),
	})
