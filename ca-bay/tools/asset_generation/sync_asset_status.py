#!/usr/bin/env python3
"""Đồng bộ trạng thái tài nguyên từ FILE THẬT trên đĩa (theo docs/14 §6, §8, §9):

- data/contracts/asset_registry.json: status/license/notes theo bằng chứng (không đánh dấu approved nếu chưa có người duyệt).
- handoff/source_manifest.json: danh sách file thật + sha256 đo được + nguồn/công cụ tạo.
- reports/ASSET_COVERAGE.md: đếm theo loại × trạng thái, số file thật, voice theo dòng × ngôn ngữ.

  python3 tools/asset_generation/sync_asset_status.py [--check]   # --check: chỉ báo, không ghi
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REG = ROOT / "data/contracts/asset_registry.json"
MANIFEST = ROOT / "handoff/source_manifest.json"
AUDIO = ROOT / "assets/audio/AUDIO_MANIFEST.json"
BAKE = ROOT / "art_src/bake/bake_report.json"
TODAY = dt.date.today().isoformat()

# UI dựng bằng mã (không có file .tscn riêng): ánh xạ asset → script thực thi, kiểm bằng E2E trình duyệt.
UI_IN_CODE = {
    "ui_hud": "client/scripts/ui/hud.gd", "ui_hotbar": "client/scripts/ui/hud.gd", "ui_bag_row": "client/scripts/ui/menus.gd",
    "ui_strain_meter": "client/scripts/ui/hud.gd", "ui_tutorial_hint": "client/scripts/game/game_session.gd",
    "ui_toast": "client/scripts/ui/hud.gd", "ui_prompt": "client/scripts/ui/hud.gd", "ui_objective_line": "client/scripts/ui/hud.gd",
    "ui_trick_popup": "client/scripts/ui/hud.gd", "ui_boss_bar": "client/scripts/ui/hud.gd", "ui_dex_panel": "client/scripts/ui/menus.gd",
    "ui_pause_menu": "client/scripts/ui/menus.gd", "ui_settings_panel": "client/scripts/ui/settings_menu.gd",
    "ui_main_menu": "client/scripts/ui/client_app.gd", "ui_dialogue_bubble": "client/scripts/ui/hud.gd",
    "ui_room_lobby": "client/scripts/ui/client_app.gd", "ui_party_status": "client/scripts/ui/hud.gd",
    "ui_hunger_meter": "client/scripts/ui/hud.gd", "ui_cosmetics_panel": "client/scripts/ui/menus.gd",
    "ui_lootbox_panel": "client/scripts/ui/menus.gd",
}
OUT_OF_SCOPE = {"ui_touch_controls": "Ngoài phạm vi bản này: chỉ desktop bàn phím + chuột (không cảm ứng)."}


def res_path(p: str) -> Path:
    return ROOT / p.removeprefix("res://")


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    reg = json.loads(REG.read_text(encoding="utf-8"))
    man = json.loads(MANIFEST.read_text(encoding="utf-8"))
    audio = json.loads(AUDIO.read_text(encoding="utf-8")) if AUDIO.exists() else {"files": []}
    bake = json.loads(BAKE.read_text(encoding="utf-8")) if BAKE.exists() else {"models": {}, "icons": {}, "misc": {}}
    audio_by_id: dict[str, list[dict]] = defaultdict(list)
    for f in audio.get("files", []):
        audio_by_id[f["asset_id"]].append(f)
    man_by_id = {m["asset_id"]: m for m in man["assets"]}

    for asset in reg["assets"]:
        aid, typ, path = asset["id"], asset["type"], asset["path"]
        rec = man_by_id.setdefault(aid, {"asset_id": aid, "status": "planned", "source_record_id": None, "license": "tbd", "files": []})
        files: list[dict] = []
        status, license_, note, source = "planned", "tbd", None, None
        if typ in ("sfx", "music", "ambience", "voice"):
            for f in audio_by_id.get(aid, []):
                p = ROOT / f["path"].removeprefix("res://")
                if p.exists():
                    files.append({"path": f["path"], "bytes": p.stat().st_size, "sha256": sha(p)})
            if files:
                lic = {f.get("license", "tbd") for f in audio_by_id[aid]}
                license_ = "self_made" if lic == {"self_made"} else "tbd"
                # tự tổng hợp + đo đạt nhưng chưa có người nghe → in_review; thoại espeak (tbd) → placeholder
                status = "in_review" if license_ == "self_made" else "placeholder"
                source = "tools/asset_generation/audio/generate_all.py (numpy/ffmpeg offline)" if license_ == "self_made" else "espeak-ng 1.51 (GPL-3.0-or-later) — bản tạm, không phát hành"
        elif typ == "anim_clip":
            p = res_path(path)
            if p.exists():
                files.append({"path": path, "clip": aid, "bytes": p.stat().st_size, "sha256": sha(p)})
                status, license_, source = "in_review", "self_made", "art_src/anim (procedural keyframes)"
        elif typ == "ui" and aid in UI_IN_CODE and not res_path(path).exists():
            status, license_ = "in_review", "self_made"
            note = f"Dựng bằng mã tại {UI_IN_CODE[aid]} (không có file cảnh riêng); kiểm bằng E2E trình duyệt tests/web/scenarios/."
            source = UI_IN_CODE[aid]
        elif aid in OUT_OF_SCOPE:
            status, note = "deprecated", OUT_OF_SCOPE[aid]
        else:
            p = res_path(path)
            if p.exists():
                files.append({"path": path, "bytes": p.stat().st_size, "sha256": sha(p)})
                if typ == "font":
                    status, license_ = "approved", "OFL"
                    source = "Be Vietnam Pro (OFL 1.1), assets/fonts/SOURCES.md"
                    for extra in ("assets/fonts/BeVietnamPro-SemiBold.ttf", "assets/fonts/BeVietnamPro-Bold.ttf", "assets/fonts/ui_symbols.ttf"):
                        q = ROOT / extra
                        files.append({"path": "res://" + extra, "bytes": q.stat().st_size, "sha256": sha(q)})
                else:
                    status, license_ = "in_review", "self_made"
                    source = {"model": "art_src/bake/bake.gd ← client/scripts/visual/models.gd (procedural)",
                              "icon": "art_src/bake/bake.gd (render 256×256 từ mô hình)",
                              "shader": "viết tay trong dự án", "environment": "art_src/bake/bake.gd ← world_view.gd",
                              "material": "art_src/bake/bake.gd ← mesh_kit.gd", "ui": "art_src/bake/bake.gd ← ui_kit.gd",
                              "vfx": "art_src/vfx (procedural particles)", "anim_library": "art_src/anim (procedural keyframes)",
                              "texture": "art_src (procedural)"}.get(typ, "self_made")
        asset["status"] = status
        asset["license"] = license_
        if note:
            asset["notes"] = note
        rec["status"] = status
        rec["license"] = license_
        rec["files"] = files
        rec["source_record_id"] = f"src_{aid}" if source else None
        if source:
            rec["source"] = {"tool_or_origin": source, "author": "Claude Code (tự tạo trong dự án)" if license_ == "self_made" else None,
                             "recorded_at": TODAY}
        if typ in ("model",) and aid in bake.get("models", {}):
            rec["measure"] = {k: bake["models"][aid][k] for k in ("triangles", "size")}
        if typ == "icon" and aid in bake.get("icons", {}):
            rec["measure"] = {k: bake["icons"][aid][k] for k in ("size", "alpha")}

    # báo cáo
    by = Counter((x["type"], x["status"]) for x in reg["assets"])
    types = sorted({x["type"] for x in reg["assets"]})
    statuses = ["planned", "placeholder", "in_review", "approved", "deprecated"]
    nfiles = sum(len(m["files"]) for m in man_by_id.values())
    lines = ["# ASSET_COVERAGE — độ phủ tài nguyên (sinh tự động từ file thật)", "",
             f"Cập nhật: {TODAY} bằng `tools/asset_generation/sync_asset_status.py`. Tổng asset ID: {len(reg['assets'])}; file thật đã băm: {nfiles}.",
             "`in_review` = file thật do dự án tự tạo, đã kiểm tự động, **chưa có người duyệt bằng mắt/tai**; `placeholder` = bản tạm không phát hành; `planned` = chưa có file.", "",
             "| Loại | " + " | ".join(statuses) + " | Tổng |", "|---|" + "---|" * (len(statuses) + 1)]
    for t in types:
        row = [by.get((t, s), 0) for s in statuses]
        lines.append(f"| {t} | " + " | ".join(str(x) for x in row) + f" | {sum(row)} |")
    tot = [sum(by.get((t, s), 0) for t in types) for s in statuses]
    lines.append("| **Tổng** | " + " | ".join(f"**{x}**" for x in tot) + f" | **{sum(tot)}** |")
    vo_lines = sum(1 for f in audio.get("files", []) if f["asset_id"].startswith("vo_dialogue_") and f["path"].endswith(".wav"))
    lines += ["", f"Thoại rõ nghĩa: {vo_lines}/62 dòng × ngôn ngữ có file, **tất cả là bản tạm espeak-ng (placeholder)** → yêu cầu giọng đọc VI/EN chưa đạt (NEED-VOICE-LICENSE / voice_v1).",
              "", "Còn `planned`:", ""]
    for x in reg["assets"]:
        if x["status"] == "planned":
            lines.append(f"- `{x['id']}` ({x['type']}, {x['priority']})")
    report = "\n".join(lines) + "\n"
    if a.check:
        print(report)
        return 0
    REG.write_text(json.dumps(reg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    man["assets"] = [man_by_id[x["id"]] for x in reg["assets"]]
    man["note"] = "Sinh từ file thật bởi tools/asset_generation/sync_asset_status.py; sha256 do dự án tự đo."
    MANIFEST.write_text(json.dumps(man, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "reports/ASSET_COVERAGE.md").write_text(report, encoding="utf-8")
    print(f"SYNC_OK files={nfiles} " + " ".join(f"{s}={tot[i]}" for i, s in enumerate(statuses)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
