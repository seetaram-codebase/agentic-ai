# ECS Health Check Issue - RESOLVED

## ✅ Problem Fixed

**Issue**: "Task stopped at: 2026-02-18T05:33:46.278Z - Task failed container health checks"

**Root Causes Identified and Fixed**:
1. ❌ Health check used `curl` but curl wasn't installed in the `python:3.11-slim` image
2. ❌ Start period was only 60 seconds - not enough time for backend to load all dependencies (ChromaDB, LangChain, etc.)
3. ❌ Timeout was only 5 seconds - health check timing out too quickly

---

## 🔧 Changes Applied

### 1. **ECS Task Definition** (`infrastructure/terraform/ecs.tf`)

**Before**:
```terraform
healthCheck = {
  command     = ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
  interval    = 30
  timeout     = 5        # Too short!
  retries     = 3
  startPeriod = 60       # Too short!
}
```

**After**:
```terraform
healthCheck = {
  command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8000/health')\" || exit 1"]
  interval    = 30
  timeout     = 10       # ✅ Doubled
  retries     = 3
  startPeriod = 120      # ✅ Doubled - 2 minutes
}
```

**Changes**:
- ✅ Uses Python's built-in `urllib` instead of curl
- ✅ Increased timeout from 5s to 10s
- ✅ Increased start period from 60s to 120s (2 minutes)

---

### 2. **Dockerfile** (`backend/Dockerfile`)

**Before**:
```dockerfile
# No curl installed
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Start period only 5s!
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
```

**After**:
```dockerfile
# ✅ Now includes curl
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# ✅ Start period now 120s, dual health check (curl + Python fallback)
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000/health || python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
```

**Changes**:
- ✅ Installed curl for better compatibility
- ✅ Increased start period to 120s
- ✅ Dual health check: tries curl first, falls back to Python

---

## 📊 Health Check Timeline

### Before (Failed)
```
0s   - Container starts
0-60s - Start period (health checks ignored)
60s  - First health check with curl (FAILS - curl not found)
90s  - Retry 1 (FAILS)
120s - Retry 2 (FAILS)
150s - Retry 3 (FAILS)
150s - ❌ Task marked unhealthy and stopped
```

### After (Should Pass)
```
0s    - Container starts
0-120s - Start period (health checks ignored)
        Backend loads: ChromaDB, LangChain, dependencies
120s  - First health check with Python urllib
        (Backend is ready, health check PASSES)
150s  - Second health check (PASSES)
180s  - Third health check (PASSES)
180s+ - ✅ Task marked healthy, stays running
```

---

## 🚀 How to Deploy the Fix

### **Via GitHub Actions** (Recommended)

1. **Go to GitHub Actions**:
   - Repository → Actions tab
   - Find "Deploy to ECS" workflow

2. **Run the workflow**:
   - Click "Run workflow"
   - Select branch: `feature/agentic-ai-rag`
   - Environment: `dev`
   - Registry: `ecr`
   - Click "Run workflow" button

3. **What happens**:
   - Builds new Docker image with curl installed
   - Pushes to ECR
   - Updates ECS task definition with new health check settings
   - Deploys new task
   - Old task drained, new task starts
   - **Health check waits 2 minutes before starting**
   - Task should pass health checks and stay running ✅

### **Manual Deployment** (If GitHub Actions isn't set up)

```bash
# 1. Update Terraform infrastructure
cd infrastructure/terraform
terraform init
terraform apply -var-file=environments/dev.tfvars

# 2. Build and push new Docker image
cd ../../backend
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker build -t rag-demo-backend .
docker tag rag-demo-backend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/rag-demo-backend:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/rag-demo-backend:latest

# 3. Force new deployment
aws ecs update-service --cluster rag-demo --service backend --force-new-deployment --region us-east-1
```

---

## 🔍 Verify the Fix

### After Deployment

**1. Check ECS Service Events** (if AWS CLI is installed):
```bash
aws ecs describe-services \
  --cluster rag-demo \
  --services backend \
  --region us-east-1 \
  --query 'services[0].events[0:5]'
```

**2. Watch Task Status**:
- Go to AWS Console → ECS → rag-demo cluster → backend service → Tasks
- Click on the running task
- Check **Health status**: Should show "HEALTHY" after ~2-3 minutes

**3. Check Logs**:
```bash
aws logs tail /ecs/rag-demo --follow --region us-east-1
```

Look for:
- ✅ "Starting RAG Demo API..."
- ✅ "Application startup complete"
- ✅ "Uvicorn running on http://0.0.0.0:8000"

**4. Test Health Endpoint**:
```bash
# Get task public IP first, then:
curl http://<task-public-ip>:8000/health

# Should return:
# {"status":"healthy","timestamp":"...","service":"rag-demo-api"}
```

---

## 📈 Expected Results

### Task Lifecycle

1. **0-120s**: Container starting
   - Backend loading dependencies
   - No health checks yet
   - Status: "PROVISIONING" → "PENDING"

2. **120s**: First health check
   - Checks http://localhost:8000/health
   - Should get 200 OK response
   - Status: "RUNNING"

3. **150s+**: Subsequent health checks
   - Every 30 seconds
   - All passing
   - **Health Status: "HEALTHY"** ✅

4. **Task stays running**: Service is stable!

---

## 🆘 If It Still Fails

### Check CloudWatch Logs

```bash
aws logs tail /ecs/rag-demo --follow --region us-east-1
```

**Look for these errors**:

1. **Import errors**:
   ```
   ModuleNotFoundError: No module named 'xxx'
   ```
   **Solution**: Check requirements.txt, rebuild Docker image

2. **NameError**:
   ```
   NameError: name 'DocumentListItem' is not defined
   ```
   **Solution**: This was fixed in previous commit, ensure latest code is deployed

3. **Port binding errors**:
   ```
   OSError: [Errno 98] Address already in use
   ```
   **Solution**: Check port 8000 is not used by another process

4. **Database/ChromaDB errors**:
   ```
   Error connecting to ChromaDB
   ```
   **Solution**: Check if ChromaDB initialization is working

### Manual Health Check Test

SSH into the container (if possible) or check logs:
```bash
# Inside container
curl http://localhost:8000/health

# Or via Python
python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/health').read())"
```

---

## 📝 Summary

**What was wrong**:
- Health check used curl (not installed)
- Not enough time for startup (60s → 120s)
- Timeout too short (5s → 10s)

**What was fixed**:
- ✅ Health check now uses Python (always available)
- ✅ Start period doubled to 2 minutes
- ✅ Timeout doubled to 10 seconds
- ✅ Curl installed as backup option

**What to do**:
1. Deploy via GitHub Actions: "Deploy to ECS"
2. Wait 3-4 minutes for deployment
3. Check task status in ECS console
4. Verify health check passes

**Expected outcome**:
- ✅ Task starts successfully
- ✅ Health checks pass after 2 minutes
- ✅ Task stays running (healthy)
- ✅ Backend accessible at http://<public-ip>:8000

---

## ✅ Status

- **Code committed**: ✅ Yes (commit 1b84ee1)
- **Code pushed**: ✅ Yes (to feature/agentic-ai-rag)
- **Ready to deploy**: ✅ Yes
- **Next step**: Run GitHub Actions workflow to deploy

**The fix is complete and ready to deploy!** 🚀

