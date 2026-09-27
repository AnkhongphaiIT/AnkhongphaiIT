# 12 — Kiểm tra trước khi triển khai

Mục tiêu: kiểm tra thực tế rồi làm ngay phần đủ điều kiện. Không biến mọi tài nguyên chưa có thành câu hỏi cho người dùng. Không quét toàn bộ máy hoặc in biến môi trường chứa bí mật.

## 1. Môi trường và gói nguồn

| Kiểm tra | Bằng chứng cần ghi | Xử lý |
|---|---|---|
| ZIP/nguồn | Đường dẫn, checksum, phiên bản 2.0.0, root hợp lệ | Giải nén trong workspace, chặn đường dẫn vượt thư mục; không chạy script lạ trước khi đọc |
| Thư mục đích | Đường dẫn tuyệt đối, thư mục mới hay dự án cũ | Tạo `ca-bay`, hoặc tiếp tục dự án đúng nguồn; không ghi đè dữ liệu không liên quan |
| Hệ điều hành/RAM/đĩa | Thông số thực tế, RAM 8 GB là thông tin chủ dự án cung cấp | Giảm song song, không tự nâng cấp máy |
| Claude/Godot/Git/Python | Executable và phiên bản thực tế, không chỉ tên shortcut | Nếu thiếu, dùng bản miễn phí chính thức và cài cục bộ khi quyền cho phép |
| Godot export | Editor stable + template đúng phiên bản, Compatibility, test GDScript và web một cảnh | Chưa pin số phiên bản lấy từ tài liệu cũ; ghi cặp đã chạy được vào toolchain lock |
| Python backend | Venv, dependency khóa phiên bản, SQLite hoạt động | Tránh phụ thuộc Docker để bắt đầu; không sửa Python hệ thống |
| Agent khác | Khả năng gọi thật của Codex/Antigravity, phiên đăng nhập, quyền đọc/sửa | Không dựa vào việc đã cài ứng dụng để kết luận có API/CLI điều phối |
| Trình duyệt | Chrome/Edge hoặc Firefox có WebGL2, WebSocket, Pointer Lock | Xuất web và chạy từ HTTP local, không mở `file://` để nghiệm thu |
| Hạ tầng | Server đang có, disk bền vững, HTTPS/WSS, giới hạn CPU/RAM/kết nối | Không chọn gói tính phí hay dùng thẻ; xem `15` |

Những kiểm tra trên chưa được chạy trên môi trường Claude Code tương lai. Gói tài liệu không tuyên bố phiên bản Godot hay server của người dùng đã sẵn sàng.

## 2. Đã có và thiếu gì trong gói

Đã có: đặc tả, nội dung JSON, schema, khóa dịch, registry, map âm thanh/VFX, save mẫu và prompt. Các hàng registry là dự kiến, không phải file tài nguyên đã giao. Chưa có mã game chạy được, server chạy thật, mô hình/ảnh/âm thanh/font thực tế, tài khoản itch.io được xác nhận, endpoint server hoặc tên miền đã xác nhận.

| Nhóm thiếu | Chủ xử lý mặc định | Có chặn bắt đầu không? |
|---|---|---|
| Repo, scene, GDScript, server, test, build scripts | Claude và agent code | Không — đây là công việc phải làm |
| Đảo/cá/NPC/đồ dùng/animation | Agent procedural art; mô hình tạm rồi low-poly bản cuối | Không |
| UI/icon | Code UI; icon render mô hình; ChatGPT concept nếu cần | Không |
| Nhạc/SFX/ambience | Tự tổng hợp/soạn đơn giản; tìm nguồn miễn phí có quyền thương mại | Không; bản cuối cần QA |
| Lời thoại có giọng Việt/Anh | Thử local TTS có giấy phép phù hợp hoặc thu âm; dùng gibberish tạm | Không chặn code; có thể chặn nghiệm thu âm thanh cuối |
| Hosting máy chủ | Claude khảo sát lựa chọn thực có; chủ dự án cung cấp quyền nếu cần | Chặn thử public khi chưa có; không chặn local |
| itch.io login, xác nhận tài khoản | Chủ dự án thao tác trong màn hình đăng nhập | Chặn upload công khai; không chặn build |
| Domain .io | Dùng domain có sẵn được cấp quyền | Chặn website .io khi chưa sở hữu; itch.io vẫn làm được |

## 3. Báo cáo thiếu hụt phải có hành động

Claude tạo `reports/PREFLIGHT.md` với bảng `hạng mục | detected/absent/unverified | bằng chứng | hành động`. Tạo `reports/NEEDS_USER.md` theo mẫu:

| ID | Thiếu cụ thể | Chặn mốc nào | Đã thử thay thế miễn phí | Người dùng cần làm | Phần vẫn tiếp tục |
|---|---|---|---|---|---|
| NEED-HOST | Chưa có endpoint máy chủ persistent HTTPS/WSS | Internet co-op, public accounts | Local/LAN đang chạy; kiểm tra free tier chưa đạt tiêu chí | Cấp quyền host sẵn có hoặc chọn vận hành máy riêng | Gameplay, local tests, asset, build |

Chỉ đưa vào báo cáo mục thật sự phát hiện, không sao chép ví dụ thành kết luận. Gộp yêu cầu theo đợt; không hỏi lại bộ 32 câu. Không yêu cầu dán mật khẩu/token vào chat. Đưa hướng dẫn cấu hình bí mật cục bộ, chỉ kiểm tra tồn tại và kết nối.

## 4. Cổng quyết định

- **CODE_READY:** có workspace ghi được + runtime cơ bản; bắt đầu code, server local, placeholder.
- **WEB_READY:** đã export và mở web qua HTTP, input/audio unlock hoạt động.
- **ONLINE_TEST_READY:** endpoint HTTPS/WSS + disk bền + tài khoản thử + hai thiết bị; chạy test 4 người thật.
- **PUBLIC_READY:** bộ test đạt, license đủ, giới hạn vận hành rõ, tài khoản đăng sẵn, nội dung trang đúng thực trạng.

Không yêu cầu tất cả cổng cùng đạt mới viết game. Chỉ dừng nhánh phụ thuộc trực tiếp vào thiếu hụt. Sau kiểm tra, tự đọc Prompt 02 và thực hiện việc khả thi tiếp theo.
