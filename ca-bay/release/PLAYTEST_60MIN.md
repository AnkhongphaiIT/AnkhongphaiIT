# Buổi chơi thử 60 phút (theo `docs/10_VALIDATION.md` §4)

Dành cho chủ dự án + tối đa 3 người bạn, **sau khi** máy chủ đã chạy công khai (NEED-HOST) hoặc trong cùng mạng LAN. Bạn không cần cài đặt hay ghép file; chỉ mở đường link game.

## Chuẩn bị (Claude/người vận hành làm trước)

- [ ] Máy chủ chạy theo `server/ops/public/README.md`, `/healthz` đạt; bản web cùng content_hash.
- [ ] 4 tài khoản sạch cho 4 người (người chơi tự tạo trong buổi thử để kiểm luồng đăng ký).
- [ ] Tài khoản checkpoint (đã tới boss đảo 1, đảo 2, đảo 3, cuối game) để xem nội dung sau mà không phải cày. Trong thư mục gói máy chủ, lúc **chưa có người chơi**:
  ```
  set -a; . ./.env; set +a
  CABAY_DATA_DIR=$PWD/data CABAY_DB_PATH=$PWD/var/cabay.db .venv/bin/python ops/seed_checkpoint.py \
      --stage isl1_boss --stage isl2_start --stage isl3_start --stage endgame --yes-this-is-an-operator-db
  ```
  Tên đăng nhập `checkpoint_…` in ra màn hình; mật khẩu nằm trong `var/checkpoint_accounts.txt` (quyền 600) — xóa file sau buổi thử. Công cụ đi đúng pipeline op của server (không sửa save bằng tay); tiến trình này **không** tính là bằng chứng đã chơi hết 3 đảo.
- [ ] Sao lưu DB trước buổi thử (`run/backup.sh`).
- [ ] Mở sẵn file ghi chép (bảng dưới) để điền trong lúc chơi.

## Lịch

| Phút | Làm gì | Ghi lại |
|---|---|---|
| 0–5 | Mở link, bấm bật âm thanh, chọn VI/EN, đăng ký, **lưu mã khôi phục**, chỉnh âm lượng/độ nhạy chuột trong Tùy chọn | Có tự hiểu cách vào game không? Lưu mã khôi phục có dễ không? |
| 5–20 | Đảo 1: nói chuyện Cô Ba (nhận dép) và Ông Tư; ra cuối bến quăng câu; giật; đập xỉu; nhặt; bán ở sạp; mua đồ/nâng cấp | Có thư giãn/buồn cười không? Chỗ nào thao tác thừa, chóng mặt, khó nhìn? Cá sổng có quá nhiều không? |
| 20–35 | Cả 4 người vào **cùng phòng** (một người tạo, 3 người nhập mã phòng); gọi boss Lóc Già ở cọc cờ đỏ; thử tranh nhặt cá của nhau; ăn cơm nắm/nướng cá; mở hộp quà bằng vé | Có đồng bộ, công bằng không? Có cảm giác bị ép cày? Âm thanh có gây khó chịu? |
| 35–45 | Dùng tài khoản checkpoint: đảo 2 và 3, boss/loài mới, đổi VI↔EN | Nội dung có khác biệt? Kẹt địa hình? Chữ/phụ đề sai? |
| 45–55 | Tắt Wi-Fi 20 giây rồi bật lại; đăng nhập cùng tài khoản trên máy khác và bấm "Chuyển phiên chơi sang thiết bị này"; mở menu giữa lúc bạn đang chơi | Có tin là dữ liệu còn nguyên? Thông báo lỗi mạng có dễ hiểu? |
| 55–60 | Mỗi người nêu **3 điều khó chịu nhất** và chấm điểm muốn chơi tiếp (1–5) | — |

## Mẫu ghi chép

| Thời điểm | Người | Chuyện gì xảy ra (mong đợi / thực tế) | Mức độ (chặn / khó chịu / nhỏ) |
|---|---|---|---|
| | | | |

Sau buổi thử: Claude chuyển các ghi chép thành lỗi có bước tái hiện trong `reports/TEST_RESULTS.md` (mục NET-01 / UX), sửa theo mức độ, không chỉ hỏi "có ổn không".
