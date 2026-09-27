"""AUTH-01…05 (docs/10_VALIDATION.md)."""
from __future__ import annotations

import sqlite3

from conftest import register


def test_register_login_and_hash_not_plaintext(client, env):
    u = register(client, username="NguoiCau_01", password="mat khau dai du 12")
    assert len(u["recovery_codes"]) == 8
    # username chuẩn hóa chữ thường, không phân biệt hoa thường khi đăng nhập
    r = client.post("/v1/auth/login", json={"username": "nguoicau_01", "password": "mat khau dai du 12"})
    assert r.status_code == 200
    conn = sqlite3.connect(env / "test.db")
    blob = b"".join(bytes(str(row), "utf-8") for row in conn.execute("SELECT * FROM credentials"))
    assert b"mat khau dai du 12" not in blob
    rows = conn.execute("SELECT algo, params FROM credentials").fetchall()
    assert rows[0][0] == "scrypt"
    for tbl in ("access_tokens", "refresh_tokens"):
        for (th,) in conn.execute(f"SELECT token_hash FROM {tbl}"):
            assert th != u["access_token"] and th != u["refresh_token"]


def test_duplicate_username_and_bad_inputs(client):
    register(client, username="trung_ten")
    r = client.post("/v1/auth/register", json={"username": "TRUNG_TEN", "display_name": "x", "password": "x" * 12})
    assert r.status_code == 409 and r.json()["error_code"] == "USERNAME_TAKEN"
    for body in (
        {"username": "ab", "display_name": "x", "password": "x" * 12},
        {"username": "tên_có_dấu", "display_name": "x", "password": "x" * 12},
        {"username": "ok_name", "display_name": "", "password": "x" * 12},
        {"username": "ok_name2", "display_name": "x", "password": "short"},
        {"username": "ok'); DROP TABLE accounts;--", "display_name": "x", "password": "x" * 12},
    ):
        assert client.post("/v1/auth/register", json=body).status_code == 400
    assert client.post("/v1/auth/register", content=b"{" + b"a" * 9000 + b"}", headers={"content-type": "application/json"}).status_code == 413


def test_login_generic_error_does_not_leak(client):
    register(client, username="co_that")
    a = client.post("/v1/auth/login", json={"username": "co_that", "password": "sai mat khau roi"})
    b = client.post("/v1/auth/login", json={"username": "khong_ton_tai", "password": "sai mat khau roi"})
    assert a.status_code == b.status_code == 401
    assert a.json() == b.json() == {"error_code": "INVALID_CREDENTIALS"}


def test_rate_limit_account(client):
    register(client, username="bi_do")
    codes = [client.post("/v1/auth/login", json={"username": "bi_do", "password": "sai" * 5}).status_code for _ in range(6)]
    assert codes[:5] == [401] * 5 and codes[5] == 429
    # mật khẩu đúng cũng bị chặn tạm thời trong cửa sổ, không khóa vĩnh viễn (limiter theo thời gian)
    assert client.post("/v1/auth/login", json={"username": "bi_do", "password": "correct horse battery"}).status_code == 429


def test_tokens_refresh_rotation_reuse_logout(client):
    u = register(client)
    r = client.post("/v1/auth/refresh", json={"refresh_token": u["refresh_token"]})
    assert r.status_code == 200
    new = r.json()
    # dùng lại refresh cũ -> thu hồi session
    assert client.post("/v1/auth/refresh", json={"refresh_token": u["refresh_token"]}).status_code == 401
    assert client.get("/v1/account/save", headers={"Authorization": f"Bearer {new['access_token']}"}).status_code == 401
    # đăng nhập lại rồi logout -> token chết
    lg = client.post("/v1/auth/login", json={"username": u["username"], "password": u["password"]}).json()
    h = {"Authorization": f"Bearer {lg['access_token']}"}
    assert client.get("/v1/account/save", headers=h).status_code == 200
    assert client.post("/v1/auth/logout", headers=h).status_code == 200
    assert client.get("/v1/account/save", headers=h).status_code == 401


def test_expired_access_token(client, env):
    u = register(client)
    conn = sqlite3.connect(env / "test.db")
    conn.execute("UPDATE access_tokens SET expires_at=0")
    conn.commit()
    r = client.get("/v1/account/save", headers=u["auth"])
    assert r.status_code == 401 and r.json()["error_code"] == "AUTH_EXPIRED"


def test_recovery_one_time_and_revokes_sessions(client):
    u = register(client, username="quen_mk")
    code = u["recovery_codes"][0]
    r = client.post("/v1/auth/recover", json={"username": "quen_mk", "recovery_code": code.lower(), "new_password": "mat khau moi 123456"})
    assert r.status_code == 200 and len(r.json()["recovery_codes"]) == 8
    assert client.get("/v1/account/save", headers=u["auth"]).status_code == 401
    # mã cũ (kể cả mã chưa dùng của bộ cũ) không còn hiệu lực
    assert client.post("/v1/auth/recover", json={"username": "quen_mk", "recovery_code": code, "new_password": "x" * 12}).status_code == 401
    assert client.post("/v1/auth/recover", json={"username": "quen_mk", "recovery_code": u["recovery_codes"][1], "new_password": "x" * 12}).status_code == 401
    assert client.post("/v1/auth/login", json={"username": "quen_mk", "password": "mat khau moi 123456"}).status_code == 200


def test_recovery_without_code_fails(client):
    register(client, username="khong_ma")
    r = client.post("/v1/auth/recover", json={"username": "khong_ma", "recovery_code": "AAAA-BBBB-CCCC", "new_password": "x" * 12})
    assert r.status_code == 401


def test_password_change_revokes(client):
    u = register(client)
    r = client.post("/v1/auth/password", headers=u["auth"], json={"current_password": u["password"], "new_password": "doi mat khau moi 1"})
    assert r.status_code == 200
    assert client.get("/v1/account/save", headers=u["auth"]).status_code == 401


def test_delete_account_requires_recent_auth_and_only_self(client, env):
    a = register(client)
    b = register(client)
    conn = sqlite3.connect(env / "test.db")
    conn.execute("UPDATE sessions SET last_auth_at=0")
    conn.commit()
    r = client.request("DELETE", "/v1/account", headers=a["auth"], json={"password": a["password"]})
    assert r.status_code == 403 and r.json()["error_code"] == "REAUTH_REQUIRED"
    assert client.post("/v1/auth/reauth", headers=a["auth"], json={"password": a["password"]}).status_code == 200
    assert client.request("DELETE", "/v1/account", headers=a["auth"], json={"password": "sai mat khau 123"}).status_code == 401
    assert client.request("DELETE", "/v1/account", headers=a["auth"], json={"password": a["password"]}).status_code == 200
    assert client.post("/v1/auth/login", json={"username": a["username"], "password": a["password"]}).status_code == 401
    # tài khoản khác không bị ảnh hưởng
    assert client.post("/v1/auth/login", json={"username": b["username"], "password": b["password"]}).status_code == 200
    n = conn.execute("SELECT COUNT(*) FROM account_saves").fetchone()[0]
    assert n == 1


def test_internal_api_requires_service_key(client):
    assert client.get("/internal/room-controls").status_code == 403
    assert client.get("/internal/room-controls", headers={"X-Service-Key": "sai"}).status_code == 403


def test_save_view_has_no_secrets(client):
    u = register(client)
    s = client.get("/v1/account/save", headers=u["auth"]).json()["save"]
    text = str(s)
    for bad in ("password", "token", "recovery_code", u["refresh_token"], u["access_token"]):
        assert bad not in text
