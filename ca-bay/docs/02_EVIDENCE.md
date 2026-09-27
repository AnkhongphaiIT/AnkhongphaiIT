> **NGHIÊN CỨU LỊCH SỬ V1.** Giữ nội dung gốc để tham khảo; chưa tái xác minh toàn bộ dữ kiện tại bản 2. Đây không phải chỉ dẫn triển khai. Android, chơi đơn trước, không đói, không lootbox, local save và cốt truyện cũ đã được thay bằng yêu cầu bản 2 trong `00_START_HERE.md` và `11_DECISIONS_AND_UNKNOWNS.md`. Phiên bản/giá/chính sách/capability công cụ phải kiểm tra lại khi dùng.

# 02 — BẰNG CHỨNG, MỨC CHẮC CHẮN, MÂU THUẪN, KHOẢNG TRỐNG

> **Vai trò của file:** nơi chính thức lưu các phát hiện về game gốc (`EV-xxx`), mâu thuẫn (`CF-xx`) và khoảng trống nghiên cứu (`GAP-xx`). File này **không chứa quyết định cho game mới** (xem `04`–`08`).
> Mã nguồn `Sxx` xem `01_SOURCES.md`; mốc video xem `references/ref_video_logs.md`.

## 1. Quy ước phân loại

| Nhãn | Nghĩa | Khi nào dùng |
|---|---|---|
| **Đã xác minh** | Quan sát trực tiếp hoặc có nguồn đáng tin cậy hỗ trợ | Nguồn chính thức (S01–S03), ảnh mình xem trực tiếp (S13), hoặc ≥2 nguồn độc lập thống nhất |
| **Suy luận** | Cách giải thích hợp lý từ bằng chứng, chưa được xác nhận | Rút ra từ nhiều dấu hiệu gián tiếp, hoặc 1 nguồn video qua Gemini |
| **Chưa rõ** | Chưa đủ dữ liệu, hoặc nguồn mâu thuẫn chưa giải quyết | — |

**Mức tin cậy:** Cao / Trung bình (TB) / Thấp — kèm lý do ngắn. Quan sát chỉ đến từ video "qua Gemini" (công cụ AI xem video hộ) tối đa là TB nếu không có nguồn thứ hai.

## 2. Nhận dạng, phiên bản, bối cảnh

