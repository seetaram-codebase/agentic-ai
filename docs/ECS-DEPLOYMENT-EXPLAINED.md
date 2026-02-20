# ECS Deployment Process - Complete Explanation

## ✅ Yes! Deploy ECS Workflow Compiles and Deploys

The **Deploy to ECS** workflow (`deploy-ecs.yml`) does the following:

1. ✅ **Compiles/Builds** your Python code into a Docker container
2. ✅ **Pushes** the image to Amazon ECR (container registry)
3. ✅ **Deploys** the new container to ECS Fargate
4. ✅ **Updates** the running service with zero downtime

---

## 🔄 Complete ECS Deployment Flow

### Step-by-Step Process

```
┌─────────────────────────────────────────────────────────┐
│ 1. Trigger Workflow                                      │
│    - Manual: Actions → Deploy to ECS → Run workflow     │
│    - Automatic: Push to main (backend/** changes)       │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Checkout Code                                         │
│    - Downloads latest code from GitHub                  │
│    - Includes: backend/app/*, Dockerfile, requirements  │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ 3. Build Docker Image                                    │
│    cd backend                                            │
│    docker build -t <registry>/rag-demo-backend:sha .    │
│                                                          │
│    This runs Dockerfile which:                          │
│    - Uses Python 3.11 base image                        │
│    - Copies requirements.txt                            │
│    - pip install -r requirements.txt ← COMPILES DEPS    │
│    - Copies all Python code (app/*.py)                  │
│    - Sets up FastAPI server                             │
│    - Creates final container image                      │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Push to ECR (Container Registry)                     │
│    docker push <registry>/rag-demo-backend:sha          │
│    docker push <registry>/rag-demo-backend:latest       │
│                                                          │
│    Image stored in: Amazon ECR repository               │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ 5. Update ECS Task Definition                           │
│    - Downloads current task definition                  │
│    - Updates container image to new version             │
│    - Keeps all other settings (CPU, memory, env vars)   │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ 6. Deploy to ECS Service                                │
│    - ECS creates new tasks with new container image     │
│    - Waits for new tasks to become healthy              │
│    - Gradually replaces old tasks (zero downtime)       │
│    - Old tasks drained and stopped                      │
└─────────────────────────────────────────────────────────┘
                           ↓
                    ✅ DEPLOYMENT COMPLETE!
```

---

## 🐳 What Happens During Docker Build

### Dockerfile Execution

When `docker build` runs, it executes your `backend/Dockerfile`:

```dockerfile
# 1. Start with Python base image
FROM python:3.11-slim

# 2. Set working directory
WORKDIR /app

# 3. Copy and install dependencies (COMPILATION HAPPENS HERE)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# This installs: FastAPI, LangChain, ChromaDB, boto3, etc.

# 4. Copy application code
COPY app/ ./app/

# 5. Expose port
EXPOSE 8000

# 6. Set startup command
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**What gets compiled/installed**:
- ✅ FastAPI framework
- ✅ LangChain libraries
- ✅ ChromaDB vector database
- ✅ boto3 (AWS SDK)
- ✅ All Python dependencies from `requirements.txt`

**Result**: A complete, self-contained Docker image (~2-3 GB) with:
- Python runtime
- All your code
- All dependencies
- Ready to run

---

## 📊 Build vs Deploy

### What is "Compilation"?

For Python (interpreted language), "compilation" means:

1. **Installing Dependencies**
   ```bash
   pip install -r requirements.txt
   # Downloads and installs all packages
   # Compiles native extensions (if any)
   # Creates Python bytecode
   ```

2. **Creating Docker Image**
   ```bash
   docker build -t rag-demo-backend .
   # Packages everything into a container
   # ~2-3 GB final image
   ```

3. **Result**: Executable container that can run anywhere

---

## 🚀 Deployment Process

### How ECS Deploys the New Image

```
Current State:
┌──────────────────────────────┐
│ ECS Service: backend         │
│ Running Tasks: 1             │
│ Image: rag-demo-backend:old  │
└──────────────────────────────┘

After deployment trigger:

Step 1: Create new task
┌──────────────────────────────┐
│ New Task (starting)          │
│ Image: rag-demo-backend:new  │
└──────────────────────────────┘

Step 2: Wait for health check
┌──────────────────────────────┐
│ New Task (healthy) ✅        │
│ Health: GET /health → 200    │
└──────────────────────────────┘

Step 3: Drain old task
┌──────────────────────────────┐
│ Old Task (draining)          │
│ No new connections           │
└──────────────────────────────┘

Step 4: Complete
┌──────────────────────────────┐
│ ECS Service: backend         │
│ Running Tasks: 1             │
│ Image: rag-demo-backend:new ✅│
└──────────────────────────────┘
```

**Zero Downtime Deployment!** ✅

---

## 🎯 What Gets Deployed

### Your Python Application Code

All files in `backend/app/`:
- ✅ `main.py` - FastAPI application, API endpoints
- ✅ `rag_engine.py` - Document processing, RAG logic
- ✅ `azure_openai.py` - Azure OpenAI client, failover
- ✅ `vector_store.py` - ChromaDB/Pinecone integration
- ✅ `ssm_config.py` - AWS SSM parameter store
- ✅ `dynamodb_config.py` - DynamoDB configuration

### Dependencies Installed

From `backend/requirements.txt`:
```python
fastapi==0.109.0         # Web framework
uvicorn==0.27.0          # ASGI server
langchain==0.1.20        # RAG framework
chromadb==0.4.24         # Vector database
boto3==1.34.0            # AWS SDK
# ... and more
```

### Environment Variables

Configured in ECS Task Definition:
```bash
USE_SSM_CONFIG=true
AWS_REGION=us-east-1
S3_BUCKET=rag-demo-documents-971778147952
DYNAMODB_CONFIG_TABLE=rag-demo-config
DYNAMODB_DOCUMENTS_TABLE=rag-demo-documents
# ... and more
```

---

## 🔍 Verification After Deployment

### Check Deployment Status

```bash
# Get ECS service status
aws ecs describe-services \
  --cluster rag-demo \
  --services backend

