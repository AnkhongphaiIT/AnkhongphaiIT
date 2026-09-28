# CHANGELOG

Định dạng: mỗi phiên bản ghi thay đổi người chơi thấy được + thay đổi vận hành. Trạng thái kiểm thử chi tiết ở `reports/TEST_RESULTS.md`.

## 0.1.0 — bản phát triển (chưa phát hành công khai)

**Chơi được (local, đã kiểm bằng trình duyệt thật + bot):**
- Tài khoản: đăng ký (mã khôi phục, tải .txt), đăng nhập, khôi phục, đổi mật khẩu, xóa tài khoản, tiếp quản thiết bị; token chỉ trong bộ nhớ phiên.
- Sảnh: tạo phòng trên đảo đã mở, vào phòng bằng mã 6 ký tự, danh sách phòng đang mở; 1–4 người/phòng.
- Đảo 1 Cù lao Bến Làng: câu (nạp lực, cắn, giật đúng lúc, kéo, cá quẫy), cá bay qua vai rơi lên bờ, đập xỉu bằng tay/dép/chổi/vỉ ruồi/ná/dừa nổ, trick nhân giá (trần ×6), nhặt vào túi, bán/mua/nâng cấp ở sạp, cơm nắm miễn phí, nướng cá, cò tha cá, nhiệm vụ Ông Tư, Sổ Cá, hộp quà lễ hội (vé miễn phí, tỉ lệ công khai), đi đảo khác theo biểu quyết.
- Đảo 2–3, 3 boss, 15 loài: bot chơi qua mạng thật hết 6 nhiệm vụ, 3 boss, mở 3 đảo, bắt đủ 15/15 loài (chưa có người thật chơi hết).
- Trận boss: vòng phao đỏ-trắng đánh dấu bãi, cảnh báo khi ra ngoài, bị xỉu thì dậy ngay trong bãi (không bị đưa về bến), ân hạn rời bãi 8 s; tầm đánh boss tính tới thân boss (hết trượt "vô hình").
- Giao diện Việt/Anh, font Be Vietnam Pro; HUD, menu, cài đặt; tự kết nối lại tới 85 giây, lệnh đang chờ gửi lại không nhân đôi.
- Âm thanh tự tổng hợp: 65 SFX, 4 nhạc, 3 âm nền, giọng "ú ớ". Thoại có giọng (espeak-ng) chỉ là bản tạm, **không** có trong gói phát hành.

- Nướng cá: đồng hồ "Đang nướng… còn N giây", báo "Cá chín rồi!" kèm âm, cảnh báo sắp khét; tải lại trang/đổi máy giữa lúc nướng không còn làm mất cá hay khóa bếp.
- Hộp quà: bảng tỉ lệ hiển thị đúng con số (trước đó lỗi "%g%"). Nhận việc ngay tại người giao thì không phải nói chuyện lần hai. Mục tiêu chỉ đường khi việc nằm ở đảo khác. Thêm icon cho vỉ ruồi, ná, dừa nổ, cần carbon, 3 loại mồi, nâng cấp túi/guồng.

- Tùy chọn → Phím điều khiển: đổi phím cho di chuyển, nhảy, tương tác, ô công cụ, đổi mồi, Sổ Cá (trùng phím tự đổi chỗ, nút về mặc định); mọi gợi ý trên màn hình hiện đúng phím đang dùng.

**Chơi thử trên máy mình / một link cho bạn bè (P-035, P-038):** gói máy chủ bản Windows có sẵn Python và room server — giải nén, bấm `CHOI_THU.bat` là chơi ở `http://127.0.0.1:8787`; máy chủ phục vụ luôn trang game và chuyển tiếp kết nối phòng chơi trên cùng một cổng, nên một đường hầm HTTPS (ví dụ `cloudflared tunnel --url http://127.0.0.1:8787`) cho ra **một link** gửi bạn bè. Gói Linux: `run/choi_thu.sh`.

**Mạng (từ kiểm thử bot WP-12):** mất Wi-Fi/máy ngủ mà không có gói đóng kết nối giờ được máy chủ nhận ra sau ~15 s (trước đây người chơi "ma" giữ chỗ mãi và máy chủ dồn dữ liệu vào kết nối chết) — người chơi được giữ chỗ 90 s và tự nối lại; cá đã thả xuống đất lúc room server sập giờ về hộp thư đồ khi vào lại (trước đây kẹt, không thấy để nhặt); tên boss chỉ hiện trên thanh máu HUD (nhãn 3D trên đầu boss chồng lên thanh này đã bỏ).

**Bảo mật:** bản công khai không cho tham số `?api=&ws=` đổi máy chủ (chống link lừa gửi mật khẩu đi nơi khác, P-034); giới hạn thử sai theo IP sau đường hầm không còn lách được bằng header giả (P-036); script PowerShell của gói Windows trước đây lỗi cú pháp trên PowerShell 5.1 vì thiếu BOM — đã sửa và thêm bước kiểm khi đóng gói (P-037).

**Sửa lỗi an toàn giao dịch (từ kiểm thử bot):** gửi lại lệnh gọi boss cũ không còn mở thêm trận miễn phí; chuyển thiết bị không đá nhầm máy mới; bị server ngắt thì được dọn khỏi phòng đúng cách; gửi lại lệnh nhặt sau khi máy chủ phòng khởi động lại nhận đúng kết quả cũ; nhặt được cá đang nhấp nháy sắp tỉnh.

**Vận hành:** `server/ops/seed_checkpoint.py` tạo tài khoản checkpoint cho buổi chơi thử. Gói web (`tools/build/package_web.py`) và gói máy chủ (`tools/build/package_server.py`) với runbook, sao lưu/khôi phục; bản công khai bị chặn tới khi có host HTTPS/WSS, quyền itch.io và kênh liên hệ.
