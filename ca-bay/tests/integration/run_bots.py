"""Chạy một kịch bản bot trên stack thật (backend + room server Godot) với cổng riêng, có điều phối từ ngoài.

    python3 tests/integration/run_bots.py --scenario quest_boss --bots 1
    python3 tests/integration/run_bots.py --scenario quest_boss --bots 4
    python3 tests/integration/run_bots.py --scenario content_all --bots 1 --timeout 2400 [--bot-arg=--all-species]
    python3 tests/integration/run_bots.py --scenario takeover --bots 2
    python3 tests/integration/run_bots.py --scenario restart --bots 1
    python3 tests/integration/run_bots.py --scenario two_rooms --bots 4 --max-rooms 2
    python3 tests/integration/run_bots.py --scenario summon_replay --bots 2      (gửi lại boss.summon cùng op_id)
    python3 tests/integration/run_bots.py --scenario kick_cleanup --bots 2       (server tự ngắt phiên rate_limit)
    python3 tests/integration/run_bots.py --scenario pickup_blink --bots 1       (nhặt cá đang "stunned_waking")
  WP-12 (mạng xấu / mất mạng / boss co-op nâng cao / giết room server):
    python3 tests/integration/run_bots.py --scenario net_outage --bots 2 --proxy --delay-ms 0 --jitter-ms 0 --timeout 900
    python3 tests/integration/run_bots.py --scenario net_halfopen --bots 2 --proxy --delay-ms 0 --jitter-ms 0
    python3 tests/integration/run_bots.py --scenario fish_loop --bots 4 --proxy                (RTT ≈150 ms ± 30 ms/chiều)
    python3 tests/integration/run_bots.py --scenario quest_boss --bots 2 --proxy
    python3 tests/integration/run_bots.py --scenario fish_net --bots 3 --proxy --cut-mean-s 25  (cắt ngẫu nhiên, bot tự nối lại)
    python3 tests/integration/run_bots.py --scenario quest_boss --bots 2 --proxy --bot-arg=--net-cuts
    python3 tests/integration/run_bots.py --scenario boss_coop --bots 4
    python3 tests/integration/run_bots.py --scenario room_kill_boss --bots 2
    python3 tests/integration/run_bots.py --scenario owner_leave --bots 3

Mặc định API 8797 / WS 8920 (không đụng stack khác ở 8787/8910); proxy mạng xấu (tests/integration/netem_proxy.py) nghe
8921 khi có --proxy và bot nối `ws://127.0.0.1:8921`. Bot in "BOTSIGNAL restart_room" → runner dừng room server (tiến trình
do chính runner tạo), chờ 2 s rồi bật lại. Bot in "BOTSIGNAL <tên> {json có "id"}" → runner làm việc điều phối (cắt/đóng
băng kết nối ở proxy, SIGKILL/bật room server, đọc DB test, lùi created_at trận boss trong DB test rồi gọi
`app.main.maintenance_once()`, commit nội bộ bằng epoch cũ) và ghi kết quả JSON vào `<ipc-dir>/<id>.json` cho bot đọc.
--db giữ DB giữa các lần chạy (tiếp tục bằng --bot-arg=--from-island=2 --bot-arg=--user=<tên> --bot-arg=--password=<mk>;
không sửa save trong DB). In kết quả JSON (BOTRESULT) và ghi --out nếu có. Mã thoát 0 = kịch bản đạt.
"""
from __future__ import annotations

import argparse
import json
import os
import queue
import signal
import sqlite3
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from netem_proxy import ProxyThread  # noqa: E402
from stack import BACKEND, ROOT, Stack  # noqa: E402

SHOW = ("CHECK", "BOTRESULT", "TIMING", "NOTE", "BOTSIGNAL", "[stack]", "[boss]", "[proxy]", "[ipc]", "CONTENT", "SCRIPT ERROR", "ERROR", "USER ERROR")


