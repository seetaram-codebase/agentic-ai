#!/bin/bash
# Quick Start Script for Local Development (Mac/Linux)
# This script sets up and starts the backend server

echo "============================================"
echo "RAG Demo - Local Backend Setup"
echo "============================================"
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python is not installed"
    echo "Please install Python 3.11+ from https://www.python.org/"
    exit 1
fi

echo "[1/5] Python found: $(python3 --version)"
echo ""

# Navigate to backend directory
cd "$(dirname "$0")/../backend" || exit

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "[2/5] Creating virtual environment..."
    python3 -m venv venv
    echo "Virtual environment created"
else
    echo "[2/5] Virtual environment already exists"
fi
echo ""

# Activate virtual environment
echo "[3/5] Activating virtual environment..."
source venv/bin/activate
echo ""

# Install dependencies
echo "[4/5] Installing dependencies..."
echo "This may take a few minutes on first run..."
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install dependencies"
    exit 1
fi
echo ""

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "WARNING: .env file not found"
    echo "Creating .env from .env.local.example..."
    cp .env.local.example .env
    echo ""
    echo "IMPORTANT: Please edit .env and add your Azure OpenAI credentials"
    echo "Then run this script again."
    echo ""
    echo "Opening .env in default editor..."
    ${EDITOR:-nano} .env
    exit 0
fi

echo "[5/5] Starting backend server..."
echo ""
echo "============================================"
echo "Backend running at: http://localhost:8000"
echo "API Docs: http://localhost:8000/docs"
echo "Press Ctrl+C to stop"
echo "============================================"
echo ""

# Start the server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

