#!/usr/bin/env bash
# Sao lưu DB đang chạy (SQLite backup API, có sha256). Đặt lịch mỗi giờ bằng cron:  0 * * * * /đường/dẫn/run/backup.sh
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; [ -f .env ] && . ./.env; set +a
exec .venv/bin/python ops/backup.py backup --db "${CABAY_DB_PATH:-$PWD/var/cabay.db}" --out backups --keep 48
