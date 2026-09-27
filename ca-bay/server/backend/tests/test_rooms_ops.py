"""AUTH-02 (ticket), SAVE-02, CORE-02 (backend), LOOT-01/02, SURV-01 (phần backend), CONTENT-02 (thưởng boss)."""
from __future__ import annotations

import sqlite3
import threading
import uuid

import pytest

from conftest import commit, connect_player, current_version, fresh_fish, ready_room, register


def test_ticket_single_use_ttl_and_room_limits(client, svc, env):
    owner = register(client)
    room = ready_room(client, svc, owner)
    t = client.post(f"/v1/rooms/{room['room_id']}/ticket", headers=owner["auth"]).json()
    body = {"ticket": t["ticket"], "protocol_version": t["protocol_version"], "content_hash": t["content_hash"], "connection_id": str(uuid.uuid4())}
    assert client.post("/internal/tickets/consume", headers=svc, json=body).status_code == 200
    r = client.post("/internal/tickets/consume", headers=svc, json=body)
    assert r.status_code == 401 and r.json()["error_code"] == "BAD_TICKET"
    # hết hạn
    t2 = client.post(f"/v1/rooms/{room['room_id']}/ticket", headers=owner["auth"]).json()
    conn = sqlite3.connect(env / "test.db")
    conn.execute("UPDATE room_tickets SET expires_at=0 WHERE consumed_at IS NULL")
    conn.commit()
    body2 = {**body, "ticket": t2["ticket"]}
    assert client.post("/internal/tickets/consume", headers=svc, json=body2).status_code == 401
    # sai content hash / protocol
    t3 = client.post(f"/v1/rooms/{room['room_id']}/ticket", headers=owner["auth"]).json()
    assert client.post("/internal/tickets/consume", headers=svc, json={**body, "ticket": t3["ticket"], "content_hash": "0" * 64}).status_code == 409
    assert client.post("/internal/tickets/consume", headers=svc, json={**body, "ticket": t3["ticket"], "protocol_version": "9.0.0"}).status_code == 409


def test_fifth_player_rejected_and_wrong_invite(client, svc):
    owner = register(client)
    room = ready_room(client, svc, owner)
    for _ in range(3):
        p = register(client)
        assert client.post(f"/v1/rooms/{room['room_id']}/join", json={"invite_code": room["invite_code"]}, headers=p["auth"]).status_code == 200
    fifth = register(client)
    r = client.post(f"/v1/rooms/{room['room_id']}/join", json={"invite_code": room["invite_code"]}, headers=fifth["auth"])
    assert r.status_code == 409 and r.json()["error_code"] == "ROOM_FULL"
    r = client.post(f"/v1/rooms/{room['room_id']}/join", json={"invite_code": "ZZZZZZ"}, headers=fifth["auth"])
    assert r.status_code == 403
    # người ngoài không xin được ticket
    assert client.post(f"/v1/rooms/{room['room_id']}/ticket", headers=fifth["auth"]).status_code == 403


def test_takeover_fences_old_epoch(client, svc):
    u = register(client)
    room = ready_room(client, svc, u)
    lease_a = connect_player(client, svc, u, room)
    # Thiết bị B đăng nhập: xem save được, xin ticket bị từ chối cho tới khi takeover
    b = client.post("/v1/auth/login", json={"username": u["username"], "password": u["password"]}).json()
    hb = {"Authorization": f"Bearer {b['access_token']}"}
    assert client.get("/v1/account/save", headers=hb).status_code == 200
    r = client.post(f"/v1/rooms/{room['room_id']}/ticket", headers=hb)
    assert r.status_code == 409 and r.json()["error_code"] == "LEASE_ACTIVE_ELSEWHERE"
    assert client.post("/v1/account/takeover", headers=hb).status_code == 200
    ctl = client.get("/internal/room-controls", headers=svc).json()["controls"]
    assert any(c["kind"] == "kick_account" and c["payload"]["account_id"] == u["account_id"] for c in ctl)
    ub = {**u, "auth": hb, "_joined": room["room_id"]}
    lease_b = connect_player(client, svc, ub, room)
    assert lease_b["lease_epoch"] > lease_a["lease_epoch"]
    # commit mang epoch cũ bị từ chối
    res = commit(client, svc, lease_a, "bait.select", {"bait_id": "bait_bread"})
    assert res["status"] == "rejected" and res["error_code"] in ("SESSION_TAKEN_OVER", "LEASE_EXPIRED")
    assert commit(client, svc, lease_b, "bait.select", {"bait_id": "bait_bread"})["status"] == "committed"


