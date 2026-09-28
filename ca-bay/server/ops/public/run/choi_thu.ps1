# Chơi thử trên máy Windows này bằng MỘT cổng (P-035): http://127.0.0.1:8787 là trang game + tài khoản + phòng chơi.
# Bạn bè vào qua Internet: mở PowerShell khác và chạy đường hầm (README mục 0), ví dụ
#   cloudflared tunnel --url http://127.0.0.1:8787      → gửi link https://….trycloudflare.com cho bạn bè
# Bấm lại khi máy chủ đang chạy: chỉ mở lại trình duyệt; cửa sổ máy chủ nào đã bị đóng thì mở lại cửa sổ đó.
$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "CA BAY - khoi dong"

function Test-Port([int]$p) {
  $c = New-Object Net.Sockets.TcpClient
  try { $c.Connect("127.0.0.1", $p); return $true } catch { return $false } finally { $c.Close() }
}

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
$m = Select-String -Path .env -Pattern '^CABAY_WS_PORT=(\d+)' | Select-Object -First 1
$wsPort = if ($m) { $m.Matches[0].Groups[1].Value } else { "8910" }
$started = @()
foreach ($pair in @(@("start_room.ps1", $wsPort), @("start_backend.ps1", $port))) {
  if (Test-Port $pair[1]) { continue }  # đang chạy sẵn: không mở cửa sổ thứ hai
  Start-Process powershell -WorkingDirectory $root -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSScriptRoot\$($pair[0])`"")
  $started += $pair[0]
}
if ($started.Count -gt 0) { Write-Host "Đang khởi động máy chủ (lần đầu có thể mất 1-2 phút)... Hai cửa sổ đen vừa mở là máy chủ: đừng đóng." }
$ok = $false
for ($i = 0; $i -lt 300; $i++) {
  try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 "http://127.0.0.1:$port/healthz"
    if ($r.StatusCode -eq 200) { $ok = $true; break }
  } catch { }
  Start-Sleep -Seconds 1
}
if (-not $ok) { throw "Máy chủ tài khoản chưa chạy sau 5 phút — xem cửa sổ 'CA BAY - may chu tai khoan', chụp màn hình gửi người hỗ trợ" }
Start-Process "http://127.0.0.1:$port/"
Write-Host "Đã mở http://127.0.0.1:$port/ trong trình duyệt. Cửa sổ này có thể đóng; muốn tắt game thì đóng hai cửa sổ máy chủ."
Write-Host "Mời bạn bè qua Internet: cloudflared tunnel --url http://127.0.0.1:$port"
