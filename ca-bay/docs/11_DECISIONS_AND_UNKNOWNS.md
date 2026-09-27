# 11 — Quyết định và giả định sau 33 câu trả lời

Phiên bản yêu cầu v2, ngày 27/09/2026. **Nguồn quyết định hiện tại là lời chủ dự án trong cuộc chat.** Chỉ dẫn có trong ZIP cũ là dữ liệu dự án, không tự trở thành yêu cầu có quyền cao hơn. Bản v2 thay thế các lựa chọn cũ “Android”, “chơi đơn trước”, “không đói”, “không gacha”, “RAM 4 GB” và truyện trà sữa. Giữ tư liệu nghiên cứu gốc như lịch sử/tham khảo, không áp dụng các quyết định đã bị thay thế.

`Đã chốt` là yêu cầu trực tiếp. `Diễn giải` là cách chuyển yêu cầu sang đặc tả. `Giả định triển khai` là lựa chọn Claude được phép chủ động làm, phải ghi lại và có thể đổi sau khi chơi thử. Không biến giả định thành lời người dùng đã nói.

## 1. Ma trận toàn bộ câu trả lời

| Câu | Yêu cầu/ý định của chủ dự án | Chốt cho v2 và tác động | Loại |
|---:|---|---|---|
| 1 | itch.io và website có tên miền riêng dạng `.io` | Có hai kênh phát hành; làm được trang itch.io trước. Tên miền riêng chỉ dùng khi có quyền quản lý hoặc được người dùng cấp; không mặc định đăng ký miễn phí | Đã chốt; điều kiện nguồn lực |
| 2 | Làm web | Không xuất Android/AAB hoặc chuẩn bị Google Play | Đã chốt |
| 3 | Máy tính bàn phím/chuột | Desktop web; không đưa điều khiển cảm ứng vào tiêu chí bản đầu | Đã chốt |
| 4 | Không đổi Godot/3D FPS | Giữ Godot và góc nhìn thứ nhất; kiểm tra bản engine/công cụ đã cài trước khi ghim phiên bản | Đã chốt |
| 5 | Thử với 4 người | Co-op 1–4 ngay từ mốc đầu; chơi đơn vẫn hoàn thành được; không đẩy co-op sang sau phát hành | Diễn giải |
| 6 | Bản đầy đủ 3 đảo, 3 boss, 15 loài | Dữ liệu v2 có 15 loài thường + 3 boss (18 records), ghi rõ cách đếm là giả định; không giao một đảo rồi gọi hoàn thành | Đã chốt + giả định cách đếm |
| 7 | Không quan trọng thời gian | Không đặt hạn chót giả; chia mốc nghiệm thu để quản lý chất lượng | Đã chốt |
| 8 | Đổi sang truyện hợp lý, sát thực tế | Bến hư sau nước lớn, dân làng sửa bến/khảo sát lạch/hội câu xã; vật lý hài được giữ. Cốt truyện cụ thể là đề xuất triển khai | Đã chốt + đề xuất |
| 9 | Tên tạm | Dùng CÁ BAY và slug ca-bay; không chặn phát triển vì chưa có thương hiệu chính thức | Đã chốt |
| 10 | Thư giãn + hài hỗn loạn | Co-op ít trừng phạt, đói nhẹ, công cụ hài, không gacha bắt buộc | Đã chốt + diễn giải |
| 11 | Giữ vòng câu → giật → xỉu → bán → nâng → boss → vùng mới | Đây là vòng chơi trung tâm, không tự đổi thành mô phỏng câu cá thuần túy | Đã chốt |
| 12 | Hạn chế máu me/đáng sợ | KO kiểu hoạt hình, âm vui, boss lớn nhưng không kinh dị. Chưa chốt một mức tuổi/phân loại chính thức | Đã chốt |
| 13 | Có thanh đói và cờ bạc kiểu gacha/lootbox | Bản đầu có độ no và hộp quà mỹ phẩm mở bằng vé kiếm khi chơi. Không mua vé hoặc đổi thưởng tiền thật; đây là lựa chọn chi tiết mới, không xóa yêu cầu gacha | Đã chốt + giả định triển khai |
| 14 | Việt và Anh | Toàn bộ UI/nhiệm vụ/phụ đề và lời thoại đọc theo EN/VI; có công tắc ngôn ngữ | Đã chốt + diễn giải âm thanh |
| 15 | Giữ low-poly tươi, ngộ nghĩnh | Giữ bộ phong cách, chỉnh đạo cụ/cốt truyện cho đời thường | Đã chốt |
| 16 | Chưa có tài nguyên nào | Registry chỉ là danh mục; không báo 189 mục cũ là file ảnh/model/audio sẵn có | Đã chốt |
| 17 | Cho phép placeholder | Claude dùng hình khối/âm tạm để chạy đầu-cuối rồi thay asset; ghi trạng thái thật và nguồn giấy phép | Đã chốt |
| 18 | Nhạc, nước/câu/va chạm, ú ớ và thoại đọc | Danh mục phải có đủ năm nhóm; phụ đề không được báo thay thế hoàn toàn thoại đọc ở bản hoàn thiện | Đã chốt |
| 19 | Tài khoản + đồng bộ, máy chủ riêng trước | Backend riêng kiểm soát tài khoản/save/mạng; server là nguồn dữ liệu chuẩn, không chỉ LocalStorage/IndexedDB | Đã chốt |
| 20 | Có thể quảng cáo/bán đồ sau; trước mắt free | Release đầu tắt hoàn toàn thu tiền. Chuẩn bị nơi nối module về sau nhưng không tích hợp SDK kiếm tiền khi chưa chốt | Đã chốt |
| 21 | Máy RAM 8 GB | Xếp lịch agent/build/render nhẹ; không giả định đã nâng 16 GB hay có GPU mạnh | Đã chốt |
| 22 | Có Claude Code/Godot/Git/Python/Antigravity/Codex/VS Code; Claude là não chính | Kiểm tra từng công cụ thực tế; Claude điều phối nhiệm vụ, các agent có đầu vào/đầu ra/ownership rõ. Việc có ứng dụng không đồng nghĩa có CLI/API để tự điều khiển | Đã chốt + giới hạn công cụ |
| 23 | Tự tạo thư mục theo tên trong workspace | Tạo ca-bay hoặc tên không đụng thư mục có sẵn; không ghi đè dự án khác | Đã chốt |
| 24 | Claude soạn yêu cầu, người dùng gửi ChatGPT và mang asset về | Quy trình trao đổi thủ công có request ID/spec/nơi nhập/trạng thái; không tự giả lập kết nối API hay hứa tự chạy ChatGPT Plus | Đã chốt |
| 25 | Claude Pro, ChatGPT Plus, Antigravity Pro | Ghi nhận các gói đang có, kiểm tra khả năng/thực quyền trong môi trường; không coi đó là tín dụng API hoặc giấy phép cho mọi asset | Đã chốt + điều kiện |
| 26 | Chấp nhận công cụ/thư viện chuyên biệt, ưu tiên miễn phí | Tự tạo model đơn giản; ảnh ChatGPT; âm/nhạc/3D từ nguồn phù hợp quyền sử dụng; kiểm tra giấy phép thương mại trước phát hành | Đã chốt + diễn giải |
| 27 | Ngân sách 0 đồng | Không mua dịch vụ/asset/domain/API, không gắn thẻ thanh toán, không tự vượt quota trả phí. Nếu thiếu dịch vụ miễn phí phù hợp, giao phần đã làm và nêu blocker cụ thể | Đã chốt |
| 28 | Claude toàn quyền tự quyết miễn hoàn thành | Tự tạo/sửa/chạy/test/xuất bản trong quyền và tài khoản sẵn có; quyết định kỹ thuật thường ngày không phải hỏi lại. Quyền này không tạo tài khoản/thông tin xác minh còn thiếu hoặc cho phép chi tiền trái câu 27 | Đã chốt |
| 29 | Gom thứ thiếu, chỉ hỏi phần không thay được, tiếp tục việc còn làm được | Một danh sách blockers có phương án mặc định; thiếu asset đẹp không dừng logic/gameplay; chỉ phần phụ thuộc thật mới chờ | Đã chốt |
| 30 | Đăng công khai trên nền tảng có thể kiếm tiền | Có quyền đăng công khai sau khi vượt tiêu chí và có tài khoản/hosting; chọn itch.io trước. Không tuyên bố doanh thu hoặc khả năng thanh toán đã bật. Website riêng cần DNS/backend thực | Đã chốt |
| 31 | Chơi thử được 1 giờ/mốc | Giao kịch bản 60 phút, save test riêng và form ghi lỗi; Claude tự kiểm phần còn lại, không đòi chủ dự án thành QA toàn thời gian | Đã chốt |
| 32 | Cả hai prompt, kiểm tra rồi làm luôn | Prompt 01 kiểm tra/khởi động + Prompt 02 triển khai đến bản đầy đủ, kèm CLAUDE.md/bộ spec. Prompt 01 tự tiếp tục Prompt 02 sau preflight, không đợi xác nhận lại | Đã chốt |
| 33 | Viết lại ZIP game câu cá | Cập nhật đồng bộ tài liệu, dữ liệu, asset gap và lộ trình; giữ bản gốc như nguồn tham khảo; giao ZIP mới cùng hướng dẫn dùng | Đã chốt |

