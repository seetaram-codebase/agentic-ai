# Pinecone RAG Diagnostics

## Run this checklist to debug why queries return generic answers

### 1. Verify Pinecone Has Documents

**Check Pinecone Dashboard:**
- Go to https://app.pinecone.io
- Select your index: `rag-demo`
- Check "Total vectors" count

**Or use the verification script:**
```bash
cd C:\Users\seeta\IdeaProjects\agentic-ai
python scripts\verify-pinecone.py
```

**Expected:** Total vectors > 0 (should match number of chunks from uploaded documents)
**If 0:** Documents were never successfully embedded

---

### 2. Check Lambda Embedder Logs

Check CloudWatch logs for `rag-demo-embedder` lambda:

**Success looks like:**
```
Stored embedding in Pinecone: {document_id}_{chunk_index}
Document {document_id} fully embedded
```

**Failure looks like:**
```
Error storing in Pinecone: ...
```

**Common errors:**
- `Vector dimension X does not match Y` → Index dimension mismatch
- `No module named 'pinecone'` → Missing dependency
- `Pinecone API key not available` → SSM parameter not set

---

### 3. Verify Backend Can Query Pinecone

**Check `/stats` endpoint:**
```bash
curl http://13.222.106.90:8000/stats
```

**Expected response:**
```json
{
  "vector_store": {
    "type": "pinecone",
    "index_name": "rag-demo",
    "document_count": 10,  // Should be > 0
    "dimension": 1536
  },
  "azure_openai": {
    ...
  }
}
```

**If `document_count` is 0:**
- Either no documents uploaded
- Or embeddings failed to store

---

### 4. Test End-to-End Flow

**Upload a test document:**
1. Go to UI: http://localhost:5173 (or your UI URL)
2. Upload a simple text file with unique content like:
   ```
   The secret code is BANANA123.
   The password is APPLE456.
   ```

**Wait 30-60 seconds** for processing:
- S3 upload → SQS → Chunker Lambda → SQS → Embedder Lambda → Pinecone

**Query for the content:**
Ask: "What is the secret code?"

**Expected:** Should return "BANANA123" from YOUR document
**Actual (if broken):** Generic answer or "I don't have information..."

---

### 5. Check Backend Environment Variables

**Verify ECS task definition has:**
```
USE_PINECONE=true
PINECONE_API_KEY_PARAM=/rag-demo/pinecone/api-key
PINECONE_INDEX=rag-demo
```

**Check via AWS Console:**
1. ECS → Clusters → rag-demo
2. Tasks → Click running task
3. Configuration → Environment variables

---

### 6. Common Issues & Fixes

#### Issue: "No relevant documents found"
**Cause:** Pinecone is empty
**Fix:** 
1. Delete old failed documents from S3
2. Re-upload documents
3. Monitor lambda logs to ensure successful embedding

#### Issue: Generic answers from Azure OpenAI
**Cause:** Query isn't using RAG context
**Fix:**
1. Check backend logs when querying
2. Should see: "Retrieved X documents from vector store"
3. If not retrieving docs, Pinecone query is failing

#### Issue: Dimension mismatch (even though index is 1536)
**Cause:** Old vectors with wrong dimension still in index
**Fix:**
```python
# In Pinecone dashboard or via API:
# Delete ALL vectors and re-upload
```

#### Issue: Backend using ChromaDB instead of Pinecone
**Cause:** `USE_PINECONE` not set to "true"
**Fix:**
1. Update ECS task definition environment variable
2. Redeploy backend service

---

### 7. Debug Flow Manually

**Step 1: Upload Document**
- Upload via UI → Check S3 bucket for file in `uploads/` folder

**Step 2: Check Chunker**
- CloudWatch Logs → `/aws/lambda/rag-demo-chunker`
- Should see: "Successfully chunked document: X chunks"
- Check SQS: `rag-demo-embedding` queue should have X messages

**Step 3: Check Embedder**
- CloudWatch Logs → `/aws/lambda/rag-demo-embedder`  
- Should see: "Stored embedding in Pinecone" for each chunk
- Check Pinecone: Vector count should increase by X

**Step 4: Query**
- Query via UI
- Backend logs should show:
  ```
  Processing query: {your question}
  Retrieved {N} documents from vector store
  ```

---

### 8. Quick Test Script

Run this in backend directory to test Pinecone connection:

```python
import os
from app.vector_store import get_vector_store

# Must set these environment variables first
os.environ['USE_PINECONE'] = 'true'
os.environ['PINECONE_API_KEY'] = 'your-api-key'

vs = get_vector_store()
stats = vs.get_stats()
print(f"Vector store type: {stats['type']}")
print(f"Document count: {stats['document_count']}")
print(f"Dimension: {stats['dimension']}")

# If count > 0, try a test query
if stats['document_count'] > 0:
    test_embedding = [0.1] * 1536  # Dummy embedding
    results = vs.query(test_embedding, n_results=3)
    print(f"Query returned {len(results['documents'])} documents")
```

---

### 9. Expected Successful Flow

```
User uploads document.txt
  ↓
Backend → S3 (uploads/abc123_document.txt)
  ↓
S3 → SQS (document-chunking queue)
  ↓
Chunker Lambda:
  - Downloads from S3
  - Splits into chunks (e.g., 5 chunks)
  - Sends each chunk → SQS (embedding queue)
  ↓
SQS (5 messages, one per chunk)
  ↓
Embedder Lambda (processes each message):
  - Generates embedding via Azure OpenAI
  - Stores vector in Pinecone
  - Updates DynamoDB progress
  ↓
Pinecone Index:
  - Now has 5 new vectors
  - Metadata includes text, source, page
  ↓
User queries: "What is in the document?"
  ↓
Backend:
  - Generates query embedding
  - Searches Pinecone → finds matching chunks
  - Sends chunks as context to Azure OpenAI
  - Returns answer based on YOUR document
```

---

### 10. Most Likely Cause

Based on the symptoms (generic answers), the issue is usually:

**Vectors are not in Pinecone**

Reasons:
1. ✅ Embedder lambda failed (check logs)
2. ✅ Backend using ChromaDB instead of Pinecone (check USE_PINECONE env var)
3. ✅ Pinecone API key not accessible (check SSM parameter)
4. ✅ Index name mismatch (backend looks for "rag-demo", but index named differently)

**Next Action:**
1. Check Pinecone dashboard - count the vectors
2. If 0 vectors → Check embedder lambda logs
3. If N vectors → Check backend USE_PINECONE env var
4. If both OK → Run a test query and check backend logs for "Retrieved X documents"

