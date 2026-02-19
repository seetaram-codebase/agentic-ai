# Quick Start: LangSmith Integration for RAG Observability

## What is LangSmith?

**LangSmith** is LangChain's official observability platform that:
- ✅ Automatically traces all LangChain operations
- ✅ Shows exact prompts and responses
- ✅ Tracks costs and latencies
- ✅ Debugs why specific documents were retrieved
- ✅ Perfect for your RAG system (you're using LangChain!)

## 5-Minute Setup

### Step 1: Sign Up (2 minutes)

1. Go to https://smith.langchain.com/
2. Sign up with GitHub/Google/Email
3. Verify email
4. Create organization: `rag-demo`

### Step 2: Get API Key (1 minute)

1. Click on your profile (top right)
2. Settings → API Keys
3. Create new API key: `rag-demo-key`
4. Copy the key (starts with `lsv2_...`)

### Step 3: Configure Backend (2 minutes)

Add to `backend/.env`:

```bash
# LangSmith Configuration
LANGCHAIN_TRACING_V2=true
LANGCHAIN_API_KEY=lsv2_pt_xxxxxxxxxxxxx  # Your API key
LANGCHAIN_PROJECT=rag-demo
LANGCHAIN_ENDPOINT=https://api.smith.langchain.com
```

**For ECS deployment**, add to Terraform or update task definition:

```hcl
# infrastructure/terraform/ecs.tf
environment = [
  # ...existing variables...
  { name = "LANGCHAIN_TRACING_V2", value = "true" },
  { name = "LANGCHAIN_API_KEY", value = var.langsmith_api_key },
  { name = "LANGCHAIN_PROJECT", value = "rag-demo" },
  { name = "LANGCHAIN_ENDPOINT", value = "https://api.smith.langchain.com" }
]
```

### Step 4: Install SDK (if not already installed)

```bash
cd backend
pip install langsmith
```

Update `backend/requirements.txt`:
```
langsmith==0.1.0
```

### Step 5: Test It!

```bash
# Run backend locally or use deployed ECS
# Make a query
curl -X POST http://YOUR_IP:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What is machine learning?"}'
```

Go to https://smith.langchain.com/ → You'll see the trace! 🎉

---

## What You'll See in LangSmith

### Trace View:

```
rag_query (6.2s, $0.0021)
├─ generate_embeddings (2.3s, $0.0001)
│  ├─ Input: "What is machine learning?"
│  ├─ Model: text-embedding-3-small
│  ├─ Provider: Embedding (us-east)
│  ├─ Tokens: 5
│  └─ Output: [0.05, -0.12, 0.08, ...] (1536 dims)
│
├─ vector_store.query (0.5s, $0)
│  ├─ Query embedding: [0.05, -0.12, ...]
│  ├─ Top K: 5
│  ├─ Results: 5 documents found
│  └─ Scores: [0.89, 0.85, 0.82, 0.78, 0.75]
│
└─ chat_completion (3.4s, $0.002)
   ├─ Model: gpt-4
   ├─ Provider: Chat (us-east)
   ├─ System Prompt: "You are a helpful assistant..."
   ├─ User Prompt: "Context: [...]\nQuestion: What is ML?"
   ├─ Tokens: 450 input, 150 output
   └─ Response: "Machine learning is a subset of..."

Total Cost: $0.0021
Total Time: 6.2s
```

---

## Enhanced Integration (Optional)

### Add Custom Metadata to Traces:

```python
# backend/app/rag_engine.py
from langsmith import traceable
from langsmith.run_helpers import get_current_run_tree

class RAGEngine:
    
    @traceable(
        name="rag_query",
        run_type="chain",
        tags=["production", "rag"]
    )
    def query(self, question: str, n_results: int = 5) -> QueryResult:
        """Query with enhanced LangSmith tracing"""
        
        # Add metadata to trace
        run_tree = get_current_run_tree()
        if run_tree:
            run_tree.extra = {
                "n_results": n_results,
                "question_length": len(question),
                "user_id": "demo-user"  # Add if you track users
            }
        
        # Generate query embedding
        query_embeddings, embed_provider = self.azure_client.generate_embeddings([question])
        
        # Retrieve documents
        results = self.vector_store.query(
            query_embedding=query_embeddings[0],
            n_results=n_results
        )
        
        # Add retrieved docs to trace
        if run_tree:
            run_tree.outputs = {
                "documents_found": len(results.get("documents", [])),
                "top_score": max(results.get("distances", [0])) if results.get("distances") else 0
            }
        
        # Generate response
        # ...existing code...
        
        return result
```

### Track Failover Events:

```python
# backend/app/azure_openai.py
from langsmith import traceable

@traceable(name="azure_openai_failover", run_type="llm")
def chat_completion(self, messages, **kwargs):
    """Chat completion with failover tracking"""
    
    for attempt in range(len(self.configs)):
        index = (self.current_index + attempt) % len(self.configs)
        config = self.configs[index]
        
        try:
            # Log attempt
            logger.info(f"Attempting {config.name}")
            
            response = client.chat.completions.create(
                model=config.deployment,
                messages=messages,
                **kwargs
            )
            
            # Success - log to LangSmith
            return content, config.name
            
        except Exception as e:
            # Failure - logged automatically by LangSmith
            logger.error(f"Failed {config.name}: {e}")
            if attempt < len(self.configs) - 1:
                logger.info(f"Failing over to next region...")
            continue
```

---

## Demonstration Scripts

### Script 1: Show Normal Operation

```bash
#!/bin/bash
# demo-normal.sh

echo "=== Normal Operation Demo ==="
echo ""
echo "1. Making query to RAG system..."
echo ""

curl -X POST http://YOUR_IP:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What is machine learning?"}' | jq

echo ""
echo "2. Check LangSmith: https://smith.langchain.com/"
echo "   - See full trace"
echo "   - Provider: Chat (us-east)"
echo "   - Latency: ~3-5 seconds"
echo "   - Cost: ~$0.002"
```

### Script 2: Trigger and Show Failover

```bash
#!/bin/bash
# demo-failover.sh

echo "=== Failover Demonstration ==="
echo ""
echo "Step 1: Check current status"
curl http://YOUR_IP:8000/demo/health-status | jq '.azure_openai.current_provider'

echo ""
echo "Step 2: Trigger failover (simulates us-east failure)"
curl -X POST http://YOUR_IP:8000/demo/failover | jq

echo ""
echo "Step 3: Make a query (will use eu-west)"
curl -X POST http://YOUR_IP:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "Explain deep learning"}' | jq '.provider'

echo ""
echo "Step 4: Check LangSmith trace"
echo "   - Go to: https://smith.langchain.com/"
echo "   - Latest trace shows: Provider = 'Chat (eu-west)'"
echo "   - Timeline shows failover event"
```

### Script 3: Show Cost Tracking

```python
# demo-cost-tracking.py
import requests
from datetime import datetime, timedelta

# Make 10 queries
questions = [
    "What is machine learning?",
    "Explain neural networks",
    "What is deep learning?",
    # ... add more
]

print("Making 10 queries to track costs...")
for q in questions:
    resp = requests.post(
        "http://YOUR_IP:8000/query",
        json={"question": q}
    )
    print(f"✓ {q[:30]}... - {resp.json()['provider']}")

print("\nCheck LangSmith:")
print("1. Go to https://smith.langchain.com/")
print("2. Click 'Monitoring' tab")
print("3. View total cost, queries per provider")
print("4. See latency distribution (P50, P95, P99)")
```

---

## LangSmith Dashboard Features

### 1. Traces Tab
**What it shows:**
- Every query with full trace
- Input/output at each step
- Latency breakdown
- Error stack traces

**Demo use:**
- Show end-to-end RAG flow
- Highlight embedding → search → generation
- Show failover in action

### 2. Playground Tab
**What it shows:**
- Test different prompts
- Compare prompt variations
- A/B test system prompts

**Demo use:**
- Show how changing system prompt affects responses
- Test different retrieval strategies

### 3. Datasets & Testing Tab
**What it shows:**
- Create test question sets
- Run automated evaluations
- Track quality metrics

**Demo use:**
- Show regression testing
- Demonstrate quality monitoring

### 4. Monitoring Tab
**What it shows:**
- Request volume over time
- Latency percentiles (P50, P95, P99)
- Error rates
- Cost per query
- Provider distribution

**Demo use:**
- Show real-time metrics
- Highlight us-east vs eu-west distribution
- Show cost optimization

---

## Alternative: Simple Custom Dashboard

If you prefer a custom solution:

```python
# backend/app/dashboard.py
from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from datetime import datetime
import json

router = APIRouter()

# In-memory metrics (replace with Redis/DB in production)
traces = []

@router.middleware("http")
async def track_requests(request, call_next):
    """Track all requests"""
    if request.url.path == "/query":
        start = time.time()
        response = await call_next(request)
        latency = time.time() - start
        
        traces.append({
            'timestamp': datetime.now().isoformat(),
            'path': request.url.path,
            'latency': latency,
            'status': response.status_code
        })
        
        return response
    return await call_next(request)

@router.get("/dashboard", response_class=HTMLResponse)
async def dashboard():
    """Simple observability dashboard"""
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>RAG System Dashboard</title>
        <meta http-equiv="refresh" content="5">
        <style>
            body {{ font-family: Arial; margin: 40px; }}
            .metric {{ background: #f0f0f0; padding: 20px; margin: 10px 0; }}
            .healthy {{ color: green; }}
            .unhealthy {{ color: red; }}
        </style>
    </head>
    <body>
        <h1>🔍 RAG System Dashboard</h1>
        
        <div class="metric">
            <h2>Recent Requests</h2>
            <p>Total: {len(traces)}</p>
            <p>Avg Latency: {sum(t['latency'] for t in traces) / len(traces) if traces else 0:.2f}s</p>
        </div>
        
        <div class="metric">
            <h2>Latest Traces</h2>
            <ul>
                {' '.join(f"<li>{t['timestamp']}: {t['latency']:.2f}s</li>" for t in traces[-10:])}
            </ul>
        </div>
        
        <div class="metric">
            <h2>Health Status</h2>
            <p>Check: <a href="/demo/health-status">/demo/health-status</a></p>
        </div>
    </body>
    </html>
    """
    return html

# Add to main.py
from app.dashboard import router as dashboard_router
app.include_router(dashboard_router)
```

Access at: `http://YOUR_IP:8000/dashboard`

---

## Summary

### Recommended Setup:

**For Demo/Presentation:** ⭐ **LangSmith**
- Easiest setup (5 minutes)
- Beautiful UI
- Automatic tracing
- Perfect for showing RAG pipeline
- Free tier sufficient for demo

**For Production:** Both LangSmith + CloudWatch
- LangSmith: Application-level tracing
- CloudWatch: Infrastructure monitoring

### Quick Win:

1. Add 4 environment variables
2. Make a query
3. View trace in LangSmith
4. Show to audience - looks professional! 🎉

**No code changes needed - LangSmith auto-traces LangChain!**

