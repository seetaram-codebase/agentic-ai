# Complete Deployment and Processing Flow

## 📦 **Lambda Deployment Process**

### **How Chunker and Embedder are Deployed**

The Lambda functions use a **two-stage deployment approach**:

#### **Stage 1: Infrastructure Creation (Terraform)**

When you run Terraform:

```bash
# Via GitHub Actions
Actions → Infrastructure - Terraform → Run workflow
  Action: apply
```

**What Terraform Creates**:
```
✅ Lambda Function: rag-demo-chunker (with placeholder code)
   - IAM Role: lambda_execution
   - CloudWatch Log Group: /aws/lambda/rag-demo-chunker
   - SQS Trigger: document-chunking queue → Chunker Lambda
   
✅ Lambda Function: rag-demo-embedder (with placeholder code)
   - IAM Role: lambda_execution
   - CloudWatch Log Group: /aws/lambda/rag-demo-embedder
   - SQS Trigger: document-embedding queue → Embedder Lambda
```

**Placeholder Code**:
```python
def lambda_handler(event, context):
    return {'statusCode': 200, 'body': 'Placeholder - deploy via CI/CD'}
```

#### **Stage 2: Code Deployment (GitHub Actions)**

When you run Lambda Deploy workflow:

```bash
# Via GitHub Actions
Actions → Deploy Lambda Functions → Run workflow
  Function: both
```

**What Happens**:

1. **For Chunker Lambda**:
   ```bash
   cd lambda/chunker
   
   # Install Python dependencies in package/
   pip install -r requirements.txt -t package/
   # Installs: langchain, pypdf, tiktoken, boto3
   
   # Copy handler code
   cp handler.py package/
   
   # Create ZIP file (35-40 MB with dependencies)
   cd package
   zip -r ../chunker.zip .
   
   # Deploy to AWS Lambda
   aws lambda update-function-code \
     --function-name rag-demo-chunker \
     --zip-file fileb://../chunker.zip
   ```

2. **For Embedder Lambda**:
   ```bash
   cd lambda/embedder
   
   # Install Python dependencies in package/
   pip install -r requirements.txt -t package/
   # Installs: langchain, langchain-openai, chromadb, boto3
   
   # Copy handler code
   cp handler.py package/
   
   # Create ZIP file (45-50 MB with dependencies)
   cd package
   zip -r ../embedder.zip .
   
   # Deploy to AWS Lambda
   aws lambda update-function-code \
     --function-name rag-demo-embedder \
     --zip-file fileb://../embedder.zip
   ```

**GitHub Actions Workflow** (`deploy-lambda.yml`):
```yaml
- name: Package and Deploy Chunker Lambda
  run: |
    cd lambda/chunker
    pip install -r requirements.txt -t package/
    cp handler.py package/
    cd package
    zip -r ../chunker.zip .
    
    aws lambda update-function-code \
      --function-name rag-demo-chunker \
      --zip-file fileb://../chunker.zip
```

---

## 🔄 **Document Upload Processing Flow**

### **Architecture: Two Processing Modes**

Your system supports **TWO ways** to process documents:

#### **Mode 1: Synchronous Processing (Direct in Backend)**
**Current Implementation** - Fast but blocks the API

#### **Mode 2: Asynchronous Processing (S3 + Lambda)**
**Recommended Architecture** - Scalable and non-blocking

---

### **Mode 1: Current Synchronous Flow**

```
┌─────────────┐
│   User/UI   │
└──────┬──────┘
       │ POST /upload (file)
       ↓
┌─────────────────────┐
│  FastAPI Backend    │
│  (ECS Fargate)      │
└──────┬──────────────┘
       │ 1. Receive file
       │ 2. Save to temp location
       │ 3. Load document (PyPDFLoader/TextLoader)
       │ 4. Chunk text (RecursiveCharacterTextSplitter)
       │ 5. Generate embeddings (Azure OpenAI)
       │ 6. Store in vector DB (Chroma)
       │ 7. Return response
       ↓
┌─────────────┐
│   Response  │
│   (Success) │
└─────────────┘
```

**Code Path**:
```python
# backend/app/main.py
@app.post("/upload")
async def upload_document(file: UploadFile):
    # 1. Save file to temp location
    with tempfile.NamedTemporaryFile() as tmp:
        tmp.write(await file.read())
        
        # 2. Process synchronously in backend
        rag = get_rag()
        result = rag.process_file(tmp.name, file.filename)
        # ^ This does: load → chunk → embed → store
        
    return result
```

**Issues with this approach**:
- ❌ Blocks API during processing (can take 10-60 seconds)
- ❌ Limited by ECS memory/CPU
- ❌ Can't scale independently
- ❌ Doesn't use the Lambda architecture

---

### **Mode 2: Async S3 + Lambda Flow (RECOMMENDED)**

