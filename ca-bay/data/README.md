# Dữ liệu thiết kế CÁ BAY v2

Gói tài liệu phiên bản 2.0.0. `schema_version` của từng bảng mô tả cấu trúc bảng đó, độc lập với phiên bản gói; bảng không đổi cấu trúc có thể vẫn dùng 1.0.0. Không coi việc có JSON là hệ thống đã được lập trình.

## Nội dung

- `content/`: sinh vật, đảo, spawn table, mồi/cần/công cụ, nhiệm vụ, shop/NPC, cân bằng, đói và hộp thưởng. Bản đầy đủ có 15 loài thường và 3 boss; đây là cách đếm được ghi nhận trong thiết kế v2.
- `contracts/asset_registry.json`: danh mục asset dự kiến; `planned` không phải file đã giao. Các ID tiếng Anh cũ có thể giữ để tương thích, UI phải dùng tên mới.
- `contracts/events.json`: sự kiện nội bộ UI/audio/VFX; không là RPC có quyền sửa tiền/đồ. Context v2 gồm `actor_player_id`, `room_id`, `event_id`; adapter phải gắn cho event replicated. Những trường này optional ở schema để đọc fixture cũ, không phải tùy chọn bỏ qua khi triển khai co-op.
- `contracts/network_contract.json`: phiên bản/giao thức, giới hạn, endpoint và payload cần thực thi. Schema mô tả hợp đồng không thay runtime validation.
- `contracts/audio_event_map.json`, `vfx_event_map.json`: binding từ event đã xác nhận sang phản hồi. Không dùng audio trigger làm nguồn gameplay.
- `schemas/`: JSON Schema Draft 2020-12; validator đăng ký local reference, không tải schema từ mạng.
- `loc/strings.csv`: cột `keys,en,vi`; mọi khóa được data tham chiếu phải có cả hai ngôn ngữ. Placeholder `{value}` phải khớp.
- `samples/account_save_example.json`: ví dụ save server v2, không chứa credentials.
- `samples/save_example.json`: fixture v1 phục vụ migration/local legacy; không dùng làm tài khoản mới, không cho client upload để cấp tiền. Schema cũ chỉ nhằm đọc fixture này.

## Trạng thái nội dung và asset

`slice` = dùng sớm trong mốc thử; `mvp` = thuộc bản đầy đủ; `planned` = dữ liệu giữ chỗ cần hoàn thiện; `post_mvp` = ngoài bản này. Trong bản đầy đủ phải bật toàn bộ nội dung `slice` và `mvp`. Không lấy nhãn slice làm lý do dừng ở một đảo. Asset có trạng thái riêng, chỉ đổi sau khi file thật tồn tại và được kiểm tra theo `06`/`14`.

## Kiểm tra

Từ gốc bộ tài liệu hoặc dự án đã tổ chức `docs/` + `data/`:

```text
python -m pip install -r tools/requirements.txt
python tools/check_docs.py
```

Đặt dependency trong venv của dự án khi triển khai. Công cụ kiểm tra schema, ID/tham chiếu, bản dịch, binding, quy mô nội dung và các invariant dữ liệu mới. Nó không kiểm thử game, mạng thực, performance, chất lượng asset hay quyền thương mại của file chưa có.

Mỗi tham số cân bằng có một nguồn trong content; số là khởi đầu để playtest, không phải đo từ game gốc. Thay đổi phải cập nhật các consumer và test; không sao chép toàn bộ data vào một thư mục thứ hai trong dự án.
