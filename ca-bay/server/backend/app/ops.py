"""Bộ xử lý giao dịch bền vững (07 §6.2, §7; 08 §3).

Thứ tự mọi mutation: xác thực dịch vụ/lease → tra op ledger → BEGIN IMMEDIATE → kiểm version
→ tính ở server → cập nhật mọi bảng → lưu kết quả → COMMIT → trả receipt.
Client không bao giờ gửi giá, tiền, sát thương, phần thưởng hay kết quả RNG.
"""
from __future__ import annotations

import hashlib
import json
import secrets
import sqlite3
import uuid
from dataclasses import dataclass
from typing import Callable

from . import save as save_mod
from .content import Catalog
from .db import immediate, iso_now, now_s


class OpError(Exception):
    def __init__(self, code: str, detail: str = ""):
        super().__init__(code)
        self.code = code
        self.detail = detail


@dataclass
class OpContext:
    conn: sqlite3.Connection
    cat: Catalog
    account_id: str
    room_id: str | None
    op_id: str
    save: dict
    receipt: dict
    events: list


# Thao tác do room server tự khởi tạo (không đến từ ý định client) — được phép không có expected_save_version.
SERVER_OPS = {"cooking.recover", "bait.consume", "quest.talk", "quest.refill", "npc.gift", "boss.reward", "boss.refund", "tool.consume_ammo",
              "tutorial.done", "inventory.recover_escrow", "quest.progress_catch"}
# Thao tác vẫn phải chạy dù lease đã hết (bảo vệ tiến trình: hoàn mồi, trả đồ về inbox).
LEASE_OPTIONAL_OPS = {"boss.refund", "inventory.recover_escrow"}

RNG: Callable[[int], int] = secrets.randbelow  # test có thể thay bằng hàm xác định; không có endpoint đổi


# Trường do room server tự thêm vào payload (không phải ý định client): không tính vào hash idempotency, để gửi lại
# cùng op_id sau khi room server khởi động lại (thực thể đã mất) vẫn nhận kết quả gốc thay vì OP_PAYLOAD_MISMATCH.
SERVER_ADDED_FIELDS = {"inventory.pickup": ("fresh_item",), "inventory.drop": ("room_id",)}


