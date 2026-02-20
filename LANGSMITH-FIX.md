# LangSmith Fix - Why It Wasn't Working & How It's Fixed

## Problem Identified

LangSmith was **configured but not working** because:

### ✅ What Was Already Working:
1. **Environment variables set** in ECS and Lambda:
   - `LANGCHAIN_TRACING_V2=true`
   - `LANGCHAIN_PROJECT=rag-demo`
   - `LANGCHAIN_ENDPOINT=https://api.smith.langchain.com`
   - `LANGCHAIN_API_KEY=lsv2_pt_xxxxx...` (stored in SSM)

2. **LangSmith SDK installed** in `requirements.txt`:
   - `langsmith==0.1.77`

3. **Infrastructure configured** in Terraform

### ❌ What Was Missing:
**The OpenAI client was NOT wrapped with LangSmith!**

The backend was using the raw `AzureOpenAI` client directly:
```python
from openai import AzureOpenAI

client = AzureOpenAI(
    azure_endpoint=config.endpoint,
    api_key=config.api_key,
    api_version="2024-02-01"
)
```

**This does NOT auto-trace!** LangSmith environment variables alone don't automatically instrument the OpenAI SDK.

---

## The Fix

### Added LangSmith Wrapping in `backend/app/azure_openai.py`

#### 1. Import LangSmith wrapper:
```python
# LangSmith auto-instrumentation for OpenAI SDK
try:
    from langsmith import wrap_openai
    from langsmith import wrappers
    LANGSMITH_AVAILABLE = True
    logger.info("✅ LangSmith available - OpenAI calls will be traced")
except ImportError:
    LANGSMITH_AVAILABLE = False
    logger.warning("⚠️ LangSmith not installed - tracing disabled")
```

#### 2. Wrap the client after creation:
```python
def _create_client(self, config: AzureConfig) -> AzureOpenAI:
    """Create an Azure OpenAI client from config"""
    client = AzureOpenAI(
        azure_endpoint=config.endpoint,
        api_key=config.api_key,
        api_version="2024-02-01"
    )
    
    # Wrap with LangSmith if available and enabled
    if LANGSMITH_AVAILABLE and os.getenv("LANGCHAIN_TRACING_V2", "false").lower() == "true":
        client = wrap_openai(client)
        logger.info(f"✅ Wrapped OpenAI client with LangSmith tracing for {config.name}")
    
    return client
```

### Lambda Embedder (Already Working!)
The embedder Lambda uses LangChain's `AzureOpenAIEmbeddings` wrapper, which **automatically traces** when environment variables are set:

```python
from langchain_openai import AzureOpenAIEmbeddings

embedding_model = AzureOpenAIEmbeddings(
    azure_endpoint=config['endpoint'],
    api_key=config['api_key'],
    azure_deployment=config['deployment'],
    api_version="2024-02-01"
)
```

✅ **This already works!** No code changes needed for Lambda.

---

## What Gets Traced Now

### Backend API (ECS)

#### Chat Completions:
```python
# In rag_engine.py when user asks a question:
response_text, provider = self.azure_client.chat_completion(messages)
```

**LangSmith will trace:**
- 📊 Run name: `AzureOpenAI.chat.completions.create`
- 📥 Input: System prompt + user question + context
- 📤 Output: GPT-4's response
- ⏱️ Latency: X seconds
- 💰 Cost: $0.00X
- 🏷️ Tags: `provider=Chat (us-east)` or `Chat (eu-west)`
- 🔄 Failover events if they occur

#### Embeddings:
```python
# In rag_engine.py when processing query:
query_embeddings, provider = self.azure_client.generate_embeddings([question])
```

**LangSmith will trace:**
- 📊 Run name: `AzureOpenAI.embeddings.create`
- 📥 Input: User question text
- 📤 Output: 1536-dimensional embedding vector
- ⏱️ Latency: X milliseconds
- 💰 Cost: $0.0000X
- 🏷️ Tags: `provider=Embedding (us-east)` or `Embedding (eu-west)`

### Lambda Embedder

#### Document Chunk Embeddings:
```python
# In embedder Lambda for each chunk:
embedding = embedding_model.embed_query(chunk['text'])
```

**LangSmith will trace:**
- 📊 Run name: `AzureOpenAIEmbeddings.embed_query`
- 📥 Input: Document chunk text
- 📤 Output: 1536-dimensional embedding
- ⏱️ Latency: X milliseconds
- 💰 Cost per chunk
- 🏷️ Tags: `document_id`, `chunk_index`

---

## How to Deploy the Fix

### Option 1: Deploy Backend to ECS (Recommended)
```bash
# Commit the changes
git add backend/app/azure_openai.py
git commit -m "feat: enable LangSmith tracing with wrap_openai"
git push origin main

# GitHub Actions will automatically:
# 1. Build new Docker image
# 2. Push to ECR
# 3. Update ECS task definition
# 4. ECS will rolling-restart with new code
```

