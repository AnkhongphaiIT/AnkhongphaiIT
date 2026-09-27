# CÁ BAY — Hướng dẫn vận hành máy chủ (runbook)

Gói này chạy phần **tài khoản + lưu tiến trình** (backend Python/FastAPI + SQLite) và **phòng chơi** (room server Godot headless, WebSocket). Bản web (itch.io) chỉ là file tĩnh; người chơi cần máy chủ này online để đăng nhập và chơi.

> Trạng thái: đã chạy thử **trên máy local / container** (xem `reports/TEST_RESULTS.md` trong repo). Chưa chạy trên Internet công khai. Các dịch vụ đường hầm bên dưới **chưa được xác minh điều khoản/giới hạn** từ phiên phát triển — kiểm tra trước khi dùng.

## 1. Cần có

| Thứ | Linux | Windows |
|---|---|---|
| Python | 3.11 | 3.11 (python.org, tick "Add to PATH") |
| Godot để chạy room server | có sẵn `room/ca-bay-room-server.x86_64` | tải **Godot 4.7.2 stable** bản `win64_console.exe` từ godotengine.org (đúng 4.7.2) |
| Đĩa bền | thư mục `var/` (DB) và `backups/` phải nằm trên ổ không bị xóa | như Linux |
| RAM/CPU | ~300 MB backend + ~150 MB room server mỗi tiến trình; 4 phòng × 4 người chạy trên 2 nhân (chưa đo trên máy thật) | như Linux |
| HTTPS + WSS công khai | đường hầm hoặc reverse proxy (mục 4) | như Linux |

## 2. Cài lần đầu

```bash
unzip ca-bay-server-<version>.zip && cd ca-bay-server-<version>
cp run/env.example .env          # Windows: copy run\env.example .env
python3 -c "import secrets;print(secrets.token_urlsafe(32))"   # dán kết quả vào CABAY_SERVICE_KEY trong .env
```

Không gửi `.env` cho ai, không đưa vào Git, không dán vào chat. Khóa này chỉ dùng giữa backend và room server trên cùng máy.

## 3. Chạy

Mở 2 cửa sổ dòng lệnh:

| | Linux | Windows (PowerShell) |
|---|---|---|
| Backend | `run/start_backend.sh` | `powershell -ExecutionPolicy Bypass -File run\start_backend.ps1` |
| Room server | `run/start_room.sh` | `powershell -ExecutionPolicy Bypass -File run\start_room.ps1` (cần `GODOT_EXE` trong `.env`) |

Kiểm tra: `curl http://127.0.0.1:8787/healthz` → `{"ok":true,...,"content_hash":"…"}`. Cửa sổ room server in `CABAY_SERVER listening ws://127.0.0.1:8910 content_hash=…` — **hai content_hash phải giống nhau** và giống bản web (nếu khác: client báo "Cần phiên bản game mới").

Lần chạy đầu backend tự tạo DB ở `var/cabay.db` và áp migration.

## 4. Mở ra Internet (HTTPS/WSS)

Cả hai cổng chỉ nghe `127.0.0.1`; phải có một lớp HTTPS/WSS đứng trước. Hai phương án 0 đồng (chưa xác minh điều khoản):

**A. Tailscale Funnel** (URL cố định dạng `https://<máy>.<tailnet>.ts.net`, cần tài khoản Tailscale miễn phí):
```bash
tailscale funnel --bg --https=443  http://127.0.0.1:8787    # API  → https://<máy>.<tailnet>.ts.net
tailscale funnel --bg --https=8443 http://127.0.0.1:8910    # WS   → wss://<máy>.<tailnet>.ts.net:8443
```

**B. Cloudflare quick tunnel** (URL ngẫu nhiên, đổi mỗi lần chạy — chỉ hợp cho buổi thử ngắn):
```bash
cloudflared tunnel --url http://127.0.0.1:8787    # in ra https://xxxx.trycloudflare.com
cloudflared tunnel --url http://127.0.0.1:8910    # in ra https://yyyy.trycloudflare.com → dùng wss://yyyy.trycloudflare.com
```

Sau khi có URL, xuất bản web trỏ vào đó (trên máy có mã nguồn):
```bash
python3 tools/build/package_web.py --api https://<API> --ws wss://<WS>
```
Rồi tải `release/ca-bay-web-<version>.zip` lên itch.io (loại HTML, "This file will be played in the browser"). Nếu URL đổi (phương án B) phải xuất lại bản web.

