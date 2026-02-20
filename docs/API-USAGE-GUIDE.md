# API Usage Guide

## 📋 Overview

The RAG Demo API supports **two processing modes**:

1. **Async Mode** (Recommended) - Upload to S3, processed by Lambda
2. **Sync Mode** - Process immediately in backend

## 🚀 API Endpoints

### **Upload Document**

#### Async Mode (Default - Recommended)
```http
POST /upload?mode=async
Content-Type: multipart/form-data

file: document.pdf
```

**Response** (202 Accepted):
```json
{
  "filename": "document.pdf",
  "document_id": "a1b2c3d4e5f6g7h8",
  "status": "processing",
  "processing_mode": "async",
  "message": "Document uploaded to S3 and queued for processing. Check status at /documents/a1b2c3d4e5f6g7h8/status"
}
```

**Flow**:
1. File uploaded to S3
2. S3 event triggers SQS
3. Chunker Lambda processes document
4. Embedder Lambda generates embeddings
5. Document ready for querying

**Check status**:
```http
GET /documents/a1b2c3d4e5f6g7h8/status
```

#### Sync Mode (Immediate Processing)
```http
POST /upload?mode=sync
Content-Type: multipart/form-data

file: document.pdf
```

**Response** (200 OK):
```json
{
  "filename": "document.pdf",
  "chunks_created": 25,
  "document_id": "x9y8z7",
  "provider": "azure-openai-us-east",
  "status": "success",
  "processing_mode": "sync"
}
```

---

### **Check Document Status**

```http
GET /documents/{document_id}/status
```

**Response**:
```json
{
  "document_id": "a1b2c3d4e5f6g7h8",
  "document_key": "uploads/a1b2c3d4_document.pdf",
  "status": "embedding",
  "chunk_count": 25,
  "chunks_embedded": 18,
  "progress": 72,
  "created_at": 1708214400,
  "updated_at": 1708214460
}
```

**Status Values**:
- `uploaded` - Uploaded to S3, waiting for chunking
- `chunked` - Document chunked, embedding in progress
- `embedding` - Generating embeddings
- `completed` - All chunks embedded, ready for queries
- `error` - Processing failed

---

### **List All Documents**

```http
GET /documents?limit=100
```

**Response**:
```json
[
  {
    "document_id": "a1b2c3d4e5f6g7h8",
    "document_key": "uploads/doc1.pdf",
    "status": "completed",
    "chunk_count": 25,
    "created_at": 1708214400
  },
  {
    "document_id": "b2c3d4e5f6g7h8i9",
    "document_key": "uploads/doc2.txt",
    "status": "embedding",
    "chunk_count": 15,
    "created_at": 1708214380
  }
]
```

---

### **Query Documents**

```http
POST /query
Content-Type: application/json

{
  "question": "What are the main features?",
  "n_results": 5
}
```

**Response**:
```json
{
  "response": "The main features include...",
  "sources": [
    {
      "source": "document.pdf",
      "page": 3,
      "chunk_index": 5,
      "relevance": 0.89
    }
  ],
  "provider": "azure-openai-us-east"
}
```

---

### **Health Check**

```http
GET /health
```

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2026-02-17T15:30:00Z",
  "service": "rag-demo-api"
}
```

---

### **Readiness Check**

```http
GET /ready
```

**Response**:
```json
{
  "status": "ready",
  "timestamp": "2026-02-17T15:30:00Z",
  "checks": {
    "api": "ok",
    "vector_store": "ok"
  }
}
```

---

## 🔄 Complete End-to-End Flow

### Async Mode (Lambda Processing)

```bash
# Step 1: Upload document
curl -X POST http://api-endpoint:8000/upload?mode=async \
  -F "file=@product-guide.pdf"

# Response:
# {
#   "document_id": "abc123",
#   "status": "processing",
#   "message": "Check status at /documents/abc123/status"
# }

# Step 2: Check processing status
curl http://api-endpoint:8000/documents/abc123/status

# Response (processing):
# {
#   "status": "embedding",
#   "progress": 60,
#   "chunks_embedded": 15,
#   "chunk_count": 25
# }

# Step 3: Wait for completion (poll every few seconds)
# Status will change: uploaded → chunked → embedding → completed

# Step 4: Query the document
curl -X POST http://api-endpoint:8000/query \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What are the product features?",
    "n_results": 5
  }'

