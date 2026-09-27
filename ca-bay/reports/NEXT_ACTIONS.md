# NEXT_ACTIONS (tối đa 5, theo thứ tự)

1. **Nhận kết quả agent QA WP-12** (mất mạng 10/60/100 s, mạng xấu qua proxy, boss co-op nâng cao, giết room giữa trận boss): đọc diff `tests/bots/**`, `tests/integration/**`, chạy lại, sửa lỗi sản phẩm được báo, commit.
2. **Làm đẹp còn thô**: tay góc nhìn thứ nhất, NPC, icon mảnh (cần carbon, vỉ ruồi); nhãn 3D tên boss trùng thanh máu HUD khi boss vừa tới.
3. **PERF-01 phần làm được**: ghi bộ nhớ JS/wasm và thời gian tải trong Chromium; chuẩn bị bảng đo cho máy thật (F3/"Hiện FPS" trong Tùy chọn).
4. **Chờ chủ dự án** (không chặn việc khác): NEED-HOST, NEED-ITCH, NEED-CONTACT, NEED-VOICE-LICENSE/voice_v1, NEED-DEVICES (buổi thử 60 phút có máy Firefox), relay batch ChatGPT b01/b02.
5. Sau mỗi mốc: cập nhật `reports/*`, đóng gói lại web/server, commit + push.

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
python3 tests/web/run_web_e2e.py --scenario save01_cross --seed-stage isl2_start      # SAVE-01 đổi máy khác origin
python3 tests/web/run_web_e2e.py --scenario boss_isl3 --seed-stage isl3_boss          # boss đảo 3 (tương tự boss_isl2 / isl2_boss)
python3 tests/web/run_web_e2e.py --scenario full_loop --iframe                        # chạy trong iframe khác site (giả lập itch.io)
```
