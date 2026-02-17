# Phase 2: AWS Pipeline Integration

## 🎯 Goal
Add production-grade AWS infrastructure for document ingestion.

## Architecture

```
┌──────────────┐     ┌─────────┐     ┌─────────┐     ┌──────────────┐
│  Electron UI │────▶│   S3    │────▶│   SQS   │────▶│    Lambda    │
│  (Upload)    │     │ Bucket  │     │  Queue  │     │  (Process)   │
└──────────────┘     └─────────┘     └─────────┘     └──────────────┘
                                                            │
                                                            ▼
                                                     ┌──────────────┐
                                                     │   Pinecone/  │
                                                     │    Chroma    │
                                                     └──────────────┘
```

## AWS Services Required

| Service | Purpose | Cost/Hour |
|---------|---------|-----------|
| S3 | Document storage | ~$0.01 |
| SQS | Message queue | ~$0.01 |
| Lambda | Processing | ~$0.05 |
| API Gateway | REST API | ~$0.02 |
| CloudWatch | Monitoring | ~$0.01 |

## Implementation Steps

### Step 1: Create S3 Bucket

```bash
aws s3 mb s3://rag-demo-documents-YOUR_ID --region us-east-1
```

### Step 2: Create SQS Queue

```bash
aws sqs create-queue --queue-name rag-document-queue --region us-east-1
```

### Step 3: S3 Event Notification

Configure S3 to send events to SQS when files are uploaded:

```json
{
  "QueueConfigurations": [
    {
      "QueueArn": "arn:aws:sqs:us-east-1:ACCOUNT_ID:rag-document-queue",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {"Name": "suffix", "Value": ".pdf"},
            {"Name": "suffix", "Value": ".txt"}
          ]
        }
      }
    }
  ]
}
```

### Step 4: Lambda Function

```python
# aws/lambda/process_document/handler.py
import json
import boto3
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.document_loaders import S3FileLoader

def handler(event, context):
    for record in event['Records']:
        body = json.loads(record['body'])
        bucket = body['Records'][0]['s3']['bucket']['name']
        key = body['Records'][0]['s3']['object']['key']
        
        # Load document from S3
        loader = S3FileLoader(bucket, key)
        documents = loader.load()
        
        # Chunk documents
        splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200
        )
        chunks = splitter.split_documents(documents)
        
        # Send to vector store (via another Lambda or direct)
        # ... embedding and storage logic
        
    return {'statusCode': 200}
```

### Step 5: Lambda Layer for Dependencies

```bash
# Create layer with dependencies
pip install -t python/ langchain chromadb openai boto3
zip -r layer.zip python/
aws lambda publish-layer-version \
    --layer-name rag-dependencies \
    --zip-file fileb://layer.zip \
    --compatible-runtimes python3.11
```

## Terraform/CDK (Optional)

For reproducible infrastructure, use CDK:

```typescript
// aws/cdk/lib/rag-stack.ts
import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as sqs from 'aws-cdk-lib/aws-sqs';
import * as lambda from 'aws-cdk-lib/aws-lambda';

export class RagStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string) {
    super(scope, id);
    
    const bucket = new s3.Bucket(this, 'DocumentBucket');
    const queue = new sqs.Queue(this, 'ProcessingQueue');
    // ... Lambda, API Gateway, etc.
  }
}
```

## Testing the Pipeline

```bash
# Upload a test document
aws s3 cp test.pdf s3://rag-demo-documents-YOUR_ID/

# Check SQS for messages
aws sqs receive-message --queue-url YOUR_QUEUE_URL

# Check Lambda logs
aws logs tail /aws/lambda/rag-processor --follow
```

## ✅ Phase 2 Checklist

- [ ] S3 bucket created
- [ ] SQS queue created
- [ ] S3 → SQS event notification configured
- [ ] Lambda function deployed
- [ ] End-to-end test passed
