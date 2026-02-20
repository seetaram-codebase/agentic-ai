# Running RAG Demo Locally - Complete Guide

## 🏠 Local Development Setup

This guide shows you how to run the **complete RAG application on your local machine** without AWS.

---

## 📋 Prerequisites

### Required Software

1. **Python 3.11+**
   ```bash
   python --version
   # Should show: Python 3.11.x or higher
   ```

2. **Node.js 18+** (for Electron UI)
   ```bash
   node --version
   # Should show: v18.x or higher
   ```

3. **Git**
   ```bash
   git --version
   ```

### Required Accounts

- **Azure OpenAI** account (for AI responses)
  - Or OpenAI API key as alternative

---

## 🚀 Quick Start (3 Steps)

### Step 1: Start the Backend

```bash
# Navigate to backend directory
cd C:\Users\seeta\IdeaProjects\agentic-ai\backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
.\venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create .env file
copy .env.example .env
# Edit .env with your Azure OpenAI credentials

# Start the backend server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Backend will start at**: `http://localhost:8000`

### Step 2: Start the Electron UI

Open a **new terminal**:

```bash
# Navigate to electron-ui directory
cd C:\Users\seeta\IdeaProjects\agentic-ai\electron-ui

# Install dependencies
npm install

# Start in development mode
npm run dev
```

**Electron app will open automatically**

### Step 3: Use the Application

1. The Electron desktop app opens
2. Upload a PDF or TXT file
3. Wait for processing (~30 seconds for local processing)
4. Ask questions about your document
5. Get AI-powered answers!

---

## 📁 Detailed Setup Instructions

### 1️⃣ Backend Setup (FastAPI + ChromaDB)

#### Create Local Environment File

```bash
cd backend
```

Create `.env` file:

```bash
# .env
# ============================================
# Local Development Configuration
# ============================================

# Backend Mode - Local (no AWS)
USE_S3_UPLOAD=false
USE_SSM_CONFIG=false

# Azure OpenAI Configuration (Primary)
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your-api-key-here
AZURE_OPENAI_DEPLOYMENT=gpt-4
AZURE_OPENAI_API_VERSION=2024-02-01

# Azure OpenAI Embeddings
AZURE_OPENAI_EMBEDDING_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_EMBEDDING_API_KEY=your-api-key-here
AZURE_OPENAI_EMBEDDING_DEPLOYMENT=text-embedding-ada-002

# Local ChromaDB
CHROMA_PERSIST_DIR=./chroma_db
CHROMA_COLLECTION_NAME=rag-demo-local

# Application Settings
LOG_LEVEL=INFO
```

#### Install Dependencies

```bash
# Activate virtual environment
.\venv\Scripts\activate

# Install all dependencies
pip install -r requirements.txt

# Verify installation
pip list | grep fastapi
pip list | grep chromadb
pip list | grep langchain
```

#### Start Backend Server

```bash
# Development mode (auto-reload on changes)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Production mode
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

**Verify it's running**:
- Open browser: http://localhost:8000/docs
- You should see the Swagger UI

---

### 2️⃣ Electron UI Setup

#### Install Dependencies

```bash
cd electron-ui
npm install
```

#### Configure API Endpoint

The API client is already configured for `localhost:8000`:

**File**: `electron-ui/src/api/client.ts`
```typescript
const BASE_URL = 'http://localhost:8000';  // ✅ Already set for local
```

#### Start Development Mode

```bash
# Start Vite dev server + Electron
npm run dev
```

This will:
1. Start Vite dev server on `http://localhost:5173`
2. Open Electron window automatically
3. Hot reload on code changes

#### Build Desktop App (Optional)

```bash
# Build for your platform
npm run build

# Or build for specific platforms:
# Windows
npm run build -- --win

# macOS
npm run build -- --mac

# Linux
npm run build -- --linux

# Build for all platforms
npm run build -- --win --mac --linux
```

**Output**: `electron-ui/dist-electron/`

---

## 🔧 Configuration for Local Mode

### Backend Configuration Changes

Update `backend/app/main.py` to work locally without AWS:

The backend already has the logic, just ensure your `.env` has:
```bash
USE_S3_UPLOAD=false  # Don't use S3, process synchronously
USE_SSM_CONFIG=false  # Don't use AWS SSM
```

### How Local Mode Works

When `USE_S3_UPLOAD=false`:

```
┌─────────────────┐
│  Electron UI    │
└────────┬────────┘
         │ Upload File
         ↓
┌─────────────────┐
│  FastAPI        │
│  (localhost)    │
│                 │
│  1. Receive file│
│  2. Load PDF    │
│  3. Chunk text  │
│  4. Generate    │
│     embeddings  │
│  5. Store in    │
│     ChromaDB    │
│  6. Return      │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  ChromaDB       │
│  (local file)   │
│  ./chroma_db/   │
└─────────────────┘
```

**Processing happens synchronously in the backend** - no Lambda, no S3, no DynamoDB needed!

---

## 📊 Local vs AWS Mode Comparison

| Feature | Local Mode | AWS Mode |
|---------|-----------|----------|
| **Upload** | Direct to backend | S3 → Lambda |
| **Processing** | Synchronous (blocks) | Async (Lambda) |
| **Vector DB** | Local ChromaDB file | ChromaDB in ECS |
| **Storage** | Local filesystem | S3 + DynamoDB |
| **Speed** | Immediate response | 30-60s async |
| **Cost** | Free | ~$20-30/month |
| **Scale** | Single machine | Unlimited |
| **Best for** | Development, testing | Production |

---

## 🧪 Testing Local Setup

### 1. Test Backend API

```bash
# Health check
curl http://localhost:8000/health

# Expected response:
# {"status":"healthy","timestamp":"...","service":"rag-demo-api"}

# Test upload (in another terminal)
curl -X POST http://localhost:8000/upload \
  -F "file=@sample-docs/product-features.txt"
```

### 2. Test Electron UI

1. Open Electron app (automatically opens with `npm run dev`)
2. Click "Upload Document"
3. Select a PDF or TXT file
4. Wait for processing (should be fast in local mode)
5. Type a question in the chat
6. Get AI response!

### 3. Check ChromaDB

```bash
# ChromaDB data is stored locally
ls -la backend/chroma_db/

# You should see database files
```

---

## 🐛 Troubleshooting Local Setup

### Backend Issues

#### Issue: Port 8000 already in use
```bash
# Find process using port 8000
netstat -ano | findstr :8000

# Kill the process
taskkill /PID <PID> /F

# Or use a different port
uvicorn app.main:app --reload --port 8001
```

#### Issue: Module not found errors
```bash
# Ensure virtual environment is activated
.\venv\Scripts\activate

# Reinstall dependencies
pip install -r requirements.txt --force-reinstall
```

#### Issue: ChromaDB errors
```bash
# Clear ChromaDB directory
rm -rf backend/chroma_db

# Restart backend (ChromaDB will recreate)
```

### Electron UI Issues

#### Issue: Electron won't start
```bash
# Clear node_modules and reinstall
rm -rf node_modules
npm install

# Try running separately
npm run vite  # Terminal 1
npm start     # Terminal 2 (after vite starts)
```

#### Issue: Can't connect to backend
```bash
# Check if backend is running
curl http://localhost:8000/health

# Check API URL in src/api/client.ts
# Should be: http://localhost:8000
```

#### Issue: Build fails
```bash
# Ensure all dependencies are installed
npm install electron-builder --save-dev

# Try building without all platforms
npm run build -- --win  # Windows only
```

---

## 📦 Building Standalone Desktop Apps

### For Distribution

```bash
cd electron-ui

# Build for Windows (creates .exe installer)
npm run build -- --win

# Build for macOS (creates .dmg)
npm run build -- --mac

# Build for Linux (creates .AppImage)
npm run build -- --linux

# Build for all platforms
npm run build -- --win --mac --linux
```

**Output location**: `electron-ui/dist-electron/`

### Build Results

After building, you'll get:

**Windows**:
- `RAG Demo Setup 1.0.0.exe` - Installer
- `RAG Demo 1.0.0.exe` - Portable exe

**macOS**:
- `RAG Demo-1.0.0.dmg` - DMG installer
- `RAG Demo.app` - Application bundle

**Linux**:
- `RAG Demo-1.0.0.AppImage` - AppImage (portable)
- `rag-demo_1.0.0_amd64.deb` - Debian package

### Installing Built Apps

**Users don't need**:
- ✅ No Python installation required
- ✅ No Node.js required
- ✅ No dependencies to install
- ✅ Just run the installer!

**But they DO need**:
- ⚠️ Backend server running (see "Distributing to Users" below)

---

## 🚀 Distributing to Users

