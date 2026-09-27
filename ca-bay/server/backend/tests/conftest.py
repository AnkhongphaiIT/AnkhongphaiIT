"""Fixture test backend: DB SQLite thật trong thư mục tạm, hash scrypt giảm tham số CHỈ trong môi trường test."""
from __future__ import annotations

import os
import sys
import uuid
from pathlib import Path

import pytest

BACKEND = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND))

SERVICE_KEY = "test-service-key-" + uuid.uuid4().hex


@pytest.fixture()
def env(tmp_path, monkeypatch):
    monkeypatch.setenv("CABAY_ENV", "test")
    monkeypatch.setenv("CABAY_TEST_FAST_HASH", "1")
    monkeypatch.setenv("CABAY_DB_PATH", str(tmp_path / "test.db"))
    monkeypatch.setenv("CABAY_SERVICE_KEY", SERVICE_KEY)
    from app import config, content
    config.reload_settings()
    content.reset_catalog()
    # các module đã import `settings` theo tên: cập nhật tham chiếu
    import app.db, app.security, app.deps, app.save
    for m in (app.db, app.security, app.deps, app.save):
        m.settings = config.settings
    app.save._validator.cache_clear()
    from app.ratelimit import limiter
    limiter.reset()
    yield tmp_path


@pytest.fixture()
def client(env):
    from fastapi.testclient import TestClient
    from app.main import app
    with TestClient(app) as c:
        yield c


@pytest.fixture()
def svc():
    return {"X-Service-Key": SERVICE_KEY}


def register(client, username=None, password="correct horse battery", display="Người Câu"):
    username = username or ("u" + uuid.uuid4().hex[:10])
    r = client.post("/v1/auth/register", json={"username": username, "display_name": display, "password": password})
    assert r.status_code == 200, r.text
    d = r.json()
    d["username"] = username
    d["password"] = password
    d["auth"] = {"Authorization": f"Bearer {d['access_token']}"}
    return d


def ready_room(client, svc, owner):
    r = client.post("/v1/rooms", json={}, headers=owner["auth"])
    assert r.status_code == 200, r.text
    room = r.json()
    ctl = client.get("/internal/room-controls", headers=svc).json()["controls"]
    ack = [c["control_id"] for c in ctl if c["room_id"] == room["room_id"]]
    r = client.post("/internal/room-status", headers=svc, json={"acks": ack, "rooms": [{"room_id": room["room_id"], "status": "ready", "island_id": room["island_id"]}]})
    assert r.status_code == 200
    return room


def connect_player(client, svc, player, room):
    """Ticket + consume như room server làm; trả lease."""
    if player.get("_joined") != room["room_id"]:
        r = client.post(f"/v1/rooms/{room['room_id']}/join", json={"invite_code": room["invite_code"]}, headers=player["auth"])
        assert r.status_code == 200, r.text
    t = client.post(f"/v1/rooms/{room['room_id']}/ticket", headers=player["auth"])
    assert t.status_code == 200, t.text
    tj = t.json()
    c = client.post("/internal/tickets/consume", headers=svc, json={"ticket": tj["ticket"], "protocol_version": tj["protocol_version"], "content_hash": tj["content_hash"], "connection_id": str(uuid.uuid4())})
    assert c.status_code == 200, c.text
    return c.json()


def commit(client, svc, lease, op_type, payload, expected=None, op_id=None, server=False):
    body = {"account_id": lease["account_id"], "lease_epoch": lease["lease_epoch"], "room_id": lease["room_id"],
            "op_id": op_id or str(uuid.uuid4()), "op_type": op_type, "payload": payload,
            "expected_save_version": None if server else (expected if expected is not None else current_version(client, svc, lease))}
    r = client.post("/internal/accounts/commit", headers=svc, json=body)
    assert r.status_code == 200, r.text
    return r.json()


_versions: dict = {}


def current_version(client, svc, lease):
    from app.db import connect
    conn = connect()
    try:
        return conn.execute("SELECT save_version FROM account_saves WHERE account_id=?", (lease["account_id"],)).fetchone()[0]
    finally:
        conn.close()


def fresh_fish(def_id="cre_ca_ro", tmm=1000, tricks=None, variant=None):
    return {"def_kind": "creature", "def_id": def_id, "variant_id": variant, "trick_mult_milli": tmm, "tricks": tricks or []}