# Response:
# {
#   "response": "The product features include...",
#   "sources": [...]
# }
```

### Sync Mode (Immediate Processing)

```bash
# Step 1: Upload and process (blocks until complete)
curl -X POST http://api-endpoint:8000/upload?mode=sync \
  -F "file=@quick-note.txt"

# Response (after processing completes):
# {
#   "filename": "quick-note.txt",
#   "chunks_created": 5,
#   "status": "success",
#   "processing_mode": "sync"
# }

# Step 2: Query immediately
curl -X POST http://api-endpoint:8000/query \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What does the note say?",
    "n_results": 3
  }'
```

---

## 🏗️ Architecture

### Async Mode Flow

```
User → POST /upload?mode=async
  ↓
FastAPI Backend
  ↓
Upload to S3 (uploads/ folder)
  ↓
S3 Event Notification → SQS (chunking queue)
  ↓
Chunker Lambda
  ├─ Download from S3
  ├─ Load document (PyPDFLoader/TextLoader)
  ├─ Chunk text (RecursiveCharacterTextSplitter + tiktoken)
  ├─ Save metadata to DynamoDB
  └─ Send chunks to SQS (embedding queue)
      ↓
Embedder Lambda (triggered for each chunk)
  ├─ Get Azure OpenAI config from SSM
  ├─ Generate embedding (Azure OpenAI)
  ├─ Store in vector DB (Chroma/Pinecone)
  └─ Update progress in DynamoDB
      ↓
Document ready for querying!
```

### Sync Mode Flow

```
User → POST /upload?mode=sync
  ↓
FastAPI Backend
  ├─ Save to temp file
  ├─ Load document
  ├─ Chunk text
  ├─ Generate embeddings
  ├─ Store in vector DB
  └─ Return response
      ↓
Document ready immediately!
```

---

## 🎯 When to Use Each Mode

### Use **Async Mode** when:
✅ Processing large files (> 10 pages)
✅ Uploading multiple documents
✅ Need scalability (auto-scales with Lambda)
✅ Don't need immediate results
✅ Production deployment

### Use **Sync Mode** when:
✅ Quick testing
✅ Small files (< 5 pages)
✅ Need immediate feedback
✅ Demo/development
✅ Single document uploads

---

## 📊 Configuration

### Environment Variables

```bash
# Enable/disable async S3 upload
USE_S3_UPLOAD=true

# S3 bucket for documents
S3_BUCKET=rag-demo-documents-123456789012

# DynamoDB table for tracking
DYNAMODB_DOCUMENTS_TABLE=rag-demo-documents

# AWS region
AWS_REGION=us-east-1
```

### Default Behavior

- If `USE_S3_UPLOAD=true` and S3 is configured → Async mode is default
- If `USE_S3_UPLOAD=false` or S3 not configured → Sync mode is used
- You can always override with `?mode=sync` or `?mode=async` query parameter

---

## 🧪 Testing

### Test Async Upload

```python
import requests

# Upload
response = requests.post(
    'http://localhost:8000/upload?mode=async',
    files={'file': open('test.pdf', 'rb')}
)
document_id = response.json()['document_id']

# Check status
import time
while True:
    status = requests.get(f'http://localhost:8000/documents/{document_id}/status').json()
    print(f"Status: {status['status']}, Progress: {status['progress']}%")
    
    if status['status'] == 'completed':
        break
    time.sleep(2)

# Query
response = requests.post(
    'http://localhost:8000/query',
    json={'question': 'What is this about?', 'n_results': 5}
)
print(response.json()['response'])
```

---

## 🔍 Troubleshooting

### "Document not found" when checking status
**Cause**: Document ID doesn't exist or hasn't been created in DynamoDB yet
**Solution**: Wait a few seconds after upload, S3 event processing takes time

### Async mode falls back to sync
**Cause**: S3 not configured or `USE_S3_UPLOAD=false`
**Solution**: Set environment variables and ensure AWS credentials are configured

### Status stuck at "uploaded"
**Cause**: Chunker Lambda not triggered or failed
**Solution**: Check CloudWatch logs: `/aws/lambda/rag-demo-chunker`

### Status stuck at "chunked"
**Cause**: Embedder Lambda not processing chunks
**Solution**: Check CloudWatch logs: `/aws/lambda/rag-demo-embedder`

---

## 📚 Related Documentation

- **Deployment Flow**: `docs/DEPLOYMENT-AND-PROCESSING-FLOW.md`
- **Lambda Deployment**: `docs/LAMBDA-DEPLOYMENT.md`
- **GitHub Actions**: `docs/GITHUB-ACTIONS-SETUP.md`

