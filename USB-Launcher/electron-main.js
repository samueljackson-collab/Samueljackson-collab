'use strict';

const { app, BrowserWindow, ipcMain, shell } = require('electron');
const path = require('path');
const http = require('http');
const net = require('net');
const { spawn, spawnSync } = require('child_process');
const fs = require('fs');
const Store = require('electron-store');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const store = new Store({ name: 'portfolio-launcher' });

const CONFIG_PATH = path.join(__dirname, 'apps-config.json');
const appsConfig = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));

// ---------------------------------------------------------------------------
// Path resolution strategy
// ---------------------------------------------------------------------------
// In development (npm start):
//   __dirname                   = /home/user/USB-Launcher
//   paths like ../Ai-Job-Agent  resolve correctly relative to __dirname
//
// In a packed Electron app (electron-builder):
//   __dirname                   = <app>/resources/app.asar (or app/)
//   extraResources land at      = <app>/resources/apps/<id>/dist
//   process.resourcesPath       = <app>/resources
//
// We detect the packed state by checking app.isPackaged, then remap the
// relative paths (../Foo/dist) to their extraResources equivalents.
// The mapping is: "../Ai-Job-Agent/dist" → process.resourcesPath/apps/ai-job-agent/dist
// This matches exactly what is declared in package.json build.extraResources.

const PACKED_RESOURCE_MAP = {
  '../Ai-Job-Agent/dist':                                              'apps/ai-job-agent/dist',
  '../Secure-Deployer/dist':                                           'apps/secure-deployer/dist',
  '../Tab-Sorter/dist':                                                'apps/tab-sorter/dist',
  '../Reportify/dist':                                                 'apps/reportify/dist',
  '../AstraDup-Cross-Storage-Video-Files-duplication-tracker/dist':    'apps/astradup/dist',
  '../Download-Command-Center':                                        'apps/download-command-center',
  '../Playbook-Generator':                                             'apps/playbook-generator',
  '../BugJaeger/docker-compose.yml':                                   'apps/bugjaeger/docker-compose.yml',
  '../BugJaeger':                                                      'apps/bugjaeger',
  '../Samueljackson-collab/frontend':                                  'apps/elderphoto/frontend',
  '../Samueljackson-collab/backend':                                   'apps/elderphoto/backend',
};

function resolveAppPath(relPath) {
  if (app.isPackaged) {
    const key = relPath.replace(/\\/g, '/');
    if (PACKED_RESOURCE_MAP[key]) {
      return path.join(process.resourcesPath, PACKED_RESOURCE_MAP[key]);
    }
    // Fallback: resolve relative to process.resourcesPath
    return path.resolve(process.resourcesPath, relPath);
  }
  // Dev mode: resolve relative to USB-Launcher directory (__dirname)
  return path.resolve(__dirname, relPath);
}

// Resolve relative distDir / serverDir / etc.
appsConfig.apps = appsConfig.apps.map((appEntry) => {
  const resolved = { ...appEntry };
  if (appEntry.distDir)     resolved.distDir     = resolveAppPath(appEntry.distDir);
  if (appEntry.serverDir)   resolved.serverDir   = resolveAppPath(appEntry.serverDir);
  if (appEntry.composeFile) resolved.composeFile = resolveAppPath(appEntry.composeFile);
  if (appEntry.frontendDir) resolved.frontendDir = resolveAppPath(appEntry.frontendDir);
  if (appEntry.backendDir)  resolved.backendDir  = resolveAppPath(appEntry.backendDir);
  return resolved;
});

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/** @type {Map<string, import('child_process').ChildProcess | { type: 'http-server', server: import('http').Server }>} */
const childProcesses = new Map();

/** @type {Map<string, number>} appId → actual running port */
const actualPorts = new Map();

/** @type {Map<string, string[]>} appId → last N log lines */
const appLogs = new Map();

const MAX_LOG_LINES = 200;

/** @type {BrowserWindow | null} */
let mainWindow = null;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function appendLog(appId, line) {
  if (!appLogs.has(appId)) appLogs.set(appId, []);
  const lines = appLogs.get(appId);
  lines.push(line);
  if (lines.length > MAX_LOG_LINES) lines.splice(0, lines.length - MAX_LOG_LINES);
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('app-log', { id: appId, line });
  }
}

function sendStatus(appId, status, port) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('app-status', { id: appId, status, port: port || actualPorts.get(appId) || null });
  }
}

// ---------------------------------------------------------------------------
// Port utilities
// ---------------------------------------------------------------------------

/**
 * Try to bind a TCP server on `port`. Resolve true if free, false otherwise.
 * @param {number} port
 * @returns {Promise<boolean>}
 */
function isPortFree(port) {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.once('error', () => resolve(false));
    server.once('listening', () => {
      server.close(() => resolve(true));
    });
    server.listen(port, '127.0.0.1');
  });
}

