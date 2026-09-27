# 10 — Kiểm chứng và nghiệm thu v2

Tình trạng ban đầu của gói tài liệu: chưa có game executable, chưa chạy test Godot/game/network, chưa có tài nguyên hoàn thiện. Kiểm tra JSON/tài liệu chỉ chứng minh độ nhất quán của gói. Sau này Claude phải ghi rõ `PASS`, `FAIL`, `NOT_RUN`, `BLOCKED_EXTERNAL`; không dùng `PASS` cho test chỉ được mô tả hoặc chạy trên mock.

## 1. Điều kiện bàn giao đầy đủ

- Web PC dùng chuột/phím và Godot 3D góc nhìn thứ nhất; chơi 1–4 người trong cùng room thực.
- Đủ ba đảo đi được, ba boss có hành vi và phần thưởng, 15 loài thường có catch/collection; cân bằng/hướng dẫn làm người chơi mới đi hết vòng chính được.
- Đói/food/cooking và hộp thưởng kiếm bằng gameplay; miễn phí toàn bộ bản đầu, không SDK thanh toán/quảng cáo hoạt động.
- VI/EN cho UI/nội dung/subtitle và thoại đọc đã yêu cầu; nhạc/SFX/nhân vật ú ớ hiện diện, không lỗi autoplay hoặc âm trùng sau reconnect.
- Tài khoản trên server, lưu bền vững, đồng bộ máy khác, recovery, bảo vệ dữ liệu và backup/restore thật.
- Web export thật, gói server, bằng chứng test, và public itch.io khi có hạ tầng. Domain `.io` chỉ khi người dùng đã có và không phát sinh phí; thiếu domain không ngăn itch.io.

## 2. Ma trận test bắt buộc

