# GitHub Actions - Which Workflow Deploys to ECS?

## Answer: `.github/workflows/deploy-ecs.yml`

This workflow **automatically** builds and deploys the backend to ECS when you push code.

---

## Automatic Trigger

### When It Runs:
```yaml
on:
  push:
    branches: [main]
    paths:
      - 'backend/**'
```

**Triggers when:**
- ✅ You push to `main` branch
- ✅ AND changes are in `backend/**` directory

**Does NOT trigger when:**
- ❌ You push to other branches
- ❌ You only change `electron-ui/`, `docs/`, etc.

---

## Manual Trigger

You can also trigger it manually via GitHub UI:

```yaml
  workflow_dispatch:
    inputs:
      environment: dev/staging/prod
      registry: ecr/jfrog
```

**How to trigger manually:**
1. Go to GitHub: https://github.com/your-repo/actions
2. Click "Deploy to ECS" workflow
3. Click "Run workflow"
4. Select environment and registry
5. Click "Run workflow" button

---

## What It Does (Step-by-Step)

### 1. **Checkout Code**
```yaml
- name: Checkout code
  uses: actions/checkout@v4
```

### 2. **Configure AWS Credentials**
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1
```

### 3. **Login to ECR (Amazon Container Registry)**
```yaml
- name: Login to Amazon ECR
  uses: aws-actions/amazon-ecr-login@v2
```

### 4. **Build Docker Image**
```yaml
- name: Build, tag, and push image
  run: |
    cd backend
    docker build -t $REGISTRY_URL:$IMAGE_TAG .
    docker push $REGISTRY_URL:$IMAGE_TAG
    docker tag $REGISTRY_URL:$IMAGE_TAG $REGISTRY_URL:latest
    docker push $REGISTRY_URL:latest
```

**This step:**
- Builds Docker image from `backend/Dockerfile`
- **Installs all requirements from `requirements.txt`** (including langsmith!)
- Tags with commit SHA and `latest`
- Pushes to ECR

### 5. **Update ECS Task Definition**
```yaml
- name: Download task definition
  run: |
    aws ecs describe-task-definition \
      --task-definition rag-demo-backend \
      --query taskDefinition > task-definition.json

- name: Update task definition with new image
  uses: aws-actions/amazon-ecs-render-task-definition@v1
  with:
    task-definition: task-definition.json
    container-name: backend
    image: ${{ steps.build-image.outputs.image }}
```

### 6. **Deploy to ECS**
```yaml
- name: Deploy to ECS
  uses: aws-actions/amazon-ecs-deploy-task-definition@v1
  with:
    task-definition: ${{ steps.task-def.outputs.task-definition }}
    service: backend
    cluster: rag-demo
    wait-for-service-stability: true
```

**This step:**
- Registers new task definition
- Updates ECS service
- Performs rolling deployment
- Waits for service to stabilize
- Old tasks are replaced with new ones

---

## To Deploy Your LangSmith Fix

### Option 1: Automatic (Recommended)

```bash
# Make sure you're on main branch or merge to main
git checkout main
git merge feature/agentic-ai-rag-fix

# Push to trigger deployment
git push origin main

# GitHub Actions will automatically:
# 1. Detect changes in backend/
# 2. Run deploy-ecs.yml workflow
# 3. Build new Docker image with langsmith
# 4. Deploy to ECS
```

**Watch the deployment:**
- GitHub: https://github.com/your-repo/actions
- Look for "Deploy to ECS" workflow run

### Option 2: Manual Trigger

1. Go to: https://github.com/your-repo/actions
2. Click "Deploy to ECS"
3. Click "Run workflow"
4. Select:
   - Branch: `main`
   - Environment: `dev`
   - Registry: `ecr`
5. Click "Run workflow"

---

## Verification After Deployment

### 1. Check GitHub Actions Log
```
✅ Build, tag, and push image
✅ Deploy to ECS
✅ Deployment Complete
```

### 2. Check ECS Service
```bash
aws ecs describe-services \
  --cluster rag-demo \
  --services backend \
  --query "services[0].deployments"
```

**Should show:**
- `desiredCount: 1`
- `runningCount: 1`
- `status: PRIMARY`

### 3. Check Backend Logs
```bash
aws logs tail /ecs/rag-demo --follow
```

**Look for:**
```
✅ LangSmith available - OpenAI calls will be traced
✅ Wrapped OpenAI client with LangSmith tracing for Primary (us-east)
```

**NOT:**
```
⚠️ LangSmith not installed - tracing disabled
```

### 4. Test the Endpoint
```bash
curl http://54.89.155.20:8000/health
# Should return: {"status": "healthy"}
```

---

## Other Related Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `deploy-ecs.yml` | Push to `main` with `backend/**` changes | Deploy backend to ECS |
| `deploy-lambda.yml` | Push to `main` with `lambda/**` changes | Deploy Lambda functions |
| `backend-ci.yml` | Push to any branch with `backend/**` | Run tests/linting |
| `infrastructure.yml` | Manual or push with `infrastructure/**` | Update Terraform |

---

## Timeline

Once you push to `main`:

| Time | Event |
|------|-------|
| 0s | GitHub detects push to `main` with `backend/` changes |
| 5s | Workflow starts, checks out code |
| 10s | Configures AWS credentials, logs into ECR |
| 2-5min | Builds Docker image (installs all dependencies including langsmith) |
| 30s | Pushes image to ECR |
| 1min | Updates ECS task definition |
| 2-3min | ECS performs rolling deployment (drains old tasks, starts new ones) |
| **~10min total** | ✅ Deployment complete with LangSmith enabled! |

---

## Quick Answer

**To deploy your LangSmith fix to ECS:**

```bash
git push origin main
```

That's it! The `.github/workflows/deploy-ecs.yml` workflow will automatically:
1. Build a new Docker image with langsmith installed
2. Deploy it to ECS
3. Replace the old containers with new ones

Within ~10 minutes, you'll see "✅ LangSmith available" in the logs instead of the warning!

