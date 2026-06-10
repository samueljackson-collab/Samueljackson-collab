#!/usr/bin/env bash
# ==============================================================================
# create-usb-image.sh — Package the built launcher into a bootable ISO or
#                        copy files ready for a Ventoy USB drive.
# ==============================================================================
#
# What this script does:
#   1. Checks for genisoimage or mkisofs
#   2. Creates /tmp/usb-staging/
#   3. Copies the built .exe from dist-electron/ into staging
#   4. Copies start-all.bat and start-all.sh into staging
#   5. Documents the portable Node.js download URL (skips actual download)
#   6. Creates README.txt with quick-start instructions
#   7. Creates AUTORUN.INF for legacy Windows AutoPlay
#   8. Option A: runs genisoimage to produce portfolio-suite.iso
#   9. Prints instructions for both Ventoy and dd
#
# Usage:
#   chmod +x create-usb-image.sh
#   ./create-usb-image.sh
#
# Requirements (Option A only):
#   genisoimage  — sudo apt install genisoimage   (Debian/Ubuntu)
#              OR  mkisofs (aliased as genisoimage on some distros)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist-electron"
STAGING="/tmp/usb-staging"
ISO_OUT="${SCRIPT_DIR}/portfolio-suite.iso"
LAUNCHER_VERSION="1.0.0"
PORTABLE_EXE="PortfolioLauncher-Portable-${LAUNCHER_VERSION}.exe"

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

echo ""
echo -e "${BOLD}=====================================================${RESET}"
echo -e "${BOLD} Portfolio Suite — USB Image Creator${RESET}"
echo -e "${BOLD}=====================================================${RESET}"
echo ""

# -------------------------------------------------------
# 1. Check for ISO creation tool
# -------------------------------------------------------
step "Checking for ISO creation tool"
ISO_TOOL=""
if command -v genisoimage &>/dev/null; then
    ISO_TOOL="genisoimage"
    ok "genisoimage found."
elif command -v mkisofs &>/dev/null; then
    ISO_TOOL="mkisofs"
    ok "mkisofs found."
else
    warn "Neither genisoimage nor mkisofs found."
    warn "  Install on Debian/Ubuntu: sudo apt install genisoimage"
    warn "  Install on Fedora/RHEL:   sudo dnf install genisoimage"
    warn "  ISO creation will be skipped; Ventoy copy instructions will still be shown."
fi

# -------------------------------------------------------
# 2. Create staging directory
# -------------------------------------------------------
step "Creating staging directory at ${STAGING}"
rm -rf "$STAGING"
mkdir -p "${STAGING}"
ok "Staging directory ready."

# -------------------------------------------------------
# 3. Copy the built .exe
# -------------------------------------------------------
step "Copying built .exe to staging"
if [[ -f "${DIST_DIR}/${PORTABLE_EXE}" ]]; then
    cp "${DIST_DIR}/${PORTABLE_EXE}" "${STAGING}/"
    ok "Copied ${PORTABLE_EXE}"
else
    warn "${PORTABLE_EXE} not found in ${DIST_DIR}/"
    warn "  Run ./build-exe.sh first to compile the Electron app."
    warn "  Continuing without .exe (README and scripts will still be staged)."
fi

# Also copy NSIS installer if present
NSIS_EXE="Portfolio Launcher Setup ${LAUNCHER_VERSION}.exe"
if [[ -f "${DIST_DIR}/${NSIS_EXE}" ]]; then
    cp "${DIST_DIR}/${NSIS_EXE}" "${STAGING}/"
    ok "Copied NSIS installer: ${NSIS_EXE}"
fi

# -------------------------------------------------------
# 4. Copy start-all scripts
# -------------------------------------------------------
step "Copying launcher scripts"
cp "${SCRIPT_DIR}/start-all.bat" "${STAGING}/"
cp "${SCRIPT_DIR}/start-all.sh"  "${STAGING}/"
ok "start-all.bat and start-all.sh copied."

# -------------------------------------------------------
# 5. Document portable Node.js download (skip actual download)
# -------------------------------------------------------
step "Portable Node.js v20 LTS — documentation only"
NODE_VERSION="v20.18.0"
NODE_WIN_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-win-x64.zip"
NODE_LIN_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-x64.tar.xz"
NODE_MAC_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-darwin-x64.tar.gz"

