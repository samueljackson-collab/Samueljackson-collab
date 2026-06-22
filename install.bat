@echo off
REM install.bat — ElderPhoto (samueljackson-collab)
REM Two-phase installer: Node.js + frontend, then Python + backend.
REM Usage: install.bat

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
REM Remove trailing backslash
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

echo.
echo ====================================================
echo   ElderPhoto - Installer
echo ====================================================
echo.

REM ============================================================
REM  PHASE 1 -- Node.js + Frontend
REM ============================================================

echo.
echo ---- Phase 1: Node.js and Frontend ----
echo.

REM --- Node.js check ---

echo [INFO]  Checking Node.js...

where node >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js is not installed or not on PATH.
    echo [ERROR] Install Node.js 20 or later from https://nodejs.org and re-run.
    pause
    exit /b 1
)

for /f "tokens=1 delims=v" %%i in ('node --version') do set "NODE_VERSION=%%i"
for /f "tokens=1 delims=." %%m in ('node --version') do (
    set "NODE_MAJOR=%%m"
    set "NODE_MAJOR=!NODE_MAJOR:v=!"
)

if !NODE_MAJOR! LSS 20 (
    echo [ERROR] Node.js !NODE_MAJOR! found but version 20 or later is required.
    echo [ERROR] Download the latest LTS from https://nodejs.org and re-run.
    pause
    exit /b 1
)

for /f %%v in ('node --version') do echo [INFO]  Node.js %%v - OK
for /f %%v in ('npm --version') do echo [INFO]  npm %%v - OK

REM --- Frontend install ---

echo.
echo [INFO]  Installing frontend dependencies...

if not exist "%SCRIPT_DIR%\frontend" (
    echo [ERROR] frontend\ directory not found. Run this script from the project root.
    pause
    exit /b 1
)

cd /d "%SCRIPT_DIR%\frontend"
call npm install
if errorlevel 1 (
    echo [ERROR] npm install failed. Check the output above.
    cd /d "%SCRIPT_DIR%"
    pause
    exit /b 1
)
echo [INFO]  Frontend dependencies installed.

REM --- Frontend test verification ---

echo.
echo [INFO]  Verifying frontend (running tests)...
echo [WARN]  Test failures are non-fatal during install but should be investigated.

call npm test -- --run
if errorlevel 1 (
    echo [WARN]  One or more frontend tests failed. Check the output above.
    echo [WARN]  Install will continue - address test failures before deploying.
) else (
    echo [INFO]  Frontend tests passed.
)

cd /d "%SCRIPT_DIR%"

REM ============================================================
REM  PHASE 2 -- Python + Backend
REM ============================================================

echo.
echo ---- Phase 2: Python and Backend ----
echo.

REM --- Python check ---

echo [INFO]  Checking Python...

where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not on PATH.
    echo [ERROR] Install Python 3.12 or later from https://python.org and re-run.
    pause
    exit /b 1
)

for /f "tokens=2" %%v in ('python --version 2^>^&1') do set "PY_VERSION=%%v"
for /f "tokens=1,2 delims=." %%a in ("%PY_VERSION%") do (
    set "PY_MAJOR=%%a"
    set "PY_MINOR=%%b"
)

if !PY_MAJOR! LSS 3 (
    echo [ERROR] Python !PY_VERSION! found but version 3.12 or later is required.
    pause
    exit /b 1
)
if !PY_MAJOR! EQU 3 if !PY_MINOR! LSS 12 (
    echo [ERROR] Python !PY_VERSION! found but version 3.12 or later is required.
    pause
    exit /b 1
)

echo [INFO]  Python %PY_VERSION% - OK

REM --- Backend venv + deps ---

echo.
echo [INFO]  Setting up backend virtual environment...

if not exist "%SCRIPT_DIR%\backend" (
    echo [ERROR] backend\ directory not found. Run this script from the project root.
    pause
    exit /b 1
)

cd /d "%SCRIPT_DIR%\backend"

if not exist ".venv" (
    echo [INFO]  Creating virtual environment...
    python -m venv .venv
    if errorlevel 1 (
        echo [ERROR] Failed to create virtual environment.
        cd /d "%SCRIPT_DIR%"
        pause
        exit /b 1
    )
) else (
    echo [INFO]  Virtual environment already exists - skipping creation.
)

echo [INFO]  Installing runtime dependencies...
call .venv\Scripts\activate.bat
python -m pip install --quiet --upgrade pip
python -m pip install --quiet -r requirements.txt
if errorlevel 1 (
    echo [ERROR] pip install -r requirements.txt failed.
    cd /d "%SCRIPT_DIR%"
    pause
    exit /b 1
)

echo [INFO]  Installing dev/test dependencies...
python -m pip install --quiet -r requirements-dev.txt
if errorlevel 1 (
    echo [ERROR] pip install -r requirements-dev.txt failed.
    cd /d "%SCRIPT_DIR%"
    pause
    exit /b 1
)

echo [INFO]  Backend dependencies installed.

REM --- Backend test verification ---

echo.
echo [INFO]  Verifying backend (running pytest)...
echo [WARN]  Test failures are non-fatal during install but should be investigated.
echo [WARN]  NOTE: test_backup_sync.py has expected failures due to known bugs in
echo [WARN]  backend\scripts\backup_sync.py. These must be fixed before deploying.

pytest --tb=short
if errorlevel 1 (
    echo [WARN]  One or more backend tests failed.
    echo [WARN]  If failures are only in test_backup_sync.py, these are expected.
    echo [WARN]  All other failures need investigation before deployment.
    echo [WARN]  Install will continue.
) else (
    echo [INFO]  Backend tests passed.
)

cd /d "%SCRIPT_DIR%"

REM ============================================================
REM  Environment file
REM ============================================================

echo.
echo [INFO]  Checking environment file...

if exist "%SCRIPT_DIR%\.env.local" (
    echo [INFO]  .env.local already exists - skipping.
) else if exist "%SCRIPT_DIR%\.env.local.example" (
    copy "%SCRIPT_DIR%\.env.local.example" "%SCRIPT_DIR%\.env.local" >nul
    echo [INFO]  Created .env.local from .env.local.example.
    echo [WARN]  Edit .env.local and fill in all required values before starting the app.
) else (
    echo [WARN]  .env.local.example not found. Create .env.local manually with:
    echo.
    echo             VITE_API_BASE_URL=http://localhost:8000
    echo             ALLOWED_ORIGINS=http://localhost:5173
    echo.
)

REM ============================================================
REM  Usage
REM ============================================================

echo.
echo ====================================================
echo   Setup complete. How to start the app:
echo ====================================================
echo.
echo   Start the backend first (in one terminal):
echo.
echo     cd backend
echo     .venv\Scripts\activate
echo     uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
echo.
echo   Then start the frontend (in a second terminal):
echo.
echo     cd frontend
echo     npm run dev
echo.
echo   Frontend:      http://localhost:5173
echo   Backend docs:  http://localhost:8000/docs
echo.
echo   Frontend test commands (run from frontend\):
echo     npm test                -- run tests once
echo     npm run test:watch      -- interactive watch mode
echo     npm run test:coverage   -- coverage report in coverage\
echo.
echo   Backend test command (run from backend\ with venv active):
echo     pytest --tb=short
echo.
echo   Full docs:         docs\GUIDE.md
echo   Pre-deploy checks: docs\PRODUCTION_CHECKLIST.md
echo.

pause
endlocal