/**
 * Find a free port starting at `preferred`, trying up to +20.
 * @param {number} preferred
 * @returns {Promise<number>}
 */
async function findFreePort(preferred) {
  for (let offset = 0; offset <= 20; offset++) {
    if (await isPortFree(preferred + offset)) {
      return preferred + offset;
    }
  }
  throw new Error(`No free port found near ${preferred}`);
}

// ---------------------------------------------------------------------------
// MIME types for static server
// ---------------------------------------------------------------------------

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript; charset=utf-8',
  '.mjs':  'application/javascript; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif':  'image/gif',
  '.svg':  'image/svg+xml',
  '.ico':  'image/x-icon',
  '.woff': 'font/woff',
  '.woff2':'font/woff2',
  '.ttf':  'font/ttf',
  '.eot':  'application/vnd.ms-fontobject',
  '.webp': 'image/webp',
  '.txt':  'text/plain; charset=utf-8',
  '.map':  'application/json; charset=utf-8',
};

function getMime(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  return MIME_TYPES[ext] || 'application/octet-stream';
}

// ---------------------------------------------------------------------------
// SPA static server
// ---------------------------------------------------------------------------

/**
 * Spawn an in-process HTTP static file server for a SPA dist directory.
 * Falls back to index.html for unknown paths (SPA routing).
 * @param {{ id: string, distDir: string }} appCfg
 * @param {number} port
 */
function spawnStaticServer(appCfg, port) {
  const distDir = appCfg.distDir;

  if (!fs.existsSync(distDir)) {
    appendLog(appCfg.id, `[launcher] dist directory not found: ${distDir}`);
    sendStatus(appCfg.id, 'offline', port);
    return;
  }

  const server = http.createServer((req, res) => {
    // Strip query string / fragments
    let urlPath = req.url.split('?')[0].split('#')[0];
    // Decode percent-encoding
    try { urlPath = decodeURIComponent(urlPath); } catch (_) { /* ignore */ }

    let filePath = path.join(distDir, urlPath);

    // Security: prevent path traversal
    if (!filePath.startsWith(distDir)) {
      res.writeHead(403);
      res.end('Forbidden');
      return;
    }

    // If it's a directory, try index.html inside it
    if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
      filePath = path.join(filePath, 'index.html');
    }

    // Serve file if it exists
    if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
      res.writeHead(200, { 'Content-Type': getMime(filePath) });
      fs.createReadStream(filePath).pipe(res);
    } else {
      // SPA fallback — serve root index.html
      const indexPath = path.join(distDir, 'index.html');
      if (fs.existsSync(indexPath)) {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        fs.createReadStream(indexPath).pipe(res);
      } else {
        res.writeHead(404);
        res.end('Not found');
      }
    }
  });

  server.listen(port, '127.0.0.1', () => {
    appendLog(appCfg.id, `[launcher] Static server listening on http://localhost:${port}`);
    actualPorts.set(appCfg.id, port);
    sendStatus(appCfg.id, 'running', port);
  });

  server.on('error', (err) => {
    appendLog(appCfg.id, `[launcher] Static server error: ${err.message}`);
    sendStatus(appCfg.id, 'offline', port);
  });

  // Store a pseudo-entry so cleanup can close it
  childProcesses.set(appCfg.id, { type: 'http-server', server });
  actualPorts.set(appCfg.id, port);
}

// ---------------------------------------------------------------------------
// Node.js server spawner
// ---------------------------------------------------------------------------

/**
 * @param {{ id: string, serverDir: string, startCmd: string, startArgs: string[], geminiRequired: boolean }} appCfg
 * @param {number} port
 */
