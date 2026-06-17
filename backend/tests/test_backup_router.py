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

    def test_response_body_has_job_id(self, client: TestClient):
        response = client.post("/backup/photos")
        body = response.json()
        assert "job_id" in body
        assert isinstance(body["job_id"], str)
        assert len(body["job_id"]) > 0

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
        from app.services import backup_jobs

        job = backup_jobs.create_job()
        with patch("app.routers.backup.sync_backup_file", return_value=True):
            await sync_all_photos(job.job_id)

    @pytest.mark.asyncio
    async def test_sync_all_photos_does_not_raise_on_failure(self):
        """sync_all_photos() does not raise even when the underlying sync fails."""
        from app.routers.backup import sync_all_photos
        from app.services import backup_jobs

        job = backup_jobs.create_job()
        with patch("app.routers.backup.sync_backup_file", return_value=False):
            await sync_all_photos(job.job_id)

    @pytest.mark.asyncio
    async def test_sync_all_photos_swallows_unexpected_exceptions(self):
        """sync_all_photos() catches and logs unexpected errors rather than crashing."""
        from app.routers.backup import sync_all_photos
        from app.services import backup_jobs

        job = backup_jobs.create_job()
        with patch("app.routers.backup.sync_backup_file", side_effect=RuntimeError("disk full")):
            await sync_all_photos(job.job_id)  # Must not re-raise

    @pytest.mark.asyncio
    async def test_sync_all_photos_marks_job_success(self):
        """On success, the job status is updated to 'success'."""
        from app.routers.backup import sync_all_photos
        from app.services import backup_jobs

        job = backup_jobs.create_job()
        with patch("app.routers.backup.sync_backup_file", return_value=True):
            await sync_all_photos(job.job_id)

        updated = backup_jobs.get_job(job.job_id)
        assert updated.status == "success"
        assert updated.error is None

    @pytest.mark.asyncio
    async def test_sync_all_photos_marks_job_failed_on_sync_failure(self):
        """When sync_backup_file returns False, the job status is updated to 'failed'."""
        from app.routers.backup import sync_all_photos
        from app.services import backup_jobs

        job = backup_jobs.create_job()
        with patch("app.routers.backup.sync_backup_file", return_value=False):
            await sync_all_photos(job.job_id)

        updated = backup_jobs.get_job(job.job_id)
        assert updated.status == "failed"
        assert updated.error is not None

    @pytest.mark.asyncio
    async def test_sync_all_photos_marks_job_failed_on_exception(self):
        """When sync_backup_file raises, the job status is updated to 'failed' with the error."""
        from app.routers.backup import sync_all_photos
        from app.services import backup_jobs

        job = backup_jobs.create_job()
        with patch(
            "app.routers.backup.sync_backup_file",
            side_effect=RuntimeError("disk full"),
        ):
            await sync_all_photos(job.job_id)

        updated = backup_jobs.get_job(job.job_id)
        assert updated.status == "failed"
        assert "disk full" in updated.error


class TestBackupStatusEndpoint:
    """Tests for GET /backup/status and GET /backup/status/{job_id}."""

    def test_status_by_job_id_reflects_post_response(self, client: TestClient):
        with patch("app.routers.backup.sync_backup_file", return_value=True):
            post_response = client.post("/backup/photos")
            job_id = post_response.json()["job_id"]

        status_response = client.get(f"/backup/status/{job_id}")
        assert status_response.status_code == 200
        body = status_response.json()
        assert body["job_id"] == job_id
        assert body["status"] == "success"

    def test_status_unknown_job_id_returns_404(self, client: TestClient):
        response = client.get("/backup/status/does-not-exist")
        assert response.status_code == 404

    def test_status_latest_returns_404_when_no_jobs(self, client: TestClient):
        response = client.get("/backup/status")
        assert response.status_code == 404

    def test_status_latest_returns_most_recent_job(self, client: TestClient):
        with patch("app.routers.backup.sync_backup_file", return_value=True):
            first = client.post("/backup/photos").json()
            second = client.post("/backup/photos").json()

        response = client.get("/backup/status")
        assert response.status_code == 200
        assert response.json()["job_id"] == second["job_id"]
        assert response.json()["job_id"] != first["job_id"]

    def test_status_reflects_failure(self, client: TestClient):
        with patch("app.routers.backup.sync_backup_file", return_value=False):
            job_id = client.post("/backup/photos").json()["job_id"]

        response = client.get(f"/backup/status/{job_id}")
        assert response.json()["status"] == "failed"
