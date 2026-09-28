# PROJECT_STATUS — CÁ BAY

Cập nhật: 28/09/2026 (phiên 2, rạng sáng) · Nhánh: `claude/tender-allen-ofqkn5` · Toolchain: Godot 4.7.2.stable (xem `toolchain.lock.json`)

## Tóm tắt trung thực theo lớp

| Lớp | Trạng thái | Bằng chứng |
|---|---|---|
| Tài liệu/dữ liệu | **Đạt** | validator 0 lỗi/0 cảnh báo, 393 khóa VI/EN, 296 asset ID |
| Code chạy local | **Chạy được**: backend + room server Godot headless + client web thật trong Chromium; cả **gói máy chủ phát hành** (giải nén thư mục mới, chạy bằng script vận hành) | `TEST_RESULTS.md`: pytest 37, Godot 28, bot 1–4 người (quest/boss, **CONTENT-01 3 đảo + 15/15 loài**, takeover, restart, 2 phòng, gửi lại lệnh, crash backend SIGKILL ×6), WEB-E2E trình duyệt: câu→bán→mua, **thắng cả 3 boss**, nướng cá, hộp quà, đi đảo, **đổi máy khác origin (SAVE-01)**, đổi phím, tab ẩn, co-op 2 trình duyệt, chạy trong iframe khác site |
| Co-op đã thử thật | **Chưa với người thật**. Đã có: 4 bot qua WebSocket thật; **2 trình duyệt thật cùng phòng** thấy nhau và nhận sự kiện của nhau. NET-01 (4 người, ≥2 máy, Internet) cần host + người; Firefox chưa thử (mạng chặn tải) | NEED-HOST, NEED-DEVICES |
| Tài nguyên | **Đủ file cho 295/296 asset ID (thêm 9 icon CR-007)** (1 ngoài phạm vi: điều khiển cảm ứng). 282 `in_review` (tự tạo, đã kiểm tự động, **chưa có người duyệt**), 12 `placeholder` (thoại espeak-ng, không phát hành), font `approved`. Yêu cầu **giọng đọc VI/EN chưa đạt** | `reports/ASSET_COVERAGE.md`, `handoff/source_manifest.json`, `reports/AUDIO_REPORT.md` |
| Public đã xác minh | **Chưa** — thiếu host (NEED-HOST) và quyền itch.io (NEED-ITCH) | — |

## Mốc

| Mốc | Trạng thái | Ghi chú |
|---|---|---|
| WP-00 preflight/cấu trúc | VERIFIED | commit `2195762` |
| M0 nền tảng | VERIFIED (local) | Export web thật chạy qua HTTP trong Chromium (WebGL2, không thread); gói .pck quét sạch mã server/test/secret và **không có chế độ autotest** (P-028); audio unlock bằng cú nhấp đầu. Pointer lock/Firefox cần máy thật (WEB-01) |
| M1 mạng/tài khoản | IMPLEMENTED, VERIFIED (bot) | Đăng ký/đăng nhập/khôi phục/đổi mật khẩu/xóa (backend pytest), ticket 30 s dùng một lần, phòng ≤4, reconnect, chuyển chủ phòng, **tiếp quản thiết bị không nhân đôi**, **room server khởi động lại**, **2 phòng song song** (bot qua mạng thật). Chưa: 2 thiết bị thật, người thật qua Internet |
| M2 một đảo trọn vòng | IMPLEMENTED, VERIFIED (trình duyệt + bot) | Trên **trình duyệt thật**: câu→cắn→giật→kéo→cá bay→đập xỉu→trick→nhặt→bán→mua, NPC quà dép, nhiệm vụ, Sổ Cá, **gọi + thắng boss Lóc Già**, **nướng cá**, **mở hộp quà**, **đi đảo 2**. Chưa: người thật đánh giá cảm giác chơi |
| M3 đủ 3 đảo | IMPLEMENTED, VERIFIED (bot) | Bot chơi qua mạng thật hết 6 nhiệm vụ, 3 boss, mở 3 đảo, bắt đủ 15/15 loài thường (CONTENT-01 bằng bot). Chưa có người thật chơi hết; tài khoản checkpoint cho playtest: `server/ops/seed_checkpoint.py` |
| M4 tài nguyên | IN_PROGRESS | 54 mô hình, 41 icon, 60 clip hoạt ảnh, 19 VFX, 4 shader, môi trường riêng từng đảo (P-031), 80 audio — dùng thật trong game. Còn: người duyệt; **giọng đọc thật** (NEED-VOICE-LICENSE); batch ChatGPT chờ relay; tay/NPC còn thô |
| M5 chất lượng | IN_PROGRESS | Đạt bằng máy: SAVE-01/02/03, NET-02, restart, CONTENT-01 (bot), UX-01 đổi phím, cá đầu tiên ≤ 60 s, tab ẩn không trôi nhân vật. Đang làm (agent QA WP-12): mất mạng 10/60/100 s, mạng xấu (trễ + jitter), boss co-op vào giữa trận/rời/thua-thử lại, giết room server giữa trận boss. Chưa: FPS/bộ nhớ trên máy thật, 4 người thật |
| M6 phát hành | BLOCKED_EXTERNAL (host, itch.io, liên hệ) | **Đã có và đã kiểm trên thư mục giải nén**: ZIP web theo P-011 (16,0 MB nén / 46,5 MB), gói máy chủ 28,9 MB + runbook Linux/Windows + sao lưu/khôi phục + công cụ tài khoản checkpoint, PRIVACY VI/EN, CREDITS + giấy phép, CHANGELOG, trang itch nháp + 17 ảnh thật (cả 3 đảo, 3 boss), kịch bản playtest 60 phút. Bản công khai tự chặn khi chưa có NEED-CONTACT |

