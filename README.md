# RAG Knowledge Assistant - Developer Week 2026

Enterprise-grade Retrieval-Augmented Generation (RAG) system with multi-cloud deployment, real-time document processing, and intelligent failover capabilities.

---

## 🏗️ Architecture Overview

### **Document Ingestion Pipeline**
```
Upload (Electron UI) → Backend API → S3 → SQS → Chunker Lambda → SQS → Embedder Lambda → Pinecone
                                      ↓                ↓                       ↓
                                  DynamoDB         DynamoDB                DynamoDB
                                (uploaded)        (chunked)               (completed)
```

### **Inference Pipeline**
```
Question (Electron UI) → Backend API → Pinecone (vector search) → Azure OpenAI (GPT-4) → Response
                                            ↓                              ↓
                                    Retrieve relevant chunks      Generate answer with context
                                                                  (Multi-region failover)
```

---

## 🌐 End-to-End Infrastructure

| Component | Platform | Link |
|-----------|----------|------|
| **Infrastructure** | Terraform Cloud | [Workspace](https://app.terraform.io/app/agentic-ai-org/workspaces/agentic-ai-rag-workspace/runs) |
| **CI/CD** | GitHub Actions | `.github/workflows/` |
| **AI/ML** | Azure OpenAI | [Resource Usage](https://ai.azure.com/observability/resourceUsage?wsid=/subscriptions/ed8ae890-acf2-41b8-b5df-f2576f8168db/resourceGroups/developer-week/providers/Microsoft.CognitiveServices/accounts/my-openai-us-east-1&tid=08ff7ffa-252f-450e-8351-d9a86602a790&selectedDeployments=/subscriptions/ed8ae890-acf2-41b8-b5df-f2576f8168db/resourceGroups/developer-week/providers/Microsoft.CognitiveServices/accounts/my-openai-us-east-1/deployments/gpt-4o-mini) |
| **Vector Store** | Pinecone | [Index Browser](https://app.pinecone.io/organizations/-Olo5gbrEffVec7geolk/projects/047b8708-0520-49de-bc71-4fce13e5468d/indexes/rag-demo/browser) |
| **Compute** | AWS ECS + Lambda | EC2: `http://54.89.155.20:8000` |

---

## 📋 Quick Start

### Local Development
```bash
# Backend
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload

# UI
cd electron-ui
npm install
npm run dev
```

### Production Deployment
```bash
# Terraform (automated via Terraform Cloud)
terraform plan
terraform apply

# GitHub Actions (automated on push)
git push origin main
```

---

## 📚 Documentation

| Topic | Document |
|-------|----------|
| **Architecture** | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| **Document Status** | [HOW-TO-CHECK-DOCUMENT-STATUS.md](HOW-TO-CHECK-DOCUMENT-STATUS.md) |
| **Local Setup** | [LOCAL-QUICK-START.md](LOCAL-QUICK-START.md) |
| **Deployment** | [DEPLOYMENT-READY.md](DEPLOYMENT-READY.md) |
| **Pinecone Setup** | [docs/PINECONE-COMPLETE-FLOW.md](docs/PINECONE-COMPLETE-FLOW.md) |
| **LangSmith Tracing** | [LANGSMITH-AUTO-TRACING.md](LANGSMITH-AUTO-TRACING.md) |
| **CI/CD** | [docs/CI-CD-SUMMARY.md](docs/CI-CD-SUMMARY.md) |

---

## 🔧 Technology Stack

**Backend:** FastAPI, LangChain, Azure OpenAI  
**Ingestion:** AWS Lambda, SQS, S3  
**Vector DB:** Pinecone (1536-dim embeddings)  
**Tracking:** DynamoDB, LangSmith  
**UI:** Electron, React, TypeScript  
**Infrastructure:** Terraform, GitHub Actions, AWS ECS

---

## 🚀 Key Features

✅ **Asynchronous Processing** - Lambda-based chunking and embedding  
✅ **Real-time Status Tracking** - DynamoDB + polling UI  
✅ **Multi-region Failover** - Azure OpenAI US-East ↔ EU-West  
✅ **Observability** - LangSmith auto-tracing, CloudWatch logs  
✅ **Production Ready** - ECS deployment, health checks, auto-scaling

---

## 📞 Support

See [docs/](docs/) for detailed guides on setup, deployment, and troubleshooting.