def payload_hash(op_type: str, payload: dict, expected_save_version) -> str:
    drop = SERVER_ADDED_FIELDS.get(op_type, ())
    intent = {k: v for k, v in payload.items() if k not in drop} if drop else payload
    canon = json.dumps({"t": op_type, "p": intent, "v": expected_save_version}, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(canon.encode()).hexdigest()


def load_save(conn: sqlite3.Connection, account_id: str) -> tuple[dict, int]:
    row = conn.execute("SELECT state_json, save_version FROM account_saves WHERE account_id=?", (account_id,)).fetchone()
    if row is None:
        raise OpError("AUTH_REQUIRED", "không có save")
    return json.loads(row["state_json"]), int(row["save_version"])


def write_save(conn: sqlite3.Connection, save: dict) -> None:
    conn.execute("UPDATE account_saves SET save_version=?, state_json=?, updated_at=? WHERE account_id=?",
                 (save["save_version"], json.dumps(save, ensure_ascii=False, separators=(",", ":")), save["updated_at"], save["account_id"]))


def commit(conn: sqlite3.Connection, cat: Catalog, *, account_id: str, op_id: str, op_type: str,
           payload: dict, expected_save_version: int | None, lease_epoch: int | None, room_id: str | None) -> dict:
    """Thực thi một op nguyên tử. Luôn trả dict kết quả (committed/rejected); kết quả được lưu theo op_id."""
    if op_type not in HANDLERS:
        return _result("rejected", op_id, "INVALID_PAYLOAD", None, None)
    try:
        uuid.UUID(op_id)
    except ValueError:
        return _result("rejected", op_id, "INVALID_PAYLOAD", None, None)
    if op_type not in SERVER_OPS and expected_save_version is None:
        return _result("rejected", op_id, "INVALID_PAYLOAD", None, None)
    phash = payload_hash(op_type, payload, expected_save_version)
    with immediate(conn):
        prev = conn.execute("SELECT payload_hash, result_json FROM operations WHERE account_id=? AND op_id=?", (account_id, op_id)).fetchone()
        if prev is not None:
            if prev["payload_hash"] != phash:
                return _result("rejected", op_id, "OP_PAYLOAD_MISMATCH", None, None)
            stored = json.loads(prev["result_json"])
            if stored.get("expired"):
                return _result("rejected", op_id, "OP_EXPIRED", None, None)
            stored["replayed"] = True
            if op_type == "boss.summon" and stored.get("status") == "committed":
                # Gửi lại lệnh gọi boss: chỉ được mở trận khi lượt gọi đó chưa từng diễn ra (mất phản hồi lần đầu) —
                # trận còn "open" và thuộc đúng phòng này. Trận đã thắng/hoàn mồi thì không mở lại (chống gọi boss miễn phí).
                enc = (stored.get("receipt") or {}).get("encounter_id")
                att = conn.execute("SELECT status, room_id FROM boss_attempts WHERE encounter_id=?", (enc,)).fetchone() if enc else None
                stored["encounter_open"] = bool(att is not None and att["status"] == "open" and room_id is not None and att["room_id"] == room_id)
            return stored
        if op_type not in LEASE_OPTIONAL_OPS:
            lease = conn.execute("SELECT epoch, active, room_id FROM gameplay_leases WHERE account_id=?", (account_id,)).fetchone()
            if lease is None or not lease["active"]:
                return _store(conn, account_id, op_id, op_type, phash, _result("rejected", op_id, "LEASE_EXPIRED", None, None))
            if lease_epoch is None or int(lease["epoch"]) != int(lease_epoch):
                return _store(conn, account_id, op_id, op_type, phash, _result("rejected", op_id, "SESSION_TAKEN_OVER", None, None))
            if room_id is not None and lease["room_id"] != room_id:
                return _store(conn, account_id, op_id, op_type, phash, _result("rejected", op_id, "LEASE_EXPIRED", None, None))
        save, version = load_save(conn, account_id)
        if expected_save_version is not None and int(expected_save_version) != version:
            res = _result("rejected", op_id, "SAVE_CONFLICT", version, None)
            res["save"] = save
            return _store(conn, account_id, op_id, op_type, phash, res)
        work = save_mod.clone(save)
        ctx = OpContext(conn, cat, account_id, room_id, op_id, work, {}, [])
        conn.execute("SAVEPOINT op")
        try:
            HANDLERS[op_type](ctx, payload)
            errs = save_mod.invariant_errors(cat, work) + save_mod.schema_errors(work)
            if errs:
                raise OpError("INVALID_PAYLOAD", "; ".join(errs[:3]))
        except OpError as e:
            conn.execute("ROLLBACK TO op")
            conn.execute("RELEASE op")
            res = _result("rejected", op_id, e.code, version, None)
            return _store(conn, account_id, op_id, op_type, phash, res)
        conn.execute("RELEASE op")
        work["save_version"] = version + 1
        work["updated_at"] = iso_now()
        write_save(conn, work)
        res = _result("committed", op_id, None, version + 1, ctx.receipt)
        res["events"] = ctx.events
        res["save"] = work
        return _store(conn, account_id, op_id, op_type, phash, res)


def _result(status, op_id, error_code, save_version, receipt) -> dict:
    return {"status": status, "op_id": op_id, "error_code": error_code, "save_version": save_version, "receipt": receipt}


def _store(conn, account_id, op_id, op_type, phash, res) -> dict:
    stored = {k: v for k, v in res.items() if k != "save"}
    conn.execute("INSERT INTO operations(account_id, op_id, op_type, payload_hash, result_json, committed_at) VALUES (?,?,?,?,?,?)",
                 (account_id, op_id, op_type, phash, json.dumps(stored, ensure_ascii=False), now_s()))
    return res


def expire_old_operations(conn: sqlite3.Connection, retention_days: int) -> int:
    """Giữ dấu op_id vĩnh viễn nhưng xóa kết quả sau cửa sổ: retry quá hạn nhận OP_EXPIRED, không chạy lại."""
    cutoff = now_s() - retention_days * 86400
    with immediate(conn):
        cur = conn.execute("UPDATE operations SET result_json='{\"expired\":true}' WHERE committed_at < ? AND result_json != '{\"expired\":true}'", (cutoff,))
        return cur.rowcount


# ---------------------------------------------------------------- tiện ích

def _get(d: dict, key: str, typ, required: bool = True):
    if key not in d:
        if required:
            raise OpError("INVALID_PAYLOAD", f"thiếu {key}")
        return None
    v = d[key]
    if typ is int and isinstance(v, bool):
        raise OpError("INVALID_PAYLOAD", key)
    if not isinstance(v, typ):
        raise OpError("INVALID_PAYLOAD", key)
    return v


def _bag_find(save: dict, uid: str) -> dict | None:
    for it in save["inventory"]["bag"]:
        if it["uid"] == uid:
            return it
    return None


def _registry(ctx: OpContext, uid: str):
    return ctx.conn.execute("SELECT * FROM item_registry WHERE item_uid=?", (uid,)).fetchone()


def _set_state(ctx: OpContext, uid: str, state: str, room_id=None, station_id=None) -> None:
    ctx.conn.execute("UPDATE item_registry SET state=?, room_id=?, station_id=?, state_since=? WHERE item_uid=?",
                     (state, room_id, station_id, now_s(), uid))


def _new_item(ctx: OpContext, def_kind: str, def_id: str, flags: list[str]) -> dict:
    it = {
        "uid": str(uuid.uuid4()),
        "owner_account_id": ctx.account_id,
        "caught_by_account_id": None,
        "def_kind": def_kind,
        "def_id": def_id,
        "variant_id": None,
        "base_value": 0,
        "trick_mult_milli": 1000,
        "cook_level": "raw",
        "flags": flags,
        "created_at": iso_now(),
    }
    ctx.conn.execute("INSERT INTO item_registry(item_uid, owner_account_id, def_kind, def_id, state, state_since, instance_json) VALUES (?,?,?,?,?,?,?)",
                     (it["uid"], ctx.account_id, def_kind, def_id, "bag", now_s(), json.dumps(it)))
    return it


def _give_item(ctx: OpContext, it: dict) -> str:
    """Thêm vào túi; túi đầy thì vào recovery inbox (không mất đồ nhiệm vụ)."""
    cap = save_mod.bag_capacity(ctx.cat, ctx.save)
    if len(ctx.save["inventory"]["bag"]) < cap:
        ctx.save["inventory"]["bag"].append(it)
        return "bag"
    ctx.save["inventory"]["recovery_inbox"].append(it)
    _set_state(ctx, it["uid"], "inbox")
    return "inbox"


def item_value(cat: Catalog, it: dict) -> int:
    v = int(it["base_value"]) * int(it["trick_mult_milli"]) // 1000
    if it.get("cook_level") == "burnt":
        v = v * int(round(float(cat.balance["cooking"]["burnt_mult"]) * 1000)) // 1000
    return max(0, v)


def _add_money(ctx: OpContext, amount: int, reason: str) -> None:
    old = ctx.save["currencies"]["money"]
    ctx.save["currencies"]["money"] = old + amount
    if ctx.save["currencies"]["money"] > 2147483647:
        raise OpError("INVALID_PAYLOAD", "tràn tiền")
    ctx.events.append({"name": "economy.money_changed", "payload": {"old": old, "new": ctx.save["currencies"]["money"], "delta": amount, "reason": reason}})


def _grant(ctx: OpContext, kind: str, gid: str, amount: int) -> None:
    inv = ctx.save["inventory"]
    cat = ctx.cat
    if kind == "bait":
        if gid not in cat.baits:
            raise OpError("INVALID_PAYLOAD", gid)
        if cat.baits[gid].get("infinite"):
            return
        inv["bait_counts"][gid] = int(inv["bait_counts"].get(gid, 0)) + amount
    elif kind == "tool":
        tool = cat.tools[gid]
        if gid not in inv["tools_owned"]:
            inv["tools_owned"].append(gid)
        if tool.get("ammo", {}).get("recover") == "buy":
            ammo = inv.setdefault("tool_ammo", {})
            ammo[gid] = min(999, int(ammo.get(gid, 0)) + amount)
    elif kind == "rod":
        if gid not in inv["rods_owned"]:
            inv["rods_owned"].append(gid)
    elif kind == "item":
        item = cat.items[gid]
        if item["kind"] == "consumable":
            inv["food_counts"][gid] = int(inv["food_counts"].get(gid, 0)) + amount
        else:
            for _ in range(amount):
                _give_item(ctx, _new_item(ctx, "item", gid, list(item.get("flags", []))))
    elif kind == "money":
        _add_money(ctx, amount, "reward")
    else:
        raise OpError("INVALID_PAYLOAD", f"kind {kind}")


# ---------------------------------------------------------------- túi đồ

def op_pickup(ctx: OpContext, p: dict) -> None:
    uid = _get(p, "item_uid", str)
    fresh = p.get("fresh_item")
    reg = _registry(ctx, uid)
    inv = ctx.save["inventory"]
    cap = save_mod.bag_capacity(ctx.cat, ctx.save)
    if reg is not None:
        # Nhặt lại vật đã thả (escrow) hoặc lấy từ inbox. Chỉ chủ sở hữu.
        if reg["owner_account_id"] != ctx.account_id:
            raise OpError("ITEM_NOT_OWNED")
        if reg["state"] not in ("escrow", "inbox"):
            raise OpError("ITEM_ALREADY_CLAIMED")
        if reg["state"] == "escrow" and ctx.room_id is not None and reg["room_id"] != ctx.room_id:
            raise OpError("OUT_OF_RANGE")
        if len(inv["bag"]) >= cap:
            raise OpError("INVENTORY_FULL")
        it = json.loads(reg["instance_json"])
        if reg["state"] == "inbox":
            inv["recovery_inbox"] = [i for i in inv["recovery_inbox"] if i["uid"] != uid]
        inv["bag"].append(it)
        _set_state(ctx, uid, "bag")
        ctx.receipt = {"item_uid": uid, "source": reg["state"]}
        return
    if not isinstance(fresh, dict):
        raise OpError("ITEM_ALREADY_CLAIMED")
    # Cá mới do room server xác thực: kiểm lại mọi thành phần giá với catalog (phòng thủ nhiều lớp).
    cre = ctx.cat.creatures.get(fresh.get("def_id", ""))
    if cre is None or cre.get("is_boss") or fresh.get("def_kind") != "creature":
        raise OpError("INVALID_PAYLOAD", "def_id")
    variant = fresh.get("variant_id")
    mult = 1
    if variant is not None:
        vs = {v["variant_id"]: v for v in cre.get("variants", [])}
        if variant not in vs:
            raise OpError("INVALID_PAYLOAD", "variant")
        mult = int(vs[variant]["value_mult"])
    base_value = int(cre["base_value"]) * mult
    tmm = fresh.get("trick_mult_milli")
    cap_milli = int(round(float(ctx.cat.balance["scoring"]["max_total_multiplier"]) * 1000))
    if not isinstance(tmm, int) or isinstance(tmm, bool) or not 1000 <= tmm <= cap_milli:
        raise OpError("INVALID_PAYLOAD", "trick_mult_milli")
    tricks = fresh.get("tricks", [])
    if not isinstance(tricks, list) or any(t not in ctx.cat.tricks for t in tricks):
        raise OpError("INVALID_PAYLOAD", "tricks")
    if len(inv["bag"]) >= cap:
        raise OpError("INVENTORY_FULL")
    it = {
        "uid": uid,
        "owner_account_id": ctx.account_id,
        "caught_by_account_id": ctx.account_id,
        "def_kind": "creature",
        "def_id": cre["id"],
        "variant_id": variant,
        "base_value": base_value,
        "trick_mult_milli": tmm,
        "cook_level": "raw",
        "flags": [],
        "created_at": iso_now(),
    }
    try:
        ctx.conn.execute("INSERT INTO item_registry(item_uid, owner_account_id, def_kind, def_id, state, room_id, state_since, instance_json) VALUES (?,?,?,?,?,?,?,?)",
                         (uid, ctx.account_id, "creature", cre["id"], "bag", ctx.room_id, now_s(), json.dumps(it)))
    except sqlite3.IntegrityError:
        raise OpError("ITEM_ALREADY_CLAIMED")
    inv["bag"].append(it)
    col = ctx.save["collection"]["species"]
    is_new = cre["id"] not in col
    entry = col.setdefault(cre["id"], {"caught": 0, "best_value": 0, "variants_seen": []})
    entry["caught"] += 1
    entry["best_value"] = max(entry["best_value"], item_value(ctx.cat, it))
    if variant and variant not in entry["variants_seen"]:
        entry["variants_seen"].append(variant)
        ctx.events.append({"name": "dex.new_variant", "payload": {"creature_def_id": cre["id"], "variant_id": variant}})
    for t in tricks:
        if t not in ctx.save["collection"]["tricks_seen"]:
            ctx.save["collection"]["tricks_seen"].append(t)
    if is_new:
        ctx.events.append({"name": "dex.new_species", "payload": {"creature_def_id": cre["id"]}})
        bonus = int(ctx.cat.balance["economy"]["first_catch_bonus"])
        if bonus > 0:
            _add_money(ctx, bonus, "first_catch")
    ctx.receipt = {"item_uid": uid, "value": item_value(ctx.cat, it), "new_species": is_new}


def op_drop(ctx: OpContext, p: dict) -> None:
    uid = _get(p, "item_uid", str)
    it = _bag_find(ctx.save, uid)
    if it is None:
        raise OpError("ITEM_NOT_OWNED")
    if ctx.room_id is None:
        raise OpError("INVALID_PAYLOAD", "room")
    ctx.save["inventory"]["bag"] = [i for i in ctx.save["inventory"]["bag"] if i["uid"] != uid]
    _set_state(ctx, uid, "escrow", room_id=ctx.room_id)
    ctx.receipt = {"item_uid": uid, "item": it}


def op_recover_escrow(ctx: OpContext, p: dict) -> None:
    """Chủ rời room / room đóng: đồ đã thả trả về recovery inbox đúng một lần."""
    room_id = _get(p, "room_id", str)
    rows = ctx.conn.execute("SELECT * FROM item_registry WHERE owner_account_id=? AND state='escrow' AND room_id=?", (ctx.account_id, room_id)).fetchall()
    moved = []
    for r in rows:
        it = json.loads(r["instance_json"])
        ctx.save["inventory"]["recovery_inbox"].append(it)
        _set_state(ctx, it["uid"], "inbox")
        moved.append(it["uid"])
    ctx.receipt = {"moved": moved}


def op_sell(ctx: OpContext, p: dict) -> None:
    uids = _get(p, "item_uids", list)
    shop_id = _get(p, "shop_id", str)
    shop = ctx.cat.shops.get(shop_id)
    if shop is None or not uids or len(set(uids)) != len(uids):
        raise OpError("INVALID_PAYLOAD")
    buys = shop.get("buys", {})
    total = 0
    own_fish = 0
    sold = []
    for uid in uids:
        it = _bag_find(ctx.save, uid)
        if it is None:
            raise OpError("ITEM_NOT_OWNED")
        if it["def_kind"] not in buys.get("accepts_kinds", []):
            raise OpError("INVALID_PAYLOAD", "không mua loại này")
        flags = set(it.get("flags", []))
        if it["def_kind"] == "item":
            flags |= set(ctx.cat.items[it["def_id"]].get("flags", []))
        if flags & set(buys.get("reject_flags", [])):
            raise OpError("INVALID_PAYLOAD", "no_sell")
        v = item_value(ctx.cat, it)
        total += v
        if it["def_kind"] == "creature" and it.get("caught_by_account_id") == ctx.account_id and not ctx.cat.creatures[it["def_id"]].get("is_boss"):
            own_fish += 1
        sold.append({"item_uid": uid, "def_id": it["def_id"], "value": v})
    ctx.save["inventory"]["bag"] = [i for i in ctx.save["inventory"]["bag"] if i["uid"] not in set(uids)]
    for uid in uids:
        _set_state(ctx, uid, "sold")
    _add_money(ctx, total, "sell")
    lp = ctx.save["lootbox_progress"]
    lp["valid_owned_fish_sales_total"] += own_fish
    per = int(ctx.cat.lootboxes["earning"]["owned_creatures_per_ticket"])
    milestones = lp["valid_owned_fish_sales_total"] // per
    new_tickets = (milestones - lp["fish_sale_ticket_milestones_awarded"]) * int(ctx.cat.lootboxes["earning"]["tickets_per_owned_creatures_sold"])
    lp["fish_sale_ticket_milestones_awarded"] = milestones
    if new_tickets > 0:
        ctx.save["currencies"]["festival_ticket"] += new_tickets
    for s in sold:
        ctx.events.append({"name": "economy.item_sold", "payload": {"item_uid": s["item_uid"], "def_id": s["def_id"], "value": s["value"], "npc_id": shop["npc_id"]}})
    ctx.receipt = {"total": total, "sold": sold, "tickets_awarded": max(0, new_tickets)}


def op_buy(ctx: OpContext, p: dict) -> None:
    shop_id = _get(p, "shop_id", str)
    entry_id = _get(p, "entry_id", str)
    qty = _get(p, "quantity", int)
    if not 1 <= qty <= 10:
        raise OpError("INVALID_PAYLOAD", "quantity")
    shop = ctx.cat.shops.get(shop_id)
    entry = next((e for e in (shop or {}).get("entries", []) if e["entry_id"] == entry_id), None)
    if entry is None:
        raise OpError("INVALID_PAYLOAD", "entry")
    g = entry["grant"]
    inv = ctx.save["inventory"]
    if entry.get("max_purchases") == 1 or g["kind"] in ("rod", "upgrade"):
        qty = 1
    if g["kind"] == "tool" and g["id"] in inv["tools_owned"] and ctx.cat.tools[g["id"]].get("ammo", {}).get("recover") != "buy":
        raise OpError("ALREADY_OWNED")
    if g["kind"] == "rod" and g["id"] in inv["rods_owned"]:
        raise OpError("ALREADY_OWNED")
    if g["kind"] == "upgrade":
        cur = int(inv["upgrades"].get(g["id"], 0))
        if cur >= int(g["level"]):
            raise OpError("ALREADY_OWNED")
        if cur != int(g["level"]) - 1:
            raise OpError("UNLOCK_REQUIRED")
    if g["kind"] == "item" and g["id"] == "item_rice_ball":
        max_free = int(ctx.cat.hunger["free_food_max_owned"])
        if int(inv["food_counts"].get("item_rice_ball", 0)) + qty > max_free:
            raise OpError("ALREADY_OWNED", "free_limit")
    if g["kind"] == "tool" and ctx.cat.tools[g["id"]].get("ammo", {}).get("recover") == "buy":
        cap = int(ctx.cat.tools[g["id"]]["ammo"]["max"])
        if int(inv.get("tool_ammo", {}).get(g["id"], 0)) >= cap:
            raise OpError("ALREADY_OWNED", "ammo_full")
    price = int(entry["price"]) * qty
    if ctx.save["currencies"]["money"] < price:
        raise OpError("INSUFFICIENT_FUNDS")
    if price:
        _add_money(ctx, -price, "buy")
    if g["kind"] == "upgrade":
        inv["upgrades"][g["id"]] = int(g["level"])
        if g["id"] == "upg_backpack":
            inv["capacity"] = save_mod.bag_capacity(ctx.cat, ctx.save)
    else:
        amount = int(g.get("amount", 1)) * qty
        if g["kind"] == "tool" and ctx.cat.tools[g["id"]].get("ammo", {}).get("recover") == "buy":
            cap = int(ctx.cat.tools[g["id"]]["ammo"]["max"])
            amount = min(amount, cap - int(inv.get("tool_ammo", {}).get(g["id"], 0)))
        _grant(ctx, g["kind"], g["id"], amount)
    ctx.events.append({"name": "economy.purchase_succeeded", "payload": {"shop_id": shop_id, "entry_id": entry_id, "price": price}})
    ctx.receipt = {"shop_id": shop_id, "entry_id": entry_id, "price": price, "quantity": qty}


def op_food(ctx: OpContext, p: dict) -> None:
    item_id = _get(p, "item_id", str)
    food = next((f for f in ctx.cat.hunger["foods"] if f["item_id"] == item_id), None)
    if food is None:
        raise OpError("INVALID_PAYLOAD", "food")
    inv = ctx.save["inventory"]
    if int(inv["food_counts"].get(item_id, 0)) <= 0:
        raise OpError("ITEM_NOT_OWNED")
    pl = ctx.save["player"]
    if not ctx.cat.hunger.get("consume_at_full", False) and pl["hunger"] >= float(ctx.cat.hunger["clamp_max"]):
        raise OpError("ALREADY_CLAIMED", "full")
    inv["food_counts"][item_id] -= 1
    prev = pl["hunger"]
    pl["hunger"] = min(float(ctx.cat.hunger["clamp_max"]), prev + float(food["restore"]))
    pl["hp"] = min(float(ctx.cat.balance["player"]["max_hp"]), pl["hp"] + float(food.get("heal_hp", 0)))
    ctx.events.append({"name": "hunger.ate", "payload": {"item_id": item_id, "player_id": ctx.account_id}})
    ctx.receipt = {"item_id": item_id, "hunger": pl["hunger"], "previous": prev, "hp": pl["hp"]}


def op_cook_start(ctx: OpContext, p: dict) -> None:
    uid = _get(p, "item_uid", str)
    station = _get(p, "station_id", str)
    it = _bag_find(ctx.save, uid)
    if it is None:
        raise OpError("ITEM_NOT_OWNED")
    if it["def_kind"] != "creature" or it["cook_level"] != "raw":
        raise OpError("INVALID_PAYLOAD", "not cookable")
    if station not in ctx.cat.shops:
        raise OpError("INVALID_PAYLOAD", "station")
    # Con đang nằm trên bếp (bị quên, mất kết nối, đổi máy) được giải quyết trước — không bao giờ khóa bếp vĩnh viễn.
    _resolve_cooking(ctx)
    ctx.save["inventory"]["bag"] = [i for i in ctx.save["inventory"]["bag"] if i["uid"] != uid]
    _set_state(ctx, uid, "cooking", room_id=ctx.room_id, station_id=station)
    ctx.events.append({"name": "cooking.started", "payload": {"item_uid": uid, "station_id": station}})
    ctx.receipt = {"item_uid": uid, "cook_time_s": ctx.cat.balance["cooking"]["cook_time_s"]}


def _cook_outcome(ctx: OpContext, reg, elapsed: float) -> str:
    """Kết quả một cá đang nằm trên bếp theo thời gian đã nướng: raw (trả cá sống), cooked (thêm cá nướng), burnt."""
    ck = ctx.cat.balance["cooking"]
    uid = reg["item_uid"]
    it = json.loads(reg["instance_json"])
    if elapsed < float(ck["cook_time_s"]):
        _set_state(ctx, uid, "bag")
        _give_item(ctx, it)
        return "raw"
    if elapsed <= float(ck["burn_time_s"]):
        _set_state(ctx, uid, "consumed")
        ctx.save["inventory"]["food_counts"]["item_grilled_fish"] = int(ctx.save["inventory"]["food_counts"].get("item_grilled_fish", 0)) + 1
        return "cooked"
    it["cook_level"] = "burnt"
    ctx.conn.execute("UPDATE item_registry SET instance_json=? WHERE item_uid=?", (json.dumps(it), uid))
    _set_state(ctx, uid, "bag")
    _give_item(ctx, it)
    return "burnt"


def _resolve_cooking(ctx: OpContext) -> int:
    rows = ctx.conn.execute("SELECT * FROM item_registry WHERE owner_account_id=? AND state='cooking'", (ctx.account_id,)).fetchall()
    for reg in rows:
        level = _cook_outcome(ctx, reg, now_s() - int(reg["state_since"]))
        ctx.events.append({"name": "cooking.level_changed", "payload": {"item_uid": reg["item_uid"], "level": level}})
    return len(rows)


def op_cook_recover(ctx: OpContext, p: dict) -> None:
    """Room server gọi khi người chơi vào phòng mới: cá còn trên bếp từ phiên trước được trả/nướng xong theo thời gian."""
    n = _resolve_cooking(ctx)
    if n == 0:
        raise OpError("ALREADY_CLAIMED", "không có gì trên bếp")
    ctx.receipt = {"resolved": n}


def op_cook_collect(ctx: OpContext, p: dict) -> None:
    """Chín: đổi đúng một cá thành một phần cá nướng. Cháy: trả cá về túi ở trạng thái cháy (bán rẻ)."""
    uid = _get(p, "item_uid", str)
    station = _get(p, "station_id", str)
    reg = _registry(ctx, uid)
    if reg is None or reg["owner_account_id"] != ctx.account_id or reg["state"] != "cooking" or reg["station_id"] != station:
        raise OpError("ITEM_NOT_OWNED")
    elapsed = now_s() - int(reg["state_since"])
    if elapsed < float(ctx.cat.balance["cooking"]["cook_time_s"]):
        raise OpError("COOLDOWN", "chưa chín")
    level = _cook_outcome(ctx, reg, elapsed)
    ctx.events.append({"name": "cooking.level_changed", "payload": {"item_uid": uid, "level": level}})
    ctx.receipt = {**ctx.receipt, "item_uid": uid, "level": level}


def op_equip(ctx: OpContext, p: dict) -> None:
    eid = _get(p, "equipment_id", str)
    inv = ctx.save["inventory"]
    if eid in inv["rods_owned"]:
        inv["equipped_rod_id"] = eid
        inv["equipped_id"] = eid
    elif eid in inv["tools_owned"]:
        inv["equipped_id"] = eid
    else:
        raise OpError("ITEM_NOT_OWNED")
    ctx.receipt = {"equipped_id": eid}


def op_bait_select(ctx: OpContext, p: dict) -> None:
    bid = _get(p, "bait_id", str)
    bait = ctx.cat.baits.get(bid)
    if bait is None:
        raise OpError("INVALID_PAYLOAD")
    if not bait.get("infinite") and int(ctx.save["inventory"]["bait_counts"].get(bid, 0)) <= 0:
        raise OpError("ITEM_NOT_OWNED")
    ctx.save["inventory"]["selected_bait_id"] = bid
    ctx.receipt = {"bait_id": bid}


def op_bait_consume(ctx: OpContext, p: dict) -> None:
    """Mồi bị ăn khi cá dính câu (consumed_on=hook). Mồi vô hạn không trừ."""
    bid = _get(p, "bait_id", str)
    bait = ctx.cat.baits.get(bid)
    if bait is None:
        raise OpError("INVALID_PAYLOAD")
    if bait.get("infinite"):
        ctx.receipt = {"bait_id": bid, "remaining": None}
        return
    counts = ctx.save["inventory"]["bait_counts"]
    if int(counts.get(bid, 0)) <= 0:
        raise OpError("ITEM_NOT_OWNED")
    counts[bid] -= 1
    if counts[bid] == 0 and ctx.save["inventory"]["selected_bait_id"] == bid:
        ctx.save["inventory"]["selected_bait_id"] = "bait_bread"
    ctx.receipt = {"bait_id": bid, "remaining": counts[bid]}


def op_consume_ammo(ctx: OpContext, p: dict) -> None:
    tid = _get(p, "tool_id", str)
    ammo = ctx.save["inventory"].setdefault("tool_ammo", {})
    if int(ammo.get(tid, 0)) <= 0:
        raise OpError("ITEM_NOT_OWNED")
    ammo[tid] -= 1
    ctx.receipt = {"tool_id": tid, "remaining": ammo[tid]}


def op_tutorial(ctx: OpContext, p: dict) -> None:
    sid = _get(p, "step_id", str)
    if not sid.isidentifier() or len(sid) > 32:
        raise OpError("INVALID_PAYLOAD")
    done = ctx.save["progress"]["tutorial_done"]
    if sid not in done:
        done.append(sid)
    ctx.receipt = {"step_id": sid}


# ---------------------------------------------------------------- nhiệm vụ

def _quest(ctx: OpContext, qid: str) -> tuple[dict, dict]:
    q = ctx.cat.quests.get(qid)
    if q is None:
        raise OpError("INVALID_PAYLOAD", "quest")
    st = ctx.save["progress"]["quests"].get(qid)
    return q, st


def _advance_if_done(ctx: OpContext, q: dict, st: dict) -> None:
    while st["step_index"] < len(q["steps"]):
        step = q["steps"][st["step_index"]]
        if int(st["counts"].get(step["step_id"], 0)) >= int(step["count"]):
            st["step_index"] += 1
            ctx.events.append({"name": "quest.step_progressed", "payload": {"quest_id": q["id"], "step_id": step["step_id"], "count": int(step["count"]), "required": int(step["count"])}})
        else:
            break


def _current_step(q: dict, st: dict | None) -> dict | None:
    if st is None or st["state"] != "active" or st["step_index"] >= len(q["steps"]):
        return None
    return q["steps"][st["step_index"]]


def op_quest_accept(ctx: OpContext, p: dict) -> None:
    qid = _get(p, "quest_id", str)
    npc = _get(p, "npc_id", str)
    q, st = _quest(ctx, qid)
    if q["giver_npc_id"] != npc:
        raise OpError("INVALID_PAYLOAD", "npc")
    if st is None or st["state"] != "available":
        raise OpError("UNLOCK_REQUIRED")
    st["state"] = "active"
    ctx.events.append({"name": "quest.started", "payload": {"quest_id": qid}})
    # Nhận việc ngay khi đang nói chuyện với chính người giao: bước "nói chuyện với <người đó>" tính luôn
    # (trước đây phải bấm nói chuyện lần nữa — E2E trình duyệt thấy mục tiêu kẹt ở "(0/1)").
    step = _current_step(q, st)
    if step and step["type"] == "talk" and step["target_id"] == npc:
        st["counts"][step["step_id"]] = int(step["count"])
        _advance_if_done(ctx, q, st)
    ctx.receipt = {"quest_id": qid}


def op_quest_talk(ctx: OpContext, p: dict) -> None:
    npc = _get(p, "npc_id", str)
    progressed = []
    for qid, st in ctx.save["progress"]["quests"].items():
        q = ctx.cat.quests[qid]
        step = _current_step(q, st)
        if step and step["type"] == "talk" and step["target_id"] == npc:
            st["counts"][step["step_id"]] = int(step["count"])
            _advance_if_done(ctx, q, st)
            progressed.append(qid)
    if not progressed:
        raise OpError("ALREADY_CLAIMED", "không có bước nói chuyện")
    ctx.receipt = {"quests": progressed}


def op_quest_deliver(ctx: OpContext, p: dict) -> None:
    qid = _get(p, "quest_id", str)
    step_id = _get(p, "step_id", str)
    npc = _get(p, "npc_id", str)
    uids = _get(p, "item_uids", list)
    q, st = _quest(ctx, qid)
    step = _current_step(q, st)
    if step is None or step["step_id"] != step_id or not step["type"].startswith("deliver"):
        raise OpError("INVALID_PAYLOAD", "step")
    if step.get("deliver_to_npc_id") != npc:
        raise OpError("INVALID_PAYLOAD", "npc")
    if not uids or len(set(uids)) != len(uids):
        raise OpError("INVALID_PAYLOAD")
    need = int(step["count"]) - int(st["counts"].get(step_id, 0))
    if len(uids) > need:
        raise OpError("INVALID_PAYLOAD", "quá số lượng")
    for uid in uids:
        it = _bag_find(ctx.save, uid)
        if it is None:
            raise OpError("ITEM_NOT_OWNED")
        if it["def_id"] != step["target_id"]:
            raise OpError("INVALID_PAYLOAD", "sai loại")
    ctx.save["inventory"]["bag"] = [i for i in ctx.save["inventory"]["bag"] if i["uid"] not in set(uids)]
    for uid in uids:
        _set_state(ctx, uid, "delivered")
    st["counts"][step_id] = int(st["counts"].get(step_id, 0)) + len(uids)
    _advance_if_done(ctx, q, st)
    ctx.receipt = {"quest_id": qid, "step_id": step_id, "count": st["counts"][step_id], "required": int(step["count"])}


def op_quest_claim(ctx: OpContext, p: dict) -> None:
    qid = _get(p, "quest_id", str)
    q, st = _quest(ctx, qid)
    if st is None or st["state"] != "active" or st["step_index"] < len(q["steps"]):
        raise OpError("UNLOCK_REQUIRED")
    if st["reward_claimed"]:
        raise OpError("ALREADY_CLAIMED")
    try:
        ctx.conn.execute("INSERT INTO reward_claims(account_id, claim_key, reward_kind, created_at) VALUES (?,?,?,?)",
                         (ctx.account_id, qid, "quest_reward", now_s()))
    except sqlite3.IntegrityError:
        raise OpError("ALREADY_CLAIMED")
    for rw in q["rewards"]:
        _grant(ctx, rw["type"], rw.get("id", ""), int(rw.get("amount", 1)))
    st["reward_claimed"] = True
    st["state"] = "completed"
    lp = ctx.save["lootbox_progress"]
    tickets = 0
    if qid not in lp["quest_ticket_awarded_ids"]:
        lp["quest_ticket_awarded_ids"].append(qid)
        tickets = int(ctx.cat.lootboxes["earning"]["tickets_per_first_quest_completion"])
        ctx.save["currencies"]["festival_ticket"] += tickets
    ctx.events.append({"name": "quest.completed", "payload": {"quest_id": qid}})
    nxt = q.get("next_quest_id")
    if nxt and nxt not in ctx.save["progress"]["quests"]:
        auto = ctx.cat.quests[nxt].get("auto_start", False)
        ctx.save["progress"]["quests"][nxt] = {"state": "active" if auto else "available", "step_index": 0, "counts": {}, "reward_claimed": False}
    completed = {k for k, v in ctx.save["progress"]["quests"].items() if v["state"] == "completed"}
    unlocked = []
    for isl in ctx.cat.islands.values():
        if isl["id"] in ctx.save["progress"]["islands_unlocked"]:
            continue
        if set(isl["unlock"]["requires_quest_ids"]) <= completed:
            ctx.save["progress"]["islands_unlocked"].append(isl["id"])
            unlocked.append(isl["id"])
            ctx.events.append({"name": "progress.island_unlocked", "payload": {"island_id": isl["id"]}})
    ctx.receipt = {"quest_id": qid, "tickets": tickets, "islands_unlocked": unlocked, "next_quest_id": nxt}


def op_quest_refill(ctx: OpContext, p: dict) -> None:
    """Hết mồi boss khi đang ở bước đánh boss: NPC cấp lại (chống soft-lock)."""
    npc = _get(p, "npc_id", str)
    for qid, st in ctx.save["progress"]["quests"].items():
        q = ctx.cat.quests[qid]
        step = _current_step(q, st)
        if step and step["type"] == "defeat_boss" and step.get("refill_bait_id") and q["giver_npc_id"] == npc:
            bait = step["refill_bait_id"]
            if int(ctx.save["inventory"]["bait_counts"].get(bait, 0)) > 0:
                raise OpError("ALREADY_OWNED")
            opened = ctx.conn.execute("SELECT 1 FROM boss_attempts WHERE account_id=? AND bait_id=? AND status='open'", (ctx.account_id, bait)).fetchone()
            if opened:
                raise OpError("ALREADY_CLAIMED", "đang có trận")
            _grant(ctx, "bait", bait, 1)
            ctx.receipt = {"bait_id": bait}
            return
    raise OpError("ALREADY_CLAIMED", "không cần cấp lại")


def op_npc_gift(ctx: OpContext, p: dict) -> None:
    npc_id = _get(p, "npc_id", str)
    npc = ctx.cat.npcs.get(npc_id)
    if npc is None or "gift" not in npc:
        raise OpError("INVALID_PAYLOAD")
    flags = ctx.save["progress"]["npc_flags"].setdefault(npc_id, [])
    if "gift_given" in flags:
        raise OpError("ALREADY_CLAIMED")
    g = npc["gift"]
    _grant(ctx, g["kind"], g["id"], int(g.get("amount", 1)))
    flags.append("gift_given")
    ctx.receipt = {"npc_id": npc_id, "gift": g["id"]}


# ---------------------------------------------------------------- boss

def op_boss_summon(ctx: OpContext, p: dict) -> None:
    boss_id = _get(p, "boss_id", str)
    zone_id = _get(p, "zone_id", str)
    boss = ctx.cat.bosses.get(boss_id)
    if boss is None or boss["summon"]["zone_id"] != zone_id:
        raise OpError("INVALID_PAYLOAD", "zone")
    island = next((i for i in ctx.cat.islands.values() if any(z["zone_id"] == zone_id for z in i["zones"])), None)
    if island is None or island["id"] not in ctx.save["progress"]["islands_unlocked"]:
        raise OpError("UNLOCK_REQUIRED")
    bait = boss["summon"]["bait_id"]
    counts = ctx.save["inventory"]["bait_counts"]
    if int(counts.get(bait, 0)) <= 0:
        raise OpError("ITEM_NOT_OWNED")
    counts[bait] -= 1
    enc = str(uuid.uuid4())
    ctx.conn.execute("INSERT INTO boss_attempts(encounter_id, account_id, boss_id, bait_id, room_id, status, created_at) VALUES (?,?,?,?,?,?,?)",
                     (enc, ctx.account_id, boss_id, bait, ctx.room_id, "open", now_s()))
    ctx.receipt = {"encounter_id": enc, "boss_id": boss_id}


def op_boss_reward(ctx: OpContext, p: dict) -> None:
    enc = _get(p, "encounter_id", str)
    boss_id = _get(p, "boss_id", str)
    boss = ctx.cat.bosses.get(boss_id)
    att = ctx.conn.execute("SELECT * FROM boss_attempts WHERE encounter_id=?", (enc,)).fetchone()
    if boss is None or att is None or att["boss_id"] != boss_id or att["status"] == "refunded":
        raise OpError("INVALID_PAYLOAD", "encounter")
    try:
        ctx.conn.execute("INSERT INTO reward_claims(account_id, claim_key, reward_kind, created_at) VALUES (?,?,?,?)",
                         (ctx.account_id, enc, "boss_reward", now_s()))
    except sqlite3.IntegrityError:
        raise OpError("ALREADY_CLAIMED")
    ctx.conn.execute("UPDATE boss_attempts SET status='defeated', resolved_at=? WHERE encounter_id=? AND status='open'", (now_s(), enc))
    _add_money(ctx, int(boss["reward_base_value"]), "boss")
    placed = []
    for d in boss["drops"]:
        before_inbox = len(ctx.save["inventory"]["recovery_inbox"])
        _grant(ctx, d["kind"], d["id"], int(d["count"]))
        placed.append({"id": d["id"], "where": "inbox" if len(ctx.save["inventory"]["recovery_inbox"]) > before_inbox else "bag"})
    prog = ctx.save["progress"]
    if boss_id not in prog["bosses_defeated"]:
        prog["bosses_defeated"].append(boss_id)
    col = ctx.save["collection"]["species"].setdefault(boss["creature_id"], {"caught": 0, "best_value": 0, "variants_seen": []})
    col["caught"] += 1
    col["best_value"] = max(col["best_value"], int(boss["reward_base_value"]))
    for qid, st in prog["quests"].items():
        q = ctx.cat.quests[qid]
        step = _current_step(q, st)
        if step and step["type"] == "defeat_boss" and step["target_id"] == boss_id:
            st["counts"][step["step_id"]] = int(step["count"])
            _advance_if_done(ctx, q, st)
    ctx.events.append({"name": "boss.defeated", "payload": {"boss_id": boss_id, "reward": int(boss["reward_base_value"])}})
    ctx.receipt = {"encounter_id": enc, "money": int(boss["reward_base_value"]), "drops": placed}


def op_boss_refund(ctx: OpContext, p: dict) -> None:
    enc = _get(p, "encounter_id", str)
    att = ctx.conn.execute("SELECT * FROM boss_attempts WHERE encounter_id=?", (enc,)).fetchone()
    if att is None or att["account_id"] != ctx.account_id:
        raise OpError("INVALID_PAYLOAD", "encounter")
    if att["status"] != "open":
        raise OpError("ALREADY_CLAIMED")
    try:
        ctx.conn.execute("INSERT INTO reward_claims(account_id, claim_key, reward_kind, created_at) VALUES (?,?,?,?)",
                         (ctx.account_id, enc, "bait_refund", now_s()))
    except sqlite3.IntegrityError:
        raise OpError("ALREADY_CLAIMED")
    ctx.conn.execute("UPDATE boss_attempts SET status='refunded', resolved_at=? WHERE encounter_id=?", (now_s(), enc))
    counts = ctx.save["inventory"]["bait_counts"]
    counts[att["bait_id"]] = int(counts.get(att["bait_id"], 0)) + 1
    ctx.receipt = {"encounter_id": enc, "bait_id": att["bait_id"]}


# ---------------------------------------------------------------- hộp quà / mỹ phẩm

def op_lootbox(ctx: OpContext, p: dict) -> None:
    box_id = _get(p, "box_id", str)
    tv = _get(p, "table_version", str)
    box = ctx.cat.lootbox_records.get(box_id)
    if box is None:
        raise OpError("INVALID_PAYLOAD", "box")
    if tv != box["table_version"]:
        raise OpError("CONTENT_MISMATCH", "table_version")
    cur = ctx.save["currencies"]
    cost = int(box["ticket_cost"])
    if cur["festival_ticket"] < cost:
        raise OpError("INSUFFICIENT_TICKETS")
    before = dict(cur)
    total = int(box["total_weight"])
    roll = int(RNG(total))
    if not 0 <= roll < total:
        raise OpError("SERVER_BUSY", "rng")
    acc = 0
    chosen = None
    for e in box["entries"]:
        acc += int(e["weight"])
        if roll < acc:
            chosen = e["cosmetic_id"]
            break
    assert chosen is not None
    cur["festival_ticket"] -= cost
    owned = ctx.save["cosmetics"]["owned"]
    if chosen in owned:
        outcome, dust = "duplicate", int(box["duplicate_dust"])
        cur["cosmetic_dust"] += dust
    else:
        outcome, dust = "new", 0
        owned.append(chosen)
    lp = ctx.save["lootbox_progress"]
    b = lp["boxes"].setdefault(box_id, {"table_version": tv, "opens_total": 0})
    b["opens_total"] += 1
    b["table_version"] = tv
    receipt_id = str(uuid.uuid4())
    lp["last_receipt_id"] = receipt_id
    ctx.conn.execute(
        "INSERT INTO lootbox_receipts(receipt_id, account_id, op_id, box_id, table_version, roll, cosmetic_id, outcome, dust_granted, balance_before, balance_after, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
        (receipt_id, ctx.account_id, ctx.op_id, box_id, tv, roll, chosen, outcome, dust, json.dumps(before), json.dumps(cur), iso_now()))
    ctx.events.append({"name": "lootbox.opened", "payload": {"reward_id": chosen, "player_id": ctx.account_id, "transaction_id": receipt_id}})
    ctx.receipt = {"receipt_id": receipt_id, "box_id": box_id, "table_version": tv, "cosmetic_id": chosen, "outcome": outcome, "dust_granted": dust}


def op_cos_buy(ctx: OpContext, p: dict) -> None:
    cid = _get(p, "cosmetic_id", str)
    cos = ctx.cat.cosmetics.get(cid)
    if cos is None:
        raise OpError("INVALID_PAYLOAD")
    owned = ctx.save["cosmetics"]["owned"]
    if cid in owned:
        raise OpError("ALREADY_OWNED")
    cost = int(cos["direct_dust_cost"])
    if ctx.save["currencies"]["cosmetic_dust"] < cost:
        raise OpError("INSUFFICIENT_DUST")
    ctx.save["currencies"]["cosmetic_dust"] -= cost
    owned.append(cid)
    ctx.receipt = {"cosmetic_id": cid, "dust_spent": cost}


def op_cos_equip(ctx: OpContext, p: dict) -> None:
    eid = _get(p, "equipment_id", str)
    cid = _get(p, "cosmetic_id", str)
    cos = ctx.cat.cosmetics.get(cid)
    inv = ctx.save["inventory"]
    if cos is None or cid not in ctx.save["cosmetics"]["owned"] or cos["target_id"] != eid:
        raise OpError("ITEM_NOT_OWNED")
    if eid not in inv["tools_owned"] + inv["rods_owned"]:
        raise OpError("ITEM_NOT_OWNED")
    ctx.save["cosmetics"]["equipped"][eid] = cid
    ctx.receipt = {"equipment_id": eid, "cosmetic_id": cid}


HANDLERS: dict[str, Callable[[OpContext, dict], None]] = {
    "inventory.pickup": op_pickup,
    "inventory.drop": op_drop,
    "inventory.sell": op_sell,
    "inventory.recover_escrow": op_recover_escrow,
    "shop.buy": op_buy,
    "food.consume": op_food,
    "cooking.start": op_cook_start,
    "cooking.collect": op_cook_collect,
    "cooking.recover": op_cook_recover,
    "equipment.equip": op_equip,
    "bait.select": op_bait_select,
    "tool.consume_ammo": op_consume_ammo,
    "bait.consume": op_bait_consume,
    "tutorial.done": op_tutorial,
    "quest.accept": op_quest_accept,
    "quest.talk": op_quest_talk,
    "quest.deliver": op_quest_deliver,
    "quest.claim": op_quest_claim,
    "quest.refill": op_quest_refill,
    "npc.gift": op_npc_gift,
    "boss.summon": op_boss_summon,
    "boss.reward": op_boss_reward,
    "boss.refund": op_boss_refund,
    "lootbox.open": op_lootbox,
    "cosmetic.buy": op_cos_buy,
    "cosmetic.equip": op_cos_equip,
}
