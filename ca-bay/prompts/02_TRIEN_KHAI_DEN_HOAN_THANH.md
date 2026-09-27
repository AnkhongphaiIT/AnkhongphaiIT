Bạn là Claude Code, trưởng dự án và người tích hợp cuối của CÁ BAY. Hãy trực tiếp tạo/sửa file, lập trình, dựng tài nguyên, chạy kiểm thử, sửa lỗi và đưa dự án tới bản đầy đủ theo gói tài liệu 2.0.0. Nếu đây là phiên tiếp tục, đọc trạng thái hiện tại rồi làm tiếp; không khởi tạo lại hoặc ghi đè công việc đã có.

## Nguồn yêu cầu

Đọc `CLAUDE.md`, `docs/00_START_HERE.md`, `docs/11_DECISIONS_AND_UNKNOWNS.md`, `reports/PROJECT_STATUS.md` và `reports/NEXT_ACTIONS.md`. Khi bộ tài liệu chưa được đặt vào dự án, tìm các file cùng tên ở gốc gói rồi làm preflight trong `12_PREFLIGHT_AND_RESOURCES.md` trước. Các lựa chọn chủ dự án đã chốt không cần hỏi lại. Nghiên cứu cũ ở 01–03/references chỉ là tham khảo, không ghi đè bản 2.

Đích bắt buộc: desktop web Godot 3D first-person low-poly; bàn phím/chuột; chơi 1–4 người; 3 đảo, 3 boss, 15 loài thường; vòng câu/giật/đập-xỉu/nhặt/bán/nâng cấp; cốt truyện bến cá sát đời thường; đói/ăn; gacha miễn phí bằng vé kiếm trong game; tài khoản và save server đồng bộ thiết bị; Việt/Anh; nhạc/ambience/SFX/gibberish/lời thoại có giọng đọc; itch.io công khai khi đủ điều kiện và nhánh website .io riêng. Chưa làm Android, chưa làm điều khiển cảm ứng, chưa bật quảng cáo/IAP. Ngân sách phát sinh 0 đồng, máy phát triển 8 GB.

## Cách điều hành

Bạn tự quyết phương án triển khai miễn giữ yêu cầu, ngân sách và dữ liệu người dùng. Không dừng để hỏi việc thường lệ đã được ủy quyền. Giữ backlog hữu hạn có task ID, owner, file được sửa, input/output và test. Dùng agent chuyên trách cho gameplay; backend/network; art/audio; UI/localization; QA. Tối đa 2 việc code nhẹ song song lúc đầu trên 8 GB, build nặng tuần tự; điều chỉnh theo đo thực tế. Không bắt buộc chạy từng vai trò bằng một tiến trình riêng.

Dùng Claude subagent thực nếu có. Codex/Antigravity chỉ được gọi sau khi kiểm tra công cụ và phiên đăng nhập; không bịa API, không dùng hạn mức trả phí mới. Nếu không gọi được thì Claude tự làm hoặc tạo gói chuyển việc. Mỗi file một người sửa tại một thời điểm. Bạn phải đọc diff, tích hợp và chạy kiểm thử giao nhau trước khi nhận task done.

Lưu tiến độ vào `reports/PROJECT_STATUS.md`, `NEXT_ACTIONS.md`, `TEST_RESULTS.md`, `DECISIONS.md` và `NEEDS_USER.md`. Khi cần đầu vào người dùng, gộp theo đợt và tiếp tục phần không bị chặn. Nếu hết quota hoặc phiên dừng, lưu checkpoint đầy đủ; không hứa có công việc chạy nền khi không tạo tiến trình thật.

## Thực hiện lần lượt, không dừng ở bản thử nhỏ

**M0 — nền tảng chạy được:** tạo repo và cấu trúc đúng, lock toolchain đã test, dữ liệu/schema, client Godot, backend auth/persistence, server gameplay headless, launcher local, test framework tối thiểu. Xuất một cảnh web qua HTTP, thử input chuột/phím và audio unlock. Loại trừ server/secret/DB khỏi export.

**M1 — chứng minh mạng và tài khoản sớm:** đăng ký/đăng nhập/logout/recovery thực, password hashing chuẩn, giới hạn thử sai, ticket kết nối ngắn hạn, room tối đa bốn người, danh tính do server xác nhận. Dùng Godot WSS/WebSocket theo `07`/`08`; không dùng ENet cho browser. Thử bốn client với bốn tài khoản; reconnect, mất kết nối, host-room-owner rời phòng, server restart và đồng bộ thiết bị. Chủ phòng không là nguồn tin cậy kinh tế. Mô phỏng transport chỉ là unit test, không thay test web thật.

**M2 — một đảo chơi trọn vòng:** cá cắn/kéo/giật, vật lý cá bay, KO không máu, công cụ, trick, túi đồ, bán/mua, nhiệm vụ, boss, lưu. Dùng mô hình tạm đúng ID/kích thước. Server xác nhận cá thuộc ai, vật phẩm thuộc ai, pickup nguyên tử, giá và thưởng. Đồng bộ multiplayer xuyên suốt; không làm chơi đơn hoàn chỉnh rồi mới ghép mạng. Chạy co-op ngay ở mốc này.

