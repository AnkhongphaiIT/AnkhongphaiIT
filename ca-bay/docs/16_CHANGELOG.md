# 16 — Lịch sử bản 2.0.0

Ngày 27/09/2026. Nguồn thay đổi: 33 mục trả lời/yêu cầu của chủ dự án trong cuộc trò chuyện, sau bước kiểm tra ZIP và 32 câu hỏi làm rõ. Đây là cập nhật tài liệu và dữ liệu, không phải bản game 2.0 đã phát hành.

| Trước | Sau |
|---|---|
| Chơi đơn, co-op sau MVP | Room 1–4 người trong kiến trúc và test từ đầu |
| Web + Android, điều khiển cảm ứng | Chỉ desktop web, bàn phím/chuột |
| Mốc thiết kế nội dung mới đủ một đảo, đảo sau nhiều chỗ giữ chỗ | Đích đủ 3 đảo, 3 boss, 15 loài thường và các chuỗi mở vùng |
| Shipper trà sữa/cá hóa quậy | Cốt truyện bến cá đời thường; hài đến từ gameplay |
| Không đói/không cờ bạc bản đầu | Thanh đói/ăn và hộp thưởng miễn phí bằng gameplay |
| Local save là chính | Account và save authoritative trên server riêng, local chỉ cache/prefs |
| Máy 4 GB, đợi nâng RAM | Máy 8 GB; giới hạn song song, không đợi nâng máy để bắt đầu |
| Giao từng gói rời | Claude là lead, có backlog, ownership, integration, checkpoint |
| Chưa có quy trình ChatGPT nhận file | Batch chuyển tay, incoming, kiểm tra và nhập tài nguyên |
| Chủ yếu tiếng nhân vật ú ớ | Thêm yêu cầu giọng đọc VI/EN có coverage được nghiệm thu |
| Chưa làm kiếm tiền | Free trước; public trên itch.io có hướng donations; ads/IAP chưa bật |
| Nhiều phiên bản/capability công cụ chốt theo nghiên cứu cũ | Kiểm tra executable, stable version, template và quyền thực tế |

Các quyết định triển khai bổ sung như cốt truyện cụ thể, 15 loài không tính boss, đồ trang trí trong gacha, phương án server và quy tắc đói được phân biệt với câu trả lời nguyên văn trong `11`. Chúng là mặc định để làm việc theo quyền tự quyết đã được cấp, không được trình bày như lời người dùng đã nói.

Các file active 00, 04–17, hướng dẫn và dữ liệu liên quan được sửa/cập nhật. Nghiên cứu 01–03/references giữ nguyên phần nội dung nghiên cứu, có nhãn lịch sử, không được dùng để suy ra yêu cầu Android/chơi đơn/không đói hiện hành. Quy trình kiểm tra v2 kiểm schema, tham chiếu nội dung, registry, map âm thanh/VFX, tiếng Việt/Anh, độ phủ nội dung và các hợp đồng mới; không tái xác minh toàn bộ nghiên cứu và không chạy test gameplay khi chưa có game.

Gói không kèm ảnh/nhạc/mô hình do AI tạo, không mua dịch vụ, không đăng game, không tạo tài khoản người chơi thật. `VALIDATION_REPORT.md` ghi kết quả kiểm tra thực tế của tài liệu/dữ liệu lúc đóng gói.
