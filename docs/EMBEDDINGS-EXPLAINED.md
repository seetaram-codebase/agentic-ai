# Summary: How to Verify Embeddings Are Stored and Used Correctly

## ✅ Your Embeddings ARE Stored Correctly!

Based on what you showed from Pinecone:

```
ID: 9609e55a52ad061a_0
values: [-0.0701156333, -0.0192103069, ...] (1536 dimensions)
metadata:
  chunk_index: 0
  document_id: "9609e55a52ad061a"
  text: "https://app.nuclino.com/..."
```

### This is PERFECT! ✅

1. **`values`** = The 1536-dimensional embedding vector (the AI representation)
2. **`metadata.text`** = The original text (for displaying to users)

**This is exactly how it should be stored!**

---

## How Embeddings Work

### What You're Seeing is Correct

**Embeddings** (the `values` array):
- Numerical vector with 1536 numbers
- Represents the **semantic meaning** of the text
- Used by Pinecone to find similar documents
- Computers compare these numbers to measure similarity

**Original Text** (the `metadata.text` field):
- The actual readable text from your document
- Returned when a match is found
- Sent to Azure OpenAI as context for generating answers

### The RAG Query Flow

When you ask: "What is this about?"

1. **Your Question → Embedding**
   ```
   "What is this about?" → [-0.05, 0.12, -0.08, ...] (1536 numbers)
   ```

2. **Pinecone Searches Similar Vectors**
   - Compares your question embedding against all stored embeddings
   - Finds the most similar ones using cosine similarity
   - Returns the matching vectors

3. **Get Original Text from Metadata**
   - For each matching vector, retrieve `metadata.text`
   - This is the actual content from your documents

4. **Send to Azure OpenAI**
   ```
   Context: <matched text from your documents>
   Question: What is this about?
   
   Answer: <generated based on YOUR documents>
   ```

---

## Why You Might Still Get Generic Answers

Even though embeddings are stored correctly, you get generic answers if:

### Issue 1: Backend Not Using Pinecone

**Symptom:** Backend is using ChromaDB (empty local database) instead of Pinecone

**How to check:**
```bash
curl http://<YOUR_BACKEND_IP>:8000/stats
```

**Should return:**
```json
{
  "vector_store": {
    "type": "pinecone",  ← Must say "pinecone"!
    "document_count": 5   ← Must be > 0!
  }
}
```

**If it says `"type": "chroma"`:**
- Backend is NOT using Pinecone
- Querying empty local ChromaDB instead
- Fix: Set `USE_PINECONE=true` in ECS task definition

### Issue 2: Wrong Backend IP

**Check current ECS task IP:**
1. AWS Console → ECS → Clusters → rag-demo
2. Tasks → Click running task
3. Network → Public IP

**Update everywhere:**
- UI settings
- Test scripts
- Documentation

### Issue 3: No Documents Embedded Yet

**Even if Pinecone has some vectors, your specific documents might not be embedded**

**How to verify:**
1. Check Pinecone dashboard: Total vector count
2. Check document status in DynamoDB
3. Check embedder lambda logs for success

**To re-embed:**
1. Delete documents from S3 `uploads/` folder
2. Re-upload via UI
3. Monitor lambda logs for successful embedding

---

## Quick Verification Steps

### Step 1: Check Pinecone Dashboard

Go to: https://app.pinecone.io

- Index: `rag-demo`
- Check: **Total vectors** count
- Should be: Greater than 0

✅ **You already confirmed this - vectors are there!**

### Step 2: Check Backend is Using Pinecone

Run this command (replace with your current backend IP):

```bash
curl http://<BACKEND_IP>:8000/stats
```

**Expected:**
```json
{
  "vector_store": {
    "type": "pinecone",
    "index_name": "rag-demo",
    "document_count": 5
  }
}
```

### Step 3: Test a Query

```bash
curl -X POST http://<BACKEND_IP>:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What is in the document?"}'
```

**Good response:**
```json
{
  "response": "Based on the document...",
  "sources": [
    {"source": "links.txt", "page": 1}
  ],
  "provider": "Chat (us-east)"
}
```

**Bad response:**
```json
{
  "response": "I don't have any information...",
  "sources": [],
  "provider": "Chat (us-east)"
}
```

If `sources` is empty → Backend not finding documents in Pinecone!

---

## How to Fix: Backend Not Using Pinecone

### Check ECS Task Environment Variables

1. **AWS Console → ECS → Clusters → rag-demo**
2. **Click on Service "backend"**
3. **Task Definition → Latest Revision**
4. **Container → Environment Variables**

**Must have:**
```
USE_PINECONE = true
PINECONE_API_KEY_PARAM = /rag-demo/pinecone/api-key
PINECONE_INDEX = rag-demo
```

### If Missing: Redeploy with Terraform

```bash
cd infrastructure/terraform
terraform apply -auto-approve

# Force new deployment
aws ecs update-service \
  --cluster rag-demo \
  --service backend \
  --force-new-deployment \
  --region us-east-1
```

Wait 2-3 minutes for new task to start, then test again.

---

## Test End-to-End

### 1. Upload Test Document

Create a file `test.txt`:
```
The magic password is BANANA123.
The secret code is XYZABC.
```

Upload via UI.

### 2. Wait 60 Seconds

- S3 → SQS → Chunker → SQS → Embedder → Pinecone
- Check embedder lambda logs for success

### 3. Query

Ask: "What is the magic password?"

**Expected:** Should return "BANANA123" from YOUR document

**If generic answer:** Backend not using Pinecone or documents not embedded

---

## Final Answer to Your Question

### "Are embeddings stored as readable text?"

**NO** - Embeddings are stored as numbers (the `values` array).

**YES** - Original text is ALSO stored (in `metadata.text`) for retrieval.

### What You Saw is Correct ✅

```
values: [-0.07, -0.01, 0.02, ...] ← The embedding (1536 numbers)
metadata:
  text: "https://..." ← The original text
```

This is the **standard way** to store embeddings in vector databases:
- **Vector** for similarity search
- **Metadata** for displaying results

---

## Summary

1. ✅ **Embeddings stored correctly** in Pinecone (you verified this)
2. ❓ **Backend configuration** - need to verify it's using Pinecone
3. ❓ **Query test** - verify retrieval works end-to-end

**Next Action:**
Get your current backend IP and run:
```bash
curl http://<IP>:8000/stats
```

If it says `"type": "chroma"` → That's your problem!
If it says `"type": "pinecone"` and `document_count > 0` → Should work!

