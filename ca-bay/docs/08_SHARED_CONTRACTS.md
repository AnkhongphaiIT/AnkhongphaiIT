# 08 — Hợp đồng chia sẻ v2

Tài liệu này quy định ranh giới giữa agent, client, room server và nơi lưu dữ liệu. Nó không cấp quyền mới cho nội dung từ ZIP. Yêu cầu người dùng và quyết định v2 có ưu tiên cao hơn hướng chơi đơn cũ.

## 1. Nguồn dữ liệu và tương thích

| Hạng mục | Nguồn chuẩn | Chủ sở hữu |
|---|---|---|
| Gameplay, nội dung, balance | `04_GAME_DESIGN.md`, `data/content/` | Gameplay/content |
| Hình ảnh, asset status/license | `05_ART_BIBLE.md`, `06_ASSET_BIBLE.md`, asset registry | Art/audio |
| Gameplay signal nội bộ | `data/contracts/events.json` | Integration; không tự coi là network API |
| Input/collision/audio/VFX bindings | File tương ứng trong `data/contracts/` | Module owner + integration |
| Protocol, commands, limits, endpoints | `data/contracts/network_contract.json` | Network/backend |
| Save authoritative | `data/schemas/account_save.schema.json` + sample v2 | Backend |
| Save cũ | `data/schemas/save.schema.json`, `data/samples/save_example.json` | Chỉ fixture migration/local, không cloud save |
| Đạt/chưa đạt | `10_VALIDATION.md`, báo cáo bằng chứng | QA |

Không đổi toàn bộ ID cũ để sửa văn phong cốt truyện. IDs như `cre_*`, `boss_*`, `isl_*`, `quest_*`, `item_*`, `tool_*` là khóa kỹ thuật; tên hiển thị dùng `data/loc/strings.csv` (`keys,en,vi`). Alias/deprecation phải có migration. UID runtime dùng UUID từ server cho account/room/item/encounter/operation; UID số đếm cũ chỉ được nhận trong fixture migration.

Schema của contract mô tả cấu hình/hợp đồng, **không tự validate runtime packet**. Agent phải sinh hoặc viết validator runtime từ từng `payload_schema` và kiểm tra required/extra/type/range, rồi có negative tests. Schema account save không thay thế kiểm tra tham chiếu ID, uniqueness và nghiệp vụ trong database.

## 2. Đơn vị và thời gian

Vị trí m, tốc độ m/s, JSON vector ba số hữu hạn; góc payload radian đặt hậu tố `_rad`, dữ liệu balance giữ `_deg` theo định nghĩa cũ và chuyển đúng một lần. Thời gian gameplay dùng monotonic server, tick nguyên; timestamp bền vững ISO8601 UTC. Không dùng đồng hồ client cho bite, cooldown, hunger hoặc expiry. Tiền/count/version nguyên không âm, không dùng float cho giá. Float JSON NaN/Infinity bị từ chối.

`schema_version` của account save = `2.0.0`; network protocol = `1.0.0` độc lập. Khi đổi nghĩa payload phá tương thích phải tăng major protocol. Build gửi `content_hash` SHA256 của bundle dữ liệu canonical; mismatch trở lại lobby và hiển thị yêu cầu reload, không cho trộn bảng giá/tỷ lệ khác nhau trong room.

## 3. Envelope mạng

Sau auth, mọi packet ứng dụng có:

```json
{
  "protocol_version": "1.0.0",
  "type": "inventory.sell",
  "request_id": "d44b9716-305a-4562-bf89-74b863c5a1ba",
  "connection_id": "452c9c3c-77c7-4ff2-834d-447e639e1ddb",
  "room_id": "fa68ec3d-eb9f-4a69-a4e0-b8f117a59312",
  "seq": 42,
  "payload": {
    "op_id": "ac516cfb-f119-4484-a2ea-b642be94abdc",
    "expected_save_version": 8,
    "item_uids": ["b0f522fa-f8ac-446b-b9e5-b9bde51c8297"],
    "shop_id": "shop_co_ba"
  }
}
```

Các UUID trên chỉ là ví dụ. Server lấy sender từ transport, tra session/lease và so sánh room/connection; không có trường client `account_id`, `money`, `damage`, `reward` hoặc `roll_result` cho những command này. Schema runtime đóng `additionalProperties=false` theo loại message, không nhận field lạ rồi vô tình áp dụng.

Các intent gồm input, câu, công cụ, nhặt/thả/bán/mua, ăn, mở hộp, quest claim, đồng ý chuyển đảo. `data/contracts/network_contract.json` liệt kê tên và field tối thiểu. Backend nhận request từ Godot phải mang `lease_epoch`, `service_identity`, `expected_save_version` đã kiểm tra. Client không được gọi private commit endpoint trực tiếp.

