# Observability Tools for RAG System

## Quick Answer: YES - Multiple Options Available!

### Recommended Observability Tools:

1. **LangSmith** ✅ (LangChain official - BEST for your use case)
2. **AWS CloudWatch** ✅ (Already integrated)
3. **Pinecone Console** ✅ (Already available)
4. **Azure Monitor** ✅ (For Azure OpenAI)
5. **Custom Dashboard** (Build your own)

---

## 1. LangSmith - Recommended! 🎯

**Why LangSmith is Perfect for Your System:**
- ✅ Designed specifically for LangChain applications (you use LangChain)
- ✅ Traces embedding generation and RAG queries
- ✅ Shows exact prompts sent to Azure OpenAI
- ✅ Tracks costs per request
- ✅ Debugs why certain documents were retrieved
- ✅ Visualizes the complete RAG pipeline

### What LangSmith Shows:

```
Query: "What is machine learning?"
├─ Embedding Generation (2.3s, $0.0001)
│  ├─ Input: "What is machine learning?"
│  └─ Output: [0.05, -0.12, ...] (1536 dims)
├─ Vector Search (0.5s, free)
│  ├─ Top 5 matches found
│  └─ Scores: [0.89, 0.85, 0.82, 0.78, 0.75]
└─ Chat Completion (3.2s, $0.002)
   ├─ Prompt: "Context: [docs]\nQuestion: What is ML?"
   ├─ Tokens: 450 input, 150 output
   └─ Response: "Machine learning is..."

Total: 6.0s, $0.0021
```

### Integration Steps:

#### Step 1: Sign Up for LangSmith

1. Go to https://smith.langchain.com/
2. Sign up (free tier available)
3. Create a project: `rag-demo`
4. Get API key from settings

#### Step 2: Install LangSmith SDK

Add to `backend/requirements.txt`:
```python
langsmith==0.1.0
```

#### Step 3: Configure Environment Variables

Add to your ECS task definition and local environment:
```bash
LANGCHAIN_TRACING_V2=true
LANGCHAIN_API_KEY=your-langsmith-api-key
LANGCHAIN_PROJECT=rag-demo
LANGCHAIN_ENDPOINT=https://api.smith.langchain.com
```

#### Step 4: Update Code (Automatic Tracing)

LangSmith automatically traces LangChain operations! You're already using:
- `AzureOpenAIEmbeddings` ✅
- LangChain text splitters ✅

Just add the env vars and it works!

**For explicit tracing:**

```python
# backend/app/rag_engine.py
from langsmith import traceable

@traceable(name="rag_query", run_type="chain")
def query(self, question: str, n_results: int = 5):
    """Query with LangSmith tracing"""
    
    # This entire method is now traced!
    # LangSmith will show:
    # - Embedding generation
    # - Vector search
    # - Context retrieval
    # - Final response generation
    
    # ...existing code...
```

#### Step 5: View Traces

1. Go to https://smith.langchain.com/
2. Select project: `rag-demo`
3. See all queries, traces, and performance metrics

### LangSmith Dashboard Features:

**Traces View:**
- See every API call in the RAG pipeline
- Input/output at each step
- Latency breakdown
- Token usage and costs

**Playground:**
- Test different prompts
- Compare responses
- Optimize system prompts

**Datasets:**
- Create test datasets
- Run evaluations
- Track quality over time

**Monitoring:**
- Real-time metrics
- Error rates
- P95/P99 latencies
- Cost per query

---

## 2. AWS CloudWatch - Already Integrated ✅

**What You Already Have:**

### Backend Logs:
```bash
# View ECS backend logs
aws logs tail /aws/ecs/rag-demo-backend --follow
```

**Shows:**
```
2026-02-19 10:30:15 Processing query: What is machine learning?
2026-02-19 10:30:15 Attempting chat with Chat (us-east)
2026-02-19 10:30:18 ✅ Success with Chat (us-east)
```

### Lambda Logs:
```bash
# Chunker lambda
aws logs tail /aws/lambda/rag-demo-chunker --follow

# Embedder lambda
aws logs tail /aws/lambda/rag-demo-embedder --follow
```

### CloudWatch Insights Queries:

