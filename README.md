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

## 🔐 Pinecone Integration

This application uses **Pinecone** as the cloud vector database for storing document embeddings.

### How Lambda Reads Pinecone API Key

Lambda functions securely read the Pinecone API key from **AWS Systems Manager (SSM) Parameter Store** at runtime:

```
Terraform → SSM Parameter (placeholder)
    ↓
You Update → SSM with real API key (one-time)
    ↓
Lambda Env Var → Parameter NAME (not value)
    ↓
Lambda Runtime → boto3.client('ssm').get_parameter()
    ↓
AWS SSM/KMS → Decrypt and return API key
    ↓
Pinecone Client → Initialized with API key
```

**Security Benefits:**
- ✅ No secrets in code or Git
- ✅ Encrypted at rest with KMS
- ✅ IAM-based access control
- ✅ Easy rotation without code changes

**Quick Setup:**
```powershell
# 1. Deploy infrastructure
cd infrastructure/terraform
terraform apply

# 2. Update SSM with your Pinecone API key
aws ssm put-parameter `
  --name "/rag-demo/pinecone/api-key" `
  --value "pc-YOUR-API-KEY" `
  --type "SecureString" `
  --overwrite

# 3. Verify
aws logs tail /aws/lambda/rag-demo-embedder --follow
```

**📚 Documentation:**
- **[PINECONE-HOW-IT-WORKS.md](docs/PINECONE-HOW-IT-WORKS.md)** - Complete guide
- **[PINECONE-API-KEY-QUICKREF.md](docs/PINECONE-API-KEY-QUICKREF.md)** - Quick reference
- **[PINECONE-DOCS-INDEX.md](docs/PINECONE-DOCS-INDEX.md)** - All Pinecone docs

## 📁 Project Structure

```
agentic-ai/
├── .github/
│   └── workflows/
│       ├── backend-ci.yml       # Backend lint, test, build
│       ├── frontend-ci.yml      # Frontend lint, build
│       ├── deploy-ecs.yml       # Deploy to AWS ECS
│       ├── deploy-lambda.yml    # Deploy Lambda functions
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
├── lambda/                      # AWS Lambda functions
│   ├── chunker/                # Document chunking
│   │   ├── handler.py
│   │   └── requirements.txt
│   └── embedder/               # Embedding generation
│       ├── handler.py          # Reads Pinecone key from SSM
│       └── requirements.txt
├── electron-ui/                 # Electron frontend
│   ├── src/
│   │   ├── App.tsx
│   │   ├── api/client.ts
│   │   └── styles.css
│   ├── main.js
│   └── package.json
├── infrastructure/              # Infrastructure as Code
│   └── terraform/
│       ├── lambda.tf           # Lambda configuration
│       ├── ssm.tf              # SSM parameters (Pinecone key)
│       ├── ecs.tf              # ECS, ECR
│       └── s3.tf               # S3, SQS, DynamoDB
├── docs/                        # Documentation
│   ├── PINECONE-HOW-IT-WORKS.md     # Pinecone integration guide
│   ├── PINECONE-DOCS-INDEX.md       # Pinecone docs index
│   ├── 00-overview.md
│   ├── SETUP-REQUIREMENTS.md
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
