"""Đăng ký / đăng nhập / refresh / logout / phục hồi / đổi mật khẩu / xóa tài khoản (07 §4)."""
from __future__ import annotations

import json
import re
import secrets
import sqlite3
import unicodedata
import uuid

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel

from ..content import Catalog
from ..db import immediate, iso_now, now_s
from ..deps import AuthSession, api_error, client_ip, get_cat, get_db, require_access
from ..ratelimit import guest_limiter, limiter
from ..save import new_save
from .. import security

router = APIRouter()

USERNAME_RE = re.compile(r"^[a-z0-9_]{3,24}$")
REAUTH_WINDOW_S = 300


class RegisterBody(BaseModel):
    username: str
    display_name: str
    password: str


class LoginBody(BaseModel):
    username: str
    password: str


class RefreshBody(BaseModel):
    refresh_token: str


class RecoverBody(BaseModel):
    username: str
    recovery_code: str
    new_password: str


class PasswordBody(BaseModel):
    current_password: str
    new_password: str


class ReauthBody(BaseModel):
    password: str


class DeleteBody(BaseModel):
    password: str


def normalize_username(u: str) -> str:
    return u.strip().lower()


def valid_display_name(name: str) -> str:
    name = unicodedata.normalize("NFC", name.strip())
    if not 1 <= len(name) <= 32 or any(unicodedata.category(c).startswith("C") for c in name):
        raise api_error(400, "INVALID_PAYLOAD")
    return name


def check_password_policy(pw: str) -> None:
    if not 12 <= len(pw) <= 128:
        raise api_error(400, "WEAK_PASSWORD")


def issue_session(conn: sqlite3.Connection, cat: Catalog, account_id: str) -> dict:
    now = now_s()
    sid = str(uuid.uuid4())
    access, refresh = security.new_token(), security.new_token()
    ttl = int(cat.limit("access_token_ttl_s"))
    max_s = int(cat.limit("refresh_session_max_s"))
    conn.execute("INSERT INTO sessions(session_id, account_id, created_at, expires_at, last_auth_at) VALUES (?,?,?,?,?)", (sid, account_id, now, now + max_s, now))
    conn.execute("INSERT INTO access_tokens(token_hash, session_id, expires_at) VALUES (?,?,?)", (security.token_hash(access), sid, now + ttl))
    conn.execute("INSERT INTO refresh_tokens(token_hash, session_id, expires_at) VALUES (?,?,?)", (security.token_hash(refresh), sid, now + max_s))
    return {"access_token": access, "refresh_token": refresh, "expires_in": ttl, "session_expires_in": max_s}


def revoke_all(conn: sqlite3.Connection, account_id: str, reason: str) -> None:
    """Thu hồi mọi session/ticket/lease và báo room server ngắt kết nối (logout toàn bộ, đổi mật khẩu, phục hồi, xóa)."""
    now = now_s()
    conn.execute("UPDATE sessions SET revoked_at=? WHERE account_id=? AND revoked_at IS NULL", (now, account_id))
    conn.execute("DELETE FROM access_tokens WHERE session_id IN (SELECT session_id FROM sessions WHERE account_id=?)", (account_id,))
    conn.execute("UPDATE room_tickets SET consumed_at=? WHERE account_id=? AND consumed_at IS NULL", (now, account_id))
    _revoke_lease(conn, account_id, reason)


def _revoke_lease(conn: sqlite3.Connection, account_id: str, reason: str, session_id: str | None = None) -> None:
    lease = conn.execute("SELECT * FROM gameplay_leases WHERE account_id=?", (account_id,)).fetchone()
    if lease is None:
        return
    if session_id is not None and lease["session_id"] != session_id:
        return
    conn.execute("UPDATE gameplay_leases SET epoch=epoch+1, active=0, updated_at=? WHERE account_id=?", (now_s(), account_id))
    if lease["active"]:
        conn.execute("INSERT INTO room_controls(room_id, kind, payload_json, created_at) VALUES (?,?,?,?)",
                     (lease["room_id"], "kick_account", json.dumps({"account_id": account_id, "reason": reason, "connection_id": lease["connection_id"]}), now_s()))


def _auth_fail(key: str | None, ip: str, status: int = 401, code: str = "INVALID_CREDENTIALS"):
    limiter.record_failure(key, ip)
    return api_error(status, code)


