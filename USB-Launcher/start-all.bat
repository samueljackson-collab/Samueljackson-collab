@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: Portfolio Suite — Windows Batch Launcher (no Electron needed)
:: ============================================================
:: Starts all 9 portfolio apps using available runtimes.
:: Requires: Node.js (for SPA servers + node-server apps)
::           Python 3 (for ElderPhoto backend, optional fallback)
::           Docker Desktop (for BugJaeger only)
:: ============================================================

set "APP_DIR=%~dp0"
set "PARENT_DIR=%APP_DIR%..\"

echo.
echo  =====================================================
echo   Samuel Jackson -- Portfolio Suite Launcher
echo  =====================================================
echo.

:: -------------------------------------------------------
:: Check for Node.js
:: -------------------------------------------------------
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js not found. Please install Node.js 20+ from https://nodejs.org
    pause
    exit /b 1
)
for /f "tokens=*" %%v in ('node --version') do set NODE_VER=%%v
echo [INFO] Node.js %NODE_VER% detected.

:: -------------------------------------------------------
:: Helper: serve a SPA dist directory with a tiny Node server
:: We write a one-liner inline node server to a temp file
:: -------------------------------------------------------
:: Usage: call :serve_spa <APP_ID> <DIST_DIR> <PORT>

:: -------------------------------------------------------
:: 1. Ai-Job-Agent  (spa-static, port 4001)
:: -------------------------------------------------------
set "DIST=%PARENT_DIR%Ai-Job-Agent\dist"
set PORT=4001
if exist "%DIST%\index.html" (
    echo [START] Ai-Job-Agent on port %PORT% ...
    start "Ai-Job-Agent [:4001]" /MIN cmd /c "node -e \"const http=require('http'),fs=require('fs'),path=require('path');const d='%DIST%'.replace(/\\/g,'/');http.createServer((q,r)=>{let p=path.join(d,q.url.split('?')[0]||'/');if(!fs.existsSync(p)||fs.statSync(p).isDirectory())p=path.join(d,'index.html');const m={'html':'text/html','js':'application/javascript','css':'text/css','json':'application/json','png':'image/png','svg':'image/svg+xml','ico':'image/x-icon'};const ext=path.extname(p).slice(1);r.writeHead(200,{'Content-Type':m[ext]||'application/octet-stream'});fs.createReadStream(p).pipe(r)}).listen(%PORT%,'127.0.0.1',()=>console.log('Ai-Job-Agent ready http://localhost:%PORT%'))\""
) else (
    echo [WARN]  Ai-Job-Agent dist not found at %DIST% — run 'npm run build' in Ai-Job-Agent first.
)

:: -------------------------------------------------------
:: 2. Secure-Deployer  (spa-static, port 4002)
:: -------------------------------------------------------
set "DIST=%PARENT_DIR%Secure-Deployer\dist"
set PORT=4002
if exist "%DIST%\index.html" (
    echo [START] Secure-Deployer on port %PORT% ...
    start "Secure-Deployer [:4002]" /MIN cmd /c "node -e \"const http=require('http'),fs=require('fs'),path=require('path');const d='%DIST%'.replace(/\\/g,'/');http.createServer((q,r)=>{let p=path.join(d,q.url.split('?')[0]||'/');if(!fs.existsSync(p)||fs.statSync(p).isDirectory())p=path.join(d,'index.html');const m={'html':'text/html','js':'application/javascript','css':'text/css','json':'application/json','png':'image/png','svg':'image/svg+xml','ico':'image/x-icon'};const ext=path.extname(p).slice(1);r.writeHead(200,{'Content-Type':m[ext]||'application/octet-stream'});fs.createReadStream(p).pipe(r)}).listen(%PORT%,'127.0.0.1',()=>console.log('Secure-Deployer ready http://localhost:%PORT%'))\""
) else (
    echo [WARN]  Secure-Deployer dist not found — run 'npm run build' in Secure-Deployer first.
)

:: -------------------------------------------------------
:: 3. BugJaeger  (docker, port 80)
:: -------------------------------------------------------
echo.
echo [DOCKER] BugJaeger requires Docker Desktop.
where docker >nul 2>&1
if %errorlevel% equ 0 (
    echo [START] Launching BugJaeger via docker compose...
    start "BugJaeger [docker]" /MIN cmd /c "cd /d \"%PARENT_DIR%BugJaeger\" && docker compose up --build && pause"
) else (
    echo [WARN]  Docker not found. To run BugJaeger:
    echo          1. Install Docker Desktop: https://www.docker.com/products/docker-desktop
    echo          2. Run: cd ..\BugJaeger ^&^& docker compose up -d
)

