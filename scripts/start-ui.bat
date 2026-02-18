@echo off
REM Start Electron UI with proper error handling

echo ============================================
echo Starting RAG Demo Electron UI
echo ============================================
echo.

REM Add Node.js to PATH
set "PATH=%PATH%;C:\Program Files\nodejs"

REM Check if npm is available
where npm >nul 2>&1
if errorlevel 1 (
    echo ERROR: npm not found!
    echo.
    echo Please ensure Node.js is installed.
    echo Download from: https://nodejs.org/
    echo.
    pause
    exit /b 1
)

echo [1/3] Node.js found:
call npm --version
echo.

REM Navigate to electron-ui directory
cd /d "%~dp0..\electron-ui"

REM Check if node_modules exists
if not exist "node_modules" (
    echo [2/3] Installing dependencies...
    echo This may take a few minutes...
    call npm install
    if errorlevel 1 (
        echo ERROR: Failed to install dependencies
        pause
        exit /b 1
    )
) else (
    echo [2/3] Dependencies already installed
)
echo.

echo [3/3] Starting Electron app...
echo.
echo ============================================
echo UI will connect to backend at:
echo http://54.91.39.84:8000
echo.
echo The Electron window should open shortly...
echo Press Ctrl+C to stop
echo ============================================
echo.

REM Start the development server
call npm run dev

pause

