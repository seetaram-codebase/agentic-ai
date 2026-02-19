# Pinecone SSM Setup Guide

## Overview

Pinecone API key is securely stored in AWS SSM Parameter Store, just like Azure OpenAI keys. This ensures the API key is never stored in code or Terraform files.

---

## 🔐 Security Architecture

```
Pinecone API Key Flow:
1. Store API key in AWS SSM Parameter Store (encrypted)
2. Terraform creates SSM parameter with placeholder
3. You update placeholder with real key via AWS CLI/Console
4. Lambda/ECS read key from SSM at runtime using IAM permissions
5. No API key ever touches Git or Terraform state
```

---

## 📋 Setup Steps

### Step 1: Create Pinecone Account & Index

```bash
# 1. Sign up at https://www.pinecone.io/
# 2. Create API key in Pinecone Console
# 3. Create index:
#    Name: rag-demo
#    Dimensions: 1536 (for text-embedding-3-small)
#    Metric: cosine
#    Region: us-east-1 (AWS)
```

### Step 2: Deploy Terraform Infrastructure

```powershell
cd infrastructure/terraform

# Optional: Enable Pinecone in terraform.tfvars
# use_pinecone = true
# pinecone_index = "rag-demo"

# Deploy
terraform init
terraform plan
terraform apply
```

This creates the SSM parameter: `/rag-demo/pinecone/api-key` with placeholder value.

### Step 3: Update SSM Parameter with Real API Key

**Option A: AWS CLI (Recommended)**

```powershell
aws ssm put-parameter `
  --name "/rag-demo/pinecone/api-key" `
  --value "pcsk_xxxxx_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" `
  --type "SecureString" `
  --overwrite `
  --region us-east-1
```

**Option B: AWS Console**

```
1. Go to AWS Console → Systems Manager → Parameter Store
2. Find parameter: /rag-demo/pinecone/api-key
3. Click "Edit"
4. Update value with your real Pinecone API key
5. Save
```

### Step 4: Verify IAM Permissions

The Lambda and ECS IAM roles already have SSM permissions (from `iam.tf`):

```hcl
{
  "Effect": "Allow",
  "Action": [
    "ssm:GetParameter",
    "ssm:GetParameters"
  ],
  "Resource": "arn:aws:ssm:*:*:parameter/rag-demo/*"
}
```

### Step 5: Verify Configuration

```powershell
# Check SSM parameter exists
aws ssm get-parameter `
  --name "/rag-demo/pinecone/api-key" `
  --with-decryption `
  --region us-east-1

# Check Lambda environment variables
aws lambda get-function-configuration `
  --function-name rag-demo-embedder `
  --region us-east-1 `
  --query 'Environment.Variables'

# Should show:
# {
#   "PINECONE_API_KEY_PARAM": "/rag-demo/pinecone/api-key",
#   "PINECONE_INDEX": "rag-demo",
#   "USE_PINECONE": "true"
# }
```

---

## 📊 SSM Parameters Created

Terraform creates these parameters in AWS SSM:

| Parameter | Type | Default Value | Description |
|-----------|------|---------------|-------------|
| `/rag-demo/pinecone/api-key` | SecureString | `REPLACE_WITH_REAL_PINECONE_KEY` | Pinecone API key (encrypted) |
| `/rag-demo/pinecone/index-name` | String | `rag-demo` | Pinecone index name |
| `/rag-demo/pinecone/environment` | String | `us-east-1` | Pinecone region |

**⚠️ Important:** After `terraform apply`, update the `api-key` parameter with your real Pinecone API key!

---

## 🔧 Environment Variables

### Lambda Embedder
```bash
PINECONE_API_KEY_PARAM=/rag-demo/pinecone/api-key  # SSM parameter name
PINECONE_INDEX=rag-demo
USE_PINECONE=true
```

### ECS Backend
```bash
PINECONE_API_KEY_PARAM=/rag-demo/pinecone/api-key  # SSM parameter name
PINECONE_INDEX=rag-demo
USE_PINECONE=true
```

**How it works:**
- Instead of storing the API key directly, we store the SSM parameter name
- Code reads the parameter name and fetches the actual key from SSM at runtime
- This is the same pattern used for Azure OpenAI keys

---

## 💻 Code Implementation

### Lambda Handler (embedder/handler.py)

```python
import boto3

ssm = boto3.client('ssm')

def get_pinecone_api_key():
    """Get Pinecone API key from SSM Parameter Store"""
    param_name = os.environ.get('PINECONE_API_KEY_PARAM')
    if not param_name:
        return None
    
    try:
        response = ssm.get_parameter(Name=param_name, WithDecryption=True)
        return response['Parameter']['Value']
    except Exception as e:
        logger.error(f"Failed to get Pinecone API key from SSM: {e}")
        return None

# Usage
api_key = get_pinecone_api_key()
pc = Pinecone(api_key=api_key)
```

### Backend (backend/app/vector_store.py)

```python
import boto3

_ssm_client = boto3.client('ssm')

def get_pinecone_api_key_from_ssm():
    """Get Pinecone API key from SSM Parameter Store"""
    param_name = os.getenv("PINECONE_API_KEY_PARAM")
    
    if not param_name:
        # Fallback to direct env var (for local development)
        return os.getenv("PINECONE_API_KEY")
    
    try:
        response = _ssm_client.get_parameter(Name=param_name, WithDecryption=True)
        return response['Parameter']['Value']
    except Exception as e:
        logger.error(f"Failed to get Pinecone API key from SSM: {e}")
        return None

