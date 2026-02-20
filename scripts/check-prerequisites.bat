@echo off
REM Check if all prerequisites are installed

echo ============================================
echo Checking Prerequisites for RAG Demo
echo ============================================
echo.

set "all_ok=1"

echo [1/3] Checking Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python NOT FOUND
    echo.
    echo Install Python 3.11+ from: https://www.python.org/downloads/
    echo IMPORTANT: Check "Add Python to PATH" during installation
    set "all_ok=0"
) else (
    python --version
    echo ✅ Python installed
)
echo.

echo [2/3] Checking Node.js...
node --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Node.js NOT FOUND
    echo.
    echo Install Node.js 18+ from: https://nodejs.org/
    echo Download the LTS version ^(Recommended for most users^)
    set "all_ok=0"
) else (
    node --version
    echo ✅ Node.js installed
)
echo.

echo [3/3] Checking npm...
npm --version >nul 2>&1
if errorlevel 1 (
    echo ❌ npm NOT FOUND
    echo.
    echo npm should come automatically with Node.js
    echo If Node.js is installed but npm is missing:
    echo 1. Reinstall Node.js from https://nodejs.org/
    echo 2. Make sure to use the official installer
    set "all_ok=0"
) else (
    npm --version
    echo ✅ npm installed
)
echo.

echo ============================================
echo Summary
echo ============================================
python --version >nul 2>&1 && (echo Python:  ✅) || (echo Python:  ❌)
node --version >nul 2>&1 && (echo Node.js: ✅) || (echo Node.js: ❌)
npm --version >nul 2>&1 && (echo npm:     ✅) || (echo npm:     ❌)
echo ============================================
echo.

if "%all_ok%"=="1" (
    echo ✅ All prerequisites installed!
    echo.
    echo You're ready to run the RAG Demo locally.
    echo.
    echo Next steps:
    echo 1. Start backend: scripts\start-backend-local.bat
    echo 2. Start UI:      scripts\start-ui-local.bat
    echo.
    echo See LOCAL-QUICK-START.md for more details.
) else (
    echo ❌ Some prerequisites are missing!
    echo.
    echo Please install the missing software listed above.
    echo See docs\INSTALL-PREREQUISITES.md for detailed instructions.
    echo.
)

pause