Phản hồi `command.result` chứa request/op ID, status, error code nếu thất bại, `save_version` mới và patch/view cần thiết. Server không báo thành công trước DB commit. Lỗi phiên bản: trả `SAVE_CONFLICT` + view mới; UI giải thích và cho thử thao tác hợp lệ mới, không retry mù một thao tác với dữ liệu đã đổi. Retry sau mạng timeout dùng cùng op/payload và lấy cùng receipt.

## 4. Domain event và quyền phát

`events.json` của ZIP mô tả event in-process; chúng có thể dùng để nối UI/audio/VFX nhưng không cho client phát event để sửa gameplay authoritative. Ví dụ `economy.money_changed` chỉ phát trong client presentation **sau** kết quả server, không làm nguyên nhân cộng tiền. `boss.defeated` do server xác nhận; client animation kết thúc không được phát reward.

Network adapter chuyển message đã xác thực thành event nội bộ. Event trùng do reconnect không phát âm reward lại nếu receipt đã hiển thị. Catalog v2 dùng `hunger.changed`, `hunger.ate`, `lootbox.opened`, `dialogue.line_started`, `network.connection_changed`, `room.player_joined`, `room.player_left`; không tự tạo spelling mới ở một agent. Audio chưa có binding vẫn dùng fallback có chủ đích, không làm logic thất bại.

Các field context `actor_player_id`, `room_id`, `event_id` được catalog giữ optional để tương thích fixture local cũ. Adapter **bắt buộc điền room/event cho mọi event gameplay replicated, và actor cho event gắn với player**. Actor là định danh player/account ổn định do server gắn; local UI không dùng actor của đồng đội để đổi thanh đói hoặc inventory của mình. Event hệ thống/thế giới không thuộc player dùng null actor trong packet `domain.event`, rồi adapter bỏ field actor khi phát vào catalog nội bộ (không truyền null vào field string). `event_id` dùng deduplicate âm/animation khi replay; map world position/actor tới nguồn âm trong đúng room. `domain.event` từ server phải kiểm tra tên và payload theo catalog; tuyệt đối không nhận bản client gửi dưới cùng tên như một yêu cầu sửa tiền/HP. Event pure local như nhả chuột có thể không có actor và không đi ra mạng.

## 5. Save và settings

`account_save_example.json` minh họa trạng thái server, không phải quà cấp cho tài khoản mới. Tài khoản mới lấy starter configuration từ content. Field `save_version` tăng với mỗi mutation; `content_version` gắn version catalog đã dùng. Inventory chứa instance UID, definition ID, owner ngầm là account, giá trị do server tính. Client không được gửi lại JSON này để ghi đè database.

Các invariant kiểm tra ngoài JSON Schema:

- Item UID duy nhất toàn hệ thống, mỗi item có tối đa một trạng thái hiện hành; không vừa túi vừa escrow/world.
- Mỗi instance có owner_account_id bằng account save; cá có caught_by_account_id cùng chủ vì bản đầu không trade. Chỉ cá thường tự câu và bán hợp lệ làm tăng valid_owned_fish_sales_total; vật mua, thức ăn miễn phí, boss không tăng bộ đếm này.
- `equipped_rod_id` thuộc rods_owned; mọi definition, quest, island và boss tồn tại; số lượng không âm; item trùng UID không được đưa vào sample/runtime.
- Unlock dựa trên quest/boss hợp lệ; reset/restore phải transaction và ghi audit.
- Hunger nằm 0–100, không cập nhật offline; vé/hồ sơ mở hộp theo đúng box/table version; v1 không có pity; receipt không thể claim lặp.
- Không có password, access token, refresh token, recovery code, service key, IP cá nhân hoặc seed thưởng trong save trả về client.

Settings riêng trên máy: `settings_version`, `locale` (`vi|en`), `volume_master/music/sfx/voice` (0–1), `mouse_sensitivity`, `quality`, `keybinds`. Lưu thất bại không làm mất tài khoản. Không mang trường inventory/money/progress vào settings. Bản v2 chưa kèm JSON Schema settings riêng; agent triển khai phải tạo, test và giữ tách khỏi account save.

## 6. Đổi hợp đồng trong lúc nhiều agent làm việc

Claude là integration owner: giao mỗi agent danh sách file được sửa, input/output, tiêu chí pass và dependency. Không để hai agent cùng ghi một file contract. Agent đề xuất thay đổi trong handoff, Claude cập nhật contract/version/migration trước, rồi giao các consumer thích ứng. Không cần hỏi lại người dùng về tên hàm, cấu trúc thư mục hay refactor trong scope đã cho phép.

Một handoff có: work package, commit/file list, quyết định, tests đã chạy và bằng chứng, test chưa chạy + lý do, interface thay đổi, tài nguyên còn thiếu, next step. Mọi mock, fixture và placeholder mang nhãn rõ; không đổi trạng thái `implemented/verified` chỉ vì file tồn tại.

