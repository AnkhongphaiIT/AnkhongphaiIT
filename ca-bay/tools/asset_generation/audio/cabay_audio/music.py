"""Nhạc nền nguyên bản (sáng tác trong code), render vòng tròn để loop liền.

Mỗi bài: sequencer đơn giản -> bus stereo -> vang tích chập vòng -> chuẩn hóa độ to
(~ -18 LUFS). Nốt có đuôi vượt quá cuối vòng được quấn về đầu (circular), vang
cũng tích chập vòng nên điểm nối đầu/cuối liền mạch.
Giai điệu viết tay theo thang ngũ cung; nhạc cụ tổng hợp (dây gảy Karplus-Strong,
sáo, marimba, bass sine, kèn saw, bộ gõ nhẹ).
"""
from __future__ import annotations

import math

import numpy as np

from . import dsp
from .dsp import SR, TAU, midi_hz, n_of, tvec
from .sfx import brass, burst, mallet, pad_tone


# ================================================================ nhạc cụ
def i_pluck(f, d, rng, t60=1.6, bright=0.55, damp=0.2, release=0.1):
    ring = d + min(t60 * 0.5, 1.0)
    n = n_of(ring)
    y = dsp.ks_pluck(f, n, rng, t60=t60, damp=damp, bright=bright)
    t = tvec(n)
    y = y * np.where(t < d, 1.0, np.exp(-(t - d) / release))
    return dsp.fade(y, 0.0015, 0.01)  # mềm cú gảy + đuôi về 0


def i_flute(f, d, rng, vib=0.0055, breath=0.03, attack=0.07, rel=0.16):
    n = n_of(d + rel)
    t = tvec(n)
    vib_env = np.clip((t - 0.18) / 0.25, 0, 1)
    fm = f * (1 + vib * vib_env * np.sin(TAU * 5.2 * t + rng.uniform(0, TAU))) * (1 - 0.012 * np.exp(-t / 0.05))
    ph = dsp.phase_of(fm)
    y = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.09 * np.sin(3 * ph) + 0.035 * np.sin(4 * ph) + 0.015 * np.sin(5 * ph)
    nb = dsp.band(rng.standard_normal(n), 1200, 7000, 2)
    nb = nb / (np.std(nb) + 1e-9)
    env = dsp.env_adsr(n, attack, 0.25, 0.85, rel * 0.4, d)
    out = (y + breath * nb) * env
    ch = burst(min(0.03, d + rel), rng, 2000, 5000, 0.002, 0.012)
    out[:ch.shape[0]] += 0.06 * ch
    return out


def i_bass(f, d, rng, tau=0.6, rel=0.06, sustain=0.55):
    n = n_of(d + rel + 0.02)
    t = tvec(n)
    fm = f * (1 + 0.015 * np.exp(-t / 0.02))
    ph = dsp.phase_of(fm)
    y = np.sin(ph) + 0.28 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph) + 0.03 * np.sin(4 * ph)
    return y * dsp.env_adsr(n, 0.006, tau, sustain, rel * 0.5, d)


def i_mallet(f, d, rng, decay=0.5, bright=0.6):
    return mallet(f, max(d, decay * 2.5), rng, decay=decay, bright=bright)


def i_brass(f, d, rng, bright=1.0):
    return brass(f, d, rng, bright=bright, attack=0.02, release=0.08)


def i_square(f, d, rng, rel=0.05):
    n = n_of(d + rel)
    t = tvec(n)
    fm = f * (1 + 0.004 * np.sin(TAU * 6 * t) * np.clip((t - 0.1) / 0.2, 0, 1))
    y = dsp.osc_harmonics(fm, lambda k: (1.0 / k ** 1.15) if k % 2 else 0.12 / k, n, max_freq=9000)
    y = dsp.lowpass(y, 3200, 2)
    return y * dsp.env_adsr(n, 0.005, 0.12, 0.6, rel * 0.5, d) * 0.6


