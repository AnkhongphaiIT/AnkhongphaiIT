#!/usr/bin/env python3
"""Đóng gói bản web phát hành (itch.io HTML5 / web tĩnh) theo P-011:
xuất vào build/web → CHỈ chép đúng các file của bản release sang thư mục mới release/<tên>/ → nén ZIP.

  python3 tools/build/package_web.py                                   # bản thử local (endpoint localhost)
  python3 tools/build/package_web.py --api https://api.example --ws wss://ws.example   # bản công khai

Kết quả: release/<tên>/, release/<tên>.zip, release/<tên>.zip.sha256, release/<tên>.manifest.json.
ZIP có index.html ở gốc; kiểm không có DB/.env/mã server/test/khóa; ghi hash từng file.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/build"))
import export as exporter  # noqa: E402

BUILD = ROOT / "build/web"
RELEASE = ROOT / "release"
# Chỉ những file này của bản xuất web được đưa vào gói (P-011).
CLIENT_FILES = re.compile(r"^index\.(html|js|wasm|pck|png|icon\.png|apple-touch-icon\.png|audio\.worklet\.js|audio\.position\.worklet\.js)$")
LICENSE_FILES = {
    "LICENSES/fonts/OFL-BeVietnamPro.txt": ROOT / "assets/fonts/OFL-BeVietnamPro.txt",
    "LICENSES/fonts/LICENSE-DejaVu-symbols.txt": ROOT / "assets/fonts/LICENSE-DejaVu-symbols.txt",
    "LICENSES/fonts/SOURCES.md": ROOT / "assets/fonts/SOURCES.md",
    "CREDITS.md": ROOT / "CREDITS.md",
    "PRIVACY.md": ROOT / "PRIVACY.md",
}
FORBIDDEN_NAMES = re.compile(r"(\.env|\.db|\.sqlite|\.py|\.pyc|\.gd|\.log|id_rsa|\.pem|\.key)$", re.I)
FORBIDDEN_BYTES = [b"CABAY_SERVICE_KEY", b"X-Service-Key", b"res://server/", b"res://tests/", b"\"allow_autotest\": true"]
# Khối PEM có dữ liệu thật (engine chứa sẵn chuỗi hằng "BEGIN PRIVATE KEY" của mbedTLS để đọc PEM — không phải khóa).
PEM_KEY = re.compile(rb"-----BEGIN [A-Z ]*PRIVATE KEY-----\s*[A-Za-z0-9+/=\s]{64}")


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def project_version() -> str:
    m = re.search(r'config/version="([^"]+)"', (ROOT / "project.godot").read_text(encoding="utf-8"))
    return m.group(1) if m else "0.0.0"


def git_commit() -> str:
    r = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True)
    dirty = subprocess.run(["git", "status", "--porcelain", "--untracked-files=no"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    return r.stdout.strip() + ("-dirty" if dirty else "")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--api")
    ap.add_argument("--ws")
    ap.add_argument("--skip-export", action="store_true", help="dùng build/web có sẵn (phải là bản --release)")
    a = ap.parse_args()
    public = bool(a.api and a.ws)
    if public and "NEED-CONTACT" in (ROOT / "PRIVACY.md").read_text(encoding="utf-8"):
        raise SystemExit("PRIVACY.md còn chỗ trống liên hệ (NEED-CONTACT): chủ dự án phải điền trước khi làm bản công khai")
    version = project_version()
    name = f"ca-bay-web-{version}" + ("" if public else "-local")
    if not a.skip_export:
        exporter.export("web", a.api, a.ws, debug=False, release=True)
    endpoints = json.loads((ROOT / "client/config/endpoints.json").read_text(encoding="utf-8"))
    if a.api:
        endpoints["api_base"] = a.api
    if a.ws:
        endpoints["ws_url"] = a.ws

    out = RELEASE / name
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    copied = []
    for f in sorted(BUILD.iterdir()):
        if f.is_file() and CLIENT_FILES.match(f.name):
            shutil.copy2(f, out / f.name)
            copied.append(f.name)
    if "index.html" not in copied or "index.pck" not in copied or "index.wasm" not in copied:
        raise SystemExit(f"Thiếu file bắt buộc trong build/web: {copied}")
    # Giấy phép Godot sinh từ chính engine đang dùng (không chép tay).
    lic = out / "LICENSES/GODOT.txt"
    lic.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run([exporter.godot_bin(), "--headless", "--script", str(ROOT / "tools/build/godot_license.gd"), "--", str(lic)],
                       capture_output=True, text=True, timeout=120)
    if "GODOT_LICENSE_OK" not in r.stdout or not lic.exists():
        raise SystemExit("Không sinh được LICENSES/GODOT.txt:\n" + (r.stdout + r.stderr)[-2000:])
    for rel, src in LICENSE_FILES.items():
        if not src.exists():
            raise SystemExit(f"Thiếu file giấy phép/credits: {src.relative_to(ROOT)}")
        dst = out / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    # kiểm an toàn
    problems = []
    files = sorted(p for p in out.rglob("*") if p.is_file())
    for p in files:
        if FORBIDDEN_NAMES.search(p.name):
            problems.append(f"tên file cấm: {p.relative_to(out)}")
        data = p.read_bytes()
        for b in FORBIDDEN_BYTES:
            if b in data:
                problems.append(f"{p.relative_to(out)} chứa {b.decode()}")
        if PEM_KEY.search(data):
            problems.append(f"{p.relative_to(out)} chứa khối khóa riêng PEM")
    if problems:
        raise SystemExit("Gói không an toàn:\n" + "\n".join(problems))

    zpath = RELEASE / f"{name}.zip"
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in files:
            info = zipfile.ZipInfo(str(p.relative_to(out)).replace("\\", "/"), date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, p.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    with zipfile.ZipFile(zpath) as z:
        names = z.namelist()
        assert "index.html" in names, "index.html phải ở gốc ZIP"
    digest = sha256(zpath)
    (RELEASE / f"{name}.zip.sha256").write_text(f"{digest}  {zpath.name}\n", encoding="utf-8")
    manifest = {
        "name": name, "version": version, "commit": git_commit(), "public_endpoints": public,
        "endpoints": {k: endpoints[k] for k in ("api_base", "ws_url")},
        "godot": json.loads((ROOT / "toolchain.lock.json").read_text())["godot"]["version"] if (ROOT / "toolchain.lock.json").exists() else "",
        "zip": zpath.name, "zip_sha256": digest, "zip_bytes": zpath.stat().st_size,
        "files": {str(p.relative_to(out)): {"bytes": p.stat().st_size, "sha256": sha256(p)} for p in files},
        "excluded_by_policy": ["assets/audio/vo/* (thoại tạm espeak-ng, giấy phép chưa chốt — P-018)"],
    }
    (RELEASE / f"{name}.manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    total = sum(p.stat().st_size for p in files)
    print(f"PACKAGE_OK {zpath.relative_to(ROOT)}  {zpath.stat().st_size / 1e6:.2f} MB nén / {total / 1e6:.2f} MB giải nén  sha256={digest[:16]}…")
    if not public:
        print("Lưu ý: bản này trỏ tới localhost — chỉ để thử local, KHÔNG tải lên itch.io.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
