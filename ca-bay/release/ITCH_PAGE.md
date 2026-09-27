# Trang itch.io — bản nháp (VI/EN)

> Trạng thái: **nháp, chưa đăng**. Cần: máy chủ công khai HTTPS/WSS (NEED-HOST), quyền đăng lên itch.io (NEED-ITCH), kênh liên hệ trong `PRIVACY.md` (NEED-CONTACT). Ảnh chụp trong `release/screenshots/` là ảnh game thật chạy trong Chromium với máy chủ local (render phần mềm, chất lượng thấp hơn máy có GPU) — nên chụp lại trên máy thật trước khi đăng.

## Cấu hình trang

| Mục | Giá trị |
|---|---|
| Kind of project | HTML |
| Upload | `ca-bay-web-<version>.zip` (xuất bằng `tools/build/package_web.py --api https://… --ws wss://…`), tick "This file will be played in the browser" |
| Viewport | 1280 × 720, bật "Fullscreen button", bật "Mobile friendly" = **không** (desktop bàn phím + chuột) |
| SharedArrayBuffer | **Không cần** (bản web không thread) |
| Pricing | No payments (hoặc "Donate" chỉ khi chủ dự án đã tự thiết lập nhận tiền hợp lệ) |
| Genre / Tags | Simulation, Fishing, Co-op, Multiplayer, 3D, Low-poly, Funny, Vietnamese |
| Community | tùy chủ dự án |
| Ảnh bìa | cần ảnh 630×500 — xin từ batch ChatGPT (`handoff/requests/`) hoặc ghép từ ảnh chụp thật |

## Tiếng Việt

**CÁ BAY** — câu cá kiểu hỗn loạn vui nhộn cùng bạn bè (tên tạm)

Bão vừa qua, bến cá của làng tan hoang. Cùng tối đa 4 người bạn, bạn quăng cần, giật cá bay vèo lên bờ, rồi… đập cho nó xỉu bằng dép, chổi, vỉ ruồi — cá không chảy máu, chỉ nằm sao quay vòng vòng. Bán cá ở sạp Cô Ba, nâng cấp đồ nghề, giúp bà con sửa bến, gọi "trùm sông" ra đấu và mở đường tới ba cù lao.

- 3 đảo, 15 loài cá thường, 3 con trùm, nhiệm vụ đời thường với người dân bến cá
- Trick khi đập: đập lúc cá đang bay, một phát ăn ngay, tâng cá… nhân giá bán
- Đói thì ăn cơm nắm (miễn phí ở sạp) hoặc nướng cá
- Hộp quà lễ hội mở bằng vé kiếm khi chơi — **không bán bằng tiền thật**, chỉ đồ trang trí, tỉ lệ công khai
- Tài khoản + tiến trình lưu trên máy chủ, chơi tiếp trên máy khác
- Tiếng Việt / English

**Điều khiển:** WASD di chuyển · chuột nhìn · chuột trái: giữ nạp lực / thả quăng / giữ kéo cá / đập · chuột phải: thu dây · E: nói chuyện, nhặt · 1–4: đổi công cụ · B: đổi mồi · Tab: Sổ Cá · Esc: menu

**Lưu ý:** cần kết nối Internet và tạo tài khoản (không cần email). Lưu mã khôi phục khi đăng ký. Chơi tốt nhất trên Chrome/Edge/Firefox máy tính. Quyền riêng tư: xem `PRIVACY.md` đi kèm.

## English

**CÁ BAY** — chaotic, silly co-op fishing with friends (working title)

A storm wrecked the village pier. With up to 4 friends, cast your line, yank fish flying onto the shore, then… bonk them unconscious with flip-flops, brooms and fly swatters — no blood, just spinning stars. Sell your catch at Aunt Ba's stall, upgrade your gear, help the locals rebuild, summon the river bosses and open the way to three islets.

- 3 islands, 15 regular species, 3 bosses, everyday quests with the pier folks
- Smack tricks: air smack, one-hit, juggle… multiply the sale price
- Get hungry? Free rice balls at the stall, or grill a fish
- Festival box opened with tickets earned by playing — **never sold for real money**, cosmetics only, odds shown
- Account + server-side progress, continue on another computer
- Tiếng Việt / English

**Controls:** WASD move · mouse look · left click: hold to charge / release to cast / hold to reel / smack · right click: reel in · E: talk, pick up · 1–4: tools · B: bait · Tab: Fish Book · Esc: menu

**Note:** requires an Internet connection and an account (no email needed). Save your recovery codes. Best on desktop Chrome/Edge/Firefox. Privacy: see the included `PRIVACY.md`.

## Ảnh chụp đề xuất (thứ tự)

`p03_arrive.png` (đảo 1, Ông Tư, bến), `p05_waiting.png` (quăng câu), `p06_flying.png` (cá bay), `p07_ko.png` (đập xỉu + trick), `p10_shop.png` (sạp Cô Ba), `p11_quest.png` (nhiệm vụ), `p09_dex.png` (Sổ Cá), `p02_lobby.png` (sảnh tạo/vào phòng).

## Trước khi bấm Publish (REL-01)

1. Máy chủ công khai chạy theo `server/ops/public/README.md`, `/healthz` qua HTTPS trả đúng content_hash.
2. Bản web xuất với endpoint công khai; tải lên trang ở chế độ **Draft/Restricted**; mở bằng trình duyệt ẩn danh: đăng ký, vào phòng, câu, pointer lock, âm thanh, Esc, toàn màn hình.
3. 4 người thật trên ≥2 thiết bị (NET-01), thử đổi thiết bị giữa chừng, tắt/mở room server.
4. Ghi URL, phiên bản, sha256 ZIP vào `reports/TEST_RESULTS.md`; chỉ khi đạt mới chuyển trang sang Public.
