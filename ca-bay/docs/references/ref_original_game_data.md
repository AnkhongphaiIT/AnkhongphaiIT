> **NGHIÊN CỨU LỊCH SỬ V1.** Giữ nội dung gốc để tham khảo; chưa tái xác minh toàn bộ dữ kiện tại bản 2. Đây không phải chỉ dẫn triển khai. Android, chơi đơn trước, không đói, không lootbox, local save và cốt truyện cũ đã được thay bằng yêu cầu bản 2 trong `../00_START_HERE.md` và `../11_DECISIONS_AND_UNKNOWNS.md`. Phiên bản/giá/chính sách/capability công cụ phải kiểm tra lại khi dùng.

# Dữ liệu trích từ game gốc "How to Fish" (CHỈ ĐỂ THAM CHIẾU)

> ⚠️ **Đây là dữ liệu của game gốc, không phải dữ liệu của game mới.** Không nhập các con số/tên dưới đây vào `data/`. Dữ liệu game mới là giá trị khởi đầu tự thiết kế (xem `data/README.md`).
> Mỗi dòng có nguồn (`01_SOURCES.md`) và mức tin cậy: **C** = cao (≥2 nguồn độc lập hoặc nguồn chính thức), **TB** = trung bình (1 nguồn tốt hoặc video qua Gemini), **T** = thấp (1 nguồn yếu/mâu thuẫn).

## 1. Dòng thời gian phiên bản

| Ngày (2026) | Bản | Nội dung đáng chú ý cho thiết kế | Nguồn | Tin cậy |
|---|---|---|---|---|
| 20/08 | 1.0.0 (phát hành) | Giảm 38% trong 1 tuần; mô tả 1–4 người | S03, S01 | C |
| 21/08 | 1.0.4 | Lobby tối đa 8 người; nerf boss cá nóc & cá voi; làm rõ đường lên đảo cuối; sửa đồng hồ boss hiển thị mãi; sửa chữ hồi sinh khi người chết tự hồi sinh lúc đang bị bế | S03 | C |
| 22/08 | 1.0.5 | Đảo trục nhìn, lobby riêng tư, bỏ khóa di chuyển đảo | S04, S34 | TB |
| 23/08 | 1.0.6 | Kiểm tra file save trước khi tải; chỉ lưu khi bấm Save/Main Menu/Quit, **tự lưu mỗi phút** | S03 | C |
| 24/08 | 1.0.8 | Biểu tượng tay cầm PlayStation; âm lửa theo thanh âm lượng FX | S04 | TB |
| 24/08 | 1.0.9 | **Độ khó**: Easy = sinh vật −25% máu, −50% sát thương; Hard = +25% máu, +25% sát thương; công cụ kiểm tra kết nối Steam relay; "hy vọng" sửa hỏng save | S03 | C |
| 27/08 | 1.0.10 | Vũ khí/dụng cụ dính bẩn khi nấu được rửa sạch khi nhúng nước; **vật phẩm rơi được lưu (tối đa 64, ưu tiên vũ khí, dụng cụ, vật phẩm nhiệm vụ, sinh vật)**; nerf cá lồng đèn; sửa roulette, radar, lỗi hải âu và người chơi cùng nhặt đồ; giới hạn vận tốc nổ; bỏ rich text trong chat | S03 | C |
| 02/09 | 1.0.11 | Steam Deck Verified, GeForce NOW; tùy chọn bật/tắt kiểu "toggle" cho ngắm, chạy, tấn công; tắt tên trên đầu; nerf ống giảm thanh | S04 | TB |
| 04/09 | 1.0.12 | Lưu qua Steam Cloud; cân bằng piranha, nerf cá ngừ; giới hạn vận tốc vật phẩm; cập nhật "MetaVoice 4.3"; sửa giới hạn FPS khi chơi mạng | S04, S34, S09 (menu hiện 1.0.12) | TB |

## 2. Chuỗi tiến trình đảo – nhiệm vụ – boss

