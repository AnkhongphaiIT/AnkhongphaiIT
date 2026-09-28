"""Tự host một cổng (P-035): backend phục vụ luôn bản web (file tĩnh) và chuyển tiếp WebSocket `/ws` tới room server
trên cùng máy. Một đường hầm HTTPS (cloudflared, Tailscale Funnel…) trỏ vào cổng backend là ra MỘT link chơi được:
trang game, API tài khoản và kết nối phòng chơi cùng một origin (không cần CORS, không phải xuất lại bản web theo URL).

Bật bằng biến môi trường (run/choi_thu.* đặt sẵn):
  CABAY_WEB_DIR=<thư mục bản web selfhost>    CABAY_WS_UPSTREAM=ws://127.0.0.1:8910
Chỉ chuyển tiếp tới room server trên chính máy này (loopback) — không thành cầu nối tới máy khác.
"""
from __future__ import annotations

import asyncio
import logging
import mimetypes
from pathlib import Path
from urllib.parse import urlsplit

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from starlette.staticfiles import StaticFiles
from starlette.types import Scope

log = logging.getLogger("cabay.selfhost")

# Client gửi tối đa 8 KB mỗi gói (network_contract max_client_payload_bytes) — 64 KB là quá đủ, lớn hơn là bất thường.
CLIENT_MAX_BYTES = 64 * 1024
# Room server gửi tối đa 64 KB mỗi gói (max_server_payload_bytes) + đầu gói Godot.
UPSTREAM_MAX_BYTES = 1 << 20
LOOPBACK = {"127.0.0.1", "localhost", "::1"}

# Windows có thể khai .js là text/plain trong registry; trình duyệt cần đúng kiểu cho wasm/js.
for _ext, _type in ((".wasm", "application/wasm"), (".js", "text/javascript"), (".pck", "application/octet-stream"),
                    (".html", "text/html"), (".png", "image/png"), (".md", "text/plain")):
    mimetypes.add_type(_type, _ext)


class WebFiles(StaticFiles):
    """File tĩnh của bản web. `no-cache` = trình duyệt luôn hỏi lại (ETag) → cập nhật bản mới không bị kẹt bản cũ."""

    async def get_response(self, path: str, scope: Scope):
        resp = await super().get_response(path, scope)
        resp.headers["Cache-Control"] = "no-cache"
        resp.headers["X-Content-Type-Options"] = "nosniff"
        resp.headers["Referrer-Policy"] = "no-referrer"
        return resp


def check_upstream(url: str) -> str:
    u = urlsplit(url)
    if u.scheme != "ws" or u.hostname not in LOOPBACK or not u.port:
        raise ValueError("CABAY_WS_UPSTREAM phải là ws://127.0.0.1:<cổng> (room server trên cùng máy)")
    return url


async def relay(client: WebSocket, upstream_url: str) -> None:
    """Nối một kết nối trình duyệt với một kết nối tới room server; chuyển nguyên từng gói hai chiều (nhị phân/văn bản)."""
    from websockets.asyncio.client import connect
    from websockets.exceptions import WebSocketException

    await client.accept()
    try:
        up = await connect(upstream_url, max_size=UPSTREAM_MAX_BYTES, ping_interval=None, open_timeout=5, compression=None)
    except (OSError, WebSocketException, asyncio.TimeoutError):
        await client.close(code=1013)  # room server chưa chạy: "thử lại sau"
        return
    close_code = 1000

    async def to_upstream() -> None:
        nonlocal close_code
        while True:
            m = await client.receive()
            if m["type"] == "websocket.disconnect":
                return
            data = m.get("bytes")
            if data is None:
                data = m.get("text")
            if data is None:
                continue
            if len(data) > CLIENT_MAX_BYTES:
                close_code = 1009  # gói quá lớn
                return
            await up.send(data)

    async def to_client() -> None:
        async for m in up:
            if isinstance(m, bytes):
                await client.send_bytes(m)
            else:
                await client.send_text(m)

    tasks = {asyncio.create_task(to_upstream()), asyncio.create_task(to_client())}
    try:
        done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for t in pending:
            t.cancel()
        await asyncio.gather(*pending, return_exceptions=True)
        for t in done:
            if not t.cancelled() and t.exception() is not None and not isinstance(t.exception(), (WebSocketException, OSError)):
                log.warning("ws relay: %s", type(t.exception()).__name__)
    finally:
        if up.close_code is not None and close_code == 1000:
            close_code = up.close_code if up.close_code in (1000, 1001) or 3000 <= up.close_code < 5000 else 1011
        await up.close()
        try:
            await client.close(code=close_code)
        except (RuntimeError, OSError, WebSocketDisconnect):
            pass  # trình duyệt đã đóng trước


def install(app: FastAPI, web_dir: Path | None, ws_upstream: str | None) -> None:
    """Gọi SAU khi đã gắn các router API: route `/ws` và file tĩnh `/` chỉ nhận những đường chưa có chủ."""
    if ws_upstream:
        upstream = check_upstream(ws_upstream)

        @app.websocket("/ws")
        async def ws_relay(ws: WebSocket) -> None:
            await relay(ws, upstream)

    if web_dir:
        if not (Path(web_dir) / "index.html").is_file():
            raise RuntimeError(f"CABAY_WEB_DIR không có index.html: {web_dir}")
        app.mount("/", WebFiles(directory=str(web_dir), html=True), name="web")
