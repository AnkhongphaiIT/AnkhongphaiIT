extends Node
## Gọi API tài khoản/phòng qua HTTPS. Token chỉ giữ trong bộ nhớ phiên (07 §4):
## đóng trang phải đăng nhập lại; không dùng cookie bên thứ ba trong iframe itch.io.

signal session_expired

var base_url: String = "http://127.0.0.1:8787"
var access_token: String = ""
var refresh_token: String = ""
var account_id: String = ""
var display_name: String = ""
var username: String = ""


func is_logged_in() -> bool:
	return access_token != ""


func request(method: int, path: String, body: Variant = null, use_auth: bool = true, retry: bool = true) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if use_auth and access_token != "":
		headers.append("Authorization: Bearer " + access_token)
	var err := req.request(base_url + path, headers, method, "" if body == null else JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return {"ok": false, "status": 0, "data": {}, "error_code": "SERVER_BUSY"}
	var res: Array = await req.request_completed
	req.queue_free()
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if text != "" else {}
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "data": {}, "error_code": "OFFLINE"}
	var ecode: String = String(data.get("error_code", "")) if code != 200 else ""
	if code == 401 and use_auth and retry and refresh_token != "" and ecode == "AUTH_EXPIRED":
		if await refresh():
			return await request(method, path, body, use_auth, false)
	if code == 401 and use_auth:
		session_expired.emit()
	return {"ok": code == 200, "status": code, "data": data, "error_code": ecode}


func _take_tokens(d: Dictionary) -> void:
	access_token = String(d.get("access_token", access_token))
	refresh_token = String(d.get("refresh_token", refresh_token))
	account_id = String(d.get("account_id", account_id))
	display_name = String(d.get("display_name", display_name))


func register(user: String, display: String, password: String) -> Dictionary:
	var r := await request(HTTPClient.METHOD_POST, "/v1/auth/register", {"username": user, "display_name": display, "password": password}, false)
	if r["ok"]:
		username = user.strip_edges().to_lower()
		_take_tokens(r["data"])
	return r


func login(user: String, password: String) -> Dictionary:
	var r := await request(HTTPClient.METHOD_POST, "/v1/auth/login", {"username": user, "password": password}, false)
	if r["ok"]:
		username = user.strip_edges().to_lower()
		_take_tokens(r["data"])
	return r


func refresh() -> bool:
	var r := await request(HTTPClient.METHOD_POST, "/v1/auth/refresh", {"refresh_token": refresh_token}, false, false)
	if r["ok"]:
		_take_tokens(r["data"])
		return true
	access_token = ""
	refresh_token = ""
	return false


func logout() -> Dictionary:
	var r := await request(HTTPClient.METHOD_POST, "/v1/auth/logout")
	access_token = ""
	refresh_token = ""
	return r


func recover(user: String, code: String, new_password: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/auth/recover", {"username": user, "recovery_code": code, "new_password": new_password}, false)


func change_password(current: String, new_password: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/auth/password", {"current_password": current, "new_password": new_password})


func reauth(password: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/auth/reauth", {"password": password})


func delete_account(password: String) -> Dictionary:
	return await request(HTTPClient.METHOD_DELETE, "/v1/account", {"password": password})


func get_save() -> Dictionary:
	return await request(HTTPClient.METHOD_GET, "/v1/account/save")


func takeover() -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/account/takeover")


func list_rooms() -> Dictionary:
	return await request(HTTPClient.METHOD_GET, "/v1/rooms")


func create_room(island_id: String = "") -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/rooms", {"island_id": island_id} if island_id != "" else {})


func lookup_room(code: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/rooms/lookup", {"invite_code": code})


func join_room(room_id: String, code: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/rooms/%s/join" % room_id, {"invite_code": code})


func ticket(room_id: String) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, "/v1/rooms/%s/ticket" % room_id)
