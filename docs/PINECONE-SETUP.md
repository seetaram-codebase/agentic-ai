# Pinecone Setup Guide

## Overview

Pinecone is a managed vector database used for storing and searching document embeddings. This guide will help you set up Pinecone for the RAG demo application.

---

## Step 1: Create Pinecone Account

1. **Sign Up:**
   - Go to https://www.pinecone.io/
   - Click "Sign Up" or "Get Started Free"
   - Sign up with email or GitHub

2. **Verify Email:**
   - Check your email for verification link
   - Click to verify your account

3. **Create Organization:**
   - Enter organization name (e.g., "YourCompany-RAG")
   - Select your region/cloud provider

---

## Step 2: Create API Key

1. **Navigate to API Keys:**
   - Login to Pinecone Console: https://app.pinecone.io/
   - Click on your profile → "API Keys"
   - Or go to: https://app.pinecone.io/organizations/-/projects/-/keys

2. **Create New API Key:**
   - Click "Create API Key"
   - Name: `rag-demo-key` (or any descriptive name)
   - Click "Create Key"

3. **Copy API Key:**
   - ⚠️ **IMPORTANT:** Copy the API key immediately
   - You won't be able to see it again!
   - Format: `pcsk_xxxxx_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

4. **Save Securely:**
   ```bash
   # DO NOT commit this to Git!
   # Save in password manager or secure location
   ```

---

## Step 3: Create Pinecone Index

An index is where your vectors will be stored.

### Using Pinecone Console (Recommended for First Time)

1. **Navigate to Indexes:**
   - In Pinecone Console, click "Indexes"
   - Or go to: https://app.pinecone.io/organizations/-/projects/-/indexes

2. **Create New Index:**
   - Click "Create Index"

3. **Configure Index:**
   ```
   Index Name: rag-demo
   Dimensions: 1536
   Metric: cosine
   Cloud: AWS
   Region: us-east-1 (same as your Lambda/ECS)
   ```

   **Dimension Explanation:**
   - `1536` = OpenAI's text-embedding-3-small model
   - `3072` = OpenAI's text-embedding-3-large model
   - `1024` = Azure OpenAI text-embedding-ada-002
   
   **For this project, use `1536`** (matches text-embedding-3-small)

4. **Select Plan:**
   - **Starter (Free):** Good for development
     - 100K vectors free
     - 1 index
   - **Standard:** For production
     - Pay per usage
     - Multiple indexes

5. **Create Index:**
   - Click "Create Index"
   - Wait for index to be ready (takes ~1 minute)

### Using Python Script (Alternative)

```python
from pinecone import Pinecone, ServerlessSpec

# Initialize Pinecone
pc = Pinecone(api_key="YOUR_API_KEY_HERE")

# Create index
pc.create_index(
    name="rag-demo",
    dimension=1536,  # text-embedding-3-small
    metric="cosine",
    spec=ServerlessSpec(
        cloud="aws",
        region="us-east-1"
    )
)

print("Index created successfully!")
```

---

## Step 4: Configure Environment Variables

### For Lambda Functions (Embedder)

Add to `infrastructure/terraform/lambda.tf`:

```hcl
resource "aws_lambda_function" "embedder" {
  # ...existing code...

  environment {
    variables = {
      # ...existing variables...
      PINECONE_API_KEY = var.pinecone_api_key
      PINECONE_INDEX   = "rag-demo"
    }
  }
}
```

Add to `infrastructure/terraform/variables.tf`:

```hcl
variable "pinecone_api_key" {
  description = "Pinecone API key for vector storage"
  type        = string
  sensitive   = true
}
```

### For ECS Backend

Add to `infrastructure/terraform/ecs.tf`:

```hcl
resource "aws_ecs_task_definition" "backend" {
  # ...existing code...

  container_definitions = jsonencode([{
    # ...existing config...
    environment = [
      # ...existing env vars...
      {
        name  = "PINECONE_API_KEY"
        value = var.pinecone_api_key
      },
      {
        name  = "PINECONE_INDEX"
        value = "rag-demo"
      }
    ]
  }])
}
```

### Using AWS Systems Manager Parameter Store (Recommended)

Store the API key securely:

```powershell
# Store in SSM Parameter Store
aws ssm put-parameter `
  --name "/rag-demo/pinecone-api-key" `
  --value "YOUR_PINECONE_API_KEY" `
  --type "SecureString" `
  --description "Pinecone API key for RAG demo" `
  --region us-east-1
```