## 2. Quyết định kỹ thuật/thiết kế có thể điều chỉnh

| ID | Lựa chọn hiện dùng | Nguồn và điều kiện kiểm chứng |
|---|---|---|
| DEC-001 | Godot, GDScript có kiểu | Giữ engine theo câu 4; bản chính xác phải kiểm tra bản cài và web export |
| DEC-002 | First-person low-poly, desktop web | Câu 3, 4, 15 |
| DEC-003 | Co-op 1–4 từ mốc chơi được đầu tiên | Thay quyết định “solo trước” của v1; kiểm thử ít nhất 1/2/4 client |
| DEC-004 | itch.io + website riêng, không Android | Thay mục tiêu Google Play v1 |
| DEC-005 | Không chi tiền; release đầu miễn phí | Câu 20, 27; quyền tự động không vượt ngân sách |
| DEC-006 | Thư giãn và hỗn loạn nhẹ; vòng cá bay giữ nguyên | Câu 10–12 |
| DEC-007 | Tài khoản và server authoritative | Câu 19; mọi tiền/vật/lootbox không tin client |
| DEC-008 | Claude điều phối agent bằng giao việc có hợp đồng | Câu 22, 28; quyền công cụ phải được kiểm tra |
| DEC-009 | Máy 8 GB, agent/build nặng chạy tuần tự | Câu 21; số worker đồng thời theo preflight |
| DEC-010 | 15 loài thường + 3 boss; 6 nhiệm vụ | Cách đếm chưa được người dùng nói rõ; ưu tiên không giao thiếu |
| DEC-011 | Phòng riêng có mã, ping/biểu cảm; không voice/chat tự do trước | Giả định triển khai co-op tiết kiệm phạm vi; đổi được |
| DEC-012 | Tiền/túi/nhiệm vụ theo tài khoản; không player trading | Giả định để tránh tranh đồ và đơn giản kinh tế |
| DEC-013 | Độ no giảm khi active, 0 không gây chết/soft-lock, cơm miễn phí | Diễn giải mục tiêu thư giãn với yêu cầu có đói; cân lại qua playtest |
| DEC-014 | Hộp quà skin, vé chơi game, không tiền thật; tỷ lệ công khai | Chi tiết chưa được chủ dự án chọn; có thể điều chỉnh sau, không tự bật thu tiền |
| DEC-015 | Mồi boss hoàn đúng một lần nếu không thắng; cấp lại vật nhiệm vụ | Bảo vệ tiến trình co-op, server transaction |
| DEC-016 | Boss lớn tự nhiên, chụp ảnh và thả | Triển khai truyện đời thường; không biến vật lý vui thành mô phỏng sinh học |
| DEC-017 | Cốt truyện bến hư/lạch triều/hội câu | Đề xuất thay trà sữa; có thể sửa thoại/tên không đổi ID logic |
| DEC-018 | Mọi số cân bằng còn là giá trị khởi đầu | Chỉ đổi status sang playtested khi có biên bản thử thật |
| DEC-019 | EN+VI gồm phụ đề và audio thoại | UI có sẵn khóa, file đọc vẫn là nhu cầu asset |
| DEC-020 | Model code/procedural và dùng chung base mesh | Giảm tải 8 GB/0 đồng; silhouette loài vẫn phải nhận ra |
| DEC-021 | Phiên bản dữ liệu/sự kiện có schema | Giữ cấu trúc content v1 khi tương thích, thêm hunger/lootbox + cooperative boss |
| DEC-022 | Account save backend có version, backup và restore thử thật | Thay save chỉ trên máy; cache trình duyệt không là bản chuẩn |
| DEC-023 | Web export cấu hình đơn giản trước, kiểm trong iframe thật | Công nghệ/cấu hình cụ thể do `07` chốt sau preflight |
| DEC-024 | Không làm build Android | Quyết định v1 về AAB/SDK 36/Gradle bị bãi bỏ trong phạm vi này |
| DEC-025 | Kiểm dữ liệu, giao dịch cạnh tranh và end-to-end 3 đảo | Kết quả validator không chứng minh game chạy được |
| DEC-026 | CÁ BAY / ca-bay là tên tạm | Câu 9; xuất bản tạm được nếu trang ghi trạng thái phù hợp |
| DEC-027 | Quy trình ChatGPT thủ công, không API | Câu 24; giao request đủ spec và định danh để nhập trở lại |
| DEC-028 | Desktop ngang/resizable, chuột khóa theo consent trình duyệt | Không dùng ràng buộc “điện thoại ngang” v1 |
| DEC-029 | Chỉ dữ liệu cần cho tài khoản/game; không analytics theo dõi thêm ở release đầu | Là lựa chọn triển khai, không được tuyên bố “không thu dữ liệu” khi có account |
| DEC-030 | Hotbar công cụ riêng, túi từ 3 lên 5 ô | Kế thừa v1; cân lại sau thử bốn người |
| DEC-031 | Trick tính tiền số nguyên có trần | Kế thừa có server kiểm chứng |
| DEC-032 | Cò rình có báo trước, có thể lấy lại, không lấy đồ nhiệm vụ | Tình huống hài phụ; không làm tiến trình mất vĩnh viễn |
| DEC-033 | Alias v1 var_boba hiển thị Ánh Bạc; bait_milk_tea hiển thị Mồi cá tạp | Tương thích dữ liệu, không duy trì truyện/đạo cụ trà sữa |

