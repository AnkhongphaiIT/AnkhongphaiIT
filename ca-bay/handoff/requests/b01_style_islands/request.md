# Batch b01_style_islands — bảng phong cách làng chài + 3 đảo (concept_only)

- Phiên bản: 1 (27/09/2026)
- Mục tiêu: có ảnh tham khảo thẩm mỹ để Claude chỉnh mô hình procedural (màu, tỉ lệ nhà/cây/bến, không khí mỗi đảo). **Không** dùng làm tài nguyên trong game.
- Nguồn quyết định: `docs/05_ART_BIBLE.md` (bảng màu §3), `docs/04_GAME_DESIGN.md` (3 đảo), DEC đã chốt (low-poly tươi, không máu, không trà sữa)
- Người thực hiện: chủ dự án relay ChatGPT Plus (không API). Ngân sách 0.

| request_id | asset_id | deliverable_kind | Đầu ra | Tiêu chí duyệt |
|---|---|---|---|---|
| b01_r1 | tex_palette_main | concept_only | 1 ảnh PNG 1536×1024 bảng phong cách | Có bến gỗ, sạp, nhà sàn lá, thuyền nhỏ, cây dừa/bần, người dân đội nón; đúng bảng màu; không chữ |
| b01_r2 | env_isl01_day | concept_only | 1 ảnh PNG 1536×864 | Cù lao Bến Làng: bến đò dài ra sông nước phù sa, bãi bùn, sạp Cô Ba, cọc cờ đỏ; buổi trưa nắng |
| b01_r3 | env_isl02_day | concept_only | 1 ảnh PNG 1536×864 | Rừng Dừa Nước: dừa nước dày, ao sen giữa đảo, bến dừa; xanh đậm hơn đảo 1 |
| b01_r4 | env_isl03_day | concept_only | 1 ảnh PNG 1536×864 | Mũi Đá: đá xám, nước xanh trong hơn, ngọn hải đăng nhỏ, bãi đá |

Sau khi nhận: chép file vào `handoff/incoming/b01_style_islands/` với tên `b01_r1.png` … `b01_r4.png`. Claude sẽ kiểm định dạng/kích thước, ghi SHA-256 và nguồn (ChatGPT, ngày tạo, điều khoản tài khoản), rồi chỉ dùng làm tham khảo.

## Prompt dán vào ChatGPT

Tôi đang làm game câu cá web máy tính bằng Godot: 3D low-poly, góc nhìn thứ nhất, 1–4 người co-op, bối cảnh làng chài miền Tây Việt Nam đời thường sau một trận bão (mọi người cùng sửa lại bến). Màu phẳng tươi, khối rõ, vui nhẹ, không máu me, không ma thuật, không trà sữa/trân châu. Dự án có 3 đảo; hãy bám các mục bên dưới, không tự mở rộng.

Batch: b01_style_islands. Bản brief: 1. Mục tiêu: ảnh concept tham khảo phong cách. Đầu ra: concept_only (chỉ tham khảo, không phải mô hình 3D).

1. b01_r1 — bảng phong cách (style board) 1536×1024: bến gỗ, sạp bán cá mái bạt sọc xanh–nâu, nhà sàn mái lá, xuồng ba lá, cây dừa và cây bần, 2–3 người dân đội nón lá kiểu khối low-poly (mắt tròn to, thân hình hộp), cần câu tre, phao đỏ trắng. Góc nhìn 3/4 từ trên cao.
2. b01_r2 — Cù lao Bến Làng 1536×864: đảo nhỏ nhìn từ trên xuống chéo, bến đò gỗ dài đâm ra sông nước phù sa nâu xanh, bãi bùn một bên, sạp cá gần bến, một cọc cờ đỏ ở mép nước phía tây. Buổi trưa nắng.
3. b01_r3 — Rừng Dừa Nước 1536×864: đảo phủ dừa nước dày, có ao sen tròn giữa đảo, bến dừa, nước xanh ngả lục.
4. b01_r4 — Mũi Đá 1536×864: đảo nhiều đá xám bo tròn, nước xanh trong, một ngọn hải đăng nhỏ trắng–đỏ, bãi đá phẳng để đứng câu.

Yêu cầu chung: thiết kế nguyên bản, không sao chép nhân vật/logo/ảnh game khác, không chữ/số/logo/watermark trong hình. Bảng màu: trời #5EC8F2/#CDEFF7, nước #1F7A8C/#3FB8AF, phù sa #9C8455, cát #E9C98B, cỏ #7CC24A/#3E8E3A, gỗ #9C6B3F/#6B4428, tín hiệu #E4473C/#FFC93C. Độ chi tiết: low-poly flat shading, ít đa giác, không texture chi tiết. Nếu không xuất được đúng kích thước, nêu kích thước thật. Kèm danh sách ngắn mục nào đã tạo và định dạng thật. Không tự khẳng định ảnh là CC0.
