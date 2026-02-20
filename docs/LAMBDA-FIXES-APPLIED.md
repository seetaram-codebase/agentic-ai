# Lambda Code Fixes - Summary

## Problem Identified

Your Lambdas ARE working and processing documents successfully (evidenced by Pinecone entries), but the **DynamoDB status tracking was broken** because:

1. **Backend** creates document with ID: `6058ee32-f80b-40` (truncated UUID)
2. **Chunker Lambda** was generating NEW ID: `f6d3023d39ad42ec` (SHA256 hash)
3. **Result**: Two different DynamoDB records, UI shows 0% but document is actually indexed in Pinecone

## Fixes Applied

### ✅ Fixed: `lambda/chunker/handler.py`

**Line ~225: Changed `generate_document_id()` function**

**Before:**
```python
def generate_document_id(bucket: str, key: str) -> str:
    """Generate a unique document ID"""
    import hashlib
    import time
    unique_string = f"{bucket}/{key}/{time.time()}"
    return hashlib.sha256(unique_string.encode()).hexdigest()[:16]
```

**After:**
```python
def generate_document_id(bucket: str, key: str) -> str:
    """
    Extract document ID from S3 key filename
    
    Backend creates keys like: uploads/{document_id}_{filename}
    e.g., uploads/6058ee32-f80b-40_latest_news_file.txt
    
    We need to extract the document_id part to match the DynamoDB record
    """
    import re
    
    # Extract filename from key (removes path)
    filename = key.split('/')[-1]
    
    # Pattern: {document_id}_{original_filename}
    # document_id is first 16 chars of UUID with hyphens: xxxxxxxx-xxxx-xx
    match = re.match(r'^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{2})', filename)
    
    if match:
        document_id = match.group(1)
        logger.info(f"Extracted document_id from S3 key: {document_id}")
        return document_id
    else:
        # Fallback: generate from hash (legacy behavior)
        logger.warning(f"Could not extract document_id from key: {key}, generating new ID")
        import hashlib
        import time
        unique_string = f"{bucket}/{key}/{time.time()}"
        return hashlib.sha256(unique_string.encode()).hexdigest()[:16]
```

**Line ~280: Changed `save_document_metadata()` function**

**Before:**
```python
def save_document_metadata(...):
    """Save document metadata to DynamoDB"""
    table.put_item(Item={
        'document_id': document_id,
        'document_key': key,
        # ... creates NEW record
    })
```

**After:**
```python
def save_document_metadata(...):
    """
    Update document metadata in DynamoDB
    
    The backend already created a record with status='uploaded'
    We need to UPDATE it, not overwrite it
    """
    table.update_item(
        Key={'document_id': document_id},
        UpdateExpression='SET chunk_count = :chunk_count, #status = :status, updated_at = :now',
        ExpressionAttributeNames={
            '#status': 'status'  # 'status' is a reserved word in DynamoDB
        },
        # ... updates EXISTING record
    )
```

### ✅ Enhanced: `lambda/embedder/handler.py`

**Line ~90-130: Better logging and error handling**

Added:
- More detailed logging showing document_id being processed
- Embedding dimension logging
- Better error handling with `exc_info=True` for stack traces
- Store success checking before updating DynamoDB

**Line ~380-420: Enhanced `update_document_progress()`**

Added:
- Better logging showing which document_id is being updated
- Progress percentage calculation and logging
- `ReturnValues='ALL_NEW'` to get updated values in one call
- Celebration emoji when document completes! 🎉
- Better error messages with document_id context

## What These Fixes Do

### Before Fixes:
```
Backend upload:
  Creates DynamoDB record: ID = "6058ee32-f80b-40", status = "uploaded"
  
Chunker Lambda:
  Generates NEW ID: "f6d3023d39ad42ec"
  Creates NEW DynamoDB record with this ID ❌
  
Embedder Lambda:
  Updates the NEW record (wrong one!) ❌
  
Result:
  Backend's record: status = "uploaded", 0% forever ❌
  Lambda's record: status = "completed", 100% (but backend doesn't know) ❌
  Pinecone: Has embeddings (working!) ✅
  UI: Shows 0% (wrong!) ❌
```

### After Fixes:
```
Backend upload:
  Creates DynamoDB record: ID = "6058ee32-f80b-40", status = "uploaded"
  
Chunker Lambda:
  Extracts ID from S3 key: "6058ee32-f80b-40" ✅
  UPDATES existing DynamoDB record ✅
  Sets chunk_count, status = "chunked"
  
Embedder Lambda:
  Uses same ID: "6058ee32-f80b-40" ✅
  Updates chunks_embedded counter ✅
  Sets status = "completed" when done ✅
  
Result:
  Single DynamoDB record with correct status! ✅
  Pinecone: Has embeddings ✅
  UI: Shows correct progress! ✅
```

## Files Modified