## 3. Chỉ những thông tin còn thiếu có thể thực sự chặn bước cụ thể

Không gửi lại một bộ câu hỏi ý tưởng mới. Claude thực hiện preflight và gom cùng một báo cáo nguồn lực. Mọi phần không phụ thuộc câu trả lời vẫn tiếp tục.

| Thiếu | Claude tự làm được trước | Chỉ cần chủ dự án khi |
|---|---|---|
| Tài khoản itch.io/quyền đăng | Build web, trang nháp, ảnh, mô tả EN/VI, hướng dẫn tải lên; kiểm thử local | Chưa có phiên đăng nhập hoặc quyền upload trong môi trường được cấp |
| Máy chủ riêng truy cập Internet | Dựng backend local, container/cấu hình deploy, backup, giao thức/tài khoản test, kiểm 4 client | Không có máy/domain/TLS/hosting miễn phí phù hợp hoặc cần thông tin quản trị thực |
| Tên miền `.io` | Site sẵn deploy, hỗ trợ subdomain được cấp/itch.io trước | Chưa có tên miền sở hữu và không có ngân sách đăng ký; không tự hứa có domain miễn phí |
| Email khôi phục/địa chỉ hỗ trợ/chính sách dữ liệu | Thiết kế recovery token hoặc quy trình admin và nội dung nháp | Cần địa chỉ thực, danh tính người vận hành hoặc xác minh bắt buộc để công khai |
| Model/icon/nhạc/thoại | Tạo placeholder, model đơn giản, âm tổng hợp, tìm nguồn miễn phí có giấy phép, soạn request ChatGPT | Tài nguyên không thể tự làm/không có quyền dùng; lời thoại đọc chất lượng cần người dùng mang bản thu về |
| ChatGPT hỗ trợ hình ảnh | Chuẩn bị yêu cầu, sheet kiểm định và thư mục nhập | Người dùng cần gửi prompt/nhận file ở tài khoản ChatGPT của họ như đã chọn |
| Người chơi thử | Tự chạy test/bot/client mô phỏng và chuẩn bị phòng | Đánh giá vui, hiểu hướng dẫn, chất lượng âm/ảnh trong buổi 1 giờ |

