# CÁ BAY (tên tạm)

Game câu cá 3D góc nhìn thứ nhất, low-poly, chơi trên web máy tính (bàn phím + chuột), 1–4 người cùng phòng, tài khoản và tiến trình lưu trên máy chủ. Godot 4.7.2 + backend Python (FastAPI/SQLite).

**Trạng thái thật:** xem `reports/PROJECT_STATUS.md`. Tài liệu thiết kế: `docs/00_START_HERE.md`.

| Thư mục | Nội dung |
|---|---|
| `docs/` | Bộ tài liệu v2.0.0 (00–17), nghiên cứu tham khảo |
| `data/` | Nội dung, hợp đồng, bản dịch, schema — **nguồn duy nhất** |
| `client/`, `ui/`, `shared/`, `server/gameplay/` | Mã Godot (client, logic dùng chung, room server) |
| `server/backend/` | Tài khoản, lưu, giao dịch (FastAPI + SQLite) |
| `tools/` | Kiểm dữ liệu, build, tạo tài nguyên |
| `tests/` | Test tự động |
| `handoff/`, `incoming/` | Yêu cầu ChatGPT gửi tay và nơi nhận file về |
| `reports/` | Preflight, trạng thái, quyết định, test, việc cần chủ dự án |

## Chạy thử trên máy (local)

Cần: Python 3.11, Godot 4.7.2 (`python3 tools/build/install_godot.py` nếu chưa có), trình duyệt Chrome/Edge/Firefox.

```bash
# 1) backend + room server (DB tạm, khóa dịch vụ ngẫu nhiên)
(cd server/backend && python3.11 -m venv .venv && .venv/bin/pip install -r requirements.lock.txt)
python3 tests/integration/stack.py --serve
# 2) bản web trỏ localhost
python3 tools/build/export.py web
python3 -m http.server 8060 --bind 127.0.0.1 --directory build/web
# 3) mở http://127.0.0.1:8060  (mở nhiều tab/nhiều trình duyệt để thử co-op, mỗi tab một tài khoản)
```

## Kiểm thử

| Lệnh | Kiểm gì |
|---|---|
| `.venv/bin/python tools/validate/check_docs.py` | dữ liệu/hợp đồng/bản dịch (không phải gameplay) |
| `(cd server/backend && .venv/bin/python -m pytest -q)` | tài khoản, lưu, giao dịch, idempotency, backup |
| `python3 tools/build/run_godot_tests.py` | biên dịch script, mô phỏng server, giao thức, UI |
| `python3 tests/integration/run_bots.py --scenario fish_loop --bots 4` | bot Godot qua WebSocket + backend thật |
| `python3 tests/integration/run_bots.py --scenario content_all --bots 1 --timeout 2400` | CONTENT-01: bot chơi hết 3 đảo, 3 boss (thêm `--bot-arg=--all-species` để bắt đủ 15 loài) |
| `python3 tests/integration/crash_backend.py --kills 6` | SAVE-03: SIGKILL backend giữa giao dịch, gửi lại cùng op_id không nhân đôi |
| `python3 tests/web/run_web_e2e.py --scenario full_loop` | client web thật trong Chromium: đăng ký → câu → xỉu → nhặt → bán → mua |
| `python3 tests/web/run_web_e2e.py --scenario boss_isl1 --seed-stage isl1_boss` | thắng boss trên trình duyệt bằng tài khoản checkpoint (`boss_isl2`/`isl2_boss`, `boss_isl3`/`isl3_boss`) |
| `python3 tests/web/run_web_e2e.py --scenario meta_isl2 --seed-stage isl2_start` | hộp quà, nướng cá, đi đảo 2, nhận việc |
| `python3 tests/web/run_web_e2e.py --scenario save01_cross --seed-stage isl2_start` | SAVE-01: đổi máy khác origin, bộ nhớ trình duyệt trống |
| `python3 tools/build/export.py web --selfhost && python3 tests/web/run_web_e2e.py --scenario full_loop --selfhost` | một cổng: backend phục vụ trang + chuyển tiếp `/ws` (P-035) |
| `python3 tools/build/check_ps1.py server/ops/public` | script PowerShell đọc đúng trên Windows PowerShell 5.1 (BOM, cú pháp; cần `pwsh`) |
| `python3 tests/web/run_web_e2e.py --scenario room_crash` | room server bị SIGKILL/SIGTERM khi đang chơi → client tự nối lại |
| `python3 tests/web/run_web_e2e.py --scenario coop2` | 2 trình duyệt cùng phòng |
| `… --scenario settings_keys` / `lang_switch` / `focus_freeze` / `perf_probe` / `full_loop --iframe` | đổi phím, đổi ngôn ngữ giữa trận, tab bị ẩn, đo bộ nhớ/dung lượng, chạy trong iframe khác site |

Ảnh chụp và log của mỗi kịch bản trình duyệt nằm ở `tests/web/artifacts/<tên>/` (không commit). Cần Playwright 1.56.1 cài toàn cục (`npm i -g playwright@1.56.1`) và Chromium của Playwright.

## Phát hành

- Bản web: `python3 tools/build/package_web.py --api https://… --ws wss://…` → `release/ca-bay-web-<version>.zip` (chỉ chép file release sang thư mục mới rồi nén — P-011). Thiếu endpoint công khai thì tạo bản `-local` chỉ để thử.
- Máy chủ: `python3 tools/build/package_server.py` → `release/ca-bay-server-<version>-windows.zip` (có sẵn Python 3.11.9 + room server .exe; bấm `CHOI_THU.bat`) và `…-linux.zip` (`run/choi_thu.sh`). Cả hai phục vụ luôn trang game ở một cổng (P-035): một đường hầm HTTPS = một link chơi. Vận hành theo `server/ops/public/README.md`. Tài khoản checkpoint cho buổi chơi thử: `ops/seed_checkpoint.py` trong gói (xem `release/PLAYTEST_60MIN.md`).
- Trang itch.io nháp: `release/ITCH_PAGE.md`; buổi chơi thử: `release/PLAYTEST_60MIN.md`; ghi công: `CREDITS.md`; quyền riêng tư: `PRIVACY.md`.
