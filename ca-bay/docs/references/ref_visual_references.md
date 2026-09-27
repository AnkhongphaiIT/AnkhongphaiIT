> **NGHIÊN CỨU LỊCH SỬ V1.** Giữ nội dung gốc để tham khảo; chưa tái xác minh toàn bộ dữ kiện tại bản 2. Đây không phải chỉ dẫn triển khai. Android, chơi đơn trước, không đói, không lootbox, local save và cốt truyện cũ đã được thay bằng yêu cầu bản 2 trong `../00_START_HERE.md` và `../11_DECISIONS_AND_UNKNOWNS.md`. Phiên bản/giá/chính sách/capability công cụ phải kiểm tra lại khi dùng.

# Bảng tham chiếu hình ảnh (game gốc) — có nguồn

> **Mục đích:** giúp agent mỹ thuật/UI hiểu *vì sao* phong cách game gốc dễ đọc và buồn cười, để **học nguyên tắc**, không sao chép hình dạng, nhân vật, màu nhận diện hay bố cục cụ thể. Định hướng riêng của game mới nằm ở `05_ART_BIBLE.md`.
> **SS1–SS7:** mình xem trực tiếp (nguồn S13). **V-xx:** quan sát qua Gemini (S09–S12) — cần xác minh bằng mắt nếu dùng làm quyết định lớn.

## 1. Ảnh chính thức trên Steam (S13)

URL gốc có dạng `https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/4001890/<id>/ss_<id>.1920x1080.jpg`

| Mã | id ảnh | Cảnh | Quan sát trực tiếp | Nên học | Không nên sao chép |
|---|---|---|---|---|---|
| SS1 | 48f6817fe466a7c9666605527558bf1fac48d0d2 | Đảo rừng thông, góc nhìn thứ nhất cầm cần câu | Cần màu xanh–đen có guồng, tay thấp đa giác; bảng gỗ treo hàng bán (mồi xanh, súng lục, dao, thuốc nổ đỏ, nắm đấm sắt); NPC ông lão ngồi ghế, người chơi khác áo liền quần cam có tên nổi trên đầu; cây thông, cỏ dạng khối | **Cửa hàng "diegetic"** (hàng hóa là vật thể thật treo trên tường, không cần menu); silhouette vật phẩm rõ ở khoảng cách 3–5 m | Bảng vũ khí thật; nhân vật đầu trọc da vàng mắt lồi áo cam |
| SS2 | 5f867d8c9b03c63867cc95b7bfaa4a3d2193ea48 | Bãi biển đảo 3, đánh boss cá nóc | Cá nóc khổng lồ nâu, gai tam giác, mắt trắng tròn; số sát thương trắng chồng nhau; "máu" là khối lập phương đỏ; vỏ đạn vàng; hạt tím dạng pixel. **HUD:** góc dưới trái ô tiền viền trắng bo tròn (`$6052`), dưới là 2 vòng tròn (tim = máu, dao dĩa = đói); hotbar giữa dưới 7 ô đánh số + ô **B "Bait"** có số lượng (5); ô đang chọn to hơn, viền trắng, có tên bên dưới; biểu tượng vật phẩm là **ảnh render 3D** | Thứ tự ưu tiên HUD: tiền–máu–đói nhỏ ở góc, hotbar to ở giữa; ô mồi tách riêng; hiệu ứng trúng đòn to, rõ, "vui mắt" | Máu voxel đỏ (không hợp PEGI 12 cho game mới); icon dao/súng |
| SS3 | 2a912cdbf746286400cece1ca607ac077c11a1dc | Bãi biển, vừa giật cá lên | Tay phải cầm cần đen, tay trái quay guồng; cá bạc treo lơ lửng giữa không trung ở đầu dây; người chơi khác chĩa súng vào con cá; không HUD | **Khoảnh khắc "cá treo giữa trời"** là điểm nhấn thị giác của cả game; cá phải đọc được trên nền trời | Tư thế bắn cá bằng súng |
| SS4 | e15ab15c09cd3f6ec06d4ffacdf07f6c2b679db2 | Bếp nướng trên bãi cát | Vỉ nướng đỏ lớn, than phát sáng cam; khói là **khối cầu thấp đa giác màu trắng**; NPC tạp dề nâu; mặt nước là các tam giác phẳng thấy rõ mặt cắt, viền bọt trắng ở bờ | Khói/lửa làm bằng hình khối đơn giản vẫn đọc tốt; nước phẳng chia mặt (flat-shaded) rẻ mà đẹp | Bố cục/hình vỉ nướng y hệt |
| SS5 | 65be87272efaa4bac87e16dc764a9535165effd2 | Quầy hàng đảo 3 | Người chơi đưa con hải âu cho cô bán hàng (áo sọc đỏ trắng, mũ sọc); vũ khí treo tường; cần câu dựng cạnh quầy | Hành động **bán = đưa vật thể cho NPC** đọc được ngay không cần chữ | Cô bán hàng áo sọc, hành động nhét vào miệng |
| SS6 | 3c10ad99000bdcf9cd99509de59d2a1351496690 | Người chơi bay giữa rặng dừa | Nhân vật bị hất tung, tư thế ragdoll, tay cầm cần | Hài vật lý: cơ thể bị hất tung là "meme" tự nhiên | — |
| SS7 | 57f53b814c84511019f86aa89cedaed37148dcfa | Hoàng hôn, cầm súng bắn tỉa mạ vàng | Mặt trời tròn hơi vỡ điểm ảnh, biển xanh chia mặt, cỏ khối nhỏ; ánh sáng xanh lạnh buổi chiều | Một cảnh "đẹp để chụp" với bảng màu hạn chế; skin vàng cho vật phẩm hiếm | Súng mạ vàng |

