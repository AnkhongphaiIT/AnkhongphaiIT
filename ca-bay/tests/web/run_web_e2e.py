#!/usr/bin/env python3
"""Kiểm thử đầu-cuối client web thật: backend + room server Godot + bản web đã xuất, điều khiển bằng
Chromium (Playwright) qua giao diện người dùng — đăng ký, vào phòng, câu, đập xỉu, nhặt.

  python3 tools/build/export.py web            # xuất bản web localhost trước
  python3 tests/web/run_web_e2e.py [--scenario fish_loop] [--keep]

Kịch bản trong tests/web/scenarios/<tên>.json; {USER} và {BASE} được thay lúc chạy.
--seed-stage isl1_boss: tạo tài khoản checkpoint bằng server/ops/seed_checkpoint.py (pipeline op thật) trước khi
room server chạy; tên/mật khẩu thay vào {CP_USER}/{CP_PASS}.
Ảnh chụp + console lưu ở tests/web/artifacts/<tên>/ (không commit).
"""
from __future__ import annotations

import argparse
import functools
import http.server
import json
import os
import secrets
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/integration"))
from stack import Stack  # noqa: E402

WEB_PORT = 8060


def serve_web(directory: Path | None = None, port: int = WEB_PORT) -> http.server.ThreadingHTTPServer:
    class Quiet(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *a, **k):  # noqa: D401 - im lặng log truy cập
            pass
    handler = functools.partial(Quiet, directory=str(directory or ROOT / "build/web"))
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd


