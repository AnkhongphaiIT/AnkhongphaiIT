"""Save v2 do server quản lý (data/schemas/account_save.schema.json).

Client chỉ nhận view của chính mình; không có đường PUT save từ client.
"""
from __future__ import annotations

import copy
import json
from functools import lru_cache

from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry, Resource

from .config import settings
from .content import Catalog
from .db import iso_now

SCHEMA_VERSION = "2.0.0"


def new_save(cat: Catalog, account_id: str, display_name: str) -> dict:
    first = cat.first_island()
    quests: dict = {}
    for q in cat.quests.values():
        if q.get("auto_start") and not _is_next_of_any(cat, q["id"]):
            quests[q["id"]] = {"state": "active", "step_index": 0, "counts": {}, "reward_claimed": False}
    bal = cat.balance
    return {
        "schema_version": SCHEMA_VERSION,
        "game_version": settings.game_version,
        "content_version": "2.0.0",
        "save_version": 1,
        "account_id": account_id,
        "updated_at": iso_now(),
        "active_playtime_s": 0,
        "profile": {"display_name": display_name},
        "currencies": {"money": int(bal["economy"]["starting_money"]), "festival_ticket": 0, "cosmetic_dust": 0},
        "player": {
            "hunger": float(cat.hunger["initial_value"]),
            "hp": float(bal["player"]["max_hp"]),
            "safe_island_id": first["id"],
            "safe_spawn_zone_id": cat.spawn_zone(first["id"]),
        },
        "inventory": {
            "capacity": int(bal["inventory"]["bag_base_slots"]),
            "bag": [],
            "recovery_inbox": [],
            "bait_counts": {},
            "food_counts": {"item_rice_ball": 1},
            "selected_bait_id": "bait_bread",
            "tools_owned": ["tool_hand"],
            "rods_owned": ["rod_bamboo"],
            "equipped_rod_id": "rod_bamboo",
            "equipped_id": "rod_bamboo",
            "upgrades": {u: 0 for u in cat.upgrades},
            "tool_ammo": {},
        },
        "progress": {
            "quests": quests,
            "bosses_defeated": [],
            "islands_unlocked": [first["id"]],
            "tutorial_done": [],
            "npc_flags": {},
        },
        "collection": {"species": {}, "tricks_seen": []},
        "cosmetics": {"owned": [], "equipped": {}},
        "lootbox_progress": {
            "valid_owned_fish_sales_total": 0,
            "fish_sale_ticket_milestones_awarded": 0,
            "quest_ticket_awarded_ids": [],
            "boxes": {b: {"table_version": r["table_version"], "opens_total": 0} for b, r in cat.lootbox_records.items()},
            "last_receipt_id": None,
        },
    }


def _is_next_of_any(cat: Catalog, quest_id: str) -> bool:
    return any(q.get("next_quest_id") == quest_id for q in cat.quests.values())


def bag_capacity(cat: Catalog, save: dict) -> int:
    base = int(cat.balance["inventory"]["bag_base_slots"])
    cap_max = int(cat.balance["inventory"]["bag_max_slots"])
    lvl = int(save["inventory"]["upgrades"].get("upg_backpack", 0))
    extra = sum(int(l["value"]) for l in cat.upgrades["upg_backpack"]["levels"] if int(l["level"]) <= lvl)
    return min(cap_max, base + extra)


@lru_cache(maxsize=1)
def _validator() -> Draft202012Validator:
    schemas = {}
    for p in (settings.data_dir / "schemas").glob("*.schema.json"):
        s = json.loads(p.read_text(encoding="utf-8"))
        schemas[s["$id"]] = s
    reg = Registry().with_resources([(k, Resource.from_contents(v)) for k, v in schemas.items()])
    main = json.loads((settings.data_dir / "schemas" / "account_save.schema.json").read_text(encoding="utf-8"))
    return Draft202012Validator(main, registry=reg, format_checker=FormatChecker())


def schema_errors(save: dict) -> list[str]:
    return [f"{'/'.join(map(str, e.path))}: {e.message}" for e in _validator().iter_errors(save)]


def invariant_errors(cat: Catalog, save: dict) -> list[str]:
    """Bất biến ngoài JSON Schema (08 §5)."""
    errs: list[str] = []
    inv = save["inventory"]
    uids = [i["uid"] for i in inv["bag"]] + [i["uid"] for i in inv["recovery_inbox"]]
    if len(uids) != len(set(uids)):
        errs.append("UID trùng trong túi/inbox")
    if len(inv["bag"]) > bag_capacity(cat, save):
        errs.append("túi vượt sức chứa")
    for it in inv["bag"] + inv["recovery_inbox"]:
        if it["owner_account_id"] != save["account_id"]:
            errs.append(f"item {it['uid']} không thuộc tài khoản")
        if it["def_kind"] == "creature" and it.get("caught_by_account_id") != save["account_id"]:
            errs.append(f"cá {it['uid']} không do tài khoản câu")
    if inv["equipped_rod_id"] not in inv["rods_owned"]:
        errs.append("equipped_rod_id không sở hữu")
    if inv["equipped_id"] not in inv["rods_owned"] + inv["tools_owned"]:
        errs.append("equipped_id không sở hữu")
    lp = save["lootbox_progress"]
    if lp["fish_sale_ticket_milestones_awarded"] != lp["valid_owned_fish_sales_total"] // int(cat.lootboxes["earning"]["owned_creatures_per_ticket"]):
        errs.append("mốc vé bán cá lệch")
    for q in lp["quest_ticket_awarded_ids"]:
        if save["progress"]["quests"].get(q, {}).get("state") != "completed":
            errs.append(f"vé quest {q} nhưng quest chưa hoàn thành")
    for k, v in save["currencies"].items():
        if v < 0:
            errs.append(f"tiền âm {k}")
    if not 0 <= save["player"]["hunger"] <= 100:
        errs.append("hunger ngoài 0..100")
    return errs


def clone(save: dict) -> dict:
    return copy.deepcopy(save)