1. **`lambda/chunker/handler.py`**
   - `generate_document_id()` - Extract from S3 key instead of generating
   - `save_document_metadata()` - UPDATE instead of PUT

2. **`lambda/embedder/handler.py`**
   - Better logging throughout
   - Enhanced error handling
   - Better progress tracking

## Deployment Instructions

### Deploy Chunker Lambda:

```bash
cd lambda/chunker

# Install dependencies
pip install -r requirements.txt -t package/

# Copy handler
cp handler.py package/

# Create ZIP
cd package
zip -r ../chunker.zip .
cd ..

# Upload to AWS
aws lambda update-function-code \
  --function-name rag-demo-chunker \
  --zip-file fileb://chunker.zip

# Wait for update
aws lambda wait function-updated --function-name rag-demo-chunker
```

### Deploy Embedder Lambda:

```bash
cd lambda/embedder

# Install dependencies
pip install -r requirements.txt -t package/

# Copy handler
cp handler.py package/

# Create ZIP
cd package
zip -r ../embedder.zip .
cd ..

# Upload to AWS
aws lambda update-function-code \
  --function-name rag-demo-embedder \
  --zip-file fileb://embedder.zip

# Wait for update
aws lambda wait function-updated --function-name rag-demo-embedder
```

### Windows PowerShell Version:

```powershell
# Chunker
cd lambda\chunker
pip install -r requirements.txt -t package\
Copy-Item handler.py package\
Compress-Archive -Path package\* -DestinationPath chunker.zip -Force
aws lambda update-function-code --function-name rag-demo-chunker --zip-file fileb://chunker.zip

# Embedder
cd ..\embedder
pip install -r requirements.txt -t package\
Copy-Item handler.py package\
Compress-Archive -Path package\* -DestinationPath embedder.zip -Force
aws lambda update-function-code --function-name rag-demo-embedder --zip-file fileb://embedder.zip
```

## Testing After Deployment

### 1. Upload a new test document

```bash
curl -X POST http://54.89.155.20:8000/upload \
  -F "file=@test.txt"
```

Note the `document_id` in the response (e.g., `6058ee32-f80b-40`)

### 2. Monitor Chunker Lambda logs

```bash
aws logs tail /aws/lambda/rag-demo-chunker --since 1m --follow
```

**Look for:**
```
Extracted document_id from S3 key: 6058ee32-f80b-40
Updated metadata for document 6058ee32-f80b-40: 5 chunks, status=chunked
```

### 3. Monitor Embedder Lambda logs

```bash
aws logs tail /aws/lambda/rag-demo-embedder --since 1m --follow
```

**Look for:**
```
Updating DynamoDB progress for document_id: 6058ee32-f80b-40
Progress updated: 1/5 chunks embedded
Progress updated: 2/5 chunks embedded
...
🎉 Document 6058ee32-f80b-40 fully embedded (5 chunks)! Status set to 'completed'
```

### 4. Check DynamoDB

```bash
aws dynamodb get-item \
  --table-name rag-demo-documents \
  --key '{"document_id": {"S": "6058ee32-f80b-40"}}'
```

**Should show:**
```json
{
  "Item": {
    "document_id": {"S": "6058ee32-f80b-40"},
    "status": {"S": "completed"},
    "chunk_count": {"N": "5"},
    "chunks_embedded": {"N": "5"}
  }
}
```

### 5. Check UI

The UI should now show:
- Real-time progress updates
- Progress bar moving from 0% → 100%
- Status changing: uploaded → chunked → embedding → completed
- Document disappearing from processing list when done

## Verification

After deploying both Lambdas, upload a new document and verify:

✅ **Chunker extracts correct document_id** (check CloudWatch logs)  
✅ **DynamoDB record is UPDATED not created** (check DynamoDB)  
✅ **Embedder updates same record** (check CloudWatch logs)  
✅ **UI shows correct progress** (check Electron UI)  
✅ **Status reaches "completed"** (check DynamoDB and UI)  
✅ **Document queryable** (test query in UI)  

## Key Changes Summary

| Component | Before | After |
|-----------|--------|-------|
| **document_id** | Generated new hash | Extracted from S3 key |
| **DynamoDB operation** | `put_item` (create new) | `update_item` (update existing) |
| **Status tracking** | Broken (0% forever) | Working (real-time updates) |
| **UI display** | Always 0% | Correct progress |
| **Logging** | Basic | Detailed with document_id |

## Why This Works Now

1. **Backend** creates: `6058ee32-f80b-40` and uploads to S3 as `uploads/6058ee32-f80b-40_file.txt`
2. **Chunker** extracts: `6058ee32-f80b-40` from filename ✅
3. **Chunker** updates DynamoDB record with this ID ✅
4. **Embedder** receives: `6058ee32-f80b-40` from chunker ✅
5. **Embedder** updates same DynamoDB record ✅
6. **UI** queries same record and shows correct status! ✅

**Everything now uses the SAME document_id!** 🎉