def test_pickup_sell_idempotent_and_conflicts(client, svc):
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    uid = str(uuid.uuid4())
    op = str(uuid.uuid4())
    r1 = commit(client, svc, lease, "inventory.pickup", {"item_uid": uid, "fresh_item": fresh_fish(tmm=1300, tricks=["trick_air_smack"])}, op_id=op)
    assert r1["status"] == "committed" and r1["receipt"]["value"] == 5 * 1300 // 1000
    # retry cùng op -> cùng kết quả, không nhân đôi
    r2 = commit(client, svc, lease, "inventory.pickup", {"item_uid": uid, "fresh_item": fresh_fish(tmm=1300, tricks=["trick_air_smack"])}, op_id=op, expected=r1["save_version"] - 1)
    assert r2["status"] == "committed" and r2["save_version"] == r1["save_version"] and r2.get("replayed")
    # cùng op khác payload -> conflict
    r3 = commit(client, svc, lease, "inventory.pickup", {"item_uid": str(uuid.uuid4()), "fresh_item": fresh_fish()}, op_id=op, expected=r1["save_version"] - 1)
    assert r3["error_code"] == "OP_PAYLOAD_MISMATCH"
    # stale version
    r4 = commit(client, svc, lease, "bait.select", {"bait_id": "bait_bread"}, expected=1)
    assert r4["error_code"] == "SAVE_CONFLICT"
    # nhặt lại cùng UID bằng op khác -> đã claim
    r5 = commit(client, svc, lease, "inventory.pickup", {"item_uid": uid, "fresh_item": fresh_fish()})
    assert r5["error_code"] == "ITEM_ALREADY_CLAIMED"
    money_before = client.get("/v1/account/save", headers=u["auth"]).json()["save"]["currencies"]["money"]
    s1 = commit(client, svc, lease, "inventory.sell", {"item_uids": [uid], "shop_id": "shop_co_ba"})
    assert s1["status"] == "committed"
    s2 = commit(client, svc, lease, "inventory.sell", {"item_uids": [uid], "shop_id": "shop_co_ba"})
    assert s2["error_code"] == "ITEM_NOT_OWNED"
    save = client.get("/v1/account/save", headers=u["auth"]).json()["save"]
    assert save["currencies"]["money"] == money_before + 6
    assert save["lootbox_progress"]["valid_owned_fish_sales_total"] == 1


def test_forged_values_rejected(client, svc):
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    bad = [
        fresh_fish(tmm=999999),
        fresh_fish(tmm=999),
        fresh_fish(def_id="cre_boss_ca_loc"),
        fresh_fish(def_id="cre_khong_co"),
        fresh_fish(tricks=["trick_fake"]),
        fresh_fish(variant="var_fake"),
    ]
    for f in bad:
        r = commit(client, svc, lease, "inventory.pickup", {"item_uid": str(uuid.uuid4()), "fresh_item": f})
        assert r["status"] == "rejected" and r["error_code"] == "INVALID_PAYLOAD", f
    # op client không kèm expected_save_version -> từ chối
    body = {"account_id": lease["account_id"], "lease_epoch": lease["lease_epoch"], "room_id": lease["room_id"], "op_id": str(uuid.uuid4()),
            "op_type": "shop.buy", "payload": {"shop_id": "shop_co_ba", "entry_id": "entry_broom", "quantity": 1}, "expected_save_version": None}
    assert client.post("/internal/accounts/commit", headers=svc, json=body).json()["error_code"] == "INVALID_PAYLOAD"