def i_pad(f, d, rng):
    return pad_tone(f, d, rng, attack=0.4, release=0.8, tilt=1.8, max_freq=4000)


def i_bell(f, d, rng, decay=0.5):
    return dsp.bell(n_of(decay * 3), f, decay=decay, bright=0.7, rng=rng)


# ---- bộ gõ
def d_kick(rng):
    n = n_of(0.35)
    t = tvec(n)
    f = 48 + 75 * np.exp(-t / 0.028)
    y = np.sin(dsp.phase_of(f)) * np.exp(-t / 0.16)
    c = dsp.lowpass(rng.standard_normal(n_of(0.004)), 2500)
    y[:c.shape[0]] += 0.15 * c / (np.max(np.abs(c)) + 1e-9) * np.hanning(c.shape[0])
    return dsp.fade(y, 0.0, 0.08)


def d_snare(rng):
    n = n_of(0.25)
    t = tvec(n)
    nz = burst(0.25, rng, 900, 7000, 0.001, 0.07)
    return 0.55 * nz / (np.max(np.abs(nz)) + 1e-9) + 0.5 * np.sin(TAU * 190 * t) * np.exp(-t / 0.045) + \
        0.2 * np.sin(TAU * 330 * t) * np.exp(-t / 0.03)


def d_clap(rng):
    y = np.zeros(n_of(0.25))
    for k, st in enumerate((0.0, 0.009, 0.018)):
        b = burst(0.03, rng, 900, 5000, 0.0005, 0.005)
        dsp.add_at(y, b * (0.8 if k < 2 else 1.0), n_of(st))
    tail = burst(0.2, rng, 900, 4500, 0.001, 0.05)
    dsp.add_at(y, 0.5 * tail, n_of(0.018))
    return y / (np.max(np.abs(y)) + 1e-9)


def d_shaker(rng):
    b = burst(0.1, rng, 4000, 11000, 0.012, 0.03)
    return b / (np.max(np.abs(b)) + 1e-9)


def d_hat(rng, open_=False):
    b = burst(0.3 if open_ else 0.08, rng, 7000, 14000, 0.0005, 0.12 if open_ else 0.022)
    return b / (np.max(np.abs(b)) + 1e-9)


def d_wood(rng, f=900.0):
    y = dsp.modal(n_of(0.15), [f, f * 2.52, f * 4.1], [0.045, 0.02, 0.01], [1.0, 0.35, 0.12], rng=rng, attack=0.0003)
    return y / (np.max(np.abs(y)) + 1e-9)


def d_tom(rng, f=140.0):
    n = n_of(0.45)
    t = tvec(n)
    y = np.sin(dsp.phase_of(f * (1 + 0.35 * np.exp(-t / 0.02)))) * np.exp(-t / 0.22)
    nz = dsp.lowpass(rng.standard_normal(n), 1500) * np.exp(-t / 0.03)
    return dsp.fade(y + 0.04 * nz / (np.max(np.abs(nz)) + 1e-9), 0.0, 0.1)


def d_frame(rng, f=88.0):
    n = n_of(0.5)
    t = tvec(n)
    y = np.sin(dsp.phase_of(f * (1 + 0.2 * np.exp(-t / 0.02)))) * np.exp(-t / 0.25)
    nz = dsp.lowpass(rng.standard_normal(n), 1200) * np.exp(-t / 0.04)
    return dsp.fade(y + 0.35 * nz / (np.max(np.abs(nz)) + 1e-9), 0.0, 0.1)


def d_crash(rng):
    n = n_of(1.6)
    b = burst(1.6, rng, 3000, 12000, 0.002, 0.8)
    return dsp.fade(b / (np.max(np.abs(b)) + 1e-9) * (1 + 0.15 * np.sin(TAU * 7 * tvec(n))), 0.0, 0.3)


