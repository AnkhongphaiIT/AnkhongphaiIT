"""Thoại VI/EN bằng espeak-ng cục bộ (không mbrola, không mạng).

Quy trình mỗi dòng: espeak-ng -> WAV 22.05 kHz (lưu thô trong build/tts_raw) ->
lọc DC -> nâng mẫu x2 bằng FFT lên 44.1 kHz -> cắt lặng hai đầu (giữ đệm) ->
chuẩn hóa ~ -18 LUFS, trần peak -3 dBFS -> fade 5 ms -> WAV PCM16 mono 44.1 kHz.
"""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import numpy as np

from . import dsp, wavio

# Mỗi NPC một bộ tham số riêng (biến thể giọng espeak-ng, cao độ -p, tốc độ -s, khoảng nghỉ từ -g).
# Chỉ dùng biến thể formant tích hợp của espeak-ng (thư mục voices/!v), KHÔNG dùng mbrola.
NPC_VOICES: dict[str, dict] = {
    "npc_co_ba": {"desc": "Cô Ba — bà bán cá lanh lợi, nói nhanh",
                  "variant": "f4", "vi": {"p": 56, "s": 165, "g": 1}, "en": {"p": 58, "s": 170, "g": 1}},
    "npc_ong_tu": {"desc": "Ông Tư — ông lão điềm đạm, giọng trầm hơi run",
                   "variant": "grandpa", "vi": {"p": 38, "s": 140, "g": 2}, "en": {"p": 36, "s": 145, "g": 2}},
    "npc_bay_cho": {"desc": "Bảy Chợ — người bán ở chợ đảo 2, tươi tắn",
                    "variant": "f2", "vi": {"p": 66, "s": 168, "g": 1}, "en": {"p": 66, "s": 172, "g": 1}},
    "npc_co_tam": {"desc": "Cô Tám — cô bán hàng đảo 3, ấm và chậm rãi",
                   "variant": "f1", "vi": {"p": 48, "s": 150, "g": 2}, "en": {"p": 50, "s": 155, "g": 2}},
    "npc_nam_sau": {"desc": "Chú Sáu — người khảo sát lạch, thực tế, giọng trung",
                    "variant": "m2", "vi": {"p": 46, "s": 158, "g": 1}, "en": {"p": 44, "s": 162, "g": 1}},
    "npc_chi_lan": {"desc": "Chị Lan — người tổ chức hội câu, trẻ, rõ ràng, hơi thở nhẹ",
                    "variant": "f5", "vi": {"p": 70, "s": 160, "g": 1}, "en": {"p": 68, "s": 165, "g": 1}},
}
BASE_VOICE = {"vi": "vi", "en": "en"}
TARGET_LUFS = -18.0
CEILING_DB = -3.0


def espeak_args(npc_id: str, locale: str) -> list[str]:
    v = NPC_VOICES[npc_id]
    p = v[locale]
    return ["-v", f"{BASE_VOICE[locale]}+{v['variant']}", "-p", str(p["p"]), "-s", str(p["s"]),
            "-g", str(p["g"]), "-a", "100", "-b", "1"]


def run_espeak(text: str, out_raw: Path, args: list[str]) -> None:
    exe = shutil.which("espeak-ng")
    if not exe:
        raise RuntimeError("Thiếu espeak-ng. Cài: apt-get install -y espeak-ng")
    out_raw.parent.mkdir(parents=True, exist_ok=True)
    # đọc văn bản qua stdin (UTF-8) để tránh vấn đề trích dẫn đối số
    subprocess.run([exe, *args, "-w", str(out_raw), "--stdin"], input=text.encode("utf-8"), check=True,
                   capture_output=True)


def upsample2(x: np.ndarray) -> np.ndarray:
    """Nâng mẫu x2 giới hạn băng bằng FFT (có đệm để tránh quấn vòng)."""
    pad = 4096
    xp = np.concatenate([np.zeros(pad), x, np.zeros(pad)])
    n = xp.shape[0]
    X = np.fft.rfft(xp)
    Y = np.zeros(n + 1, dtype=complex)  # rfft của tín hiệu dài 2n có n+1 bin
    Y[:X.shape[0]] = X
    # nửa năng lượng tại bin Nyquist cũ
    Y[X.shape[0] - 1] *= 0.5 if n % 2 == 0 else 1.0
    y = np.fft.irfft(Y, 2 * n) * 2.0
    return y[2 * pad:2 * pad + 2 * x.shape[0]]