**Query: Find Slow Requests**
```sql
fields @timestamp, @message
| filter @message like /Processing query/
| filter @message like /Success/
| stats count() by bin(30s)
```

**Query: Track Failover Events**
```sql
fields @timestamp, @message
| filter @message like /Marked .* as unhealthy/
| stats count() by bin(1h)
```

**Query: Embedding Errors**
```sql
fields @timestamp, @message
| filter @message like /Error storing in Pinecone/
| stats count() by bin(5m)
```

### CloudWatch Metrics (Custom):

Add custom metrics to track:
- Query latency
- Embedding success rate
- Failover frequency
- Cost per query

---

## 3. Pinecone Console - Already Available ✅

**Monitor Vector Database:**

1. Go to https://app.pinecone.io/
2. Select index: `rag-demo`
3. View:
   - Total vectors
   - Query performance
   - Storage usage

**Useful Metrics:**
- Queries per second
- P95 query latency
- Index utilization

---

## 4. Azure Monitor - For Azure OpenAI

**Track Azure OpenAI Usage:**

1. Azure Portal → Azure OpenAI Service
2. Monitoring → Metrics

**View:**
- Total requests
- Errors (429, 500)
- Token usage
- Latency per region

---

## 5. Custom Observability Dashboard

### Option A: Simple Metrics Endpoint

Already have `/stats` endpoint:

```bash
curl http://YOUR_BACKEND_IP:8000/stats
```

**Enhance it:**

```python
# backend/app/main.py

from datetime import datetime
from collections import defaultdict

# Track metrics in memory
metrics = {
    'queries': defaultdict(int),
    'latencies': [],
    'errors': defaultdict(int),
    'providers': defaultdict(int)
}

@app.post("/query")
async def query_documents(request: QueryRequest):
    start_time = time.time()
    
    try:
        rag = get_rag()
        result = rag.query(request.question, request.n_results)
        
        # Track metrics
        latency = time.time() - start_time
        metrics['queries'][datetime.now().hour] += 1
        metrics['latencies'].append(latency)
        metrics['providers'][result.provider] += 1
        
        return QueryResponse(
            response=result.response,
            sources=result.sources,
            provider=result.provider
        )
    except Exception as e:
        metrics['errors'][str(type(e).__name__)] += 1
        raise

@app.get("/metrics")
async def get_metrics():
    """Prometheus-style metrics"""
    return {
        'total_queries': sum(metrics['queries'].values()),
        'avg_latency': sum(metrics['latencies']) / len(metrics['latencies']) if metrics['latencies'] else 0,
        'p95_latency': sorted(metrics['latencies'])[int(len(metrics['latencies']) * 0.95)] if metrics['latencies'] else 0,
        'errors_by_type': dict(metrics['errors']),
        'queries_by_provider': dict(metrics['providers']),
        'queries_by_hour': dict(metrics['queries'])
    }
```

### Option B: Prometheus + Grafana

**Add Prometheus metrics:**

```bash
pip install prometheus-client
```

```python
# backend/app/main.py
from prometheus_client import Counter, Histogram, make_asgi_app

# Define metrics
query_counter = Counter('rag_queries_total', 'Total queries', ['provider', 'status'])
query_latency = Histogram('rag_query_duration_seconds', 'Query latency')
embedding_counter = Counter('rag_embeddings_total', 'Total embeddings', ['provider'])

@app.post("/query")
@query_latency.time()
async def query_documents(request: QueryRequest):
    try:
        result = rag.query(request.question, request.n_results)
        query_counter.labels(provider=result.provider, status='success').inc()
        return result
    except Exception as e:
        query_counter.labels(provider='unknown', status='error').inc()
        raise

# Expose metrics endpoint
metrics_app = make_asgi_app()
app.mount("/prometheus", metrics_app)
```

**Grafana Dashboard:**
- Query rate over time
- Latency percentiles (P50, P95, P99)
- Error rate
- Provider distribution (us-east vs eu-west)
- Cost tracking

---

## 6. Demonstration Observability - For Your Presentation

### Show Failover in Real-Time:

**Create a Demo Dashboard:**