| Mã | Phát hiện | Nhãn | Tin cậy | Nguồn | Lý do / ghi chú |
|---|---|---|---|---|---|
| EV-001 | Game là **How to Fish**, do **Dazed Games** phát triển và phát hành, Steam app 4001890, chỉ Windows, phát hành **20/08/2026** | Đã xác minh | Cao | S01, S02, S03 | Trang cửa hàng + thông báo phát hành chính thức |
| EV-002 | Không phát hành dạng Early Access; không thấy bản demo công khai | Đã xác minh (EA) / Suy luận (demo) | Cao / TB | S01, S29 | Trang Steam không có nhãn EA; nhà phát triển nói chiến lược "không làm demo" |
| EV-003 | Bản mới nhất có ghi chú: **1.0.12 (04/09/2026)**; SteamDB ghi cập nhật bản ghi 23/09/2026 nhưng không thấy ghi chú bản vá mới hơn | Đã xác minh / Chưa rõ | Cao / Thấp | S04, S09, S25, S05 | Menu speedrun hiện 1.0.12; review GameBrief chấm bản 1.0.12 |
| EV-004 | Giá: 7,99 USD (≈ 209.000 ₫ theo tỷ giá bán 26.166 ₫/USD); **giá vùng Việt Nam 99.000 ₫**; tuần đầu giảm còn 4,95 USD | Đã xác minh | Cao | S01, S05, S03, S26 | — |
| EV-005 | Cửa hàng ghi "1–4 người" nhưng bản 1.0.4 cho phép lobby tối đa **8 người** | Đã xác minh | Cao | S01, S03 | Xem CF-01 |
| EV-006 | Nền tảng: Windows; Steam Deck Verified và GeForce NOW từ 1.0.11; dự định console (Xbox, PlayStation) và Mac | Đã xác minh (hiện tại) / Suy luận (kế hoạch) | Cao / TB | S01, S04, S05, S02, S29 | — |
| EV-007 | Công nghệ: Unity + URP, mạng FishNet, Steamworks.NET | Đã xác minh (do SteamDB tự phát hiện) | TB | S05 | Không phải tuyên bố của nhà phát triển |
| EV-008 | Đội ngũ: 2 nhà sáng lập (thiết kế, lập trình, đồ họa) + thuê ngoài âm thanh (nhạc Martin Weidenborn; SFX Patrik Carlsson, Alexander Fuentes, thư viện zapsplat); bản địa hóa thuê ngoài; **~1 năm phát triển** (8/2025 → 8/2026); Landfall đầu tư theo dự án | Đã xác minh | Cao | S28, S29, S09 (credits), S32 | — |
| EV-009 | Đón nhận: 1 triệu bản trong 2 ngày; đỉnh **373.971** người chơi đồng thời (26/08/2026); **51.439 đánh giá, 95% tích cực** (27/09/2026) | Đã xác minh | Cao | S29, S05, S06, S30 | Số đánh giá khác nhau theo phạm vi — CF-10 |
| EV-010 | Cấu hình tối thiểu: i5-5257U / GTX 1050 / RAM 8 GB / 1 GB ổ đĩa | Đã xác minh | Cao | S01 | — |
| EV-011 | 16 ngôn ngữ; nhãn nội dung "bạo lực hoạt hình với cá và cờ bạc bằng cá (không dùng tiền thật)"; hỗ trợ tay cầm đầy đủ | Đã xác minh | Cao | S01 | — |

## 3. Vòng lặp và cơ chế câu cá

