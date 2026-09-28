#!/usr/bin/env bash
# Chơi thử trên máy này bằng MỘT cổng (P-035): trang game + tài khoản + phòng chơi ở http://127.0.0.1:8787
# Muốn bạn bè vào qua Internet: mở cửa sổ khác, chạy đường hầm (README mục 4), ví dụ
#   cloudflared tunnel --url http://127.0.0.1:8787      → gửi link https://….trycloudflare.com cho bạn bè
# Dừng: Ctrl+C (tắt cả room server).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p var
if [ ! -f .env ]; then
  umask 077
  key=$(python3 -c "import secrets;print(secrets.token_urlsafe(32))")
  sed -e "s|^CABAY_SERVICE_KEY=.*|CABAY_SERVICE_KEY=$key|" -e "s|^CABAY_SELFHOST=.*|CABAY_SELFHOST=1|" run/env.example > .env
  echo "Đã tạo .env với khóa dịch vụ ngẫu nhiên (không in ra; không gửi file này cho ai)."
fi
grep -q '^CABAY_SELFHOST=1' .env || { echo "Trong .env hãy đặt CABAY_SELFHOST=1 để chạy một cổng"; exit 1; }
port=$(grep -E '^CABAY_API_PORT=' .env | cut -d= -f2); port=${port:-8787}
run/start_room.sh > var/room.log 2>&1 &
room=$!
trap 'kill "$room" 2>/dev/null || true' EXIT
echo "Room server đang chạy (log: var/room.log). Mở trình duyệt: http://127.0.0.1:$port"
run/start_backend.sh
