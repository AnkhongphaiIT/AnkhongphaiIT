# PREFLIGHT — kiểm tra môi trường thật

Ngày: 27/09/2026 · Người chạy: Claude Code (phiên đám mây) · Gói nguồn: `game-cau-ca-docs-v2.zip` bản **2.0.0**

> Môi trường triển khai hiện tại là **container Ubuntu đám mây** của phiên Claude Code (chủ dự án đã xác nhận dùng môi trường này). Máy Windows 8 GB của chủ dự án **không** truy cập được từ đây; các ứng dụng cài trên máy đó (Godot, Codex, Antigravity, VS Code) không được tính là có sẵn trong phiên này.

## 1. Gói nguồn

| Hạng mục | Trạng thái | Bằng chứng | Hành động |
|---|---|---|---|
| ZIP v2 | detected | `/root/.claude/uploads/.../bda92d08-game-cau-ca-docs-v2.zip`, sha256 `6aeabf21e4392b31ead46ed0a49e9690eade66df4858df8a1d9a3cba14f51b21`, 90 mục, 911 441 byte | Dùng làm nguồn duy nhất |
| Phiên bản | detected 2.0.0 | `00_START_HERE.md` "Bộ yêu cầu triển khai 2.0.0"; `11` §5 có dòng 2.0.0 | — |
| An toàn ZIP | pass | Không có đường dẫn tuyệt đối, `..`, symlink hay tỉ lệ nén bất thường; `testzip()` sạch | Giải nén vào scratchpad rồi chép vào dự án; ZIP gốc không sửa |
| Toàn vẹn file | pass | `sha256sum -c SOURCE_FILES_SHA256.txt`: 89/89 OK | — |
| ZIP v1 (`game-cau-ca-docs.zip`, 1.0.0) | bỏ qua | sha256 `17e08807…`, lịch sử chỉ có 1.0.0 | Không dùng theo chỉ thị |
| Script trong gói | đã đọc trước khi chạy | `tools/check_docs.py`, `check_data_core.py` chỉ đọc file, không có lệnh mạng/xóa/subprocess | Chạy trong venv dự án |
| Validator gói | pass | `.venv/bin/python tools/validate/check_docs.py` → `{"errors":0,"warnings":0,"json_files":25,"regular_species":15,"bosses":3,"islands":3,"assets":287,"events":84,"localization_keys":273}` | Chỉ chứng minh tài liệu/dữ liệu nhất quán, **không** chứng minh game chạy |

## 2. Máy và thư mục

| Hạng mục | Trạng thái | Bằng chứng | Hành động |
|---|---|---|---|
| Thư mục làm việc | detected, ghi được | `/home/user/AnkhongphaiIT` (repo Git, nhánh `claude/tender-allen-ofqkn5`, chưa có commit) | Tạo `ca-bay/` mới (chưa tồn tại trước đó), không tạo repo lồng |
| OS | detected | Ubuntu 24.04.4 LTS x86_64, kernel 6.18 | — |
| CPU/RAM | detected | 4 nhân, 15 GiB RAM, không swap | Vẫn giữ nguyên tắc 8 GB của tài liệu cho **máy chủ dự án**; tối đa 2 việc code song song |
| Đĩa | detected | ~30 GB trống | — |
| Tính bền | **ephemeral** | Container bị thu hồi khi phiên không hoạt động | Mọi tiến độ phải commit + push lên GitHub; không dùng container này làm server công khai |

## 3. Công cụ

