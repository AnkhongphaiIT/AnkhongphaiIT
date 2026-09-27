# Batch b02_store_art — ảnh trang itch.io (chỉ trang cửa hàng, không nằm trong game)

- Phiên bản: 1 (27/09/2026)
- Mục tiêu: ảnh bìa và banner cho trang itch.io (`release/ITCH_PAGE.md`). Chữ tên game sẽ do Claude đặt bằng font Be Vietnam Pro, **không** vẽ chữ vào ảnh.
- Người thực hiện: chủ dự án relay ChatGPT Plus. Ngân sách 0.

| request_id | asset_id | deliverable_kind | Đầu ra | Tiêu chí duyệt |
|---|---|---|---|---|
| b02_r1 | store_itch_cover (ngoài registry, chỉ trang cửa hàng) | runtime_candidate | PNG 1260×1000 (tỉ lệ 630×500) | Cảnh 1–4 người trên bến gỗ, một con cá bay vọt lên trời, một người giơ dép; để trống 1/3 phía trên cho chữ; không chữ |
| b02_r2 | store_itch_banner (ngoài registry) | runtime_candidate | PNG 1920×480 | Toàn cảnh cù lao low-poly nhìn ngang, trời trong; không chữ |

Sau khi nhận: chép vào `handoff/incoming/b02_store_art/` tên `b02_r1.png`, `b02_r2.png`. Claude kiểm kích thước/alpha, ghi nguồn và điều khoản tài khoản ChatGPT tại thời điểm tạo trước khi dùng trên trang công khai.

## Prompt dán vào ChatGPT

Tôi đang làm game câu cá web máy tính bằng Godot: 3D low-poly, góc nhìn thứ nhất, 1–4 người co-op, bối cảnh làng chài miền Tây Việt Nam đời thường. Màu phẳng tươi, khối rõ, hài hước nhẹ, không máu me. Cá khi bị đánh chỉ "xỉu" có sao quay trên đầu.

Batch: b02_store_art. Bản brief: 1. Đầu ra: runtime_candidate cho trang cửa hàng (không dùng trong game).

1. b02_r1 — ảnh bìa 1260×1000: bốn người bạn kiểu nhân vật khối low-poly (đội nón lá, mũ lưỡi trai, khăn) đứng trên bến gỗ; một người vừa giật cần làm con cá rô bay vọt lên trời theo đường cong; một người khác giơ chiếc dép tổ ong chuẩn bị đập; phía sau là sạp cá mái bạt sọc và sông nước. Để trống khoảng trời 1/3 phía trên cho chữ tiêu đề (tôi tự đặt chữ).
2. b02_r2 — banner 1920×480: toàn cảnh cù lao low-poly nhìn ngang từ sông: bến đò, nhà sàn, dừa, xuồng; trời trong xanh.

Yêu cầu chung: thiết kế nguyên bản, không sao chép game/nhân vật/logo nào; không chữ, số, logo, watermark. Bảng màu như: trời #5EC8F2, nước #1F7A8C/#3FB8AF, gỗ #9C6B3F, cát #E9C98B, cỏ #7CC24A, đỏ #E4473C, vàng #FFC93C. Flat shading, ít đa giác. Nếu không xuất được đúng kích thước, nêu kích thước thật. Không tự khẳng định ảnh là CC0.