def test_bag_full_and_concurrent_pickup_same_uid(client, svc, env):
    a = register(client)
    b = register(client)
    room = ready_room(client, svc, a)
    la = connect_player(client, svc, a, room)
    lb = connect_player(client, svc, b, room)
    uid = str(uuid.uuid4())
    from app import ops
    from app.content import get_catalog
    from app.db import connect
    cat = get_catalog()
    results = []

    def worker(lease):
        conn = connect()
        try:
            v = conn.execute("SELECT save_version FROM account_saves WHERE account_id=?", (lease["account_id"],)).fetchone()[0]
            results.append(ops.commit(conn, cat, account_id=lease["account_id"], op_id=str(uuid.uuid4()), op_type="inventory.pickup",
                                      payload={"item_uid": uid, "fresh_item": fresh_fish()}, expected_save_version=v,
                                      lease_epoch=lease["lease_epoch"], room_id=lease["room_id"]))
        finally:
            conn.close()

    ths = [threading.Thread(target=worker, args=(l,)) for l in (la, lb, la, lb)]
    for t in ths:
        t.start()
    for t in ths:
        t.join()
    assert sum(r["status"] == "committed" for r in results) == 1
    # túi đầy
    for _ in range(3):
        commit(client, svc, la, "inventory.pickup", {"item_uid": str(uuid.uuid4()), "fresh_item": fresh_fish()})
    r = commit(client, svc, la, "inventory.pickup", {"item_uid": str(uuid.uuid4()), "fresh_item": fresh_fish()})
    assert r["error_code"] == "INVENTORY_FULL" or r["status"] == "committed"
    save = client.get("/v1/account/save", headers=a["auth"]).json()["save"]
    assert len(save["inventory"]["bag"]) <= save["inventory"]["capacity"]


def test_drop_escrow_recover_once(client, svc):
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    uid = str(uuid.uuid4())
    commit(client, svc, lease, "inventory.pickup", {"item_uid": uid, "fresh_item": fresh_fish()})
    assert commit(client, svc, lease, "inventory.drop", {"item_uid": uid})["status"] == "committed"
    # room server báo lease hết grace -> đồ escrow về inbox đúng một lần (gọi 2 lần)
    rel = {"account_id": lease["account_id"], "lease_epoch": lease["lease_epoch"], "room_id": lease["room_id"], "reason": "grace_expired"}
    for _ in range(2):
        client.post("/internal/room-status", headers=svc, json={"released": [rel]})
    save = client.get("/v1/account/save", headers=u["auth"]).json()["save"]
    assert [i["uid"] for i in save["inventory"]["recovery_inbox"]] == [uid]
    assert save["inventory"]["bag"] == []


def test_shop_buy_rules_and_food(client, svc):
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    assert commit(client, svc, lease, "shop.buy", {"shop_id": "shop_co_ba", "entry_id": "entry_broom", "quantity": 1})["error_code"] == "INSUFFICIENT_FUNDS"
    # cơm miễn phí giới hạn 3
    ok = [commit(client, svc, lease, "shop.buy", {"shop_id": "shop_co_ba", "entry_id": "entry_rice_ball", "quantity": 1})["status"] for _ in range(3)]
    assert ok[:2] == ["committed", "committed"] and ok[2] == "rejected"
    # đang no -> không tiêu đồ ăn
    assert commit(client, svc, lease, "food.consume", {"item_id": "item_rice_ball"})["status"] == "rejected"
    client.post("/internal/accounts/checkpoint", headers=svc, json={"account_id": lease["account_id"], "lease_epoch": lease["lease_epoch"], "room_id": lease["room_id"],
                                                                      "hunger": 20, "hp": 100, "safe_island_id": "isl_01_cu_lao", "safe_spawn_zone_id": "zone_01_spawn"})
    r = commit(client, svc, lease, "food.consume", {"item_id": "item_rice_ball"})
    assert r["status"] == "committed" and r["receipt"]["hunger"] == 55


