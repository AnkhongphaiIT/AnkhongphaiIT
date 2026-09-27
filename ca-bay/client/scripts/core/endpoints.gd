class_name Endpoints
extends RefCounted
## Địa chỉ backend/room server cho client. Thứ tự: tham số URL trang web (?api=&ws=) → file
## res://client/config/endpoints.json (ghi lúc build) → mặc định localhost. Không có secret.


static func load_endpoints() -> Dictionary:
	var cfg := {"api_base": "http://127.0.0.1:8787", "ws_url": "ws://127.0.0.1:8910"}
	var f := FileAccess.open("res://client/config/endpoints.json", FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			for k in ["api_base", "ws_url"]:
				if typeof(d.get(k)) == TYPE_STRING and d[k] != "":
					cfg[k] = d[k]
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		if typeof(q) == TYPE_STRING and q.length() > 1:
			for part in String(q).substr(1).split("&"):
				var kv := part.split("=")
				if kv.size() == 2:
					var v := kv[1].uri_decode()
					if kv[0] == "api" and (v.begins_with("https://") or v.begins_with("http://127.0.0.1") or v.begins_with("http://localhost")):
						cfg["api_base"] = v
					elif kv[0] == "ws" and (v.begins_with("wss://") or v.begins_with("ws://127.0.0.1") or v.begins_with("ws://localhost")):
						cfg["ws_url"] = v
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--api="):
			cfg["api_base"] = a.substr(6)
		elif a.begins_with("--ws="):
			cfg["ws_url"] = a.substr(5)
	return cfg
