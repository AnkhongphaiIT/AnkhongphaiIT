# Windows: chạy room server Godot headless (WebSocket), chỉ nghe localhost.
# Gói bản Windows có sẵn room\ca-bay-room-server.console.exe. Nếu không có: tải Godot 4.7.2 stable bản
# win64_console.exe từ godotengine.org và đặt đường dẫn vào GODOT_EXE trong .env, ví dụ
#   GODOT_EXE=C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe
$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "CA BAY - may chu phong choi (DUNG DONG khi dang choi)"
trap {
  Write-Host ""
  Write-Host "LỖI: $_" -ForegroundColor Red
  Write-Host "Máy chủ phòng chơi chưa chạy được. Chụp màn hình cửa sổ này gửi người hỗ trợ." -ForegroundColor Yellow
  break
}

function Test-Port([int]$p) {
  $c = New-Object Net.Sockets.TcpClient
  try { $c.Connect("127.0.0.1", $p); return $true } catch { return $false } finally { $c.Close() }
}

Set-Location (Split-Path $PSScriptRoot -Parent)
Write-Host "CÁ BAY — máy chủ phòng chơi." -ForegroundColor Cyan
Write-Host "ĐỪNG ĐÓNG cửa sổ này khi đang chơi (đóng cửa sổ = rớt khỏi phòng)." -ForegroundColor Yellow
if (-not (Test-Path .env)) { throw "Thiếu .env — chạy CHOI_THU.bat trước" }
Get-Content .env -Encoding UTF8 | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object { $k, $v = $_ -split '=', 2; Set-Item -Path "env:$k" -Value $v }
$wsPort = if ($env:CABAY_WS_PORT) { $env:CABAY_WS_PORT } else { "8910" }
if (Test-Port $wsPort) {
  Write-Host "Cổng $wsPort đang có chương trình khác dùng (thường là máy chủ phòng chơi đã chạy ở một cửa sổ khác). Cửa sổ này không cần nữa, có thể đóng." -ForegroundColor Yellow
  return
}
$env:CABAY_BACKEND_URL = "http://127.0.0.1:$(if ($env:CABAY_API_PORT) { $env:CABAY_API_PORT } else { 8787 })"
if (Test-Path room\ca-bay-room-server.console.exe) {
  & room\ca-bay-room-server.console.exe --headless -- --server
} elseif ($env:GODOT_EXE) {
  & $env:GODOT_EXE --headless --main-pack room\ca-bay-room-server.pck -- --server
} else {
  throw "Chưa có room server cho Windows: đặt GODOT_EXE trong .env (Godot 4.7.2 bản win64 console)"
}
Write-Host ""
Write-Host "Máy chủ phòng chơi đã dừng (mã thoát $LASTEXITCODE)." -ForegroundColor Red
Write-Host "Nếu bạn không tự tắt: chụp màn hình cửa sổ này gửi người hỗ trợ. Chạy lại: bấm đúp CHOI_THU.bat." -ForegroundColor Yellow
