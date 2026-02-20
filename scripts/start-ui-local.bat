@echo off
REM Start Electron UI in Development Mode

echo ============================================
echo RAG Demo - Electron UI Setup
echo ============================================
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js 18+ from https://nodejs.org/
    pause
    exit /b 1
)

echo [1/3] Node.js found:
node --version
echo.

REM Navigate to electron-ui directory
cd /d "%~dp0..\electron-ui"

REM Install dependencies if node_modules doesn't exist
if not exist "node_modules" (
    echo [2/3] Installing dependencies...
    echo This may take a few minutes on first run...
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

echo [3/3] Starting Electron app in development mode...
echo.
echo ============================================
echo Make sure backend is running at:
echo http://localhost:8000
echo.
echo Starting Electron UI...
echo ============================================
echo.

REM Start development mode
npm run dev

pause

