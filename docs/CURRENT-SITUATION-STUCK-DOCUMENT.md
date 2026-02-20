# Document Processing Status - Current Situation

## Summary

Your document `latest_news_file.txt` (ID: `b26fc7a6-d57f-46`) is **stuck at the "uploaded" stage** with 0% progress.

### Current Status
- ✅ **Uploaded to S3**: Document successfully uploaded to S3 bucket
- ❌ **Chunking**: NOT started (Lambda function not processing)
- ❌ **Embedding**: Waiting for chunking to complete
- ❌ **Indexing**: Waiting for embedding to complete

### What This Means

**0% Progress + Status "uploaded" = Chunking Lambda is not processing the SQS queue**

## Why Is It Stuck?

The document is waiting for the **Chunking Lambda function** to:
1. Read the message from the SQS chunking queue
2. Download the document from S3
3. Split it into text chunks
4. Update DynamoDB with chunk count
5. Send chunks to the embedding queue

### Possible Causes

1. **Lambda Function Not Deployed**
   - The chunking Lambda may not exist in your AWS account
   - Check: AWS Lambda console for `rag-chunking-lambda`

2. **SQS Queue Not Connected**
   - Lambda may not be triggered by SQS events
   - Check: Lambda event source mapping for SQS trigger

3. **Lambda Execution Errors**
   - Function may be failing silently
   - Check: CloudWatch Logs for the chunking Lambda

4. **IAM Permissions Missing**
   - Lambda may not have permissions to read from SQS or S3
   - Check: Lambda execution role permissions

5. **Lambda Timeout/Cold Start**
   - Function may be timing out
   - Check: Lambda configuration (timeout should be 60+ seconds)

## How to Diagnose

### Step 1: Check if Lambda Exists

```powershell
# Check if chunking Lambda exists
aws lambda list-functions --query "Functions[?contains(FunctionName, 'chunking')].FunctionName"
```

Expected output:
```json
[
    "rag-chunking-lambda"
]
```

### Step 2: Check SQS Queue

```powershell
# List SQS queues
aws sqs list-queues --query "QueueUrls[?contains(@, 'chunking')]"

# Get approximate message count
$queueUrl = "YOUR_QUEUE_URL"
aws sqs get-queue-attributes --queue-url $queueUrl --attribute-names ApproximateNumberOfMessages
```

If messages are stuck in the queue, the Lambda is not processing them.

### Step 3: Check CloudWatch Logs

```powershell
# Get latest log stream for chunking Lambda
aws logs tail /aws/lambda/rag-chunking-lambda --since 10m --follow
```

Look for:
- Invocation logs
- Error messages
- Timeout warnings

### Step 4: Check Lambda Event Source

```powershell
# Check if Lambda has SQS trigger
aws lambda list-event-source-mappings --function-name rag-chunking-lambda
```

Expected: Should show an SQS queue as trigger with State: "Enabled"

### Step 5: Manually Trigger Lambda (Test)

You can test the Lambda manually through AWS Console:
1. Go to Lambda console
2. Find `rag-chunking-lambda`
3. Create test event with document info
4. Run test and check logs

## What Should Happen (Normal Flow)

### Timeline for a Small Text File (~5 chunks)

```
Time  | Action                           | Status      | Progress
------|----------------------------------|-------------|----------
0s    | Upload complete to S3            | uploaded    | 0%
1s    | SQS message sent to queue        | uploaded    | 0%
2-5s  | Lambda cold start (first time)   | uploaded    | 0%
6s    | Lambda downloads from S3         | uploaded    | 0%
7s    | Lambda chunks document           | uploaded    | 0%
8s    | Lambda updates DynamoDB          | chunked     | 0%
9s    | Lambda sends to embedding queue  | chunked     | 0%
10s   | Embedding Lambda starts          | embedding   | 0%
12s   | First chunk embedded             | embedding   | 20%
15s   | All chunks embedded              | embedding   | 100%
16s   | Status updated                   | completed   | 100%
```

### Your Current Situation (Stuck)

```
Time       | Action                           | Status      | Progress
-----------|----------------------------------|-------------|----------
0s         | Upload complete to S3            | uploaded    | 0%
1s         | SQS message sent to queue        | uploaded    | 0%
2s - NOW   | ⚠️ STUCK - Lambda not running   | uploaded    | 0%
```

## How to Fix

### Solution 1: Deploy Chunking Lambda (If Missing)

If the Lambda doesn't exist, you need to deploy it:

```powershell
# Navigate to lambda directory
cd C:\Users\seeta\IdeaProjects\agentic-ai\lambda

# Check if chunking Lambda code exists
ls chunking/

# Deploy using Terraform or AWS CLI
# (Instructions depend on your deployment method)
```

