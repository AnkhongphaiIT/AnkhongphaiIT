> **NGHIÊN CỨU LỊCH SỬ V1.** Giữ nội dung gốc để tham khảo; chưa tái xác minh toàn bộ dữ kiện tại bản 2. Đây không phải chỉ dẫn triển khai. Android, chơi đơn trước, không đói, không lootbox, local save và cốt truyện cũ đã được thay bằng yêu cầu bản 2 trong `00_START_HERE.md` và `11_DECISIONS_AND_UNKNOWNS.md`. Phiên bản/giá/chính sách/capability công cụ phải kiểm tra lại khi dùng.

# 01 — DANH MỤC NGUỒN (SOURCES)

> **Vai trò của file:** nơi chính thức lưu mã nguồn `Sxx` (nguồn về game tham chiếu) và `Txx` (nguồn nền tảng/kỹ thuật cho game mới). Mọi tài liệu khác chỉ dẫn mã, không chép lại URL.
> **Ngày truy cập chung:** 27/09/2026 (giờ Việt Nam), trừ khi ghi khác.
> **Phiên bản game tham chiếu:** How to Fish — Dazed Games — bản vá 1.0.12 (04/09/2026) là bản mới nhất có ghi chú công khai tại thời điểm nghiên cứu. Xem `02_EVIDENCE.md` EV-003.

## 1. Cách đọc bảng

| Cột | Ý nghĩa |
|---|---|
| Mã | `Sxx` = nguồn về game gốc; `Txx` = nguồn kỹ thuật/nền tảng cho game mới; `Xxx` = đã kiểm tra nhưng không dùng được |
| Loại | OFF = chính thức/nhà phát triển · PATCH = ghi chú bản vá · STAT = số liệu nền tảng · VID = video gameplay · TRL = trailer · IMG = ảnh chính thức · GUIDE = hướng dẫn/wiki · REV = đánh giá · COM = cộng đồng · NEWS = tin/hậu trường |
| Vai trò | **Cốt lõi** (dùng cho kết luận quan trọng) · **Bổ trợ** (đối chiếu, chi tiết phụ) · **Tin cậy thấp** (chỉ dùng khi có nguồn khác xác nhận) |
| Cách tiếp cận | Đọc toàn văn (qua công cụ tải trang) · Xem trực tiếp (ảnh) · Phân tích qua Gemini (xem mục 3) |

## 2. Nguồn về game tham chiếu (S01–S35)

