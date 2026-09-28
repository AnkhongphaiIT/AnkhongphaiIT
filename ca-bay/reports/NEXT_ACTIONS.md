# NEXT_ACTIONS (tối đa 5, theo thứ tự)

0. **Chờ chủ dự án chạy gói Windows mới** (gửi 28/09 10:25, commit 31789c6: 3 phần `.001–.003` + `GHEP_FILE.bat` → giải nén → `CHOI_THU.bat` → **Chơi ngay**) và báo kết quả; room server `.exe` chưa chạy thử được trên Windows thật (Wine 9 không chạy Godot 4.7). Nếu lỗi: xem ảnh cửa sổ đen (đã có lời báo lỗi tiếng Việt), dự phòng `GODOT_EXE`. Khi có link cloudflared: buổi thử 60 phút (`release/PLAYTEST_60MIN.md`) → NET-01, WEB-02, UX thật.
1. **Nếu chủ dự án vẫn muốn bỏ hẳn bảo mật** (vào bằng tên, không khóa): xác nhận rõ rủi ro trước (ai gõ đúng tên là vào tài khoản người khác), đổi docs 07/08, P-041.
2. **Mục MỘT PHẦN trong `reports/VALIDATION_MATRIX.md`**: WEB-01 (thử tay khóa chuột/Esc/toàn màn hình, Firefox), PERF-01 (FPS máy thật) — cần máy thật.
3. **Làm đẹp còn thô**: tay góc nhìn thứ nhất, NPC, icon mảnh (cần carbon, vỉ ruồi).
4. **Chờ chủ dự án** (không chặn việc khác): NEED-HOST (đường một link đã sẵn), NEED-ITCH, NEED-CONTACT, NEED-VOICE-LICENSE/voice_v1, NEED-DEVICES, relay batch ChatGPT b01/b02.
5. Sau mỗi mốc: cập nhật `reports/*` (kể cả `VALIDATION_MATRIX.md`), đóng gói lại, chia phần (`split_parts.py`), commit + push.

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
python3 tools/build/package_web.py && python3 tools/build/package_server.py   # gói web (-local khi chưa có endpoint) + gói máy chủ Linux/Windows (cần `install_godot.py --windows`)
python3 tools/build/split_parts.py release/ca-bay-server-0.1.0-windows.zip --mb 25   # chia gói để gửi qua kênh giới hạn 30 MiB
python3 tools/build/export.py web --selfhost && python3 tests/web/run_web_e2e.py --scenario full_loop --selfhost   # một cổng (P-035)
python3 tests/integration/run_bots.py --scenario net_outage --bots 2 --proxy --delay-ms 0 --jitter-ms 0 --timeout 900   # NET-03 (xem thêm WP-12 trong run_bots.py)
python3 tests/integration/run_bots.py --scenario content_all --bots 1 --timeout 2400   # CONTENT-01 bằng bot (≈8 phút)
python3 tests/integration/crash_backend.py --kills 6                                   # SAVE-03: SIGKILL backend giữa giao dịch
python3 tests/web/run_web_e2e.py --scenario boss_isl1 --seed-stage isl1_boss          # boss trên trình duyệt với tài khoản checkpoint
python3 tests/web/run_web_e2e.py --scenario meta_isl2 --seed-stage isl2_start         # hộp quà, nướng cá, đi đảo 2, nhận việc
python3 tests/web/run_web_e2e.py --scenario save01_cross --seed-stage isl2_start      # SAVE-01 đổi máy khác origin
python3 tests/web/run_web_e2e.py --scenario boss_isl3 --seed-stage isl3_boss          # boss đảo 3 (tương tự boss_isl2 / isl2_boss)
python3 tests/web/run_web_e2e.py --scenario full_loop --iframe                        # chạy trong iframe khác site (giả lập itch.io)
```
