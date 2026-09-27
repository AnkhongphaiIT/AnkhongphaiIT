# 17 — Nguồn đối chiếu cho bản 2

Kiểm tra ngày 27/09/2026. Các URL dưới là tài liệu chính thức được đọc cho lần cập nhật này; nội dung có thể thay đổi. Chỉ áp dụng đúng kết luận ghi ở cột cuối. Không suy ra giấy phép tài nguyên, quota tài khoản người dùng hoặc khả năng hosting từ một trang không nói tới chúng.

| Nguồn | URL | Kết luận được dùng |
|---|---|---|
| Godot export web | https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html | Giới hạn mạng trình duyệt; cần kiểm chứng web export thực tế, không dùng ENet UDP cho web |
| Godot WebSocket | https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html | WebSocket dùng với trình duyệt, server chạy bên ngoài browser |
| Claude Code subagents | https://code.claude.com/docs/en/sub-agents | Có cấu hình agent theo project; kiểm tra bản cài để dùng đúng cú pháp |
| Claude Code permissions | https://code.claude.com/docs/en/permissions | Công cụ có cơ chế quyền; prompt tự chủ không thay thế quyền của môi trường |
| itch.io HTML5 | https://itch.io/docs/creators/html5 | ZIP chứa index.html, game embed trong iframe; thanh toán HTML5 dạng donations |
| itch.io payments | https://itch.io/docs/creators/payments | Nhận tiền cần thiết lập thanh toán/người nhận; không được bịa đã thiết lập |
| itch.io quality | https://itch.io/docs/creators/quality-guidelines | Trang phát hành phải được kiểm tra theo hướng dẫn hiện hành, mô tả đúng sản phẩm |
| OpenAI image generation | https://developers.openai.com/api/docs/guides/image-generation | API tạo/sửa ảnh là khả năng riêng; dự án hiện chọn chuyển tay ChatGPT, không tích hợp API |

Không ghim tên model AI, không tuyên bố gói Plus/Pro cho phép tự động điều phối lẫn nhau, không mặc định khả năng xuất nhạc/3D. Agent phải kiểm tra công cụ thực tế; nếu chưa có thì giao việc bằng file hoặc Claude tự làm. Bản 2 không sử dụng phát biểu "Godot 4.7.2 là bản mới nhất" trong nghiên cứu cũ làm căn cứ cài đặt.

Các khẳng định chi tiết về How to Fish trong `01`–`03` được giữ như nghiên cứu gốc, không được coi là đã tái kiểm chứng ở bản 2. Chỉ lấy cảm hứng cơ chế chung, không sao chép tài nguyên hoặc lời thoại.
