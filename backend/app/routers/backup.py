"""Backup-related routes and background sync wiring."""

import logging
import os
from pathlib import Path

from fastapi import APIRouter, BackgroundTasks, HTTPException, status

from app.services import backup_jobs
from app.services.backup_service import sync_backup_file

router = APIRouter(prefix="/backup", tags=["backup"])
logger = logging.getLogger(__name__)

_DEFAULT_SOURCE = os.getenv("BACKUP_SOURCE_DIR", "/tmp/elderphoto_uploads")
_DEFAULT_DESTINATION = os.getenv("BACKUP_DEST_DIR", "/tmp/elderphoto_backup")


async def sync_all_photos(job_id: str) -> None:
    """Synchronize all photos to backup storage, tracking status by job_id."""
    backup_jobs.update_job(job_id, "running")
    try:
        source = str(Path(_DEFAULT_SOURCE))
        destination = str(Path(_DEFAULT_DESTINATION))
        success = sync_backup_file(source, destination)
        if success:
            logger.info("Photo backup completed successfully.")
            backup_jobs.update_job(job_id, "success")
        else:
            logger.error("Photo backup failed.")
            backup_jobs.update_job(job_id, "failed", error="rsync sync failed")
    except Exception as exc:
        logger.exception("Background photo sync failed")
        backup_jobs.update_job(job_id, "failed", error=str(exc))


@router.post("/photos", status_code=status.HTTP_202_ACCEPTED)
async def trigger_photo_backup(background_tasks: BackgroundTasks) -> dict[str, str]:
    """Kick off a photo backup in the background.

    Returns a ``job_id`` that can be used to poll
    ``GET /backup/status/{job_id}`` for the eventual outcome.
    """
    job = backup_jobs.create_job()
    background_tasks.add_task(sync_all_photos, job.job_id)
    return {
        "status": "success",
        "message": "Photo backup started",
        "job_id": job.job_id,
    }


@router.get("/status/{job_id}", status_code=status.HTTP_200_OK)
async def get_backup_status(job_id: str) -> dict:
    """Return the status of a previously triggered backup job."""
    job = backup_jobs.get_job(job_id)
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No backup job found with id '{job_id}'.",
        )
    return job.to_dict()


@router.get("/status", status_code=status.HTTP_200_OK)
async def get_latest_backup_status() -> dict:
    """Return the status of the most recently triggered backup job."""
    job = backup_jobs.get_latest_job()
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No backup jobs have been triggered yet.",
        )
    return job.to_dict()
