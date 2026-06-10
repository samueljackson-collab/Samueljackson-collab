# AI Portfolio Suite — Master Guide

**Samuel Jackson** | samuel.jackson@csuglobal.edu

9 AI-powered web applications built with React 19 + TypeScript + Vite, most leveraging Google Gemini AI. Each app is an independent SPA or full-stack project; this document is the single entry point for understanding or running the entire portfolio.

---

## Suite Overview

| # | App | Category |
|---|-----|----------|
| 1 | Ai-Job-Agent | Career automation — job search, cover letters, interview prep |
| 2 | Secure-Deployer | IT ops — device deployment tracking PWA |
| 3 | BugJaeger | Security — static code scanner, 125 rules, Docker-based |
| 4 | Download-Command-Center | Utilities — AI video download manager with history DB |
| 5 | Tab-Sorter | Productivity — AI browser tab organiser with drag-and-drop |
| 6 | Reportify | Business — enterprise report generator, 21 templates |
| 7 | AstraDup | Media — AI video de-duplication across storage locations |
| 8 | Playbook-Generator | DevOps — AI Ansible playbook generator |
| 9 | ElderPhoto | Accessibility — photo platform for elderly users |

All apps are pure client-side or Node/Python-backed; there is no shared cloud backend.

---

## Quick-Start Table

| App | Description | Tech Stack | Local Port | Gemini Required | Install |
|-----|-------------|------------|------------|-----------------|---------|
| **Ai-Job-Agent** | Job search & AI cover letter generation | React 19, TypeScript, Vite | 3000 | Y | `npm install` |
| **Secure-Deployer** | IT device deployment dashboard (PWA) | React 19, TypeScript, Vite, Recharts | 3000 | N | `npm install` |
| **BugJaeger** | Security code scanner, 125 rules | FastAPI, React 19, TypeScript, Docker Compose, Nginx | 80 | N | `docker compose up` |
| **Download-Command-Center** | AI video download manager + SQLite history | React 19, Express, SQLite, TypeScript | 3000 | Y | `npm install` |
| **Tab-Sorter** | AI browser tab organiser with drag-and-drop | React 19, TypeScript, @dnd-kit, Vite | 3000 | Y | `npm install` |
| **Reportify** | Enterprise report generator, 21 templates, PDF/Word/HTML export | React 19, TypeScript, jsPDF, docx, Vite | 5173 | Y | `npm install` |
| **AstraDup** | AI video de-duplication across storage locations | React 19, TypeScript, @google/genai 0.14, Vite | 5173 | Y | `npm install` |
| **Playbook-Generator** | AI Ansible playbook generator with Git integration | React 19, Express, TypeScript, js-yaml | 3000 | Y | `npm install` |
| **ElderPhoto** | Accessibility-first photo platform | React 19 (frontend, port 5173), FastAPI + Python 3.12 (backend, port 8000) | 5173 / 8000 | Y | `npm install` + `pip install -r requirements.txt` |

---

## Global Prerequisites

Install these once before working with any app in the portfolio.

### Node.js 20+

```bash
# Check current version
node --version   # must be >= 20.0.0

# Install via nvm (recommended)
nvm install 20
nvm use 20
```

Download: https://nodejs.org/en/download

### Python 3.12+ (BugJaeger and ElderPhoto only)

```bash
python3 --version   # must be >= 3.12
```

Download: https://www.python.org/downloads/

### Docker Desktop (BugJaeger only)

BugJaeger uses Docker Compose to run FastAPI + React behind Nginx on port 80.

Download: https://www.docker.com/products/docker-desktop/

### Google Gemini API Key

Required for 7 of the 9 apps. See the next section for how to obtain one.

---

## Getting a Gemini API Key

1. Go to **https://aistudio.google.com**
2. Sign in with a Google account.
3. Click **"Get API key"** in the left sidebar.
4. Click **"Create API key"** and choose a project (or create a new one).
5. Copy the key — it begins with `AIza...`.
6. Keep it private; do not commit it to source control.

**How each app uses the key:**

