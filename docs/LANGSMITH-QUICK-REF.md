# LangSmith Integration - Quick Reference

## Setup (5 Minutes)

### 1. Store API Key in SSM
```powershell
# Windows
.\scripts\setup-langsmith.ps1 -LangSmithApiKey "lsv2_pt_xxxxxxxxxxxxx"
```

### 2. Deploy Infrastructure
```bash
cd infrastructure/terraform
terraform apply
```

### 3. Redeploy Services
```bash
# ECS Backend
aws ecs update-service --cluster rag-demo --service backend --force-new-deployment

# Lambda (via GitHub Actions or manually)
```

### 4. Test
```bash
# Make query
curl -X POST http://YOUR_IP:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What is ML?"}'

# View in LangSmith
# https://smith.langchain.com/
```

---

## Failover Support

### ✅ ECS Backend
- **Type**: Sophisticated with health tracking
- **Failover**: us-east → eu-west (automatic)
- **Recovery**: Retries after 60 seconds
- **Optimization**: Skips unhealthy endpoints
- **LangSmith**: Shows both attempts in trace

### ✅ Embedder Lambda  
- **Type**: Sequential (stateless)
- **Failover**: us-east → eu-west (automatic)
- **Recovery**: Tries us-east every invocation
- **Optimization**: None (stateless lambda)
- **LangSmith**: Shows successful region used

---

## What You'll See in LangSmith

### Normal Query
```
rag_query (6s, $0.002)
├─ embedding (2s) → us-east ✅
├─ vector search (0.5s)
└─ chat (3.5s) → us-east ✅
```

### During Failover
```
rag_query (35s, $0.002)
├─ embedding (32s)
│  ├─ us-east → TIMEOUT ❌
│  └─ eu-west → SUCCESS ✅
└─ chat (3s) → eu-west ✅
```

---

## Demo Commands

### Trigger Failover
```bash
curl -X POST http://YOUR_IP:8000/demo/failover
```

### Check Health
```bash
curl http://YOUR_IP:8000/demo/health-status | jq
```

### View Logs
```bash
# ECS
aws logs tail /aws/ecs/rag-demo-backend --follow

# Lambda
aws logs tail /aws/lambda/rag-demo-embedder --follow
```

---

## Environment Variables (Already Configured)

### ECS & Lambda
```
LANGCHAIN_TRACING_V2=true
LANGCHAIN_API_KEY=<from SSM>
LANGCHAIN_PROJECT=rag-demo
LANGCHAIN_ENDPOINT=https://api.smith.langchain.com
```

---

## Files Modified

- ✅ `backend/requirements.txt` - Added langsmith
- ✅ `lambda/embedder/requirements.txt` - Added langsmith  
- ✅ `infrastructure/terraform/ecs.tf` - Added env vars
- ✅ `infrastructure/terraform/lambda.tf` - Added env vars
- ✅ `infrastructure/terraform/variables.tf` - Added variables
- ✅ `infrastructure/terraform/ssm.tf` - Added SSM parameter

---

## Next Steps

1. **Run setup script** with your API key
2. **Apply terraform** changes
3. **Redeploy** services
4. **Make test query**
5. **Open LangSmith** dashboard
6. **See your traces!** 🎉

---

## Support

- LangSmith Docs: https://docs.smith.langchain.com/
- LangSmith Dashboard: https://smith.langchain.com/
- Free Tier: 5,000 traces/month
- Pricing: https://www.langchain.com/pricing

---

**That's it! Full observability in 5 minutes.** ✨

