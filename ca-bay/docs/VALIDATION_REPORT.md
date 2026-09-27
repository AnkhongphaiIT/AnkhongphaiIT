# Báo cáo kiểm tra gói tài liệu CÁ BAY 2.0.0

Ngày: 27/09/2026. Kết quả: **0 lỗi, 0 cảnh báo trong phạm vi kiểm tra cấu trúc và dữ liệu**. Bộ gốc được giữ nguyên ở nguồn; gói này là bản cập nhật độc lập.

## Đã kiểm tra thực tế

| Hạng mục | Kết quả |
|---|---|
| File JSON dữ liệu/hợp đồng/save mẫu theo schema | 25 file, đạt |
| JSON Schema local | 26 schema hợp lệ |
| Nội dung | 3 đảo, 15 loài thường, 3 boss; đủ vùng câu/điểm xuất hiện/boss |
| Tham chiếu nội dung | Loài, mồi, nhiệm vụ, NPC, shop, asset và khóa dịch tồn tại |
| Việt/Anh | 273 khóa; không trùng, không thiếu ngôn ngữ; placeholder khớp |
| Registry tài nguyên | 287 ID; bảng Asset Bible và source manifest trùng danh mục |
| Event nội bộ | 84 sự kiện; map audio/VFX có tham chiếu hợp lệ |
| Network | 35 message, 19 HTTP endpoint; các payload schema hợp lệ |
| Save máy chủ v2 | Có schema và mẫu; định dạng UUID/timestamp hợp lệ; kiểm ID, không chứa credentials |
| Đói/hộp thưởng | Food ID hợp lệ; odds tổng đúng, cosmetic target hợp lệ, không bật tiền thật/offline drain |
| Nhịp mô phỏng/lưu | Content và hợp đồng mạng đồng nhất: 30 Hz, checkpoint 15 giây; tiền/đồ commit ngay theo đặc tả |
| Tệp văn bản | JSON đọc được; UTF-8, không ký tự thay thế hoặc ký tự điều khiển lạ |
| Liên kết Markdown nội bộ | Các liên kết tương đối trong tài liệu hiện hành được kiểm tra |

## Kiểm tra khả năng phát hiện lỗi

Sáu bản sao dữ liệu được cố ý làm sai; cả sáu bị bộ kiểm tra từ chối đúng lý do:

1. Thiếu mẫu save máy chủ bắt buộc.
2. Tổng trọng số hộp thưởng không khớp.
3. Loài tham chiếu model không có trong registry.
4. Account ID sai định dạng UUID.
5. Thêm loại tiền ngoài schema vào save mẫu.
6. Nhịp physics và hợp đồng mạng không khớp.

Các bản sao làm sai chỉ ở thư mục kiểm tra nội bộ, không nằm trong ZIP bàn giao.

## Rà soát nội dung và giới hạn

Đã sửa các mâu thuẫn phát hiện về bố cục dự án, số NPC cần thoại, quyền sở hữu cá trong co-op, nhịp mô phỏng/lưu, lịch chơi thử, phạm vi Android cũ và trạng thái tài nguyên. Mọi quyết định mới chưa được người dùng nói chi tiết được ghi là giả định triển khai trong 11. Hai prompt và CLAUDE.md được kiểm tra để không yêu cầu hỏi lại các quyết định đã chốt.

**Chưa có game runtime, server được triển khai, ảnh/model/nhạc/voice thực tế trong gói này.** Không chạy Godot/gameplay, không thử 4 người trên mạng, không đo FPS hoặc duyệt chất lượng media, không đăng itch.io hoặc mua tên miền. Mọi tài nguyên vẫn planned/tbd. Các bài kiểm thử game trong 10 là yêu cầu Claude phải thực hiện sau khi lập trình, không phải kết quả đã đạt.

Nghiên cứu How to Fish cũ ở 01–03/references chưa được tái xác minh toàn bộ. Nguồn công cụ/nền tảng được đọc cho cập nhật này nằm trong 17. Kiểm tra schema không tự hiểu mọi mâu thuẫn văn bản và không chứng minh chất lượng game.

## Chạy lại

Trong venv của dự án, cài dependency trong `tools/requirements.txt`, sau đó chạy `python tools/check_docs.py` từ gốc gói hoặc từ root dự án có `docs/` và `data/`. Mỗi lần sửa dữ liệu/hợp đồng cần chạy lại; thêm bảng mới phải kèm schema.