# ================================================================ sequencer
class Song:
    def __init__(self, bpm: float, bars: int, bpb: int, seed: int, swing: float = 0.0, humanize: float = 0.005):
        self.spb = 60.0 / bpm
        self.bpb = bpb
        self.bars = bars
        self.total_beats = bars * bpb
        self.n = n_of(self.total_beats * self.spb)
        self.rng = dsp.rng_for(seed)
        self.swing = swing
        self.humanize = humanize
        self.buses: dict[str, np.ndarray] = {}

    def bus(self, name):
        if name not in self.buses:
            self.buses[name] = np.zeros((self.n, 2))
        return self.buses[name]

    def t_of(self, beat: float) -> float:
        frac = beat % 1.0
        sw = self.swing * self.spb * 0.5 if abs(frac - 0.5) < 1e-6 else 0.0
        return beat * self.spb + sw

    def put(self, bus, beat, mono, pan=0.0, gain=1.0, human=True):
        t = self.t_of(beat) + (float(self.rng.normal(0, self.humanize)) if human else 0.0)
        dsp.add_at(self.bus(bus), dsp.pan_stereo(mono * gain, pan), n_of(t), circular=True)

    def note(self, bus, inst, beat, dur_beats, midi, vel=1.0, pan=0.0, **kw):
        if midi is None:
            return
        y = inst(midi_hz(midi), dur_beats * self.spb, self.rng, **kw)
        self.put(bus, beat, y, pan, vel * (0.92 + 0.16 * float(self.rng.random())))

    def melody(self, bus, inst, bars_notes, start_bar=0, transpose=0, vel=1.0, pan=0.0, **kw):
        """bars_notes: danh sách ô nhịp, mỗi ô [(midi|None, dur_beats), ...]."""
        for bi, bar in enumerate(bars_notes):
            b = (start_bar + bi) * self.bpb
            assert abs(sum(d for _, d in bar) - self.bpb) < 1e-6, (bi, bar)
            for m, d in bar:
                if m is not None:
                    self.note(bus, inst, b, d, m + transpose, vel, pan, **kw)
                b += d

    def mix(self, levels: dict, rt60=1.6, wet=0.3, target_lufs=-18.0, ceiling_db=-1.5,
            predelay=0.02, stereo_width=1.0) -> np.ndarray:
        dry = np.zeros((self.n, 2))
        send = np.zeros((self.n, 2))
        for name, buf in self.buses.items():
            g, s = levels.get(name, (1.0, 0.0))
            dry += g * buf
            send += s * g * buf
        ir = dsp.reverb_ir(dsp.rng_for(7), rt60=rt60, predelay=predelay, stereo=True)
        wet_sig = dsp.convolve(send, ir, circular=True)
        mix = dry + wet * wet_sig
        if stereo_width != 1.0:
            m = (mix[:, 0] + mix[:, 1]) / 2
            sd = (mix[:, 0] - mix[:, 1]) / 2 * stereo_width
            mix = np.stack([m + sd, m - sd], axis=1)
        mix = dsp.highpass(mix, 32.0, 2, circular=True)
        mix = dsp.filt(mix, dsp.r_lp(15000.0, 2), circular=True)
        return dsp.normalize_loudness(mix, target_lufs, ceiling_db, circular=True)


def _split(ch):
    return ch.split("|") if "|" in ch else [ch]