**Tổng kết phong cách game gốc (S13, S23):** low-poly phẳng (flat-shaded), màu bão hòa vừa, ánh sáng mặt trời mềm có bóng đổ, gần như không có texture chi tiết; nhân vật và sinh vật hình khối đơn giản, mắt tròn to; hiệu ứng khối lập phương/pixel; icon vật phẩm render 3D.

## 2. Tham chiếu từ video (qua Gemini — cần xác minh bằng mắt)

| Mã | Nguồn + mốc | Nội dung | Nên học |
|---|---|---|---|
| V-01 | S09 00:36–01:34 | Chuỗi quăng → dính → kéo → sinh vật bay lên bờ | Nhịp một lần câu rất ngắn; phản hồi âm thanh "ting" khi dính |
| V-02 | S09 03:00–04:00; S12 00:18–00:29 | Popup chuỗi trick xếp chồng, tổng hệ số lớn dần | Hiển thị từng dòng trick + tổng; dùng âm thanh tăng cao độ |
| V-03 | S10 00:01–04:16 | Hộp hướng dẫn góc trên trái, mỗi hộp một động từ | Dạy từng động từ một, ngắn |
| V-04 | S10 33:00–41:55; S12 00:21 | Radar cầm tay màn hình xanh kiểu CRT | Công cụ điều hướng "vật lý" thay minimap |
| V-05 | S11 04:04–07:29 | Boss bay + gọi đàn cá nhỏ | Boss = sự kiện có nhạc riêng, thanh máu trên cùng |
| V-06 | S11 17:57–21:51 | Boss chuyển dạng (pha 2) với đổi màu phát sáng | Báo hiệu đổi pha bằng màu/ánh sáng |
| V-07 | S11 22:36–23:50 | Cảnh kết + cú lật thuyền quay lại đầu game | Cái kết "meme" tự giễu |

## 3. Cần bổ sung nếu muốn xác minh bằng mắt (tùy chọn)

Nếu bạn có thời gian, chụp màn hình 4 mốc sau rồi gửi mình (mỗi ảnh 1 lần là đủ): S09 00:40 (prompt kéo cần), S09 03:40 (popup trick), S10 02:10 (hộp hướng dẫn "How to Kill"), S11 05:00 (thanh máu boss + đoạn trắng). Mục đích: đóng mâu thuẫn CF-04 và CF-07.
