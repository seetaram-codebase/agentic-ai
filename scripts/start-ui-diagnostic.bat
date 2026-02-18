http://54.89.127.74:8000/@echo off
REM Comprehensive UI Startup with Full Diagnostics

echo ============================================
echo RAG Demo UI - Diagnostic Startup
echo ============================================
echo.

REM Step 1: Kill existing processes
echo [1/6] Cleaning up existing processes...
taskkill /F /IM node.exe >nul 2>&1
taskkill /F /IM electron.exe >nul 2>&1
timeout /t 2 >nul
echo Done.
echo.

REM Step 2: Add Node to PATH
echo [2/6] Adding Node.js to PATH...
set "PATH=%PATH%;C:\Program Files\nodejs"
echo Done.
echo.

REM Step 3: Verify npm
echo [3/6] Verifying npm...
where npm >nul 2>&1
if errorlevel 1 (
    echo ERROR: npm not found!
    echo Please install Node.js from: https://nodejs.org/
    pause
    exit /b 1
)
npm --version
echo.

REM Step 4: Navigate to electron-ui
echo [4/6] Navigating to electron-ui...
cd /d "%~dp0..\electron-ui"
echo Current directory: %CD%
echo.

REM Step 5: Check dependencies
echo [5/6] Checking dependencies...
if not exist "node_modules" (
    echo Installing dependencies...
    call npm install
    if errorlevel 1 (
        echo ERROR: npm install failed!
        pause
        exit /b 1
    )
) else (
    echo Dependencies already installed.
)
echo.

REM Step 6: Clear Vite cache
echo [6/6] Clearing Vite cache...
if exist "node_modules\.vite" (
    rmdir /s /q "node_modules\.vite"
    echo Cache cleared.
) else (
    echo No cache to clear.
)
echo.

echo ============================================
echo Starting Development Server
echo ============================================
echo.
echo Backend URL: http://54.89.127.74:8000
echo.
echo IMPORTANT: When Electron opens:
echo  1. Press F12 to open DevTools
echo  2. Click Console tab
echo  3. Look for log messages starting with emojis
echo.
echo If blank screen:
echo  - Check Console for errors (red messages)
echo  - Look for messages starting with ❌
echo  - All logs have emojis for easy identification
echo.
echo Starting in 3 seconds...
timeout /t 3 >nul
echo.

REM Start the app
call npm run dev

pause

