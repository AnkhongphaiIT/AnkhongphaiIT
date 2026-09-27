"""Đường dẫn dự án, đọc registry/strings/npcs (chỉ đọc), ghi file đầu ra + manifest."""
from __future__ import annotations

import csv
import hashlib
import json
import platform
import re
import shutil
import subprocess
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
TOOL_DIR = HERE.parent                      # tools/asset_generation/audio
ROOT = TOOL_DIR.parents[2]                  # thư mục dự án ca-bay
BUILD = TOOL_DIR / "build"                  # WAV nguồn nhạc/âm nền + TTS thô (ngoài assets/)
ASSETS_AUDIO = ROOT / "assets" / "audio"
MANIFEST_PATH = ASSETS_AUDIO / "AUDIO_MANIFEST.json"
REGISTRY_PATH = ROOT / "data" / "contracts" / "asset_registry.json"
STRINGS_PATH = ROOT / "data" / "loc" / "strings.csv"
NPCS_PATH = ROOT / "data" / "content" / "npcs.json"
AUDIO_TYPES = ("sfx", "music", "ambience", "voice")


def res_to_path(res: str) -> Path:
    assert res.startswith("res://"), res
    return ROOT / res[len("res://"):]


def path_to_res(p: Path) -> str:
    return "res://" + p.resolve().relative_to(ROOT).as_posix()


def rel(p: Path) -> str:
    return p.resolve().relative_to(ROOT).as_posix()


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_registry_audio() -> list[dict]:
    reg = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    return [a for a in reg["assets"] if a.get("type") in AUDIO_TYPES]


def expand_paths(asset: dict) -> list[tuple[str | None, str]]:
    """[(variant, res_path)] — thay {nn} bằng 01..NN theo `variants`."""
    p = asset["path"]
    if "{nn}" in p:
        n = int(asset.get("variants", 0))
        return [(f"{i:02d}", p.replace("{nn}", f"{i:02d}")) for i in range(1, n + 1)]
    return [(None, p)]


def load_strings() -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    with open(STRINGS_PATH, encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            out[row["keys"]] = {"en": row["en"], "vi": row["vi"]}
    return out


def load_npcs() -> list[dict]:
    return json.loads(NPCS_PATH.read_text(encoding="utf-8"))["records"]


def npc_lines(strings: dict, npc_id: str) -> list[str]:
    """Mọi khóa npc_<id>.* trừ .name, sắp theo tên (ổn định)."""
    pref = npc_id + "."
    return sorted(k for k in strings if k.startswith(pref) and k != pref + "name")


def cmd_version(cmd: list[str]) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        return (out.stdout or out.stderr).strip().splitlines()[0]
    except Exception as exc:  # pragma: no cover
        return f"unavailable ({exc.__class__.__name__})"


def dpkg_version(pkg: str) -> str:
    if not shutil.which("dpkg-query"):
        return "unknown"
    out = subprocess.run(["dpkg-query", "-W", "-f=${Version}", pkg], capture_output=True, text=True)
    return out.stdout.strip() or "not-installed"


def tool_versions(include_tts: bool = False, include_ffmpeg: bool = False) -> dict:
    v = {"python": platform.python_version(), "numpy": np.__version__}
    if include_ffmpeg:
        v["ffmpeg"] = re.sub(r" Copyright.*", "", cmd_version(["ffmpeg", "-version"]))
        v["libvorbis_deb"] = dpkg_version("libvorbisenc2")
    if include_tts:
        v["espeak-ng"] = cmd_version(["espeak-ng", "--version"]).split("  Data at")[0]
        v["espeak-ng_deb"] = dpkg_version("espeak-ng")
        v["espeak-ng-data_deb"] = dpkg_version("espeak-ng-data")
    return v


class Manifest:
    def __init__(self):
        self.entries: list[dict] = []

    def add(self, asset_id: str, variant, path: Path, generator: str, seed, license: str, notes: str,
            tool_versions: dict, **extra) -> dict:
        e = {
            "asset_id": asset_id,
            "variant": variant,
            "path": path_to_res(path),
            "sha256": sha256_file(path),
            "bytes": path.stat().st_size,
            "generator": generator,
            "seed": seed,
            "tool_versions": tool_versions,
            "license": license,
            "notes": notes,
        }
        e.update(extra)
        self.entries.append(e)
        return e

    def write(self, extra_meta: dict | None = None) -> None:
        ents = sorted(self.entries, key=lambda e: e["path"])
        data = {
            "schema_version": "1.0.0",
            "generated_by": "tools/asset_generation/audio/generate_all.py",
            "notes": ("Âm thanh CÁ BAY tạo offline. license=self_made: tổng hợp nguyên bản bằng numpy "
                      "(không sample/model ngoài). license=tbd: thoại TTS espeak-ng — chờ trưởng dự án "
                      "quyết định quyền thương mại (xem phân tích trong `license_analysis`)."),
            "count": len(ents),
            "files": ents,
        }
        if extra_meta:
            data.update(extra_meta)
        MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
        MANIFEST_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
