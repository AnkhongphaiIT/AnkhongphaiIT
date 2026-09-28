#!/usr/bin/env python3
"""Chia một gói ZIP lớn thành các phần nhỏ (mặc định 24 MB) để gửi qua kênh giới hạn dung lượng, kèm GHEP_FILE.bat
(Windows: `copy /b` ghép lại rồi kiểm SHA-256 bằng certutil có sẵn). 7-Zip mở thẳng được file .001.

  python3 tools/build/split_parts.py release/ca-bay-server-0.1.0-windows.zip [--mb 24]

Kết quả: release/<tên>-parts/<tên>.zip.001 … + GHEP_FILE.bat + SHA256.txt
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("zip")
    ap.add_argument("--mb", type=float, default=24.0)
    a = ap.parse_args()
    src = Path(a.zip)
    out = src.parent / (src.stem + "-parts")
    if out.exists():
        shutil.rmtree(out)
    out.mkdir()
    size = int(a.mb * 1_000_000)
    data = src.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    names = []
    for i in range(0, len(data), size):
        n = f"{src.name}.{len(names) + 1:03d}"
        (out / n).write_bytes(data[i:i + size])
        names.append(n)
    joined = b"".join((out / n).read_bytes() for n in names)
    assert hashlib.sha256(joined).hexdigest() == digest
    # .bat chỉ dùng ASCII (cmd.exe đọc theo bảng mã OEM)
    bat = "\r\n".join([
        "@echo off",
        f"rem Ghep {len(names)} phan thanh {src.name} va kiem SHA-256. Dat file nay cung thu muc voi cac file .001 ... .{len(names):03d}",
        "setlocal",
        'cd /d "%~dp0"',
        f"copy /b {' + '.join(names)} {src.name} >nul",
        f"if errorlevel 1 (echo Thieu mot trong cac file {names[0]} ... {names[-1]} trong thu muc nay & pause & exit /b 1)",
        # dòng mã băm là dòng duy nhất không có dấu ':'; Windows 7/8 in có dấu cách giữa các byte → bỏ dấu cách
        'set "H="',
        f'for /f "delims=" %%h in (\'certutil -hashfile {src.name} SHA256 ^| findstr /v ":"\') do set "H=%%h"',
        'set "H=%H: =%"',
        f'if /i not "%H%"=="{digest}" (echo CANH BAO: SHA-256 khong khop - co the tai thieu/hong, nen tai lai cac phan & pause & exit /b 1)',
        f"echo OK: da tao {src.name} (SHA-256 dung). Chuot phai file zip - Properties - Unblock, giai nen, roi bam CHOI_THU.bat",
        "pause",
        "",
    ])
    (out / "GHEP_FILE.bat").write_bytes(bat.encode("ascii"))
    (out / "SHA256.txt").write_text(f"{digest}  {src.name}\n", encoding="ascii")
    for n in names + ["GHEP_FILE.bat", "SHA256.txt"]:
        print(f"{out / n}  {(out / n).stat().st_size / 1e6:.1f} MB")
    print(f"SPLIT_OK {len(names)} phần sha256={digest[:16]}…")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
