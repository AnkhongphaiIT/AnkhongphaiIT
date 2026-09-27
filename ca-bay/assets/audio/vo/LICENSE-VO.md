# Thoại tạm (placeholder) — giấy phép

Các file `vo/<npc_id>/<locale>/*.wav` và `vo_dialogue_*.json` được tổng hợp bằng **espeak-ng 1.51**
(gói Ubuntu `espeak-ng`, GPL-3.0-or-later; dữ liệu giọng có đoạn sóng mẫu có thể nằm trong âm đầu ra)
bằng script `tools/asset_generation/audio/` (tái tạo byte-giống-hệt).

- Coi các file thoại này là dữ liệu **GPL-3.0-or-later** (mã nguồn espeak-ng công khai; script tạo nằm trong repo).
- Trạng thái trong manifest: `license: "tbd"`. **Không đưa vào bản phát hành công khai/thương mại** cho tới khi
  chủ dự án chọn: (a) phát hành kèm điều khoản GPL, (b) hỏi tư vấn pháp lý, hoặc (c) thay bằng ghi âm có đồng ý.
- `tools/build/export.py web --release` tự loại thư mục này; game khi thiếu thoại sẽ phát gibberish + phụ đề.
- Chất lượng: giọng máy (formant), chưa được người nghe duyệt. Yêu cầu "lời thoại có giọng đọc Việt/Anh" **chưa đạt**.
