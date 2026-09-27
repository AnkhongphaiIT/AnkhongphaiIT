"""Âm nền (ambience) nguyên bản, stereo, render vòng tròn để loop liền (>= 30 s).

Nước, gió, chim, côn trùng, ghe xa, sóng: tổng hợp từ nhiễu lọc + dao động,
mọi điều biến chậm đều tuần hoàn theo độ dài vòng lặp; sự kiện (chim, bọt, sóng)
đặt với quấn vòng nên điểm nối không lộ. Mức ~ -26 LUFS.
"""
from __future__ import annotations

import math

import numpy as np

from . import dsp
from .dsp import SR, TAU, n_of, tvec


# ================================================================ lớp nền
def _noise2(n, rng):
    return rng.standard_normal(n), rng.standard_normal(n)


def bed(n, rng, resp, mod_rate=0.0, mod_depth=0.0, corr=0.3):
    """Nhiễu stereo đã lọc (tương quan một phần), điều biến biên độ chậm tuần hoàn."""
    common = rng.standard_normal(n)
    chans = []
    for _ in range(2):
        w = corr * common + (1 - corr) * rng.standard_normal(n)
        y = dsp.filt(w, resp, circular=True)
        y /= np.std(y) + 1e-9
        if mod_depth > 0:
            m = dsp.random_walk(n, rng, mod_rate, circular=True)
            y *= (1.0 - mod_depth) + mod_depth * (0.5 + 0.5 * m)
        chans.append(y)
    return np.stack(chans, axis=1)


def gusts(n, rng, rate, floor=0.25):
    m = dsp.random_walk(n, rng, rate, circular=True)
    return floor + (1 - floor) * np.clip(0.5 + 0.6 * m, 0, 1)


def place(dst, mono, t, pan=0.0, gain=1.0):
    dsp.add_at(dst, dsp.pan_stereo(mono * gain, pan), n_of(t), circular=True)


# ================================================================ sự kiện
def chirp_note(rng, f0, f1, dur, vib=0.0, vib_rate=30.0, harm=0.15):
    n = n_of(dur)
    t = tvec(n)
    f = f0 * (f1 / f0) ** (t / dur) * (1 + vib * np.sin(TAU * vib_rate * t))
    ph = dsp.phase_of(f)
    y = np.sin(ph) + harm * np.sin(2 * ph)
    return y * np.sin(math.pi * np.clip(t / dur, 0, 1)) ** 1.5


def bird(rng, kind):
    parts = []
    if kind == "tweet":
        k = int(rng.integers(2, 5))
        base = rng.uniform(3400, 4600)
        for i in range(k):
            parts.append((i * rng.uniform(0.11, 0.15), chirp_note(rng, base * (1 - 0.04 * i), base * 0.72, rng.uniform(0.05, 0.08), 0.02)))
    elif kind == "trill":
        k = int(rng.integers(8, 14))
        base = rng.uniform(3000, 4000)
        for i in range(k):
            parts.append((i * 0.04, chirp_note(rng, base * (1 + 0.01 * i), base * 1.12, 0.028)))
    elif kind == "whistle":
        a = rng.uniform(2100, 2700)
        parts.append((0.0, chirp_note(rng, a, a * 1.05, 0.16, 0.01, 6.0)))
        parts.append((0.22, chirp_note(rng, a * 0.78, a * 0.74, 0.22, 0.012, 6.0)))
    elif kind == "koel":
        a = rng.uniform(650, 760)
        for i in range(3):
            parts.append((i * 0.55, chirp_note(rng, a * (1 + 0.06 * i), a * 1.45 * (1 + 0.06 * i), 0.36, 0.0, 0.0, 0.25)))
    elif kind == "bulbul":
        seq = [1.0, 1.25, 1.12, 1.4, 1.0]
        a = rng.uniform(1500, 1900)
        for i, r in enumerate(seq):
            parts.append((i * 0.1, chirp_note(rng, a * r, a * r * 1.08, 0.08, 0.01, 12.0, 0.2)))
    total = max(tp + p.shape[0] / SR for tp, p in parts) + 0.05
    y = np.zeros(n_of(total))
    for tp, p in parts:
        dsp.add_at(y, p, n_of(tp))
    return y