# ================================================================ Đảo 1: Cù Lao (ấm áp, 96 BPM, Sol ngũ cung)
def song_isl01(seed: int) -> np.ndarray:
    s = Song(96, 16, 4, seed, swing=0.08)
    chords = ["G", "Em", "C", "D", "G", "Em", "C|D", "G", "C", "G", "Am", "D", "Em", "C", "D", "G"]
    arps = {"G": [55, 62, 67, 71, 74, 71, 67, 62], "Em": [52, 59, 64, 67, 71, 67, 64, 59],
            "C": [55, 60, 64, 67, 72, 67, 64, 60], "D": [57, 62, 66, 69, 74, 69, 66, 62],
            "Am": [57, 60, 64, 69, 72, 69, 64, 60]}
    roots = {"G": 43, "Em": 40, "C": 48, "D": 50, "Am": 45}
    acc = [1.0, 0.6, 0.8, 0.6, 0.9, 0.6, 0.8, 0.65]
    for bi, ch in enumerate(chords):
        parts = _split(ch)
        for e in range(8):
            c = parts[0] if (len(parts) == 1 or e < 4) else parts[1]
            m = arps[c][e]
            s.note("pluck", i_pluck, bi * 4 + e * 0.5, 1.5, m, 0.5 * acc[e], pan=0.25 if e % 2 else -0.15,
                   t60=1.8, bright=0.5)
        if len(parts) == 1:
            r = roots[ch]
            for b, m, d in ((0, r, 1.5), (1.5, r + 7, 0.5), (2, r, 1.0), (3, r + 7, 1.0)):
                s.note("bass", i_bass, bi * 4 + b, d * 0.9, m, 1.0 if b == 0 else 0.8)
        else:
            for k, c in enumerate(parts):
                r = roots[c]
                s.note("bass", i_bass, bi * 4 + 2 * k, 0.9, r, 1.0)
                s.note("bass", i_bass, bi * 4 + 2 * k + 1, 0.9, r + 7, 0.8)
    mel = [
        [(74, 1), (71, .5), (69, .5), (67, 1), (69, 1)],
        [(71, 1.5), (74, .5), (76, 1), (74, 1)],
        [(76, 1), (79, 1), (76, .5), (74, .5), (71, 1)],
        [(69, 3), (None, 1)],
        [(74, 1), (71, .5), (69, .5), (67, 1), (64, 1)],
        [(67, 1.5), (69, .5), (71, 1), (74, 1)],
        [(76, 1), (74, .5), (71, .5), (69, 1), (71, 1)],
        [(67, 3), (None, 1)],
        [(76, 1.5), (79, .5), (81, 1), (79, 1)],
        [(76, 1), (74, 1), (71, 2)],
        [(69, 1), (71, .5), (74, .5), (76, 1), (74, 1)],
        [(69, 2), (71, .5), (69, .5), (None, 1)],
        [(71, 1), (74, 1), (76, 1), (79, 1)],
        [(81, 1.5), (79, .5), (76, 1), (74, 1)],
        [(76, 1), (74, .5), (71, .5), (69, 1), (74, 1)],
        [(67, 2.5), (None, 0.5), (69, 0.5), (71, 0.5)],
    ]
    s.melody("flute", i_flute, mel, pan=-0.12)
    s.melody("mallet", i_mallet, mel[8:], start_bar=8, pan=0.3, vel=0.8, decay=0.45, bright=0.5)
    for bi in range(16):
        for e in range(8):
            s.put("shaker", bi * 4 + e * 0.5, d_shaker(s.rng), pan=0.35, gain=0.5 if e % 2 else 0.3)
        for b in (1, 3):
            s.put("wood", bi * 4 + b, d_wood(s.rng, 980.0), pan=-0.3, gain=0.4)
        if bi % 4 == 3:
            s.put("wood", bi * 4 + 3.5, d_wood(s.rng, 1150.0), pan=-0.3, gain=0.22)
        kicks = (0,) if bi < 4 else (0, 2)
        for b in kicks:
            s.put("kick", bi * 4 + b, d_kick(s.rng), gain=0.45 if bi < 4 else 0.6)
    levels = {"pluck": (2.4, 0.3), "flute": (0.55, 0.35), "mallet": (0.3, 0.3), "bass": (0.5, 0.0),
              "kick": (0.85, 0.05), "wood": (1.2, 0.2), "shaker": (0.8, 0.15)}
    return s.mix(levels, rt60=1.7, wet=0.32)


