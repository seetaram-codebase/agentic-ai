# Phase 1: 2-Hour MVP Build

## 🎯 Goal
Get a working RAG demo in 2 hours that you can enhance over the next 4 days.

## ⏱️ Time Breakdown

| Task | Time | Status |
|------|------|--------|
| Project setup | 10 min | ⬜ |
| FastAPI backend | 30 min | ⬜ |
| Chroma vector store | 20 min | ⬜ |
| Azure OpenAI integration | 20 min | ⬜ |
| Electron UI | 40 min | ⬜ |

## Step 1: Project Setup (10 min)

```bash
# Create directory structure
mkdir -p backend/app electron-ui aws scripts

# Install Python dependencies
cd backend
pip install fastapi uvicorn chromadb openai python-multipart langchain langchain-community pypdf python-dotenv
```

## Step 2: Environment Variables

Create `.env` file:
```env
# Azure OpenAI - Primary
AZURE_OPENAI_ENDPOINT_1=https://your-resource-1.openai.azure.com/
AZURE_OPENAI_KEY_1=your-key-1
AZURE_OPENAI_DEPLOYMENT_1=gpt-4

# Azure OpenAI - Failover
AZURE_OPENAI_ENDPOINT_2=https://your-resource-2.openai.azure.com/
AZURE_OPENAI_KEY_2=your-key-2
AZURE_OPENAI_DEPLOYMENT_2=gpt-4

# Vector DB
CHROMA_PERSIST_DIR=./chroma_db
PINECONE_API_KEY=your-pinecone-key
PINECONE_INDEX=rag-demo
```

## Step 3: Backend Implementation (30 min)

### File: `backend/app/main.py`
- POST `/upload` - Upload documents
- POST `/query` - Query the RAG system
- GET `/health` - Health check
- GET `/documents` - List ingested documents

### File: `backend/app/azure_openai.py`
- Primary/failover Azure OpenAI client
- Automatic failover on errors
- Health check for both subscriptions

### File: `backend/app/vector_store.py`
- Chroma local storage (MVP)
- Pinecone cloud storage (Day 2)

### File: `backend/app/rag_engine.py`
- Document chunking
- Embedding generation
- Context retrieval
- Response generation

## Step 4: Electron UI (40 min)

Simple UI with:
- File upload dropzone
- Query input box
- Response display
- Status indicators (primary/failover)
- Document list

## 🏃 Quick Start Commands

```bash
# Terminal 1: Start backend
cd backend
uvicorn app.main:app --reload --port 8000

# Terminal 2: Start Electron
cd electron-ui
npm install
npm start
```

## ✅ MVP Success Criteria

1. [ ] Can upload PDF/TXT files
2. [ ] Documents are chunked and embedded
3. [ ] Can query and get relevant responses
4. [ ] Failover indicator works
5. [ ] Basic UI is functional

## 🔄 What to Add in Next 4 Days

- Day 2: AWS S3 + SQS + Lambda pipeline
- Day 3: Pinecone cloud + real failover testing
- Day 4: UI polish + demo recording