def gull(rng):
    y = np.zeros(n_of(1.4))
    for i in range(int(rng.integers(2, 4))):
        dur = rng.uniform(0.3, 0.42)
        n = n_of(dur)
        t = tvec(n)
        f = np.interp(t, [0, dur * 0.3, dur], [950, 1500, 820]) * rng.uniform(0.95, 1.05)
        x = dsp.osc_harmonics(f, lambda k: k ** -1.1, n, max_freq=7000)
        x *= 1 - 0.4 * (0.5 + 0.5 * np.sin(TAU * 55 * t))
        x = dsp.filt(x, dsp.r_mul(dsp.r_band(900, 4500, 2), dsp.r_peak(2200, 900, 6)))
        x *= np.sin(math.pi * np.clip(t / dur, 0, 1)) ** 0.8
        dsp.add_at(y, x, n_of(i * rng.uniform(0.42, 0.5)))
    return y


def bubble(f0, dur=0.04):
    n = n_of(dur)
    t = tvec(n)
    f = f0 * (1.9 ** np.clip(t / (dur * 0.6), 0, 1))
    return dsp.fade(np.sin(dsp.phase_of(f)) * np.exp(-t / (dur * 0.35)) * np.clip(t / 0.002, 0, 1), 0.0, dur * 0.3)


def insects(n, rng, carrier, pulse_rate, pulses, period, level, width=0.012):
    """Dế: chuỗi xung hình sin, lặp theo chu kỳ (số chu kỳ nguyên trong vòng lặp)."""
    L = n / SR
    reps = max(1, int(round(L / period)))
    period = L / reps
    t = tvec(n)
    ph = (t % period)
    env = np.zeros(n)
    for i in range(pulses):
        c = i / pulse_rate
        env += np.exp(-0.5 * ((ph - c - width) / (width / 2.5)) ** 2)
    slow = 0.6 + 0.4 * dsp.random_walk(n, rng, 0.15, circular=True)
    cyc = round(carrier * L)
    return np.sin(TAU * (cyc / L) * t) * env * slow * level


def cicada(n, rng, level):
    w = dsp.band(rng.standard_normal(n), 4800, 7600, 3, circular=True)
    w /= np.std(w) + 1e-9
    L = n / SR
    am_hz = round(92 * L) / L
    am = (0.5 + 0.5 * np.sign(np.sin(TAU * am_hz * tvec(n)))) * 0.7 + 0.3
    sw = np.clip(0.5 + 0.8 * dsp.random_walk(n, rng, 0.05, circular=True), 0, 1) ** 2
    return w * am * sw * level


def boat_putt(n, rng, start, length, level):
    """Ghe máy xa: 'bạch bạch' 5,5 Hz, lọc thấp, lên rồi tắt dần."""
    y = np.zeros(n)
    rate = 5.5
    k = int(length * rate)
    for i in range(k):
        tt = start + i / rate + rng.normal(0, 0.004)
        x = i / max(k - 1, 1)
        a = math.sin(math.pi * x) ** 1.5 * rng.uniform(0.8, 1.0)
        m = n_of(0.12)
        tp = tvec(m)
        p = np.sin(TAU * 58 * tp) * np.exp(-tp / 0.03) + 0.6 * dsp.lowpass(rng.standard_normal(m), 400) * np.exp(-tp / 0.02)
        dsp.add_at(y, p * a, n_of(tt), circular=True)
    y = dsp.lowpass(y, 380, 2, circular=True)
    return y / (dsp.peak(y) + 1e-9) * level


def wave_event(rng, dur=6.0):
    n = n_of(dur)
    t = tvec(n)
    L = []
    for _ in range(2):
        w = rng.standard_normal(n)
        rumble = dsp.lowpass(w, 260, 2) * np.clip(t / 1.4, 0, 1) ** 2 * np.exp(-np.maximum(t - 1.6, 0) / 0.8)
        crash_env = np.where(t < 1.4, 0.0, np.clip((t - 1.4) / 0.35, 0, 1) ** 1.5 * np.exp(-np.maximum(t - 1.75, 0) / 1.0))
        crash = dsp.band(w, 150, 6000, 2) * crash_env
        wash_env = np.where(t < 1.8, 0.0, np.clip((t - 1.8) / 0.5, 0, 1) * np.exp(-np.maximum(t - 2.3, 0) / 1.4))
        wash = dsp.band(rng.standard_normal(n), 1500, 9000, 2) * wash_env
        fizz = np.zeros(n)
        for _k in range(160):
            tt = rng.uniform(2.0, dur - 0.1)
            g = dsp.band(rng.standard_normal(n_of(0.004)), 3000, 10000, 2) * np.hanning(n_of(0.004))
            dsp.add_at(fizz, g * math.exp(-(tt - 2.0) / 1.6) * rng.uniform(0.2, 1.0), n_of(tt))
        ch = 0.8 * rumble / (np.std(rumble) + 1e-9) + crash / (np.std(crash) + 1e-9) + \
            0.6 * wash / (np.std(wash) + 1e-9) + 0.3 * fizz / (np.std(fizz) + 1e-9)
        L.append(ch)
    y = np.stack(L, axis=1)
    return y * np.sin(math.pi * np.clip(t / dur, 0, 1))[:, None] ** 0.3