Then update Terraform to read from SSM:

```hcl
data "aws_ssm_parameter" "pinecone_api_key" {
  name = "/rag-demo/pinecone-api-key"
}

# Use in Lambda
resource "aws_lambda_function" "embedder" {
  environment {
    variables = {
      PINECONE_API_KEY = data.aws_ssm_parameter.pinecone_api_key.value
      PINECONE_INDEX   = "rag-demo"
    }
  }
}
```

### Using GitHub Secrets (For GitHub Actions)

1. **Add to GitHub Secrets:**
   - Go to your GitHub repository
   - Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `PINECONE_API_KEY`
   - Value: Your Pinecone API key
   - Click "Add secret"

2. **Update GitHub Actions Workflow:**

Add to `.github/workflows/deploy-lambda.yml`:

```yaml
- name: Deploy Embedder Lambda
  env:
    PINECONE_API_KEY: ${{ secrets.PINECONE_API_KEY }}
  run: |
    # Update Lambda environment variables
    aws lambda update-function-configuration \
      --function-name rag-demo-embedder \
      --environment "Variables={
        PINECONE_API_KEY=$PINECONE_API_KEY,
        PINECONE_INDEX=rag-demo
      }" \
      --region us-east-1
```

### For Local Development

Create `.env` file in project root:

```bash
# .env (DO NOT COMMIT!)
PINECONE_API_KEY=pcsk_xxxxx_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
PINECONE_INDEX=rag-demo
```

Add to `.gitignore` (already done):
```
.env
**/.env
*.env.local
```

---

## Step 5: Update Lambda Requirements

Add Pinecone to `lambda/embedder/requirements-minimal.txt`:

```txt
# ...existing dependencies...

# Pinecone for vector storage
pinecone-client
```

---

## Step 6: Verify Setup

### Test Connection (Python)

```python
import os
from pinecone import Pinecone

# Initialize
pc = Pinecone(api_key=os.environ.get('PINECONE_API_KEY'))

# List indexes
indexes = pc.list_indexes()
print("Available indexes:", indexes)

# Connect to index
index = pc.Index("rag-demo")

# Get stats
stats = index.describe_index_stats()
print("Index stats:", stats)
```

### Test Embedding Storage

```python
from pinecone import Pinecone

pc = Pinecone(api_key="YOUR_API_KEY")
index = pc.Index("rag-demo")

# Test upsert
test_embedding = [0.1] * 1536  # Dummy 1536-dim vector

index.upsert(vectors=[{
    'id': 'test-vector-1',
    'values': test_embedding,
    'metadata': {
        'text': 'This is a test document',
        'source': 'test.txt'
    }
}])

print("✅ Test vector stored successfully!")

# Query
results = index.query(
    vector=test_embedding,
    top_k=1,
    include_metadata=True
)

print("Query results:", results)

# Clean up
index.delete(ids=['test-vector-1'])
print("✅ Test vector deleted")
```

---

## Step 7: Deploy Changes

### Update Terraform

```powershell
cd infrastructure/terraform

# Initialize
terraform init

# Plan with Pinecone key
terraform plan -var="pinecone_api_key=YOUR_API_KEY"

# Apply
terraform apply -var="pinecone_api_key=YOUR_API_KEY"
```

### Update Lambda Environment Variables Manually

```powershell
# Update Embedder Lambda
aws lambda update-function-configuration `
  --function-name rag-demo-embedder `
  --environment "Variables={
    PINECONE_API_KEY=YOUR_PINECONE_API_KEY,
    PINECONE_INDEX=rag-demo,
    DYNAMODB_DOCUMENTS_TABLE=rag-demo-documents,
    DYNAMODB_CHUNKS_TABLE=rag-demo-chunks,
    VECTOR_STORE_API_URL=http://YOUR_BACKEND_IP:8000,
    AZURE_OPENAI_KEY=$env:AZURE_OPENAI_KEY,
    AZURE_OPENAI_ENDPOINT=$env:AZURE_OPENAI_ENDPOINT
  }" `
  --region us-east-1
```

---

## Architecture: How Pinecone is Used

```
Document Upload
    ↓
S3 → SQS → Chunker Lambda → Chunks (SQS)
                ↓
        Embedder Lambda
                ↓
    Generate Embedding (Azure OpenAI)
                ↓
        Store in Pinecone
                ↓
    Index: rag-demo
    Vector ID: {document_id}_{chunk_index}
    Metadata: text, source, page
```

### Query Flow

```
User Query
    ↓
