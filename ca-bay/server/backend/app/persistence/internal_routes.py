"""API nội bộ cho room server Godot (chỉ bind loopback/private, cần X-Service-Key)."""
from __future__ import annotations

import json
import uuid
from typing import Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from ..content import Catalog
from ..db import PersistenceBusy, immediate, now_s
from ..deps import api_error, get_cat, get_db, require_service
from .. import ops as ops_mod
from .. import security

router = APIRouter(dependencies=[Depends(require_service)])


class ConsumeBody(BaseModel):
    ticket: str
    protocol_version: str
    content_hash: str
    connection_id: str


class CommitBody(BaseModel):
    account_id: str
    lease_epoch: int | None = None
    room_id: str | None = None
    op_id: str
    op_type: str
    expected_save_version: int | None = None
    payload: dict[str, Any]


class CheckpointBody(BaseModel):
    account_id: str
    lease_epoch: int
    room_id: str
    hunger: float
    hp: float
    safe_island_id: str
    safe_spawn_zone_id: str
    active_playtime_delta_s: float = 0


class RoomStatusEntry(BaseModel):
    room_id: str
    status: str
    island_id: str
    owner_account_id: str | None = None
    members: list[str] = []


class LeaseRelease(BaseModel):
    account_id: str
    lease_epoch: int
    room_id: str
    reason: str


class RoomStatusBody(BaseModel):
    acks: list[int] = []
    rooms: list[RoomStatusEntry] = []
    released: list[LeaseRelease] = []


@router.post("/internal/tickets/consume")
def consume_ticket(body: ConsumeBody, conn=Depends(get_db), cat: Catalog = Depends(get_cat)):
    if body.protocol_version != cat.protocol_version:
        raise api_error(409, "PROTOCOL_MISMATCH")
    if body.content_hash != cat.content_hash:
        raise api_error(409, "CONTENT_MISMATCH")
    try:
        uuid.UUID(body.connection_id)
    except ValueError:
        raise api_error(400, "INVALID_PAYLOAD")
    now = now_s()
    with immediate(conn):
        t = conn.execute("SELECT * FROM room_tickets WHERE ticket_hash=?", (security.token_hash(body.ticket),)).fetchone()
        if t is None or t["consumed_at"] is not None or t["expires_at"] <= now or t["protocol_version"] != body.protocol_version:
            raise api_error(401, "BAD_TICKET")
        conn.execute("UPDATE room_tickets SET consumed_at=? WHERE ticket_hash=?", (now, t["ticket_hash"]))
        sess = conn.execute("SELECT revoked_at, expires_at FROM sessions WHERE session_id=?", (t["session_id"],)).fetchone()
        if sess is None or sess["revoked_at"] is not None or sess["expires_at"] <= now:
            raise api_error(401, "BAD_TICKET")
        room = conn.execute("SELECT * FROM rooms WHERE room_id=?", (t["room_id"],)).fetchone()
        if room is None or room["status"] != "ready":
            raise api_error(404, "ROOM_NOT_FOUND")
        lease = conn.execute("SELECT * FROM gameplay_leases WHERE account_id=?", (t["account_id"],)).fetchone()
        if lease and lease["active"] and lease["session_id"] != t["session_id"]:
            raise api_error(409, "LEASE_ACTIVE_ELSEWHERE")
        epoch = (int(lease["epoch"]) if lease else 0) + 1
        conn.execute("""INSERT INTO gameplay_leases(account_id, room_id, session_id, epoch, connection_id, active, updated_at) VALUES (?,?,?,?,?,1,?)
                        ON CONFLICT(account_id) DO UPDATE SET room_id=excluded.room_id, session_id=excluded.session_id, epoch=excluded.epoch,
                        connection_id=excluded.connection_id, active=1, updated_at=excluded.updated_at""",
                     (t["account_id"], t["room_id"], t["session_id"], epoch, body.connection_id, now))
        acc = conn.execute("SELECT display_name FROM accounts WHERE account_id=?", (t["account_id"],)).fetchone()
        sv = conn.execute("SELECT state_json FROM account_saves WHERE account_id=?", (t["account_id"],)).fetchone()
    return {
        "account_id": t["account_id"],
        "display_name": acc["display_name"],
        "room_id": t["room_id"],
        "island_id": room["island_id"],
        "owner_account_id": room["owner_account_id"],
        "lease_epoch": epoch,
        "save": json.loads(sv["state_json"]),
    }


@router.post("/internal/accounts/commit")
def commit_op(body: CommitBody, conn=Depends(get_db), cat: Catalog = Depends(get_cat)):
    try:
        return ops_mod.commit(conn, cat, account_id=body.account_id, op_id=body.op_id, op_type=body.op_type,
                              payload=body.payload, expected_save_version=body.expected_save_version,
                              lease_epoch=body.lease_epoch, room_id=body.room_id)
    except PersistenceBusy:
        raise api_error(503, "PERSISTENCE_UNAVAILABLE")


