# Installing Prerequisites for RAG Demo

## 📋 What You Need to Install

Before running the RAG Demo locally, you need to install:

1. **Python 3.11+** (for backend)
2. **Node.js 18+** (includes npm - for Electron UI)
3. **Azure OpenAI account** (or OpenAI API key)

---

## 🐍 Install Python 3.11+

### Windows

1. **Download Python**:
   - Go to: https://www.python.org/downloads/
   - Click **"Download Python 3.11.x"** (or newer)

2. **Run the installer**:
   - ✅ **IMPORTANT**: Check **"Add Python to PATH"**
   - Click "Install Now"

3. **Verify installation**:
   ```batch
   python --version
   # Should show: Python 3.11.x or higher
   
   pip --version
   # Should show: pip 23.x or higher
   ```

### macOS

**Option 1: Official Installer**
```bash
# Download from python.org
open https://www.python.org/downloads/macos/

# Or use Homebrew
brew install python@3.11
```

**Option 2: Homebrew (Recommended)**
```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Python
brew install python@3.11
```

**Verify**:
```bash
python3 --version
pip3 --version
```

### Linux (Ubuntu/Debian)

```bash
# Update package list
sudo apt update

# Install Python 3.11
sudo apt install python3.11 python3.11-venv python3-pip

# Verify
python3 --version
pip3 --version
```

---

## 🟢 Install Node.js 18+ (includes npm)

### Windows

1. **Download Node.js**:
   - Go to: https://nodejs.org/
   - Download **"LTS"** version (Recommended for most users)
   - Current LTS: Node.js 20.x

2. **Run the installer**:
   - Click through the installer
   - Accept all defaults
   - It will install both Node.js and npm

3. **Verify installation**:
   ```batch
   node --version
   # Should show: v18.x.x or v20.x.x
   
   npm --version
   # Should show: 9.x.x or 10.x.x
   ```

### macOS

**Option 1: Official Installer**
```bash
# Download from nodejs.org
open https://nodejs.org/

# Download and run the .pkg installer
```

**Option 2: Homebrew (Recommended)**
```bash
# Install Node.js (includes npm)
brew install node

# Or install specific version
brew install node@20
```

**Verify**:
```bash
node --version
npm --version
```

### Linux (Ubuntu/Debian)

**Using NodeSource Repository (Recommended)**:
```bash
# Download and import NodeSource GPG key
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

# Create deb repository
NODE_MAJOR=20
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

# Install Node.js
sudo apt-get update
sudo apt-get install nodejs -y

# Verify
node --version
npm --version
```

**Alternative - Using nvm (Node Version Manager)**:
```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Reload shell
source ~/.bashrc

# Install Node.js
nvm install 20
nvm use 20

# Verify
node --version
npm --version
```

---

## 🔑 Get Azure OpenAI Access

### Option 1: Azure OpenAI (Recommended)

1. **Sign up for Azure**:
   - Go to: https://portal.azure.com
   - Create account (free tier available)

2. **Request Azure OpenAI access**:
   - Go to: https://aka.ms/oai/access
   - Fill out the form
   - Wait for approval (usually 1-2 business days)

3. **Create Azure OpenAI resource**:
   - In Azure Portal, search "Azure OpenAI"
   - Click "Create"
   - Fill in details, create resource

4. **Deploy models**:
   - Go to Azure OpenAI Studio: https://oai.azure.com/
   - Deploy `gpt-4` (for chat)
   - Deploy `text-embedding-ada-002` (for embeddings)

5. **Get credentials**:
   - In Azure Portal, go to your OpenAI resource
   - Click "Keys and Endpoint"
   - Copy:
     - Endpoint URL
     - API Key (Key 1)
     - Deployment names

### Option 2: OpenAI API (Alternative)

1. **Sign up**:
   - Go to: https://platform.openai.com/signup
   - Create account

2. **Get API key**:
   - Go to: https://platform.openai.com/api-keys
   - Click "Create new secret key"
   - Copy the key (shown only once!)

3. **Add payment method**:
   - Go to: https://platform.openai.com/account/billing
   - Add credit card
   - Add credits ($5-10 for testing)

---

## ✅ Verify All Installations

### Quick Check Script (Windows)

Create `check-prerequisites.bat`:

```batch
@echo off
echo ============================================
echo Checking Prerequisites for RAG Demo
echo ============================================
echo.

echo [1/3] Checking Python...
python --version
if errorlevel 1 (
    echo ❌ Python not found! Install from https://www.python.org/
) else (
    echo ✅ Python installed
)
echo.

echo [2/3] Checking Node.js...
node --version
if errorlevel 1 (
    echo ❌ Node.js not found! Install from https://nodejs.org/
) else (
    echo ✅ Node.js installed
)
echo.

echo [3/3] Checking npm...
npm --version
if errorlevel 1 (
    echo ❌ npm not found! Should come with Node.js
) else (
    echo ✅ npm installed
)
echo.

echo ============================================
echo Summary
echo ============================================
python --version 2>nul && echo Python: ✅ || echo Python: ❌
node --version 2>nul && echo Node.js: ✅ || echo Node.js: ❌
npm --version 2>nul && echo npm: ✅ || echo npm: ❌
echo.

pause
```

### Quick Check Script (Mac/Linux)

Create `check-prerequisites.sh`:

```bash
#!/bin/bash
echo "============================================"
echo "Checking Prerequisites for RAG Demo"
echo "============================================"
echo ""

echo "[1/3] Checking Python..."
if command -v python3 &> /dev/null; then
    echo "✅ Python installed: $(python3 --version)"
else
    echo "❌ Python not found! Install from https://www.python.org/"
fi
echo ""

echo "[2/3] Checking Node.js..."
if command -v node &> /dev/null; then
    echo "✅ Node.js installed: $(node --version)"
else
    echo "❌ Node.js not found! Install from https://nodejs.org/"
fi
echo ""

echo "[3/3] Checking npm..."
if command -v npm &> /dev/null; then
    echo "✅ npm installed: $(npm --version)"
else
    echo "❌ npm not found! Should come with Node.js"
fi
echo ""

echo "============================================"
echo "Summary"
echo "============================================"
command -v python3 &> /dev/null && echo "Python: ✅" || echo "Python: ❌"
command -v node &> /dev/null && echo "Node.js: ✅" || echo "Node.js: ❌"
command -v npm &> /dev/null && echo "npm: ✅" || echo "npm: ❌"
echo ""
```

Run it:
```bash
# Windows
check-prerequisites.bat

# Mac/Linux
chmod +x check-prerequisites.sh
./check-prerequisites.sh
```

---

## 🎯 After Installation

Once everything is installed:

1. **Backend setup**:
   ```batch
   cd backend
   python -m venv venv
   venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **UI setup**:
   ```batch
   cd electron-ui
   npm install
   ```

3. **Start development**:
   ```batch
   # Terminal 1
   scripts\start-backend-local.bat
   
   # Terminal 2
   scripts\start-ui-local.bat
   ```

---

## 🆘 Troubleshooting

### Python not recognized

**Windows**:
```batch
# Python installed but not in PATH
# Reinstall Python and check "Add Python to PATH"
# Or manually add to PATH:
setx PATH "%PATH%;C:\Python311;C:\Python311\Scripts"
```

**Mac/Linux**:
```bash
# Use python3 instead of python
python3 --version
```

### npm not found after installing Node.js

**Windows**:
```batch
# Restart your terminal/command prompt
# Node.js installer should have added npm to PATH

# Verify installation location
where node
where npm

# If not found, reinstall Node.js
```

**Mac/Linux**:
```bash
# Restart terminal
# Check installation
which node
which npm

# If using nvm, activate it
nvm use 20
```

### Permission errors (Mac/Linux)

```bash
# Don't use sudo with npm
# Instead, fix npm permissions:
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

---

## 📚 Next Steps

After installing all prerequisites:

1. ✅ Read: `LOCAL-QUICK-START.md`
2. ✅ Run: `scripts\start-backend-local.bat`
3. ✅ Run: `scripts\start-ui-local.bat`
4. ✅ Start building your RAG app!

---

## 🔗 Official Download Links

- **Python**: https://www.python.org/downloads/
- **Node.js**: https://nodejs.org/ (includes npm)
- **Azure Portal**: https://portal.azure.com
- **OpenAI Platform**: https://platform.openai.com

---

## ✅ Installation Checklist

Before running the app, verify:

- [ ] Python 3.11+ installed (`python --version`)
- [ ] pip installed (`pip --version`)
- [ ] Node.js 18+ installed (`node --version`)
- [ ] npm installed (`npm --version`)
- [ ] Azure OpenAI or OpenAI API key obtained
- [ ] All commands work in terminal

**When all checked, you're ready to run locally!** 🚀