function spawnNodeServer(appCfg, port) {
  const geminiKey = appCfg.geminiRequired ? (store.get('geminiKey', '') || '') : '';

  const env = {
    ...process.env,
    PORT: String(port),
    NODE_ENV: 'production',
  };

  if (appCfg.geminiRequired && geminiKey) {
    env.GEMINI_API_KEY = geminiKey;
  }

  const serverDir = appCfg.serverDir;

  if (!fs.existsSync(serverDir)) {
    appendLog(appCfg.id, `[launcher] server directory not found: ${serverDir}`);
    sendStatus(appCfg.id, 'offline', port);
    return;
  }

  // Determine actual entry file path
  const entryFile = path.join(serverDir, appCfg.startArgs[0]);
  if (!fs.existsSync(entryFile)) {
    appendLog(appCfg.id, `[launcher] server entry not found: ${entryFile} — has the server been compiled?`);
    sendStatus(appCfg.id, 'offline', port);
    return;
  }

  const child = spawn(appCfg.startCmd, appCfg.startArgs, {
    cwd: serverDir,
    env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  child.stdout.on('data', (data) => {
    const line = data.toString().trimEnd();
    appendLog(appCfg.id, line);
  });

  child.stderr.on('data', (data) => {
    const line = data.toString().trimEnd();
    appendLog(appCfg.id, `[stderr] ${line}`);
  });

  child.on('error', (err) => {
    appendLog(appCfg.id, `[launcher] spawn error: ${err.message}`);
    sendStatus(appCfg.id, 'offline', port);
  });

  child.on('exit', (code, signal) => {
    appendLog(appCfg.id, `[launcher] process exited code=${code} signal=${signal}`);
    sendStatus(appCfg.id, 'offline', port);
    childProcesses.delete(appCfg.id);
  });

  childProcesses.set(appCfg.id, child);
  actualPorts.set(appCfg.id, port);
  sendStatus(appCfg.id, 'starting', port);
  appendLog(appCfg.id, `[launcher] Started node server on port ${port} (pid ${child.pid})`);
}

// ---------------------------------------------------------------------------
// Docker helpers
// ---------------------------------------------------------------------------

function checkDockerAvailable() {
  const result = spawnSync('docker', ['compose', 'version'], { encoding: 'utf8' });
  return result.status === 0;
}

/**
 * @param {{ id: string, composeFile: string, port: number }} appCfg
 */
function spawnDocker(appCfg) {
  if (!checkDockerAvailable()) {
    appendLog(appCfg.id, '[launcher] Docker Compose not available on this system.');
    sendStatus(appCfg.id, 'docker-required', appCfg.port);
    return;
  }

  const composeDir = path.dirname(appCfg.composeFile);
  const child = spawn('docker', ['compose', 'up', '-d', '--build'], {
    cwd: composeDir,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  child.stdout.on('data', (data) => {
    appendLog(appCfg.id, data.toString().trimEnd());
  });

  child.stderr.on('data', (data) => {
    appendLog(appCfg.id, data.toString().trimEnd());
  });

  child.on('error', (err) => {
    appendLog(appCfg.id, `[launcher] docker spawn error: ${err.message}`);
    sendStatus(appCfg.id, 'offline', appCfg.port);
  });

  child.on('exit', (code) => {
    if (code === 0) {
      appendLog(appCfg.id, '[launcher] docker compose up -d completed successfully.');
      // BugJaeger nginx binds port 80 — health check will detect it
      actualPorts.set(appCfg.id, appCfg.port);
      sendStatus(appCfg.id, 'starting', appCfg.port);
    } else {
      appendLog(appCfg.id, `[launcher] docker compose exited with code ${code}`);
      sendStatus(appCfg.id, 'offline', appCfg.port);
    }
  });

  // docker compose up -d is a one-shot command; we track it only during startup
  childProcesses.set(appCfg.id, child);
  actualPorts.set(appCfg.id, appCfg.port);
  sendStatus(appCfg.id, 'starting', appCfg.port);
  appendLog(appCfg.id, `[launcher] Running docker compose up -d in ${composeDir}`);
}

// ---------------------------------------------------------------------------
// Fullstack (ElderPhoto) spawner
// ---------------------------------------------------------------------------

/**
 * Spawn uvicorn backend + in-process static frontend server.
 * @param {{ id: string, frontendDir: string, backendDir: string, port: number, backendPort: number,
 *           backendCmd: string, backendArgs: string[], geminiRequired: boolean }} appCfg
 */
async function spawnFullstack(appCfg) {
  // --- Backend (uvicorn) ---
  const pythonResult = spawnSync('python3', ['--version'], { encoding: 'utf8' });
  if (pythonResult.status !== 0) {
    appendLog(appCfg.id, '[launcher] python3 not found — backend cannot start.');
    sendStatus(appCfg.id, 'offline', appCfg.port);
    return;
  }

  const backendEnv = {
    ...process.env,
    PORT: String(appCfg.backendPort),
    CORS_ALLOWED_ORIGINS: `http://localhost:${appCfg.port},http://localhost:3000`,
  };

  const backendChild = spawn(appCfg.backendCmd, appCfg.backendArgs, {
    cwd: appCfg.backendDir,
    env: backendEnv,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  backendChild.stdout.on('data', (data) => {
    appendLog(appCfg.id, `[backend] ${data.toString().trimEnd()}`);
  });

  backendChild.stderr.on('data', (data) => {
    appendLog(appCfg.id, `[backend:stderr] ${data.toString().trimEnd()}`);
  });

  backendChild.on('error', (err) => {
    appendLog(appCfg.id, `[launcher] uvicorn spawn error: ${err.message}`);
  });

  backendChild.on('exit', (code, signal) => {
    appendLog(appCfg.id, `[launcher] uvicorn exited code=${code} signal=${signal}`);
  });

  // Store backend under a sub-key; we re-use the same id for the frontend status
  childProcesses.set(`${appCfg.id}:backend`, backendChild);
  appendLog(appCfg.id, `[launcher] Started uvicorn on port ${appCfg.backendPort} (pid ${backendChild.pid})`);

  // --- Frontend (static SPA) ---
  const frontendDistDir = path.join(appCfg.frontendDir, 'dist');
  let frontendPort;
  try {
    frontendPort = await findFreePort(appCfg.port);
  } catch (err) {
    appendLog(appCfg.id, `[launcher] Could not find free port near ${appCfg.port}: ${err.message}`);
    sendStatus(appCfg.id, 'offline', appCfg.port);
    return;
  }

  // Build a pseudo-config object matching what spawnStaticServer expects
  const frontendPseudoCfg = { id: appCfg.id, distDir: frontendDistDir };
  spawnStaticServer(frontendPseudoCfg, frontendPort);
}

// ---------------------------------------------------------------------------
// Start all apps
// ---------------------------------------------------------------------------

async function startAllApps() {
  for (const appCfg of appsConfig.apps) {
    try {
      if (appCfg.type === 'spa-static') {
        const port = await findFreePort(appCfg.port);
        spawnStaticServer(appCfg, port);

      } else if (appCfg.type === 'node-server') {
        const port = await findFreePort(appCfg.port);
        spawnNodeServer(appCfg, port);

      } else if (appCfg.type === 'docker') {
        spawnDocker(appCfg);

      } else if (appCfg.type === 'fullstack') {
        await spawnFullstack(appCfg);
      }
    } catch (err) {
      appendLog(appCfg.id, `[launcher] Failed to start: ${err.message}`);
      sendStatus(appCfg.id, 'offline', appCfg.port);
    }
  }
}

// ---------------------------------------------------------------------------
// Health checker
// ---------------------------------------------------------------------------

function startHealthChecks() {
  setInterval(() => {
    for (const appCfg of appsConfig.apps) {
      const port = actualPorts.get(appCfg.id);
      if (!port) continue;

      const req = http.get(`http://127.0.0.1:${port}/`, { timeout: 3000 }, (res) => {
        res.resume(); // drain
        sendStatus(appCfg.id, 'running', port);
      });

      req.on('error', () => {
        // Check if we still think it's "starting" (process exists) or truly offline
        const proc = childProcesses.get(appCfg.id);
        const status = proc ? 'starting' : 'offline';
        sendStatus(appCfg.id, status, port);
      });

      req.on('timeout', () => {
        req.destroy();
      });
    }
  }, 5000);
}

// ---------------------------------------------------------------------------
// IPC handlers
// ---------------------------------------------------------------------------

ipcMain.handle('get-apps', () => {
  return appsConfig.apps.map((a) => ({
    ...a,
    actualPort: actualPorts.get(a.id) || a.port,
  }));
});

ipcMain.handle('launch-app', (_event, appId) => {
  const port = actualPorts.get(appId);
  if (!port) return { error: 'App not running' };
  shell.openExternal(`http://localhost:${port}`);
  return { ok: true };
});

ipcMain.handle('get-gemini-key', () => {
  return store.get('geminiKey', '');
});

ipcMain.handle('set-gemini-key', (_event, key) => {
  store.set('geminiKey', key);
  return { ok: true };
});

ipcMain.handle('get-logs', (_event, appId) => {
  if (appId) {
    return appLogs.get(appId) || [];
  }
  // Return all logs as an object
  const all = {};
  for (const [id, lines] of appLogs.entries()) {
    all[id] = lines;
  }
  return all;
});

// ---------------------------------------------------------------------------
// Cleanup
// ---------------------------------------------------------------------------

function killAll() {
  // Kill child processes
  for (const [id, proc] of childProcesses.entries()) {
    if (proc && proc.type === 'http-server') {
      // In-process HTTP server
      try { proc.server.close(); } catch (_) { /* ignore */ }
    } else if (proc && typeof proc.kill === 'function') {
      try {
        proc.kill('SIGTERM');
        setTimeout(() => {
          try { proc.kill('SIGKILL'); } catch (_) { /* already dead */ }
        }, 3000);
      } catch (_) { /* ignore */ }
    }
    childProcesses.delete(id);
  }
}

// ---------------------------------------------------------------------------
// Window creation
// ---------------------------------------------------------------------------

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 900,
    minHeight: 600,
    title: 'Portfolio Launcher',
    backgroundColor: '#0f0f0f',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'launcher.html'));

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// ---------------------------------------------------------------------------
// App lifecycle
// ---------------------------------------------------------------------------

app.whenReady().then(async () => {
  createWindow();

  // Give the renderer a moment to attach listeners before we start firing events
  setTimeout(async () => {
    await startAllApps();
    startHealthChecks();
  }, 1500);

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('before-quit', () => {
  killAll();
});
