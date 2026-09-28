class_name GuestStore
extends RefCounted
## Tài khoản khách "Chơi ngay" (P-041): tên đăng nhập + khóa do server cấp, giữ trên máy này (user://guest.json — trên web là
## bộ nhớ của trình duyệt) để lần sau tự vào lại. Tiến trình vẫn ở server. Không bao giờ lưu mật khẩu người chơi tự đặt;
## khóa khách chỉ mở được đúng tài khoản khách đó và hết hiệu lực khi người chơi đặt mật khẩu.

const PATH := "user://guest.json"

# khách "Người chơi khác" của tab này (chơi chung nhiều tab trên một máy): chỉ trong bộ nhớ, không ghi đè khách đã lưu
static var _session: Dictionary = {}


static func remember_session(username: String, secret: String) -> void:
	_session = {"username": username, "secret": secret}


static func load_guest() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("username")) != TYPE_STRING or typeof(d.get("secret")) != TYPE_STRING:
		return {}
	return d


static func save_guest(username: String, secret: String, display_name: String) -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"username": username, "secret": secret, "display_name": display_name}))
	f.close()
	return true


static func is_current(api_username: String) -> bool:
	return secret_for(api_username) != ""


static func secret_for(api_username: String) -> String:
	if String(_session.get("username", "")) == api_username:
		return String(_session["secret"])
	var g := load_guest()
	return String(g["secret"]) if not g.is_empty() and String(g["username"]) == api_username else ""


## Quên đúng tài khoản khách này (khách của tab và/hoặc khách đã lưu của máy) — không đụng tài khoản khách của người khác.
static func forget(username: String) -> void:
	if String(_session.get("username", "")) == username:
		_session = {}
	var g := load_guest()
	if not g.is_empty() and String(g["username"]) == username and FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
