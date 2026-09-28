class_name Endpoints
extends RefCounted
## Địa chỉ backend/room server cho client. Thứ tự: tham số URL trang web (?api=&ws=, chỉ bản thử local)
## → file res://client/config/endpoints.json (ghi lúc build) → mặc định localhost. Không có secret.


static func load_endpoints() -> Dictionary:
	var cfg := {"api_base": "http://127.0.0.1:8787", "ws_url": "ws://127.0.0.1:8910"}
	var allow_autotest := OS.is_debug_build()
	var allow_override := OS.is_debug_build()
	var f := FileAccess.open("res://client/config/endpoints.json", FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			for k in ["api_base", "ws_url"]:
				if typeof(d.get(k)) == TYPE_STRING and d[k] != "":
					cfg[k] = d[k]
			# chỉ file ghi lúc build (không phải tham số URL) mới bật được chế độ kiểm thử trong bản xuất
			allow_autotest = allow_autotest or d.get("allow_autotest", false) == true
			allow_override = allow_override or d.get("allow_endpoint_override", false) == true
	if OS.has_feature("web"):
		var origin: Variant = JavaScriptBridge.eval("window.location.origin", true)
		if typeof(origin) == TYPE_STRING:
			resolve_origin(cfg, String(origin))
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		if typeof(q) == TYPE_STRING:
			apply_query(cfg, String(q), allow_override)
	# bản tự host mở ngoài trình duyệt/ngoài http(s): về mặc định localhost
	if String(cfg["api_base"]).begins_with("@origin"):
		cfg["api_base"] = "http://127.0.0.1:8787"
	if String(cfg["ws_url"]).begins_with("@origin"):
		cfg["ws_url"] = "ws://127.0.0.1:8910"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--api="):
			cfg["api_base"] = a.substr(6)
		elif a.begins_with("--ws="):
			cfg["ws_url"] = a.substr(5)
		elif a == "--autotest":
			cfg["autotest"] = true
	# Bản phát hành (export --release) không có phím tự quay về cá/boss (tránh thành "ngắm tự động").
	autotest = bool(cfg.get("autotest", false)) and allow_autotest
	render_scale_override = float(cfg.get("render_scale", 0.0))
	return cfg


## Bản tự host (P-035, máy chủ phục vụ luôn trang game): "@origin" = đúng địa chỉ trang đang mở; kết nối phòng chơi
## đi qua "/ws" của cùng cổng (https → wss). Một đường hầm = một link chơi được, không phải xuất lại bản web.
static func resolve_origin(cfg: Dictionary, origin: String) -> void:
	var secure := origin.begins_with("https://")
	if not (secure or origin.begins_with("http://")):
		return
	if String(cfg.get("api_base", "")) == "@origin":
		cfg["api_base"] = origin
	var ws := String(cfg.get("ws_url", ""))
	if ws.begins_with("@origin"):
		cfg["ws_url"] = ("wss://" + origin.substr(8) if secure else "ws://" + origin.substr(7)) + ws.substr(7)


## Tham số trang web: ?api=&ws= (đổi máy chủ), ?autotest=1, ?scale=. Đổi máy chủ chỉ khi bản build cho phép
## (bản thử local, P-034): bản công khai khóa endpoint lúc build, để một đường link lạ kiểu
## `…/index.html?api=https://máy-khác` không thể khiến trang game thật gửi mật khẩu người chơi sang máy khác.
static func apply_query(cfg: Dictionary, query: String, allow_override: bool) -> void:
	if query.length() <= 1:
		return
	for part in query.substr(1).split("&"):
		var kv := part.split("=")
		if kv.size() != 2:
			continue
		var v := kv[1].uri_decode()
		if kv[0] == "api" and allow_override and (v.begins_with("https://") or v.begins_with("http://127.0.0.1") or v.begins_with("http://localhost")):
			cfg["api_base"] = v
		elif kv[0] == "ws" and allow_override and (v.begins_with("wss://") or v.begins_with("ws://127.0.0.1") or v.begins_with("ws://localhost")):
			cfg["ws_url"] = v
		elif kv[0] == "autotest" and v == "1":
			cfg["autotest"] = true
		elif kv[0] == "scale" and v.is_valid_float():
			cfg["render_scale"] = clampf(v.to_float(), 0.25, 1.0)


## ?scale=0.25..1 ghi đè độ phân giải 3D (chụp ảnh quảng bá ở chế độ autotest; máy yếu).
static var render_scale_override := 0.0


## Chế độ kiểm thử tự động (?autotest=1): không khóa chuột (pointer lock trong Chromium headless
## sinh chuyển động giả), xoay nhìn bằng I/J/K/L. Chỉ đổi cách nhập ở client; server vẫn quyết định mọi thứ.
static var autotest := false