| Mã | Phát hiện | Nhãn | Tin cậy | Nguồn | Lý do / ghi chú |
|---|---|---|---|---|---|
| EV-020 | Vòng lặp tự mô tả: câu → hạ → bán → mua đồ tốt hơn; nhiệm vụ + boss mở đảo mới; sưu tầm biến thể hiếm; trick shot được nhiều tiền; cờ bạc | Đã xác minh | Cao | S01 | Mô tả chính thức |
| EV-021 | Quăng cần: giữ nút chính để kéo cần ra sau, thả để quăng theo đường vòng cung | Đã xác minh | TB | S09, S10 | Hai video (qua Gemini) thống nhất |
| EV-022 | Cá **tự cắn** sau một khoảng chờ ngắn; báo bằng chữ + âm "ting"; không thấy kỹ năng canh thời điểm giật | Đã xác minh | TB | S10, S09, S26 | S26: "bắt tự động khi cần xuống nước" |
| EV-023 | Thời gian chờ ~4–7 giây với mồi thường | Suy luận | Thấp | S10 | Ước lượng của Gemini, 1 video |
| EV-024 | Kéo cá: giữ hoặc bấm liên tục nút chính; **không có thanh lực căng** | Đã xác minh | TB–Cao | S09, S10, S08, S35 | 4 nguồn thống nhất |
| EV-025 | Dây câu đứt / cá sổng trong lúc kéo | Chưa rõ | — | S10 | Gemini: "không thấy"; không nguồn nào mô tả |
| EV-026 | Sinh vật bị giật ra khỏi nước, **bay qua không trung** rồi rơi xuống bờ và giãy; cần câu hoạt động như "máy bắn" | Đã xác minh | Cao | S13 (SS3), S08, S35, S09, S10 | Ảnh xem trực tiếp + 4 nguồn |
| EV-027 | Trên cạn: sinh vật giãy, có loài tìm đường về nước, có loài tấn công người chơi | Đã xác minh | TB | S23, S10, S11 | — |
| EV-028 | Cách hạ: tay không, nắm đấm sắt, dao, súng lục, shotgun, tiểu liên, súng trường, bắn tỉa, thuốc nổ (+ bật lửa) | Đã xác minh | Cao | S09, S10, S11, S13, S15 | — |
| EV-029 | Nâng cấp vũ khí: mài dao, sát thương đạn, phụ kiện (laser, băng đạn mở rộng, giảm giật, giảm thanh, red dot) | Đã xác minh (tồn tại) | TB | S10, S20, S04 | Giá trị cụ thể: Thấp |
| EV-030 | Vũ khí quá nhiệt khi bắn lâu | Chưa rõ | Thấp | S25 | 1 nguồn |
| EV-031 | **Hệ số trick nhân dồn** vào giá bán; các giá trị chính (360 ×1,5; nổ ×1,5; headshot ×1,25; viên cuối ×1,25; một phát ×1,25; hạ trên không ×1,25; không ngắm ×1,2; cự ly gần ×1,1; ngắm nhanh ×1,1; kết liễu ×1,1; cận chiến ×1,05) | Đã xác minh | Cao | S17, S18, S12, S09, S11, S07, S24 | Bảng đầy đủ: `references/ref_original_game_data.md` §5 |
| EV-032 | Game **không giải thích** các hệ số trong UI; người chơi dựa vào cộng đồng | Suy luận | TB | S25, S18 | Ý kiến reviewer, phù hợp việc có nhiều hướng dẫn riêng về hệ số |
| EV-033 | Popup khi hạ: tên sinh vật + tiền + danh sách trick và hệ số; lần đầu bắt loài mới có thông báo riêng | Đã xác minh | TB | S09, S11, S12 | — |
| EV-034 | Bán = **ném/đưa vật phẩm vào miệng NPC bán hàng**, NPC phản ứng ăn uống | Đã xác minh | Cao | S10, S09, S13 (SS5), S33 | Ảnh + hướng dẫn trong game |
| EV-035 | Xem giá trị vật phẩm bằng phím "inspect" | Đã xác minh | TB | S10, S09 | — |
| EV-036 | **Đói** tồn tại: ăn sinh vật để giảm đói; HUD có vòng tim (máu) và vòng dao-dĩa (đói) | Đã xác minh | Cao | S10, S09, S13 (SS2) | Tốc độ đói: GAP-05 |
| EV-037 | Nấu: vỉ nướng/dung nham tăng giá trị tối đa ×1,5, để lâu bị cháy; có thể nấu cả vũ khí; nhúng nước để rửa | Đã xác minh (×1,5, tồn tại) / Suy luận (cháy) | TB | S15, S24, S03, S13 (SS4) | Vị trí mở khóa vỉ nướng: CF-08 |
| EV-038 | **Hải âu cướp** đồ để trên đất; có thể nhấc bổng người chơi đang cầm cá | Đã xác minh | Cao | S15, S10, S35, S12, S03 | — |
| EV-039 | Vật phẩm rơi được lưu giữa các phiên (tối đa 64, có thứ tự ưu tiên) | Đã xác minh | Cao | S03 | — |
| EV-040 | Hotbar đánh số + **ô mồi riêng có số lượng**; mua thêm ô túi đồ | Đã xác minh | TB–Cao | S13 (SS2), S09, S10 | Mồi có tiêu hao theo lần cắn hay không: GAP-02 |
| EV-041 | Mồi chia **cấp theo đảo** (miễn phí → Beginner → Standard → Professional → Scientific) + **mồi boss** + **vật phẩm đặc biệt làm mồi** (lon bia rỗng, đỉa, cà rốt, xác cá ngừ, xô cá…) | Đã xác minh (cấu trúc) | TB | S16, S09, S10, S21 | Bảng chi tiết loài–mồi: TB–Thấp (S14 cảnh báo mâu thuẫn) |
| EV-042 | Giá quan sát được (bia $12, radar $10, thuốc nổ $25, shotgun $150, Big Motor $230…) | Đã xác minh (các giá ≥2 nguồn) | Cao | S09, S10, S15 | Chi tiết: `references/ref_original_game_data.md` §4 |
| EV-043 | Biến thể hiếm "drip": tên chữ cầu vồng, skin lòe loẹt, phải hạ mới ghi nhận; đổi lấy lượt quay máy **Reel of Fortune** để nhận skin vũ khí | Đã xác minh | TB–Cao | S19, S23, S09, S10, S01 | Tỉ lệ xuất hiện: không công bố (GAP-08) |
| EV-044 | Danh mục sưu tầm (Fishipedia / "Think", phím Tab) liệt kê loài và biến thể đã bắt | Đã xác minh | TB | S10, S19 | — |
| EV-045 | Cờ "endangered" là loại đánh dấu dùng cho nhiệm vụ đảo 3, đồng thời có trick "Endangered Species" | Đã xác minh | TB | S21, S17, S09, S12 | — |
| EV-046 | Cờ bạc: **roulette** ở casino đảo 4 (có thể cả đảo 5): đặt vật phẩm lên bàn, đỏ/đen ×2, xanh ×35 (37 ô), trả thưởng bằng vật phẩm | Đã xác minh | TB–Cao | S22, S15, S24, S09, S11 | — |
| EV-047 | Radar cầm tay (màn hình xanh kiểu CRT) để tìm đảo theo tọa độ NPC đưa | Đã xác minh | TB–Cao | S10, S15, S12, S09 | — |
| EV-048 | Di chuyển giữa đảo bằng thuyền; nâng động cơ | Đã xác minh | Cao | S09, S10, S15 | — |
| EV-049 | Mỗi đảo theo khuôn: **NPC yêu cầu → mồi đặc biệt → gọi boss → mang bộ phận boss về → tọa độ/chìa khóa đảo sau** | Đã xác minh | Cao | S14, S16, S20, S21, S10, S11 | Cấu trúc lặp lại 5 lần |
| EV-050 | 5 đảo, boss chính theo thứ tự: cua nhện → piranha khổng lồ → cá nóc → cá ngừ + hải âu lớn → cá voi đầu cong (2 dạng); có boss phụ (cá chó già, cá mặt trăng, cá mập xanh, cá mập yêu tinh) | Đã xác minh | Cao | S14, S11, S09, S16 | Tên đảo không thống nhất (CF-12) |
| EV-051 | Boss có thanh máu trên cùng kèm tên, kiểu tấn công riêng, có boss gọi quái nhỏ, có boss chuyển pha | Đã xác minh | TB | S11, S20, S13 (SS2) | — |
| EV-052 | Boss có **đồng hồ giới hạn** | Đã xác minh | Cao | S03 (1.0.4 sửa lỗi "đồng hồ boss") | Hiển thị dạng thanh trắng + hết giờ boss bỏ trốn: Suy luận, TB (S15, S20) — CF-07 |
| EV-053 | Boss và một số sinh vật khó liên tục được cân bằng lại sau phát hành: boss (nerf cá nóc, cá voi, cá ngừ; cân bằng piranha) và sinh vật thường ở đảo 5 (nerf cá lồng đèn) | Đã xác minh | Cao | S03, S04 | Dấu hiệu độ khó boss là điểm đau; cá lồng đèn là loài thường, không phải boss (`references/ref_original_game_data.md` §3) |
| EV-054 | 3 mức độ khó từ 1.0.9 (giá trị trong `references/…` §1) | Đã xác minh | Cao | S03 | S34 ghi sai — CF-05 |
| EV-055 | Chết: màn hình báo chết → bấm để hồi sinh ở bờ; đồ đang cầm rơi tại chỗ; có cơ chế hồi sinh khi đang bị người khác bế | Đã xác minh (hồi sinh) / Suy luận (bế) | TB | S10, S03 | — |
| EV-056 | Kết thúc: về đất liền → cảnh kết + credits → thuyền lật, quay lại đầu game (vòng lặp hài) | Đã xác minh | TB | S11, S09 | Hai video qua Gemini thống nhất |
| EV-057 | Thời lượng: speedrun 10:23; chơi thường khoảng 3,5–7 giờ | Đã xác minh | Cao | S09, S23, S25, S06 | — |
| EV-058 | Hướng dẫn nhập môn: chuỗi hộp chữ "How to …" góc trên trái, mỗi hộp một động từ, kết thúc bằng thông báo tự do chơi | Đã xác minh | TB | S10, S09, S12 | — |
| EV-059 | NPC nói bằng bóng chữ + âm "lảm nhảm" (gibberish); giọng văn tỉnh bơ, tự giễu | Đã xác minh | TB | S10, S11 | — |
| EV-060 | Nhịp chơi thường: hạ boss đầu tiên ở phút ~33 (có 2 lần chết) | Suy luận | Thấp | S10 | 1 lượt chơi |
| EV-061 | Lưu game: tự lưu mỗi phút, lưu khi thoát; từng có lỗi hỏng save và được vá nhiều lần; Steam Cloud từ 1.0.12 | Đã xác minh | Cao | S03, S04 | Bài học cho game mới |
| EV-062 | Nhiều tùy chọn được thêm sau phát hành: đảo trục nhìn, toggle, độ khó, tắt tên, biểu tượng tay cầm | Đã xác minh | TB–Cao | S03, S04, S25 | S25: lúc ra mắt thiếu tùy chọn âm thanh/hình ảnh |
| EV-063 | Chơi mạng qua lobby Steam (công khai/bạn bè/riêng), vào bằng ID lobby; friendly fire và chia tiền chung là tùy chọn lobby | Đã xác minh (lobby) / Suy luận (tùy chọn) | TB / Thấp | S14, S03, S34 | — |
| EV-064 | Voice chat trong game | Chưa rõ | — | S33 vs S04 | CF-06 |
| EV-065 | Hiệu năng: 60 fps+ trên Steam Deck ở thiết lập cao, ~16 W | Đã xác minh | TB | S26 | 1 nguồn |
| EV-066 | Ngày/đêm, thời tiết | Chưa rõ | — | S13 (SS7 ánh chiều), S11 (hoàng hôn ở cảnh kết) | Không nguồn nào mô tả chu kỳ |