| ID | Bài kiểm tra | Điều kiện đạt / bằng chứng |
|---|---|---|
| DATA-01 | JSON Schema, CSV VI/EN, IDs, refs, input/events/assets | Tất cả file parse, refs tồn tại, key không trùng, không thiếu bản dịch runtime; asset planned không bị ghi thành produced |
| DATA-02 | Số nội dung, unlock graph, odds | Đúng 3 đảo/3 boss/15 cá thường; không vòng khóa vô nghiệm; odds mỗi bảng cộng đúng 1; duplicate map và vé kiếm được có test |
| BUILD-01 | Toolchain pin/import/export | Ghi engine thật + templates đúng version; import exit 0, Web ZIP có index.html root, headless export chạy; hash artifacts |
| BUILD-02 | Client export secret scan | Không `.env`, private service key, DB, token/password/recovery, server-only config có bí mật trong web ZIP/PCK/log |
| WEB-01 | Browser smoke | Web export được serve qua HTTP(S), chạy Chrome/Edge và Firefox đã ghi version; pointer lock bằng click, Esc, fullscreen, resize, tab focus |
| WEB-02 | itch.io iframe | Chạy đúng public/test build trong iframe, HTTPS API/WSS, CORS origin thực, không mixed content; không dựa third-party cookies để đăng nhập |
| AUTH-01 | Register/login | Password đúng/sai, username normalized duplicate, SQL/injection/overlong body, generic error không lộ tài khoản, hash không plaintext |
| AUTH-02 | Tokens | Expired/revoked token bị chặn; refresh rotation/reuse, logout; ticket một lần/30s/đúng room; hết 5s auth socket bị ngắt |
| AUTH-03 | Recovery | Code một lần đổi password, mọi session cũ bị thu hồi, dùng lại code fail; recovery không code không được qua; mã không lọt log/save |
| AUTH-04 | Abuse | Rate limit account/IP, giới hạn hash worker và body, unknown origin bị từ chối, API private không ra Internet |
| AUTH-05 | Xóa tài khoản | Mật khẩu/xác thực gần đây bắt buộc, xóa đúng chủ, revoke mọi session/ticket/lease, không cho xóa tài khoản khác; kiểm chứng chính sách backup được công bố |
| NET-01 | Room thật bốn người | Bốn tài khoản độc lập, tối thiểu hai thiết bị vật lý, xuất web thực; cả bốn thấy nhau và câu/đánh/nhặt đồng thời; người thứ năm không vào |
| NET-02 | Room isolation | Hai room có World3D/physics space riêng; đặt entities cùng tọa độ vẫn không hit/collision/raycast chéo. Không rò snapshot/ping/item; guessed room/peer/account ID fail |
| NET-03 | Mất mạng/reconnect | Cắt mạng 10/60/100s; trong grace resync đúng, hết grace về bến; không replay input/nhân vật/thưởng; connection cũ không ghi được |
| NET-04 | Chủ phòng rời/AFK/menu | Server vẫn chạy, owner chuyển đúng; mở menu không dừng người khác; AFK/mất mạng dừng hao đói theo luật, không nhận thưởng AFK |
| NET-05 | Mạng xấu | RTT 150ms+jitter 30ms và disconnect mô phỏng, TCP queue giới hạn, không crash/mất giao dịch đã ack; test network shaping tách khỏi mock |
| NET-06 | Protocol mismatch | Build/content/protocol khác bị từ chối với thông báo VI/EN; payload sai type/field/range, NaN, packet quá lớn, spam seq đều bị chặn |
| CORE-01 | Vòng câu đầy đủ | Quăng/chờ/cắn/kéo/cá bay/đánh xỉu/nhặt/bán/nâng cấp có state cleanup, bốn dây độc lập, phản hồi có âm/hình |
| CORE-02 | Quyền sở hữu và nhân đôi | Hai player nhặt/bán cùng UID cùng lúc; duy nhất một người thành công. Bán rồi retry, drop rồi disconnect/crash, pickup sau restart đều không nhân đôi |
| CORE-03 | Chống giả lệnh | Client tự gửi damage/money/reward, hit ngoài tầm, teleport, vô hạn lực/rapid cooldown bị từ chối; không tin event client |
| CONTENT-01 | Account sạch toàn game | Chơi/automation qua ba đảo, bắt đủ 15 loài thường và hạ ba boss; mỗi khu có thực chất gameplay; không thay bài test bằng liệt kê data records |
| CONTENT-02 | Boss coop | 1/2/4 player, join giữa trận, chết/rời, fail/retry, scale chốt, eligibility; reward mỗi encounter đúng một lần/tài khoản |
| SURV-01 | Hunger | Active tick đúng rates, clamp, food/cook đúng, đói không softlock, pause/AFK/reconnect/offline 24h không catch-up drain |
| LOOT-01 | Exact rewards | Boundary RNG test mỗi interval + duplicate; v1 không pity; debit+grant+receipt atomic; retry cùng op cùng kết quả, đổi op payload fail, xác suất UI = version server |
| LOOT-02 | Free-only | Không nút mua lượt bằng tiền thật, không quảng cáo đổi roll, không cash-out/trade; có thể kiếm mọi phần thưởng theo thiết kế mà không thanh toán |
| SAVE-01 | Cross-device | A bán/nâng cấp/ăn/mở hộp rồi logout; B đăng nhập từ origin khác nhận version/tiền/items/progress đúng; local storage bị xóa vẫn lấy save server |
| SAVE-02 | Concurrent sessions | A và B cùng account, B takeover thu hồi A; pending command epoch cũ thất bại; stale version và duplicate op tests |
| SAVE-03 | Crash consistency | Kill backend trước/sau commit, kill room trong lúc bán/roll/boss/drop; giao dịch đã ack còn nguyên, chưa ack hỏi lại receipt; không thưởng lặp |
| SAVE-04 | Backup/migrate/restore | Backup DB đang dùng bằng API an toàn, restore vào vị trí khác, integrity/foreign keys/ref checks, account login/save đúng; fixture v1 không thành đường nhập tiền public |
| AV-01 | Audio/VO/art thật | Các loại audio yêu cầu nghe được trong web, subtitle khớp VI/EN; không asset mất/license thiếu; không dựa runtime synth không hỗ trợ |
| UX-01 | Dễ chơi | Tutorial, readable HUD, keybind, mouse sensitivity, volume riêng, subtitles, chuyển ngôn ngữ không reset save, nhắc server offline rõ ràng |
| PERF-01 | Máy 8 GB | Ghi CPU/GPU/RAM/browser/resolution; 10 phút mỗi đảo + boss 4P, frame time P50/P95, memory/peak/download; so sánh budget trong 07, báo rõ sai lệch |
| REL-01 | Public launch | URL itch.io public, anonymous page load, signup/login WSS trên mạng ngoài, bốn client, SSL, server restart/health/backup, credits/contacts/version; không dùng localhost screenshot làm bằng chứng |

