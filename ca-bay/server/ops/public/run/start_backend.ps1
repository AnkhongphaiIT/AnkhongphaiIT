# Windows: chạy backend (cần Python 3.11 cài từ python.org). Chạy trong PowerShell tại thư mục gói server.
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Test-Path .env)) { throw "Thiếu .env — sao chép run\env.example thành .env và điền giá trị" }
Get-Content .env | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object { $k, $v = $_ -split '=', 2; Set-Item -Path "env:$k" -Value $v }
$env:CABAY_DATA_DIR = (Resolve-Path data).Path
if (-not $env:CABAY_DB_PATH) { New-Item -ItemType Directory -Force var | Out-Null; $env:CABAY_DB_PATH = (Join-Path (Resolve-Path var).Path "cabay.db") }
New-Item -ItemType Directory -Force backups | Out-Null
if (-not (Test-Path .venv\Scripts\python.exe)) { py -3.11 -m venv .venv; .venv\Scripts\pip install -r backend\requirements.lock.txt }
Set-Location backend
& ..\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port $(if ($env:CABAY_API_PORT) { $env:CABAY_API_PORT } else { 8787 }) --proxy-headers --forwarded-allow-ips 127.0.0.1 --no-access-log
