"""Chạy một kịch bản bot trên stack thật (backend + room server Godot) với cổng riêng, có điều phối từ ngoài.

    python3 tests/integration/run_bots.py --scenario quest_boss --bots 1
    python3 tests/integration/run_bots.py --scenario quest_boss --bots 4
    python3 tests/integration/run_bots.py --scenario content_all --bots 1 --timeout 2400
    python3 tests/integration/run_bots.py --scenario takeover --bots 2
    python3 tests/integration/run_bots.py --scenario restart --bots 1
    python3 tests/integration/run_bots.py --scenario two_rooms --bots 4 --max-rooms 2

Mặc định API 8797 / WS 8920 (không đụng stack khác ở 8787/8910). Bot in "BOTSIGNAL restart_room" → runner dừng
room server (tiến trình do chính runner tạo), chờ 2 s rồi bật lại. --db giữ DB giữa các lần chạy (tiếp tục bằng
--bot-arg=--from-island=2 --bot-arg=--user=<tên> --bot-arg=--password=<mk>; không sửa save trong DB).
In kết quả JSON (BOTRESULT) và ghi --out nếu có. Mã thoát 0 = kịch bản đạt.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from stack import Stack  # noqa: E402

SHOW = ("CHECK", "BOTRESULT", "TIMING", "NOTE", "BOTSIGNAL", "[stack]", "[boss]", "CONTENT", "SCRIPT ERROR", "ERROR", "USER ERROR")


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
    a = ap.parse_args()

    extra_env = {"CABAY_MAX_ROOMS": str(a.max_rooms)} if a.max_rooms > 0 else {}
    st = Stack(a.api_port, a.ws_port, db_path=Path(a.db).resolve() if a.db else None, extra_env=extra_env)
    t0 = time.time()
    try:
        st.start_backend()
        st.start_room_server()
        print(f"[stack] API :{a.api_port} WS :{a.ws_port} log {st.tmp}", flush=True)

        def show(ln: str) -> None:
            if a.verbose or ln.startswith(SHOW) or "Parse Error" in ln or "[bot" in ln and ("lỗi" in ln or "thất bại" in ln):
                print(ln, flush=True)

        extra = [f"--timeout={int(a.timeout) - 15}", *a.bot_arg]
        r = st.run_bots_live(a.scenario, a.bots, timeout=a.timeout, extra_args=extra, on_line=show)
        wall = time.time() - t0
        summary = {"scenario": a.scenario, "bots": a.bots, "exit": r["exit"], "timed_out": r["timed_out"], "wall_s": round(wall, 1),
                   "signals": r["signals"], "result": r["result"], "logs": str(st.tmp)}
        print(f"[stack] xong sau {wall:.1f}s, exit={r['exit']}, log bot: {st.tmp / ('bots-' + a.scenario + '.log')}", flush=True)
        if a.out:
            Path(a.out).write_text(json.dumps(summary, ensure_ascii=False, indent=1))
        return 0 if r["result"] and r["result"].get("ok") else 1
    finally:
        st.stop()


if __name__ == "__main__":
    sys.exit(main())
