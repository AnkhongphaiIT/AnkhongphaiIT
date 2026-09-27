# CÁ BAY — Bộ yêu cầu triển khai 2.0.0

Cập nhật ngày 27/09/2026 từ câu trả lời trực tiếp của chủ dự án. **Đây là tài liệu, dữ liệu và prompt để Claude Code làm game; chưa có game được lập trình, xuất bản hay kiểm thử gameplay trong gói này.** Tên CÁ BAY chỉ là tên tạm.

## Bắt đầu nhanh

1. Giải nén gói này vào thư mục làm việc của Claude Code.
2. Mở `prompts/01_KIEM_TRA_VA_KHOI_DONG.md`, sao chép toàn bộ nội dung và gửi cho Claude Code.
3. Prompt 01 yêu cầu kiểm tra trước rồi **tự tiếp tục Prompt 02** khi có thể làm việc. Không cần xác nhận lại các quyết định đã trả lời.
4. `prompts/02_TRIEN_KHAI_DEN_HOAN_THANH.md` cũng dùng để tiếp tục ở phiên khác hoặc khi dự án đã được kiểm tra.
5. Claude tự tạo thư mục con `ca-bay/` trong thư mục làm việc, tạo file/thư mục dự án, phân việc, kiểm thử và lưu tiến độ. Thư mục đã tồn tại phải được kiểm tra và tiếp tục, không ghi đè mù quáng.

## Phạm vi hiện hành

| Phần | Yêu cầu |
|---|---|
| Nền tảng | Web trên máy tính, bàn phím/chuột; itch.io trước, website tên miền .io riêng khi có quyền sở hữu/hạ tầng |
| Engine | Godot, 3D góc nhìn thứ nhất, đồ họa low-poly; phiên bản stable thực tế và export template phải được kiểm chứng |
| Nhiều người | Phòng 1–4 người, hỗ trợ thử thật 4 người ngay trong quá trình phát triển |
| Bản đầy đủ | 3 đảo, 3 boss, 15 loài thường; cách đếm 15 loài ngoài boss là giả định triển khai được ghi rõ trong `11` |
| Cảm giác | Câu cá thư giãn, tương tác hỗn loạn hài hước; không máu me đáng sợ |
| Cốt truyện | Nghề câu và khôi phục bến cá sau thời tiết xấu; không cá đột biến vì trà sữa |
| Vòng chơi | Câu → giật cá bay → làm cá xỉu bằng công cụ → nhặt/bán → nâng cấp → boss → mở vùng |
| Hệ thống thêm | Thanh đói, ăn uống, lootbox/gacha miễn phí bằng phần thưởng chơi; bản đầu không có tiền thật |
| Tài khoản | Tài khoản riêng, tiến trình do máy chủ quản lý, đồng bộ giữa thiết bị |
| Nội dung | Việt/Anh; nhạc, ambience, hiệu ứng, tiếng ú ớ và lời thoại có giọng đọc |
| Ngân sách | 0 đồng chi thêm; không mua API, dịch vụ, domain, tài nguyên hoặc nâng gói |
| Máy làm | RAM 8 GB; không mặc định máy có Docker/Blender hoặc đủ để chạy nhiều trình biên dịch cùng lúc |
| Điều phối | Claude Code chịu trách nhiệm chính; agent khác thực hiện phần việc có ranh giới rõ |
| ChatGPT | Chuyển yêu cầu và nhận tệp bằng tay; không tự động hóa website ChatGPT, không dùng API trả phí |
| Phát hành | Công khai khi đạt tiêu chí và có tài khoản/hạ tầng; ban đầu chơi miễn phí, chưa bật quảng cáo/IAP |

## Quyền ưu tiên

Chỉ dẫn mới của chủ dự án > quyết định bản 2 trong `11` > đặc tả bản 2 > dữ liệu/hợp đồng hiện hành theo chủ sở hữu trong `08`. Nếu các tài liệu bản 2 mâu thuẫn nhau, Claude ghi quyết định sửa và cập nhật các bên liên quan; không tự chọn cách có lợi để bỏ tính năng. Ràng buộc chi phí 0 đồng luôn được giữ cho tới khi chủ dự án đổi rõ ràng.

`01_SOURCES.md`, `02_EVIDENCE.md`, `03_REFERENCE_GAME_ANALYSIS.md` và `references/` lưu nghiên cứu cũ. Các khẳng định giá, phiên bản, nền tảng, ngày phát hành, khả năng mô hình AI và chính sách trong đó **không được tái xác minh toàn bộ ở bản 2**. Chúng không phải chỉ dẫn thực thi và không ghi đè yêu cầu hiện hành. Nguồn kỹ thuật được đối chiếu cho lần cập nhật này nằm ở `17_VERIFIED_SOURCES.md`.

## Đọc đúng tài liệu

| File | Mục đích |
|---|---|
| `BAN_HUONG_DAN_NGAN.md` | Hướng dẫn cho chủ dự án |
| `CLAUDE.md` | Quy tắc dự án để Claude dùng sau khi được giao thực hiện |
| `04_GAME_DESIGN.md` | Cốt truyện, vòng chơi, co-op, nội dung, đói, lootbox |
| `05_ART_BIBLE.md`, `06_ASSET_BIBLE.md` | Mỹ thuật, âm thanh và danh mục tài nguyên |
| `07_TECHNICAL_DESIGN.md`, `08_SHARED_CONTRACTS.md` | Client, server, tài khoản, dữ liệu, giao tiếp |
| `09_AGENT_TASKS.md`, `10_VALIDATION.md` | Công việc đến bản đầy đủ và nghiệm thu |
| `11_DECISIONS_AND_UNKNOWNS.md` | Lựa chọn của chủ dự án, giả định, việc còn thiếu |
| `12_PREFLIGHT_AND_RESOURCES.md` | Kiểm tra ban đầu, phân loại thiếu hụt |
| `13_CLAUDE_AUTOMATION.md` | Điều phối agent và tiếp tục qua nhiều phiên |
| `14_AI_ASSET_HANDOFF.md` | Chuyển việc hình ảnh/âm thanh sang AI và nhập lại |
| `15_DEPLOYMENT_AND_COST.md` | Phát hành itch.io, website riêng, máy chủ, ngân sách |
| `16_CHANGELOG.md`, `17_VERIFIED_SOURCES.md` | Thay đổi và nguồn kiểm chứng |
| `data/` | Dữ liệu thiết kế và schema, chưa phải tiến trình người chơi thật |
| `tools/check_docs.py` | Kiểm tra cấu trúc và tham chiếu dữ liệu của gói tài liệu |

## Điều được coi là xong

Gói tài liệu này chỉ hoàn thành việc **đặc tả lại và chuẩn bị yêu cầu cho Claude Code**. Khi thực hiện dự án, Claude phải tách trạng thái: tài liệu đạt / dữ liệu đạt / chạy local / co-op thử thật / sẵn sàng phát hành / đã công khai. Bản mô phỏng, tài nguyên tạm, một phòng local hoặc các kiểm tra JSON không được dùng làm bằng chứng đã hoàn thành game công khai.