## 3. Tự động hóa phù hợp

Unit tests tập trung vào state transition, formula, cooldown, các bảng phần thưởng và giới hạn. Integration dùng database tạm và clock/RNG có thể điều khiển trong test để kiểm tra expiry, retry và mọi ranh giới. Fuzz nhỏ cho payload malformed/spam; concurrency test là transaction thật với nhiều request, không chỉ gọi hàm tuần tự. Test RNG deterministic chỉ bật trong test config, không có endpoint đổi seed public.

Godot headless bot tests giúp kiểm tra gameplay mạng nhiều client mà không mở bốn browser trên máy 8 GB. Bots phải dùng protocol thật/tài khoản test; chúng **không thay** NET-01, WEB-02 hoặc public TLS/cross-origin test. Browser automation có thể kiểm tra boot/UI/error console, nhưng Godot canvas còn cần screenshot/video và chơi thử input thật; DOM nút HTML chạy được chưa chứng minh game 3D chạy được.

Report mỗi test: ID, build/hash, thời điểm, môi trường, data seed/fixture, setup, thao tác, expected, actual, status, log/screenshot path, bug ID nếu lỗi. Secrets redact. Không tạo ảnh giả minh họa rồi gọi là screenshot build. Tests chưa chạy do thiếu máy thứ hai hay public host phải `BLOCKED_EXTERNAL` và nêu chính xác cần gì.

## 4. Buổi chơi thử của người dùng: 60 phút

Đây là vòng kiểm tra trải nghiệm sau khi automation và staff/agent QA đã pass, không thay playthrough đủ ba đảo. Claude chuẩn bị account sạch và account checkpoint riêng để người dùng thấy nội dung cuối game mà không phải grind trong 1 giờ.

| Phút | Nội dung | Ghi nhận |
|---|---|---|
| 0–5 | Đăng ký/đăng nhập, chọn VI/EN, âm lượng và chuột | Có tự hiểu cách vào game; recovery code dễ lưu |
| 5–20 | Tutorial đảo 1, câu/đánh/nhặt/bán/nâng cấp | Cảm giác thư giãn, hài, thao tác thừa, chóng mặt/khó nhìn |
| 20–35 | Room bốn người, boss, tranh nhặt vật, hunger/food/hộp thưởng | Đồng bộ, công bằng, có thấy bị ép grind; tiếng có gây khó chịu |
| 35–45 | Checkpoint đảo 2 và 3, boss/loài mới, chuyển VI/EN | Khác biệt nội dung, lỗi địa hình, lời thoại/subtitle |
| 45–55 | Reconnect, đổi thiết bị, kiểm tra save; mở menu trong coop | Tin rằng dữ liệu đã lưu; lỗi mạng được giải thích |
| 55–60 | Chọn ba điều khó chịu nhất và mức muốn chơi tiếp | Claude ghi bug và ưu tiên sửa, không chỉ hỏi “có ổn không” |

Nếu không có đủ ba người bạn, agent chuẩn bị peer/bot cho luyện tập nhưng cần lịch test người/browsers thật trước khi tuyên bố multiplayer đã kiểm chứng. Người dùng không cần làm công việc cài đặt/hợp nhất file trong buổi này.

## 5. Chặn phát hành và sửa lỗi

P0: mất/nhân đôi tài sản, lộ secrets, takeover tài khoản, public exploit nghiêm trọng. P1: không vào được web/room, progression softlock, save sai, boss thiếu, audio bắt buộc chưa có, không đủ 3 đảo/3 boss/15 thường. P2: hiệu năng dưới mục tiêu hoặc UX gây khó nhưng có cách tiếp tục; phải có đánh giá ảnh hưởng. Không phát hành “đầy đủ” khi còn P0/P1. P2 chỉ chấp nhận có ghi rõ giới hạn và bằng chứng chơi được.

Sau sửa lỗi chỉ chạy lại tests liên quan và regression gate phù hợp; không lặp mọi bộ vô ích. Khi pass, đóng gói release đã kiểm tra đúng hash. Nếu hạ tầng thiếu, bàn giao source/build/report/runbook hoàn thiện và liệt kê bước public bị chặn; không gọi đó là public online release.

