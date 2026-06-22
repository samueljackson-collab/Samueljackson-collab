"""Backup service helpers."""
import logging
import subprocess
import time

logger = logging.getLogger(__name__)

# Retry settings for transient rsync failures.
MAX_SYNC_ATTEMPTS = 3
RETRY_BASE_DELAY_SECONDS = 1.0


def sync_file_via_rsync(source: str, destination: str) -> bool:
    """Synchronize a file using rsync.

    Returns ``True`` when the synchronization succeeds and ``False`` when it
    fails (non-zero rsync exit code) after retrying with exponential backoff.
    """
    for attempt in range(1, MAX_SYNC_ATTEMPTS + 1):
        result = subprocess.run(
            ["rsync", "-av", source, destination],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return True

        logger.warning(
            "rsync attempt %d/%d failed (exit code %s) for %s -> %s",
            attempt,
            MAX_SYNC_ATTEMPTS,
            result.returncode,
            source,
            destination,
        )
        if attempt < MAX_SYNC_ATTEMPTS:
            time.sleep(RETRY_BASE_DELAY_SECONDS * (2 ** (attempt - 1)))

    return False


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
