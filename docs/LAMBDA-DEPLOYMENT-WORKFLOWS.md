# Lambda Deployment Workflows

## Overview

The application now has **two separate GitHub Actions workflows** for deploying Lambda functions:

1. **`deploy-chunker-lambda.yml`** - Deploys the Chunker Lambda independently
2. **`deploy-embedder-lambda.yml`** - Deploys the Embedder Lambda independently

This separation provides:
- **Independent deployments**: Deploy only the Lambda that changed
- **Faster CI/CD**: No waiting for unrelated Lambda to build
- **Avoid resource conflicts**: No `ResourceConflictException` when updating functions simultaneously
- **Better isolation**: Each Lambda can be deployed, tested, and rolled back independently

---

## Workflow Triggers

### Deploy Chunker Lambda
**File**: `.github/workflows/deploy-chunker-lambda.yml`

**Triggers**:
- **Automatic**: On push to `main` branch when files in `lambda/chunker/` change
- **Manual**: Via workflow_dispatch in GitHub Actions UI

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'lambda/chunker/**'
  workflow_dispatch:
```

### Deploy Embedder Lambda
**File**: `.github/workflows/deploy-embedder-lambda.yml`

**Triggers**:
- **Automatic**: On push to `main` branch when files in `lambda/embedder/` change
- **Manual**: Via workflow_dispatch in GitHub Actions UI

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'lambda/embedder/**'
  workflow_dispatch:
```

---

## How to Deploy

### Option 1: Automatic Deployment
Simply push changes to the respective Lambda folder:

```bash
# Deploy only Chunker
git add lambda/chunker/
git commit -m "Update chunker Lambda"
git push

# Deploy only Embedder
git add lambda/embedder/
git commit -m "Update embedder Lambda"
git push
```

### Option 2: Manual Deployment via GitHub UI

1. Go to **Actions** tab in GitHub
2. Select the workflow you want to run:
   - "Deploy Chunker Lambda"
   - "Deploy Embedder Lambda"
3. Click **Run workflow**
4. Select branch (usually `main`)
5. Click **Run workflow** button

### Option 3: Manual Deployment via GitHub CLI

```bash
# Deploy Chunker
gh workflow run deploy-chunker-lambda.yml

# Deploy Embedder
gh workflow run deploy-embedder-lambda.yml
```

---

## Deployment Process

Both workflows follow the same process:

1. **Checkout code**
2. **Set up Python 3.11**
3. **Configure AWS credentials** (from GitHub Secrets)
4. **Print requirements file** (for debugging)
5. **Install dependencies**:
   - Install packages to `package/` directory
   - Use platform-specific wheels for Lambda (manylinux2014_x86_64)
   - Exclude boto3/botocore (already in Lambda runtime)
6. **Clean up package**:
   - Remove tests, __pycache__, .pyc files
   - Remove .dist-info, .egg-info
   - Remove documentation and examples
7. **Create ZIP file**
8. **Check package size** (must be < 50MB)
9. **Deploy to AWS Lambda**
10. **Wait for function update to complete**
11. **Report deployment summary**

---

## Required GitHub Secrets

Both workflows require these secrets to be configured in GitHub:

| Secret Name | Description | How to Get |
|------------|-------------|------------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key | Create IAM user with Lambda deployment permissions |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key | Same as above |

### Setting up GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add both secrets

### Required IAM Permissions

