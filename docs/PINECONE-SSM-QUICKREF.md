# Pinecone SSM - Quick Commands

## 🚀 Setup (5 Steps)

### 1. Deploy Terraform
```powershell
cd infrastructure/terraform
terraform apply
```

### 2. Update SSM with Your API Key
```powershell
aws ssm put-parameter `
  --name "/rag-demo/pinecone/api-key" `
  --value "pcsk_YOUR_REAL_PINECONE_API_KEY" `
  --type "SecureString" `
  --overwrite `
  --region us-east-1
```

### 3. Enable Pinecone (Optional)
```powershell
# Edit terraform.tfvars
use_pinecone = true
pinecone_index = "rag-demo"

# Redeploy
terraform apply
```

### 4. Deploy Application
```powershell
# Via GitHub Actions or manual deployment
```

### 5. Verify
```powershell
aws ssm get-parameter --name "/rag-demo/pinecone/api-key" --with-decryption --region us-east-1
```

---

## 📝 Common Commands

### Get API Key from SSM
```powershell
aws ssm get-parameter `
  --name "/rag-demo/pinecone/api-key" `
  --with-decryption `
  --region us-east-1 `
  --query 'Parameter.Value' `
  --output text
```

### Update API Key
```powershell
aws ssm put-parameter `
  --name "/rag-demo/pinecone/api-key" `
  --value "NEW_KEY" `
  --type "SecureString" `
  --overwrite `
  --region us-east-1
```

### List All Pinecone Parameters
```powershell
aws ssm get-parameters-by-path `
  --path "/rag-demo/pinecone" `
  --with-decryption `
  --region us-east-1
```

### Check Lambda Configuration
```powershell
aws lambda get-function-configuration `
  --function-name rag-demo-embedder `
  --region us-east-1 `
  --query 'Environment.Variables'
```

---

## 🔐 SSM Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `/rag-demo/pinecone/api-key` | SecureString | `REPLACE_WITH_REAL_PINECONE_KEY` | API key (encrypted) |
| `/rag-demo/pinecone/index-name` | String | `rag-demo` | Index name |
| `/rag-demo/pinecone/environment` | String | `us-east-1` | Region |

---

## 📊 Environment Variables

Lambda & ECS receive:
```bash
PINECONE_API_KEY_PARAM=/rag-demo/pinecone/api-key
PINECONE_INDEX=rag-demo
USE_PINECONE=true
```

Code fetches actual key from SSM at runtime.

---

## ✅ Security

✅ API key encrypted in AWS SSM (KMS)
✅ Never in Git, never in Terraform
✅ IAM-controlled access
✅ CloudTrail audit logs
✅ Same pattern as Azure OpenAI keys

---

## 📚 Full Documentation

See: `docs/PINECONE-SSM-SETUP.md`