- Most apps (Ai-Job-Agent, Tab-Sorter, Reportify, AstraDup, Playbook-Generator) prompt for the key on first load and store it in `localStorage`.
- Download-Command-Center uses a `.env` file at the project root: `GEMINI_API_KEY=AIza...`
- ElderPhoto passes the key via environment variable to the FastAPI backend.
- BugJaeger and Secure-Deployer do not use Gemini.

---

## Per-App Quick Start

Each app has a full guide at `docs/GUIDE.md` inside its directory.

### 1. Ai-Job-Agent

```bash
cd /home/user/Ai-Job-Agent
npm install
npm run dev       # http://localhost:3000
```

Full guide: `Ai-Job-Agent/docs/GUIDE.md`

### 2. Secure-Deployer

```bash
cd /home/user/Secure-Deployer
npm install
npm run dev       # http://localhost:3000
```

Full guide: `Secure-Deployer/docs/GUIDE.md`

### 3. BugJaeger

```bash
cd /home/user/BugJaeger
docker compose up --build    # http://localhost:80
```

No API key required. All scanning runs locally inside Docker.

Full guide: `BugJaeger/docs/GUIDE.md`

### 4. Download-Command-Center

```bash
cd /home/user/Download-Command-Center
npm install
cp .env.example .env          # add your GEMINI_API_KEY
npm run dev                   # http://localhost:3000
```

Full guide: `Download-Command-Center/docs/GUIDE.md`

### 5. Tab-Sorter

```bash
cd /home/user/Tab-Sorter
npm install
npm run dev       # http://localhost:3000
```

Full guide: `Tab-Sorter/docs/GUIDE.md`

### 6. Reportify

```bash
cd /home/user/Reportify
npm install
npm run dev       # http://localhost:5173
```

Full guide: `Reportify/docs/GUIDE.md`

### 7. AstraDup

```bash
cd /home/user/AstraDup-Cross-Storage-Video-Files-duplication-tracker
npm install
npm run dev       # http://localhost:5173
```

Note: This app uses `@google/genai` 0.14.0 (legacy API surface), not the `^1.x` version used by most other apps.

Full guide: `AstraDup-Cross-Storage-Video-Files-duplication-tracker/docs/GUIDE.md`

### 8. Playbook-Generator

```bash
cd /home/user/Playbook-Generator
npm install
npm run dev       # http://localhost:3000 (Express + Vite)
```

Full guide: `Playbook-Generator/docs/GUIDE.md`

### 9. ElderPhoto

```bash
# Terminal 1 — backend
cd /home/user/ElderPhoto
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload     # http://localhost:8000

# Terminal 2 — frontend
cd /home/user/ElderPhoto
npm install
npm run dev                   # http://localhost:5173
```

Full guide: `ElderPhoto/docs/GUIDE.md`

---

## USB Launcher

The `USB-Launcher/` package at the repo root provides a single browser window to start, stop, and monitor all 9 apps simultaneously. It also includes tooling to burn the entire portfolio (apps + launcher + all `node_modules`) to a USB drive for offline demos.

### Run all apps from one window

```bash
cd /home/user/USB-Launcher
npm install
npm start         # http://localhost:4000
```

The dashboard shows live status (running / stopped / error) for each app and proxies their URLs for one-click navigation.

### Burn to USB

```bash
cd /home/user/USB-Launcher
npm run burn -- --drive /dev/sdX   # replace /dev/sdX with your USB device
```

This script:
1. Copies all 9 app directories (including installed `node_modules`)
2. Copies the USB-Launcher itself
3. Writes a boot script (`START_ALL.sh` / `START_ALL.bat`) to the root of the drive
4. Creates an `autorun.inf` for Windows auto-launch

---

## Test Coverage Status

| App | Test Framework | Test Files | Approx. Tests | Coverage Threshold |
|-----|---------------|------------|---------------|--------------------|
| Ai-Job-Agent | Vitest + jsdom + Testing Library | `tests/` | ~40 | 70% lines/functions |
| Secure-Deployer | Vitest + jsdom + Testing Library | `src/tests/` | 0 (scaffold only) | 70% lines/functions |
| BugJaeger | Pytest (backend) + Vitest (frontend) | `tests/` | varies | none set |
| Download-Command-Center | Vitest + jsdom + Testing Library | `src/__tests__/` | 0 (scaffold only) | 70% lines/functions |
| Tab-Sorter | Vitest + jsdom + Testing Library | `src/tests/` | varies | none set |
| Reportify | Vitest + jsdom + Testing Library | `src/__tests__/` | 0 (scaffold only) | 70% lines/functions |
| AstraDup | Vitest + jsdom + Testing Library | `src/__tests__/` | 0 (scaffold only) | 70% lines/functions |
| Playbook-Generator | Vitest + jsdom + Testing Library | `src/__tests__/` | 0 (scaffold only) | 70% lines/functions |
| ElderPhoto | Pytest (backend) + Vitest (frontend) | `tests/` | varies | none set |

