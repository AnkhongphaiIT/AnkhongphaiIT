"""Phụ thuộc dùng chung cho route: DB, xác thực bearer, khóa dịch vụ, IP client."""
from __future__ import annotations

import hmac
import sqlite3
from dataclasses import dataclass

from fastapi import Depends, Header, HTTPException, Request

from .config import settings
from .content import Catalog, get_catalog
from .db import connect, now_s
from .security import token_hash


def get_db():
    conn = connect()
    try:
        yield conn
    finally:
        conn.close()


def get_cat() -> Catalog:
    return get_catalog()


def client_ip(request: Request) -> str:
    if settings.trust_proxy_headers:
        # Proxy/đường hầm (cloudflared, Tailscale, nginx) NỐI IP thật vào CUỐI X-Forwarded-For; các mục phía trước do
        # trình duyệt tự gửi được. Lấy mục cuối — lấy mục đầu thì kẻ dò mật khẩu đổi IP giả mỗi lần để lách giới hạn/IP.
        fwd = request.headers.get("x-forwarded-for", "")
        last = fwd.split(",")[-1].strip()
        if last:
            return last
    return request.client.host if request.client else "unknown"


def api_error(status: int, code: str) -> HTTPException:
    return HTTPException(status_code=status, detail={"error_code": code})


@dataclass
class AuthSession:
    account_id: str
    session_id: str
    last_auth_at: int
    display_name: str


def require_access(authorization: str | None = Header(default=None), conn: sqlite3.Connection = Depends(get_db)) -> AuthSession:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise api_error(401, "AUTH_REQUIRED")
    tok = authorization[7:].strip()
    if not 20 <= len(tok) <= 200:
        raise api_error(401, "AUTH_REQUIRED")
    row = conn.execute(
        """SELECT s.session_id, s.account_id, s.revoked_at, s.expires_at AS s_exp, s.last_auth_at, a.expires_at AS a_exp, acc.display_name
           FROM access_tokens a JOIN sessions s ON s.session_id=a.session_id JOIN accounts acc ON acc.account_id=s.account_id
           WHERE a.token_hash=?""", (token_hash(tok),)).fetchone()
    now = now_s()
    if row is None or row["revoked_at"] is not None:
        raise api_error(401, "AUTH_REQUIRED")
    if row["a_exp"] <= now or row["s_exp"] <= now:
        raise api_error(401, "AUTH_EXPIRED")
    return AuthSession(row["account_id"], row["session_id"], row["last_auth_at"], row["display_name"])


def require_service(x_service_key: str | None = Header(default=None)) -> None:
    if not settings.service_key:
        raise api_error(503, "SERVER_BUSY")
    if not x_service_key or not hmac.compare_digest(x_service_key.encode(), settings.service_key.encode()):
        raise api_error(403, "AUTH_REQUIRED")
