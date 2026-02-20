# Verify Backend is Using Pinecone

## Issue: Embeddings are in Pinecone, but queries return generic answers

This means the **backend might be using ChromaDB (local) instead of Pinecone (cloud)**.

## Quick Check

### 1. Call the `/stats` endpoint:

```bash
curl http://13.222.106.90:8000/stats
```

**What to look for:**

✅ **If using Pinecone (CORRECT):**
```json
{
  "vector_store": {
    "type": "pinecone",
    "index_name": "rag-demo",
    "document_count": 5,  // > 0
    "dimension": 1536
  }
}
```

❌ **If using ChromaDB (WRONG):**
```json
{
  "vector_store": {
    "type": "chroma",
    "collection_name": "rag-documents",
    "document_count": 0,  // Empty!
    "persist_directory": "./chroma_db"
  }
}
```

### 2. If backend is using ChromaDB:

**Cause:** Environment variable `USE_PINECONE` is not set to `"true"`

**Fix:**

1. Check ECS Task Definition:
   - Go to AWS Console → ECS → Clusters → `rag-demo`
   - Click on Service → Task Definition
   - Check Environment Variables

2. Should have:
   ```
   USE_PINECONE=true
   PINECONE_API_KEY_PARAM=/rag-demo/pinecone/api-key
   PINECONE_INDEX=rag-demo
   ```

3. If missing, update via Terraform or AWS Console and redeploy

## Check Backend Logs When Querying

When you send a query, check CloudWatch logs for the ECS task:

**Success (using Pinecone):**
```
Processing query: what is...
Connected to Pinecone index: rag-demo
Retrieved 5 documents from vector store
```

**Failure (using ChromaDB):**
```
Processing query: what is...
Using ChromaDB collection: rag-documents
Retrieved 0 documents from vector store
```

## Fix: Update ECS Task Definition

### Option 1: Via Terraform (Recommended)

1. Ensure `variables.tf` has:
   ```hcl
   variable "use_pinecone" {
     default = true
   }
   ```

2. Apply Terraform:
   ```bash
   cd infrastructure/terraform
   terraform apply
   ```

3. Restart ECS service:
   ```bash
   aws ecs update-service --cluster rag-demo --service backend --force-new-deployment
   ```

### Option 2: Via AWS Console (Quick Fix)

1. ECS → Task Definitions → `rag-demo-backend`
2. Create new revision
3. Add environment variables:
   - `USE_PINECONE` = `true`
   - `PINECONE_API_KEY_PARAM` = `/rag-demo/pinecone/api-key`
   - `PINECONE_INDEX` = `rag-demo`
4. Update service to use new revision
5. Force new deployment

## Test After Fix

1. **Upload a test document** with unique content:
   ```
   The magic word is XYZABC123.
   ```

2. **Wait 60 seconds** for processing

3. **Query:** "What is the magic word?"

4. **Expected:** Should return "XYZABC123" from your document

5. **Check logs:** Should see "Retrieved X documents from vector store" where X > 0

## Summary

Your Pinecone setup is **CORRECT**:
- ✅ Index created with 1536 dimensions
- ✅ Embeddings stored properly
- ✅ Lambda functions working

The issue is likely:
- ❌ Backend not configured to use Pinecone
- ❌ Still using empty ChromaDB locally

**Next step:** Check `/stats` endpoint to confirm which vector store the backend is using.

