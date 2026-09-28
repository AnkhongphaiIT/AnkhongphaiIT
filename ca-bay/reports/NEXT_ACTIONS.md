# NEXT_ACTIONS (tối đa 5, theo thứ tự)

0. **Chờ chủ dự án chạy gói Windows** (`ca-bay-server-0.1.0-windows.zip` → `CHOI_THU.bat`, hoặc 3 phần `.001–.003` + `GHEP_FILE.bat`) và báo kết quả: room server `.exe` chưa chạy thử được trên Windows thật (Wine 9 không chạy Godot 4.7). Nếu lỗi: dự phòng `GODOT_EXE` trong runbook. Khi có link cloudflared: buổi thử 60 phút (`release/PLAYTEST_60MIN.md`) → NET-01, WEB-02, UX thật.
1. **Hoàn tất WP-12**: chạy xong bộ bot hồi quy sau P-039/P-040, bổ sung NET-06/AUTH-02 vào bot `negative` (NaN/vô cực, gói quá lớn, lệch content/protocol, socket không xác thực 5 s), E2E tab ẩn 20 s (`tab_hidden_long`), đo độ trễ thêm của cổng chuyển tiếp `/ws`, commit, đóng gói lại, gửi lại gói Windows nếu có sửa ở room server.
2. **Mục MỘT PHẦN trong `reports/VALIDATION_MATRIX.md`**: WEB-01 (thử tay khóa chuột/Esc/toàn màn hình khi có máy thật; Firefox), PERF-01 (FPS máy thật).
3. **Làm đẹp còn thô**: tay góc nhìn thứ nhất, NPC, icon mảnh (cần carbon, vỉ ruồi).
4. **Chờ chủ dự án** (không chặn việc khác): NEED-HOST (đã có đường một link), NEED-ITCH, NEED-CONTACT, NEED-VOICE-LICENSE/voice_v1, NEED-DEVICES (buổi thử có máy Firefox), relay batch ChatGPT b01/b02.
5. Sau mỗi mốc: cập nhật `reports/*` (kể cả `VALIDATION_MATRIX.md`), đóng gói lại web/server, commit + push.

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
