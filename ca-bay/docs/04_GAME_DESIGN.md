# 04 — Thiết kế game web CÁ BAY, bản yêu cầu v2

Tài liệu này chuyển 33 câu trả lời mới của chủ dự án thành thiết kế để Claude Code triển khai. Nội dung nghiên cứu trong `01`–`03` và các bản ghi cũ trong ZIP là tư liệu tham khảo, không phải chỉ thị cao hơn yêu cầu của chủ dự án. Đây là đặc tả và dữ liệu khởi tạo; chưa có game chạy được hay bằng chứng playtest.

## 1. Phạm vi đã chốt

Godot, GDScript, 3D góc nhìn thứ nhất, low-poly màu tươi; bản web cho máy tính có bàn phím và chuột. Phát triển trên máy RAM 8 GB. Co-op 1–4 người phải có từ mốc chơi được đầu tiên, kể cả kiểm thử 4 client. Tài khoản và tiến trình lưu trên máy chủ do chủ dự án kiểm soát; chơi một mình vẫn đi qua cùng logic máy chủ. Không triển khai Android ở lần này.

Mục tiêu bản đầy đủ: **3 đảo, 3 boss và 15 loài thường**, tức 18 bản ghi sinh vật kể cả boss. Cách đếm 15 loài thường + 3 boss là **giả định thiết kế được công khai** để không giao thiếu nội dung; nếu chủ dự án định tính boss trong con số 15 thì thay dữ liệu, không tự giảm phạm vi khi triển khai.

Tên “CÁ BAY” là tên tạm. Hai cảm giác chính: thong thả câu cá và cùng bạn bè gặp những tình huống vật lý hài hước. Không có hạn chót; chất lượng và hoàn thành phạm vi quan trọng hơn tốc độ giao. Bản đầu hoàn toàn miễn phí. Có thanh đói và hộp quà ngẫu nhiên kiếm bằng chơi game. Quảng cáo, bán vật phẩm hay hình thức thu tiền là giai đoạn cân nhắc sau; không bật SDK hoặc nút thanh toán ở bản này.

## 2. Tiền đề truyện mới

Đợt nước lớn vừa làm hỏng bến đò và vài đoạn cầu gỗ của một cụm cù lao hư cấu. Người chơi là người trong vùng quay về phụ sửa bến. Ban đầu mọi người góp các mẻ cá cho bếp đội thợ; sau đó khảo sát lại lạch triều để khôi phục tuyến đò ra cửa biển. Hội câu do xã tổ chức gây quỹ sửa nốt bến là chặng cuối.

Đây là cốt truyện được đề xuất để thực hiện yêu cầu “hợp lý, sát thực tế hơn”. Không có trà sữa làm biến đổi cá, không có nợ do người chơi đầu độc sông. Mưa, mực nước và thủy triều giải thích thay đổi cảnh vật và đường đi; không dùng đồng hồ thời gian thực để ép người chơi phải đăng nhập đúng giờ.

“Boss” là cá thể lớn khó bắt, không phải quái vật. Nhóm câu thành công sẽ chụp ảnh, đo đạc, nhận huy hiệu từ ban tổ chức rồi thả boss lại nước. Với cá thường, thao tác làm cá “xỉu” là hoạt hình phóng đại: sao quay, cú nảy và âm “bốp”, không máu, không nội tạng, không cảnh đáng sợ. Cung cá bay và hành vi vật lý phục vụ hài hước; tài liệu không mô tả chúng như hành vi sinh học thật hay hướng dẫn đối xử với động vật ngoài đời.

Lời thoại ngắn, ấm áp, hơi tỉnh bơ; tránh chế giễu vùng miền hoặc bắt người nước ngoài hiểu chơi chữ tiếng Việt. EN và VI đều đầy đủ. Thoại có phụ đề và bản đọc bằng tiếng đang chọn; âm ú ớ dùng như phản ứng ngắn. Thiếu bản thu chỉ cho phép tạm dùng phụ đề/âm tạm trong mốc phát triển, không được báo đã hoàn tất yêu cầu lồng tiếng.

## 3. Vòng chơi

**Câu → giật cá bay lên → dùng công cụ làm cá xỉu → nhặt/bán → nâng cấp → bắt boss → mở vùng mới.**

