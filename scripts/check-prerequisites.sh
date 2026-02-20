#!/bin/bash
# Check if all prerequisites are installed

echo "============================================"
echo "Checking Prerequisites for RAG Demo"
echo "============================================"
echo ""

all_ok=1

echo "[1/3] Checking Python..."
if command -v python3 &> /dev/null; then
    echo "✅ Python installed: $(python3 --version)"
else
    echo "❌ Python NOT FOUND"
    echo ""
    echo "Install Python 3.11+ from: https://www.python.org/downloads/"
    echo ""
    echo "Or on macOS with Homebrew:"
    echo "  brew install python@3.11"
    echo ""
    echo "Or on Ubuntu/Debian:"
    echo "  sudo apt install python3.11 python3-pip"
    all_ok=0
fi
echo ""

echo "[2/3] Checking Node.js..."
if command -v node &> /dev/null; then
    echo "✅ Node.js installed: $(node --version)"
else
    echo "❌ Node.js NOT FOUND"
    echo ""
    echo "Install Node.js 18+ from: https://nodejs.org/"
    echo ""
    echo "Or on macOS with Homebrew:"
    echo "  brew install node"
    echo ""
    echo "Or on Ubuntu/Debian:"
    echo "  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
    echo "  sudo apt-get install -y nodejs"
    all_ok=0
fi
echo ""

echo "[3/3] Checking npm..."
if command -v npm &> /dev/null; then
    echo "✅ npm installed: $(npm --version)"
else
    echo "❌ npm NOT FOUND"
    echo ""
    echo "npm should come automatically with Node.js"
    echo "If Node.js is installed but npm is missing:"
    echo "1. Reinstall Node.js from https://nodejs.org/"
    echo "2. Make sure to use the official installer"
    all_ok=0
fi
echo ""

echo "============================================"
echo "Summary"
echo "============================================"
command -v python3 &> /dev/null && echo "Python:  ✅" || echo "Python:  ❌"
command -v node &> /dev/null && echo "Node.js: ✅" || echo "Node.js: ❌"
command -v npm &> /dev/null && echo "npm:     ✅" || echo "npm:     ❌"
echo "============================================"
echo ""

if [ $all_ok -eq 1 ]; then
    echo "✅ All prerequisites installed!"
    echo ""
    echo "You're ready to run the RAG Demo locally."
    echo ""
    echo "Next steps:"
    echo "1. Start backend: ./scripts/start-backend-local.sh"
    echo "2. Start UI:      ./scripts/start-ui-local.sh"
    echo ""
    echo "See LOCAL-QUICK-START.md for more details."
else
    echo "❌ Some prerequisites are missing!"
    echo ""
    echo "Please install the missing software listed above."
    echo "See docs/INSTALL-PREREQUISITES.md for detailed instructions."
    echo ""
fi

