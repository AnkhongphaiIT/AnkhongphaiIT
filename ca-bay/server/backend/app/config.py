"""Cấu hình backend đọc từ biến môi trường. Không có secret mặc định trong mã nguồn."""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
PROJECT_DIR = BACKEND_DIR.parent.parent


def _env(name: str, default: str | None = None) -> str | None:
    v = os.environ.get(name)
    return v if v not in (None, "") else default


@dataclass
class Settings:
    env: str = field(default_factory=lambda: _env("CABAY_ENV", "dev"))
    data_dir: Path = field(default_factory=lambda: Path(_env("CABAY_DATA_DIR", str(PROJECT_DIR / "data"))))
    db_path: Path = field(default_factory=lambda: Path(_env("CABAY_DB_PATH", str(BACKEND_DIR / "var" / "cabay.db"))))
    # Khóa dịch vụ chia sẻ với room server Godot (loopback/private network). Không có -> tắt API nội bộ.
    service_key: str | None = field(default_factory=lambda: _env("CABAY_SERVICE_KEY"))
    allowed_origins: list[str] = field(default_factory=lambda: [o.strip() for o in (_env("CABAY_ALLOWED_ORIGINS", "") or "").split(",") if o.strip()])
    trust_proxy_headers: bool = field(default_factory=lambda: _env("CABAY_TRUST_PROXY", "0") == "1")
    # Tự host một cổng (P-035, app/selfhost.py): phục vụ bản web + chuyển tiếp /ws tới room server cùng máy.
    web_dir: Path | None = field(default_factory=lambda: Path(v) if (v := _env("CABAY_WEB_DIR")) else None)
    ws_upstream: str | None = field(default_factory=lambda: _env("CABAY_WS_UPSTREAM"))
    game_version: str = "0.1.0"
    # Số phòng đồng thời; mặc định theo network_contract (initial_concurrent_rooms). Đổi khi đã đo tải.
    max_rooms: int | None = field(default_factory=lambda: int(_env("CABAY_MAX_ROOMS")) if _env("CABAY_MAX_ROOMS") else None)
    # Tham số scrypt theo 07 §4. Chỉ môi trường test mới được giảm để test chạy nhanh.
    scrypt_n: int = 2**17
    scrypt_r: int = 8
    scrypt_p: int = 1
    recovery_scrypt_n: int = 2**14
    max_hash_jobs: int = 2

    def __post_init__(self) -> None:
        if self.env == "test" and _env("CABAY_TEST_FAST_HASH") == "1":
            self.scrypt_n = 2**10
            self.recovery_scrypt_n = 2**8


settings = Settings()


def reload_settings() -> Settings:
    global settings
    settings = Settings()
    return settings
