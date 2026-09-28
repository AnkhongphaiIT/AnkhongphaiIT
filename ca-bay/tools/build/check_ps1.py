#!/usr/bin/env python3
"""Kiểm script PowerShell như Windows PowerShell 5.1 (mặc định trên Windows 10/11) sẽ đọc:
file không có BOM bị đọc theo bảng mã ANSI (cp1252) → chữ tiếng Việt UTF-8 thành ký tự lạ, có byte thành dấu nháy
“ ” mà PowerShell coi là nháy kép → vỡ chuỗi/lệnh. Yêu cầu: có BOM UTF-8 và phân tích cú pháp không lỗi (cần `pwsh`).

  python3 tools/build/check_ps1.py <file.ps1|thư mục> ...
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

BOM = b"\xef\xbb\xbf"
PARSE = r"""
$errs = $null; $tokens = $null
$text = [Console]::In.ReadToEnd()
[void][System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errs)
$errs | ForEach-Object { $_.Message + " @" + $_.Extent.StartLineNumber } | ConvertTo-Json -Compress
"""


def as_ps51_reads(raw: bytes) -> str:
    return raw[3:].decode("utf-8") if raw.startswith(BOM) else raw.decode("cp1252", errors="replace")


def check(paths: list[Path]) -> list[str]:
    problems = []
    pwsh = shutil.which("pwsh")
    files = [f for p in paths for f in ([p] if p.is_file() else sorted(p.rglob("*.ps1")))]
    for f in files:
        raw = f.read_bytes()
        if not raw.startswith(BOM) and any(b >= 128 for b in raw):
            problems.append(f"{f}: có ký tự ngoài ASCII nhưng thiếu BOM UTF-8 (PowerShell 5.1 sẽ đọc sai)")
        if pwsh:
            r = subprocess.run([pwsh, "-NoProfile", "-NonInteractive", "-Command", PARSE], input=as_ps51_reads(raw),
                               capture_output=True, text=True, encoding="utf-8", timeout=120)
            out = r.stdout.strip()
            errs = json.loads(out) if out else []
            if isinstance(errs, str):
                errs = [errs]
            problems += [f"{f}: {e}" for e in errs]
    if not pwsh:
        print("CHECK_PS1: không có pwsh — chỉ kiểm BOM, chưa kiểm cú pháp")
    print(f"CHECK_PS1 files={len(files)} problems={len(problems)}")
    return problems


if __name__ == "__main__":
    probs = check([Path(a) for a in sys.argv[1:]])
    for p in probs:
        print(p)
    sys.exit(1 if probs else 0)
