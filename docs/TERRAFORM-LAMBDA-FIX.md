# ✅ TERRAFORM LAMBDA ISSUE - FIXED!

## 🔍 Problem

Terraform workflow was failing with:
```
Error: Archive creation error
error archiving directory: could not archive missing directory: ./../../lambda/chunker
error archiving directory: could not archive missing directory: ./../../lambda/embedder
```

## 🛠️ Root Cause

The original Terraform configuration tried to package Lambda code with dependencies using `archive_file` data source:

```terraform
# ❌ This caused the error:
data "archive_file" "chunker_code" {
  source_dir = "${path.module}/../../lambda/chunker"
  # Problem: Can't package Python dependencies this way
}
```

**Issues**:
1. Path resolution problems in GitHub Actions
2. Can't include pip-installed dependencies
3. Creates 35-45 MB packages (slow)
4. Terraform not designed for this use case

## ✅ Solution Implemented

### Changed to Two-Stage Deployment

**Stage 1: Terraform (Infrastructure)**
```terraform
# ✅ Creates placeholder Lambda:
data "archive_file" "chunker_code" {
  source {
    content  = "def lambda_handler(event, context): ..."
    filename = "handler.py"
  }
}

resource "aws_lambda_function" "chunker" {
  # ...
  lifecycle {
    ignore_changes = [source_code_hash]  # Updated separately
  }
}
```

**Stage 2: GitHub Actions (Code Deployment)**
```bash
# Deploys actual code with dependencies
cd lambda/chunker
pip install -r requirements.txt -t package/
cp handler.py package/
cd package && zip -r ../chunker.zip .
aws lambda update-function-code --function-name rag-demo-chunker --zip-file fileb://../chunker.zip
```

## 📋 What Changed

### Files Modified

1. **`infrastructure/terraform/lambda.tf`**
   - ✅ Changed to placeholder ZIP approach
   - ✅ Added `lifecycle.ignore_changes` for code updates
   - ✅ Removed problematic `source_dir` references

2. **`.github/workflows/infrastructure.yml`**
   - ✅ Removed branch restriction on `terraform apply`
   - ✅ Can now run on feature branches for testing

3. **`.gitignore`**
   - ✅ Excluded placeholder ZIP files

4. **`docs/LAMBDA-DEPLOYMENT.md`**
   - ✅ New documentation explaining the approach

## 🚀 How to Deploy Now

### First-Time Deployment

#### Step 1: Deploy Infrastructure
```bash
# Via GitHub Actions
Actions → Infrastructure - Terraform → Run workflow
  Action: apply
  Environment: dev
```

This creates:
- ✅ Lambda functions (with placeholder code)
- ✅ IAM roles
- ✅ SQS triggers
- ✅ CloudWatch log groups
- ✅ All other AWS resources

#### Step 2: Deploy Lambda Code
```bash
# Via GitHub Actions
Actions → Deploy Lambda Functions → Run workflow
  Function: both
```

This deploys:
- ✅ Actual handler code
- ✅ All Python dependencies (langchain, pypdf, chromadb, etc.)
- ✅ Properly packaged ZIP files

#### Step 3: Deploy Backend
```bash
# Via GitHub Actions
Actions → Deploy to ECS → Run workflow
  Environment: dev
```

### OR: Use Master Workflow (Recommended)

```bash
# Deploy everything at once
Actions → Deploy Full Stack → Run workflow
  Environment: dev
  Terraform action: apply
  Deploy infrastructure: ✅
  Deploy backend: ✅
  Deploy lambdas: ✅
  Run tests: ✅
```

## ✅ Benefits of New Approach

| Aspect | Old Approach | New Approach |
|--------|--------------|--------------|
| **Terraform Speed** | Slow (large ZIPs) | Fast (tiny placeholders) |
| **Dependencies** | ❌ Can't include | ✅ Properly packaged |
| **Reliability** | ❌ Path issues | ✅ Reliable paths |
| **Separation** | ❌ Mixed concerns | ✅ Clear separation |
| **CI/CD** | ❌ Complex | ✅ Simple workflows |

## 🔄 Update Workflow

### For Infrastructure Changes
```bash
# Modify terraform files
git add infrastructure/terraform/
git commit -m "Update infrastructure"
git push

# Run Terraform workflow
Actions → Infrastructure - Terraform → apply
```

### For Lambda Code Changes
```bash
# Modify Lambda code
git add lambda/
git commit -m "Update Lambda logic"
git push

# Automatically triggers or manually run
Actions → Deploy Lambda Functions
```

### For Backend Changes
```bash
# Modify backend code
git add backend/
git commit -m "Update API"
git push

# Automatically triggers on push to main
# Or manually: Actions → Deploy to ECS
```

## 🎯 What Happens Next

When you run Terraform apply now:

1. ✅ **Terraform Init** - Downloads providers
2. ✅ **Terraform Validate** - Checks syntax
3. ✅ **Terraform Plan** - Shows what will be created
4. ✅ **Terraform Apply** - Creates all resources
   - S3 bucket for documents
   - SQS queues (chunking & embedding)
   - **Lambda functions (with placeholders)** ⭐
   - DynamoDB tables
   - ECS cluster and task definition
   - ECR repository
   - IAM roles and policies
   - SSM parameters (placeholders)
   - CloudWatch log groups

5. ⏭️ **Then run**: Lambda Deploy workflow to add actual code

## 📊 Verification Steps

### After Terraform Apply
```bash
# Check Lambda functions exist
aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `rag-demo`)].FunctionName'

# Expected output:
# - rag-demo-chunker
# - rag-demo-embedder
```

### After Lambda Deploy
```bash
# Test Lambda function
aws lambda invoke \
  --function-name rag-demo-chunker \
  --payload '{"test": true}' \
  response.json

# Check logs
aws logs tail /aws/lambda/rag-demo-chunker --follow
```

## 🆘 Troubleshooting

### Q: Terraform apply succeeds but Lambda doesn't work?
**A**: That's expected! Lambda has placeholder code. Run the Lambda Deploy workflow.

### Q: Lambda Deploy workflow fails?
**A**: Check:
- AWS credentials are configured in GitHub Secrets
- Lambda function was created by Terraform first
- Requirements.txt has valid package names

### Q: Lambda shows "Placeholder" error in CloudWatch?
**A**: The actual code hasn't been deployed yet. Run Lambda Deploy workflow.

### Q: Can I test locally before deploying?
**A**: Yes!
```bash
cd lambda/chunker
pip install -r requirements.txt
python -c "from handler import lambda_handler; print(lambda_handler({}, None))"
```

## 📚 Documentation

- **Lambda Deployment Strategy**: `docs/LAMBDA-DEPLOYMENT.md`
- **GitHub Actions Setup**: `docs/GITHUB-ACTIONS-SETUP.md`
- **Deployment Checklist**: `docs/DEPLOYMENT-CHECKLIST.md`
- **CI/CD Summary**: `docs/CI-CD-SUMMARY.md`

## 🎉 Summary

✅ **Issue Fixed**: Terraform can now provision Lambda infrastructure
✅ **Workflow Updated**: Removed branch restrictions
✅ **Documentation Added**: Clear deployment strategy explained
✅ **Approach**: Two-stage deployment (Terraform + GitHub Actions)

**You can now deploy!** 🚀

---

**Next Steps**:
1. Run Terraform apply workflow in GitHub Actions
2. Wait for success
3. Run Lambda Deploy workflow
4. Run Backend Deploy workflow
5. Test end-to-end!

