# Complete Cost Analysis: Lambda + ECS + Azure OpenAI

## Overview

This analysis covers the complete RAG pipeline costs:
1. **Document Upload** → S3 + SQS
2. **Chunking** → Lambda (Chunker)
3. **Embedding** → Lambda (Embedder) + Azure OpenAI
4. **Inference** → ECS + Azure OpenAI (GPT-4o)

---

## Lambda Pricing (us-east-1)

| Resource | Price |
|----------|-------|
| Requests | $0.20 per 1 million requests |
| Duration | $0.0000166667 per GB-second |

---

## Your Lambda Configuration

| Lambda | Memory | Timeout | Cost per 100ms |
|--------|--------|---------|----------------|
| **Chunker** | 512 MB | 60s | $0.00000083 |
| **Embedder** | 512 MB | 30s | $0.00000083 |

---

## Cost Calculation Formula

```
Cost = (Memory_GB × Duration_seconds × $0.0000166667) + ($0.20 / 1,000,000)
```

---

## Scenario Analysis

### Scenario 1: Small Document (10 pages, ~50 chunks)

| Step | Invocations | Avg Duration | Memory | Cost |
|------|-------------|--------------|--------|------|
| Chunker | 1 | 5 sec | 512 MB | $0.000042 |
| Embedder | 50 | 0.5 sec each | 512 MB | $0.00021 |
| **Total** | 51 | | | **$0.00025** |

### Scenario 2: Medium Document (50 pages, ~250 chunks)

| Step | Invocations | Avg Duration | Memory | Cost |
|------|-------------|--------------|--------|------|
| Chunker | 1 | 15 sec | 512 MB | $0.000125 |
| Embedder | 50 batches (5 chunks each) | 1 sec each | 512 MB | $0.00042 |
| **Total** | 51 | | | **$0.00055** |

### Scenario 3: Large Document (200 pages, ~1000 chunks)

| Step | Invocations | Avg Duration | Memory | Cost |
|------|-------------|--------------|--------|------|
| Chunker | 1 | 45 sec | 512 MB | $0.000375 |
| Embedder | 200 batches (5 chunks each) | 1 sec each | 512 MB | $0.00167 |
| **Total** | 201 | | | **$0.002** |

### Scenario 4: Bulk Upload (100 documents, ~10,000 chunks total)

| Step | Invocations | Avg Duration | Memory | Cost |
|------|-------------|--------------|--------|------|
| Chunker | 100 | 10 sec avg | 512 MB | $0.0083 |
| Embedder | 2000 batches | 1 sec each | 512 MB | $0.0167 |
| **Total** | 2100 | | | **$0.025** |

---

## Cost Summary Table

| Documents | Pages | Chunks | Lambda Cost | Azure OpenAI Cost | **Total** |
|-----------|-------|--------|-------------|-------------------|-----------|
| 1 small | 10 | 50 | $0.00025 | $0.001 | **$0.001** |
| 1 medium | 50 | 250 | $0.00055 | $0.005 | **$0.006** |
| 1 large | 200 | 1000 | $0.002 | $0.02 | **$0.022** |
| 10 docs | 500 | 2500 | $0.005 | $0.05 | **$0.055** |
| 100 docs | 5000 | 25000 | $0.05 | $0.50 | **$0.55** |
| 1000 docs | 50000 | 250000 | $0.50 | $5.00 | **$5.50** |

---

## Azure OpenAI Embedding Cost

Using `text-embedding-3-small` ($0.02 per 1M tokens):

| Chunks | Avg Tokens/Chunk | Total Tokens | Cost |
|--------|------------------|--------------|------|
| 50 | 500 | 25,000 | $0.0005 |
| 250 | 500 | 125,000 | $0.0025 |
| 1,000 | 500 | 500,000 | $0.01 |
| 10,000 | 500 | 5,000,000 | $0.10 |
| 100,000 | 500 | 50,000,000 | $1.00 |

---

## Demo Cost Estimate

For your Developer Week demo with ~10-20 documents:

| Item | Estimate |
|------|----------|
| Lambda (chunker + embedder) | $0.01 |
| Azure OpenAI embeddings | $0.05 |
| DynamoDB reads/writes | $0.001 |
| S3 storage | $0.001 |
| SQS messages | $0.001 |
| **Total per demo run** | **~$0.06** |