The IAM user needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode",
        "lambda:GetFunction"
      ],
      "Resource": [
        "arn:aws:lambda:us-east-1:*:function:rag-demo-chunker",
        "arn:aws:lambda:us-east-1:*:function:rag-demo-embedder"
      ]
    }
  ]
}
```

---

## Package Size Optimization

Both workflows implement aggressive size reduction to stay under Lambda's 50MB limit:

### What Gets Removed
- `tests/` directories
- `__pycache__/` directories
- `*.pyc` and `*.pyo` files
- `*.dist-info/` directories
- `*.egg-info/` directories
- `examples/` and `docs/` directories
- `boto3`, `botocore`, `s3transfer` (available in Lambda runtime)

### Size Check
If the package exceeds 50MB, the workflow:
1. Fails the build
2. Lists the top 30 largest files
3. Provides info for further optimization

---

## Monitoring Deployments

### GitHub Actions UI
1. Go to **Actions** tab
2. Select the workflow run
3. View logs and deployment summary

### AWS Console
1. Go to **Lambda** service
2. Select function: `rag-demo-chunker` or `rag-demo-embedder`
3. Check **Configuration** → **General configuration** for last modified time
4. View **Monitor** tab for CloudWatch logs

### AWS CLI
```bash
# Check Chunker Lambda
aws lambda get-function --function-name rag-demo-chunker --region us-east-1

# Check Embedder Lambda
aws lambda get-function --function-name rag-demo-embedder --region us-east-1

# View Chunker logs
aws logs tail /aws/lambda/rag-demo-chunker --follow

# View Embedder logs
aws logs tail /aws/lambda/rag-demo-embedder --follow
```

---

## Troubleshooting

### Common Issues

#### 1. Package Size Too Large (> 50MB)
**Error**: `Package is too large (XXmb > 50MB)`

**Solutions**:
- Review the list of largest files in the workflow output
- Add more exclusions to the cleanup script
- Consider using Lambda Layers for large dependencies
- Use minimal versions of packages (e.g., `requirements-minimal.txt`)

#### 2. Missing Dependencies
**Error**: `No module named 'XXX'`

**Solutions**:
- Check that the package is in `requirements-minimal.txt`
- Ensure package is not being excluded during cleanup
- Verify the package is compatible with `manylinux2014_x86_64`

#### 3. AWS Credentials Error
**Error**: `Credentials could not be loaded`

**Solutions**:
- Verify GitHub Secrets are set correctly
- Check IAM user has required permissions
- Ensure access key is still active

#### 4. Resource Conflict
**Error**: `ResourceConflictException: An update is in progress`

**Solutions**:
- This is now avoided by having separate workflows
- If manually triggering, wait for previous deployment to complete
- Use `aws lambda wait function-updated` command

#### 5. Syntax Error in Handler
**Error**: `Runtime.UserCodeSyntaxError: Syntax error in module 'handler'`

**Solutions**:
- Check the handler.py file for syntax errors
- Run locally: `python -m py_compile lambda/*/handler.py`
- Ensure Python version matches (3.11)

---

## Best Practices

1. **Test Locally First**
   ```bash
   cd lambda/chunker
   python handler.py
   ```

2. **Use Pull Requests**
   - Create feature branch
   - Make changes
   - Open PR to main
   - Review before merging (triggers deployment)

3. **Monitor Logs**
   - Check CloudWatch logs after deployment
   - Verify function works as expected
   - Test with sample documents

4. **Version Control**
   - Tag releases: `git tag -a v1.0.0 -m "Release 1.0.0"`
   - Keep CHANGELOG.md updated
   - Document breaking changes

5. **Rollback Strategy**
   - Lambda keeps previous versions
   - Use aliases for production (`$LATEST` vs versioned)
   - Can revert by republishing previous commit

---

## Related Workflows

- **`infrastructure.yml`** - Deploys Terraform infrastructure (creates Lambda functions)
- **`deploy-ecs.yml`** - Deploys backend API to ECS
- **`deploy-full-stack.yml`** - Deploys entire stack (if needed)

---

## Next Steps

1. ✅ Set up GitHub Secrets (AWS credentials)
2. ✅ Ensure Lambda functions exist in AWS (run Terraform first)
3. ✅ Push changes to `lambda/chunker/` or `lambda/embedder/`
4. ✅ Monitor deployment in GitHub Actions
5. ✅ Verify in AWS Lambda console
6. ✅ Test end-to-end document processing

