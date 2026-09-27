# WP-09-audio — Âm thanh procedural + giọng đọc VI/EN (giao subagent art-audio)

Trạng thái: IN_PROGRESS (giao lúc 27/09/2026) · Chủ tích hợp: Claude (main)

## Mục tiêu
Tạo **file âm thanh thật, nguyên bản, tái tạo được** cho mọi asset `sfx_*`, `mus_*`, `amb_*`, `vo_npc_gibberish_*` và các pack thoại `vo_dialogue_<npc>_<vi|en>` trong `data/contracts/asset_registry.json`, bằng code chạy offline, chi phí 0 đồng.

## Đầu vào (chỉ đọc)
- `data/contracts/asset_registry.json` (id, path, variants `{nn}`, notes), `data/contracts/audio_event_map.json`
- `data/loc/strings.csv` (cột `keys,en,vi`) — lời thoại NPC là mọi khóa `npc_<id>.*` trừ `.name`
- `data/content/npcs.json` (6 NPC), `docs/05_ART_BIBLE.md` §11, `docs/06_ASSET_BIBLE.md` §5, `docs/14_AI_ASSET_HANDOFF.md` §7–8

## File được phép tạo/sửa (allowlist)
- `tools/asset_generation/audio/**` (script Python, requirements, README)
- `assets/audio/**` (đầu ra đúng đường dẫn `res://assets/audio/...` trong registry)
- `reports/tmp/audio_report.md`

**Không** sửa `data/**`, `handoff/source_manifest.json`, mã game hay file khác.

## Công cụ
- Python 3.11 + numpy trong venv riêng `tools/asset_generation/audio/.venv` (thêm file `.gdignore` vào `.venv`).
- `ffmpeg` (apt) chỉ để mã hóa OGG Vorbis từ WAV nguồn; `espeak-ng` (apt) cho giọng đọc TTS. Được phép `apt-get install -y ffmpeg espeak-ng`.
- Không tải asset/sample/model từ Internet. Không dùng mbrola hay giọng có điều khoản riêng.

## Yêu cầu đầu ra
| Loại | Định dạng | Ghi chú |
|---|---|---|
| SFX (`sfx_*`) | WAV PCM16 mono 44.1 kHz, thường ≤ 2 s, peak ≤ −3 dBFS, fade 5 ms | Loop (`*_loop`) không click ở điểm nối. Biến thể `{nn}` → `_01`…`_NN` đúng số `variants` |
| Nhạc (`mus_*`) | OGG Vorbis stereo 44.1 kHz + giữ WAV nguồn ngoài `assets/` (vd `tools/asset_generation/audio/build/`) | Giai điệu nguyên bản; đảo 1 ~90–100 BPM ấm áp, đảo 2 xanh/tươi, đảo 3 gió biển; boss 120–140 BPM vui căng vừa, không kinh dị; loop liền; 30–60 s |
| Ambience (`amb_*`) | OGG stereo 44.1 kHz, loop ≥ 30 s | Nước/gió/côn trùng/chim nhẹ tổng hợp; mức nhỏ (~ −26 LUFS ước lượng RMS) |
| Gibberish | WAV mono, 10 biến thể nữ + 10 nam, mỗi file 8–12 âm tiết hư cấu | Tổng hợp nguyên bản (formant/oscillator), vui, không phải tiếng người thật |
| Thoại VI/EN | Một WAV mono PCM16 44.1 kHz mỗi `line_id` × locale | espeak-ng giọng `vi` và `en`; mỗi NPC một bộ tham số giọng riêng (pitch/tốc độ/biến thể). Đường dẫn: `assets/audio/vo/<npc_id>/<locale>/<line_key>.wav` |
| Chỉ mục pack thoại | JSON đúng path registry `assets/audio/vo/vo_dialogue_<npc>_<locale>.json` | `{"npc_id","locale","lines":{"<line_key>":{"file":"res://...wav","sha256":"...","text":"..."}}}` |

## Nguồn/giấy phép
- Mỗi file ghi vào `assets/audio/AUDIO_MANIFEST.json`: `asset_id`, `variant`, `path`, `sha256` (tự tính sau khi ghi), `generator` (script + hàm), `seed`, `tool_versions`, `license`, `notes`.
- SFX/nhạc/ambience/gibberish tổng hợp bằng code: `license: "self_made"`.
- Thoại espeak-ng: đọc `/usr/share/doc/espeak-ng*/copyright` sau khi cài; ghi phiên bản, giấy phép phần mềm và giấy phép dữ liệu giọng. Đặt `license: "tbd"` kèm ghi chú phân tích nếu chưa chắc; **không tự khẳng định** quyền thương mại. Claude sẽ quyết định cuối.

## Kiểm định bắt buộc (script `tools/asset_generation/audio/validate_audio.py`)
Đọc lại từng file thật: định dạng/kênh/sample rate/bit depth, thời lượng, peak dBFS, không clipping, không im lặng hoàn toàn, loop: chênh lệch mẫu đầu/cuối nhỏ. OGG: giải mã lại bằng ffmpeg để kiểm. In bảng pass/fail; exit 1 nếu lỗi.

## Tiêu chí xong
1. `python tools/asset_generation/audio/generate_all.py` chạy lại được từ đầu (tất định theo seed) và tạo đủ file.
2. `validate_audio.py` = 0 lỗi.
3. `reports/tmp/audio_report.md`: danh sách asset đã tạo (đếm theo file và theo asset_id), số dòng thoại mỗi NPC × locale, asset chưa làm được + lý do, lệnh đã chạy và kết quả.
