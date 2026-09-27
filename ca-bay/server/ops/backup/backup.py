"""Backup/restore SQLite nhất quán cho CÁ BAY (07 §7).

  python server/ops/backup/backup.py backup  --db <cabay.db> --out <thư mục> [--keep 7]
  python server/ops/backup/backup.py verify  --file <backup.db>
  python server/ops/backup/backup.py restore --file <backup.db> --to <db mới>   (không ghi đè DB đang chạy)

Dùng sqlite3 backup API (an toàn khi DB đang ghi ở chế độ WAL), ghi SHA256 cạnh file,
giữ tối đa N bản. Restore luôn vào đường dẫn KHÁC rồi kiểm integrity/foreign keys/đếm save.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sqlite3
import sys
import time
from pathlib import Path


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def do_backup(db: Path, out: Path, keep: int) -> Path:
    out.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S", time.gmtime())
    target = out / f"cabay-{stamp}.db"
    src = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    dst = sqlite3.connect(target)
    with dst:
        src.backup(dst)
    dst.close()
    src.close()
    digest = sha256_file(target)
    (target.with_suffix(".db.sha256")).write_text(f"{digest}  {target.name}\n")
    backups = sorted(out.glob("cabay-*.db"))
    for old in backups[:-keep] if keep > 0 else []:
        old.unlink(missing_ok=True)
        old.with_suffix(".db.sha256").unlink(missing_ok=True)
    return target


def verify(path: Path) -> dict:
    side = path.with_suffix(".db.sha256")
    if side.exists():
        expected = side.read_text().split()[0]
        if expected != sha256_file(path):
            raise SystemExit(f"SHA256 không khớp cho {path.name}")
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        ic = conn.execute("PRAGMA integrity_check").fetchone()[0]
        fk = conn.execute("PRAGMA foreign_key_check").fetchall()
        accounts = conn.execute("SELECT COUNT(*) FROM accounts").fetchone()[0]
        saves = conn.execute("SELECT COUNT(*) FROM account_saves").fetchone()[0]
        claims = conn.execute("SELECT COUNT(*) FROM reward_claims").fetchone()[0]
        bad_json = 0
        for (state,) in conn.execute("SELECT state_json FROM account_saves"):
            try:
                json.loads(state)
            except ValueError:
                bad_json += 1
    finally:
        conn.close()
    report = {"integrity": ic, "foreign_key_violations": len(fk), "accounts": accounts, "saves": saves, "reward_claims": claims, "bad_save_json": bad_json}
    if ic != "ok" or fk or bad_json or accounts != saves:
        raise SystemExit(f"Backup lỗi: {report}")
    return report


def restore(path: Path, to: Path) -> dict:
    if to.exists():
        raise SystemExit(f"{to} đã tồn tại; restore chỉ ghi vào đường dẫn mới")
    verify(path)
    to.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, to)
    return verify(to)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["backup", "verify", "restore"])
    ap.add_argument("--db", type=Path)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--keep", type=int, default=7)
    ap.add_argument("--file", type=Path)
    ap.add_argument("--to", type=Path)
    a = ap.parse_args()
    if a.cmd == "backup":
        p = do_backup(a.db, a.out, a.keep)
        print(json.dumps({"backup": str(p), "sha256": sha256_file(p), **verify(p)}))
    elif a.cmd == "verify":
        print(json.dumps(verify(a.file)))
    else:
        print(json.dumps(restore(a.file, a.to)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
