# 15 — Phát hành và ngân sách 0 đồng

## 1. Những điều đã cho phép

Chủ dự án muốn game chơi miễn phí trước, công khai ở nền tảng có thể kiếm tiền; quảng cáo và bán vật phẩm sẽ xem xét sau. Claude được tự chuẩn bị và triển khai khi có quyền đăng nhập/hạ tầng thật và test đạt. Không cần hỏi lại việc muốn công khai. Chưa được mua tên miền, trả phí hosting/API, bật quảng cáo/IAP hoặc chọn phần nào tính tiền.

## 2. Tách ba phần vận hành

| Phần | Phương án | Giới hạn |
|---|---|---|
| File web | Upload ZIP HTML5 lên itch.io; static website riêng là nhánh bổ sung | Hosting static không chạy được backend Python hay Godot server |
| Tài khoản/dữ liệu/room | Máy chủ được chủ dự án kiểm soát hoặc dịch vụ miễn phí thực đáp ứng kiểm tra dưới đây | Không giả định máy phát triển luôn online; disk ephemeral không được dùng làm nơi lưu tài khoản duy nhất |
| Domain `.io` | Dùng domain đã sở hữu, hoặc hoãn riêng nhánh này | Không tự mua với ngân sách 0; URL itch.io/free subdomain không được gọi là domain `.io` riêng |

Godot web client dùng HTTP(S)/WebSocket client hoặc WebRTC trong giới hạn trình duyệt; phương án dự án chọn WSS tới server chạy riêng. Đây là lựa chọn kiến trúc, không phải dịch vụ có sẵn trong itch.io. Nguồn: [Godot web networking](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [WebSocket](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html).

## 3. Điều kiện một host miễn phí được chấp nhận

Claude phải kiểm tra điều khoản tại thời điểm triển khai, ghi URL và ngày: cho phép game/thương mại; thực sự 0 đồng và không tự tính vượt hạn mức; hỗ trợ executable cần thiết, HTTPS/WSS và kết nối đủ dài; disk bền vững; CPU/RAM thực chạy được room bốn người; chính sách sleep/restart; backup/restore; quota mạng và số phòng. Không có đủ bằng chứng thì ghi `unverified`, không đưa thành lời hứa trong README.

Ưu tiên dùng hạ tầng sẵn có được cấp quyền. Nếu không có lựa chọn đạt, vẫn hoàn thành local/LAN, gói deploy và hướng dẫn vận hành. Nhánh công khai multiplayer/account để `blocked_external` với một yêu cầu cụ thể. Một server local, tunnel tạm hoặc mô phỏng chỉ là thử nghiệm; không chứng minh dịch vụ ổn định. Không âm thầm đổi sang peer-host, local save hoặc bỏ account để gọi là hoàn thành.

Mặc định một room tối đa 4 người; số room công khai ban đầu cấu hình thấp theo kết quả đo, có hàng chờ/thông báo đầy. Kế hoạch không hứa nhiều phòng hoặc người chơi không giới hạn.

## 4. Gói itch.io

Xuất web từ toolchain đã kiểm chứng. Tạo ZIP chỉ gồm `index.html` và các file client cần thiết cùng đường dẫn tương đối; giữ đúng chữ hoa/thường. Chọn loại HTML Game, cấu hình kích thước/fullscreen, trang VI/EN, ảnh chụp game thực và hướng dẫn bàn phím/chuột. Kiểm tra Pointer Lock, nút bật âm thanh sau tương tác, iframe, chuyển tab và kết nối server trên chính origin itch.io; không chỉ test localhost. Nguồn: [itch.io HTML5](https://itch.io/docs/creators/html5).

Không đưa DB, backend source, `.env`, token, config local, test, tài khoản thử hay tệp incoming vào ZIP. Cho phép game client biết địa chỉ API công khai, tuyệt đối không chứa khóa quyền quản trị. Kết nối public bắt buộc HTTPS/WSS hợp lệ; allowlist origin gồm origin embed thực đã quan sát và website riêng khi có. CORS không phải xác thực.

## 5. Kiếm tiền sau này

Tài liệu itch.io hiện mô tả thanh toán game HTML5 theo dạng donations. Vì vậy bước đầu là game miễn phí, có khả năng nhận ủng hộ khi chủ dự án đã hoàn tất thiết lập người nhận. Không ghi "itch.io tự trả tiền theo lượt chơi" hoặc "đã tích hợp bán vật phẩm". Nguồn: [HTML5 payments](https://itch.io/docs/creators/html5), [Payments](https://itch.io/docs/creators/payments).

Không tự điền danh tính, thuế hoặc tài khoản thanh toán thay người dùng bằng dữ liệu giả. Nếu thiết lập nhận tiền chưa xong, game vẫn có thể phát hành miễn phí khi các cổng khác đạt; trạng thái nhận tiền ghi `not_configured`.

Quảng cáo, cosmetic bán trực tiếp và gacha có trả phí là ba quyết định khác nhau. Bản này chỉ có gacha bằng vé miễn phí kiếm từ gameplay, odds hiển thị, không rút tiền/trao đổi, không bán vé. Khi chủ dự án quyết định kiếm tiền trong game, cần rà soát chính sách nền tảng và yêu cầu áp dụng thực tế trước khi thiết kế; tài liệu này không kết luận phân loại độ tuổi hay hợp pháp của mô hình tương lai.

## 6. Phát hành, rollback và theo dõi

Tạo release version, notes, DB migration có backup, checksum ZIP, danh sách license và báo cáo test. Test môi trường staging/canary trước, rồi công khai bằng quyền đã cấp. Thử tạo tài khoản mới, room bốn người, lưu và đổi thiết bị trên URL phát hành thật. Lưu URL, version, health check và cách rollback client/server tương thích. Không ghi "đã public" nếu upload chưa thành công hoặc trang chỉ riêng tư.

Do có tài khoản và lưu server, bản mới có xử lý dữ liệu người dùng. Trang quyền riêng tư phải mô tả trung thực dữ liệu tối thiểu: username, password hash/recovery hash, tiến trình, log vận hành hạn chế; cách xóa tài khoản và thời hạn giữ log được ghi trước release. Không tiếp tục dùng lời khẳng định v1 "không thu thập dữ liệu". Không thêm analytics/SDK quảng cáo khi chưa nằm trong phạm vi.