1. Chọn cần và mồi. Mồi bánh mì miễn phí vô hạn luôn có ít nhất một loài hợp lệ ở mọi đảo.
2. Giữ chuột để nạp lực, thả để quăng. Phao rơi đất tự thu, không mất mồi.
3. Cá rỉa rồi cắn. Bấm đúng lúc được Giật Chuẩn; tự dính khi hết cửa sổ cho loài dễ để người mới không nản.
4. Giữ để kéo. Cá cấp cao có dấu hiệu vùng vẫy; nhả kéo để giảm căng. Màu và âm báo cùng thể hiện trạng thái.
5. Cá lên gần bờ thì bay theo cung có điểm đáp an toàn. Camera/hoạt ảnh cục bộ có thể nhấn nhịp ngắn; tuyệt đối không làm chậm đồng hồ mô phỏng của cả phòng mạng.
6. Dùng tay, dép, chổi hoặc công cụ đã mở. Đánh khi đang bay và phối hợp tạo trick; không có sát thương đồng đội mặc định.
7. Cá xỉu hiện giá, trick và dấu chủ sở hữu. Người câu sở hữu phần thưởng; đồng đội được giúp đánh nhưng không cướp cá hoặc ghi đè người nhận tiền. Nhặt/bán/nộp đều do server xác nhận một lần.
8. Bán tại sạp, mua nâng cấp, góp nhiệm vụ, dùng đồ ăn khi đói. Hộp quà trang trí là lựa chọn bên cạnh; không dùng nó để mở đảo hay lấy mồi boss.

Tiền game “Vảy” không đổi ra tiền thật. Giá, sát thương, trọng số loài, thời gian và hệ số khởi tạo nằm trong `data/content/`; tất cả chưa được cân bằng bằng playtest. Mỗi lần KO chốt giá bằng số nguyên; tổng trick có trần. Không tính lại tiền khi client gửi lại một gói tin.

## 4. Co-op và tiến trình cá nhân

- Một phòng có 1–4 tài khoản; mã phòng riêng là mặc định. Giao tiếp ban đầu bằng ping/biểu cảm, chưa thêm chat chữ tự do hoặc voice chat trong game. Đây là lựa chọn triển khai để giữ phạm vi tập trung, không phải sở thích đã được chủ dự án xác nhận.
- Tiền, nhiệm vụ, độ no, kho đồ và skin lưu theo tài khoản. Vật bắt được có chủ sở hữu; trao đổi giữa người chơi chưa có ở bản đầu. Không dùng host-client làm nguồn sự thật cho kinh tế.
- Mọi người đủ điều kiện nhiệm vụ và tham gia encounter nhận ghi nhận boss riêng. Người vào muộn hoặc đứng ngoài encounter không nhận lại phần thưởng cũ. Vật nhiệm vụ là vật riêng của tài khoản, không để người khác nhặt mất.
- Mỗi đợt mở đảo của nhóm yêu cầu tất cả thành viên đã có điều kiện cá nhân. Đổi đảo bằng đồng thuận; người có tiến trình cao có thể quay lại giúp đảo cũ. Server không cho tài khoản mới đi thẳng tới đảo cuối chỉ vì trưởng phòng đã mở.
- Độ khó boss khóa theo số người tham gia lúc bắt đầu: `HP = ceil(base_hp × (1 + 0.45 × (n − 1)))`, với `n` từ 1 tới 4. Đồng hồ 240 giây không rút ngắn khi thêm bạn. Người rời phòng không tạo mẹo hạ HP tức thì. Các con số chỉ là điểm khởi đầu playtest.
- Mất kết nối xử lý bằng cửa sổ nối lại và chính sách tại `07_TECHNICAL_DESIGN.md`; tiền, đồ, hoàn mồi, phần thưởng không được nhân đôi. Không có kết quả boss vĩnh viễn phụ thuộc một người giữ vật cốt truyện rồi thoát.
- Khi mạng mất, client ngừng yêu cầu giao dịch và hiển thị trạng thái rõ. Không cho chơi ngoại tuyến tích lũy đồ rồi tự ghi đè server khi kết nối lại.

## 5. Đói vừa đủ tạo nhịp nghỉ