@router.post("/internal/accounts/checkpoint")
def checkpoint(body: CheckpointBody, conn=Depends(get_db), cat: Catalog = Depends(get_cat)):
    """Checkpoint độ no/HP/điểm hồi sinh an toàn. Không tăng save_version (P-013): không phải giao dịch kinh tế."""
    if body.safe_island_id not in cat.islands or body.safe_spawn_zone_id not in {z["zone_id"] for z in cat.islands[body.safe_island_id]["zones"]}:
        raise api_error(400, "INVALID_PAYLOAD")
    hunger = min(float(cat.hunger["clamp_max"]), max(float(cat.hunger["clamp_min"]), float(body.hunger)))
    hp = min(float(cat.balance["player"]["max_hp"]), max(0.0, float(body.hp)))
    delta = min(max(0.0, float(body.active_playtime_delta_s)), 3600.0)
    with immediate(conn):
        lease = conn.execute("SELECT epoch, active, room_id FROM gameplay_leases WHERE account_id=?", (body.account_id,)).fetchone()
        if lease is None or not lease["active"] or int(lease["epoch"]) != body.lease_epoch or lease["room_id"] != body.room_id:
            raise api_error(409, "LEASE_EXPIRED")
        row = conn.execute("SELECT state_json FROM account_saves WHERE account_id=?", (body.account_id,)).fetchone()
        save = json.loads(row["state_json"])
        if body.safe_island_id not in save["progress"]["islands_unlocked"]:
            raise api_error(403, "UNLOCK_REQUIRED")
        save["player"].update({"hunger": hunger, "hp": hp, "safe_island_id": body.safe_island_id, "safe_spawn_zone_id": body.safe_spawn_zone_id})
        save["active_playtime_s"] = round(float(save.get("active_playtime_s", 0)) + delta, 3)
        conn.execute("UPDATE account_saves SET state_json=? WHERE account_id=?", (json.dumps(save, ensure_ascii=False, separators=(",", ":")), body.account_id))
    return {"ok": True, "hunger": hunger, "hp": hp}


@router.get("/internal/room-controls")
def room_controls(after: int = 0, conn=Depends(get_db)):
    rows = conn.execute("SELECT control_id, room_id, kind, payload_json FROM room_controls WHERE acked_at IS NULL AND control_id>? ORDER BY control_id LIMIT 100", (after,)).fetchall()
    return {"controls": [{"control_id": r["control_id"], "room_id": r["room_id"], "kind": r["kind"], "payload": json.loads(r["payload_json"])} for r in rows]}


@router.post("/internal/room-status")
def room_status(body: RoomStatusBody, conn=Depends(get_db), cat: Catalog = Depends(get_cat)):
    now = now_s()
    results = []
    with immediate(conn):
        for cid in body.acks:
            conn.execute("UPDATE room_controls SET acked_at=? WHERE control_id=? AND acked_at IS NULL", (now, cid))
        for r in body.rooms:
            if r.status not in ("ready", "closed") or r.island_id not in cat.islands:
                continue
            conn.execute("UPDATE rooms SET status=?, island_id=?, owner_account_id=COALESCE(?, owner_account_id), updated_at=? WHERE room_id=?",
                         (r.status, r.island_id, r.owner_account_id, now, r.room_id))
            conn.execute("UPDATE room_members SET connected=0 WHERE room_id=?", (r.room_id,))
            for aid in r.members:
                conn.execute("UPDATE room_members SET connected=1 WHERE room_id=? AND account_id=?", (r.room_id, aid))
    # Giải phóng lease hết cửa sổ nối lại; trả đồ escrow về inbox (mỗi account một op riêng, idempotent theo op_id).
    for rel in body.released:
        with immediate(conn):
            lease = conn.execute("SELECT epoch, active FROM gameplay_leases WHERE account_id=?", (rel.account_id,)).fetchone()
            if lease is not None and lease["active"] and int(lease["epoch"]) == rel.lease_epoch:
                conn.execute("UPDATE gameplay_leases SET active=0, updated_at=? WHERE account_id=?", (now, rel.account_id))
        op_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"release:{rel.account_id}:{rel.room_id}:{rel.lease_epoch}"))
        res = ops_mod.commit(conn, cat, account_id=rel.account_id, op_id=op_id, op_type="inventory.recover_escrow",
                             payload={"room_id": rel.room_id}, expected_save_version=None, lease_epoch=None, room_id=None)
        results.append({"account_id": rel.account_id, "status": res["status"]})
    return {"ok": True, "released": results}


def sweep_stale(conn, cat: Catalog, max_age_s: int = 900) -> dict:
    """Chống kẹt tiến trình khi room server crash: hoàn mồi boss của trận mở quá lâu, trả escrow của lease đã chết."""
    now = now_s()
    refunded = 0
    for att in conn.execute("SELECT encounter_id, account_id FROM boss_attempts WHERE status='open' AND created_at<?", (now - max_age_s,)).fetchall():
        op_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"sweep-refund:{att['encounter_id']}"))
        res = ops_mod.commit(conn, cat, account_id=att["account_id"], op_id=op_id, op_type="boss.refund",
                             payload={"encounter_id": att["encounter_id"]}, expected_save_version=None, lease_epoch=None, room_id=None)
        refunded += res["status"] == "committed"
    returned = 0
    for row in conn.execute("""SELECT DISTINCT i.owner_account_id AS aid, i.room_id FROM item_registry i
                               LEFT JOIN gameplay_leases l ON l.account_id=i.owner_account_id
                               WHERE i.state='escrow' AND (l.active IS NULL OR l.active=0 OR l.room_id IS NOT i.room_id)""").fetchall():
        op_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"sweep-escrow:{row['aid']}:{row['room_id']}:{now // 60}"))
        res = ops_mod.commit(conn, cat, account_id=row["aid"], op_id=op_id, op_type="inventory.recover_escrow",
                             payload={"room_id": row["room_id"]}, expected_save_version=None, lease_epoch=None, room_id=None)
        returned += res["status"] == "committed"
    return {"refunded": refunded, "escrow_returned": returned}
