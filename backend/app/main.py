"""FastAPI application entry point."""

import logging
import os

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.routers import backup, images, photos

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="ElderPhoto API",
    version="0.1.0",
    description="Accessibility-first family photo platform API",
)

# ---------------------------------------------------------------------------
# CORS
# ---------------------------------------------------------------------------
_ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ALLOWED_ORIGINS", "http://localhost:5173,http://localhost:3000"
    ).split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-CSRF-Token"],
)

# ---------------------------------------------------------------------------
# CSRF protection — reject state-changing requests from unexpected origins
# ---------------------------------------------------------------------------
_SAFE_METHODS = {"GET", "HEAD", "OPTIONS"}


@app.middleware("http")
async def csrf_origin_check(request: Request, call_next):
    if request.method not in _SAFE_METHODS:
        origin = request.headers.get("origin")
        if origin and origin not in _ALLOWED_ORIGINS:
            logger.warning("CSRF origin check failed: origin=%s", origin)
            return JSONResponse(
                status_code=status.HTTP_403_FORBIDDEN,
                content={"detail": "Request origin not allowed."},
            )
    return await call_next(request)


# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------
app.include_router(backup.router)
app.include_router(photos.router)
app.include_router(images.router)


@app.get("/health", tags=["health"])
async def health_check() -> dict[str, str]:
    """Liveness probe endpoint."""
    return {"status": "ok"}