| Mã | Tiêu đề / trang | Tác giả / kênh | URL | Ngày đăng | Phiên bản liên quan | Loại | Vai trò | Hỗ trợ nội dung gì |
|---|---|---|---|---|---|---|---|---|
| S01 | How to Fish on Steam (trang cửa hàng) + dữ liệu `appdetails` của Steam | Valve / Dazed Games | https://store.steampowered.com/app/4001890/How_to_Fish/ | Phát hành 20/08/2026 | Bản hiện hành | OFF | Cốt lõi | Mô tả chính thức, thể loại, tag, tính năng (single-player, online co-op, full controller support, Save Anytime), cấu hình tối thiểu, giá, 16 ngôn ngữ, nhãn nội dung, 28 thành tựu, danh sách 7 ảnh + 2 trailer |
| S02 | Dazed Games — trang chủ studio | Dazed Games | https://dazed.games | — | — | OFF | Cốt lõi | Hai nhà sáng lập, game trước đó, kế hoạch console/Mac, Discord |
| S03 | Ghi chú bản vá chính thức (bản sao trên SteamDB): phát hành (build 24840403), 1.0.4 (24866339), 1.0.6 (24894107), 1.0.9 (24911270), 1.0.10 (24975015) | Carl-Vilhelm & Melvin (Dazed Games) | https://steamdb.info/patchnotes/24840403/ · …/24866339/ · …/24894107/ · …/24911270/ · …/24975015/ | 20/08 · 21/08 · 23/08 · 24/08 · 27/08/2026 | 1.0.0 → 1.0.10 | PATCH | Cốt lõi | Lobby 8 người, nerf boss, timer boss, lưu tự động mỗi phút, độ khó, nấu ăn/rửa vũ khí, lưu vật phẩm rơi (≤64), roulette, hải âu, radar |
| S04 | Patch Notes for How to Fish (trang tổng hợp) | Patchbot | https://patchbot.io/games/how-to-fish | Liệt kê tương đối "1 tháng / 3 tuần trước" | 1.0.5, 1.0.8, 1.0.11, 1.0.12 | PATCH (bản sao) | Bổ trợ | Steam Deck Verified, GeForce NOW, tùy chọn toggle, Steam Cloud, cân bằng piranha/tuna, "MetaVoice 4.3" |
| S05 | How to Fish — SteamDB (trang app, biểu đồ người chơi, bảng giá vùng) | SteamDB | https://steamdb.info/app/4001890/ · https://steamdb.info/app/4001890/charts/ | Cập nhật bản ghi 23/09/2026 | — | STAT | Cốt lõi | Công nghệ phát hiện (Unity, URP, FishNet, Steamworks.NET), đỉnh 373.971 người chơi đồng thời (26/08/2026), giá VN 99.000₫, Steam Deck Verified |
| S06 | Đánh giá người dùng Steam (endpoint công khai `appreviews`): tổng hợp + mẫu 40 tích cực và 40 tiêu cực tiếng Anh "hữu ích nhất" | Người chơi Steam | https://store.steampowered.com/appreviews/4001890?json=1 | Lấy ngày 27/09/2026 | Nhiều bản | COM/REV | Cốt lõi | 51.439 đánh giá, 95% tích cực; chủ đề khen/chê có đếm |
| S07 | Steam Community — diễn đàn thảo luận + chủ đề "How to get good score early?" | Người chơi | https://steamcommunity.com/app/4001890/discussions/ · https://steamcommunity.com/app/4001890/discussions/0/582806239606703193/ | 24/08/2026 (chủ đề) | ~1.0.9 | COM | Bổ trợ | Cách cộng dồn hệ số trick, các chủ đề lỗi/khó khăn thường gặp |
| S08 | Steam Guide "How to beat the Fish + tips and tricks" | Discipline | https://steamcommunity.com/sharedfiles/filedetails/?id=3786923803 | 20/08/2026 | 1.0.0 | GUIDE | Bổ trợ | Cần câu như "máy bắn", không có cơ chế lực căng, cộng dồn trick |
| S09 | How to Fish Any% speedrun – 10:23 (World Record) — **video bạn gửi** | Clydo2nd | https://www.youtube.com/watch?v=eni7GP0S4BE | Chưa lấy được ngày đăng | 1.0.12 (hiện ở menu) | VID | Cốt lõi | Toàn bộ tuyến tiến trình 5 đảo, prompt điều khiển, giá, hệ số, credits, kết thúc |
| S10 | HOW TO FISH – Full Gameplay Walkthrough Part 1 [FULL GAME] No Commentary (81:20) | Zish Gaming | https://www.youtube.com/watch?v=F9HbT9_0fQI | Chưa lấy được ngày đăng | Chưa rõ | VID | Cốt lõi | Hướng dẫn nhập môn đầy đủ, nhịp chơi bình thường, thời gian chờ cá cắn, chết/hồi sinh, giá đảo 1–2, âm nhạc từng khu |
| S11 | How to Fish – All Bosses & Ending (23:50) | Chưa xác định (oEmbed trả lỗi 401) | https://www.youtube.com/watch?v=tL4uWormVs4 | Chưa lấy được | Chưa rõ | VID | Cốt lõi | 10 trận boss, UI boss, đòn đánh, vật rơi, cảnh kết và vòng lặp hài |
| S12 | How to Fish – Gameplay Trailer (0:46) — bản đăng lại trailer chính thức có trên Steam | PlayIndiesGames (đăng lại) | https://www.youtube.com/watch?v=jX-1MKmEt_M | Trước phát hành (thẻ "Q3 2026") | Tiền phát hành | TRL | Bổ trợ | Nhịp dựng, âm nhạc, popup hệ số (+10%, +25%, +50%), "Supported by Landfall" |
| S13 | 7 ảnh chụp màn hình chính thức (1920×1080) trên trang Steam, đặt mã SS1–SS7 | Dazed Games | Danh sách URL trong `references/ref_visual_references.md` | — | Chưa rõ | IMG | Cốt lõi | **Mình xem trực tiếp**: phong cách low-poly, bảng màu, HUD, hotbar, NPC, cá, vũ khí, nướng, hải âu |
| S14 | How to Fish Wiki (howto.fish) — các trang: chủ, about, islands, lighthouse, creatures, multiplayer | Nhóm biên tập fan (tự nhận không liên kết Dazed Games) | https://howto.fish/ | Có trang ghi "reviewed 28/08/2026", "last updated 30/08/2026" | Bản phát hành | GUIDE | Bổ trợ | Thứ tự 5 đảo & boss, chuỗi nhiệm vụ đảo 1, multiplayer 8 người, cảnh báo danh sách sinh vật mâu thuẫn |
| S15 | How to Fish Beginner Guide: 15 Tips | Bartosz "Resurrect" Wiktor — G2A News | https://www.g2a.com/news/features/guide/how-to-fish-beginner-guide/ | 24/08/2026 | ~1.0.6–1.0.9 | GUIDE | Bổ trợ | Radar $10, Shotgun $150, Dynamite $25, grill ×1,5, hải âu cướp, thanh trắng dưới máu boss, roulette 35× |
| S16 | How to Fish: All Fish, Bosses, Rods and Bait by Island | Bartosz "Resurrect" Wiktor — G2A News | https://www.g2a.com/news/features/guide/how-to-fish-all-fish-bosses-rods-and-bait-by-island/ | 24/08/2026 | ~1.0.6–1.0.9 | GUIDE | Bổ trợ | Bảng loài–cần–mồi theo đảo, mồi gọi boss |
| S17 | How to Fish Trickshots: Every Killscore Multiplier and Combo | AllThings.How (biên tập Pallav Pathak) | https://allthings.how/how-to-fish-trickshots-every-killscore-multiplier-and-combo/ | 26/08/2026 | ~1.0.9 | GUIDE | Cốt lõi | Bảng 23 hệ số trick, cộng dồn kiểu nhân |
| S18 | How to Fish Killscore Multipliers | NerdsChalk | https://nerdschalk.com/how-killscore-multipliers-work-in-how-to-fish/ | 24/08/2026 | ~1.0.9 | GUIDE | Bổ trợ | Đối chiếu S17; hệ số nhân với giá gốc trước khi bán |
| S19 | How to Fish Guide: How to Get Drip Creatures | Larc — games.gg | https://games.gg/how-to-fish/guides/how-to-find-drip-creatures-in-how-to-fish-full-guide/ | 26/08/2026 | ~1.0.9 | GUIDE | Bổ trợ | Biến thể "drip": tên cầu vồng, phải giết mới ghi nhận, Reel of Fortune đổi skin |
| S20 | How to Fish All Bosses Guide | Summer Ye — LagoFast | https://www.lagofast.com/en/blog/how-to-fish-all-bosses-guide-beat-giant-piranha-pufferfish/ | 27/08/2026 | ~1.0.10 | GUIDE | Bổ trợ | Mồi gọi boss, đòn đánh, "thanh thoát" màu trắng dưới máu boss |
| S21 | How to Fish Pufferfish Bait: Endangered Fish, Tourist Quest | NerdsChalk | https://nerdschalk.com/get-endangered-fish-for-tourist-how-to-fish/ | 24/08/2026 | ~1.0.9 | GUIDE | Bổ trợ | Nhiệm vụ du khách đảo 3, cờ "endangered", mồi cà rốt |
| S22 | How to Fish Roulette Wheel: Placing Bets and the 35x Green Payout | AllThings.How | https://allthings.how/how-to-fish-roulette-wheel-placing-bets-and-the-35x-green-payout/ | 27/08/2026 | ~1.0.10 | GUIDE | Bổ trợ | Cược bằng vật phẩm, đỏ/đen ×2, xanh ×35, trả thưởng bằng vật phẩm |
| S23 | How to Fish Review – A Pretty Good Catch! (8/10) | Kai Bonnar — Screen Hype | https://www.screenhype.co.uk/how-to-fish-review-a-pretty-good-catch/ | 15/09/2026 | ~1.0.12 | REV | Cốt lõi | Vòng lặp, ~7 giờ co-op, Reel of Fortune, radio, nhạc lo-fi, không bơi được |
| S24 | How to Make Money in How to Fish (Tips & Tricks) | Kai Bonnar — Screen Hype | https://www.screenhype.co.uk/how-to-make-money-in-how-to-fish-tips-tricks/ | 22/09/2026 | ~1.0.12 | GUIDE | Bổ trợ | Nấu ×1,5, nướng quá tay bị cháy, dung nham tự nấu, roulette cả đảo 5 |
| S25 | How to Fish Review: A Co-op Hit With a Solo Problem (7,6/10) | Finn Calloway — GameBrief | https://www.gamebrief.net/blog/how-to-fish-review-2026 | 27/08/2026 (cập nhật sau) | 1.0.12 | REV | Cốt lõi | Điểm yếu chơi đơn, vòng lặp nhàm sau vài giờ, hệ số không được giải thích trong game, lỗi lúc ra mắt |
| S26 | How to Fish Is A Crazy Co-Op Fishing Simulator That Runs Wonderfully on Steam Deck | Noah Kupetsky — Steam Deck HQ | https://steamdeckhq.com/news/how-to-fish-is-crazy-fishing-simulator-steam-deck/ | 21/08/2026 | 1.0.x | REV | Bổ trợ | "Bắt cá tự động khi thả cần", 60 fps trên Steam Deck |
| S27 | How to Fish — Metacritic (kèm trích đánh giá Game8 84/100) | Metacritic / Game8 | https://www.metacritic.com/game/how-to-fish/ | — | — | REV | Bổ trợ | Nhận định co-op vui, chơi đơn kém hơn do cày cuốc; điểm người dùng 5,9 (17 lượt) |
| S28 | Dazed Games Secures Project Investment and Sets Sights on 2026 Launch | Sweden Game Arena | https://swedengamearena.com/en/news/dazed-games-secures-project-investment-and-sets-sights-2026-launch/ | 02/03/2026 | Tiền phát hành | NEWS | Cốt lõi | Hậu trường: bắt đầu làm 8/2025, đầu tư dự án từ Landfall, đội 2 người |
| S29 | Dazed Games hits one million copies sold in just two days | Sweden Game Arena | https://swedengamearena.com/en/news/dazed-games-hits-one-million-copies-sold-just-two-days/ | 03/09/2026 | — | NEWS | Cốt lõi | 1 triệu bản/2 ngày, ~1 năm phát triển, cộng tác âm thanh, chiến lược không làm demo, dự định console |
| S30 | How to Fish, the newest viral friendslop game, sells 1 million copies in two days | Alexandra Wells — Dot Esports | https://dotesports.com/indies/news/how-to-fish-game-sales-friendslop-steam-indie-coop | 23/08/2026 | 1.0.x | NEWS | Bổ trợ | Bối cảnh thể loại "friendslop" (game co-op hỗn loạn, rẻ, vui với bạn bè) |
| S31 | How to Fish welcomes 1 million players in 48 hours | Stephanie Valentine — Outrun Gaming | https://outrungaming.com/how-to-fish-steam-1-million-players-48-hours-dazed-games/ | 23/08/2026 | 1.0.x | NEWS | Bổ trợ | Lời nhắn của dev hứa thêm nội dung/sửa lỗi |
| S32 | The soundtrack to friendslop hit How to Fish lands on streaming platforms | Peterline6 — NOWPLAYING | https://nowplaying.cool/how-to-fish-ost-drop-spotify-apple-music/ | 11/09/2026 | — | NEWS | Bổ trợ | Nhạc sĩ Martin Weidenborn, 10 bài, nhạc radio trong game |
| S33 | How to Fish Push-to-Talk: Voice Apps, Keybind Setup | NerdsChalk | https://nerdschalk.com/voice-chat-push-to-talk-how-to-fish/ | 24/08/2026 | ~1.0.9 | GUIDE | Tin cậy thấp | Cho rằng không có voice chat trong game (mâu thuẫn S04) ; phím Q = bán |
| S34 | How to Fish Co-op: No Match ID, 5–8 Players, Friendly Fire, Black Screen | howtofishwiki.cc (fan) | https://howtofishwiki.cc/co-op/ | Cập nhật 17/09/2026 | 1.0.12 | GUIDE | Tin cậy thấp | Friendly fire & chia tiền là tùy chọn lobby — **có lỗi**: ghi sai giá trị độ khó so với S03 |
| S35 | How to Fish Walkthrough — Bosses, Quests, Fishing and All Achievements | Andrey Pavlenko — ShowGamer | https://showgamer.com/en/prohozhdeniya-igr/5151-prohozhdenie-how-to-fish | 21/08/2026 (sửa 26/09/2026) | 1.0.x | GUIDE | Bổ trợ | "Không có thanh lực căng", thành tựu hải âu nhấc người chơi, giết boss ≤10 giây |

