#!/usr/bin/env python3
"""Python chạy sẵn cho gói máy chủ bản Windows (người chơi không phải cài Python).

Nguồn: gói NuGet chính thức `python` 3.11.9 của Python Software Foundation (bản cài đầy đủ trong thư mục tools/),
kiểm SHA-512 đã ghim trước khi giải nén. Thư viện backend: wheel win_amd64/cp311 tải từ PyPI theo đúng
server/backend/requirements.lock.txt (bỏ gói chỉ dùng cho test), "cài" bằng cách giải nén wheel vào Lib/site-packages
(wheel là zip; không chạy mã cài đặt nào). Bỏ phần không cần khi chạy (test, IDLE, tkinter, header C) — P-011.

    python3 tools/build/win_runtime.py <thư mục đích>     # tạo <đích>/python/
"""
from __future__ import annotations

import base64
import hashlib
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / "build/cache/win"
PY_VERSION = "3.11.9"
NUPKG_URL = f"https://api.nuget.org/v3-flatcontainer/python/{PY_VERSION}/python.{PY_VERSION}.nupkg"
# packageHash (SHA512, base64) trong catalog NuGet: api.nuget.org/v3/catalog0/data/2024.04.02.13.14.51/python.3.11.9.json
NUPKG_SHA512 = "41On79FZ75irnOEBGFSjDV13j1nZb8m7EbB87SmQs1XwMEhrBwf3mMc8RCAXOrERh2qW6tWYFxi2BMTN1xxVjQ=="
LOCK = ROOT / "server/backend/requirements.lock.txt"
TEST_ONLY = {"pytest", "iniconfig", "pluggy", "pygments"}
# Không cần khi chạy máy chủ (giảm ~40 MB): bộ test chuẩn, IDLE, giao diện Tk, header/thư viện để biên dịch C.
DROP = ["Lib/test", "Lib/idlelib", "Lib/tkinter", "Lib/turtledemo", "Lib/lib2to3", "Lib/ensurepip", "tcl", "include", "libs",
        "DLLs/_tkinter.pyd", "DLLs/tcl86t.dll", "DLLs/tk86t.dll", "Scripts"]


def _nupkg() -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    p = CACHE / f"python.{PY_VERSION}.nupkg"
    if not p.exists():
        tmp = p.with_suffix(".part")
        with urllib.request.urlopen(NUPKG_URL, timeout=300) as r, tmp.open("wb") as f:
            shutil.copyfileobj(r, f)
        tmp.rename(p)
    got = base64.b64encode(hashlib.sha512(p.read_bytes()).digest()).decode()
    if got != NUPKG_SHA512:
        p.unlink()
        raise SystemExit(f"SHA-512 gói Python NuGet không khớp ({got[:16]}…) — không dùng")
    return p


def _wheels() -> list[Path]:
    d = CACHE / "wheels-cp311-win_amd64"
    d.mkdir(parents=True, exist_ok=True)
    reqs = [l.strip() for l in LOCK.read_text(encoding="utf-8").splitlines()
            if l.strip() and not l.startswith("#") and l.split("==")[0].strip().lower() not in TEST_ONLY]
    pip = ROOT / "server/backend/.venv/bin/pip"
    r = subprocess.run([str(pip if pip.exists() else "pip"), "download", "--quiet", "--no-deps", "--only-binary=:all:",
                        "--platform", "win_amd64", "--python-version", "3.11", "--implementation", "cp", "--abi", "cp311",
                        "--dest", str(d), *reqs], capture_output=True, text=True, timeout=900)
    if r.returncode != 0:
        raise SystemExit("Không tải được wheel Windows:\n" + r.stdout[-2000:] + r.stderr[-2000:])
    wanted = {q.split("==")[0].lower().replace("-", "_") + "-" + q.split("==")[1] for q in reqs}
    found = [w for w in sorted(d.glob("*.whl")) if "-".join(w.name.split("-")[:2]).lower() in wanted]
    if len(found) != len(reqs):
        raise SystemExit(f"Thiếu wheel: cần {len(reqs)}, có {len(found)}")
    return found


def _install_wheel(whl: Path, site: Path) -> None:
    with zipfile.ZipFile(whl) as z:
        for m in z.infolist():
            name = m.filename
            if name.endswith("/") or ".." in Path(name).parts:
                continue
            parts = name.split("/")
            if parts[0].endswith(".data"):  # {pkg}.data/purelib|platlib/... → site-packages; scripts/headers bỏ qua
                if len(parts) < 3 or parts[1] not in ("purelib", "platlib"):
                    continue
                name = "/".join(parts[2:])
            t = site / name
            t.parent.mkdir(parents=True, exist_ok=True)
            with z.open(m) as src, t.open("wb") as dst:
                shutil.copyfileobj(src, dst)


def build(dest: Path) -> Path:
    """Tạo dest/python (python.exe + thư viện chuẩn + thư viện backend). Trả đường dẫn thư mục."""
    out = dest / "python"
    if out.exists():
        shutil.rmtree(out)
    with zipfile.ZipFile(_nupkg()) as z:
        for m in z.infolist():
            if m.filename.startswith("tools/") and not m.filename.endswith("/") and ".." not in Path(m.filename).parts:
                t = out / m.filename[len("tools/"):]
                t.parent.mkdir(parents=True, exist_ok=True)
                with z.open(m) as src, t.open("wb") as dst:
                    shutil.copyfileobj(src, dst)
    if not (out / "python.exe").exists() or not (out / "LICENSE.txt").exists():
        raise SystemExit("Gói NuGet không có tools/python.exe hoặc LICENSE.txt")
    for rel in DROP:
        p = out / rel
        if p.is_dir():
            shutil.rmtree(p)
        elif p.exists():
            p.unlink()
    for p in list(out.rglob("__pycache__")):
        shutil.rmtree(p)
    site = out / "Lib/site-packages"
    site.mkdir(parents=True, exist_ok=True)
    for whl in _wheels():
        _install_wheel(whl, site)
    return out


if __name__ == "__main__":
    o = build(Path(sys.argv[1]))
    size = sum(f.stat().st_size for f in o.rglob("*") if f.is_file())
    print(f"WIN_PYTHON_OK {o} {size / 1e6:.1f} MB")