## 4. Mỹ thuật, UI, âm thanh

| Mã | Phát hiện | Nhãn | Tin cậy | Nguồn | Ghi chú |
|---|---|---|---|---|---|
| EV-070 | Low-poly phẳng, màu tươi, texture tối giản; nhân vật hình khối đơn giản, mắt tròn to; hạt hiệu ứng dạng khối lập phương/pixel | Đã xác minh | Cao | S13, S23, S12 | Xem trực tiếp |
| EV-071 | HUD: tiền góc dưới trái trong ô viền trắng; 2 vòng tròn máu/đói; hotbar giữa dưới, ô chọn phóng to + tên; ô mồi riêng; icon render 3D; thanh boss giữa trên; hộp hướng dẫn góc trên trái; tên người chơi nổi trên đầu | Đã xác minh (SS2) / TB (phần từ video) | Cao / TB | S13, S09, S10, S11 | — |
| EV-072 | Cửa hàng dạng vật thể: hàng treo trên tường/bảng, bấm tương tác để mua | Đã xác minh | Cao | S13 (SS1, SS5), S09 | — |
| EV-073 | Âm nhạc: nhạc nhẹ (acoustic/lo-fi/đồng quê) khi khám phá, nhạc điện tử dồn dập khi gặp boss, synthwave ở cảnh kết; radio trong game phát nhạc; OST 10 bài | Đã xác minh | TB–Cao | S23, S10, S11, S32 | — |
| EV-074 | SFX: tiếng "ting" khi dính, guồng quay lạch cạch, cá quẫy "bạch bạch", súng phóng đại kiểu arcade, âm nuốt khi bán + tiếng leng keng nhận tiền, hải âu kêu khi lao xuống | Suy luận | TB | S10, S11, S12 | Mô tả của Gemini |

