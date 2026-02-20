# LangSmith Integration Complete Guide

## Integration Summary

✅ **LangSmith is now integrated with:**
- **ECS Backend** (FastAPI application)
- **Embedder Lambda** (Document embedding)

Both components support **multi-region Azure OpenAI failover** AND **LangSmith tracing**!

---

## Failover Support Comparison

### ECS Backend - Full Sophisticated Failover ⭐⭐⭐⭐⭐

**Capabilities:**
- ✅ Automatic failover (us-east → eu-west)
- ✅ Health tracking across requests
- ✅ 60-second recovery retry
- ✅ Intelligent endpoint selection
- ✅ LangSmith traces every step

**How it works:**
1. Request comes in
2. Tries us-east first
3. If fails → **automatically** tries eu-west
4. Marks us-east as unhealthy
5. Future requests skip unhealthy us-east for 60 seconds
6. After 60s, retries us-east to check recovery
7. **Every step traced in LangSmith!**

**What LangSmith Shows:**
```
rag_query (35s, $0.0021)
├─ generate_embeddings (32s, $0.0001)
│  ├─ Attempt 1: Embedding (us-east) - FAILED (timeout)
│  └─ Attempt 2: Embedding (eu-west) - SUCCESS (2.3s)
│
└─ chat_completion (3s, $0.002)
   └─ Chat (eu-west) - SUCCESS (skipped unhealthy us-east)
```

You'll see **both the failure and the successful failover** in the trace!

---

### Embedder Lambda - Sequential Failover ⭐⭐⭐⭐

**Capabilities:**
- ✅ Automatic failover (us-east → eu-west)
- ✅ Sequential region attempts
- ✅ LangSmith traces each embedding
- ⚠️  No persistent health tracking (stateless lambda)

**How it works:**
1. Lambda triggered by SQS message
2. Tries to get Azure config from us-east SSM
3. If fails → **automatically** tries eu-west SSM
4. Uses whichever region is available
5. Generates embedding
6. Stores in Pinecone
7. **Traced in LangSmith!**

**What LangSmith Shows:**
```
embed_document_chunk (5s, $0.0001)
├─ load_config
│  ├─ Try us-east SSM - FAILED
│  └─ Try eu-west SSM - SUCCESS
│
├─ generate_embedding (2s)
│  └─ AzureOpenAI (eu-west) - SUCCESS
│
└─ store_pinecone (1s)
   └─ Vector stored successfully
```

**Difference from ECS:**
- Lambda is **stateless** - no memory between invocations
- Each invocation tries us-east first (no health tracking)
- Still works! Just less optimized than ECS

---

## Setup Instructions

### Step 1: Store Your LangSmith API Key in SSM

**Option A: Using the script (Recommended)**

```powershell
# PowerShell (Windows)
cd C:\Users\seeta\IdeaProjects\agentic-ai\scripts
.\setup-langsmith.ps1 -LangSmithApiKey "lsv2_pt_xxxxxxxxxxxxx"
```

```bash
# Bash (Linux/Mac)
cd scripts
./setup-langsmith.sh lsv2_pt_xxxxxxxxxxxxx
```

**Option B: Manually via AWS CLI**

```bash
aws ssm put-parameter \
  --name "/rag-demo/langsmith/api-key" \
  --value "lsv2_pt_xxxxxxxxxxxxx" \
  --type "SecureString" \
  --region us-east-1 \
  --overwrite
```

**Option C: Via AWS Console**

1. Go to AWS Console → Systems Manager → Parameter Store
2. Click "Create parameter"
3. Name: `/rag-demo/langsmith/api-key`
4. Type: `SecureString`
5. Value: Your LangSmith API key
6. Click "Create parameter"

---

### Step 2: Deploy Infrastructure

```bash
cd infrastructure/terraform
terraform init
terraform apply
```

This will:
- Update ECS task definition with LangSmith env vars
- Update Lambda function with LangSmith env vars
- Create/update SSM parameters

---

### Step 3: Redeploy Services

**Backend (ECS):**
```bash
# Force new deployment to pick up new environment variables
aws ecs update-service \
  --cluster rag-demo \
  --service backend \
  --force-new-deployment \
  --region us-east-1
```

**Lambda (Embedder):**
```bash
# Trigger GitHub Actions workflow or manually:
cd lambda/embedder
zip -r embedder.zip .
aws lambda update-function-code \
  --function-name rag-demo-embedder \
  --zip-file fileb://embedder.zip \
  --region us-east-1
```

---

### Step 4: Test and View Traces

**Make a test query:**
```bash
curl -X POST http://YOUR_ECS_IP:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What is machine learning?"}'
```

**View in LangSmith:**
1. Go to https://smith.langchain.com/
2. Select project: `rag-demo`
3. Click "Traces" tab
4. See your query trace!

---

## What You'll See in LangSmith

### Normal Operation (Both Regions Healthy)

**Backend Query Trace:**
```
rag_query (6.2s, $0.0021)
├─ generate_embeddings (2.3s, $0.0001)
│  ├─ Input: "What is machine learning?"
│  ├─ Provider: Embedding (us-east)
│  ├─ Model: text-embedding-3-small
│  └─ Output: [0.05, -0.12, ...] (1536 dims)
│
├─ vector_store.query (0.5s)
│  ├─ Pinecone query
│  └─ Found 5 documents
│
└─ chat_completion (3.4s, $0.002)
   ├─ Provider: Chat (us-east)
   ├─ Model: gpt-4
   └─ Response: "Machine learning is..."
```

**Lambda Embedding Trace:**
```
lambda_handler (5s, $0.0001)
├─ get_azure_config
│  └─ Loaded from us-east SSM
│
├─ generate_embedding (2s)
│  ├─ Provider: Embedding (us-east)
│  └─ Model: text-embedding-3-small
│
└─ store_pinecone (1s)
   └─ Vector ID: doc123_0
```

