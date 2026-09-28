# Windows: chạy backend tài khoản/lưu (FastAPI + SQLite) + trang game, chỉ nghe localhost. Chạy trong PowerShell tại thư mục gói.
# Gói bản Windows có sẵn Python trong python\ (không cần cài). Nếu không có: cần Python 3.11 từ python.org
# (tick "Add to PATH"); lần đầu tạo .venv và tải thư viện (cần Internet).
$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "CA BAY - may chu tai khoan + trang game (DUNG DONG khi dang choi)"
trap {
  Write-Host ""
  Write-Host "LỖI: $_" -ForegroundColor Red
  Write-Host "Máy chủ tài khoản chưa chạy được. Chụp màn hình cửa sổ này gửi người hỗ trợ." -ForegroundColor Yellow
  break
}

function Test-Port([int]$p) {
  $c = New-Object Net.Sockets.TcpClient
  try { $c.Connect("127.0.0.1", $p); return $true } catch { return $false } finally { $c.Close() }
}

Set-Location (Split-Path $PSScriptRoot -Parent)
Write-Host "CÁ BAY — máy chủ tài khoản + trang game." -ForegroundColor Cyan
Write-Host "ĐỪNG ĐÓNG cửa sổ này khi đang chơi (đóng cửa sổ = tắt game)." -ForegroundColor Yellow
if (-not (Test-Path .env)) { throw "Thiếu .env — chạy CHOI_THU.bat, hoặc sao chép run\env.example thành .env và điền giá trị" }
Get-Content .env -Encoding UTF8 | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object { $k, $v = $_ -split '=', 2; Set-Item -Path "env:$k" -Value $v }
$port = if ($env:CABAY_API_PORT) { $env:CABAY_API_PORT } else { "8787" }
if (Test-Port $port) {
  Write-Host "Cổng $port đang có chương trình khác dùng (thường là máy chủ CÁ BAY đã chạy ở một cửa sổ khác). Cửa sổ này không cần nữa, có thể đóng." -ForegroundColor Yellow
  return
}
$env:CABAY_DATA_DIR = (Resolve-Path data).Path
New-Item -ItemType Directory -Force var | Out-Null
if (-not $env:CABAY_DB_PATH) { $env:CABAY_DB_PATH = (Join-Path (Resolve-Path var).Path "cabay.db") }
New-Item -ItemType Directory -Force backups | Out-Null
if (Test-Path python\python.exe) {
  $py = (Resolve-Path python\python.exe).Path
} else {
  $req = (Get-FileHash backend\requirements.lock.txt -Algorithm SHA256).Hash
  $stamp = if (Test-Path .venv\.req.sha256) { (Get-Content .venv\.req.sha256 -Raw).Trim() } else { "" }
  if (-not (Test-Path .venv\Scripts\python.exe) -or $stamp -ne $req) {
    if (-not (Test-Path .venv\Scripts\python.exe)) {
      try { & py -3.11 -m venv .venv } catch { throw "Không tìm thấy Python 3.11 (lệnh 'py'). Cài từ python.org, tick 'Add to PATH', rồi chạy lại." }
      if ($LASTEXITCODE -ne 0) { throw "Không tạo được .venv bằng Python 3.11" }
    }
    & .venv\Scripts\python.exe -m pip install -r backend\requirements.lock.txt
    if ($LASTEXITCODE -ne 0) { throw "Cài thư viện Python thất bại (cần Internet lần đầu)" }
    Set-Content -Path .venv\.req.sha256 -Value $req
  }
  $py = (Resolve-Path .venv\Scripts\python.exe).Path
}
$extra = @()
if ($env:CABAY_SELFHOST -eq "1") {
  # một cổng (P-035): phục vụ luôn trang game + chuyển tiếp /ws tới room server trên máy này
  $env:CABAY_WEB_DIR = (Resolve-Path web).Path
  $env:CABAY_WS_UPSTREAM = "ws://127.0.0.1:$(if ($env:CABAY_WS_PORT) { $env:CABAY_WS_PORT } else { 8910 })"
  $extra = @("--ws-max-size", "65536")
}
Set-Location backend
& $py -m uvicorn app.main:app --host 127.0.0.1 --port $port --proxy-headers --forwarded-allow-ips 127.0.0.1 --no-access-log @extra
Write-Host ""
Write-Host "Máy chủ tài khoản đã dừng (mã thoát $LASTEXITCODE)." -ForegroundColor Red
Write-Host "Nếu bạn không tự tắt: chụp màn hình cửa sổ này gửi người hỗ trợ. Chạy lại: bấm đúp CHOI_THU.bat." -ForegroundColor Yellow
