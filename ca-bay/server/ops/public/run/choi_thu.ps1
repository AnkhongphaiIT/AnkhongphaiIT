
# Chơi thử trên máy Windows này bằng MỘT cổng (P-035): http://127.0.0.1:8787 là trang game + tài khoản + phòng chơi.
# Bạn bè vào qua Internet: mở PowerShell khác và chạy đường hầm (README mục 4), ví dụ
#   cloudflared tunnel --url http://127.0.0.1:8787      → gửi link https://….trycloudflare.com cho bạn bè
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
if (-not (Test-Path .env)) {
  $b = New-Object byte[] 32
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
  $key = [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_')
  $lines = Get-Content run\env.example -Encoding UTF8 | ForEach-Object {
    if ($_ -match '^CABAY_SERVICE_KEY=') { "CABAY_SERVICE_KEY=$key" } elseif ($_ -match '^CABAY_SELFHOST=') { "CABAY_SELFHOST=1" } else { $_ }
  }
  [IO.File]::WriteAllLines((Join-Path $root ".env"), [string[]]$lines)
  Write-Host "Đã tạo .env với khóa dịch vụ ngẫu nhiên (không gửi file này cho ai)."
}
if (-not (Select-String -Path .env -Pattern '^CABAY_SELFHOST=1' -Quiet)) { throw "Trong .env hãy đặt CABAY_SELFHOST=1 để chạy một cổng" }
$m = Select-String -Path .env -Pattern '^CABAY_API_PORT=(\d+)' | Select-Object -First 1
$port = if ($m) { $m.Matches[0].Groups[1].Value } else { "8787" }
foreach ($s in @("start_room.ps1", "start_backend.ps1")) {
  Start-Process powershell -WorkingDirectory $root -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSScriptRoot\$s`"")
}
Write-Host "Đang khởi động máy chủ (lần đầu có thể mất vài phút)..."
$ok = $false
for ($i = 0; $i -lt 300; $i++) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 "http://127.0.0.1:$port/healthz"
    if ($r.StatusCode -eq 200) { $ok = $true; break }
  } catch { }
  Start-Sleep -Seconds 1
}
if (-not $ok) { throw "Backend chưa chạy sau 5 phút — xem cửa sổ start_backend" }
Start-Process "http://127.0.0.1:$port/"
Write-Host "Đã mở http://127.0.0.1:$port/ . Đóng hai cửa sổ máy chủ để dừng."
Write-Host "Mời bạn bè qua Internet: cloudflared tunnel --url http://127.0.0.1:$port"
