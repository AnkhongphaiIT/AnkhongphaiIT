# Batch voice_v1 — thu giọng thoại VI/EN bằng người thật (có đồng ý)

- Phiên bản: 1 (27/09/2026). Trạng thái các dòng: `script_ready` (62 dòng × ngôn ngữ = 31 câu VI + 31 câu EN, 6 NPC).
- Vì sao: yêu cầu cuối là lời thoại có giọng đọc Việt/Anh. Bản tạm hiện có dùng espeak-ng (giọng máy, giấy phép chưa chốt → loại khỏi bản phát hành, xem NEED-VOICE-LICENSE). Thu giọng người thật là phương án 0 đồng chắc chắn nhất.
- Người thực hiện: chủ dự án hoặc người tình nguyện **đồng ý bằng văn bản** cho dự án dùng giọng trong game và quảng bá (không thương lượng tiền trong phạm vi này). Không mô phỏng giọng người nổi tiếng.

## Cần thu

`voice_lines.csv`: mỗi dòng có `line_id`, `npc_id`, `locale`, `text`. Mỗi `line_id` + `locale` là **một file riêng**.

| NPC | Tính cách gợi ý | Số câu |
|---|---|---|
| Cô Ba (`npc_co_ba`) | bán cá ở bến, nhanh nhảu, tốt bụng | 6 |
| Ông Tư (`npc_ong_tu`) | ông lão chèo đò, chậm rãi, hài hước | 5 |
| Bảy Chợ (`npc_bay_cho`) | cô bán hàng đảo 2, tươi, nói nhanh | 5 |
| Cô Tám (`npc_co_tam`) | chủ sạp đảo 3, điềm đạm | 5 |
| Nam Sáu (`npc_nam_sau`) | thợ sửa bến đảo 2, chắc giọng | 5 |
| Chị Lan (`npc_chi_lan`) | trưởng hội câu đảo 3, vui vẻ | 5 |

Một người có thể đọc nhiều NPC bằng cách đổi cao độ/tốc độ.

## Cách thu (điện thoại hoặc máy tính đều được)

1. Phòng yên tĩnh, cách micro 15–20 cm, không nhạc nền.
2. Mỗi câu thu thành một file, đặt tên đúng `<line_id>__<locale>.wav` (ví dụ `npc_co_ba.greet__vi.wav`). Nếu máy chỉ ghi được .m4a/.mp3 thì cứ gửi, Claude sẽ chuyển sang WAV mono 44,1 kHz PCM16 và giữ bản gốc.
3. Nói tự nhiên, cảm xúc ấm áp/trung tính, để trống ~0,3 giây đầu và cuối.
4. Chép tất cả file vào `handoff/incoming/voice_v1/` kèm một file `consent.txt` ghi: tên người đọc (hoặc bí danh), các NPC đã đọc, ngày, câu "Tôi đồng ý cho dự án CÁ BAY dùng các bản ghi này trong game và tài liệu quảng bá."

## Claude sẽ làm sau khi nhận

Kiểm từng file (giải mã thật, thời lượng, clipping, mức âm), chuẩn hóa −18 LUFS, cắt lặng, cập nhật `assets/audio/vo/…` và gói JSON theo NPC × ngôn ngữ, ghi nguồn + đồng ý vào `handoff/source_manifest.json`, báo coverage theo **dòng × ngôn ngữ**. Câu nào thiếu vẫn dùng giọng "ú ớ" + phụ đề và được ghi là còn thiếu.