## 5. Phản hồi người chơi

| Mã | Phát hiện | Nhãn | Tin cậy | Nguồn | Ghi chú |
|---|---|---|---|---|---|
| EV-080 | Điểm được khen nhiều nhất (mẫu 40 đánh giá tích cực): **hỗn loạn co-op với bạn bè (18)**, súng & trick shot (12), hài/meme (11), cờ bạc (10), hài vật lý (8), giá rẻ (7), vòng tiến trình (6) | Đã xác minh (trong mẫu) | TB | S06 | Mẫu nhỏ, lấy theo "hữu ích nhất"; một đánh giá có thể thuộc nhiều nhóm |
| EV-081 | Điểm bị chê nhiều nhất (mẫu 40 tiêu cực): **ngắn/ít nội dung (10)**, vòng lặp lặp lại/nhàm (9), lỗi/crash (8), độ khó không cân (7), mạng/lag (4), chơi đơn kém vui (4) | Đã xác minh (trong mẫu) | TB | S06 | — |
| EV-082 | **Không đánh giá tích cực nào trong mẫu khen phần quăng/kéo cần**; người chê nói phần câu "nhanh chóng đơn giản và lặp lại" | Suy luận | TB | S06, S27 | Niềm vui nằm ở những gì xảy ra **sau khi cá lên bờ** |
| EV-083 | Chơi đơn yếu hơn: boss và đồng hồ boss như được cân cho nhóm | Đã xác minh | TB–Cao | S25, S27, S06 | 3 nguồn |
| EV-084 | Thể loại "friendslop": game co-op rẻ, vật lý hỗn loạn, hài; tiếp thị sớm qua TikTok, không làm demo | Đã xác minh | TB | S30, S29 | — |

