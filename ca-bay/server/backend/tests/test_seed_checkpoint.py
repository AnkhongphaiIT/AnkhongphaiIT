"""Công cụ tạo tài khoản checkpoint cho playtest (server/ops/seed_checkpoint.py): đi đúng pipeline op thật,
trả lease/đóng phòng sau khi xong, tài khoản đăng nhập lại và vào được đảo đã mở khóa."""
from __future__ import annotations

import importlib.util
import os
import stat
from pathlib import Path

import pytest

from conftest import SERVICE_KEY

SEED = Path(__file__).resolve().parents[2] / "ops" / "seed_checkpoint.py"


def _mod():
    spec = importlib.util.spec_from_file_location("seed_checkpoint", SEED)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


@pytest.mark.parametrize("stage,islands,bosses", [
    ("isl1_boss", 1, 0), ("isl2_start", 2, 1), ("isl2_boss", 2, 1), ("isl3_start", 3, 2), ("endgame", 3, 3),
])
def test_seed_stage_then_real_login_and_room(client, stage, islands, bosses):
    m = _mod()
    s = m.Seeder(client, SERVICE_KEY)
    pw = "mat-khau-thu-nghiem-dai"
    r = m.seed_one(s, stage, "checkpoint_t" + stage.replace("_", ""), pw)
    assert len(r["islands"]) == islands and len(r["bosses"]) == bosses
    if stage == "isl1_boss":
        assert r["baits"].get("bait_milk_tea") == 1  # đủ mồi để tự gọi Cá Lóc
    # đăng nhập lại như người thử; lease đã trả nên vào được phòng ở đảo mới nhất
    lg = client.post("/v1/auth/login", json={"username": r["username"], "password": pw})
    assert lg.status_code == 200, lg.text
    auth = {"Authorization": f"Bearer {lg.json()['access_token']}"}
    sv = client.get("/v1/account/save", headers=auth).json()
    save = sv.get("save", sv)
    assert save["player"]["safe_island_id"] == r["islands"][-1]
    if stage == "endgame":
        assert all(q["state"] == "completed" for q in save["progress"]["quests"].values())
        assert len(save["progress"]["quests"]) == 6
    room = client.post("/v1/rooms", json={}, headers=auth)
    assert room.status_code == 200, room.text
    assert room.json()["island_id"] == r["islands"][-1]
    # không còn trận boss mở, không còn đồ kẹt escrow
    from app.db import connect
    conn = connect()
    try:
        assert conn.execute("SELECT COUNT(*) FROM boss_attempts WHERE account_id=? AND status='open'", (r["account_id"],)).fetchone()[0] == 0
        assert conn.execute("SELECT COUNT(*) FROM gameplay_leases WHERE account_id=? AND active=1", (r["account_id"],)).fetchone()[0] == 0
    finally:
        conn.close()


def test_main_requires_confirmation_and_writes_private_file(client, env, capsys):
    m = _mod()
    assert m.main(["--stage", "isl1_boss"]) == 2
    assert m.main(["--stage", "isl1_boss", "--prefix", "player_", "--yes-this-is-an-operator-db"]) == 2
    out = env / "cp.txt"
    assert m.main(["--stage", "isl2_start", "--out", str(out), "--yes-this-is-an-operator-db"]) == 0
    printed = capsys.readouterr().out
    line = out.read_text(encoding="utf-8").strip().split("\t")
    assert line[0] == "isl2_start" and line[1].startswith("checkpoint_")
    assert line[2] not in printed  # mật khẩu không in ra màn hình
    assert stat.S_IMODE(os.stat(out).st_mode) == 0o600
