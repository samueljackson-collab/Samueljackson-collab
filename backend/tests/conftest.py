"""Shared pytest fixtures for the backend test suite."""
import sys
from pathlib import Path

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

# Ensure backend/ is on sys.path so `app.*` and `scripts.*` resolve correctly
_BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(_BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(_BACKEND_ROOT))

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