### Option 1: Backend Included (Recommended)

Package backend with Electron app:

1. **Build backend as executable** using PyInstaller:

```bash
cd backend
pip install pyinstaller

# Create standalone executable
pyinstaller --onefile \
  --add-data "app:app" \
  --hidden-import uvicorn \
  --hidden-import app.main \
  -n rag-demo-backend \
  app/main.py
```

2. **Include in Electron build**:

Update `electron-ui/main.js` to start backend automatically:

```javascript
const { spawn } = require('child_process');
const path = require('path');

// Start backend server
const backendPath = path.join(__dirname, 'backend', 'rag-demo-backend.exe');
const backend = spawn(backendPath);

// Rest of your Electron code...
```

### Option 2: Separate Installation (Simpler)

**For users**:
1. Install backend server first (one-time setup)
2. Install Electron desktop app
3. Backend runs in background, UI connects to it

**Instructions for users**:
```
1. Install Python 3.11+
2. Run: install-backend.bat
3. Install RAG Demo.exe
4. Run RAG Demo from desktop
```

---

## 🎯 Complete Local Development Workflow

### Daily Development

```bash
# Terminal 1: Backend
cd backend
.\venv\Scripts\activate
uvicorn app.main:app --reload

# Terminal 2: Electron UI
cd electron-ui
npm run dev
```

### Making Changes

**Backend changes**:
1. Edit files in `backend/app/`
2. Save (auto-reloads with `--reload` flag)
3. Test in Electron UI or Swagger docs

**UI changes**:
1. Edit files in `electron-ui/src/`
2. Save (hot reload automatic)
3. Changes appear immediately in Electron window

### Testing

```bash
# Backend tests
cd backend
pytest

# UI tests (if configured)
cd electron-ui
npm test
```

---

## 📚 Project Structure for Local Development

```
agentic-ai/
├── backend/                    # FastAPI Backend
│   ├── app/
│   │   ├── main.py            # Main API (endpoints)
│   │   ├── rag_engine.py      # RAG logic
│   │   ├── azure_openai.py    # Azure OpenAI client
│   │   └── vector_store.py    # ChromaDB interface
│   ├── requirements.txt       # Python dependencies
│   ├── .env                   # Local configuration ← CREATE THIS
│   ├── venv/                  # Virtual environment
│   └── chroma_db/             # Local vector database
│
├── electron-ui/               # Electron Desktop App
│   ├── src/
│   │   ├── App.tsx           # Main React component
│   │   ├── api/client.ts     # API client (localhost:8000)
│   │   └── styles.css        # Styles
│   ├── main.js               # Electron main process
│   ├── preload.js            # Electron preload script
│   ├── package.json          # Node dependencies
│   └── dist-electron/        # Built desktop apps ← OUTPUT
│
└── sample-docs/              # Test documents
    ├── product-features.txt
    └── architecture-overview.txt
```

---

## ✅ Checklist for Local Setup

### Initial Setup
- [ ] Python 3.11+ installed
- [ ] Node.js 18+ installed
- [ ] Git repository cloned
- [ ] Azure OpenAI credentials obtained

### Backend Setup
- [ ] Virtual environment created (`python -m venv venv`)
- [ ] Dependencies installed (`pip install -r requirements.txt`)
- [ ] `.env` file created with Azure credentials
- [ ] Backend starts successfully (`uvicorn app.main:app --reload`)
- [ ] Swagger UI accessible at http://localhost:8000/docs

### Electron UI Setup
- [ ] npm dependencies installed (`npm install`)
- [ ] Development mode works (`npm run dev`)
- [ ] Electron window opens
- [ ] Can connect to backend

### Testing
- [ ] Upload a document successfully
- [ ] Document appears in list
- [ ] Can query the document
- [ ] Receives AI-powered responses

### Building (Optional)
- [ ] Desktop app builds (`npm run build`)
- [ ] Installer created in `dist-electron/`
- [ ] Built app runs independently

---

## 🎉 You're Ready!

Now you can:
- ✅ Develop locally without AWS
- ✅ Test changes immediately
- ✅ Build desktop apps for Windows/Mac/Linux
- ✅ Distribute to users

**Start developing**:
```bash
# Terminal 1
cd backend && .\venv\Scripts\activate && uvicorn app.main:app --reload

# Terminal 2
cd electron-ui && npm run dev
```

**Happy coding! 🚀**

