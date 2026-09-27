"""SQLite: WAL, foreign keys, busy_timeout, transaction ngắn với BEGIN IMMEDIATE."""
from __future__ import annotations

import sqlite3
import time
from contextlib import contextmanager
from pathlib import Path

from .config import settings

MIGRATIONS_DIR = Path(__file__).resolve().parent.parent / "migrations"


def connect(path: Path | None = None) -> sqlite3.Connection:
    path = path or settings.db_path
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path), timeout=5.0, isolation_level=None, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=FULL")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def migrate(conn: sqlite3.Connection) -> int:
    conn.execute("CREATE TABLE IF NOT EXISTS schema_migrations (name TEXT PRIMARY KEY, applied_at TEXT NOT NULL)")
    done = {r[0] for r in conn.execute("SELECT name FROM schema_migrations")}
    applied = 0
    for f in sorted(MIGRATIONS_DIR.glob("*.sql")):
        if f.name in done:
            continue
        conn.execute("BEGIN IMMEDIATE")
        try:
            for stmt in [s.strip() for s in f.read_text(encoding="utf-8").split(";") if s.strip()]:
                if all(line.strip().startswith("--") or not line.strip() for line in stmt.splitlines()):
                    continue
                conn.execute(stmt)
            conn.execute("INSERT INTO schema_migrations(name, applied_at) VALUES (?, datetime('now'))", (f.name,))
            conn.execute("COMMIT")
        except Exception:
            conn.execute("ROLLBACK")
            raise
        applied += 1
    return applied


@contextmanager
def immediate(conn: sqlite3.Connection, retries: int = 5):
    """Transaction ghi. Hết số lần thử khi DB bận -> ném lỗi để API trả PERSISTENCE_UNAVAILABLE."""
    last: Exception | None = None
    for attempt in range(retries):
        try:
            conn.execute("BEGIN IMMEDIATE")
            break
        except sqlite3.OperationalError as e:  # database is locked
            last = e
            time.sleep(0.05 * (attempt + 1))
    else:
        raise PersistenceBusy(str(last))
    try:
        yield conn
        conn.execute("COMMIT")
    except BaseException:
        conn.execute("ROLLBACK")
        raise


class PersistenceBusy(Exception):
    pass


def now_s() -> int:
    return int(time.time())


def iso_now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
