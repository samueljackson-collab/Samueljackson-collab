"""In-memory tracking of backup job status.

There is no database in this app (photos are stored as flat files), so job
status is tracked in a simple in-memory dict keyed by job id. This is
sufficient for a single-process deployment; it intentionally does not
survive a process restart or work across multiple worker processes.
"""

import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from threading import Lock
from typing import Literal, Optional

JobStatus = Literal["pending", "running", "success", "failed"]


@dataclass
class BackupJob:
    job_id: str
    status: JobStatus = "pending"
    error: Optional[str] = None
    created_at: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    updated_at: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )

    def to_dict(self) -> dict:
        return {
            "job_id": self.job_id,
            "status": self.status,
            "error": self.error,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
        }


_jobs: dict[str, BackupJob] = {}
_lock = Lock()
_latest_job_id: Optional[str] = None


def create_job() -> BackupJob:
    """Create a new pending job and record it as the most recent one."""
    global _latest_job_id
    job = BackupJob(job_id=uuid.uuid4().hex)
    with _lock:
        _jobs[job.job_id] = job
        _latest_job_id = job.job_id
    return job


def update_job(job_id: str, status: JobStatus, error: Optional[str] = None) -> None:
    """Update an existing job's status (and optional error message)."""
    with _lock:
        job = _jobs.get(job_id)
        if job is None:
            return
        job.status = status
        job.error = error
        job.updated_at = datetime.now(timezone.utc).isoformat()


def get_job(job_id: str) -> Optional[BackupJob]:
    with _lock:
        return _jobs.get(job_id)


def get_latest_job() -> Optional[BackupJob]:
    with _lock:
        if _latest_job_id is None:
            return None
        return _jobs.get(_latest_job_id)


def _reset_for_tests() -> None:
    """Clear all job state. Intended for use in test fixtures only."""
    global _latest_job_id
    with _lock:
        _jobs.clear()
        _latest_job_id = None
