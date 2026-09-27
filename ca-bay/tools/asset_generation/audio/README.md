# Âm thanh CÁ BAY — bộ tạo offline (WP-09)

Tạo **file âm thanh thật, nguyên bản, tái tạo được** cho mọi asset `sfx_*`, `mus_*`, `amb_*`,
`vo_npc_gibberish_*` và 12 pack thoại `vo_dialogue_<npc>_<vi|en>` trong
`data/contracts/asset_registry.json`. Chạy offline, chi phí 0, tất định theo seed.

- SFX / nhạc / âm nền / gibberish: tổng hợp bằng numpy (không sample, không model tải về) → `license: self_made`.
- Thoại VI/EN: espeak-ng cục bộ (giọng formant tích hợp `vi`, `en` + biến thể `!v`, **không mbrola**) → `license: tbd`
  (xem mục Giấy phép).

## Cài đặt (một lần)

```bash
apt-get install -y ffmpeg espeak-ng           # ffmpeg chỉ để mã hóa OGG Vorbis; espeak-ng cho thoại
python3.11 -m venv tools/asset_generation/audio/.venv
touch tools/asset_generation/audio/.venv/.gdignore
tools/asset_generation/audio/.venv/bin/pip install -r tools/asset_generation/audio/requirements.txt
```

## Chạy (từ gốc dự án `ca-bay/`)

```bash
python3 tools/asset_generation/audio/generate_all.py            # tạo tất cả (~80 s trên 4 CPU, tuần tự)
python3 tools/asset_generation/audio/generate_all.py --only sfx,gib   # chỉ vài nhóm: sfx,gib,mus,amb,vo
python3 tools/asset_generation/audio/validate_audio.py          # kiểm định; exit 1 nếu có lỗi (--quiet, --json OUT)
```

Hai script tự chuyển sang `.venv` nếu `python3` hệ thống thiếu numpy.
Seed mỗi file = 8 hex đầu của `sha256("cabay-audio:<asset_id>:<variant>")`; chạy lại cho byte giống hệt
(đã kiểm: hai lần chạy sạch liên tiếp → sha256 của mọi file trong `assets/audio` và `build/` trùng khớp).

## Đầu ra

| Nhóm | Đường dẫn | Định dạng |
|---|---|---|
| SFX (59 id, 65 file; `{nn}` → `_01…_NN`) | `assets/audio/sfx/` | WAV PCM16 mono 44.1 kHz, ≤ 2 s (loop ≤ 3 s), peak ≤ −3 dBFS, fade 5 ms (UI click 1 ms vào) |
| Gibberish (10 nữ + 10 nam) | `assets/audio/vo/vo_npc_gibberish_{female,male}_NN.wav` | WAV PCM16 mono 44.1 kHz, 8–12 âm tiết, ~ −18 LUFS |
| Nhạc (4) | `assets/audio/mus/*.ogg` (+ WAV nguồn `build/mus/`) | OGG Vorbis q5 stereo 44.1 kHz, 35–44 s, −18 LUFS, loop liền |
| Âm nền (3) | `assets/audio/amb/*.ogg` (+ WAV nguồn `build/amb/`) | OGG Vorbis q4 stereo 44.1 kHz, 40–44 s, −26 LUFS, loop liền |
| Thoại (62 dòng = 31 dòng × vi/en) | `assets/audio/vo/<npc_id>/<locale>/<line_key>.wav` | WAV PCM16 mono 44.1 kHz, ~ −18 LUFS, peak −3.1 dBFS |
| Chỉ mục pack thoại (12) | `assets/audio/vo/vo_dialogue_<npc>_<locale>.json` | `{"npc_id","locale","pack_asset_id","voice","license","lines":{"<text_key>":{"file","sha256","text","line_key","duration_s"}}}` |
| Manifest | `assets/audio/AUDIO_MANIFEST.json` | mỗi file: `asset_id, variant, path, sha256, generator, seed, tool_versions, license, notes` (+ loop_points, source_wav…) |