@router.post("/v1/auth/register")
def register(body: RegisterBody, request: Request, conn=Depends(get_db), cat: Catalog = Depends(get_cat)):
    ip = client_ip(request)
    uname = normalize_username(body.username)
    if limiter.blocked(uname, ip):
        raise api_error(429, "RATE_LIMITED")
    if not USERNAME_RE.fullmatch(uname):
        raise _auth_fail(uname, ip, 400, "INVALID_PAYLOAD")
    display = valid_display_name(body.display_name)
    check_password_policy(body.password)
    cred = security.hash_password(body.password)
    codes = security.new_recovery_codes()
    hashed_codes = [security.hash_recovery_code(c) for c in codes]
    account_id = str(uuid.uuid4())
    with immediate(conn):
        if conn.execute("SELECT 1 FROM accounts WHERE username=?", (uname,)).fetchone():
            limiter.record_failure(uname, ip)
            raise api_error(409, "USERNAME_TAKEN")
        conn.execute("INSERT INTO accounts(account_id, username, display_name, created_at) VALUES (?,?,?,?)", (account_id, uname, display, iso_now()))
        conn.execute("INSERT INTO credentials(account_id, algo, params, salt, digest, updated_at) VALUES (?,?,?,?,?,?)",
                     (account_id, cred["algo"], cred["params"], cred["salt"], cred["digest"], iso_now()))
        for salt, dig in hashed_codes:
            conn.execute("INSERT INTO recovery_codes(account_id, salt, digest, created_at) VALUES (?,?,?,?)", (account_id, salt, dig, iso_now()))
        sv = new_save(cat, account_id, display)
        conn.execute("INSERT INTO account_saves(account_id, schema_version, save_version, state_json, updated_at) VALUES (?,?,?,?,?)",
                     (account_id, sv["schema_version"], sv["save_version"], json.dumps(sv, ensure_ascii=False), sv["updated_at"]))
        conn.execute("INSERT INTO gameplay_leases(account_id, epoch, active, updated_at) VALUES (?,0,0,?)", (account_id, now_s()))
        tokens = issue_session(conn, cat, account_id)
    return {"account_id": account_id, "display_name": display, "recovery_codes": codes, **tokens}


class GuestBody(BaseModel):
    display_name: str = ""


@router.post("/v1/auth/guest")
def guest(body: GuestBody, request: Request, conn=Depends(get_db), cat: Catalog = Depends(get_cat)):
    """"Chơi ngay" (P-041): tài khoản khách không phải chọn tên đăng nhập/mật khẩu. Server tự đặt tên `khach_xxxxxxxx` và một
    khóa ngẫu nhiên 192 bit làm mật khẩu (băm scrypt như mật khẩu thường, không lưu bản rõ); client giữ khóa trên máy đó để lần
    sau tự vào lại. Tiến trình vẫn lưu ở server. Muốn chơi trên máy khác: đặt mật khẩu (đổi mật khẩu bằng khóa làm mật khẩu cũ).
    Mỗi IP chỉ tạo được một số tài khoản khách mỗi giờ (chống tạo hàng loạt)."""
    ip = client_ip(request)
    if limiter.blocked(None, ip) or not guest_limiter.allow(ip):
        raise api_error(429, "RATE_LIMITED")
    display = valid_display_name(body.display_name or f"Người câu {secrets.randbelow(900) + 100}")
    secret = secrets.token_urlsafe(24)
    cred = security.hash_password(secret)
    account_id = str(uuid.uuid4())
    with immediate(conn):
        for _ in range(8):
            uname = "khach_" + secrets.token_hex(4)
            if not conn.execute("SELECT 1 FROM accounts WHERE username=?", (uname,)).fetchone():
                break
        else:
            raise api_error(503, "SERVER_BUSY")
        conn.execute("INSERT INTO accounts(account_id, username, display_name, created_at) VALUES (?,?,?,?)", (account_id, uname, display, iso_now()))
        conn.execute("INSERT INTO credentials(account_id, algo, params, salt, digest, updated_at) VALUES (?,?,?,?,?,?)",
                     (account_id, cred["algo"], cred["params"], cred["salt"], cred["digest"], iso_now()))
        sv = new_save(cat, account_id, display)
        conn.execute("INSERT INTO account_saves(account_id, schema_version, save_version, state_json, updated_at) VALUES (?,?,?,?,?)",
                     (account_id, sv["schema_version"], sv["save_version"], json.dumps(sv, ensure_ascii=False), sv["updated_at"]))
        conn.execute("INSERT INTO gameplay_leases(account_id, epoch, active, updated_at) VALUES (?,0,0,?)", (account_id, now_s()))
        tokens = issue_session(conn, cat, account_id)
    return {"account_id": account_id, "display_name": display, "username": uname, "guest_secret": secret, **tokens}


