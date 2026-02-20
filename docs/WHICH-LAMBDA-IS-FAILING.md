# Which Lambda is Failing? - Complete Diagnostic Report

## Quick Answer

**BOTH Lambdas are likely failing** - but the **Chunker Lambda** is the first one you need to fix.

### The Processing Flow

```
1. User uploads file via UI/API
   ↓
2. Backend uploads to S3 (s3://bucket/uploads/document.txt)
   ↓
3. S3 Event Notification triggers SQS message → Chunking Queue
   ↓
4. 🔴 CHUNKER LAMBDA (FAILING HERE) ← You are stuck here
   ↓
5. Chunker processes document → sends chunks to Embedding Queue
   ↓
6. 🔴 EMBEDDER LAMBDA (Not reached yet)
   ↓
7. Embedder generates embeddings → stores in Pinecone
   ↓
8. Document ready for queries
```

---

## The Two Lambda Functions

### Lambda 1: Chunker (THE PROBLEM)

**Function Name:** `rag-demo-chunker`

**What it does:**
- Triggered by: S3 event via SQS (when file uploaded to `uploads/` folder)
- Downloads document from S3
- Splits document into chunks using `RecursiveCharacterTextSplitter`
- Updates DynamoDB with chunk count
- Sends each chunk to Embedding Queue

**Current Status:** ❌ **NOT PROCESSING**

**Evidence:**
- Your document shows: `"uploaded"` status with 0% progress
- Hint message: "Document uploaded to S3, waiting for chunking to begin..."
- `chunk_count` = 0 (chunks never created)
- Document stuck at this stage for > 1 minute

**Dependencies:**
- Python 3.11
- Libraries: langchain, tiktoken, pypdf, boto3
- Permissions: S3 read, DynamoDB write, SQS send

### Lambda 2: Embedder

**Function Name:** `rag-demo-embedder`

**What it does:**
- Triggered by: Chunking Queue (receives chunks from Chunker Lambda)
- Generates embeddings using Azure OpenAI
- Stores embeddings in Pinecone vector database
- Updates DynamoDB with progress

**Current Status:** ⏸️ **WAITING** (Can't start until Chunker works)

**Dependencies:**
- Python 3.11
- Libraries: langchain, openai, pinecone-client, boto3
- Permissions: DynamoDB write, Pinecone access, Azure OpenAI access

---

## Why Chunker Lambda is Failing

### Possible Reasons (In Order of Likelihood)

### 1. ❌ Lambda Not Deployed (MOST LIKELY)

**Check:**
```powershell
aws lambda get-function --function-name rag-demo-chunker
```

**If it returns error:** Lambda doesn't exist - need to deploy it

**Terraform shows:**
- Lambda is defined in `infrastructure/terraform/lambda.tf`
- Initial deployment creates a PLACEHOLDER with dummy code
- Real code should be deployed via GitHub Actions

**The Issue:**
The terraform creates a placeholder Lambda with this code:
```python
def lambda_handler(event, context): 
    return {'statusCode': 200, 'body': 'Placeholder - deploy via CI/CD'}
```

This placeholder does NOTHING - it just returns success without processing!

**Solution:** Deploy the actual Lambda code from `lambda/chunker/handler.py`

---

### 2. ❌ Lambda Code is Placeholder (VERY LIKELY)

Even if Lambda exists, it might still have the placeholder code.

**Check:**
```powershell
# Download current Lambda code
aws lambda get-function --function-name rag-demo-chunker --query 'Code.Location' --output text
# This gives you a URL to download the current code ZIP
```

**The Real Code Should Be:**
- Location: `lambda/chunker/handler.py`
- Size: Should be several MB (includes dependencies like langchain, tiktoken)
- Functionality: Actually processes documents

---

### 3. ❌ SQS Trigger Not Enabled

**Check:**
```powershell
aws lambda list-event-source-mappings --function-name rag-demo-chunker
```

**Expected output:**
```json
{
  "EventSourceArn": "arn:aws:sqs:...rag-demo-document-chunking",
  "FunctionArn": "arn:aws:lambda:...rag-demo-chunker",
  "State": "Enabled",
  "BatchSize": 1
}
```

**If State is "Disabled":** Enable it
**If no mapping exists:** Terraform didn't create it properly

---

### 4. ❌ S3 Event Notification Not Configured

**Check:**
```powershell
aws s3api get-bucket-notification-configuration --bucket rag-demo-documents-[ACCOUNT_ID]
```

**Expected:**
Should show queue notifications for `.txt` and `.pdf` files in `uploads/` prefix

**If missing:** S3 isn't sending messages to SQS, so Lambda never gets triggered

---

### 5. ❌ Lambda Execution Errors

**Check CloudWatch Logs:**
```powershell
aws logs tail /aws/lambda/rag-demo-chunker --since 10m --follow
```

**Common errors:**
- **Import errors:** Missing dependencies (langchain, tiktoken, etc.)
- **Permission denied:** Can't read from S3 or write to DynamoDB
- **Timeout:** Lambda timeout too short (should be 300 seconds)
- **Memory error:** Not enough memory (should be 512MB+)

---

### 6. ❌ IAM Permissions Missing

The Lambda needs these permissions:

**S3:**
- `s3:GetObject` - Download documents from bucket

**SQS:**
- `sqs:ReceiveMessage` - Read from chunking queue
- `sqs:DeleteMessage` - Remove processed messages
- `sqs:SendMessage` - Send chunks to embedding queue

**DynamoDB:**
- `dynamodb:PutItem` - Create document record
- `dynamodb:UpdateItem` - Update chunk count

**CloudWatch:**
- `logs:CreateLogGroup`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

**Check:**
```powershell
aws iam get-role-policy --role-name rag-demo-lambda-execution --policy-name rag-demo-lambda-policy
```

---

## How to Diagnose (Step-by-Step)

### Step 1: Check if Lambda Exists

```powershell
# List all Lambda functions
aws lambda list-functions --query "Functions[?contains(FunctionName, 'rag')].FunctionName"
```

**Expected:** Should show `rag-demo-chunker` and `rag-demo-embedder`

---

### Step 2: Check Lambda Configuration

```powershell
# Get Lambda details
aws lambda get-function-configuration --function-name rag-demo-chunker
```

**Check:**
- `Runtime`: Should be `python3.11`
- `Timeout`: Should be 300 (5 minutes)
- `MemorySize`: Should be 512 MB or more
- `Environment Variables`: Should include:
  - `DYNAMODB_DOCUMENTS_TABLE`
  - `EMBEDDING_QUEUE_URL`
  - `S3_BUCKET`

---

### Step 3: Check SQS Queue

```powershell
# Get chunking queue URL
aws sqs list-queues --queue-name-prefix rag-demo-document-chunking

# Check if messages are stuck in queue
aws sqs get-queue-attributes \
  --queue-url [QUEUE_URL] \
  --attribute-names ApproximateNumberOfMessages
```

**If messages > 0:** Lambda is not processing them (Lambda issue)
**If messages = 0:** Either S3 isn't sending, or Lambda processed them (but didn't work)