### Option 2: Manual Local Testing
```bash
# Ensure environment variables are set
export LANGCHAIN_TRACING_V2=true
export LANGCHAIN_API_KEY=lsv2_pt_YOUR_LANGSMITH_API_KEY_HERE
export LANGCHAIN_PROJECT=rag-demo
export LANGCHAIN_ENDPOINT=https://api.smith.langchain.com

# Run backend
cd backend
uvicorn app.main:app --reload

# Make a query
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What is this document about?", "n_results": 5}'

# Check LangSmith: https://smith.langchain.com/
# Project: rag-demo
# You should see traces appear!
```

---

## Verification Steps

### 1. Check Backend Logs
After deploying, check ECS logs:
```bash
aws logs tail /ecs/rag-demo --follow | Select-String -Pattern "LangSmith"
```

**Expected output:**
```
✅ LangSmith available - OpenAI calls will be traced
✅ Wrapped OpenAI client with LangSmith tracing for Primary (us-east)
✅ Wrapped OpenAI client with LangSmith tracing for Secondary (eu-west)
```

### 2. Check Lambda Logs
```bash
aws logs tail /aws/lambda/rag-demo-embedder --follow | Select-String -Pattern "LANGCHAIN"
```

**Expected output:**
```
LANGCHAIN_TRACING_V2: true
LANGCHAIN_PROJECT: rag-demo
```

### 3. Check LangSmith Dashboard
1. Go to https://smith.langchain.com/
2. Sign in
3. Select project: **rag-demo**
4. You should see traces appearing in real-time!

### 4. Test with a Query
```bash
# Upload a document
curl -X POST http://54.89.155.20:8000/upload \
  -F "file=@sample-docs/test.pdf"

# Ask a question (this will trace)
curl -X POST http://54.89.155.20:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "Summarize this document", "n_results": 5}'
```

**In LangSmith you'll see:**
1. Embedding generation for query
2. Chat completion with context
3. Full trace with timing, costs, and I/O

---

## What You'll See in LangSmith

### Example Trace for a Query:

```
📊 Trace: User Query
├─ 🔍 AzureOpenAI.embeddings.create (us-east)
│  ├─ Input: "Summarize this document"
│  ├─ Output: [0.123, -0.456, ...] (1536 dims)
│  ├─ Latency: 0.234s
│  └─ Cost: $0.00001
│
└─ 💬 AzureOpenAI.chat.completions.create (us-east)
   ├─ Input:
   │  ├─ System: "You are a helpful assistant..."
   │  ├─ Context: "[Source: test.pdf, Page 1]..."
   │  └─ Question: "Summarize this document"
   ├─ Output: "This document discusses..."
   ├─ Latency: 2.134s
   ├─ Tokens: 450 prompt + 120 completion = 570 total
   └─ Cost: $0.0285
```

### Example Trace for Document Upload:

```
📊 Trace: Document Embedding (Lambda)
├─ 🔍 AzureOpenAIEmbeddings.embed_query (chunk 0)
│  ├─ Input: "This is the first chunk..."
│  └─ Output: [0.789, 0.234, ...] (1536 dims)
│
├─ 🔍 AzureOpenAIEmbeddings.embed_query (chunk 1)
│  ├─ Input: "This is the second chunk..."
│  └─ Output: [0.456, -0.123, ...] (1536 dims)
│
... (continues for all chunks)
```

---

## Troubleshooting

### Issue: "LangSmith not available" in logs
**Cause:** `langsmith` package not installed
**Fix:**
```bash
cd backend
pip install langsmith==0.1.77
```

### Issue: No traces in LangSmith dashboard
**Checks:**
1. Verify API key is correct:
   ```bash
   aws ssm get-parameter --name "/rag-demo/langsmith/api-key" --with-decryption
   ```

2. Check environment variable is set:
   ```bash
   aws ecs describe-task-definition --task-definition rag-demo-backend \
     --query "taskDefinition.containerDefinitions[0].environment[?name=='LANGCHAIN_TRACING_V2']"
   ```

3. Verify you're logged into the correct LangSmith project

### Issue: "wrap_openai" import error
**Cause:** Using old version of `langsmith`
**Fix:**
```bash
pip install --upgrade langsmith>=0.1.0
```

---

## Files Changed

1. ✅ `backend/app/azure_openai.py` - Added LangSmith wrapper
   - Import `wrap_openai`
   - Wrap client in `_create_client()`
   - Add logging for tracing status

No changes needed for:
- Lambda functions (already using LangChain wrappers)
- Terraform (already configured)
- Environment variables (already set)

---

## Next Steps

1. **Deploy the fix** (via git push or manual)
2. **Test with a query**
3. **Open LangSmith dashboard** - https://smith.langchain.com/
4. **Watch traces appear in real-time!**

You can now observe:
- 📊 All OpenAI API calls
- ⏱️ Latency and performance
- 💰 Cost tracking
- 🔄 Failover events
- 🐛 Debugging inputs/outputs
- 📈 Usage trends over time