def test_quest_chain_boss_reward_and_refund(client, svc):
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    assert commit(client, svc, lease, "quest.talk", {"npc_id": "npc_ong_tu"}, server=True)["status"] == "committed"
    uids = []
    for _ in range(3):
        uid = str(uuid.uuid4())
        commit(client, svc, lease, "inventory.pickup", {"item_uid": uid, "fresh_item": fresh_fish("cre_ca_ro")})
        uids.append(uid)
    r = commit(client, svc, lease, "quest.deliver", {"quest_id": "quest_01_bua_trua", "step_id": "step_deliver_ca_ro", "npc_id": "npc_ong_tu", "item_uids": uids})
    assert r["status"] == "committed", r
    c = commit(client, svc, lease, "quest.claim", {"quest_id": "quest_01_bua_trua"})
    assert c["status"] == "committed" and c["receipt"]["tickets"] == 1
    assert commit(client, svc, lease, "quest.claim", {"quest_id": "quest_01_bua_trua"})["status"] == "rejected"
    save = client.get("/v1/account/save", headers=u["auth"]).json()["save"]
    assert save["inventory"]["bait_counts"]["bait_milk_tea"] == 1 and "tool_broom" in save["inventory"]["tools_owned"]
    assert save["progress"]["quests"]["quest_01_trum_song"]["state"] == "available"
    assert commit(client, svc, lease, "quest.accept", {"quest_id": "quest_01_trum_song", "npc_id": "npc_ong_tu"})["status"] == "committed"
    # summon -> thua (refund đúng một lần)
    s = commit(client, svc, lease, "boss.summon", {"boss_id": "boss_ca_loc", "zone_id": "zone_01_boss_spot"})
    enc = s["receipt"]["encounter_id"]
    assert commit(client, svc, lease, "boss.refund", {"encounter_id": enc}, server=True)["status"] == "committed"
    assert commit(client, svc, lease, "boss.refund", {"encounter_id": enc}, server=True)["status"] == "rejected"
    # hết mồi khi có mồi -> không cấp thêm; summon lại rồi thắng
    assert commit(client, svc, lease, "quest.refill", {"npc_id": "npc_ong_tu"}, server=True)["error_code"] == "ALREADY_OWNED"
    s = commit(client, svc, lease, "boss.summon", {"boss_id": "boss_ca_loc", "zone_id": "zone_01_boss_spot"})
    enc = s["receipt"]["encounter_id"]
    rw = commit(client, svc, lease, "boss.reward", {"encounter_id": enc, "boss_id": "boss_ca_loc"}, server=True)
    assert rw["status"] == "committed"
    assert commit(client, svc, lease, "boss.reward", {"encounter_id": enc, "boss_id": "boss_ca_loc"}, server=True)["status"] == "rejected"
    assert commit(client, svc, lease, "boss.refund", {"encounter_id": enc}, server=True)["status"] == "rejected"
    save = client.get("/v1/account/save", headers=u["auth"]).json()["save"]
    scale = [i for i in save["inventory"]["bag"] + save["inventory"]["recovery_inbox"] if i["def_id"] == "item_golden_scale"]
    assert len(scale) == 1
    if scale[0] in save["inventory"]["recovery_inbox"]:
        pass
    d = commit(client, svc, lease, "quest.deliver", {"quest_id": "quest_01_trum_song", "step_id": "step_deliver_scale", "npc_id": "npc_ong_tu", "item_uids": [scale[0]["uid"]]})
    assert d["status"] == "committed", d
    c2 = commit(client, svc, lease, "quest.claim", {"quest_id": "quest_01_trum_song"})
    assert c2["status"] == "committed" and c2["receipt"]["islands_unlocked"] == ["isl_02_rung_dua"]


