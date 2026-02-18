# Deployment Checklist

Use this checklist to ensure all components are properly configured before deployment.

## Pre-Deployment Setup

### 1. Terraform Cloud Configuration
- [ ] Created Terraform Cloud account at https://app.terraform.io
- [ ] Created organization: `agentic-ai-org` (or updated `providers.tf`)
- [ ] Created workspace: `agentic-ai-rag-workspace`
- [ ] Workspace set to "CLI-driven workflow"
- [ ] Added environment variables in workspace:
  - [ ] `AWS_ACCESS_KEY_ID` (marked as sensitive)
  - [ ] `AWS_SECRET_ACCESS_KEY` (marked as sensitive)
- [ ] Generated Terraform Cloud API token
- [ ] Saved token for GitHub Secrets

### 2. GitHub Repository Configuration
- [ ] Repository created/forked
- [ ] Added GitHub Secrets (Repository Settings → Secrets and variables → Actions):
  - [ ] `AWS_ACCESS_KEY_ID`
  - [ ] `AWS_SECRET_ACCESS_KEY`
  - [ ] `TF_API_TOKEN` (see `docs/TERRAFORM-TOKEN-GUIDE.md` for how to generate)
- [ ] (Optional) JFrog secrets if using JFrog Artifactory:
  - [ ] `JFROG_REGISTRY_URL`
  - [ ] `JFROG_USERNAME`
  - [ ] `JFROG_PASSWORD`
  - [ ] `JFROG_REPOSITORY`

### 3. Azure OpenAI Configuration
- [ ] Azure OpenAI subscription created (primary)
- [ ] Deployment created: `gpt-4o-mini` or similar
- [ ] Embedding deployment created: `text-embedding-ada-002`
- [ ] API keys obtained
- [ ] Endpoints noted (e.g., `https://your-name.openai.azure.com/`)
- [ ] (Optional) Secondary subscription for failover
- [ ] (Optional) Secondary deployment and keys

### 4. AWS Account Setup
- [ ] AWS account accessible
- [ ] IAM user created with required permissions:
  - [ ] S3 (CreateBucket, PutObject, GetObject)
  - [ ] SQS (CreateQueue, SendMessage, ReceiveMessage)
  - [ ] Lambda (CreateFunction, UpdateFunctionCode)
  - [ ] ECS (CreateCluster, CreateService, RunTask)
  - [ ] ECR (CreateRepository, PutImage)
  - [ ] DynamoDB (CreateTable, PutItem, GetItem)
  - [ ] SSM (PutParameter, GetParameter)
  - [ ] IAM (CreateRole, AttachRolePolicy)
  - [ ] CloudWatch Logs (CreateLogGroup, PutLogEvents)
- [ ] AWS CLI configured locally
- [ ] AWS account ID noted

### 5. Local Environment
- [ ] Python 3.11+ installed
- [ ] AWS CLI installed
- [ ] Terraform 1.7+ installed
- [ ] Git installed
- [ ] Code editor (VS Code recommended)
- [ ] Created `.env` from `.env.example`
- [ ] Updated `.env` with actual values

## AWS SSM Parameter Store Setup

Run the setup script:
```powershell
./scripts/setup-ssm-parameters.ps1
```

Or manually create these parameters in AWS SSM:

### Primary Azure OpenAI (US East)
- [ ] `/{app-name}/azure-openai/us-east/endpoint` (String)
- [ ] `/{app-name}/azure-openai/us-east/api-key` (SecureString)
- [ ] `/{app-name}/azure-openai/us-east/deployment` (String)
- [ ] `/{app-name}/azure-openai/us-east/embedding-endpoint` (String)
- [ ] `/{app-name}/azure-openai/us-east/embedding-key` (SecureString)
- [ ] `/{app-name}/azure-openai/us-east/embedding-deployment` (String)

### Secondary Azure OpenAI (EU West - Optional)
- [ ] `/{app-name}/azure-openai/eu-west/endpoint` (String)
- [ ] `/{app-name}/azure-openai/eu-west/api-key` (SecureString)
- [ ] `/{app-name}/azure-openai/eu-west/deployment` (String)
- [ ] `/{app-name}/azure-openai/eu-west/embedding-endpoint` (String)
- [ ] `/{app-name}/azure-openai/eu-west/embedding-key` (SecureString)
- [ ] `/{app-name}/azure-openai/eu-west/embedding-deployment` (String)

## Terraform Configuration

### Update Variables
- [ ] Updated `infrastructure/terraform/environments/dev.tfvars`:
  - [ ] `aws_account_id` = "YOUR_ACCOUNT_ID"
  - [ ] `aws_region` = "us-east-1" (or preferred region)
  - [ ] `environment` = "dev"
  - [ ] `app_name` = "rag-demo" (or custom name)

### Verify Files
- [ ] `providers.tf` has correct organization name
- [ ] All `.tf` files are present and valid
- [ ] No syntax errors in Terraform files

## Initial Deployment

### Option 1: Automated (GitHub Actions)
1. [ ] Go to Actions → "Deploy Full Stack"
2. [ ] Click "Run workflow"
3. [ ] Select:
   - Environment: `dev`
   - Terraform action: `apply`
   - Deploy infrastructure: ✅
   - Deploy backend: ✅
   - Deploy lambdas: ✅
   - Run tests: ✅
4. [ ] Monitor workflow execution
5. [ ] Check for errors in each job

### Option 2: Manual (Local)
```bash
# Initialize Terraform
cd infrastructure/terraform
terraform init

# Plan deployment
terraform plan -var-file=environments/dev.tfvars -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Build and push backend
cd ../../backend
docker build -t rag-demo-backend .
# Push to ECR (get ECR URL from Terraform output)

# Deploy Lambdas
cd ../lambda/chunker
./package-and-deploy.sh

cd ../embedder
./package-and-deploy.sh
```

