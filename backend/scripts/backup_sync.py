"""Backup synchronization script with optional verification support."""
from __future__ import annotations

import argparse
import logging
import subprocess
import sys
import time
from pathlib import Path

logger = logging.getLogger(__name__)

DEFAULT_PROMPT = "Run backup sync? [y/N] "

# Retry settings for transient rsync failures.
MAX_SYNC_ATTEMPTS = 3
RETRY_BASE_DELAY_SECONDS = 1.0


def run_sync_with_retry(
    sync_cmd: list[str],
    max_attempts: int = MAX_SYNC_ATTEMPTS,
    base_delay: float = RETRY_BASE_DELAY_SECONDS,
) -> None:
    """Run an rsync subprocess command, retrying on failure with exponential backoff.

    Raises ``RuntimeError`` if all attempts fail.
    """
    last_result = None
    for attempt in range(1, max_attempts + 1):
        last_result = subprocess.run(sync_cmd, check=False)
        if last_result.returncode == 0:
            return
        logger.warning(
            "rsync attempt %d/%d failed with exit code %s.",
            attempt,
            max_attempts,
            last_result.returncode,
        )
        if attempt < max_attempts:
            delay = base_delay * (2 ** (attempt - 1))
            time.sleep(delay)

    raise RuntimeError(
        f"rsync failed after {max_attempts} attempts "
        f"(last exit code: {last_result.returncode})."
    )


def verify_sync(source: Path, destination: Path) -> None:
    """Verify that source and destination are in sync via a checksum-based dry run."""
    verify_cmd = [
        "rsync",
        "-a",
        "--delete",
        "--checksum",
        "--dry-run",
        f"{source}/",
        f"{destination}/",
    ]
    result = subprocess.run(verify_cmd, check=False, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"Verification command failed with exit code {result.returncode}.\n"
            f"Stderr: {result.stderr}"
        )
    if result.stdout:
        raise RuntimeError(
            "Verification failed: destination is not in sync with source.\n"
            f"Differences found:\n{result.stdout}"
        )


def run_full_sync(source: Path, destination: Path, verify: bool = False) -> None:
    """Perform a full backup sync and optionally verify the result."""
    sync_cmd = ["rsync", "-a", "--delete", f"{source}/", f"{destination}/"]
    run_sync_with_retry(sync_cmd)

    if verify:
        verify_sync(source, destination)


def run_incremental_sync(
    source: Path, destination: Path, previous_backup: Path, verify: bool = False
) -> None:
    """
    Perform an incremental backup using a previous backup as the link destination
    and optionally verify the result.
    """
    sync_cmd = [
        "rsync",
        "-a",
        "--delete",
        f"--link-dest={previous_backup}",
        f"{source}/",
        f"{destination}/",
    ]
    run_sync_with_retry(sync_cmd)

    if verify:
        verify_sync(source, destination)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Backup synchronization script")
    parser.add_argument("source", type=Path, help="Source directory")
    parser.add_argument("destination", type=Path, help="Destination directory")
    parser.add_argument(
        "--previous-backup",
        type=Path,
        default=None,
        help="Path to previous backup for incremental sync",
    )
    parser.add_argument(
        "--mode",
        choices=["full", "incremental"],
        default="full",
        help="Select full or incremental sync",
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Verify the sync via checksum-based dry run",
    )
    parser.add_argument(
        "--yes",
        "--assume-yes",
        dest="yes",
        action="store_true",
        help="Skip interactive confirmation prompt",
    )
    return parser.parse_args()


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )


def confirm_action(assume_yes: bool) -> bool:
    if assume_yes:
        logger.info("--yes supplied; skipping interactive confirmation.")
        return True

    if not sys.stdin.isatty():
        logger.error("Refusing to run without --yes/--assume-yes because stdin is not a TTY.")
        return False

    try:
        response = input(DEFAULT_PROMPT).strip().lower()
    except EOFError:
        # When the user presses Ctrl+D, input() raises an EOFError.
        # We can treat this as an intentional abort.
        response = ""

    if response in {"y", "yes"}:
        return True

    logger.info("Backup synchronization aborted by user.")
    return False


def perform_backup_sync(args: argparse.Namespace) -> None:
    """Run the appropriate sync based on CLI arguments."""
    logger.info("Running backup synchronization tasks...")
    if args.mode == "incremental":
        if args.previous_backup is None:
            raise ValueError("Incremental mode requires --previous-backup")
        run_incremental_sync(
            args.source,
            args.destination,
            args.previous_backup,
            verify=args.verify,
        )
    else:
        run_full_sync(args.source, args.destination, verify=args.verify)
    logger.info("Backup synchronization completed successfully.")


def main() -> int:
    configure_logging()
    args = parse_args()

    if not confirm_action(args.yes):
        return 1

    perform_backup_sync(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
