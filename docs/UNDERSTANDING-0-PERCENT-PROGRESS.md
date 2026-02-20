# Understanding 0% Progress

## What Does 0% Progress Mean?

When you see **Progress: 0%**, it means **no chunks have been embedded yet**, but this is completely normal! Your document is still being processed.

## The Processing Pipeline

Here's what happens when you upload a document:

```
1. Upload (0% progress)
   └─> File uploaded to S3
   
2. Chunking (0% progress)
   └─> Document split into text chunks
   └─> Status: "uploaded" → "chunked"
   
3. Embedding Starts (1-99% progress)
   └─> Each chunk gets embedded
   └─> Status: "embedding"
   └─> Progress increases as chunks complete
   
4. Complete (100% progress)
   └─> All chunks embedded
   └─> Status: "completed"
   └─> Ready for queries!
```

## Why 0% Progress Happens

### Scenario 1: Just Uploaded (Status: "uploaded")
- **What's happening**: Document just uploaded to S3
- **Next step**: Lambda chunking function will pick it up from SQS
- **Time**: Usually 2-5 seconds
- **Progress**: Will stay at 0% until chunking completes

### Scenario 2: Being Chunked (Status: "chunked")
- **What's happening**: Document split into chunks, metadata saved to DynamoDB
- **Next step**: Embedding Lambda will start processing chunks
- **Time**: Usually 1-3 seconds before first chunk embedding starts
- **Progress**: Will stay at 0% until first chunk is embedded

### Scenario 3: First Embeddings Processing
- **What's happening**: Embedding Lambda is processing the first chunks
- **Next step**: Progress will jump to 4-20% as first batch completes
- **Time**: First embeddings take 3-10 seconds
- **Progress**: Will quickly move from 0% to 10-20%

## How Long Should I Wait?

### Normal Wait Times at 0%

| Document Size | Expected 0% Duration | When to Worry |
|---------------|---------------------|---------------|
| Small (1-5 pages) | 5-15 seconds | > 1 minute |
| Medium (10-20 pages) | 10-30 seconds | > 2 minutes |
| Large (50+ pages) | 15-45 seconds | > 3 minutes |

### What If It's Stuck?

If progress stays at 0% for longer than expected:

1. **Check the status field**:
   - `uploaded` stuck? → Chunking Lambda may not be running
   - `chunked` stuck? → Embedding Lambda may not be running

2. **Refresh the UI** - Sometimes the polling might pause

3. **Check backend health**:
   ```powershell
   Invoke-WebRequest http://localhost:8000/health
   ```

4. **Query the status directly**:
   ```powershell
   $docId = "your-document-id"
   Invoke-WebRequest "http://localhost:8000/documents/$docId/status" | Select-Object -Expand Content
   ```

5. **Check AWS CloudWatch Logs**:
   - Chunking Lambda logs
   - Embedder Lambda logs
   - Look for errors or timeouts

## Expected Progress Flow

Here's what you should see for a typical 25-chunk document:

```
Time  | Status    | Progress | Chunks Embedded
------|-----------|----------|-----------------
0s    | uploaded  | 0%       | 0/0   (no chunks yet)
3s    | chunked   | 0%       | 0/25  (chunks created, waiting)
6s    | embedding | 0%       | 0/25  (first batch starting)
10s   | embedding | 20%      | 5/25  (first batch done)
15s   | embedding | 48%      | 12/25 (parallel processing)
20s   | embedding | 76%      | 19/25 (almost done)
24s   | embedding | 100%     | 25/25 (last chunk)
25s   | completed | 100%     | 25/25 (ready!)
```

## Understanding the UI

When you see this in the UI:

```
⏳ Processing Documents

📄 latest_news_file.txt                    [chunked]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Progress: 0%          Chunks: 0 / 25

ℹ️ Document chunked into 25 pieces, waiting for embedding to start...

ID: b26fc7a6-d57f-46
```

This means:
- ✅ Upload successful
- ✅ Chunking complete (25 chunks created)
- ⏳ Waiting for embedding to start (0 chunks embedded)
- ⏱️ Should start processing within 1-5 seconds

## Common Questions

### Q: Why does it take so long to start?
**A:** The system uses SQS queues and Lambda functions. There's a small delay as:
1. SQS delivers the message to Lambda (~1-2 seconds)
2. Lambda cold start if needed (~2-5 seconds first time)
3. Lambda fetches document from S3 (~1 second)
4. Lambda processes and sends to next queue (~1 second)

### Q: Can I speed this up?
**A:** The initial 0% phase is mostly infrastructure overhead. Once embedding starts, it's parallelized and very fast. The delays are minimal compared to the value of having a scalable, serverless architecture.

### Q: Is my document lost if it's stuck at 0%?
**A:** No! Your document is safely stored in S3. You can:
- Retry the upload
- Check CloudWatch logs to see what happened
- Use the document ID to trace it through the system

### Q: When can I start querying?
**A:** Wait until:
- Progress shows 100%, OR
- Status shows "completed"

You CAN query before 100%, but results will only include the chunks that have been embedded so far.

## Technical Details

### How Progress is Calculated

```python
if chunk_count > 0:
    progress = int((chunks_embedded / chunk_count) * 100)
else:
    progress = 0
```

- `chunk_count`: Total chunks created during chunking phase
- `chunks_embedded`: Number of chunks successfully embedded
- Progress: Percentage of chunks embedded

### Why Progress Stays at 0%

1. **No chunks created yet** (`chunk_count = 0`)
   - Still in upload/chunking phase
   - DynamoDB record exists but chunks not counted yet

2. **Chunks created but none embedded** (`chunk_count = 25, chunks_embedded = 0`)
   - Chunking complete
   - Embedding hasn't started or first batch still processing

3. **DynamoDB not updated yet**
   - Embedding may have started but hasn't written progress yet
   - First update comes when first chunk completes

## Monitoring Tools

### Real-time Status Check Script

Save this as `check-status.ps1`:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$DocumentId,
    [string]$ApiUrl = "http://localhost:8000"
)

Write-Host "Monitoring document: $DocumentId" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Yellow

while ($true) {
    try {
        $response = Invoke-RestMethod -Uri "$ApiUrl/documents/$DocumentId/status"
        $timestamp = Get-Date -Format "HH:mm:ss"
        
        $statusColor = switch ($response.status) {
            "completed" { "Green" }
            "embedding" { "Yellow" }
            "error" { "Red" }
            default { "White" }
        }
        
        Write-Host "[$timestamp] " -NoNewline
        Write-Host "$($response.status) " -ForegroundColor $statusColor -NoNewline
        Write-Host "| Progress: $($response.progress)% | Chunks: $($response.chunks_embedded)/$($response.chunk_count)"
        
        if ($response.status -eq "completed" -or $response.status -eq "error") {
            Write-Host "`nProcessing finished!" -ForegroundColor Green
            break
        }
    }
    catch {
        Write-Host "Error checking status: $_" -ForegroundColor Red
    }
    
    Start-Sleep -Seconds 3
}
```

Usage:
```powershell
.\check-status.ps1 -DocumentId "b26fc7a6-d57f-46"
```

## Summary

**0% progress is normal** during the initial upload and chunking phases. Here's what to remember:

✅ **Normal**: 0% for 5-30 seconds after upload
✅ **Watch**: Status field changing from "uploaded" → "chunked" → "embedding"
✅ **Wait**: Until progress reaches 100% or status is "completed"
⚠️ **Investigate**: If stuck at 0% for > 2 minutes
❌ **Don't worry**: Your document is safe in S3 even if processing pauses

The UI now shows helpful hints explaining what's happening at each stage!

