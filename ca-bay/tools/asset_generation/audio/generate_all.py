#!/usr/bin/env python3
"""Tạo toàn bộ âm thanh CÁ BAY (WP-09) — offline, tất định theo seed, chi phí 0.

Chạy (từ gốc dự án ca-bay):
    tools/asset_generation/audio/.venv/bin/python tools/asset_generation/audio/generate_all.py
    # hoặc python3 ...generate_all.py (tự chuyển sang .venv nếu thiếu numpy)
Tùy chọn:
    --only sfx,gib,mus,amb,vo   chỉ tạo các nhóm này (manifest giữ mục của nhóm khác)

Đầu ra: assets/audio/{sfx,vo,mus,amb}/..., assets/audio/AUDIO_MANIFEST.json,
WAV nguồn nhạc/âm nền + TTS thô trong tools/asset_generation/audio/build/.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
try:
    import numpy as np  # noqa: F401
except ImportError:  # tự chuyển sang venv riêng của công cụ
    _venv_py = _HERE / ".venv" / "bin" / "python"
    if _venv_py.exists() and Path(sys.prefix).resolve() != (_HERE / ".venv").resolve():
        os.execv(str(_venv_py), [str(_venv_py), str(Path(__file__).resolve()), *sys.argv[1:]])
    sys.exit("Thiếu numpy. Tạo venv: python3.11 -m venv tools/asset_generation/audio/.venv && "
             "tools/asset_generation/audio/.venv/bin/pip install -r tools/asset_generation/audio/requirements.txt")

import argparse  # noqa: E402
import hashlib  # noqa: E402
import json  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import time  # noqa: E402

sys.path.insert(0, str(_HERE))
from cabay_audio import ambience, dsp, music, project, sfx, tts, voice, wavio  # noqa: E402
from cabay_audio.project import Manifest, path_to_res, rel, res_to_path  # noqa: E402

GROUPS = ("sfx", "gib", "mus", "amb", "vo")
OGG_QUALITY = {"music": 5, "ambience": 4}


def stable_seed(asset_id: str, variant) -> int:
    h = hashlib.sha256(f"cabay-audio:{asset_id}:{variant or ''}".encode()).hexdigest()
    return int(h[:8], 16)


def group_of(asset: dict) -> str:
    aid = asset["id"]
    if asset["type"] == "sfx":
        return "sfx"
    if asset["type"] == "music":
        return "mus"
    if asset["type"] == "ambience":
        return "amb"
    if aid.startswith("vo_npc_gibberish_"):
        return "gib"
    if aid.startswith("vo_dialogue_"):
        return "vo"
    return "other"


def ensure_gdignore(d: Path) -> None:
    d.mkdir(parents=True, exist_ok=True)
    g = d / ".gdignore"
    if not g.exists():
        g.write_text("")


def encode_ogg(src: Path, dst: Path, quality: int) -> None:
    if not shutil.which("ffmpeg"):
        raise RuntimeError("Thiếu ffmpeg. Cài: apt-get install -y ffmpeg")
    dst.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(src), "-map_metadata", "-1",
           "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis", "-q:a", str(quality),
           "-ar", "44100", "-ac", "2", str(dst)]
    subprocess.run(cmd, check=True)


def gen_sfx(assets, man: Manifest, log):
    tv = project.tool_versions()
    for a in assets:
        aid = a["id"]
        if aid not in sfx.RECIPES:
            log.append(("MISSING_RECIPE", aid))
            continue
        for vi, (variant, res) in enumerate(project.expand_paths(a)):
            seed = stable_seed(aid, variant)
            y, r = sfx.render(aid, vi, seed)
            out = res_to_path(res)
            n_loop = int(y.shape[0])
            if r.loop:
                # Thêm 1 mẫu = mẫu đầu; chunk smpl ghi end = n_loop (theo RIFF là mẫu cuối được phát).
                # Godot đọc loop_end = n_loop và coi là mốc loại trừ -> lặp đúng n_loop mẫu gốc;
                # trình phát theo chuẩn RIFF chỉ lặp lại mẫu đầu thêm 1 lần (không có bước nhảy).
                y = np.concatenate([y, y[:1]])
                wavio.write_wav(out, y, 44100, loop=(0, n_loop + 1))
            else:
                wavio.write_wav(out, y, 44100)
            man.add(aid, variant, out, f"cabay_audio/sfx.py:{r.fn.__name__}", seed, "self_made",
                    (r.fn.__doc__ or "").strip(), tv, loop=bool(r.loop),
                    loop_points=({"start": 0, "end_exclusive": n_loop, "file_frames": int(y.shape[0]),
                                  "smpl_chunk": True} if r.loop else None),
                    duration_s=round(y.shape[0] / 44100, 3), peak_dbfs=round(dsp.todb(dsp.peak(y)), 2))


def gen_gib(assets, man: Manifest, log):
    tv = project.tool_versions()
    endings = ("statement", "question", "excl", "laugh", "statement", "question", "statement", "excl", "question", "statement")
    for a in assets:
        aid = a["id"]
        vox = "female" if aid.endswith("female") else "male"
        for vi, (variant, res) in enumerate(project.expand_paths(a)):
            seed = stable_seed(aid, variant)
            count = 8 + (vi * 3) % 5  # 8..12 âm tiết
            ending = endings[vi % len(endings)]
            y = voice.gibberish(seed, vox, count, ending)
            y = dsp.normalize_loudness(y, -18.0, -3.0)
            y = dsp.fade(y, 0.005, 0.005)
            if dsp.peak(y) > dsp.undb(-3.05):
                y = dsp.normalize_peak(y, -3.1)
            out = res_to_path(res)
            wavio.write_wav(out, y, 44100)
            man.add(aid, variant, out, "cabay_audio/voice.py:gibberish", seed, "self_made",
                    f"Gibberish 'ú ớ' hư cấu, giọng {'nữ' if vox == 'female' else 'nam'} tổng hợp formant nguyên bản; "
                    f"{count} âm tiết, ngữ điệu '{ending}'. Không phải thoại rõ nghĩa, không tính coverage VO.",
                    tv, syllables=count, ending=ending, duration_s=round(y.shape[0] / 44100, 3))


def _gen_long(assets, man: Manifest, table: dict, kind: str, subdir: str):
    tv = project.tool_versions(include_ffmpeg=True)
    build = project.BUILD / subdir
    ensure_gdignore(project.BUILD)
    build.mkdir(parents=True, exist_ok=True)
    for a in assets:
        aid = a["id"]
        if aid not in table:
            continue
        fn, desc = table[aid]
        seed = stable_seed(aid, None)
        t0 = time.time()
        y = fn(seed)
        src = build / f"{aid}.wav"
        wavio.write_wav(src, y, 44100)
        out = res_to_path(a["path"])
        encode_ogg(src, out, OGG_QUALITY[kind])
        man.add(aid, None, out, f"cabay_audio/{fn.__module__.split('.')[-1]}.py:{fn.__name__} + ffmpeg libvorbis q{OGG_QUALITY[kind]}",
                seed, "self_made", desc, tv, loop=True,
                loop_points={"start": 0, "end_exclusive": int(y.shape[0]),
                             "note": "Render vòng tròn; bật loop=true trong .import của Godot (loop_offset 0)."},
                duration_s=round(y.shape[0] / 44100, 3), frames=int(y.shape[0]),
                lufs_est=round(dsp.loudness_lufs(y, circular=True), 2),
                source_wav=rel(src), source_wav_sha256=project.sha256_file(src))
        print(f"  {aid}: {y.shape[0] / 44100:.1f} s, {time.time() - t0:.1f} s render", flush=True)


def gen_vo(assets, man: Manifest, log):
    tv = project.tool_versions(include_tts=True)
    strings = project.load_strings()
    npcs = {r["id"]: r for r in project.load_npcs()}
    raw_root = project.BUILD / "tts_raw"
    ensure_gdignore(project.BUILD)
    reg_ids = {a["id"]: a for a in assets}
    coverage = {}
    for npc_id in npcs:
        short = npc_id[len("npc_"):] if npc_id.startswith("npc_") else npc_id
        if npc_id not in tts.NPC_VOICES:
            log.append(("NO_VOICE_PARAMS", npc_id))
            continue
        keys = project.npc_lines(strings, npc_id)
        for loc in ("vi", "en"):
            pack_id = f"vo_dialogue_{short}_{loc}"
            if pack_id not in reg_ids:
                log.append(("PACK_NOT_IN_REGISTRY", pack_id))
                continue
            lines = {}
            for key in keys:
                line_key = key[len(npc_id) + 1:]
                text = strings[key][loc]
                if not text.strip():
                    log.append(("EMPTY_TEXT", key, loc))
                    continue
                out = project.ASSETS_AUDIO / "vo" / npc_id / loc / f"{line_key}.wav"
                raw = raw_root / npc_id / loc / f"{line_key}.wav"
                info = tts.synth_line(npc_id, loc, text, raw, out)
                e = man.add(pack_id, key, out, "cabay_audio/tts.py:synth_line (espeak-ng " + " ".join(info["espeak_args"]) + ")",
                            None, "tbd",
                            "Thoại TTS espeak-ng (giọng formant tích hợp, không mbrola). Quyền thương mại chưa chắc: xem "
                            "license_analysis trong manifest. Không tự khẳng định; trưởng dự án quyết định.",
                            tv, npc_id=npc_id, locale=loc, text_key=key, line_key=line_key, text=text,
                            espeak_args=info["espeak_args"],
                            raw_sample_rate=info["raw_sr"], duration_s=info["duration_s"], lufs_est=info["lufs_est"],
                            peak_dbfs=info["peak_dbfs"])
                # khóa = text_key đầy đủ (khớp payload dialogue.line_started.text_key); file đặt theo line_key
                lines[key] = {"file": path_to_res(out), "sha256": e["sha256"], "text": text, "line_key": line_key,
                              "duration_s": info["duration_s"]}
            pack = {
                "npc_id": npc_id,
                "locale": loc,
                "pack_asset_id": pack_id,
                "voice": {"engine": "espeak-ng", "args": tts.espeak_args(npc_id, loc), "desc": tts.NPC_VOICES[npc_id]["desc"]},
                "license": "tbd",
                "lines": dict(sorted(lines.items())),
            }
            pack_path = res_to_path(reg_ids[pack_id]["path"])
            pack_path.parent.mkdir(parents=True, exist_ok=True)
            pack_path.write_text(json.dumps(pack, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            man.add(pack_id, None, pack_path, "generate_all.py:gen_vo (chỉ mục pack)", None, "tbd",
                    f"Chỉ mục pack thoại {npc_id}/{loc}: {len(lines)} dòng, mỗi dòng một WAV riêng + sha256 + phụ đề.",
                    tv, npc_id=npc_id, locale=loc, line_count=len(lines))
            coverage[(npc_id, loc)] = (len(lines), len(keys))
    return coverage


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default=",".join(GROUPS), help="nhóm cần tạo: " + ",".join(GROUPS))
    args = ap.parse_args()
    only = [g.strip() for g in args.only.split(",") if g.strip()]
    bad = [g for g in only if g not in GROUPS]
    if bad:
        ap.error(f"nhóm không hợp lệ: {bad}")

    assets = project.load_registry_audio()
    by_group: dict[str, list] = {g: [] for g in GROUPS}
    other = []
    for a in assets:
        g = group_of(a)
        (by_group[g] if g in by_group else other).append(a)

    man = Manifest()
    # giữ mục của nhóm không tạo lại
    if project.MANIFEST_PATH.exists() and set(only) != set(GROUPS):
        old = json.loads(project.MANIFEST_PATH.read_text(encoding="utf-8"))
        keep_ids = {a["id"] for g in GROUPS if g not in only for a in by_group[g]}
        man.entries = [e for e in old.get("files", []) if e["asset_id"] in keep_ids]

    log: list = []
    t0 = time.time()
    if "sfx" in only:
        print(f"[sfx] {len(by_group['sfx'])} asset", flush=True)
        gen_sfx(by_group["sfx"], man, log)
    if "gib" in only:
        print(f"[gib] {len(by_group['gib'])} asset", flush=True)
        gen_gib(by_group["gib"], man, log)
    if "mus" in only:
        print(f"[mus] {len(by_group['mus'])} asset", flush=True)
        _gen_long(by_group["mus"], man, music.SONGS, "music", "mus")
    if "amb" in only:
        print(f"[amb] {len(by_group['amb'])} asset", flush=True)
        _gen_long(by_group["amb"], man, ambience.AMBIENCES, "ambience", "amb")
    coverage = {}
    if "vo" in only:
        print(f"[vo] {len(by_group['vo'])} pack", flush=True)
        coverage = gen_vo(by_group["vo"], man, log)

    man.write({"license_analysis": tts.LICENSE_ANALYSIS})
    produced_ids = {e["asset_id"] for e in man.entries}
    missing = sorted(a["id"] for a in assets if a["id"] not in produced_ids)
    print(f"\nXong trong {time.time() - t0:.1f} s. Manifest: {rel(project.MANIFEST_PATH)} ({len(man.entries)} file)")
    for k, v in sorted(coverage.items()):
        print(f"  VO {k[0]}/{k[1]}: {v[0]}/{v[1]} dòng")
    if other:
        print("  Asset audio không thuộc nhóm nào:", [a["id"] for a in other])
    if missing:
        print("  Asset registry CHƯA có file:", missing)
    for item in log:
        print("  CẢNH BÁO:", *item)
    return 1 if (missing and set(only) == set(GROUPS)) or log else 0


if __name__ == "__main__":
    sys.exit(main())