Backend API (ECS)
    ↓
Generate Query Embedding (Azure OpenAI)
    ↓
Search Pinecone (cosine similarity)
    ↓
Retrieve Top K Chunks
    ↓
Send to LLM with Context
    ↓
Return Answer
```

---

## Pinecone Index Configuration

### Current Settings

```
Name: rag-demo
Dimensions: 1536
Metric: cosine
Region: us-east-1
Cloud: AWS
Pod Type: Starter (Free) or s1.x1 (Standard)
```

### Metadata Stored Per Vector

```json
{
  "id": "doc123_0",
  "values": [0.123, 0.456, ...],  // 1536 dimensions
  "metadata": {
    "document_id": "doc123",
    "document_key": "uploads/myfile.pdf",
    "chunk_index": 0,
    "text": "First 1000 chars of chunk text...",
    "source": "myfile.pdf",
    "page": 1
  }
}
```

---

## Cost Estimation

### Pinecone Pricing (as of 2026)

**Starter Plan (Free):**
- 100,000 vectors
- 1 index
- $0/month

**Standard Plan:**
- $0.096/hour per s1.x1 pod (~$70/month)
- 1M vectors per pod
- Multiple indexes

### Storage Calculation

```
For 100 documents (~100 pages each):
- Total pages: ~10,000
- Chunks per page: ~2-3
- Total chunks: ~25,000
- Storage needed: 25,000 vectors

Free tier sufficient: ✅ (100K limit)
```

---

## Monitoring & Management

### View Index Stats

```python
from pinecone import Pinecone

pc = Pinecone(api_key=os.environ['PINECONE_API_KEY'])
index = pc.Index("rag-demo")

stats = index.describe_index_stats()
print(f"Total vectors: {stats['total_vector_count']}")
print(f"Dimension: {stats['dimension']}")
print(f"Index fullness: {stats['index_fullness']}")
```

### Delete All Vectors (Reset)

```python
index.delete(delete_all=True)
print("All vectors deleted")
```

### Delete Specific Document

```python
# Delete all chunks for a document
index.delete(filter={"document_id": "doc123"})
```

---

## Troubleshooting

### Issue: "Invalid API Key"
**Solution:** 
- Verify API key is correct
- Check environment variable is set: `echo $PINECONE_API_KEY`
- Regenerate API key in Pinecone console

### Issue: "Index not found"
**Solution:**
- Verify index exists: `pc.list_indexes()`
- Check index name matches: `rag-demo`
- Ensure index is in correct region

### Issue: "Dimension mismatch"
**Solution:**
- Embedding dimension must match index dimension
- text-embedding-3-small = 1536 dimensions
- Recreate index with correct dimension if needed

### Issue: "Quota exceeded"
**Solution:**
- Check vector count: `index.describe_index_stats()`
- Free tier limit: 100K vectors
- Upgrade to Standard plan or delete old vectors

---

## Alternative: Use ChromaDB Instead

If you prefer not to use Pinecone, you can use ChromaDB (already configured in backend):

**Pros:**
- Free and open source
- No API key needed
- Runs in ECS container

**Cons:**
- Not as scalable as Pinecone
- Requires persistent storage (EFS)
- More complex deployment

The backend already supports ChromaDB - just set:
```bash
USE_CHROMA=true
CHROMA_PERSIST_DIR=/data/chroma
```

---

## Quick Setup Checklist

- [ ] Create Pinecone account
- [ ] Create API key and save it securely
- [ ] Create index: `rag-demo`, dimension `1536`, metric `cosine`
- [ ] Add `PINECONE_API_KEY` to AWS SSM Parameter Store
- [ ] Add `PINECONE_API_KEY` to GitHub Secrets
- [ ] Update Terraform configuration with Pinecone variables
- [ ] Add `pinecone-client` to `lambda/embedder/requirements-minimal.txt`
- [ ] Deploy infrastructure: `terraform apply`
- [ ] Deploy embedder Lambda
- [ ] Test with sample document upload
- [ ] Verify vectors in Pinecone console

---

## Next Steps

1. **Complete Setup:** Follow steps 1-7 above
2. **Test Upload:** Upload a document and verify embeddings are stored
3. **Test Query:** Search for relevant chunks using similarity search
4. **Monitor Usage:** Check Pinecone dashboard for vector count and queries
5. **Scale:** Upgrade to Standard plan when approaching 100K vectors

---

**Status:** Pinecone integration is coded and ready - just needs API key configuration!

**Last Updated:** February 18, 2026

