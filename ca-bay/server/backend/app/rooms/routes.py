"""Phòng riêng có mã mời (tối đa 4), ticket một lần 30 giây, chuyển phiên chơi, xem save."""
from __future__ import annotations

import json
import secrets
import sqlite3
import uuid

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from ..auth.routes import _revoke_lease
from ..content import Catalog
from ..db import immediate, now_s
from ..deps import AuthSession, api_error, get_cat, get_db, require_access
from .. import security

router = APIRouter()

INVITE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
SEAT_RESERVATION_S = 60


class CreateRoomBody(BaseModel):
    island_id: str | None = None


class LookupBody(BaseModel):
    invite_code: str


class JoinBody(BaseModel):
    invite_code: str


def _seats_taken(conn: sqlite3.Connection, room_id: str) -> int:
    now = now_s()
    return conn.execute("SELECT COUNT(*) FROM room_members WHERE room_id=? AND (connected=1 OR reserved_at>?)", (room_id, now - SEAT_RESERVATION_S)).fetchone()[0]


def _room_summary(conn: sqlite3.Connection, r: sqlite3.Row, account_id: str) -> dict:
    return {
        "room_id": r["room_id"],
        "invite_code": r["invite_code"],
        "island_id": r["island_id"],
        "status": r["status"],
        "is_owner": r["owner_account_id"] == account_id,
        "players": conn.execute("SELECT COUNT(*) FROM room_members WHERE room_id=? AND connected=1", (r["room_id"],)).fetchone()[0],
        "seats_taken": _seats_taken(conn, r["room_id"]),
        "max_players": 4,
    }


def _save_view(conn: sqlite3.Connection, account_id: str) -> dict:
    row = conn.execute("SELECT state_json FROM account_saves WHERE account_id=?", (account_id,)).fetchone()
    return json.loads(row["state_json"])


@router.get("/v1/account/save")
def get_save(sess: AuthSession = Depends(require_access), conn=Depends(get_db)):
    lease = conn.execute("SELECT active, session_id, room_id FROM gameplay_leases WHERE account_id=?", (sess.account_id,)).fetchone()
    return {
        "save": _save_view(conn, sess.account_id),
        "lease": {
            "active": bool(lease and lease["active"]),
            "this_session": bool(lease and lease["active"] and lease["session_id"] == sess.session_id),
            "room_id": lease["room_id"] if lease and lease["active"] else None,
        },
    }


@router.post("/v1/account/takeover")
def takeover(sess: AuthSession = Depends(require_access), conn=Depends(get_db)):
    """Người dùng chủ động chuyển phiên chơi sang thiết bị này: nâng epoch, thu hồi thiết bị cũ trước."""
    with immediate(conn):
        _revoke_lease(conn, sess.account_id, "taken_over")
        conn.execute("UPDATE room_tickets SET consumed_at=? WHERE account_id=? AND session_id!=? AND consumed_at IS NULL", (now_s(), sess.account_id, sess.session_id))
    return {"ok": True}


@router.get("/v1/rooms")
def list_rooms(sess: AuthSession = Depends(require_access), conn=Depends(get_db)):
    rows = conn.execute("SELECT r.* FROM rooms r JOIN room_members m ON m.room_id=r.room_id WHERE m.account_id=? AND r.status!='closed' ORDER BY r.updated_at DESC", (sess.account_id,)).fetchall()
    return {"rooms": [_room_summary(conn, r, sess.account_id) for r in rows]}


def _leave_other_rooms(conn: sqlite3.Connection, account_id: str, keep_room: str | None) -> None:
    conn.execute("DELETE FROM room_members WHERE account_id=? AND room_id IS NOT ? AND connected=0", (account_id, keep_room))


