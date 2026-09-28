#!/usr/bin/env bash
# Chạy backend tài khoản/lưu (FastAPI + SQLite) chỉ nghe localhost; đường hầm/proxy HTTPS đứng trước.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || { echo "Thiếu .env — sao chép run/env.example thành .env và điền giá trị (hoặc chạy run/choi_thu.sh)"; exit 1; }
set -a; . ./.env; set +a
export CABAY_DATA_DIR="$PWD/data"
export CABAY_DB_PATH="${CABAY_DB_PATH:-$PWD/var/cabay.db}"
mkdir -p var backups
req_hash=$(sha256sum backend/requirements.lock.txt | cut -d' ' -f1)
if [ ! -x .venv/bin/python ] || [ "$(cat .venv/.req.sha256 2>/dev/null)" != "$req_hash" ]; then
  [ -x .venv/bin/python ] || python3.11 -m venv .venv
  .venv/bin/pip install --require-virtualenv -r backend/requirements.lock.txt
  echo "$req_hash" > .venv/.req.sha256
fi
extra=()
if [ "${CABAY_SELFHOST:-0}" = "1" ]; then
  # một cổng (P-035): phục vụ luôn trang game + chuyển tiếp /ws tới room server trên máy này
  export CABAY_WEB_DIR="$PWD/web"
  export CABAY_WS_UPSTREAM="ws://127.0.0.1:${CABAY_WS_PORT:-8910}"
  extra=(--ws-max-size 65536)
fi
cd backend
exec ../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port "${CABAY_API_PORT:-8787}" --proxy-headers --forwarded-allow-ips 127.0.0.1 --no-access-log ${extra[@]+"${extra[@]}"}
