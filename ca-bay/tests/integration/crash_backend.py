#!/usr/bin/env python3
"""SAVE-03 (phần backend): giết tiến trình backend (SIGKILL) giữa lúc đang ghi giao dịch, bật lại trên cùng DB,
gửi lại mọi lệnh chưa nhận phản hồi với **cùng op_id + cùng payload** (như room server/client làm), rồi kiểm:

- lệnh đã được xác nhận (ack committed) vẫn còn nguyên sau crash;
- lệnh chưa ack khi hỏi lại cho đúng một kết quả (không chạy lần hai);
- tiền = tiền ban đầu + tổng giá trị trong receipt của các lệnh bán đã commit (không cộng lặp);
- mỗi cá chỉ ở một trạng thái (túi hoặc đã bán), không nhân đôi; vé/hộp quà không mở lặp;
- `PRAGMA integrity_check` = ok.

    python3 tests/integration/crash_backend.py [--kills 6] [--seed 1]

Chỉ chạy backend (không cần room server): lệnh gửi thẳng API nội bộ bằng khóa dịch vụ ngẫu nhiên của stack test.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import signal
import sqlite3
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from stack import Stack  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


class Api:
    def __init__(self, base: str, key: str):
        self.base, self.key = base, key

    def call(self, method: str, path: str, body=None, auth: str | None = None, internal=False, timeout=5.0):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(self.base + path, data=data, method=method)
        req.add_header("Content-Type", "application/json")
        if auth:
            req.add_header("Authorization", "Bearer " + auth)
        if internal:
            req.add_header("X-Service-Key", self.key)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.status, json.loads(r.read() or b"{}")
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b"{}")


def setup_player(api: Api) -> dict:
    user = "crash" + uuid.uuid4().hex[:8]
    st, reg = api.call("POST", "/v1/auth/register", {"username": user, "display_name": "Crash Test", "password": "mat-khau-crash-test-dai"})
    assert st == 200, reg
    tok = reg["access_token"]
    st, room = api.call("POST", "/v1/rooms", {}, auth=tok)
    assert st == 200, room
    st, ctl = api.call("GET", "/internal/room-controls", internal=True)
    acks = [c["control_id"] for c in ctl["controls"] if c["room_id"] == room["room_id"]]
    api.call("POST", "/internal/room-status", {"acks": acks, "rooms": [{"room_id": room["room_id"], "status": "ready", "island_id": room["island_id"]}]}, internal=True)
    st, t = api.call("POST", f"/v1/rooms/{room['room_id']}/ticket", auth=tok)
    assert st == 200, t
    st, lease = api.call("POST", "/internal/tickets/consume", {"ticket": t["ticket"], "protocol_version": t["protocol_version"],
                                                             "content_hash": t["content_hash"], "connection_id": str(uuid.uuid4())}, internal=True)
    assert st == 200, lease
    lease["token"] = tok
    return lease


class Journal:
    """Nhật ký phía "room server": ý định (op_id, payload, esv) ghi TRƯỚC khi gửi, kết quả ghi khi có ack."""

    def __init__(self):
        self.ops: dict[str, dict] = {}
        self.order: list[str] = []
        self.lock = threading.Lock()

    def intent(self, op_type: str, payload: dict, esv, server: bool) -> str:
        op_id = str(uuid.uuid4())
        with self.lock:
            self.ops[op_id] = {"op_type": op_type, "payload": payload, "esv": esv, "server": server, "result": None}
            self.order.append(op_id)
        return op_id

    def ack(self, op_id: str, res: dict) -> None:
        with self.lock:
            self.ops[op_id]["result"] = res


def commit(api: Api, lease: dict, j: Journal, op_id: str, timeout=5.0) -> dict | None:
    o = j.ops[op_id]
    body = {"account_id": lease["account_id"], "lease_epoch": lease["lease_epoch"], "room_id": lease["room_id"], "op_id": op_id,
            "op_type": o["op_type"], "payload": o["payload"], "expected_save_version": None if o["server"] else o["esv"]}
    try:
        st, res = api.call("POST", "/internal/accounts/commit", body, internal=True, timeout=timeout)
    except (urllib.error.URLError, ConnectionError, TimeoutError, OSError):
        return None
    if st != 200:
        return None
    j.ack(op_id, res)
    return res


def worker(api: Api, lease: dict, j: Journal, stop: threading.Event, box: dict, rng: random.Random) -> None:
    """Chuỗi giao dịch liên tục: nhặt cá → bán → (có vé thì) mở hộp quà → lấy cơm miễn phí."""
    version = lease["save"]["save_version"]
    while not stop.is_set():
        kind = rng.choice(["pickup", "pickup", "sell", "loot", "rice"])
        save = lease["save"]
        if kind == "pickup":
            if len(save["inventory"]["bag"]) >= 3:
                kind = "sell"
            else:
                op = j.intent("inventory.pickup", {"item_uid": str(uuid.uuid4()), "fresh_item": {"def_kind": "creature", "def_id": rng.choice(["cre_ca_ro", "cre_tep", "cre_ca_tre"]),
                              "variant_id": None, "trick_mult_milli": rng.choice([1000, 1500, 2000]), "tricks": []}}, version, False)
        if kind == "sell":
            uids = [i["uid"] for i in save["inventory"]["bag"] if i["def_kind"] == "creature"]
            if not uids:
                continue
            op = j.intent("inventory.sell", {"shop_id": "shop_co_ba", "item_uids": uids}, version, False)
        elif kind == "loot":
            if save["currencies"]["festival_ticket"] < 1:
                continue
            op = j.intent("lootbox.open", {"box_id": box["id"], "table_version": box["table_version"]}, version, False)
        elif kind == "rice":
            op = j.intent("shop.buy", {"shop_id": "shop_co_ba", "entry_id": "entry_rice_ball", "quantity": 1}, version, False)
        res = commit(api, lease, j, op, timeout=3.0)
        if res is None:
            return  # backend chết: dừng, lệnh này thành "chưa ack"
        if "save" in res and isinstance(res["save"], dict):
            lease["save"] = res["save"]
            version = res["save"]["save_version"]
        elif res.get("error_code") == "SAVE_CONFLICT" and "save" in res:
            lease["save"] = res["save"]
            version = res["save"]["save_version"]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kills", type=int, default=6)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--api-port", type=int, default=8817)
    a = ap.parse_args()
    rng = random.Random(a.seed)
    st = Stack(api_port=a.api_port, ws_port=8930)
    checks: dict[str, bool] = {}
    try:
        st.start_backend()
        api = Api(f"http://127.0.0.1:{a.api_port}", st.key)
        lease = setup_player(api)
        boxes = json.loads((ROOT / "data/content/lootboxes.json").read_text(encoding="utf-8"))
        box = next(iter(boxes.get("records", boxes.get("lootboxes", {}).get("records", []))))
        money0 = lease["save"]["currencies"]["money"]
        j = Journal()
        for k in range(a.kills):
            stop = threading.Event()
            th = threading.Thread(target=worker, args=(api, lease, j, stop, box, rng), daemon=True)
            th.start()
            time.sleep(rng.uniform(0.4, 2.0))
            os.killpg(st.backend.pid, signal.SIGKILL)  # tắt đột ngột, có thể giữa BEGIN IMMEDIATE…COMMIT
            st.backend.wait(10)
            stop.set()
            th.join(10)
            st.procs.remove(st.backend)
            st.start_backend()  # cùng DB; migration/khởi động phải chịu được WAL dở dang
            # hỏi lại mọi lệnh chưa ack với cùng op_id + payload + esv
            pending = [op for op in j.order if j.ops[op]["result"] is None]
            for op in pending:
                j.ops[op]["was_pending"] = True
                res = commit(api, lease, j, op)
                if res is None:
                    print(f"CHECK FAIL resend_after_restart {op}")
                    return 1
                if isinstance(res.get("save"), dict) and res["save"]["save_version"] >= lease["save"]["save_version"]:
                    lease["save"] = res["save"]
            # nạp lại save mới nhất từ backend (như room server khi nối lại)
            s, sv = api.call("GET", "/v1/account/save", auth=lease["token"])
            lease["save"] = sv.get("save", lease["save"]) if s == 200 else lease["save"]
            print(f"kill {k + 1}/{a.kills}: ops={len(j.order)} chưa_ack_trước_khi_hỏi_lại={len(pending)}")
        # ---- kiểm tra cuối
        # 1) gửi lại MỌI lệnh lần nữa: kết quả phải giống hệt lần đã ack (không chạy lại)
        same = True
        for op in j.order:
            before = j.ops[op]["result"]
            res = commit(api, lease, j, op)
            if res is None or res.get("status") != before.get("status") or res.get("save_version") != before.get("save_version"):
                same = False
                print("  khác:", j.ops[op]["op_type"], before.get("status"), res and res.get("status"))
                break
        checks["replay_every_op_returns_original_result"] = same
        db = sqlite3.connect(st.db)
        db.row_factory = sqlite3.Row
        checks["integrity_check_ok"] = db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
        save = json.loads(db.execute("SELECT state_json FROM account_saves WHERE account_id=?", (lease["account_id"],)).fetchone()[0])
        committed = [j.ops[op] for op in j.order if j.ops[op]["result"]["status"] == "committed"]
        sells = [o for o in committed if o["op_type"] == "inventory.sell"]
        earned = sum(int(o["result"]["receipt"]["total"]) for o in sells)
        bonus = int(json.loads((ROOT / "data/content/balance.json").read_text(encoding="utf-8"))["economy"]["first_catch_bonus"])
        first_catch = bonus * sum(1 for o in committed if o["op_type"] == "inventory.pickup" and o["result"]["receipt"].get("new_species"))
        buys = [o for o in committed if o["op_type"] == "shop.buy"]
        loots = [o for o in committed if o["op_type"] == "lootbox.open"]
        checks["ledger_has_every_op_once"] = db.execute("SELECT COUNT(*) FROM operations WHERE account_id=?", (lease["account_id"],)).fetchone()[0] == len(j.order)
        states = {r["item_uid"]: r["state"] for r in db.execute("SELECT item_uid, state FROM item_registry WHERE owner_account_id=?", (lease["account_id"],))}
        picked = [o["payload"]["item_uid"] for o in committed if o["op_type"] == "inventory.pickup"]
        sold = {u for o in sells for u in o["payload"]["item_uids"]}
        bag = {i["uid"] for i in save["inventory"]["bag"]}
        checks["every_committed_pickup_registered_once"] = all(u in states for u in picked) and len(set(picked)) == len(picked)
        checks["sold_items_not_in_bag"] = not (sold & bag) and all(states.get(u) == "sold" for u in sold)
        checks["unsold_items_in_bag"] = all(u in bag for u in picked if u not in sold)
        checks["lootbox_receipts_match_committed_opens"] = db.execute("SELECT COUNT(*) FROM lootbox_receipts WHERE account_id=?", (lease["account_id"],)).fetchone()[0] == len(loots)
        checks["money_equals_committed_receipts"] = save["currencies"]["money"] - money0 == earned + first_catch
        checks["crashes_hit_unacked_ops"] = sum(1 for o in j.ops.values() if o.get("was_pending")) > 0
        money_delta = save["currencies"]["money"] - money0
        print(json.dumps({"ops": len(j.order), "committed": len(committed), "sells": len(sells), "earned_receipts": earned, "first_catch": first_catch,
                          "buys": len(buys), "loot_opens": len(loots), "money_delta": money_delta, "save_version": save["save_version"],
                          "unacked_at_crash": sum(1 for o in j.ops.values() if o.get("was_pending"))}, ensure_ascii=False))
        db.close()
    finally:
        st.stop()
    for k, v in checks.items():
        print(("CHECK PASS " if v else "CHECK FAIL ") + k)
    ok = all(checks.values())
    print("SAVE03_OK" if ok else "SAVE03_FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
