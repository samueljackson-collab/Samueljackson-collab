"""Shared pytest fixtures for the backend test suite."""
import importlib

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.routers.backup import router as backup_router
from app.services import backup_jobs


@pytest.fixture(autouse=True)
def _reset_backup_jobs():
    """Ensure in-memory backup job state doesn't leak between tests."""
    backup_jobs._reset_for_tests()
    yield
    backup_jobs._reset_for_tests()


@pytest.fixture()
def app() -> FastAPI:
    """Return a minimal FastAPI application with the backup router mounted."""
    _app = FastAPI()
    _app.include_router(backup_router)
    return _app


@pytest.fixture()
def client(app: FastAPI) -> TestClient:
    """Return a synchronous test client for the app."""
    return TestClient(app)


@pytest.fixture()
def upload_dir(tmp_path, monkeypatch):
    """Point UPLOAD_DIR at a temporary directory and reload the photo/image routers.

    The photos and images routers read UPLOAD_DIR at import time, so we set the
    env var and reload both modules to pick up the temp path.
    """
    monkeypatch.setenv("UPLOAD_DIR", str(tmp_path))

    from app.routers import images as images_module
    from app.routers import photos as photos_module

    importlib.reload(photos_module)
    importlib.reload(images_module)

    yield tmp_path

    # Reload again on teardown so modules go back to picking up real env state
    importlib.reload(photos_module)
    importlib.reload(images_module)


@pytest.fixture()
def photos_app(upload_dir) -> FastAPI:
    """FastAPI app with the photos and images routers mounted, using a temp UPLOAD_DIR."""
    from app.routers import images as images_module
    from app.routers import photos as photos_module

    _app = FastAPI()
    _app.include_router(photos_module.router)
    _app.include_router(images_module.router)
    return _app


@pytest.fixture()
def photos_client(photos_app: FastAPI) -> TestClient:
    """Synchronous test client for the photos/images app."""
    return TestClient(photos_app)