def _finish(mix, rng, target=-26.0, ceiling=-6.0, rt60=0.9, wet=0.15):
    ir = dsp.reverb_ir(dsp.rng_for(11), rt60=rt60, predelay=0.03, stereo=True)
    mix = mix + wet * dsp.convolve(mix, ir, circular=True)
    mix = dsp.highpass(mix, 35.0, 2, circular=True)
    return dsp.normalize_loudness(mix, target, ceiling, circular=True)


# ================================================================ các vòng âm nền
def amb_river(seed: int) -> np.ndarray:
    """Đảo 1 (sông): nước chảy róc rách, gió nhẹ, chim, dế xa, ghe máy xa."""
    rng = dsp.rng_for(seed)
    n = n_of(40.0)
    water = bed(n, rng, dsp.r_mul(dsp.r_band(70, 2200, 1.5), dsp.r_peak(500, 400, 3)), 0.4, 0.3)
    babble = np.zeros((n, 2))
    for lo, hi, rate, g in ((350, 800, 4.0, 0.5), (800, 1700, 6.0, 0.35), (1700, 3200, 9.0, 0.12)):
        b = bed(n, rng, dsp.r_band(lo, hi, 2), rate, 0.85)
        babble += g * b
    bub = np.zeros((n, 2))
    for _ in range(220):
        place(bub, bubble(rng.uniform(450, 1500), rng.uniform(0.02, 0.05)), rng.uniform(0, 40), rng.uniform(-0.7, 0.7),
              rng.uniform(0.1, 0.5))
    wind = bed(n, rng, dsp.r_band(80, 700, 2), 0.1, 0.0) * gusts(n, rng, 0.08)[:, None]
    birds = np.zeros((n, 2))
    times = np.sort(rng.uniform(0, 40, 9))
    for i, tt in enumerate(times):
        kind = ("tweet", "whistle", "trill")[i % 3]
        place(birds, bird(rng, kind), tt, rng.uniform(-0.8, 0.8), rng.uniform(0.5, 1.0))
    birds = dsp.filt(birds, dsp.r_lp(7000, 2), circular=True)
    ins = insects(n, rng, 4700.0, 32.0, 4, 0.7, 1.0)
    ins = np.stack([ins, np.roll(ins, n_of(0.23))], axis=1)
    boat = boat_putt(n, rng, 14.0, 16.0, 1.0)
    boat = dsp.pan_stereo(boat, -0.4)
    mix = 1.0 * water + 0.45 * babble + 0.9 * bub + 0.45 * wind + 2.2 * birds + 0.08 * ins + 0.45 * boat
    return _finish(mix, rng)


