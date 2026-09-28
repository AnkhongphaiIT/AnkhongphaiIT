"""Cài Godot 4.7.2 + export templates (web, linux x86_64; thêm windows x86_64 với --windows) cho môi trường
không tới được godotengine.org.

Nguồn: layer image Docker Hub barichello/godot-ci:4.7.2 (layer này tự tải từ
github.com/godotengine/godot-builds). Digest layer được ghim và kiểm tra trước khi giải nén.
Chỉ dùng thư viện chuẩn. Không cần Docker daemon.

    python3 tools/build/install_godot.py [--prefix /opt/godot/4.7.2]
    python3 tools/build/install_godot.py --windows     # thêm template Windows (room server .exe cho gói Windows)
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

REPO = "barichello/godot-ci"
TAG = "4.7.2"
LAYER_DIGEST = "sha256:8d9c0a57444f08dee259493b893b0f90f24875fe54e1b55c925e15a552e0c85b"
EXPECTED_VERSION = "4.7.2.stable.official.ed1daf0bf"
TEMPLATE_DIR_IN_LAYER = "root/.local/share/godot/export_templates/4.7.2.stable/"
WANTED_TEMPLATES = {
    "version.txt", "icudt_godot.dat",
    "web_nothreads_release.zip", "web_nothreads_debug.zip", "web_release.zip", "web_debug.zip",
    "linux_release.x86_64", "linux_debug.x86_64",
}
WINDOWS_TEMPLATES = {"windows_release_x86_64.exe", "windows_release_x86_64_console.exe"}
BINARY_IN_LAYER = "usr/local/bin/godot"


def _token() -> str:
    url = f"https://auth.docker.io/token?service=registry.docker.io&scope=repository:{REPO}:pull"
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.load(r)["token"]


def _download_layer(dest: Path) -> None:
    req = urllib.request.Request(
        f"https://registry-1.docker.io/v2/{REPO}/blobs/{LAYER_DIGEST}",
        headers={"Authorization": f"Bearer {_token()}"},
    )
    h = hashlib.sha256()
    with urllib.request.urlopen(req, timeout=600) as r, dest.open("wb") as f:
        while chunk := r.read(1 << 20):
            h.update(chunk)
            f.write(chunk)
    got = "sha256:" + h.hexdigest()
    if got != LAYER_DIGEST:
        dest.unlink(missing_ok=True)
        sys.exit(f"Digest không khớp: {got} != {LAYER_DIGEST}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prefix", default="/opt/godot/4.7.2")
    ap.add_argument("--templates", default=str(Path.home() / ".local/share/godot/export_templates/4.7.2.stable"))
    ap.add_argument("--link", default="/usr/local/bin/godot", help="symlink tới binary; để trống để bỏ qua")
    ap.add_argument("--windows", action="store_true", help="thêm export template Windows x86_64")
    args = ap.parse_args()

    prefix, tdir = Path(args.prefix), Path(args.templates)
    binary = prefix / "godot"
    wanted = WANTED_TEMPLATES | (WINDOWS_TEMPLATES if args.windows else set())
    if binary.exists() and all((tdir / n).exists() for n in wanted):
        print(f"Đã có {binary} và {tdir}; bỏ qua tải.")
    else:
        with tempfile.TemporaryDirectory() as tmp:
            layer = Path(tmp) / "layer.tar.gz"
            print("Tải layer (~1.4 GB)...")
            _download_layer(layer)
            prefix.mkdir(parents=True, exist_ok=True)
            tdir.mkdir(parents=True, exist_ok=True)
            with tarfile.open(layer, "r:gz") as tar:
                for m in tar:
                    if not m.isfile():
                        continue
                    name = m.name
                    if ".." in Path(name).parts or name.startswith("/"):
                        continue
                    if name == BINARY_IN_LAYER:
                        target = binary
                    elif name.startswith(TEMPLATE_DIR_IN_LAYER) and name[len(TEMPLATE_DIR_IN_LAYER):] in wanted:
                        target = tdir / name[len(TEMPLATE_DIR_IN_LAYER):]
                    else:
                        continue
                    src = tar.extractfile(m)
                    assert src is not None
                    with target.open("wb") as out:
                        shutil.copyfileobj(src, out)
            os.chmod(binary, 0o755)
    if args.link:
        link = Path(args.link)
        if link.is_symlink() or not link.exists():
            link.unlink(missing_ok=True)
            link.symlink_to(binary)
    import subprocess

    ver = subprocess.run([str(binary), "--version"], capture_output=True, text=True).stdout.strip()
    tv = (tdir / "version.txt").read_text().strip()
    print(f"godot --version: {ver}\ntemplates: {tv}")
    if ver != EXPECTED_VERSION or tv != "4.7.2.stable":
        print("CẢNH BÁO: phiên bản không khớp lock", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