---

## Hourly Cost Comparison

| Usage Level | Lambda/hr | Azure OpenAI/hr | Total/hr |
|-------------|-----------|-----------------|----------|
| Light (10 docs) | $0.005 | $0.05 | **$0.06** |
| Medium (50 docs) | $0.025 | $0.25 | **$0.28** |
| Heavy (200 docs) | $0.10 | $1.00 | **$1.10** |

---

## 💡 Cost Optimization Tips

### 1. Batch Embeddings (Already Implemented)
Embedder processes 5 chunks per invocation instead of 1:
- Reduces Lambda invocations by 5x
- Reduces cold starts

### 2. Use Reserved Concurrency
Set reserved concurrency to limit parallel executions:
```bash
aws lambda put-function-concurrency \
  --function-name rag-demo-embedder \
  --reserved-concurrent-executions 10
```

### 3. Optimize Memory
- 512 MB is good balance of speed vs cost
- More memory = faster but more expensive
- Less memory = slower, may timeout

### 4. Use SQS Batching
Embedder already batches 5 messages:
```hcl
batch_size = 5
maximum_batching_window_in_seconds = 5
```

---

## Free Tier (First 12 months)

AWS Lambda Free Tier includes:
- 1 million free requests/month
- 400,000 GB-seconds/month

**Your demo easily fits in free tier!**

| Your Usage | Free Tier | % Used |
|------------|-----------|--------|
| ~2,000 requests | 1,000,000 | 0.2% |
| ~1,000 GB-seconds | 400,000 | 0.25% |

---

## Bottom Line

> **Lambda costs are negligible** (~$0.01-0.10 per demo)
> 
> **Azure OpenAI is the main cost** (~$0.05-1.00 per demo)
>
> **Total demo cost: ~$0.06 to $1.10 depending on document count**

---

## ECS Inference Costs

### ECS Fargate Pricing (us-east-1)

| Resource | Price |
|----------|-------|
| vCPU | $0.04048 per vCPU per hour |
| Memory | $0.004445 per GB per hour |

### Your ECS Configuration

| Setting | Dev | Prod |
|---------|-----|------|
| vCPU | 0.5 | 1.0 |
| Memory | 1 GB | 2 GB |
| Tasks | 1 | 2 |

### ECS Hourly Cost

| Environment | vCPU Cost | Memory Cost | **Total/hour** |
|-------------|-----------|-------------|----------------|
| Dev (0.5 vCPU, 1GB) | $0.02024 | $0.00445 | **$0.025** |
| Prod (1 vCPU, 2GB, 2 tasks) | $0.08096 | $0.01778 | **$0.099** |

---

## Azure OpenAI Inference Costs (GPT-4o)

### GPT-4o Pricing

| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|----------------------|------------------------|
| GPT-4o | $2.50 | $10.00 |
| GPT-4o-mini | $0.15 | $0.60 |

### Inference Cost per Query

| Query Type | Input Tokens | Output Tokens | GPT-4o Cost | GPT-4o-mini Cost |
|------------|--------------|---------------|-------------|------------------|
| Simple (short context) | 1,000 | 200 | $0.0045 | $0.00027 |
| Medium (5 chunks context) | 3,000 | 500 | $0.0125 | $0.00075 |
| Complex (10 chunks context) | 6,000 | 1,000 | $0.025 | $0.0015 |

### Inference Cost per Hour (Queries)

| Queries/Hour | GPT-4o Cost | GPT-4o-mini Cost |
|--------------|-------------|------------------|
| 10 | $0.125 | $0.0075 |
| 50 | $0.625 | $0.0375 |
| 100 | $1.25 | $0.075 |

---

## Document Upload Costs

### S3 Pricing

| Operation | Price |
|-----------|-------|
| PUT/POST requests | $0.005 per 1,000 |
| GET requests | $0.0004 per 1,000 |
| Storage | $0.023 per GB/month |

### SQS Pricing

| Operation | Price |
|-----------|-------|
| Requests | $0.40 per 1 million |

### Upload Cost per Document

