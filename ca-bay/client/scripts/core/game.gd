extends Node
## Gốc ứng dụng. Chọn vai trò: room server headless (feature `dedicated_server` hoặc tham số
## `--server`) hay client trình duyệt/desktop.

var is_server: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	is_server = OS.has_feature("dedicated_server") or "--server" in args
	print("CABAY_BOOT role=%s godot=%s content_hash=%s errors=%d" % [
		"server" if is_server else "client", Engine.get_version_info()["string"],
		ContentDB.content_hash, ContentDB.load_errors.size()])
	if is_server:
		var srv: Node = load("res://server/gameplay/room_server.gd").new()
		srv.name = "ServerApp"
		add_child(srv)
	else:
		var app: Node = load("res://client/scripts/ui/client_app.gd").new()
		app.name = "ClientApp"
		add_child(app)
