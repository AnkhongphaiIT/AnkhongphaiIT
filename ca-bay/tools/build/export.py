#!/usr/bin/env python3
"""Xuất bản build Godot (web client hoặc room server Linux) theo export_presets.cfg.

  python3 tools/build/export.py web                       # endpoint localhost (thử local)
  python3 tools/build/export.py web --api https://api.example --ws wss://ws.example
  python3 tools/build/export.py web --selfhost            # máy chủ phục vụ luôn trang (P-035): endpoint = origin trang
  python3 tools/build/export.py server

Endpoint công khai chỉ nhận https/wss (localhost được http/ws). File client/config/endpoints.json
được ghi tạm cho lần xuất rồi khôi phục. Sau khi xuất, quét gói .pck để chắc chắn không lọt mã
server/backend, test, tài liệu hay chuỗi bí mật vào bản web.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
ENDPOINTS = ROOT / "client/config/endpoints.json"
PRESETS = {"web": ("Web", ROOT / "build/web/index.html"),
           "server": ("Linux Room Server", ROOT / "build/server/ca-bay-room-server.x86_64"),
           "server-win": ("Windows Room Server", ROOT / "build/server-win/ca-bay-room-server.exe")}
# Không được xuất hiện trong gói web.
FORBIDDEN_IN_WEB = [b"res://server/", b"res://tests/", b"res://tools/", b"res://docs/", b"CABAY_SERVICE_KEY",
                    b"X-Service-Key", b"res://data/schemas/", b"BEGIN PRIVATE KEY-----\n"]


def godot_bin() -> str:
    return os.environ.get("GODOT_BIN") or shutil.which("godot") or "/opt/godot/4.7.2/godot"


def _check_url(url: str, secure_scheme: str, plain_scheme: str) -> str:
    u = urlparse(url)
    local = u.hostname in ("127.0.0.1", "localhost", "::1")
    if u.scheme == secure_scheme or (local and u.scheme == plain_scheme):
        if u.username or u.password or u.query or u.fragment:
            raise SystemExit(f"URL không được chứa thông tin đăng nhập/query: {url}")
        return url.rstrip("/")
    raise SystemExit(f"Endpoint công khai phải dùng {secure_scheme}:// ({url})")


# Bản phát hành: loại thoại tạm espeak-ng (giấy phép chưa chốt, xem assets/audio/vo/LICENSE-VO.md).
RELEASE_EXCLUDE = "assets/audio/vo/*"
PRESETS_FILE = ROOT / "export_presets.cfg"


# P-047: glue Emscripten của template web chép bộ đệm ẩn ra canvas mỗi khung (blitOffscreenFramebuffer) và đọc trạng thái
# scissor bằng gl.getParameter — lệnh đồng bộ, luồng chính chờ tiến trình GPU xử lý xong cả khung (máy Iris Xe: 64 % CPU,
# 16,8 ms/khung → ~50 FPS). gl.isEnabled trả cùng giá trị từ trạng thái trình duyệt giữ sẵn (3,4 ms/khung, 60 FPS).
WEB_JS_PATCHES = [("var prevScissorTest=gl.getParameter(3089);", "var prevScissorTest=gl.isEnabled(3089);")]


def patch_web_js(js: Path) -> None:
    txt = js.read_text(encoding="utf-8")
    for old, new in WEB_JS_PATCHES:
        n = txt.count(old)
        if n != 1:
            raise SystemExit(f"{js.name}: mẫu vá P-047 xuất hiện {n} lần (cần đúng 1) — template web đã đổi, kiểm tra lại bản vá")
        txt = txt.replace(old, new)
    js.write_text(txt, encoding="utf-8", newline="")
    print(f"  vá {js.name}: {len(WEB_JS_PATCHES)} chỗ (P-047)")


def export(target: str, api: str | None, ws: str | None, debug: bool, release: bool = False, selfhost: bool = False) -> Path:
    if selfhost and (api or ws):
        raise SystemExit("--selfhost dùng địa chỉ của chính trang; không kèm --api/--ws")
    preset, out = PRESETS[target]
    out.parent.mkdir(parents=True, exist_ok=True)
    for f in out.parent.iterdir():
        if f.is_file():
            f.unlink()
    original = ENDPOINTS.read_bytes()
    presets_original = PRESETS_FILE.read_bytes()
    try:
        if release and target == "web":
            txt = presets_original.decode("utf-8")
            marker = 'exclude_filter="server/*,'
            assert marker in txt, "không tìm thấy exclude_filter của preset Web"
            txt = txt.replace(marker, f'exclude_filter="{RELEASE_EXCLUDE}, server/*,', 1)
            txt = txt.replace(", assets/audio/vo/*.json", "", 1)  # gói thoại JSON cũng thuộc bản tạm
            PRESETS_FILE.write_text(txt, encoding="utf-8")
        if target == "web":
            cfg = json.loads(original)
            if api:
                cfg["api_base"] = _check_url(api, "https", "http")
            if ws:
                cfg["ws_url"] = _check_url(ws, "wss", "ws")
            # Chế độ kiểm thử tự động (?autotest=1, có phím tự quay về cá/boss) chỉ có trong bản thử local, không có trong bản phát hành.
            cfg["allow_autotest"] = not release
            # ?api=&ws= trên URL chỉ dùng được ở bản trỏ localhost; bản có endpoint công khai khóa cứng (P-034).
            cfg["allow_endpoint_override"] = not (api or ws or selfhost)
            if selfhost:
                cfg["api_base"], cfg["ws_url"] = "@origin", "@origin/ws"
            ENDPOINTS.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        g = godot_bin()
        subprocess.run([g, "--headless", "--path", str(ROOT), "--import"], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=600)
        cmd = [g, "--headless", "--path", str(ROOT), "--export-debug" if debug else "--export-release", preset, str(out)]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
        log = r.stdout + r.stderr
        errors = [l for l in log.splitlines() if re.search(r"\bERROR\b|SCRIPT ERROR", l)]
        if r.returncode != 0 or not out.exists():
            print(log[-4000:])
            raise SystemExit(f"Xuất {target} thất bại (mã {r.returncode})")
        if errors:
            print("\n".join(errors[:30]))
            raise SystemExit(f"Xuất {target} có lỗi ({len(errors)} dòng ERROR)")
    finally:
        ENDPOINTS.write_bytes(original)
        PRESETS_FILE.write_bytes(presets_original)
    total = 0
    for f in sorted(out.parent.iterdir()):
        total += f.stat().st_size
        print(f"  {f.name:40s} {f.stat().st_size / 1e6:8.2f} MB")
    print(f"  tổng {total / 1e6:.2f} MB")
    if target == "web":
        patch_web_js(out.with_suffix(".js"))
        pck = out.with_suffix(".pck")
        data = pck.read_bytes()
        forbidden = FORBIDDEN_IN_WEB + ([b"assets/audio/vo/npc_"] if release else [])
        bad = [s.decode() for s in forbidden if s in data]
        if bad:
            raise SystemExit(f"Gói web chứa nội dung cấm: {bad}")
        print("  quét .pck: không có mã server/test/docs/secret")
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("target", choices=sorted(PRESETS))
    ap.add_argument("--api", help="API base công khai (https://...)")
    ap.add_argument("--ws", help="Room server công khai (wss://...)")
    ap.add_argument("--debug", action="store_true")
    ap.add_argument("--release", action="store_true", help="bản phát hành: loại tài nguyên chưa rõ giấy phép")
    ap.add_argument("--selfhost", action="store_true", help="bản cho máy chủ tự phục vụ trang (backend CABAY_WEB_DIR)")
    a = ap.parse_args()
    out = export(a.target, a.api, a.ws, a.debug, a.release, a.selfhost)
    print(f"EXPORT_OK {a.target} {out.relative_to(ROOT)}")


if __name__ == "__main__":
    sys.exit(main())
