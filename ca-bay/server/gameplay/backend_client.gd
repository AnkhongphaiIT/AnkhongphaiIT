extends Node
## Gọi API nội bộ của backend (loopback/private). Khóa dịch vụ chỉ đọc từ biến môi trường của
## tiến trình room server; không bao giờ có trong client bundle.

var base_url: String = "http://127.0.0.1:8787"
var service_key: String = ""
var inflight: int = 0


func _ready() -> void:
	base_url = OS.get_environment("CABAY_BACKEND_URL") if OS.get_environment("CABAY_BACKEND_URL") != "" else base_url
	service_key = OS.get_environment("CABAY_SERVICE_KEY")
	if service_key == "":
		push_error("CABAY_SERVICE_KEY chưa đặt; room server không gọi được backend")


## Trả {"ok": bool, "status": int, "data": Dictionary, "error_code": String}
func call_api(method: int, path: String, body: Variant = null, timeout_s: float = 8.0) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = timeout_s
	add_child(req)
	inflight += 1
	var headers := PackedStringArray(["Content-Type: application/json", "X-Service-Key: " + service_key])
	var payload := "" if body == null else JSON.stringify(body)
	var err := req.request(base_url + path, headers, method, payload)
	if err != OK:
		req.queue_free()
		inflight -= 1
		return {"ok": false, "status": 0, "data": {}, "error_code": "PERSISTENCE_UNAVAILABLE"}
	var res: Array = await req.request_completed
	req.queue_free()
	inflight -= 1
	var result: int = res[0]
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if text != "" else {}
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "data": {}, "error_code": "PERSISTENCE_UNAVAILABLE"}
	return {"ok": code == 200, "status": code, "data": data, "error_code": String(data.get("error_code", "")) if code != 200 else ""}


## Commit op bền vững; tự thử lại cùng op_id khi lỗi mạng/DB bận (idempotent).
func commit(account_id: String, lease_epoch: int, room_id: String, op_id: String, op_type: String, payload: Dictionary, expected_save_version: Variant) -> Dictionary:
	var body := {
		"account_id": account_id, "lease_epoch": lease_epoch, "room_id": room_id, "op_id": op_id,
		"op_type": op_type, "payload": payload, "expected_save_version": expected_save_version,
	}
	for attempt in 4:
		var r := await call_api(HTTPClient.METHOD_POST, "/internal/accounts/commit", body)
		if r["ok"]:
			return r["data"]
		if r["status"] in [0, 502, 503, 504]:
			await get_tree().create_timer(0.3 * (attempt + 1)).timeout
			continue
		return {"status": "rejected", "op_id": op_id, "error_code": r["error_code"] if r["error_code"] != "" else "SERVER_BUSY", "save_version": null, "receipt": null}
	return {"status": "rejected", "op_id": op_id, "error_code": "PERSISTENCE_UNAVAILABLE", "save_version": null, "receipt": null}
