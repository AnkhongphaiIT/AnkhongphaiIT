# WP-09 audio — báo cáo agent art/audio (27/09/2026)

Trạng thái: **đã tạo file thật + đã chạy kiểm định** (validate 0 lỗi, 0 cảnh báo; tái tạo tất định đã kiểm bằng 2 lần chạy sạch).
Không sửa `data/**`, `handoff/**`, `client/`, `server/`, `shared/`. Không commit/push.

## 1. Đã tạo

| Nhóm | asset_id | File | Ghi chú |
|---|---:|---:|---|
| SFX `sfx_*` | 59 | 65 | 3 id có biến thể ×3 (`sfx_flop`, `sfx_footstep_wood`, `sfx_footstep_sand`); 3 file lặp có chunk `smpl` |
| Gibberish `vo_npc_gibberish_*` | 2 | 20 | 10 nữ + 10 nam, 8–12 âm tiết hư cấu, formant nguyên bản |
| Nhạc `mus_*` | 4 | 4 OGG (+4 WAV nguồn trong `tools/.../build/mus/`) | 35,6–43,6 s, −18,0 LUFS, loop liền |
| Âm nền `amb_*` | 3 | 3 OGG (+3 WAV nguồn trong `tools/.../build/amb/`) | 40–44 s, −26 LUFS, loop liền |
| Thoại `vo_dialogue_<npc>_<loc>` | 12 | 62 WAV + 12 JSON | 31 dòng × vi/en, espeak-ng |
| **Tổng trong `assets/audio`** | **80 / 80 id audio của registry** | **166 file + `AUDIO_MANIFEST.json`** | 92 `self_made`, 74 `tbd` (62 WAV thoại + 12 pack) |

Dung lượng: `assets/audio` 33 MB (thoại 23 MB vì WAV PCM16 44.1 kHz), `tools/asset_generation/audio/build` 58 MB
(WAV nguồn nhạc 27 MB + âm nền 22 MB + TTS thô 22.05 kHz 10 MB; có `.gdignore`; tái tạo được → trưởng dự án quyết
định có commit hay thêm vào `.gitignore`).

### Thoại theo NPC × locale (dòng có WAV hợp lệ / dòng yêu cầu)

| NPC | vi | en | Tham số espeak-ng (vi / en) |
|---|---|---|---|
| npc_co_ba | 6/6 | 6/6 | `vi+f4 -p56 -s165 -g1` / `en+f4 -p58 -s170 -g1` |
| npc_ong_tu | 5/5 | 5/5 | `vi+grandpa -p38 -s140 -g2` / `en+grandpa -p36 -s145 -g2` |
| npc_bay_cho | 5/5 | 5/5 | `vi+f2 -p66 -s168 -g1` / `en+f2 -p66 -s172 -g1` |
| npc_co_tam | 5/5 | 5/5 | `vi+f1 -p48 -s150 -g2` / `en+f1 -p50 -s155 -g2` |
| npc_nam_sau | 5/5 | 5/5 | `vi+m2 -p46 -s158 -g1` / `en+m2 -p44 -s162 -g1` |
| npc_chi_lan | 5/5 | 5/5 | `vi+f5 -p70 -s160 -g1` / `en+f5 -p68 -s165 -g1` |
| **Tổng** | **31/31** | **31/31** | 62/62 dòng × ngôn ngữ; thiếu 0 |

Dòng thoại = mọi khóa `npc_<id>.*` trừ `.name` trong `data/loc/strings.csv` (đọc lúc tạo; strings.csv đang được sửa ở
nhánh làm việc nhưng không đổi khóa `npc_*`).

## 2. Lệnh đã chạy và kết quả

