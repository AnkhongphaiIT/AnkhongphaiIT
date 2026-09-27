# WP-11a — Bot kịch bản nhiệm vụ/boss/lưu (giao cho Claude subagent)

## Mục tiêu
Viết các kịch bản bot headless chạy trên **protocol thật** (WebSocket + backend thật qua `tests/integration/stack.py`) để kiểm:

1. `quest_boss` — 1 bot (và biến thể 2–4 bot): tài khoản mới → nói chuyện Cô Ba (nhận dép) → nói chuyện Ông Tư (nhận `quest_01_bua_trua`) → câu tới khi đủ 3 `cre_ca_ro` → giao → nhận thưởng (mồi trà sữa, tiền, chổi) → nhận `quest_01_trum_song` → tới cọc boss đảo 1 → `boss.summon` → cả nhóm đánh boss tới `boss.defeated` → mỗi người nhận thưởng **đúng một lần** (kiểm save/tiền trước-sau, gửi lại cùng op_id không nhận thêm) → giao `item_golden_scale` → `progress.island_unlocked` isl_02.
2. `content_all` (CONTENT-01) — tiếp tục đảo 2 và đảo 3 tới hết 3 boss (có thể chạy lâu; ghi thời gian từng chặng). Nếu quá lâu, cho phép tham số `--from-island=` nhưng **không** được sửa save trực tiếp trong DB hay thêm API gian lận.
3. `takeover` (SAVE-02) — cùng tài khoản đăng nhập ở client thứ hai, `POST /v1/account/takeover`, client cũ nhận `session.closed` reason takeover; lệnh bền vững đang chờ không nhân đôi.
4. `restart` — dừng room server giữa chừng (đang có cá trong túi và boss chưa gọi), khởi động lại, bot vào lại: tiền/túi đã commit còn nguyên, không mất/nhân đôi.
5. `two_rooms` (NET-02) — 2 phòng song song, 2 bot mỗi phòng, cùng đảo cùng tọa độ: không thấy thực thể/sự kiện của phòng kia.

## File được phép sửa/tạo
- `tests/bots/**` (bot.gd, bot_runner.gd, file mới)
- `tests/integration/**` (thêm hàm/tham số cho `stack.py`, script chạy mới)
- **Không** sửa `server/**`, `client/**`, `shared/**`, `data/**`. Nếu phát hiện lỗi sản phẩm: ghi vào báo cáo cuối với bước tái hiện + đề xuất diff (không áp dụng).

## Ràng buộc chạy
- Dùng cổng **API 8797 / WS 8920** (`Stack(api_port=8797, ws_port=8920)`; bot `--api=http://127.0.0.1:8797 --ws=ws://127.0.0.1:8920`) để không đụng phiên khác đang dùng 8787/8910/8060.
- Không kill tiến trình không do mình tạo (dùng PID mình khởi động).
- Không commit/push git. Không in biến môi trường/secret.
- Godot: `/opt/godot/4.7.2/godot`; chạy bot: `godot --headless --path . res://tests/bots/bot_runner.tscn -- --scenario=<tên> --bots=N --api=... --ws=...`; kết quả JSON có `ok`, `checks`.
- Test phải kiểm hành vi thật (đọc save/tiền/sự kiện từ server). Không viết test trả PASS cố định. Scenario chưa xong phải FAIL rõ ràng.

## Tài liệu tham khảo
`data/contracts/network_contract.json`, `data/contracts/events.json`, `data/content/quests.json`, `bosses.json`, `npcs.json`, `shared/gameplay/island_layout.gd` (tọa độ NPC/cọc boss/vùng câu), `server/gameplay/room_sim.gd` (luồng `npc.interact`, lệnh bền vững), `server/gameplay/boss_sim.gd`, `tests/bots/bot.gd` + `bot_runner.gd` (kịch bản `fish_loop` đã PASS làm mẫu), `docs/10_VALIDATION.md`.

## Đầu ra
- Các kịch bản trên chạy được; báo cáo cuối: lệnh chạy, JSON kết quả từng kịch bản (PASS/FAIL + lý do), thời gian chạy, lỗi sản phẩm phát hiện (tái hiện + đề xuất sửa).