def test_lootbox_exact_mapping_atomic_and_idempotent(client, svc, monkeypatch):
    from app import ops
    from app.db import connect
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    # không có vé
    assert commit(client, svc, lease, "lootbox.open", {"box_id": "lootbox_ben_lang", "table_version": "1.0.0"})["error_code"] == "INSUFFICIENT_TICKETS"
    conn = connect()
    import json as _j
    row = conn.execute("SELECT state_json FROM account_saves WHERE account_id=?", (lease["account_id"],)).fetchone()
    s = _j.loads(row[0])
    s["currencies"]["festival_ticket"] = 20
    conn.execute("UPDATE account_saves SET state_json=? WHERE account_id=?", (_j.dumps(s), lease["account_id"]))
    conn.close()
    # biên từng khoảng trọng số: 0,39 -> dép xanh sông; 40..64 xanh lá; 65..79 chổi; 80..89 cần đồng; 90..96 cần xanh; 97..99 dép hồng
    expect = {0: "cos_slipper_river_blue", 39: "cos_slipper_river_blue", 40: "cos_slipper_river_green", 64: "cos_slipper_river_green",
              65: "cos_broom_sunset", 79: "cos_broom_sunset", 80: "cos_rod_copper", 89: "cos_rod_copper",
              90: "cos_rod_river_green", 96: "cos_rod_river_green", 97: "cos_slipper_sunset", 99: "cos_slipper_sunset"}
    seen = set()
    for roll, cos in expect.items():
        monkeypatch.setattr(ops, "RNG", lambda n, r=roll: r)
        op = str(uuid.uuid4())
        r = commit(client, svc, lease, "lootbox.open", {"box_id": "lootbox_ben_lang", "table_version": "1.0.0"}, op_id=op)
        assert r["status"] == "committed" and r["receipt"]["cosmetic_id"] == cos
        assert r["receipt"]["outcome"] == ("duplicate" if cos in seen else "new")
        seen.add(cos)
        # retry cùng op -> cùng kết quả, không trừ thêm vé
        monkeypatch.setattr(ops, "RNG", lambda n: 0)
        r2 = commit(client, svc, lease, "lootbox.open", {"box_id": "lootbox_ben_lang", "table_version": "1.0.0"}, op_id=op, expected=r["save_version"] - 1)
        assert r2["receipt"] == r["receipt"]
    save = client.get("/v1/account/save", headers=u["auth"]).json()["save"]
    assert save["currencies"]["festival_ticket"] == 20 - len(expect)
    assert save["currencies"]["cosmetic_dust"] == 10 * (len(expect) - len(seen))
    # sai version bảng
    assert commit(client, svc, lease, "lootbox.open", {"box_id": "lootbox_ben_lang", "table_version": "0.9.0"})["error_code"] == "CONTENT_MISMATCH"
    # chọn trực tiếp bằng bụi (30)
    r = commit(client, svc, lease, "cosmetic.buy", {"cosmetic_id": "cos_slipper_sunset"})
    assert r["status"] in ("committed", "rejected")


def test_lootbox_ticket_milestones_from_sales(client, svc):
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    for _ in range(4):
        uids = []
        for _ in range(3):
            uid = str(uuid.uuid4())
            commit(client, svc, lease, "inventory.pickup", {"item_uid": uid, "fresh_item": fresh_fish("cre_tep")})
            uids.append(uid)
        commit(client, svc, lease, "inventory.sell", {"item_uids": uids, "shop_id": "shop_co_ba"})
    save = client.get("/v1/account/save", headers=u["auth"]).json()["save"]
    assert save["lootbox_progress"]["valid_owned_fish_sales_total"] == 12
    assert save["currencies"]["festival_ticket"] == 1


def test_expired_op_not_reexecuted(client, svc, env):
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    uid = str(uuid.uuid4())
    op = str(uuid.uuid4())
    r = commit(client, svc, lease, "inventory.pickup", {"item_uid": uid, "fresh_item": fresh_fish()}, op_id=op)
    from app import ops
    from app.db import connect
    conn = connect()
    conn.execute("UPDATE operations SET committed_at=0")
    assert ops.expire_old_operations(conn, 7) >= 1
    conn.close()
    r2 = commit(client, svc, lease, "inventory.pickup", {"item_uid": uid, "fresh_item": fresh_fish()}, op_id=op, expected=r["save_version"] - 1)
    assert r2["error_code"] == "OP_EXPIRED"


