# Cách dùng bộ CÁ BAY 2.0

## Bạn cần làm ngay

Giải nén ZIP vào thư mục Claude Code có thể đọc. Gửi nội dung `prompts/01_KIEM_TRA_VA_KHOI_DONG.md`. Claude sẽ kiểm tra môi trường, lập danh sách thiếu, tự tạo thư mục dự án và tự chuyển sang triển khai. Nếu phiên bị ngắt, dùng Prompt 02; tiến độ sẽ được lưu trong dự án.

Bạn không cần tạo sẵn từng thư mục, file code, mô hình hay âm thanh. Claude phải tự làm phần có thể tự làm, dùng tài nguyên tạm đúng chuẩn, rồi thay dần. Nó chỉ hỏi bạn về thứ không thể tự có: đăng nhập/tài khoản, quyền dùng máy chủ, domain đã sở hữu, tệp thu âm hoặc lựa chọn thật sự không có phương án miễn phí thay thế.

## Những lựa chọn đã được ghi lại

Game web trên máy tính; Godot 3D góc nhìn thứ nhất; 4 người; 3 đảo, 3 boss, 15 loài thường; Việt/Anh; đói và ăn; gacha miễn phí; tài khoản, lưu máy chủ; hình ảnh ngộ nghĩnh và không máu me; Claude điều phối; ChatGPT nhận việc bằng tay; máy 8 GB RAM; ngân sách phát sinh 0 đồng. Tên CÁ BAY vẫn là tên tạm.

Cốt truyện mới: nhóm bạn giúp khôi phục bến câu và hoạt động nghề cá sau một mùa thời tiết xấu. Ba khu vực mở theo việc sửa bến, giúp người dân và chinh phục cá lớn. Tình huống hài đến từ cá vùng vẫy, ném dép, va chạm và phối hợp vụng về; không cần lý do cá đột biến vì trà sữa. Đây là phương án cốt truyện được đề xuất để Claude có thể bắt đầu, có thể chỉnh sau.

## Hai prompt dùng thế nào

- **Prompt 01:** dùng lúc bắt đầu. Kiểm tra rồi tự làm tiếp, không dừng ở bản kế hoạch.
- **Prompt 02:** điều hành cả quá trình, cũng dùng để tiếp tục phiên mới. Claude phải làm tới bản đầy đủ; bản một đảo chỉ là mốc kiểm tra nội bộ.
- **Yêu cầu ChatGPT:** `prompts/CHATGPT_ASSET_REQUEST.md` là mẫu riêng để Claude điền cho từng đợt tài nguyên, không thay thế hai prompt triển khai.

## Khi Claude cần hình ảnh hoặc âm thanh

Claude tạo một gói yêu cầu có tên tài nguyên, mô tả, kích thước/định dạng và mẫu tham khảo. Bạn dán yêu cầu vào ChatGPT, lưu tệp nhận được vào thư mục `incoming/` của dự án. Claude kiểm tra, chuẩn hóa, nhập vào game. Ảnh concept không được coi là mô hình 3D. Đối với âm thanh, Claude thử phương án miễn phí hoặc tự tổng hợp trước; nếu phiên ChatGPT không xuất được tệp âm thanh thì chỉ dùng nó viết kịch bản/yêu cầu, không báo âm thanh đã có.

## Các điểm có thể cần bạn bổ sung sau

1. Tài khoản itch.io để công khai và thiết lập nhận tiền ủng hộ nếu muốn.
2. Máy chủ hoặc nơi chạy dịch vụ có lưu dữ liệu bền vững, địa chỉ HTTPS/WSS truy cập được từ bên ngoài. Máy đang phát triển có thể làm môi trường thử, nhưng không mặc nhiên là dịch vụ hoạt động 24/7.
3. Tên miền `.io` nếu bạn đã sở hữu. Gói này không cho phép mua domain vì ngân sách là 0.
4. Cách tạo/thu lời thoại Việt và Anh có quyền dùng trong game nếu chưa tìm được phương án miễn phí phù hợp.

Các mục này không ngăn Claude làm game và kiểm thử local. Nhưng khi chưa có máy chủ truy cập công khai, Claude phải ghi rõ chưa hoàn thành co-op và đồng bộ tài khoản trên bản công khai.

## Buổi chơi thử của bạn

Dành tối đa 1 giờ theo kịch bản trong `10_VALIDATION.md`: vào game và tạo tài khoản, câu/bán/nâng cấp, chơi nhóm, thử mất kết nối, đổi thiết bị, đói/ăn và mở hộp thưởng. Claude chuẩn bị sẵn bản chơi, tài khoản thử và phiếu ghi lỗi; không giao bạn chạy các kiểm thử lập trình.
