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
