extends RefCounted
## Giao thức: envelope hợp lệ/không hợp lệ và chuẩn hóa số nguyên trước khi chuyển tiếp sang backend.


func _env(type: String, payload: Dictionary) -> String:
	return JSON.stringify(Protocol.make_envelope(type, payload, Protocol.uuid4(), Protocol.uuid4(), 3))


func test_integer_fields_become_int(t) -> void:
	var text := _env("shop.buy", {"op_id": Protocol.uuid4(), "expected_save_version": 7, "shop_id": "shop_co_ba", "entry_id": "entry_worm_pack", "quantity": 1})
	var res := Protocol.parse_and_validate(text, "client_to_server")
	t.ok(res["ok"], "shop.buy hợp lệ")
	var pl: Dictionary = res["env"]["payload"]
	t.eq(typeof(pl["quantity"]), TYPE_INT, "quantity phải là int sau khi đọc")
	t.eq(typeof(pl["expected_save_version"]), TYPE_INT, "expected_save_version phải là int")
	t.ok(JSON.stringify(pl).contains("\"quantity\":1,") or JSON.stringify(pl).ends_with("\"quantity\":1}"), "chuyển tiếp ra JSON là 1, không phải 1.0: " + JSON.stringify(pl))


func test_non_integral_rejected(t) -> void:
	var text := _env("shop.buy", {"op_id": Protocol.uuid4(), "expected_save_version": 7, "shop_id": "shop_co_ba", "entry_id": "entry_worm_pack", "quantity": 1.5})
	t.ok(not Protocol.parse_and_validate(text, "client_to_server")["ok"], "quantity 1.5 bị từ chối")


func test_extra_field_and_wrong_direction_rejected(t) -> void:
	var extra := _env("inventory.sell", {"op_id": Protocol.uuid4(), "expected_save_version": 1, "item_uids": [], "shop_id": "shop_co_ba", "money": 5})
	t.ok(not Protocol.parse_and_validate(extra, "client_to_server")["ok"], "trường tiền từ client bị từ chối")
	var wrong := _env("state.snapshot", {"server_tick": 1})
	t.ok(not Protocol.parse_and_validate(wrong, "client_to_server")["ok"], "client không được gửi message của server")


func test_server_messages_with_union_types(t) -> void:
	# command.result.receipt có "type": ["object","null"]; save_version là integer → phải đọc được, không lỗi.
	var env := Protocol.make_envelope("command.result", {"request_id": Protocol.uuid4(), "op_id": null, "status": "committed",
		"error_code": null, "save_version": 12, "receipt": {"view": {"save_version": 12}}}, Protocol.uuid4(), Protocol.uuid4(), 0)
	var res := Protocol.parse_and_validate(JSON.stringify(env), "server_to_client")
	t.ok(res["ok"], "command.result hợp lệ: " + str(res.get("detail", "")))
	if res["ok"]:
		t.eq(typeof(res["env"]["payload"]["save_version"]), TYPE_INT, "save_version là int")
	var env2 := Protocol.make_envelope("command.result", {"request_id": Protocol.uuid4(), "op_id": null, "status": "rejected",
		"error_code": "COOLDOWN", "save_version": 3, "receipt": null}, Protocol.uuid4(), Protocol.uuid4(), 0)
	t.ok(Protocol.parse_and_validate(JSON.stringify(env2), "server_to_client")["ok"], "receipt null hợp lệ")
