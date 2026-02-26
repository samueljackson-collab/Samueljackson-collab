import argparse
import logging
import sys


logger = logging.getLogger(__name__)


DEFAULT_PROMPT = "Proceed with backup synchronization? [y/N]: "


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Synchronize backups between storage locations.")
    parser.add_argument(
        "--yes",
        "--assume-yes",
        action="store_true",
        help="Automatically answer yes to confirmation prompts. Required when stdin is not a TTY.",
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


def perform_backup_sync() -> None:
    # Placeholder implementation. Replace with actual backup synchronization logic.
    logger.info("Running backup synchronization tasks...")
    logger.info("Backup synchronization completed successfully.")


def main() -> int:
    configure_logging()
    args = parse_args()

    if not confirm_action(args.yes):
        return 1

    perform_backup_sync()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
