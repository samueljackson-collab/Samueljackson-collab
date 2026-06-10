#Requires -Version 5.1
<#
.SYNOPSIS
    Installs ElderPhoto (samueljackson-collab) on Windows.

.DESCRIPTION
    Two-phase installer:
      Phase 1 — Checks Node.js 20+, installs frontend npm dependencies, runs frontend tests
                (non-fatal).
      Phase 2 — Checks Python 3.12+, creates a backend virtual environment, installs pip
                dependencies, runs pytest (non-fatal, warns about known backup_sync failures).
    Also copies .env.local.example to .env.local if neither file exists, then prints start
    commands.

.EXAMPLE
    .\install.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Header { param([string]$m)
    Write-Host ""
    Write-Host $m -ForegroundColor Cyan -BackgroundColor DarkBlue
}
function Write-Info  { param([string]$m) Write-Host "[INFO]  $m" -ForegroundColor Green  }
function Write-Warn  { param([string]$m) Write-Host "[WARN]  $m" -ForegroundColor Yellow }
function Write-Err   { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red    }

# ---------------------------------------------------------------------------
# PHASE 1 — Node.js + Frontend
# ---------------------------------------------------------------------------

function Check-Node {
    Write-Header "Phase 1: Checking Node.js..."

    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Err 'Node.js is not installed or not on PATH.'
        Write-Err 'Install Node.js 20 or later from https://nodejs.org and re-run.'
        exit 1
    }

    $nodeVersion = (node --version).TrimStart('v')
    $nodeMajor   = [int]($nodeVersion.Split('.')[0])

    if ($nodeMajor -lt 20) {
        Write-Err "Node.js $nodeVersion found but version 20 or later is required."
        exit 1
    }

    Write-Info "Node.js $nodeVersion - OK"
    Write-Info "npm $(npm --version) - OK"
}

function Install-Frontend {
    Write-Header "Installing frontend dependencies..."

    $frontendDir = Join-Path $ScriptDir 'frontend'
    if (-not (Test-Path $frontendDir)) {
        Write-Err "frontend\ directory not found at $frontendDir"
        Write-Err 'Run this script from the ElderPhoto project root directory.'
        exit 1
    }

    Push-Location $frontendDir
    try {
        & npm install
        if ($LASTEXITCODE -ne 0) { throw "npm install failed with exit code $LASTEXITCODE" }
        Write-Info 'Frontend dependencies installed.'
    } finally {
        Pop-Location
    }
}

function Verify-Frontend {
    Write-Header "Verifying frontend (running tests)..."
    Write-Warn 'Test failures are non-fatal during install but should be investigated.'

    Push-Location (Join-Path $ScriptDir 'frontend')
    try {
        & npm test -- --run
        if ($LASTEXITCODE -eq 0) {
            Write-Info 'Frontend tests passed.'
        } else {
            Write-Warn 'One or more frontend tests failed. Check the output above.'
            Write-Warn 'Install will continue - address failures before deploying.'
        }
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# PHASE 2 — Python + Backend
# ---------------------------------------------------------------------------

function Check-Python {
    Write-Header "Phase 2: Checking Python..."

    $pythonCmd = $null
    foreach ($cmd in @('python', 'python3')) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            $pyVerStr = (& $cmd --version 2>&1).ToString()
            if ($pyVerStr -match '(\d+)\.(\d+)\.(\d+)') {
                $maj = [int]$Matches[1]
                $min = [int]$Matches[2]
                if ($maj -eq 3 -and $min -ge 12) {
                    $pythonCmd = $cmd
                    $Script:PythonCmd = $cmd
                    Write-Info "Python $($Matches[0]) - OK ($cmd)"
                    break
                }
            }
        }
    }

    if (-not $pythonCmd) {
        Write-Err 'Python 3.12 or later is required but was not found.'
        Write-Err 'Install Python 3.12+ from https://python.org and re-run.'
        exit 1
    }
}

