# CHANGELOG

Định dạng: mỗi phiên bản ghi thay đổi người chơi thấy được + thay đổi vận hành. Trạng thái kiểm thử chi tiết ở `reports/TEST_RESULTS.md`.

## 0.1.0 — bản phát triển (chưa phát hành công khai)

**Chơi được (local, đã kiểm bằng trình duyệt thật + bot):**
- Tài khoản: đăng ký (mã khôi phục, tải .txt), đăng nhập, khôi phục, đổi mật khẩu, xóa tài khoản, tiếp quản thiết bị; token chỉ trong bộ nhớ phiên.
- Sảnh: tạo phòng trên đảo đã mở, vào phòng bằng mã 6 ký tự, danh sách phòng đang mở; 1–4 người/phòng.
- Đảo 1 Cù lao Bến Làng: câu (nạp lực, cắn, giật đúng lúc, kéo, cá quẫy), cá bay qua vai rơi lên bờ, đập xỉu bằng tay/dép/chổi/vỉ ruồi/ná/dừa nổ, trick nhân giá (trần ×6), nhặt vào túi, bán/mua/nâng cấp ở sạp, cơm nắm miễn phí, nướng cá, cò tha cá, nhiệm vụ Ông Tư, Sổ Cá, hộp quà lễ hội (vé miễn phí, tỉ lệ công khai), đi đảo khác theo biểu quyết.
- Đảo 2–3, 3 boss, 15 loài: có trong dữ liệu và mô phỏng server; **chưa có playthrough tự động qua cả 3 đảo**.
- Giao diện Việt/Anh, font Nunito; HUD, menu, cài đặt; tự kết nối lại tới 85 giây, lệnh đang chờ gửi lại không nhân đôi.
- Âm thanh tự tổng hợp: 65 SFX, 4 nhạc, 3 âm nền, giọng "ú ớ". Thoại có giọng (espeak-ng) chỉ là bản tạm, **không** có trong gói phát hành.

**Vận hành:** gói web (`tools/build/package_web.py`) và gói máy chủ (`tools/build/package_server.py`) với runbook, sao lưu/khôi phục; bản công khai bị chặn tới khi có host HTTPS/WSS, quyền itch.io và kênh liên hệ.
