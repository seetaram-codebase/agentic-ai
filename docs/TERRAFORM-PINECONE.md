# Terraform Pinecone Integration Guide

## Overview

This guide explains how to deploy the RAG application infrastructure with Pinecone vector storage using Terraform.

---

## Files Added/Modified

### 1. `variables.tf` - New Pinecone Variables
```hcl
variable "pinecone_api_key" {
  description = "Pinecone API key for vector storage"
  type        = string
  sensitive   = true
  default     = ""
}

variable "pinecone_index" {
  description = "Pinecone index name"
  type        = string
  default     = "rag-demo"
}

variable "use_pinecone" {
  description = "Enable Pinecone vector storage"
  type        = bool
  default     = false
}
```

### 2. `lambda.tf` - Embedder Environment Variables
Pinecone config added to embedder Lambda:
```hcl
environment {
  variables = {
    PINECONE_API_KEY = var.pinecone_api_key
    PINECONE_INDEX   = var.pinecone_index
    USE_PINECONE     = var.use_pinecone ? "true" : "false"
  }
}
```

### 3. `ecs.tf` - Backend Environment Variables
Pinecone config added to ECS backend:
```hcl
environment = [
  { name = "PINECONE_API_KEY", value = var.pinecone_api_key },
  { name = "PINECONE_INDEX", value = var.pinecone_index },
  { name = "USE_PINECONE", value = var.use_pinecone ? "true" : "false" }
]
```

### 4. `terraform.tfvars.example` - Configuration Template
Example configuration file with Pinecone settings

### 5. `pinecone-ssm.tf.example` - Secure SSM Configuration
Example for reading Pinecone API key from AWS SSM Parameter Store

---

## Deployment Options

### Option 1: Direct Variable (Quick Start)

**Step 1:** Get Pinecone API Key
```bash
# Sign up at https://www.pinecone.io/
# Create API key from console
# Create index: rag-demo, dimension 1536, metric cosine
```

**Step 2:** Create `terraform.tfvars`
```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
```

**Step 3:** Edit `terraform.tfvars`
```hcl
# Enable Pinecone
use_pinecone     = true
pinecone_api_key = "pcsk_xxxxx_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
pinecone_index   = "rag-demo"
```

**Step 4:** Deploy
```bash
terraform init
terraform plan
terraform apply
```

**⚠️ Security Warning:** terraform.tfvars is in .gitignore, but API key is in plaintext on disk.

---

### Option 2: SSM Parameter Store (Recommended)

**Step 1:** Store API Key in AWS SSM
```powershell
# Store Pinecone API key securely
aws ssm put-parameter `
  --name "/rag-demo/pinecone-api-key" `
  --value "pcsk_xxxxx_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" `
  --type "SecureString" `
  --description "Pinecone API key for RAG demo" `
  --region us-east-1
```

**Step 2:** Create `pinecone-ssm.tf` (rename from .example)
```bash
cd infrastructure/terraform
cp pinecone-ssm.tf.example pinecone-ssm.tf
```

**Step 3:** Edit `pinecone-ssm.tf`
Uncomment the data source and update the Lambda/ECS resources

**Step 4:** Update IAM Permissions
Add to `iam.tf` Lambda execution role:
```hcl
resource "aws_iam_role_policy" "lambda_ssm" {
  name = "lambda-ssm-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/rag-demo/*"
    }]
  })
}
```

**Step 5:** Deploy
```bash
terraform init
terraform plan
terraform apply
```

---

### Option 3: GitHub Actions with Secrets

**Step 1:** Add Pinecone API Key to GitHub Secrets
```
Repository → Settings → Secrets and variables → Actions
New repository secret:
  Name: PINECONE_API_KEY
  Value: pcsk_xxxxx_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Step 2:** Update `.github/workflows/infrastructure.yml`
```yaml
- name: Terraform Apply
  env:
    TF_VAR_pinecone_api_key: ${{ secrets.PINECONE_API_KEY }}
    TF_VAR_use_pinecone: true
    TF_VAR_pinecone_index: rag-demo
  run: |
    cd infrastructure/terraform
    terraform apply -auto-approve
```

**Step 3:** Trigger GitHub Actions
```bash
git push origin main
# Or trigger manually via GitHub UI
```

---

## Configuration Reference

### Environment Variables Set by Terraform

#### Lambda Embedder
```bash
PINECONE_API_KEY=pcsk_xxxxx...
PINECONE_INDEX=rag-demo
USE_PINECONE=true
```

#### ECS Backend
```bash
PINECONE_API_KEY=pcsk_xxxxx...
PINECONE_INDEX=rag-demo
USE_PINECONE=true
```

---

## Terraform Commands

### Initialize
```bash
cd infrastructure/terraform
terraform init
```

### Plan (Preview Changes)
```bash
# Without Pinecone
terraform plan

# With Pinecone (using tfvars)
terraform plan -var-file=terraform.tfvars

# With Pinecone (command line)
terraform plan -var="use_pinecone=true" -var="pinecone_api_key=YOUR_KEY"
```