```bash
apt-get install -y ffmpeg espeak-ng        # ffmpeg 6.1.1-3ubuntu5, espeak-ng 1.51+dfsg-12build1 (OK)
python3.11 -m venv tools/asset_generation/audio/.venv && touch tools/asset_generation/audio/.venv/.gdignore
tools/asset_generation/audio/.venv/bin/pip install numpy          # numpy 2.4.6 (ghim trong requirements.txt)
python3 tools/asset_generation/audio/generate_all.py              # exit 0, "Xong trong 76.5 s ... (166 file)"
python3 tools/asset_generation/audio/generate_all.py              # chạy lần 2: sha256 167 file assets + 70 file build TRÙNG 100%
python3 tools/asset_generation/audio/validate_audio.py            # exit 0 (tóm tắt bên dưới)
.venv/bin/python tools/validate/check_docs.py                     # {"errors": 0, "warnings": 0, ...} (không bị ảnh hưởng)
```

Tóm tắt `validate_audio.py` (bản cuối):

```
Tổng theo loại (file / FAIL / WARN):
  ambience     3 / 0 / 0
  gib         20 / 0 / 0
  music        4 / 0 / 0
  sfx         65 / 0 / 0
  vo          62 / 0 / 0
Registry audio: 80 asset_id, 104 đường dẫn file mong đợi; manifest: 166 file
Coverage thoại: Tổng: 62/62 dòng × ngôn ngữ
KẾT QUẢ: ĐẠT — lỗi: 0, cảnh báo: 0
```

Ví dụ dòng chi tiết:

```
PASS  music    assets/audio/mus/mus_isl01_day_loop.ogg     40.0s peak  -6.13 LUFS~ -18.0 nối 0.0671/p99 0.0552
PASS  music    assets/audio/mus/mus_boss_loop.ogg          43.6s peak  -5.84 LUFS~ -18.0 nối 0.0181/p99 0.0953
PASS  ambience assets/audio/amb/amb_isl03_day_loop.ogg     44.0s peak  -8.04 LUFS~ -26.1 nối 0.0050/p99 0.0802
PASS  sfx      assets/audio/sfx/sfx_bite_alert.wav          0.62s peak  -3.20 LUFS~ -13.1
PASS  sfx      assets/audio/sfx/sfx_reel_loop.wav           1.00s peak  -6.00 LUFS~ -26.3 loop nối 0.0021/p99 0.0776
PASS  vo       assets/audio/vo/npc_co_ba/vi/greet.wav       3.08s peak  -3.10 LUFS~ -18.2
PASS  gib      assets/audio/vo/vo_npc_gibberish_male_01.wav 2.05s peak  -4.11 LUFS~ -18.0
```

Validator kiểm (đọc lại file thật): đủ file theo registry kể cả `{nn}`; sha256 khớp manifest; trường manifest bắt buộc;
WAV qua module `wave` chuẩn + quét chunk (PCM tag 1, mono, 44100 Hz, 16-bit), thời lượng (SFX ≤ 2 s, loop ≤ 4 s),
peak ≤ −3 dBFS, không clipping, không im lặng, fade đầu/cuối, onset trễ; loop: chunk `smpl` phủ toàn file + bước nhảy
điểm nối (theo cả cách hiểu của Godot và RIFF) so với phân vị 99 bước nhảy kề nhau + RMS đầu/cuối; OGG: ffprobe
(vorbis/stereo/44.1 kHz) + giải mã lại bằng ffmpeg (thời lượng, clipping, LUFS ±3 LU, điểm nối, độ dài = nguồn,
sha256 WAV nguồn); không WAV trong `mus/`/`amb/`; không file lạ ngoài manifest (bỏ qua `.import`); 12 pack JSON:
đúng npc/locale, đủ dòng, file tồn tại, sha256 và text khớp strings.csv. **Thử âm tính:** thêm file lạ + sửa 1 byte
`sfx_ui_click.wav` → validator báo 2 lỗi, exit 1 (đã khôi phục).

Kiểm thêm ngoài validator (QA thủ công, không nằm trong repo):
- Import thử vào **một project Godot 4.7.2 tạm trong scratchpad** (`/opt/godot/4.7.2/godot --headless --import`):
  94 file (65 SFX, 20 gibberish, 7 OGG, 2 thoại) load được, 0 lỗi. WAV lặp: `loop_mode=1`, `loop_begin=0`,
  `loop_end` = đúng số mẫu vòng (44100 / 88200 / 132300). OGG: `loop=false` theo mặc định import.
