class_name VfxPlayer
extends Node3D
## Gốc của mọi cảnh VFX (assets/vfx/*.tscn): bật các CPUParticles3D con, tự hủy sau `life` giây
## (life <= 0: lặp đến khi bị gỡ). `text` đặt cho Label3D con (vfx_trick_text, chỉ báo).

@export var life := 1.0
@export var text := ""
@export var spin := 0.0          # rad/s quanh trục Y (sao xỉu)
@export var grow := 0.0          # tốc độ phóng to (vòng gợn nước, vòng cảnh báo)
@export var rise := 0.0          # m/s đi lên (chữ trick)

static var _cache: Dictionary = {}


## Sinh VFX theo asset ID tại vị trí thế giới; trả null nếu chưa có file (không làm hỏng gameplay).
static func spawn(vfx_id: String, parent: Node, pos: Vector3, txt := "", life_override := -1.0) -> Node3D:
	if parent == null or not is_instance_valid(parent):
		return null
	var path := "res://assets/vfx/%s.tscn" % vfx_id
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var ps: PackedScene = _cache[path]
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	if txt != "" and "text" in n:
		n.text = txt
	if life_override >= 0.0 and "life" in n:
		n.life = life_override
	parent.add_child(n)
	n.global_position = pos
	return n


func _ready() -> void:
	for c in get_children():
		if c is CPUParticles3D:
			(c as CPUParticles3D).restart()
			(c as CPUParticles3D).emitting = true
		elif c is Label3D and text != "":
			(c as Label3D).text = text
	if life > 0.0:
		var tw := create_tween()
		tw.tween_interval(life)
		tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if spin != 0.0:
		rotation.y += spin * delta
	if grow != 0.0:
		scale += Vector3(grow, 0.0, grow) * delta
	if rise != 0.0:
		position.y += rise * delta
		for c in get_children():
			if c is Label3D:
				(c as Label3D).modulate.a = maxf(0.0, (c as Label3D).modulate.a - delta / maxf(0.1, life))