# Usage
api_key = get_pinecone_api_key_from_ssm()
```

---

## 🧪 Testing

### Test SSM Parameter

```powershell
# Get parameter value
aws ssm get-parameter `
  --name "/rag-demo/pinecone/api-key" `
  --with-decryption `
  --region us-east-1 `
  --query 'Parameter.Value' `
  --output text
```

### Test from Lambda (Local)

```python
import boto3

ssm = boto3.client('ssm', region_name='us-east-1')
response = ssm.get_parameter(
    Name='/rag-demo/pinecone/api-key',
    WithDecryption=True
)
print(f"API Key: {response['Parameter']['Value'][:10]}...")
```

### Test Pinecone Connection

```python
from pinecone import Pinecone
import boto3

# Get key from SSM
ssm = boto3.client('ssm', region_name='us-east-1')
response = ssm.get_parameter(
    Name='/rag-demo/pinecone/api-key',
    WithDecryption=True
)
api_key = response['Parameter']['Value']

# Connect to Pinecone
pc = Pinecone(api_key=api_key)
index = pc.Index("rag-demo")
stats = index.describe_index_stats()
print(f"✅ Connected! Vectors: {stats['total_vector_count']}")
```

---

## 🔄 Update API Key

If you need to rotate or update your Pinecone API key:

```powershell
# Update SSM parameter
aws ssm put-parameter `
  --name "/rag-demo/pinecone/api-key" `
  --value "NEW_API_KEY_HERE" `
  --type "SecureString" `
  --overwrite `
  --region us-east-1

# Restart Lambda (Lambda will get new key on next invocation)
# No restart needed - functions will pick up new key automatically

# Restart ECS service (to pick up new key)
aws ecs update-service `
  --cluster rag-demo `
  --service rag-demo-backend `
  --force-new-deployment `
  --region us-east-1
```

---

## 🌍 Local Development

For local development (without AWS credentials), you can use direct environment variable:

```bash
# .env file (for local development only)
PINECONE_API_KEY=pcsk_xxxxx...
PINECONE_INDEX=rag-demo
USE_PINECONE=true

# The code will fallback to PINECONE_API_KEY if PINECONE_API_KEY_PARAM is not set
```

---

## ✅ Comparison: Old vs New Approach

### ❌ Old Approach (Direct Environment Variable)
```hcl
# Bad: API key in Terraform variable
variable "pinecone_api_key" {
  type      = string
  sensitive = true
}

# Bad: API key in terraform.tfvars (risk of Git commit)
pinecone_api_key = "pcsk_xxxxx..."

# Bad: API key in Terraform state file
```

### ✅ New Approach (SSM Parameter Store)
```hcl
# Good: Only SSM parameter name in Terraform
environment {
  variables = {
    PINECONE_API_KEY_PARAM = aws_ssm_parameter.pinecone_api_key.name
  }
}

# Good: API key stored encrypted in AWS SSM
# Good: API key never in Git, never in Terraform state
# Good: Same pattern as Azure OpenAI keys
```

---

## 📚 Benefits

✅ **Security:** API key encrypted at rest in AWS SSM
✅ **No Git Risk:** API key never in code or Terraform files
✅ **IAM Controlled:** Access controlled via IAM policies
✅ **Audit Trail:** SSM tracks who accessed the parameter
✅ **Easy Rotation:** Update SSM parameter without code changes
✅ **Consistent:** Same pattern as Azure OpenAI keys
✅ **Best Practice:** Follows AWS security recommendations

---

## 🆘 Troubleshooting

### Issue: "Failed to get Pinecone API key from SSM"

**Solution:**
```powershell
# Check parameter exists
aws ssm get-parameter --name "/rag-demo/pinecone/api-key" --region us-east-1

# Check IAM permissions
aws iam get-role-policy --role-name rag-demo-lambda-role --policy-name lambda-policy

# Update parameter
aws ssm put-parameter --name "/rag-demo/pinecone/api-key" --value "YOUR_KEY" --type "SecureString" --overwrite --region us-east-1
```

### Issue: "Access Denied" when reading SSM parameter

**Solution:** Verify IAM role has SSM permissions:
```json
{
  "Effect": "Allow",
  "Action": [
    "ssm:GetParameter",
    "ssm:GetParameters"
  ],
  "Resource": "arn:aws:ssm:us-east-1:*:parameter/rag-demo/*"
}
```

### Issue: Parameter not found

**Solution:**
```powershell
# Recreate parameter
terraform apply

# Or create manually
aws ssm put-parameter `
  --name "/rag-demo/pinecone/api-key" `
  --value "YOUR_KEY" `
  --type "SecureString" `
  --region us-east-1
```

---

## 📝 Checklist

- [ ] Create Pinecone account
- [ ] Get Pinecone API key
- [ ] Create Pinecone index (rag-demo, 1536 dims, cosine)
- [ ] Run `terraform apply` (creates SSM parameter placeholder)
- [ ] Update SSM parameter with real API key via AWS CLI
- [ ] Verify SSM parameter is set correctly
- [ ] Enable Pinecone: `use_pinecone = true` in terraform.tfvars
- [ ] Redeploy infrastructure: `terraform apply`
- [ ] Deploy Lambda functions (GitHub Actions or manual)
- [ ] Deploy ECS backend (GitHub Actions or manual)
- [ ] Test document upload and verify vectors in Pinecone

---

**Status:** ✅ Pinecone API key is now securely stored in AWS SSM Parameter Store!

**Last Updated:** February 18, 2026

