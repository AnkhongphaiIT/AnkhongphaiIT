#!/usr/bin/env bash
# Chạy backend tài khoản/lưu (FastAPI + SQLite) chỉ nghe localhost; đường hầm/proxy HTTPS đứng trước.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || { echo "Thiếu .env — sao chép run/env.example thành .env và điền giá trị"; exit 1; }
set -a; . ./.env; set +a
export CABAY_DATA_DIR="$PWD/data"
export CABAY_DB_PATH="${CABAY_DB_PATH:-$PWD/var/cabay.db}"
mkdir -p var backups
if [ ! -x .venv/bin/python ]; then
  python3.11 -m venv .venv
  .venv/bin/pip install --require-virtualenv -r backend/requirements.lock.txt
fi
cd backend
exec ../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port "${CABAY_API_PORT:-8787}" --proxy-headers --forwarded-allow-ips 127.0.0.1
