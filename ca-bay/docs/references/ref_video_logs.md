> **NGHIÊN CỨU LỊCH SỬ V1.** Giữ nội dung gốc để tham khảo; chưa tái xác minh toàn bộ dữ kiện tại bản 2. Đây không phải chỉ dẫn triển khai. Android, chơi đơn trước, không đói, không lootbox, local save và cốt truyện cũ đã được thay bằng yêu cầu bản 2 trong `../00_START_HERE.md` và `../11_DECISIONS_AND_UNKNOWNS.md`. Phiên bản/giá/chính sách/capability công cụ phải kiểm tra lại khi dùng.

# Nhật ký video đã phân tích (tóm tắt có mốc thời gian)

> **Nguồn gốc dữ liệu:** các nhật ký dưới đây do công cụ Gemini (`gemini-3.8-flash`) xem video YouTube (hình + tiếng) và trả về; mình tóm tắt, diễn đạt lại và loại bỏ lời thoại nguyên văn của game. **Mình không tự xem từng khung hình.** Mọi mốc thời gian là của video, không phải của game. Chỗ Gemini ghi "uncertain" được giữ là *(không chắc)*.
> Dùng file này để **tra mốc thời gian khi cần xác minh bằng mắt**. Kết luận chính thức nằm ở `02_EVIDENCE.md`.

## S09 — Speedrun Any% 10:23 (video bạn gửi)

| Mốc | Nội dung quan sát (qua Gemini) |
|---|---|
| 00:00–00:11 | Menu chính: Host/Join/Character/Options/Credits/Quit + nút Discord; hộp tạo game có tên save, kiểu phiên (Invite Only), độ khó; góc dưới phải hiện **Version 1.0.12**. Âm thanh sóng biển, click UI. |
| 00:11–00:40 | Đảo 1 (hải đăng, xác tàu, ghế băng). Hộp hướng dẫn góc trên trái (di chuyển, nhìn, tương tác, ăn). Nhặt nghêu, "bán" bằng cách đưa vào miệng NPC, bóng chữ phản ứng ăn ngon. Bộ đếm tiền bắt đầu từ 0 và tăng từng ít. Đồng hồ speedrun (plugin) góc trên phải. |
| 00:36–01:34 | Trang bị cần, giữ nút chính để kéo cần ra sau rồi thả để quăng. Móc được boss cua nhện; prompt kéo: **giữ hoặc bấm liên tục chuột trái**; prompt thả sinh vật. Cua bị kéo lên sàn xác tàu, người chơi cất cần và đấm tay không. Thanh máu boss trên cùng, số sát thương nổi, popup "Killed …" kèm hệ số Melee. |
| 01:35–02:59 | Lên thuyền máy nhỏ, lái ra biển; thoát ra menu để tải lại ở đảo kế (mẹo speedrun). |
| 03:00–04:00 | Đảo 2 (rừng thông, lều gỗ, radio). Mua súng lục ở bảng vũ khí. Móc boss piranha khổng lồ, lên mái nhà bắn: chuỗi popup trick (One Shot One Kill ×1,25, Double Kill, Headshot, Fly Fishing, Quick Scope, Finally…), tổng hệ số khoảng ×4,7. Prompt đổi skin vũ khí (Z/C). |
| 04:01–04:44 | Nộp thịt + xương boss, lái thuyền qua biển động; menu hiện thông tin save (đảo 3, thời gian chơi). |
| 04:45–06:40 | Đảo 3 (bãi cát, dừa, ki-ốt cô bán hàng áo sọc đỏ, máy **Reel of Fortune** "cần sinh vật drip"). Mua Standard Lure $15, câu cá rồi bắn trên không lấy hệ số (Aerial, No Scope, Last Bullet…, tổng ~×7,7). Mua nhiều Dynamite ($25) + bật lửa, xếp bẫy, câu boss cá nóc và kéo vào bẫy nổ. Mua nâng cấp đạn ($200) và **Big Motor** ($230). *(không chắc: mồi dùng cho cá nóc được ghi là Hot Dog $1)* |
| 06:41–08:49 | Đảo 4 (nhà gỗ đỏ trên cọc, cầu gỗ, bàn roulette "đặt vật phẩm vào đây"). Mua Professional Lure ($50), ô túi đồ ($25), nhiều thuốc nổ. Câu boss cá ngừ, kéo lên đồi nổ chết; xác cá ngừ làm mồi gọi boss hải âu lớn (albatross), nổ chết giữa không. Bán thịt, tiền lên ~$3.964. |
| 08:50–10:23 | Đảo 5 (núi lửa, sông dung nham, trại quân sự). NPC đồ bảo hộ vàng; mua Scientific Lure ($500); nộp 5 món để nhận mồi đặc biệt *(không chắc: Gemini ghi là 5 lon bia và "Whale Bucket")*. Nhảy bằng thuốc nổ, câu cá voi đầu cong → hóa dạng "Mutated", nổ chết giữa không. Nhận chìa khóa, tương tác thuyền "về đất liền" → dừng đồng hồ 10:23. |
| 10:38–11:14 | Cảnh kết góc thứ ba: thuyền chạy về hoàng hôn, chữ cảm ơn, credits (thiết kế/lập trình/đồ họa: 2 nhà sáng lập; nhạc: Martin Weidenborn; hiệu ứng âm thanh: Patrik Carlsson, Alexander Fuentes, zapsplat.com; bản địa hóa: Lockit QA, Keywords Studios; cảm ơn: Landfall, Sweden Game Startup). |