### Solution 2: Enable/Fix SQS Trigger

```powershell
# Check event source mapping
aws lambda list-event-source-mappings --function-name rag-chunking-lambda

# If disabled, enable it
aws lambda update-event-source-mapping --uuid YOUR_UUID --enabled
```

### Solution 3: Check Lambda Permissions

The Lambda execution role needs these permissions:
- `sqs:ReceiveMessage`
- `sqs:DeleteMessage`
- `sqs:GetQueueAttributes`
- `s3:GetObject`
- `dynamodb:PutItem`
- `dynamodb:UpdateItem`
- `sqs:SendMessage` (for embedding queue)

### Solution 4: Increase Lambda Timeout

```powershell
# Update Lambda timeout to 300 seconds
aws lambda update-function-configuration \
    --function-name rag-chunking-lambda \
    --timeout 300
```

### Solution 5: Check Environment Variables

The chunking Lambda needs these environment variables:
- `DYNAMODB_DOCUMENTS_TABLE`: Table name for tracking
- `SQS_EMBEDDER_QUEUE_URL`: Queue URL for sending chunks
- `S3_BUCKET_NAME`: Bucket name for downloading documents

## Immediate Actions You Can Take

### 1. Check Backend Logs

Your backend is at `http://54.89.155.20:8000`. SSH into the EC2/ECS instance and check logs:

```bash
# If using Docker
docker logs -f CONTAINER_ID

# If using systemd
journalctl -u your-service -f
```

### 2. Check AWS Console

1. **Lambda Console**: Look for `rag-chunking-lambda`
2. **CloudWatch Logs**: Check for recent invocations
3. **SQS Console**: Check if messages are stuck in queue
4. **DynamoDB**: Check documents table for your document

### 3. Re-upload the Document

As a temporary workaround, you can try re-uploading:

```powershell
# Re-upload using the UI or curl
$file = "C:\path\to\latest_news_file.txt"
curl -X POST http://54.89.155.20:8000/upload -F "file=@$file"
```

### 4. Use Sync Mode

Upload in sync mode to bypass the async processing:

```powershell
curl -X POST "http://54.89.155.20:8000/upload?mode=sync" -F "file=@latest_news_file.txt"
```

This processes the document immediately without Lambda/SQS.

## Updated Tools

### 1. UI with Status Tracking

The Electron UI now has:
- ✅ Real-time document processing status display
- ✅ Progress bar and chunk counter
- ✅ Helpful hints explaining each stage
- ✅ Auto-polling every 3 seconds
- ✅ Configurable backend URL (Settings panel)

**To use:**
1. Open the Electron UI
2. Go to Settings at the bottom
3. Set backend URL to: `http://54.89.155.20:8000`
4. Save and refresh
5. Upload a document and watch the processing status

### 2. PowerShell Status Checker

```powershell
# Check status with AWS backend
cd C:\Users\seeta\IdeaProjects\agentic-ai
.\scripts\check-document-status.ps1 -DocumentId "b26fc7a6-d57f-46" -ApiUrl "http://54.89.155.20:8000"
```

## Next Steps

1. **Verify Lambda exists**: Check AWS Lambda console
2. **Check CloudWatch Logs**: Look for errors in chunking Lambda
3. **Verify SQS queues**: Ensure messages aren't stuck
4. **Test with sync mode**: Upload a test document with `?mode=sync`
5. **Contact AWS support**: If infrastructure issue

## Understanding "Uploaded" Status

The "uploaded" status with 0% progress means:

- ✅ Your file is **safely stored in S3**
- ✅ A record exists in **DynamoDB**
- ✅ A message was sent to **SQS chunking queue**
- ❌ **Chunking Lambda has NOT processed it yet**

This is NOT a data loss issue - your document is safe. It's an infrastructure/Lambda configuration issue.

## Documentation References

- [Document Status Tracking Guide](./DOCUMENT-STATUS-TRACKING.md) - Complete status tracking guide
- [Understanding 0% Progress](./UNDERSTANDING-0-PERCENT-PROGRESS.md) - Detailed 0% progress explanation
- [Document Processing Flow](./DOCUMENT-PROCESSING-FLOW.md) - Complete processing pipeline
- [Lambda Deployment](./LAMBDA-DEPLOYMENT.md) - How to deploy Lambda functions

## Contact Points for Help

1. **Check Lambda logs first** - Most issues show up there
2. **Verify SQS queues** - See if messages are piling up
3. **Test sync mode** - Confirms backend works without Lambda
4. **Review Terraform/CloudFormation** - Ensure infrastructure is deployed

Your document is safe in S3, it's just waiting for the chunking Lambda to wake up and process it! 🚀

