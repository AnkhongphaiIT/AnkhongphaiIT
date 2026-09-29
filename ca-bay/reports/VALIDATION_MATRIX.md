# Ma trận nghiệm thu — đối chiếu `docs/10_VALIDATION.md` §2

Mỗi mã kiểm của tài liệu 10 → bằng chứng đã chạy (lệnh/test cụ thể, chi tiết ở `reports/TEST_RESULTS.md`) → trạng thái thật.
Trạng thái: **PASS** (đã chạy, đạt) · **PASS\*** (đạt trong container/bot/trình duyệt headless, chưa có người thật/thiết bị thật) ·
**MỘT PHẦN** (đạt một số ý, còn ý chưa kiểm) · **BLOCKED** (cần chủ dự án — xem `reports/NEEDS_USER.md`).
Cập nhật: 28/09/2026 (phiên 3).

| Mã | Nội dung | Trạng thái | Bằng chứng | Còn thiếu |
|---|---|---|---|---|
| DATA-01 | Schema, CSV VI/EN, ID, tham chiếu | PASS | `tools/validate/check_docs.py` 0 lỗi (25 JSON, 393 khóa dịch, 296 tài nguyên) | — |
| DATA-02 | Số nội dung, đồ thị mở khóa, tỉ lệ | PASS | cùng validator: 3 đảo / 3 boss / 15 loài; tỉ lệ hộp quà cộng đúng 1 | — |
| BUILD-01 | Toolchain ghim, import/export | PASS | `toolchain.lock.json`, `install_godot.py` (layer Docker ghim digest), `export.py` web/server/server-win | — |
| BUILD-02 | Quét bí mật bản client | PASS | `package_web.py`/`export.py` quét .pck (không mã server/test/khóa; không cờ autotest/đổi máy chủ ở bản công khai — P-028, P-034) | — |
| WEB-01 | Trình duyệt | MỘT PHẦN | Chromium: E2E đầy đủ vòng chơi, đổi cỡ cửa sổ, tab ẩn, iframe khác site, gõ tiếng Việt, đổi phím | Firefox (BLOCKED: tải bị chặn), khóa chuột/Esc/toàn màn hình cần thử tay |
| WEB-02 | Trong iframe itch.io | PASS\* | `run_web_e2e.py --iframe` (trang cha khác site, CORS, không cookie bên thứ ba) | itch.io thật (BLOCKED: NEED-ITCH, NEED-HOST) |
| AUTH-01 | Đăng ký/đăng nhập | PASS | pytest `test_register_login_and_hash_not_plaintext`, `test_duplicate_username_and_bad_inputs`, `test_login_generic_error_does_not_leak`, `test_password_rule_shown_to_player_matches_server`; "Chơi ngay" (P-041): `test_guest_play_now_server_save_and_upgrade` (khóa khách băm, không lưu bản rõ); E2E `quick_play`, `guest_upgrade`, `two_players_one_pc`; giới hạn body 8/64 KB | — |
| AUTH-02 | Token, vé, hết giờ xác thực socket | PASS | pytest `test_tokens_refresh_rotation_reuse_logout`, `test_expired_access_token`, `test_ticket_single_use_ttl_and_room_limits`; bot `negative`: socket mở mà không xác thực bị ngắt sau 5,04 s | — |
| AUTH-03 | Khôi phục | PASS | pytest `test_recovery_one_time_and_revokes_sessions`, `test_recovery_without_code_fails`, `test_save_view_has_no_secrets` | — |
| AUTH-04 | Chống lạm dụng | PASS | giới hạn sai theo tài khoản/IP (`test_rate_limit_account`, `test_rate_limit_ip_behind_proxy_not_spoofable` — P-036), tối đa 2 phép băm scrypt song song (`test_password_hashing_limited_to_two_concurrent_jobs`), origin lạ bị chặn (`test_unknown_origin_blocked_by_cors`), tối đa 30 tài khoản khách/IP/giờ (`test_guest_creation_limited_per_ip`), giới hạn body 8/64 KB, API nội bộ cần khóa (`test_internal_api_requires_service_key`), backend/room chỉ nghe 127.0.0.1 | — |
| AUTH-05 | Xóa tài khoản | PASS | pytest `test_delete_account_requires_recent_auth_and_only_self`; chính sách bản sao lưu ghi ở runbook §7 | — |
| NET-01 | 4 người thật, ≥2 máy | BLOCKED | công cụ sẵn: gói Windows `CHOI_THU.bat` + đường hầm = một link (P-035/P-038), **gói Windows đã chạy thật trên Windows 29/09** (room `.exe`, bot 4 người/boss/restart/takeover qua gói PASS, P-045); bot 4 người qua mạng thật PASS | NEED-HOST, NEED-DEVICES |
| NET-02 | Cách ly phòng | PASS | bot `two_rooms`; Godot `test_rooms_isolated_same_coordinates` | — |
| NET-03 | Mất mạng 10/60/100 s | PASS | bot `net_outage` 44/44, `net_halfopen` (sau sửa P-040) | — |
| NET-04 | Chủ phòng rời/AFK/menu | PASS | bot `owner_leave`; Godot `test_room_owner_transfer_and_capacity`, `test_afk_after_timeout` | — |
| NET-05 | Mạng xấu | PASS | proxy `netem_proxy.py` (RTT ≈155 ms ± jitter, 0 đảo thứ tự, hàng đợi giới hạn): `fish_loop` 4 bot, `quest_boss` (+ cắt kết nối), `fish_net` cắt ngẫu nhiên | — |
| NET-06 | Lệch phiên bản / gói bẩn | PASS | bot `negative`: trường thừa, UUID sai, seq cũ, tiền giả, sai phòng, NaN/vô cực, gói > 8 KB, lệch content_hash (`CONTENT_MISMATCH`) và protocol (`PROTOCOL_MISMATCH`); client hiện "Cần phiên bản game mới"; Godot `test_protocol.gd` | — |
| CORE-01 | Vòng câu đầy đủ | PASS | E2E `full_loop`; bot `fish_loop` 4 dây độc lập | — |
| CORE-02 | Sở hữu, không nhân đôi | PASS | pytest `test_bag_full_and_concurrent_pickup_same_uid`, `test_pickup_sell_idempotent_and_conflicts`; bot `room_kill_boss` (bán/thả lúc sập), `net_outage` (thả rồi mất mạng) | — |
| CORE-03 | Chống giả lệnh | PASS | pytest `test_forged_values_rejected`; bot `negative`, `kick_cleanup` (spam); Godot `test_melee_lag_compensation_bounded`; di chuyển do server tính từ input | — |
| CONTENT-01 | Tài khoản sạch hết game | PASS\* | bot `content_all` qua mạng thật: 3 đảo, 3 boss, 15/15 loài | người thật chơi hết (buổi thử 60 phút) |
| CONTENT-02 | Boss co-op | PASS | bot `boss_coop` 4 người: HP chốt, vào giữa trận, rời/KO, thua → hoàn mồi 1 lần, đánh lại thắng, thưởng đúng người đúng một lần; Godot `test_boss_hp_scales_with_party`, `test_boss_timeout_refunds_once` | — |
| SURV-01 | Đói/ăn | PASS | Godot `test_hunger_active_only`, `test_afk_after_timeout`; bot `net_outage`/`owner_leave` (không trừ khi offline/menu/AFK); pytest thức ăn, nướng (`test_cooking_never_blocks_after_lost_client_state`); không có đường trừ theo giờ thực nên offline 24 h không bị trừ bù | — |
| LOOT-01 | Thưởng chính xác | PASS | pytest `test_lootbox_exact_mapping_atomic_and_idempotent`, `test_lootbox_ticket_milestones_from_sales`; UI hiện đúng tỉ lệ server (`test_percent_text_and_no_unsupported_format`) | — |
| LOOT-02 | Chỉ miễn phí | PASS | không có luồng thanh toán/quảng cáo/giao dịch; vé hộp quà chỉ kiếm từ bán cá | — |
| SAVE-01 | Đổi máy | PASS | E2E `save01_cross` (origin khác, bộ nhớ trình duyệt trống) | — |
| SAVE-02 | Hai phiên cùng tài khoản | PASS | bot `takeover`; pytest `test_takeover_fences_old_epoch` | — |
| SAVE-03 | Sập giữa giao dịch | PASS | `crash_backend.py --kills 6`; bot `room_kill_boss` (sau sửa P-039); E2E `room_crash` | — |
| SAVE-04 | Sao lưu/khôi phục | PASS | pytest `test_backup_while_writing_and_restore`; chạy `backup.sh` + restore trên gói máy chủ | — |
| AV-01 | Âm thanh/giọng/hình thật | BLOCKED | 65 SFX, 4 nhạc, 3 âm nền, giọng "ú ớ" + phụ đề VI/EN có trong bản web | lời thoại có giọng: bản espeak-ng bị loại khỏi bản phát hành (NEED-VOICE-LICENSE) |
| UX-01 | Dễ chơi | PASS\* | E2E: hướng dẫn, HUD, đổi phím, độ nhạy, âm lượng riêng, phụ đề, đổi ngôn ngữ giữa trận, báo máy chủ ngoại tuyến | cảm nhận người thật (buổi thử) |
| PERF-01 | Máy 8 GB | MỘT PHẦN | bộ nhớ wasm 79,8 MB/JS < 80 MB, tải 44 MB, bộ nhớ server (trong ngân sách); **FPS máy thật 29/09** (i5-1135G7 + Iris Xe, 8 GB, Edge GPU 1280×720) sau P-047: sảnh 60, **trong đảo 59,2–59,8 FPS, khung p95 16,9 ms, CPU ≈3 ms/khung** (trước vá: 45–56 FPS) | 10 phút mỗi đảo + boss 4 người trên máy thật; Firefox |
| REL-01 | Phát hành công khai | BLOCKED | gói web/server, runbook, CHANGELOG, CREDITS, PRIVACY nháp, trang itch nháp | NEED-HOST, NEED-ITCH, NEED-CONTACT |

**Kết luận:** chưa đủ điều kiện phát hành công khai (REL-01, NET-01, AV-01 bị chặn bởi việc chỉ chủ dự án làm được). Mọi mục kiểm được trong container đã chạy; các mục MỘT PHẦN còn lại (WEB-01, PERF-01) cần máy/thiết bị thật.