Thanh hiển thị **Độ no**, 100 là no và 0 là đói. Dữ liệu chuẩn nằm ở `hunger.json`:

- Bắt đầu 100; giảm 2 điểm mỗi phút **chơi tích cực**. Không giảm khi ngoại tuyến, trong sảnh, menu, tải cảnh, mất mạng, đang đánh boss hoặc AFK từ 120 giây. Không truy thu độ no sau khi đăng nhập lại.
- Dưới 25 chỉ giảm tốc kéo còn 90%; không chặn quăng cần, không gây sát thương, không mất tiền và không chết đói. Có thể hoàn thành mọi nhiệm vụ ngay cả khi thanh bằng 0.
- Cơm nắm miễn phí tại mỗi sạp hồi 35; giữ tối đa 3 phần miễn phí. Không bán hay trao đổi cơm. Khi đầy độ no thì không tiêu mất đồ ăn.
- Phần cá nướng hồi 60 độ no và 25 HP. Nấu cá là hệ thống phụ: giao dịch chuyển đúng một cá thuộc sở hữu sang một phần ăn, hoặc bán món cá theo giá nấu; không nhận cả phần ăn lẫn tiền từ cùng instance.
- Server xác nhận ăn và thay đổi chỉ số. Đồng hồ client, đóng/mở tab hay gửi lại yêu cầu không được tạo thêm thức ăn.

## 6. Gacha/lootbox miễn phí

Yêu cầu đã chốt là có gacha/lootbox. **Thiết kế bản đầu được chọn ở đây: hộp quà chỉ chứa màu trang trí công cụ, mở bằng vé kiếm qua chơi; không có tiền thật hay trao đổi.** Chủ dự án chưa chọn cơ chế gacha chi tiết; các luật này là giả định triển khai phù hợp ngân sách 0 đồng và bản đầu miễn phí.

`lootboxes.json` chứa một hộp `lootbox_ben_lang`, bảng phiên bản `1.0.0`, tốn 1 vé hội câu/lần. Mỗi nhiệm vụ hoàn thành lần đầu cho 1 vé; mỗi 10 cá thường do tài khoản câu và bán hợp lệ cho 1 vé. Bộ đếm bán là tổng server có kiểm tra instance, không nhận điểm từ client; nhiệm vụ chơi lại không tạo vé nhiệm vụ mới. Vé không mua bằng Vảy, tiền thật, quảng cáo, thẻ nạp hoặc chuyển từ tài khoản khác.

| Kết quả | Tỷ lệ |
|---|---:|
| Dép xanh sông | 40% |
| Dép xanh lá | 25% |
| Chổi hoàng hôn | 15% |
| Cần màu đồng | 10% |
| Cần xanh sông | 7% |
| Dép hồng chiều | 3% |

Tỷ lệ trên là tỷ lệ từng kết quả, tổng 100%, không có pity và không tăng/giảm bí mật theo người chơi. Bảng được hiển thị trước khi mở. Trùng màu đổi 10 bụi màu; dùng 30 bụi chọn trực tiếp bất kỳ màu nào. Trang trí không cộng sức mạnh; trúng màu của cần chưa sở hữu thì lưu trong bộ sưu tập chờ có cần. Mọi tiến trình chính có đường đạt chắc chắn không phụ thuộc hộp quà.

Server dùng RNG phù hợp, lấy số nguyên trong miền trọng số rồi ánh xạ bằng bảng phiên bản bất biến. “Xác định” ở đây nói về ánh xạ/bảng để kiểm thử, không phải seed công khai giúp client đoán kết quả. Một giao dịch nguyên tử gồm kiểm tra vé, trừ vé, chọn kết quả, cấp skin hoặc bụi, lưu sổ và trả kết quả. Khóa idempotency theo tài khoản/request; gửi lại cùng request phải nhận cùng kết quả, không trừ thêm vé. Ghi `table_version` vào lịch sử; thay tỷ lệ tạo phiên bản mới. Kiểm thử phải bao gồm rollback, hai yêu cầu đồng thời và mất mạng sau khi commit.

Hiệu ứng mở có nút bỏ qua, không dựng “suýt trúng”, không thông báo trúng thưởng toàn máy chủ, không đếm ngược khan hiếm giả. Đây là lựa chọn UX cho nhịp thư giãn. Không tuyên bố trước mức phân loại tuổi hoặc khả năng được nền tảng chấp nhận chỉ vì hộp quà miễn phí; kiểm tra yêu cầu phát hành tại mốc xuất bản.

