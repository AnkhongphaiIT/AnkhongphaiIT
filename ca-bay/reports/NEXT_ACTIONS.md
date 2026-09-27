# NEXT_ACTIONS (tối đa 5, theo thứ tự)

1. **M0 / WP-01** — Tạo `project.godot` thật, autoload `ContentDB` (tải `data/content`, tính `content_hash`), `Loc` (strings.csv VI/EN), InputMap theo `data/contracts/input_actions.json`, boot scene "Vào game" (khóa chuột + mở âm), export preset Web/Server; xuất web và smoke bằng `tools/build/web_smoke.mjs`.
2. **M0 / WP-02** — Skeleton backend `server/backend` (FastAPI, SQLite migrations, `/healthz`), khóa dependency `requirements.lock.txt`.
3. **M1** — Auth + rooms + tickets + internal API; Godot room server với ticket auth; 4 bot headless.
4. **M2** — Vòng câu/cá bay/KO/nhặt/bán trên đảo 1 qua mạng.
5. Cập nhật `reports/*` và commit + push sau mỗi mốc.

## Lệnh tiếp tục đã kiểm chứng

```bash
cd ca-bay
python3 -m venv .venv && .venv/bin/pip install -r tools/validate/requirements.txt
.venv/bin/python tools/validate/check_docs.py      # phải ra errors: 0
godot --version                                     # 4.7.2.stable.official.ed1daf0bf
```

Nếu container mới không có Godot: làm lại bước cài trong `reports/PREFLIGHT.md` §3 (layer Docker Hub `barichello/godot-ci:4.7.2`, digest trong `toolchain.lock.json`).
