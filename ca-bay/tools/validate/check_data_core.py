"""Reviewed schema and content cross-reference checks carried forward from v1.
Used by the v2 wrapper; it does not run original bundled commands.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

try:
    from jsonschema import Draft202012Validator, FormatChecker
    from referencing import Registry, Resource
except ImportError:  # pragma: no cover
    sys.exit("Thiếu thư viện: chạy `pip install jsonschema` (kèm 'referencing').")

ERRORS: list[str] = []
WARNINGS: list[str] = []


def err(msg: str) -> None:
    ERRORS.append(msg)


def warn(msg: str) -> None:
    WARNINGS.append(msg)


# --------------------------------------------------------------------------- paths
def locate(args) -> tuple[Path, Path]:
    root = Path.cwd()
    docs = Path(args.docs) if args.docs else (root / "docs" if (root / "docs" / "00_START_HERE.md").exists() else root)
    data = Path(args.data) if args.data else root / "data"
    if not (docs / "00_START_HERE.md").exists():
        sys.exit(f"Không tìm thấy 00_START_HERE.md trong {docs}")
    if not (data / "schemas").exists():
        sys.exit(f"Không tìm thấy {data}/schemas")
    return docs, data


# --------------------------------------------------------------------------- schema validation
FILE_SCHEMA = {
    "content/creatures.json": "creatures", "content/baits.json": "baits", "content/rods.json": "rods",
    "content/tools.json": "tools", "content/items.json": "items", "content/islands.json": "islands",
    "content/spawn_tables.json": "spawn_tables", "content/quests.json": "quests", "content/shops.json": "shops",
    "content/npcs.json": "npcs", "content/tricks.json": "tricks", "content/bosses.json": "bosses",
    "content/upgrades.json": "upgrades", "content/balance.json": "balance",
    "contracts/events.json": "events", "contracts/asset_registry.json": "asset_registry",
    "contracts/collision_layers.json": "collision_layers", "contracts/input_actions.json": "input_actions",
    "contracts/audio_event_map.json": "audio_event_map", "contracts/vfx_event_map.json": "vfx_event_map",
    "samples/save_example.json": "save",
}


def load_json(p: Path):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        err(f"[JSON] {p}: không đọc được ({e})")
        return None


def validate_schemas(data_dir: Path) -> dict[str, object]:
    schemas = {}
    for sp in sorted((data_dir / "schemas").glob("*.schema.json")):
        s = load_json(sp)
        if s is not None:
            schemas[sp.name.replace(".schema.json", "")] = s
    registry = Registry().with_resources([(s["$id"], Resource.from_contents(s)) for s in schemas.values()])
    for s in schemas.values():
        try:
            Draft202012Validator.check_schema(s)
        except Exception as e:  # noqa: BLE001
            err(f"[SCHEMA] {s.get('$id')}: schema không hợp lệ: {e}")
    loaded: dict[str, object] = {}
    for rel, sname in FILE_SCHEMA.items():
        p = data_dir / rel
        if not p.exists():
            err(f"[DATA] Thiếu file {rel}")
            continue
        doc = load_json(p)
        if doc is None:
            continue
        loaded[rel] = doc
        v = Draft202012Validator(schemas[sname], registry=registry, format_checker=FormatChecker())
        for e in sorted(v.iter_errors(doc), key=lambda e: list(e.path)):
            loc = "/".join(str(x) for x in e.path)
            err(f"[SCHEMA] {rel} @ {loc or '(gốc)'}: {e.message}")
    # extra: every content/contract json file must be covered
    for p in list((data_dir / "content").glob("*.json")) + list((data_dir / "contracts").glob("*.json")):
        rel = f"{p.parent.name}/{p.name}"
        if rel not in FILE_SCHEMA:
            err(f"[DATA] {rel} chưa có schema trong FILE_SCHEMA")
    return {"schemas": schemas, "files": loaded}


# --------------------------------------------------------------------------- data cross references
def collect_names(schema_obj, out: set[str]) -> None:
    """Gom tên thuộc tính, khóa $defs và giá trị enum trong schema (để bỏ qua khi quét tài liệu)."""
    if isinstance(schema_obj, dict):
        for k, v in schema_obj.items():
            if k in ("properties", "$defs") and isinstance(v, dict):
                out.update(v.keys())
            if k == "enum" and isinstance(v, list):
                out.update(str(x) for x in v)
            if k == "required" and isinstance(v, list):
                out.update(v)
            collect_names(v, out)
    elif isinstance(schema_obj, list):
        for x in schema_obj:
            collect_names(x, out)


def recs(files, rel):
    d = files.get(rel) or {}
    return d.get("records", []) if isinstance(d, dict) else []


def flatten_balance(bal: dict) -> set[str]:
    keys = set()
    for sec, val in bal.items():
        if isinstance(val, dict) and sec != "meta":
            for k in val:
                keys.add(f"{sec}.{k}")
    return keys


def check_data(data_dir: Path, files: dict) -> dict:
    ids: dict[str, set[str]] = {}

    def index(kind, rel, key="id"):
        s = set()
        for r in recs(files, rel):
            rid = r.get(key)
            if rid in s:
                err(f"[DATA] ID trùng {rid} trong {rel}")
            s.add(rid)
        ids[kind] = s

    index("creature", "content/creatures.json")
    index("bait", "content/baits.json")
    index("rod", "content/rods.json")
    index("tool", "content/tools.json")
    index("item", "content/items.json")
    index("island", "content/islands.json")
    index("spawn_table", "content/spawn_tables.json")
    index("quest", "content/quests.json")
    index("shop", "content/shops.json")
    index("npc", "content/npcs.json")
    index("trick", "content/tricks.json")
    index("boss", "content/bosses.json")
    index("upgrade", "content/upgrades.json")
    zones, steps, moves, entries, variants = set(), set(), set(), set(), set()
    for isl in recs(files, "content/islands.json"):
        for z in isl.get("zones", []):
            if z["zone_id"] in zones:
                err(f"[DATA] zone trùng {z['zone_id']}")
            zones.add(z["zone_id"])
    for q in recs(files, "content/quests.json"):
        for s in q.get("steps", []):
            steps.add(s["step_id"])
    for b in recs(files, "content/bosses.json"):
        for m in b.get("moves", []):
            moves.add(m["move_id"])
    for sh in recs(files, "content/shops.json"):
        for e in sh.get("entries", []):
            entries.add(e["entry_id"])
    for c in recs(files, "content/creatures.json"):
        for v in c.get("variants", []):
            variants.add(v["variant_id"])
    ids.update(zone=zones, step=steps, move=moves, entry=entries, variant=variants)

    assets = {a["id"]: a for a in (files.get("contracts/asset_registry.json") or {}).get("assets", [])}
    events = {e["name"]: e for e in (files.get("contracts/events.json") or {}).get("events", [])}
    loc_keys = set()
    loc_text: dict[str, tuple[str, str]] = {}
    loc_path = data_dir / "loc" / "strings.csv"
    if loc_path.exists():
        with loc_path.open(encoding="utf-8") as f:
            rd = csv.DictReader(f)
            if rd.fieldnames != ["keys", "en", "vi"]:
                err(f"[LOC] strings.csv phải có cột keys,en,vi (đang là {rd.fieldnames})")
            for row in rd:
                k = row["keys"]
                if k in loc_keys:
                    err(f"[LOC] khóa trùng {k}")
                loc_keys.add(k)
                loc_text[k] = (row.get("en") or "", row.get("vi") or "")
                if not row.get("en") or not row.get("vi"):
                    err(f"[LOC] {k} thiếu bản dịch en/vi")
    else:
        err("[LOC] thiếu data/loc/strings.csv")

    def need(kind, value, where):
        if value not in ids.get(kind, set()):
            err(f"[REF] {where}: {kind} '{value}' không tồn tại")

    def need_asset(aid, where, prefix=None):
        if aid not in assets:
            err(f"[REF] {where}: tài nguyên '{aid}' không có trong asset_registry.json")
        elif prefix and not aid.startswith(prefix):
            err(f"[REF] {where}: '{aid}' phải có tiền tố {prefix}")

    # walk all *_key fields for loc
    def walk_keys(obj, where):
        if isinstance(obj, dict):
            for k, v in obj.items():
                if isinstance(v, str) and (k.endswith("_key")):
                    if v not in loc_keys:
                        err(f"[LOC] {where}: khóa dịch '{v}' không có trong strings.csv")
                elif k == "lines" and isinstance(v, dict):
                    for lk in v.values():
                        if lk not in loc_keys:
                            err(f"[LOC] {where}: khóa thoại '{lk}' không có trong strings.csv")
                else:
                    walk_keys(v, where)
        elif isinstance(obj, list):
            for x in obj:
                walk_keys(x, where)

    for rel, doc in files.items():
        if rel.startswith("content/"):
            walk_keys(doc, rel)

    for c in recs(files, "content/creatures.json"):
        w = f"creatures/{c['id']}"
        for i in c["island_ids"]:
            need("island", i, w)
        need_asset(c["assets"]["model"], w, "mdl_")
        need_asset(c["assets"]["icon"], w, "ico_")
        for v in c.get("variants", []):
            need_asset(v["accessory_asset_id"], w, "mdl_")
        if c.get("is_boss"):
            if "boss_id" not in c:
                err(f"[REF] {w}: is_boss=true nhưng thiếu boss_id")
            else:
                need("boss", c["boss_id"], w)
        if c["archetype"] in ("pincher", "biter") and "attack" not in c:
            err(f"[REF] {w}: archetype {c['archetype']} cần trường attack")
        if c["launch"]["apex_m"]["min"] > c["launch"]["apex_m"]["max"]:
            err(f"[DATA] {w}: launch.apex_m.min > max")
    for t in recs(files, "content/tricks.json"):
        en, vi = loc_text.get(t["desc_key"], ("", ""))
        if ("{value}" in en or "{value}" in vi) and "display_value" not in t:
            err(f"[LOC] tricks/{t['id']}: mô tả có {{value}} nhưng thiếu display_value")
        if (("{value}" in en) != ("{value}" in vi)):
            err(f"[LOC] tricks/{t['id']}: {{value}} có ở một ngôn ngữ nhưng thiếu ở ngôn ngữ kia")
    for b in recs(files, "content/baits.json"):
        w = f"baits/{b['id']}"
        need_asset(b["assets"]["icon"], w, "ico_")
        need_asset(b["assets"]["lure_model"], w, "mdl_")
        if "summons_boss_id" in b:
            need("boss", b["summons_boss_id"], w)
        if b["bite_time_s"]["min"] > b["bite_time_s"]["max"]:
            err(f"[DATA] {w}: bite_time_s.min > max")
    for r in recs(files, "content/rods.json"):
        need_asset(r["assets"]["model"], f"rods/{r['id']}", "mdl_")
        need_asset(r["assets"]["icon"], f"rods/{r['id']}", "ico_")
    for t in recs(files, "content/tools.json"):
        need_asset(t["assets"]["model"], f"tools/{t['id']}", "mdl_")
        need_asset(t["assets"]["icon"], f"tools/{t['id']}", "ico_")
    for it in recs(files, "content/items.json"):
        need_asset(it["assets"]["model"], f"items/{it['id']}", "mdl_")
        need_asset(it["assets"]["icon"], f"items/{it['id']}", "ico_")
    for isl in recs(files, "content/islands.json"):
        w = f"islands/{isl['id']}"
        for q in isl["unlock"]["requires_quest_ids"]:
            need("quest", q, w)
        for z in isl["zones"]:
            if "spawn_table_id" in z:
                need("spawn_table", z["spawn_table_id"], w)
            if "boss_id" in z:
                need("boss", z["boss_id"], w)
            if "shop_id" in z:
                need("shop", z["shop_id"], w)
        a = isl["assets"]
        need_asset(a["terrain"], w, "mdl_")
        need_asset(a["music"], w, "mus_")
        need_asset(a["ambience"], w, "amb_")
        need_asset(a["environment"], w, "env_")
    for s in recs(files, "content/spawn_tables.json"):
        w = f"spawn_tables/{s['id']}"
        need("creature", s["fallback_creature_id"], w)
        for e in s["entries"]:
            need("creature", e["creature_id"], w)
            for b in e["bait_ids"]:
                need("bait", b, w)
    for q in recs(files, "content/quests.json"):
        w = f"quests/{q['id']}"
        need("npc", q["giver_npc_id"], w)
        if "next_quest_id" in q:
            need("quest", q["next_quest_id"], w)
        for st in q["steps"]:
            kind = {"talk": "npc", "deliver_creature": "creature", "catch_species": "creature",
                    "deliver_item": "item", "defeat_boss": "boss"}[st["type"]]
            need(kind, st["target_id"], f"{w}/{st['step_id']}")
            if "deliver_to_npc_id" in st:
                need("npc", st["deliver_to_npc_id"], f"{w}/{st['step_id']}")
            if "refill_bait_id" in st:
                need("bait", st["refill_bait_id"], f"{w}/{st['step_id']}")
            if st["type"].startswith("deliver") and "deliver_to_npc_id" not in st:
                err(f"[REF] {w}/{st['step_id']}: bước nộp cần deliver_to_npc_id")
        for rw in q["rewards"]:
            if rw["type"] in ("bait", "tool", "item"):
                need(rw["type"], rw.get("id"), w)
    for sh in recs(files, "content/shops.json"):
        w = f"shops/{sh['id']}"
        need("npc", sh["npc_id"], w)
        for e in sh["entries"]:
            g = e["grant"]
            need(g["kind"], g["id"], f"{w}/{e['entry_id']}")
            if g["kind"] == "upgrade":
                ups = {u["id"]: u for u in recs(files, "content/upgrades.json")}
                lv = [l["level"] for l in ups.get(g["id"], {}).get("levels", [])]
                if g.get("level") not in lv:
                    err(f"[REF] {w}/{e['entry_id']}: cấp nâng cấp {g.get('level')} không tồn tại")
            if "display_asset_id" in e:
                need_asset(e["display_asset_id"], f"{w}/{e['entry_id']}")
    for n in recs(files, "content/npcs.json"):
        w = f"npcs/{n['id']}"
        need("island", n["island_id"], w)
        need_asset(n["assets"]["model"], w, "mdl_")
        need_asset(n["assets"]["voice"], w, "vo_")
        if "shop_id" in n:
            need("shop", n["shop_id"], w)
        for q in n.get("quest_ids", []):
            need("quest", q, w)
        if "gift" in n:
            need(n["gift"]["kind"], n["gift"]["id"], w)
    for b in recs(files, "content/bosses.json"):
        w = f"bosses/{b['id']}"
        need("creature", b["creature_id"], w)
        need("bait", b["summon"]["bait_id"], w)
        need("zone", b["summon"]["zone_id"], w)
        need_asset(b["assets"]["music"], w, "mus_")
        for a in b["assets"]["anims"].values():
            need_asset(a, w, "anm_")
        move_ids = set()
        for m in b["moves"]:
            move_ids.add(m["move_id"])
            if "telegraph" not in m["anims"]:
                err(f"[REF] {w}/{m['move_id']}: thiếu clip báo trước (anims.telegraph) — REQ-BOSS-002")
            for a in m["anims"].values():
                need_asset(a, f"{w}/{m['move_id']}", "anm_")
            if "projectile_asset_id" in m:
                need_asset(m["projectile_asset_id"], f"{w}/{m['move_id']}", "mdl_")
        for ph in b["phases"]:
            for mid in ph["move_weights"]:
                if mid not in move_ids:
                    err(f"[REF] {w}: phase {ph['phase']} dùng move '{mid}' không tồn tại")
        for d in b["drops"]:
            need(d["kind"], d["id"], w)
    # contracts
    for rel in ("contracts/audio_event_map.json", "contracts/vfx_event_map.json"):
        for i, rule in enumerate((files.get(rel) or {}).get("rules", [])):
            w = f"{rel}#{i}"
            ev = rule["event"]
            if ev not in events:
                err(f"[REF] {w}: sự kiện '{ev}' không có trong events.json")
            else:
                fields = {f["name"] for f in events[ev]["payload"]}
                for k in rule.get("when", {}):
                    if k not in fields:
                        err(f"[REF] {w}: điều kiện 'when.{k}' không phải trường payload của {ev}")
                for k in rule.get("params_from_payload", []):
                    if k not in fields:
                        err(f"[REF] {w}: params_from_payload '{k}' không phải trường payload của {ev}")
                if rel.endswith("audio_event_map.json") and rule.get("repeat_for_field") and rule["repeat_for_field"] not in fields:
                    err(f"[REF] {w}: repeat_for_field không phải trường payload")
                if rule.get("attach", "").startswith("creature:") and "creature_uid" not in fields:
                    err(f"[REF] {w}: gắn vào creature nhưng payload không có creature_uid")
            need_asset(rule["asset_id"], w)
    names = [e["name"] for e in (files.get("contracts/events.json") or {}).get("events", [])]
    for n in {x for x in names if names.count(x) > 1}:
        err(f"[EVENT] tên sự kiện trùng: {n}")
    layers = (files.get("contracts/collision_layers.json") or {}).get("layers", [])
    nums = [l["layer"] for l in layers]
    if len(nums) != len(set(nums)):
        err("[LAYER] số lớp va chạm bị trùng")
    for l in layers:
        for m in l["mask"]:
            if m not in nums:
                err(f"[LAYER] lớp {l['name']} có mask {m} chưa được định nghĩa")
    # asset registry sanity
    prefix_type = {"mdl": {"model"}, "mat": {"material"}, "shd": {"shader"}, "tex": {"texture"},
                   "env": {"environment"}, "vfx": {"vfx"}, "anm": {"anim_library", "anim_clip"}, "ui": {"ui"},
                   "ico": {"icon"}, "fnt": {"font"}, "sfx": {"sfx"}, "mus": {"music"}, "amb": {"ambience"},
                   "vo": {"voice"}}
    reg_list = (files.get("contracts/asset_registry.json") or {}).get("assets", [])
    reg_ids = [a["id"] for a in reg_list]
    for d in {x for x in reg_ids if reg_ids.count(x) > 1}:
        err(f"[ASSET] ID trùng trong registry: {d}")
    for a in reg_list:
        p = a["id"].split("_", 1)[0]
        if a["type"] not in prefix_type[p]:
            err(f"[ASSET] {a['id']}: type '{a['type']}' không khớp tiền tố")
        if a["type"] == "anim_clip":
            lib = Path(a["path"]).stem
            if lib not in assets:
                err(f"[ASSET] {a['id']}: thư viện {lib} chưa đăng ký")
    # save sample cross refs
    sv = files.get("samples/save_example.json") or {}
    if sv:
        need("island", sv["player"]["island_id"], "save_example/player")
        need("tool", sv["player"]["last_tool_id"], "save_example/player")
        for q in sv["progress"]["quests"]:
            need("quest", q, "save_example/progress")
        for c in sv["dex"]["species"]:
            need("creature", c, "save_example/dex")
        for t in sv["dex"]["tricks_seen"]:
            need("trick", t, "save_example/dex")
        for b in sv["inventory"]["bait_counts"]:
            need("bait", b, "save_example/inventory")
    bal = files.get("content/balance.json") or {}
    return {"ids": ids, "assets": assets, "events": events, "loc_keys": loc_keys,
            "balance_keys": flatten_balance(bal), "balance_sections": {k for k in bal if k not in ("meta", "schema_version")}}


