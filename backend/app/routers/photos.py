"""Photo upload and listing endpoints."""

import imghdr
import logging
import os
import uuid
from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile, status

router = APIRouter(prefix="/photos", tags=["photos"])
logger = logging.getLogger(__name__)

UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR", "/tmp/elderphoto_uploads"))
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# Maximum 20 MB per upload
MAX_UPLOAD_BYTES = 20 * 1024 * 1024


@router.post("/upload", status_code=status.HTTP_200_OK)
async def upload_photo(file: UploadFile = File(...)) -> dict[str, str]:
    """Accept a multipart image upload, validate it server-side, and store it.

    Returns the relative URL that can be used with the /images endpoints.
    """
    contents = await file.read(MAX_UPLOAD_BYTES + 1)
    if len(contents) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="File exceeds the 20 MB size limit.",
        )

    # Server-side MIME type validation via magic bytes (no client trust)
    image_type = imghdr.what(None, h=contents)
    if image_type is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is not a recognised image format.",
        )

    filename = f"{uuid.uuid4().hex}.{image_type}"
    file_path = UPLOAD_DIR / filename
    file_path.write_bytes(contents)

    logger.info("Stored uploaded photo: %s", filename)
    return {"url": f"/images/{filename}"}


@router.get("", status_code=status.HTTP_200_OK)
async def list_photos() -> dict:
    """Return metadata for all stored photos."""
    photos = [
        {"filename": f.name, "url": f"/images/{f.name}"}
        for f in sorted(UPLOAD_DIR.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True)
        if f.is_file()
    ]
    return {"photos": photos}
