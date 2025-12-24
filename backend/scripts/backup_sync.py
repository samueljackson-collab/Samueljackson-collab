"""Backup synchronization script with optional verification support."""
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path


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
    subprocess.run(sync_cmd, check=True)

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
    subprocess.run(sync_cmd, check=True)

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
    return parser.parse_args()


def main() -> None:
    args = parse_args()

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


if __name__ == "__main__":
    main()