@router.post("/v1/auth/login")
def login(body: LoginBody, request: Request, conn=Depends(get_db), cat: Catalog = Depends(get_cat)):
    ip = client_ip(request)
    uname = normalize_username(body.username)
    if limiter.blocked(uname, ip):
        raise api_error(429, "RATE_LIMITED")
    if len(body.password) > 128:
        raise _auth_fail(uname, ip)
    row = conn.execute("SELECT a.account_id, a.display_name, c.algo, c.params, c.salt, c.digest FROM accounts a JOIN credentials c ON c.account_id=a.account_id WHERE a.username=?", (uname,)).fetchone()
    if row is None:
        security.dummy_verify(body.password)
        raise _auth_fail(uname, ip)
    if not security.verify_password(body.password, row["algo"], row["params"], row["salt"], row["digest"]):
        raise _auth_fail(uname, ip)
    with immediate(conn):
        tokens = issue_session(conn, cat, row["account_id"])
    return {"account_id": row["account_id"], "display_name": row["display_name"], **tokens}


@router.post("/v1/auth/refresh")
def refresh(body: RefreshBody, conn=Depends(get_db), cat: Catalog = Depends(get_cat)):
    th = security.token_hash(body.refresh_token)
    now = now_s()
    with immediate(conn):
        row = conn.execute("SELECT r.session_id, r.used_at, r.expires_at, s.revoked_at, s.account_id, s.expires_at AS s_exp FROM refresh_tokens r JOIN sessions s ON s.session_id=r.session_id WHERE r.token_hash=?", (th,)).fetchone()
        if row is None or row["revoked_at"] is not None:
            raise api_error(401, "AUTH_REQUIRED")
        if row["used_at"] is not None:
            # Dùng lại refresh token đã xoay: coi là bị lộ → thu hồi session.
            conn.execute("UPDATE sessions SET revoked_at=? WHERE session_id=?", (now, row["session_id"]))
            conn.execute("DELETE FROM access_tokens WHERE session_id=?", (row["session_id"],))
            _revoke_lease(conn, row["account_id"], "refresh_reuse", row["session_id"])
            return_error = api_error(401, "AUTH_EXPIRED")
        elif row["expires_at"] <= now or row["s_exp"] <= now:
            raise api_error(401, "AUTH_EXPIRED")
        else:
            return_error = None
            conn.execute("UPDATE refresh_tokens SET used_at=? WHERE token_hash=?", (now, th))
            access, new_refresh = security.new_token(), security.new_token()
            ttl = int(cat.limit("access_token_ttl_s"))
            conn.execute("INSERT INTO access_tokens(token_hash, session_id, expires_at) VALUES (?,?,?)", (security.token_hash(access), row["session_id"], now + ttl))
            conn.execute("INSERT INTO refresh_tokens(token_hash, session_id, expires_at) VALUES (?,?,?)", (security.token_hash(new_refresh), row["session_id"], row["s_exp"]))
    if return_error is not None:
        raise return_error
    return {"access_token": access, "refresh_token": new_refresh, "expires_in": ttl}


@router.post("/v1/auth/logout")
def logout(sess: AuthSession = Depends(require_access), conn=Depends(get_db)):
    now = now_s()
    with immediate(conn):
        conn.execute("UPDATE sessions SET revoked_at=? WHERE session_id=?", (now, sess.session_id))
        conn.execute("DELETE FROM access_tokens WHERE session_id=?", (sess.session_id,))
        conn.execute("UPDATE room_tickets SET consumed_at=? WHERE session_id=? AND consumed_at IS NULL", (now, sess.session_id))
        _revoke_lease(conn, sess.account_id, "logout", sess.session_id)
    return {"ok": True}


def _replace_recovery_codes(conn: sqlite3.Connection, account_id: str) -> list[str]:
    conn.execute("DELETE FROM recovery_codes WHERE account_id=?", (account_id,))
    codes = security.new_recovery_codes()
    for c in codes:
        salt, dig = security.hash_recovery_code(c)
        conn.execute("INSERT INTO recovery_codes(account_id, salt, digest, created_at) VALUES (?,?,?,?)", (account_id, salt, dig, iso_now()))
    return codes


