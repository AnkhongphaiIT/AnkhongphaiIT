#!/usr/bin/env python3
"""Nghiệm thu gói máy chủ **Windows** đã giải nén và đang chạy (bấm CHOI_THU.bat) trên máy Windows thật — P-045.

  python tests/integration/win_package_check.py --pkg "<thư mục gói đã giải nén>" --scenario restart --bots 1
  python tests/integration/win_package_check.py --pkg "<...>" --scenario fish_loop --bots 4 --bot-arg=--ping=1

Chạy bot Godot của dự án này (cùng content_hash với gói) tới trang một cổng http://127.0.0.1:8787 + /ws của gói.
Khi bot in "BOTSIGNAL restart_room": tắt đột ngột room server .exe của gói (taskkill /F, như đóng cửa sổ/sập), đóng
cửa sổ PowerShell cũ của nó rồi mở lại run\\start_room.ps1 trong cửa sổ mới đúng lệnh CHOI_THU.bat dùng.
Cần GODOT_BIN (bản _console.exe để thấy log). run_bots.py/stack.py chỉ chạy trên Linux (killpg).
"""
from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROOM_EXES = ("ca-bay-room-server.console.exe", "ca-bay-room-server.exe")


def port_open(port: int) -> bool:
    with socket.socket() as s:
        s.settimeout(0.5)
        return s.connect_ex(("127.0.0.1", port)) == 0


def ps(cmd: str) -> str:
    return subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", cmd],
                          capture_output=True, text=True, encoding="utf-8", errors="replace").stdout


def restart_room(pkg: Path, ws_port: int) -> float:
    t0 = time.time()
    for exe in ROOM_EXES:
        subprocess.run(["taskkill", "/F", "/IM", exe], capture_output=True)
    # cửa sổ PowerShell cũ của start_room.ps1 (gói này) còn mở ở dòng "đã dừng": đóng để không dồn cửa sổ
    ps("Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*start_room.ps1*' } "
       "| ForEach-Object { Stop-Process -Id $_.ProcessId -Force }")
    while port_open(ws_port) and time.time() - t0 < 15:
        time.sleep(0.2)
    script = pkg / "run" / "start_room.ps1"
    ps(f"Start-Process powershell -WorkingDirectory '{pkg}' -ArgumentList @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', "
       f"'-File', '\"{script}\"')")
    while not port_open(ws_port) and time.time() - t0 < 120:
        time.sleep(0.2)
    return time.time() - t0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pkg", required=True, help="thư mục gói ca-bay-server-<v>-windows đã giải nén")
    ap.add_argument("--scenario", default="restart")
    ap.add_argument("--bots", type=int, default=1)
    ap.add_argument("--api-port", type=int, default=8787)
    ap.add_argument("--ws-port", type=int, default=8910)
    ap.add_argument("--timeout", type=float, default=900.0)
    ap.add_argument("--bot-arg", action="append", default=[])
    a = ap.parse_args()
    pkg = Path(a.pkg).resolve()
    godot = os.environ.get("GODOT_BIN")
    if not godot or not (pkg / "run" / "start_room.ps1").exists():
        print("Cần GODOT_BIN và --pkg trỏ vào gói Windows đã giải nén")
        return 2
    health = json.loads(urllib.request.urlopen(f"http://127.0.0.1:{a.api_port}/healthz", timeout=5).read())
    print("healthz", health, "| gói", (pkg / "VERSION").read_text(encoding="utf-8").strip())
    cmd = [godot, "--headless", "--path", str(ROOT), "res://tests/bots/bot_runner.tscn", "--", f"--scenario={a.scenario}",
           f"--bots={a.bots}", f"--api=http://127.0.0.1:{a.api_port}", f"--ws=ws://127.0.0.1:{a.api_port}/ws",
           f"--timeout={a.timeout}", *a.bot_arg]
    p = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                         errors="replace", bufsize=1)
    res = None
    restarts: list[float] = []
    deadline = time.time() + a.timeout + 60
    for ln in p.stdout:
        ln = ln.rstrip("\n")
        if ln.startswith("BOTRESULT "):
            res = json.loads(ln[len("BOTRESULT "):])
        elif ln.startswith("CHECK ") or ln.startswith("MARK") or "ERROR" in ln:
            print(ln[:400], flush=True)
        if ln.startswith("BOTSIGNAL restart_room"):
            took = restart_room(pkg, a.ws_port)
            restarts.append(round(took, 1))
            print(f"[win] room server .exe bị tắt đột ngột và mở lại qua start_room.ps1 sau {took:.1f}s", flush=True)
        if time.time() > deadline:
            p.kill()
            print("TIMEOUT")
            break
    p.wait(30)
    ok = bool(res and res.get("ok"))
    summary = {"scenario": a.scenario, "bots": a.bots, "ok": ok, "restarts_s": restarts,
               "net": (res or {}).get("net", {}), "failed": [k for k, v in ((res or {}).get("checks") or {}).items() if not v.get("ok")]}
    print("WINPKG_RESULT " + json.dumps(summary, ensure_ascii=False))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
