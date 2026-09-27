# 05 — MỸ THUẬT, GIAO DIỆN VÀ ÂM THANH V2

> Đây là đặc tả cần xây dựng, chưa phải bộ tài nguyên đã sản xuất. Quyết định mới của chủ dự án ghi trong bộ v2 thay thế đề xuất khác biệt trong tài liệu gốc. Thông số file và registry nằm ở `06_ASSET_BIBLE.md`; bàn giao qua ChatGPT ở `14_AI_ASSET_HANDOFF.md`.

## 1. Định hướng đã chốt

Game câu cá web trên máy tính, Godot, 3D low-poly, góc nhìn thứ nhất, chơi đơn hoặc nhóm 1–4 người. Bản hoàn chỉnh gồm 3 đảo, 15 loài sinh vật thường và 3 boss. Thế giới là một làng chài Việt Nam đời thường: bến nước, chợ cá, ghe gỗ, rừng dừa và mũi đá. Câu chuyện xoay quanh người dân, nghề cá và sự phục hồi sinh hoạt của làng theo `04_GAME_DESIGN.md`.

Khối lớn, màu phẳng, nắng ấm, mặt ngộ nghĩnh và động tác rõ. Hài đến từ phản ứng của nhân vật, cá quẫy và công cụ dân dã. Không ma thuật, đột biến trân châu, boss uống trà sữa hay hiệu ứng phép thuật. Không máu me; khi choáng dùng sao, bọt nước và nét biểu cảm. Boss là sinh vật khỏe và khó câu trong cùng thế giới, không quái vật siêu nhiên.

Tài nguyên phải nguyên bản hoặc có nguồn và quyền sử dụng phù hợp. Không trích xuất, đồ lại hoặc sao chép sát nhân vật, logo, hình ảnh và âm thanh của game tham khảo. Tài liệu tham khảo giải thích nguyên tắc thiết kế, không cấp quyền dùng tài nguyên của bên khác.

## 2. Hình khối và đọc hình

| Nhóm | Thiết kế | Điều kiện đọc hình |
|---|---|---|
| Người dân | Đầu lớn vừa phải, thân chắc, áo bà ba/sơ mi, nón hoặc khăn; da và quần áo đa dạng | Nhìn phân biệt được vai trò và NPC từ màu áo, dáng, phụ kiện; không chỉ dùng màu |
| Tay người chơi | Bàn tay hoạt hình 4 ngón, cổ tay áo; dụng cụ ở góc phải dưới | Tâm ngắm và cá đang bay luôn nhìn rõ |
| Đồng đội | Thân đầy đủ cùng ngôn ngữ hình khối; áo/chỉ dấu người chơi khác nhau | Đọc được hướng nhìn, dụng cụ và hành động; nhân vật mình không che camera |
| 15 loài thường | Đặc điểm nhận dạng thật được giản lược, mắt lớn có tròng trắng | Mỗi loài phân biệt được bằng hình bóng: thân, vây, râu, càng hoặc xúc tu |
| 3 boss | Cá Lóc, Cua Bùn, Cá Bớp theo dữ liệu gameplay; lớn hơn sinh vật thường | Báo trước đòn bằng tư thế, vùng tác động và âm; không dựa riêng màu |
| Công cụ | Cần tre, dép, chổi và dụng cụ đã có trong dữ liệu | Điểm cầm và đầu làm việc rõ, không tạo cảm giác vũ khí hiện đại |
| Môi trường | Khối đơn giản, cạnh vát, cây dừa lá tam giác, nhà gỗ/lá | Vật tương tác nổi bật hơn phông nền; bến có lối đi đủ 4 người |

Chiều dài loài lấy từ `data/content/creatures.json`; không lấy chiều dài từ concept AI. Ảnh concept không được coi là mô hình 3D hay animation dùng ngay trong game.

## 3. Bảng màu

| Nhóm | Màu | Dùng cho |
|---|---|---|
| Trời | `#5EC8F2`, `#CDEFF7` | Trời đỉnh và chân trời |
| Nước | `#1F7A8C`, `#3FB8AF`, `#F4F1DE` | Nước sâu, nông, bọt |
| Phù sa | `#9C8455` | Nước và đất đảo 1, pha có kiểm soát |
| Đất và cây | `#E9C98B`, `#8D6A4A`, `#7CC24A`, `#3E8E3A` | Cát, bùn, cỏ, lá |
| Gỗ | `#9C6B3F`, `#6B4428`, `#C8A160` | Bến, sạp, mái |
| Tín hiệu | `#E4473C`, `#FFC93C`, `#6CC24A` | Phao/nguy hiểm, tiền/phần thưởng, thành công |
| Vảy bạc | `#B8C4C8`, `#E8ECE8` | Biến thể Ánh Bạc, phản chiếu nhẹ không phát sáng |
| Da | `#F1C27D`, `#D9A066`, `#A86B3C` | Các NPC và người chơi |
| Quần áo | `#B79AD9`, `#9FB7C9`, `#8A5A3C`, `#2B2B2B` | NPC, đồng đội, tùy biến mỹ phẩm |
| Mắt | `#FFFFFF`, `#111111` | Tròng trắng, con ngươi |
| Tre/nón | `#B8A05A`, `#D9C27A` | Cần tre, nón |
| UI | `#22313A`, `#FFF8E7`, `#1B1B1B` | Panel tối 85% đục, chữ, viền |
| Nắng | `#FFF1D6` | Ánh sáng mặt trời |

