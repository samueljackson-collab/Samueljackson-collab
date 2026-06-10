#!/usr/bin/env bash
# ==============================================================================
# Portfolio Suite — Bash Launcher (Linux / macOS / WSL, no Electron needed)
# ==============================================================================
# Starts all 9 portfolio apps using Node.js, Python 3, and Docker.
#
# Requirements:
#   - Node.js 20+  (SPA servers + node-server apps)
#   - Python 3.11+ + uvicorn (ElderPhoto backend)
#   - Docker + docker compose v2 (BugJaeger)
#
# Usage:
#   chmod +x start-all.sh
#   ./start-all.sh
#   ./start-all.sh --stop    # Kill all background processes started by this script
# ==============================================================================

set -euo pipefail

# Resolve the real directory of this script regardless of symlinks / cwd
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# PID tracking file for --stop support
PID_FILE="${SCRIPT_DIR}/.launcher-pids"

# -------------------------------------------------------
# Colour helpers
# -------------------------------------------------------
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
ok()    { echo -e "${GREEN}[START]${RESET} $*"; }
err()   { echo -e "${RED}[ERROR]${RESET} $*"; }

# -------------------------------------------------------
# --stop flag: kill previously launched processes
# -------------------------------------------------------
if [[ "${1:-}" == "--stop" ]]; then
    if [[ -f "$PID_FILE" ]]; then
        echo "Stopping all launcher processes..."
        while IFS= read -r pid; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" && echo "  Killed PID $pid"
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
        echo "Done."
    else
        echo "No PID file found at $PID_FILE — nothing to stop."
    fi
    exit 0
fi

# Clear old PID file
> "$PID_FILE"

echo ""
echo -e "${BOLD}=====================================================${RESET}"
echo -e "${BOLD} Samuel Jackson — Portfolio Suite Launcher${RESET}"
echo -e "${BOLD}=====================================================${RESET}"
echo ""

# -------------------------------------------------------
# Prerequisite checks
# -------------------------------------------------------
check_node() {
    if ! command -v node &>/dev/null; then
        err "Node.js not found. Install from https://nodejs.org (v20+ recommended)."
        return 1
    fi
    local ver; ver=$(node --version)
    info "Node.js ${ver} detected."
    return 0
}

check_python() {
    if command -v python3 &>/dev/null; then PYTHON=python3; return 0; fi
    if command -v python  &>/dev/null; then PYTHON=python;  return 0; fi
    warn "Python 3 not found — ElderPhoto backend will not start."
    PYTHON=""
    return 1
}

check_docker() {
    if command -v docker &>/dev/null && docker compose version &>/dev/null 2>&1; then
        return 0
    fi
    return 1
}

NODE_OK=false; check_node  && NODE_OK=true
PYTHON_OK=false; check_python && PYTHON_OK=true

# -------------------------------------------------------
# SPA static server helper (tiny inline Node.js server)
# -------------------------------------------------------
# Usage: serve_spa <APP_NAME> <DIST_DIR> <PORT>
serve_spa() {
    local name="$1" dist="$2" port="$3"

    if [[ ! -f "${dist}/index.html" ]]; then
        warn "${name}: dist not found at ${dist} — run 'npm run build' first."
        return
    fi

    if [[ "$NODE_OK" != "true" ]]; then
        warn "${name}: Node.js unavailable, cannot start static server."
        return
    fi

    # Try npx serve if available for a nicer experience; fall back to inline Node server
    if command -v npx &>/dev/null && npx --yes serve --version &>/dev/null 2>&1; then
        ok "${name} via 'npx serve' on http://localhost:${port}"
        npx serve -s "${dist}" -l "${port}" --no-clipboard \
            > "${SCRIPT_DIR}/.log-${name// /-}.txt" 2>&1 &
    else
        ok "${name} via inline Node HTTP server on http://localhost:${port}"
        node - "${dist}" "${port}" <<'NODE_EOF' \
            > "${SCRIPT_DIR}/.log-${name// /-}.txt" 2>&1 &
const http=require('http'),fs=require('fs'),path=require('path');
const [,, distDir, portStr]=process.argv;
const port=parseInt(portStr,10);
const MIME={'html':'text/html','js':'application/javascript','mjs':'application/javascript',
  'css':'text/css','json':'application/json','png':'image/png','jpg':'image/jpeg',
  'jpeg':'image/jpeg','gif':'image/gif','svg':'image/svg+xml','ico':'image/x-icon',
  'woff':'font/woff','woff2':'font/woff2','webp':'image/webp'};
http.createServer((req,res)=>{
  let p=path.join(distDir,decodeURIComponent(req.url.split('?')[0])||'/');
  if(!fs.existsSync(p)||fs.statSync(p).isDirectory()) p=path.join(distDir,'index.html');
  const ext=path.extname(p).slice(1).toLowerCase();
  res.writeHead(200,{'Content-Type':MIME[ext]||'application/octet-stream'});
  fs.createReadStream(p).pipe(res);
}).listen(port,'127.0.0.1',()=>process.stdout.write(`${path.basename(distDir)} ready http://localhost:${port}\n`));
NODE_EOF
    fi

    local pid=$!
    echo "$pid" >> "$PID_FILE"
    info "${name} PID: ${pid}"
}

