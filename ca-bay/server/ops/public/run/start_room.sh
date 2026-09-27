#!/usr/bin/env bash
# Chạy room server Godot headless (WebSocket) chỉ nghe localhost; đường hầm/proxy WSS đứng trước.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || { echo "Thiếu .env"; exit 1; }
set -a; . ./.env; set +a
export CABAY_BACKEND_URL="http://127.0.0.1:${CABAY_API_PORT:-8787}"
# Bản xuất tự nạp file .pck cùng tên nằm cạnh (template không cho --main-pack).
exec ./room/ca-bay-room-server.x86_64 --headless -- --server
