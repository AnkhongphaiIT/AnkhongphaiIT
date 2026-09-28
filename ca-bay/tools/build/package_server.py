#!/usr/bin/env python3
"""Đóng gói máy chủ CÁ BAY (backend tài khoản/lưu + room server Godot headless + trang game tự host) để chạy trên
máy do chủ dự án kiểm soát. Theo P-011: chỉ chép đúng file cần.

  python3 tools/build/package_server.py                   # cả hai gói
  python3 tools/build/package_server.py --target windows  # chỉ gói Windows

- `ca-bay-server-<v>-linux.zip`: room server Linux x86_64; backend chạy bằng Python 3.11 của máy (venv tự tạo).
- `ca-bay-server-<v>-windows.zip`: room server .exe + Python 3.11.9 đóng kèm (python/, từ NuGet chính thức, thư viện
  cài sẵn) → giải nén rồi bấm CHOI_THU.bat, không phải cài gì (tools/build/win_runtime.py).
Cả hai có web/ (bản web tự host, P-035): một cổng http://127.0.0.1:8787 là trang game + tài khoản + phòng chơi.
Không chứa DB, .env, khóa dịch vụ, venv, test.
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/build"))
import check_ps1  # noqa: E402
import export as exporter  # noqa: E402
import win_runtime  # noqa: E402
from package_web import assemble_web, git_commit, godot_license, project_version, sha256  # noqa: E402

RELEASE = ROOT / "release"
ROOM_FILES = {"linux": ["ca-bay-room-server.x86_64", "ca-bay-room-server.pck"],
              "windows": ["ca-bay-room-server.exe", "ca-bay-room-server.console.exe", "ca-bay-room-server.pck"]}
ROOM_BUILD = {"linux": ("server", ROOT / "build/server"), "windows": ("server-win", ROOT / "build/server-win")}
EXECUTABLE = (".sh", ".x86_64")


def copytree(src: Path, dst: Path, patterns: tuple[str, ...] = ("*",)) -> None:
    for pat in patterns:
        for p in src.rglob(pat):
            if p.is_file() and "__pycache__" not in p.parts and not p.name.endswith(".pyc"):
                t = dst / p.relative_to(src)
                t.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(p, t)


def build_package(target: str, version: str, web_dir: Path) -> Path:
    name = f"ca-bay-server-{version}-{target}"
    out = RELEASE / name
    if out.exists():
        shutil.rmtree(out)
    preset, build_dir = ROOM_BUILD[target]
    exporter.export(preset, None, None, debug=False)
    (out / "room").mkdir(parents=True)
    for f in ROOM_FILES[target]:
        shutil.copy2(build_dir / f, out / "room" / f)
    copytree(ROOT / "server/backend/app", out / "backend/app", ("*.py",))
    copytree(ROOT / "server/backend/migrations", out / "backend/migrations", ("*.sql",))
    shutil.copy2(ROOT / "server/backend/requirements.lock.txt", out / "backend/requirements.lock.txt")
    copytree(ROOT / "data/content", out / "data/content", ("*.json",))
    copytree(ROOT / "data/schemas", out / "data/schemas", ("*.schema.json",))
    (out / "data/contracts").mkdir(parents=True)
    shutil.copy2(ROOT / "data/contracts/network_contract.json", out / "data/contracts/network_contract.json")
    (out / "ops").mkdir()
    shutil.copy2(ROOT / "server/ops/backup/backup.py", out / "ops/backup.py")
    shutil.copy2(ROOT / "server/ops/seed_checkpoint.py", out / "ops/seed_checkpoint.py")
    copytree(ROOT / "server/ops/public/run", out / "run")
    shutil.copytree(web_dir, out / "web")
    godot_license(out / "LICENSES/GODOT.txt")
    if target == "windows":
        shutil.copy2(ROOT / "server/ops/public/CHOI_THU.bat", out / "CHOI_THU.bat")
        py = win_runtime.build(out)
        shutil.copy2(py / "LICENSE.txt", out / "LICENSES/PYTHON.txt")
        for f in (out / "run").glob("*.sh"):
            f.unlink()
    else:
        for f in (out / "run").glob("*.ps1"):
            f.unlink()
        for f in (out / "run").glob("*.sh"):
            f.chmod(0o755)
        (out / "room/ca-bay-room-server.x86_64").chmod(0o755)
    shutil.copy2(ROOT / "server/ops/public/README.md", out / "README.md")
    shutil.copy2(ROOT / "CREDITS.md", out / "CREDITS.md")
    (out / "VERSION").write_text(f"{version} {git_commit()} {target}\n", encoding="utf-8")

    bad = [p for p in out.rglob("*") if p.is_file() and (p.suffix in (".db", ".sqlite", ".log") or p.name in (".env",)
                                                          or ("tests" in p.parts and "python" not in p.relative_to(out).parts[:1]))]
    if bad:
        raise SystemExit(f"Gói server chứa file cấm: {bad[:5]}")
    for p in out.rglob("*"):
        if p.is_file() and p.suffix in (".py", ".sh", ".ps1", ".bat", ".md", ".txt") and "python" not in p.relative_to(out).parts[:1] \
                and b"CABAY_SERVICE_KEY=" in p.read_bytes():
            for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
                if line.strip().startswith("CABAY_SERVICE_KEY=") and len(line.split("=", 1)[1].strip()) > 8 and "<" not in line:
                    raise SystemExit(f"Có vẻ có khóa thật trong {p}: không đóng gói")
    probs = check_ps1.check([out / "run"])
    if probs:
        raise SystemExit("Script PowerShell lỗi:\n" + "\n".join(probs))

    zpath = RELEASE / f"{name}.zip"
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in sorted(out.rglob("*")):
            if p.is_file():
                info = zipfile.ZipInfo(f"{name}/{p.relative_to(out).as_posix()}", date_time=(2026, 1, 1, 0, 0, 0))
                info.external_attr = (0o755 if p.suffix in EXECUTABLE else 0o644) << 16
                z.writestr(info, p.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    digest = sha256(zpath)
    (RELEASE / f"{name}.zip.sha256").write_text(f"{digest}  {zpath.name}\n", encoding="utf-8")
    total = sum(p.stat().st_size for p in out.rglob("*") if p.is_file())
    print(f"PACKAGE_OK {zpath.relative_to(ROOT)} {zpath.stat().st_size / 1e6:.2f} MB nén / {total / 1e6:.1f} MB giải nén sha256={digest[:16]}…")
    return zpath


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", choices=["linux", "windows", "all"], default="all")
    a = ap.parse_args()
    version = project_version()
    if "NEED-CONTACT" in (ROOT / "PRIVACY.md").read_text(encoding="utf-8"):
        print("Lưu ý: PRIVACY.md còn chỗ trống liên hệ (NEED-CONTACT) — chỉ dùng gói này cho buổi chơi thử với người quen.")
    # Bản web tự host (P-035): endpoint = địa chỉ trang đang mở; bản phát hành (không phím kiểm thử, không thoại tạm).
    exporter.export("web", None, None, debug=False, release=True, selfhost=True)
    web = RELEASE / ".web-selfhost"
    assemble_web(web, locked_endpoints=True)
    if b'"api_base": "@origin"' not in (web / "index.pck").read_bytes():
        raise SystemExit("bản web trong gói máy chủ phải là bản tự host (@origin)")
    try:
        for target in (["linux", "windows"] if a.target == "all" else [a.target]):
            build_package(target, version, web)
    finally:
        shutil.rmtree(web, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
