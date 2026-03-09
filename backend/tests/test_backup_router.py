"""Tests for the /backup/photos FastAPI endpoint.

These tests verify:
- The endpoint responds with HTTP 202 Accepted
- A background task is enqueued (not executed inline)
- The response body has the expected shape
- The no-op stub (asyncio.sleep(0)) is detected and documented
"""
import asyncio
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


class TestSyncAllPhotosStub:
    """Document and detect the no-op placeholder implementation."""

    @pytest.mark.asyncio
    async def test_sync_all_photos_is_a_noop(self):
        """
        sync_all_photos() currently does nothing (asyncio.sleep(0)).
        This test documents the placeholder and will guide a real implementation.
        """
        from app.routers.backup import sync_all_photos
        import inspect

        source = inspect.getsource(sync_all_photos)
        assert "asyncio.sleep(0)" in source, (
            "sync_all_photos() is expected to be a no-op placeholder. "
            "If this assertion fails the implementation has been updated — "
            "remove or update this test accordingly."
        )

    @pytest.mark.asyncio
    async def test_sync_all_photos_does_not_raise(self):
        """The stub must not raise even though it does nothing."""
        from app.routers.backup import sync_all_photos
        await sync_all_photos()  # Should complete without error