`CABAY_ALLOWED_ORIGINS` trong `.env` phải chứa origin thật mà trình duyệt gửi khi chơi trên itch.io (mở DevTools → Network → xem header `Origin` của request `/v1/auth/login`), sau đó khởi động lại backend.

## 5. Sao lưu và khôi phục

- Sao lưu tay: `run/backup.sh` → `backups/cabay-<thời điểm>.db` + `.sha256`, giữ 48 bản mới nhất.
- Đặt lịch: Linux `crontab -e` thêm `0 * * * * /đường/dẫn/run/backup.sh`; Windows dùng Task Scheduler chạy `.venv\Scripts\python.exe ops\backup.py backup --db var\cabay.db --out backups --keep 48` mỗi giờ.
- Kiểm tra một bản: `.venv/bin/python ops/backup.py verify --file backups/<file>.db`
- Khôi phục (không bao giờ ghi đè DB đang chạy):
  1. Dừng backend và room server.
  2. `.venv/bin/python ops/backup.py restore --file backups/<file>.db --to var/cabay.restored.db`
  3. Đổi tên `var/cabay.db` → `var/cabay.broken.db`, rồi `var/cabay.restored.db` → `var/cabay.db`.
  4. Chạy lại backend + room server, kiểm `/healthz`, đăng nhập thử một tài khoản.
- Nên chép `backups/` sang ổ/máy khác định kỳ.

### Tài khoản checkpoint cho buổi chơi thử

`ops/seed_checkpoint.py` tạo tài khoản `checkpoint_…` đã tới một mốc (isl1_boss, isl2_start, isl2_boss, isl3_start, isl3_boss, endgame) bằng chính các giao dịch server dùng khi chơi (có idempotency, kiểm bất biến save). Chỉ chạy trên DB mình quản lý, lúc chưa có người chơi; cần cờ `--yes-this-is-an-operator-db`. Lệnh mẫu ở `release/PLAYTEST_60MIN.md` của mã nguồn:
`CABAY_DATA_DIR=$PWD/data CABAY_DB_PATH=$PWD/var/cabay.db .venv/bin/python ops/seed_checkpoint.py --stage isl2_start --yes-this-is-an-operator-db` (sau khi `set -a; . ./.env; set +a`). Mật khẩu ghi vào `var/checkpoint_accounts.txt` quyền 600, không in ra màn hình. Xóa tài khoản checkpoint sau buổi thử bằng Tùy chọn → Xóa tài khoản.

## 6. Cập nhật phiên bản và quay lại (rollback)

1. Sao lưu DB (mục 5).
2. Dừng hai tiến trình; giải nén gói mới vào thư mục mới; chép `.env`, `var/`, `backups/` sang.
3. Chạy backend mới (migration tự áp một lần, có bảng `schema_migrations`), rồi room server mới; tải bản web cùng phiên bản lên itch.io (content_hash phải khớp).
4. Rollback: dừng bản mới, chạy lại thư mục cũ với **bản sao lưu DB trước khi cập nhật** nếu bản mới đã đổi schema; tải lại ZIP web cũ.

## 7. Dữ liệu người chơi và nhật ký

Backend lưu: tên đăng nhập, tên hiển thị, băm mật khẩu (scrypt), băm mã khôi phục, băm token phiên, tiến trình game, nhật ký kiểm toán giao dịch trong game. Không lưu email, không analytics, không quảng cáo. Xóa tài khoản trong game (Tùy chọn → Xóa tài khoản) xóa dữ liệu tài khoản khỏi DB đang chạy; các bản sao lưu cũ tự hết hạn theo số bản giữ lại. Không in token/mật khẩu ra log; log tiến trình chỉ nên giữ ngắn ngày.

## 8. Sự cố thường gặp

| Hiện tượng | Kiểm tra |
|---|---|
| Client báo "Chưa kết nối được máy chủ" | `/healthz` qua URL công khai; đường hầm còn chạy; `CABAY_ALLOWED_ORIGINS` đúng origin |
| "Cần phiên bản game mới" | content_hash của backend, room server và bản web phải giống nhau |
| Tạo phòng báo máy chủ bận | đã đạt `CABAY_MAX_ROOMS`; phòng trống tự đóng sau 5 phút |
| Room server tắt đột ngột | chạy lại `start_room`; người chơi tự kết nối lại trong 90 s, đồ đã lưu không mất |
