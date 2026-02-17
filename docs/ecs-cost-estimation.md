# ECS Deployment Cost Estimation

## 🎯 Demo Scenario

Running the RAG application on AWS ECS for a Developer Week demo.

---

## Option 1: ECS Fargate (Serverless - Recommended for Demo)

### Configuration
| Component | Spec |
|-----------|------|
| Backend Container | 0.5 vCPU, 1 GB RAM |
| Tasks | 1 (scale to 2 for failover demo) |
| Region | us-east-1 |

### Fargate Pricing (us-east-1)
| Resource | Price |
|----------|-------|
| vCPU | $0.04048 per vCPU per hour |
| Memory | $0.004445 per GB per hour |

### Cost Calculation

**Per Task (0.5 vCPU, 1 GB):**
```
vCPU:   0.5 × $0.04048 = $0.02024/hour
Memory: 1.0 × $0.004445 = $0.00445/hour
─────────────────────────────────────────
Total per task:           $0.02469/hour
```

**Demo Scenarios:**

| Scenario | Tasks | Hours | ECS Cost |
|----------|-------|-------|----------|
| Quick demo (1 hour) | 1 | 1 | $0.02 |
| Half-day testing | 1 | 4 | $0.10 |
| Full day (8 hours) | 1 | 8 | $0.20 |
| Demo with failover | 2 | 2 | $0.10 |
| Week of prep (40 hrs) | 1 | 40 | $0.99 |

---

## Option 2: ECS EC2 (More Control)

### Configuration
| Component | Spec |
|-----------|------|
| Instance Type | t3.small |
| vCPU | 2 |
| Memory | 2 GB |

### EC2 Pricing
| Instance | On-Demand | Spot (~70% savings) |
|----------|-----------|---------------------|
| t3.small | $0.0208/hour | ~$0.006/hour |
| t3.medium | $0.0416/hour | ~$0.012/hour |

**Demo Cost (t3.small On-Demand):**
| Scenario | Hours | Cost |
|----------|-------|------|
| Quick demo (1 hour) | 1 | $0.02 |
| Full day (8 hours) | 8 | $0.17 |
| Week of prep (40 hrs) | 40 | $0.83 |

---

## Total Demo Cost (All Services Combined)

### 1-Hour Demo

| Service | Cost |
|---------|------|
| ECS Fargate (1 task) | $0.02 |
| DynamoDB (on-demand) | $0.01 |
| ECR (container storage) | $0.01 |
| ALB (if used) | $0.02 |
| Data Transfer | $0.01 |
| Azure OpenAI (GPT-4o) | $1.00 - $2.00 |
| **Total** | **~$1.10 - $2.10** |

### 8-Hour Demo Day

| Service | Cost |
|---------|------|
| ECS Fargate | $0.20 |
| DynamoDB | $0.05 |
| ECR | $0.01 |
| ALB | $0.16 |
| Data Transfer | $0.05 |
| Azure OpenAI | $5.00 - $15.00 |
| **Total** | **~$5.50 - $15.50** |

### Full Week Preparation (40 hours)

| Service | Cost |
|---------|------|
| ECS Fargate | $0.99 |
| DynamoDB | $0.25 |
| ECR | $0.10 |
| ALB | $0.80 |
| Data Transfer | $0.20 |
| Azure OpenAI | $20.00 - $50.00 |
| **Total** | **~$22 - $52** |

---

## Detailed Service Costs

### DynamoDB (On-Demand)

| Operation | Price | Demo Usage | Cost |
|-----------|-------|------------|------|
| Write (WCU) | $1.25 per million | ~100 writes | $0.0001 |
| Read (RCU) | $0.25 per million | ~1000 reads | $0.0003 |
| Storage | $0.25 per GB/month | <1 MB | ~$0.00 |
| **Per Hour** | | | **~$0.01** |

### ECR (Container Registry)

| Item | Price |
|------|-------|
| Storage | $0.10 per GB/month |
| Data Transfer | $0.09 per GB (outbound) |
| **Per Image (~500MB)** | **~$0.05/month** |

### Application Load Balancer (Optional)

| Item | Price |
|------|-------|
| ALB Hour | $0.0225/hour |
| LCU (usage) | $0.008 per LCU-hour |
| **Per Hour** | **~$0.02-0.03** |

### CloudWatch Logs

| Item | Price |
|------|-------|
| Ingestion | $0.50 per GB |
| Storage | $0.03 per GB/month |
| **Per Hour (demo)** | **~$0.01** |

---

## 💡 Cost Optimization Tips

### 1. Use Fargate Spot (up to 70% savings)
```
Regular: $0.02469/hour
Spot:    $0.0074/hour (70% off)
```
⚠️ Can be interrupted - not recommended for live demo

### 2. Run Only When Needed
```bash
# Stop ECS service
aws ecs update-service --cluster rag-demo --service backend --desired-count 0

# Start ECS service
aws ecs update-service --cluster rag-demo --service backend --desired-count 1
```

### 3. Skip ALB for Demo
- Use ECS public IP directly
- Or use API Gateway instead

### 4. Use DynamoDB Free Tier
- 25 GB storage
- 25 WCU, 25 RCU (provisioned)
- Enough for demo!

---

## 📊 Cost Comparison Summary

| Option | 1 Hour | 8 Hours | 40 Hours |
|--------|--------|---------|----------|
| **Local (just Azure)** | $1-2 | $5-15 | $20-50 |
| **ECS Fargate** | $1-2.50 | $6-16 | $25-55 |
| **ECS EC2 (t3.small)** | $1-2.50 | $5-15 | $22-52 |
| **ECS EC2 Spot** | $1-2.20 | $5-12 | $20-45 |

---

## 🎯 Recommendation for Demo

**Use ECS Fargate:**
- ✅ No server management
- ✅ Pay only when running
- ✅ Easy to start/stop
- ✅ ~$2/hour total (including Azure OpenAI)

**Budget for Demo:**
| Phase | Budget |
|-------|--------|
| Development (local) | $10 |
| Testing on ECS | $15 |
| Demo day (2 hours) | $5 |
| **Total Safe Budget** | **$30** |

---

## Quick Deploy Commands

```bash
# Build and push to ECR
docker build -t rag-demo-backend ./backend
aws ecr get-login-password | docker login --username AWS --password-stdin YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
docker tag rag-demo-backend:latest YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/rag-demo:latest
docker push YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/rag-demo:latest

# Create ECS cluster (Fargate)
aws ecs create-cluster --cluster-name rag-demo --capacity-providers FARGATE

# Run service
aws ecs create-service --cluster rag-demo --service-name backend --task-definition rag-demo-task --desired-count 1 --launch-type FARGATE
```