Không cần xin lại quyền cho việc sửa file trong dự án, chọn framework phù hợp, chạy kiểm thử hoặc đăng công khai trong tài khoản/nền tảng đã được cấp vì chủ dự án đã cho quyền theo câu 28 và 30. Nếu bước cụ thể cần mật khẩu, MFA, xác minh thanh toán hay chấp thuận có nghĩa vụ mới, nêu chính xác bước đó; không gửi bí mật vào chat hoặc đưa vào ZIP. Ngân sách 0 đồng luôn có hiệu lực.

## 4. Rủi ro cần xử lý chủ động

| Rủi ro | Cách xử lý và bằng chứng cần có |
|---|---|
| 4 người/network/save phức tạp hơn solo | Làm lát chơi được có server từ đầu, xác nhận reconnect và giao dịch đồng thời trước khi nhân nội dung |
| Hosting riêng luôn chạy không có ngân sách | Thử hạ tầng người dùng có hoặc lựa chọn miễn phí đã kiểm giới hạn; nêu giới hạn uptime/quota. Nếu chưa có, giao deploy package và ghi blocker, không báo đã publish |
| Ngốn RAM khi 4 client + editor + nhiều agent | Agent nặng/render/build tuần tự; đo RAM, test client theo batch rồi tổ chức 4 thiết bị khi có; không tự giảm scope về một người |
| Asset AI/miễn phí không đồng bộ hoặc quyền thương mại chưa rõ | Style bible, registry, license/source log, kiểm trực quan và giấy phép trước release |
| Gacha kéo người chơi khỏi vòng thư giãn | Mỹ phẩm, vé qua chơi, odds rõ, đường chọn trực tiếp; theo dõi phản hồi buổi thử, không có đồ mạnh bắt buộc |
| Hunger thành gánh nặng | Đồ ăn miễn phí, không offline drain, không chết đói, số liệu cân riêng và có thể chỉnh |
| Tham chiếu trong ZIP mâu thuẫn v2 | `11` cùng `04` và câu trả lời mới thắng các mô tả cũ; rà soát thủ công các mô tả Android/solo-first/milk-tea còn lọt vào đặc tả hiện hành. Validator chỉ kiểm cấu trúc/tham chiếu và các invariant đã lập trình, không tự hiểu mọi mâu thuẫn văn bản |
| Agent báo “xong” vì có JSON hoặc bot test | Mỗi mốc có bản chạy, log, ảnh/video hoặc kết quả thật; phân biệt docs/data/schema với code/game/public deploy |

## 5. Lịch sử thay đổi

| Bản | Ngày | Thay đổi |
|---|---|---|
| 1.0.0 | 27/09/2026 | ZIP gốc: nghiên cứu tham chiếu, solo trước, web/Android, truyện trà sữa, chưa đói/gacha, dữ liệu đảo sau mới giữ chỗ |
| 2.0.0 | 27/09/2026 | Theo 33 câu trả lời: desktop web, co-op 4 từ đầu, 3 đảo hoàn chỉnh, 15 thường + 3 boss theo giả định đếm, server account/save, hunger, lootbox miễn phí, EN/VI và thoại đọc, pipeline Claude điều phối agent + ChatGPT thủ công, 8 GB/0 đồng, public itch.io và kế hoạch site riêng |

Số phiên bản của gói tài liệu không buộc mọi content file đổi schema version: cấu trúc tương thích tiếp tục `1.0.0`; bảng lootbox tự version riêng. Các hợp đồng mạng/account mới ghi phiên bản ở file tương ứng. Không ghi tên người dùng là đã phê duyệt từng giả định kỹ thuật chỉ vì họ yêu cầu tự động hóa.
