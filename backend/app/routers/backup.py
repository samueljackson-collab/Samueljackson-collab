"""Backup-related routes and background sync wiring."""

import asyncio
import logging

from fastapi import APIRouter, BackgroundTasks, status

router = APIRouter(prefix="/backup", tags=["backup"])
logger = logging.getLogger(__name__)


async def sync_all_photos() -> None:
    """Synchronize all photos to backup storage.

    Placeholder implementation; the concrete sync logic should live here.
    """
    try:
        await asyncio.sleep(0)
    except Exception:
        logger.exception("Background photo sync failed")


@router.post("/photos", status_code=status.HTTP_202_ACCEPTED)
async def trigger_photo_backup(background_tasks: BackgroundTasks) -> dict[str, str]:
    """Kick off a photo backup in the background."""
    background_tasks.add_task(sync_all_photos)
    return {"status": "success", "message": "Photo backup started"}