## Post-Deployment Verification

### Infrastructure
- [ ] Terraform apply completed successfully
- [ ] All AWS resources created:
  - [ ] S3 bucket: `rag-demo-documents-{account-id}`
  - [ ] SQS queues: chunking and embedding
  - [ ] Lambda functions: chunker and embedder
  - [ ] DynamoDB tables: config and documents
  - [ ] ECS cluster and service
  - [ ] ECR repository
  - [ ] Security groups and IAM roles

### Backend Service
- [ ] ECS service running
- [ ] Tasks in RUNNING state
- [ ] Health check passing: `curl http://{ecs-ip}:8000/health`
- [ ] Ready check passing: `curl http://{ecs-ip}:8000/ready`
- [ ] API accessible: `curl http://{ecs-ip}:8000/`

### Lambda Functions
- [ ] Chunker Lambda active
- [ ] Embedder Lambda active
- [ ] Both Lambdas have correct environment variables
- [ ] SQS triggers configured
- [ ] CloudWatch log groups created

### Permissions
- [ ] ECS task can read from SSM
- [ ] ECS task can write to S3
- [ ] Lambda can read from S3
- [ ] Lambda can write to SQS
- [ ] Lambda can read/write DynamoDB
- [ ] Lambda can read from SSM

## End-to-End Testing

### Manual Test
```bash
# 1. Upload a document
curl -X POST http://{ecs-ip}:8000/upload \
  -F "file=@sample-docs/product-features.txt"

# 2. Wait 10-30 seconds for processing

# 3. Query the document
curl -X POST http://{ecs-ip}:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What are the features?", "n_results": 5}'
```

### Automated Tests
- [ ] Unit tests pass: `pytest tests/test_api.py`
- [ ] Integration tests pass: `pytest tests/test_e2e.py::TestHealthEndpoints`
- [ ] AWS tests pass (if enabled): `RUN_AWS_TESTS=1 pytest tests/test_e2e.py::TestAWSIntegration`

### Verify Data Flow
- [ ] Document uploaded to S3
- [ ] S3 event triggered SQS message
- [ ] Chunker Lambda processed document
- [ ] Chunks sent to embedding queue
- [ ] Embedder Lambda generated embeddings
- [ ] Embeddings stored in vector database
- [ ] Query returns relevant results

## Monitoring Setup

### CloudWatch Logs
- [ ] ECS logs visible: `/ecs/rag-demo`
- [ ] Chunker logs visible: `/aws/lambda/rag-demo-chunker`
- [ ] Embedder logs visible: `/aws/lambda/rag-demo-embedder`
- [ ] No errors in logs

### Metrics
- [ ] ECS CPU/Memory metrics available
- [ ] Lambda invocation metrics available
- [ ] SQS message metrics available
- [ ] Set up alarms (optional):
  - [ ] ECS task failures
  - [ ] Lambda errors
  - [ ] SQS dead letter queue messages

## Cost Optimization

- [ ] Set up AWS Budget alerts
- [ ] Review resource sizes:
  - [ ] ECS task: 512 CPU / 1024 MB for dev
  - [ ] Lambda timeout: 60s for chunker, 30s for embedder
  - [ ] DynamoDB: On-demand pricing
- [ ] Enable cost allocation tags
- [ ] Schedule ECS tasks to stop during non-working hours (optional)

## Security Review

- [ ] No hardcoded credentials in code
- [ ] All secrets in SSM or GitHub Secrets
- [ ] S3 bucket encryption enabled
- [ ] DynamoDB encryption enabled
- [ ] Security groups restrict access appropriately
- [ ] IAM roles follow least privilege
- [ ] CORS configured appropriately
- [ ] API authentication planned (if needed)

## Troubleshooting

If deployment fails, check:

### Terraform Issues
- [ ] Valid AWS credentials
- [ ] Terraform Cloud token valid
- [ ] Organization and workspace names correct
- [ ] No resource name conflicts
- [ ] IAM permissions sufficient

### ECS Issues
- [ ] Docker image built successfully
- [ ] Image pushed to ECR
- [ ] Task definition updated
- [ ] Environment variables set correctly
- [ ] Security group allows port 8000
- [ ] SSM parameters accessible from task role

### Lambda Issues
- [ ] Dependencies packaged correctly
- [ ] Handler function name correct
- [ ] Timeout not too short
- [ ] Memory allocation sufficient
- [ ] SQS trigger configured
- [ ] IAM permissions granted

### Application Issues
- [ ] Azure OpenAI credentials correct
- [ ] Vector store initialized
- [ ] File upload working
- [ ] Document chunking working
- [ ] Embedding generation working

## Production Checklist (Additional)

For production deployment, also verify:

- [ ] Custom domain configured
- [ ] SSL/TLS certificates
- [ ] CloudFront or API Gateway
- [ ] WAF rules configured
- [ ] Rate limiting enabled
- [ ] Backup strategy defined
- [ ] Disaster recovery plan
- [ ] Multi-AZ deployment
- [ ] Auto-scaling configured
- [ ] Cost alerts configured
- [ ] Security audit completed
- [ ] Documentation updated
- [ ] Runbook created

## Documentation

- [ ] Architecture diagram updated
- [ ] API documentation generated
- [ ] Deployment guide reviewed
- [ ] Troubleshooting guide created
- [ ] Runbook for on-call engineers

## Sign-off

- [ ] Development team approved
- [ ] Security team reviewed
- [ ] Cost projection reviewed
- [ ] Stakeholders notified
- [ ] Demo scheduled

---

**Deployment Date**: _________________

**Deployed By**: _________________

**Environment**: _________________

**Git Commit**: _________________

**Notes**: 
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