:: -------------------------------------------------------
:: 4. Download-Command-Center  (node-server, port 4004)
:: -------------------------------------------------------
set "SRV_DIR=%PARENT_DIR%Download-Command-Center"
set PORT=4004
if exist "%SRV_DIR%\server.js" (
    echo [START] Download-Command-Center on port %PORT% ...
    start "Download-Command-Center [:4004]" /MIN cmd /c "cd /d \"%SRV_DIR%\" && set PORT=%PORT% && node server.js"
) else (
    echo [WARN]  Download-Command-Center: server.js not found at %SRV_DIR%
    echo         This app uses TypeScript. Compile with: cd ..\Download-Command-Center ^&^& npx tsc
    echo         Or run in dev mode: npm run dev (requires tsx)
)

:: -------------------------------------------------------
:: 5. Tab-Sorter  (spa-static, port 4005)
:: -------------------------------------------------------
set "DIST=%PARENT_DIR%Tab-Sorter\dist"
set PORT=4005
if exist "%DIST%\index.html" (
    echo [START] Tab-Sorter on port %PORT% ...
    start "Tab-Sorter [:4005]" /MIN cmd /c "node -e \"const http=require('http'),fs=require('fs'),path=require('path');const d='%DIST%'.replace(/\\/g,'/');http.createServer((q,r)=>{let p=path.join(d,q.url.split('?')[0]||'/');if(!fs.existsSync(p)||fs.statSync(p).isDirectory())p=path.join(d,'index.html');const m={'html':'text/html','js':'application/javascript','css':'text/css','json':'application/json','png':'image/png','svg':'image/svg+xml','ico':'image/x-icon'};const ext=path.extname(p).slice(1);r.writeHead(200,{'Content-Type':m[ext]||'application/octet-stream'});fs.createReadStream(p).pipe(r)}).listen(%PORT%,'127.0.0.1',()=>console.log('Tab-Sorter ready http://localhost:%PORT%'))\""
) else (
    echo [WARN]  Tab-Sorter dist not found — run 'npm run build' in Tab-Sorter first.
)

:: -------------------------------------------------------
:: 6. Reportify  (spa-static, port 4006)
:: -------------------------------------------------------
set "DIST=%PARENT_DIR%Reportify\dist"
set PORT=4006
if exist "%DIST%\index.html" (
    echo [START] Reportify on port %PORT% ...
    start "Reportify [:4006]" /MIN cmd /c "node -e \"const http=require('http'),fs=require('fs'),path=require('path');const d='%DIST%'.replace(/\\/g,'/');http.createServer((q,r)=>{let p=path.join(d,q.url.split('?')[0]||'/');if(!fs.existsSync(p)||fs.statSync(p).isDirectory())p=path.join(d,'index.html');const m={'html':'text/html','js':'application/javascript','css':'text/css','json':'application/json','png':'image/png','svg':'image/svg+xml','ico':'image/x-icon'};const ext=path.extname(p).slice(1);r.writeHead(200,{'Content-Type':m[ext]||'application/octet-stream'});fs.createReadStream(p).pipe(r)}).listen(%PORT%,'127.0.0.1',()=>console.log('Reportify ready http://localhost:%PORT%'))\""
) else (
    echo [WARN]  Reportify dist not found — run 'npm run build' in Reportify first.
)

:: -------------------------------------------------------
:: 7. AstraDup  (spa-static, port 4007)
:: -------------------------------------------------------
set "DIST=%PARENT_DIR%AstraDup-Cross-Storage-Video-Files-duplication-tracker\dist"
set PORT=4007
if exist "%DIST%\index.html" (
    echo [START] AstraDup on port %PORT% ...
    start "AstraDup [:4007]" /MIN cmd /c "node -e \"const http=require('http'),fs=require('fs'),path=require('path');const d='%DIST%'.replace(/\\/g,'/');http.createServer((q,r)=>{let p=path.join(d,q.url.split('?')[0]||'/');if(!fs.existsSync(p)||fs.statSync(p).isDirectory())p=path.join(d,'index.html');const m={'html':'text/html','js':'application/javascript','css':'text/css','json':'application/json','png':'image/png','svg':'image/svg+xml','ico':'image/x-icon'};const ext=path.extname(p).slice(1);r.writeHead(200,{'Content-Type':m[ext]||'application/octet-stream'});fs.createReadStream(p).pipe(r)}).listen(%PORT%,'127.0.0.1',()=>console.log('AstraDup ready http://localhost:%PORT%'))\""
) else (
    echo [WARN]  AstraDup dist not found — run 'npm run build' in the AstraDup directory first.
)

