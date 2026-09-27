# NEXT_ACTIONS (tối đa 5, theo thứ tự)

1. **M2 E2E trình duyệt còn lại** — thêm kịch bản `tests/web/scenarios/` cho: nói chuyện Cô Ba (quà dép) → Ông Tư (nhận việc) → bán túi ở sạp → mua đồ → ăn/nấu → mở hộp quà → Sổ Cá → cài đặt/đổi ngôn ngữ → rời phòng/vào lại. Sửa lỗi phát sinh.
2. **Bot `quest_boss` + CONTENT-01** — viết kịch bản bot đi hết nhiệm vụ đảo 1 → gọi boss co-op 2–4 bot → thưởng đúng một lần → mở đảo 2 → … đảo 3; thêm SAVE-02 (tiếp quản thiết bị), server restart, NET-02 hai room.
3. **Chất lượng hình/cảm giác** — tay/cần góc nhìn thứ nhất, hoạt ảnh NPC/người chơi, VFX (bọt nước, sao xỉu), icon; kiểm lại gõ tiếng Việt trong LineEdit (WEB-01 FAIL); rút gọn thoại/âm (OGG) nếu cần.
4. **Phát hành (phần không bị chặn)** — `tools/build/package_web.py` theo P-011 (chỉ chép file release sang thư mục mới rồi nén), README chạy local, CHANGELOG, credits/giấy phép, trang quyền riêng tư nháp, `release/ITCH_PAGE.md` VI/EN với ảnh chụp thật, runbook server trên máy Windows + đường hầm (`server/ops/public/README.md`), kịch bản playtest 60 phút.
5. **Batch ChatGPT** — `handoff/requests/<batch>/request.md` (concept đảo/NPC, ảnh bìa itch, UI icon) theo `docs/14_AI_ASSET_HANDOFF.md`.

## Lệnh tiếp tục đã kiểm chứng

```bash
cd ca-bay
python3 tools/build/install_godot.py                  # nếu container mới chưa có Godot 4.7.2
python3 -m venv .venv && .venv/bin/pip install -r tools/validate/requirements.txt
.venv/bin/python tools/validate/check_docs.py         # phải ra errors: 0
(cd server/backend && python3.11 -m venv .venv && .venv/bin/pip install -r requirements.lock.txt && .venv/bin/python -m pytest -q)
python3 tools/build/run_godot_tests.py                # GODOT_TESTS ... failures=0
python3 tools/build/export.py web                     # bản web localhost vào build/web
python3 tests/web/run_web_e2e.py                      # E2E Chromium (cần playwright toàn cục: npm i -g playwright@1.56.1)
python3 tests/integration/stack.py --serve            # chạy backend + room server để chơi thử: mở http://127.0.0.1:8060
python3 -m http.server 8060 --directory build/web     # (cửa sổ khác) phục vụ bản web
```

Âm thanh tái tạo: xem `tools/asset_generation/audio/README.md` (cần `apt-get install ffmpeg espeak-ng`).
