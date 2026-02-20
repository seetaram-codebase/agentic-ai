# How to Check Document Processing Status

## Quick Answer

The UI now shows clear, real-time document processing status! Here's what you'll see:

### 1. **Upload Section** (Top)
```
📊 Vector Store: 28 chunks indexed
✅ 1 file(s) uploaded successfully
```
- Shows total chunks in the vector store
- Confirms when upload completes

### 2. **Processing Documents Section** (Appears automatically)
Shows each document with:
- **Filename**: The file you uploaded
- **Status Badge**: `uploaded` → `chunked` → `embedding` → `completed`
- **Progress Bar**: Visual 0-100% indicator
- **Progress Details**: `Chunks: 15/20` (chunks embedded / total chunks)
- **Document ID**: For tracking in logs

**Status Meanings:**
- 🔵 **uploaded**: File in S3, waiting for chunker Lambda to start
- 🟠 **chunked**: Document split into chunks, waiting for embedder Lambda
- 🟡 **embedding**: Embeddings being generated (in progress)
- 🟢 **completed**: All chunks embedded, ready to query!
- 🔴 **error**: Something went wrong

### 3. **Helpful Hints**
The UI shows contextual hints:
- `ℹ️ Document uploaded to S3, waiting for chunking to begin...` (status: uploaded, progress: 0%)
- `ℹ️ Document chunked into 20 pieces, waiting for embedding to start...` (status: chunked, progress: 0%)
- `⚡ Embeddings being generated in parallel - this usually takes 4-10 seconds` (status: embedding)

---

## How Document Processing Works

### **Backend Flow:**
```
Upload → S3 → SQS → Chunker Lambda → SQS → Embedder Lambda → Pinecone
          ↓                    ↓                      ↓
       DynamoDB            DynamoDB               DynamoDB
     status=uploaded    status=chunked       status=completed
                        chunk_count=20       chunks_embedded=20
```

### **DynamoDB Tracking:**

When you upload a document, the backend creates a DynamoDB record:
```json
{
  "document_id": "6058ee32-f80b-40",
  "document_key": "uploads/6058ee32-f80b-40_latest_news_file.txt",
  "status": "uploaded",
  "chunk_count": 0,
  "chunks_embedded": 0,
  "created_at": 1234567890,
  "updated_at": 1234567890
}
```

**Chunker Lambda updates:**
```json
{
  "status": "chunked",
  "chunk_count": 20,
  "updated_at": 1234567895
}
```

**Embedder Lambda updates (for each chunk):**
```json
{
  "chunks_embedded": 1,  // increments: 1, 2, 3, ... 20
  "updated_at": 1234567896
}
```

**When all chunks embedded:**
```json
{
  "status": "completed",
  "chunks_embedded": 20,
  "chunk_count": 20,
  "completed_at": 1234567900
}
```

---

## How to Check Status Manually

### **Method 1: Use the UI** (Recommended)
1. Upload a document via drag & drop
2. Watch the "⏳ Processing Documents" section appear
3. Status updates automatically every 3 seconds
4. When it shows "completed" and 100%, you're ready to query!

### **Method 2: Check Backend API**
```bash
# Get status for a specific document
curl http://54.89.155.20:8000/documents/6058ee32-f80b-40/status

# Response:
{
  "document_id": "6058ee32-f80b-40",
  "document_key": "uploads/6058ee32-f80b-40_latest_news_file.txt",
  "status": "embedding",
  "chunk_count": 20,
  "chunks_embedded": 15,
  "progress": 75,
  "created_at": 1234567890,
  "updated_at": 1234567900
}
```

### **Method 3: Check DynamoDB Directly**
```bash
aws dynamodb get-item \
  --table-name rag-demo-documents \
  --key '{"document_id":{"S":"6058ee32-f80b-40"}}'
```

### **Method 4: Check CloudWatch Logs**

**Chunker Lambda logs:**
```
START RequestId: xxx
🚀 Lambda handler started
Processing document: s3://your-bucket/uploads/6058ee32-f80b-40_latest_news_file.txt
Loaded 3 pages/documents from uploads/6058ee32-f80b-40_latest_news_file.txt
Created 20 chunks from uploads/6058ee32-f80b-40_latest_news_file.txt
Sent 20 chunks to embedding queue for document 6058ee32-f80b-40
✅ Successfully chunked: uploads/6058ee32-f80b-40_latest_news_file.txt into 20 chunks
END RequestId: xxx
```