# ================================================================ Đảo 2: Rừng Dừa (tươi, 108 BPM, La ngũ cung)
def song_isl02(seed: int) -> np.ndarray:
    s = Song(108, 16, 4, seed, swing=0.0, humanize=0.004)
    chords = ["A", "F#m", "D", "E", "A", "F#m", "D|E", "A", "D", "A", "Bm", "E", "F#m", "D", "E", "A"]
    chop = {"A": [61, 64, 69], "F#m": [61, 66, 69], "D": [62, 66, 69], "E": [59, 64, 68], "Bm": [59, 62, 66]}
    roots = {"A": 45, "F#m": 42, "D": 50, "E": 40, "Bm": 47}
    for bi, ch in enumerate(chords):
        parts = _split(ch)
        for b in range(4):
            c = parts[0] if (len(parts) == 1 or b < 2) else parts[1]
            for k, m in enumerate(chop[c]):
                s.note("chop", i_pluck, bi * 4 + b + 0.5 + 0.008 * k, 0.3, m, 0.45, pan=0.35 if b % 2 else -0.35,
                       t60=0.5, bright=0.85, damp=0.12, release=0.05)
        if len(parts) == 1:
            r = roots[ch]
            pat = ((0, r, 0.5), (0.75, r, 0.25), (1.5, r + 7, 0.5), (2, r, 0.5), (3, r + 12, 0.5), (3.5, r + 7, 0.5))
        else:
            r1, r2 = roots[parts[0]], roots[parts[1]]
            pat = ((0, r1, 0.5), (0.75, r1, 0.25), (1.5, r1 + 7, 0.5), (2, r2, 0.5), (3, r2 + 12, 0.5), (3.5, r2 + 7, 0.5))
        for b, m, d in pat:
            s.note("bass", i_bass, bi * 4 + b, d * 0.85, m, 1.0 if b in (0, 2) else 0.75, tau=0.3, sustain=0.4)
    mel = [
        [(76, .5), (73, .5), (76, .5), (78, .5), (76, 1), (73, 1)],
        [(71, .5), (73, .5), (71, .5), (69, .5), (66, 1), (69, 1)],
        [(69, .5), (71, .5), (73, .5), (76, 1), (78, .5), (76, 1)],
        [(71, 2), (None, .5), (64, .5), (66, .5), (69, .5)],
        [(76, .5), (73, .5), (76, .5), (78, .5), (81, 1), (78, 1)],
        [(76, .5), (73, .5), (71, .5), (73, .5), (69, 1), (66, 1)],
        [(69, .5), (71, .5), (73, 1), (71, .5), (69, .5), (71, 1)],
        [(69, 2), (None, 2)],
        [(78, 1), (76, .5), (78, .5), (81, 1), (78, 1)],
        [(76, .5), (73, .5), (69, 1), (73, 1), (76, 1)],
        [(71, 1), (73, .5), (71, .5), (66, 1), (71, 1)],
        [(76, 1.5), (73, .5), (71, 1), (None, 1)],
        [(73, .5), (76, .5), (78, 1), (81, .5), (78, .5), (76, 1)],
        [(78, 1), (76, 1), (73, 1), (69, 1)],
        [(71, .5), (73, .5), (76, 1), (71, 1), (73, 1)],
        [(69, 1), (None, 1), (76, .5), (73, .5), (None, 1)],
    ]
    s.melody("marimba", i_mallet, mel, pan=-0.1, decay=0.42, bright=0.75)
    counter = [[(78, 4)], [(76, 4)], [(74, 4)], [(71, 4)], [(73, 4)], [(74, 4)], [(71, 2), (76, 2)], [(73, 4)]]
    s.melody("flute", i_flute, counter, start_bar=8, pan=0.3, vib=0.007, breath=0.045)
    for bi in range(16):
        for e in range(16):
            s.put("shaker", bi * 4 + e * 0.25, d_shaker(s.rng), pan=0.4, gain=(0.5, 0.25, 0.35, 0.25)[e % 4])
        for b in (1, 3):
            s.put("clap", bi * 4 + b, d_clap(s.rng), pan=0.1, gain=0.35)
        for b in (0, 2, 2.75):
            s.put("kick", bi * 4 + b, d_kick(s.rng), gain=0.6 if b != 2.75 else 0.35)
        if bi % 2 == 1:
            s.put("wood", bi * 4 + 3.5, d_wood(s.rng, 1250.0), pan=-0.35, gain=0.35)
    levels = {"chop": (1.5, 0.2), "bass": (0.49, 0.0), "marimba": (0.55, 0.25), "flute": (0.25, 0.4),
              "shaker": (0.6, 0.1), "clap": (1.6, 0.25), "kick": (0.8, 0.05), "wood": (1.1, 0.2)}
    return s.mix(levels, rt60=1.3, wet=0.25)