## S10 — Walkthrough phần 1, không bình luận (81:20)

| Mốc | Nội dung quan sát (qua Gemini) |
|---|---|
| 00:00–00:07 | Mở đầu bằng tiếng xuồng cháy cạnh ghềnh đá, sóng biển. |
| 00:01–04:16 | Chuỗi hộp hướng dẫn "How to …": Move, Look, Interact (thử với con nghêu), Talk, Eat (giữ chuột phải khi cầm sinh vật để giảm đói), Sell (giữ Q ném vào miệng người bán), Buy (mua cần câu cua bằng E), Fish (nhìn ra nước, chuột trái để quăng), Kill (kéo bằng chuột trái, chuột phải để thả, X để cất đồ, chuột trái để đấm), Inspect (F xem giá trị), Think (Tab mở danh mục "đã bắt được gì"), Talk (nhận nhiệm vụ) → thông báo hết hướng dẫn, tự do chơi. |
| 00:06 | Người giữ hải đăng giao nhiệm vụ đầu: một sinh vật chân dài hay ăn trộm bia; gợi ý dùng lon rỗng làm mồi; hứa đổi thuyền nếu hạ được nó; nhắc dùng radar khi đi thuyền. (Diễn đạt lại, không trích nguyên văn.) |
| 02:04–13:30 | Câu cua/tôm để kiếm tiền. Thời gian từ lúc mồi chạm nước đến khi cắn **~4–7 giây** với mồi thường (ước lượng của Gemini). Cắn câu: tiếng "ting", chữ báo đã dính. **Không thấy thanh lực căng**, dây không đứt. Cá bay lên bờ và giãy; cua bò về nước hoặc quay lại tấn công. |
| 13:35–14:07 | Gọi boss cua nhện bằng lon bia rỗng; người chơi chết (màn hình "bạn đã chết", bấm để hồi sinh ở bờ gần thuyền; đồ rơi nằm tại chỗ). |
| 14:10–26:30 | Cày tiền, mua nắm đấm sắt ($24), dao ($45), mài dao ở đe ($14 → $28 → $36 → $84), mua radio cassette ($10). Chết thêm 1 lần với boss. |
| 26:40–33:00 | Hạ cua nhện bằng dao, nộp thịt/xác, nhận chìa khóa thuyền. |
| 33:00–41:55 | Lái thuyền, dùng radar màn hình xanh kiểu CRT để tìm đảo 2. Nhạc phiêu lưu vui khi chạy thuyền. |
| 42:00–81:20 | Đảo 2: cô gái nhờ nhặt 3 con đỉa làm mồi cho "cá to"; ông lão ngư dân gợi ý mua cần tốt hơn và bắn trick. Giá quan sát: Fishing Rod $3, Beginner Lure $3, Beginner Boss Lure $40, Pistol $50, Shotgun $150, Dynamite $25, Laser Sight $100, ô túi đồ $5, nâng đạn $15→$25→$35, Big Motor $230. Chết vì bầy piranha (48:26), chết vì thuốc nổ (74:00). Mini-boss cá mặt trăng (Sunfish) và boss cá chó già (The Old Pike). Nhạc đồng quê/banjo; đổi sang nhạc dồn dập khi đánh boss. |
| Toàn video | Biến thể hiếm "drip" thấy ở tôm, cua đá, cá gar. NPC nói bằng âm "lảm nhảm" (gibberish) + bóng chữ. Hải âu sà xuống cướp cá/thịt để trên đất. |

