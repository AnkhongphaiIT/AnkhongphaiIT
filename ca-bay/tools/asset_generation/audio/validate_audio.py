#!/usr/bin/env python3
"""Kiểm định âm thanh CÁ BAY (WP-09): đọc lại từng file thật trên đĩa.

Chạy từ gốc dự án:
    tools/asset_generation/audio/.venv/bin/python tools/asset_generation/audio/validate_audio.py [--quiet] [--json OUT]

Kiểm: đủ file theo registry (biến thể {nn}), sha256 khớp manifest, định dạng/kênh/
sample rate/bit depth (WAV đọc bằng module `wave` chuẩn + quét chunk, OGG bằng
ffprobe + giải mã lại bằng ffmpeg), thời lượng, peak dBFS, clipping, im lặng, fade,
loop (chunk smpl + điểm nối đầu/cuối), độ to ước lượng, pack thoại khớp strings.csv.
In bảng PASS/FAIL; exit 1 nếu có lỗi.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
try:
    import numpy as np
except ImportError:
    _venv_py = _HERE / ".venv" / "bin" / "python"
    if _venv_py.exists() and Path(sys.prefix).resolve() != (_HERE / ".venv").resolve():
        os.execv(str(_venv_py), [str(_venv_py), str(Path(__file__).resolve()), *sys.argv[1:]])
    sys.exit("Thiếu numpy (xem README).")

import argparse  # noqa: E402
import csv  # noqa: E402
import hashlib  # noqa: E402
import json  # noqa: E402
import math  # noqa: E402
import struct  # noqa: E402
import subprocess  # noqa: E402
import wave  # noqa: E402

ROOT = _HERE.parents[2]
AUDIO = ROOT / "assets" / "audio"
MANIFEST = AUDIO / "AUDIO_MANIFEST.json"
REGISTRY = ROOT / "data" / "contracts" / "asset_registry.json"
STRINGS = ROOT / "data" / "loc" / "strings.csv"
NPCS = ROOT / "data" / "content" / "npcs.json"
LICENSES = {"self_made", "tbd", "verified_custom"}

SFX_MAX_S = 2.0
SFX_LOOP_MAX_S = 4.0
PEAK_MAX_DB = -3.0
FADE_MAX = 10 ** (-40 / 20)


def db(x: float) -> float:
    return 20 * math.log10(max(x, 1e-12))


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def res_path(res: str) -> Path:
    return ROOT / res[len("res://"):]


# ---------------------------------------------------------------- độ to (BS.1770 ước lượng, độc lập)
def _biquad_mag(b, a, f, fs=48000.0):
    w = 2 * math.pi * np.minimum(f, fs / 2 - 1) / fs
    z1 = np.exp(-1j * w)
    z2 = z1 * z1
    return np.abs((b[0] + b[1] * z1 + b[2] * z2) / (a[0] + a[1] * z1 + a[2] * z2))


def lufs(x: np.ndarray, sr: int) -> float:
    xs = x[:, None] if x.ndim == 1 else x
    n = xs.shape[0]
    nfft = 1 << (n + 4096).bit_length()
    f = np.fft.rfftfreq(nfft, 1 / sr)
    H = _biquad_mag((1.53512485958697, -2.69169618940638, 1.19839281085285), (1.0, -1.69065929318241, 0.73248077421585), f) * \
        _biquad_mag((1.0, -2.0, 1.0), (1.0, -1.99004745483398, 0.99007225036621), f)
    y = np.stack([np.fft.irfft(np.fft.rfft(xs[:, c], nfft) * H, nfft)[:n] for c in range(xs.shape[1])], axis=1)
    blk, step = int(0.4 * sr), int(0.1 * sr)
    if n < blk:
        z = float(np.sum(np.mean(y * y, axis=0)))
        return -0.691 + 10 * math.log10(max(z, 1e-20))
    sq = np.cumsum(np.concatenate([np.zeros((1, y.shape[1])), y * y]), axis=0)
    st = np.arange(0, n - blk + 1, step)
    z = np.sum((sq[st + blk] - sq[st]) / blk, axis=1)
    lj = -0.691 + 10 * np.log10(np.maximum(z, 1e-20))
    g1 = lj > -70
    if not np.any(g1):
        return -120.0
    gamma = -0.691 + 10 * math.log10(float(np.mean(z[g1]))) - 10
    g2 = g1 & (lj > gamma)
    return -0.691 + 10 * math.log10(float(np.mean(z[g2])))


# ---------------------------------------------------------------- đọc file
def scan_chunks(p: Path) -> dict:
    raw = p.read_bytes()
    out = {"chunks": [], "smpl": None}
    if raw[:4] != b"RIFF" or raw[8:12] != b"WAVE":
        return out
    pos = 12
    while pos + 8 <= len(raw):
        cid = raw[pos:pos + 4].decode("latin1")
        size = struct.unpack("<I", raw[pos + 4:pos + 8])[0]
        out["chunks"].append(cid)
        if cid == "fmt ":
            out["format_tag"] = struct.unpack("<H", raw[pos + 8:pos + 10])[0]
        if cid == "smpl" and size >= 60:
            b = raw[pos + 8:pos + 8 + size]
            nl = struct.unpack("<I", b[28:32])[0]
            if nl >= 1:
                _cue, typ, s, e, _f, _pc = struct.unpack("<6I", b[36:60])
                out["smpl"] = {"type": typ, "start": s, "end_inclusive": e, "count": nl}
        pos += 8 + size + (size & 1)
    return out


def read_wav(p: Path):
    with wave.open(str(p), "rb") as w:
        ch, sw, sr, n, comp = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes(), w.getcomptype()
        data = w.readframes(n)
    if sw != 2:
        return {"ch": ch, "bits": sw * 8, "sr": sr, "frames": n, "comp": comp, "x": None}
    x = np.frombuffer(data, dtype="<i2").astype(np.int32)
    if ch > 1:
        x = x.reshape(-1, ch)
    return {"ch": ch, "bits": 16, "sr": sr, "frames": n, "comp": comp, "x": x}


def probe_ogg(p: Path) -> dict:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=codec_name,channels,sample_rate",
                          "-of", "json", str(p)], capture_output=True, text=True)
    if out.returncode != 0:
        return {"error": out.stderr.strip()}
    st = json.loads(out.stdout).get("streams", [])
    return st[0] if st else {"error": "no stream"}


def decode_ogg(p: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(p), "-f", "f32le", "-ac", "2", "-ar", "44100", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").astype(np.float64).reshape(-1, 2)


def seam_check(x: np.ndarray) -> tuple[float, float]:
    """Trả (bước nhảy tại điểm nối, phân vị 99 của bước nhảy giữa hai mẫu kề nhau)."""
    xs = x[:, None] if x.ndim == 1 else x
    d = np.max(np.abs(np.diff(xs, axis=0)), axis=1)
    jump = float(np.max(np.abs(xs[0] - xs[-1])))
    return jump, float(np.percentile(d, 99))


# ---------------------------------------------------------------- kiểm tra
class Report:
    def __init__(self):
        self.rows = []
        self.errors = 0
        self.warnings = 0

    def row(self, path: str, kind: str, errs: list, warns: list, info: str):
        self.errors += len(errs)
        self.warnings += len(warns)
        self.rows.append({"path": path, "kind": kind, "status": "FAIL" if errs else ("WARN" if warns else "PASS"),
                          "errors": errs, "warnings": warns, "info": info})


def check_wav(p: Path, kind: str, loop_expected: bool, rep: Report):
    errs, warns = [], []
    ck = scan_chunks(p)
    if ck.get("format_tag") != 1:
        errs.append(f"format_tag={ck.get('format_tag')} (cần PCM=1)")
    try:
        w = read_wav(p)
    except Exception as exc:  # noqa: BLE001
        rep.row(str(p.relative_to(ROOT)), kind, [f"không đọc được: {exc}"], [], "")
        return
    if w["ch"] != 1:
        errs.append(f"kênh={w['ch']} (cần mono)")
    if w["sr"] != 44100:
        errs.append(f"sr={w['sr']} (cần 44100)")
    if w["bits"] != 16:
        errs.append(f"bit={w['bits']} (cần 16)")
    if w["comp"] != "NONE":
        errs.append(f"nén={w['comp']}")
    if w["x"] is None:
        rep.row(str(p.relative_to(ROOT)), kind, errs, warns, "")
        return
    xi = w["x"] if w["x"].ndim == 1 else w["x"][:, 0]
    x = xi / 32768.0
    dur = w["frames"] / w["sr"]
    pk = float(np.max(np.abs(x))) if x.size else 0.0
    rms = float(np.sqrt(np.mean(x * x))) if x.size else 0.0
    clip = int(np.sum((xi >= 32767) | (xi <= -32768)))
    L = lufs(x, w["sr"]) if x.size else -120.0
    if db(pk) > PEAK_MAX_DB + 0.01:
        errs.append(f"peak {db(pk):.2f} dBFS > {PEAK_MAX_DB}")
    if clip:
        errs.append(f"clipping {clip} mẫu")
    if db(rms) < -60:
        errs.append(f"gần im lặng (RMS {db(rms):.1f} dBFS)")
    if kind == "sfx":
        lim = SFX_LOOP_MAX_S if loop_expected else SFX_MAX_S
        if dur > lim + 1e-6:
            errs.append(f"dài {dur:.2f}s > {lim}s")
        if dur < 0.03:
            errs.append(f"quá ngắn {dur:.3f}s")
    elif kind == "gib":
        if not 1.0 <= dur <= 4.0:
            errs.append(f"thời lượng gibberish {dur:.2f}s ngoài 1–4 s")
    elif kind == "vo":
        if not 0.4 <= dur <= 15.0:
            errs.append(f"thời lượng thoại {dur:.2f}s bất thường")
        if abs(L + 18) > 3:
            warns.append(f"độ to {L:.1f} LUFS lệch mục tiêu -18")
    info = f"{dur:5.2f}s peak {db(pk):6.2f} LUFS~{L:6.1f}"
    if loop_expected:
        sm = ck.get("smpl")
        if not sm:
            errs.append("thiếu chunk smpl (điểm loop)")
        elif sm["start"] != 0 or sm["end_inclusive"] != w["frames"] - 1:
            errs.append(f"điểm loop {sm} không phủ toàn file ({w['frames']} mẫu)")
        _j, p99 = seam_check(x)
        if sm:
            s0, e = sm["start"], sm["end_inclusive"]
            # Godot: loop_end loại trừ -> nối x[e-1] -> x[s]; chuẩn RIFF: nối x[e] -> x[s]
            jump = max(abs(x[e - 1] - x[s0]), abs(x[e] - x[s0]))
        else:
            jump = _j
        if jump > 1.5 * p99 + 1e-3:
            errs.append(f"click điểm nối: nhảy {jump:.4f} > 1.5×p99 {p99:.4f}")
        k = min(x.size // 4, 2205)
        r0 = db(float(np.sqrt(np.mean(x[:k] ** 2))))
        r1 = db(float(np.sqrt(np.mean(x[-k:] ** 2))))
        if abs(r0 - r1) > 6:
            warns.append(f"RMS đầu/cuối lệch {abs(r0 - r1):.1f} dB")
        info += f" loop nối {jump:.4f}/p99 {p99:.4f}"
    else:
        if abs(x[0]) > FADE_MAX or abs(x[-1]) > FADE_MAX:
            errs.append(f"không fade: mẫu đầu {x[0]:.4f} / cuối {x[-1]:.4f}")
        if kind == "sfx" and pk > 0:
            onset = int(np.argmax(np.abs(x) > 0.1 * pk)) / w["sr"]
            if onset > 0.03:
                warns.append(f"khởi âm trễ {onset * 1000:.0f} ms")
        if ck.get("smpl"):
            warns.append("có chunk smpl ở file không lặp")
    rep.row(str(p.relative_to(ROOT)), kind, errs, warns, info)


def check_ogg(p: Path, kind: str, rep: Report, manifest_entry: dict | None):
    errs, warns = [], []
    pr = probe_ogg(p)
    if "error" in pr:
        rep.row(str(p.relative_to(ROOT)), kind, [f"ffprobe: {pr['error']}"], [], "")
        return
    if pr.get("codec_name") != "vorbis":
        errs.append(f"codec {pr.get('codec_name')} (cần vorbis)")
    if int(pr.get("channels", 0)) != 2:
        errs.append(f"kênh {pr.get('channels')} (cần stereo)")
    if int(pr.get("sample_rate", 0)) != 44100:
        errs.append(f"sr {pr.get('sample_rate')} (cần 44100)")
    x = decode_ogg(p)
    dur = x.shape[0] / 44100
    pk = float(np.max(np.abs(x)))
    L = lufs(x, 44100)
    rms = float(np.sqrt(np.mean(x * x)))
    if kind == "music":
        if not 30.0 <= dur <= 60.0:
            errs.append(f"thời lượng {dur:.1f}s ngoài 30–60 s")
        target = -18.0
    else:
        if dur < 30.0:
            errs.append(f"thời lượng {dur:.1f}s < 30 s")
        target = -26.0
    if abs(L - target) > 3:
        errs.append(f"độ to {L:.1f} LUFS lệch mục tiêu {target} quá 3 LU")
    elif abs(L - target) > 1.5:
        warns.append(f"độ to {L:.1f} LUFS lệch mục tiêu {target}")
    if pk >= 0.999:
        errs.append(f"clipping sau giải mã (peak {db(pk):.2f} dBFS)")
    elif db(pk) > -1.0:
        warns.append(f"peak giải mã {db(pk):.2f} dBFS sát 0")
    if db(rms) < -60:
        errs.append("gần im lặng")
    jump, p99 = seam_check(x)
    if jump > 1.5 * p99 + 1e-3:
        errs.append(f"click điểm nối: nhảy {jump:.4f} > 1.5×p99 {p99:.4f}")
    k = 22050
    r0 = db(float(np.sqrt(np.mean(x[:k] ** 2))))
    r1 = db(float(np.sqrt(np.mean(x[-k:] ** 2))))
    if abs(r0 - r1) > 6:
        warns.append(f"RMS 0,5 s đầu/cuối lệch {abs(r0 - r1):.1f} dB")
    if manifest_entry and manifest_entry.get("frames") and abs(manifest_entry["frames"] - x.shape[0]) > 1:
        errs.append(f"độ dài giải mã {x.shape[0]} ≠ nguồn {manifest_entry['frames']} mẫu")
    src = manifest_entry.get("source_wav") if manifest_entry else None
    if src:
        sp = ROOT / src
        if not sp.exists():
            warns.append(f"thiếu WAV nguồn {src}")
        elif manifest_entry.get("source_wav_sha256") and sha256(sp) != manifest_entry["source_wav_sha256"]:
            errs.append("sha256 WAV nguồn không khớp manifest")
    info = f"{dur:5.1f}s peak {db(pk):6.2f} LUFS~{L:6.1f} nối {jump:.4f}/p99 {p99:.4f}"
    rep.row(str(p.relative_to(ROOT)), kind, errs, warns, info)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--quiet", action="store_true", help="chỉ in dòng FAIL/WARN + tổng kết")
    ap.add_argument("--json", help="ghi kết quả chi tiết ra file JSON")
    args = ap.parse_args()
    rep = Report()
    glob_errs: list[str] = []

    reg = json.loads(REGISTRY.read_text(encoding="utf-8"))
    audio_assets = [a for a in reg["assets"] if a["type"] in ("sfx", "music", "ambience", "voice")]
    if not MANIFEST.exists():
        print("FAIL: thiếu", MANIFEST)
        return 1
    man = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = man.get("files", [])
    by_path = {}
    for e in entries:
        if e["path"] in by_path:
            glob_errs.append(f"manifest trùng path {e['path']}")
        by_path[e["path"]] = e
        for fld in ("asset_id", "path", "sha256", "generator", "license", "tool_versions", "notes"):
            if fld not in e or e[fld] in (None, "", {}):
                glob_errs.append(f"manifest {e.get('path')}: thiếu trường {fld}")
        if "seed" not in e or "variant" not in e:
            glob_errs.append(f"manifest {e.get('path')}: thiếu seed/variant")
        if e.get("license") not in LICENSES:
            glob_errs.append(f"manifest {e['path']}: license '{e.get('license')}' không hợp lệ")

    # 1) đủ file theo registry
    expected: dict[str, tuple[str, dict]] = {}
    per_asset_files: dict[str, int] = {}
    for a in audio_assets:
        p = a["path"]
        if "{nn}" in p:
            n = int(a.get("variants", 0))
            if n <= 0:
                glob_errs.append(f"{a['id']}: đường dẫn {{nn}} nhưng variants={a.get('variants')}")
            paths = [p.replace("{nn}", f"{i:02d}") for i in range(1, n + 1)]
        else:
            paths = [p]
        per_asset_files[a["id"]] = len(paths)
        for rp in paths:
            expected[rp] = (a["id"], a)
            if not res_path(rp).exists():
                glob_errs.append(f"THIẾU file {rp} ({a['id']})")
            elif rp not in by_path:
                glob_errs.append(f"file {rp} không có trong manifest")

    # 2) sha256 + kiểm từng file trong manifest
    for e in entries:
        p = res_path(e["path"])
        if not p.exists():
            glob_errs.append(f"manifest trỏ file không tồn tại: {e['path']}")
            continue
        if sha256(p) != e["sha256"]:
            glob_errs.append(f"sha256 không khớp: {e['path']}")
        aid = e["asset_id"]
        if p.suffix == ".wav":
            if aid.startswith("sfx_"):
                check_wav(p, "sfx", bool(e.get("loop")) or aid.endswith("_loop"), rep)
            elif aid.startswith("vo_npc_gibberish_"):
                check_wav(p, "gib", False, rep)
            elif aid.startswith("vo_dialogue_"):
                check_wav(p, "vo", False, rep)
            else:
                glob_errs.append(f"WAV không rõ loại: {e['path']}")
            if aid.endswith("_loop") and not e.get("loop"):
                glob_errs.append(f"{aid} là loop nhưng manifest không đánh dấu loop")
        elif p.suffix == ".ogg":
            kind = "music" if aid.startswith("mus_") else "ambience"
            check_ogg(p, kind, rep, e)
        elif p.suffix == ".json":
            pass
        else:
            glob_errs.append(f"đuôi file lạ: {e['path']}")

    # 3) không có WAV trong mus/amb; không có file lạ ngoài manifest
    for sub in ("mus", "amb"):
        for w in (AUDIO / sub).glob("*.wav") if (AUDIO / sub).exists() else []:
            glob_errs.append(f"WAV nguồn không được đặt trong assets: {w.relative_to(ROOT)}")
    known = {res_path(e["path"]).resolve() for e in entries} | {MANIFEST.resolve()}
    for f in AUDIO.rglob("*"):
        if f.is_file() and f.suffix not in (".import",) and f.name != ".gdignore" and f.resolve() not in known:
            glob_errs.append(f"file ngoài manifest: {f.relative_to(ROOT)}")

    # 4) pack thoại
    strings = {}
    with open(STRINGS, encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            strings[row["keys"]] = row
    npcs = [r["id"] for r in json.loads(NPCS.read_text(encoding="utf-8"))["records"]]
    reg_ids = {a["id"]: a for a in audio_assets}
    coverage = []
    for npc in npcs:
        short = npc[4:] if npc.startswith("npc_") else npc
        keys = sorted(k for k in strings if k.startswith(npc + ".") and k != npc + ".name")
        for loc in ("vi", "en"):
            pid = f"vo_dialogue_{short}_{loc}"
            if pid not in reg_ids:
                glob_errs.append(f"pack {pid} không có trong registry")
                continue
            pp = res_path(reg_ids[pid]["path"])
            if not pp.exists():
                glob_errs.append(f"THIẾU pack {pid}")
                coverage.append((npc, loc, 0, len(keys)))
                continue
            pk = json.loads(pp.read_text(encoding="utf-8"))
            if pk.get("npc_id") != npc or pk.get("locale") != loc or not isinstance(pk.get("lines"), dict):
                glob_errs.append(f"pack {pid}: sai npc_id/locale/lines")
                continue
            ok = 0
            for key in keys:
                lk = key  # pack dùng text_key đầy đủ làm khóa
                ln = pk["lines"].get(lk)
                if not ln:
                    glob_errs.append(f"pack {pid}: thiếu dòng {lk}")
                    continue
                f = res_path(ln["file"])
                if not f.exists():
                    glob_errs.append(f"pack {pid}/{lk}: thiếu WAV {ln['file']}")
                    continue
                if sha256(f) != ln.get("sha256"):
                    glob_errs.append(f"pack {pid}/{lk}: sha256 không khớp")
                    continue
                if ln.get("text") != strings[key][loc]:
                    glob_errs.append(f"pack {pid}/{lk}: text lệch strings.csv")
                    continue
                if ln["file"] not in by_path or by_path[ln["file"]].get("asset_id") != pid:
                    glob_errs.append(f"pack {pid}/{lk}: WAV không ghi đúng trong manifest")
                    continue
                ok += 1
            extra = set(pk["lines"]) - set(keys)
            if extra:
                glob_errs.append(f"pack {pid}: dòng thừa {sorted(extra)}")
            coverage.append((npc, loc, ok, len(keys)))

    # ---- in kết quả
    for r in rep.rows:
        if args.quiet and r["status"] == "PASS":
            continue
        msg = "; ".join(r["errors"] + [f"(cảnh báo) {w}" for w in r["warnings"]])
        print(f"{r['status']:4s}  {r['kind']:8s} {r['path']:<62s} {r['info']}" + (f"  <- {msg}" if msg else ""))
    print()
    kinds = {}
    for r in rep.rows:
        k = kinds.setdefault(r["kind"], [0, 0, 0])
        k[0] += 1
        k[1] += r["status"] == "FAIL"
        k[2] += r["status"] == "WARN"
    print("Tổng theo loại (file / FAIL / WARN):")
    for k, v in sorted(kinds.items()):
        print(f"  {k:9s} {v[0]:4d} / {v[1]} / {v[2]}")
    print(f"Registry audio: {len(audio_assets)} asset_id, {len(expected)} đường dẫn file mong đợi; manifest: {len(entries)} file")
    print("Coverage thoại (dòng có WAV hợp lệ / dòng yêu cầu):")
    tot_ok = tot = 0
    for npc, loc, ok, n in coverage:
        tot_ok += ok
        tot += n
        print(f"  {npc:12s} {loc}: {ok}/{n}")
    print(f"  Tổng: {tot_ok}/{tot} dòng × ngôn ngữ")
    if glob_errs:
        print("\nLỗi tổng thể:")
        for g in glob_errs:
            print("  FAIL", g)
    total_err = rep.errors + len(glob_errs)
    print(f"\nKẾT QUẢ: {'ĐẠT' if total_err == 0 else 'LỖI'} — lỗi: {total_err}, cảnh báo: {rep.warnings}")
    if args.json:
        Path(args.json).write_text(json.dumps({"rows": rep.rows, "global_errors": glob_errs, "coverage": coverage,
                                               "errors": total_err, "warnings": rep.warnings}, ensure_ascii=False, indent=1),
                                   encoding="utf-8")
    return 1 if total_err else 0


if __name__ == "__main__":
    sys.exit(main())