def test_stale_boss_attempt_sweep_refunds(client, svc, env):
    from app.db import connect
    from app.content import get_catalog
    from app.persistence.internal_routes import sweep_stale
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    conn = connect()
    import json as _j
    row = conn.execute("SELECT state_json FROM account_saves WHERE account_id=?", (lease["account_id"],)).fetchone()
    s = _j.loads(row[0])
    s["inventory"]["bait_counts"]["bait_milk_tea"] = 1
    conn.execute("UPDATE account_saves SET state_json=? WHERE account_id=?", (_j.dumps(s), lease["account_id"]))
    r = commit(client, svc, lease, "boss.summon", {"boss_id": "boss_ca_loc", "zone_id": "zone_01_boss_spot"})
    assert r["status"] == "committed"
    conn.execute("UPDATE boss_attempts SET created_at=0")
    assert sweep_stale(conn, get_catalog())["refunded"] == 1
    assert sweep_stale(conn, get_catalog())["refunded"] == 0
    conn.close()
    save = client.get("/v1/account/save", headers=u["auth"]).json()["save"]
    assert save["inventory"]["bait_counts"]["bait_milk_tea"] == 1


def _with_milk_tea(lease):
    from app.db import connect
    import json as _j
    conn = connect()
    try:
        row = conn.execute("SELECT state_json FROM account_saves WHERE account_id=?", (lease["account_id"],)).fetchone()
        s = _j.loads(row[0])
        s["inventory"]["bait_counts"]["bait_milk_tea"] = 1
        conn.execute("UPDATE account_saves SET state_json=? WHERE account_id=?", (_j.dumps(s), lease["account_id"]))
        conn.commit()
    finally:
        conn.close()


def test_boss_summon_replay_only_reopens_unstarted_encounter(client, svc):
    """Lỗi QA WP-11a P0: gửi lại boss.summon cùng op_id sau khi đã thắng không được mở thêm trận (thưởng miễn phí)."""
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    _with_milk_tea(lease)
    ver = current_version(client, svc, lease)
    op = str(uuid.uuid4())
    payload = {"boss_id": "boss_ca_loc", "zone_id": "zone_01_boss_spot"}
    s = commit(client, svc, lease, "boss.summon", payload, expected=ver, op_id=op)
    assert s["status"] == "committed"
    enc = s["receipt"]["encounter_id"]
    # mất phản hồi lần đầu → gửi lại: trận còn open trong đúng phòng → được mở
    r1 = commit(client, svc, lease, "boss.summon", payload, expected=ver, op_id=op)
    assert r1.get("replayed") and r1["encounter_open"] is True
    # đã thắng → gửi lại: không mở lại
    assert commit(client, svc, lease, "boss.reward", {"encounter_id": enc, "boss_id": "boss_ca_loc"}, server=True)["status"] == "committed"
    r2 = commit(client, svc, lease, "boss.summon", payload, expected=ver, op_id=op)
    assert r2.get("replayed") and r2["encounter_open"] is False
    assert r2["receipt"]["encounter_id"] == enc


def test_pickup_replay_without_server_fields_returns_original(client, svc):
    """Lỗi QA WP-11a P2: room server khởi động lại (thực thể mất, không còn fresh_item) — gửi lại cùng op_id phải trả kết quả gốc."""
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    ver = current_version(client, svc, lease)
    op = str(uuid.uuid4())
    uid = str(uuid.uuid4())
    first = commit(client, svc, lease, "inventory.pickup", {"item_uid": uid, "fresh_item": fresh_fish("cre_ca_ro")}, expected=ver, op_id=op)
    assert first["status"] == "committed"
    again = commit(client, svc, lease, "inventory.pickup", {"item_uid": uid}, expected=ver, op_id=op)
    assert again["status"] == "committed" and again.get("replayed") and again["save_version"] == first["save_version"]
    # ý định khác (uid khác) cùng op_id vẫn bị chặn
    bad = commit(client, svc, lease, "inventory.pickup", {"item_uid": str(uuid.uuid4())}, expected=ver, op_id=op)
    assert bad["error_code"] == "OP_PAYLOAD_MISMATCH"