## Việc đã làm gần đây (tóm tắt)

- Phiên 1: client web đầy đủ luồng (khởi động → tài khoản → sảnh → trong game → menu → tự nối lại), room server + backend, công cụ build/đóng gói/E2E, âm thanh (subagent WP-09), bot CONTENT-01 (subagent WP-11a).
- Phiên 2: sửa 7 lỗi bot QA tìm (P0 gọi boss lặp miễn phí, takeover đá nhầm, …; P-023/P-024); trận boss hồi sinh trong bãi + vòng phao + tầm đánh khớp (CR-006); bếp không khóa (P-025); nhận việc tại người giao (P-026); dọn định kỳ backend (P-027); tắt autotest ở bản phát hành (P-028); đổi phím (P-029); bỏ input cũ khi tab ẩn (P-030); bản sắc 3 đảo (P-031); tỉ lệ hộp quà hiển thị đúng; công cụ tài khoản checkpoint (P-022); 9 icon mới (CR-007).

- Phiên 3 (28/09): chủ dự án hỏi link game → chưa có link công khai (NEED-HOST/NEED-ITCH). Làm đường tự host **một cổng** (P-035: backend phục vụ trang + chuyển tiếp `/ws`; client `@origin`), gói máy chủ **Windows** có sẵn Python 3.11.9 + room server `.exe` + `CHOI_THU.bat` và gói **Linux** `run/choi_thu.sh` (P-038). Sửa 3 lỗi bảo mật/vận hành: `?api=` đổi được máy chủ ở bản công khai (P-034), giả IP qua `X-Forwarded-For` để lách giới hạn thử sai (P-036), script PowerShell lỗi cú pháp trên PS 5.1 (P-037). Kiểm: E2E một cổng (full_loop, room_crash), gói Linux qua `choi_thu.sh`, backend Windows dưới Wine; room server `.exe` **chưa chạy được thử** (Wine 9 không chạy Godot 4.7) → chờ chủ dự án thử trên Windows thật.

## Tài nguyên còn tạm

- Thoại VI/EN: espeak-ng (giọng máy, GPL/tbd) — **chưa đạt** yêu cầu giọng đọc; bản phát hành loại thoại tạm, chỉ phụ đề + âm "lẩm bẩm".
- Toàn bộ mô hình/icon/hoạt ảnh/VFX/âm thanh tự tạo đang `in_review` — chưa có người xem/nghe duyệt.
- Ảnh concept/ảnh cửa hàng từ ChatGPT: gói yêu cầu b01/b02 chờ chủ dự án chuyển tay.

## Blocker

Xem `reports/NEEDS_USER.md`. Không có blocker cho lập trình. Mới: NEED-VOICE-LICENSE (quyết định dùng thoại espeak-ng).
