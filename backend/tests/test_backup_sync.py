"""Tests for backend/scripts/backup_sync.py.

Several of these tests are designed to expose known bugs in the script:
- duplicate main() definitions
- missing `sys` and `logging` imports in module scope
- undefined variables (DEFAULT_PROMPT, args.yes)
"""
import subprocess
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Import individual functions to test them in isolation.
from scripts.backup_sync import (
    parse_args,
    run_full_sync,
    run_incremental_sync,
    run_sync_with_retry,
    verify_sync,
)


# ---------------------------------------------------------------------------
# parse_args
# ---------------------------------------------------------------------------

class TestParseArgs:
    def test_full_sync_defaults(self, tmp_path):
        src = tmp_path / "src"
        dst = tmp_path / "dst"
        args = parse_args.__wrapped__(["str(src)", "str(dst)"]) if hasattr(parse_args, "__wrapped__") else None
        # parse_args uses sys.argv; patch it
        with patch("sys.argv", ["backup_sync.py", str(src), str(dst)]):
            args = parse_args()
        assert args.mode == "full"
        assert args.verify is False
        assert args.previous_backup is None

    def test_incremental_mode_flag(self, tmp_path):
        src = tmp_path / "src"
        dst = tmp_path / "dst"
        prev = tmp_path / "prev"
        with patch(
            "sys.argv",
            [
                "backup_sync.py",
                str(src),
                str(dst),
                "--mode",
                "incremental",
                "--previous-backup",
                str(prev),
            ],
        ):
            args = parse_args()
        assert args.mode == "incremental"
        assert args.previous_backup == prev

    def test_verify_flag(self, tmp_path):
        src = tmp_path / "src"
        dst = tmp_path / "dst"
        with patch("sys.argv", ["backup_sync.py", str(src), str(dst), "--verify"]):
            args = parse_args()
        assert args.verify is True


# ---------------------------------------------------------------------------
# verify_sync
# ---------------------------------------------------------------------------

class TestVerifySync:
    def test_passes_when_no_differences(self, tmp_path):
        mock_result = MagicMock(returncode=0, stdout="", stderr="")
        with patch("subprocess.run", return_value=mock_result) as mock_run:
            verify_sync(tmp_path / "src", tmp_path / "dst")
        mock_run.assert_called_once()
        cmd = mock_run.call_args[0][0]
        assert "--dry-run" in cmd
        assert "--checksum" in cmd

    def test_raises_on_nonzero_return_code(self, tmp_path):
        mock_result = MagicMock(returncode=1, stdout="", stderr="rsync error")
        with patch("subprocess.run", return_value=mock_result):
            with pytest.raises(RuntimeError, match="Verification command failed"):
                verify_sync(tmp_path / "src", tmp_path / "dst")

    def test_raises_when_differences_found(self, tmp_path):
        mock_result = MagicMock(returncode=0, stdout="some/file.jpg\n", stderr="")
        with patch("subprocess.run", return_value=mock_result):
            with pytest.raises(RuntimeError, match="not in sync"):
                verify_sync(tmp_path / "src", tmp_path / "dst")


# ---------------------------------------------------------------------------
# run_full_sync
# ---------------------------------------------------------------------------

class TestRunFullSync:
    def test_calls_rsync_with_delete_flag(self, tmp_path):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            run_full_sync(tmp_path / "src", tmp_path / "dst")
        cmd = mock_run.call_args[0][0]
        assert "rsync" in cmd
        assert "--delete" in cmd

    def test_verify_called_when_flag_set(self, tmp_path):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            with patch("scripts.backup_sync.verify_sync") as mock_verify:
                run_full_sync(tmp_path / "src", tmp_path / "dst", verify=True)
        mock_verify.assert_called_once()

    def test_verify_not_called_by_default(self, tmp_path):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            with patch("scripts.backup_sync.verify_sync") as mock_verify:
                run_full_sync(tmp_path / "src", tmp_path / "dst")
        mock_verify.assert_not_called()

    def test_raises_after_exhausting_retries_on_persistent_failure(self, tmp_path):
        with patch("subprocess.run") as mock_run, patch("scripts.backup_sync.time.sleep"):
            mock_run.return_value = MagicMock(returncode=1)
            with pytest.raises(RuntimeError, match="rsync failed after"):
                run_full_sync(tmp_path / "src", tmp_path / "dst")


