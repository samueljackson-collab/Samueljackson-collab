#!/usr/bin/env bash
# ==============================================================================
# build-exe.sh — Build all portfolio apps then compile the Electron .exe
# ==============================================================================
# This script:
#   1. Verifies npm is available
#   2. Builds each SPA (npm ci && npm run build) if dist/ is missing or empty
#   3. Notes the TypeScript compilation requirement for node-server apps
#   4. Runs npm ci && npm run build:win inside USB-Launcher/
#   5. Prints the output .exe path
#
# Usage:
#   chmod +x build-exe.sh
#   ./build-exe.sh
#
# Optional env vars:
#   SKIP_BUILD=1   — skip npm build steps (use existing dist/ dirs)
#   WIN_ONLY=1     — build only the Windows target (default)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# -------------------------------------------------------
# Colour helpers
# -------------------------------------------------------
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}[INFO]${RESET}    $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}      $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}    $*"; }
step()    { echo -e "\n${BOLD}${CYAN}>>> $*${RESET}"; }
err_exit(){ echo -e "${RED}[ERROR]${RESET}   $*"; exit 1; }

# -------------------------------------------------------
# 0. Verify npm
# -------------------------------------------------------
step "Checking prerequisites"
if ! command -v npm &>/dev/null; then
    err_exit "npm not found. Install Node.js 20+ from https://nodejs.org"
fi
NPM_VER=$(npm --version)
NODE_VER=$(node --version)
ok "Node.js ${NODE_VER} / npm ${NPM_VER}"

SKIP_BUILD="${SKIP_BUILD:-0}"
if [[ "$SKIP_BUILD" == "1" ]]; then
    warn "SKIP_BUILD=1 — skipping all npm build steps."
fi

# -------------------------------------------------------
# Helper: build a SPA app if dist/ is missing or empty
# -------------------------------------------------------
build_spa() {
    local name="$1" dir="$2" build_cmd="${3:-build}"

    step "SPA: ${name}"

    if [[ ! -d "$dir" ]]; then
        warn "Directory not found: ${dir} — skipping."
        return
    fi

    local dist="${dir}/dist"
    local needs_build=false

    if [[ ! -d "$dist" ]]; then
        needs_build=true
        info "dist/ does not exist — will build."
    elif [[ -z "$(ls -A "$dist" 2>/dev/null)" ]]; then
        needs_build=true
        info "dist/ is empty — will build."
    else
        ok "dist/ already populated — skipping build."
    fi

    if [[ "$SKIP_BUILD" == "1" ]]; then
        needs_build=false
        info "Skipping build (SKIP_BUILD=1)."
    fi

    if [[ "$needs_build" == "true" ]]; then
        info "Running: npm ci && npm run ${build_cmd}  (in ${dir})"
        ( cd "$dir" && npm ci && npm run "$build_cmd" )
        ok "${name} built successfully."
    fi
}

# -------------------------------------------------------
# 1. SPA apps — build if needed
# -------------------------------------------------------
build_spa "Ai-Job-Agent"     "${PARENT_DIR}/Ai-Job-Agent"
build_spa "Secure-Deployer"  "${PARENT_DIR}/Secure-Deployer"
build_spa "Tab-Sorter"       "${PARENT_DIR}/Tab-Sorter"
build_spa "Reportify"        "${PARENT_DIR}/Reportify"
build_spa "AstraDup" \
    "${PARENT_DIR}/AstraDup-Cross-Storage-Video-Files-duplication-tracker"

# -------------------------------------------------------
# 2. Download-Command-Center — SPA build + server note
# -------------------------------------------------------
step "Full-stack: Download-Command-Center"
DCC_DIR="${PARENT_DIR}/Download-Command-Center"

if [[ -d "$DCC_DIR" ]]; then
    # Frontend SPA
    local_dist="${DCC_DIR}/dist"
    if [[ ! -d "$local_dist" || -z "$(ls -A "$local_dist" 2>/dev/null)" ]]; then
        if [[ "$SKIP_BUILD" != "1" ]]; then
            info "Building Download-Command-Center SPA..."
            ( cd "$DCC_DIR" && npm ci && npm run build )
            ok "Download-Command-Center SPA built."
        fi
    else
        ok "Download-Command-Center SPA dist/ already present."
    fi

    # Server-side compiled JS
    local_srv="${DCC_DIR}/dist-server"
    if [[ ! -d "$local_srv" || -z "$(ls -A "$local_srv" 2>/dev/null)" ]]; then
        warn "Download-Command-Center: dist-server/ not found."
        warn "  The server (server.ts) must be compiled to JavaScript."
        warn "  Recommended fix — add this to Download-Command-Center/package.json scripts:"
        warn "    \"build:server\": \"tsc --project tsconfig.server.json\""
        warn "  Then run: cd ${DCC_DIR} && npm run build:server"
        warn "  Until then, the Electron launcher will fall back to running server.ts"
        warn "  directly (requires tsx, which is not bundled in the .exe)."
        warn "  For a standalone .exe, please compile server.ts → dist-server/server.js"
    else
        ok "Download-Command-Center dist-server/ present."
    fi
else
    warn "Download-Command-Center directory not found: ${DCC_DIR}"