# Look for:
# - desiredCount: 1
# - runningCount: 1
# - deployments: [status: PRIMARY, rolloutState: COMPLETED]
```

### Get Container Endpoint

```bash
# Get task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster rag-demo \
  --service-name backend \
  --query 'taskArns[0]' \
  --output text)

# Get task details
aws ecs describe-tasks \
  --cluster rag-demo \
  --tasks $TASK_ARN \
  --query 'tasks[0].attachments[0].details'

# Find publicIp in the output
```

### Test the API

```bash
# Health check
curl http://<public-ip>:8000/health

# Expected response:
# {
#   "status": "healthy",
#   "timestamp": "2026-02-17T...",
#   "service": "rag-demo-api"
# }

# Ready check
curl http://<public-ip>:8000/ready

# Test upload
curl -X POST http://<public-ip>:8000/upload \
  -F "file=@test.pdf"
```

---

## 📋 Workflow Triggers

### Automatic Deployment

Deploys automatically when you push to `main` branch with changes in `backend/**`:

```bash
# Make changes to backend code
vim backend/app/main.py

# Commit and push
git add backend/app/main.py
git commit -m "Update API endpoint"
git push origin main

# Workflow automatically triggers!
# 1. Detects backend/** path changed
# 2. Builds new Docker image
# 3. Deploys to ECS
```

### Manual Deployment

Deploy manually via GitHub Actions:

```bash
# Go to: Actions → Deploy to ECS → Run workflow
# Select:
#   - Environment: dev
#   - Registry: ecr
# Click: Run workflow

# Workflow runs same build/deploy process
```

---

## 🏗️ Build Architecture

### What Gets Built

```
Docker Image: rag-demo-backend:latest
├── Base Layer: python:3.11-slim (900 MB)
├── Dependencies Layer: pip packages (1-2 GB)
│   ├── FastAPI + uvicorn
│   ├── LangChain + OpenAI
│   ├── ChromaDB (large!)
│   ├── boto3
│   └── Other packages
├── Application Layer: Your code (1-5 MB)
│   ├── app/main.py
│   ├── app/rag_engine.py
│   ├── app/azure_openai.py
│   └── Other modules
└── Config Layer: Dockerfile, CMD
    └── uvicorn app.main:app

Total Size: ~2-3 GB
```

### Why Docker?

**Benefits**:
- ✅ **Consistent environment** - Works same everywhere
- ✅ **Isolated dependencies** - No conflicts with other apps
- ✅ **Easy deployment** - Just update image version
- ✅ **Scalable** - ECS can run multiple containers
- ✅ **Version control** - Each build tagged with git SHA

---

## 💰 What This Costs

### ECS Fargate Pricing

**Development (1 task, 0.5 vCPU, 1 GB RAM)**:
- Per hour: $0.02068
- Per day: $0.50
- Per month: ~$15

**Build Process**:
- Docker build: Free (runs in GitHub Actions)
- ECR storage: $0.10/GB/month (~$0.30 for 3 GB image)

**Total**: ~$15-20/month for dev environment

---

## 🔄 Update Workflow

### Making Changes to Backend

```bash
# 1. Make code changes
vim backend/app/main.py

# 2. Test locally (optional)
cd backend
uvicorn app.main:app --reload

# 3. Commit changes
git add backend/app/main.py
git commit -m "Add new feature"

# 4. Push to trigger deployment
git push origin main

# 5. GitHub Actions automatically:
#    - Builds new Docker image
#    - Pushes to ECR
#    - Updates ECS service
#    - New code deployed in ~5-10 minutes

# 6. Verify deployment
curl http://<ecs-ip>:8000/health
```

---

## 🎯 Summary

**Question**: Does deploy-ecs compile code and deploy to ECS?

**Answer**: ✅ **YES!**

**What it does**:
1. ✅ **Compiles** (builds Docker image with all dependencies)
2. ✅ **Tests** (optional, can add test step)
3. ✅ **Packages** (creates container with code + runtime)
4. ✅ **Pushes** (uploads to Amazon ECR)
5. ✅ **Deploys** (updates ECS service with new image)
6. ✅ **Verifies** (waits for service to be stable)

**Result**: Your Python FastAPI backend running in AWS ECS Fargate with:
- ✅ All your code
- ✅ All dependencies installed
- ✅ Ready to handle requests
- ✅ Auto-scaling capable
- ✅ Zero downtime deployments

---

## 📚 Related Documentation

- **Deployment Guide**: `docs/GITHUB-ACTIONS-SETUP.md`
- **Processing Flow**: `docs/DEPLOYMENT-AND-PROCESSING-FLOW.md`
- **API Usage**: `docs/API-USAGE-GUIDE.md`
- **Troubleshooting**: `docs/GITHUB-ACTIONS-TROUBLESHOOTING.md`