## 6. Mâu thuẫn giữa các nguồn (CF)

| Mã | Mâu thuẫn | Các phía | Phân tích | Kết luận tạm |
|---|---|---|---|---|
| CF-01 | Số người chơi | Cửa hàng/báo: 1–4 · Bản vá 1.0.4: tối đa 8 | Khác thời điểm; trang cửa hàng không cập nhật; S34 cho rằng "cân bằng cho 4" | Cả hai đúng theo ngữ cảnh; tối đa kỹ thuật = 8 |
| CF-02 | Nhiệm vụ đảo 5 | S14: nộp 5 con cá; S16: mồi "Fish Bucket" · S09 (qua Gemini): 5 lon bia, "Whale Bucket" | 2 nguồn chữ độc lập thống nhất về cá/xô cá; Gemini có thể đọc nhầm hình | Nghiêng về "5 con cá → xô cá" — **Chưa rõ**, không ảnh hưởng game mới |
| CF-03 | Mồi gọi boss cá nóc | S16, S20, S21: cà rốt · S09 (qua Gemini): Hot Dog | 3 nguồn chữ thống nhất | Cà rốt; speedrun có thể dùng tuyến khác hoặc Gemini nhận nhầm vật phẩm |
| CF-04 | Phím ăn/thả | S09: giữ E / Q · S10: giữ chuột phải | Có thể khác phiên bản, thiết lập phím, hoặc Gemini đọc sai | Chưa rõ — không cần cho game mới (điều khiển tự thiết kế) |
| CF-05 | Giá trị độ khó | S03 (chính thức) vs S34 (fan: 75%/125% cho cả hai) | Nguồn chính thức thắng | Dùng S03; S34 bị hạ độ tin cậy |
| CF-06 | Voice chat | S33: không có · S04: "cập nhật MetaVoice 4.3 cho ổn định voice chat" | S04 là bản sao ghi chú chính thức (TB), S33 là hướng dẫn cũ hơn (24/08) | Chưa rõ; có thể voice chat được thêm sau 24/08 |
| CF-07 | Đồng hồ boss hiển thị thế nào | S03: có đồng hồ boss · S15, S20: thanh trắng dưới thanh máu · S11 (qua Gemini): "không thấy đồng hồ", chỉ thấy "đoạn trắng bám đuôi" | Đoạn trắng Gemini mô tả có thể chính là thanh thoát | Tồn tại: Đã xác minh; dạng hiển thị: Suy luận |
| CF-08 | Vỉ nướng có từ đảo nào | S15: mở ở đảo 3 · S24: đảo 1–4 | Có thể có nhiều vỉ ở nhiều đảo hoặc S24 viết chung chung | Chưa rõ |
| CF-09 | Đỉnh người chơi | S30/S31 (23/08): ~267–268 nghìn · S05: 373.971 (26/08) | Khác ngày đo | Dùng số SteamDB kèm ngày |
| CF-10 | Số đánh giá | Cửa hàng: 34.624 (30 ngày gần nhất) & 25.076 (tiếng Anh) · API: 51.439 (tất cả) · SteamDB: ~70 nghìn | Khác phạm vi (gần đây / ngôn ngữ / loại mua / cách tính của SteamDB) | Ghi rõ phạm vi khi trích |
| CF-11 | Tên nhạc sĩ | Weidenborn (S09, S29, S32) · Weldenborn (S11 qua Gemini) | 3 nguồn thống nhất | Martin Weidenborn |
| CF-12 | Tên đảo | Forest / Pine / Forest Outpost; Desert / Tropical Resort; Rocks / Casino | Tên do người viết hướng dẫn đặt | Chưa rõ tên chính thức trong game |
| CF-13 | Danh sách boss phụ | S16 có cá chó già nhưng không có cá mặt trăng; S10, S11 có cả hai | Danh sách S16 chưa đầy đủ | Dùng S11 cho danh sách boss |

