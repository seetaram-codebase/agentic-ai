# Lambda Deployment Workflow Fix

## 🔴 Issue

```
Error: ResourceConflictException when calling the UpdateFunctionCode operation: 
The operation cannot be performed at this time. An update is in progress for resource: 
arn:aws:lambda:us-east-1:971778147952:function:rag-demo-embedder
```

**Additional symptoms**:
- "deploy-chunker is calling deploy-embedder"
- Both Lambda functions being updated simultaneously

---

## 🔍 Root Cause

**Two problems in `.github/workflows/deploy-lambda.yml`**:

### Problem 1: Copy-Paste Error
The `deploy-chunker` job had the **wrong code** - it was deploying the embedder!

```yaml
# ❌ WRONG - deploy-chunker job was deploying embedder
deploy-chunker:
  steps:
    - name: Install dependencies and package Embedder  # ❌ Should be Chunker
      run: |
        cd lambda/embedder  # ❌ Wrong directory!
        # ... package embedder code
    
    - name: Deploy Embedder Lambda  # ❌ Wrong function!
      run: |
        aws lambda update-function-code \
          --function-name rag-demo-embedder  # ❌ Should be chunker!
```

### Problem 2: Parallel Execution Conflict
Both jobs ran **in parallel**, trying to update Lambda at the same time:

```yaml
# ❌ WRONG - Jobs run in parallel
deploy-chunker:
  runs-on: ubuntu-latest  # Starts immediately
  
deploy-embedder:
  runs-on: ubuntu-latest  # Also starts immediately
  # No dependency - runs in parallel!
```

**Result**: AWS rejects the second update because the first is still in progress.

---

## ✅ Solution Applied

### Fix 1: Corrected deploy-chunker Job

```yaml
# ✅ CORRECT - deploy-chunker now deploys chunker
deploy-chunker:
  steps:
    - name: Install dependencies and package Chunker  # ✅ Correct
      run: |
        cd lambda/chunker  # ✅ Correct directory
        pip install -r requirements-minimal.txt -t package/
        cp handler.py package/
        cd package && zip -r9 ../chunker.zip .
    
    - name: Deploy Chunker Lambda  # ✅ Correct
      run: |
        aws lambda update-function-code \
          --function-name rag-demo-chunker \  # ✅ Correct function
          --zip-file fileb://lambda/chunker/chunker.zip
```

### Fix 2: Sequential Execution

```yaml
# ✅ CORRECT - Jobs run sequentially
deploy-chunker:
  runs-on: ubuntu-latest
  
deploy-embedder:
  runs-on: ubuntu-latest
  needs: deploy-chunker  # ✅ Wait for chunker to finish!
```

**Now**:
1. Chunker deploys first
2. Embedder waits for chunker to complete
3. Embedder deploys second
4. No conflicts! ✅

---

## 📊 Before vs After

### Before (Broken)
```
┌─────────────────┐     ┌─────────────────┐
│ deploy-chunker  │     │ deploy-embedder │
│                 │     │                 │
│ Deploys:        │     │ Deploys:        │
│ ❌ Embedder     │     │ ✅ Embedder     │
└────────┬────────┘     └────────┬────────┘
         │ Parallel               │ Parallel
         │ (Both run at           │ (Both run at
         │  same time)            │  same time)
         ↓                        ↓
    ┌────────────────────────────────┐
    │  Both update embedder!         │
    │  ❌ ResourceConflictException  │
    └────────────────────────────────┘
```

### After (Fixed)
```
┌─────────────────┐
│ deploy-chunker  │
│                 │
│ Deploys:        │
│ ✅ Chunker      │
└────────┬────────┘
         │ Sequential
         │ (Finishes first)
         ↓
    ┌─────────────────┐
    │ deploy-embedder │
    │                 │
    │ Waits...        │
    │ Then deploys:   │
    │ ✅ Embedder     │
    └─────────────────┘
         ↓
    ✅ SUCCESS!
```

