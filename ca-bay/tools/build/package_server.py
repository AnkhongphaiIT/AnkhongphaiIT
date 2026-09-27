#!/usr/bin/env python3
"""Đóng gói máy chủ CÁ BAY (backend tài khoản/lưu + room server Godot headless) để chạy trên máy chủ
do chủ dự án kiểm soát (Linux, hoặc Windows với Godot 4.7.2 chính thức). Theo P-011: chỉ chép đúng file cần.

  python3 tools/build/package_server.py

Kết quả: release/ca-bay-server-<version>/ + .zip + .sha256. Không chứa DB, .env, khóa dịch vụ, venv, test.
"""
from __future__ import annotations

import hashlib
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/build"))
import export as exporter  # noqa: E402
from package_web import git_commit, project_version, sha256  # noqa: E402

RELEASE = ROOT / "release"


def copytree(src: Path, dst: Path, patterns: tuple[str, ...] = ("*",)) -> None:
    for pat in patterns:
        for p in src.rglob(pat):
            if p.is_file() and "__pycache__" not in p.parts and not p.name.endswith(".pyc"):
                t = dst / p.relative_to(src)
                t.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(p, t)


def main() -> int:
    version = project_version()
    name = f"ca-bay-server-{version}"
    exporter.export("server", None, None, debug=False)
    out = RELEASE / name
    if out.exists():
        shutil.rmtree(out)
    (out / "room").mkdir(parents=True)
    for f in ("ca-bay-room-server.x86_64", "ca-bay-room-server.pck"):
        shutil.copy2(ROOT / "build/server" / f, out / "room" / f)
    (out / "room/ca-bay-room-server.x86_64").chmod(0o755)
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
    for f in (out / "run").glob("*.sh"):
        f.chmod(0o755)
    shutil.copy2(ROOT / "server/ops/public/README.md", out / "README.md")
    shutil.copy2(ROOT / "CREDITS.md", out / "CREDITS.md")
    (out / "VERSION").write_text(f"{version} {git_commit()}\n", encoding="utf-8")

    bad = [p for p in out.rglob("*") if p.is_file() and (p.suffix in (".db", ".sqlite", ".log") or p.name in (".env",) or "tests" in p.parts)]
    if bad:
        raise SystemExit(f"Gói server chứa file cấm: {bad}")
    for p in out.rglob("*"):
        if p.is_file() and p.suffix in (".py", ".sh", ".ps1", ".md", ".txt") and b"CABAY_SERVICE_KEY=" in p.read_bytes():
            txt = p.read_text(encoding="utf-8", errors="replace")
            for line in txt.splitlines():
                if line.strip().startswith("CABAY_SERVICE_KEY=") and len(line.split("=", 1)[1].strip()) > 8 and "<" not in line:
                    raise SystemExit(f"Có vẻ có khóa thật trong {p}: không đóng gói")

    zpath = RELEASE / f"{name}.zip"
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in sorted(out.rglob("*")):
            if p.is_file():
                info = zipfile.ZipInfo(f"{name}/{p.relative_to(out)}", date_time=(2026, 1, 1, 0, 0, 0))
                info.external_attr = (0o755 if p.suffix in (".sh", ".x86_64") else 0o644) << 16
                z.writestr(info, p.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    digest = sha256(zpath)
    (RELEASE / f"{name}.zip.sha256").write_text(f"{digest}  {zpath.name}\n", encoding="utf-8")
    print(f"PACKAGE_OK {zpath.relative_to(ROOT)} {zpath.stat().st_size / 1e6:.2f} MB sha256={digest[:16]}…")
    return 0


if __name__ == "__main__":
    sys.exit(main())
