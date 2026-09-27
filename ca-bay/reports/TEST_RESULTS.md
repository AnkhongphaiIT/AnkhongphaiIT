# TEST_RESULTS

Mỗi dòng: ID · build/commit · thời điểm · môi trường · kết quả · bằng chứng. Trạng thái: `PASS`, `FAIL`, `NOT_RUN`, `BLOCKED_EXTERNAL`. Test trên mock/bot không được ghi PASS cho mục yêu cầu người thật hoặc môi trường công khai.

Môi trường chung: container Ubuntu đám mây, Python 3.11.15, Godot 4.7.2.stable ed1daf0bf headless, Chromium 141 headless (SwiftShader WebGL2), backend + room server chạy local (`tests/integration/stack.py`).

| ID | Build | Thời điểm (UTC) | Kết quả | Bằng chứng / ghi chú |
|---|---|---|---|---|
| DATA-01 (validator gói) | phiên 1 chiều | 2026-09-27 16:10 | PASS | `tools/validate/check_docs.py` → 0 lỗi/0 cảnh báo, 25 JSON, 362 khóa loc, 86 sự kiện |
| DATA-02 (khóa dịch dùng trong code) | phiên 1 chiều | 16:05 | PASS | `tests/godot/test_ui.gd`: mọi khóa `ui.*`/`tutorial.*` trong client + khóa động (emote, ping, nấu, tên vùng) có bản dịch |
| AUTH/SAVE backend | phiên 1 chiều | 16:08 | PASS (26/26) | `server/backend` pytest: đăng ký/đăng nhập/khóa thử sai/refresh xoay vòng + phát hiện dùng lại/khôi phục/đổi mật khẩu/xóa cần reauth, ticket dùng 1 lần, op ledger idempotent + OP_PAYLOAD_MISMATCH, lease/epoch, backup/restore |
| Godot unit | phiên 1 chiều | 16:08 | PASS (18/18) | `tools/build/run_godot_tests.py`: biên dịch toàn bộ script, bố cục 3 đảo, cá rơi đất an toàn, dép KO tép + trick, trần hệ số trick, HP boss theo số người, hoàn mồi đúng 1 lần, đói chỉ giảm khi hoạt động, AFK, 2 room cùng tọa độ cách ly, chuyển chủ phòng, bù trễ đòn đánh có giới hạn, HUD phủ kín màn hình |
| NET bot connect4 | commit 765322d | 15:00 | PASS | 4 bot Godot, 4 tài khoản, WebSocket thật + backend thật: thấy nhau trong snapshot |
| NET bot negative | commit 765322d | 15:00 | PASS | trường thừa, uuid sai, seq cũ, gửi tiền từ client, sai room, nhặt/bán giả mạo → bị từ chối |
| NET bot reconnect | commit 765322d | 15:00 | PASS | ngắt rồi vào lại giữ slot; người khác thấy lại |
| CORE bot fish_loop ×4 | commit 765322d | 15:00 | PASS | 4 bot đồng thời: câu, cá bay, KO, nhặt, bán; tiền tăng đúng theo server |
| BUILD-01 export web | phiên 1 chiều | 16:12 | PASS | `tools/build/export.py web --release`: 46,13 MB (wasm 39,51 MB, pck ≈6,4 MB); quét .pck không có `res://server/`, `res://tests/`, `CABAY_SERVICE_KEY`, thoại tạm |
| WEB-E2E fish_loop | phiên 1 chiều | 16:06 | PASS | `tests/web/run_web_e2e.py`: Chromium thật mở bản web → đăng ký qua UI → sảnh → tạo phòng đảo 1 → WS vào phòng → đi ra cuối bến → quăng → cá cắn → giật + kéo → cá bay lên bờ → tự đổi sang tay → đập xỉu (trick) → nhặt vào túi; server xác nhận (`dex.new_species`, `item.picked_up`). Ảnh chụp ở `tests/web/artifacts/fish_loop/` (không commit). Chạy ở chế độ `?autotest=1` (không pointer lock, xoay nhìn bằng phím) |
| WEB-01 pointer lock/Esc/fullscreen | — | — | NOT_RUN (tự động) | Pointer lock trong Chromium headless sinh chuyển động chuột giả → không kiểm tự động được; cần thử tay trên máy thật |
| WEB-01 gõ tiếng Việt có dấu | — | 16:00 | FAIL (chưa rõ nguyên nhân) | `keyboard.type("Bạn Web")` của Playwright (insertText) làm rơi "ạ" trong LineEdit → tên hiển thị "Bn Web". Chưa kiểm với bộ gõ thật (Unikey/Telex, macOS). Cần thử tay |
| AUDIO-01 file âm thanh | subagent WP-09 | 15:55 | PASS (đo bằng máy) | `tools/asset_generation/audio/validate_audio.py`: 80/80 asset id, 166 file, 0 lỗi; loop có chunk smpl; nhạc −18 LUFS. **Chưa có người nghe duyệt** |
| Godot unit (cập nhật) | phiên 1 tối | 18:05 | PASS (22/22) | thêm test giao thức (số nguyên chuẩn hóa, kiểu hợp object/null), HUD phủ màn hình, khóa dịch động |
| WEB-E2E full_loop | phiên 1 tối | 17:05 | PASS | + đi tới sạp Cô Ba → **bán cả túi** (economy.item_sold) → lấy cơm nắm miễn phí (shop.buy). Phát hiện + sửa lỗi thật: shop.buy bị từ chối vì số nguyên thành 1.0 khi chuyển tiếp (Protocol.normalize_integers) |
| WEB-E2E npc_shop | phiên 1 tối | 16:55 | PASS | quà dép Cô Ba, menu sạp, hội thoại + nhiệm vụ Ông Tư, Sổ Cá, menu tạm dừng |
| WEB-E2E coop2 (2 trình duyệt) | phiên 1 tối | 17:40 | PASS | 2 context Chromium, 2 tài khoản: B nhập mã phòng của A, cả hai thấy n=2, B nhận sự kiện câu cá của A (CABAY_OTHER). Ảnh `release/screenshots/p12_coop.png` |
| WEB-E2E trên gói server phát hành | phiên 1 tối | 16:52 | PASS | giải nén `ca-bay-server-0.1.0.zip`, chạy `run/start_backend.sh` + `run/start_room.sh` (room server đã xuất, scrypt production), trình duyệt chơi full_loop; `run/backup.sh` → verify → restore OK |
| BUILD-02 quét bí mật gói web | phiên 1 tối | 17:10 | PASS | `package_web.py`: không .env/.db/.py/.gd, không khóa dịch vụ, không khối PEM có dữ liệu; `index.html` ở gốc ZIP |
| ASSET sync | phiên 1 tối | 18:00 | PASS (đo máy) | `sync_asset_status.py`: 353 file thật đã băm; 0 planned; ngân sách tam giác mô hình đạt (boss ≤3000, vật phẩm ≤300) |
| SAVE-02/03 (takeover, crash) | — | — | NOT_RUN | Chưa có kịch bản |
| NET-02 hai room song song trên server thật | — | — | NOT_RUN | Có unit test cách ly dữ liệu; chưa chạy 2 room qua mạng |
| NET server restart | — | — | NOT_RUN | |
| CONTENT-01 playthrough 3 đảo | — | — | NOT_RUN | Bot `quest_boss` còn cố ý FAIL "chưa viết kịch bản" |
| NET-01 bốn người thật | — | — | BLOCKED_EXTERNAL | NEED-HOST, NEED-DEVICES |
| PERF (FPS/bộ nhớ trên máy thật) | — | — | NOT_RUN | SwiftShader không đại diện cho GPU thật |
