"""Tổng hợp giọng formant nguyên bản (cộng hài + đường bao formant).

Dùng cho gibberish "ú ớ" của NPC và các tiếng kêu không lời (úi, oái, gầm gừ,
cò kêu, ho, bụng reo). Không dùng bản thu hay mô hình giọng người thật.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np

from . import dsp
from .dsp import SR

# Formant F1..F3 (Hz) tham chiếu giọng nam; nhân fscale cho giọng nữ/nhỏ.
VOWELS: dict[str, tuple[float, float, float]] = {
    "a": (760.0, 1230.0, 2600.0),
    "ă": (700.0, 1320.0, 2550.0),
    "e": (560.0, 1800.0, 2550.0),
    "ê": (420.0, 2020.0, 2650.0),
    "i": (300.0, 2250.0, 3000.0),
    "o": (560.0, 900.0, 2500.0),
    "ô": (430.0, 820.0, 2450.0),
    "u": (330.0, 780.0, 2300.0),
    "ơ": (520.0, 1320.0, 2450.0),
    "ư": (360.0, 1400.0, 2350.0),
}
NASAL_M = (260.0, 1000.0, 2250.0)
NASAL_N = (260.0, 1550.0, 2400.0)
NASAL_NG = (270.0, 1250.0, 2300.0)
LIQUID_L = (360.0, 1100.0, 2600.0)
LOCUS = {"b": 800.0, "m": 900.0, "d": 1700.0, "n": 1650.0, "l": 1150.0, "t": 1800.0,
         "k": 1500.0, "g": 1500.0, "h": None, "s": 1700.0, "x": 1900.0, "": None}
NOISE_BANDS = {
    "s": (4200.0, 9500.0),
    "x": (2300.0, 6500.0),
    "t": (2600.0, 7500.0),
    "k": (1300.0, 3800.0),
    "p": (250.0, 2600.0),
}
TONES = ("ngang", "sac", "huyen", "hoi", "nga", "nang")


@dataclass
class Tracks:
    f0: list = field(default_factory=list)      # hệ số nhân f0 theo mẫu
    F: list = field(default_factory=list)       # (n, 3)
    amp: list = field(default_factory=list)     # biên độ phần hữu thanh
    breath: list = field(default_factory=list)  # biên độ hơi (nhiễu qua formant)
    noise: dict = field(default_factory=lambda: {k: [] for k in NOISE_BANDS})

    def push(self, n, f0, F, amp, breath=0.0, noise=None):
        if n <= 0:
            return
        self.f0.append(np.broadcast_to(np.asarray(f0, float), (n,)).copy())
        Fa = np.asarray(F, float)
        if Fa.ndim == 1:
            Fa = np.tile(Fa, (n, 1))
        self.F.append(Fa)
        self.amp.append(np.broadcast_to(np.asarray(amp, float), (n,)).copy())
        self.breath.append(np.broadcast_to(np.asarray(breath, float), (n,)).copy())
        for k in NOISE_BANDS:
            v = (noise or {}).get(k, 0.0)
            self.noise[k].append(np.broadcast_to(np.asarray(v, float), (n,)).copy())

    def arrays(self):
        f0 = np.concatenate(self.f0)
        F = np.concatenate(self.F, axis=0)
        amp = np.concatenate(self.amp)
        br = np.concatenate(self.breath)
        nz = {k: np.concatenate(v) for k, v in self.noise.items()}
        return f0, F, amp, br, nz


def lerp_F(a, b, n):
    w = np.linspace(0.0, 1.0, max(n, 1))[:, None]
    w = w * w * (3 - 2 * w)
    return (1 - w) * np.asarray(a, float)[None, :] + w * np.asarray(b, float)[None, :]


def tone_curve(tone: str, n: int) -> np.ndarray:
    x = np.linspace(0.0, 1.0, max(n, 1))
    if tone == "sac":
        return 0.96 + 0.30 * x ** 1.4
    if tone == "huyen":
        return 0.97 - 0.17 * x
    if tone == "hoi":
        return 0.96 - 0.20 * np.sin(math.pi * np.clip(x * 1.2, 0, 1)) * (1 - 0.3 * x) + 0.05 * x
    if tone == "nga":
        return np.where(x < 0.45, 1.0 - 0.14 * (x / 0.45), 0.86 + 0.42 * ((x - 0.45) / 0.55))
    if tone == "nang":
        return 0.92 - 0.25 * x
    return np.ones_like(x)


def render(f0: np.ndarray, F: np.ndarray, amp: np.ndarray, rng: np.random.Generator, *,
           breath: np.ndarray | None = None, noise: dict | None = None, sr: int = SR,
           fscale: float = 1.0, tilt: float = 1.1, bw: tuple = (90.0, 110.0, 170.0),
           fgain: tuple = (1.0, 0.75, 0.35), jitter: float = 0.012, shimmer: float = 0.06,
           rough: float = 0.0, rough_rate: float = 28.0, subharm: float = 0.0,
           max_freq: float = 9500.0, breath_level: float = 0.05, noise_level: float = 0.35,
           vibrato: float = 0.0, vib_rate: float = 5.5) -> np.ndarray:
    """Dựng tín hiệu từ các đường f0 (Hz), formant F (n,3), biên độ."""
    n = f0.shape[0]
    t = dsp.tvec(n, sr)
    jit = dsp.random_walk(n, rng, 35.0, sr) * jitter
    fz = f0 * (1.0 + jit) * (1.0 + vibrato * np.sin(dsp.TAU * vib_rate * t))
    fz = np.maximum(fz, 30.0)
    Fs = F * fscale
    bws = np.array(bw) * (0.6 + 0.4 * fscale)
    ph = dsp.phase_of(fz, sr=sr)
    K = int(max_freq / max(float(np.min(fz)), 40.0))
    out = np.zeros(n)

    def env_at(fk):
        e = np.full(n, 0.02)
        for j in range(3):
            e += fgain[j] / (1.0 + ((fk - Fs[:, j]) / (bws[j] / 2.0)) ** 2)
        return e

    for k in range(1, K + 1):
        fk = k * fz
        if float(np.min(fk)) > max_freq:
            break
        taper = np.clip((max_freq - fk) / 1500.0, 0.0, 1.0)
        out += (k ** -tilt) * env_at(fk) * taper * np.sin(k * ph)
    if subharm > 0:
        for k in range(1, K * 2 + 1, 2):
            fk = 0.5 * k * fz
            if float(np.min(fk)) > max_freq * 0.5:
                break
            out += subharm * ((0.5 * k) ** -tilt) * env_at(fk) * np.sin(0.5 * k * ph)
    if shimmer > 0:
        out *= 1.0 + shimmer * dsp.random_walk(n, rng, 25.0, sr)
    if rough > 0:
        rph = dsp.phase_of(rough_rate * (1.0 + 0.25 * dsp.random_walk(n, rng, 6.0, sr)), sr=sr)
        out *= 1.0 - rough * (0.5 + 0.5 * np.sin(rph))
    out *= amp
    # hơi thở / h: nhiễu qua formant
    if breath is not None and np.any(breath > 0):
        w = rng.standard_normal(n)
        hop = 128

        def g(tc, fr):
            idx = np.clip((tc[:, 0] * sr).astype(int), 0, n - 1)
            Fm = Fs[idx]
            e = np.full((idx.shape[0], fr.shape[1]), 0.03)
            for j in range(3):
                e += fgain[j] / (1.0 + ((fr - Fm[:, j:j + 1]) / (bws[j] * 1.6 / 2.0)) ** 2)
            return e

        bn = dsp.tv_filter(w, g, sr, nfft=512, hop=hop)
        bn /= np.std(bn) + 1e-9
        out += breath_level * breath * bn * 0.25
    if noise:
        for key, trk in noise.items():
            if trk is None or not np.any(trk > 0):
                continue
            lo, hi = NOISE_BANDS[key]
            w = dsp.band(rng.standard_normal(n), lo, hi, 3)
            w /= np.std(w) + 1e-9
            out += noise_level * trk * w * 0.25
    return out


# ---------------------------------------------------------------- gibberish
@dataclass
class Syl:
    onset: str
    vowel: str
    coda: str
    tone: str


ONSETS_W = [("", 3), ("b", 3), ("m", 3), ("l", 3), ("n", 2), ("d", 2), ("t", 2), ("k", 2),
            ("h", 2), ("s", 1), ("x", 1), ("g", 1)]
VOWELS_W = [("a", 5), ("o", 3), ("ô", 2), ("u", 3), ("i", 3), ("e", 2), ("ê", 1), ("ơ", 3), ("ư", 2), ("ă", 1)]
CODAS_W = [("", 7), ("m", 1), ("n", 2), ("ng", 2), ("i", 2)]
TONES_W = [("ngang", 4), ("sac", 4), ("huyen", 2), ("hoi", 2), ("nga", 1), ("nang", 2)]


def _pick(rng, table):
    items = [a for a, _ in table]
    w = np.array([b for _, b in table], float)
    return items[int(rng.choice(len(items), p=w / w.sum()))]


def random_syllables(rng: np.random.Generator, count: int) -> list[Syl]:
    out = []
    prev = None
    for _ in range(count):
        for _try in range(10):
            s = Syl(_pick(rng, ONSETS_W), _pick(rng, VOWELS_W), _pick(rng, CODAS_W), _pick(rng, TONES_W))
            if prev is None or (s.onset, s.vowel) != (prev.onset, prev.vowel):
                break
        if s.coda == "i" and s.vowel in ("i", "ê", "e"):
            s.coda = ""
        out.append(s)
        prev = s
    return out


def syllables_tracks(sylls: list[Syl], rng: np.random.Generator, *, tempo: float = 1.0,
                     sr: int = SR, phrase_every: tuple[int, int] = (3, 5),
                     ending: str = "statement") -> tuple[Tracks, list[int]]:
    """Chuỗi âm tiết -> các đường tham số. Trả tracks và chỉ số mẫu bắt đầu mỗi âm tiết."""
    tr = Tracks()
    starts = []
    pos = 0
    next_break = int(rng.integers(phrase_every[0], phrase_every[1] + 1))
    last_F = VOWELS["ơ"]
    for i, s in enumerate(sylls):
        starts.append(pos)
        V = VOWELS[s.vowel]
        is_last = i == len(sylls) - 1
        vdur = rng.uniform(0.085, 0.14) * tempo
        if s.tone == "nang":
            vdur *= 0.75
        if is_last:
            vdur *= 1.45
        nv = dsp.n_of(vdur, sr)
        # ---- phụ âm đầu
        o = s.onset
        if o == "":
            k = dsp.n_of(0.018, sr)
            tr.push(k, 1.0, V, np.linspace(0.0, 0.8, k), breath=np.linspace(0.3, 0.0, k))
            pos += k
        elif o in ("b", "d", "g"):
            k1 = dsp.n_of(0.016 * tempo, sr)
            tr.push(k1, 0.92, (250.0, 700.0, 2200.0), 0.07)
            k2 = dsp.n_of(0.006, sr)
            tr.push(k2, 0.95, (300.0, LOCUS[o], 2400.0), 0.25, noise={"p": 0.5})
            pos += k1 + k2
        elif o in ("m", "n"):
            k = dsp.n_of(0.05 * tempo, sr)
            nasal = NASAL_M if o == "m" else NASAL_N
            tr.push(k, 0.97, nasal, np.linspace(0.15, 0.4, k))
            pos += k
        elif o == "l":
            k = dsp.n_of(0.04 * tempo, sr)
            tr.push(k, 0.98, LIQUID_L, np.linspace(0.25, 0.55, k))
            pos += k
        elif o in ("t", "k"):
            k0 = dsp.n_of(0.028 * tempo, sr)
            tr.push(k0, 1.0, last_F, 0.0)
            k1 = dsp.n_of(0.012, sr)
            tr.push(k1, 1.0, V, 0.0, noise={o: np.linspace(1.0, 0.3, k1)})
            k2 = dsp.n_of(0.022, sr)
            tr.push(k2, 1.0, V, np.linspace(0.0, 0.3, k2), breath=np.linspace(1.0, 0.2, k2))
            pos += k0 + k1 + k2
        elif o == "h":
            k = dsp.n_of(0.05 * tempo, sr)
            tr.push(k, 1.0, V, np.linspace(0.0, 0.25, k), breath=np.linspace(0.2, 1.0, k))
            pos += k
        elif o in ("s", "x"):
            k = dsp.n_of(0.07 * tempo, sr)
            env = np.sin(np.linspace(0, math.pi, k)) ** 0.7
            tr.push(k, 1.0, V, 0.0, noise={o: env})
            k2 = dsp.n_of(0.008, sr)
            tr.push(k2, 1.0, V, 0.0)
            pos += k + k2
        # ---- nguyên âm (+ chuyển formant từ locus)
        tc = tone_curve(s.tone, nv)
        loc = LOCUS.get(o)
        ntr = min(nv, dsp.n_of(0.035, sr))
        start_F = (V[0] * 0.8, loc if loc else V[1], V[2]) if o else V
        F = np.concatenate([lerp_F(start_F, V, ntr), np.tile(V, (nv - ntr, 1))], axis=0)
        if s.coda == "i":
            ng = int(nv * 0.4)
            F[nv - ng:] = lerp_F(V, VOWELS["i"], ng)
        amp = np.ones(nv)
        ka = min(nv, dsp.n_of(0.012, sr))
        amp[:ka] *= np.linspace(0.6, 1.0, ka)
        if s.tone == "nang":
            kz = dsp.n_of(0.02, sr)
            amp[-kz:] *= np.linspace(1.0, 0.0, kz)
        if s.tone == "nga":
            mid = int(nv * 0.45)
            w = dsp.n_of(0.02, sr)
            amp[max(0, mid - w):mid + w] *= 0.55
        tr.push(nv, tc, F, amp)
        pos += nv
        last_F = V
        # ---- phụ âm cuối
        if s.coda in ("m", "n", "ng"):
            k = dsp.n_of(0.05 * tempo, sr)
            nasal = {"m": NASAL_M, "n": NASAL_N, "ng": NASAL_NG}[s.coda]
            tr.push(k, tc[-1], lerp_F(V, nasal, k), np.linspace(0.6, 0.0, k) ** 0.8)
            pos += k
        elif s.tone != "nang":
            k = dsp.n_of(0.03 * tempo, sr)
            tr.push(k, tc[-1], F[-1], np.linspace(1.0, 0.0, k) ** 1.5, breath=np.linspace(0.3, 0.0, k))
            pos += k
        # ---- khoảng nghỉ
        gap = rng.uniform(0.008, 0.03) * tempo
        if i + 1 == next_break and not is_last:
            gap += rng.uniform(0.09, 0.16) * tempo
            next_break += int(rng.integers(phrase_every[0], phrase_every[1] + 1))
        k = dsp.n_of(gap, sr)
        tr.push(k, tc[-1], F[-1], 0.0)
        pos += k
    return tr, starts


def gibberish(seed: int, voice: str, count: int, ending: str) -> np.ndarray:
    """Một câu ú ớ hư cấu. voice: 'female' | 'male'."""
    rng = dsp.rng_for(seed)
    if voice == "female":
        base = 232.0 * rng.uniform(0.94, 1.06)
        fscale, tempo, tilt, breath_lv, rng_pitch = 1.17, 0.9, 1.15, 0.09, 1.0
    else:
        base = 116.0 * rng.uniform(0.93, 1.06)
        fscale, tempo, tilt, breath_lv, rng_pitch = 1.0, 1.05, 1.0, 0.05, 0.85
    sylls = random_syllables(rng, count)
    tr, starts = syllables_tracks(sylls, rng, tempo=tempo, ending=ending)
    f0m, F, amp, br, nz = tr.arrays()
    n = f0m.shape[0]
    # làm mượt các đường tham số
    F = np.stack([dsp.smooth(F[:, j], 0.012) for j in range(3)], axis=1)
    amp = dsp.smooth(amp, 0.004)
    br = dsp.smooth(br, 0.003)
    nz = {k: dsp.smooth(v, 0.0015) for k, v in nz.items()}
    f0m = dsp.smooth(f0m, 0.02)
    x = np.linspace(0.0, 1.0, n)
    decl = 1.06 - 0.12 * x
    if ending == "question":
        decl = decl * (1.0 + 0.35 * np.clip((x - 0.86) / 0.14, 0, 1) ** 1.5)
    elif ending == "excl":
        decl = decl * (1.12 - 0.06 * x)
    elif ending == "laugh":
        decl = decl * (1.05 + 0.05 * np.sin(dsp.TAU * 3.0 * x))
    f0m = 1.0 + (f0m - 1.0) * rng_pitch
    f0 = base * f0m * decl
    y = render(f0, F, amp, rng, breath=br, noise=nz, fscale=fscale, tilt=tilt,
               breath_level=breath_lv * 4.0, jitter=0.01, shimmer=0.05,
               vibrato=0.006 if voice == "female" else 0.004)
    y = dsp.highpass(y, 80.0 if voice == "male" else 140.0, 2)
    y = dsp.filt(y, dsp.r_mul(dsp.r_peak(3000.0, 1500.0, 2.0), dsp.r_lp(9000.0, 2)))
    y = dsp.fade(y, 0.008, 0.02)
    lead = dsp.silence(0.03)
    tail = dsp.silence(0.08)
    y = dsp.concat(lead, y, tail)
    return y


def vocal(f0_pts, vowel_pts, dur: float, rng: np.random.Generator, *, fscale=1.0, amp_pts=None,
          rough=0.0, rough_rate=28.0, subharm=0.0, breath=0.0, tilt=1.1, jitter=0.012,
          vibrato=0.0, vib_rate=5.5, max_freq=9000.0, bw=(90.0, 110.0, 170.0)) -> np.ndarray:
    """Tiếng kêu không lời: f0_pts [(t, Hz)], vowel_pts [(t, 'a')], amp_pts [(t, a)]."""
    n = dsp.n_of(dur)
    f0 = dsp.env_points(f0_pts, n)
    ts = np.array([p[0] for p in vowel_pts]) * SR
    F = np.stack([np.interp(np.arange(n), ts, [VOWELS[v][j] if isinstance(v, str) else v[j]
                                                for _, v in vowel_pts]) for j in range(3)], axis=1)
    F = np.stack([dsp.smooth(F[:, j], 0.02) for j in range(3)], axis=1)
    amp = dsp.env_points(amp_pts, n) if amp_pts else np.ones(n)
    br = np.full(n, breath) if breath else None
    return render(f0, F, amp, rng, breath=br, fscale=fscale, rough=rough, rough_rate=rough_rate,
                  subharm=subharm, tilt=tilt, jitter=jitter, vibrato=vibrato, vib_rate=vib_rate,
                  max_freq=max_freq, bw=bw, breath_level=0.3 if breath else 0.05)
