extends RefCounted
## Khung test mô phỏng: RoomSim thật + server giả (ghi lại gói gửi, backend commit trả kết quả dựng sẵn).
## Chỉ dùng cho unit test logic; không thay test mạng/backend thật.

const RoomSim := preload("res://server/gameplay/room_sim.gd")


class FakeBackend:
	var commits: Array = []
	var reject_types: Dictionary = {}
	func commit(account_id: String, lease_epoch: int, room_id: String, op_id: String, op_type: String, payload: Dictionary, esv: Variant) -> Dictionary:
		commits.append({"account_id": account_id, "op_type": op_type, "payload": payload})
		if reject_types.has(op_type):
			return {"status": "rejected", "op_id": op_id, "error_code": reject_types[op_type], "save_version": null, "receipt": null}
		return {"status": "committed", "op_id": op_id, "error_code": null, "save_version": 2, "receipt": {}, "events": []}
	func call_api(method: int, path: String, body: Variant = null, timeout_s: float = 8.0) -> Dictionary:
		return {"ok": true, "status": 200, "data": {}, "error_code": ""}


class FakeServer:
	var sent: Array = []
	var backend := FakeBackend.new()
	var releases: Array = []
	func send(peer_id: int, type: String, payload: Dictionary, request_id: String = "") -> void:
		sent.append({"peer": peer_id, "type": type, "payload": payload})
	func reply_result(peer_id: int, request_id: String, op_id: Variant, status: String, error_code: Variant, save_version: int, receipt: Variant) -> void:
		sent.append({"peer": peer_id, "type": "command.result", "payload": {"status": status, "error_code": error_code, "receipt": receipt}})
	func queue_release(account_id: String, lease_epoch: int, room_id: String, reason: String) -> void:
		releases.append(account_id)
	func events(name: String) -> Array:
		return sent.filter(func(m): return m["type"] == "domain.event" and m["payload"]["name"] == name)


static func make_save(aid: String) -> Dictionary:
	var s: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/samples/account_save_example.json"))
	s["account_id"] = aid
	s["inventory"]["bag"] = []
	s["inventory"]["tools_owned"] = ["tool_hand", "tool_slipper", "tool_broom"]
	s["inventory"]["tool_ammo"] = {}
	return s


static func make_room(island := "isl_01_cu_lao") -> Array:
	var srv := FakeServer.new()
	var room: RefCounted = RoomSim.new(srv, Protocol.uuid4(), island, "")
	return [room, srv]


static func add_player(room: RefCounted, peer: int, name := "P") -> Dictionary:
	var aid := Protocol.uuid4()
	room.attach_player(peer, {"account_id": aid, "display_name": name, "connection_id": Protocol.uuid4(), "lease_epoch": 1, "save": make_save(aid)})
	return room.players[aid]


static func run(room: RefCounted, seconds: float) -> void:
	for i in int(seconds / room.dt):
		room.tick(room.dt)
