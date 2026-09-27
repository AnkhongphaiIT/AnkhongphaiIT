"""SAVE-04: backup DB đang dùng bằng API an toàn, restore vào vị trí khác, kiểm integrity và đăng nhập được."""
from __future__ import annotations

import importlib.util
import threading
import uuid
from pathlib import Path

from conftest import commit, connect_player, fresh_fish, ready_room, register

SPEC = importlib.util.spec_from_file_location("backup", Path(__file__).resolve().parents[2] / "ops" / "backup" / "backup.py")
backup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(backup)


def test_backup_while_writing_and_restore(client, svc, env, monkeypatch):
    users = [register(client) for _ in range(3)]
    room = ready_room(client, svc, users[0])
    lease = connect_player(client, svc, users[0], room)
    stop = threading.Event()

    def writer():
        while not stop.is_set():
            commit(client, svc, lease, "bait.select", {"bait_id": "bait_bread"})

    t = threading.Thread(target=writer)
    t.start()
    try:
        paths = [backup.do_backup(env / "test.db", env / "backups", keep=2) for _ in range(3)]
    finally:
        stop.set()
        t.join()
    remaining = sorted((env / "backups").glob("cabay-*.db"))
    assert len(remaining) <= 2
    rep = backup.restore(remaining[-1], env / "restored" / "cabay.db")
    assert rep["integrity"] == "ok" and rep["accounts"] == 3 and rep["saves"] == 3
    # server chạy trên bản restore: đăng nhập lấy đúng save
    monkeypatch.setenv("CABAY_DB_PATH", str(env / "restored" / "cabay.db"))
    from app import config
    import app.db, app.deps
    config.reload_settings()
    app.db.settings = config.settings
    app.deps.settings = config.settings
    r = client.post("/v1/auth/login", json={"username": users[1]["username"], "password": users[1]["password"]})
    assert r.status_code == 200
    s = client.get("/v1/account/save", headers={"Authorization": f"Bearer {r.json()['access_token']}"}).json()["save"]
    assert s["account_id"] == users[1]["account_id"]
