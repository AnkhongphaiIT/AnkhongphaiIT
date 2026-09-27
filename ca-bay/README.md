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
| `python3 tests/web/run_web_e2e.py --scenario full_loop` | client web thật trong Chromium: đăng ký → câu → xỉu → nhặt → bán |

## Phát hành

- Bản web: `python3 tools/build/package_web.py --api https://… --ws wss://…` → `release/ca-bay-web-<version>.zip` (chỉ chép file release sang thư mục mới rồi nén — P-011). Thiếu endpoint công khai thì tạo bản `-local` chỉ để thử.
- Máy chủ: `python3 tools/build/package_server.py` → `release/ca-bay-server-<version>.zip`; vận hành theo `server/ops/public/README.md`.
- Trang itch.io nháp: `release/ITCH_PAGE.md`; buổi chơi thử: `release/PLAYTEST_60MIN.md`; ghi công: `CREDITS.md`; quyền riêng tư: `PRIVACY.md`.