| Đảo (tên theo hướng dẫn, không chắc là tên trong game) | NPC/nhiệm vụ chính | Mồi gọi boss chính | Boss chính → boss phụ | Vật phẩm mang về → mở khóa | Nguồn | Tin cậy |
|---|---|---|---|---|---|---|
| 1 — Hải đăng | Người giữ hải đăng bị "sinh vật chân dài" trộm bia | Lon bia rỗng (mua bia $12, nhờ NPC uống hộ) | Cua nhện | Xác/thịt boss → chìa khóa thuyền | S14, S10, S11, S16 | C |
| 2 — Rừng thông | Cô gái cần 3 con đỉa làm mồi cho "cá to"; ông lão gợi ý trick | Đỉa đã xử lý (Modified Leech) | Piranha khổng lồ → phụ: cá chó già (Beginner Boss Lure), cá mặt trăng | Xương piranha → tọa độ đảo 3 | S14, S16, S20, S10, S11 | C |
| 3 — Sa mạc/nhiệt đới | Du khách muốn "bơi trong kỳ nghỉ", cần một con cá mang cờ **endangered** | Cà rốt (đổi từ du khách) | Cá nóc → phụ: cá mập xanh (Standard Boss Lure) | Vây cá nóc → tọa độ đảo 4 | S21, S20, S16, S11 | TB (mâu thuẫn CF-03) |
| 4 — Đá/casino | (Casino "Lucky Bait", roulette) | Professional Boss Lure → cá ngừ; **xác cá ngừ làm mồi** | Cá ngừ → hải âu lớn | → đảo 5 | S16, S09, S11, S14 | C |
| 5 — Núi lửa | Nhà khoa học đồ bảo hộ cần 5 món | "Fish Bucket" (S16) / "Whale Bucket" (S09 qua Gemini) | Cá voi đầu cong → dạng đột biến; phụ: cá mập yêu tinh | Chìa khóa thuyền về đất liền → cảnh kết | S14, S16, S09, S11 | TB (mâu thuẫn CF-02) |

## 3. Loài theo đảo – cần – mồi (theo S16, đối chiếu một phần với S10/S11)

S14 cảnh báo danh sách loài trên các trang hướng dẫn tuần đầu có mâu thuẫn → **toàn bảng: TB/T**.

| Đảo | Loài thường (mồi) | Ghi chú |
|---|---|---|
| 1 | Cua đá, tôm (mồi miễn phí); tôm hùm (Hot Dog) — cần câu cua | S10 thấy thêm "cua nâu", nghêu nhặt tay |
| 2 | Cá thu, gar, pike, cá tuyết, cá vàng, cá rô châu Âu, cá bò (Free/Beginner Lure); piranha (Hot Dog) | S10 thấy biến thể drip ở gar |
| 3 | Cá thần tiên, cá hộp, cá da trơn, nhím biển, cá ngựa, cá hề, bluegill, cá hồi, cá kim (Standard Lure) | Cá "endangered" dùng cho nhiệm vụ du khách |
| 4 | Cá vẹt, "Voxelfish", cá vược, cá bơn, lươn, cá hổ, cá chuồn, cá hồng… (Professional Lure) | |
| 5 | Cá lồng đèn, cá giọt nước, cá mái chèo, cá đá… (Scientific Lure) | |

## 4. Giá đã quan sát

| Vật phẩm | Giá | Nguồn | Tin cậy |
|---|---|---|---|
| Bia | $12 | S09, S14, S10 | C |
| Radar | $10 | S15, S09, S10, S14 | C |
| Thuốc nổ (1 cây) | $25 | S15, S09, S10 | C |
| Shotgun | $150 | S15, S10 | C |
| Big Motor (nâng động cơ thuyền) | $230 | S09, S10 | C |
| Standard Lure | $15 | S09, S21 | C |
| Professional Lure | $50 | S09 | TB |
| Scientific Lure | $500 (S24 nói mồi đảo 5 từ $500 đến $5.800) | S09, S24 | TB |
| Hot Dog | $1 | S09, S10 | TB |
| Súng lục | $50 | S10 | TB |
| Nắm đấm sắt / Dao | $24 / $45 | S10 | TB |
| Mài dao (4 cấp) | $14 → $28 → $36 → $84 | S10 | T |
| Ô túi đồ | $5 (đảo 2, S10) / $25 (đảo 4, S09) — có thể tăng dần | S10, S09 | T |
| Nâng sát thương đạn | $15 → $25 → $35 (S10); $200 (đảo 3, S09) | S10, S09 | T |
| Laser sight | $100 | S10 | T |

Giá bán tham khảo: nghêu $1 (S24, S10); cua/tôm hùm $4–10 (S24); boss bán hàng nghìn đến hàng chục nghìn đô sau hệ số (S11, S21: cá nóc $12.000) → T.

## 5. Hệ số "Killscore" (trick) — kiểu nhân dồn

