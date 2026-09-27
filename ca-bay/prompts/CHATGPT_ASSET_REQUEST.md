# Prompt chuyển thủ công sang ChatGPT Plus

Claude thay các trường trong ngoặc vuông bằng dữ liệu cụ thể của batch trước khi đưa người dùng. Không gửi mật khẩu, cookie hoặc khóa API. Người dùng dán vào ChatGPT, lấy file trả về và chép vào `handoff/incoming/[batch_id]/` trong dự án game.

---

Tôi đang làm game câu cá web máy tính bằng Godot: 3D low-poly, góc nhìn thứ nhất, 1–4 người co-op, bối cảnh làng chài Việt Nam đời thường. Màu phẳng tươi, khối rõ, vui nhẹ, không máu me, ma thuật hay trà sữa/trân châu. Dự án có 3 đảo, 15 loài thường và 3 boss thực tế; hãy bám các mục cụ thể bên dưới, không tự mở rộng.

Batch: [batch_id]. Bản brief: [version]. Mục tiêu: [mục tiêu của batch]. Đầu ra cần: [concept_only hoặc runtime_candidate]. Các hình 3D được yêu cầu dưới dạng concept chỉ là tham khảo để dựng mô hình sau, không phải file mô hình.

Danh sách tối đa 4–6 mục:

[Mỗi mục ghi request_id; asset_id; tên hiển thị; hình dáng đặc trưng; màu; góc nhìn; số ảnh; nền; kích thước đề nghị; tiêu chí duyệt.]

Yêu cầu chung:

- Thiết kế nguyên bản, không sao chép nhân vật/logo/screenshot game khác hoặc dùng nhãn hiệu.
- Không chữ, số, logo hoặc watermark trong hình UI; chữ sẽ do engine hiển thị.
- Giữ cùng bảng màu [bảng màu] và độ chi tiết [ngân sách/hướng hình khối].
- Với concept sinh vật, cung cấp góc trước/bên/3 phần tư nếu công cụ hỗ trợ; bộ phận phải nhất quán. Không hứa chính xác kích thước vật lý từ hình.
- Với ảnh cần trong suốt, chỉ báo nền trong suốt nếu file thực có alpha. Nếu không xuất được định dạng/kích thước này, nêu đúng đầu ra thực tế để Claude xử lý.
- Nếu phiên này không xuất được âm thanh, giọng hoặc model 3D, hãy trả brief/kịch bản/mã đề xuất bằng văn bản và ghi rõ chưa có media; không tạo đường dẫn tải giả.
- Âm thanh nếu chỉ viết brief: mô tả loại tiếng, nhịp, thời lượng, loop và mức ưu tiên; lời thoại cần văn bản Việt/Anh và cảm xúc trung tính, không mô phỏng giọng người nổi tiếng.

File có thể đổi tên đúng request_id sau khi tải. Kèm danh sách ngắn: mục nào đã tạo, định dạng thật, giới hạn còn lại. Không tự khẳng định ảnh/âm thanh là CC0 hoặc mọi quyền đã được bảo đảm; tôi sẽ lưu thông tin công cụ và kiểm điều khoản sử dụng khi nhập vào dự án.

---

Claude không tự động thao tác website ChatGPT. Trong lúc chờ relay, tiếp tục tài nguyên procedural theo cùng asset ID. Chỉ nhập file thật và cập nhật trạng thái sau kiểm tra trong `14_AI_ASSET_HANDOFF.md`.