**Note on apps with scaffold-only tests:** The vitest config and `setup.ts` are in place; test suites need to be written. Run `npm install -D @testing-library/jest-dom @testing-library/react @testing-library/user-event vitest @vitest/coverage-v8 jsdom` in each of those app directories before running tests.

---

## Production Readiness

Each app includes a checklist of steps required before deploying to production.

| App | Checklist |
|-----|-----------|
| Ai-Job-Agent | `Ai-Job-Agent/docs/PRODUCTION_CHECKLIST.md` |
| Secure-Deployer | `Secure-Deployer/docs/PRODUCTION_CHECKLIST.md` |
| BugJaeger | `BugJaeger/docs/PRODUCTION_CHECKLIST.md` |
| Download-Command-Center | `Download-Command-Center/docs/PRODUCTION_CHECKLIST.md` |
| Tab-Sorter | `Tab-Sorter/docs/PRODUCTION_CHECKLIST.md` |
| Reportify | `Reportify/docs/PRODUCTION_CHECKLIST.md` |
| AstraDup | `AstraDup-Cross-Storage-Video-Files-duplication-tracker/docs/PRODUCTION_CHECKLIST.md` |
| Playbook-Generator | `Playbook-Generator/docs/PRODUCTION_CHECKLIST.md` |
| ElderPhoto | `ElderPhoto/docs/PRODUCTION_CHECKLIST.md` |

Common checklist items across all apps:
- Replace localStorage Gemini key storage with a server-side proxy for production (never expose API keys in the browser)
- Set appropriate Content Security Policy headers
- Enable HTTPS (use Netlify, Vercel, or a reverse proxy with Let's Encrypt)
- Run `npm run build` and smoke-test `dist/` before deploying
- Review and pin all dependency versions

---

## Architecture Overview

The portfolio spans three structural patterns:

### Pure SPAs (browser-only, no server process)

**Ai-Job-Agent, Secure-Deployer, Tab-Sorter, Reportify, AstraDup**

- Built with React 19 + TypeScript + Vite
- All state stored in `localStorage`; no backend, no user accounts
- Gemini API calls go directly from the browser using the user-supplied key
- Deploy as static files to any CDN (Netlify, Vercel, GitHub Pages)
- Gemini key is visible in browser DevTools — acceptable for personal/demo use; add a server proxy for production

### SPAs with a Node.js/Express Backend

**Download-Command-Center, Playbook-Generator**

- React frontend (Vite) + Express server in the same repository
- Server handles: SQLite persistence (Download-Command-Center), Git operations and YAML generation (Playbook-Generator)
- Gemini calls may run server-side, keeping the API key out of the browser
- Start with `npm run dev` which launches the Express server (tsx); Vite proxies API requests

### Full-Stack Apps with a Python Backend

**BugJaeger, ElderPhoto**

- React 19 frontend + FastAPI (Python 3.12) backend in the same repository
- BugJaeger: Dockerised — Docker Compose runs FastAPI + React build behind Nginx on port 80; all scanning is local
- ElderPhoto: Run frontend (Vite, port 5173) and backend (uvicorn, port 8000) in separate terminals; Python venv required
- Both expose REST APIs consumed by the React frontend

### Summary

```
Pure SPA          →  Ai-Job-Agent, Secure-Deployer, Tab-Sorter, Reportify, AstraDup
SPA + Node/Express →  Download-Command-Center, Playbook-Generator
SPA + FastAPI/Python → BugJaeger, ElderPhoto
```

All apps share the same frontend foundation: React 19, TypeScript, Vite, and Tailwind CSS (CDN or npm). Testing uses Vitest across the board, with Pytest added for Python backends.