## 7. Nội dung đầy đủ

| Đảo | 5 loài thường | Boss | Chuỗi nhiệm vụ và mở khóa |
|---|---|---|---|
| Cù lao Bến Làng — `isl_01_cu_lao` | Tép, cá rô, cua đồng, cá trê, cá mè | Lóc Già — `boss_ca_loc` | Bữa trưa đội sửa bến → Ghi nhận cá lớn → mở lạch dừa |
| Rừng Dừa Nước — `isl_02_rung_dua` | Cá thòi lòi, lươn, cá đối, cua bùn, tôm càng | Cua Cụ — `boss_cua_bun` | Khảo sát lạch triều → Cua Cụ bên cọc mốc → mở mũi đá |
| Mũi Đá — `isl_03_mui_da` | Cá nục, cá chuồn, cá trích, mực ống, cá hồng | Bớp Mũi Đá — `boss_ca_bop` | Hội câu Bến Làng → Mẻ cá cuối hội → bến mở lại, tiếp tục chơi tự do |

“Loài” trong phạm vi sản phẩm gồm cá và các sinh vật câu được như tôm, cua, mực. Mỗi đảo có hai bảng câu, điểm hồi sinh, sạp và điểm boss. Đảo 2 gồm lạch nước lợ cùng ao nước ngọt phía trong để phân bố loài hợp bối cảnh. Đảo 3 là vùng cửa biển; vùng câu có thể đặt biển chỉ dẫn thay vì dùng ID kỹ thuật làm tên hiển thị.

Các file nội dung đã có đủ định nghĩa cho 3 đảo, 18 sinh vật, 3 boss, 6 nhiệm vụ, 6 NPC, 3 sạp, 6 mồi, 2 cần, 6 công cụ và 11 trick. Trạng thái `slice`/`mvp` là thứ tự triển khai, **không chứng minh đã có code, cảnh hay tài nguyên**. Không còn đảo rỗng hoặc boss chỉ ghi “sẽ thiết kế sau”. `ends_vertical_slice` chỉ được harness test nội bộ dùng làm mốc; bản đầy đủ phải tiếp tục sang đảo 2.

ID `bait_milk_tea`, `var_boba`, các asset tương ứng được giữ để tương thích bộ gốc nhưng đổi nghĩa: mồi cá tạp, biến thể màu Ánh Bạc, vệt nước và họa tiết bạc. Không hiển thị từ “trà sữa”/“trân châu” ở gameplay. Không tái dùng mô hình ly hoặc viên trân châu thật khi hoàn thiện asset; thay nội dung asset dưới cùng ID.

## 8. Yêu cầu nghiệm thu gameplay