# ================================================================ Đảo 3: Mũi Đá (gió biển, 6/8, Rê ngũ cung)
def song_isl03(seed: int) -> np.ndarray:
    s = Song(186, 20, 6, seed, swing=0.0, humanize=0.006)  # đơn vị = móc đơn; chấm đen chấm = 62 BPM
    chords = ["D", "Bm", "G", "A", "D", "G", "Em", "A", "Bm", "G", "D", "A", "Bm", "G", "Em", "A", "D", "G", "A", "D"]
    arps = {"D": [62, 69, 74, 78, 74, 69], "Bm": [59, 66, 71, 74, 71, 66], "G": [55, 62, 67, 71, 67, 62],
            "A": [57, 64, 69, 73, 69, 64], "Em": [52, 59, 64, 67, 64, 59]}
    roots = {"D": 38, "Bm": 35, "G": 43, "A": 45, "Em": 40}
    pads = {"D": [62, 66, 69], "Bm": [59, 62, 66], "G": [59, 62, 67], "A": [61, 64, 69], "Em": [59, 64, 67]}
    for bi, ch in enumerate(chords):
        for e in range(6):
            s.note("pluck", i_pluck, bi * 6 + e, 2.5, arps[ch][e], 0.42 * (1.0 if e in (0, 3) else 0.7),
                   pan=(-0.3, 0.1, 0.3, -0.1, 0.25, -0.25)[e], t60=2.2, bright=0.45)
        r = roots[ch]
        s.note("bass", i_bass, bi * 6, 2.8, r, 1.0, tau=0.9, sustain=0.5)
        s.note("bass", i_bass, bi * 6 + 3, 2.8, r + 7, 0.75, tau=0.9, sustain=0.5)
        for k, m in enumerate(pads[ch]):
            s.note("pad", i_pad, bi * 6, 6.0, m, 0.5, pan=(-0.5, 0.0, 0.5)[k])
    mel = [
        [(78, 3), (76, 1), (74, 2)],
        [(71, 3), (74, 2), (76, 1)],
        [(78, 2), (81, 1), (78, 2), (76, 1)],
        [(76, 6)],
        [(81, 3), (83, 1), (81, 2)],
        [(78, 2), (76, 1), (74, 3)],
        [(76, 2), (78, 1), (76, 2), (71, 1)],
        [(69, 6)],
        [(71, 2), (74, 1), (76, 3)],
        [(78, 2), (76, 1), (74, 2), (71, 1)],
        [(74, 3), (78, 3)],
        [(76, 4), (None, 2)],
        [(83, 3), (81, 1), (78, 2)],
        [(81, 2), (78, 1), (76, 3)],
        [(78, 2), (76, 1), (74, 2), (76, 1)],
        [(76, 3), (69, 3)],
        [(74, 2), (76, 1), (78, 3)],
        [(81, 3), (78, 2), (76, 1)],
        [(76, 2), (74, 1), (71, 2), (69, 1)],
        [(74, 6)],
    ]
    s.melody("flute", i_flute, mel, pan=0.0, vib=0.007, breath=0.05, attack=0.1)
    pent = [86, 88, 90, 93, 95, 98]
    for bi in range(20):
        s.put("drum", bi * 6, d_frame(s.rng, 86.0), gain=0.55)
        s.put("drum", bi * 6 + 3, d_frame(s.rng, 96.0), gain=0.35)
        for e, g in ((1, 0.1), (2, 0.22), (4, 0.1), (5, 0.22)):
            s.put("shaker", bi * 6 + e, d_shaker(s.rng), pan=0.3, gain=g)
        if bi % 4 == 3:
            for k in range(4):
                m = pent[int(s.rng.integers(0, len(pent)))]
                s.note("chime", i_bell, bi * 6 + 4 + 0.35 * k, 0.5, m, 0.3, pan=float(s.rng.uniform(-0.7, 0.7)),
                       decay=0.6)
    # sóng nhẹ: nhiễu lọc phồng lên mỗi 4 ô nhịp (tuần hoàn)
    n = s.n
    wave = dsp.lowpass(np.stack([s.rng.standard_normal(n), s.rng.standard_normal(n)], 1), 900.0, 2, circular=True)
    wave /= np.std(wave) + 1e-9
    period = 4 * 6 * s.spb
    ph = (tvec(n) % period) / period
    env = np.sin(math.pi * np.clip(ph / 0.8, 0, 1)) ** 2
    s.bus("waves")[:] += wave * env[:, None] * 0.25
    levels = {"pluck": (2.2, 0.35), "bass": (0.45, 0.0), "pad": (0.25, 0.5), "flute": (0.55, 0.4),
              "drum": (0.8, 0.1), "shaker": (1.5, 0.2), "chime": (0.25, 0.5), "waves": (0.13, 0.2)}
    return s.mix(levels, rt60=2.2, wet=0.35, stereo_width=1.15)