function Install-Backend {
    Write-Header "Setting up backend Python virtual environment..."

    $backendDir = Join-Path $ScriptDir 'backend'
    if (-not (Test-Path $backendDir)) {
        Write-Err "backend\ directory not found at $backendDir"
        Write-Err 'Run this script from the ElderPhoto project root directory.'
        exit 1
    }

    Push-Location $backendDir
    try {
        $venvPath = Join-Path $backendDir '.venv'
        if (-not (Test-Path $venvPath)) {
            Write-Info 'Creating virtual environment...'
            & $Script:PythonCmd -m venv .venv
            if ($LASTEXITCODE -ne 0) { throw "venv creation failed" }
        } else {
            Write-Info 'Virtual environment already exists - skipping creation.'
        }

        $pip = Join-Path $venvPath 'Scripts\pip.exe'

        Write-Info 'Installing runtime dependencies (requirements.txt)...'
        & $pip install --quiet --upgrade pip
        & $pip install --quiet -r requirements.txt
        if ($LASTEXITCODE -ne 0) { throw "pip install requirements.txt failed" }

        Write-Info 'Installing dev/test dependencies (requirements-dev.txt)...'
        & $pip install --quiet -r requirements-dev.txt
        if ($LASTEXITCODE -ne 0) { throw "pip install requirements-dev.txt failed" }

        Write-Info 'Backend dependencies installed.'
        $Script:BackendVenvPython = Join-Path $venvPath 'Scripts\python.exe'
        $Script:BackendVenvPytest  = Join-Path $venvPath 'Scripts\pytest.exe'
    } finally {
        Pop-Location
    }
}

function Verify-Backend {
    Write-Header "Verifying backend (running pytest)..."
    Write-Warn 'Test failures are non-fatal during install but should be investigated.'
    Write-Warn 'NOTE: test_backup_sync.py contains expected failures due to known bugs in'
    Write-Warn 'backend\scripts\backup_sync.py. These must be fixed before deploying.'
    Write-Warn 'See backend\tests\test_backup_sync.py for the full bug list.'

    Push-Location (Join-Path $ScriptDir 'backend')
    try {
        & $Script:BackendVenvPytest --tb=short
        if ($LASTEXITCODE -eq 0) {
            Write-Info 'Backend tests passed.'
        } else {
            Write-Warn 'One or more backend tests failed.'
            Write-Warn 'If failures are only in test_backup_sync.py, these are expected.'
            Write-Warn 'All other failures need investigation before deployment.'
            Write-Warn 'Install will continue.'
        }
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# Environment file
# ---------------------------------------------------------------------------

function Setup-Env {
    Write-Header "Setting up environment file..."

    $envLocal    = Join-Path $ScriptDir '.env.local'
    $envExample  = Join-Path $ScriptDir '.env.local.example'

    if (Test-Path $envLocal) {
        Write-Info '.env.local already exists - skipping.'
    } elseif (Test-Path $envExample) {
        Copy-Item $envExample $envLocal
        Write-Info 'Created .env.local from .env.local.example.'
        Write-Warn 'Edit .env.local and fill in all required values before starting the app.'
    } else {
        Write-Warn '.env.local.example not found. Create .env.local manually with:'
        Write-Host ""
        Write-Host "    VITE_API_BASE_URL=http://localhost:8000" -ForegroundColor DarkCyan
        Write-Host "    ALLOWED_ORIGINS=http://localhost:5173"   -ForegroundColor DarkCyan
        Write-Host ""
    }
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

function Print-Usage {
    Write-Header "Setup complete. How to start the app:"
    Write-Host ""
    Write-Host "  Start the backend first (in one terminal):"
    Write-Host ""
    Write-Host "    cd backend"                                                       -ForegroundColor DarkCyan
    Write-Host "    .venv\Scripts\activate"                                           -ForegroundColor DarkCyan
    Write-Host "    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"        -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Then start the frontend (in a second terminal):"
    Write-Host ""
    Write-Host "    cd frontend"                                                      -ForegroundColor DarkCyan
    Write-Host "    npm run dev"                                                      -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Frontend:      http://localhost:5173"
    Write-Host "  Backend docs:  http://localhost:8000/docs"
    Write-Host ""
    Write-Host "  Frontend test commands (run from frontend\):"
    Write-Host "    npm test                 - run tests once"
    Write-Host "    npm run test:watch       - interactive watch mode"
    Write-Host "    npm run test:coverage    - coverage report in coverage\"
    Write-Host ""
    Write-Host "  Backend test command (run from backend\ with venv active):"
    Write-Host "    pytest --tb=short"
    Write-Host ""
    Write-Host "  Full docs:         docs\GUIDE.md"
    Write-Host "  Pre-deploy checks: docs\PRODUCTION_CHECKLIST.md"
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  ElderPhoto - Installer                           " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# Phase 1
Check-Node
Install-Frontend
Verify-Frontend

# Phase 2
Check-Python
Install-Backend
Verify-Backend

# Env + usage
Setup-Env
Print-Usage