def amb_isl02(seed: int) -> np.ndarray:
    """Đảo 2 (rừng dừa): gió lá dừa xào xạc, lạch nước nhẹ, chim nhiệt đới, ve."""
    rng = dsp.rng_for(seed)
    n = n_of(42.0)
    g = gusts(n, rng, 0.07, 0.2)
    wind = bed(n, rng, dsp.r_band(300, 3500, 1.5), 0.3, 0.3, corr=0.1) * g[:, None]
    rustle = np.zeros((n, 2))
    for _ in range(2600):
        tt = rng.uniform(0, 42)
        gg = dsp.band(rng.standard_normal(n_of(0.006)), 2000, 8000, 2) * np.hanning(n_of(0.006))
        place(rustle, gg, tt, rng.uniform(-0.9, 0.9), rng.uniform(0.2, 1.0))
    rustle *= (g ** 2)[:, None]
    water = bed(n, rng, dsp.r_band(100, 900, 2), 0.25, 0.6)
    t = tvec(n)
    lap = 0.6 + 0.4 * np.sin(TAU * round(42 / 4.2) / 42 * t) ** 2
    water *= lap[:, None]
    bub = np.zeros((n, 2))
    for _ in range(90):
        place(bub, bubble(rng.uniform(500, 1300), 0.035), rng.uniform(0, 42), rng.uniform(-0.5, 0.5), rng.uniform(0.1, 0.4))
    birds = np.zeros((n, 2))
    kinds = ["koel", "bulbul", "tweet", "bulbul", "whistle", "koel", "tweet", "bulbul", "trill", "tweet"]
    times = np.sort(rng.uniform(0, 42, len(kinds)))
    for kind, tt in zip(kinds, times):
        place(birds, bird(rng, kind), tt, rng.uniform(-0.85, 0.85), rng.uniform(0.45, 1.0) * (0.6 if kind == "koel" else 1.0))
    birds = dsp.filt(birds, dsp.r_lp(7500, 2), circular=True)
    cic = cicada(n, rng, 1.0)
    cic = np.stack([cic, np.roll(cic, n_of(0.37))], axis=1)
    mix = 0.7 * wind + 0.35 * rustle + 0.45 * water + 0.6 * bub + 2.0 * birds + 0.07 * cic
    return _finish(mix, rng, rt60=1.1, wet=0.2)


def amb_isl03(seed: int) -> np.ndarray:
    """Đảo 3 (mũi đá): sóng biển vỗ, gió hú qua đá, hải âu xa."""
    rng = dsp.rng_for(seed)
    L = 44.0
    n = n_of(L)
    sea = bed(n, rng, dsp.r_band(60, 1500, 1.5), 0.15, 0.4)
    waves = np.zeros((n, 2))
    k = 6
    for i in range(k):
        tt = i * L / k + rng.uniform(-0.6, 0.6)
        w = wave_event(rng, rng.uniform(5.5, 7.0))
        pan = rng.uniform(-0.4, 0.4)
        wl = w * np.array([math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4)])[None, :] * math.sqrt(2)
        dsp.add_at(waves, wl * rng.uniform(0.7, 1.0), n_of(tt), circular=True)
    g = gusts(n, rng, 0.06, 0.3)
    wn = rng.standard_normal(n)

    def howl(tc, f):
        tm = np.mod(tc[:, 0], L)
        c1 = 560 + 180 * np.sin(TAU * (3 / L) * tm)
        c2 = 1350 + 250 * np.sin(TAU * (2 / L) * tm + 1.0)
        ff = np.maximum(f, 1.0)
        r1 = 1.0 / np.sqrt(1 + 36 * (ff / c1[:, None] - c1[:, None] / ff) ** 2)
        r2 = 0.5 / np.sqrt(1 + 64 * (ff / c2[:, None] - c2[:, None] / ff) ** 2)
        return r1 + r2 + 0.05

    hw = dsp.tv_filter(wn, howl, nfft=2048, hop=512, circular=True)
    hw /= np.std(hw) + 1e-9
    hw2 = np.roll(hw, n_of(0.8))
    wind = np.stack([hw, hw2], axis=1) * g[:, None]
    broad = bed(n, rng, dsp.r_band(100, 1200, 2), 0.1, 0.0) * g[:, None]
    gulls = np.zeros((n, 2))
    for tt in (7.0, 23.5, 36.0):
        place(gulls, gull(rng), tt + rng.uniform(-1, 1), rng.uniform(-0.7, 0.7), rng.uniform(0.6, 1.0))
    gulls = dsp.filt(gulls, dsp.r_lp(5000, 2), circular=True)
    mix = 0.5 * sea + 0.9 * waves / (np.std(waves) + 1e-9) + 0.35 * wind + 0.3 * broad + 1.4 * gulls
    return _finish(mix, rng, rt60=1.4, wet=0.18)


AMBIENCES = {
    "amb_river_day_loop": (amb_river, "Đảo 1 sông: nước róc rách + bọt nhỏ, gió nhẹ, 9 tiếng chim, dế xa, ghe máy xa (14–30 s); 40 s"),
    "amb_isl02_day_loop": (amb_isl02, "Đảo 2 rừng dừa: gió lá xào xạc theo cơn, lạch nước nhẹ, 10 tiếng chim nhiệt đới, ve; 42 s"),
    "amb_isl03_day_loop": (amb_isl03, "Đảo 3 mũi đá: 6 con sóng vỗ + rút, gió hú qua đá theo cơn, hải âu xa; 44 s"),
}