---

### Step 4: Check S3 Notifications

```powershell
# Check bucket notification configuration
aws s3api get-bucket-notification-configuration \
  --bucket rag-demo-documents-[ACCOUNT_ID]
```

**Should show:** Queue configurations for `.txt` and `.pdf` files

---

### Step 5: Check CloudWatch Logs

```powershell
# Tail Lambda logs in real-time
aws logs tail /aws/lambda/rag-demo-chunker --since 30m --follow
```

**Look for:**
- Invocation logs (Lambda being called)
- Error messages
- Import errors
- Timeout warnings

---

### Step 6: Manually Test Lambda

```powershell
# Create test event
$testEvent = @{
    Records = @(
        @{
            s3 = @{
                bucket = @{ name = "rag-demo-documents-[ACCOUNT_ID]" }
                object = @{ key = "uploads/6058ee32-f80b-40_yourfile.txt" }
            }
        }
    )
} | ConvertTo-Json -Depth 10

# Invoke Lambda with test event
aws lambda invoke \
  --function-name rag-demo-chunker \
  --payload $testEvent \
  output.json

# Check response
Get-Content output.json
```

**If it works:** SQS trigger is the problem
**If it fails:** Lambda code or permissions issue

---

## How to Fix

### Fix Option 1: Deploy Lambda Code via GitHub Actions (RECOMMENDED)

The proper way is to use the CI/CD pipeline:

1. **Check if GitHub Actions workflow exists:**
   ```
   .github/workflows/deploy-lambda-chunker.yml
   .github/workflows/deploy-lambda-embedder.yml
   ```

2. **Trigger deployment:**
   - Push to `main` branch, OR
   - Manually trigger workflow from GitHub Actions tab

3. **Workflow will:**
   - Install dependencies
   - Create deployment package (ZIP with code + dependencies)
   - Upload to Lambda

---

### Fix Option 2: Manual Deployment (QUICK FIX)

Deploy Lambda manually:

```powershell
# Navigate to lambda directory
cd C:\Users\seeta\IdeaProjects\agentic-ai\lambda\chunker

# Install dependencies
pip install -r requirements.txt -t package/

# Copy handler
Copy-Item handler.py package/

# Create ZIP
Compress-Archive -Path package\* -DestinationPath chunker.zip

# Upload to Lambda
aws lambda update-function-code `
  --function-name rag-demo-chunker `
  --zip-file fileb://chunker.zip

# Wait for update to complete
aws lambda wait function-updated --function-name rag-demo-chunker

Write-Host "Lambda deployed successfully!"
```

