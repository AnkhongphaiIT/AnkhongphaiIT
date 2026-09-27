"""Dựng stack local thật cho test: backend FastAPI (uvicorn, DB tạm) + room server Godot headless.

    python3 tests/integration/stack.py --scenario fish_loop --bots 4
    python3 tests/integration/stack.py --serve   (chỉ chạy stack để chơi thử local)
"""
from __future__ import annotations

import argparse
import json
import os
import secrets
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import queue
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "server" / "backend"


def godot() -> str:
    return os.environ.get("GODOT_BIN") or shutil.which("godot") or "/opt/godot/4.7.2/godot"


def wait_http(url: str, timeout: float = 20.0) -> bool:
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                if r.status == 200:
                    return True
        except Exception:
            time.sleep(0.2)
    return False


class Stack:
    def __init__(self, api_port=8787, ws_port=8910, db_path: Path | None = None, extra_env: dict | None = None, origins: str = ""):
        self.tmp = Path(tempfile.mkdtemp(prefix="cabay-stack-"))
        self.db = db_path or (self.tmp / "cabay.db")
        self.key = secrets.token_urlsafe(32)
        self.api_port, self.ws_port = api_port, ws_port
        self.procs: list[subprocess.Popen] = []
        self.logs: dict[str, Path] = {}
        self.env = {**os.environ, "CABAY_DB_PATH": str(self.db), "CABAY_SERVICE_KEY": self.key,
                    "CABAY_BACKEND_URL": f"http://127.0.0.1:{api_port}", "CABAY_WS_PORT": str(ws_port),
                    "CABAY_ALLOWED_ORIGINS": origins or f"http://127.0.0.1:8060,http://localhost:8060",
                    **(extra_env or {})}

    def _spawn(self, name, cmd, cwd):
        log = self.tmp / f"{name}.log"
        self.logs[name] = log
        p = subprocess.Popen(cmd, cwd=cwd, env=self.env, stdout=log.open("w"), stderr=subprocess.STDOUT, start_new_session=True)
        self.procs.append(p)
        return p

    def start_backend(self):
        py = str(BACKEND / ".venv" / "bin" / "python")
        self.backend = self._spawn("backend", [py, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", str(self.api_port), "--log-level", "warning"], BACKEND)
        if not wait_http(f"http://127.0.0.1:{self.api_port}/healthz"):
            raise RuntimeError("backend không lên: " + self.logs["backend"].read_text()[-2000:])

    def start_room_server(self, log_name: str = "room"):
        self.room = self._spawn(log_name, [godot(), "--headless", "--path", str(ROOT), "--", "--server"], ROOT)
        self.room_log = log_name
        t0 = time.time()
        while time.time() - t0 < 30:
            if "CABAY_SERVER listening" in self.logs[log_name].read_text():
                return
            if self.room.poll() is not None:
                break
            time.sleep(0.2)
        raise RuntimeError("room server không lên: " + self.logs[log_name].read_text()[-3000:])

    def stop_room_server(self):
        if getattr(self, "room", None) and self.room.poll() is None:
            os.killpg(self.room.pid, signal.SIGTERM)
            try:
                self.room.wait(10)
            except subprocess.TimeoutExpired:
                os.killpg(self.room.pid, signal.SIGKILL)
                self.room.wait(5)

    def restart_room_server(self, down_s: float = 2.0) -> float:
        """Dừng room server (SIGTERM tiến trình do stack tạo), chờ, bật lại với log mới. Trả thời gian (giây)."""
        t0 = time.time()
        self.stop_room_server()
        time.sleep(down_s)
        self._room_gen = getattr(self, "_room_gen", 1) + 1
        self.start_room_server(f"room{self._room_gen}")
        return time.time() - t0

    def bot_cmd(self, scenario: str, bots: int, extra_args=()) -> list[str]:
        return [godot(), "--headless", "--path", str(ROOT), "res://tests/bots/bot_runner.tscn", "--",
                f"--scenario={scenario}", f"--bots={bots}", f"--api=http://127.0.0.1:{self.api_port}",
                f"--ws=ws://127.0.0.1:{self.ws_port}", *extra_args]

    def run_bots_live(self, scenario: str, bots: int, timeout: float = 600, extra_args=(), on_line=None) -> dict:
        """Chạy bot, đọc stdout theo dòng; "BOTSIGNAL restart_room" → khởi động lại room server.
        on_line(line) được gọi cho mọi dòng (để in tiến độ)."""
        cmd = self.bot_cmd(scenario, bots, extra_args)
        p = subprocess.Popen(cmd, cwd=ROOT, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                             bufsize=1, start_new_session=True)
        q: queue.Queue = queue.Queue()

        def reader():
            for ln in p.stdout:
                q.put(ln.rstrip("\n"))
            q.put(None)

        threading.Thread(target=reader, daemon=True).start()
        lines: list[str] = []
        signals: list[dict] = []
        res = None
        deadline = time.time() + timeout
        timed_out = False
        while True:
            try:
                ln = q.get(timeout=max(0.1, min(1.0, deadline - time.time())))
            except queue.Empty:
                if time.time() > deadline:
                    timed_out = True
                    os.killpg(p.pid, signal.SIGKILL)
                    break
                continue
            if ln is None:
                break
            lines.append(ln)
            if on_line:
                on_line(ln)
            if ln.startswith("BOTRESULT "):
                res = json.loads(ln[len("BOTRESULT "):])
            elif ln.startswith("BOTSIGNAL "):
                name = ln.split(" ", 1)[1].strip()
                if name == "restart_room":
                    took = self.restart_room_server()
                    signals.append({"signal": name, "seconds": round(took, 2), "log": self.room_log})
                    if on_line:
                        on_line(f"[stack] room server đã khởi động lại sau {took:.1f}s (log {self.logs[self.room_log]})")
        try:
            p.wait(10)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid, signal.SIGKILL)
        out = "\n".join(lines)
        (self.tmp / f"bots-{scenario}.log").write_text(out)
        return {"exit": p.returncode, "result": res, "log": out, "signals": signals, "timed_out": timed_out}

    def run_bots(self, scenario: str, bots: int, timeout: float = 600) -> dict:
        cmd = [godot(), "--headless", "--path", str(ROOT), "res://tests/bots/bot_runner.tscn", "--",
               f"--scenario={scenario}", f"--bots={bots}", f"--api=http://127.0.0.1:{self.api_port}", f"--ws=ws://127.0.0.1:{self.ws_port}"]
        r = subprocess.run(cmd, cwd=ROOT, env=self.env, capture_output=True, text=True, timeout=timeout)
        out = r.stdout + r.stderr
        (self.tmp / f"bots-{scenario}.log").write_text(out)
        res = None
        for line in out.splitlines():
            if line.startswith("BOTRESULT "):
                res = json.loads(line[len("BOTRESULT "):])
        return {"exit": r.returncode, "result": res, "log": out}

    def stop(self):
        for p in self.procs:
            if p.poll() is None:
                try:
                    os.killpg(p.pid, signal.SIGTERM)
                    p.wait(10)
                except Exception:
                    p.kill()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenario", default="connect4")
    ap.add_argument("--bots", type=int, default=4)
    ap.add_argument("--serve", action="store_true")
    ap.add_argument("--api-port", type=int, default=8787)
    ap.add_argument("--ws-port", type=int, default=8910)
    a = ap.parse_args()
    st = Stack(a.api_port, a.ws_port)
    try:
        st.start_backend()
        st.start_room_server()
        if a.serve:
            print(f"Stack chạy: API http://127.0.0.1:{a.api_port}  WS ws://127.0.0.1:{a.ws_port}  log: {st.tmp}")
            while True:
                time.sleep(3600)
        r = st.run_bots(a.scenario, a.bots)
        for line in r["log"].splitlines():
            if line.startswith(("CHECK", "BOTRESULT", "[bot", "SCRIPT ERROR", "ERROR")) or "Parse Error" in line:
                print(line)
        print("room log:", st.logs["room"])
        return 0 if r["result"] and r["result"]["ok"] else 1
    finally:
        st.stop()


if __name__ == "__main__":
    sys.exit(main())
