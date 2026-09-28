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


def test_password_rule_shown_to_player_matches_server(client):
    # Màn hình tạo tài khoản từng ghi "tối thiểu 10 ký tự" trong khi server đòi 12 → người chơi đặt 10–11 ký tự bị báo lỗi
    # với đúng dòng hướng dẫn sai. Lấy con số từ chính chuỗi hiển thị (VI và EN) rồi thử đăng ký ở ranh giới.
    import csv
    import re
    from pathlib import Path
    rows = {r[0]: r for r in csv.reader((Path(__file__).resolve().parents[3] / "data/loc/strings.csv").open(encoding="utf-8"))}
    en, vi = rows["ui.account.rules"][1], rows["ui.account.rules"][2]
    n_en = int(re.search(r"at least (\d+) characters", en).group(1))
    n_vi = int(re.search(r"tối thiểu (\d+) ký tự", vi).group(1))
    assert n_en == n_vi
    short = client.post("/v1/auth/register", json={"username": "ranh_gioi_a", "display_name": "x", "password": "m" * (n_en - 1)})
    assert short.status_code == 400 and short.json()["error_code"] == "WEAK_PASSWORD"
    ok = client.post("/v1/auth/register", json={"username": "ranh_gioi_b", "display_name": "x", "password": "m" * n_en})
    assert ok.status_code == 200


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


def test_rate_limit_ip_behind_proxy_not_spoofable(client, monkeypatch):
    # Sau đường hầm/proxy, IP thật nằm CUỐI X-Forwarded-For; mục đầu do người gửi tự điền. Đổi mục đầu mỗi lần
    # (thử mật khẩu trên nhiều tài khoản) không được lách giới hạn 20 lần sai/IP.
    import app.deps
    from app.ratelimit import IP_LIMIT
    monkeypatch.setattr(app.deps.settings, "trust_proxy_headers", True)
    codes = [client.post("/v1/auth/login", json={"username": f"nguoi_{i}", "password": "sai" * 5},
                         headers={"X-Forwarded-For": f"10.9.{i}.1, 203.0.113.7"}).status_code for i in range(IP_LIMIT + 1)]
    assert codes[:IP_LIMIT] == [401] * IP_LIMIT and codes[IP_LIMIT] == 429
    # IP thật khác (người chơi khác sau cùng proxy) không bị vạ lây
    assert client.post("/v1/auth/login", json={"username": "nguoi_khac", "password": "sai" * 5},
                       headers={"X-Forwarded-For": "198.51.100.4"}).status_code == 401


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


def test_unknown_origin_blocked_by_cors(env, monkeypatch):
    # AUTH-04: trình duyệt ở origin lạ không gọi được API (preflight bị từ chối, không có Access-Control-Allow-Origin);
    # origin đã khai (trang itch.io) thì được.
    import importlib
    from fastapi.testclient import TestClient
    from app import config
    import app.main
    monkeypatch.setenv("CABAY_ALLOWED_ORIGINS", "https://html-classic.itch.zone")
    config.reload_settings()
    try:
        with TestClient(importlib.reload(app.main).app) as c:
            pre = {"Access-Control-Request-Method": "POST", "Access-Control-Request-Headers": "content-type"}
            bad = c.options("/v1/auth/login", headers={"Origin": "https://evil.example", **pre})
            assert bad.status_code == 400 and "access-control-allow-origin" not in bad.headers
            good = c.options("/v1/auth/login", headers={"Origin": "https://html-classic.itch.zone", **pre})
            assert good.status_code == 200 and good.headers["access-control-allow-origin"] == "https://html-classic.itch.zone"
            # yêu cầu thường từ origin lạ: phản hồi không kèm quyền đọc cho trình duyệt
            r = c.post("/v1/auth/login", json={"username": "khongco", "password": "x" * 12}, headers={"Origin": "https://evil.example"})
            assert "access-control-allow-origin" not in r.headers
    finally:
        monkeypatch.delenv("CABAY_ALLOWED_ORIGINS")
        config.reload_settings()
        importlib.reload(app.main)


def test_password_hashing_limited_to_two_concurrent_jobs(env, monkeypatch):
    # AUTH-04: nhiều yêu cầu đăng nhập/đăng ký cùng lúc không làm chạy song song quá 2 phép băm scrypt (chống dồn CPU/RAM)
    import threading
    import time
    import app.security as sec
    active = {"now": 0, "max": 0}
    lock = threading.Lock()
    real = sec.hashlib.scrypt

    def slow_scrypt(*a, **k):
        with lock:
            active["now"] += 1
            active["max"] = max(active["max"], active["now"])
        time.sleep(0.05)
        try:
            return real(*a, **k)
        finally:
            with lock:
                active["now"] -= 1

    monkeypatch.setattr(sec.hashlib, "scrypt", slow_scrypt)
    threads = [threading.Thread(target=sec.hash_password, args=("mat khau dai du %d" % i,)) for i in range(8)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(10)
    assert active["max"] == 2


def test_guest_play_now_server_save_and_upgrade(client, env):
    # P-041 "Chơi ngay": không chọn tên đăng nhập/mật khẩu; server cấp tên khach_… + khóa ngẫu nhiên (băm, không lưu bản rõ)
    r = client.post("/v1/auth/guest", json={"display_name": "Bạn Cá Rô"})
    assert r.status_code == 200, r.text
    g = r.json()
    assert g["username"].startswith("khach_") and len(g["guest_secret"]) >= 32 and g["display_name"] == "Bạn Cá Rô"
    assert "recovery_codes" not in g
    auth = {"Authorization": f"Bearer {g['access_token']}"}
    assert client.get("/v1/account/save", headers=auth).json()["save"]["profile"]["display_name"] == "Bạn Cá Rô"
    conn = sqlite3.connect(env / "test.db")
    blob = b"".join(bytes(str(row), "utf-8") for row in conn.execute("SELECT * FROM credentials"))
    assert g["guest_secret"].encode() not in blob
    # lần sau trên cùng máy: client đăng nhập lại bằng khóa đã giữ
    again = client.post("/v1/auth/login", json={"username": g["username"], "password": g["guest_secret"]})
    assert again.status_code == 200
    # muốn chơi trên máy khác: đặt mật khẩu (mật khẩu cũ = khóa khách); khóa cũ hết hiệu lực
    h = {"Authorization": f"Bearer {again.json()['access_token']}"}
    ch = client.post("/v1/auth/password", json={"current_password": g["guest_secret"], "new_password": "mat khau moi du dai"}, headers=h)
    assert ch.status_code == 200, ch.text
    assert client.post("/v1/auth/login", json={"username": g["username"], "password": "mat khau moi du dai"}).status_code == 200
    assert client.post("/v1/auth/login", json={"username": g["username"], "password": g["guest_secret"]}).status_code == 401
    # tên hiển thị trống → tên gợi ý; tên có ký tự điều khiển → từ chối
    assert client.post("/v1/auth/guest", json={}).json()["display_name"].startswith("Người câu ")
    assert client.post("/v1/auth/guest", json={"display_name": "a\u0000b"}).status_code == 400


def test_guest_creation_limited_per_ip(client):
    from app.ratelimit import guest_limiter
    codes = [client.post("/v1/auth/guest", json={}).status_code for _ in range(guest_limiter.limit + 1)]
    assert codes[:guest_limiter.limit] == [200] * guest_limiter.limit and codes[-1] == 429
