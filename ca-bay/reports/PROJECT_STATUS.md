# PROJECT_STATUS — CÁ BAY

Cập nhật: 27/09/2026 (phiên 1, chiều) · Nhánh: `claude/tender-allen-ofqkn5` · Toolchain: Godot 4.7.2.stable (xem `toolchain.lock.json`)

## Tóm tắt trung thực theo lớp

| Lớp | Trạng thái | Bằng chứng |
|---|---|---|
| Tài liệu/dữ liệu | **Đạt** | validator 0 lỗi/0 cảnh báo, 362 khóa VI/EN |
| Code chạy local | **Chạy được**: backend + room server Godot headless + client web thật trong Chromium | `TEST_RESULTS.md`: pytest 26, Godot 18, bot 4 người, WEB-E2E fish_loop |
| Co-op đã thử thật | **Chưa (người thật)** — mới có 4 bot tự động qua WebSocket thật và 1 client trình duyệt; NET-01 cần người + host | NEED-HOST, NEED-DEVICES |
| Tài nguyên cuối | **Chưa**. Có: mô hình low-poly procedural (đảo, NPC, 18 loài), font Be Vietnam Pro (OFL), 80/80 asset âm thanh tự tổng hợp (SFX, nhạc, ambience, gibberish). Thoại espeak-ng là **bản tạm**, giấy phép chưa chốt, loại khỏi bản phát hành | `assets/fonts/SOURCES.md`, `reports/AUDIO_REPORT.md`, `assets/audio/vo/LICENSE-VO.md` |
| Public đã xác minh | **Chưa** — thiếu host (NEED-HOST) và quyền itch.io (NEED-ITCH) | — |

## Mốc

| Mốc | Trạng thái | Ghi chú |
|---|---|---|
| WP-00 preflight/cấu trúc | VERIFIED | commit `2195762` |
| M0 nền tảng | VERIFIED (local) | Export web thật chạy qua HTTP trong Chromium (WebGL2, không thread); gói .pck quét sạch mã server/test/secret; audio unlock bằng cú nhấp đầu. Pointer lock thật chưa kiểm tự động (xem WEB-01) |
| M1 mạng/tài khoản | IMPLEMENTED, VERIFIED một phần | Đăng ký/đăng nhập/khôi phục/đổi mật khẩu/xóa (backend pytest), ticket 30 s dùng một lần, phòng ≤4, reconnect, chuyển chủ phòng (bot). Chưa: server restart test, đồng bộ 2 thiết bị thật, người thật |
| M2 một đảo trọn vòng | IN_PROGRESS | Câu→cắn→giật→kéo→cá bay→đập xỉu→trick→nhặt chạy trên **trình duyệt thật** và 4 bot. UI bán/mua/nấu/nhiệm vụ/boss/lootbox đã viết, **chưa chạy E2E trên trình duyệt**; bot kịch bản quest+boss chưa viết |
| M3 đủ 3 đảo | IN_PROGRESS | Dữ liệu + bố cục 3 đảo, 3 boss, 15 loài, NPC, nhiệm vụ đã có trong mô phỏng; chưa có playthrough tự động 3 đảo (CONTENT-01) |
| M4 tài nguyên | IN_PROGRESS | Xem lớp "Tài nguyên cuối" |
| M5 chất lượng | NOT_STARTED phần lớn | Đã đo kích thước web: bản phát hành 46,1 MB (wasm 39,5 MB chưa nén). FPS/bộ nhớ chưa đo trên máy thật |
| M6 phát hành | BLOCKED_EXTERNAL một phần (host, itch.io) | Script export/phát hành đã có; ZIP, trang itch, privacy, credits, runbook chưa làm |

## Việc đã làm trong phiên này (tóm tắt)

- Client web đầy đủ luồng: khởi động (mở âm) → đăng ký/đăng nhập/khôi phục (mã khôi phục, tải .txt) → sảnh (tạo phòng 3 đảo, vào bằng mã, phòng đang mở, tiếp quản thiết bị) → trong game (HUD, thanh công cụ, mồi, túi, mục tiêu nhiệm vụ, popup trick/giá, phụ đề, thanh boss, đội, trạng thái mạng) → menu (tạm dừng, sạp, NPC nhiệm vụ, Sổ Cá, hộp quà có công khai tỉ lệ, túi/ăn/đổi mồi, đi đảo, cài đặt + tài khoản) → tự kết nối lại trong 85 s, lệnh bền vững gửi lại cùng op_id.
- Server: gửi bản xem save khi vào phòng; đánh dấu hướng dẫn vào save; máu boss cho HUD (CR-004); bù trễ có giới hạn cho đòn đánh (P-020); thời gian choáng khi cá rơi (CR-005).
- Công cụ: `tools/build/export.py` (web/server, `--release`, kiểm URL https/wss, quét .pck), `tests/web/run_web_e2e.py` + `drive.cjs` (Chromium thật).
- Âm thanh (subagent WP-09): 166 file, validator đạt, tái tạo byte-giống-hệt.

## Tài nguyên còn tạm

- Thoại VI/EN: espeak-ng (giọng máy, GPL/tbd) — **chưa đạt** yêu cầu giọng đọc.
- Tay/cần góc nhìn thứ nhất, hoạt ảnh nhân vật: procedural thô, cần làm đẹp.
- Icon, VFX (bọt nước, sao xỉu dạng chữ), ảnh quảng bá: chưa có.

## Blocker

Xem `reports/NEEDS_USER.md`. Không có blocker cho lập trình. Mới: NEED-VOICE-LICENSE (quyết định dùng thoại espeak-ng).
