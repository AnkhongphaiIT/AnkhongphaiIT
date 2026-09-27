# WP-12 — Kiểm thử mạng xấu, mất mạng dài, boss co-op nâng cao (giao cho Claude subagent)

Tiếp nối WP-11a (bot `quest_boss`, `content_all`, `takeover`, `restart`, `two_rooms` đã PASS). Mục tiêu là các hàng còn thiếu trong `docs/10_VALIDATION.md` §2 mà bot qua **protocol thật** kiểm được.

## Mục tiêu

1. **NET-03 mất mạng 10/60/100 s** (`net_outage`): 2 bot cùng phòng; bot B đang có cá trong túi (và/hoặc cá đã thả xuống đất = escrow) thì ngắt kết nối:
   - 10 s và 60 s (trong `reconnect_grace_s` = 90 s của `network_contract.json`): A thấy B `disconnected`; B vào lại cùng phòng, cùng vị trí/slot; túi/tiền/save_version không đổi; lệnh bền vững gửi lại cùng op_id không nhân đôi; lệnh gửi bằng connection cũ (connection_id/lease_epoch cũ) bị từ chối.
   - 100 s (quá grace): room xóa B; lease được trả; đồ escrow của B về recovery inbox đúng một lần; B vào lại được như người mới (hồi ở bến) mà không mất đồ. Không thưởng AFK, độ no không giảm khi mất kết nối.
2. **NET-05 mạng xấu** (`netem`): viết `tests/integration/netem_proxy.py` — proxy TCP userspace (asyncio) đặt giữa bot và room server WS, thêm độ trễ ~75 ms mỗi chiều (RTT ≈150 ms) + jitter ±30 ms **giữ thứ tự byte trong từng chiều** (không đảo gói trên cùng kết nối TCP), tùy chọn cắt kết nối ngẫu nhiên. (Thử `tc netem` trước; nếu container không có quyền NET_ADMIN thì dùng proxy — ghi rõ đã dùng gì.) Chạy `fish_loop` (2–4 bot) và `quest_boss` 2 bot qua proxy: không crash, không mất giao dịch đã ack, không nhân đôi; ghi thời gian so với mạng thường. Có biến thể cắt kết nối giữa chừng rồi bot tự nối lại.
3. **CONTENT-02 boss co-op nâng cao** (`boss_coop`): (a) người thứ 2 vào phòng **giữa trận**: HP boss giữ nguyên mức đã chốt lúc bắt đầu, người vào muộn có đóng góp sát thương thì được thưởng, vào muộn mà không đánh thì không; (b) một người bị KO/rời phòng giữa trận: trận vẫn tiếp tục, người rời không nhận thưởng, người còn lại thắng nhận đúng một lần; (c) thua (hết giờ hoặc cả nhóm rời bãi): mồi hoàn đúng một lần cho người gọi, gọi lại được (retry) và thắng.
4. **SAVE-03 phần room** (`room_kill_boss`): giết room server (tiến trình do mình tạo) **giữa trận boss** và giữa lúc bán; bật lại. Kiểm: lệnh đã ack còn nguyên; mồi boss của trận mồ côi được hoàn **đúng một lần** bởi vòng dọn của backend (`app.main.maintenance_once`, P-027). Được phép gọi `maintenance_once()` trong tiến trình Python trên cùng DB test sau khi lùi `boss_attempts.created_at` **của DB test** để không phải chờ 15 phút (chỉ trong test, ghi rõ trong báo cáo); không thêm API hay đường tắt vào sản phẩm.
5. Nếu còn thời gian: **NET-04** chủ phòng rời phòng → chủ phòng chuyển cho người còn lại, phòng vẫn chạy; người mở menu không làm dừng người khác.

## File được phép sửa/tạo
- `tests/bots/**`, `tests/integration/**` (trừ `tests/integration/crash_backend.py`), file mới trong đó.
- **Không** sửa `server/**`, `client/**`, `shared/**`, `data/**`, `tools/**`, `reports/**`. Lỗi sản phẩm: ghi vào báo cáo cuối với bước tái hiện + đề xuất diff (không áp dụng).

## Ràng buộc chạy
- Cổng **API 8797 / WS 8920**, proxy dùng **8921** (bot nối `ws://127.0.0.1:8921`). Không đụng 8787/8910/8060/8817/8827/8940 (phiên chính dùng).
- Máy 4 lõi, phiên chính đang chạy trình duyệt kiểm thử: **mỗi lúc chỉ một stack**; không chạy song song nhiều kịch bản.
- Chỉ kill tiến trình do mình tạo (theo PID/nhóm tiến trình mình khởi động). Không commit/push git. Không in biến môi trường/secret.
- Godot: `/opt/godot/4.7.2/godot`; chạy qua `python3 tests/integration/run_bots.py --scenario <tên> --bots N [...]`.
- Test phải đọc kết quả thật từ server (save, tiền, sự kiện, DB test). Không viết test trả PASS cố định; kịch bản chưa xong phải FAIL rõ ràng.

## Tài liệu tham khảo
`docs/10_VALIDATION.md` (NET-03/04/05, CONTENT-02, SAVE-03), `data/contracts/network_contract.json` (grace, limits), `server/gameplay/room_sim.gd` (detach/remove_player_now, escrow, owner), `server/gameplay/boss_sim.gd` (participants, eligibility, refund), `server/backend/app/main.py` (`maintenance_once`), `server/backend/app/persistence/internal_routes.py` (`sweep_stale`, room-status released), `tests/bots/*` và `tests/integration/run_bots.py` (mẫu từ WP-11a), `reports/DECISIONS.md` (P-020…P-028, CR-006).

## Đầu ra
Báo cáo cuối: lệnh chạy, JSON kết quả từng kịch bản (PASS/FAIL + lý do), thời gian, RTT đo được qua proxy, lỗi sản phẩm (tái hiện + đề xuất sửa), danh sách file đã sửa/tạo.
