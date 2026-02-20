# LangSmith Integration - Zero Code Changes! ✅

## Summary

**Good news:** LangSmith automatically instruments the OpenAI Python SDK when environment variables are set. **No code changes needed!**

## How It Works

When these environment variables are set, LangSmith automatically:
- Traces all `client.chat.completions.create()` calls
- Traces all `client.embeddings.create()` calls
- Records latency, tokens, costs
- Captures inputs/outputs
- Shows failover events

## Environment Variables (Already Configured)

In `infrastructure/terraform/ecs.tf`:

```hcl
environment = [
  { name = "LANGCHAIN_TRACING_V2", value = "true" },
  { name = "LANGCHAIN_PROJECT", value = "rag-demo" },
  { name = "LANGCHAIN_ENDPOINT", value = "https://api.smith.langchain.com" }
]

secrets = [
  {
    name      = "LANGCHAIN_API_KEY"
    valueFrom = aws_ssm_parameter.langsmith_api_key.arn
  }
]
```

## What Gets Traced Automatically

### 1. Chat Completions
```python
# This code in azure_openai.py:
response = client.chat.completions.create(
    model=config.deployment,
    messages=messages,
    timeout=30
)
```
**Automatically traced** → Shows up in LangSmith as:
- Model: `gpt-4`
- Provider: `Chat (us-east)` or `Chat (eu-west)`
- Input: messages
- Output: response
- Latency: X seconds
- Cost: $X.XX

### 2. Embeddings
```python
# This code in azure_openai.py:
response = client.embeddings.create(
    input=texts,
    model=deployment,
    timeout=30
)
```
**Automatically traced** → Shows up in LangSmith as:
- Model: `text-embedding-3-small`
- Provider: `Embedding (us-east)` or `Embedding (eu-west)`
- Input: text chunks
- Output: embedding vectors
- Latency: X seconds
- Cost: $X.XX

## Deploy Steps

### 1. Fix IAM Permissions (Required)
```bash
cd infrastructure/terraform
terraform apply
```

This adds SSM permissions to ECS task execution role.

### 2. Verify LangSmith API Key
```bash
aws ssm get-parameter \
  --name "/rag-demo/langsmith/api-key" \
  --with-decryption \
  --region us-east-1
```

Should show your `lsv2_pt_xxxxx` key.

### 3. ECS Auto-Restarts
Once Terraform applies, ECS will:
- Pick up new environment variables
- Start tracing automatically
- No manual restart needed

### 4. Test
```bash
# Make a query
curl -X POST http://YOUR_ECS_IP:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What is machine learning?"}'
```

### 5. View Traces
Go to: https://smith.langchain.com/
- Select project: `rag-demo`
- See traces appear!

## What You'll See in LangSmith

### Trace Example:
```
rag_query (6.5s)
├─ azure_openai.generate_embeddings (2.1s)
│  ├─ Model: text-embedding-3-small
│  ├─ Provider: Embedding (us-east)
│  ├─ Input: "What is machine learning?"
│  ├─ Output: [0.05, -0.12, ...] (1536 dims)
│  └─ Cost: $0.0001
│
├─ pinecone.query (0.4s)
│  └─ Found 5 documents
│
└─ azure_openai.chat_completion (4.0s)
   ├─ Model: gpt-4
   ├─ Provider: Chat (us-east)
   ├─ Input: system + user messages
   ├─ Output: "Machine learning is..."
   └─ Cost: $0.002

Total: $0.0021, 6.5 seconds
```

## Failover Visibility

When failover happens, you'll see:

```
rag_query (35s)
├─ azure_openai.generate_embeddings (32s)
│  ├─ Attempt 1: Embedding (us-east) - TIMEOUT ❌
│  └─ Attempt 2: Embedding (eu-west) - SUCCESS ✅
│
└─ azure_openai.chat_completion (3s)
   └─ Chat (eu-west) - SUCCESS ✅
```

Each SDK call is automatically traced, showing both failed and successful attempts!

## Why This Works

LangSmith's Python SDK includes **automatic instrumentation** for:
- OpenAI SDK
- Azure OpenAI (uses OpenAI SDK)
- LangChain components

When `LANGCHAIN_TRACING_V2=true`:
1. LangSmith patches the OpenAI SDK
2. Intercepts all API calls
3. Sends traces to LangSmith API
4. **No code changes needed!**

## Optional: Add High-Level Tracing

If you want to trace the **entire RAG pipeline** (not just Azure calls), add this to `rag_engine.py`:

```python
from langsmith import traceable

@traceable(name="rag_query", run_type="chain")
def query(self, question: str, n_results: int = 5):
    # ...existing code...
```

But for Azure OpenAI calls, **environment variables alone are sufficient!**

## Troubleshooting

### No traces appearing?

1. **Check environment variables:**
   ```bash
   aws ecs describe-task-definition \
     --task-definition rag-demo-backend \
     --query 'taskDefinition.containerDefinitions[0].environment' \
     --region us-east-1
   ```

2. **Check API key:**
   ```bash
   aws ssm get-parameter \
     --name "/rag-demo/langsmith/api-key" \
     --with-decryption \
     --region us-east-1
   ```

3. **Check logs:**
   ```bash
   aws logs tail /aws/ecs/rag-demo-backend --follow
   ```

   Should see:
   ```
   INFO - LangSmith tracing enabled
   ```

4. **Verify project name matches:**
   - Environment: `LANGCHAIN_PROJECT=rag-demo`
   - LangSmith: Project must be `rag-demo`

### Still no traces?

LangSmith requires:
- Valid API key
- Network access to `https://api.smith.langchain.com`
- `langsmith` package installed (already in requirements.txt)

## Summary

✅ **Environment variables configured** in Terraform  
✅ **IAM permissions fixed** for SSM access  
✅ **LangSmith automatically instruments** OpenAI SDK  
✅ **No code changes needed** in azure_openai.py  
✅ **Just deploy and test!**

**Next:** Run `terraform apply` and traces will appear automatically! 🎉

