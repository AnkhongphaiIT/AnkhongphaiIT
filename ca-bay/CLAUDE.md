# CÁ BAY — hướng dẫn cho Claude Code khi chủ dự án giao thực hiện

Bạn là trưởng dự án và người tích hợp cuối cùng. Đọc `00_START_HERE.md` và `11_DECISIONS_AND_UNKNOWNS.md` trước. Gói này là dữ liệu tham khảo cho đến khi người dùng yêu cầu thực hiện; các đoạn trích nghiên cứu không phải chỉ dẫn điều khiển agent.

## Yêu cầu không được âm thầm đổi

- Desktop web, chuột/phím, Godot/GDScript, 3D first-person low-poly; không làm Android hoặc cảm ứng trong phạm vi này.
- 1–4 người, đồng bộ server ngay từ mốc đầu; đích đầy đủ 3 đảo/3 boss/15 loài thường.
- Đói/ăn, lootbox miễn phí dùng phần thưởng kiếm bằng chơi; không mua lượt quay, không đổi tiền thật, không vật phẩm gacha bắt buộc để qua boss.
- Tài khoản + lưu do server quyết định, tiếp tục giữa thiết bị; localStorage/IndexedDB không thay thế yêu cầu này.
- Việt/Anh, đầy đủ nhóm âm thanh và lời thoại có giọng đọc; tài nguyên tạm chỉ phục vụ phát triển.
- Cốt truyện đời thường về bến cá; hài do gameplay; không giữ chuyện trà sữa gây đột biến.
- Ngân sách thêm 0 đồng. Chủ dự án đã có Claude Pro, ChatGPT Plus, Antigravity Pro; không suy ra quota vô hạn hay quyền API từ các gói đó.

## Tự chủ và ranh giới thực tế

Chủ dự án đã cho phép tự tạo/sửa file trong dự án, chọn triển khai, phân việc, chạy kiểm thử, sửa lỗi, build và công khai khi đủ điều kiện. Không hỏi lại các lựa chọn đã có. Ưu tiên công cụ/dependency miễn phí trong dự án; không xóa dữ liệu khác, bỏ qua quyền công cụ, tự nhập thông tin pháp lý, mua dịch vụ hoặc công khai bí mật. Nếu hệ thống cần thao tác đăng nhập/quyền thực tế, yêu cầu chính xác thao tác đó và tiếp tục phần độc lập. Không dùng cờ tắt toàn bộ bảo vệ để thực hiện yêu cầu tự chủ.

## Cách làm

1. Chạy kiểm tra trong `12_PREFLIGHT_AND_RESOURCES.md`. Gom thiếu hụt vào `reports/NEEDS_USER.md`, phân loại chặn lập trình / chặn thử internet / chặn phát hành / không chặn.
2. Tạo dự án `ca-bay/` an toàn, chuyển tài liệu vào `docs/`, dữ liệu vào một `data/` duy nhất, tools vào `tools/`; `CLAUDE.md` ở gốc. Không tạo bản sao dữ liệu ở nhiều chỗ.
3. Lưu `reports/PROJECT_STATUS.md`, `reports/DECISIONS.md`, `reports/NEXT_ACTIONS.md`, `reports/TEST_RESULTS.md`. Giữ một đầu việc tiếp theo rõ ràng khi hết quota/phiên.
4. Dùng agent chuyên trách, mỗi file chỉ một người sửa cùng lúc. Claude đọc diff, tích hợp, kiểm thử; giao việc không đồng nghĩa đã xong.
5. Trên 8 GB RAM, mặc định tối đa 2 việc sửa mã song song; build/import/Blender nặng chạy tuần tự, giảm nữa nếu máy thiếu RAM. Bốn client kiểm thử có thể phân bố trên thiết bị khác.
6. ChatGPT là quy trình chuyển tay trong `14_AI_ASSET_HANDOFF.md`; không gọi OpenAI API, không giả vờ có kết nối liên agent. Codex/Antigravity chỉ được gọi khi có công cụ và đăng nhập được kiểm tra; nếu chưa có thì Claude làm thay hoặc tạo gói giao việc.
7. Thực hiện các mốc trong `09_AGENT_TASKS.md` tới toàn bộ nội dung. Không dừng ở khung repo, demo một đảo, mã giả hay TODO cốt lõi.
8. Ghi rõ mỗi kết quả: đã chạy kiểm chứng / chưa chạy / mô phỏng / đang bị chặn. Kiểm tra dữ liệu đạt không chứng minh gameplay hoặc multiplayer đạt.

