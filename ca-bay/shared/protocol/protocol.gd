class_name Protocol
extends RefCounted
## Envelope JSON theo 08 §3 và network_contract.json. Dùng chung client/server.

static var _crypto: Crypto


static func uuid4() -> String:
	if _crypto == null:
		_crypto = Crypto.new()
	var b := _crypto.generate_random_bytes(16)
	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


static func make_envelope(type: String, payload: Dictionary, connection_id: String, room_id: String, seq: int, request_id: String = "") -> Dictionary:
	return {
		"protocol_version": ContentDB.protocol_version(),
		"type": type,
		"request_id": request_id if request_id != "" else uuid4(),
		"connection_id": connection_id,
		"room_id": room_id,
		"seq": seq,
		"payload": payload,
	}


## Giải mã + kiểm envelope + kiểm payload theo schema của message.
## Trả {"ok": bool, "error": code, "detail": String, "env": Dictionary}
static func parse_and_validate(text: String, expected_direction: String) -> Dictionary:
	var max_bytes: int = int(ContentDB.limit("max_client_payload_bytes", 8192)) if expected_direction == "client_to_server" else int(ContentDB.limit("max_server_payload_bytes", 65536))
	if text.to_utf8_buffer().size() > max_bytes:
		return {"ok": false, "error": "INVALID_PAYLOAD", "detail": "quá kích thước"}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "error": "INVALID_PAYLOAD", "detail": "JSON lỗi"}
	var env: Variant = json.data
	if typeof(env) != TYPE_DICTIONARY:
		return {"ok": false, "error": "INVALID_PAYLOAD", "detail": "không phải object"}
	var err := SchemaLite.validate(env, ContentDB.network.get("envelope", {}), "$")
	if err != "":
		if env.get("protocol_version", "") != ContentDB.protocol_version():
			return {"ok": false, "error": "PROTOCOL_MISMATCH", "detail": err}
		return {"ok": false, "error": "INVALID_PAYLOAD", "detail": err}
	var spec: Dictionary = ContentDB.messages.get(env["type"], {})
	if spec.is_empty() or spec.get("direction", "") != expected_direction:
		return {"ok": false, "error": "INVALID_PAYLOAD", "detail": "loại message không hợp lệ: %s" % env["type"]}
	err = SchemaLite.validate(env["payload"], spec.get("payload_schema", {}), "$.payload")
	if err != "":
		return {"ok": false, "error": "INVALID_PAYLOAD", "detail": err}
	env["seq"] = int(env["seq"])
	return {"ok": true, "env": env}


static func encode(env: Dictionary) -> String:
	return JSON.stringify(env)
