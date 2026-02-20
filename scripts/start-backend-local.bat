@echo off
REM Quick Start Script for Local Development
REM This script sets up and starts the backend server

echo ============================================
echo RAG Demo - Local Backend Setup
echo ============================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.11+ from https://www.python.org/
    pause
    exit /b 1
)

echo [1/5] Python found
echo.

REM Navigate to backend directory
cd /d "%~dp0..\backend"

REM Create virtual environment if it doesn't exist
if not exist "venv" (
    echo [2/5] Creating virtual environment...
    python -m venv venv
    echo Virtual environment created
) else (
    echo [2/5] Virtual environment already exists
)
echo.

REM Activate virtual environment
echo [3/5] Activating virtual environment...
call venv\Scripts\activate.bat
echo.

REM Install dependencies
echo [4/5] Installing dependencies...
echo This may take a few minutes on first run...
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)
echo.

REM Check if .env exists
if not exist ".env" (
    echo WARNING: .env file not found
    echo Creating .env from .env.local.example...
    copy .env.local.example .env
    echo.
    echo IMPORTANT: Please edit .env and add your Azure OpenAI credentials
    echo Then run this script again.
    notepad .env
    pause
    exit /b 0
)

echo [5/5] Starting backend server...
echo.
echo ============================================
echo Backend running at: http://localhost:8000
echo API Docs: http://localhost:8000/docs
echo Press Ctrl+C to stop
echo ============================================
echo.

REM Start the server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

pause