| Trick | Điều kiện (tóm tắt) | Hệ số | Nguồn đồng ý | Tin cậy |
|---|---|---|---|---|
| 360 | Xoay đủ vòng trước khi bắn (không ngắm) | ×1,5 | S17, S18, S24, S11 (popup) | C |
| Explosion | Hạ bằng thuốc nổ | ×1,5 | S17, S12 (+50%) | C |
| Headshot | Trúng đầu | ×1,25 | S17, S18, S12 (+25%), S24 | C |
| Last Bullet | Viên cuối băng đạn | ×1,25 | S17, S18, S09 | C |
| One Shot One Kill | Hạ bằng 1 phát | ×1,25 | S17, S09 | C |
| Fly Fishing | Hạ mục tiêu đang ở trên không | ×1,25 | S17, S11 (popup) | C |
| No Scope | Không ngắm | ×1,2 | S17, S18, S11, S24 | C |
| Point Blank | Cự ly rất gần | ×1,1 | S17, S18, S12 (+10%), S11 | C |
| Quickscope | Ngắm nhanh rồi bắn | ×1,1 | S17, S12 (+10%) | C |
| Finally | Kết liễu mục tiêu đã bị đánh nhiều | ×1,1 | S17, S11 | C |
| Melee | Cận chiến | ×1,05 | S17, S24, S09 | C |
| Impressive | Pha đặc biệt đẹp | ×2 (S17, S07) — S08 ghi ×5 | S17, S07, S08 | T |
| Aerial, Dogfight, Longshot, Killsteal, Overkill, Endangered Species, Multikill, Double…Penta Kill | Nhiều điều kiện | ×1,05–×1,5 | Chủ yếu S17 | T–TB |

Cách cộng dồn: **nhân các hệ số với nhau**, áp vào giá gốc của sinh vật trước khi bán (S17, S18). Game không giải thích các hệ số này (S25).

## 6. Các giá trị khác

| Mục | Giá trị | Nguồn | Tin cậy |
|---|---|---|---|
| Nấu nướng | Tối đa ×1,5 giá trị; để quá lâu bị cháy; dung nham nấu ngay | S15, S24 | C (×1,5) / TB (cháy) |
| Roulette | Đặt vật phẩm lên bàn; đỏ/đen ×2, xanh ×35; 37 ô; trả thưởng bằng vật phẩm | S22, S15, S24 | C |
| Biến thể "drip" | Tên chữ cầu vồng, skin lòe loẹt; phải hạ mới ghi nhận; 1 con = 1 lần quay Reel of Fortune (skin vũ khí) | S19, S23, S10 | TB |
| Lưu game | Tự lưu mỗi phút; ≤64 vật phẩm rơi được lưu | S03 | C |
| Thời lượng | Speedrun 10:23; chơi thường ~3,5–7 giờ | S09, S23, S25, S06 | C |
| Sát thương (qua Gemini) | Tay 3, nắm đấm sắt 5, dao 16 (mài lên 22), súng lục 25 (nâng lên 33) | S10 | T |
| Thời gian chờ cá cắn | ~4–7 giây với mồi thường (ước lượng) | S10 | T |

## 7. Điều khiển PC đã thấy (không áp dụng trực tiếp cho game mới)

| Hành động | Phím | Nguồn | Ghi chú |
|---|---|---|---|
| Di chuyển / nhìn | WASD / chuột | S09, S10 | C |
| Tương tác / nhặt / nói chuyện / mua | E | S09, S10 | C |
| Quăng cần, kéo cần | Chuột trái (giữ để kéo cần ra sau; kéo cá: giữ hoặc bấm liên tục) | S09, S10 | TB |
| Thả sinh vật | Q (S09) hoặc chuột phải (S10) | — | Mâu thuẫn CF-04 |
| Ăn | Giữ E (S09) hoặc giữ chuột phải (S10) | — | Mâu thuẫn CF-04 |
| Bán | Giữ Q để ném vào miệng NPC | S10, S33 | TB |
| Xem giá trị | F | S09, S10 | TB |
| Danh mục đã bắt | Tab | S10, S19 | TB |
| Cất đồ trên tay | X | S10 | TB |
| Đổi skin vũ khí | Z / C | S09, S23 | C |

## 8. Thành tựu nổi bật (tên do Steam hiển thị, S01)

Getting started · Let me go (bị hải âu nhấc bổng khi đang cầm cá — S35) · Who stole my beer · Noob · Drip · I'm the bird now · Getting an upgrade · Dinnertime · Yummy in my tummy · Competitive eating. Tổng 28 thành tựu (S01).
