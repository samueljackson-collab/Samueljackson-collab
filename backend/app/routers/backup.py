"""Backup-related routes and background sync wiring."""

import asyncio
import logging

from fastapi import APIRouter, BackgroundTasks, status

router = APIRouter(prefix="/backup", tags=["backup"])
logger = logging.getLogger(__name__)


def _log_task_failure(task: asyncio.Task) -> None:
    """Log exceptions raised by the background task."""
    try:
        task.result()
    except Exception:
        logger.exception("Background photo sync failed")


async def sync_all_photos() -> None:
    """Synchronize all photos to backup storage.

    Placeholder implementation; the concrete sync logic should live here.
    """
    await asyncio.sleep(0)


@router.post("/photos", status_code=status.HTTP_202_ACCEPTED)
async def trigger_photo_backup() -> dict[str, str]:
    """Kick off a photo backup in the background."""
    task = asyncio.create_task(sync_all_photos())
    task.add_done_callback(_log_task_failure)
    return {"status": "success", "message": "Photo backup started"}
