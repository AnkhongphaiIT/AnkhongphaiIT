# BACKLOG — toàn bộ bản đầy đủ CÁ BAY

Nguồn: `docs/09_AGENT_TASKS.md` (WP-00…WP-12), `docs/10_VALIDATION.md`. Trạng thái hợp lệ: `NOT_STARTED`, `IN_PROGRESS`, `IMPLEMENTED_UNVERIFIED`, `VERIFIED`, `BLOCKED_EXTERNAL`. Trạng thái thật được cập nhật ở `reports/PROJECT_STATUS.md`.

## 1. Quyền sửa file (mỗi file một chủ tại một thời điểm)

| Vùng file | Chủ sửa | Ghi chú |
|---|---|---|
| `data/**` (content, contracts, loc, schemas) | Claude (integration) | Agent khác chỉ đề xuất; đổi hợp đồng qua Claude |
| `project.godot`, `export_presets.cfg`, `client/scripts/core/**`, `shared/protocol/**` | Claude | Nền tảng + giao thức |
| `server/backend/**` | Claude (WP-02) | Có thể giao subagent `backend` theo `tasks/WP-02.md` khi interface đã chốt |
| `server/gameplay/**`, `shared/gameplay/**` | Claude (WP-03/04/08) | Mô phỏng authoritative |
| `client/**`, `ui/**` | Claude (WP-04/09/10) | Trình bày, HUD, menu |
| `shared/content/world/**` | Claude (WP-05/06/07) | Bố cục đảo procedural |
| `tools/asset_generation/**`, `assets/audio/**` | subagent `art-audio` khi được giao | Chỉ ghi vào allowlist trong task file |
| `handoff/requests/**` | Claude | Batch ChatGPT |
| `tests/**` | Claude; subagent `qa` chỉ thêm test trong `tests/` | Không sửa code sản phẩm |
| `tools/build/**`, `release/**` | Claude (WP-12) | Quy tắc release P-011 |
| `reports/**`, `tasks/**` | Claude | — |

## 2. Gói việc

| WP | Mục tiêu | Output kiểm được | Phụ thuộc | Người làm | Trạng thái |
|---|---|---|---|---|---|
| WP-00 | Preflight, cấu trúc, git, lock | `reports/PREFLIGHT.md`, `toolchain.lock.json`, validator 0 lỗi | — | Claude | xem status |
| WP-01 | Foundation Godot: boot, ContentDB, content hash, Loc VI/EN, InputMap, settings local, fallback asset loader, export presets web/server | Headless import pass; web export chạy qua HTTP; bấm vào game khóa chuột + mở âm | WP-00 | Claude | |
| WP-02 | Backend auth/save/lease/op ledger/rooms/tickets/internal API/backup | pytest: AUTH-01…05, SAVE-02…04, LOOT-01 | WP-00 | Claude | |
| WP-03 | Room server Godot headless + client mạng; ticket auth; 1–4 người; reconnect; owner transfer | 4 bot Godot qua WS thật; NET-02/03/04/06 | WP-01, WP-02 | Claude | |
| WP-04 | Gameplay lõi: di chuyển, câu FSM, cá bay, công cụ/KO/trick, nhặt/túi/bán/mua/nâng cấp | CORE-01…03 với 4 bot | WP-03 | Claude | |
| WP-05 | Đảo 1 đầy đủ + boss Lóc Già + quest 01 | Tài khoản mới → mở đảo 2 | WP-04 | Claude | |
| WP-06 | Đảo 2 + boss Cua Cụ + quest 02 | Đi 1→2→mở 3 | WP-05 | Claude | |
| WP-07 | Đảo 3 + boss Bớp Mũi Đá + quest 03 + Sổ Cá | CONTENT-01 tự động qua 3 đảo | WP-06 | Claude | |
| WP-08 | Đói/ăn/nấu, cò rình, hộp quà miễn phí | SURV-01, LOOT-01/02 | WP-02, WP-04 | Claude | |
| WP-09 | Mesh procedural, animation, UI, icon bake, SFX/nhạc/ambience, gibberish, TTS VI/EN, phụ đề | Manifest nguồn/license/hash; nghe/nhìn thật trên web | WP-01 | Claude + subagent `art-audio` | |
| WP-10 | Tích hợp: menu/AFK/modal, lỗi mạng, đồng bộ account, không lộ secret | Không mất đồ khi reconnect/restart | WP-03…09 | Claude | |
| WP-11 | QA ma trận `10` | `reports/TEST_RESULTS.md` có bằng chứng | từng phần | Claude + subagent `qa` | |
| WP-12 | Release ZIP sạch, gói server, runbook, itch page, privacy, credits | ZIP + SHA256 + URL công khai khi có host | WP-11 + NEED-HOST/NEED-ITCH | Claude | |

## 3. Việc thật đã giao cho agent

Chỉ ghi khi đã thực sự gọi agent và nhận kết quả. (Chưa giao việc nào.)