class Harness:
    """Việc điều phối bot yêu cầu qua BOTSIGNAL. Chỉ đụng tiến trình/DB/proxy do chính runner này tạo."""

    def __init__(self, st: Stack, proxy: ProxyThread | None, ipc_dir: Path, say):
        self.st, self.proxy, self.ipc_dir, self.say = st, proxy, ipc_dir, say
        self.handled: list[dict] = []
        self.room_events: list[dict] = []

    # ---------------------------------------------------------------- điều phối chung
    def handle(self, name: str, args: dict) -> dict:
        t0 = time.time()
        try:
            fn = getattr(self, "h_" + name, None)
            res = fn(args) if fn else {"ok": False, "error": f"không có lệnh {name}"}
        except Exception as e:  # trả lỗi cho bot thay vì treo
            res = {"ok": False, "error": f"{type(e).__name__}: {e}"}
        res.setdefault("ok", True)
        res["took_s"] = round(time.time() - t0, 2)
        brief = {k: v for k, v in args.items() if k != "id"}
        self.handled.append({"t": round(t0 - self.st_t0, 1), "name": name, "args": brief, "ok": res.get("ok"),
                             "error": res.get("error")})
        self.say(f"[ipc] {name} {json.dumps(brief, ensure_ascii=False)[:160]} → ok={res.get('ok')} {str(res.get('error') or '')[:120]}")
        return res

    st_t0 = time.time()

    def reply(self, rid: str, res: dict) -> None:
        tmp = self.ipc_dir / f".{rid}.tmp"
        tmp.write_text(json.dumps(res, ensure_ascii=False, default=str))
        tmp.rename(self.ipc_dir / f"{rid}.json")

    # ---------------------------------------------------------------- proxy mạng xấu
    def h_proxy(self, a: dict) -> dict:
        if self.proxy is None:
            return {"ok": False, "error": "chạy không có --proxy"}
        op = a.get("op", "")
        aid = a.get("account_id")
        cid = a.get("cid")
        if op == "cut":
            return self.proxy.cut(aid, cid)
        if op == "freeze":
            return self.proxy.mode("both", "hold", aid, cid)
        if op == "thaw":
            return self.proxy.mode("both", "pass", aid, cid)
        if op == "mute":
            return self.proxy.mode(a.get("dir", "both"), "drop", aid, cid)
        if op == "unmute":
            return self.proxy.mode(a.get("dir", "both"), "pass", aid, cid)
        if op == "halfopen":
            return self.proxy.halfopen(aid, cid)
        if op == "release":
            return self.proxy.release(aid, cid)
        if op == "stats":
            return {"stats": self.proxy.stats()}
        if op == "conns":
            return {"conns": self.proxy.conns()}
        return {"ok": False, "error": f"proxy op {op}"}

    # ---------------------------------------------------------------- room server (tiến trình do runner tạo)
    def h_room(self, a: dict) -> dict:
        op = a.get("op", "")
        st = self.st
        if op in ("kill", "term"):
            p = st.room
            if p.poll() is not None:
                return {"ok": False, "error": "room server đã dừng"}
            sig = signal.SIGKILL if op == "kill" else signal.SIGTERM
            os.killpg(p.pid, sig)
            try:
                p.wait(10)
            except subprocess.TimeoutExpired:
                os.killpg(p.pid, signal.SIGKILL)
                p.wait(5)
            ev = {"op": op, "pid": p.pid, "exit": p.returncode, "t": round(time.time() - self.st_t0, 1)}
            self.room_events.append(ev)
            return ev
        if op == "start":
            st._room_gen = getattr(st, "_room_gen", 1) + 1
            t0 = time.time()
            st.start_room_server(f"room{st._room_gen}")
            ev = {"op": op, "pid": st.room.pid, "log": str(st.logs[st.room_log]), "startup_s": round(time.time() - t0, 2),
                  "t": round(time.time() - self.st_t0, 1)}
            self.room_events.append(ev)
            return ev
        if op == "restart":
            took = st.restart_room_server(float(a.get("down_s", 2.0)))
            ev = {"op": op, "seconds": round(took, 2), "log": str(st.logs[st.room_log]), "t": round(time.time() - self.st_t0, 1)}
            self.room_events.append(ev)
            return ev
        if op == "alive":
            return {"alive": st.room.poll() is None}
        return {"ok": False, "error": f"room op {op}"}

    # ---------------------------------------------------------------- DB test (chỉ đọc, trừ age_boss_attempt)
    def _db(self) -> sqlite3.Connection:
        c = sqlite3.connect(str(self.st.db), timeout=10, isolation_level=None)
        c.row_factory = sqlite3.Row
        c.execute("PRAGMA busy_timeout=10000")
        return c

    def h_db(self, a: dict) -> dict:
        c = self._db()
        try:
            return self._query(c, a)
        finally:
            c.close()

    def _query(self, c: sqlite3.Connection, a: dict) -> dict:
        q = a.get("q", "")
        if True:
            if q == "lease":
                r = c.execute("SELECT account_id, room_id, epoch, active, connection_id FROM gameplay_leases WHERE account_id=?", (a["account_id"],)).fetchone()
                return {"row": dict(r) if r else None}
            if q == "boss_attempts":
                sql, par = "SELECT encounter_id, account_id, boss_id, bait_id, room_id, status, created_at, resolved_at FROM boss_attempts WHERE 1=1", []
                for k in ("account_id", "encounter_id"):
                    if a.get(k):
                        sql += f" AND {k}=?"
                        par.append(a[k])
                return {"rows": [dict(r) for r in c.execute(sql + " ORDER BY created_at, rowid", par)]}
            if q == "reward_claims":
                sql, par = "SELECT account_id, claim_key, reward_kind, created_at FROM reward_claims WHERE claim_key=?", [a["claim_key"]]
                if a.get("account_id"):
                    sql += " AND account_id=?"
                    par.append(a["account_id"])
                return {"rows": [dict(r) for r in c.execute(sql, par)]}
            if q == "max_op_rowid":
                return {"rowid": c.execute("SELECT COALESCE(MAX(rowid), 0) FROM operations").fetchone()[0]}
            if q == "ops_since":
                rows = []
                for r in c.execute("SELECT rowid, op_id, op_type, result_json FROM operations WHERE account_id=? AND rowid>? ORDER BY rowid",
                                   (a["account_id"], int(a.get("rowid", 0)))):
                    res = json.loads(r["result_json"])
                    rec = res.get("receipt") if isinstance(res.get("receipt"), dict) else {}
                    rec = {k: v for k, v in rec.items() if k in ("item_uid", "total", "new_species", "value", "encounter_id", "moved", "money", "bait_id")}
                    rows.append({"rowid": r["rowid"], "op_id": r["op_id"], "op_type": r["op_type"], "status": res.get("status"),
                                 "error_code": res.get("error_code"), "save_version": res.get("save_version"), "receipt": rec})
                return {"rows": rows}
            if q == "item":
                r = c.execute("SELECT item_uid, owner_account_id, def_id, state, room_id, state_since FROM item_registry WHERE item_uid=?", (a["item_uid"],)).fetchone()
                return {"row": dict(r) if r else None}
            if q == "room":
                r = c.execute("SELECT room_id, owner_account_id, island_id, status, updated_at FROM rooms WHERE room_id=?", (a["room_id"],)).fetchone()
                m = [dict(x) for x in c.execute("SELECT account_id, connected FROM room_members WHERE room_id=?", (a["room_id"],))]
                return {"row": dict(r) if r else None, "members": m}
            if q == "save_version":
                r = c.execute("SELECT save_version FROM account_saves WHERE account_id=?", (a["account_id"],)).fetchone()
                return {"save_version": r[0] if r else None}
        return {"ok": False, "error": f"db q {q}"}

    def h_age_boss_attempt(self, a: dict) -> dict:
        """CHỈ TRÊN DB TEST: lùi created_at của một trận boss còn 'open' để vòng dọn (15 phút) xử lý ngay, khỏi chờ thật."""
        secs = int(a.get("seconds", 1000))
        c = self._db()
        try:
            c.execute("BEGIN IMMEDIATE")
            n = c.execute("UPDATE boss_attempts SET created_at=created_at-? WHERE encounter_id=? AND status='open'", (secs, a["encounter_id"])).rowcount
            c.execute("COMMIT")
        finally:
            c.close()
        return {"updated": n, "seconds": secs, "db": str(self.st.db)}

    def h_maintenance(self, a: dict) -> dict:
        """Gọi đúng hàm sản phẩm app.main.maintenance_once() trong một tiến trình Python trên cùng DB test (không thêm API)."""
        py = str(BACKEND / ".venv" / "bin" / "python")
        code = "import json\nfrom app.main import maintenance_once\nprint('MAINT ' + json.dumps(maintenance_once()))"
        r = subprocess.run([py, "-c", code], cwd=str(BACKEND), env=self.st.env, capture_output=True, text=True, timeout=120)
        for ln in r.stdout.splitlines():
            if ln.startswith("MAINT "):
                return {"result": json.loads(ln[6:]), "exit": r.returncode}
        return {"ok": False, "error": f"maintenance exit {r.returncode}: {(r.stderr or r.stdout)[-400:]}"}

    def h_commit(self, a: dict) -> dict:
        """Commit qua API nội bộ như một phiên room server cũ (epoch cũ) — kiểm fencing lease."""
        body = {"account_id": a["account_id"], "lease_epoch": a.get("lease_epoch"), "room_id": a.get("room_id"),
                "op_id": a.get("op_id") or str(uuid.uuid4()), "op_type": a["op_type"], "payload": a.get("payload", {}),
                "expected_save_version": a.get("expected_save_version")}
        req = urllib.request.Request(f"http://127.0.0.1:{self.st.api_port}/internal/accounts/commit", data=json.dumps(body).encode(), method="POST")
        req.add_header("Content-Type", "application/json")
        req.add_header("X-Service-Key", self.st.key)
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                out = json.loads(r.read() or b"{}")
                code = r.status
        except urllib.error.HTTPError as e:
            out = json.loads(e.read() or b"{}")
            code = e.code
        out.pop("save", None)
        return {"http": code, "result": out, "op_id": body["op_id"]}

    def h_note(self, a: dict) -> dict:
        return {}