## 7. Khoảng trống nghiên cứu (GAP) và cách xử lý

| Mã | Chưa biết | Ảnh hưởng đến game mới | Cách xử lý cụ thể | Trạng thái |
|---|---|---|---|---|
| GAP-01 | Phân bố thời gian chờ cá cắn, ảnh hưởng của mồi/vị trí | Thấp — game mới tự thiết kế | Thử nghiệm EXP-03 (`10_VALIDATION.md`) | Không cần nghiên cứu thêm |
| GAP-02 | Mồi tiêu hao theo lần cắn hay lần quăng | Thấp | *(Đề xuất cho game mới — xem `04` §5, DEC-015)*: trừ mồi khi cá dính, hoàn mồi khi gián đoạn; không suy ra cách làm của bản gốc | Đóng (không nghiên cứu thêm) |
| GAP-03 | Thông số AI sinh vật trên cạn | Thấp | Tự thiết kế + chỉnh qua playtest | Đóng |
| GAP-04 | Thời lượng đồng hồ boss và cách nó thay đổi theo số người | TB — liên quan bài học "chơi đơn bị ép" | *(Đề xuất cho game mới — xem `04` §7.9, `bosses.json`)*: đồng hồ chơi đơn rộng rãi, đo trong EXP-06. Nghiên cứu thêm về bản gốc (tùy chọn): xem S11 mốc 04:04 để đo | Mở (không chặn) |
| GAP-05 | Tốc độ đói và hình phạt khi đói | TB — quyết định có làm hệ thống đói hay không | Q-006 (`11_DECISIONS_AND_UNKNOWNS.md`) | Chờ quyết định |
| GAP-06 | Có chu kỳ ngày/đêm, thời tiết hay không | Thấp | Ngoài phạm vi MVP | Đóng |
| GAP-07 | Xác minh bằng mắt các prompt/popup lấy từ video | Thấp–TB | 4 mốc chụp màn hình trong `references/ref_visual_references.md` §3 | Tùy chọn |
| GAP-08 | Tỉ lệ xuất hiện biến thể hiếm | Thấp | Game mới đặt giá trị khởi đầu và đo (EXP-07) | Đóng |
| GAP-09 | Trailer ra mắt chưa phân tích được | Thấp | Thử lại công cụ khi dịch vụ ổn định | Tùy chọn |
| GAP-10 | Voice chat (CF-06) | Thấp cho MVP (không có co-op) | Kiểm tra khi thiết kế co-op | Hoãn |
