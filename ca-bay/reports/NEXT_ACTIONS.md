# NEXT_ACTIONS (tối đa 5, theo thứ tự)

1. **Hồi quy sau P-025/P-026**: kết quả bot `content_all` + `quest_boss` 2 bot; xuất lại web, chạy `meta_isl2`, `boss_isl1`, `full_loop`, `coop2`; đóng gói lại web/server.
2. **Cảm giác chơi**: độ khó cá cuối bến, hình NPC/tay cầm; icon mảnh (cần carbon, vỉ ruồi) cần làm dày; cân nhắc giảm cày đảo 3.
3. **SAVE-03** (giết backend giữa giao dịch) và kiểm dung lượng/bộ nhớ bản web; F3 hiển thị FPS/bộ nhớ cho buổi thử trên máy thật.
4. **Chờ chủ dự án** (không chặn việc khác): NEED-HOST, NEED-ITCH, NEED-CONTACT, NEED-VOICE-LICENSE/voice_v1, relay batch ChatGPT b01/b02, NEED-DEVICES cho buổi playtest 60 phút.
5. Cập nhật `reports/*`, commit + push sau mỗi mốc.

## Lệnh tiếp tục đã kiểm chứng

```bash
cd ca-bay
python3 tools/build/install_godot.py                  # nếu container mới chưa có Godot 4.7.2
python3 -m venv .venv && .venv/bin/pip install -r tools/validate/requirements.txt
.venv/bin/python tools/validate/check_docs.py         # errors: 0
(cd server/backend && python3.11 -m venv .venv && .venv/bin/pip install -r requirements.lock.txt && .venv/bin/python -m pytest -q)
python3 tools/build/run_godot_tests.py                # GODOT_TESTS ... failures=0
python3 tools/build/export.py web && python3 tests/web/run_web_e2e.py --scenario full_loop   # cần: npm i -g playwright@1.56.1
xvfb-run -a godot --path . --rendering-driver opengl3 res://art_src/bake/bake.tscn   # bake mô hình/icon (thêm `-- --missing-icons` để chỉ bake icon chưa có)
godot --headless --path . --script art_src/anim/build_anim.gd && godot --headless --path . --script art_src/vfx/build_vfx.gd
python3 tools/asset_generation/sync_asset_status.py   # cập nhật registry/source_manifest/ASSET_COVERAGE từ file thật
python3 tools/build/package_web.py && python3 tools/build/package_server.py   # gói phát hành (bản -local khi chưa có endpoint)
python3 tests/integration/run_bots.py --scenario content_all --bots 1 --timeout 2400   # CONTENT-01 bằng bot (≈8 phút)
python3 tests/integration/crash_backend.py --kills 6                                   # SAVE-03: SIGKILL backend giữa giao dịch
python3 tests/web/run_web_e2e.py --scenario boss_isl1 --seed-stage isl1_boss          # boss trên trình duyệt với tài khoản checkpoint
python3 tests/web/run_web_e2e.py --scenario meta_isl2 --seed-stage isl2_start         # hộp quà, nướng cá, đi đảo 2, nhận việc
```
