class_name Movement
extends RefCounted
## Tích phân di chuyển người chơi (server authoritative; client dùng cùng hàm để dự đoán).
## Không nhận vị trí/vận tốc từ client: chỉ trục di chuyển [-1,1], góc nhìn và nhảy.

const GRAVITY := 9.8
const RADIUS := 0.35


## state: {"pos": Vector3, "vel_y": float, "on_ground": bool}
## Trả về state mới. yaw: 0 nhìn -Z (quy ước Godot), move_z âm = tiến.
static func step(island_id: String, state: Dictionary, move_x: float, move_z: float, yaw: float, jump: bool, dt: float, speed_mult: float = 1.0) -> Dictionary:
	var bal: Dictionary = ContentDB.balance.get("player", {})
	var speed: float = float(bal.get("walk_speed_mps", 4.5)) * speed_mult
	var jump_v: float = float(bal.get("jump_velocity_mps", 4.5))
	var pos: Vector3 = state["pos"]
	var vel_y: float = state["vel_y"]
	var on_ground: bool = state["on_ground"]
	var input := Vector2(clampf(move_x, -1, 1), clampf(move_z, -1, 1))
	if input.length() > 1.0:
		input = input.normalized()
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var dir := right * input.x + fwd * (-input.y)
	var delta := dir * speed * dt
	var nx := pos.x + delta.x
	var nz := pos.z + delta.y
	# Không đi xuống nước sâu: trượt theo từng trục
	if not IslandLayout.walkable(island_id, nx, nz):
		if IslandLayout.walkable(island_id, nx, pos.z):
			nz = pos.z
		elif IslandLayout.walkable(island_id, pos.x, nz):
			nx = pos.x
		else:
			nx = pos.x
			nz = pos.z
	var ground := IslandLayout.ground_height(island_id, nx, nz)
	if on_ground and jump:
		vel_y = jump_v
		on_ground = false
	var ny := pos.y + vel_y * dt
	vel_y -= GRAVITY * dt
	if ny <= ground:
		ny = ground
		vel_y = 0.0
		on_ground = true
	elif on_ground and ny - ground < 0.35:
		# bám dốc khi đi xuống
		ny = ground
		vel_y = 0.0
	else:
		on_ground = false
	return {"pos": Vector3(nx, ny, nz), "vel_y": vel_y, "on_ground": on_ground}


static func eye(pos: Vector3) -> Vector3:
	return pos + Vector3(0, float(ContentDB.balance.get("player", {}).get("eye_height_m", 1.6)), 0)


static func look_dir(yaw: float, pitch: float) -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()