info "Portable Node.js download URLs (not downloaded automatically):"
info "  Windows:  ${NODE_WIN_URL}"
info "  Linux:    ${NODE_LIN_URL}"
info "  macOS:    ${NODE_MAC_URL}"
info ""
info "REASON: Node.js archives are ~25–40 MB each. Downloading them automatically"
info "        would add significant time and bandwidth to every build."
info "        To include them in the USB image, run these commands manually:"
info ""
info "  cd ${STAGING}"
info "  curl -LO '${NODE_WIN_URL}'"
info "  curl -LO '${NODE_LIN_URL}'"
info "  # Then re-run this script with ISO_ONLY=1"

# Create a note file in staging
cat > "${STAGING}/NODEJS_DOWNLOAD.txt" <<EOF
Portable Node.js v20 LTS — Download Links
==========================================

The start-all.bat and start-all.sh scripts require Node.js to be installed
on the host machine. If running from a USB on a machine without Node.js,
download the portable version from one of these URLs:

Windows x64:  ${NODE_WIN_URL}
Linux x64:    ${NODE_LIN_URL}
macOS x64:    ${NODE_MAC_URL}

After downloading, extract the archive to a 'node-portable/' folder on the
USB drive and update start-all.bat / start-all.sh to use the bundled node
binary instead of the system-wide 'node' command:

  Windows: set NODE_EXE=%APP_DIR%node-portable\node.exe
  Bash:    NODE_EXE="\${SCRIPT_DIR}/node-portable/bin/node"
EOF
ok "Created NODEJS_DOWNLOAD.txt in staging."

# -------------------------------------------------------
# 6. Create README.txt
# -------------------------------------------------------
step "Creating README.txt"
cat > "${STAGING}/README.txt" <<EOF
=======================================================
 Samuel Jackson — Portfolio Suite USB Launcher v${LAUNCHER_VERSION}
=======================================================

CONTENTS
--------
  PortfolioLauncher-Portable-${LAUNCHER_VERSION}.exe  — Windows standalone launcher (no install)
  Portfolio Launcher Setup ${LAUNCHER_VERSION}.exe      — Windows NSIS installer
  start-all.bat                                 — Windows batch fallback launcher
  start-all.sh                                  — Linux/macOS bash fallback launcher
  NODEJS_DOWNLOAD.txt                           — Portable Node.js download links
  AUTORUN.INF                                   — Windows AutoPlay config

THE APPS (9 total)
------------------
  App                         Port   Description
  --------------------------  -----  ------------------------------------------
  Ai-Job-Agent                4001   AI-powered job application automation
  Secure-Deployer             4002   Deployment management with RBAC
  BugJaeger                   80     Bug tracker (requires Docker Desktop)
  Download-Command-Center     4004   AI download queue manager
  Tab-Sorter                  4005   Browser tab organisation
  Reportify                   4006   AI report generator
  AstraDup                    4007   Video file deduplication tracker
  Playbook-Generator          4008   Ansible playbook AI generator
  ElderPhoto                  4009   Accessibility-first photo platform

QUICK START — ELECTRON LAUNCHER (recommended)
---------------------------------------------
1. Double-click PortfolioLauncher-Portable-${LAUNCHER_VERSION}.exe
2. Enter your Google Gemini API key in the header (required for AI-powered apps)
3. Wait ~10–30 seconds for all servers to start (status dots turn green)
4. Click the "Launch" button on any card to open the app in your browser

QUICK START — BATCH / BASH FALLBACK (no Electron)
--------------------------------------------------
Windows:
  1. Double-click start-all.bat
  2. Follow any on-screen prompts
  3. Visit http://localhost:4001 etc. in your browser

Linux/macOS:
  1. Open a terminal in this directory
  2. chmod +x start-all.sh && ./start-all.sh
  3. Visit http://localhost:4001 etc.
  4. To stop all: ./start-all.sh --stop

REQUIREMENTS
------------
- Windows 10/11 x64, Linux x64, or macOS 12+ (for .exe: Windows only)
- Node.js 20+ (for batch/bash fallback and node-server apps)
- Python 3.11+ with uvicorn (for ElderPhoto backend)
- Docker Desktop (for BugJaeger only)

GEMINI API KEY
--------------
Apps that require a Gemini API key:
  - Ai-Job-Agent
  - Download-Command-Center
  - Playbook-Generator
  - Reportify