- Quét click nội bộ (sai phân bậc 2): đã sửa các click do cắt đuôi nốt/limiter; còn lại chỉ là transient có chủ đích
  (tiếng tách UI, lạch cạch guồng, hạt giòn, gõ gỗ) và burst phụ âm có sẵn trong đầu ra thô của espeak-ng.
- Xem spectrogram (PNG tự vẽ) các SFX chính, nhạc, âm nền, gibberish, thoại để kiểm hình dạng âm. **Không có tai người nghe
  thật** — cần trưởng dự án/chủ dự án nghe duyệt.

## 3. Mô tả ngắn nội dung

- SFX: quăng cần "vút" (noise quét dải + rít dây), phao "tõm" (bọt nước pitch đi lên), cá rỉa "plip", cá cắn "bụp" +
  2 nốt chuông thủy tinh G6→C7 "tink-tink" (to nhất, −13 LUFS), giật chuẩn "ping" E7 + lấp lánh, cá quẫy lạch bạch
  (3 biến thể 2–4 cú đập ướt), dép "CHÁT!" + bật nhẹ, KO chuông sao quay + huýt trượt, tiền 2 đồng xu leng keng, lỗi
  "nè-nè" mũi nhẹ, bước chân gỗ (gót + mũi, 3 biến thể) / cát (hạt lạo xạo, 3 biến thể), boss gầm formant cách điệu +
  nước quẫy, fanfare kèn "ta-ta-ta TAAA" + trống + chuông (2,0 s)… Mỗi hàm có docstring trong `cabay_audio/sfx.py`.
- Nhạc (giai điệu viết tay, ngũ cung): đảo 1 Sol 96 BPM đàn gảy Karplus-Strong + sáo + bass + gõ gỗ; đảo 2 La 108 BPM
  marimba + gảy chặt nhịp + sáo đối; đảo 3 Rê 6/8 (chấm đen chấm 62) sáo + pad + trống khung + sóng + chuông gió; boss
  Mi thứ → Sol trưởng 132 BPM kèn + bass nảy + trống + tom fill (không kinh dị).
- Âm nền: đảo 1 nước róc rách + bọt + gió + 9 tiếng chim + dế + ghe máy xa; đảo 2 gió lá dừa theo cơn + lạch nước +
  chim nhiệt đới (koel, bulbul) + ve; đảo 3 6 con sóng vỗ/rút + gió hú qua đá + hải âu xa.

## 4. Giấy phép

- `self_made` (92 file): SFX, nhạc, âm nền, gibberish — tổng hợp nguyên bản bằng numpy trong `tools/asset_generation/audio`;
  không sample/model/tài nguyên tải về.
- `tbd` (74 file): 62 WAV thoại + 12 pack JSON. Phân tích espeak-ng (ghi trong `license_analysis` của manifest):
  - Gói Ubuntu `espeak-ng` / `espeak-ng-data` **1.51+dfsg-12build1**; hai tệp `/usr/share/doc/espeak-ng/copyright` và
    `/usr/share/doc/espeak-ng-data/copyright` giống nhau:
    - "Copyright Holders: Jonathan Duddington <jonsd@talktalk.net> 2005-2014 … Reece H. Dunn 2013-2016" (cùng Gilles
      Casse 2007, Ross Bencina / Phil Burk 1999-2002, Sun Microsystems 2008, Bill Cox 2010, Nicolas Pitre 2010, The
      NetBSD Foundation 2000).
    - "The rest of upstream sources are licensed under the following terms: This package is free software; you can
      redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free
      Software Foundation; either version 3 of the License, or (at your option) any later version."
    - Ngoại lệ chỉ cho `src/libespeak-ng/ieee80.c` (Apple, cho phép phân phối kèm thông báo) và `src/compat/getopt.c` (BSD NetBSD).
  - Dữ liệu giọng (phondata, từ điển `vi_dict`/`en_dict`, biến thể `voices/!v`) không có điều khoản riêng → thuộc
    GPL-3.0-or-later. `phondata-manifest` liệt kê **162 mục "W - A wavefile segment"** (ustop 60, ufric 33, x 14,
    vietnam 9, h 9, …): các đoạn sóng mẫu này có thể được chép vào âm thanh đầu ra, nên không thể mặc định coi đầu ra là
    không vướng GPL.
  - Không dùng mbrola. Không tự khẳng định quyền thương mại. Phương án: (a) phát hành WAV thoại như dữ liệu phái sinh
    GPL-3.0-or-later kèm thông báo + script tái tạo, tách khỏi mã game (gộp đơn thuần); (b) xin tư vấn pháp lý; (c) thay
    bằng ghi âm có đồng ý.