**Embedder Lambda logs:**
```
START RequestId: yyy
📄 Processing chunk 0/20 for document_id: 6058ee32-f80b-40
Generated embedding vector: 1536 dimensions
Stored embedding in Pinecone: 6058ee32-f80b-40_0
Progress updated: 1/20 chunks embedded
Document 6058ee32-f80b-40 progress: 1/20 (5%)
✅ Successfully embedded and stored chunk 0 for 6058ee32-f80b-40
END RequestId: yyy

...

START RequestId: zzz
📄 Processing chunk 19/20 for document_id: 6058ee32-f80b-40
Generated embedding vector: 1536 dimensions
Stored embedding in Pinecone: 6058ee32-f80b-40_19
Progress updated: 20/20 chunks embedded
🎉 Document 6058ee32-f80b-40 fully embedded (20 chunks)! Status set to 'completed'
END RequestId: zzz
```

---

## Troubleshooting

### "Document stuck at 'uploaded' status"
**Cause:** Chunker Lambda not running or failing
**Check:**
```bash
# Check chunker Lambda logs
aws logs tail /aws/lambda/rag-demo-chunker --follow

# Check SQS queue (should be empty if processing)
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/YOUR_ACCOUNT/rag-demo-chunking-queue \
  --attribute-names ApproximateNumberOfMessages
```

### "Document stuck at 'chunked' status"
**Cause:** Embedder Lambda not running or failing (Azure OpenAI credentials issue)
**Check:**
```bash
# Check embedder Lambda logs
aws logs tail /aws/lambda/rag-demo-embedder --follow

# Check if Azure OpenAI credentials are set
aws ssm get-parameter --name /rag-demo/azure-openai/us-east/embedding-key --with-decryption
```

### "Progress is 0% but status is 'chunked'"
**Normal!** This means:
- ✅ Document uploaded to S3
- ✅ Chunker Lambda processed it
- ⏳ Embedder Lambda hasn't started yet (SQS messages in queue)

Wait a few seconds and refresh. Progress should start increasing.

### "Pinecone shows vectors but DynamoDB doesn't update"
**Cause:** DynamoDB permissions issue or table name mismatch
**Fix:**
```bash
# Check Lambda has DynamoDB permissions
aws lambda get-policy --function-name rag-demo-embedder

# Verify table name
echo $DYNAMODB_DOCUMENTS_TABLE
# Should be: rag-demo-documents
```

---

## Expected Timeline

For a typical document:

| Time | Event |
|------|-------|
| 0s | Upload to S3, DynamoDB record created (status: `uploaded`) |
| 1-2s | Chunker Lambda processes (status: `chunked`, chunk_count set) |
| 3-15s | Embedder Lambda processes chunks in parallel (status: `embedding`, progress increases) |
| 15-20s | All chunks embedded (status: `completed`, progress: 100%) |

**Processing speed:**
- **Small files** (1-5 pages): ~5-10 seconds total
- **Medium files** (10-20 pages): ~15-30 seconds total
- **Large files** (50+ pages): ~1-2 minutes total

---

## UI Improvements Made

### Before:
```
📄 Documents: 28 chunks indexed
✅ AMZN.pdf: processing - Document uploaded and queued for processing. 
Check status at /documents/5b071bb9-3190-40/status
```
❌ Confusing - shows both chunk count AND processing message
❌ Asks user to manually check URL
❌ No real-time updates

### After:
```
📊 Vector Store: 28 chunks indexed
✅ 1 file(s) uploaded successfully

⏳ Processing Documents
📄 AMZN.pdf          [🟡 embedding]
Progress: 75%
Chunks: 15 / 20
⚡ Embeddings being generated in parallel - this usually takes 4-10 seconds
ID: 5b071bb9-3190-40
```
✅ Clear separation of vector store stats and upload status
✅ Real-time progress tracking every 3 seconds
✅ Visual progress bar
✅ Contextual hints about what's happening
✅ Auto-removes from list when completed

---

## When Can I Query?

**You can query as soon as:**
- ✅ Status shows `completed` OR
- ✅ Progress reaches 100% OR
- ✅ The document disappears from "Processing Documents" section

The UI will automatically refresh the vector store count, and you can start asking questions!

**Pro tip:** You can actually start querying when progress is at ~50% or higher - the chunks that are already embedded are searchable!