**Phủ nhóm nguồn (yêu cầu ≥5 nhóm):** chính thức/cửa hàng (S01, S02) · bản vá (S03, S04) · số liệu (S05) · gameplay dài/cơ chế (S09, S10, S11) · trailer/ảnh (S12, S13) · hướng dẫn/wiki (S14–S22, S24, S33–S35) · đánh giá & phản hồi (S06, S23, S25–S27) · cộng đồng (S07, S08) · hậu trường/tin (S28–S32). → **9 nhóm**.

**Nguồn "cốt lõi": 14** (S01, S02, S03, S05, S06, S09, S10, S11, S13, S17, S23, S25, S28, S29). S03 gộp 5 ghi chú bản vá cùng tác giả thành một mã để không "đếm trùng". Các nguồn còn lại chỉ dùng để đối chiếu.

## 3. Giới hạn cách tiếp cận (đọc kỹ trước khi dùng bằng chứng video)

1. **Video (S09, S10, S11, S12):** mình **không tự xem từng khung hình**. Mình gửi link YouTube cho công cụ phân tích Gemini (mô hình `gemini-3.8-flash`, công cụ bạn đã cài trên máy) để nó xem cả hình lẫn tiếng rồi trả nhật ký có mốc thời gian. Mình đọc nhật ký đó và đối chiếu với nguồn chữ. Vì vậy mọi quan sát chỉ đến từ video được ghi "qua Gemini" và mức tin cậy tối đa là **Trung bình** nếu không có nguồn thứ hai.
2. **Ảnh (S13):** mình **xem trực tiếp** 7 ảnh chính thức 1920×1080 trong trình duyệt tích hợp, có phóng to vùng HUD.
3. **Trang web:** đọc qua công cụ tải trang (chuyển HTML → văn bản). Một số trang không tải được (mục 5), mình không tìm cách vượt chặn.
4. **Trailer ra mắt chính thức** (https://www.youtube.com/watch?v=GdX4HCbd28Q, kênh GameTrailers đăng lại): 3 lần phân tích đều lỗi dịch vụ (503) → **chưa dùng**.
5. Mình **không chơi game** và không xem livestream.

## 4. Nguồn kỹ thuật/nền tảng cho game mới (T01–T13)

| Mã | Tiêu đề | Tác giả | URL | Ngày | Hỗ trợ nội dung gì |
|---|---|---|---|---|---|
| T01 | Godot Engine 4.7.2-stable Released | GameDev.net | https://gamedev.net/news/5172-godot-engine-472-stable-released/ | 18/08/2026 | Phiên bản ổn định mới nhất 4.7.2 (bản bảo trì) |
| T02 | What's New in Godot 4.7 | Godot Learning | https://godotlearning.com/blog/godot-4-7-whats-new | 2026 | 4.7.0 ra 18/06/2026; node `VirtualJoystick` có sẵn; tùy chọn scale nearest cho 3D low-res |
| T03 | How to target latest Android SDK? (diễn đàn Godot) | Cộng đồng Godot | https://forum.godotengine.org/t/how-to-target-latest-android-sdk/142631 | 05–29/08/2026 | Godot 4.7: target SDK mặc định 36 khi build Gradle + AAB; kênh test cũng phải target 36 |
| T04 | Web Export in 4.3 (báo cáo tiến độ chính thức) | Godot Engine | https://godotengine.org/article/progress-report-web-export-in-4-3/ | 2024 | Xuất web đơn luồng (không cần SharedArrayBuffer/COOP/COEP), phát âm thanh dạng sample, `.wasm` ~40 MB gốc / ~5 MB nén Brotli |
| T05 | Godot 4.6 Jolt Physics: Migration Guide | StraySpark | https://www.strayspark.studio/blog/godot-46-jolt-physics-migration-guide | 2026 | Jolt là engine vật lý 3D mặc định từ 4.6 (nguồn thứ cấp) |
| T06 | "Is there an update on exporting C# projects to Web" + issue #70796 | Diễn đàn Godot / GitHub | https://forum.godotengine.org/t/is-there-an-update-on-exporting-c-projects-to-web/128821 · https://github.com/godotengine/godot/issues/70796 | 11/2025–04/2026 | C# **chưa** xuất web được ở bản ổn định → dùng GDScript |
| T07 | Target API level requirements for Google Play apps | Google (Play Console Help) | https://support.google.com/googleplay/android-developer/answer/11926878 | Hiệu lực 31/08/2026 | App mới & bản cập nhật phải target Android 16 (API 36) |
| T08 | Real-Money Gambling, Games, and Contests; Families Policies | Google (Play Console Help) | https://support.google.com/googleplay/android-developer/answer/9877032 · https://support.google.com/googleplay/android-developer/answer/9893335 | Hiện hành | App cho trẻ em không được có cờ bạc thật/mô phỏng hay bạo lực không phù hợp |
| T09 | App testing requirements for new personal developer accounts; Get started with Play Console | Google (Play Console Help) | https://support.google.com/googleplay/android-developer/answer/14151465 · https://support.google.com/googleplay/android-developer/answer/6112435 | Hiện hành | Tài khoản cá nhân mới: test kín ≥12 người trong ≥14 ngày trước khi lên production; phí đăng ký 25 USD một lần |
| T10 | CrazyGames Documentation — Technical & Gameplay requirements | CrazyGames | https://docs.crazygames.com/requirements/technical/ · https://docs.crazygames.com/requirements/gameplay/ | Hiện hành | Tải ban đầu ≤50 MB (≤20 MB để lên trang chủ di động), tổng ≤250 MB, ≤1500 file, chạy mượt trên Chromebook 4 GB, hỗ trợ chuột/phím/cảm ứng, PEGI 12, tiếng Anh bắt buộc, vào gameplay ngay (tối đa 1 cú bấm) |
| T11 | PEGI launches "interactive risk categories" | Reed Smith | https://www.reedsmith.com/articles/pegi-launches-interactive-risk-categories-overhauls-age-ratings-for-loot-boxes-in-game-spending-and-communication-features/ | 23/03/2026 (hiệu lực 6/2026) | Vật phẩm ngẫu nhiên trả phí ≥ PEGI 16; tính năng giao tiếp không có chặn/báo cáo = PEGI 18; tiêu chí cờ bạc mô phỏng đang được chi tiết hóa |
| T12 | Kenney — Support (giấy phép) | Kenney | https://kenney.nl/support | Hiện hành | Tài nguyên Kenney là CC0, dùng thương mại được, không bắt buộc ghi công |
| T13 | gdUnit4 (kho mã & bảng tương thích) | godot-gdunit-labs | https://github.com/godot-gdunit-labs/gdUnit4 | Hiện hành | gdUnit4 v6.x yêu cầu Godot ≥4.5 (cần tự kiểm tra với 4.7) |

Tham khảo tỷ giá khi quy đổi VNĐ: tỷ giá bán USD của Vietcombank ngày 26/09/2026 khoảng **26.166 ₫/USD** (https://doanhnghiephoinhap.vn/ty-gia-usd-hom-nay-2692026-dong-usd-the-gioi-quay-dau-giam-nhe-149900.html).

## 5. Đã kiểm tra nhưng không dùng (X01–X08)

| Mã | Nguồn | Lý do không dùng |
|---|---|---|
| X01 | Game8 — review & các hướng dẫn (game8.co) | Công cụ tải trang bị chặn bởi robots.txt → chỉ dùng câu trích lại trên Metacritic (S27) |
| X02 | Sportskeeda — full walkthrough | Trả lỗi 403 |
| X03 | GameRant — endangered creature guide | Bị chặn bởi robots.txt |
| X04 | API tin tức Steam (api.steampowered.com) & trang tin Steam dạng JS | Bị chặn/không hiển thị nội dung → thay bằng bản sao SteamDB (S03) và Patchbot (S04) |
| X05 | Trailer ra mắt (GdX4HCbd28Q) | Dịch vụ phân tích lỗi 503 ba lần |
| X06 | Hàng loạt "wiki" tự động (howtofish101.com, how2fish.wiki, howtofishgame.wiki, how-to-fish.org, howtofish.fans…) | Nội dung trùng lặp, không dẫn nguồn, có dấu hiệu tự sinh; howto.fish (S14) tự cảnh báo danh sách sinh vật trên mạng mâu thuẫn |
| X07 | TikTok chính thức @dazed_games | Bị chặn bởi robots.txt |
| X08 | Worldeka multiplayer guide | Không dẫn nguồn, một số khẳng định đã lỗi thời (4 người tối đa) |