## 5. Chưa làm được / giới hạn (kèm lý do)

1. **Không có asset audio nào của registry bị thiếu file.** Tuy vậy thoại hiện là TTS formant espeak-ng: nghe máy móc,
   tiếng Việt dùng giọng `vi` (Bắc) theo yêu cầu — bối cảnh miền Tây hợp hơn với `vi-vn-x-south` (có sẵn, chưa dùng;
   đổi ở `BASE_VOICE` trong `cabay_audio/tts.py`). Giấy phép `tbd` → chưa phát hành được cho tới khi trưởng dự án quyết.
2. Chưa có người nghe duyệt thật (môi trường không có loa); mới kiểm bằng số đo + spectrogram.
3. Loop OGG: Godot import mặc định `loop=false`. `AudioDirector` hiện tự đặt `loop = true` trong code nên chạy được;
   nếu muốn, đặt `loop=true` trong `.ogg.import` của 7 file. Tôi **không** sửa các `.import` (do tiến trình Godot của
   trưởng dự án tạo trong `assets/audio/`).
4. `AudioDirector.start_loop` ghi đè `loop_end = get_length()*mix_rate` = số mẫu file (gồm 1 mẫu nhân đôi ở cuối) →
   chỉ lặp lại mẫu đầu thêm 1 lần, không nghe thấy; có thể bỏ ghi đè vì WAV đã có điểm loop chính xác.
5. `sfx_cast_charge` là one-shot 1,25 s (kẽo kẹt dồn dập, cao dần) — không gắn loop; `sfx_line_strain` là vòng 2 s đều,
   "tăng dần" nên do code tăng `pitch_scale`/âm lượng theo lực căng.
6. Pack JSON khóa `lines` bằng **text_key đầy đủ** (vd `npc_co_ba.greet`) để khớp `AudioDirector.play_voice(npc_id,
   p["text_key"])`; file đặt theo `<npc_id>/<locale>/<line_key>.wav` (vd `vo/npc_co_ba/vi/greet.wav`), mỗi mục có `line_key`.
7. Import WAV mặc định Godot 4.7.2 là `compress/mode=2` (QOA, có tổn hao nhẹ) — giữ nguyên hay chuyển PCM là quyết định tích hợp.
8. Độ to là ước lượng BS.1770 tự viết (không có đồng hồ LUFS chuẩn); sai số nhỏ so với công cụ chuẩn là có thể.

## 6. File do agent này tạo/sửa

- `tools/asset_generation/audio/`: `generate_all.py`, `validate_audio.py`, `requirements.txt`, `README.md`,
  `cabay_audio/{__init__,dsp,wavio,project,voice,sfx,music,ambience,tts}.py`, `.venv/` (+ `.gdignore`, bị `.gitignore` gốc bỏ qua),
  `build/` (+ `.gdignore`; WAV nguồn + TTS thô).
- `assets/audio/`: `sfx/` (65 WAV), `vo/` (20 gibberish + 12 pack JSON + 62 WAV trong `vo/<npc_id>/<locale>/`),
  `mus/` (4 OGG), `amb/` (3 OGG), `AUDIO_MANIFEST.json`. (Các `*.import` trong đó do tiến trình Godot của dự án tạo.)
- `reports/tmp/audio_report.md` (file này; lưu ý `reports/tmp/` đang bị `.gitignore` gốc bỏ qua).