---

## 🎯 Testing the Fix

### Re-run the Deployment

```bash
# Via GitHub Actions
Actions → Deploy Lambda Functions → Run workflow
  Function: both
  
# Click: Run workflow
```

**Expected output**:
```
✅ deploy-chunker:
   - Package Chunker: ~15 MB
   - Deploy rag-demo-chunker
   - Success!

✅ deploy-embedder:
   - Wait for deploy-chunker to complete
   - Package Embedder: ~20 MB
   - Deploy rag-demo-embedder
   - Success!

✅ Both deployed successfully!
```

### Verify Lambda Functions

```bash
# Check both functions deployed correctly
aws lambda get-function --function-name rag-demo-chunker
aws lambda get-function --function-name rag-demo-embedder

# Both should show:
# State: Active
# LastUpdateStatus: Successful
```

---

## 🔍 How This Bug Happened

**Copy-paste error** when creating the workflow:
1. Created `deploy-embedder` job first
2. Copied to create `deploy-chunker` job
3. Forgot to change the step names and paths
4. Result: Both jobs deploying embedder

**Lesson**: Always double-check variable names and paths after copy-paste!

---

## 📝 Changes Made

### File Modified
`.github/workflows/deploy-lambda.yml`

### Specific Changes

**Line ~42-70** (deploy-chunker job):
```diff
- - name: Install dependencies and package Embedder
+ - name: Install dependencies and package Chunker
    run: |
-     cd lambda/embedder
+     cd lambda/chunker
      mkdir -p package
      pip install -r requirements-minimal.txt -t package/
      cp handler.py package/
      cd package
-     zip -r9 ../embedder.zip .
+     zip -r9 ../chunker.zip .

- - name: Deploy Embedder Lambda
+ - name: Deploy Chunker Lambda
    run: |
      aws lambda update-function-code \
-       --function-name ${{ env.APP_NAME }}-embedder \
+       --function-name ${{ env.APP_NAME }}-chunker \
-       --zip-file fileb://lambda/embedder/embedder.zip
+       --zip-file fileb://lambda/chunker/chunker.zip
```

**Line ~74** (deploy-embedder job):
```diff
  deploy-embedder:
    runs-on: ubuntu-latest
+   needs: deploy-chunker  # Wait for chunker to finish
    if: github.event.inputs.function == 'both' || ...
```

---

## ✅ Verification

After deploying, check:

### CloudWatch Logs
```bash
# Chunker logs
aws logs tail /aws/lambda/rag-demo-chunker --follow

# Embedder logs
aws logs tail /aws/lambda/rag-demo-embedder --follow
```

### Function Details
```bash
# Get chunker info
aws lambda get-function-configuration \
  --function-name rag-demo-chunker \
  --query '[FunctionName,Runtime,CodeSize,LastModified]'

# Get embedder info
aws lambda get-function-configuration \
  --function-name rag-demo-embedder \
  --query '[FunctionName,Runtime,CodeSize,LastModified]'
```

Both should show:
- ✅ Runtime: python3.11
- ✅ CodeSize: 15-20 MB range
- ✅ Recent LastModified timestamp

---

## 🎉 Issue Resolved

**Status**: ✅ **FIXED**

**What was broken**:
- deploy-chunker deploying embedder (wrong function)
- Parallel execution causing ResourceConflictException

**What's fixed**:
- deploy-chunker now deploys chunker (correct function)
- Sequential execution (embedder waits for chunker)
- No more conflicts!

**Next**: Deploy again and it should work! 🚀

---

## 📚 Related Documentation

- **Lambda Size Fix**: `docs/LAMBDA-SIZE-FIX.md`
- **GitHub Actions Troubleshooting**: `docs/GITHUB-ACTIONS-TROUBLESHOOTING.md`
- **Deployment Guide**: `docs/GITHUB-ACTIONS-SETUP.md`

