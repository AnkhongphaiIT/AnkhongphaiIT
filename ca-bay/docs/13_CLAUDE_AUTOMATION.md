# 13 — Claude Code điều phối toàn dự án

## 1. Vai trò

Claude giữ backlog, hợp đồng dữ liệu, quyết định tích hợp và chất lượng cuối. Các agent nhận việc cụ thể: gameplay, network/backend, art/audio, UI/localization, QA. Đây là vai trò; số agent đang chạy phụ thuộc RAM/quota. Trên 8 GB, bắt đầu tối đa 2 việc code nhẹ song song, build/asset import tuần tự. Không chạy tất cả agent chỉ vì đã có tên trong danh sách.

Claude có thể tạo subagent theo cấu hình project `.claude/agents/`, tùy khả năng phiên bản thực tế. Xác minh cú pháp và gọi thử trước khi giao việc dài. Nếu phiên hiện tại chưa nhận agent mới, dùng cơ chế task có sẵn hoặc tiếp tục tuần tự và ghi cách nạp cho phiên sau. Không cần dừng cả dự án để hoàn thiện hệ thống agent. Nguồn: [Claude Code — subagents](https://code.claude.com/docs/en/sub-agents).

## 2. Kết nối thực, không mô phỏng tổ chức

| Bên nhận | Cách dùng |
|---|---|
| Claude subagent | Gọi bằng công cụ subagent thực tế; nhận output + file diff + test |
| Codex | Kiểm tra CLI/công cụ đã đăng nhập và quyền trong repo. Chỉ dùng lệnh được xác minh qua tài liệu/help của bản cài. Chưa callable thì dùng task file để người dùng chuyển, hoặc Claude làm thay |
| Antigravity | Kiểm tra tương tự; không tự bịa endpoint, API, cờ CLI hoặc quyền từ gói Pro |
| ChatGPT Plus | Claude viết batch request; chủ dự án gửi tay và đưa file vào `incoming/`; không chờ ở đó nếu vẫn còn code/test khác |

Không đưa gói công việc chứa mật khẩu, token, thông tin người chơi hoặc source không cần thiết cho bên khác. Quota hết thì checkpoint, thu nhỏ context và tiếp tục khi phiên có thể chạy; không đăng ký gói trả phí hoặc hứa tự chạy khi ứng dụng đã đóng.

## 3. Hợp đồng giao việc

Mỗi task lưu thành `tasks/<id>.md`, chứa: mục tiêu; input tối thiểu và phiên bản; file được phép sửa; file không được sửa; API/ID phải giữ; test chấp nhận; đường dẫn output; phụ thuộc; trạng thái. Mỗi file chỉ một chủ sửa cùng lúc. Mọi đổi schema/sự kiện đi qua Claude tích hợp, cập nhật dữ liệu/QA cùng đợt. Có thể ghi decision record mà không hỏi người dùng lại cho quyết định kỹ thuật thường lệ.

Agent trả: thay đổi cụ thể, test đã chạy/lệnh và kết quả, việc chưa kiểm chứng, thiếu hụt thật, đề xuất tiếp theo. Claude đọc thay đổi, chạy test giao nhau rồi mới đánh dấu done. Hai agent cùng báo thành công nhưng chưa chạy chung vẫn là chưa tích hợp.

## 4. Bố cục dự án đích

```text
ca-bay/
  CLAUDE.md
  .claude/agents/           # Claude tạo phù hợp công cụ hiện có
  docs/                    # tài liệu 00–17, references và handoff hướng dẫn
  data/                    # một bản dữ liệu/schema duy nhất
  project.godot            # root dự án Godot, res://data dùng trực tiếp
  client/                  # scene/script client
  ui/                      # scene UI theo đường dẫn res://ui trong registry
  server/                  # headless gameplay + auth/persistence service
  shared/                  # logic thuần dùng client/server
  assets/                  # tài nguyên đã import/kiểm chứng
  incoming/                # người dùng bỏ tệp trả về từ ChatGPT; chưa tin tự động
  prompts/                 # hai prompt chính và mẫu yêu cầu tài nguyên
  handoff/                 # yêu cầu, biểu mẫu, gói chuyển tay
  tasks/                   # backlog và quyền sở hữu file
  tests/
  tools/
  reports/
  build/
  release/
```

Tạo `.gdignore` cho docs, backend Python, incoming, venv, test không dùng Godot và thư mục build phù hợp để tránh import dư. Editor export dùng whitelist/exclude để không đóng server, DB, `.env`, test, docs và secrets vào bundle web. Gitignore tương ứng; không bỏ data/ hoặc source cần thiết.

## 5. Tự động hóa hữu ích cần Claude tạo

- Lệnh kiểm tra môi trường không in secrets; cấu hình paths riêng máy đặt local.
- Lệnh chạy auth + room server + web local; stop chỉ tiến trình dự án do launcher tạo.
- Schema/reference checks; backend transactions/auth integration; headless gameplay tests; smoke web.
- Tạo tài nguyên procedural lặp lại được theo seed; asset validation và import có manifest.
- Xuất web, tạo ZIP sạch `index.html` ở root, kiểm tra không lộ bí mật; SHA256 artifact.
- Backup/restore DB bằng cơ chế nhất quán SQLite, không copy thô file DB đang ghi bỏ quên WAL.
- Một lệnh smoke cho từng mốc và báo cáo ngắn. Dùng Python/PowerShell phù hợp máy, không giả định shell Linux.

## 6. Chu kỳ làm việc và tiếp tục

Đọc trạng thái → chọn task chưa bị chặn → làm → test đúng rủi ro → tích hợp → cập nhật trạng thái → chọn task kế tiếp. Bản nhỏ để thử mạng và cảm giác chơi là cổng nội bộ, không thay thế bản đủ ba đảo.

Cuối phiên ghi `PROJECT_STATUS.md` gồm milestone, commit/checkpoint, đã làm, test pass/fail/not-run, danh sách tài nguyên còn tạm, blocker và đường dẫn. `NEXT_ACTIONS.md` có tối đa 5 việc theo thứ tự cùng lệnh tiếp tục đã kiểm chứng. Không chỉ viết lời hứa trong chat.

Các trạng thái task: `NOT_STARTED`, `IN_PROGRESS`, `IMPLEMENTED_UNVERIFIED`, `VERIFIED`, `BLOCKED_EXTERNAL`, thống nhất với `09`. Trạng thái test riêng: `PASS`, `FAIL`, `NOT_RUN`, `BLOCKED_EXTERNAL`. Không đánh dấu VERIFIED khi chờ tệp thật, còn stub auth, chưa test bốn người hoặc deploy thất bại. Nếu dừng vì quota, lưu checkpoint và nói rõ thao tác tiếp tục; không tuyên bố đã tạo một tiến trình tự chạy nền nếu không có tiến trình đó.
