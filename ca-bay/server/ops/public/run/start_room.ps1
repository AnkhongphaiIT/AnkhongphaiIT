
# Windows: chạy room server Godot headless (WebSocket), chỉ nghe localhost.
# Gói bản Windows có sẵn room\ca-bay-room-server.console.exe. Nếu không có: tải Godot 4.7.2 stable bản
# win64_console.exe từ godotengine.org và đặt đường dẫn vào GODOT_EXE trong .env, ví dụ
#   GODOT_EXE=C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Test-Path .env)) { throw "Thiếu .env — chạy CHOI_THU.bat trước" }
Get-Content .env -Encoding UTF8 | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object { $k, $v = $_ -split '=', 2; Set-Item -Path "env:$k" -Value $v }
$env:CABAY_BACKEND_URL = "http://127.0.0.1:$(if ($env:CABAY_API_PORT) { $env:CABAY_API_PORT } else { 8787 })"
if (Test-Path room\ca-bay-room-server.console.exe) {
  & room\ca-bay-room-server.console.exe --headless -- --server
} elseif ($env:GODOT_EXE) {
  & $env:GODOT_EXE --headless --main-pack room\ca-bay-room-server.pck -- --server
} else {
  throw "Chưa có room server cho Windows: đặt GODOT_EXE trong .env (Godot 4.7.2 bản win64 console)"
}