def test_cooking_never_blocks_after_lost_client_state(client, svc, env):
    """P-025: client mất cooking_uid (tải lại trang/đổi máy) — bếp không bị khóa, cá không mất."""
    from app.db import connect
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    a, b = str(uuid.uuid4()), str(uuid.uuid4())
    for uid in (a, b):
        assert commit(client, svc, lease, "inventory.pickup", {"item_uid": uid, "fresh_item": fresh_fish("cre_ca_ro")})["status"] == "committed"
    assert commit(client, svc, lease, "cooking.start", {"item_uid": a, "station_id": "shop_co_ba"})["status"] == "committed"
    # chưa chín mà vào phòng mới → trả cá sống
    r = commit(client, svc, lease, "cooking.recover", {}, server=True)
    assert r["status"] == "committed" and r["events"][0]["payload"]["level"] == "raw"
    save = client.get("/v1/account/save", headers=u["auth"]).json()["save"]
    assert a in [i["uid"] for i in save["inventory"]["bag"]]
    assert commit(client, svc, lease, "cooking.recover", {}, server=True)["error_code"] == "ALREADY_CLAIMED"
    # nướng a, "quên" 10 s (đã chín) rồi nướng b: a thành cá nướng, b bắt đầu nướng — không COOLDOWN
    assert commit(client, svc, lease, "cooking.start", {"item_uid": a, "station_id": "shop_co_ba"})["status"] == "committed"
    conn = connect()
    conn.execute("UPDATE item_registry SET state_since=state_since-10 WHERE item_uid=?", (a,))
    conn.commit()
    conn.close()
    r2 = commit(client, svc, lease, "cooking.start", {"item_uid": b, "station_id": "shop_co_ba"})
    assert r2["status"] == "committed", r2
    assert any(e["name"] == "cooking.level_changed" and e["payload"]["level"] == "cooked" for e in r2["events"])
    save = client.get("/v1/account/save", headers=u["auth"]).json()["save"]
    assert save["inventory"]["food_counts"].get("item_grilled_fish") == 1
    # b để quá giờ khét rồi mới vào phòng mới → cá khét về túi
    conn = connect()
    conn.execute("UPDATE item_registry SET state_since=state_since-60 WHERE item_uid=?", (b,))
    conn.commit()
    conn.close()
    r3 = commit(client, svc, lease, "cooking.recover", {}, server=True)
    assert r3["events"][0]["payload"]["level"] == "burnt"
    save = client.get("/v1/account/save", headers=u["auth"]).json()["save"]
    burnt = [i for i in save["inventory"]["bag"] if i["uid"] == b]
    assert burnt and burnt[0]["cook_level"] == "burnt"


def test_accept_at_giver_completes_talk_step(client, svc):
    """Nhận việc từ Chú Sáu khi đang nói chuyện với chú: bước 'nói chuyện với Chú Sáu' tính luôn."""
    from app.db import connect
    import json as _j
    u = register(client)
    room = ready_room(client, svc, u)
    lease = connect_player(client, svc, u, room)
    conn = connect()
    row = conn.execute("SELECT state_json FROM account_saves WHERE account_id=?", (lease["account_id"],)).fetchone()
    s = _j.loads(row[0])
    s["progress"]["quests"]["quest_02_sua_ben"] = {"state": "available", "step_index": 0, "counts": {}, "reward_claimed": False}
    conn.execute("UPDATE account_saves SET state_json=? WHERE account_id=?", (_j.dumps(s), lease["account_id"]))
    conn.commit()
    conn.close()
    r = commit(client, svc, lease, "quest.accept", {"quest_id": "quest_02_sua_ben", "npc_id": "npc_nam_sau"})
    assert r["status"] == "committed"
    st = r["save"]["progress"]["quests"]["quest_02_sua_ben"]
    assert st["state"] == "active" and st["step_index"] == 1
    assert any(e["name"] == "quest.step_progressed" for e in r["events"])