Repeat for embedder Lambda.

---

### Fix Option 3: Enable SQS Trigger (If Disabled)

```powershell
# List event source mappings
$mappings = aws lambda list-event-source-mappings --function-name rag-demo-chunker | ConvertFrom-Json

# Get UUID of first mapping
$uuid = $mappings.EventSourceMappings[0].UUID

# Enable it
aws lambda update-event-source-mapping --uuid $uuid --enabled
```

---

### Fix Option 4: Check S3 Notifications

```powershell
# Apply S3 notification configuration
# (This should be done by Terraform, but can be manual)

# First, ensure SQS queue policy allows S3
aws sqs get-queue-attributes \
  --queue-url [QUEUE_URL] \
  --attribute-names Policy

# Then configure S3 notification via Terraform
cd infrastructure/terraform
terraform apply -target=aws_s3_bucket_notification.document_upload
```

---

## Verification Steps

After fixing, verify it works:

### 1. Upload a Test File

```powershell
# Upload via API
Invoke-WebRequest `
  -Uri "http://54.89.155.20:8000/upload" `
  -Method POST `
  -InFile "test.txt"
```

### 2. Check CloudWatch Logs Immediately

```powershell
# Should see Lambda invocation within seconds
aws logs tail /aws/lambda/rag-demo-chunker --since 1m --follow
```

**Expected output:**
```
START RequestId: abc-123...
Downloading document from S3...
Chunking document...
Created 15 chunks
Sending chunks to embedding queue...
END RequestId: abc-123...
REPORT Duration: 2543.21 ms Memory Used: 187 MB
```

### 3. Check DynamoDB

```powershell
# Check if chunk_count was updated
aws dynamodb get-item \
  --table-name rag-demo-documents \
  --key '{"document_id": {"S": "6058ee32-f80b-40"}}'
```

**Expected:** `chunk_count` should be > 0 and `status` should be `"chunked"`

### 4. Check SQS Embedding Queue

```powershell
# Should have messages (one per chunk)
aws sqs get-queue-attributes \
  --queue-url [EMBEDDING_QUEUE_URL] \
  --attribute-names ApproximateNumberOfMessages
```

**Expected:** Number of messages = chunk_count

---

## Summary

### The Problem
Your document processing is stuck at **Stage 1: Chunking**

### The Culprit
**Chunker Lambda** is not processing documents because:
1. It probably only has placeholder code (not the real implementation)
2. OR it's not deployed at all
3. OR the SQS trigger is disabled

### The Fix
1. **Deploy the Lambda code** from `lambda/chunker/handler.py`
2. **Verify SQS trigger** is enabled
3. **Test with a new upload**

### Once Chunker Works
Then you'll see if Embedder Lambda has issues too (but you're not there yet)

---

## Quick Diagnostic Command

Run this to check everything at once:

```powershell
# Check Lambda exists
Write-Host "`n=== CHUNKER LAMBDA ===" -ForegroundColor Cyan
try {
    $lambda = aws lambda get-function-configuration --function-name rag-demo-chunker | ConvertFrom-Json
    Write-Host "✓ Lambda exists" -ForegroundColor Green
    Write-Host "  Runtime: $($lambda.Runtime)"
    Write-Host "  Timeout: $($lambda.Timeout)s"
    Write-Host "  Memory: $($lambda.MemorySize)MB"
    Write-Host "  Code Size: $($lambda.CodeSize) bytes"
} catch {
    Write-Host "✗ Lambda not found!" -ForegroundColor Red
}

# Check SQS trigger
Write-Host "`n=== SQS TRIGGER ===" -ForegroundColor Cyan
$mappings = aws lambda list-event-source-mappings --function-name rag-demo-chunker | ConvertFrom-Json
if ($mappings.EventSourceMappings.Count -gt 0) {
    Write-Host "✓ SQS trigger configured" -ForegroundColor Green
    Write-Host "  State: $($mappings.EventSourceMappings[0].State)"
    Write-Host "  Batch Size: $($mappings.EventSourceMappings[0].BatchSize)"
} else {
    Write-Host "✗ No SQS trigger found!" -ForegroundColor Red
}

# Check recent invocations
Write-Host "`n=== RECENT INVOCATIONS ===" -ForegroundColor Cyan
aws logs tail /aws/lambda/rag-demo-chunker --since 10m | Select-Object -First 20
```

**The most likely issue:** Lambda has placeholder code and needs real deployment! 🔧

