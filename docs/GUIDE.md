# ElderPhoto — Developer Guide

## Overview

ElderPhoto is an accessibility-first family photo platform built for elderly users. The design
prioritises large tap targets, high-contrast colours (primary `#0D47A1` measures 8.63:1 against
white — WCAG AAA), and simple single-purpose screens. Core features include photo upload, a
calendar-based photo browser, a gallery view, and a backup synchronisation tool for mirroring
photos to local directories.

**Architecture:**

| Layer | Technology | Location |
|---|---|---|
| Frontend | React 18, TypeScript, Vite 5, react-calendar, axios | `frontend/` |
| Backend | Python 3.12, FastAPI, uvicorn, python-multipart | `backend/` |
| Testing (FE) | Vitest, @testing-library/react, jest-axe, msw | `frontend/src/__tests__/` |
| Testing (BE) | pytest, pytest-asyncio, httpx | `backend/tests/` |

---

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| Node.js | 20 or later | `node --version` |
| npm | 9 or later (bundled with Node 20) | `npm --version` |
| Python | 3.12 or later | `python3 --version` |
| pip | Bundled with Python 3.12 | `pip --version` |

---

## Install — Frontend

```bash
cd frontend
npm install
```

This installs React 18, react-calendar, axios, Vitest, @testing-library/react, jest-axe (for
accessibility assertions), msw (API mocking), and all other dependencies listed in
`frontend/package.json`.

---

## Install — Backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

`requirements.txt` installs `fastapi`, `uvicorn[standard]`, and `python-multipart` for file
uploads. `requirements-dev.txt` adds `pytest`, `pytest-asyncio`, and `httpx` for testing.

---

## Environment Variables

Copy the example environment file in the project root:

```bash
cp .env.local.example .env.local
```

Edit `.env.local` and fill in the required values. At minimum you will need:

```dotenv
# Backend API base URL as seen by the frontend
VITE_API_BASE_URL=http://localhost:8000

# CORS allowed origins (comma-separated) — used by the FastAPI backend
ALLOWED_ORIGINS=http://localhost:5173
```

The frontend reads variables prefixed with `VITE_` at build time via Vite. The backend reads
`ALLOWED_ORIGINS` at startup.

---

## Running the App

Always start the **backend first** so the frontend can reach the API on load.

### 1. Start the backend

```bash
cd backend
source .venv/bin/activate          # Windows: .venv\Scripts\activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`. Interactive docs (Swagger UI) are at
`http://localhost:8000/docs`.

### 2. Start the frontend (in a separate terminal)

```bash
cd frontend
npm run dev
```

The app will be available at `http://localhost:5173` (Vite default).

---

## Frontend Scripts

Run all frontend scripts from inside the `frontend/` directory.

| Command | Purpose |
|---|---|
| `npm run dev` | Vite dev server with HMR |
| `npm run build` | TypeScript compile + Vite production build to `dist/` |
| `npm test` | Run all Vitest tests once (non-watch) |
| `npm run test:watch` | Vitest in interactive watch mode |
| `npm run test:coverage` | Run tests and generate a coverage report in `coverage/` |

---

## Usage

### Photo upload

Navigate to the **Upload** screen. Select one or more JPEG or PNG files. The upload form sends
files to the backend `POST /photos` endpoint via multipart form data using axios.

### Calendar browsing

The **Calendar** screen uses `react-calendar` to browse photos by date. Selecting a date loads
photos taken on that day from the backend.

### Gallery

The **Gallery** screen shows all photos in a paginated grid. Thumbnail previews are served by
the backend.

### Backup sync

The **Backup** screen allows triggering a local backup synchronisation via the backend's
`/backup` router. This calls `backend/scripts/backup_sync.py` to mirror photos to a configured
destination directory.

> **Known issue:** `backup_sync.py` contains documented bugs (duplicate `main()` definitions,
> missing `sys` and `logging` imports, undefined variables `DEFAULT_PROMPT` and `args.yes`).
> These are tracked in `backend/tests/test_backup_sync.py`. Do not use the backup sync feature
> in production until these bugs are fixed. See the Testing section below.

---

## Testing

### Frontend tests

Run from `frontend/`:

```bash
npm test
```

There are five test files:

| File | What it tests |
|---|---|
| `src/__tests__/api/services.test.ts` | API service layer (axios calls, mocked with msw) |
| `src/__tests__/components/LargeButton.test.tsx` | Accessible button component |
| `src/__tests__/components/PhotoCalendar.test.tsx` | Calendar date-selection behaviour |
| `src/__tests__/components/PhotoUpload.test.tsx` | File selection and upload flow |
| `src/__tests__/components/SidebarNav.test.tsx` | Navigation sidebar rendering and keyboard access |

`jest-axe` is used in component tests to run automated accessibility checks.

### Backend tests

Activate the virtual environment and run from `backend/`:

```bash
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pytest --tb=short
```

There are three test files:

| File | What it tests |
|---|---|
| `tests/test_backup_router.py` | FastAPI `/backup` router endpoints |
| `tests/test_backup_service.py` | Backup service layer logic |
| `tests/test_backup_sync.py` | `scripts/backup_sync.py` functions |

> **Known failures:** Several tests in `test_backup_sync.py` are intentionally designed to
> expose known bugs in `backup_sync.py` (see the module docstring at the top of that file for
> the full list). These tests will fail until the bugs are fixed. This is expected and not a
> setup problem. Do not suppress or skip them — fixing the underlying bugs is a prerequisite
> for production deployment.

---

## Accessibility

ElderPhoto is designed for elderly family members who may have limited technical experience or
visual impairments. Design principles:

- **Large buttons:** All primary actions use the `.btn-primary` class with generous padding
  (`0.75rem 1.25rem`) and a minimum touch target of 44×44px.
- **High contrast:** Primary colour `#0D47A1` with white text achieves 8.63:1 (WCAG AAA).
  Body text uses near-black `#0A0A0A` on white for maximum readability.
- **Simple navigation:** One task per screen. No nested menus or multi-step flows beyond a
  single confirmation.
- **Screen reader support:** All interactive elements have ARIA labels; image thumbnails include
  descriptive `alt` text.

Run a Lighthouse accessibility audit (DevTools > Lighthouse > Accessibility) and aim for a score
of 90 or higher before releasing any UI changes.

---

## Troubleshooting

### CORS errors in the browser console

The FastAPI backend reads the `ALLOWED_ORIGINS` environment variable to configure CORS. Ensure:

1. `.env.local` contains `ALLOWED_ORIGINS=http://localhost:5173` (or your frontend origin).
2. The backend was restarted after changing `.env.local`.
3. For production, replace `localhost:5173` with your actual frontend domain.

### Photos not loading

1. Confirm the backend is running: open `http://localhost:8000/docs` in a browser. If it does
   not load, start the backend with `uvicorn app.main:app --reload --port 8000`.
2. Check the browser Network tab for failed requests to `http://localhost:8000`.
3. Verify `VITE_API_BASE_URL` in `.env.local` matches the port the backend is listening on.

### Backup sync tests fail

This is expected for the tests in `test_backup_sync.py`. The test file documents the specific
bugs in `backup_sync.py` at the top of the file. Read those notes, fix the bugs in
`backend/scripts/backup_sync.py`, and re-run `pytest` to confirm the fixes.

### Frontend build errors

```bash
cd frontend
npm run build
```

TypeScript errors will be reported to the console. Fix all type errors before deploying.

### Python import errors on test run

Ensure you have activated the virtual environment (`source .venv/bin/activate`) before running
`pytest`. Without activation, system Python may lack the required packages.