`<npc_id>` là id trong `data/content/npcs.json` (vd `npc_co_ba`); `<line_key>` là phần sau `npc_<id>.` của khóa
trong `data/loc/strings.csv` (vd `greet`). Trong pack JSON, `lines` được khóa bằng **khóa đầy đủ** `text_key`
(vd `npc_co_ba.greet`, khớp payload `dialogue.line_started.text_key` và `AudioDirector.play_voice`), mỗi mục có thêm `line_key`.

`build/` (có `.gdignore`): WAV nguồn nhạc/âm nền (~49 MB) + WAV thô 22.05 kHz của espeak-ng (~10 MB). Tái tạo được
bằng script, nên có thể không cần commit.

## Vòng lặp (loop)

- SFX lặp (`sfx_reel_loop`, `sfx_line_strain`, `sfx_grill_sizzle_loop`): render tuần hoàn; file có chunk RIFF `smpl`
  (vòng forward) và thêm 1 mẫu cuối = mẫu đầu. Godot 4.7.2 (import mặc định "Detect From WAV") đã được thử:
  `loop_mode=1`, `loop_begin=0`, `loop_end` = đúng số mẫu vòng gốc. `sfx_line_strain` là vòng đều; code nên tăng
  `pitch_scale`/âm lượng theo lực căng để có cảm giác "tăng dần".
- Nhạc/âm nền OGG: render vòng tròn (đuôi nốt, vang và điều biến quấn về đầu). Godot import OGG mặc định `loop=false`
  → khi tích hợp cần đặt `loop=true` (loop_offset 0) trong `.ogg.import`.

## Thiết kế ngắn

- `cabay_audio/dsp.py`: lọc pha 0 bằng FFT, lọc biến thiên theo STFT, tổng hợp mode (chuông/gỗ), Karplus-Strong có
  trễ phân số, vang tích chập (vòng), limiter, ước lượng LUFS (BS.1770, K-weighting).
- `sfx.py`: mỗi SFX một hàm có docstring mô tả âm (vd bite_alert = "bụp" nước + 2 nốt chuông tink-tink; slipper_hit =
  "CHÁT!"; boss_roar = nước quẫy + gầm formant cách điệu; fanfare = kèn "ta-ta-ta TAAA").
- `voice.py`: giọng formant cộng hài (nguyên âm a/ă/e/ê/i/o/ô/u/ơ/ư, phụ âm b/d/g/m/n/l/t/k/h/s/x, 6 đường thanh điệu kiểu
  tiếng Việt) cho gibberish và tiếng kêu không lời.
- `music.py`: 4 bài viết tay theo thang ngũ cung — đảo 1 (Sol, 96 BPM, đàn gảy + sáo), đảo 2 (La, 108 BPM, marimba),
  đảo 3 (Rê, 6/8 gió biển), boss (Mi thứ → Sol trưởng, 132 BPM, kèn + bass nảy, không kinh dị).
- `ambience.py`: nước róc rách + chim + dế + ghe máy xa (đảo 1), gió lá dừa + chim nhiệt đới + ve (đảo 2), sóng vỗ +
  gió hú mũi đá + hải âu xa (đảo 3).
- `tts.py`: espeak-ng → 22.05 kHz → nâng mẫu ×2 bằng FFT → cắt lặng → −18 LUFS, trần −3 dBFS → fade 5 ms.
  Mỗi NPC một bộ tham số (biến thể, `-p`, `-s`, `-g`), xem `NPC_VOICES`.

## Giấy phép

- `self_made`: SFX, nhạc, âm nền, gibberish — tạo nguyên bản bằng code trong thư mục này.
- `tbd`: toàn bộ thoại espeak-ng và 12 pack JSON. espeak-ng 1.51+dfsg-12build1: phần mềm và dữ liệu giọng
  (`espeak-ng-data`) đều GPL-3.0-or-later theo `/usr/share/doc/espeak-ng*/copyright`; `phondata` chứa 162 đoạn sóng
  mẫu ("W - A wavefile segment") có thể đi vào âm thanh đầu ra. Không tự khẳng định quyền thương mại — xem
  `license_analysis` trong `AUDIO_MANIFEST.json`; trưởng dự án quyết định.
