# LangSmith + IAM Fix - Deployment Checklist

## Quick Deploy (5 minutes)

### ✅ Step 1: Apply Terraform (2 min)
```bash
cd infrastructure/terraform
terraform apply
```

**What this does:**
- ✅ Adds SSM permissions to ECS task execution role (fixes AccessDeniedException)
- ✅ Configures LangSmith environment variables in ECS task
- ✅ Sets up LangSmith API key as secret from SSM

### ✅ Step 2: Verify API Key (1 min)
```bash
aws ssm get-parameter \
  --name "/rag-demo/langsmith/api-key" \
  --with-decryption \
  --region us-east-1 \
  --query 'Parameter.Value' \
  --output text
```

Should show: `lsv2_pt_xxxxxxxxxxxxx`

### ✅ Step 3: Wait for ECS (1-2 min)
ECS automatically redeploys with new configuration.

Check status:
```bash
aws ecs describe-services \
  --cluster rag-demo \
  --services backend \
  --region us-east-1 \
  --query 'services[0].deployments' \
  --output table
```

Wait for `runningCount` = `desiredCount`

### ✅ Step 4: Test (1 min)
```bash
# Get ECS task IP
aws ecs list-tasks --cluster rag-demo --service backend --region us-east-1
aws ecs describe-tasks --cluster rag-demo --tasks <TASK_ARN> --region us-east-1

# Test query
curl -X POST http://ECS_IP:8000/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What is machine learning?"}'
```

### ✅ Step 5: View Traces
1. Go to https://smith.langchain.com/
2. Login
3. Select project: `rag-demo`
4. See traces! 🎉

## What's Fixed

### Before:
❌ ECS tasks failing: `AccessDeniedException: ssm:GetParameters`  
❌ No LangSmith traces

### After:
✅ ECS tasks running  
✅ LangSmith automatically tracing all Azure OpenAI calls  
✅ No code changes needed!

## Files Modified

1. `infrastructure/terraform/iam.tf`
   - Added SSM permissions to ECS task execution role

2. `infrastructure/terraform/ecs.tf`
   - Already has LangSmith environment variables configured

3. `backend/requirements.txt`
   - Already has `langsmith` package

## That's It!

**Zero code changes needed** - LangSmith automatically instruments the OpenAI SDK when environment variables are set.

Just run `terraform apply` and you're done! 🚀