def npm_root() -> str:
    # Ưu tiên playwright cài trong dự án (`npm install --prefix build/node playwright@1.56.1`, máy Windows — P-045).
    local = ROOT / "build/node/node_modules"
    if (local / "playwright").is_dir():
        return str(local)
    npm = shutil.which("npm") or "npm"  # Windows: npm.cmd
    return subprocess.run([npm, "root", "-g"], capture_output=True, text=True, check=True).stdout.strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenario", default="fish_loop")
    ap.add_argument("--keep", action="store_true", help="giữ stack chạy sau khi xong (để xem tay)")
    ap.add_argument("--external-api", help="dùng máy chủ đang chạy sẵn (ví dụ gói server đã giải nén), không tự dựng stack")
    ap.add_argument("--external-ws")
    ap.add_argument("--seed-stage", help="tạo tài khoản checkpoint ở mốc này (isl1_boss, isl2_start, …)")
    ap.add_argument("--cp-file", help="máy chủ ngoài: file checkpoint_accounts.txt do ops/seed_checkpoint.py của gói máy chủ ghi; dùng dòng --cp-stage")
    ap.add_argument("--cp-stage", default="isl1_boss")
    ap.add_argument("--iframe", action="store_true", help="chạy game trong iframe khác site (trang cha localhost:8061) — giả lập itch.io")
    ap.add_argument("--selfhost", action="store_true",
                    help="một cổng (P-035): backend phục vụ build/web và chuyển tiếp /ws tới room server; cần export.py web --selfhost")
    a = ap.parse_args()
    if not (ROOT / "build/web/index.pck").exists():
        print("Chưa có build/web — chạy tools/build/export.py web trước")
        return 2
    selfhost_build = b'"api_base": "@origin"' in (ROOT / "build/web/index.pck").read_bytes()
    if a.selfhost and a.external_api:
        pass  # gói máy chủ đã giải nén tự phục vụ trang (web/ của gói), không dùng build/web
    elif a.selfhost != selfhost_build:
        print("build/web không khớp chế độ: " + ("cần tools/build/export.py web --selfhost" if a.selfhost else "đây là bản --selfhost, xuất lại tools/build/export.py web"))
        return 2
    steps = json.loads((ROOT / f"tests/web/scenarios/{a.scenario}.json").read_text(encoding="utf-8"))
    user = "e2e" + secrets.token_hex(4)
    base = (a.external_api or "http://127.0.0.1:8787") if a.selfhost else f"http://127.0.0.1:{WEB_PORT}"
    text = json.dumps(steps, ensure_ascii=False).replace("{USER}", user).replace("{BASE}", base)
    if a.iframe:
        import urllib.parse
        game = f"http://127.0.0.1:{WEB_PORT}/index.html?autotest=1"
        text = text.replace(f"http://127.0.0.1:{WEB_PORT}/index.html?autotest=1", f"http://localhost:{WEB_PORT + 1}/index.html#" + urllib.parse.quote(game, safe=""), 1)
    if a.external_api and a.external_ws and not a.selfhost:
        # client đọc ?api=&ws= (chỉ nhận https/wss hoặc localhost)
        text = text.replace("index.html?autotest=1", f"index.html?autotest=1&api={a.external_api}&ws={a.external_ws}")
    out = ROOT / "tests/web/artifacts" / a.scenario
    out.mkdir(parents=True, exist_ok=True)
    if a.cp_file:
        for line in Path(a.cp_file).read_text(encoding="utf-8").splitlines():
            parts = line.split("\t")
            if parts and parts[0] == a.cp_stage:
                text = text.replace("{CP_USER}", parts[1]).replace("{CP_PASS}", parts[2])
    (out / "scenario.json").write_text(text, encoding="utf-8")
    extra = {"CABAY_DEBUG_INPUT": "1"} if os.environ.get("CABAY_DEBUG_INPUT") == "1" else {}
    if a.selfhost:
        # cùng origin: không cần CORS; trình duyệt chỉ thấy cổng 8787
        extra.update({"CABAY_WEB_DIR": str(ROOT / "build/web"), "CABAY_WS_UPSTREAM": "ws://127.0.0.1:8910", "CABAY_ALLOWED_ORIGINS": ""})
    st = Stack(extra_env=extra or None)
    httpd = host = None
    try:
        if not (a.external_api and (a.external_ws or a.selfhost)):
            st.start_backend()
            if a.seed_stage:
                cp_file = st.tmp / "checkpoint_accounts.txt"
                r = subprocess.run([str(ROOT / "server/backend/.venv/bin/python"), str(ROOT / "server/ops/seed_checkpoint.py"),
                                    "--stage", a.seed_stage, "--out", str(cp_file), "--yes-this-is-an-operator-db"],
                                   env={k: v for k, v in st.env.items() if k != "CABAY_SERVICE_KEY"}, capture_output=True, text=True, timeout=120)
                print(r.stdout.strip() or r.stderr.strip())
                if r.returncode != 0:
                    return 1
                stage, cp_user, cp_pass = cp_file.read_text(encoding="utf-8").strip().split("\t")[:3]
                (out / "scenario.json").write_text(text.replace("{CP_USER}", cp_user).replace("{CP_PASS}", cp_pass), encoding="utf-8")
            st.start_room_server()
        if not a.selfhost:
            httpd = serve_web()
        if a.iframe:
            host = serve_web(ROOT / "tests/web/iframe_host", WEB_PORT + 1)
        env = dict(os.environ, NODE_PATH=npm_root())
        # chạy driver, đọc stdout từng dòng: DRIVE_SIGNAL restart_room <down_ms> <term|kill> → tắt/bật room server thật
        proc = subprocess.Popen(["node", str(ROOT / "tests/web/drive.cjs"), str(out / "scenario.json"), str(out)],
                                env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        stdout_lines: list[str] = []
        workers: list[threading.Thread] = []

        def restart_room(down_ms: int, mode: str) -> None:
            import signal as _sig
            if mode == "kill" and getattr(st, "room", None) and st.room.poll() is None:
                os.killpg(st.room.pid, _sig.SIGKILL)  # sập đột ngột: không gửi session.closed
                st.room.wait(10)
            st.stop_room_server()
            time.sleep(down_ms / 1000.0)
            st._room_gen = getattr(st, "_room_gen", 1) + 1
            st.start_room_server(f"room{st._room_gen}")
            print(f"[runner] room server bật lại sau {down_ms} ms ({mode})", flush=True)

        deadline = time.time() + 900
        for line in proc.stdout:
            stdout_lines.append(line.rstrip("\n"))
            if line.startswith("DRIVE_SIGNAL restart_room") and not (a.external_api and a.external_ws):
                _, _, down, mode = line.split()
                th = threading.Thread(target=restart_room, args=(int(down), mode), daemon=True)
                th.start()
                workers.append(th)
            if time.time() > deadline:
                proc.kill()
                break
        proc.wait(30)
        for th in workers:
            th.join(60)

        class _R:  # giữ giao diện cũ (r.stdout) cho phần tổng kết bên dưới
            stdout = "\n".join(l for l in stdout_lines if not l.startswith("DRIVE_SIGNAL"))
        r = _R()
        # bộ nhớ tiến trình máy chủ sau buổi chạy (VmRSS hiện tại / VmHWM đỉnh), MB — PERF-01 phía server
        server_mem = {}
        for name, proc in (("room", getattr(st, "room", None)), ("backend", getattr(st, "backend", None))):
            try:
                txt = Path(f"/proc/{proc.pid}/status").read_text()
                vals = {l.split(":")[0]: int(l.split()[1]) for l in txt.splitlines() if l.startswith(("VmRSS", "VmHWM"))}
                server_mem[name] = {"rss_mb": round(vals["VmRSS"] / 1024, 1), "peak_mb": round(vals["VmHWM"] / 1024, 1)}
            except Exception:
                pass
        print(r.stdout.strip())
        log = (out / "console.log").read_text(encoding="utf-8") if (out / "console.log").exists() else ""
        events = [l.split()[2] for l in log.splitlines() if l.startswith("[log] CABAY_EV")]
        summary = {"scenario": a.scenario, "ok": "DRIVE_OK" in r.stdout, "events": sorted(set(events)),
                   "rejections": [l[6:] for l in log.splitlines() if l.startswith("[log] CABAY_REJ")],
                   "page_errors": [l for l in log.splitlines() if "[pageerror]" in l],
                   "other_pages": sorted({l.split()[2] for l in log.splitlines() if l.startswith("[p1] [log] CABAY_EV") or l.startswith("[p1] [log] CABAY_OTHER")}),
                   "perf": [l.split("CABAY_PERF ", 1)[1] for l in log.splitlines() if "CABAY_PERF " in l],
                   "server_mem": server_mem}
        endpoints = sorted({l.split("CABAY_ENDPOINTS ", 1)[1] for l in log.splitlines() if "CABAY_ENDPOINTS " in l})
        summary["endpoints"] = endpoints
        want = base.replace("http://", "ws://") + "/ws"
        if a.selfhost and endpoints != [f"api={base} ws={want}"]:
            summary["ok"] = False  # client phải đi đúng một cổng (trang, API, /ws), không nối thẳng room server
        (out / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1), encoding="utf-8")
        print(json.dumps(summary, ensure_ascii=False))
        if a.keep:
            input("Stack đang chạy; Enter để dừng…")
        return 0 if summary["ok"] and not summary["page_errors"] else 1
    finally:
        if httpd:
            httpd.shutdown()
        if host:
            host.shutdown()
        st.stop()
        for name, lp in st.logs.items():
            if lp.exists():
                (out / f"server-{name}.log").write_text(lp.read_text(errors="replace")[-200000:], encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
