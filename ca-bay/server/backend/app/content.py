"""Catalog nội dung phía backend: đọc đúng data/content/*.json mà Godot dùng.

content_hash phải khớp ContentDB.content_hash của Godot (shared/content/content_db.gd):
SHA256 của, với mỗi file theo tên tăng dần: "<tên>\n" + byte gốc + "\n".
"""
from __future__ import annotations

import hashlib
import json
from functools import cached_property
from pathlib import Path

CONTENT_FILES = [
    "baits.json", "balance.json", "bosses.json", "creatures.json", "hunger.json",
    "islands.json", "items.json", "lootboxes.json", "npcs.json", "quests.json",
    "rods.json", "shops.json", "spawn_tables.json", "tools.json", "tricks.json",
    "upgrades.json",
]


class Catalog:
    def __init__(self, data_dir: Path):
        self.data_dir = data_dir
        h = hashlib.sha256()
        self.raw: dict[str, dict] = {}
        for name in sorted(CONTENT_FILES):
            b = (data_dir / "content" / name).read_bytes()
            h.update(name.encode() + b"\n")
            h.update(b)
            h.update(b"\n")
            self.raw[name[:-5]] = json.loads(b.decode("utf-8"))
        self.content_hash = h.hexdigest()
        self.network = json.loads((data_dir / "contracts" / "network_contract.json").read_text(encoding="utf-8"))

    def _index(self, key: str) -> dict[str, dict]:
        return {r["id"]: r for r in self.raw[key]["records"]}

    @cached_property
    def creatures(self): return self._index("creatures")
    @cached_property
    def baits(self): return self._index("baits")
    @cached_property
    def rods(self): return self._index("rods")
    @cached_property
    def tools(self): return self._index("tools")
    @cached_property
    def items(self): return self._index("items")
    @cached_property
    def islands(self): return self._index("islands")
    @cached_property
    def quests(self): return self._index("quests")
    @cached_property
    def shops(self): return self._index("shops")
    @cached_property
    def npcs(self): return self._index("npcs")
    @cached_property
    def tricks(self): return self._index("tricks")
    @cached_property
    def bosses(self): return self._index("bosses")
    @cached_property
    def upgrades(self): return self._index("upgrades")

    @property
    def balance(self) -> dict: return self.raw["balance"]
    @property
    def hunger(self) -> dict: return self.raw["hunger"]
    @property
    def lootboxes(self) -> dict: return self.raw["lootboxes"]

    @cached_property
    def lootbox_records(self) -> dict[str, dict]:
        return {r["id"]: r for r in self.lootboxes["records"]}

    @cached_property
    def cosmetics(self) -> dict[str, dict]:
        return {c["id"]: c for c in self.lootboxes["cosmetics"]}

    @property
    def protocol_version(self) -> str:
        return self.network["protocol_version"]

    def limit(self, name: str):
        return self.network["limits"][name]

    def island_order(self) -> list[str]:
        return [i["id"] for i in sorted(self.islands.values(), key=lambda r: r["order"])]

    def first_island(self) -> dict:
        return sorted(self.islands.values(), key=lambda r: r["order"])[0]

    def spawn_zone(self, island_id: str) -> str:
        for z in self.islands[island_id]["zones"]:
            if z["kind"] == "player_spawn":
                return z["zone_id"]
        raise KeyError(island_id)


_catalog: Catalog | None = None


def get_catalog() -> Catalog:
    global _catalog
    if _catalog is None:
        from .config import settings
        _catalog = Catalog(settings.data_dir)
    return _catalog


def reset_catalog() -> None:
    global _catalog
    _catalog = None
