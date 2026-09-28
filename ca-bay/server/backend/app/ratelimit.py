"""Giới hạn thử sai theo account và IP (07 §4): 5 lần/account/5 phút, 20 lần/IP/5 phút. Không khóa vĩnh viễn."""
from __future__ import annotations

import threading
import time
from collections import defaultdict, deque

WINDOW_S = 300
ACCOUNT_LIMIT = 5
IP_LIMIT = 20


class FailureLimiter:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._acc: dict[str, deque] = defaultdict(deque)
        self._ip: dict[str, deque] = defaultdict(deque)

    def _prune(self, q: deque, now: float) -> None:
        while q and now - q[0] > WINDOW_S:
            q.popleft()

    def blocked(self, account_key: str | None, ip: str) -> bool:
        now = time.monotonic()
        with self._lock:
            qi = self._ip[ip]
            self._prune(qi, now)
            if len(qi) >= IP_LIMIT:
                return True
            if account_key:
                qa = self._acc[account_key]
                self._prune(qa, now)
                if len(qa) >= ACCOUNT_LIMIT:
                    return True
        return False

    def record_failure(self, account_key: str | None, ip: str) -> None:
        now = time.monotonic()
        with self._lock:
            self._ip[ip].append(now)
            if account_key:
                self._acc[account_key].append(now)

    def reset(self) -> None:
        with self._lock:
            self._acc.clear()
            self._ip.clear()


limiter = FailureLimiter()


class CreationLimiter:
    """Giới hạn số lần TẠO (không phải thử sai) theo IP trong một cửa sổ trượt — dùng cho tài khoản khách "Chơi ngay"."""

    def __init__(self, limit: int, window_s: int) -> None:
        self.limit, self.window_s = limit, window_s
        self._lock = threading.Lock()
        self._ip: dict[str, deque] = defaultdict(deque)

    def allow(self, ip: str) -> bool:
        now = time.monotonic()
        with self._lock:
            q = self._ip[ip]
            while q and now - q[0] > self.window_s:
                q.popleft()
            if len(q) >= self.limit:
                return False
            q.append(now)
            return True

    def reset(self) -> None:
        with self._lock:
            self._ip.clear()


# 30 tài khoản khách/IP/giờ: đủ cho một nhóm bạn chung mạng (cùng IP sau NAT/đường hầm), chặn tạo hàng loạt.
guest_limiter = CreationLimiter(limit=30, window_s=3600)
