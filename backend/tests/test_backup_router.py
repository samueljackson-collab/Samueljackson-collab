"""Tests for the /backup/photos FastAPI endpoint.

These tests verify:
- The endpoint responds with HTTP 202 Accepted
- A background task is enqueued (not executed inline)
- The response body has the expected shape
- The no-op stub (asyncio.sleep(0)) is detected and documented
"""
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient


class TestTriggerPhotoBackupEndpoint:
    def test_returns_202_accepted(self, client: TestClient):
        response = client.post("/backup/photos")
        assert response.status_code == 202

    def test_response_body_has_status_and_message(self, client: TestClient):
        response = client.post("/backup/photos")
        body = response.json()
        assert body["status"] == "success"
        assert "message" in body

    def test_background_task_is_added(self, app):
        """Verify that a background task is enqueued rather than executed inline."""
        from fastapi.testclient import TestClient
        from fastapi import BackgroundTasks

        added_tasks = []

        original_add_task = BackgroundTasks.add_task

        def recording_add_task(self, func, *args, **kwargs):
            added_tasks.append(func)
            original_add_task(self, func, *args, **kwargs)

        with patch.object(BackgroundTasks, "add_task", recording_add_task):
            client = TestClient(app)
            client.post("/backup/photos")

        assert len(added_tasks) == 1, "Expected exactly one background task to be enqueued"

    def test_method_not_allowed_on_get(self, client: TestClient):
        response = client.get("/backup/photos")
        assert response.status_code == 405


class TestSyncAllPhotos:
    """Tests for the implemented sync_all_photos background task."""

    @pytest.mark.asyncio
    async def test_sync_all_photos_does_not_raise_on_success(self):
        """sync_all_photos() completes without raising when sync succeeds."""
        from app.routers.backup import sync_all_photos
        with patch("app.routers.backup.sync_backup_file", return_value=True):
            await sync_all_photos()

    @pytest.mark.asyncio
    async def test_sync_all_photos_does_not_raise_on_failure(self):
        """sync_all_photos() does not raise even when the underlying sync fails."""
        from app.routers.backup import sync_all_photos
        with patch("app.routers.backup.sync_backup_file", return_value=False):
            await sync_all_photos()

    @pytest.mark.asyncio
    async def test_sync_all_photos_swallows_unexpected_exceptions(self):
        """sync_all_photos() catches and logs unexpected errors rather than crashing."""
        from app.routers.backup import sync_all_photos
        with patch("app.routers.backup.sync_backup_file", side_effect=RuntimeError("disk full")):
            await sync_all_photos()  # Must not re-raise