@router.post("/v1/auth/recover")
def recover(body: RecoverBody, request: Request, conn=Depends(get_db)):
    ip = client_ip(request)
    uname = normalize_username(body.username)
    if limiter.blocked(uname, ip):
        raise api_error(429, "RATE_LIMITED")
    check_password_policy(body.new_password)
    acc = conn.execute("SELECT account_id FROM accounts WHERE username=?", (uname,)).fetchone()
    if acc is None:
        raise _auth_fail(uname, ip)
    rows = conn.execute("SELECT id, salt, digest FROM recovery_codes WHERE account_id=? AND used_at IS NULL", (acc["account_id"],)).fetchall()
    match = next((r for r in rows if security.verify_recovery_code(body.recovery_code, r["salt"], r["digest"])), None)
    if match is None:
        raise _auth_fail(uname, ip)
    cred = security.hash_password(body.new_password)
    with immediate(conn):
        cur = conn.execute("UPDATE recovery_codes SET used_at=? WHERE id=? AND used_at IS NULL", (iso_now(), match["id"]))
        if cur.rowcount != 1:
            raise api_error(401, "INVALID_CREDENTIALS")
        conn.execute("UPDATE credentials SET algo=?, params=?, salt=?, digest=?, updated_at=? WHERE account_id=?",
                     (cred["algo"], cred["params"], cred["salt"], cred["digest"], iso_now(), acc["account_id"]))
        revoke_all(conn, acc["account_id"], "recovered")
        codes = _replace_recovery_codes(conn, acc["account_id"])
        conn.execute("INSERT INTO audit_log(account_id, kind, detail, created_at) VALUES (?,?,?,?)", (acc["account_id"], "recover", "{}", iso_now()))
    return {"ok": True, "recovery_codes": codes}


def _verify_current(conn, account_id: str, password: str) -> bool:
    c = conn.execute("SELECT algo, params, salt, digest FROM credentials WHERE account_id=?", (account_id,)).fetchone()
    return c is not None and len(password) <= 128 and security.verify_password(password, c["algo"], c["params"], c["salt"], c["digest"])


@router.post("/v1/auth/password")
def change_password(body: PasswordBody, request: Request, sess: AuthSession = Depends(require_access), conn=Depends(get_db)):
    ip = client_ip(request)
    if limiter.blocked(sess.account_id, ip):
        raise api_error(429, "RATE_LIMITED")
    if not _verify_current(conn, sess.account_id, body.current_password):
        raise _auth_fail(sess.account_id, ip)
    check_password_policy(body.new_password)
    cred = security.hash_password(body.new_password)
    with immediate(conn):
        conn.execute("UPDATE credentials SET algo=?, params=?, salt=?, digest=?, updated_at=? WHERE account_id=?",
                     (cred["algo"], cred["params"], cred["salt"], cred["digest"], iso_now(), sess.account_id))
        revoke_all(conn, sess.account_id, "password_changed")
    return {"ok": True}


@router.post("/v1/auth/reauth")
def reauth(body: ReauthBody, request: Request, sess: AuthSession = Depends(require_access), conn=Depends(get_db)):
    ip = client_ip(request)
    if limiter.blocked(sess.account_id, ip):
        raise api_error(429, "RATE_LIMITED")
    if not _verify_current(conn, sess.account_id, body.password):
        raise _auth_fail(sess.account_id, ip)
    with immediate(conn):
        conn.execute("UPDATE sessions SET last_auth_at=? WHERE session_id=?", (now_s(), sess.session_id))
    return {"ok": True, "valid_for_s": REAUTH_WINDOW_S}


@router.delete("/v1/account")
def delete_account(body: DeleteBody, request: Request, sess: AuthSession = Depends(require_access), conn=Depends(get_db)):
    ip = client_ip(request)
    if limiter.blocked(sess.account_id, ip):
        raise api_error(429, "RATE_LIMITED")
    if now_s() - sess.last_auth_at > REAUTH_WINDOW_S:
        raise api_error(403, "REAUTH_REQUIRED")
    if not _verify_current(conn, sess.account_id, body.password):
        raise _auth_fail(sess.account_id, ip)
    aid = sess.account_id
    with immediate(conn):
        revoke_all(conn, aid, "deleted")
        # Chỉ xóa dữ liệu của chính người gửi. Tombstone op/UID không chứa dữ liệu cá nhân.
        conn.execute("DELETE FROM item_registry WHERE owner_account_id=?", (aid,))
        conn.execute("DELETE FROM lootbox_receipts WHERE account_id=?", (aid,))
        conn.execute("DELETE FROM boss_attempts WHERE account_id=?", (aid,))
        conn.execute("DELETE FROM reward_claims WHERE account_id=?", (aid,))
        conn.execute("DELETE FROM operations WHERE account_id=?", (aid,))
        conn.execute("DELETE FROM room_members WHERE account_id=?", (aid,))
        conn.execute("UPDATE rooms SET owner_account_id=NULL WHERE owner_account_id=?", (aid,))
        conn.execute("DELETE FROM accounts WHERE account_id=?", (aid,))
        conn.execute("INSERT INTO audit_log(account_id, kind, detail, created_at) VALUES (?,?,?,?)", (None, "account_deleted", "{}", iso_now()))
    return {"ok": True}
