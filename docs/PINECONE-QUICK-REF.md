# Pinecone Quick Reference

## 🚀 Quick Start (5 Minutes)

### 1. Create Account & Get API Key
```
1. Go to: https://www.pinecone.io/
2. Sign up (free tier available)
3. Create API key: https://app.pinecone.io/organizations/-/projects/-/keys
4. Copy the key (starts with pcsk_...)
```

### 2. Run Setup Script
```powershell
# Install Pinecone client
pip install pinecone-client

# Set API key
$env:PINECONE_API_KEY = "pcsk_your_key_here"

# Run setup script
python scripts/setup-pinecone.py
```

### 3. Configure AWS
```powershell
# Store API key in SSM
aws ssm put-parameter `
  --name "/rag-demo/pinecone-api-key" `
  --value "YOUR_API_KEY" `
  --type "SecureString" `
  --region us-east-1

# Update Lambda
aws lambda update-function-configuration `
  --function-name rag-demo-embedder `
  --environment "Variables={PINECONE_API_KEY=YOUR_KEY,PINECONE_INDEX=rag-demo}" `
  --region us-east-1
```

---

## 📊 Index Configuration

**For this project:**
```
Name: rag-demo
Dimensions: 1536 (text-embedding-3-small)
Metric: cosine
Cloud: AWS
Region: us-east-1
```

---

## 💰 Pricing

**Free Tier:**
- 100,000 vectors
- 1 index
- Perfect for development

**Standard Plan:**
- ~$70/month per pod
- 1M+ vectors
- Multiple indexes

---

## 🔑 Environment Variables

Add to your Lambda/ECS:
```bash
PINECONE_API_KEY=pcsk_xxxxx_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
PINECONE_INDEX=rag-demo
```

---

## 🧪 Test Connection

```python
from pinecone import Pinecone

pc = Pinecone(api_key="YOUR_KEY")
index = pc.Index("rag-demo")

# Get stats
stats = index.describe_index_stats()
print(f"Vectors: {stats['total_vector_count']}")
```

---

## 📝 Common Commands

### List Indexes
```python
pc.list_indexes()
```

### Get Index Stats
```python
index = pc.Index("rag-demo")
stats = index.describe_index_stats()
```

### Delete All Vectors
```python
index.delete(delete_all=True)
```

### Delete by Document ID
```python
index.delete(filter={"document_id": "doc123"})
```

---

## ⚠️ Important Notes

1. **API Key Security:**
   - Never commit API key to Git
   - Use SSM Parameter Store or GitHub Secrets
   - API key format: `pcsk_...`

2. **Dimension Must Match:**
   - Index dimension MUST match embedding dimension
   - text-embedding-3-small = 1536
   - text-embedding-3-large = 3072

3. **Free Tier Limits:**
   - 100K vectors max
   - 1 index only
   - Sufficient for ~4,000 documents

---

## 🔗 Links

- **Console:** https://app.pinecone.io/
- **API Keys:** https://app.pinecone.io/organizations/-/projects/-/keys
- **Docs:** https://docs.pinecone.io/
- **Python SDK:** https://github.com/pinecone-io/pinecone-python-client

---

## 📚 Full Guide

See `docs/PINECONE-SETUP.md` for complete setup instructions.

