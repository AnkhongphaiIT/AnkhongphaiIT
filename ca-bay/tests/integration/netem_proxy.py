#!/usr/bin/env python3
"""NET-05: proxy TCP userspace (asyncio) mô phỏng mạng xấu giữa bot/trình duyệt và room server WebSocket.

    python3 tests/integration/netem_proxy.py --listen 8921 --target 127.0.0.1:8920 --delay-ms 75 --jitter-ms 30 [--cut-mean-s 40]
    python3 tests/integration/netem_proxy.py --selftest        (đo RTT/thứ tự qua proxy với máy chủ echo, cổng tạm do hệ điều hành cấp)

Vì sao không dùng `tc netem`: kernel của VM không có qdisc netem (`CONFIG_NET_SCH_NETEM is not set`, không có /lib/modules),
container không có binary `tc`; ngoài ra netem trên `lo` làm trễ cả stack khác đang chạy trên cùng máy.

Mô hình:
- Mỗi chiều của một kết nối là một hàng đợi FIFO. Khối byte đọc lúc t được giao lúc max(t + delay ± jitter, lúc giao khối
  trước) → trễ trung bình `delay_ms` mỗi chiều (RTT ≈ 2×delay), jitter phân bố đều ±`jitter_ms`, **không bao giờ đảo thứ tự
  byte trong một chiều** (TCP không cho phép; proxy chỉ làm trễ).
- Hàng đợi mỗi chiều có giới hạn byte (`queue_kb`): đầy thì ngừng đọc → áp lực ngược về TCP (không đệm vô hạn).
- Cắt kết nối ngẫu nhiên (tùy chọn, `cut_mean_s` > 0): khoảng cách giữa hai lần cắt theo phân bố mũ; cắt cứng một kết nối
  đã xác thực (đóng cả hai phía), client tự nối lại.
- Điều khiển (nhúng trong tests/integration/run_bots.py): cut / freeze / thaw / mute / halfopen theo account_id. account_id
  của kết nối đọc từ `session.accepted` mà server gửi (khung WebSocket server→client không mask, JSON Godot sắp khóa).

Chỉ dùng cho kiểm thử local; không đụng sản phẩm.
"""
from __future__ import annotations

import argparse
import asyncio
import collections
import json
import random
import re
import socket
import statistics
import threading
import time

SNIFF = re.compile(rb'"payload":\{"account_id":"([0-9a-f-]{36})","connection_id":"([0-9a-f-]{36})","content_hash"')


def _pct(xs: list[float], p: float) -> float:
    if not xs:
        return 0.0
    s = sorted(xs)
    k = min(len(s) - 1, max(0, int(round(p / 100.0 * (len(s) - 1)))))
    return s[k]


def summarize(xs: list[float]) -> dict:
    if not xs:
        return {"n": 0}
    return {"n": len(xs), "mean": round(statistics.fmean(xs), 1), "p50": round(_pct(xs, 50), 1), "p95": round(_pct(xs, 95), 1),
            "min": round(min(xs), 1), "max": round(max(xs), 1)}


