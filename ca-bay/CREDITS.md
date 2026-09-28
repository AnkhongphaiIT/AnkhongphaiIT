# CÁ BAY — Ghi công và giấy phép / Credits and licenses

Tên game là tên tạm. / The title is a working title.

## Làm game / Made with

| Thành phần / Component | Nguồn / Source | Giấy phép / License |
|---|---|---|
| Godot Engine 4.7.2 (web runtime) | godotengine.org | MIT + thành phần bên thứ ba, xem `LICENSES/GODOT.txt` / see `LICENSES/GODOT.txt` |
| Mô hình 3D low-poly, địa hình, nhân vật, cá / 3D low-poly models | Tự dựng bằng mã GDScript (procedural) trong dự án / generated procedurally by project code | Của dự án / project-owned |
| Hiệu ứng âm thanh, nhạc, âm nền, giọng "ú ớ" / SFX, music, ambience, gibberish voices | Tự tổng hợp offline bằng Python + numpy, mã hóa OGG bằng ffmpeg (chỉ dùng làm công cụ) / synthesized offline by project scripts (`tools/asset_generation/audio/`) | Của dự án / project-owned (`self_made`) |
| Font giao diện Be Vietnam Pro / UI font Be Vietnam Pro | The Be Vietnam Pro Project Authors (github.com/bettergui/BeVietnamPro) | SIL Open Font License 1.1, `LICENSES/fonts/OFL-BeVietnamPro.txt` |
| Font ký hiệu "CaBay Symbols" (tập con DejaVu Sans) / symbol font (DejaVu Sans subset) | DejaVu fonts (Bitstream Vera derivative) | Bitstream Vera license + public domain, `LICENSES/fonts/LICENSE-DejaVu-symbols.txt` |

Bản phát hành web **không** kèm thoại tổng hợp giọng máy (espeak-ng) vì giấy phép chưa được chốt; NPC dùng giọng "ú ớ" + phụ đề.
The web release does **not** include the espeak-ng synthesized dialogue (license not yet cleared); NPCs use gibberish voices + subtitles.

## Gói máy chủ / Server packages

| Thành phần / Component | Nguồn / Source | Giấy phép / License |
|---|---|---|
| Godot Engine 4.7.2 (room server headless, Linux x86_64 / Windows x86_64) | godotengine.org | MIT + bên thứ ba / third-party, `LICENSES/GODOT.txt` |
| Python 3.11.9 (chỉ gói Windows, thư mục `python\` / Windows package only) | Gói NuGet `python` của Python Software Foundation / PSF NuGet package | PSF License, `LICENSES/PYTHON.txt` |
| FastAPI, Starlette, Pydantic, pydantic-core, Uvicorn, AnyIO, h11, Click, jsonschema, referencing, rpds-py, attrs, annotated-types, typing-inspection, annotated-doc | PyPI (`backend/requirements.lock.txt`) | MIT |
| websockets, httpx, httpcore, idna, Starlette, Uvicorn, Click | PyPI | BSD-3-Clause |
| typing_extensions | PyPI | PSF-2.0 |
| certifi | PyPI | MPL-2.0 (không sửa đổi / unmodified) |
| packaging | PyPI | Apache-2.0 OR BSD-2-Clause |

Văn bản giấy phép đầy đủ của từng thư viện nằm trong thư mục `*.dist-info` khi cài (gói Windows: `python\Lib\site-packages\`).
Full license texts of each library ship in its `*.dist-info` folder (Windows package: `python\Lib\site-packages\`).

## Dữ liệu người chơi / Player data

Game cần tài khoản để lưu tiến trình trên máy chủ. Xem trang quyền riêng tư đi kèm bản phát hành.
An account is required to store progress on the server. See the privacy page shipped with the release.