| Công cụ | Trạng thái | Bằng chứng | Hành động |
|---|---|---|---|
| Godot | **detected 4.7.2.stable.official.ed1daf0bf** | `godot --version`; hash commit khớp tag `4.7.2-stable` (`git ls-remote`), là tag stable mới nhất | Ghim trong `toolchain.lock.json` |
| Nguồn cài Godot | unverified-official-sums | `godotengine.org` / `downloads.godotengine.org` bị chính sách mạng chặn (403); GitHub release asset bị chặn. Đã lấy từ layer Docker Hub `barichello/godot-ci:4.7.2` (digest đã kiểm), layer này tải từ `godotengine/godot-builds` | Chưa đối chiếu SHA512-SUMS chính thức — ghi rủi ro, không chặn phát triển |
| Export templates | detected 4.7.2.stable | `version.txt` = `4.7.2.stable`; cài web (threads/nothreads, release/debug) + linux x86_64 | Khớp editor |
| Xuất web Compatibility | **pass** | Dự án thử `gl_compatibility` → `--export-release Web` exit 0 → phục vụ HTTP → Chromium headless: `OpenGL ES 3.0 (WebGL 2.0) - Compatibility`, `single-threaded, no GDExtension`, cảnh 3D render ra ảnh | Dùng bản không thread (không cần COOP/COEP, hợp iframe itch.io) |
| GDScript/WebSocket | pass | `ClassDB.class_exists("WebSocketMultiplayerPeer") == true` trong bản web | — |
| Git | detected 2.43.0 | `git --version` | — |
| Python | detected 3.11.15 | venv dự án `.venv/` | Không sửa Python hệ thống |
| scrypt | detected | `hashlib.scrypt` có (OpenSSL 3.0.13); n=2^17,r=8,p=1: 0,45 s/lần | Dùng theo `07` §4 |
| SQLite | detected 3.45.1 | module `sqlite3` | WAL + backup API |
| PyPI | reachable | `jsonschema==4.26.0`, `referencing==0.37.0` cài được; FastAPI/uvicorn/httpx/pytest/numpy có | Khóa phiên bản trong lock file |
| Node / Playwright | detected Node 22.22.2, Playwright 1.56.1 | `npm ls -g` | Dùng cho smoke web |
| Chromium | detected 141.0.7390.37 | Playwright bundle, WebGL2 qua SwiftShader | — |
| Firefox | absent | Không có trong `/opt/pw-browsers` | WEB-01 phần Firefox = `NOT_RUN` cho tới khi chủ dự án thử trên máy mình |
| apt (Ubuntu archive) | reachable | `apt-cache policy`: `ffmpeg 6.1.1`, `espeak-ng 1.51`, `blender 4.0.2` có sẵn để cài | Cài khi cần cho pipeline âm thanh |
| Docker | client có, daemon không chạy | `/var/run/docker.sock` không tồn tại | Không cần; tài liệu yêu cầu tránh phụ thuộc Docker |
| Blender | absent (có thể cài từ apt) | — | Không dùng; mô hình procedural trong Godot (DEC-020) |

## 4. Agent và kết nối AI

| Bên | Trạng thái | Bằng chứng | Hành động |
|---|---|---|---|
| Claude subagent | detected | Công cụ Agent của phiên có các loại `general-purpose`, `Explore`, `Plan` | Dùng cho việc có ranh giới rõ (xem `tasks/BACKLOG.md`) |
| Codex CLI | absent | `command -v codex` → không có | Không giao tự động; Claude làm thay |
| Antigravity | absent | `command -v antigravity` → không có | Không giao tự động; Claude làm thay |
| ChatGPT Plus | chỉ qua người dùng | Không API, không tự điều khiển web (theo `14`) | Batch yêu cầu ở `handoff/requests/` |

## 5. Mạng (chính sách môi trường)

| Host | Trạng thái | Ảnh hưởng |
|---|---|---|
| `itch.io` | **blocked 403** (egress policy) | Không upload/không kiểm iframe itch.io từ phiên này |
| `godotengine.org`, `downloads.godotengine.org` | blocked 403 | Đã có phương án thay (Docker Hub) |
| GitHub release assets | blocked | Chỉ đọc git được (clone/ls-remote) |
| `huggingface.co`, `opengameart.org`, `kenney.nl`, `freesound.org`, `polyhaven.com`, `fonts.google.com` | không kết nối được | Không tải được model TTS/asset thư viện → dùng procedural + apt |
| `pypi.org`, `registry.npmjs.org`, `archive.ubuntu.com`, Docker Hub | reachable | Đủ cho backend, test, audio tool |
| Trang giá fly.io, render.com, railway, koyeb, trycloudflare docs | không kết nối được | Không xác minh được điều khoản free tier từ đây |

## 6. Tài khoản, hạ tầng, tên miền

| Hạng mục | Trạng thái | Bằng chứng | Hành động |
|---|---|---|---|
| Tài khoản itch.io / quyền upload | absent trong phiên | Không có token butler, host bị chặn | `NEED-ITCH` |
| Máy chủ công khai HTTPS/WSS + đĩa bền | absent | Không có endpoint nào được cấp; container này ephemeral và không nhận kết nối vào | `NEED-HOST`; vẫn làm server local/LAN + gói deploy |
| Tên miền `.io` | absent | Không có thông tin sở hữu | Nhánh website `.io` chờ; không mua |
| Email/liên hệ vận hành cho trang quyền riêng tư | absent | — | `NEED-CONTACT` (chỉ chặn công khai) |

## 7. Cổng quyết định (`12` §4)

| Cổng | Trạng thái | Lý do |
|---|---|---|
| CODE_READY | **đạt** | Workspace ghi được, Godot 4.7.2 + templates, Python/SQLite, Node/Chromium |
| WEB_READY | đạt một phần | Export + HTTP + WebGL2 đã chạy với cảnh thử; input chuột/phím và mở âm thanh sẽ kiểm ở M0 trong dự án thật |
| ONLINE_TEST_READY | chưa | Thiếu endpoint HTTPS/WSS bền và thiết bị thứ hai |
| PUBLIC_READY | chưa | Thiếu host, quyền itch.io, test đầy đủ, license tài nguyên cuối |
