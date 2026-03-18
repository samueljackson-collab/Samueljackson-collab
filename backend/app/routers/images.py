"""Image serving endpoints — signed URL and direct blob retrieval."""

import logging
import os
import secrets
from pathlib import Path

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import FileResponse

router = APIRouter(prefix="/images", tags=["images"])
logger = logging.getLogger(__name__)

UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR", "/tmp/elderphoto_uploads"))

# Paths must not escape the upload directory.
_ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".tiff"}


def _resolve_safe_path(image_path: str) -> Path:
    """Resolve *image_path* against UPLOAD_DIR, rejecting traversal attempts."""
    # Normalise and strip any leading slashes that would make Path treat it as absolute
    safe_name = Path(image_path.lstrip("/")).name
    if not safe_name:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid image path.")
    resolved = (UPLOAD_DIR / safe_name).resolve()
    if not str(resolved).startswith(str(UPLOAD_DIR.resolve())):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Path not allowed.")
    if resolved.suffix.lower() not in _ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported file type.")
    if not resolved.exists():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Image not found.")
    return resolved


@router.get("/{image_path:path}/signed-url", status_code=status.HTTP_200_OK)
async def get_signed_image_url(image_path: str) -> dict[str, str]:
    """Return a short-lived signed URL for the requested image.

    In production this would generate a cloud-storage pre-signed URL.
    Here we return a local URL with an opaque token for demonstration.
    """
    # Validate the path exists before issuing any URL
    _resolve_safe_path(image_path)
    token = secrets.token_urlsafe(16)
    safe_name = Path(image_path.lstrip("/")).name
    signed_url = f"/images/{safe_name}?token={token}"
    return {"url": signed_url}


@router.get("/{image_path:path}", status_code=status.HTTP_200_OK)
async def get_image(image_path: str) -> FileResponse:
    """Serve an image file directly (used with Authorization header via fetch)."""
    resolved = _resolve_safe_path(image_path)
    return FileResponse(path=str(resolved), media_type="image/*")
