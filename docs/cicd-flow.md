# CI/CD Flow: Code Commit → JFrog → ECS

## 🔄 Complete Pipeline Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Developer │────▶│   GitHub    │────▶│   JFrog     │────▶│   AWS ECS   │
│  git push   │     │   Actions   │     │ Artifactory │     │   Fargate   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                          │                    │                    │
                          │ 1. Build Docker    │                    │
                          │ 2. Push to JFrog   │                    │
                          │                    │ 3. Pull image      │
                          │ 4. Update ECS ─────┼────────────────────┘
                          │    task definition │
                          └────────────────────┘
```

## ✅ What Happens on Code Commit

1. **Developer pushes to `main` branch** (changes in `backend/`)
2. **GitHub Actions triggers `deploy-ecs.yml`**
3. **Workflow:**
   - Logs into JFrog Artifactory
   - Builds Docker image from `backend/Dockerfile`
   - Tags with commit SHA + `latest`
   - Pushes to JFrog (`your-org.jfrog.io/docker-local/rag-demo-backend:sha`)
   - Updates ECS task definition with new image
   - Deploys to ECS (rolling update)
4. **ECS pulls the new image from JFrog and runs it**

## 🔐 Required GitHub Secrets

| Secret | Example Value |
|--------|---------------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | `wJalr...` |
| `JFROG_REGISTRY_URL` | `your-org.jfrog.io` |
| `JFROG_USERNAME` | `deployer@company.com` |
| `JFROG_PASSWORD` | `AKCp8...` (API key) |
| `JFROG_REPOSITORY` | `docker-local` |

## 🔐 ECS Authentication to JFrog

ECS needs credentials to pull from JFrog. Two options:

### Option A: AWS Secrets Manager (Recommended)
Store JFrog credentials in Secrets Manager, ECS pulls them automatically.

### Option B: Task Definition with repositoryCredentials
The task definition references a Secrets Manager secret.