---

### During Failover (US-East Down)

**Backend Query Trace:**
```
rag_query (35s, $0.0021)
├─ generate_embeddings (32s, $0.0001)
│  ├─ Attempt 1: Embedding (us-east)
│  │  └─ ERROR: Connection timeout (30s)
│  │
│  └─ Attempt 2: Embedding (eu-west)  ← AUTOMATIC FAILOVER
│     └─ SUCCESS (2s)
│
└─ chat_completion (3s, $0.002)
   └─ Chat (eu-west) - SUCCESS
      (Skipped unhealthy us-east)
```

**Lambda Embedding Trace:**
```
lambda_handler (5s, $0.0001)
├─ get_azure_config
│  ├─ Try us-east SSM - FAILED
│  └─ Try eu-west SSM - SUCCESS  ← AUTOMATIC FAILOVER
│
├─ generate_embedding (2s)
│  ├─ Provider: Embedding (eu-west)
│  └─ SUCCESS
│
└─ store_pinecone (1s)
   └─ SUCCESS
```

**You can clearly see the failover happening!** ✅

---

## Key Differences: ECS vs Lambda Failover

| Feature | ECS Backend | Embedder Lambda |
|---------|-------------|-----------------|
| **Failover Type** | Sophisticated | Sequential |
| **Health Tracking** | ✅ Yes (in-memory) | ❌ No (stateless) |
| **Recovery Retry** | ✅ After 60s | ❌ Tries us-east every time |
| **Optimization** | ✅ Skips known-bad endpoints | ⚠️  Always tries us-east first |
| **Failover Speed** | ⭐⭐⭐⭐⭐ Fast (after first failure) | ⭐⭐⭐ OK (retries each time) |
| **LangSmith Tracing** | ✅ Yes | ✅ Yes |
| **Complexity** | High | Low |
| **Best For** | Real-time queries | Background processing |

---

## Why Lambda Doesn't Have Persistent Health Tracking

**Lambda is stateless:**
- Each invocation is isolated
- No shared memory between invocations
- Can't remember that us-east failed

**Workaround options:**
1. **DynamoDB health table** (adds complexity + cost)
2. **Accept sequential failover** (simpler, works fine) ✅

**Current implementation: Sequential failover**
- Simple and reliable
- No extra infrastructure needed
- Slight overhead (tries us-east each time)
- Still fast enough for background processing

---

## Demonstration Ideas

### Demo 1: Show Normal LangSmith Trace
1. Make a query
2. Open LangSmith
3. Show clean trace with us-east

### Demo 2: Show Failover in LangSmith
1. Trigger failover: `curl -X POST http://IP:8000/demo/failover`
2. Make a query
3. Open LangSmith
4. Show trace with:
   - Failed us-east attempt
   - Successful eu-west attempt
   - Total time comparison

### Demo 3: Compare Costs
1. Make 10 queries
2. Go to LangSmith → Monitoring
3. Show cost breakdown:
   - Embedding costs
   - Chat completion costs
   - Total per query

### Demo 4: Debug a Query
1. Find a query with unexpected results
2. Open trace in LangSmith
3. Inspect:
   - What documents were retrieved?
   - What was the prompt?
   - What was the response?
4. Identify issue and fix

---

## Environment Variables Summary

### ECS Backend
```bash
LANGCHAIN_TRACING_V2=true
LANGCHAIN_API_KEY=<from SSM: /rag-demo/langsmith/api-key>
LANGCHAIN_PROJECT=rag-demo
LANGCHAIN_ENDPOINT=https://api.smith.langchain.com
```

### Embedder Lambda
```bash
LANGCHAIN_TRACING_V2=true
LANGCHAIN_API_KEY=<from SSM: /rag-demo/langsmith/api-key>
LANGCHAIN_PROJECT=rag-demo
LANGCHAIN_ENDPOINT=https://api.smith.langchain.com
```

**Both get the same environment variables!**

---

## Verification Checklist

After deployment, verify:

- [ ] SSM parameter exists: `/rag-demo/langsmith/api-key`
- [ ] ECS task definition has LangSmith env vars
- [ ] Lambda function has LangSmith env vars
- [ ] Make a test query
- [ ] Check LangSmith dashboard - trace appears
- [ ] Trigger failover
- [ ] Make another query
- [ ] Check LangSmith - see failover in trace

---

## Troubleshooting

### Traces not appearing in LangSmith

**Check:**
1. API key is correct in SSM
2. Environment variable `LANGCHAIN_TRACING_V2=true`
3. Network connectivity from ECS/Lambda to LangSmith API
4. CloudWatch logs for errors

**Test locally:**
```bash
export LANGCHAIN_TRACING_V2=true
export LANGCHAIN_API_KEY=lsv2_pt_xxxxx
export LANGCHAIN_PROJECT=rag-demo

# Make a query - should appear in LangSmith
```

### Lambda traces not showing failover

**This is normal!** Lambda chooses region at startup:
- If us-east SSM available → uses us-east
- If us-east SSM fails → uses eu-west
- No "retry" visible in single trace

**To see failover in Lambda:**
1. Remove us-east SSM parameters
2. Lambda will use eu-west
3. Trace will show eu-west as primary

---

## Summary

✅ **Both ECS and Lambda support failover**
✅ **Both are traced in LangSmith**
✅ **ECS has more sophisticated failover** (health tracking)
✅ **Lambda has simpler failover** (sequential, stateless)
✅ **Both work reliably** for their use cases

**For your presentation:**
- Show ECS failover (more impressive!)
- Mention Lambda also has failover
- LangSmith makes it all visible!

🎉 **You now have full observability with resilience!**

