# 🏠 Run Locally - Quick Reference

## ⚡ Super Quick Start (Windows)

### Option 1: Automated Scripts (Easiest)

```batch
REM Terminal 1: Start Backend
scripts\start-backend-local.bat

REM Terminal 2: Start UI
scripts\start-ui-local.bat
```

### Option 2: Manual Start

```batch
REM Terminal 1: Backend
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
copy .env.local.example .env
REM Edit .env with your Azure OpenAI keys
uvicorn app.main:app --reload

REM Terminal 2: Electron UI
cd electron-ui
npm install
npm run dev
```

---

## 📋 Prerequisites

✅ **Python 3.11+** - https://www.python.org/  
✅ **Node.js 18+** - https://nodejs.org/  
✅ **Azure OpenAI account** - Or OpenAI API key

---

## 🎯 What You Get Locally

### Backend (FastAPI)
- **URL**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **No AWS needed**: Runs completely offline
- **Local storage**: ChromaDB in `backend/chroma_db/`

### Electron UI
- **Desktop app**: Auto-opens after `npm run dev`
- **Hot reload**: Changes update immediately
- **Platform**: Works on Windows, Mac, Linux

---

## 🔧 Configuration

### Backend `.env` File

```bash
# Required: Azure OpenAI
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your-key-here
AZURE_OPENAI_DEPLOYMENT=gpt-4

# Local mode (no AWS)
USE_S3_UPLOAD=false
USE_SSM_CONFIG=false
```

---

## 📦 Building Desktop Apps

```batch
cd electron-ui

REM Build for Windows
npm run build -- --win

REM Build for macOS
npm run build -- --mac

REM Build for Linux
npm run build -- --linux

REM Build for all platforms
npm run build -- --win --mac --linux
```

**Output**: `electron-ui/dist-electron/`

---

## 🔄 Local vs AWS

| Feature | Local | AWS |
|---------|-------|-----|
| **Backend** | FastAPI (localhost) | ECS Fargate |
| **Processing** | Synchronous | Async (Lambda) |
| **Storage** | Local files | S3 + DynamoDB |
| **Vector DB** | ChromaDB (file) | ChromaDB (ECS) |
| **Cost** | **FREE** | ~$20-30/month |
| **Setup** | 5 minutes | 30 minutes |
| **Best for** | Dev/Testing | Production |

---

## 🐛 Quick Troubleshooting

### Backend won't start
```batch
REM Check Python version
python --version

REM Recreate virtual environment
rmdir /s venv
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

### UI won't connect
```batch
REM Check backend is running
curl http://localhost:8000/health

REM Verify API URL in electron-ui/src/api/client.ts
REM Should be: http://localhost:8000
```

### Port 8000 in use
```batch
REM Find what's using port 8000
netstat -ano | findstr :8000

REM Kill the process
taskkill /PID <PID> /F
```

---

## 📚 Full Documentation

**See**: `docs/RUN-LOCALLY.md` for complete guide

---

## ✅ Success Checklist

- [ ] Backend starts: `http://localhost:8000/docs` works
- [ ] Electron app opens automatically
- [ ] Upload a test document (PDF or TXT)
- [ ] Ask a question about the document
- [ ] Get AI-powered response

---

## 🎉 You're Running Locally!

**No AWS, No Cloud, Just Your Machine** ✨

