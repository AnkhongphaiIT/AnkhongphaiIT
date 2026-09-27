# Windows: chạy room server bằng Godot 4.7.2 bản chính thức (file Godot_v4.7.2-stable_win64_console.exe tải từ godotengine.org).
# Đặt đường dẫn exe vào biến GODOT_EXE trong .env, ví dụ: GODOT_EXE=C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not (Test-Path .env)) { throw "Thiếu .env" }
Get-Content .env | Where-Object { $_ -match '^[A-Z_]+=' } | ForEach-Object { $k, $v = $_ -split '=', 2; Set-Item -Path "env:$k" -Value $v }
if (-not $env:GODOT_EXE) { throw "Chưa đặt GODOT_EXE trong .env" }
$env:CABAY_BACKEND_URL = "http://127.0.0.1:$(if ($env:CABAY_API_PORT) { $env:CABAY_API_PORT } else { 8787 })"
& $env:GODOT_EXE --headless --main-pack room\ca-bay-room-server.pck -- --server
