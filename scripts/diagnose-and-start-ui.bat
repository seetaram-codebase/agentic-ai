@echo off
REM Complete diagnostic and startup script for RAG Demo UI

echo ============================================
echo RAG Demo - Complete Diagnostic and Startup
echo ============================================
echo.

REM Kill any stale processes
echo [1/8] Cleaning up stale processes...
taskkill /F /IM node.exe >nul 2>&1
taskkill /F /IM electron.exe >nul 2>&1
timeout /t 2 >nul
echo Done.
echo.

REM Add Node.js to PATH
echo [2/8] Setting up environment...
set "PATH=%PATH%;C:\Program Files\nodejs"
echo PATH configured.
echo.

REM Check npm
echo [3/8] Checking npm...
where npm >nul 2>&1
if errorlevel 1 (
    echo ERROR: npm not found!
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)
npm --version
echo.

REM Navigate to electron-ui
echo [4/8] Navigating to electron-ui directory...
cd /d "%~dp0..\electron-ui"
echo Current directory: %CD%
echo.

REM Check if node_modules exists
echo [5/8] Checking dependencies...
if not exist "node_modules" (
    echo Dependencies not found. Installing...
    call npm install
    if errorlevel 1 (
        echo ERROR: Failed to install dependencies
        pause
        exit /b 1
    )
) else (
    echo Dependencies already installed.
)
echo.

REM Check backend connectivity
echo [6/8] Testing backend connection...
echo Testing: http://13.222.106.90:8000/health
curl -s -m 5 http://13.222.106.90:8000/health >nul 2>&1
if errorlevel 1 (
    echo WARNING: Backend not responding!
    echo The UI will still start, but may not function properly.
    echo.
    echo Please check:
    echo - Is the backend running in AWS ECS?
    echo - Is the security group allowing port 8000?
    echo - Check: http://13.222.106.90:8000/docs
    echo.
) else (
    echo Backend is responding! ✓
)
echo.

REM Check critical files
echo [7/8] Checking critical files...
if not exist "package.json" (
    echo ERROR: package.json not found!
    echo You may be in the wrong directory.
    pause
    exit /b 1
)
if not exist "main.js" (
    echo ERROR: main.js not found!
    pause
    exit /b 1
)
if not exist "src\App.tsx" (
    echo ERROR: src\App.tsx not found!
    pause
    exit /b 1
)
echo All critical files present ✓
echo.

REM Start the UI
echo [8/8] Starting Electron UI...
echo ============================================
echo.
echo Backend URL: http://13.222.106.90:8000
echo.
echo The Electron window should open in 15-20 seconds.
echo If you see a blank screen:
echo   1. Wait 10 more seconds
echo   2. Press Ctrl+R to refresh
echo   3. Press F12 to check console for errors
echo.
echo To stop: Press Ctrl+C or close the Electron window
echo ============================================
echo.

REM Start with proper error handling
call npm run dev
if errorlevel 1 (
    echo.
    echo ERROR: Failed to start UI
    echo.
    echo Troubleshooting steps:
    echo 1. Check if port 5173 is already in use
    echo 2. Try: npm cache clean --force
    echo 3. Try: npm install again
    echo 4. Check docs\UI-TROUBLESHOOTING.md
    pause
    exit /b 1
)

pause

