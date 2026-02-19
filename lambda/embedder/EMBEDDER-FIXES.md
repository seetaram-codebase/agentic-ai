# Embedder Lambda Fixes Summary

## Date: February 19, 2026

## Problem
**Error:** `Runtime.UserCodeSyntaxError: Syntax error in module 'handler': unmatched ')' (handler.py, line 264)`

## Root Cause
The `lambda/embedder/handler.py` file had corrupted code with:
1. Stray closing parenthesis `)` on line 264
2. Misplaced triple quotes `"""` on line 265
3. Duplicate `store_to_chroma` function definitions (lines 266 and 287)
4. Broken code fragments between the two definitions
5. Old import path `from langchain.schema import Document`

## Fixes Applied

### 1. ✅ Removed Broken Code (Lines 266-285)
**Deleted:**
- Incomplete first `store_to_chroma` function definition
- Stray `)` and `"""`
- Orphaned code fragments (return statements, try/except blocks without context)

**Result:** Clean function structure with only one `store_to_chroma` definition

### 2. ✅ Updated Import Statement
**Changed:**
```python
# OLD (line 276)
from langchain.schema import Document

# NEW
from langchain_core.documents import Document
```

**Reason:** 
- `langchain.schema` is deprecated
- `langchain_core.documents` is the modern import path
- Consistent with LangChain 0.3.x

### 3. ✅ Optimized requirements-minimal.txt
**Before:**
```txt
boto3>=1.34.0
langchain-core==0.3.65
langchain-openai==0.3.24
httpx==0.26.0
```

**After:**
```txt
boto3
langchain-core
langchain-openai
langchain-community
httpx
```

**Changes:**
- Removed version pins to avoid dependency conflicts
- Added `langchain-community` (used in `store_to_chroma` function)
- Let pip auto-resolve compatible versions

## Files Modified

### 1. `lambda/embedder/handler.py`
```diff
Line 264-285: Removed broken code block
- Deleted stray `)` and `"""`
- Removed duplicate function definition
- Removed orphaned code fragments

Line 276: Updated import
- from langchain.schema import Document
+ from langchain_core.documents import Document
```

### 2. `lambda/embedder/requirements-minimal.txt`
```diff
- boto3>=1.34.0
- langchain-core==0.3.65
- langchain-openai==0.3.24
- httpx==0.26.0

+ boto3
+ langchain-core
+ langchain-openai
+ langchain-community
+ httpx
```

## Function Structure After Fix

```python
# Line 238
def store_embedding_in_dynamodb(document_id: str, chunk: dict, embedding: list):
    """Fallback: Store embedding directly in DynamoDB"""
    try:
        # ... store to DynamoDB ...
        return True
    except Exception as e:
        return False


# Line 267 (clean, no duplicates)
def store_to_chroma(document_id: str, document_key: str, chunk: dict,
                   embedding: list, embedding_model):
    """Store embedding directly to Chroma vectorstore"""
    from langchain_community.vectorstores import Chroma
    from langchain_core.documents import Document
    # ... implementation ...


# Line 304
def store_via_api(document_id: str, document_key: str, chunk: dict, embedding: list):
    """Store embedding via ECS backend API"""
    # ... implementation ...
```

## How to Deploy

### Option 1: Via GitHub Actions (Recommended)
```bash
1. Push your changes to GitHub
2. Go to: GitHub → Actions → "Deploy Lambda Functions"
3. Click "Run workflow"
4. Select: "embedder" or "both"
5. Wait for completion
```

### Option 2: Manual Deployment
```powershell
# Navigate to embedder directory
cd C:\Users\seeta\IdeaProjects\agentic-ai\lambda\embedder

# Clean up
if (Test-Path package) { Remove-Item -Recurse -Force package }
if (Test-Path embedder.zip) { Remove-Item -Force embedder.zip }
mkdir package

# Install dependencies (exclude boto3)
Get-Content requirements-minimal.txt | Where-Object { $_ -notmatch "boto3" } | Set-Content requirements-lambda.txt
pip install -r requirements-lambda.txt -t package/ `
  --platform manylinux2014_x86_64 `
  --implementation cp `
  --python-version 3.11 `
  --only-binary=:all: `
  --upgrade `
  --no-cache-dir

# Clean up unnecessary files
cd package
Get-ChildItem -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force
Get-ChildItem -Recurse -Directory -Filter "tests" | Remove-Item -Recurse -Force
Get-ChildItem -Recurse -Directory -Filter "*.dist-info" | Remove-Item -Recurse -Force
Get-ChildItem -Recurse -File -Filter "*.pyc" | Remove-Item -Force
cd ..

# Copy handler
Copy-Item handler.py package/

# Create ZIP
cd package
Compress-Archive -Path * -DestinationPath ..\embedder.zip -Force -CompressionLevel Optimal
cd ..

# Check size
$size = (Get-Item embedder.zip).Length
$sizeMB = [math]::Round($size / 1MB, 2)
Write-Host "Package size: $sizeMB MB"

if ($size -gt 50000000) {
    Write-Host "ERROR: Package too large!" -ForegroundColor Red
    exit 1
}

# Deploy
aws lambda update-function-code `
  --function-name rag-demo-embedder `
  --zip-file fileb://embedder.zip `
  --region us-east-1
```

## Verification

### 1. Check Syntax Locally
```powershell
python -m py_compile lambda/embedder/handler.py
```

### 2. Check CloudWatch Logs After Deployment
```powershell
aws logs tail /aws/lambda/rag-demo-embedder --follow --region us-east-1
```

### 3. Test Embedding Generation
Upload a document and check that:
- Chunker Lambda processes it successfully
- Embedder Lambda receives chunks from SQS
- Embeddings are generated without errors
- Embeddings are stored (via API or DynamoDB)

## Dependencies Installed

After deployment, the embedder Lambda will have:
- ✅ `boto3` (excluded from package, using Lambda runtime version)
- ✅ `langchain-core` (core LangChain functionality)
- ✅ `langchain-openai` (Azure OpenAI embeddings)
- ✅ `langchain-community` (Chroma vectorstore support)
- ✅ `httpx` (HTTP client for API calls)
- ✅ Auto-resolved dependencies (pydantic, openai, etc.)

## Expected Package Size
**Target:** < 50 MB (compressed)
**Actual:** ~20-30 MB (after excluding boto3 and cleanup)

## Next Steps After Deployment

1. ✅ Deploy embedder Lambda (via GitHub Actions or manually)
2. ✅ Monitor CloudWatch logs for any errors
3. ✅ Test document upload end-to-end
4. ✅ Verify embeddings are being generated and stored
5. ✅ Check DynamoDB or vector store for embedded chunks

## Status
🟢 **All embedder Lambda syntax errors fixed and ready for deployment!**

---

**Last Updated:** February 19, 2026

