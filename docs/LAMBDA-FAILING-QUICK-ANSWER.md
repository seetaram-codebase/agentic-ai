# Quick Answer: Which Lambda is Failing?

## TL;DR

**The CHUNKER Lambda (`rag-demo-chunker`) is failing.**

Your document is stuck at the very first processing stage because the Chunker Lambda is either:
1. Not deployed (only exists as placeholder), OR
2. Not being triggered by SQS

## Evidence

- Document status: `"uploaded"` with 0% progress
- UI hint: "Document uploaded to S3, waiting for chunking to begin..."
- `chunk_count` = 0 (no chunks created)
- Stuck for > 1 minute

## The Processing Pipeline

```
✅ User Upload → Backend → S3
✅ S3 Event → SQS Chunking Queue
❌ SQS → CHUNKER LAMBDA ← STUCK HERE
⏸️  Chunker → SQS Embedding Queue (not reached)
⏸️  SQS → EMBEDDER LAMBDA (not reached)
⏸️  Embedder → Pinecone (not reached)
```

## What the Chunker Lambda Should Do

1. Receive S3 event from SQS queue
2. Download document from S3
3. Split into chunks using `RecursiveCharacterTextSplitter`
4. Update DynamoDB: `chunk_count`, status = `"chunked"`
5. Send each chunk to Embedding Queue

**Currently doing:** NOTHING (placeholder code or not triggered)

## Run This to Diagnose

```powershell
# Quick diagnostic
cd C:\Users\seeta\IdeaProjects\agentic-ai
.\scripts\diagnose-lambda.ps1
```

This will tell you:
- ✓/✗ If Lambda exists
- ✓/✗ If it has real code (or placeholder)
- ✓/✗ If SQS trigger is enabled
- ✓/✗ If it's been invoked recently
- ✓/✗ If there are any errors

## Most Likely Problem

**Terraform created the Lambda with PLACEHOLDER code that does nothing:**

```python
# This is what's probably deployed (USELESS)
def lambda_handler(event, context): 
    return {'statusCode': 200, 'body': 'Placeholder - deploy via CI/CD'}
```

**What SHOULD be deployed:**
- Real code from `lambda/chunker/handler.py`
- With dependencies: langchain, tiktoken, pypdf, boto3
- Several MB in size

## How to Fix

### Quick Fix: Deploy Lambda Code Manually

```powershell
cd C:\Users\seeta\IdeaProjects\agentic-ai\lambda\chunker

# Install dependencies
pip install -r requirements.txt -t package/

# Copy handler
Copy-Item handler.py package/

# Create ZIP
Compress-Archive -Path package\* -DestinationPath chunker.zip -Force

# Upload to Lambda
aws lambda update-function-code `
  --function-name rag-demo-chunker `
  --zip-file fileb://chunker.zip

# Wait for update
aws lambda wait function-updated --function-name rag-demo-chunker

Write-Host "✅ Chunker Lambda deployed!" -ForegroundColor Green
```

### Verify It Works

After deploying, upload a new document and check:

```powershell
# Monitor Lambda logs in real-time
aws logs tail /aws/lambda/rag-demo-chunker --since 1m --follow
```

**You should see:**
- Lambda being invoked
- "Downloading document from S3..."
- "Created X chunks"
- "Sending to embedding queue..."

## Next Steps

Once Chunker works, you'll need to deploy Embedder Lambda too (same process).

## Documentation

- **Full analysis:** `docs/WHICH-LAMBDA-IS-FAILING.md`
- **Status tracking:** `docs/DOCUMENT-STATUS-TRACKING.md`
- **Diagnostic script:** `scripts/diagnose-lambda.ps1`