Đảo 1 ấm và có phù sa, đảo 2 xanh lá và bùn, đảo 3 xanh biển lạnh. Sinh vật giữ nhận dạng tự nhiên. Mỹ phẩm đổi phối màu được nhưng không che mắt, báo trước boss, phao hoặc tín hiệu nguy hiểm.

## 4. Vật liệu và ánh sáng

Dùng vertex color, flat shading, vật liệu chung nhám. Một nguồn sáng mặt trời với bóng giới hạn; chất lượng thấp dùng bóng giả đơn giản. Tránh chi tiết texture nặng, hiệu ứng hậu kỳ bắt buộc và shader phụ thuộc tính năng chưa thử trên web. Chất lượng cuối được quyết định bằng phép đo trong `10_VALIDATION.md`, không bằng lời hứa hiệu năng.

## 5. Nước

Mặt nước low-poly với sóng nhỏ. Phao đỏ–trắng và vòng gợn phải đọc được ở khoảng cách câu thực tế. Có bọt bờ và vệt nước theo chuyển động, không giả lập chất lỏng nặng. Màu nông/sâu có thể nướng vào đỉnh. Không dùng màu hay độ trong khiến người chơi nhầm vùng đứng được.

## 6. Sinh vật và boss

Lấy đúng 15 loài và 3 boss từ dữ liệu, không tự thêm biến thể làm tăng số loài nghiệm thu. Boss báo trước bằng chuyển trọng tâm, giương càng, quật đuôi hoặc lấy đà. Đòn phun chỉ là nước; projectile kỹ thuật mang tên cũ vẫn phải nhìn như nước. Pha sau nhanh/khó hơn theo dữ liệu, không mọc bộ phận phép thuật.

Biến thể `var_boba` cũ được giữ ID để tương thích nhưng tên hiển thị là **Ánh Bạc**: những mảng vảy bạc tự nhiên, không vòng hạt trân châu. `mdl_item_milk_tea` và `ico_bait_milk_tea` là mồi cá tạp, không phải cốc trà sữa. Bảng tương thích chi tiết nằm trong `06`.

## 7. Camera và chuyển động

Góc nhìn thứ nhất, tối ưu chuột/bàn phím máy tính. FOV, độ nhạy và hiệu ứng rung theo thiết kế kỹ thuật; có tùy chọn giảm rung/giảm chuyển động. Không rung camera đồng đội khi người khác đánh cá. Cảnh 4 người vẫn phải thấy dây câu, phao và báo trước boss của mình. Không triển khai điều khiển cảm ứng như điều kiện hoàn thành v2.

## 8. Animation

Cấu trúc bộ phận cứng và animation bằng code/track được chấp nhận làm bản cuối nếu đẹp, nhẹ, đúng socket và nghiệm thu. Quăng cần có chuẩn bị–vung–dư âm; giật cá phải có phản lực; đi đứng không trượt chân rõ rệt. Đồng đội có idle, đi, chạy, câu, kéo, dùng đồ và ngã/đứng dậy theo trạng thái mạng đã xác nhận. Clip chỉ trình bày, không tự quyết sát thương hay phần thưởng.

## 9. VFX

Nước bắn, bụi, vài mảnh confetti, sao choáng và chữ tượng thanh là lớp phản hồi nhẹ. Chúng không xác nhận thay logic máy chủ. Hiệu ứng lootbox chỉ chạy sau kết quả nhận thưởng hợp lệ. Không tạo cảnh quay thưởng đánh lừa như suýt trúng vật hiếm; có thể bỏ qua animation và xem kết quả trực tiếp. Hiệu ứng hiếm là phản chiếu/ngôi sao UI ngắn, không ma thuật trong thế giới.

## 10. UI máy tính

- Tâm: tâm ngắm, căng dây, nhắc thao tác và báo cắn; trung tâm không bị banner che.
- Mép trái: máu, đói và mục tiêu; đói có icon/nhãn và ngưỡng, không chỉ đổi màu.
- Mép phải: tiền, thông tin phiên, danh sách đồng đội và trạng thái kết nối.
- Dưới: công cụ, mồi, túi đồ; phím tắt hiển thị rõ.
- Menu: phòng co-op, cài đặt, phụ đề/giọng, bộ sưu tập và mỹ phẩm miễn phí.

