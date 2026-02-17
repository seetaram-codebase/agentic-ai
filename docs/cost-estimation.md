# Cost Estimation - RAG Demo

## Overview

This document provides detailed cost estimates for running the RAG demo application per hour, broken down by AWS and Azure services.

## Cost Summary

| Category | Per Hour | Per Day (8 hrs) | Per Month (est.) |
|----------|----------|-----------------|------------------|
| AWS Services | $0.10 - $0.20 | $0.80 - $1.60 | $25 - $50 |
| Azure OpenAI | $0.50 - $3.00 | $4.00 - $24.00 | $120 - $720 |
| Vector DB | $0.00 - $0.10 | $0.00 - $0.80 | $0 - $70 |
| **TOTAL** | **$0.60 - $3.30** | **$4.80 - $26.40** | **$145 - $840** |

## AWS Services Breakdown

### S3 (Document Storage)

| Item | Cost |
|------|------|
| Storage (per GB/month) | $0.023 |
| PUT requests (per 1000) | $0.005 |
| GET requests (per 1000) | $0.0004 |
| **Estimated per hour (demo)** | **~$0.01** |

*For demo: ~100MB documents, ~100 requests/hour*

### SQS (Message Queue)

| Item | Cost |
|------|------|
| First 1M requests/month | Free |
| After 1M (per 1M) | $0.40 |
| **Estimated per hour (demo)** | **~$0.01** |

*For demo: ~100 messages/hour = essentially free*

### Lambda (Processing)

| Item | Cost |
|------|------|
| Requests (per 1M) | $0.20 |
| Duration (per GB-second) | $0.0000166667 |
| Free tier | 1M requests + 400K GB-seconds |
| **Estimated per hour (demo)** | **~$0.05 - $0.10** |

*For demo: ~50 invocations/hour, 512MB memory, 10s avg duration*

Calculation:
- 50 invocations × 10 seconds × 0.5 GB = 250 GB-seconds/hour
- 250 × $0.0000166667 = $0.004/hour
- Plus request costs: 50 × $0.0000002 = negligible
- **Realistic with processing: ~$0.05/hour**

### API Gateway

| Item | Cost |
|------|------|
| REST API (per 1M requests) | $3.50 |
| **Estimated per hour (demo)** | **~$0.02** |

*For demo: ~500 API calls/hour*

### CloudWatch

| Item | Cost |
|------|------|
| Logs ingestion (per GB) | $0.50 |
| Logs storage (per GB/month) | $0.03 |
| **Estimated per hour (demo)** | **~$0.01** |

### AWS Total Per Hour: **$0.10 - $0.20**

---

## Azure OpenAI Breakdown

### GPT-4 (Chat Completions)

| Model | Input (per 1K tokens) | Output (per 1K tokens) |
|-------|----------------------|------------------------|
| GPT-4 | $0.03 | $0.06 |
| GPT-4-32k | $0.06 | $0.12 |
| GPT-4o | $0.005 | $0.015 |
| GPT-4o-mini | $0.00015 | $0.0006 |

### Embeddings

| Model | Cost (per 1K tokens) |
|-------|---------------------|
| text-embedding-ada-002 | $0.0001 |
| text-embedding-3-small | $0.00002 |
| text-embedding-3-large | $0.00013 |

### Demo Usage Estimate

**Scenario: Active demo session (1 hour)**

| Operation | Tokens | Count | Cost |
|-----------|--------|-------|------|
| Document embedding | 1000 | 50 chunks | $0.005 |
| Query embedding | 100 | 20 queries | $0.0002 |
| GPT-4 input | 2000 | 20 queries | $1.20 |
| GPT-4 output | 500 | 20 queries | $0.60 |
| **Subtotal** | | | **$1.81** |

**Light usage (testing): ~$0.50/hour**
**Heavy demo: ~$3.00/hour**

### Azure Total Per Hour: **$0.50 - $3.00**

---

## Vector Database Options

### Option A: Chroma (Self-hosted)

| Deployment | Cost/Hour |
|------------|-----------|
| Local (development) | $0.00 |
| EC2 t3.small | ~$0.02 |
| Lambda (ephemeral) | Included in Lambda costs |

### Option B: Pinecone

| Tier | Cost |
|------|------|
| Free tier | $0.00 (100K vectors) |
| Starter | $0.00 (1 index, 100K vectors) |
| Standard (Serverless) | ~$0.10/hour |

**Recommendation for demo: Pinecone Free Tier = $0.00**

---

## Demo Day Cost Scenarios

### Scenario 1: Light Demo (1 hour)
- Few document uploads
- 10-15 queries
- **Cost: ~$0.70**

### Scenario 2: Full Demo (1 hour)
- Multiple document uploads
- 30-40 queries
- Failover demonstration
- **Cost: ~$2.00**

### Scenario 3: All-Day Testing (8 hours)
- Continuous testing
- Multiple demo runs
- **Cost: ~$15.00**

### Scenario 4: Week of Preparation (40 hours)
- Development and testing
- Multiple full demos
- **Cost: ~$50-80**

---

## Cost Optimization Tips

### 1. Use GPT-4o-mini for Development
- 20x cheaper than GPT-4
- Good for testing, switch to GPT-4 for demo

### 2. Use Pinecone Free Tier
- 100K vectors included
- Sufficient for demo

### 3. Lambda Provisioned Concurrency (Skip for demo)
- Only needed for production
- Adds ~$0.015/hour per provisioned instance

### 4. Cleanup After Demo
```bash
# Delete S3 objects
aws s3 rm s3://rag-demo-bucket --recursive

# Delete Pinecone index
# Via Pinecone console or API

# Delete CloudWatch logs
aws logs delete-log-group --log-group-name /aws/lambda/rag-processor
```

---

## Recording Cost for Backup

**OBS Studio**: Free
**Storage (1 hour 1080p recording)**: ~5GB local storage

No additional cloud costs for recording.

---

## Budget Recommendation

| Phase | Budget |
|-------|--------|
| Development (2 hours) | $5 |
| Testing (1 day) | $20 |
| Demo day (2 hours active) | $5 |
| **Total Demo Budget** | **$30** |

**Safe buffer: $50 total budget**
