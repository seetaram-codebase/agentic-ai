# Document Status Tracking Guide

## Overview
When you upload a document, it goes through several processing stages before it's ready for querying. This guide explains how to track the processing status.

## Processing Stages

Documents go through these stages:

1. **uploaded** - File uploaded to S3, waiting for chunking
2. **chunked** - Document has been split into chunks, waiting for embedding
3. **embedding** - Embeddings are being generated for the chunks
4. **completed** - All chunks have been embedded and indexed, ready for queries
5. **error** - Processing failed at some stage

## How to Check Status

### Option 1: Using the UI (Recommended)

The Electron UI now automatically tracks document processing status:

1. **Upload a document** - Drag and drop or click to select a file
2. **Watch the "Processing Documents" section** - This will appear automatically below the upload area
3. **Monitor progress** - You'll see:
   - Document filename
   - Current status badge (color-coded)
   - Progress bar (0-100%)
   - Chunk progress (e.g., "18 / 25 chunks")
4. **Wait for completion** - The document will automatically disappear from the processing list when done

**Status Badge Colors:**
- 🔵 Blue = `uploaded` (just started)
- 🟠 Orange = `chunked` (chunks created)
- 🟡 Yellow = `embedding` (actively processing - animated)
- 🟢 Green = `completed` (ready to query!)
- 🔴 Red = `error` (something went wrong)

The UI polls the backend every 3 seconds to update the status automatically.

### Option 2: Using the API Directly

If you're testing via command line or want to integrate with other tools:

**1. Upload a document and note the document ID:**
```bash
curl -X POST http://localhost:8000/upload \
  -F "file=@your-document.pdf"
```

Response:
```json
{
  "filename": "your-document.pdf",
  "document_id": "b26fc7a6-d57f-46",
  "status": "processing",
  "message": "Document uploaded and queued for processing. Check status at /documents/b26fc7a6-d57f-46/status"
}
```

**2. Check the status using the document ID:**
```bash
curl http://localhost:8000/documents/b26fc7a6-d57f-46/status
```

Response:
```json
{
  "document_id": "b26fc7a6-d57f-46",
  "document_key": "uploads/b26fc7a6-d57f-46_latest_news_file.txt",
  "status": "embedding",
  "chunk_count": 25,
  "chunks_embedded": 18,
  "progress": 72,
  "created_at": 1708214400,
  "updated_at": 1708214460
}
```

**3. Keep checking until status is "completed":**

You can use a simple polling script:
```bash
# PowerShell
$docId = "b26fc7a6-d57f-46"
while ($true) {
    $status = (curl http://localhost:8000/documents/$docId/status | ConvertFrom-Json)
    Write-Host "Status: $($status.status) - Progress: $($status.progress)%"
    if ($status.status -eq "completed" -or $status.status -eq "error") {
        break
    }
    Start-Sleep -Seconds 3
}
```

## Understanding Progress

### Progress Percentage
The `progress` field shows what percentage of chunks have been embedded:
- `0%` - Just uploaded, no chunks embedded yet
- `50%` - Half of the chunks have been embedded
- `100%` - All chunks embedded, document ready for queries

### Chunk Count vs Chunks Embedded
- `chunk_count`: Total number of text chunks the document was split into
- `chunks_embedded`: Number of chunks that have been processed and embedded
- When `chunks_embedded == chunk_count`, processing is complete

## Typical Processing Times

Processing time depends on document size:

- **Small document** (1-5 pages, ~5 chunks): ~5-15 seconds
- **Medium document** (10-20 pages, ~20 chunks): ~30-60 seconds
- **Large document** (50+ pages, ~100 chunks): ~2-5 minutes

Lambda functions process chunks in parallel, so larger documents don't scale linearly.

## Troubleshooting

### Status stuck at "uploaded"
- **Cause**: SQS chunking queue might not be processing
- **Check**: Verify Lambda chunking function is running
- **Logs**: Check CloudWatch logs for chunking Lambda

### Status stuck at "chunked"
- **Cause**: Embedding Lambda might not be processing
- **Check**: Verify embedding Lambda is triggered for each chunk
- **Logs**: Check CloudWatch logs for embedder Lambda

### Status shows "error"
- **Check**: DynamoDB documents table for error details
- **Check**: CloudWatch logs for both Lambda functions
- **Common causes**: 
  - Invalid document format
  - Azure OpenAI rate limits
  - Pinecone connection issues
  - Lambda timeout

### Progress not updating
- **Cause**: UI might not be polling
- **Fix**: Refresh the page
- **Alternative**: Check status via API directly

## API Reference

### Get Document Status
```
GET /documents/{document_id}/status
```

**Response Fields:**
- `document_id`: Unique identifier for the document
- `document_key`: S3 key where the document is stored
- `status`: Current processing stage (see stages above)
- `chunk_count`: Total number of chunks
- `chunks_embedded`: Number of chunks processed
- `progress`: Percentage complete (0-100)
- `created_at`: Unix timestamp when document was uploaded
- `updated_at`: Unix timestamp of last status update

### List All Documents
```
GET /documents?limit=100
```

Returns all documents with their current status.

## Best Practices

1. **Wait for completion** - Don't query a document until status is "completed"
2. **Poll responsibly** - The UI polls every 3 seconds, which is reasonable
3. **Handle errors** - Check for "error" status and handle gracefully
4. **Monitor large uploads** - For large documents, expect longer processing times
5. **Check backend health** - If status isn't updating, check if backend is running

## See Also

- [API Usage Guide](./API-USAGE-GUIDE.md) - Complete API documentation
- [Document Processing Flow](./DOCUMENT-PROCESSING-FLOW.md) - Detailed processing pipeline
- [Pinecone Integration](./PINECONE-COMPLETE-FLOW.md) - How embeddings are stored

