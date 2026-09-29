# NEXT_ACTIONS (tối đa 5, theo thứ tự)

0. **Đang ở máy Windows của chủ dự án** (từ 29/09, Claude Code cục bộ; xem `CLAUDE.md` mục "Khi chạy trên máy Windows"). Đã có: Python 3.12 venv (P-043), Godot 4.7.2 win64 chính thức ở `Downloads` (đặt `GODOT_BIN` tới `_console.exe`), templates đủ, Playwright `build/node` + Edge (P-045). **Gói Windows đã chạy thật** (WIN-PKG-01 + bot 4 người/boss/restart/takeover PASS, `TEST_RESULTS.md` phiên 4). Tiếp: (a) **PERF-01 FPS thật**: chạy trình duyệt có GPU (Iris Xe, không headless) trên máy này, bật `show_perf`; (b) nâng đồ họa để bán: ảnh 2D qua ChatGPT (thử Claude in Chrome, nếu không thì chuyển tay), mô hình 3D CC0 (Kenney/Quaternius, kiểm license) hoặc Blender. Máy thường chỉ còn < 1 GB RAM trống khi mở ChatGPT/Brave/nhiều phiên Claude: chạy tuần tự.
0b. **Chủ dự án chơi tay gói Windows** trên máy này (`release/ca-bay-server-0.1.0-windows.zip` c010cca, hoặc bản đã giải nén ở scratchpad) và báo cảm giác chơi; khi đồng ý mở máy ra Internet: cài `cloudflared` (miễn phí, không cần tài khoản cho quick tunnel) → một link cho bạn bè → buổi thử 60 phút (`release/PLAYTEST_60MIN.md`) → NET-01, WEB-02, UX thật.
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

### Trên máy Windows của chủ dự án (Git Bash; đã kiểm chứng 29/09)

```bash
export GODOT_BIN="C:/Users/PhamDanAn/Downloads/Godot_v4.7.2-stable_win64_console.exe" PYTHONUTF8=1 PYTHONIOENCODING=utf-8
.venv/Scripts/python.exe tools/validate/check_docs.py                        # errors: 0
(cd server/backend && .venv/Scripts/python.exe -m pytest -q)                  # 48 passed
.venv/Scripts/python.exe tools/build/run_godot_tests.py                       # GODOT_TESTS run=32 failures=0
.venv/Scripts/python.exe tools/build/package_server.py --target windows       # gói Windows (≈2 phút)
# giải nén vào thư mục mới → bấm CHOI_THU.bat, rồi:
CHROME_PATH="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" .venv/Scripts/python.exe tests/web/run_web_e2e.py --scenario release_quick --selfhost --external-api http://127.0.0.1:8787
.venv/Scripts/python.exe tests/integration/win_package_check.py --pkg "<thư mục gói>" --scenario restart --bots 1   # cũng: fish_loop 4, quest_boss 4, takeover 2, summon_replay 2
```
