# Project Organization & GitHub Actions Plan

## 🎯 Overview

Organize the RAG demo into multiple repositories for better separation of concerns, independent deployments, and team collaboration.

---

## 📁 Repository Structure

### Option 1: Monorepo (Recommended for Demo)
```
rag-demo/
├── .github/
│   └── workflows/
│       ├── backend-ci.yml
│       ├── frontend-ci.yml
│       ├── deploy-ecs.yml
│       └── deploy-electron.yml
├── backend/
├── electron-ui/
├── infrastructure/
│   ├── terraform/
│   └── cloudformation/
├── docs/
└── scripts/
```

**Pros:** Simple, single repo, easy to manage for demo
**Cons:** All code in one place, harder to scale teams

---

### Option 2: Multi-Repo (Recommended for Production)

```
Organization: your-org/

├── rag-demo-backend          # FastAPI backend
├── rag-demo-frontend         # Electron UI
├── rag-demo-infrastructure   # Terraform/CloudFormation
├── rag-demo-docs             # Documentation
└── rag-demo-shared           # Shared libraries/configs
```

---

## 🏗️ Recommended: Hybrid Approach (3 Repos)

### Repo 1: `rag-demo-backend`
**Purpose:** Backend API, Lambda functions, core RAG logic

```
rag-demo-backend/
├── .github/
│   └── workflows/
│       ├── ci.yml              # Lint, test, build
│       ├── deploy-ecs.yml      # Deploy to ECS
│       └── deploy-lambda.yml   # Deploy Lambda functions
├── app/
│   ├── main.py
│   ├── azure_openai.py
│   ├── vector_store.py
│   ├── rag_engine.py
│   └── dynamodb_config.py
├── lambda/
│   └── document_processor/
│       └── handler.py
├── tests/
│   ├── test_api.py
│   ├── test_rag.py
│   └── test_azure.py
├── Dockerfile
├── requirements.txt
├── pyproject.toml
└── README.md
```

### Repo 2: `rag-demo-frontend`
**Purpose:** Electron desktop application

```
rag-demo-frontend/
├── .github/
│   └── workflows/
│       ├── ci.yml              # Lint, test, build
│       ├── build-electron.yml  # Build for Win/Mac/Linux
│       └── release.yml         # Create GitHub releases
├── src/
│   ├── main.tsx
│   ├── App.tsx
│   ├── api/
│   │   └── client.ts
│   └── components/
├── main.js
├── preload.js
├── package.json
├── tsconfig.json
└── README.md
```

### Repo 3: `rag-demo-infrastructure`
**Purpose:** AWS/Azure infrastructure as code

```
rag-demo-infrastructure/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml
│       ├── terraform-apply.yml
│       └── destroy.yml
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── modules/
│   │   ├── ecs/
│   │   ├── dynamodb/
│   │   ├── s3/
│   │   ├── sqs/
│   │   └── lambda/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── cloudformation/
│   └── rag-stack.yaml
└── README.md
```

---

## 🔄 GitHub Actions Workflows

### Backend CI/CD (`rag-demo-backend`)

#### `.github/workflows/ci.yml`
```yaml
name: Backend CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install ruff
      - run: ruff check .

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      - run: pip install pytest pytest-asyncio
      - run: pytest tests/ -v

  build:
    runs-on: ubuntu-latest
    needs: [lint, test]
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: docker build -t rag-demo-backend .
      - name: Save image
        run: docker save rag-demo-backend > backend.tar
      - uses: actions/upload-artifact@v4
        with:
          name: docker-image
          path: backend.tar
```

#### `.github/workflows/deploy-ecs.yml`
```yaml
name: Deploy to ECS

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: rag-demo-backend
  ECS_CLUSTER: rag-demo
  ECS_SERVICE: backend

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster $ECS_CLUSTER \
            --service $ECS_SERVICE \
            --force-new-deployment
```

### Frontend CI/CD (`rag-demo-frontend`)

#### `.github/workflows/ci.yml`
```yaml
name: Frontend CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm run lint

  build:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm run build
```

#### `.github/workflows/release.yml`
```yaml
name: Build & Release Electron

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build:
    strategy:
      matrix:
        os: [windows-latest, macos-latest, ubuntu-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm run build
      
      - name: Build Electron
        run: npm run pack
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: electron-${{ matrix.os }}
          path: dist-electron/

  release:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            electron-windows-latest/*
            electron-macos-latest/*
            electron-ubuntu-latest/*
```

### Infrastructure CI/CD (`rag-demo-infrastructure`)

#### `.github/workflows/terraform-plan.yml`
```yaml
name: Terraform Plan

on:
  pull_request:
    branches: [main]

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init
        working-directory: terraform/environments/dev

      - name: Terraform Plan
        run: terraform plan -no-color
        working-directory: terraform/environments/dev

      - name: Comment on PR
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '✅ Terraform plan completed successfully!'
            })
```

---

## 🔐 GitHub Secrets Required

### Backend Repo
| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `AZURE_OPENAI_KEY_1` | Azure OpenAI primary key |
| `AZURE_OPENAI_KEY_2` | Azure OpenAI failover key |

### Frontend Repo
| Secret | Description |
|--------|-------------|
| `GITHUB_TOKEN` | Auto-provided for releases |

### Infrastructure Repo
| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `TF_STATE_BUCKET` | S3 bucket for Terraform state |

---

## 📋 Migration Steps

### Step 1: Create GitHub Repositories
```bash
# Create repos via GitHub CLI
gh repo create your-org/rag-demo-backend --private
gh repo create your-org/rag-demo-frontend --private
gh repo create your-org/rag-demo-infrastructure --private
```

### Step 2: Split Current Code
```bash
# Backend
mkdir ../rag-demo-backend
cp -r backend/* ../rag-demo-backend/
cp .gitignore ../rag-demo-backend/

# Frontend
mkdir ../rag-demo-frontend
cp -r electron-ui/* ../rag-demo-frontend/

# Infrastructure
mkdir ../rag-demo-infrastructure
cp -r aws/* ../rag-demo-infrastructure/terraform/
```

### Step 3: Initialize Git & Push
```bash
# Backend
cd ../rag-demo-backend
git init
git add .
git commit -m "Initial commit - Backend"
git remote add origin git@github.com:your-org/rag-demo-backend.git
git push -u origin main

# Repeat for frontend and infrastructure
```

### Step 4: Add GitHub Secrets
```bash
# Via GitHub CLI
gh secret set AWS_ACCESS_KEY_ID --repo your-org/rag-demo-backend
gh secret set AWS_SECRET_ACCESS_KEY --repo your-org/rag-demo-backend
```

### Step 5: Enable Branch Protection
- Require PR reviews
- Require CI to pass
- No direct pushes to main

---

## 🎯 Recommendation for Demo (4 Days)

Given your timeline, I recommend:

### Day 1-2: Keep as Monorepo
- Faster to set up
- Single CI/CD pipeline
- Easier to manage alone

### Day 3: Add GitHub Actions
- CI for testing
- Deploy to ECS on push

### Day 4: Demo Day
- Everything working
- Optional: Split to multi-repo after demo

---

## Quick Start: Monorepo with GitHub Actions

For your demo, I'll set up GitHub Actions in the current monorepo structure. This is the fastest path to CI/CD.

Would you like me to create the GitHub Actions workflow files now?
