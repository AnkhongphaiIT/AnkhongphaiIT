# Preflight tài nguyên (theo `docs/14_AI_ASSET_HANDOFF.md` §2)

Cập nhật: 27/09/2026. Máy: container Ubuntu đám mây (4 CPU, 15 GB RAM), Godot 4.7.2 + export templates web/linux, Python 3.11, ffmpeg 6.1.1, espeak-ng 1.51, Chromium 141 (Playwright), fontTools. Không có Blender, không có GPU (render phần mềm).

## Có thật (file trên đĩa, đã kiểm)

| Nhóm | Số lượng | Trạng thái | Bằng chứng |
|---|---|---|---|
| Âm thanh SFX/nhạc/ambience/gibberish | 59 + 4 + 3 + 2 id (92 file) | `in_review` (tự tổng hợp, đo đạt; **chưa có người nghe duyệt**) | `assets/audio/AUDIO_MANIFEST.json`, `tools/asset_generation/audio/validate_audio.py` |
| Thoại VI/EN espeak-ng | 12 pack (62 file) | `tbd` — không phát hành | `assets/audio/vo/LICENSE-VO.md` |
| Font UI Be Vietnam Pro + ký hiệu | 1 id | OFL đã kiểm, dùng trong game | `assets/fonts/SOURCES.md` |
| Mô hình 3D low-poly | đảo ×3, NPC ×6, người chơi, 18 loài, công cụ ×6, cần ×2, đạo cụ | dựng bằng mã lúc chạy (`client/scripts/visual/models.gd`), **chưa bake ra file theo đường dẫn registry** | ảnh chụp `release/screenshots/` |
| UI | theme + mọi màn hình dựng bằng mã | chạy thật trong trình duyệt | `tests/web/scenarios/*` |

## Claude tự tạo tiếp được (không cần người dùng)

- Bake mô hình procedural ra file `.tscn/.res` đúng đường dẫn registry; bake icon 256×256 RGBA từ mô hình (render phần mềm qua xvfb).
- Hoạt ảnh (quăng, giật, quay cần, cá giãy/xỉu, NPC idle/nói), VFX (bọt nước, sao xỉu, tiền), shader nước/viewmodel.
- Cập nhật `handoff/source_manifest.json` từ file thật (hash đo được).

## Cần người dùng (không chặn lập trình)

| Việc | Batch | Chặn gì |
|---|---|---|
| Relay ChatGPT: bảng phong cách + 3 đảo (tham khảo) | `requests/b01_style_islands/` | không chặn (chỉ để chỉnh thẩm mỹ) |
| Relay ChatGPT: ảnh bìa/banner itch.io | `requests/b02_store_art/` | trang itch đẹp hơn (có thể dùng ảnh chụp game thay) |
| Thu giọng thoại VI/EN có đồng ý (hoặc quyết định về espeak-ng) | `requests/voice_v1/` | tiêu chí "lời thoại có giọng đọc" của bản cuối |
| Nghe duyệt SFX/nhạc | — | chuyển âm thanh từ `in_review` sang `approved` |

## Thiếu chỉ chặn một hạng mục

- Voice người thật → chỉ chặn nghiệm thu voice; game vẫn chạy bằng gibberish + phụ đề.
- Ảnh bìa ChatGPT → chỉ ảnh hưởng trang itch.