class Pipe:
    """Một chiều của kết nối: đọc → hàng đợi (thời điểm giao đơn điệu) → ghi."""

    def __init__(self, conn: "Conn", name: str, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        self.conn, self.name, self.reader, self.writer = conn, name, reader, writer
        self.q: collections.deque = collections.deque()  # (deliver_at, read_at, data, held)
        self.queued = 0
        self.max_queued = 0
        self.last_at = 0.0
        self.mode = "pass"  # pass | hold (đọc, giữ lại, chưa giao) | drop (đọc rồi bỏ) | stall (ngừng đọc)
        self.eof = False
        self.bytes_in = 0
        self.bytes_out = 0
        self.dropped = 0
        self.chunks = 0
        self.delays_ms: list[float] = []
        self.order_violations = 0
        self._last_deliver = 0.0
        self.wake = asyncio.Event()
        self.space = asyncio.Event()
        self.space.set()
        self.sniff_tail = b""

    @property
    def proxy(self) -> "NetemProxy":
        return self.conn.proxy

    def set_mode(self, mode: str) -> None:
        self.mode = mode
        self.wake.set()
        self.space.set()

    async def read_loop(self) -> None:
        loop = asyncio.get_running_loop()
        try:
            while not self.conn.closed:
                if self.mode == "stall":
                    await self.wake.wait()
                    self.wake.clear()
                    continue
                limit = self.proxy.hold_limit if self.mode == "hold" else self.proxy.queue_limit
                if self.queued > limit:
                    self.space.clear()
                    await self.space.wait()
                    continue
                data = await self.reader.read(65536)
                if not data:
                    self.eof = True
                    self.wake.set()
                    return
                now = loop.time()
                self.bytes_in += len(data)
                if self.name == "s2c" and self.conn.account_id is None:
                    self._sniff(data)
                if self.mode == "drop":
                    self.dropped += len(data)
                    continue
                at = max(now + self.proxy.sample_delay(), self.last_at)
                self.last_at = at
                self.q.append((at, now, data, self.mode == "hold"))
                self.queued += len(data)
                self.max_queued = max(self.max_queued, self.queued)
                self.wake.set()
        except (ConnectionError, OSError, asyncio.IncompleteReadError):
            self.eof = True
            self.wake.set()
        except asyncio.CancelledError:
            raise

    def _sniff(self, data: bytes) -> None:
        buf = self.sniff_tail + data
        m = SNIFF.search(buf)
        if m:
            self.conn.account_id = m.group(1).decode()
            self.conn.connection_id = m.group(2).decode()
            self.proxy.log(f"conn#{self.conn.cid} = account {self.conn.account_id[:8]} connection_id {self.conn.connection_id[:8]}")
            self.sniff_tail = b""
        else:
            self.sniff_tail = buf[-400:]

    async def write_loop(self) -> None:
        loop = asyncio.get_running_loop()
        try:
            while not self.conn.closed:
                if not self.q or self.mode in ("hold", "stall"):
                    if self.eof and not self.q and self.mode not in ("hold", "stall") and self.conn.state == "open":
                        # nguồn đã đóng và đã giao hết: đóng êm cả hai phía (dữ liệu cuối như session.closed vẫn tới nơi)
                        await self.conn.close(f"{self.name}_eof", abort=False)
                        return
                    self.wake.clear()
                    await self.wake.wait()
                    continue
                at, read_at, data, held = self.q[0]
                now = loop.time()
                if at > now and not held:
                    try:
                        await asyncio.wait_for(self.wake.wait(), timeout=at - now)
                        self.wake.clear()
                    except asyncio.TimeoutError:
                        pass
                    continue
                self.q.popleft()
                self.queued -= len(data)
                self.space.set()
                if self.mode == "drop":
                    self.dropped += len(data)
                    continue
                t = loop.time()
                if t + 1e-9 < self._last_deliver:
                    self.order_violations += 1
                self._last_deliver = t
                if not held:
                    self.delays_ms.append((t - read_at) * 1000.0)
                self.writer.write(data)
                self.bytes_out += len(data)
                self.chunks += 1
                await self.writer.drain()
        except (ConnectionError, OSError):
            await self.conn.close(f"{self.name}_write_error")
        except asyncio.CancelledError:
            raise


class Conn:
    def __init__(self, proxy: "NetemProxy", cid: int, cr, cw, sr, sw):
        self.proxy, self.cid = proxy, cid
        self.cw, self.sw = cw, sw
        self.account_id: str | None = None
        self.connection_id: str | None = None
        self.opened = time.time()
        self.closed = False
        self.close_reason = ""
        self.state = "open"  # open | frozen | halfopen | closed
        self.c2s = Pipe(self, "c2s", cr, sw)
        self.s2c = Pipe(self, "s2c", sr, cw)
        self.tasks: list[asyncio.Task] = []

    def start(self) -> None:
        for p in (self.c2s, self.s2c):
            self.tasks.append(asyncio.ensure_future(p.read_loop()))
            self.tasks.append(asyncio.ensure_future(p.write_loop()))

    async def close(self, reason: str, abort: bool = True) -> None:
        if self.closed:
            return
        self.closed = True
        self.state = "closed"
        self.close_reason = reason
        for w in (self.cw, self.sw):
            try:
                if abort:
                    w.transport.abort()
                else:
                    w.close()
            except Exception:
                pass
        cur = asyncio.current_task()
        for t in self.tasks:
            if t is not cur:
                t.cancel()
        self.proxy.log(f"conn#{self.cid} đóng ({reason}) account={str(self.account_id)[:8]}")

    def info(self) -> dict:
        return {"cid": self.cid, "account_id": self.account_id, "connection_id": self.connection_id, "state": self.state,
                "close_reason": self.close_reason, "age_s": round(time.time() - self.opened, 1),
                "c2s": {"in": self.c2s.bytes_in, "out": self.c2s.bytes_out, "dropped": self.c2s.dropped, "queued": self.c2s.queued, "max_queued": self.c2s.max_queued},
                "s2c": {"in": self.s2c.bytes_in, "out": self.s2c.bytes_out, "dropped": self.s2c.dropped, "queued": self.s2c.queued, "max_queued": self.s2c.max_queued}}


class NetemProxy:
    def __init__(self, listen_port: int, target_host: str, target_port: int, delay_ms: float = 75.0, jitter_ms: float = 30.0,
                 queue_kb: int = 256, hold_kb: int = 8192, cut_mean_s: float = 0.0, seed: int | None = None, quiet: bool = False,
                 listen_host: str = "127.0.0.1"):
        self.listen_host, self.listen_port = listen_host, listen_port
        self.target_host, self.target_port = target_host, target_port
        self.delay_s, self.jitter_s = delay_ms / 1000.0, jitter_ms / 1000.0
        self.queue_limit, self.hold_limit = queue_kb * 1024, hold_kb * 1024
        self.cut_mean_s = cut_mean_s
        self.rng = random.Random(seed)
        self.quiet = quiet
        self.conns: dict[int, Conn] = {}
        self._next = 0
        self.events: list[dict] = []
        self.cuts: list[dict] = []
        self.refused = 0
        self.server: asyncio.AbstractServer | None = None
        self.loop: asyncio.AbstractEventLoop | None = None
        self._cut_task: asyncio.Task | None = None
        self.t0 = time.time()

    # ------------------------------------------------------------ tiện ích
    def log(self, msg: str) -> None:
        ev = {"t": round(time.time() - self.t0, 2), "msg": msg}
        self.events.append(ev)
        if not self.quiet:
            print(f"[proxy] {ev['t']:8.2f}s {msg}", flush=True)

    def sample_delay(self) -> float:
        if self.delay_s <= 0 and self.jitter_s <= 0:
            return 0.0
        return max(0.0, self.delay_s + self.rng.uniform(-self.jitter_s, self.jitter_s))

    # ------------------------------------------------------------ vòng đời
    async def start(self) -> None:
        self.loop = asyncio.get_running_loop()
        self.server = await asyncio.start_server(self._on_client, self.listen_host, self.listen_port)
        self.listen_port = self.server.sockets[0].getsockname()[1]
        self.log(f"nghe {self.listen_host}:{self.listen_port} → {self.target_host}:{self.target_port}, trễ {self.delay_s*1000:.0f}±{self.jitter_s*1000:.0f} ms/chiều, "
                 f"hàng đợi {self.queue_limit // 1024} KiB, cắt ngẫu nhiên {'mỗi ~%.0f s' % self.cut_mean_s if self.cut_mean_s > 0 else 'tắt'}")
        if self.cut_mean_s > 0:
            self._cut_task = asyncio.ensure_future(self._random_cuts())

    async def stop(self) -> None:
        if self._cut_task:
            self._cut_task.cancel()
        if self.server:
            self.server.close()
        for c in list(self.conns.values()):
            await c.close("proxy_stop")

    async def _on_client(self, cr: asyncio.StreamReader, cw: asyncio.StreamWriter) -> None:
        self._next += 1
        cid = self._next
        try:
            sr, sw = await asyncio.open_connection(self.target_host, self.target_port)
        except OSError as e:
            self.refused += 1
            self.log(f"conn#{cid} không nối được đích: {e}")
            cw.transport.abort()
            return
        for w in (cw, sw):
            sock = w.get_extra_info("socket")
            if sock is not None:
                sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        c = Conn(self, cid, cr, cw, sr, sw)
        self.conns[cid] = c
        c.start()
        self.log(f"conn#{cid} mở từ {cw.get_extra_info('peername')}")

    async def _random_cuts(self) -> None:
        while True:
            await asyncio.sleep(self.rng.expovariate(1.0 / self.cut_mean_s))
            live = [c for c in self.conns.values() if not c.closed and c.state == "open" and c.account_id]
            if not live:
                continue
            c = self.rng.choice(live)
            self.cuts.append({"t": round(time.time() - self.t0, 2), "cid": c.cid, "account_id": c.account_id, "kind": "random"})
            await c.close("random_cut")

    # ------------------------------------------------------------ điều khiển (chạy trong loop)
    def _match(self, account_id: str | None = None, cid: int | None = None, include_closed: bool = False) -> list[Conn]:
        out = []
        for c in self.conns.values():
            if c.closed and not include_closed:
                continue
            if cid is not None and c.cid != cid:
                continue
            if account_id is not None and c.account_id != account_id:
                continue
            out.append(c)
        return out

    async def a_cut(self, account_id=None, cid=None) -> dict:
        cs = self._match(account_id, cid)
        for c in cs:
            self.cuts.append({"t": round(time.time() - self.t0, 2), "cid": c.cid, "account_id": c.account_id, "kind": "manual"})
            await c.close("manual_cut")
        return {"ok": bool(cs), "cut": [c.cid for c in cs]}

    async def a_mode(self, direction: str, mode: str, account_id=None, cid=None) -> dict:
        cs = self._match(account_id, cid)
        for c in cs:
            for p in ((c.c2s, c.s2c) if direction == "both" else (c.c2s,) if direction == "c2s" else (c.s2c,)):
                p.set_mode(mode)
            if mode == "hold" and direction == "both":
                c.state = "frozen"
            elif mode == "pass" and direction == "both" and c.state == "frozen":
                c.state = "open"
        self.log(f"{direction}={mode} cho {[c.cid for c in cs]} (account {str(account_id)[:8]})")
        return {"ok": bool(cs), "conns": [c.cid for c in cs]}

    async def a_halfopen(self, account_id=None, cid=None) -> dict:
        """Mất mạng thật: phía client thấy đứt ngay, phía server không nhận FIN/RST và không còn ai đọc (không ACK)."""
        cs = self._match(account_id, cid)
        for c in cs:
            c.state = "halfopen"
            c.s2c.set_mode("stall")
            c.c2s.set_mode("drop")
            try:
                c.cw.transport.abort()
            except Exception:
                pass
        self.log(f"half-open cho {[c.cid for c in cs]} (account {str(account_id)[:8]})")
        return {"ok": bool(cs), "conns": [c.cid for c in cs]}

    async def a_release(self, account_id=None, cid=None) -> dict:
        """Kết thúc half-open/freeze bằng cách đóng hẳn cả hai phía."""
        cs = [c for c in self._match(account_id, cid) if c.state in ("halfopen", "frozen")]
        for c in cs:
            await c.close("released")
        return {"ok": bool(cs), "conns": [c.cid for c in cs]}

    def stats(self) -> dict:
        d_c2s: list[float] = []
        d_s2c: list[float] = []
        order = 0
        byt = {"c2s": 0, "s2c": 0}
        maxq = {"c2s": 0, "s2c": 0}
        for c in self.conns.values():
            d_c2s += c.c2s.delays_ms
            d_s2c += c.s2c.delays_ms
            order += c.c2s.order_violations + c.s2c.order_violations
            byt["c2s"] += c.c2s.bytes_out
            byt["s2c"] += c.s2c.bytes_out
            maxq["c2s"] = max(maxq["c2s"], c.c2s.max_queued)
            maxq["s2c"] = max(maxq["s2c"], c.s2c.max_queued)
        return {"listen": self.listen_port, "target": f"{self.target_host}:{self.target_port}",
                "delay_ms": self.delay_s * 1000, "jitter_ms": self.jitter_s * 1000, "queue_kb": self.queue_limit // 1024,
                "connections": len(self.conns), "live": sum(1 for c in self.conns.values() if not c.closed),
                "cuts": self.cuts, "order_violations": order, "bytes": byt, "max_queued_bytes": maxq,
                "one_way_delay_ms": {"c2s": summarize(d_c2s), "s2c": summarize(d_s2c)}}

    def conn_list(self) -> list[dict]:
        return [c.info() for c in self.conns.values()]


class ProxyThread:
    """Chạy NetemProxy trong luồng nền (event loop riêng) để script đồng bộ điều khiển được."""

    def __init__(self, **kw):
        self.proxy = NetemProxy(**kw)
        self._ready = threading.Event()
        self._stop: asyncio.Event | None = None
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.error: BaseException | None = None

    def _run(self) -> None:
        async def main():
            self._stop = asyncio.Event()
            try:
                await self.proxy.start()
            except BaseException as e:  # cổng bận...
                self.error = e
                self._ready.set()
                return
            self._ready.set()
            await self._stop.wait()
            await self.proxy.stop()
        asyncio.run(main())

    def start(self) -> "ProxyThread":
        self.thread.start()
        self._ready.wait(10)
        if self.error:
            raise RuntimeError(f"proxy không mở được: {self.error}")
        return self

    def call(self, coro, timeout: float = 10.0):
        return asyncio.run_coroutine_threadsafe(coro, self.proxy.loop).result(timeout)

    def sync(self, fn, timeout: float = 10.0):
        async def w():
            return fn()
        return self.call(w(), timeout)

    # API đồng bộ
    def cut(self, account_id=None, cid=None) -> dict:
        return self.call(self.proxy.a_cut(account_id, cid))

    def mode(self, direction: str, mode: str, account_id=None, cid=None) -> dict:
        return self.call(self.proxy.a_mode(direction, mode, account_id, cid))

    def halfopen(self, account_id=None, cid=None) -> dict:
        return self.call(self.proxy.a_halfopen(account_id, cid))

    def release(self, account_id=None, cid=None) -> dict:
        return self.call(self.proxy.a_release(account_id, cid))

    def stats(self) -> dict:
        return self.sync(self.proxy.stats)

    def conns(self) -> list[dict]:
        return self.sync(self.proxy.conn_list)

    def stop(self) -> None:
        if self._stop is not None and self.proxy.loop is not None:
            self.proxy.loop.call_soon_threadsafe(self._stop.set)
        self.thread.join(10)


# ---------------------------------------------------------------- tự kiểm (không cần game)

async def _selftest(n: int, delay_ms: float, jitter_ms: float) -> dict:
    """Máy chủ echo + client gửi n tin đánh số qua proxy: đo RTT, kiểm thứ tự, kiểm lượng byte."""
    async def echo(r, w):
        try:
            while True:
                d = await r.read(65536)
                if not d:
                    break
                w.write(d)
                await w.drain()
        finally:
            w.close()
    srv = await asyncio.start_server(echo, "127.0.0.1", 0)
    eport = srv.sockets[0].getsockname()[1]
    px = NetemProxy(0, "127.0.0.1", eport, delay_ms=delay_ms, jitter_ms=jitter_ms, quiet=True, seed=1)
    await px.start()
    r, w = await asyncio.open_connection("127.0.0.1", px.listen_port)
    loop = asyncio.get_running_loop()
    sent: dict[int, float] = {}
    rtts: list[float] = []
    order_ok = True
    got = 0
    buf = b""

    async def rx():
        nonlocal buf, got, order_ok
        while got < n:
            d = await r.read(65536)
            if not d:
                break
            buf += d
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                i = int(line.split(b" ")[0])
                if i != got:
                    order_ok = False
                rtts.append((loop.time() - sent[i]) * 1000.0)
                got += 1
    t = asyncio.ensure_future(rx())
    for i in range(n):
        sent[i] = loop.time()
        w.write(b"%d %s\n" % (i, b"x" * random.randint(10, 2000)))
        await w.drain()
        await asyncio.sleep(0.02)
    await asyncio.wait_for(t, 30)
    w.close()
    st = px.stats()
    await px.stop()
    srv.close()
    return {"messages": n, "received": got, "in_order": order_ok and got == n, "rtt_ms": summarize(rtts),
            "one_way_delay_ms": st["one_way_delay_ms"], "order_violations": st["order_violations"]}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--listen", type=int, default=8921)
    ap.add_argument("--target", default="127.0.0.1:8920")
    ap.add_argument("--delay-ms", type=float, default=75.0)
    ap.add_argument("--jitter-ms", type=float, default=30.0)
    ap.add_argument("--queue-kb", type=int, default=256)
    ap.add_argument("--cut-mean-s", type=float, default=0.0)
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--n", type=int, default=300)
    a = ap.parse_args()
    if a.selftest:
        res = asyncio.run(_selftest(a.n, a.delay_ms, a.jitter_ms))
        print(json.dumps(res, ensure_ascii=False))
        return 0 if res["in_order"] and res["order_violations"] == 0 else 1
    host, port = a.target.rsplit(":", 1)
    pt = ProxyThread(listen_port=a.listen, target_host=host, target_port=int(port), delay_ms=a.delay_ms, jitter_ms=a.jitter_ms,
                     queue_kb=a.queue_kb, cut_mean_s=a.cut_mean_s, seed=a.seed).start()
    try:
        while True:
            time.sleep(10)
            print("[proxy] " + json.dumps(pt.stats(), ensure_ascii=False), flush=True)
    except KeyboardInterrupt:
        pass
    finally:
        print(json.dumps(pt.stats(), ensure_ascii=False))
        pt.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
