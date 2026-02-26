"""Backup service helpers."""
import logging

logger = logging.getLogger(__name__)


def sync_file_via_rsync(source: str, destination: str) -> bool:
    """Synchronize a file using rsync.

    This function is expected to return ``True`` when the synchronization
    succeeds and ``False`` when it fails.
    """
    raise NotImplementedError


def sync_backup_file(source: str, destination: str) -> bool:
    """Sync a file to its backup destination via rsync.

    The boolean result from :func:`sync_file_via_rsync` is captured so that a
    failure is logged and returned immediately instead of being reported as a
    success.
    """
    sync_succeeded = sync_file_via_rsync(source, destination)
    if sync_succeeded:
        logger.info("Successfully synced %s -> %s", source, destination)
    else:
        logger.error("sync_file_via_rsync failed for %s -> %s", source, destination)
    return sync_succeeded