```python
# backend/app/main.py

@app.get("/demo/realtime-status")
async def realtime_status():
    """Real-time status for demo"""
    azure = get_azure()
    
    return {
        'timestamp': datetime.now().isoformat(),
        'active_region': azure.get_current_provider(),
        'health': {
            endpoint.name: {
                'healthy': azure.health_status[i],
                'last_failure': azure.last_failure_time.get(i)
            }
            for i, endpoint in enumerate(azure.configs)
        },
        'recent_queries': metrics['queries'],
        'current_provider_distribution': dict(metrics['providers'])
    }
```

**Visualize Failover:**

Create a simple HTML dashboard:

```html
<!-- backend/static/dashboard.html -->
<!DOCTYPE html>
<html>
<head>
    <title>RAG System - Resilience Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>RAG System - Multi-Region Resilience</h1>
    
    <div id="status">
        <h2>Current Status</h2>
        <div id="active-region"></div>
    </div>
    
    <div id="health">
        <h2>Region Health</h2>
        <div class="region">
            <h3>🇺🇸 US-East</h3>
            <span id="us-east-status"></span>
        </div>
        <div class="region">
            <h3>🇪🇺 EU-West</h3>
            <span id="eu-west-status"></span>
        </div>
    </div>
    
    <canvas id="providerChart"></canvas>
    
    <script>
        async function updateStatus() {
            const response = await fetch('/demo/realtime-status');
            const data = await response.json();
            
            // Update active region
            document.getElementById('active-region').textContent = 
                `Active: ${data.active_region}`;
            
            // Update health indicators
            for (const [name, health] of Object.entries(data.health)) {
                const id = name.includes('us-east') ? 'us-east-status' : 'eu-west-status';
                document.getElementById(id).textContent = 
                    health.healthy ? '✅ Healthy' : '❌ Unhealthy';
            }
            
            // Update chart
            updateChart(data.current_provider_distribution);
        }
        
        // Refresh every 2 seconds
        setInterval(updateStatus, 2000);
        updateStatus();
    </script>
</body>
</html>
```

---

## Recommended Setup for Your Demo

### Phase 1: Quick Setup (5 minutes)

1. **Add LangSmith**
   ```bash
   # Set environment variables
   export LANGCHAIN_TRACING_V2=true
   export LANGCHAIN_API_KEY=your-key
   export LANGCHAIN_PROJECT=rag-demo
   ```

2. **View in LangSmith Dashboard**
   - Make a query
   - See full trace in LangSmith UI
   - Show to audience

### Phase 2: Enhanced Monitoring (30 minutes)

1. **Add custom metrics endpoint** (code above)
2. **Create simple HTML dashboard**
3. **Add failover visualization**

### Phase 3: Production Ready (2 hours)

1. **Integrate Prometheus**
2. **Set up Grafana**
3. **Configure CloudWatch alarms**
4. **Set up cost tracking**

---

## What to Show in Your Presentation

### 1. LangSmith Trace:
- Show complete RAG pipeline
- Highlight embedding → search → generation
- Show cost per query
- Show latency breakdown

### 2. Failover Demonstration:
```bash
# Trigger failover
curl -X POST http://YOUR_IP:8000/demo/failover

# Check status
curl http://YOUR_IP:8000/demo/health-status

# Make a query - show it uses eu-west
curl -X POST http://YOUR_IP:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What is machine learning?"}'
```

### 3. CloudWatch Logs:
- Show real-time logs during failover
- Highlight error → retry → success pattern

### 4. Pinecone Metrics:
- Show vector count increasing during upload
- Show query performance

---

## Cost of Observability Tools

| Tool | Cost | Value |
|------|------|-------|
| LangSmith | Free tier: 5k traces/month<br>Pro: $39/month | ⭐⭐⭐⭐⭐ Best for LangChain |
| CloudWatch | ~$0.50/GB logs<br>Already included | ⭐⭐⭐⭐ Essential |
| Pinecone Console | Free with Pinecone | ⭐⭐⭐⭐ Essential |
| Azure Monitor | Free tier sufficient | ⭐⭐⭐ Nice to have |
| Prometheus/Grafana | Self-hosted (free) | ⭐⭐⭐ Production use |

---

## Next Steps

1. **Sign up for LangSmith** (5 min)
2. **Add environment variables** (2 min)
3. **Make test query** (1 min)
4. **View trace in LangSmith** (instant!)

**Total: < 10 minutes to full observability!** 🎉

