"""Băm mật khẩu (scrypt), token ngẫu nhiên, mã phục hồi. Không log giá trị bí mật."""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import threading

from .config import settings

_hash_slots = threading.BoundedSemaphore(value=2)
_RECOVERY_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"  # bỏ ký tự dễ nhầm


def _scrypt(secret: bytes, salt: bytes, n: int, r: int, p: int) -> bytes:
    maxmem = 128 * r * n * 2 + 1024 * 1024
    with _hash_slots:
        return hashlib.scrypt(secret, salt=salt, n=n, r=r, p=p, maxmem=maxmem, dklen=32)


def hash_password(password: str) -> dict:
    salt = secrets.token_bytes(16)
    n, r, p = settings.scrypt_n, settings.scrypt_r, settings.scrypt_p
    digest = _scrypt(password.encode("utf-8"), salt, n, r, p)
    return {"algo": "scrypt", "params": json.dumps({"n": n, "r": r, "p": p}), "salt": salt, "digest": digest}


def verify_password(password: str, algo: str, params: str, salt: bytes, digest: bytes) -> bool:
    if algo != "scrypt":
        return False
    prm = json.loads(params)
    got = _scrypt(password.encode("utf-8"), salt, int(prm["n"]), int(prm["r"]), int(prm["p"]))
    return hmac.compare_digest(got, digest)


# Hash giả dùng khi username không tồn tại để thời gian phản hồi tương đương (không lộ tài khoản).
_DUMMY = None


def dummy_verify(password: str) -> None:
    global _DUMMY
    if _DUMMY is None:
        _DUMMY = hash_password("dummy-password-for-timing")
    verify_password(password, _DUMMY["algo"], _DUMMY["params"], _DUMMY["salt"], _DUMMY["digest"])


def new_token() -> str:
    return secrets.token_urlsafe(32)


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def new_recovery_codes(count: int = 8) -> list[str]:
    codes = []
    for _ in range(count):
        raw = "".join(secrets.choice(_RECOVERY_ALPHABET) for _ in range(12))
        codes.append(f"{raw[:4]}-{raw[4:8]}-{raw[8:]}")
    return codes


def normalize_recovery_code(code: str) -> str:
    return "".join(ch for ch in code.upper() if ch in _RECOVERY_ALPHABET)


def hash_recovery_code(code: str, salt: bytes | None = None) -> tuple[bytes, bytes]:
    salt = salt or secrets.token_bytes(16)
    norm = normalize_recovery_code(code).encode()
    return salt, _scrypt(norm, salt, settings.recovery_scrypt_n, 8, 1)


def verify_recovery_code(code: str, salt: bytes, digest: bytes) -> bool:
    _, got = hash_recovery_code(code, salt)
    return hmac.compare_digest(got, digest)


def b64(b: bytes) -> str:
    return base64.b64encode(b).decode()