Get a free key at https://aistudio.google.com/app/apikey

SUPPORT
-------
Portfolio by Samuel Jackson
Email: samuel.jackson@csuglobal.edu

=======================================================
EOF
ok "README.txt created."

# -------------------------------------------------------
# 7. Create AUTORUN.INF
# -------------------------------------------------------
step "Creating AUTORUN.INF"
cat > "${STAGING}/AUTORUN.INF" <<EOF
[AutoRun]
open=PortfolioLauncher-Portable-${LAUNCHER_VERSION}.exe
icon=PortfolioLauncher-Portable-${LAUNCHER_VERSION}.exe,0
label=Portfolio Suite Launcher
action=Launch Samuel Jackson's Portfolio Suite

[AutoRun.Amd64]
open=PortfolioLauncher-Portable-${LAUNCHER_VERSION}.exe
icon=PortfolioLauncher-Portable-${LAUNCHER_VERSION}.exe,0
EOF
ok "AUTORUN.INF created."

# -------------------------------------------------------
# 8. Option A: Create ISO with genisoimage / mkisofs
# -------------------------------------------------------
step "Creating ISO image (Option A)"
if [[ -n "$ISO_TOOL" ]]; then
    info "Running ${ISO_TOOL} to create ${ISO_OUT} ..."
    $ISO_TOOL \
        -o "${ISO_OUT}" \
        -V "PORTFOLIO_LAUNCHER" \
        -J \
        -r \
        -l \
        -joliet-long \
        "${STAGING}"
    ok "ISO created: ${ISO_OUT}"
    ISO_SIZE=$(du -sh "${ISO_OUT}" | cut -f1)
    info "ISO size: ${ISO_SIZE}"
else
    warn "ISO creation skipped (no ISO tool available)."
    warn "  Install genisoimage and re-run this script."
fi

# -------------------------------------------------------
# 9. Print deployment instructions
# -------------------------------------------------------
echo ""
echo -e "${BOLD}=====================================================${RESET}"
echo -e "${BOLD} Deployment Instructions${RESET}"
echo -e "${BOLD}=====================================================${RESET}"
echo ""

echo -e "${BOLD}Option 1 — Ventoy USB (recommended):${RESET}"
echo "  Ventoy creates a multi-boot USB from a single formatted drive."
echo "  1. Download Ventoy: https://www.ventoy.net/en/download.html"
echo "  2. Run Ventoy2Disk.exe (Windows) or Ventoy2Disk.sh (Linux)"
echo "     and select your USB drive."
echo "  3. Copy the portable .exe directly to the USB partition:"
echo ""
echo "     cp \"${STAGING}/${PORTABLE_EXE}\" /media/\$USER/Ventoy/"
echo ""
echo "  4. Also copy the fallback scripts for non-Windows machines:"
echo "     cp \"${STAGING}/start-all.sh\" /media/\$USER/Ventoy/"
echo "     cp \"${STAGING}/start-all.bat\" /media/\$USER/Ventoy/"
echo ""
echo "  5. Boot the target machine from USB and select the .exe in Ventoy menu."
echo ""

if [[ -f "$ISO_OUT" ]]; then
    echo -e "${BOLD}Option 2 — dd / Rufus (ISO → USB):${RESET}"
    echo "  WARNING: This will ERASE all data on the target USB drive."
    echo ""
    echo "  Linux (replace /dev/sdX with your USB device — verify with lsblk!):"
    echo "    sudo dd if=\"${ISO_OUT}\" of=/dev/sdX bs=4M status=progress oflag=sync"
    echo ""
    echo "  Windows — use Rufus:"
    echo "    1. Download Rufus: https://rufus.ie"
    echo "    2. Select ${ISO_OUT} as the image"
    echo "    3. Select your USB drive and click START"
    echo ""
    echo "  macOS:"
    echo "    diskutil list                    # find your USB (e.g. /dev/disk2)"
    echo "    diskutil unmountDisk /dev/disk2"
    echo "    sudo dd if=\"${ISO_OUT}\" of=/dev/rdisk2 bs=4m"
    echo ""
fi

echo -e "${BOLD}Staging directory:${RESET} ${STAGING}"
if [[ -f "$ISO_OUT" ]]; then
    echo -e "${BOLD}ISO file:${RESET}          ${ISO_OUT}"
fi
echo ""
echo -e "${GREEN}Done.${RESET}"