| Document Size | S3 PUT | S3 Storage/month | SQS | **Total** |
|---------------|--------|------------------|-----|-----------|
| 1 MB | $0.000005 | $0.000023 | $0.0000004 | **~$0.00003** |
| 10 MB | $0.000005 | $0.00023 | $0.0000004 | **~$0.0003** |
| 100 MB | $0.000005 | $0.0023 | $0.0000004 | **~$0.003** |

### Upload Cost for Demo

| Documents | Total Size | S3 + SQS Cost |
|-----------|------------|---------------|
| 10 docs | 50 MB | **$0.001** |
| 50 docs | 250 MB | **$0.006** |
| 100 docs | 500 MB | **$0.012** |

---

## Complete Demo Cost Breakdown

### Per-Hour Costs (Running Demo)

| Component | Dev Cost/hr | Prod Cost/hr |
|-----------|-------------|--------------|
| ECS Fargate | $0.025 | $0.099 |
| Lambda (idle) | $0.00 | $0.00 |
| DynamoDB | $0.01 | $0.01 |
| S3 | $0.001 | $0.001 |
| **AWS Subtotal** | **$0.036** | **$0.11** |

### Per-Activity Costs

| Activity | Cost |
|----------|------|
| Upload 1 document (50 pages) | $0.0001 |
| Chunk 1 document (250 chunks) | $0.0006 |
| Embed 1 document (250 chunks) | $0.0004 (Lambda) + $0.0025 (Azure) = $0.003 |
| Query (1 inference with GPT-4o) | $0.0125 |
| Query (1 inference with GPT-4o-mini) | $0.00075 |

---

## Demo Day Cost Estimate

### Scenario: 2-Hour Demo

| Activity | Quantity | Cost |
|----------|----------|------|
| ECS running (2 hours) | 2 hrs | $0.05 |
| Upload documents | 20 docs | $0.002 |
| Chunk documents | 20 docs | $0.012 |
| Embed documents (~5000 chunks) | 5000 | $0.05 (Azure) |
| Live queries (GPT-4o-mini) | 50 queries | $0.04 |
| Live queries (GPT-4o) | 10 queries | $0.125 |
| **TOTAL** | | **~$0.28** |

### Cost by Service

| Service | 2-Hour Demo Cost | % of Total |
|---------|------------------|------------|
| AWS (ECS, Lambda, S3, SQS, DynamoDB) | $0.07 | 25% |
| Azure OpenAI (Embeddings) | $0.05 | 18% |
| Azure OpenAI (Inference GPT-4o/mini) | $0.16 | 57% |
| **Total** | **$0.28** | 100% |

---

## Monthly Cost Projections

### Light Usage (Dev/Testing)

| Component | Hours/Month | Cost |
|-----------|-------------|------|
| ECS (8 hrs/day × 20 days) | 160 hrs | $4.00 |
| Lambda (~1000 invocations) | - | $0.10 |
| Azure Embeddings (~10K chunks) | - | $0.20 |
| Azure Inference (~500 queries) | - | $6.25 |
| S3 + DynamoDB + SQS | - | $1.00 |
| **Total** | | **~$11.55** |

### Production Usage

| Component | Hours/Month | Cost |
|-----------|-------------|------|
| ECS (24/7, 2 tasks) | 720 hrs | $71.28 |
| Lambda (~100K invocations) | - | $2.00 |
| Azure Embeddings (~1M chunks) | - | $20.00 |
| Azure Inference (~50K queries) | - | $625.00 |
| S3 + DynamoDB + SQS | - | $10.00 |
| **Total** | | **~$728** |

---

## 💰 Cost Optimization Summary

| Optimization | Savings |
|--------------|---------|
| Use GPT-4o-mini instead of GPT-4o | 95% on inference |
| Stop ECS when not in use | 100% of idle ECS |
| Use Lambda Free Tier | ~$2/month |
| Batch embeddings | 5x fewer Lambda calls |
| Use Fargate Spot | 70% on ECS |

---

## Quick Reference Card

| What | Cost |
|------|------|
| **Upload 1 doc** | ~$0.0001 |
| **Process 1 doc (chunk + embed)** | ~$0.003 |
| **1 Query (GPT-4o-mini)** | ~$0.001 |
| **1 Query (GPT-4o)** | ~$0.013 |
| **ECS running (1 hour)** | ~$0.025 |
| **Full demo (2 hours)** | **~$0.30** |

