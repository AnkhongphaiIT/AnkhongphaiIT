# NEXT_ACTIONS (tối đa 5, theo thứ tự)

1. **Nhận kết quả subagent QA (WP-11a)**: bot `quest_boss`, `content_all` (CONTENT-01 qua 3 đảo), `takeover` (SAVE-02), `restart`, `two_rooms` (NET-02). Đọc diff, chạy lại, sửa lỗi sản phẩm được báo, commit.
2. **E2E trình duyệt phần còn lại**: boss co-op (gọi ở cọc cờ đỏ), nấu cá, hộp quà, đi đảo khác; lớp phủ F3 (FPS/ping/bộ nhớ) cho buổi thử trên máy thật.
3. **Cảm giác chơi**: tinh chỉnh độ khó cá ở cuối bến (tép/cua sổng nhanh), kiểm lại gõ tiếng Việt có dấu trong ô nhập (WEB-01 FAIL), hình NPC/tay cầm.
4. **Chờ chủ dự án** (không chặn việc khác): NEED-HOST, NEED-ITCH, NEED-CONTACT, NEED-VOICE-LICENSE/voice_v1, relay batch ChatGPT b01/b02.
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
xvfb-run -a godot --path . --rendering-driver opengl3 res://art_src/bake/bake.tscn   # bake mô hình/icon
godot --headless --path . --script art_src/anim/build_anim.gd && godot --headless --path . --script art_src/vfx/build_vfx.gd
python3 tools/asset_generation/sync_asset_status.py   # cập nhật registry/source_manifest/ASSET_COVERAGE từ file thật
python3 tools/build/package_web.py && python3 tools/build/package_server.py   # gói phát hành (bản -local khi chưa có endpoint)
```
