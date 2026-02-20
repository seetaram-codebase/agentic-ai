# Failover Flow Diagram: US-East → EU-West

## Complete Request Flow with Automatic Failover

```
┌────────────────────────────────────────────────────────────────────┐
│                         USER MAKES QUERY                           │
│                   "What is machine learning?"                      │
└────────────────────┬───────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    BACKEND API (ECS Container)                      │
│                                                                     │
│  Step 1: Generate Query Embedding                                  │
│  ────────────────────────────────────                              │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ EMBEDDING FAILOVER LOGIC                                   │   │
│  ├────────────────────────────────────────────────────────────┤   │
│  │                                                            │   │
│  │ 🔵 Try: US-East Embedding Endpoint                        │   │
│  │    POST https://us-east-xyz.openai.azure.com/             │   │
│  │         /openai/deployments/text-embedding-3-small/...    │   │
│  │                                                            │   │
│  │    ┌─────────────────────────────────────┐                │   │
│  │    │ Timeout after 30 seconds            │                │   │
│  │    │ OR                                  │                │   │
│  │    │ 429 Rate Limit                      │                │   │
│  │    │ OR                                  │                │   │
│  │    │ 500 Server Error                    │                │   │
│  │    └─────────────────────────────────────┘                │   │
│  │              ❌ FAILURE                                    │   │
│  │                                                            │   │
│  │ ⚠️  Mark US-East as UNHEALTHY                             │   │
│  │    health_status[0] = False                               │   │
│  │    last_failure_time[0] = now                             │   │
│  │                                                            │   │
│  │              ↓ AUTOMATIC RETRY                             │   │
│  │                                                            │   │
│  │ 🟢 Try: EU-West Embedding Endpoint                        │   │
│  │    POST https://eu-west-xyz.openai.azure.com/             │   │
│  │         /openai/deployments/text-embedding-3-small/...    │   │
│  │                                                            │   │
│  │              ✅ SUCCESS (2-3 seconds)                       │   │
│  │                                                            │   │
│  │    Embedding: [0.05, -0.12, 0.08, ... 1536 dims]          │   │
│  │    Provider: "Embedding (eu-west)"                        │   │
│  │                                                            │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  Total Time: 32-33 seconds (30s timeout + 2-3s success)            │
│                                                                     │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       PINECONE VECTOR SEARCH                        │
│  Query: [0.05, -0.12, 0.08, ... 1536 dims]                         │
│  Returns: Top 5 matching document chunks                           │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    BACKEND API (ECS Container)                      │
│                                                                     │
│  Step 2: Generate Answer Using Context                             │
│  ───────────────────────────────────────                           │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ CHAT COMPLETION FAILOVER LOGIC                            │   │
│  ├────────────────────────────────────────────────────────────┤   │
│  │                                                            │   │
│  │ ❌ Skip: US-East Chat Endpoint (marked unhealthy)         │   │
│  │                                                            │   │
│  │              ↓ GO DIRECTLY TO HEALTHY ENDPOINT             │   │
│  │                                                            │   │
│  │ 🟢 Try: EU-West Chat Endpoint                             │   │
│  │    POST https://eu-west-xyz.openai.azure.com/             │   │
│  │         /openai/deployments/gpt-4/chat/completions        │   │
│  │                                                            │   │
│  │    Request:                                                │   │
│  │    {                                                       │   │
│  │      "messages": [                                         │   │
│  │        {                                                   │   │
│  │          "role": "system",                                 │   │
│  │          "content": "Answer based on context..."           │   │
│  │        },                                                  │   │
│  │        {                                                   │   │
│  │          "role": "user",                                   │   │
│  │          "content": "Context: [retrieved docs]\n           │   │
│  │                      Question: What is ML?"                │   │
│  │        }                                                   │   │
│  │      ]                                                     │   │
│  │    }                                                       │   │
│  │                                                            │   │
│  │              ✅ SUCCESS (3-5 seconds)                       │   │
│  │                                                            │   │
│  │    Response: "Machine learning is a subset of AI..."      │   │
│  │    Provider: "Chat (eu-west)"                             │   │
│  │                                                            │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  Total Time: 3-5 seconds (no timeout, direct to healthy endpoint)  │
│                                                                     │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          USER GETS RESPONSE                         │
│                                                                     │
│  {                                                                  │
│    "response": "Machine learning is a subset of AI that...",       │
│    "sources": [                                                     │
│      { "source": "ml-guide.pdf", "page": 1 }                       │
│    ],                                                               │
│    "provider": "Chat (eu-west)"  ← Shows failover region used     │
│  }                                                                  │
│                                                                     │
│  Total Time: 35-40 seconds for first request after failure         │
│              5-10 seconds for subsequent requests (skips timeout)   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Next Request (1 Minute Later)

```
┌────────────────────────────────────────────────────────────────────┐
│                      USER MAKES ANOTHER QUERY                      │
│                   "What is deep learning?"                         │
└────────────────────┬───────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    BACKEND API (ECS Container)                      │
│                                                                     │
│  Health Status Check:                                               │
│  ──────────────────                                                 │
│  • US-East: UNHEALTHY (failed 1 min ago)                           │
│  • EU-West: HEALTHY (last success just now)                        │
│                                                                     │
│  Decision: SKIP US-East, use EU-West directly                      │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ 🟢 Direct to: EU-West Embedding Endpoint                  │   │
│  │    ✅ SUCCESS (2-3 seconds)                                 │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          ▼
                    Pinecone Search
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    BACKEND API (ECS Container)                      │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ 🟢 Direct to: EU-West Chat Endpoint                       │   │
│  │    ✅ SUCCESS (3-5 seconds)                                 │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  Total Time: 5-8 seconds (FAST - no timeout delays!)               │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          ▼
                   USER GETS RESPONSE
                   (5-8 seconds - normal speed!)