```
┌─────────────┐
│   User/UI   │
└──────┬──────┘
       │ POST /upload (file)
       ↓
┌─────────────────────┐
│  FastAPI Backend    │ 
│  (ECS Fargate)      │
│                     │
│  1. Upload to S3    │──────────┐
│  2. Return 202      │          │
│     (Accepted)      │          │
└─────────────────────┘          │
                                 ↓
                        ┌─────────────────┐
                        │   S3 Bucket     │
                        │   uploads/      │
                        └────────┬────────┘
                                 │ S3 Event Notification
                                 ↓
                        ┌─────────────────┐
                        │  SQS Queue      │
                        │  (chunking)     │
                        └────────┬────────┘
                                 │ Trigger
                                 ↓
                        ┌─────────────────┐
                        │  Chunker Lambda │
                        │                 │
                        │  1. Download    │
                        │  2. Load (PDF)  │
                        │  3. Chunk text  │
                        │  4. Save to DDB │
                        │  5. Send to SQS │
                        └────────┬────────┘
                                 │ Chunks
                                 ↓
                        ┌─────────────────┐
                        │  SQS Queue      │
                        │  (embedding)    │
                        └────────┬────────┘
                                 │ Trigger
                                 ↓
                        ┌─────────────────┐
                        │ Embedder Lambda │
                        │                 │
                        │  1. Get chunk   │
                        │  2. Generate    │
                        │     embedding   │
                        │  3. Store in    │
                        │     vector DB   │
                        │  4. Update DDB  │
                        └─────────────────┘
```

**Processing Steps**:

1. **User uploads document via API**
   ```http
   POST /upload
   Content-Type: multipart/form-data
   
   file: document.pdf
   ```

2. **Backend uploads to S3**
   ```python
   # backend/app/main.py (NEEDS TO BE ADDED)
   @app.post("/upload")
   async def upload_document(file: UploadFile):
       # Upload to S3 bucket
       s3_key = f"uploads/{uuid.uuid4()}_{file.filename}"
       s3_client.upload_fileobj(file.file, S3_BUCKET, s3_key)
       
       # Return immediately - processing happens async
       return {
           "status": "processing",
           "document_id": doc_id,
           "message": "Document uploaded and queued for processing"
       }
   ```

3. **S3 triggers SQS notification**
   - S3 bucket has event notification configured (done by Terraform)
   - When file lands in `uploads/` folder → sends message to SQS

4. **SQS triggers Chunker Lambda**
   ```python
   # lambda/chunker/handler.py
   def lambda_handler(event, context):
       # Get S3 event from SQS message
       bucket = event['Records'][0]['s3']['bucket']['name']
       key = event['Records'][0]['s3']['object']['key']
       
       # Download file from S3
       s3.download_fileobj(bucket, key, tmp_file)
       
       # Load document (PyPDFLoader/TextLoader)
       documents = load_document(tmp_file, key)
       
       # Chunk with tiktoken
       chunks = chunk_documents(documents)
       # Uses: RecursiveCharacterTextSplitter.from_tiktoken_encoder()
       
       # Save metadata to DynamoDB
       save_document_metadata(document_id, chunk_count, status='chunked')
       
       # Send each chunk to embedding queue
       for chunk in chunks:
           sqs.send_message(
               QueueUrl=EMBEDDING_QUEUE_URL,
               MessageBody=json.dumps({
                   'document_id': document_id,
                   'chunk': chunk
               })
           )
   ```

5. **SQS triggers Embedder Lambda (for each chunk)**
   ```python
   # lambda/embedder/handler.py
   def lambda_handler(event, context):
       # Get chunk from SQS message
       chunk = event['Records'][0]['body']['chunk']
       
       # Get Azure OpenAI config from SSM/DynamoDB
       azure_config = get_azure_config()
       
       # Generate embedding
       embedding = embedding_model.embed_query(chunk['text'])
       
       # Store in vector database (Chroma/Pinecone)
       vector_store.add(
           text=chunk['text'],
           embedding=embedding,
           metadata=chunk['metadata']
       )
       
       # Update progress in DynamoDB
       update_document_progress(document_id)
   ```

6. **User can check status**
   ```http
   GET /documents/{document_id}/status
   
   Response:
   {
       "document_id": "abc123",
       "status": "processing",
       "chunks_total": 25,
       "chunks_embedded": 18,
       "progress": 72
   }
   ```

---

## 📊 **Comparison: Sync vs Async**

| Aspect | Sync (Current) | Async (Lambda) |
|--------|----------------|----------------|
| **Response Time** | 10-60 seconds | < 1 second (202 Accepted) |
| **Scalability** | Limited by ECS | Auto-scales with Lambda |
| **Cost** | ECS runs 24/7 | Pay per execution |
| **User Experience** | Blocks/waits | Upload and continue |
| **Large Files** | Can timeout | Handles any size |
| **Concurrent Uploads** | Limited | Unlimited |

---

## 🛠️ **Implementation Status**

### ✅ What's Already Configured

1. **Terraform Infrastructure**:
   - ✅ S3 bucket with event notifications
   - ✅ SQS queues (chunking + embedding)
   - ✅ Lambda functions (chunker + embedder)
   - ✅ DynamoDB tables (config + documents)
   - ✅ IAM roles and permissions

2. **Lambda Functions**:
   - ✅ Chunker code (complete, ready to deploy)
   - ✅ Embedder code (complete, ready to deploy)
   - ✅ Deployment workflow (GitHub Actions)

3. **Backend API**:
   - ✅ Health/ready endpoints
   - ✅ Sync upload endpoint (current)
   - ❌ S3 upload endpoint (MISSING)
   - ❌ Status check endpoint (MISSING)

### ⚠️ What Needs to be Added

To enable the async Lambda flow, the backend needs:

1. **S3 Upload Functionality**
2. **Status Check Endpoint**
3. **Document Listing Endpoint**

---

## 🚀 **Next Steps**

I'll now update the backend to support the async S3 + Lambda architecture!

This will add:
1. S3 upload in the `/upload` endpoint
2. `/documents/{id}/status` endpoint to check processing status
3. `/documents` endpoint to list all documents

Would you like me to implement this now?