fi

# -------------------------------------------------------
# 3. Playbook-Generator — SPA build + server note
# -------------------------------------------------------
step "Full-stack: Playbook-Generator"
PG_DIR="${PARENT_DIR}/Playbook-Generator"

if [[ -d "$PG_DIR" ]]; then
    local_dist="${PG_DIR}/dist"
    if [[ ! -d "$local_dist" || -z "$(ls -A "$local_dist" 2>/dev/null)" ]]; then
        if [[ "$SKIP_BUILD" != "1" ]]; then
            info "Building Playbook-Generator SPA..."
            ( cd "$PG_DIR" && npm ci && npm run build )
            ok "Playbook-Generator SPA built."
        fi
    else
        ok "Playbook-Generator SPA dist/ already present."
    fi

    local_srv="${PG_DIR}/dist-server"
    if [[ ! -d "$local_srv" || -z "$(ls -A "$local_srv" 2>/dev/null)" ]]; then
        warn "Playbook-Generator: dist-server/ not found."
        warn "  server.ts must be compiled to JavaScript for the standalone .exe."
        warn "  Recommended fix — add to Playbook-Generator/package.json scripts:"
        warn "    \"build:server\": \"tsc --project tsconfig.server.json\""
        warn "  Then run: cd ${PG_DIR} && npm run build:server"
    else
        ok "Playbook-Generator dist-server/ present."
    fi
else
    warn "Playbook-Generator directory not found: ${PG_DIR}"
fi

# -------------------------------------------------------
# 4. ElderPhoto frontend SPA
# -------------------------------------------------------
step "SPA: ElderPhoto (frontend)"
EP_FRONTEND="${PARENT_DIR}/Samueljackson-collab/frontend"

if [[ -d "$EP_FRONTEND" ]]; then
    local_dist="${EP_FRONTEND}/dist"
    if [[ ! -d "$local_dist" || -z "$(ls -A "$local_dist" 2>/dev/null)" ]]; then
        if [[ "$SKIP_BUILD" != "1" ]]; then
            info "Building ElderPhoto frontend SPA..."
            ( cd "$EP_FRONTEND" && npm ci && npm run build )
            ok "ElderPhoto frontend built."
        fi
    else
        ok "ElderPhoto frontend dist/ already present."
    fi
else
    warn "ElderPhoto frontend not found: ${EP_FRONTEND}"
fi

# Note: ElderPhoto backend is Python/FastAPI — not built here.
info "ElderPhoto backend (Python/FastAPI) is not pre-built."
info "  The Electron launcher will invoke: python3 -m uvicorn app.main:app ..."
info "  Ensure uvicorn and FastAPI are installed:"
info "    pip install -r ${PARENT_DIR}/Samueljackson-collab/backend/requirements.txt"

# -------------------------------------------------------
# 5. BugJaeger — Docker only, no build step needed here
# -------------------------------------------------------
step "Docker: BugJaeger"
info "BugJaeger uses Docker Compose; no pre-build step required here."
info "  The Electron launcher will run: docker compose up -d --build"
info "  Ensure Docker Desktop is installed on the target machine."
ok "BugJaeger — no action needed."

# -------------------------------------------------------
# 6. Install Electron / electron-builder deps
# -------------------------------------------------------
step "Installing USB-Launcher dependencies"
cd "${SCRIPT_DIR}"

if [[ ! -d "node_modules" || "$SKIP_BUILD" != "1" ]]; then
    info "Running npm ci in ${SCRIPT_DIR}..."
    npm ci
    ok "Dependencies installed."
else
    ok "node_modules already present — skipping npm ci."
fi

# -------------------------------------------------------
# 7. Build the Windows .exe
# -------------------------------------------------------
step "Building Electron Windows .exe"
info "Running: npm run build:win"
npm run build:win

# -------------------------------------------------------
# 8. Report output
# -------------------------------------------------------
DIST_DIR="${SCRIPT_DIR}/dist-electron"
echo ""
echo -e "${BOLD}=====================================================${RESET}"
echo -e "${BOLD} Build complete!${RESET}"
echo -e "${BOLD}=====================================================${RESET}"
echo ""

if [[ -d "$DIST_DIR" ]]; then
    echo "  Output files:"
    find "$DIST_DIR" -maxdepth 2 \( -name "*.exe" -o -name "*.AppImage" -o -name "*.dmg" \) \
        -exec echo "    {}" \;
else
    warn "dist-electron/ directory not found — build may have failed."
fi

echo ""
echo -e "  ${CYAN}Portable .exe:${RESET}"
echo -e "    ${DIST_DIR}/PortfolioLauncher-Portable-1.0.0.exe"
echo ""
echo -e "  ${CYAN}NSIS installer:${RESET}"
echo -e "    ${DIST_DIR}/Portfolio Launcher Setup 1.0.0.exe"
echo ""
echo -e "  ${YELLOW}NOTE:${RESET} The portable .exe embeds all SPA dist/ dirs."
echo -e "  Node-server apps (Download-Command-Center, Playbook-Generator) require"
echo -e "  compiled dist-server/server.js to run standalone. See warnings above."
echo ""
