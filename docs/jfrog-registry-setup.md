# JFrog Artifactory Docker Registry Setup

## ⚠️ JFrog Requires Corporate Email

JFrog Cloud free trial requires a corporate/work email (not Gmail, Yahoo, etc.)

### Options:

**Option A: Use your work email** (if you have one)

**Option B: Use GitHub Container Registry (GHCR) instead** ⭐ Recommended
- Free with GitHub account
- No corporate email needed
- Works with GitHub Actions

**Option C: Use AWS ECR** (already configured)
- Set `use_jfrog = false` in Terraform
- Works out of the box

**Option D: Self-host JFrog locally** (Docker)
- No email verification needed
- Free Artifactory OSS

---

## Recommended: Use GitHub Container Registry (GHCR)

Since JFrog requires corporate email, **use GHCR instead** - it's free and easy!

### Quick Setup for GHCR:

```powershell
# Login to GHCR
echo $env:GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# Or use GitHub CLI
gh auth token | docker login ghcr.io -u $(gh api user -q .login) --password-stdin
```

### Update deploy-ecs.yml for GHCR:
```yaml
# Login to GHCR instead of JFrog
- name: Login to GitHub Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

I can update your project to use GHCR if you want!

---

## Option 1: JFrog Cloud (Requires Corporate Email)

### Step 1: Sign Up for Free Trial
1. Go to: https://jfrog.com/start-free/
2. Select **JFrog Cloud** (hosted)
3. Create account with your email
4. Choose a server name (e.g., `your-org.jfrog.io`)

### Step 2: Create Docker Repository
1. Login to your JFrog Platform
2. Go to **Administration** → **Repositories** → **Repositories**
3. Click **+ Add Repository** → **Local Repository**
4. Select **Docker** as package type
5. Name it: `docker-local`
6. Click **Create Local Repository**

### Step 3: Get Access Token
1. Go to **User Menu** (top right) → **Edit Profile**
2. Click **Generate Identity Token**
3. Copy the token (this is your `JFROG_PASSWORD`)

### Step 4: Configure in Your Project

```powershell
# Add GitHub Secrets
gh secret set JFROG_REGISTRY_URL --body "your-org.jfrog.io"
gh secret set JFROG_USERNAME --body "your-email@example.com"
gh secret set JFROG_PASSWORD --body "your-identity-token"
gh secret set JFROG_REPOSITORY --body "docker-local"
```

### Step 5: Update Terraform
```hcl
# environments/dev.tfvars
use_jfrog          = true
jfrog_registry_url = "your-org.jfrog.io"
jfrog_repository   = "docker-local"
```

### Step 6: Store JFrog Credentials in AWS Secrets Manager
```powershell
aws secretsmanager put-secret-value `
  --secret-id rag-demo/jfrog-credentials `
  --secret-string '{"username":"your-email@example.com","password":"your-identity-token"}'
```

---

## Option 2: Self-Hosted JFrog (Docker)

### Run JFrog Artifactory Locally
```powershell
# Create data directory
mkdir C:\jfrog\artifactory

# Run JFrog Artifactory OSS (free)
docker run -d --name artifactory `
  -p 8081:8081 -p 8082:8082 `
  -v C:\jfrog\artifactory:/var/opt/jfrog/artifactory `
  releases-docker.jfrog.io/jfrog/artifactory-oss:latest
```

### Access
- URL: http://localhost:8081
- Default login: `admin` / `password`

---

## Quick Setup Script

Run this after creating JFrog account:

```powershell
# Set your JFrog details
$JFROG_URL = "your-org.jfrog.io"
$JFROG_USER = "your-email@example.com"
$JFROG_TOKEN = "your-identity-token"

# Test Docker login
docker login $JFROG_URL -u $JFROG_USER -p $JFROG_TOKEN

# Add GitHub Secrets
gh secret set JFROG_REGISTRY_URL --body $JFROG_URL
gh secret set JFROG_USERNAME --body $JFROG_USER
gh secret set JFROG_PASSWORD --body $JFROG_TOKEN
gh secret set JFROG_REPOSITORY --body "docker-local"

# Update AWS Secrets Manager (after terraform apply)
$secretJson = @{username=$JFROG_USER; password=$JFROG_TOKEN} | ConvertTo-Json -Compress
aws secretsmanager put-secret-value --secret-id rag-demo/jfrog-credentials --secret-string $secretJson

Write-Host "✅ JFrog configured!"
```

---

## Verify Setup

### Test Docker Login
```powershell
docker login your-org.jfrog.io
```

### Push Test Image
```powershell
docker pull hello-world
docker tag hello-world your-org.jfrog.io/docker-local/hello-world:test
docker push your-org.jfrog.io/docker-local/hello-world:test
```

---

## JFrog Free Tier Limits

| Feature | Free Cloud | Self-Hosted OSS |
|---------|------------|-----------------|
| Storage | 2 GB | Unlimited |
| Transfer | 10 GB/month | Unlimited |
| Users | 5 | Unlimited |
| Repos | Unlimited | Unlimited |
| Price | **FREE** | **FREE** |

---

## JFrog Pricing (If You Exceed Free Tier)

### Cloud Plans

| Plan | Storage | Transfer | Price |
|------|---------|----------|-------|
| **Free** | 2 GB | 10 GB/mo | **$0** |
| **Pro Team** | 25 GB | 250 GB/mo | **$150/mo** |
| **Enterprise** | Custom | Custom | Contact Sales |

### Self-Hosted (Your Own Server)

| Option | Cost |
|--------|------|
| **Artifactory OSS** | **FREE** (open source) |
| **Pro** | ~$3,000/year |
| **Enterprise** | ~$10,000+/year |

---

## Cost for Your Demo

### Using JFrog Cloud Free Tier

| Resource | Your Usage | Limit | Cost |
|----------|------------|-------|------|
| Storage | ~200 MB (Docker images) | 2 GB | **$0** |
| Transfer | ~500 MB | 10 GB/mo | **$0** |
| **Total** | | | **$0** |

### Using Self-Hosted on AWS EC2 (Optional)

| Resource | Size | Cost/Month |
|----------|------|------------|
| EC2 (t3.small) | 2 vCPU, 2GB | ~$15 |
| EBS Storage | 20 GB | ~$2 |
| **Total** | | **~$17/mo** |

---

## Recommendation for Your Demo

> **Use JFrog Cloud Free Tier** - It's completely FREE and sufficient for your demo!
>
> - ✅ 2 GB storage (your images ~200 MB)
> - ✅ 10 GB transfer (plenty for demo)
> - ✅ No infrastructure to manage
> - ✅ 5 users included

### When to Consider Paid Plans

| Scenario | Recommendation |
|----------|---------------|
| Demo (4 days) | **Free tier** |
| Small team (<5) | **Free tier** |
| Production (small) | **Pro Team $150/mo** |
| Enterprise | Self-hosted or Enterprise plan |

---

## Summary

1. **Create account**: https://jfrog.com/start-free/
2. **Create repo**: `docker-local` (Docker type)
3. **Get token**: User Profile → Generate Identity Token
4. **Configure**: Set GitHub secrets + AWS Secrets Manager
5. **Deploy**: `terraform apply` with `use_jfrog = true`