# ================================================================ Boss: vui căng vừa (132 BPM, Mi thứ ngũ cung)
def song_boss(seed: int) -> np.ndarray:
    s = Song(132, 24, 4, seed, swing=0.0, humanize=0.003)
    secA = ["Em", "Em", "C", "D", "Em", "Em", "C", "B"]
    secB = ["G", "D", "Em", "C", "G", "D", "C", "D"]
    chords = secA + secB + secA
    roots = {"Em": 40, "C": 36, "D": 38, "B": 35, "G": 43}
    chop = {"Em": [64, 67, 71], "C": [64, 67, 72], "D": [62, 66, 69], "B": [63, 66, 71], "G": [62, 67, 71]}
    bass_pat = [0, 0, 12, 0, 7, 0, 12, 7]
    for bi, ch in enumerate(chords):
        r = roots[ch]
        for e, off in enumerate(bass_pat):
            s.note("bass", i_bass, bi * 4 + e * 0.5, 0.38, r + off, 1.0 if e % 2 == 0 else 0.8, tau=0.2, sustain=0.5)
        for b in range(4):
            for k, m in enumerate(chop[ch]):
                s.note("chop", i_pluck, bi * 4 + b + 0.5 + 0.006 * k, 0.22, m, 0.5, pan=0.3 if b % 2 else -0.3,
                       t60=0.4, bright=0.9, damp=0.1, release=0.04)
    melA = [
        [(64, .5), (67, .5), (69, .5), (71, .5), (74, .5), (71, .5), (69, 1)],
        [(67, .5), (69, .5), (67, .5), (64, .5), (62, 1), (64, 1)],
        [(76, 1), (74, .5), (72, .5), (71, 1), (67, 1)],
        [(69, .5), (71, .5), (74, 1), (69, 1), (None, 1)],
        [(64, .5), (67, .5), (69, .5), (71, .5), (74, .5), (71, .5), (69, 1)],
        [(67, .5), (69, .5), (67, .5), (64, .5), (62, 1), (64, 1)],
        [(76, .5), (79, .5), (76, .5), (74, .5), (72, 1), (71, 1)],
        [(74, .5), (71, .5), (69, .5), (67, .5), (66, 1), (71, 1)],
    ]
    melB = [
        [(79, .75), (76, .25), (74, .5), (76, .5), (79, 1), (81, 1)],
        [(78, 1), (74, .5), (76, .5), (78, 1), (81, 1)],
        [(79, .5), (78, .5), (76, .5), (74, .5), (71, 1), (76, 1)],
        [(76, 1.5), (74, .5), (72, 1), (None, 1)],
        [(79, .75), (76, .25), (74, .5), (76, .5), (79, 1), (83, 1)],
        [(81, 1), (78, .5), (81, .5), (86, 1), (81, 1)],
        [(79, .5), (81, .5), (79, .5), (76, .5), (74, 1), (72, 1)],
        [(74, 1), (78, 1), (81, 1), (None, 1)],
    ]
    s.melody("lead", i_brass, melA, 0, pan=-0.05, vel=0.9)
    s.melody("lead", i_brass, melB, 8, pan=-0.05, vel=0.9)
    s.melody("mallet", i_mallet, melB, 8, transpose=12, pan=0.35, vel=0.45, decay=0.3, bright=0.8)
    s.melody("sq", i_square, melA, 16, transpose=12, pan=0.2, vel=0.7)
    s.melody("lead", i_brass, melA, 16, pan=-0.2, vel=0.6)
    for bi in range(24):
        base = bi * 4
        for b in (0, 2):
            s.put("kick", base + b, d_kick(s.rng), gain=0.8)
        if bi % 2 == 1:
            s.put("kick", base + 2.75, d_kick(s.rng), gain=0.45)
        for b in (1, 3):
            s.put("snare", base + b, d_snare(s.rng), gain=0.55)
            if 8 <= bi < 16:
                s.put("clap", base + b, d_clap(s.rng), gain=0.35, pan=0.15)
        for e in range(8):
            s.put("hat", base + e * 0.5, d_hat(s.rng), pan=0.3, gain=0.55 if e % 2 else 0.3)
        if bi % 8 == 7:
            for k, (b, f) in enumerate(((2, 190), (2.5, 165), (3, 140), (3.25, 125), (3.5, 110), (3.75, 95))):
                s.put("tom", base + b, d_tom(s.rng, f), pan=0.4 - 0.16 * k, gain=0.55)
        if bi in (0, 8, 16):
            s.put("crash", base, d_crash(s.rng), pan=-0.2, gain=0.35)
    levels = {"bass": (0.39, 0.0), "chop": (1.1, 0.15), "lead": (0.8, 0.25), "mallet": (0.38, 0.25),
              "sq": (0.42, 0.2), "kick": (0.64, 0.0), "snare": (1.4, 0.2), "clap": (1.3, 0.2),
              "hat": (0.65, 0.05), "tom": (0.35, 0.2), "crash": (0.4, 0.1)}
    return s.mix(levels, rt60=1.1, wet=0.2)


SONGS = {
    "mus_isl01_day_loop": (song_isl01, "Đảo 1 Cù Lao: ấm áp 96 BPM, Sol ngũ cung, đàn gảy + sáo + bass + bộ gõ gỗ; 16 ô nhịp"),
    "mus_isl02_day_loop": (song_isl02, "Đảo 2 Rừng Dừa: tươi 108 BPM, La ngũ cung, marimba + gảy chặt nhịp + sáo đối; 16 ô nhịp"),
    "mus_isl03_day_loop": (song_isl03, "Đảo 3 Mũi Đá: gió biển 6/8 (chấm đen chấm 62), Rê ngũ cung, sáo + pad + trống khung + sóng; 20 ô nhịp"),
    "mus_boss_loop": (song_boss, "Boss: vui căng vừa 132 BPM, Mi thứ ngũ cung -> Sol trưởng, kèn + bass nảy + trống; 24 ô nhịp"),
}
