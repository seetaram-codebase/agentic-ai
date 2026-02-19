# Complete RAG Pipeline: Azure OpenAI Integration Points

## Where Azure OpenAI is Called

```
┌─────────────────────────────────────────────────────────────────┐
│                        RAG PIPELINE                             │
└─────────────────────────────────────────────────────────────────┘

USER UPLOADS DOCUMENT (links.txt)
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ BACKEND API (ECS)                                               │
│ POST /upload                                                    │
│ - Saves file to S3: uploads/abc123_links.txt                   │
│ - Creates DynamoDB record                                       │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ S3 BUCKET: rag-demo-documents-971778147952                      │
│ - File stored in: uploads/abc123_links.txt                     │
│ - Triggers: S3 Event → SQS                                      │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ SQS QUEUE: rag-demo-document-chunking                          │
│ - Message: { bucket, key, eventName: ObjectCreated:Put }       │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ CHUNKER LAMBDA: rag-demo-chunker                               │
│ ❌ NO Azure OpenAI calls here                                   │
│                                                                 │
│ 1. Downloads file from S3                                      │
│ 2. Splits text into chunks (using LangChain)                   │
│    - Chunk 0: "https://app.nuclino.com/..."                    │
│    - Chunk 1: "https://github.com/..."                         │
│    - ...                                                        │
│ 3. Sends each chunk → SQS embedding queue                      │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ SQS QUEUE: rag-demo-embedding                                  │
│ - Message 1: { document_id, chunk: {index: 0, text: "..."}  }  │
│ - Message 2: { document_id, chunk: {index: 1, text: "..."}  }  │
│ - ...                                                           │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌═════════════════════════════════════════════════════════════════┐
║ EMBEDDER LAMBDA: rag-demo-embedder                             ║
║ ✅ AZURE OPENAI CALLED HERE!                                    ║
║                                                                 ║
║ For each chunk:                                                 ║
║                                                                 ║
║ 1. Get Azure OpenAI config from SSM:                           ║
║    /rag-demo/azure-openai/us-east/embedding-endpoint           ║
║    /rag-demo/azure-openai/us-east/embedding-key                ║
║    /rag-demo/azure-openai/us-east/embedding-deployment         ║
║                                                                 ║
║ 2. ✅ CALL AZURE OPENAI API:                                    ║
║    POST https://<endpoint>/openai/deployments/                 ║
║         text-embedding-3-small/embeddings                      ║
║                                                                 ║
║    Request:                                                     ║
║    {                                                            ║
║      "input": ["https://app.nuclino.com/..."]                  ║
║    }                                                            ║
║                                                                 ║
║    Response:                                                    ║
║    {                                                            ║
║      "data": [{                                                 ║
║        "embedding": [-0.0701, -0.0192, 0.0267, ... 1536 nums] ║
║      }]                                                         ║
║    }                                                            ║
║                                                                 ║
║ 3. Store in Pinecone:                                          ║
║    index.upsert({                                              ║
║      id: "abc123_0",                                           ║
║      values: [-0.0701, -0.0192, ...],  ← Azure OpenAI result  ║
║      metadata: { text: "https://...", ... }                    ║
║    })                                                           ║
└═════════════════════════════════════════════════════════════════┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ PINECONE VECTOR DATABASE                                        │
│ Index: rag-demo                                                 │
│                                                                 │
│ Vector ID: abc123_0                                            │
│ Values: [-0.0701, -0.0192, 0.0267, ...] (1536 dimensions)     │
│ Metadata:                                                       │
│   - text: "https://app.nuclino.com/..."                        │
│   - document_id: "abc123"                                      │
│   - chunk_index: 0                                             │
│   - source: "links.txt"                                        │
└─────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════
LATER: USER QUERIES THE SYSTEM
═══════════════════════════════════════════════════════════════════

USER ASKS: "What links are in the document?"
    │
    ▼
┌═════════════════════════════════════════════════════════════════┐
║ BACKEND API (ECS): POST /query                                 ║
║ ✅ AZURE OPENAI CALLED HERE (TWICE!)                            ║
║                                                                 ║
║ Step 1: Generate query embedding                               ║
║ ─────────────────────────────────────                          ║
║ ✅ CALL AZURE OPENAI (Embedding):                               ║
║    POST https://<endpoint>/openai/deployments/                 ║
║         text-embedding-3-small/embeddings                      ║
║                                                                 ║
║    Request:                                                     ║
║    { "input": ["What links are in the document?"] }            ║
║                                                                 ║
║    Response:                                                    ║
║    { "data": [{ "embedding": [0.05, -0.12, ...] }] }          ║
║                                                                 ║
║ Step 2: Search Pinecone                                        ║
║ ─────────────────────────                                      ║
║ Query Pinecone with embedding vector                           ║
║ → Returns top 5 matching chunks with text                      ║
║                                                                 ║
║ Step 3: Generate answer using context                          ║
║ ───────────────────────────────────────                        ║
║ ✅ CALL AZURE OPENAI (Chat):                                    ║
║    POST https://<endpoint>/openai/deployments/                 ║
║         gpt-4/chat/completions                                 ║
║                                                                 ║
║    Request:                                                     ║
║    {                                                            ║
║      "messages": [                                              ║
║        {                                                        ║
║          "role": "system",                                      ║
║          "content": "Answer based on context..."               ║
║        },                                                       ║
║        {                                                        ║
║          "role": "user",                                        ║
║          "content": "Context: https://app.nuclino.com/...\n    ║
║                      Question: What links...?"                  ║
║        }                                                        ║
║      ]                                                          ║
║    }                                                            ║
║                                                                 ║
║    Response:                                                    ║
║    {                                                            ║
║      "choices": [{                                              ║
║        "message": {                                             ║
║          "content": "The document contains links to..."        ║
║        }                                                        ║
║      }]                                                         ║
║    }                                                            ║
║                                                                 ║
║ Step 4: Return to user                                         ║
║ ──────────────────────                                         ║
║ {                                                               ║
║   "response": "The document contains links to...",             ║
║   "sources": [{ "source": "links.txt", "page": 1 }],           ║
║   "provider": "Chat (us-east)"                                 ║
║ }                                                               ║
└═════════════════════════════════════════════════════════════════┘
    │
    ▼
USER SEES ANSWER BASED ON THEIR DOCUMENT ✅

═══════════════════════════════════════════════════════════════════

## Summary: Azure OpenAI API Calls

### During Document Upload (Async):

1. **Embedder Lambda** (per chunk):
   - ✅ Calls: `text-embedding-3-small` embedding API
   - Purpose: Convert text → 1536-dim vector
   - Stored: In Pinecone

### During Query (Sync):

2. **Backend API** - Embedding:
   - ✅ Calls: `text-embedding-3-small` embedding API
   - Purpose: Convert question → 1536-dim vector
   - Used: To search Pinecone

3. **Backend API** - Chat:
   - ✅ Calls: `gpt-4` or `gpt-35-turbo` chat API
   - Purpose: Generate answer using retrieved context
   - Returned: To user as final response

### Total Azure OpenAI Calls Per Document:

- **Upload**: N calls (where N = number of chunks)
  - Example: 1 file → 5 chunks → 5 embedding API calls

- **Query**: 2 calls per query
  - 1 embedding call (for the question)
  - 1 chat call (for the answer)

### Cost Example:

**Upload 10 documents (100 chunks total):**
- 100 embedding calls × $0.00002/1K tokens = ~$0.002

**100 queries:**
- 100 embedding calls × $0.00002/1K tokens = ~$0.002
- 100 chat calls × $0.002/1K tokens = ~$0.20

**Total: ~$0.204**

## Failover Architecture

Both embedder lambda and backend support multi-region failover:

### Primary Region: us-east
- First choice for all API calls
- If fails → automatically tries eu-west

### Failover Region: eu-west  
- Backup when us-east unavailable
- Same models deployed

This ensures high availability even if one Azure region goes down!

