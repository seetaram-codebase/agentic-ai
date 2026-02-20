# Post-Terraform Apply - Verification Steps

✅ **Terraform already applied!** Now let's verify everything is working.

## Quick Verification (2 minutes)

### 1. Check ECS Task is Running
```powershell
aws ecs describe-services `
  --cluster rag-demo `
  --services backend `
  --region us-east-1 `
  --query 'services[0].{Running:runningCount,Desired:desiredCount}' `
  --output table
```

**Expected:** `Running` should equal `Desired` (usually 1)

### 2. Get ECS Task IP
```powershell
# List tasks
$taskArn = aws ecs list-tasks --cluster rag-demo --service-name backend --region us-east-1 --query 'taskArns[0]' --output text

# Get IP
aws ecs describe-tasks --cluster rag-demo --tasks $taskArn --region us-east-1 --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' --output text
```

Save this IP for testing!

### 3. Test Backend
```powershell
# Replace with your actual IP
$IP = "YOUR_ECS_IP"

# Health check
Invoke-RestMethod -Uri "http://${IP}:8000/health"

# Should return: {"status": "healthy"}
```

### 4. Make Test Query
```powershell
.\scripts\test-langsmith.ps1
```

Or manually:
```powershell
$body = @{ question = "What is AI?" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://${IP}:8000/query" -Method Post -Body $body -ContentType "application/json"
```

### 5. Check LangSmith
1. Go to https://smith.langchain.com/
2. Login
3. Select project: **rag-demo**
4. Look for recent traces (last 5 minutes)

**What you should see:**
- Trace with embeddings call
- Trace with chat completion
- Provider info (us-east or eu-west)
- Latency and cost data

## If No Traces Appear

### Check 1: Environment Variables Set?
```powershell
aws ecs describe-task-definition `
  --task-definition rag-demo-backend `
  --region us-east-1 `
  --query 'taskDefinition.containerDefinitions[0].environment[?name==`LANGCHAIN_TRACING_V2`]'
```

**Expected:** `[{"name": "LANGCHAIN_TRACING_V2", "value": "true"}]`

### Check 2: API Key Configured?
```powershell
aws ssm get-parameter `
  --name "/rag-demo/langsmith/api-key" `
  --with-decryption `
  --region us-east-1 `
  --query 'Parameter.Value' `
  --output text
```

**Expected:** Shows your `lsv2_pt_xxxxx` key

### Check 3: Check Logs
```powershell
aws logs tail /aws/ecs/rag-demo-backend --follow --region us-east-1
```

Look for:
- ✅ `Starting server...` - Backend started
- ✅ `Loaded configs from SSM` - Configuration loaded
- ❌ Any errors about LangSmith or langsmith package

### Check 4: LangSmith Package Installed?
```powershell
# Check if langsmith is in requirements.txt
Get-Content backend\requirements.txt | Select-String "langsmith"
```

**Expected:** `langsmith==0.1.77`

## Common Issues

### Issue: "Module 'langsmith' not found"
**Solution:** 
```bash
cd backend
pip install langsmith
# Rebuild Docker image
docker build -t backend .
```

### Issue: "Invalid API key"
**Solution:**
```powershell
# Update the key in SSM
.\scripts\setup-langsmith.ps1 -LangSmithApiKey "lsv2_pt_NEW_KEY"

# Redeploy ECS
aws ecs update-service --cluster rag-demo --service backend --force-new-deployment --region us-east-1
```

### Issue: "Project not found"
**Solution:**
- Create project in LangSmith with exact name: `rag-demo`
- Or update `LANGCHAIN_PROJECT` env var in Terraform

## Success Criteria ✅

You know it's working when:
1. ✅ ECS task is running (no errors in logs)
2. ✅ Backend responds to health check
3. ✅ Query succeeds and returns response
4. ✅ **Traces appear in LangSmith dashboard**

## Next Steps

Once traces appear:
- 📊 Monitor query performance
- 💰 Track costs per query
- 🔄 See failover events in real-time
- 🐛 Debug slow queries
- 📈 Analyze usage patterns

**That's it! LangSmith is now tracking all your RAG queries!** 🎉