def process(raw: dict) -> np.ndarray:
    x = raw["data"]
    if x.ndim == 2:
        x = x.mean(axis=1)
    sr = raw["sr"]
    x = x - np.mean(x)
    if sr == 22050:
        x = upsample2(x)
    elif sr != 44100:
        raise ValueError(f"sample rate espeak-ng không mong đợi: {sr}")
    x = dsp.highpass(x, 70.0, 2)
    p = dsp.peak(x)
    if p <= 0:
        raise ValueError("espeak-ng trả về tín hiệu im lặng")
    idx = np.nonzero(np.abs(x) > p * dsp.undb(-45))[0]
    s = max(0, idx[0] - dsp.n_of(0.03))
    e = min(x.shape[0], idx[-1] + dsp.n_of(0.12))
    x = x[s:e]
    x = np.concatenate([np.zeros(dsp.n_of(0.03)), x, np.zeros(dsp.n_of(0.05))])
    x = dsp.normalize_loudness(x, TARGET_LUFS, CEILING_DB)
    x = dsp.fade(x, 0.005, 0.005)
    # an toàn: bảo đảm trần peak
    if dsp.peak(x) > dsp.undb(CEILING_DB - 0.05):
        x = dsp.normalize_peak(x, CEILING_DB - 0.1)
    return x


def synth_line(npc_id: str, locale: str, text: str, raw_path: Path, out_path: Path) -> dict:
    args = espeak_args(npc_id, locale)
    run_espeak(text, raw_path, args)
    raw = wavio.read_wav(raw_path)
    y = process(raw)
    wavio.write_wav(out_path, y, 44100)
    return {"espeak_args": args, "raw_sr": raw["sr"], "duration_s": round(y.shape[0] / 44100.0, 3),
            "lufs_est": round(dsp.loudness_lufs(y), 2), "peak_dbfs": round(dsp.todb(dsp.peak(y)), 2)}


LICENSE_ANALYSIS = {
    "engine": "espeak-ng (gói Ubuntu noble 1.51+dfsg-12build1, cài bằng apt; chạy offline)",
    "voices_used": "Giọng ngôn ngữ tích hợp `vi` và `en` + biến thể formant trong espeak-ng-data/voices/!v "
                   "(f1, f2, f4, f5, m2, grandpa). Không dùng mbrola (mbrola có giấy phép riêng, hạn chế).",
    "software_license": "GPL-3.0-or-later — /usr/share/doc/espeak-ng/copyright: 'The rest of upstream sources are "
                        "licensed under the following terms: ... GNU General Public License as published by the Free "
                        "Software Foundation; either version 3 of the License, or (at your option) any later version.'",
    "voice_data_license": "Gói espeak-ng-data dùng cùng tệp copyright (/usr/share/doc/espeak-ng-data/copyright), không có "
                          "điều khoản riêng cho dữ liệu giọng -> dữ liệu âm vị/từ điển/biến thể cũng thuộc GPL-3.0-or-later. "
                          "Chủ bản quyền liệt kê: Jonathan Duddington 2005-2014, Reece H. Dunn 2013-2016, Gilles Casse, "
                          "Ross Bencina, Phil Burk, Sun Microsystems, Bill Cox, Nicolas Pitre, The NetBSD Foundation.",
    "output_note": "GPL điều chỉnh việc sao chép/phân phối chương trình; đầu ra của chương trình thường không tự động thuộc GPL, "
                   "TRỪ KHI đầu ra chứa phần có bản quyền của chương trình. phondata-manifest cho thấy phondata chứa 162 "
                   "'W - A wavefile segment' (ustop, ufric, vietnam, h, x, ...) — các đoạn mẫu sóng này có thể được chép "
                   "vào âm thanh đầu ra. Vì vậy quyền dùng thương mại của file thoại là CHƯA CHẮC.",
    "decision": "license=tbd. Không tự khẳng định quyền thương mại. Phương án cho trưởng dự án: (a) coi file thoại là "
                "dữ liệu phái sinh GPL-3.0-or-later và phát hành kèm thông báo GPL + cách tái tạo (script này) — tách biệt "
                "với mã game (gộp đơn thuần); (b) xin tư vấn pháp lý; (c) thay bằng ghi âm có đồng ý của người thật.",
}