# ---------------------------------------------------------------------------
# run_incremental_sync
# ---------------------------------------------------------------------------

class TestRunIncrementalSync:
    def test_includes_link_dest_flag(self, tmp_path):
        prev = tmp_path / "prev"
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            run_incremental_sync(tmp_path / "src", tmp_path / "dst", prev)
        cmd = mock_run.call_args[0][0]
        assert any("--link-dest" in arg for arg in cmd)

    def test_verify_called_when_flag_set(self, tmp_path):
        prev = tmp_path / "prev"
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            with patch("scripts.backup_sync.verify_sync") as mock_verify:
                run_incremental_sync(tmp_path / "src", tmp_path / "dst", prev, verify=True)
        mock_verify.assert_called_once()


# ---------------------------------------------------------------------------
# run_sync_with_retry
# ---------------------------------------------------------------------------

class TestRunSyncWithRetry:
    def test_succeeds_immediately_when_rsync_exits_zero(self):
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            run_sync_with_retry(["rsync", "-a", "src/", "dst/"])
        assert mock_run.call_count == 1

    def test_retries_on_failure_then_succeeds(self):
        with patch("subprocess.run") as mock_run, patch("scripts.backup_sync.time.sleep") as mock_sleep:
            mock_run.side_effect = [MagicMock(returncode=1), MagicMock(returncode=0)]
            run_sync_with_retry(["rsync", "-a", "src/", "dst/"])
        assert mock_run.call_count == 2
        assert mock_sleep.call_count == 1

    def test_raises_runtime_error_after_max_attempts(self):
        with patch("subprocess.run") as mock_run, patch("scripts.backup_sync.time.sleep") as mock_sleep:
            mock_run.return_value = MagicMock(returncode=1)
            with pytest.raises(RuntimeError, match="rsync failed after 3 attempts"):
                run_sync_with_retry(["rsync", "-a", "src/", "dst/"], max_attempts=3, base_delay=0)
        assert mock_run.call_count == 3
        assert mock_sleep.call_count == 2

    def test_backoff_delays_are_exponential(self):
        with patch("subprocess.run") as mock_run, patch("scripts.backup_sync.time.sleep") as mock_sleep:
            mock_run.return_value = MagicMock(returncode=1)
            with pytest.raises(RuntimeError):
                run_sync_with_retry(["rsync"], max_attempts=3, base_delay=1.0)
        delays = [call.args[0] for call in mock_sleep.call_args_list]
        assert delays == [1.0, 2.0]


# ---------------------------------------------------------------------------
# Duplicate main() bug detection
# ---------------------------------------------------------------------------

class TestModuleIntegrity:
    def test_module_has_single_main(self):
        """main() is defined exactly once and takes no positional parameters."""
        import scripts.backup_sync as mod
        import inspect
        sig = inspect.signature(mod.main)
        assert len(sig.parameters) == 0, (
            "main() should take no positional parameters — it reads args via parse_args()."
        )

    def test_module_imports_sys(self):
        """confirm_action() references sys.stdin — verify the import is present."""
        import scripts.backup_sync as mod
        assert hasattr(mod, "sys"), (
            "scripts/backup_sync.py uses sys.stdin but never imports sys"
        )

    def test_module_imports_logging(self):
        """configure_logging() references logging — verify the import is present."""
        import scripts.backup_sync as mod
        assert hasattr(mod, "logging"), (
            "scripts/backup_sync.py calls logging.basicConfig but never imports logging"
        )

    def test_default_prompt_is_defined(self):
        """DEFAULT_PROMPT constant must be defined for confirm_action()."""
        import scripts.backup_sync as mod
        assert hasattr(mod, "DEFAULT_PROMPT"), "DEFAULT_PROMPT constant is missing"
        assert isinstance(mod.DEFAULT_PROMPT, str)

    def test_yes_flag_in_parse_args(self):
        """parse_args() must support --yes/--assume-yes for non-interactive use."""
        with patch("sys.argv", ["backup_sync.py", "/src", "/dst", "--yes"]):
            args = parse_args()
        assert args.yes is True
