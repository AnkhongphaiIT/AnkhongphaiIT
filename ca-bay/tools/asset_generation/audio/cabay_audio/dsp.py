"""Các khối DSP cơ bản (chỉ numpy), tất định theo seed.

Quy ước: tín hiệu float64 trong [-1, 1]; mono là mảng (n,), stereo là (n, 2).
Bộ lọc dùng miền tần số (pha 0) để không cần scipy; `circular=True` giữ tính
tuần hoàn cho các vòng lặp (loop) nhạc/âm nền.
"""
from __future__ import annotations

import math
from typing import Callable, Iterable, Sequence

import numpy as np

SR = 44100
TAU = 2.0 * math.pi


# ---------------------------------------------------------------- tiện ích
def n_of(sec: float, sr: int = SR) -> int:
    return int(round(sec * sr))


def tvec(n: int, sr: int = SR) -> np.ndarray:
    return np.arange(n, dtype=np.float64) / sr


def undb(d: float) -> float:
    return 10.0 ** (d / 20.0)


def todb(x: float) -> float:
    return 20.0 * math.log10(max(float(x), 1e-12))


def midi_hz(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def rng_for(seed: int) -> np.random.Generator:
    return np.random.default_rng(int(seed))


def fast_len(n: int) -> int:
    """Độ dài FFT >= n chỉ gồm thừa số 2, 3, 5 (nhanh với pocketfft)."""
    best = 1 << max(0, (n - 1).bit_length())
    p5 = 1
    while p5 < best:
        p35 = p5
        while p35 < best:
            p = p35
            while p < n:
                p *= 2
            if p < best:
                best = p
            p35 *= 3
        p5 *= 5
    return best


def zeros(n: int, ch: int = 1) -> np.ndarray:
    return np.zeros(n) if ch == 1 else np.zeros((n, ch))


def add_at(dst: np.ndarray, src: np.ndarray, pos: int, circular: bool = False) -> None:
    """Cộng src vào dst tại vị trí pos (mẫu). circular=True: phần tràn quấn về đầu."""
    n = dst.shape[0]
    m = src.shape[0]
    if m == 0:
        return
    if circular:
        pos %= n
        off = 0
        while off < m:
            p = (pos + off) % n
            k = min(m - off, n - p)
            dst[p:p + k] += src[off:off + k]
            off += k
        return
    if pos >= n or pos + m <= 0:
        return
    s0 = max(0, -pos)
    d0 = max(0, pos)
    k = min(m - s0, n - d0)
    dst[d0:d0 + k] += src[s0:s0 + k]


def pad_to(x: np.ndarray, n: int) -> np.ndarray:
    if x.shape[0] >= n:
        return x[:n]
    pad = [(0, n - x.shape[0])] + [(0, 0)] * (x.ndim - 1)
    return np.pad(x, pad)


def concat(*parts: np.ndarray) -> np.ndarray:
    return np.concatenate(parts, axis=0)


def silence(sec: float, sr: int = SR) -> np.ndarray:
    return np.zeros(n_of(sec, sr))


# ---------------------------------------------------------------- đường bao
def env_points(points: Sequence[tuple[float, float]], n: int, sr: int = SR) -> np.ndarray:
    ts = np.array([p[0] for p in points], dtype=float) * sr
    vs = np.array([p[1] for p in points], dtype=float)
    return np.interp(np.arange(n, dtype=float), ts, vs)


def env_perc(n: int, attack: float, tau: float, sr: int = SR, hold: float = 0.0) -> np.ndarray:
    t = tvec(n, sr)
    a = np.clip(t / max(attack, 1e-6), 0.0, 1.0)
    a = np.sin(a * math.pi / 2.0) ** 2
    d = np.where(t < attack + hold, 1.0, np.exp(-np.maximum(t - attack - hold, 0.0) / max(tau, 1e-6)))
    return _end_taper(a * d, sr)


def _end_taper(e: np.ndarray, sr: int = SR, sec: float = 0.005) -> np.ndarray:
    """Đưa đuôi mảng về 0 (raised-cosine) để cắt mảng không gây click."""
    k = min(e.shape[0] // 4, n_of(sec, sr))
    if k > 1:
        e = e.copy()
        e[-k:] *= 0.5 + 0.5 * np.cos(np.linspace(0.0, math.pi, k))
    return e


def env_adsr(n: int, a: float, d: float, s: float, r: float, gate: float, sr: int = SR) -> np.ndarray:
    """ADSR: gate = thời gian nhấn (giây). Nhả (release) dạng mũ."""
    t = tvec(n, sr)
    e = np.empty(n)
    ga = t < a
    e[ga] = np.sin(np.clip(t[ga] / max(a, 1e-6), 0, 1) * math.pi / 2) ** 2
    gd = (t >= a)
    e[gd] = s + (1.0 - s) * np.exp(-(t[gd] - a) / max(d, 1e-6))
    # mức tại thời điểm nhả
    if gate < a:
        lvl = math.sin(min(gate / max(a, 1e-6), 1.0) * math.pi / 2) ** 2
    else:
        lvl = s + (1.0 - s) * math.exp(-(gate - a) / max(d, 1e-6))
    gr = t >= gate
    e[gr] = lvl * np.exp(-(t[gr] - gate) / max(r, 1e-6))
    # nhả về đúng 0 ở cuối mảng (tránh click khi mảng bị cắt)
    T = n / sr
    if T > gate:
        x = np.clip((t[gr] - gate) / (T - gate), 0.0, 1.0)
        e[gr] *= 0.5 + 0.5 * np.cos(math.pi * x)
    return _end_taper(e, sr, 0.003)


def fade(x: np.ndarray, fin: float = 0.005, fout: float = 0.005, sr: int = SR) -> np.ndarray:
    """Fade raised-cosine ở hai đầu (giây)."""
    y = x.copy()
    n = y.shape[0]
    for length, head in ((fin, True), (fout, False)):
        k = min(n, n_of(length, sr))
        if k <= 1:
            continue
        ramp = 0.5 - 0.5 * np.cos(np.linspace(0.0, math.pi, k))
        if y.ndim == 2:
            ramp = ramp[:, None]
        if head:
            y[:k] *= ramp
        else:
            y[n - k:] *= ramp[::-1]
    return y


def smooth(x: np.ndarray, sec: float, sr: int = SR) -> np.ndarray:
    """Làm mượt bằng trung bình trượt (giữ độ dài)."""
    k = max(1, n_of(sec, sr))
    if k == 1:
        return x.copy()
    ker = np.ones(k) / k
    return np.convolve(np.pad(x, (k // 2, k - 1 - k // 2), mode="edge"), ker, mode="valid")


def random_walk(n: int, rng: np.random.Generator, rate_hz: float, sr: int = SR,
                circular: bool = False) -> np.ndarray:
    """Nhiễu tần thấp chuẩn hóa ~[-1, 1] (điều biến chậm)."""
    w = rng.standard_normal(n)
    y = filt(w, r_lp(rate_hz, 2), sr=sr, circular=circular)
    m = np.max(np.abs(y)) or 1.0
    return y / m


# ---------------------------------------------------------------- dao động
def phase_of(freq, n: int | None = None, sr: int = SR, phase0: float = 0.0) -> np.ndarray:
    f = np.asarray(freq, dtype=float)
    if f.ndim == 0:
        assert n is not None
        return phase0 + TAU * f * np.arange(n) / sr
    return phase0 + TAU * np.concatenate(([0.0], np.cumsum(f[:-1]))) / sr


def osc_sine(freq, n: int | None = None, sr: int = SR, phase0: float = 0.0) -> np.ndarray:
    return np.sin(phase_of(freq, n, sr, phase0))


def osc_harmonics(freq, amps: Sequence[float] | Callable[[int], float], n: int | None = None,
                  sr: int = SR, max_freq: float = 16000.0, nharm: int | None = None,
                  phase0: float = 0.0) -> np.ndarray:
    """Tổng hợp cộng hài có giới hạn băng (không aliasing)."""
    f = np.asarray(freq, dtype=float)
    if f.ndim == 0:
        f = np.full(n, float(f))
    ph = phase_of(f, sr=sr, phase0=phase0)
    fmin = max(float(np.min(f)), 1.0)
    if callable(amps):
        K = nharm or int(max_freq / fmin)
        getter = amps
    else:
        K = len(amps)
        getter = lambda k: amps[k - 1]  # noqa: E731
    out = np.zeros(f.shape[0])
    for k in range(1, K + 1):
        a = getter(k)
        if a == 0.0:
            continue
        fk = k * f
        if float(np.min(fk)) > max_freq:
            break
        taper = np.clip((max_freq - fk) / (0.15 * max_freq), 0.0, 1.0)
        out += a * taper * np.sin(k * ph)
    return out


def osc_saw(freq, n: int | None = None, sr: int = SR, tilt: float = 1.0, max_freq: float = 14000.0) -> np.ndarray:
    return osc_harmonics(freq, lambda k: (1.0 / k ** tilt), n, sr, max_freq)


def osc_square(freq, n: int | None = None, sr: int = SR, tilt: float = 1.0, max_freq: float = 14000.0) -> np.ndarray:
    return osc_harmonics(freq, lambda k: (1.0 / k ** tilt) if k % 2 else 0.0, n, sr, max_freq)


def osc_tri(freq, n: int | None = None, sr: int = SR, max_freq: float = 12000.0) -> np.ndarray:
    return osc_harmonics(freq, lambda k: ((-1) ** ((k - 1) // 2)) / (k * k) if k % 2 else 0.0, n, sr, max_freq)


# ---------------------------------------------------------------- nhiễu
def white(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n)


def colored(n: int, rng: np.random.Generator, slope_db_oct: float, sr: int = SR,
            circular: bool = False) -> np.ndarray:
    """Nhiễu màu: slope -3 dB/oct = hồng, -6 = nâu."""
    w = rng.standard_normal(n)
    p = slope_db_oct / (20.0 * math.log10(2.0))
    y = filt(w, lambda f: np.power(np.maximum(f, 20.0) / 1000.0, p), sr=sr, circular=circular)
    return y / (np.std(y) + 1e-12)


# ---------------------------------------------------------------- lọc miền tần số
Resp = Callable[[np.ndarray], np.ndarray]


def r_lp(fc: float, order: float = 2) -> Resp:
    return lambda f: 1.0 / np.sqrt(1.0 + (np.asarray(f) / fc) ** (2 * order))


def r_hp(fc: float, order: float = 2) -> Resp:
    return lambda f: 1.0 / np.sqrt(1.0 + (fc / np.maximum(np.asarray(f), 1e-3)) ** (2 * order))


def r_bp(fc: float, q: float) -> Resp:
    return lambda f: 1.0 / np.sqrt(1.0 + q * q * (np.maximum(np.asarray(f), 1e-3) / fc - fc / np.maximum(np.asarray(f), 1e-3)) ** 2)


def r_band(lo: float, hi: float, order: float = 2) -> Resp:
    a, b = r_hp(lo, order), r_lp(hi, order)
    return lambda f: a(f) * b(f)


def r_peak(fc: float, bw: float, gain_db: float) -> Resp:
    g = undb(gain_db)
    return lambda f: 1.0 + (g - 1.0) / (1.0 + ((np.asarray(f) - fc) / (bw / 2.0)) ** 2)


def r_shelf_hi(fc: float, gain_db: float) -> Resp:
    g = undb(gain_db)
    return lambda f: 1.0 + (g - 1.0) / (1.0 + (fc / np.maximum(np.asarray(f), 1e-3)) ** 2)


def r_mul(*rs: Resp) -> Resp:
    def fn(f):
        out = np.ones_like(np.asarray(f, dtype=float))
        for r in rs:
            out = out * r(f)
        return out
    return fn


def r_sum(*pairs: tuple[float, Resp]) -> Resp:
    def fn(f):
        out = np.zeros_like(np.asarray(f, dtype=float))
        for w, r in pairs:
            out = out + w * r(f)
        return out
    return fn


def filt(x: np.ndarray, resp: Resp | np.ndarray, sr: int = SR, circular: bool = False,
         pad: float = 0.25) -> np.ndarray:
    """Lọc pha 0 bằng FFT. x mono (n,) hoặc (n, c)."""
    if x.ndim == 2:
        return np.stack([filt(x[:, c], resp, sr, circular, pad) for c in range(x.shape[1])], axis=1)
    n = x.shape[0]
    if n == 0:
        return x.copy()
    nfft = n if circular else fast_len(n + max(2048, n_of(pad, sr)))
    X = np.fft.rfft(x, nfft)
    f = np.fft.rfftfreq(nfft, 1.0 / sr)
    H = resp(f) if callable(resp) else resp
    y = np.fft.irfft(X * H, nfft)
    return y[:n]


def lowpass(x, fc, order=2, **kw):
    return filt(x, r_lp(fc, order), **kw)


def highpass(x, fc, order=2, **kw):
    return filt(x, r_hp(fc, order), **kw)


def bandpass(x, fc, q, **kw):
    return filt(x, r_bp(fc, q), **kw)


def band(x, lo, hi, order=2, **kw):
    return filt(x, r_band(lo, hi, order), **kw)


def tv_filter(x: np.ndarray, gain_fn: Callable[[np.ndarray, np.ndarray], np.ndarray],
              sr: int = SR, nfft: int = 1024, hop: int = 256, circular: bool = False) -> np.ndarray:
    """Lọc biến thiên theo thời gian qua STFT.

    gain_fn(t, f) nhận t (frames, 1) giây tính từ đầu x và f (1, bins) Hz, trả về
    độ lợi (frames, bins). circular=True: tín hiệu được coi là tuần hoàn; gain_fn
    phải tự xử lý t < 0 hoặc t >= độ dài (vd. np.mod).
    """
    if x.ndim == 2:
        return np.stack([tv_filter(x[:, c], gain_fn, sr, nfft, hop, circular) for c in range(x.shape[1])], axis=1)
    n = x.shape[0]
    ratio = nfft // hop
    assert nfft % hop == 0
    if circular:
        assert n > nfft
        xp = np.concatenate([x[-nfft:], x, x[:nfft]])
    else:
        xp = np.concatenate([np.zeros(nfft), x, np.zeros(nfft)])
    L = xp.shape[0]
    nframes = 1 + (L - nfft) // hop
    win = 0.5 - 0.5 * np.cos(TAU * np.arange(nfft) / nfft)
    idx = np.arange(nfft)[None, :] + hop * np.arange(nframes)[:, None]
    X = np.fft.rfft(xp[idx] * win, axis=1)
    centers = (hop * np.arange(nframes) + nfft / 2.0 - nfft) / sr
    freqs = np.fft.rfftfreq(nfft, 1.0 / sr)
    G = gain_fn(centers[:, None], freqs[None, :])
    Y = np.fft.irfft(X * G, n=nfft, axis=1) * win
    out = np.zeros(L + nfft)
    norm = np.zeros(L + nfft)
    w2 = win * win
    for r in range(ratio):
        sel = Y[r::ratio]
        if sel.shape[0] == 0:
            continue
        flat = sel.reshape(-1)
        start = r * hop
        out[start:start + flat.shape[0]] += flat
        norm[start:start + flat.shape[0]] += np.tile(w2, sel.shape[0])
    out = out[:L] / np.maximum(norm[:L], 1e-6)
    return out[nfft:nfft + n]


# ---------------------------------------------------------------- tổng hợp mode (chuông, gỗ)
def modal(n: int, freqs: Iterable[float], taus: Iterable[float], amps: Iterable[float],
          sr: int = SR, rng: np.random.Generator | None = None, attack: float = 0.0005) -> np.ndarray:
    t = tvec(n, sr)
    out = np.zeros(n)
    for i, (f, tau, a) in enumerate(zip(freqs, taus, amps)):
        if f <= 0 or f >= 0.47 * sr or a == 0:
            continue
        ph = float(rng.uniform(0, TAU)) if rng is not None else 0.0
        out += a * np.exp(-t / tau) * np.sin(TAU * f * t + ph)
    if attack > 0:
        k = max(1, n_of(attack, sr))
        out[:k] *= np.linspace(0.0, 1.0, k)
    return _end_taper(out, sr, 0.01)


def bell(n: int, f0: float, sr: int = SR, decay: float = 0.8, bright: float = 1.0,
         ratios: Sequence[float] = (1.0, 2.0, 2.76, 4.07, 5.4, 8.93),
         rel_amps: Sequence[float] = (1.0, 0.35, 0.45, 0.2, 0.18, 0.08),
         rng: np.random.Generator | None = None) -> np.ndarray:
    freqs = [f0 * r for r in ratios]
    taus = [decay / (r ** 0.6) for r in ratios]
    amps = [a * (bright ** i) for i, a in enumerate(rel_amps)]
    return modal(n, freqs, taus, amps, sr, rng)


# ---------------------------------------------------------------- Karplus-Strong
def _lagrange(D: float, order: int = 3) -> np.ndarray:
    h = np.ones(order + 1)
    for k in range(order + 1):
        for m in range(order + 1):
            if m != k:
                h[k] *= (D - m) / (k - m)
    return h


def ks_pluck(freq: float, n: int, rng: np.random.Generator, t60: float = 1.5, damp: float = 0.18,
             pick: float = 0.2, bright: float = 0.6, sr: int = SR) -> np.ndarray:
    """Dây gảy Karplus-Strong có trễ phân số (Lagrange) - vector hóa theo khối chu kỳ."""
    P = sr / freq
    N0 = int(math.floor(P - 2.0))
    D = P - 1.0 - N0
    lp = np.array([damp, 1.0 - 2.0 * damp, damp])
    taps = np.convolve(lp, _lagrange(D))  # trễ N0 .. N0+5
    g = 10.0 ** (-3.0 / (t60 * freq))
    L0 = N0 + len(taps)
    exc = rng.uniform(-1.0, 1.0, L0)
    # làm tối kích thích theo bright (lọc 1 cực, vòng lặp ngắn)
    a = 0.05 + 0.9 * bright
    for i in range(1, L0):
        exc[i] = a * exc[i] + (1 - a) * exc[i - 1]
    k = max(1, int(pick * L0))
    exc = exc - np.roll(exc, k)
    exc -= np.mean(exc)
    exc /= (np.max(np.abs(exc)) + 1e-9)
    y = np.zeros(max(n, L0 + 1))
    y[:L0] = exc
    start = L0
    total = y.shape[0]
    while start < total:
        end = min(start + N0, total)
        acc = np.zeros(end - start)
        for j, h in enumerate(taps):
            acc += h * y[start - N0 - j:end - N0 - j]
        y[start:end] = g * acc
        start = end
    return y[:n]


# ---------------------------------------------------------------- vang (reverb)
def reverb_ir(rng: np.random.Generator, rt60: float = 1.6, predelay: float = 0.012, sr: int = SR,
              stereo: bool = True, tone: tuple[float, float, float] = (1.0, 0.7, 0.4),
              early: int = 7) -> np.ndarray:
    n = n_of(predelay + rt60 * 1.05, sr)
    chans = []
    t = tvec(n, sr)
    for _ in range(2 if stereo else 1):
        w = rng.standard_normal(n)
        lo = lowpass(w, 900.0, 2)
        mid = band(w, 900.0, 4000.0, 2)
        hi = highpass(w, 4000.0, 2)
        ir = np.zeros(n)
        for comp, k in zip((lo, mid, hi), tone):
            ir += comp * np.exp(-6.9078 * t / max(rt60 * k, 1e-3))
        pd = n_of(predelay, sr)
        ir[:pd] = 0.0
        ramp = min(n - pd, n_of(0.004, sr))
        ir[pd:pd + ramp] *= np.linspace(0, 1, ramp)
        for _e in range(early):
            d = pd + int(rng.uniform(0.002, 0.045) * sr)
            if d < n:
                ir[d] += rng.uniform(-1.0, 1.0) * 6.0
        ir /= np.sqrt(np.sum(ir * ir)) + 1e-12
        chans.append(ir)
    return np.stack(chans, axis=1) if stereo else chans[0]


def convolve(x: np.ndarray, ir: np.ndarray, circular: bool = False) -> np.ndarray:
    """Tích chập FFT. x (n,) / (n, c); ir (m,) / (m, c). circular giữ độ dài n (quấn đuôi)."""
    if x.ndim == 1 and ir.ndim == 2:
        x = np.stack([x] * ir.shape[1], axis=1)
    if x.ndim == 2:
        cols = []
        for c in range(x.shape[1]):
            h = ir[:, c % ir.shape[1]] if ir.ndim == 2 else ir
            cols.append(convolve(x[:, c], h, circular))
        return np.stack(cols, axis=1)
    n, m = x.shape[0], ir.shape[0]
    if circular:
        h = np.zeros(n)
        for s in range(0, m, n):
            seg = ir[s:s + n]
            h[:seg.shape[0]] += seg
        return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(h), n)
    nfft = fast_len(n + m - 1)
    return np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[:n + m - 1]


def add_reverb(x: np.ndarray, rng: np.random.Generator, wet: float = 0.2, rt60: float = 1.2,
               predelay: float = 0.01, tone=(1.0, 0.7, 0.4)) -> np.ndarray:
    """Vang cho SFX mono (không tuần hoàn): trả mono cùng độ dài + đuôi cắt theo n gốc + rt60."""
    ir = reverb_ir(rng, rt60, predelay, stereo=False, tone=tone)
    wet_sig = convolve(x, ir)
    out = np.zeros(wet_sig.shape[0])
    out[:x.shape[0]] += x
    out += wet * wet_sig * (np.sqrt(np.sum(x * x)) / (np.sqrt(np.sum(wet_sig * wet_sig)) + 1e-12))
    return out


# ---------------------------------------------------------------- mức, pan
def peak(x: np.ndarray) -> float:
    return float(np.max(np.abs(x))) if x.size else 0.0


def normalize_peak(x: np.ndarray, peak_db: float) -> np.ndarray:
    p = peak(x)
    return x if p <= 0 else x * (undb(peak_db) / p)


def pan_stereo(x: np.ndarray, pan: float) -> np.ndarray:
    """pan -1 (trái) .. +1 (phải), luật công suất bằng nhau."""
    a = (pan + 1.0) * math.pi / 4.0
    return np.stack([x * math.cos(a), x * math.sin(a)], axis=1)


def limit(x: np.ndarray, ceiling_db: float, sr: int = SR, release: float = 0.08, block: int = 64) -> np.ndarray:
    """Limiter đơn giản: tính độ lợi theo khối, giữ-min + nhả mượt, rồi kẹp an toàn."""
    c = undb(ceiling_db)
    a = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)
    n = a.shape[0]
    nb = (n + block - 1) // block
    ap = np.pad(a, (0, nb * block - n))
    bmax = ap.reshape(nb, block).max(axis=1)
    need = np.minimum(1.0, c / np.maximum(bmax, 1e-12))
    # giữ-min với hàng xóm (lookahead 2 khối mỗi phía) -> nội suy tuyến tính không vượt mức cần
    g = need.copy()
    for sh in (1, 2):
        g[sh:] = np.minimum(g[sh:], need[:-sh])
        g[:-sh] = np.minimum(g[:-sh], need[sh:])
    # nhả mượt: tái tạo dạng mũ theo khối (vòng lặp ngắn trên số khối)
    coef = math.exp(-block / max(release * sr, 1.0))
    out = np.empty_like(g)
    cur = 1.0
    for i in range(nb):
        cur = g[i] if g[i] < cur else g[i] + (cur - g[i]) * coef
        out[i] = cur
    gs = np.interp(np.arange(n), np.arange(nb) * block + block / 2.0, out)
    y = x * (gs if x.ndim == 1 else gs[:, None])
    return np.clip(y, -c, c)


# ---------------------------------------------------------------- độ to (BS.1770 ước lượng)
_K1_B = (1.53512485958697, -2.69169618940638, 1.19839281085285)
_K1_A = (1.0, -1.69065929318241, 0.73248077421585)
_K2_B = (1.0, -2.0, 1.0)
_K2_A = (1.0, -1.99004745483398, 0.99007225036621)


def _biquad_mag(b, a, f, fs=48000.0):
    w = TAU * np.minimum(np.asarray(f, dtype=float), fs / 2 - 1) / fs
    z1 = np.exp(-1j * w)
    z2 = z1 * z1
    return np.abs((b[0] + b[1] * z1 + b[2] * z2) / (a[0] + a[1] * z1 + a[2] * z2))


def k_weight(f: np.ndarray) -> np.ndarray:
    return _biquad_mag(_K1_B, _K1_A, f) * _biquad_mag(_K2_B, _K2_A, f)


def loudness_lufs(x: np.ndarray, sr: int = SR, circular: bool = False) -> float:
    """Ước lượng integrated loudness (LUFS) theo BS.1770 (K-weighting pha 0, gate -70/-10)."""
    xs = x[:, None] if x.ndim == 1 else x
    y = np.stack([filt(xs[:, c], k_weight, sr, circular=circular) for c in range(xs.shape[1])], axis=1)
    n = y.shape[0]
    blk, step = n_of(0.4, sr), n_of(0.1, sr)
    if n < blk:
        z = float(np.sum(np.mean(y * y, axis=0)))
        return -0.691 + 10.0 * math.log10(max(z, 1e-20))
    sq = np.cumsum(np.concatenate([np.zeros((1, y.shape[1])), y * y]), axis=0)
    starts = np.arange(0, n - blk + 1, step)
    ms = (sq[starts + blk] - sq[starts]) / blk
    z = np.sum(ms, axis=1)
    lj = -0.691 + 10.0 * np.log10(np.maximum(z, 1e-20))
    g1 = lj > -70.0
    if not np.any(g1):
        return -120.0
    gamma = -0.691 + 10.0 * math.log10(float(np.mean(z[g1]))) - 10.0
    g2 = g1 & (lj > gamma)
    return -0.691 + 10.0 * math.log10(float(np.mean(z[g2])))


def normalize_loudness(x: np.ndarray, target_lufs: float, ceiling_db: float, sr: int = SR,
                       circular: bool = False) -> np.ndarray:
    """Đưa về độ to mục tiêu; nếu vượt trần peak thì dùng limiter nhẹ."""
    cur = loudness_lufs(x, sr, circular)
    y = x * undb(target_lufs - cur)
    if peak(y) > undb(ceiling_db):
        y = limit(y, ceiling_db - 0.1, sr)
        # bù lại một phần độ to đã mất do limiter (tối đa 1 vòng)
        cur2 = loudness_lufs(y, sr, circular)
        if cur2 < target_lufs - 0.5:
            y = limit(y * undb(min(target_lufs - cur2, 3.0)), ceiling_db - 0.1, sr)
    return y


def to_stereo(x: np.ndarray) -> np.ndarray:
    return x if x.ndim == 2 else np.stack([x, x], axis=1)
