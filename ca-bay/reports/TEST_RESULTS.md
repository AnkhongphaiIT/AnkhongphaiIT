# TEST_RESULTS

Mỗi dòng: ID · build/hash · thời điểm · môi trường · kết quả · bằng chứng. Trạng thái: `PASS`, `FAIL`, `NOT_RUN`, `BLOCKED_EXTERNAL`. Test trên mock không được ghi PASS cho mục yêu cầu môi trường thật.

| ID | Build | Thời điểm (UTC) | Môi trường | Kết quả | Bằng chứng / ghi chú |
|---|---|---|---|---|---|
| DATA-01 (một phần: validator gói) | docs v2.0.0 | 2026-09-27 13:47 | container, Python 3.11.15, jsonschema 4.26.0 | PASS | `tools/validate/check_docs.py` → 0 lỗi / 0 cảnh báo. Phần runtime (khóa dịch runtime, asset planned≠produced trong build) chưa chạy |
| BUILD-01 (một phần: toolchain) | Godot 4.7.2.stable ed1daf0bf | 2026-09-27 13:48 | container | PASS | Editor + templates cùng `4.7.2.stable`; dự án thử import exit 0, export Web exit 0. Export dự án thật chưa chạy |
| WEB-01 (một phần: Chromium) | dự án thử | 2026-09-27 13:49 | Chromium 141 headless, SwiftShader WebGL2 | PASS (chỉ khởi động + render) | Console: `Compatibility`, `single-threaded`; ảnh chụp cảnh 3D. Pointer lock/Esc/fullscreen/Firefox chưa chạy |
| Các mục còn lại của `docs/10_VALIDATION.md` §2 | — | — | — | NOT_RUN | Chưa có mã game |
