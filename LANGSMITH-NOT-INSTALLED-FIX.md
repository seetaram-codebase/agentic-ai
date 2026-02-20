# Fix: LangSmith Not Installed Warning

## The Warning You're Seeing

```
app.azure_openai - WARNING - ⚠️ LangSmith not installed - tracing disabled
```

## Cause

The `langsmith` package is **not installed** in your current runtime environment, even though it's in `requirements.txt`.

## Solutions (Pick Based on Your Environment)

### Solution 1: Running Backend Locally

If you're running the backend locally with `uvicorn`:

```bash
cd backend

# Install langsmith
pip install langsmith==0.1.77

# Or reinstall all requirements
pip install -r requirements.txt

# Restart the server
uvicorn app.main:app --reload
```

**Verify:**
```bash
pip show langsmith
# Should show: Version: 0.1.77
```

---

### Solution 2: Running in Docker Locally

If you're running via Docker:

```bash
cd backend

# Rebuild the Docker image
docker build -t rag-backend .

# Run the container
docker run -p 8000:8000 \
  -e LANGCHAIN_TRACING_V2=true \
  -e LANGCHAIN_API_KEY=your_key_here \
  -e LANGCHAIN_PROJECT=rag-demo \
  rag-backend
```

---

### Solution 3: Running in AWS ECS (Production)

The ECS container needs to be rebuilt and redeployed:

#### Option A: Trigger GitHub Actions (Recommended)
```bash
# Commit any pending changes
git add .
git commit -m "chore: ensure langsmith is installed"
git push origin main

# GitHub Actions will automatically:
# 1. Build new Docker image with all requirements
# 2. Push to ECR
# 3. Update ECS task definition
# 4. ECS will deploy new version
```

#### Option B: Manual Docker Build & Push to ECR
```bash
cd backend

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build image
docker build -t rag-demo-backend .

# Tag for ECR
docker tag rag-demo-backend:latest YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/rag-demo-backend:latest

# Push to ECR
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/rag-demo-backend:latest

# Update ECS service (force new deployment)
aws ecs update-service \
  --cluster rag-demo \
  --service backend \
  --force-new-deployment \
  --region us-east-1
```

---

## Verification

After fixing, restart the backend and check the logs:

### Local/Docker:
```bash
# You should see this in the startup logs:
✅ LangSmith available - OpenAI calls will be traced
✅ Wrapped OpenAI client with LangSmith tracing for Primary (us-east)
```

**NOT this:**
```bash
⚠️ LangSmith not installed - tracing disabled
```

### ECS:
```bash
# Check ECS logs
aws logs tail /ecs/rag-demo --follow

# Look for:
✅ LangSmith available - OpenAI calls will be traced
```

---

## Quick Test

Once deployed, make a query and check LangSmith:

```bash
# Make a query
curl -X POST http://54.89.155.20:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "test", "n_results": 1}'

# Check LangSmith dashboard
# https://smith.langchain.com/
# Project: rag-demo
# Should see a new trace!
```

---

## Why This Happened

1. The `langsmith` package **is** in `requirements.txt`
2. But the **running container/environment** was built **before** langsmith was added
3. Or you're running locally without installing dependencies

## The Fix in Summary

| Environment | Fix |
|-------------|-----|
| **Local (pip)** | `pip install langsmith==0.1.77` |
| **Local (Docker)** | `docker build -t rag-backend .` |
| **ECS (Production)** | `git push origin main` (triggers CI/CD) |

---

## Next Steps

1. Apply the fix for your environment (see above)
2. Restart the backend
3. Check logs for "✅ LangSmith available"
4. Make a test query
5. Verify traces in LangSmith dashboard

Once you see "✅ LangSmith available" instead of "⚠️ LangSmith not installed", tracing will work!

