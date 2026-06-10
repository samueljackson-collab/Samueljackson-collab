#!/usr/bin/env bash
# install.sh — ElderPhoto (samueljackson-collab)
# Two-phase installer: Node.js + frontend, then Python + backend.
# Usage: bash install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

info()   { echo -e "${GREEN}[INFO]${RESET}  $*"; }
warn()   { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
header() { echo -e "\n${BOLD}$*${RESET}"; }

# ---------------------------------------------------------------------------
# PHASE 1 — Node.js + Frontend
# ---------------------------------------------------------------------------

check_node() {
  header "Phase 1: Checking Node.js..."

  if ! command -v node &>/dev/null; then
    error "Node.js is not installed or not on PATH."
    error "Install Node.js 20 or later from https://nodejs.org and re-run."
    exit 1
  fi

  NODE_VERSION=$(node --version | sed 's/v//')
  NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)

  if [[ "$NODE_MAJOR" -lt 20 ]]; then
    error "Node.js $NODE_VERSION found, but version 20 or later is required."
    exit 1
  fi

  info "Node.js $NODE_VERSION — OK"
  info "npm $(npm --version) — OK"
}

install_frontend() {
  header "Installing frontend dependencies..."

  FRONTEND_DIR="$SCRIPT_DIR/frontend"
  if [[ ! -d "$FRONTEND_DIR" ]]; then
    error "frontend/ directory not found at $FRONTEND_DIR"
    exit 1
  fi

  cd "$FRONTEND_DIR"
  npm install
  info "Frontend dependencies installed."
  cd "$SCRIPT_DIR"
}

verify_frontend() {
  header "Verifying frontend (running tests)..."
  warn "Test failures here are non-fatal during install but should be investigated."

  cd "$SCRIPT_DIR/frontend"
  if npm test -- --run; then
    info "Frontend tests passed."
  else
    warn "One or more frontend tests failed. Check the output above."
    warn "Install will continue — address test failures before deploying."
  fi
  cd "$SCRIPT_DIR"
}

# ---------------------------------------------------------------------------
# PHASE 2 — Python + Backend
# ---------------------------------------------------------------------------

check_python() {
  header "Phase 2: Checking Python..."

  PYTHON_CMD=""
  for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
      PY_VERSION=$("$cmd" --version 2>&1 | awk '{print $2}')
      PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
      PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
      if [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -ge 12 ]]; then
        PYTHON_CMD="$cmd"
        break
      fi
    fi
  done

  if [[ -z "$PYTHON_CMD" ]]; then
    error "Python 3.12 or later is required but was not found."
    error "Install Python 3.12+ from https://python.org and re-run."
    exit 1
  fi

  info "Python $PY_VERSION — OK ($PYTHON_CMD)"
}

install_backend() {
  header "Setting up backend Python virtual environment..."

  BACKEND_DIR="$SCRIPT_DIR/backend"
  if [[ ! -d "$BACKEND_DIR" ]]; then
    error "backend/ directory not found at $BACKEND_DIR"
    exit 1
  fi

  cd "$BACKEND_DIR"

  if [[ ! -d ".venv" ]]; then
    info "Creating virtual environment..."
    "$PYTHON_CMD" -m venv .venv
  else
    info "Virtual environment already exists — skipping creation."
  fi

  # shellcheck disable=SC1091
  source .venv/bin/activate

  info "Installing runtime dependencies (requirements.txt)..."
  pip install --quiet --upgrade pip
  pip install --quiet -r requirements.txt

  info "Installing dev/test dependencies (requirements-dev.txt)..."
  pip install --quiet -r requirements-dev.txt

  info "Backend dependencies installed."
  cd "$SCRIPT_DIR"
}

verify_backend() {
  header "Verifying backend (running pytest)..."
  warn "Test failures here are non-fatal during install but should be investigated."
  warn "NOTE: Several tests in test_backup_sync.py are expected to fail due to"
  warn "known bugs in backend/scripts/backup_sync.py. See that file and"
  warn "backend/tests/test_backup_sync.py for details."

  cd "$SCRIPT_DIR/backend"
  # shellcheck disable=SC1091
  source .venv/bin/activate
  if pytest --tb=short; then
    info "Backend tests passed."
  else
    warn "One or more backend tests failed. If failures are only in test_backup_sync.py,"
    warn "these are expected known-bug failures. All other failures need investigation."
    warn "Install will continue — fix failures before deploying."
  fi
  cd "$SCRIPT_DIR"
}

# ---------------------------------------------------------------------------
# Environment file
# ---------------------------------------------------------------------------

setup_env() {
  header "Setting up environment file..."

  if [[ -f "$SCRIPT_DIR/.env.local" ]]; then
    info ".env.local already exists — skipping."
  elif [[ -f "$SCRIPT_DIR/.env.local.example" ]]; then
    cp "$SCRIPT_DIR/.env.local.example" "$SCRIPT_DIR/.env.local"
    info "Created .env.local from .env.local.example."
    warn "Edit .env.local and fill in all required values before starting the app."
  else
    warn ".env.local.example not found. Create .env.local manually with:"
    echo ""
    echo "    VITE_API_BASE_URL=http://localhost:8000"
    echo "    ALLOWED_ORIGINS=http://localhost:5173"
    echo ""
  fi
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

print_usage() {
  header "Setup complete. How to start the app:"
  echo ""
  echo "  Start the backend first:"
  echo ""
  echo "    cd backend"
  echo "    source .venv/bin/activate"
  echo "    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
  echo ""
  echo "  Then start the frontend (in a separate terminal):"
  echo ""
  echo "    cd frontend"
  echo "    npm run dev"
  echo ""
  echo "  Frontend:      http://localhost:5173"
  echo "  Backend docs:  http://localhost:8000/docs"
  echo ""
  echo "  Frontend test commands (run from frontend/):"
  echo "    npm test              — run tests once"
  echo "    npm run test:watch    — interactive watch mode"
  echo "    npm run test:coverage — coverage report in coverage/"
  echo ""
  echo "  Backend test command (run from backend/ with venv active):"
  echo "    pytest --tb=short"
  echo ""
  echo "  Full docs:         docs/GUIDE.md"
  echo "  Pre-deploy checks: docs/PRODUCTION_CHECKLIST.md"
  echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  echo ""
  echo -e "${BOLD}====================================================${RESET}"
  echo -e "${BOLD}  ElderPhoto — Installer                           ${RESET}"
  echo -e "${BOLD}====================================================${RESET}"

  # Phase 1 — Node / Frontend
  check_node
  install_frontend
  verify_frontend

  # Phase 2 — Python / Backend
  check_python
  install_backend
  verify_backend

  # Environment
  setup_env

  print_usage
}

main "$@"
