"""Tự host một cổng (P-035): backend phục vụ bản web + chuyển tiếp /ws tới room server trên cùng máy.

Phía room server ở đây là một máy chủ WebSocket thật (thư viện websockets) chạy trên cổng loopback ngẫu nhiên;
kiểm thử chạy qua đúng app FastAPI của backend (nạp lại với CABAY_WEB_DIR/CABAY_WS_UPSTREAM). Đường đi thật
trình duyệt → backend → room server Godot kiểm bằng tests/web/run_web_e2e.py --selfhost.
"""
from __future__ import annotations

import asyncio
import importlib
import threading

import pytest
from starlette.websockets import WebSocketDisconnect


class Upstream:
    """Máy chủ WS giả vai room server: dội lại gói (giữ kiểu nhị phân/văn bản), 'bye' → đóng mã 4000."""

    def __init__(self) -> None:
        self.loop = asyncio.new_event_loop()
        self.port = 0
        self.connections = 0
        self.received: list = []
        self._ready = threading.Event()
        self._stop: asyncio.Future | None = None
        self.thread = threading.Thread(target=self._run, daemon=True)

    async def _handler(self, ws) -> None:
        self.connections += 1
        async for m in ws:
            self.received.append(m)
            if m == "bye":
                await ws.close(code=4000, reason="kicked")
                return
            await ws.send((b"echo:" + m) if isinstance(m, bytes) else ("echo:" + m))

    async def _main(self) -> None:
        from websockets.asyncio.server import serve
        self._stop = self.loop.create_future()
        async with serve(self._handler, "127.0.0.1", 0, compression=None) as server:
            self.port = next(iter(server.sockets)).getsockname()[1]
            self._ready.set()
            await self._stop

    def _run(self) -> None:
        self.loop.run_until_complete(self._main())

    def __enter__(self) -> "Upstream":
        self.thread.start()
        assert self._ready.wait(10)
        return self

    def __exit__(self, *exc) -> None:
        self.loop.call_soon_threadsafe(self._stop.set_result, None)
        self.thread.join(10)


def _selfhost_app(env, monkeypatch, web_dir, upstream_url):
    monkeypatch.setenv("CABAY_WEB_DIR", str(web_dir))
    monkeypatch.setenv("CABAY_WS_UPSTREAM", upstream_url)
    from app import config
    config.reload_settings()
    import app.main
    return importlib.reload(app.main).app


@pytest.fixture()
def web_dir(tmp_path):
    d = tmp_path / "web"
    d.mkdir()
    (d / "index.html").write_text("<!doctype html><title>CÁ BAY</title>", encoding="utf-8")
    (d / "index.js").write_text("var Engine={};", encoding="utf-8")
    (d / "index.wasm").write_bytes(b"\0asm\1\0\0\0")
    (d / "index.pck").write_bytes(b"GDPC")
    return d


@pytest.fixture()
def restore_main(monkeypatch):
    yield
    # các test khác dùng app không bật tự host
    monkeypatch.delenv("CABAY_WEB_DIR", raising=False)
    monkeypatch.delenv("CABAY_WS_UPSTREAM", raising=False)
    from app import config
    config.reload_settings()
    import app.main
    importlib.reload(app.main)


def test_one_origin_serves_page_api_and_relay(env, monkeypatch, web_dir, restore_main):
    from fastapi.testclient import TestClient
    with Upstream() as up:
        app = _selfhost_app(env, monkeypatch, web_dir, f"ws://127.0.0.1:{up.port}")
        with TestClient(app) as c:
            # trang game + kiểu MIME đúng (wasm phải là application/wasm để trình duyệt biên dịch)
            r = c.get("/")
            assert r.status_code == 200 and "CÁ BAY" in r.text and r.headers["content-type"].startswith("text/html")
            assert r.headers["cache-control"] == "no-cache" and r.headers["x-content-type-options"] == "nosniff"
            assert c.get("/index.wasm").headers["content-type"] == "application/wasm"
            assert c.get("/index.js").headers["content-type"].startswith("text/javascript")
            assert c.get("/index.pck").headers["content-type"] == "application/octet-stream"
            # API vẫn ưu tiên hơn file tĩnh, đường lạ vẫn 404, không đọc được file ngoài thư mục web
            h = c.get("/healthz").json()
            assert h["ok"] is True and h["content_hash"]
            assert c.post("/v1/auth/login", json={"username": "khongco", "password": "x" * 12}).status_code in (400, 401)
            assert c.get("/khong-co.txt").status_code == 404
            assert c.get("/../conftest.py").status_code == 404
            # chuyển tiếp WebSocket: nhị phân và văn bản giữ nguyên kiểu, hai chiều
            with c.websocket_connect("/ws") as ws:
                ws.send_bytes(b"\x01\x02\xffgoi")
                assert ws.receive_bytes() == b"echo:\x01\x02\xffgoi"
                ws.send_text("xin chào")
                assert ws.receive_text() == "echo:xin chào"
                # room server đóng (đá người chơi) → trình duyệt nhận đúng mã đóng
                ws.send_text("bye")
                with pytest.raises(WebSocketDisconnect) as e:
                    ws.receive_bytes()
                assert e.value.code == 4000
            # gói quá lớn từ trình duyệt bị chặn ở cổng, không chuyển tới room server
            before = len(up.received)
            with c.websocket_connect("/ws") as ws:
                ws.send_bytes(b"x" * (64 * 1024 + 1))
                with pytest.raises(WebSocketDisconnect) as e:
                    ws.receive_bytes()
                assert e.value.code == 1009
            assert len(up.received) == before
            assert up.connections == 2  # mỗi kết nối trình duyệt = đúng một kết nối tới room server


def test_relay_reports_room_server_down(env, monkeypatch, web_dir, restore_main):
    import socket
    from fastapi.testclient import TestClient
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()  # cổng trống: room server chưa chạy
    app = _selfhost_app(env, monkeypatch, web_dir, f"ws://127.0.0.1:{port}")
    with TestClient(app) as c:
        with c.websocket_connect("/ws") as ws:
            with pytest.raises(WebSocketDisconnect) as e:
                ws.receive_bytes()
            assert e.value.code == 1013


def test_upstream_must_be_loopback():
    from app.selfhost import check_upstream
    assert check_upstream("ws://127.0.0.1:8910") == "ws://127.0.0.1:8910"
    for bad in ("ws://10.0.0.5:8910", "wss://evil.example/ws", "ws://127.0.0.1", "http://127.0.0.1:8910"):
        with pytest.raises(ValueError):
            check_upstream(bad)


def test_selfhost_off_by_default(client):
    # không đặt biến môi trường → không có /ws, không phục vụ file (bản triển khai itch.io giữ nguyên)
    assert client.get("/").status_code == 404
    assert client.get("/index.html").status_code == 404
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect("/ws") as ws:
            ws.receive_bytes()
