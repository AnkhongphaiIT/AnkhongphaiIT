"""Ứng dụng FastAPI: tài khoản, phòng, lưu tiến trình. Chạy: uvicorn app.main:app --host 127.0.0.1 --port 8787"""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from .auth.routes import router as auth_router
from .config import settings
from .content import get_catalog
from .db import connect, migrate
from .ops import expire_old_operations
from .persistence.internal_routes import router as internal_router, sweep_stale
from .rooms.routes import router as rooms_router

log = logging.getLogger("cabay")

AUTH_BODY_LIMIT = 8 * 1024
DEFAULT_BODY_LIMIT = 64 * 1024


@asynccontextmanager
async def lifespan(app: FastAPI):
    conn = connect()
    try:
        migrate(conn)
        cat = get_catalog()
        expire_old_operations(conn, int(cat.limit("idempotency_retention_days")))
        sweep_stale(conn, cat)
    finally:
        conn.close()
    yield


app = FastAPI(title="CÁ BAY backend", version=settings.game_version, lifespan=lifespan, docs_url=None, redoc_url=None, openapi_url=None)

if settings.allowed_origins:
    # Chỉ origin thật đã quan sát (iframe itch.io, website riêng); không wildcard, không cookie.
    app.add_middleware(CORSMiddleware, allow_origins=settings.allowed_origins, allow_credentials=False,
                       allow_methods=["GET", "POST", "DELETE"], allow_headers=["Authorization", "Content-Type"], max_age=600)


@app.middleware("http")
async def body_limit(request: Request, call_next):
    limit = AUTH_BODY_LIMIT if request.url.path.startswith("/v1/auth") else DEFAULT_BODY_LIMIT
    cl = request.headers.get("content-length")
    if cl is not None and (not cl.isdigit() or int(cl) > limit):
        return JSONResponse(status_code=413, content={"error_code": "INVALID_PAYLOAD"})
    body = await request.body()
    if len(body) > limit:
        return JSONResponse(status_code=413, content={"error_code": "INVALID_PAYLOAD"})
    return await call_next(request)


@app.exception_handler(StarletteHTTPException)
async def http_exc(request: Request, exc: StarletteHTTPException):
    detail = exc.detail if isinstance(exc.detail, dict) else {"error_code": "NOT_FOUND" if exc.status_code == 404 else "INVALID_PAYLOAD"}
    return JSONResponse(status_code=exc.status_code, content=detail)


@app.exception_handler(RequestValidationError)
async def validation_exc(request: Request, exc: RequestValidationError):
    # Không phản hồi lại input (có thể chứa mật khẩu).
    return JSONResponse(status_code=400, content={"error_code": "INVALID_PAYLOAD"})


@app.get("/healthz")
def healthz():
    cat = get_catalog()
    return {"ok": True, "version": settings.game_version, "protocol_version": cat.protocol_version, "content_hash": cat.content_hash}


app.include_router(auth_router)
app.include_router(rooms_router)
app.include_router(internal_router)