# -------------------------------------------------------
# 1. Ai-Job-Agent  (spa-static, port 4001)
# -------------------------------------------------------
serve_spa "Ai-Job-Agent" "${PARENT_DIR}/Ai-Job-Agent/dist" 4001

# -------------------------------------------------------
# 2. Secure-Deployer  (spa-static, port 4002)
# -------------------------------------------------------
serve_spa "Secure-Deployer" "${PARENT_DIR}/Secure-Deployer/dist" 4002

# -------------------------------------------------------
# 3. BugJaeger  (docker, port 80)
# -------------------------------------------------------
BUGJAEGER_DIR="${PARENT_DIR}/BugJaeger"
if check_docker; then
    ok "BugJaeger via docker compose (frontend → http://localhost:80)"
    ( cd "${BUGJAEGER_DIR}" && docker compose up -d --build \
        > "${SCRIPT_DIR}/.log-bugjaeger.txt" 2>&1 ) &
    echo "$!" >> "$PID_FILE"
else
    warn "BugJaeger: Docker / docker compose not available."
    warn "  Install Docker Desktop: https://www.docker.com/products/docker-desktop"
    warn "  Then run: cd ${BUGJAEGER_DIR} && docker compose up -d"
fi

# -------------------------------------------------------
# 4. Download-Command-Center  (node-server, port 4004)
# -------------------------------------------------------
DCC_DIR="${PARENT_DIR}/Download-Command-Center"
if [[ "$NODE_OK" == "true" ]]; then
    # Prefer compiled server.js; fall back to tsx dev server
    if [[ -f "${DCC_DIR}/server.js" ]]; then
        ok "Download-Command-Center (compiled) on http://localhost:4004"
        PORT=4004 node "${DCC_DIR}/server.js" \
            > "${SCRIPT_DIR}/.log-download-command-center.txt" 2>&1 &
        echo "$!" >> "$PID_FILE"
    elif command -v npx &>/dev/null; then
        ok "Download-Command-Center (tsx dev) on http://localhost:4004"
        ( cd "${DCC_DIR}" && PORT=4004 npx tsx server.ts \
            > "${SCRIPT_DIR}/.log-download-command-center.txt" 2>&1 ) &
        echo "$!" >> "$PID_FILE"
    else
        warn "Download-Command-Center: neither server.js nor tsx available."
        warn "  Compile: cd ${DCC_DIR} && npx tsc && node server.js"
    fi
else
    warn "Download-Command-Center: Node.js unavailable."
fi

# -------------------------------------------------------
# 5. Tab-Sorter  (spa-static, port 4005)
# -------------------------------------------------------
serve_spa "Tab-Sorter" "${PARENT_DIR}/Tab-Sorter/dist" 4005

# -------------------------------------------------------
# 6. Reportify  (spa-static, port 4006)
# -------------------------------------------------------
serve_spa "Reportify" "${PARENT_DIR}/Reportify/dist" 4006

# -------------------------------------------------------
# 7. AstraDup  (spa-static, port 4007)
# -------------------------------------------------------
serve_spa "AstraDup" \
    "${PARENT_DIR}/AstraDup-Cross-Storage-Video-Files-duplication-tracker/dist" 4007

