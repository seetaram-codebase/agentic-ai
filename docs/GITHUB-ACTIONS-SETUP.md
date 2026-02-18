# GitHub Actions CI/CD Setup Guide

This guide will help you set up the complete CI/CD pipeline for deploying the RAG application to AWS using GitHub Actions and Terraform Cloud.

## 📋 Prerequisites

Before you begin, ensure you have:

1. **AWS Account** with appropriate permissions
2. **Terraform Cloud Account** (free tier is fine)
3. **GitHub Account** with this repository
4. **Azure OpenAI** subscriptions (at least one, preferably two for failover)

## 🔧 Setup Steps

### 1. Terraform Cloud Setup

#### 1.1 Create Organization and Workspace

1. Go to [Terraform Cloud](https://app.terraform.io)
2. Sign up or log in
3. Create a new organization: `agentic-ai-org` (or update `providers.tf` with your org name)
4. Create a workspace: `agentic-ai-rag-workspace`
5. Choose "CLI-driven workflow"

#### 1.2 Configure Workspace Variables

In your Terraform Cloud workspace, add these **Environment Variables**:

| Variable | Value | Sensitive |
|----------|-------|-----------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key | ✅ |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key | ✅ |
| `TF_VAR_aws_account_id` | Your AWS account ID | ❌ |

#### 1.3 Generate API Token

1. Go to User Settings → Tokens
2. Create a new API token
3. Copy the token (you'll need it for GitHub Secrets)

### 2. GitHub Secrets Configuration

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these **Repository Secrets**:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `TF_API_TOKEN` | Terraform Cloud API token | `your-terraform-token` |

**Optional (for JFrog):**
- `JFROG_REGISTRY_URL`
- `JFROG_USERNAME`
- `JFROG_PASSWORD`
- `JFROG_REPOSITORY`

### 3. AWS SSM Parameter Store Setup

You need to store Azure OpenAI credentials in AWS SSM Parameter Store. Run these AWS CLI commands:

```bash
# Set your app name
APP_NAME=rag-demo
REGION=us-east-1

# Primary Azure OpenAI (US East)
aws ssm put-parameter \
  --name "/$APP_NAME/azure-openai/us-east/endpoint" \
  --type "String" \
  --value "https://your-openai-us-east.openai.azure.com/" \
  --region $REGION

aws ssm put-parameter \
  --name "/$APP_NAME/azure-openai/us-east/api-key" \
  --type "SecureString" \
  --value "your-actual-api-key" \
  --region $REGION

aws ssm put-parameter \
  --name "/$APP_NAME/azure-openai/us-east/deployment" \
  --type "String" \
  --value "gpt-4o-mini" \
  --region $REGION

# Secondary Azure OpenAI (EU West - Failover)
aws ssm put-parameter \
  --name "/$APP_NAME/azure-openai/eu-west/endpoint" \
  --type "String" \
  --value "https://your-openai-eu-west.openai.azure.com/" \
  --region $REGION

aws ssm put-parameter \
  --name "/$APP_NAME/azure-openai/eu-west/api-key" \
  --type "SecureString" \
  --value "your-actual-api-key" \
  --region $REGION

aws ssm put-parameter \
  --name "/$APP_NAME/azure-openai/eu-west/deployment" \
  --type "String" \
  --value "gpt-4o-mini" \
  --region $REGION

# Embedding configurations (similar pattern)
aws ssm put-parameter \
  --name "/$APP_NAME/azure-openai/us-east/embedding-endpoint" \
  --type "String" \
  --value "https://your-openai-us-east.openai.azure.com/" \
  --region $REGION

aws ssm put-parameter \
  --name "/$APP_NAME/azure-openai/us-east/embedding-key" \
  --type "SecureString" \
  --value "your-actual-embedding-api-key" \
  --region $REGION

aws ssm put-parameter \
  --name "/$APP_NAME/azure-openai/us-east/embedding-deployment" \
  --type "String" \
  --value "text-embedding-ada-002" \
  --region $REGION
```

### 4. Update Terraform Variables

Edit `infrastructure/terraform/environments/dev.tfvars`:

```terraform
aws_account_id = "YOUR_AWS_ACCOUNT_ID"  # Update this!
aws_region     = "us-east-1"
environment    = "dev"
app_name       = "rag-demo"
```

### 5. Local Development Setup

```bash
# Clone repository
git clone <your-repo-url>
cd agentic-ai

# Copy environment template
cp .env.example .env

# Edit .env with your values
# Install dependencies
cd backend
pip install -r requirements.txt

# Run locally
uvicorn app.main:app --reload
```

## 🚀 Deployment Workflows

### Option 1: Full Stack Deployment (Recommended)

Deploy everything at once:

1. Go to Actions → "Deploy Full Stack"
2. Click "Run workflow"
3. Configure options:
   - **Environment**: `dev` or `prod`
   - **Terraform action**: `apply`
   - **Deploy infrastructure**: ✅
   - **Deploy backend**: ✅
   - **Deploy lambdas**: ✅
   - **Run tests**: ✅
4. Click "Run workflow"

This will:
- ✅ Deploy AWS infrastructure (S3, SQS, Lambda, ECS, DynamoDB)
- ✅ Build and deploy backend to ECS
- ✅ Deploy Lambda functions (chunker, embedder)
- ✅ Run E2E tests

### Option 2: Individual Component Deployment

#### Deploy Infrastructure Only

1. Go to Actions → "Infrastructure - Terraform"
2. Run workflow with:
   - **Action**: `apply`
   - **Environment**: `dev`

#### Deploy Backend Only

1. Go to Actions → "Deploy to ECS"
2. Run workflow with:
   - **Environment**: `dev`
   - **Registry**: `ecr`

#### Deploy Lambdas Only

1. Go to Actions → "Deploy Lambda Functions"
2. Run workflow with:
   - **Function**: `both`

### Option 3: Continuous Deployment (Automatic)

The workflows are configured to deploy automatically on push to `main`:

- `backend/**` changes → Deploys backend to ECS
- `lambda/**` changes → Deploys Lambda functions
- `infrastructure/**` changes → Runs Terraform plan (manual apply required)

## 🧪 Testing

### Run Tests Locally

```bash
cd backend

# Unit tests
pytest tests/test_api.py -v

# Integration tests
pytest tests/test_e2e.py::TestHealthEndpoints -v

# AWS integration tests (requires AWS credentials)
export RUN_AWS_TESTS=1
pytest tests/test_e2e.py::TestAWSIntegration -v

# Full E2E tests
export RUN_E2E_TESTS=1
pytest tests/test_e2e.py -v
```

### Run Tests via GitHub Actions

1. Go to Actions → "E2E Tests"
2. Run workflow with:
   - **Environment**: `dev`
   - **Run AWS tests**: ✅

## 📊 Monitoring Deployment

### Check Terraform State

View in Terraform Cloud:
1. Go to your workspace
2. Click "Runs" to see deployment history
3. Check "State" to see current infrastructure

### Check ECS Deployment

```bash
# List ECS clusters
aws ecs list-clusters

# Get service status
aws ecs describe-services \
  --cluster rag-demo \
  --services backend

# Get task status
aws ecs list-tasks \
  --cluster rag-demo \
  --service-name backend
```

### Check Lambda Functions

```bash
# List functions
aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `rag-demo`)].FunctionName'

# Get function status
aws lambda get-function --function-name rag-demo-chunker
aws lambda get-function --function-name rag-demo-embedder
```

### View Logs

```bash
# ECS logs
aws logs tail /ecs/rag-demo --follow

# Lambda chunker logs
aws logs tail /aws/lambda/rag-demo-chunker --follow

# Lambda embedder logs
aws logs tail /aws/lambda/rag-demo-embedder --follow
```

## 🔄 End-to-End Test Flow

1. **Upload Document** → S3 bucket (uploads/ folder)
2. **S3 Event** → Triggers SQS message
3. **Chunker Lambda** → Processes document, creates chunks
4. **SQS** → Chunks sent to embedding queue
5. **Embedder Lambda** → Generates embeddings, stores in vector DB
6. **Query API** → Retrieves relevant chunks, generates response

### Verify Flow

```bash
# 1. Upload a test document
curl -X POST http://<ecs-endpoint>:8000/upload \
  -F "file=@sample-docs/product-features.txt"

# 2. Check S3 bucket
aws s3 ls s3://rag-demo-documents-<account-id>/uploads/

# 3. Check SQS queues
aws sqs get-queue-attributes \
  --queue-url <chunking-queue-url> \
  --attribute-names ApproximateNumberOfMessages

# 4. Check Lambda invocations
aws lambda get-function --function-name rag-demo-chunker \
  --query 'Configuration.LastUpdateStatus'

# 5. Query the document
curl -X POST http://<ecs-endpoint>:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What are the product features?", "n_results": 5}'
```

## 🛠️ Troubleshooting

### Terraform Cloud Issues

**Problem**: "Organization not found"
- Verify organization name in `providers.tf` matches your Terraform Cloud org
- Check `TF_API_TOKEN` is valid

**Problem**: "Invalid credentials"
- Verify AWS credentials in Terraform Cloud workspace variables
- Ensure credentials have appropriate IAM permissions

### ECS Deployment Issues

**Problem**: Task fails to start
- Check CloudWatch logs: `/ecs/rag-demo`
- Verify environment variables in task definition
- Check security group allows port 8000

**Problem**: Service unhealthy
- Check health endpoint: `curl http://<ip>:8000/health`
- Verify SSM parameters exist and are accessible
- Check IAM role permissions

### Lambda Deployment Issues

**Problem**: Lambda timeout
- Increase timeout in `variables.tf`
- Check dependency package size
- Consider using Lambda layers for large dependencies

**Problem**: Permission denied
- Verify IAM role has required permissions (S3, SQS, DynamoDB, SSM)
- Check KMS key permissions for encrypted SSM parameters

## 📝 Next Steps

1. ✅ Set up Terraform Cloud organization and workspace
2. ✅ Configure GitHub Secrets
3. ✅ Add Azure OpenAI credentials to AWS SSM
4. ✅ Run "Deploy Full Stack" workflow
5. ✅ Test the deployment with sample documents
6. ✅ Set up monitoring and alerting
7. ✅ Configure custom domain (optional)
8. ✅ Set up CloudFront for API (optional)

## 💰 Cost Optimization

Monitor costs in AWS Cost Explorer:
- Lambda invocations
- ECS Fargate hours
- S3 storage and requests
- DynamoDB read/write capacity
- Data transfer

Expected costs for dev environment: **$1-5/day**

## 🔒 Security Checklist

- ✅ All secrets stored in AWS SSM or GitHub Secrets
- ✅ S3 bucket encryption enabled
- ✅ DynamoDB encryption enabled
- ✅ VPC security groups configured
- ✅ IAM roles follow least privilege
- ✅ No hardcoded credentials in code
- ✅ CORS configured appropriately

## 📚 Additional Resources

- [Terraform Cloud Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Azure OpenAI Documentation](https://learn.microsoft.com/en-us/azure/ai-services/openai/)