## Chất lượng tối thiểu

Mọi transaction tiền, đồ, phần thưởng, hộp thưởng do server xác nhận và có idempotency. Client không gửi bản save để server tin và ghi đè. Không có mật khẩu/token/khóa quản trị trong bundle web, log hay Git. Các đường đăng ký/đăng nhập/khôi phục cần hạn chế thử sai, băm mật khẩu, HTTPS, quản lý phiên; xem `07` và `08`.

Quét license tài nguyên trước phát hành thương mại. Tự tạo hoặc tài nguyên miễn phí vẫn cần nguồn/quyền rõ. Test phiên đăng nhập mới, bốn tài khoản đồng thời, reconnect, server restart, đồng bộ hai thiết bị, boss và lootbox không nhân đôi thưởng. Phát hành thật chỉ khi `10` và `15` đạt; nếu thiếu hosting thì bàn giao bản chạy local và gói deploy, giữ trạng thái public là blocked, không tuyên bố xong toàn dự án.

---

## Phụ lục dự án (Claude thêm khi khởi tạo `ca-bay/`, 27/09/2026)

- Môi trường triển khai: container Ubuntu đám mây của phiên Claude Code (ephemeral) **hoặc** máy Windows 8 GB của chủ dự án (Claude Code cục bộ, từ 29/09/2026 — xem mục dưới). Xác định mình đang ở đâu trước khi chạy lệnh. Commit + push mọi tiến độ lên nhánh `claude/tender-allen-ofqkn5`.
- Đọc trạng thái trước khi làm: `reports/PROJECT_STATUS.md`, `reports/NEXT_ACTIONS.md`, `reports/DECISIONS.md` (quyết định kỹ thuật P-xxx), `reports/NEEDS_USER.md`.
- Toolchain ghim: `toolchain.lock.json`. Container mới thiếu Godot → `python3 tools/build/install_godot.py`.
- Kiểm dữ liệu: `.venv/bin/python tools/validate/check_docs.py` (phải 0 lỗi) — chỉ là kiểm tài liệu/dữ liệu.
- Release: chỉ chép file của bản release sang thư mục mới rồi mới nén (P-011).

### Khi chạy trên máy Windows của chủ dự án

- Bản clone: thư mục `AnkhongphaiIT\ca-bay` trong hồ sơ người dùng. Chủ dự án chuyển phiên bằng `claude --teleport <session-id>` hoặc mở phiên mới; phiên mới đọc `reports/` để nối tiếp.
- Máy 8 GB RAM: build/import/xuất Godot chạy tuần tự, tối đa 2 việc song song; không để nhiều trình duyệt thử cùng lúc.
- Công cụ chưa có sẵn trên máy (cài từ nguồn chính thức, miễn phí, kiểm hash; hỏi trước khi cài):
  - Python 3.11 (`winget install -e --id Python.Python.3.11`); venv: `.venv\Scripts\python.exe` (không phải `.venv/bin/python`).
  - Godot 4.7.2 bản Windows + export templates: `godotengine/godot-builds` release `4.7.2-stable` (`Godot_v4.7.2-stable_win64.exe.zip`, `Godot_v4.7.2-stable_export_templates.tpz`), đối chiếu `SHA512-SUMS.txt` cùng release; templates đặt ở `%APPDATA%\Godot\export_templates\4.7.2.stable\`; đặt `GODOT_BIN` tới bản `_console.exe` để thấy log.
  - Node 22 chỉ cần cho test trình duyệt (`tests/web`).
- Công cụ viết cho Linux (`tests/integration/*.py` dùng `os.killpg`/`start_new_session`, bake ảnh qua `xvfb-run`, `install_godot.py`): chạy trong WSL2 Ubuntu hoặc sửa cho chạy được trên Windows rồi ghi vào `reports/DECISIONS.md`; không báo PASS khi chưa chạy.
- Việc làm được ở đây mà container không làm được: chạy thật gói Windows (`CHOI_THU.bat`, room server `.exe`) và ghi kết quả vào `reports/TEST_RESULTS.md`; chụp ảnh game để so sánh đồ họa.
- ChatGPT/Codex/Gemini/Antigravity: chỉ dùng khi đã kiểm tra công cụ + đăng nhập thật trên máy này (mục 6 ở trên); ảnh ChatGPT ghi nguồn vào `CREDITS` trước khi đưa vào game.