# -------------------------------------------------------
# 8. Playbook-Generator  (node-server, port 4008)
# -------------------------------------------------------
PG_DIR="${PARENT_DIR}/Playbook-Generator"
if [[ "$NODE_OK" == "true" ]]; then
    if [[ -f "${PG_DIR}/server.js" ]]; then
        ok "Playbook-Generator (compiled) on http://localhost:4008"
        PORT=4008 node "${PG_DIR}/server.js" \
            > "${SCRIPT_DIR}/.log-playbook-generator.txt" 2>&1 &
        echo "$!" >> "$PID_FILE"
    elif command -v npx &>/dev/null; then
        ok "Playbook-Generator (tsx dev) on http://localhost:4008"
        ( cd "${PG_DIR}" && PORT=4008 npx tsx server.ts \
            > "${SCRIPT_DIR}/.log-playbook-generator.txt" 2>&1 ) &
        echo "$!" >> "$PID_FILE"
    else
        warn "Playbook-Generator: neither server.js nor tsx available."
        warn "  Compile: cd ${PG_DIR} && npx tsc && node server.js"
    fi
else
    warn "Playbook-Generator: Node.js unavailable."
fi

# -------------------------------------------------------
# 9. ElderPhoto  (fullstack — Python backend + SPA frontend)
# -------------------------------------------------------
EP_BACKEND="${PARENT_DIR}/Samueljackson-collab/backend"
EP_FRONTEND_DIST="${PARENT_DIR}/Samueljackson-collab/frontend/dist"

# Backend
if [[ "$PYTHON_OK" == "true" ]]; then
    ok "ElderPhoto backend (uvicorn) on http://localhost:8000"
    CORS_ALLOWED_ORIGINS="http://localhost:4009,http://localhost:3000" \
        ${PYTHON} -m uvicorn app.main:app \
            --host 0.0.0.0 --port 8000 \
            --app-dir "${EP_BACKEND}" \
            > "${SCRIPT_DIR}/.log-elderphoto-backend.txt" 2>&1 &
    echo "$!" >> "$PID_FILE"
else
    warn "ElderPhoto backend: Python 3 unavailable."
    warn "  Install Python 3.11+ and: pip install -r ${EP_BACKEND}/requirements.txt"
fi

# Frontend (SPA)
serve_spa "ElderPhoto-Frontend" "${EP_FRONTEND_DIST}" 4009

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo ""
echo -e "${BOLD}=====================================================${RESET}"
echo -e "${BOLD} All servers started. Open your browser to:${RESET}"
echo -e "${BOLD}=====================================================${RESET}"
echo ""
printf "  %-35s  %s\n" "App" "URL"
printf "  %-35s  %s\n" "-----------------------------------" "----------------------------"
printf "  %-35s  %s\n" "Ai-Job-Agent"              "http://localhost:4001"
printf "  %-35s  %s\n" "Secure-Deployer"           "http://localhost:4002"
printf "  %-35s  %s\n" "BugJaeger (Docker/nginx)"  "http://localhost:80"
printf "  %-35s  %s\n" "Download-Command-Center"   "http://localhost:4004"
printf "  %-35s  %s\n" "Tab-Sorter"                "http://localhost:4005"
printf "  %-35s  %s\n" "Reportify"                 "http://localhost:4006"
printf "  %-35s  %s\n" "AstraDup"                  "http://localhost:4007"
printf "  %-35s  %s\n" "Playbook-Generator"        "http://localhost:4008"
printf "  %-35s  %s\n" "ElderPhoto (frontend)"     "http://localhost:4009"
printf "  %-35s  %s\n" "ElderPhoto (API)"          "http://localhost:8000"
echo ""
echo -e "  ${YELLOW}NOTE:${RESET} Apps requiring a Gemini API key: Ai-Job-Agent, Download-Command-Center,"
echo -e "        Playbook-Generator, Reportify. Set GEMINI_API_KEY env var or enter in-app."
echo ""
echo -e "  ${CYAN}PIDs saved to:${RESET} ${PID_FILE}"
echo -e "  ${CYAN}Stop all:${RESET}      ${SCRIPT_DIR}/start-all.sh --stop"
echo ""
echo -e "  ${CYAN}Log files:${RESET}     ${SCRIPT_DIR}/.log-*.txt"
echo ""
