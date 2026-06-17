"""Tests for backend/app/services/backup_service.py.

These tests:
- Verify sync_file_via_rsync calls rsync and returns True/False based on exit code
- Verify sync_backup_file correctly propagates the result
- Verify logging on success and failure
"""
import logging
from unittest.mock import MagicMock, patch

import pytest

from app.services.backup_service import sync_backup_file, sync_file_via_rsync


class TestSyncFileViaRsync:
    def test_returns_true_on_successful_rsync(self):
        """sync_file_via_rsync() returns True when rsync exits with code 0."""
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0)
            result = sync_file_via_rsync("/source/photo.jpg", "/backup/photo.jpg")
        assert result is True
        cmd = mock_run.call_args[0][0]
        assert "rsync" in cmd

    def test_returns_false_on_rsync_failure(self):
        """sync_file_via_rsync() returns False when rsync exits non-zero, after retrying."""
        with patch("subprocess.run") as mock_run, patch(
            "app.services.backup_service.time.sleep"
        ):
            mock_run.return_value = MagicMock(returncode=1)
            result = sync_file_via_rsync("/source/photo.jpg", "/backup/photo.jpg")
        assert result is False

    def test_signature_accepts_source_and_destination(self):
        """The function signature should accept exactly two string parameters."""
        import inspect
        sig = inspect.signature(sync_file_via_rsync)
        params = list(sig.parameters.keys())
        assert params == ["source", "destination"]

    def test_retries_up_to_max_attempts_on_persistent_failure(self):
        """sync_file_via_rsync() retries failed rsync calls up to MAX_SYNC_ATTEMPTS times."""
        from app.services.backup_service import MAX_SYNC_ATTEMPTS

        with patch("subprocess.run") as mock_run, patch(
            "app.services.backup_service.time.sleep"
        ) as mock_sleep:
            mock_run.return_value = MagicMock(returncode=1)
            result = sync_file_via_rsync("/source/photo.jpg", "/backup/photo.jpg")

        assert result is False
        assert mock_run.call_count == MAX_SYNC_ATTEMPTS
        assert mock_sleep.call_count == MAX_SYNC_ATTEMPTS - 1

    def test_recovers_after_transient_failure(self):
        """sync_file_via_rsync() returns True if a later retry succeeds."""
        with patch("subprocess.run") as mock_run, patch(
            "app.services.backup_service.time.sleep"
        ) as mock_sleep:
            mock_run.side_effect = [
                MagicMock(returncode=1),
                MagicMock(returncode=0),
            ]
            result = sync_file_via_rsync("/source/photo.jpg", "/backup/photo.jpg")

        assert result is True
        assert mock_run.call_count == 2
        assert mock_sleep.call_count == 1

    def test_backoff_delay_increases_exponentially(self):
        """Each retry sleep delay should be longer than the previous (exponential backoff)."""
        with patch("subprocess.run") as mock_run, patch(
            "app.services.backup_service.time.sleep"
        ) as mock_sleep:
            mock_run.return_value = MagicMock(returncode=1)
            sync_file_via_rsync("/source/photo.jpg", "/backup/photo.jpg")

        delays = [call.args[0] for call in mock_sleep.call_args_list]
        assert delays == sorted(delays)
        assert len(set(delays)) == len(delays), "Expected strictly increasing delays"


class TestSyncBackupFile:
    def test_returns_true_on_success(self):
        with patch(
            "app.services.backup_service.sync_file_via_rsync", return_value=True
        ):
            result = sync_backup_file("/source/a.jpg", "/backup/a.jpg")
        assert result is True

    def test_returns_false_on_failure(self):
        with patch(
            "app.services.backup_service.sync_file_via_rsync", return_value=False
        ):
            result = sync_backup_file("/source/a.jpg", "/backup/a.jpg")
        assert result is False

    def test_logs_success_at_info(self, caplog):
        with patch(
            "app.services.backup_service.sync_file_via_rsync", return_value=True
        ):
            with caplog.at_level(logging.INFO, logger="app.services.backup_service"):
                sync_backup_file("/source/a.jpg", "/backup/a.jpg")
        assert any("Successfully synced" in r.message for r in caplog.records)

    def test_logs_failure_at_error(self, caplog):
        with patch(
            "app.services.backup_service.sync_file_via_rsync", return_value=False
        ):
            with caplog.at_level(logging.ERROR, logger="app.services.backup_service"):
                sync_backup_file("/source/a.jpg", "/backup/a.jpg")
        assert any("failed" in r.message for r in caplog.records)

    def test_propagates_unexpected_exception(self):
        with patch(
            "app.services.backup_service.sync_file_via_rsync",
            side_effect=RuntimeError("rsync error"),
        ):
            with pytest.raises(RuntimeError, match="rsync error"):
                sync_backup_file("/source/a.jpg", "/backup/a.jpg")