## S11 — Tổng hợp 10 boss và cảnh kết (23:50)

| Mốc | Boss | Quan sát chính (qua Gemini) |
|---|---|---|
| 00:12–01:25 | Cua nhện (đảo 1) | Gọi bằng lon bia từ cầu gỗ; chạy nhanh, nhảy vồ, kẹp; đánh bằng dao ~1 phút 10 giây; nổ thành khối "máu" voxel, rơi miếng thịt. Nhạc chuyển sang điện tử dồn dập khi xuất hiện. |
| 01:35–02:34 | Cá mặt trăng (đảo 2, phụ) | Bay/giãy lao vào người; hạ bằng shotgun + súng lục ~48 giây; xác nguyên con mang bán. |
| 02:47–03:54 | Cá chó già (đảo 2, phụ) | Bơi uốn lượn trong không khí, lao cắn; ~57 giây. |
| 04:04–07:29 | Piranha khổng lồ (đảo 2) | Bay, liên tục gọi bầy piranha nhỏ; ~3 phút 14 giây với shotgun; chuỗi trick liên tục. |
| 07:36–09:46 | Cá mập xanh (đảo 3, phụ) | Bay lượn ngang tầm đầu giữa hàng dừa, lao cắn; ~2 phút với súng tiểu liên. |
| 09:55–11:59 | Cá nóc (đảo 3) | Phồng thành quả cầu gai, nảy/lăn, phun gai/độc tím; ~2 phút. |
| 12:10–13:48 | Cá ngừ (đảo 4) | Bay cao, bổ nhào; hạ bằng súng bắn tỉa; khu có nhà gỗ đỏ và biển "Lucky Bait Casino". |
| 13:56–16:27 | Hải âu lớn (đảo 4) | Lượn vòng cao, sà xuống; hạ bằng súng bắn tỉa ~2,5 phút; rơi hộp quà. |
| 16:34–17:49 | Cá mập yêu tinh (đảo 5, phụ) | Trườn qua dung nham, bay, phóng hàm; súng trường. |
| 17:57–21:51 | Cá voi đầu cong → dạng đột biến (đảo 5) | Pha 1: bay vòng, thả đá; pha 2: xác cá voi rơi vào miệng núi lửa, trồi lên dạng nham thạch, nhanh hơn, cầu lửa; tổng ~3,5 phút; rơi vây cá voi. |
| 22:05–23:25 | Kết thúc | NPC trao chìa khóa thuyền về đất liền; cảnh thuyền chạy về hoàng hôn + credits, nhạc synthwave nhẹ. |
| 23:25–23:50 | Vòng lặp hài | Thuyền bất ngờ lật, màn hình đen, người chơi tỉnh lại ở đảo 1 cạnh xác thuyền mới, NPC hải đăng lặp lại lời thoại đầu game. |

Ghi chú UI của S11: thanh máu boss đỏ ở giữa trên cùng, có tên boss và một đoạn trắng "bám đuôi" khi mất máu; Gemini ghi "không thấy đồng hồ" — xem mâu thuẫn CF-07 trong `02_EVIDENCE.md`.

## S12 — Trailer gameplay (0:46, trước phát hành)

| Mốc | Quan sát (qua Gemini) |
|---|---|
| 00:00–00:02 | Thẻ tiêu đề: Dazed Games, "Q3 2026", thể loại; thẻ "Supported by Landfall" *(không chắc chính tả)*. |
| 00:02–00:05 | Cầu gỗ, cá bị giật bay lên, bắn shotgun cự ly gần; máu dạng khối voxel; popup: hệ số ×1,20 cho biến thể tên "Ultra …" *(không chắc)*, +10% Quick Scope, +10% Point Blank; tiền ~$8.543. |
| 00:05–00:11 | Bắn tỉa cá bay trên trời; ống ngắm tròn hạ hải âu đang ngậm cá: +25% Headshot. |
| 00:15–00:18 | Nổ dưới nước làm cả đàn cá văng lên: "Killed 3× …", **+50% Explosive**. |
| 00:18–00:29 | Súng tiểu liên, chuỗi trick "Dogfight / Headshot / Endangered Species / Finally" (×2,05); radar màn hình xanh; boss piranha. |
| 00:35–00:46 | Thẻ tên game. Nhạc: điện tử nhịp nhanh, vui, hỗn loạn; SFX súng phóng đại, "hit marker" kiểu arcade. |