```

---

## After 60 Seconds: Recovery Check

```
┌────────────────────────────────────────────────────────────────────┐
│              USER MAKES QUERY (61 seconds after failure)           │
└────────────────────┬───────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    BACKEND API (ECS Container)                      │
│                                                                     │
│  Health Status Check:                                               │
│  ──────────────────                                                 │
│  • US-East: UNHEALTHY (failed 61 seconds ago)                      │
│  • Recovery time: 60 seconds                                        │
│  • Decision: RETRY US-East to check if recovered                   │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │ 🔵 Retry: US-East Embedding Endpoint                      │   │
│  │    POST https://us-east-xyz.openai.azure.com/...          │   │
│  │                                                            │   │
│  │    ✅ SUCCESS! (US-East recovered!)                        │   │
│  │                                                            │   │
│  │    ✅ Mark US-East as HEALTHY                              │   │
│  │       health_status[0] = True                             │   │
│  │       current_index = 0  (switch back to primary)         │   │
│  │                                                            │   │
│  └────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  Future requests will use US-East again (primary region)           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Health Status Over Time

```
TIME    US-EAST          EU-WEST          ACTIVE REGION
─────   ──────────────   ──────────────   ─────────────
00:00   ✅ Healthy        ✅ Healthy        US-East
01:00   ✅ Healthy        ✅ Healthy        US-East
02:00   ❌ FAILS          ✅ Healthy        EU-West (failover!)
02:01   ❌ Unhealthy      ✅ Healthy        EU-West
02:30   ❌ Unhealthy      ✅ Healthy        EU-West
03:00   ❌ Unhealthy      ✅ Healthy        EU-West
03:02   🔄 Retry          ✅ Healthy        US-East (recovered!)
03:03   ✅ Healthy        ✅ Healthy        US-East
04:00   ✅ Healthy        ✅ Healthy        US-East
```

**Timeline:**
- **02:00** - US-East fails, automatic failover to EU-West
- **02:00 - 03:02** - All requests use EU-West (62 minutes)
- **03:02** - System retries US-East (60 second recovery period passed)
- **03:02+** - US-East recovered, switch back to primary

---

## What Users See

### Normal Operation (Both Regions Healthy):
```
Request → 3 seconds → Response ✅
Provider: Chat (us-east)
```

### First Request After US-East Fails:
```
Request → 33 seconds → Response ✅
         (30s timeout + 3s success)
Provider: Chat (eu-west)
```

### Subsequent Requests (US-East Still Down):
```
Request → 3 seconds → Response ✅
         (skips unhealthy us-east)
Provider: Chat (eu-west)
```

### After US-East Recovers:
```
Request → 3 seconds → Response ✅
Provider: Chat (us-east)
```

**Users experience:**
- ✅ No errors
- ✅ Requests always succeed
- ⚠️  First failure: slower (30s delay)
- ✅ After failover: normal speed
- ✅ Transparent failover (only visible in "provider" field)

---

## Monitoring Failover Events

### Check Current Health:
```bash
GET http://YOUR_BACKEND_IP:8000/demo/health-status
```

**Response:**
```json
{
  "status": "healthy",
  "azure_openai": {
    "current_provider": "Chat (eu-west)",  ← Currently using failover!
    "endpoints": [
      {
        "name": "Chat (us-east)",
        "healthy": false,                   ← Primary is down
        "is_current": false,
        "last_failure": 1771401490.5
      },
      {
        "name": "Chat (eu-west)",
        "healthy": true,                    ← Failover is healthy
        "is_current": true                  ← Active region
      }
    ]
  }
}
```

### Check Backend Logs:
```
2026-02-19 02:00:15 [INFO] Attempting chat with Chat (us-east)
2026-02-19 02:00:45 [ERROR] Error with Chat (us-east): Connection timeout
2026-02-19 02:00:45 [WARNING] Marked Chat (us-east) as unhealthy
2026-02-19 02:00:45 [INFO] Attempting chat with Chat (eu-west)
2026-02-19 02:00:48 [INFO] ✅ Success with Chat (eu-west)
```

**Log shows:**
1. Tried us-east
2. Failed after timeout
3. Marked unhealthy
4. **Automatically** tried eu-west
5. Succeeded with eu-west

---

## Summary

### Does Traffic Switch to EU-West? YES! ✅

✅ **Automatic** - No manual intervention needed
✅ **Immediate** - Within same request (after timeout)
✅ **Transparent** - User just sees slower first response
✅ **Persistent** - Future requests skip failed region
✅ **Recoverable** - Switches back when primary recovers
✅ **Zero cost** - Only pays for actual API calls made

### The Failover Is:
- Built into the code (`azure_openai.py`)
- Automatic on any error (timeout, rate limit, server error)
- Applied to both chat and embedding endpoints
- Health-tracked to avoid repeated failures
- Self-recovering after 60 seconds

**Your system IS resilient!** 🎉