Lootbox phải nói rõ nguồn kiếm miễn phí, xác suất theo dữ liệu gameplay, vật phẩm chỉ thay ngoại hình và quy tắc đồ trùng. Không cửa hàng tiền thật, mua lượt mở hay quy đổi tiền mặt. Mặc định không làm UI di động; ID cũ cho cảm ứng chỉ lưu tương thích.

Chữ Việt/Anh là khóa dịch, không in sẵn trên ảnh. Be Vietnam Pro là ứng viên phông; phải có file thật và kiểm tra giấy phép khi lấy. Chưa có font thì dùng font hệ thống/engine hỗ trợ dấu để tiếp tục và ghi thiếu tài nguyên. Icon vật phẩm render từ chính mô hình đã duyệt. Không dùng concept AI khác hình mô hình làm icon cuối.

## 11. Âm thanh và lời thoại

| Lớp | Hướng sáng tác và sản xuất |
|---|---|
| Nhạc đảo | Giai điệu nguyên bản giản dị, acoustic/tổng hợp nhẹ; đảo 1 khoảng 90–100 BPM, đảo khác biến tấu riêng |
| Nhạc boss | Nhịp vui căng vừa phải, khoảng 120–140 BPM; không nhạc kinh dị |
| Âm nền | Nước, gió, côn trùng/chim, ghe xa theo đảo; vòng lặp không lộ điểm nối |
| SFX | Cần tre, phao, dây, cá quẫy, bước chân, đồ ăn, UI và co-op; ngắn, dễ phân biệt |
| Gibberish | Âm tiết hư cấu nguyên bản theo nhân vật; dùng cho phản ứng hoặc fallback phát triển |
| Thoại rõ nghĩa | Thoại cốt truyện và hướng dẫn được viết, dịch và thu/tổng hợp riêng cho tiếng Việt và tiếng Anh |

Cắn câu > báo trước boss > thông tin sinh tồn khẩn > thoại đang nghe > các âm khác. Giảm nhạc khi cắn câu, cảnh báo hoặc thoại; giới hạn âm chồng nhau khi 4 người chơi. Có volume riêng Master, Music, SFX, UI, Ambience, Voice; phụ đề luôn có lựa chọn bật. Cho phép bỏ qua thoại, không khóa mục tiêu vào âm thanh.

Ngân sách sản xuất hiện tại là 0. Claude tạo SFX/nhạc gốc bằng code xuất file **offline**, dùng ghi âm của người đồng ý hoặc công cụ miễn phí có giấy phép phù hợp. Không dựa vào tổng hợp audio runtime trên web khi chưa kiểm chứng. Giấy phép chương trình TTS và giấy phép model/giọng là hai việc riêng phải kiểm tra. Không hứa ChatGPT Plus xuất nhạc, SFX, giọng hay mô hình 3D nếu phiên đó không có khả năng này.

Phạm vi thoại gồm cả 6 NPC trong dữ liệu: Cô Ba, Ông Tư, Bảy Chợ, Cô Tám, Nam Sáu và Chị Lan; mỗi NPC có pack Việt và Anh riêng theo `14`.

Phụ đề + gibberish giúp bản phát triển chạy được, nhưng **không đáp ứng yêu cầu lồng tiếng Việt/Anh cuối cùng**. Chưa có giọng hợp lệ phải báo số dòng thiếu theo ngôn ngữ và giữ hạng mục voice chưa hoàn thành.

## 12. Điều kiện duyệt

Một tài nguyên chỉ được coi hoàn thành khi có file thật, đúng kỹ thuật `06`, nguồn/quyền rõ, hoạt động trong Godot web và khớp phong cách. Bản cuối phải có đủ 3 đảo/15 loài/3 boss, hình đồng đội, đói, mỹ phẩm và các lớp âm thanh. Bộ thoại được đối chiếu từng dòng × hai ngôn ngữ; không lấy số lượng file gibberish để lấp coverage thoại.

## 13. Bảng kiểm nhìn và nghe

Kiểm tra hình bóng loài, màu/phao dễ đọc, chữ Việt không lỗi, icon đúng model, không chi tiết trà sữa hoặc phép thuật, UI 4 người không chồng, vùng nguy hiểm không bị hiệu ứng che, âm cắn nghe rõ, loop không click, thoại khớp phụ đề và nút bỏ qua hoạt động. Lưu bằng chứng chụp/quay/nghe thật; không chuyển tài nguyên `planned` thành `approved` chỉ vì đã viết đặc tả.
