"""Tests for backend/app/services/backup_service.py.

These tests:
- Document the NotImplementedError in sync_file_via_rsync (drives implementation)
- Verify sync_backup_file correctly propagates the result
- Verify logging on success and failure
"""
import logging
from unittest.mock import patch

import pytest

from app.services.backup_service import sync_backup_file, sync_file_via_rsync


class TestSyncFileViaRsync:
    def test_raises_not_implemented(self):
        """
        sync_file_via_rsync() currently raises NotImplementedError.
        This test documents the missing implementation.
        When the function is implemented, replace this test with behavioural tests.
        """
        with pytest.raises(NotImplementedError):
            sync_file_via_rsync("/source/photo.jpg", "/backup/photo.jpg")

    def test_signature_accepts_source_and_destination(self):
        """The function signature should accept exactly two string parameters."""
        import inspect
        sig = inspect.signature(sync_file_via_rsync)
        params = list(sig.parameters.keys())
        assert params == ["source", "destination"]


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
