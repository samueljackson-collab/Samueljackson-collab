"""Shared pytest fixtures for the backend test suite."""
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.routers.backup import router as backup_router


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