@router.post("/v1/rooms")
def create_room(body: CreateRoomBody, sess: AuthSession = Depends(require_access), conn=Depends(get_db), cat: Catalog = Depends(get_cat)):
    save = _save_view(conn, sess.account_id)
    island = body.island_id or save["player"]["safe_island_id"]
    if island not in cat.islands:
        raise api_error(400, "INVALID_PAYLOAD")
    if island not in save["progress"]["islands_unlocked"]:
        raise api_error(403, "UNLOCK_REQUIRED")
    active = conn.execute("SELECT COUNT(*) FROM rooms WHERE status!='closed' AND updated_at>?", (now_s() - 3600,)).fetchone()[0]
    max_rooms = int(cat.limit("initial_concurrent_rooms"))
    room_id = str(uuid.uuid4())
    now = now_s()
    with immediate(conn):
        if active >= max_rooms:
            # Giới hạn phòng đồng thời thấp theo máy 8 GB (15 §3); đóng phòng rỗng quá hạn trước khi báo bận.
            conn.execute("UPDATE rooms SET status='closed', updated_at=? WHERE status!='closed' AND room_id NOT IN (SELECT room_id FROM room_members WHERE connected=1 OR reserved_at>?)", (now, now - SEAT_RESERVATION_S))
            active = conn.execute("SELECT COUNT(*) FROM rooms WHERE status!='closed'").fetchone()[0]
            if active >= max_rooms:
                raise api_error(503, "SERVER_BUSY")
        for _ in range(10):
            code = "".join(secrets.choice(INVITE_ALPHABET) for _ in range(6))
            if not conn.execute("SELECT 1 FROM rooms WHERE invite_code=?", (code,)).fetchone():
                break
        conn.execute("INSERT INTO rooms(room_id, invite_code, owner_account_id, island_id, status, created_at, updated_at) VALUES (?,?,?,?,?,?,?)",
                     (room_id, code, sess.account_id, island, "requested", now, now))
        _leave_other_rooms(conn, sess.account_id, room_id)
        conn.execute("INSERT INTO room_members(room_id, account_id, reserved_at) VALUES (?,?,?)", (room_id, sess.account_id, now))
        conn.execute("INSERT INTO room_controls(room_id, kind, payload_json, created_at) VALUES (?,?,?,?)",
                     (room_id, "create_room", json.dumps({"room_id": room_id, "island_id": island, "owner_account_id": sess.account_id}), now))
        r = conn.execute("SELECT * FROM rooms WHERE room_id=?", (room_id,)).fetchone()
        return _room_summary(conn, r, sess.account_id)


@router.post("/v1/rooms/lookup")
def lookup_room(body: LookupBody, sess: AuthSession = Depends(require_access), conn=Depends(get_db)):
    code = body.invite_code.strip().upper()
    r = conn.execute("SELECT * FROM rooms WHERE invite_code=? AND status!='closed'", (code,)).fetchone()
    if r is None:
        raise api_error(404, "INVITE_INVALID")
    return _room_summary(conn, r, sess.account_id)


@router.post("/v1/rooms/{room_id}/join")
def join_room(room_id: str, body: JoinBody, sess: AuthSession = Depends(require_access), conn=Depends(get_db)):
    now = now_s()
    with immediate(conn):
        r = conn.execute("SELECT * FROM rooms WHERE room_id=? AND status!='closed'", (room_id,)).fetchone()
        if r is None:
            raise api_error(404, "ROOM_NOT_FOUND")
        if r["invite_code"] != body.invite_code.strip().upper():
            raise api_error(403, "INVITE_INVALID")
        member = conn.execute("SELECT * FROM room_members WHERE room_id=? AND account_id=?", (room_id, sess.account_id)).fetchone()
        if member is None and _seats_taken(conn, room_id) >= 4:
            raise api_error(409, "ROOM_FULL")
        _leave_other_rooms(conn, sess.account_id, room_id)
        conn.execute("INSERT INTO room_members(room_id, account_id, reserved_at) VALUES (?,?,?) ON CONFLICT(room_id, account_id) DO UPDATE SET reserved_at=excluded.reserved_at", (room_id, sess.account_id, now))
        return _room_summary(conn, r, sess.account_id)


@router.post("/v1/rooms/{room_id}/ticket")
def room_ticket(room_id: str, sess: AuthSession = Depends(require_access), conn=Depends(get_db), cat: Catalog = Depends(get_cat)):
    now = now_s()
    with immediate(conn):
        r = conn.execute("SELECT * FROM rooms WHERE room_id=?", (room_id,)).fetchone()
        if r is None or r["status"] == "closed":
            raise api_error(404, "ROOM_NOT_FOUND")
        if r["status"] != "ready":
            raise api_error(409, "ROOM_NOT_READY")
        if conn.execute("SELECT 1 FROM room_members WHERE room_id=? AND account_id=?", (room_id, sess.account_id)).fetchone() is None:
            raise api_error(403, "INVITE_INVALID")
        lease = conn.execute("SELECT * FROM gameplay_leases WHERE account_id=?", (sess.account_id,)).fetchone()
        if lease and lease["active"] and lease["session_id"] != sess.session_id:
            raise api_error(409, "LEASE_ACTIVE_ELSEWHERE")
        conn.execute("UPDATE room_members SET reserved_at=? WHERE room_id=? AND account_id=?", (now, room_id, sess.account_id))
        ticket = security.new_token()
        ttl = int(cat.limit("ticket_ttl_s"))
        conn.execute("INSERT INTO room_tickets(ticket_hash, account_id, room_id, session_id, protocol_version, expires_at) VALUES (?,?,?,?,?,?)",
                     (security.token_hash(ticket), sess.account_id, room_id, sess.session_id, cat.protocol_version, now + ttl))
    return {"ticket": ticket, "expires_in": ttl, "room_id": room_id, "protocol_version": cat.protocol_version, "content_hash": cat.content_hash}
