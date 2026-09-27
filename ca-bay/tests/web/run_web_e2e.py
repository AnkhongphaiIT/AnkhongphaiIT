#!/usr/bin/env python3
"""Kiểm thử đầu-cuối client web thật: backend + room server Godot + bản web đã xuất, điều khiển bằng
Chromium (Playwright) qua giao diện người dùng — đăng ký, vào phòng, câu, đập xỉu, nhặt.

  python3 tools/build/export.py web            # xuất bản web localhost trước
  python3 tests/web/run_web_e2e.py [--scenario fish_loop] [--keep]

Kịch bản trong tests/web/scenarios/<tên>.json; {USER} và {BASE} được thay lúc chạy.
Ảnh chụp + console lưu ở tests/web/artifacts/<tên>/ (không commit).
"""
from __future__ import annotations

import argparse
import functools
import http.server
import json
import os
import secrets
import subprocess
import sys
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/integration"))
from stack import Stack  # noqa: E402

WEB_PORT = 8060


def serve_web() -> http.server.ThreadingHTTPServer:
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a, **k):  # noqa: D401 - im lặng log truy cập
            pass
    handler = functools.partial(Quiet, directory=str(ROOT / "build/web"))
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", WEB_PORT), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def npm_root() -> str:
    return subprocess.run(["npm", "root", "-g"], capture_output=True, text=True, check=True).stdout.strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenario", default="fish_loop")
    ap.add_argument("--keep", action="store_true", help="giữ stack chạy sau khi xong (để xem tay)")
    ap.add_argument("--external-api", help="dùng máy chủ đang chạy sẵn (ví dụ gói server đã giải nén), không tự dựng stack")
    ap.add_argument("--external-ws")
    a = ap.parse_args()
    if not (ROOT / "build/web/index.pck").exists():
        print("Chưa có build/web — chạy tools/build/export.py web trước")
        return 2
    steps = json.loads((ROOT / f"tests/web/scenarios/{a.scenario}.json").read_text(encoding="utf-8"))
    user = "e2e" + secrets.token_hex(4)
    text = json.dumps(steps, ensure_ascii=False).replace("{USER}", user).replace("{BASE}", f"http://127.0.0.1:{WEB_PORT}")
    if a.external_api and a.external_ws:
        # client đọc ?api=&ws= (chỉ nhận https/wss hoặc localhost)
        text = text.replace("index.html?autotest=1", f"index.html?autotest=1&api={a.external_api}&ws={a.external_ws}")
    out = ROOT / "tests/web/artifacts" / a.scenario
    out.mkdir(parents=True, exist_ok=True)
    (out / "scenario.json").write_text(text, encoding="utf-8")
    st = Stack(extra_env={"CABAY_DEBUG_INPUT": "1"} if os.environ.get("CABAY_DEBUG_INPUT") == "1" else None)
    httpd = None
    try:
        if not (a.external_api and a.external_ws):
            st.start_backend()
            st.start_room_server()
        httpd = serve_web()
        env = dict(os.environ, NODE_PATH=npm_root())
        r = subprocess.run(["node", str(ROOT / "tests/web/drive.cjs"), str(out / "scenario.json"), str(out)],
                           env=env, capture_output=True, text=True, timeout=900)
        print(r.stdout.strip())
        log = (out / "console.log").read_text(encoding="utf-8") if (out / "console.log").exists() else ""
        events = [l.split()[2] for l in log.splitlines() if l.startswith("[log] CABAY_EV")]
        summary = {"scenario": a.scenario, "ok": "DRIVE_OK" in r.stdout, "events": sorted(set(events)),
                   "rejections": [l[6:] for l in log.splitlines() if l.startswith("[log] CABAY_REJ")],
                   "page_errors": [l for l in log.splitlines() if l.startswith("[pageerror]")]}
        (out / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1), encoding="utf-8")
        print(json.dumps(summary, ensure_ascii=False))
        if a.keep:
            input("Stack đang chạy; Enter để dừng…")
        return 0 if summary["ok"] and not summary["page_errors"] else 1
    finally:
        if httpd:
            httpd.shutdown()
        st.stop()
        for name, lp in st.logs.items():
            if lp.exists():
                (out / f"server-{name}.log").write_text(lp.read_text(errors="replace")[-200000:], encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