| Nhóm | Hành vi phải có trong bản phát hành đầu |
|---|---|
| REQ-CORE | Vòng chơi đầy đủ qua 3 đảo; boss cuối dẫn tới cảnh bến hoạt động và chơi tiếp; không soft-lock vì hết tiền, mồi, đồ ăn hoặc mất vật nhiệm vụ |
| REQ-FISH | Quăng/kéo/giật rõ phản hồi; mồi vô hạn; hoàn mồi boss đúng một lần ở mọi kết cục không thắng; bắt cá đầu tiên có thể đạt trong 60 giây |
| REQ-CRE | 15 loài thường phân biệt được bằng dáng/màu/hành vi và 3 boss; KO không máu; đồ nhiệm vụ thất lạc có cơ chế cấp lại |
| REQ-TOOL | 6 công cụ dùng được, sát thương/cooldown do server quyết định; tay không luôn có để tránh kẹt |
| REQ-SCORE | Trick được giải thích trong Sổ Cá, giá có trần, không gian lận qua gói tin hoặc làm tròn |
| REQ-INV | Thanh công cụ riêng với túi; mua/nộp/nhặt xử lý đầy túi rõ ràng; quyền sở hữu không thay đổi vì ai đánh đòn cuối |
| REQ-ECO | Bán vật theo instance duy nhất; cấm bán đồ nhiệm vụ/đồ ăn miễn phí; cấp công cụ/upgrades kiểm sở hữu toàn tài khoản |
| REQ-QUEST | 6 nhiệm vụ nối liên tục, mỗi tài khoản mở đảo đúng thứ tự, chơi một mình vẫn hoàn thành được |
| REQ-BOSS | Đòn báo trước rõ, phối hợp 4 người không làm timer ngắn hơn, hoàn mồi và thưởng được ghi sổ |
| REQ-HUNGER | Có thanh độ no, thức ăn, nhịp giảm khi active; 0 độ no không khóa tiến trình; không giảm offline |
| REQ-LOOTBOX | Có hộp quà/vé/bảng tỷ lệ/lịch sử, skin trùng đổi bụi, chọn màu trực tiếp; không tiền thật; giao dịch nguyên tử |
| REQ-COOP | Phòng riêng 1–4 tài khoản, join/leave/reconnect, đồng bộ câu/boss/đảo, không nhân đôi hoặc cướp phần thưởng |
| REQ-ACCOUNT | Tài khoản thật trên backend riêng, đăng nhập thiết bị khác lấy đúng tiến trình; lỗi đọc save không tự reset tài khoản |
| REQ-COOK/THIEF | Nấu cá và cò rình đồ phục vụ hài nhẹ; cò báo trước, không lấy đồ nhiệm vụ, không gây mất đồ vĩnh viễn |
| REQ-DEX | Sổ có 15 loài + 3 boss, trick, địa điểm, mồi; biến thể màu không tăng số loài |
| REQ-INPUT | WASD/chuột, khóa con trỏ theo thao tác người dùng, Esc trả con trỏ; phím tắt đổi đồ, tương tác và túi có chú giải |
| REQ-SET | Âm lượng nhạc/SFX/thoại riêng, phụ đề, độ nhạy, đảo Y, FOV, chất lượng, bật/tắt rung, kéo giữ hoặc bật/tắt |
| REQ-LOC/AUD | EN/VI không thiếu khóa, văn bản không nhúng vào ảnh, đủ nhạc/ambience/SFX/ú ớ/lời thoại đọc có phụ đề |
| REQ-PUBLISH | Chạy trong itch.io iframe và trang web riêng; phân phối HTTPS cùng backend WSS; kiểm tra quyền sử dụng toàn bộ asset trước đăng công khai |

Chi tiết kỹ thuật, state machine và test nằm ở `07`–`10`. Máy chủ hoặc tên miền chưa có không làm dừng xây dựng nội dung; nhưng bản localhost không được báo là đã phát hành công khai.

## 9. Mốc xây dựng và buổi thử một giờ

Mốc nội bộ đầu tiên gồm đảo 1 có đầy đủ câu/boss, **4 người kết nối**, tài khoản server, hunger và một hộp trang trí. Dùng hình khối/âm tạm để xác nhận mạng, quyền sở hữu, save và cảm giác câu trước khi nhân rộng. Đây là mốc kiểm chứng, không thay thế mục tiêu giao 3 đảo.

Mốc tiếp theo hoàn thiện đảo 2 và 3, sau đó thay toàn bộ placeholder còn ảnh hưởng nhận diện loài/NPC, hoàn thiện tiếng đọc EN/VI, tối ưu web và kiểm nghiệm công khai. Claude không tự đánh dấu “xong” cho tài nguyên chưa có hoặc API/dịch vụ chưa kết nối.

Buổi playtest của chủ dự án kéo dài tối đa 60 phút; dùng duy nhất lịch chi tiết trong 10_VALIDATION.md §4. Claude chuẩn bị account sạch và snapshot test để thấy đủ ba đảo trong buổi ngắn. Snapshot không phải bằng chứng người mới hoàn thành toàn campaign trong một giờ. Bot kiểm thử mạng có ích nhưng không thay đánh giá vui/dễ hiểu của người chơi thật.

Ngoài buổi này, Claude tự chạy smoke test, dữ liệu/schema, các giao dịch cạnh tranh và hành trình tự động qua đủ 3 đảo. Bản chơi còn thiếu lồng tiếng, thiếu backend công khai, hoặc chỉ thử 1 người phải ghi rõ hạn chế; không gọi đó là hoàn thành toàn bộ yêu cầu.
