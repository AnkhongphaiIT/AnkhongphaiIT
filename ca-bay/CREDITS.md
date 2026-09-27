# CÁ BAY — Ghi công và giấy phép / Credits and licenses

Tên game là tên tạm. / The title is a working title.

## Làm game / Made with

| Thành phần / Component | Nguồn / Source | Giấy phép / License |
|---|---|---|
| Godot Engine 4.7.2 (web runtime) | godotengine.org | MIT + thành phần bên thứ ba, xem `LICENSES/GODOT.txt` / see `LICENSES/GODOT.txt` |
| Mô hình 3D low-poly, địa hình, nhân vật, cá / 3D low-poly models | Tự dựng bằng mã GDScript (procedural) trong dự án / generated procedurally by project code | Của dự án / project-owned |
| Hiệu ứng âm thanh, nhạc, âm nền, giọng "ú ớ" / SFX, music, ambience, gibberish voices | Tự tổng hợp offline bằng Python + numpy, mã hóa OGG bằng ffmpeg (chỉ dùng làm công cụ) / synthesized offline by project scripts (`tools/asset_generation/audio/`) | Của dự án / project-owned (`self_made`) |
| Font giao diện Nunito / UI font Nunito | The Nunito Project Authors (github.com/googlefonts/nunito) | SIL Open Font License 1.1, `LICENSES/fonts/OFL-Nunito.txt` |
| Font ký hiệu "CaBay Symbols" (tập con DejaVu Sans) / symbol font (DejaVu Sans subset) | DejaVu fonts (Bitstream Vera derivative) | Bitstream Vera license + public domain, `LICENSES/fonts/LICENSE-DejaVu-symbols.txt` |

Bản phát hành web **không** kèm thoại tổng hợp giọng máy (espeak-ng) vì giấy phép chưa được chốt; NPC dùng giọng "ú ớ" + phụ đề.
The web release does **not** include the espeak-ng synthesized dialogue (license not yet cleared); NPCs use gibberish voices + subtitles.

## Dữ liệu người chơi / Player data

Game cần tài khoản để lưu tiến trình trên máy chủ. Xem trang quyền riêng tư đi kèm bản phát hành.
An account is required to store progress on the server. See the privacy page shipped with the release.