def run_live(st: Stack, h: Harness, scenario: str, bots: int, timeout: float, extra_args, on_line) -> dict:
    """Như Stack.run_bots_live nhưng xử lý thêm BOTSIGNAL có JSON (trả lời qua file trong ipc-dir)."""
    cmd = st.bot_cmd(scenario, bots, extra_args)
    p = subprocess.Popen(cmd, cwd=ROOT, env=st.env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
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
            rest = ln.split(" ", 1)[1].strip()
            name, _, js = rest.partition(" ")
            if name == "restart_room" and not js:
                took = st.restart_room_server()
                signals.append({"signal": name, "seconds": round(took, 2), "log": st.room_log})
                if on_line:
                    on_line(f"[stack] room server đã khởi động lại sau {took:.1f}s (log {st.logs[st.room_log]})")
                continue
            try:
                args = json.loads(js) if js else {}
            except json.JSONDecodeError:
                args = {}
            rid = str(args.get("id", ""))
            out = h.handle(name, args)
            if rid:
                h.reply(rid, out)
    try:
        p.wait(10)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid, signal.SIGKILL)
    out = "\n".join(lines)
    (st.tmp / f"bots-{scenario}.log").write_text(out)
    return {"exit": p.returncode, "result": res, "log": out, "signals": signals, "timed_out": timed_out}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenario", required=True)
    ap.add_argument("--bots", type=int, default=1)
    ap.add_argument("--api-port", type=int, default=8797)
    ap.add_argument("--ws-port", type=int, default=8920)
    ap.add_argument("--timeout", type=float, default=900.0, help="giây cho tiến trình bot (runner Godot nhận cùng giá trị)")
    ap.add_argument("--max-rooms", type=int, default=0, help="CABAY_MAX_ROOMS cho backend (0 = mặc định hợp đồng)")
    ap.add_argument("--db", default="", help="đường dẫn SQLite giữ lại giữa các lần chạy")
    ap.add_argument("--bot-arg", action="append", default=[], help="tham số thêm cho bot_runner (lặp lại được)")
    ap.add_argument("--out", default="", help="ghi JSON kết quả vào file")
    ap.add_argument("--verbose", action="store_true", help="in mọi dòng log của bot")
    ap.add_argument("--proxy", action="store_true", help="bot nối room server qua proxy mạng xấu (netem_proxy.py) ở --proxy-port")
    ap.add_argument("--proxy-port", type=int, default=8921)
    ap.add_argument("--delay-ms", type=float, default=75.0, help="trễ mỗi chiều của proxy (RTT ≈ 2×)")
    ap.add_argument("--jitter-ms", type=float, default=30.0, help="jitter đều ± mỗi chiều (không đảo thứ tự byte)")
    ap.add_argument("--queue-kb", type=int, default=256, help="giới hạn hàng đợi mỗi chiều của proxy")
    ap.add_argument("--cut-mean-s", type=float, default=0.0, help=">0: cắt ngẫu nhiên một kết nối đã xác thực, trung bình mỗi N giây")
    ap.add_argument("--seed", type=int, default=None)
    a = ap.parse_args()

    extra_env = {"CABAY_MAX_ROOMS": str(a.max_rooms)} if a.max_rooms > 0 else {}
    st = Stack(a.api_port, a.ws_port, db_path=Path(a.db).resolve() if a.db else None, extra_env=extra_env)
    t0 = time.time()
    proxy: ProxyThread | None = None
    try:
        st.start_backend()
        st.start_room_server()
        print(f"[stack] API :{a.api_port} WS :{a.ws_port} log {st.tmp}", flush=True)

        def show(ln: str) -> None:
            if a.verbose or ln.startswith(SHOW) or "Parse Error" in ln or "[bot" in ln and ("lỗi" in ln or "thất bại" in ln):
                print(ln, flush=True)

        extra = [f"--timeout={int(a.timeout) - 15}"]
        ipc_dir = st.tmp / "ipc"
        ipc_dir.mkdir(exist_ok=True)
        extra.append(f"--ipc-dir={ipc_dir}")
        extra.append(f"--direct-ws=ws://127.0.0.1:{a.ws_port}")
        if a.proxy:
            proxy = ProxyThread(listen_port=a.proxy_port, target_host="127.0.0.1", target_port=a.ws_port, delay_ms=a.delay_ms,
                                jitter_ms=a.jitter_ms, queue_kb=a.queue_kb, cut_mean_s=a.cut_mean_s, seed=a.seed).start()
            extra.append(f"--ws=ws://127.0.0.1:{a.proxy_port}")
            extra.append("--via-proxy")
        extra += a.bot_arg
        h = Harness(st, proxy, ipc_dir, lambda s: print(s, flush=True))
        h.st_t0 = t0
        r = run_live(st, h, a.scenario, a.bots, timeout=a.timeout, extra_args=extra, on_line=show)
        wall = time.time() - t0
        summary = {"scenario": a.scenario, "bots": a.bots, "exit": r["exit"], "timed_out": r["timed_out"], "wall_s": round(wall, 1),
                   "signals": r["signals"], "ipc": h.handled, "room_events": h.room_events, "result": r["result"], "logs": str(st.tmp),
                   "network": {"proxy": a.proxy, "delay_ms": a.delay_ms if a.proxy else 0, "jitter_ms": a.jitter_ms if a.proxy else 0,
                               "cut_mean_s": a.cut_mean_s if a.proxy else 0}}
        if proxy is not None:
            summary["proxy"] = proxy.stats()
            summary["proxy"]["events_tail"] = proxy.proxy.events[-30:]
            print("[proxy] " + json.dumps({k: v for k, v in summary["proxy"].items() if k != "events_tail"}, ensure_ascii=False), flush=True)
        room_alive = st.room.poll() is None
        summary["room_server_alive_at_end"] = room_alive
        print(f"[stack] xong sau {wall:.1f}s, exit={r['exit']}, room server còn sống={room_alive}, log bot: {st.tmp / ('bots-' + a.scenario + '.log')}", flush=True)
        if a.out:
            Path(a.out).write_text(json.dumps(summary, ensure_ascii=False, indent=1))
        return 0 if r["result"] and r["result"].get("ok") else 1
    finally:
        if proxy is not None:
            proxy.stop()
        st.stop()


if __name__ == "__main__":
    sys.exit(main())
