"""Ghi/đọc WAV PCM16 (tự viết header RIFF để thêm chunk `smpl` cho loop).

Godot 4 (ResourceImporterWAV, loop mode "Detect From WAV") đọc điểm loop từ
chunk `smpl`, nên SFX lặp sẽ tự lặp khi import mặc định.
"""
from __future__ import annotations

import struct
from pathlib import Path

import numpy as np


def float_to_pcm16(x: np.ndarray) -> np.ndarray:
    y = np.clip(np.asarray(x, dtype=np.float64), -1.0, 1.0)
    return np.round(y * 32767.0).astype("<i2")


def write_wav(path: Path | str, x: np.ndarray, sr: int = 44100, loop: tuple[int, int] | None = None) -> None:
    """x: (n,) mono hoặc (n, c). loop=(start, end_exclusive) để ghi chunk smpl."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = float_to_pcm16(x)
    ch = 1 if pcm.ndim == 1 else pcm.shape[1]
    data = pcm.tobytes()
    block_align = ch * 2
    fmt = struct.pack("<HHIIHH", 1, ch, sr, sr * block_align, block_align, 16)
    chunks = [b"fmt " + struct.pack("<I", len(fmt)) + fmt]
    if loop is not None:
        start, end_excl = int(loop[0]), int(loop[1])
        # smpl: 9 trường header + 1 vòng lặp (cue id, type, start, end, fraction, playcount).
        # Theo đặc tả RIFF, dwEnd là mẫu cuối cùng được phát (bao gồm) -> end_excl - 1.
        sample_period = int(round(1e9 / sr))
        smpl = struct.pack("<9I", 0, 0, sample_period, 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, start, end_excl - 1, 0, 0)
        chunks.append(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
    chunks.append(b"data" + struct.pack("<I", len(data)) + data + (b"\x00" if len(data) % 2 else b""))
    body = b"WAVE" + b"".join(chunks)
    path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)


def read_wav(path: Path | str) -> dict:
    """Đọc WAV PCM (8/16/24/32-bit int). Trả dict: sr, channels, bits, format_tag, data (float), loops."""
    raw = Path(path).read_bytes()
    if raw[:4] != b"RIFF" or raw[8:12] != b"WAVE":
        raise ValueError(f"{path}: không phải RIFF/WAVE")
    pos = 12
    info: dict = {"loops": []}
    data = None
    while pos + 8 <= len(raw):
        cid = raw[pos:pos + 4]
        size = struct.unpack("<I", raw[pos + 4:pos + 8])[0]
        body = raw[pos + 8:pos + 8 + size]
        if cid == b"fmt ":
            tag, ch, sr, _br, _ba, bits = struct.unpack("<HHIIHH", body[:16])
            info.update(format_tag=tag, channels=ch, sr=sr, bits=bits)
        elif cid == b"data":
            data = body
        elif cid == b"smpl" and len(body) >= 36:
            nloops = struct.unpack("<I", body[28:32])[0]
            for i in range(nloops):
                off = 36 + 24 * i
                if off + 24 <= len(body):
                    _cue, typ, s, e, _fr, _pc = struct.unpack("<6I", body[off:off + 24])
                    info["loops"].append({"type": typ, "start": s, "end_inclusive": e})
        pos += 8 + size + (size & 1)
    if data is None or "sr" not in info:
        raise ValueError(f"{path}: thiếu fmt/data")
    bits = info["bits"]
    ch = info["channels"]
    if bits == 16:
        arr = np.frombuffer(data[: len(data) // 2 * 2], dtype="<i2").astype(np.float64) / 32768.0
    elif bits == 8:
        arr = (np.frombuffer(data, dtype=np.uint8).astype(np.float64) - 128.0) / 128.0
    elif bits == 24:
        b = np.frombuffer(data[: len(data) // 3 * 3], dtype=np.uint8).reshape(-1, 3)
        v = (b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16))
        v = np.where(v >= 1 << 23, v - (1 << 24), v)
        arr = v.astype(np.float64) / float(1 << 23)
    elif bits == 32:
        arr = np.frombuffer(data[: len(data) // 4 * 4], dtype="<i4").astype(np.float64) / float(1 << 31)
    else:
        raise ValueError(f"{path}: bit depth {bits} không hỗ trợ")
    if ch > 1:
        arr = arr[: len(arr) // ch * ch].reshape(-1, ch)
    info["data"] = arr
    info["frames"] = arr.shape[0]
    return info
