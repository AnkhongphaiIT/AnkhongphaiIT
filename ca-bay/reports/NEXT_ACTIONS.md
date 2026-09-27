# NEXT_ACTIONS (tối đa 5, theo thứ tự)

1. **E2E trình duyệt boss** (`tests/web/scenarios/boss_isl1.json`, tài khoản checkpoint `--seed-stage isl1_boss`): chạy lại sau CR-006 + sửa tầm đánh boss; sau đó nấu cá, hộp quà, đi đảo khác trên trình duyệt.
2. **Hồi quy sau sửa lỗi QA**: chạy lại `content_all` 1 bot và `quest_boss` 4 bot trên code mới; WEB-E2E full_loop + coop2.
3. **Cảm giác chơi**: độ khó cá cuối bến, hình NPC/tay cầm; cân nhắc giảm cày ở đảo 3 (bot mất 180 s chuẩn bị).
4. **Chờ chủ dự án** (không chặn việc khác): NEED-HOST, NEED-ITCH, NEED-CONTACT, NEED-VOICE-LICENSE/voice_v1, relay batch ChatGPT b01/b02, NEED-DEVICES cho buổi playtest 60 phút.
5. Cập nhật `reports/*`, đóng gói lại web/server, commit + push sau mỗi mốc.

## Lệnh tiếp tục đã kiểm chứng

```bash
cd ca-bay
python3 tools/build/install_godot.py                  # nếu container mới chưa có Godot 4.7.2
python3 -m venv .venv && .venv/bin/pip install -r tools/validate/requirements.txt
.venv/bin/python tools/validate/check_docs.py         # errors: 0
(cd server/backend && python3.11 -m venv .venv && .venv/bin/pip install -r requirements.lock.txt && .venv/bin/python -m pytest -q)
python3 tools/build/run_godot_tests.py                # GODOT_TESTS ... failures=0
python3 tools/build/export.py web && python3 tests/web/run_web_e2e.py --scenario full_loop   # cần: npm i -g playwright@1.56.1
xvfb-run -a godot --path . --rendering-driver opengl3 res://art_src/bake/bake.tscn   # bake mô hình/icon
godot --headless --path . --script art_src/anim/build_anim.gd && godot --headless --path . --script art_src/vfx/build_vfx.gd
python3 tools/asset_generation/sync_asset_status.py   # cập nhật registry/source_manifest/ASSET_COVERAGE từ file thật
python3 tools/build/package_web.py && python3 tools/build/package_server.py   # gói phát hành (bản -local khi chưa có endpoint)
python3 tests/integration/run_bots.py --scenario content_all --bots 1 --timeout 2400   # CONTENT-01 bằng bot (≈8 phút)
python3 tests/web/run_web_e2e.py --scenario boss_isl1 --seed-stage isl1_boss          # boss trên trình duyệt với tài khoản checkpoint
```