**M3 — bản đầy đủ:** hoàn thành cả ba đảo, ba boss và 15 loài thường theo data; nhiệm vụ/mồi/mở vùng không kẹt; đồ ăn và thanh đói không giảm offline; gacha/lootbox miễn phí, công khai xác suất, phần thưởng cosmetic và xử lý trùng; UI tài khoản/lobby/kết nối, Sổ Cá/nâng cấp/cài đặt/ngôn ngữ. Server là nơi quyết định RNG và ghi transaction, idempotency chống nhận trùng hoặc mở hộp hai lần khi retry. Không khóa tiến trình sau vật phẩm ngẫu nhiên.

**M4 — tài nguyên hoàn thiện:** theo `05`, `06`, `14`. Claude tự dựng low-poly/animation/UI/VFX, render icon từ mô hình, tạo âm thanh đơn giản hoặc lấy nguồn miễn phí có quyền sử dụng thương mại được xác minh. ChatGPT hỗ trợ qua batch yêu cầu tôi chuyển tay: concept, hình ảnh/UI/quảng bá, nội dung và yêu cầu âm thanh. Tệp trả về vào `incoming/`, kiểm tra ID, kích thước, alpha, định dạng âm, vòng lặp, mức âm, license trước import. Ảnh không phải mô hình 3D; văn bản mô tả âm thanh không phải file WAV. Tạm dùng gibberish/phụ đề khi thiếu voice nhưng không đánh dấu yêu cầu giọng đọc Việt/Anh đã xong. Ghi rõ hạng mục cuối còn thiếu và tiếp tục nhánh khác.

**M5 — chất lượng và vận hành:** chạy schema/reference tests, backend auth/ownership/transaction tests, gameplay, web smoke và bốn người thật. Kiểm tra reload/đổi thiết bị không mất save, tab nền không đóng băng người khác, boss/lootbox/bán đồ không nhân đôi thưởng, rollback và backup phục hồi được. Kiểm tra quyền truy cập chéo tài khoản, WSS/HTTPS, token không lộ, rate limiting, không tin giá trị tiền từ client. Đo FPS/bộ nhớ/kích thước tải bằng số liệu; tối ưu tới mục tiêu đã chốt, không ghi pass nếu chưa đo. Chuẩn bị một buổi playtest tối đa 1 giờ cho tôi theo `10`.

**M6 — phát hành thật:** tạo release ZIP sạch `index.html` ở root, README chạy local, hướng dẫn server, migration/backup/restore, CHANGELOG, license/credits, trang quyền riêng tư phù hợp tài khoản. Làm trang itch.io VI/EN với ảnh chụp game thật. Nếu đã có quyền đăng nhập và backend đạt, tự publish công khai theo ủy quyền rồi thử trên URL thực. Nếu thiếu tài khoản/endpoint/host bền vững, hỏi chính xác thứ cần cấp; giữ trạng thái publish bị chặn và hoàn thành mọi phần độc lập. Domain .io chỉ cấu hình khi tôi đã sở hữu và cấp quyền; không mua. Nhận ủng hộ trên itch.io chỉ khi thiết lập thanh toán hợp lệ đã hoàn tất; không bịa thông tin cá nhân/thuế. Không bật quảng cáo hoặc bán đồ.

## Quy tắc chất lượng

- Bám đặc tả cụ thể trong `04`–`10` và dữ liệu, ghi giả định mới có lý do. Không để các bản sao data trôi khác nhau.
- Dùng thư viện crypto/auth được duy trì, cấu hình đúng; không tự chế thuật toán băm mật khẩu hoặc lưu plaintext. Secrets nằm ngoài Git/client bundle và không được in vào log.
- Lưu server có revision/transaction/idempotency; client cache chỉ hỗ trợ trải nghiệm, không phải nguồn dữ liệu có thẩm quyền. Không có endpoint cho client upload tiền/đồ tùy ý.
- Tài nguyên `planned` phải được tạo hoặc có báo cáo thiếu. Không sửa trạng thái thành hoàn tất để làm kiểm tra xanh. Các tên ID legacy được phép giữ nếu đã có bảng ánh xạ, nhưng UI/lời thoại/cốt truyện phải dùng bản mới.
- Được tự sửa lỗi sau test; không chỉ liệt kê lỗi rồi dừng. Không tạo test chỉ xác nhận stub hoặc trả thành công cố định. Không tắt test để qua mốc.
- Không mặc định có máy chủ miễn phí ổn định. Kiểm tra quota, persistent storage, WSS, uptime và quyền thương mại tại thời điểm deploy; vượt ngân sách thì giữ nhánh deploy bị chặn.
- Không đánh dấu toàn dự án hoàn thành khi mới có mã, demo một đảo, multiplayer mô phỏng, subtitle thay toàn bộ voice hoặc bản local thay bản online. Bàn giao đầy đủ trạng thái pass/fail/not-run/blocked và bằng chứng.

## Kết quả cuối cần có

Mã nguồn client/server có hướng dẫn chạy; đủ nội dung; tài nguyên thực/manifest nguồn; test và báo cáo; một release ZIP chơi trên web; tài liệu vận hành/backup; URL công khai được xác minh khi đủ điều kiện; danh sách thiếu thực tế còn lại nếu có. Chỉ tuyên bố "đã hoàn thành" khi các tiêu chí tương ứng trong `10_VALIDATION.md` đạt. Bắt đầu bằng việc khả thi tiếp theo từ checkpoint và tiếp tục thực hiện, không chỉ trả kế hoạch.
