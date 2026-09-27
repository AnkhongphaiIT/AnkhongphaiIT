"""Công thức SFX nguyên bản (numpy). Mỗi hàm trả tín hiệu mono float.

Đăng ký trong RECIPES: asset_id -> Recipe(fn, peak_db, loop, notes).
fn(rng, variant_index) -> np.ndarray. variant_index = 0 nếu không có biến thể.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Callable

import numpy as np

from . import dsp, voice
from .dsp import SR, n_of, tvec, midi_hz


# ================================================================ khối dựng
def burst(dur: float, rng, lo: float, hi: float, attack: float = 0.001, tau: float = 0.02,
          order: float = 2, hold: float = 0.0) -> np.ndarray:
    n = n_of(dur)
    w = dsp.band(rng.standard_normal(n), lo, hi, order)
    w /= np.std(w) + 1e-9
    return w * dsp.env_perc(n, attack, tau, hold=hold)


def lp_burst(dur, rng, fc, attack=0.002, tau=0.03, order=2):
    n = n_of(dur)
    w = dsp.lowpass(rng.standard_normal(n), fc, order)
    w /= np.std(w) + 1e-9
    return w * dsp.env_perc(n, attack, tau)


def glide(dur: float, f0: float, f1: float, tau: float, attack: float = 0.002, curve: str = "exp",
          harm: tuple = (1.0,), glide_time: float | None = None) -> np.ndarray:
    """Sine (hoặc vài hài) trượt cao độ f0->f1, biên độ tắt dần mũ."""
    n = n_of(dur)
    t = tvec(n)
    gt = glide_time or dur
    x = np.clip(t / gt, 0, 1)
    if curve == "exp":
        f = f0 * (f1 / f0) ** x
    else:
        f = f0 + (f1 - f0) * x
    ph = dsp.phase_of(f)
    y = sum(a * np.sin((k + 1) * ph) for k, a in enumerate(harm))
    return y * dsp.env_perc(n, attack, tau)


def bubble(f0: float, dur: float = 0.08, rise: float = 2.2, tau: float = 0.03, attack: float = 0.0015) -> np.ndarray:
    """Bọt nước: sine tăng cao độ nhanh + tắt dần ('plop')."""
    return glide(dur, f0, f0 * rise, tau, attack, glide_time=dur * 0.6)


def sweep_noise(dur: float, rng, pts_f: list, pts_a: list, q: float = 1.5, nfft: int = 512,
                hop: int = 128) -> np.ndarray:
    """Nhiễu qua bandpass có tâm trượt (vút/whoosh). pts_f/pts_a: [(t, value)]."""
    n = n_of(dur)
    w = rng.standard_normal(n)
    tf = np.array([p[0] for p in pts_f])
    vf = np.log(np.array([p[1] for p in pts_f]))

    def g(tc, f):
        fc = np.exp(np.interp(tc[:, 0], tf, vf))[:, None]
        ff = np.maximum(f, 1.0)
        return 1.0 / np.sqrt(1.0 + q * q * (ff / fc - fc / ff) ** 2)

    y = dsp.tv_filter(w, g, nfft=nfft, hop=hop)
    y /= np.std(y) + 1e-9
    return y * dsp.env_points(pts_a, n)


def knock(f0: float, dur: float, rng, ratios=(1.0, 2.57, 4.1, 6.3), taus=(0.05, 0.025, 0.012, 0.007),
          amps=(1.0, 0.6, 0.4, 0.2), click: float = 0.3, click_hi: float = 6000.0) -> np.ndarray:
    n = n_of(dur)
    y = dsp.modal(n, [f0 * r for r in ratios], taus, amps, rng=rng)
    if click > 0:
        c = burst(min(dur, 0.01), rng, 800.0, click_hi, 0.0003, 0.0015)
        y[:c.shape[0]] += click * c
    return y


def place(dst: np.ndarray, src: np.ndarray, t: float, gain: float = 1.0) -> None:
    dsp.add_at(dst, src * gain, n_of(t))


def canvas(dur: float) -> np.ndarray:
    return np.zeros(n_of(dur))


def stick_slip(dur: float, rng, rate_pts: list, amp_pts: list, res_freqs, res_taus, res_amps,
               jitter: float = 0.2) -> np.ndarray:
    """Tiếng kẽo kẹt: chuỗi xung ma sát (stick-slip) kích các cộng hưởng (tre/gỗ)."""
    n = n_of(dur)
    imp = np.zeros(n)
    t = 0.0
    tr = np.array([p[0] for p in rate_pts])
    vr = np.array([p[1] for p in rate_pts])
    ta = np.array([p[0] for p in amp_pts])
    va = np.array([p[1] for p in amp_pts])
    while t < dur:
        rate = float(np.interp(t, tr, vr))
        a = float(np.interp(t, ta, va))
        i = n_of(t)
        if i < n and a > 0:
            imp[i] += a * rng.uniform(0.6, 1.0) * (1 if rng.random() > 0.15 else -1)
        t += (1.0 / max(rate, 1.0)) * (1.0 + jitter * rng.uniform(-1, 1))
    m = n_of(0.08)
    ir = dsp.modal(m, res_freqs, res_taus, res_amps, rng=rng, attack=0.0)
    return dsp.convolve(imp, ir)[:n]


def bells_seq(canvas_arr, rng, notes: list, decay=0.35, bright=0.8, gain=1.0,
              ratios=(1.0, 2.0, 2.76, 4.07, 5.4), rel=(1.0, 0.3, 0.4, 0.15, 0.12)):
    """notes: [(t, midi_or_hz, amp)] thêm chuông vào canvas."""
    for t, m, a in notes:
        f = midi_hz(m) if m < 200 else m
        d = min(decay * 4, canvas_arr.shape[0] / SR - t)
        if d <= 0:
            continue
        b = dsp.bell(n_of(d), f, decay=decay, bright=bright, ratios=ratios, rel_amps=rel, rng=rng)
        place(canvas_arr, b, t, gain * a)


def mallet(freq: float, dur: float, rng, decay: float = 0.5, bright: float = 0.6) -> np.ndarray:
    n = n_of(dur)
    y = dsp.modal(n, [freq, freq * 3.93, freq * 9.2], [decay, decay * 0.18, decay * 0.06],
                  [1.0, 0.35 * bright, 0.12 * bright], rng=rng, attack=0.001)
    c = burst(min(dur, 0.01), rng, 1000.0, 5000.0, 0.0003, 0.002)
    y[:c.shape[0]] += 0.08 * c
    return y


def brass(freq: float, dur: float, rng, bright: float = 1.0, attack: float = 0.025,
          release: float = 0.12, vib: float = 0.004) -> np.ndarray:
    """Kèn tổng hợp: saw giới hạn băng, độ sáng mở ra khi bật hơi (bwah)."""
    n = n_of(dur + release)
    t = tvec(n)
    f = freq * (1.0 + vib * np.sin(dsp.TAU * 5.5 * t) * np.clip((t - 0.12) / 0.2, 0, 1))
    f = f * (1.0 - 0.02 * np.exp(-t / 0.03))
    ph = dsp.phase_of(f)
    tilt = 2.6 - (2.6 - 1.15 / bright) * (1 - np.exp(-t / 0.035))
    tilt = np.where(t > dur, tilt + (t - dur) * 6.0, tilt)
    y = np.zeros(n)
    K = int(12000 / freq)
    for k in range(1, K + 1):
        y += np.power(float(k), -tilt) * np.sin(k * ph)
    env = dsp.env_adsr(n, attack, 0.15, 0.75, release * 0.5, dur)
    return y * env * 0.5


def pad_tone(freq: float, dur: float, rng, attack: float = 0.3, release: float = 0.5,
             tilt: float = 1.7, max_freq: float = 5000.0) -> np.ndarray:
    n = n_of(dur + release)
    y = np.zeros(n)
    for cents in (-7.0, 0.0, 7.0):
        f = freq * 2 ** (cents / 1200.0)
        y += dsp.osc_harmonics(f, lambda k: k ** -tilt, n, max_freq=max_freq,
                               phase0=float(rng.uniform(0, dsp.TAU)))
    return y * dsp.env_adsr(n, attack, 0.3, 0.85, release * 0.5, dur) / 3.0


# ================================================================ công thức
def cast_charge(rng, v):
    """Cần tre uốn khi nạp lực: kẽo kẹt dồn dập, cao dần (1.2 s)."""
    dur = 1.25
    y = canvas(dur)
    starts = [0.0, 0.27, 0.49, 0.67, 0.82, 0.95, 1.06]
    for i, s in enumerate(starts):
        p = i / (len(starts) - 1)
        gl = 0.14 - 0.05 * p
        r0 = 85 + 160 * p
        cr = stick_slip(gl, rng, [(0, r0), (gl, r0 * 1.6)], [(0, 0.0), (0.015, 1.0), (gl * 0.7, 0.8), (gl, 0.0)],
                        [480 + 60 * p, 1150 + 120 * p, 2100, 3300], [0.012, 0.008, 0.005, 0.003],
                        [1.0, 0.7, 0.45, 0.2])
        place(y, cr, s, 0.5 + 0.5 * p)
    n = y.shape[0]
    t = tvec(n)
    hum = np.sin(dsp.phase_of(170 * (2.4 ** (t / dur)))) * 0.06 * np.clip(t / dur, 0, 1) ** 1.5
    fr = dsp.band(rng.standard_normal(n), 1200, 4200, 2)
    fr = fr / (np.std(fr) + 1e-9) * 0.025 * (0.3 + t / dur)
    return y / (dsp.peak(y) + 1e-9) + hum + fr


def cast_whoosh(rng, v):
    """Vung cần: 'vút' 0,35 s + tiếng dây nhả rít nhẹ."""
    dur = 0.42
    y = sweep_noise(dur, rng, [(0, 450), (0.12, 2800), (0.3, 1300), (dur, 900)],
                    [(0, 0), (0.1, 1.0), (0.16, 0.8), (0.34, 0.1), (dur, 0)], q=2.0)
    n = y.shape[0]
    t = tvec(n)
    f = np.interp(t, [0, 0.12, 0.3, dur], [700, 1650, 1000, 850])
    tone = np.sin(dsp.phase_of(f)) * dsp.env_points([(0, 0), (0.1, 0.12), (0.2, 0.06), (0.32, 0)], n)
    zip_ = dsp.band(rng.standard_normal(n), 4500, 9000, 2)
    zip_ = zip_ / (np.std(zip_) + 1e-9) * (0.5 + 0.5 * np.sin(dsp.TAU * 95 * t)) * \
        dsp.env_points([(0, 0), (0.1, 0), (0.14, 0.12), (0.4, 0)], n)
    return y + tone + zip_


def lure_splash(rng, v):
    """Phao chạm nước: 'tõm' tròn nhỏ."""
    y = canvas(0.55)
    place(y, bubble(270, 0.16, 2.6, 0.055), 0.004, 1.0)
    place(y, burst(0.12, rng, 1500, 7000, 0.0008, 0.028), 0.0, 0.32)
    place(y, glide(0.08, 130, 95, 0.025), 0.0, 0.3)
    for i in range(4):
        place(y, bubble(rng.uniform(900, 1900), 0.06, rng.uniform(1.6, 2.2), rng.uniform(0.012, 0.02)),
              0.06 + i * rng.uniform(0.04, 0.07), rng.uniform(0.1, 0.22))
    return y


def lure_ground(rng, v):
    """Phao rơi đất: 'cộc'."""
    y = canvas(0.3)
    place(y, knock(310, 0.25, rng, (1.0, 2.3, 3.9, 5.6), (0.045, 0.022, 0.011, 0.007)), 0.0, 1.0)
    place(y, lp_burst(0.12, rng, 600, 0.001, 0.02), 0.0, 0.6)
    for i in range(5):
        place(y, burst(0.01, rng, 2000, 6000, 0.0003, 0.0015), 0.02 + rng.uniform(0, 0.08), rng.uniform(0.05, 0.12))
    return y


def nibble(rng, v):
    """Cá rỉa: 'plip' nhẹ."""
    y = canvas(0.2)
    place(y, bubble(950, 0.07, 2.0, 0.02), 0.002, 1.0)
    place(y, burst(0.006, rng, 3000, 9000, 0.0002, 0.0012), 0.0, 0.25)
    place(y, bubble(1250, 0.06, 1.8, 0.015), 0.05, 0.45)
    return y


def bite_alert(rng, v):
    """Cá cắn: 'bụp' nước + 2 nốt chuông 'tink-tink' rõ (0,4 s)."""
    y = canvas(0.62)
    place(y, bubble(210, 0.14, 2.4, 0.045), 0.0, 0.55)
    place(y, burst(0.08, rng, 900, 5000, 0.0008, 0.022), 0.0, 0.2)
    glass = (1.0, 2.0, 2.76, 5.4)
    rel = (1.0, 0.18, 0.35, 0.12)
    bells_seq(y, rng, [(0.015, 91, 1.0), (0.145, 96, 1.1)], decay=0.2, bright=0.9, ratios=glass, rel=rel)
    for st in (0.015, 0.145):
        place(y, burst(0.006, rng, 5000, 12000, 0.0002, 0.0012), st, 0.35)
    return y


def perfect_yank(rng, v):
    """Giật chuẩn: 'ping' sáng + lấp lánh 0,3 s."""
    y = canvas(0.6)
    bells_seq(y, rng, [(0.0, 100, 1.0), (0.0, 88, 0.35)], decay=0.3, bright=0.8,
              ratios=(1.0, 2.0, 3.0, 4.2), rel=(1.0, 0.2, 0.08, 0.12))
    pent = [100, 102, 105, 107, 109, 112]
    for i in range(6):
        bells_seq(y, rng, [(0.03 + 0.028 * i, pent[int(rng.integers(0, len(pent)))], 0.3)], decay=0.06, bright=0.6)
    place(y, sweep_noise(0.14, rng, [(0, 3000), (0.1, 8500)], [(0, 0), (0.03, 1), (0.14, 0)], q=2.5), 0.0, 0.18)
    return y


def reel_loop(rng, v):
    """Guồng quay: lạch cạch đều, lặp liền (1,0 s = 14 nhịp)."""
    n = SR  # 1.0 s
    y = np.zeros(n)
    clicks = 14
    for i in range(clicks):
        f = 1.0 + (0.04 if i % 2 else -0.03)
        c = dsp.modal(n_of(0.03), [2400 * f, 3900 * f, 5600 * f, 7300 * f, 620], [0.004, 0.003, 0.002, 0.0015, 0.006],
                      [1.0, 0.7, 0.4, 0.2, 0.35], rng=rng, attack=0.0002)
        c[:n_of(0.004)] += 0.3 * burst(0.004, rng, 3000, 9000, 0.0002, 0.001)
        pos = int((i + 0.5) * n / clicks) + int(rng.integers(-40, 40))
        dsp.add_at(y, c * rng.uniform(0.8, 1.0), pos, circular=True)
    t = tvec(n)
    whir = dsp.band(rng.standard_normal(n), 700, 3200, 2, circular=True)
    whir = whir / (np.std(whir) + 1e-9) * (0.35 + 0.65 * np.sin(math.pi * clicks * t) ** 2) * 0.05
    hum = np.sin(dsp.TAU * 14 * 9 * t) * 0.012  # 126 Hz, số chu kỳ nguyên trong 1 s
    return y + whir + hum


def line_strain(rng, v):
    """Dây căng khi cá vùng vẫy: kẽo kẹt + ù dây, lặp liền 2 s (code tăng pitch/âm lượng theo lực)."""
    dur = 2.0
    n = n_of(dur)
    t = tvec(n)
    wob = dsp.random_walk(n, rng, 3.0, circular=True)
    f0 = 205.0 * (1.0 + 0.025 * wob)
    # ép tổng số chu kỳ trong vòng lặp thành số nguyên để pha nối liền
    cycles = float(np.sum(f0)) / SR
    f0 = f0 * (round(cycles) / cycles)
    ph = dsp.phase_of(f0)
    hum = sum((k ** -1.3) * np.sin(k * ph) for k in range(1, 20))
    hum = dsp.filt(hum, dsp.r_mul(dsp.r_band(300, 2500, 1), dsp.r_peak(1100, 600, 5)), circular=True)
    hum = hum / (np.std(hum) + 1e-9) * 0.12 * (0.8 + 0.2 * dsp.random_walk(n, rng, 1.5, circular=True))
    y = np.zeros(n)
    for s, a in ((0.1, 1.0), (0.62, 0.7), (1.05, 0.9), (1.55, 0.75)):
        gl = rng.uniform(0.12, 0.2)
        r0 = rng.uniform(140, 200)
        cr = stick_slip(gl, rng, [(0, r0), (gl, r0 * 1.5)], [(0, 0), (0.02, 1), (gl * 0.7, 0.7), (gl, 0)],
                        [520, 1250, 2300, 3500], [0.011, 0.007, 0.004, 0.003], [1.0, 0.8, 0.4, 0.2])
        dsp.add_at(y, cr / (dsp.peak(cr) + 1e-9) * a * 0.45, n_of(s), circular=True)
    fib = dsp.band(rng.standard_normal(n), 2500, 7000, 2, circular=True)
    fib = fib / (np.std(fib) + 1e-9) * 0.02 * (0.6 + 0.4 * dsp.random_walk(n, rng, 4.0, circular=True))
    return hum + y + fib


def escape_bloop(rng, v):
    """Cá sổng: 'bloop' hài đi xuống."""
    y = canvas(0.62)
    n = n_of(0.3)
    t = tvec(n)
    f = 880 * (0.28 ** np.clip(t / 0.2, 0, 1)) * (1 + 0.04 * np.sin(dsp.TAU * 22 * t))
    blo = np.sin(dsp.phase_of(f)) * dsp.env_points([(0, 0), (0.01, 1), (0.16, 0.8), (0.3, 0)], n)
    place(y, blo, 0.0, 1.0)
    place(y, bubble(300, 0.12, 2.2, 0.04), 0.23, 0.8)
    place(y, lp_burst(0.1, rng, 1200, 0.002, 0.025), 0.0, 0.25)
    return y


def launch_pop(rng, v):
    """Cá bị giật khỏi nước: 'BỤP' nước."""
    y = canvas(0.7)
    place(y, glide(0.3, 130, 55, 0.08, 0.001, glide_time=0.08), 0.0, 1.0)
    place(y, burst(0.35, rng, 400, 6500, 0.0015, 0.06), 0.0, 0.75)
    place(y, burst(0.25, rng, 700, 5000, 0.002, 0.05), 0.04, 0.4)
    place(y, bubble(300, 0.12, 3.0, 0.05), 0.01, 0.5)
    for i in range(10):
        tt = 0.08 + i * rng.uniform(0.03, 0.05)
        place(y, bubble(rng.uniform(1000, 2800), 0.05, rng.uniform(1.4, 2.0), 0.012), tt,
              0.25 * (1 - i / 11) + 0.03)
    return y


def air_whistle(rng, v):
    """Sinh vật bay: huýt gió ngắn (doppler lên rồi xuống)."""
    dur = 0.7
    n = n_of(dur)
    t = tvec(n)
    f = np.interp(t, [0, 0.25, dur], [1350, 2250, 1450])
    ph = dsp.phase_of(f)
    tone = np.sin(ph) + 0.12 * np.sin(2 * ph)
    env = dsp.env_points([(0, 0), (0.12, 0.8), (0.25, 1.0), (0.55, 0.5), (dur, 0)], n)
    w = rng.standard_normal(n)

    def g(tc, fr):
        fc = np.interp(tc[:, 0], t, f)[:, None]
        return 1.0 / np.sqrt(1.0 + 64 * (np.maximum(fr, 1) / fc - fc / np.maximum(fr, 1)) ** 2)

    br = dsp.tv_filter(w, g, nfft=512, hop=128)
    br /= np.std(br) + 1e-9
    wh = sweep_noise(dur, rng, [(0, 800), (0.25, 2000), (dur, 900)], [(0, 0), (0.25, 1), (dur, 0)], q=1.0)
    return (0.6 * tone + 0.25 * br) * env + 0.12 * wh


def flop(rng, v):
    """Cá quẫy trên cạn: lạch bạch ướt, 3 biến thể."""
    counts = (3, 2, 4)[v % 3]
    y = canvas(0.8)
    t = 0.0
    for i in range(counts):
        a = 1.0 - 0.18 * i + rng.uniform(-0.08, 0.08)
        base = rng.uniform(150, 210)
        s = burst(0.08, rng, 700, 5000, 0.0006, 0.016)
        s += 0.5 * glide(0.08, base, base * 0.8, 0.025)
        sq = dsp.bandpass(rng.standard_normal(n_of(0.08)), rng.uniform(900, 1400), 4.0)
        sq = sq / (np.std(sq) + 1e-9) * dsp.env_perc(sq.shape[0], 0.002, 0.03) * 0.35
        s[:sq.shape[0]] += sq
        place(y, s, t, a)
        for _ in range(int(rng.integers(1, 3))):
            place(y, bubble(rng.uniform(1500, 3000), 0.04, 1.6, 0.01), t + rng.uniform(0.02, 0.07), 0.12)
        t += rng.uniform(0.1, 0.17)
    return y


def hit_slap(rng, v):
    """Tay trúng: 'Bốp'."""
    y = canvas(0.35)
    place(y, burst(0.08, rng, 1000, 8000, 0.0004, 0.011), 0.0, 1.0)
    place(y, glide(0.2, 205, 140, 0.04), 0.0, 0.7)
    bp = dsp.bandpass(rng.standard_normal(n_of(0.1)), 900, 3.0)
    place(y, bp / (np.std(bp) + 1e-9) * dsp.env_perc(bp.shape[0], 0.001, 0.028), 0.0, 0.45)
    return dsp.add_reverb(y, rng, wet=0.08, rt60=0.35)[:y.shape[0]]


def hit_bonk(rng, v):
    """Chổi trúng: 'boing' gỗ."""
    y = canvas(0.65)
    place(y, knock(420, 0.4, rng, (1.0, 2.7, 4.6, 6.9), (0.09, 0.04, 0.02, 0.01), (1.0, 0.6, 0.4, 0.2)), 0.0, 1.0)
    n = n_of(0.6)
    t = tvec(n)
    f = 255 * (1 + 0.32 * np.exp(-t / 0.16) * np.sin(dsp.TAU * 16 * t)) * (1 - 0.1 * t)
    ph = dsp.phase_of(f)
    boing = (np.sin(ph) + 0.25 * np.sin(2 * ph)) * dsp.env_perc(n, 0.004, 0.2)
    place(y, boing, 0.005, 0.55)
    return y


def slipper_throw(rng, v):
    """Ném dép: vút + xoay vụt vụt."""
    dur = 0.62
    n = n_of(dur)
    t = tvec(n)
    y = sweep_noise(dur, rng, [(0, 1300), (0.2, 2300), (dur, 1000)],
                    [(0, 0), (0.12, 1), (0.35, 0.8), (dur, 0)], q=1.6)
    am = 0.3 + 0.7 * np.abs(np.sin(math.pi * 13.0 * t)) ** 1.6
    return y * am


def slipper_hit(rng, v):
    """Dép trúng: 'CHÁT!' giòn + dép bật nhẹ."""
    y = canvas(0.42)
    place(y, burst(0.05, rng, 1500, 9500, 0.0003, 0.008), 0.0, 1.0)
    sm = dsp.bandpass(rng.standard_normal(n_of(0.1)), 2500, 2.0)
    place(y, sm / (np.std(sm) + 1e-9) * dsp.env_perc(sm.shape[0], 0.0005, 0.022), 0.0, 0.55)
    place(y, glide(0.15, 270, 180, 0.035), 0.0, 0.45)
    place(y, burst(0.04, rng, 1200, 7000, 0.0005, 0.006), 0.075, 0.18)
    return dsp.add_reverb(y, rng, wet=0.12, rt60=0.3)[:y.shape[0]]


def _stars(rng, dur, start, amp=1.0, count=13):
    y = canvas(dur)
    pent = [91, 93, 96, 98, 100, 103]
    order = [0, 2, 4, 5, 3, 1]
    for i in range(count):
        tt = start + i * 0.085
        if tt > dur - 0.2:
            break
        m = pent[order[i % len(order)]]
        trem = 0.55 + 0.45 * math.sin(dsp.TAU * 2.6 * (tt - start))
        bells_seq(y, rng, [(tt, m, amp * trem * (1 - 0.35 * i / count))], decay=0.13, bright=0.8)
    n = y.shape[0]
    t = tvec(n)
    f = 1250 + 180 * np.sin(dsp.TAU * 3.0 * t)
    sw = np.sin(dsp.phase_of(f)) * dsp.env_points([(0, 0), (start + 0.1, 0.08 * amp), (dur - 0.3, 0.05 * amp), (dur, 0)], n)
    return y + sw


def ko_stars(rng, v):
    """KO: chuông sao quay leng keng."""
    return _stars(rng, 1.5, 0.0, 1.0, 14)


def trick_ding(rng, v):
    """Mỗi trick: 'ting' 1 nốt thủy tinh (code tăng cao độ)."""
    y = canvas(0.6)
    bells_seq(y, rng, [(0.0, 88, 1.0)], decay=0.32, bright=1.0, ratios=(1.0, 2.0, 3.0, 4.2),
              rel=(1.0, 0.25, 0.08, 0.12))
    return y


def coin_gain(rng, v):
    """Nhận tiền: leng keng hai đồng xu."""
    y = canvas(0.7)
    coin = (1.0, 2.32, 3.87, 5.4)
    rel = (1.0, 0.55, 0.35, 0.2)
    bells_seq(y, rng, [(0.0, 95, 0.7), (0.075, 100, 1.0)], decay=0.22, bright=0.9, ratios=coin, rel=rel)
    place(y, burst(0.01, rng, 4000, 10000, 0.0002, 0.0015), 0.0, 0.25)
    return y


def sell_basket(rng, v):
    """Vật rơi vào thúng: 'phịch' + tre lạo xạo."""
    y = canvas(0.6)
    place(y, lp_burst(0.25, rng, 700, 0.002, 0.045), 0.0, 1.0)
    place(y, glide(0.2, 95, 60, 0.06), 0.0, 0.8)
    for i in range(7):
        f = rng.uniform(1200, 2600)
        place(y, dsp.modal(n_of(0.05), [f, f * 2.3], [rng.uniform(0.008, 0.015), 0.006], [1.0, 0.4], rng=rng),
              0.005 + rng.uniform(0, 0.14), 0.35 * (1 - i / 9))
    cr = stick_slip(0.07, rng, [(0, 120), (0.07, 160)], [(0, 0), (0.01, 1), (0.07, 0)],
                    [900, 2100, 3200], [0.01, 0.006, 0.004], [1.0, 0.6, 0.3])
    place(y, cr / (dsp.peak(cr) + 1e-9), 0.04, 0.25)
    return y


def buy(rng, v):
    """Mua thành công: chuông quầy 'ding' + xu nhỏ."""
    y = canvas(1.0)
    place(y, burst(0.008, rng, 2000, 9000, 0.0002, 0.001), 0.0, 0.3)
    bells_seq(y, rng, [(0.0, 93, 1.0)], decay=0.55, bright=0.85, ratios=(1.0, 2.46, 4.1, 5.8),
              rel=(1.0, 0.5, 0.25, 0.12))
    bells_seq(y, rng, [(0.2, 98, 0.22), (0.26, 101, 0.18)], decay=0.12, bright=0.9,
              ratios=(1.0, 2.32, 3.87, 5.4), rel=(1.0, 0.5, 0.3, 0.2))
    return y


def error_nope(rng, v):
    """Không được: 'nè-nè' mũi hài, nhẹ."""
    y = canvas(0.46)
    for i, (f0, st) in enumerate(((330.0, 0.0), (262.0, 0.2))):
        d = 0.16
        s = voice.vocal([(0, f0 * 1.04), (d, f0 * 0.93)], [(0, voice.NASAL_N), (0.04, "e"), (d, "e")], d, rng,
                        fscale=1.12, amp_pts=[(0, 0), (0.01, 0.6), (0.04, 1), (0.12, 0.8), (d, 0)],
                        tilt=0.9, jitter=0.003)
        place(y, s, st, 1.0)
    return y


def pickup(rng, v):
    """Nhặt: 'bloop' đi lên ngắn + lấp lánh."""
    y = canvas(0.26)
    place(y, glide(0.12, 420, 1150, 0.05, glide_time=0.07, harm=(1.0, 0.15)), 0.0, 1.0)
    place(y, burst(0.005, rng, 2000, 8000, 0.0002, 0.001), 0.0, 0.2)
    bells_seq(y, rng, [(0.045, 100, 0.2)], decay=0.07)
    return y


def drop_thud(rng, v):
    """Thả/rơi: 'phịch'."""
    y = canvas(0.36)
    place(y, lp_burst(0.25, rng, 500, 0.002, 0.045), 0.0, 1.0)
    place(y, glide(0.25, 110, 55, 0.07), 0.0, 0.8)
    for i in range(2):
        place(y, knock(rng.uniform(800, 1200), 0.05, rng, (1.0, 2.4), (0.01, 0.005), (1, 0.4), click=0.1),
              0.03 + 0.03 * i, 0.12)
    return y


def player_hurt(rng, v):
    """Người chơi bị đánh: 'úi' (không lời)."""
    y = canvas(0.42)
    s = voice.vocal([(0, 300), (0.06, 395), (0.2, 330), (0.33, 255)], [(0, "u"), (0.07, "u"), (0.15, "i"), (0.33, "i")],
                    0.35, rng, fscale=1.1, amp_pts=[(0, 0), (0.015, 1), (0.22, 0.85), (0.34, 0)], breath=0.3)
    place(y, s, 0.0, 1.0)
    place(y, glide(0.1, 160, 120, 0.035), 0.0, 0.35)
    return y


def player_ko(rng, v):
    """Người chơi xỉu: 'oái' + sao."""
    y = canvas(1.55)
    s = voice.vocal([(0, 360), (0.1, 430), (0.35, 300), (0.62, 185)], [(0, "o"), (0.12, "a"), (0.4, "a"), (0.62, "i")],
                    0.64, rng, fscale=1.1, amp_pts=[(0, 0), (0.02, 1), (0.45, 0.8), (0.64, 0)], vibrato=0.05,
                    vib_rate=8.0, breath=0.25)
    place(y, s, 0.0, 1.0)
    st = _stars(rng, 1.0, 0.0, 0.55, 10)
    place(y, st, 0.55, 1.0)
    return y


def footstep_wood(rng, v):
    """Bước trên bến gỗ: gót + mũi chân, 3 biến thể."""
    y = canvas(0.26)
    f0 = (165.0, 182.0, 150.0)[v % 3] * rng.uniform(0.97, 1.03)
    place(y, knock(f0, 0.2, rng, (1.0, 2.1, 3.5, 5.2), (0.06, 0.03, 0.02, 0.01), (1, 0.5, 0.35, 0.2), click=0.25), 0, 1.0)
    place(y, glide(0.12, 95, 90, 0.045), 0.0, 0.3)
    place(y, burst(0.05, rng, 1000, 5000, 0.002, 0.018), 0.008, 0.18)
    place(y, knock(f0 * 1.35, 0.1, rng, (1.0, 2.2, 3.6), (0.03, 0.015, 0.008), (1, 0.4, 0.2), click=0.15),
          rng.uniform(0.03, 0.05), 0.33)
    return y


def footstep_sand(rng, v):
    """Bước trên cát/bùn: lạo xạo hạt, 3 biến thể."""
    y = canvas(0.3)
    count = int(rng.integers(45, 70))
    peak_t = (0.025, 0.035, 0.03)[v % 3]
    for _ in range(count):
        tt = abs(rng.normal(peak_t, 0.035))
        if tt > 0.16:
            continue
        g = burst(0.004, rng, 1500, 7500, 0.0002, rng.uniform(0.0005, 0.0015))
        place(y, g, tt, rng.uniform(0.2, 1.0) * math.exp(-tt / 0.08))
    place(y, lp_burst(0.12, rng, 300, 0.004, 0.03), 0.0, 0.8)
    place(y, burst(0.14, rng, 2000, 6000, 0.005, 0.04), 0.0, 0.18)
    return y


def jump(rng, v):
    """Nhảy: vút vải ngắn + nảy nhẹ."""
    y = canvas(0.3)
    place(y, sweep_noise(0.22, rng, [(0, 600), (0.18, 2600)], [(0, 0), (0.06, 1), (0.22, 0)], q=1.3), 0.0, 1.0)
    place(y, glide(0.12, 300, 620, 0.05, glide_time=0.1), 0.0, 0.2)
    return y


def land(rng, v):
    """Tiếp đất: thịch + sột soạt."""
    y = canvas(0.32)
    place(y, lp_burst(0.2, rng, 420, 0.002, 0.04), 0.0, 1.0)
    place(y, glide(0.2, 90, 50, 0.05), 0.0, 0.8)
    place(y, burst(0.1, rng, 1000, 4000, 0.002, 0.03), 0.0, 0.3)
    place(y, burst(0.2, rng, 2000, 6000, 0.01, 0.06), 0.01, 0.1)
    return y


def _splash_big(rng, dur=0.9, amp=1.0):
    y = canvas(dur)
    place(y, glide(0.5, 100, 42, 0.15, 0.002, glide_time=0.12), 0.0, 1.0 * amp)
    place(y, burst(0.7, rng, 250, 7000, 0.003, 0.12), 0.0, 0.9 * amp)
    place(y, burst(0.5, rng, 600, 5000, 0.004, 0.08), 0.05, 0.45 * amp)
    place(y, bubble(250, 0.15, 2.8, 0.06), 0.01, 0.5 * amp)
    for i in range(10):
        place(y, bubble(rng.uniform(600, 2200), 0.06, rng.uniform(1.4, 2.2), 0.015), 0.1 + i * rng.uniform(0.03, 0.06),
              0.22 * amp * (1 - i / 12))
    return y


def boss_roar(rng, v):
    """Boss xuất hiện: nước quẫy mạnh + gầm cách điệu ngắn (không kinh dị)."""
    y = canvas(1.9)
    for st, a in ((0.0, 1.0), (0.26, 0.6), (0.52, 0.45)):
        place(y, _splash_big(rng, 0.9, a), st, 0.45)
    r = voice.vocal([(0, 82), (0.3, 112), (0.9, 98), (1.3, 72)],
                    [(0, "u"), (0.25, "o"), (0.5, "a"), (1.05, "a"), (1.35, "o")], 1.4, rng,
                    fscale=0.72, amp_pts=[(0, 0), (0.12, 0.7), (0.4, 1.0), (1.0, 0.85), (1.4, 0)],
                    rough=0.5, rough_rate=31.0, subharm=0.55, jitter=0.03, breath=0.35, max_freq=6000)
    r = dsp.filt(r, dsp.r_mul(dsp.r_hp(60, 2), dsp.r_peak(250, 200, 4)))
    r = np.tanh(2.2 * r / (dsp.peak(r) + 1e-9))
    place(y, r / (dsp.peak(r) + 1e-9), 0.18, 1.0)
    return dsp.add_reverb(y, rng, wet=0.22, rt60=1.0)[:y.shape[0]]


def boss_telegraph(rng, v):
    """Báo trước đòn boss: còi ngắn tăng dần (cao độ + âm lượng + nhịp rung)."""
    dur = 0.85
    n = n_of(dur)
    t = tvec(n)
    f = 600 * (1300 / 600) ** (t / 0.8)
    ph = dsp.phase_of(f)
    trem_rate = 6 + 8 * t / dur
    trem = 0.75 + 0.25 * np.sin(dsp.phase_of(trem_rate))
    tone = (np.sin(ph) + 0.3 * np.sin(3 * ph) + 0.1 * np.sin(2 * ph)) * trem
    env = dsp.env_points([(0, 0), (0.03, 0.3), (0.75, 1.0), (dur, 0)], n)
    return tone * env


def boss_escape_warning(rng, v):
    """Boss sắp trốn: 'tít tít'."""
    y = canvas(0.5)
    for st in (0.0, 0.2):
        n = n_of(0.12)
        ph = dsp.phase_of(1760.0, n)
        b = (np.sin(ph) + 0.2 * np.sin(3 * ph) + 0.35 * np.sin(1.5 * ph)) * dsp.env_adsr(n, 0.003, 0.05, 0.8, 0.015, 0.1)
        place(y, b, st, 1.0)
    return y


def boss_phase(rng, v):
    """Boss đổi pha: quẫy nước mạnh + nhạc nhấn 'ta-ta-TAM' nguyên bản."""
    y = canvas(1.7)
    place(y, _splash_big(rng, 0.9, 1.0), 0.0, 0.55)
    chords = [(0.06, (60, 64, 67), 0.12), (0.22, (62, 66, 69), 0.12), (0.38, (64, 68, 71, 76), 0.95)]
    for st, notes, d in chords:
        for m in notes:
            place(y, brass(midi_hz(m), d, rng), st, 0.28)
    n = n_of(0.9)
    t = tvec(n)
    timp = dsp.fade(np.sin(dsp.phase_of(98 * (1 - 0.1 * np.exp(-t / 0.05)))) * np.exp(-t / 0.4), 0.0, 0.25)
    place(y, timp, 0.38, 0.7)
    place(y, lp_burst(0.2, rng, 1500, 0.001, 0.03), 0.38, 0.3)
    return dsp.add_reverb(y, rng, wet=0.15, rt60=0.9)[:y.shape[0]]


def boss_escape_splash(rng, v):
    """Boss lặn trốn: tiếng lặn to + ùng ục + 'bloop'."""
    y = canvas(1.6)
    place(y, _splash_big(rng, 0.9, 1.0), 0.0, 0.9)
    for i in range(12):
        tt = 0.2 + i * 0.065 + rng.uniform(-0.02, 0.02)
        f = 900 - 50 * i + rng.uniform(-60, 60)
        place(y, bubble(max(f, 220), 0.08, 1.8, 0.025), tt, 0.35 * (1 - i / 14))
    n = n_of(0.35)
    t = tvec(n)
    f = 700 * (0.3 ** np.clip(t / 0.25, 0, 1))
    blo = np.sin(dsp.phase_of(f)) * dsp.env_points([(0, 0), (0.01, 1), (0.2, 0.7), (0.35, 0)], n)
    place(y, blo, 1.05, 0.8)
    return y


def creature_warn(rng, v):
    """Sinh vật sắp tấn công: gầm gừ nhỏ hài 0,3 s."""
    y = canvas(0.4)
    s = voice.vocal([(0, 150), (0.15, 178), (0.32, 138)], [(0, "ơ"), (0.3, "ư")], 0.34, rng, fscale=1.25,
                    amp_pts=[(0, 0), (0.03, 1), (0.25, 0.8), (0.34, 0)], rough=0.65, rough_rate=26.0,
                    subharm=0.25, jitter=0.02)
    place(y, s, 0.0, 1.0)
    return y


def swing_whoosh(rng, v):
    """Vung tay/chổi: vút ngắn."""
    return sweep_noise(0.28, rng, [(0, 700), (0.1, 2400), (0.28, 1300)], [(0, 0), (0.08, 1), (0.28, 0)], q=1.4)


def boss_defeat_fanfare(rng, v):
    """Hạ boss: kèn vui ~2 s (ta-ta-ta TAAA) + trống + chuông lấp lánh."""
    y = canvas(2.0)
    seq = [(0.0, 67, 0.08), (0.11, 67, 0.08), (0.22, 67, 0.08), (0.34, 72, 0.26), (0.64, 76, 0.1), (0.77, 74, 0.1)]
    for st, m, d in seq:
        place(y, brass(midi_hz(m), d, rng), st, 0.8)
        place(y, brass(midi_hz(m - 5), d, rng, bright=0.7), st, 0.35)
    for m in (60, 64, 67, 72, 76):
        place(y, brass(midi_hz(m), 0.7, rng, vib=0.006), 0.92, 0.26)
    for st in [0.62 + 0.035 * i for i in range(9)]:
        place(y, burst(0.06, rng, 1200, 7000, 0.001, 0.02), st, 0.12 + 0.02 * ((st - 0.62) / 0.035))
    n = n_of(0.8)
    t = tvec(n)
    for st, f in ((0.34, 65.4), (0.92, 65.4)):
        timp = dsp.fade(np.sin(dsp.phase_of(f * 1.5 * (1 - 0.08 * np.exp(-t / 0.05)))) * np.exp(-t / 0.35), 0.0, 0.25)
        place(y, timp, st, 0.55)
    place(y, burst(1.0, rng, 3000, 12000, 0.002, 0.45), 0.92, 0.25)
    bells_seq(y, rng, [(1.0 + 0.06 * i, m, 0.35) for i, m in enumerate((96, 100, 103, 108))], decay=0.25)
    out = dsp.add_reverb(y, rng, wet=0.18, rt60=1.1)[:y.shape[0]]
    return out * dsp.env_points([(0, 1), (1.7, 1), (2.0, 0)], out.shape[0])


def quest_complete(rng, v):
    """Hoàn thành bước nhiệm vụ: chuông ngắn hai nốt đi lên."""
    y = canvas(0.95)
    for st, m in ((0.0, 79), (0.12, 84)):
        place(y, mallet(midi_hz(m), 0.8, rng, decay=0.45, bright=0.8), st, 0.7)
        bells_seq(y, rng, [(st, m + 12, 0.35)], decay=0.35)
    bells_seq(y, rng, [(0.2 + 0.04 * i, m, 0.12) for i, m in enumerate((103, 105, 108))], decay=0.08)
    return y


def new_species(rng, v):
    """Loài mới: hợp âm vui ~1 s (rải + nở)."""
    y = canvas(1.25)
    for i, m in enumerate((72, 76, 79, 84)):
        place(y, mallet(midi_hz(m), 1.0, rng, decay=0.55, bright=0.7), 0.07 * i, 0.55)
        place(y, dsp.ks_pluck(midi_hz(m), n_of(1.0), rng, t60=1.0, bright=0.7), 0.07 * i, 0.3)
    for m in (72, 76, 79, 86):
        place(y, pad_tone(midi_hz(m), 0.55, rng, attack=0.15, release=0.35), 0.25, 0.12)
    bells_seq(y, rng, [(0.3 + 0.05 * i, m, 0.2) for i, m in enumerate((96, 100, 103, 108, 103))], decay=0.12)
    return y


def ui_click(rng, v):
    """Bấm nút: tách gỗ rất ngắn."""
    y = canvas(0.06)
    place(y, dsp.modal(n_of(0.05), [1900, 3600, 5200], [0.006, 0.003, 0.002], [1.0, 0.5, 0.25], rng=rng, attack=0.0002),
          0.0, 1.0)
    place(y, burst(0.004, rng, 3000, 10000, 0.0001, 0.0006), 0.0, 0.3)
    return y


def ui_back(rng, v):
    """Quay lại: hai tách nhỏ đi xuống."""
    y = canvas(0.1)
    for st, f, a in ((0.0, 1300, 1.0), (0.035, 950, 0.8)):
        place(y, dsp.modal(n_of(0.05), [f, f * 1.9, f * 2.8], [0.007, 0.004, 0.002], [1.0, 0.45, 0.2], rng=rng,
                           attack=0.0002), st, a)
    return y


def tutorial_pop(rng, v):
    """Hiện gợi ý: bong bóng + chuông nhẹ."""
    y = canvas(0.4)
    place(y, bubble(450, 0.1, 2.2, 0.04), 0.0, 0.8)
    bells_seq(y, rng, [(0.025, 84, 0.45)], decay=0.2, bright=0.6)
    return y


def grill_sizzle_loop(rng, v):
    """Nướng: xèo xèo liên tục, lặp liền 3 s."""
    dur = 3.0
    n = n_of(dur)
    base = dsp.band(rng.standard_normal(n), 2500, 10000, 2, circular=True)
    base = base / (np.std(base) + 1e-9) * (0.75 + 0.25 * dsp.random_walk(n, rng, 3.0, circular=True)) * 0.18
    y = np.zeros(n)
    k = int(55 * dur)
    for _ in range(k):
        c = burst(0.006, rng, 1500, 9000, 0.0001, rng.uniform(0.0004, 0.0018))
        dsp.add_at(y, c * math.exp(rng.normal(-1.3, 0.6)), int(rng.integers(0, n)), circular=True)
    for _ in range(int(3 * dur)):
        c = burst(0.03, rng, 700, 3500, 0.0003, 0.007)
        dsp.add_at(y, c * rng.uniform(0.3, 0.6), int(rng.integers(0, n)), circular=True)
    fat = dsp.band(rng.standard_normal(n), 300, 1200, 2, circular=True)
    fat = fat / (np.std(fat) + 1e-9) * 0.04 * (0.5 + 0.5 * np.abs(dsp.random_walk(n, rng, 30.0, circular=True)))
    return base + y + fat


def cook_done(rng, v):
    """Chín: 'ting' kim loại ấm (khác trick_ding)."""
    y = canvas(0.8)
    bells_seq(y, rng, [(0.0, 93, 1.0)], decay=0.45, bright=0.9, ratios=(1.0, 2.32, 4.25, 6.8),
              rel=(1.0, 0.45, 0.25, 0.1))
    return y


def burnt(rng, v):
    """Cháy: 'xì' hơi + ho 'khụ khụ' hài."""
    y = canvas(1.2)
    place(y, burst(0.7, rng, 3000, 9000, 0.03, 0.25), 0.0, 0.5)
    for st in (0.38, 0.64):
        d = 0.16
        s = voice.vocal([(0, 260), (d, 200)], [(0, "ơ"), (d, "ư")], d, rng, fscale=1.1,
                        amp_pts=[(0, 0), (0.01, 0.35), (0.06, 0.15), (d, 0)], breath=1.0, jitter=0.03)
        hn = burst(d, rng, 400, 3000, 0.002, 0.05)
        s = s / (dsp.peak(s) + 1e-9) + 0.5 * hn
        place(y, s, st, 0.9)
    return y


def egret_call(rng, v):
    """Cò bắt đầu rình: 'quạc... quạc' khàn, nghe từ xa."""
    y = canvas(1.05)
    for st, d, f in ((0.0, 0.28, 380), (0.42, 0.2, 350)):
        s = voice.vocal([(0, f), (d * 0.3, f * 1.08), (d, f * 0.9)], [(0, "a"), (d * 0.6, "a"), (d, "o")], d, rng,
                        fscale=1.45, amp_pts=[(0, 0), (0.015, 1), (d * 0.7, 0.8), (d, 0)], rough=0.75,
                        rough_rate=48.0, subharm=0.5, jitter=0.05, breath=0.4)
        place(y, s / (dsp.peak(s) + 1e-9), st, 1.0)
    y = dsp.filt(y, dsp.r_band(300, 3000, 2))
    return dsp.add_reverb(y, rng, wet=0.35, rt60=1.3)[:y.shape[0]]


def egret_steal(rng, v):
    """Cò ngậm được đồ rồi vỗ cánh bay đi."""
    y = canvas(1.3)
    place(y, knock(2200, 0.05, rng, (1.0, 1.8), (0.005, 0.003), (1.0, 0.5), click=0.3), 0.0, 0.8)
    place(y, lp_burst(0.1, rng, 1500, 0.001, 0.02), 0.01, 0.5)
    tt = 0.15
    for i in range(6):
        fl = dsp.band(rng.standard_normal(n_of(0.14)), 250, 2500 - 250 * i, 2)
        fl = fl / (np.std(fl) + 1e-9) * dsp.env_perc(fl.shape[0], 0.025, 0.05)
        place(y, fl, tt, 0.9 * (1 - i / 7))
        tt += 0.14 + 0.01 * i
    return y


def rare_reveal(rng, v):
    """Lộ biến thể hiếm: hợp âm lấp lánh."""
    y = canvas(1.6)
    place(y, sweep_noise(0.2, rng, [(0, 2500), (0.19, 8000)], [(0, 0.45), (0.17, 1), (0.2, 0)], q=1.2), 0.0, 0.35)
    bells_seq(y, rng, [(0.17 + 0.025 * i, m, 0.5) for i, m in enumerate((84, 88, 91, 95, 98))], decay=0.7, bright=0.7)
    pent = [96, 98, 100, 103, 105, 108]
    for i in range(12):
        bells_seq(y, rng, [(0.22 + 0.06 * i, pent[int(rng.integers(0, 6))], 0.2 * (1 - i / 14))], decay=0.09)
    for m in (72, 76, 79, 83):
        place(y, pad_tone(midi_hz(m), 0.7, rng, attack=0.25, release=0.45), 0.12, 0.1)
    return y * dsp.env_points([(0, 1), (1.35, 1), (1.6, 0)], y.shape[0])


def slingshot_shot(rng, v):
    """Bắn ná: dây thun bật 'tưng' + vút."""
    y = canvas(0.5)
    place(y, burst(0.01, rng, 2000, 8000, 0.0002, 0.003), 0.0, 0.8)
    n = n_of(0.3)
    t = tvec(n)
    f = 180 * (1 + 0.08 * np.sin(dsp.TAU * 30 * t) * np.exp(-t / 0.05)) * (1 - 0.3 * t)
    ph = dsp.phase_of(f)
    tw = (np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)) * dsp.env_perc(n, 0.001, 0.08)
    place(y, tw, 0.0, 0.6)
    place(y, sweep_noise(0.32, rng, [(0, 2600), (0.3, 1400)], [(0, 0), (0.04, 1), (0.32, 0)], q=2.0), 0.04, 0.35)
    return y


def swatter_zap(rng, v):
    """Vợt điện: 'tách' + rè ngắn (vui, không đáng sợ)."""
    y = canvas(0.4)
    place(y, burst(0.02, rng, 2000, 10000, 0.0001, 0.002), 0.0, 1.0)
    n = n_of(0.22)
    buzz = dsp.osc_harmonics(110.0, lambda k: k ** -0.7, n, max_freq=6000)
    buzz = dsp.band(buzz, 300, 6000, 2)
    buzz *= (0.6 + 0.4 * dsp.random_walk(n, rng, 60.0)) * dsp.env_perc(n, 0.001, 0.06)
    place(y, buzz / (dsp.peak(buzz) + 1e-9), 0.003, 0.45)
    for _ in range(5):
        place(y, burst(0.004, rng, 3000, 10000, 0.0001, 0.0008), rng.uniform(0.01, 0.15), rng.uniform(0.2, 0.5))
    return y


def coconut_boom(rng, v):
    """Nổ dừa hài: 'CỐC' vỏ rỗng + 'bụp' mềm + mảnh vỏ lách cách."""
    y = canvas(1.1)
    place(y, knock(230, 0.4, rng, (1.0, 1.9, 3.1, 4.7), (0.12, 0.07, 0.04, 0.02), (1, 0.6, 0.35, 0.2)), 0.0, 0.9)
    place(y, lp_burst(0.6, rng, 900, 0.005, 0.18), 0.02, 0.8)
    place(y, glide(0.45, 70, 40, 0.15), 0.02, 0.6)
    for i in range(8):
        f = rng.uniform(900, 2500)
        place(y, dsp.modal(n_of(0.05), [f, f * 2.2], [0.012, 0.006], [1, 0.4], rng=rng), 0.12 + i * rng.uniform(0.04, 0.07),
              0.3 * (1 - i / 10))
    place(y, glide(0.4, 1200, 420, 0.25, attack=0.02, glide_time=0.35), 0.05, 0.12)
    return y


def hunger_low(rng, v):
    """Đói: bụng reo 'ọc ọc' nhẹ."""
    y = canvas(1.3)
    s = voice.vocal([(0, 78), (0.3, 96), (0.6, 70), (0.9, 108), (1.15, 80)], [(0, "u"), (0.6, "ô"), (1.2, "u")], 1.2, rng,
                    fscale=0.8, amp_pts=[(0, 0), (0.03, 0.6), (0.35, 0.3), (0.55, 0.9), (0.8, 0.4), (1.0, 0.7), (1.2, 0)],
                    rough=0.8, rough_rate=17.0, subharm=0.4, jitter=0.05, max_freq=3000)
    s = dsp.lowpass(s, 800, 2)
    place(y, s / (dsp.peak(s) + 1e-9), 0.0, 1.0)
    for st in (0.25, 0.7, 0.95):
        place(y, bubble(rng.uniform(200, 420), 0.1, 1.8, 0.035), st, 0.3)
    return y


def eat(rng, v):
    """Ăn: 'rộp rộp' giòn ngắn, dễ chịu."""
    y = canvas(0.8)
    for bi, st in enumerate((0.0, 0.22, 0.45)):
        a = 1.0 - 0.15 * bi
        for _ in range(25):
            tt = st + abs(rng.normal(0.015, 0.02))
            place(y, burst(0.004, rng, 1500, 8000, 0.0002, rng.uniform(0.0005, 0.0015)), tt, a * rng.uniform(0.3, 1.0))
        place(y, lp_burst(0.12, rng, 400, 0.003, 0.04), st, 0.3 * a)
    place(y, glide(0.08, 600, 900, 0.03), 0.64, 0.12)
    return y


def lootbox_open(rng, v):
    """Mở hộp: nắp gỗ kẽo kẹt + cạch + nhận vật lấp lánh."""
    y = canvas(1.5)
    cr = stick_slip(0.25, rng, [(0, 90), (0.25, 140)], [(0, 0), (0.03, 1), (0.2, 0.8), (0.25, 0)],
                    [700, 1500, 2600], [0.012, 0.008, 0.005], [1.0, 0.6, 0.3])
    place(y, cr / (dsp.peak(cr) + 1e-9), 0.0, 0.45)
    place(y, knock(260, 0.3, rng, (1.0, 2.3, 3.9, 5.6), (0.07, 0.035, 0.015, 0.008)), 0.28, 1.0)
    for i, m in enumerate((84, 88, 91, 96)):
        place(y, mallet(midi_hz(m), 0.8, rng, decay=0.4, bright=0.8), 0.36 + 0.07 * i, 0.45)
        bells_seq(y, rng, [(0.36 + 0.07 * i, m + 12, 0.25)], decay=0.25)
    bells_seq(y, rng, [(0.65 + 0.05 * i, m, 0.15) for i, m in enumerate((103, 105, 108, 110))], decay=0.1)
    return y


def player_join(rng, v):
    """Đồng đội vào phòng: hai nốt đi lên thân thiện."""
    y = canvas(0.65)
    place(y, bubble(400, 0.08, 2.0, 0.03), 0.0, 0.3)
    for st, m in ((0.0, 72), (0.1, 79)):
        place(y, mallet(midi_hz(m), 0.5, rng, decay=0.35, bright=0.7), st, 0.8)
        bells_seq(y, rng, [(st, m + 12, 0.18)], decay=0.2)
    return y


def player_leave(rng, v):
    """Đồng đội rời phòng: hai nốt đi xuống, dịu."""
    y = canvas(0.65)
    for st, m in ((0.0, 79), (0.12, 72)):
        place(y, mallet(midi_hz(m), 0.5, rng, decay=0.3, bright=0.35), st, 0.8)
    return y


def connection_lost(rng, v):
    """Mất kết nối: ba nốt 'bù-bù-bùuu' đi xuống, rung nhẹ."""
    y = canvas(0.95)
    for st, m, d, wob in ((0.0, 76, 0.16, 0.0), (0.19, 72, 0.16, 0.0), (0.38, 69, 0.42, 1.0)):
        n = n_of(d + 0.06)
        t = tvec(n)
        f = midi_hz(m) * 2 ** (-0.4 / 12 * t / d)
        tri = dsp.osc_tri(f, n, max_freq=5000)
        sq = dsp.osc_square(f, n, max_freq=3000)
        s = (0.7 * tri + 0.2 * sq) * dsp.env_adsr(n, 0.008, 0.08, 0.8, 0.03, d)
        if wob:
            s *= 1.0 - 0.35 * (0.5 + 0.5 * np.sin(dsp.TAU * 8 * t)) * np.clip(t / 0.15, 0, 1)
        place(y, s, st, 0.8)
    return dsp.lowpass(y, 3500, 2)


# ================================================================ đăng ký
@dataclass
class Recipe:
    fn: Callable
    peak_db: float
    loop: bool = False
    fin_ms: float = 5.0


RECIPES: dict[str, Recipe] = {
    "sfx_cast_charge": Recipe(cast_charge, -5.0),
    "sfx_cast_whoosh": Recipe(cast_whoosh, -4.5),
    "sfx_lure_splash": Recipe(lure_splash, -4.0),
    "sfx_lure_ground": Recipe(lure_ground, -5.0),
    "sfx_nibble": Recipe(nibble, -6.0),
    "sfx_bite_alert": Recipe(bite_alert, -3.2),
    "sfx_perfect_yank": Recipe(perfect_yank, -3.5),
    "sfx_reel_loop": Recipe(reel_loop, -6.0, loop=True),
    "sfx_line_strain": Recipe(line_strain, -7.0, loop=True),
    "sfx_escape_bloop": Recipe(escape_bloop, -4.0),
    "sfx_launch_pop": Recipe(launch_pop, -3.2),
    "sfx_air_whistle": Recipe(air_whistle, -6.0),
    "sfx_flop": Recipe(flop, -4.5),
    "sfx_hit_slap": Recipe(hit_slap, -3.5),
    "sfx_hit_bonk": Recipe(hit_bonk, -3.5),
    "sfx_slipper_throw": Recipe(slipper_throw, -5.5),
    "sfx_slipper_hit": Recipe(slipper_hit, -3.2),
    "sfx_ko_stars": Recipe(ko_stars, -5.0),
    "sfx_trick_ding": Recipe(trick_ding, -5.0),
    "sfx_coin_gain": Recipe(coin_gain, -5.0),
    "sfx_sell_basket": Recipe(sell_basket, -4.5),
    "sfx_buy": Recipe(buy, -5.0),
    "sfx_error_nope": Recipe(error_nope, -6.0),
    "sfx_pickup": Recipe(pickup, -6.0),
    "sfx_drop_thud": Recipe(drop_thud, -5.0),
    "sfx_player_hurt": Recipe(player_hurt, -4.0),
    "sfx_player_ko": Recipe(player_ko, -4.0),
    "sfx_footstep_wood": Recipe(footstep_wood, -8.0),
    "sfx_footstep_sand": Recipe(footstep_sand, -9.0),
    "sfx_jump": Recipe(jump, -9.0),
    "sfx_land": Recipe(land, -6.0),
    "sfx_boss_roar": Recipe(boss_roar, -3.0),
    "sfx_boss_telegraph": Recipe(boss_telegraph, -4.0),
    "sfx_boss_escape_warning": Recipe(boss_escape_warning, -5.0),
    "sfx_boss_phase": Recipe(boss_phase, -3.2),
    "sfx_boss_escape_splash": Recipe(boss_escape_splash, -3.2),
    "sfx_creature_warn": Recipe(creature_warn, -5.0),
    "sfx_swing_whoosh": Recipe(swing_whoosh, -6.0),
    "sfx_boss_defeat_fanfare": Recipe(boss_defeat_fanfare, -3.2),
    "sfx_quest_complete": Recipe(quest_complete, -5.0),
    "sfx_new_species": Recipe(new_species, -4.5),
    "sfx_ui_click": Recipe(ui_click, -10.0, fin_ms=1.0),
    "sfx_ui_back": Recipe(ui_back, -11.0, fin_ms=1.0),
    "sfx_tutorial_pop": Recipe(tutorial_pop, -7.0),
    "sfx_grill_sizzle_loop": Recipe(grill_sizzle_loop, -9.0, loop=True),
    "sfx_cook_done": Recipe(cook_done, -5.0),
    "sfx_burnt": Recipe(burnt, -5.0),
    "sfx_egret_call": Recipe(egret_call, -6.0),
    "sfx_egret_steal": Recipe(egret_steal, -5.0),
    "sfx_rare_reveal": Recipe(rare_reveal, -4.5),
    "sfx_slingshot_shot": Recipe(slingshot_shot, -5.0),
    "sfx_swatter_zap": Recipe(swatter_zap, -5.0),
    "sfx_coconut_boom": Recipe(coconut_boom, -3.5),
    "sfx_hunger_low": Recipe(hunger_low, -8.0),
    "sfx_eat": Recipe(eat, -6.5),
    "sfx_lootbox_open": Recipe(lootbox_open, -4.0),
    "sfx_player_join": Recipe(player_join, -7.0),
    "sfx_player_leave": Recipe(player_leave, -8.0),
    "sfx_connection_lost": Recipe(connection_lost, -5.5),
}


def render(asset_id: str, variant_index: int, seed: int) -> tuple[np.ndarray, Recipe]:
    """Trả tín hiệu đã hoàn thiện (DC, fade, chuẩn hóa peak)."""
    r = RECIPES[asset_id]
    rng = dsp.rng_for(seed)
    y = np.asarray(r.fn(rng, variant_index), dtype=float)
    if r.loop:
        y = dsp.highpass(y, 25.0, 2, circular=True)
        y = y - np.mean(y)
    else:
        y = dsp.highpass(y, 25.0, 2)
        # cắt đuôi im lặng (< -70 dBFS so với đỉnh) nhưng giữ 20 ms
        p = dsp.peak(y)
        if p > 0:
            idx = np.nonzero(np.abs(y) > p * dsp.undb(-66))[0]
            if idx.size:
                end = min(y.shape[0], idx[-1] + n_of(0.02))
                y = y[:end]
        y = dsp.fade(y, r.fin_ms / 1000.0, 0.005)
    y = dsp.normalize_peak(y, r.peak_db)
    return y, r
