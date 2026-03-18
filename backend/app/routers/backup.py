"""Backup-related routes and background sync wiring."""

import logging
import os
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, status

from app.services.backup_service import sync_backup_file

router = APIRouter(prefix="/backup", tags=["backup"])
logger = logging.getLogger(__name__)

_DEFAULT_SOURCE = os.getenv("BACKUP_SOURCE_DIR", "/tmp/elderphoto_uploads")
_DEFAULT_DESTINATION = os.getenv("BACKUP_DEST_DIR", "/tmp/elderphoto_backup")


async def sync_all_photos() -> None:
    """Synchronize all photos to backup storage."""
    try:
        source = str(Path(_DEFAULT_SOURCE))
        destination = str(Path(_DEFAULT_DESTINATION))
        success = sync_backup_file(source, destination)
        if success:
            logger.info("Photo backup completed successfully.")
        else:
            logger.error("Photo backup failed.")
    except Exception:
        logger.exception("Background photo sync failed")


@router.post("/photos", status_code=status.HTTP_202_ACCEPTED)
async def trigger_photo_backup(background_tasks: BackgroundTasks) -> dict[str, str]:
    """Kick off a photo backup in the background."""
    background_tasks.add_task(sync_all_photos)
    return {"status": "success", "message": "Photo backup started"}