### Apply (Deploy)
```bash
# Interactive (asks for confirmation)
terraform apply

# Auto-approve (no confirmation)
terraform apply -auto-approve

# With variables
terraform apply -var="use_pinecone=true" -var="pinecone_api_key=YOUR_KEY"
```

### Destroy (Cleanup)
```bash
terraform destroy
```

### Update Specific Resource
```bash
# Update only embedder Lambda
terraform apply -target=aws_lambda_function.embedder

# Update only ECS service
terraform apply -target=aws_ecs_service.backend
```

---

## Validation

### Check Terraform State
```bash
# Show all resources
terraform show

# Show specific resource
terraform state show aws_lambda_function.embedder

# List all resources
terraform state list
```

### Verify Lambda Environment Variables
```powershell
aws lambda get-function-configuration `
  --function-name rag-demo-embedder `
  --region us-east-1 `
  --query 'Environment.Variables'
```

Expected output:
```json
{
  "PINECONE_API_KEY": "pcsk_xxxxx...",
  "PINECONE_INDEX": "rag-demo",
  "USE_PINECONE": "true"
}
```

### Verify ECS Environment Variables
```powershell
aws ecs describe-task-definition `
  --task-definition rag-demo-backend `
  --region us-east-1 `
  --query 'taskDefinition.containerDefinitions[0].environment'
```

---

## Troubleshooting

### Issue: "variable not found"
**Solution:**
```bash
# Ensure terraform.tfvars exists
ls -la terraform.tfvars

# Or pass via command line
terraform apply -var="pinecone_api_key=YOUR_KEY"
```

### Issue: "sensitive value in plan output"
**Solution:** This is normal. Terraform hides sensitive values in output.
```bash
# Values are hidden but still applied
terraform apply
```

### Issue: Lambda not updated
**Solution:**
```bash
# Force update
terraform taint aws_lambda_function.embedder
terraform apply

# Or manually trigger update
aws lambda update-function-configuration \
  --function-name rag-demo-embedder \
  --environment "Variables={PINECONE_API_KEY=YOUR_KEY,PINECONE_INDEX=rag-demo}" \
  --region us-east-1
```

### Issue: SSM parameter not found
**Solution:**
```bash
# Verify parameter exists
aws ssm get-parameter --name "/rag-demo/pinecone-api-key" --region us-east-1

# Create if missing
aws ssm put-parameter \
  --name "/rag-demo/pinecone-api-key" \
  --value "YOUR_KEY" \
  --type "SecureString" \
  --region us-east-1
```

---

## Migration from Manual to Terraform

If you manually set environment variables before:

**Step 1:** Import existing infrastructure (if needed)
```bash
# Import Lambda function
terraform import aws_lambda_function.embedder rag-demo-embedder

# Import ECS service
terraform import aws_ecs_service.backend rag-demo/backend
```

**Step 2:** Apply Terraform with Pinecone config
```bash
terraform apply -var="use_pinecone=true"
```

**Step 3:** Verify
```bash
# Check Lambda
aws lambda get-function-configuration --function-name rag-demo-embedder

# Check ECS
aws ecs describe-task-definition --task-definition rag-demo-backend
```

---

## Security Best Practices

### ✅ DO:
- Use SSM Parameter Store for API keys
- Enable encryption at rest for SSM parameters
- Use IAM roles for Lambda/ECS to access SSM
- Add terraform.tfvars to .gitignore
- Use GitHub Secrets for CI/CD
- Rotate API keys regularly

### ❌ DON'T:
- Commit API keys to Git
- Store API keys in plaintext files
- Share terraform.tfvars between environments
- Use same API key for dev/prod
- Hard-code API keys in Terraform files

---

## Deployment Checklist

- [ ] Create Pinecone account and get API key
- [ ] Create Pinecone index (rag-demo, 1536 dimensions)
- [ ] Store API key in SSM Parameter Store OR terraform.tfvars
- [ ] Update .gitignore to exclude terraform.tfvars
- [ ] Review terraform.tfvars.example
- [ ] Run `terraform init`
- [ ] Run `terraform plan` to preview changes
- [ ] Run `terraform apply` to deploy
- [ ] Verify Lambda environment variables
- [ ] Verify ECS environment variables
- [ ] Test document upload and embedding
- [ ] Check Pinecone console for vectors

---

## Quick Reference

### Files to Configure
```
infrastructure/terraform/
├── terraform.tfvars          # Your config (create from .example)
├── terraform.tfvars.example  # Template with Pinecone settings
├── variables.tf              # ✅ Updated with Pinecone vars
├── lambda.tf                 # ✅ Updated with Pinecone env vars
├── ecs.tf                    # ✅ Updated with Pinecone env vars
└── pinecone-ssm.tf.example   # Optional SSM configuration
```

### Terraform Variables
```hcl
use_pinecone     = true
pinecone_api_key = "pcsk_xxxxx..."
pinecone_index   = "rag-demo"
```

### Deploy Command
```bash
cd infrastructure/terraform
terraform apply -var="use_pinecone=true" -var="pinecone_api_key=YOUR_KEY"
```

---

**Status:** ✅ Terraform configuration ready for Pinecone integration!

**Last Updated:** February 18, 2026

