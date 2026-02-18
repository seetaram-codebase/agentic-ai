#!/bin/bash
# Start Electron UI in Development Mode (Mac/Linux)

echo "============================================"
echo "RAG Demo - Electron UI Setup"
echo "============================================"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js is not installed"
    echo "Please install Node.js 18+ from https://nodejs.org/"
    exit 1
fi

echo "[1/3] Node.js found: $(node --version)"
echo ""

# Navigate to electron-ui directory
cd "$(dirname "$0")/../electron-ui" || exit

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "[2/3] Installing dependencies..."
    echo "This may take a few minutes on first run..."
    npm install
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install dependencies"
        exit 1
    fi
else
    echo "[2/3] Dependencies already installed"
fi
echo ""

echo "[3/3] Starting Electron app in development mode..."
echo ""
echo "============================================"
echo "Make sure backend is running at:"
echo "http://localhost:8000"
echo ""
echo "Starting Electron UI..."
echo "============================================"
echo ""

# Start development mode
npm run dev

