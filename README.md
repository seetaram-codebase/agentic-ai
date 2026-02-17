# RAG Demo - Developer Week

A scalable RAG (Retrieval-Augmented Generation) application demonstrating enterprise-grade document intelligence with Azure OpenAI failover.

## 🎯 Features

- **Document Ingestion**: Upload PDF/TXT files for processing
- **Vector Storage**: Chroma (local) or Pinecone (cloud)
- **Azure OpenAI**: Multi-subscription failover support
- **Electron UI**: Modern desktop application
- **Demo Ready**: Built-in failover trigger for demonstrations

## 🚀 Quick Start (2 Hours MVP)

### Prerequisites

- Python 3.11+
- Node.js 18+
- Azure OpenAI subscription(s)

### 1. Clone and Setup

```powershell
cd C:\Users\seeta\IdeaProjects\agentic-ai

# Copy environment template
cp backend\.env.example backend\.env

# Edit .env with your Azure OpenAI credentials
notepad backend\.env
```

### 2. Configure Azure OpenAI

Edit `backend\.env`:
```env
AZURE_OPENAI_ENDPOINT_1=https://your-resource.openai.azure.com/
AZURE_OPENAI_KEY_1=your-api-key
AZURE_OPENAI_DEPLOYMENT_1=gpt-4

# Optional: Failover endpoint
AZURE_OPENAI_ENDPOINT_2=https://your-backup-resource.openai.azure.com/
AZURE_OPENAI_KEY_2=your-backup-key
AZURE_OPENAI_DEPLOYMENT_2=gpt-4
```

### 3. Install Dependencies

```powershell
# Backend
cd backend
pip install -r requirements.txt

# Frontend
cd ..\electron-ui
npm install
```

### 4. Start the Demo

```powershell
# Terminal 1: Backend
cd backend
uvicorn app.main:app --reload --port 8000

# Terminal 2: Electron UI
cd electron-ui
npm run dev
```

### 5. Use the Demo

1. Open the Electron app (launches automatically)
2. Drag & drop PDF/TXT files to upload
3. Ask questions about your documents
4. Click "Trigger Failover" to demo failover capability

## 📁 Project Structure

```
agentic-ai/
├── .github/
│   └── workflows/
│       ├── backend-ci.yml       # Backend lint, test, build
│       ├── frontend-ci.yml      # Frontend lint, build
│       ├── deploy-ecs.yml       # Deploy to AWS ECS
│       ├── build-electron.yml   # Build Electron for Win/Mac/Linux
│       └── infrastructure.yml   # Terraform plan/apply
├── backend/                     # FastAPI backend
│   ├── app/
│   │   ├── main.py             # API endpoints
│   │   ├── azure_openai.py     # Failover client
│   │   ├── vector_store.py     # Chroma/Pinecone
│   │   ├── rag_engine.py       # RAG logic
│   │   └── dynamodb_config.py  # DynamoDB config store
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .env.example
├── electron-ui/                 # Electron frontend
│   ├── src/
│   │   ├── App.tsx
│   │   ├── api/client.ts
│   │   └── styles.css
│   ├── main.js
│   └── package.json
├── infrastructure/              # Infrastructure as Code
│   └── terraform/
│       └── main.tf             # ECS, ECR, DynamoDB
├── docs/                        # Documentation
│   ├── 00-overview.md
│   ├── SETUP-REQUIREMENTS.md
│   ├── ecs-cost-estimation.md
│   ├── project-organization-plan.md
│   └── architecture/
├── sample-docs/                 # Test documents
└── scripts/                     # Utility scripts
```

## 💰 Cost Estimation

| Service | Per Hour |
|---------|----------|
| AWS (Lambda, S3, SQS) | ~$0.10 |
| Azure OpenAI (GPT-4) | ~$0.50-2.00 |
| Pinecone (Free Tier) | $0.00 |
| **Total** | **~$0.60-2.10/hr** |

See [cost-estimation.md](docs/cost-estimation.md) for details.

## 🔄 Failover Architecture

```
┌──────────────┐     ┌──────────────┐
│   Primary    │     │  Secondary   │
│  Azure OpenAI│ ──▶ │  Azure OpenAI│
│  (East US)   │     │  (West US)   │
└──────────────┘     └──────────────┘
       │                    │
       └────────┬───────────┘
                │
         Automatic Failover
         on 429/500/Timeout
```

## 📋 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/upload` | Upload document |
| POST | `/query` | Query documents |
| GET | `/stats` | Get system stats |
| GET | `/demo/health-status` | Check endpoint health |
| POST | `/demo/trigger-failover` | Trigger failover (demo) |

## 🎬 Demo Day

See [06-phase6-demo-preparation.md](docs/06-phase6-demo-preparation.md) for:
- Demo script
- Recording setup
- Troubleshooting guide
- Emergency commands

## 📄 License

MIT License - Built for Developer Week 2026
