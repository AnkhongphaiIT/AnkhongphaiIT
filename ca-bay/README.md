# CÁ BAY (tên tạm)

Game câu cá 3D góc nhìn thứ nhất, low-poly, chơi trên web máy tính (bàn phím + chuột), 1–4 người cùng phòng, tài khoản và tiến trình lưu trên máy chủ. Godot 4.7.2 + backend Python (FastAPI/SQLite).

**Trạng thái thật:** xem `reports/PROJECT_STATUS.md`. Tài liệu thiết kế: `docs/00_START_HERE.md`.

| Thư mục | Nội dung |
|---|---|
| `docs/` | Bộ tài liệu v2.0.0 (00–17), nghiên cứu tham khảo |
| `data/` | Nội dung, hợp đồng, bản dịch, schema — **nguồn duy nhất** |
| `client/`, `ui/`, `shared/`, `server/gameplay/` | Mã Godot (client, logic dùng chung, room server) |
| `server/backend/` | Tài khoản, lưu, giao dịch (FastAPI + SQLite) |
| `tools/` | Kiểm dữ liệu, build, tạo tài nguyên |
| `tests/` | Test tự động |
| `handoff/`, `incoming/` | Yêu cầu ChatGPT gửi tay và nơi nhận file về |
| `reports/` | Preflight, trạng thái, quyết định, test, việc cần chủ dự án |