:: -------------------------------------------------------
:: 8. Playbook-Generator  (node-server, port 4008)
:: -------------------------------------------------------
set "SRV_DIR=%PARENT_DIR%Playbook-Generator"
set PORT=4008
if exist "%SRV_DIR%\server.js" (
    echo [START] Playbook-Generator on port %PORT% ...
    start "Playbook-Generator [:4008]" /MIN cmd /c "cd /d \"%SRV_DIR%\" && set PORT=%PORT% && node server.js"
) else (
    echo [WARN]  Playbook-Generator: server.js not found at %SRV_DIR%
    echo         Compile with: cd ..\Playbook-Generator ^&^& npx tsc
    echo         Or run in dev mode: npm run dev (requires tsx)
)

:: -------------------------------------------------------
:: 9. ElderPhoto  (fullstack, frontend 4009, backend 8000)
:: -------------------------------------------------------
set "FRONTEND_DIST=%PARENT_DIR%Samueljackson-collab\frontend\dist"
set "BACKEND_DIR=%PARENT_DIR%Samueljackson-collab\backend"
set FRONT_PORT=4009
set BACK_PORT=8000

:: Backend (uvicorn / Python)
where python3 >nul 2>&1
if %errorlevel% equ 0 (
    echo [START] ElderPhoto backend (uvicorn) on port %BACK_PORT% ...
    start "ElderPhoto-Backend [:8000]" /MIN cmd /c "cd /d \"%BACKEND_DIR%\" && python3 -m uvicorn app.main:app --host 0.0.0.0 --port %BACK_PORT%"
) else (
    where python >nul 2>&1
    if %errorlevel% equ 0 (
        echo [START] ElderPhoto backend (uvicorn via python) on port %BACK_PORT% ...
        start "ElderPhoto-Backend [:8000]" /MIN cmd /c "cd /d \"%BACKEND_DIR%\" && python -m uvicorn app.main:app --host 0.0.0.0 --port %BACK_PORT%"
    ) else (
        echo [WARN]  Python not found. ElderPhoto backend cannot start.
        echo         Install Python 3.11+ from https://www.python.org/downloads/
        echo         Then: cd ..\Samueljackson-collab\backend ^&^& pip install -r requirements.txt
    )
)

:: Frontend (static SPA)
if exist "%FRONTEND_DIST%\index.html" (
    echo [START] ElderPhoto frontend on port %FRONT_PORT% ...
    start "ElderPhoto-Frontend [:4009]" /MIN cmd /c "node -e \"const http=require('http'),fs=require('fs'),path=require('path');const d='%FRONTEND_DIST%'.replace(/\\/g,'/');http.createServer((q,r)=>{let p=path.join(d,q.url.split('?')[0]||'/');if(!fs.existsSync(p)||fs.statSync(p).isDirectory())p=path.join(d,'index.html');const m={'html':'text/html','js':'application/javascript','css':'text/css','json':'application/json','png':'image/png','svg':'image/svg+xml','ico':'image/x-icon'};const ext=path.extname(p).slice(1);r.writeHead(200,{'Content-Type':m[ext]||'application/octet-stream'});fs.createReadStream(p).pipe(r)}).listen(%FRONT_PORT%,'127.0.0.1',()=>console.log('ElderPhoto frontend ready http://localhost:%FRONT_PORT%'))\""
) else (
    echo [WARN]  ElderPhoto frontend dist not found at %FRONTEND_DIST%
    echo         Build with: cd ..\Samueljackson-collab\frontend ^&^& npm ci ^&^& npm run build
)

:: -------------------------------------------------------
:: Summary
:: -------------------------------------------------------
echo.
echo  =====================================================
echo   All servers started. Open your browser to:
echo  =====================================================
echo.
echo   App                        URL
echo   -------------------------  ---------------------------
echo   Ai-Job-Agent               http://localhost:4001
echo   Secure-Deployer            http://localhost:4002
echo   BugJaeger (Docker/nginx)   http://localhost:80
echo   Download-Command-Center    http://localhost:4004
echo   Tab-Sorter                 http://localhost:4005
echo   Reportify                  http://localhost:4006
echo   AstraDup                   http://localhost:4007
echo   Playbook-Generator         http://localhost:4008
echo   ElderPhoto (frontend)      http://localhost:4009
echo   ElderPhoto (API)           http://localhost:8000
echo.
echo   NOTE: Apps that require a Gemini API key (Ai-Job-Agent,
echo         Download-Command-Center, Playbook-Generator, Reportify)
echo         must have GEMINI_API_KEY set or entered in-app.
echo.
echo   Press any key to close this launcher window.
echo   (Server windows will continue running in the background.)
echo.
pause
endlocal
