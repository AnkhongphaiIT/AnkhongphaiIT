# PROJECT_STATUS — CÁ BAY

Cập nhật: 27/09/2026 (phiên 1, tối) · Nhánh: `claude/tender-allen-ofqkn5` · Toolchain: Godot 4.7.2.stable (xem `toolchain.lock.json`)

## Tóm tắt trung thực theo lớp

| Lớp | Trạng thái | Bằng chứng |
|---|---|---|
| Tài liệu/dữ liệu | **Đạt** | validator 0 lỗi/0 cảnh báo, 362 khóa VI/EN |
| Code chạy local | **Chạy được**: backend + room server Godot headless + client web thật trong Chromium; cả **gói server phát hành** đã chạy thử | `TEST_RESULTS.md`: pytest 36, Godot 25, bot 1–4 người (quest/boss, **CONTENT-01 3 đảo + 15/15 loài**, takeover, restart, 2 phòng), WEB-E2E fish_loop/full_loop/npc_shop/coop2/promo/**boss_isl1**/**meta_isl2** |
| Co-op đã thử thật | **Chưa với người thật**. Đã có: 4 bot qua WebSocket thật; **2 trình duyệt thật cùng phòng** thấy nhau và nhận sự kiện của nhau. NET-01 (4 người, ≥2 máy, Internet) cần host + người | NEED-HOST, NEED-DEVICES |
| Tài nguyên | **Đủ file cho 295/296 asset ID (thêm 9 icon CR-007)** (1 ngoài phạm vi: điều khiển cảm ứng). 282 `in_review` (tự tạo, đã kiểm tự động, **chưa có người duyệt**), 12 `placeholder` (thoại espeak-ng, không phát hành), font `approved`. Yêu cầu **giọng đọc VI/EN chưa đạt** | `reports/ASSET_COVERAGE.md`, `handoff/source_manifest.json`, `reports/AUDIO_REPORT.md` |
| Public đã xác minh | **Chưa** — thiếu host (NEED-HOST) và quyền itch.io (NEED-ITCH) | — |

## Mốc

| Mốc | Trạng thái | Ghi chú |
|---|---|---|
| WP-00 preflight/cấu trúc | VERIFIED | commit `2195762` |
| M0 nền tảng | VERIFIED (local) | Export web thật chạy qua HTTP trong Chromium (WebGL2, không thread); gói .pck quét sạch mã server/test/secret; audio unlock bằng cú nhấp đầu. Pointer lock thật chưa kiểm tự động (xem WEB-01) |
| M1 mạng/tài khoản | IMPLEMENTED, VERIFIED (bot) | Đăng ký/đăng nhập/khôi phục/đổi mật khẩu/xóa (backend pytest), ticket 30 s dùng một lần, phòng ≤4, reconnect, chuyển chủ phòng, **tiếp quản thiết bị không nhân đôi**, **room server khởi động lại**, **2 phòng song song** (bot qua mạng thật). Chưa: 2 thiết bị thật, người thật qua Internet |
| M2 một đảo trọn vòng | IMPLEMENTED, VERIFIED (trình duyệt + bot) | Trên **trình duyệt thật**: câu→cắn→giật→kéo→cá bay→đập xỉu→trick→nhặt→bán→mua, NPC quà dép, nhiệm vụ, Sổ Cá, **gọi + thắng boss Lóc Già**, **nướng cá**, **mở hộp quà**, **đi đảo 2**. Chưa: người thật đánh giá cảm giác chơi |
| M3 đủ 3 đảo | IMPLEMENTED, VERIFIED (bot) | Bot chơi qua mạng thật hết 6 nhiệm vụ, 3 boss, mở 3 đảo, bắt đủ 15/15 loài thường (CONTENT-01 bằng bot). Chưa có người thật chơi hết; tài khoản checkpoint cho playtest: `server/ops/seed_checkpoint.py` |
| M4 tài nguyên | IN_PROGRESS | 54 mô hình bake, 32 icon, 60 clip hoạt ảnh, 19 VFX, 4 shader, môi trường/vật liệu/theme, 80 audio — dùng thật trong game. Còn: người duyệt; giọng đọc thật; batch ChatGPT chờ relay |
| M5 chất lượng | NOT_STARTED phần lớn | Đã đo kích thước web: bản phát hành 46,1 MB (wasm 39,5 MB chưa nén). FPS/bộ nhớ chưa đo trên máy thật |
| M6 phát hành | BLOCKED_EXTERNAL (host, itch.io, liên hệ) | **Đã có**: ZIP web theo P-011 (15,9 MB nén), gói server + runbook Linux/Windows + sao lưu/khôi phục (đã chạy thử), PRIVACY VI/EN, CREDITS + giấy phép, CHANGELOG, trang itch nháp + ảnh thật, kịch bản playtest 60 phút. Bản công khai tự chặn khi chưa có NEED-CONTACT |

## Việc đã làm trong phiên này (tóm tắt)

- Client web đầy đủ luồng: khởi động (mở âm) → đăng ký/đăng nhập/khôi phục (mã khôi phục, tải .txt) → sảnh (tạo phòng 3 đảo, vào bằng mã, phòng đang mở, tiếp quản thiết bị) → trong game (HUD, thanh công cụ, mồi, túi, mục tiêu nhiệm vụ, popup trick/giá, phụ đề, thanh boss, đội, trạng thái mạng) → menu (tạm dừng, sạp, NPC nhiệm vụ, Sổ Cá, hộp quà có công khai tỉ lệ, túi/ăn/đổi mồi, đi đảo, cài đặt + tài khoản) → tự kết nối lại trong 85 s, lệnh bền vững gửi lại cùng op_id.
- Server: gửi bản xem save khi vào phòng; đánh dấu hướng dẫn vào save; máu boss cho HUD (CR-004); bù trễ có giới hạn cho đòn đánh (P-020); thời gian choáng khi cá rơi (CR-005).
- Công cụ: `tools/build/export.py` (web/server, `--release`, kiểm URL https/wss, quét .pck), `tests/web/run_web_e2e.py` + `drive.cjs` (Chromium thật).
- Âm thanh (subagent WP-09): 166 file, validator đạt, tái tạo byte-giống-hệt.

## Tài nguyên còn tạm

- Thoại VI/EN: espeak-ng (giọng máy, GPL/tbd) — **chưa đạt** yêu cầu giọng đọc; bản phát hành loại thoại tạm, chỉ phụ đề + âm "lẩm bẩm".
- Toàn bộ mô hình/icon/hoạt ảnh/VFX/âm thanh tự tạo đang `in_review` — chưa có người xem/nghe duyệt.
- Ảnh concept/ảnh cửa hàng từ ChatGPT: gói yêu cầu b01/b02 chờ chủ dự án chuyển tay.

## Blocker

Xem `reports/NEEDS_USER.md`. Không có blocker cho lập trình. Mới: NEED-VOICE-LICENSE (quyết định dùng thoại espeak-ng).
