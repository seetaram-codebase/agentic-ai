# 🚨 Disaster Recovery & Business Continuity

> **Purpose**: Comprehensive disaster recovery procedures and RTO/RPO targets  
> **Audience**: Operations team, incident responders, business continuity planners

---

## 📋 Executive Summary

This document defines disaster recovery procedures for our Document RAG system, including:
- **RTO/RPO targets** for each failure scenario
- **Recovery runbooks** with step-by-step procedures
- **Backup and restore** strategies
- **Testing procedures** for DR readiness

### Key Commitments

| Scenario | RTO (Recovery Time) | RPO (Data Loss) | Auto-Recovery |
|----------|---------------------|-----------------|---------------|
| Container failure | < 60 seconds | Zero | ✅ Automatic |
| Lambda crash | < 30 seconds | Zero | ✅ Automatic (retry) |
| Azure region down | < 1 second | Zero | ✅ Automatic |
| Database corruption | < 5 minutes | < 1 hour (PITR) | ⚠️ Manual |
| S3 data loss | < 10 minutes | < 24 hours (versioning) | ⚠️ Manual |
| Complete AWS region outage | < 4 hours | Zero | ❌ Manual (future: auto) |

---

## 🏗️ Backup Strategy

### What Gets Backed Up

```
┌─────────────────────────────────────────────────────────┐
│                    Data Layer                            │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ✅ DynamoDB Tables (Automatic)                          │
│  ├─ Point-in-Time Recovery (PITR): 35 days             │
│  ├─ Continuous backups                                  │
│  └─ Restore to any second in last 35 days              │
│                                                           │
│  ✅ S3 Bucket (Automatic)                                │
│  ├─ Versioning: Enabled                                 │
│  ├─ Lifecycle: Keep all versions 90 days               │
│  └─ Cross-region replication: Not configured           │
│                                                           │
│  ✅ SSM Parameters (Automatic)                           │
│  ├─ Version history: Unlimited                          │
│  ├─ Previous values: Always accessible                  │
│  └─ Rollback: Instant                                   │
│                                                           │
│  ✅ Lambda Code (Automatic)                              │
│  ├─ Previous versions: Kept indefinitely                │
│  ├─ Version aliases: point to specific versions         │
│  └─ Rollback: Update function configuration            │
│                                                           │
│  ✅ ECS Task Definitions (Automatic)                     │
│  ├─ All revisions: Retained                             │
│  ├─ Rollback: Update service to previous revision       │
│  └─ History: Complete audit trail                       │
│                                                           │
│  ✅ Terraform State (Automatic)                          │
│  ├─ S3 backend: State file in S3                        │
│  ├─ Versioning: Enabled on S3 bucket                    │
│  ├─ Locking: DynamoDB prevents concurrent changes       │
│  └─ Rollback: Restore previous state version            │
│                                                           │
│  ✅ Docker Images (Automatic)                            │
│  ├─ ECR: All images tagged with git SHA                 │
│  ├─ Retention: 30 days (configurable)                   │
│  └─ Rollback: Deploy previous image tag                 │
│                                                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│              What's NOT Backed Up                        │
├─────────────────────────────────────────────────────────┤
│  ⚠️  Pinecone Vector Database                            │
│  └─ Reason: Third-party SaaS, no direct backup access   │
│  └─ Mitigation: Can rebuild from S3 documents           │
│                                                           │
│  ⚠️  Azure OpenAI Fine-tuned Models (N/A)                │
│  └─ Reason: Not using fine-tuning currently             │
│                                                           │
│  ⚠️  CloudWatch Logs > 30 days                           │
│  └─ Reason: Cost optimization (30-day retention)        │
│  └─ Mitigation: Export to S3 if long-term needed        │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 RTO/RPO Targets

### Tier 1: Critical (< 5 min RTO, Zero RPO)

**Services**: Backend API, Document Upload, Query

| Scenario | RTO | RPO | Procedure |
|----------|-----|-----|-----------|
| ECS container unhealthy | 60s | 0 | Automatic (ECS replaces) |
| Azure OpenAI us-east down | 1s | 0 | Automatic (failover eu-west) |
| Lambda function error | 30s | 0 | Automatic (SQS retry) |

### Tier 2: Important (< 1 hour RTO, < 1 hour RPO)

**Services**: Document Processing, Embeddings

| Scenario | RTO | RPO | Procedure |
|----------|-----|-----|-----------|
| DynamoDB table corrupted | 5min | 1hr | Manual (PITR restore) |
| S3 bucket data deleted | 10min | 0 | Manual (restore versions) |
| Lambda deployment broken | 5min | 0 | Manual (rollback version) |

### Tier 3: Non-Critical (< 4 hours RTO, < 24 hours RPO)

**Services**: Analytics, Reporting

| Scenario | RTO | RPO | Procedure |
|----------|-----|-----|-----------|
| CloudWatch logs lost | N/A | 30d | Not recoverable (retention) |
| Pinecone index corrupted | 2hr | 0 | Rebuild from S3 documents |
| Complete AWS region down | 4hr | 0 | Redeploy to new region |

---

## 📖 Recovery Runbooks

### Runbook 1: Restore DynamoDB from PITR

**Scenario**: Document metadata corrupted or accidentally deleted

**RTO**: 5 minutes  
**RPO**: < 1 hour (can restore to any second in last 35 days)

**Prerequisites**:
- AWS CLI configured
- IAM permissions for DynamoDB restore

**Procedure**:

```bash
# Step 1: Identify restore point
# Find time before corruption occurred
aws dynamodb describe-continuous-backups \
  --table-name rag-demo-documents

# Step 2: Restore to new table
RESTORE_TIME="2026-02-19T00:00:00Z"  # UTC timestamp

aws dynamodb restore-table-to-point-in-time \
  --source-table-name rag-demo-documents \
  --target-table-name rag-demo-documents-restored \
  --restore-date-time $RESTORE_TIME

# Step 3: Wait for restore to complete (5-10 minutes)
aws dynamodb wait table-exists \
  --table-name rag-demo-documents-restored

# Step 4: Verify data
aws dynamodb scan \
  --table-name rag-demo-documents-restored \
  --max-items 10

# Step 5: Update application to use restored table
# Option A: Rename tables (requires downtime)
aws dynamodb delete-table --table-name rag-demo-documents
# Wait for deletion...
# Rename restored table (requires Terraform or console)

# Option B: Update Terraform and redeploy
# Edit terraform/dynamodb.tf to point to new table
terraform apply

# Step 6: Update ECS task definition environment variable
# DYNAMODB_DOCUMENTS_TABLE=rag-demo-documents-restored

# Step 7: Deploy updated task definition
aws ecs update-service \
  --cluster rag-demo \
  --service rag-demo-service \
  --force-new-deployment

# Total time: ~5-10 minutes
```

---

### Runbook 2: Restore S3 Object from Version

**Scenario**: Document accidentally deleted or overwritten

**RTO**: < 1 minute  
**RPO**: Zero (all versions retained for 90 days)

**Procedure**:

```bash
# Step 1: List versions of the file
aws s3api list-object-versions \
  --bucket rag-demo-documents-971778147952 \
  --prefix uploads/document.txt

# Output shows:
# VersionId: xyz123 (current - deleted)
# VersionId: abc789 (previous - good)

# Step 2: Restore previous version
aws s3api copy-object \
  --bucket rag-demo-documents-971778147952 \
  --copy-source rag-demo-documents-971778147952/uploads/document.txt?versionId=abc789 \
  --key uploads/document.txt

# Or download specific version
aws s3api get-object \
  --bucket rag-demo-documents-971778147952 \
  --key uploads/document.txt \
  --version-id abc789 \
  document-restored.txt

# Step 3: Verify restoration
aws s3 ls s3://rag-demo-documents-971778147952/uploads/

# Total time: < 1 minute
```

---

### Runbook 3: Rollback Lambda Deployment

**Scenario**: New Lambda code has bugs, causing failures

**RTO**: < 2 minutes  
**RPO**: Zero (code rollback, no data loss)

**Procedure**:

```bash
# Step 1: Check current version
aws lambda get-function \
  --function-name rag-demo-embedder \
  --query 'Configuration.Version'

# Step 2: List recent versions
aws lambda list-versions-by-function \
  --function-name rag-demo-embedder \
  --query 'Versions[*].[Version,LastModified]' \
  --output table

# Step 3: Test previous version
aws lambda invoke \
  --function-name rag-demo-embedder:42 \  # Version 42
  --payload '{"test": true}' \
  response.json

# Step 4: Update function alias to previous version
aws lambda update-alias \
  --function-name rag-demo-embedder \
  --name production \
  --function-version 42

# OR: Republish previous version via GitHub Actions
# Go to Actions → Deploy Embedder Lambda → Run workflow on previous commit

# Total time: < 2 minutes
```

---

### Runbook 4: Rollback ECS Deployment

**Scenario**: New backend code causes errors

**RTO**: < 3 minutes  
**RPO**: Zero (code rollback, no data loss)

**Procedure**:

```bash
# Step 1: Check current task definition
aws ecs describe-services \
  --cluster rag-demo \
  --services rag-demo-service \
  --query 'services[0].taskDefinition'

# Output: rag-demo-backend:45 (current - broken)

# Step 2: List recent task definitions
aws ecs list-task-definitions \
  --family-prefix rag-demo-backend \
  --sort DESC \
  --max-items 10

# Step 3: Update service to previous version
aws ecs update-service \
  --cluster rag-demo \
  --service rag-demo-service \
  --task-definition rag-demo-backend:44  # Previous good version

# Step 4: Monitor deployment
aws ecs describe-services \
  --cluster rag-demo \
  --services rag-demo-service \
  --query 'services[0].deployments'

# Step 5: Wait for rollback to complete
aws ecs wait services-stable \
  --cluster rag-demo \
  --services rag-demo-service

# Total time: 2-3 minutes (ECS rolling update)
```

---

### Runbook 5: Rebuild Pinecone Index from S3

**Scenario**: Pinecone index corrupted or lost

**RTO**: 2 hours (depends on document count)  
**RPO**: Zero (rebuild from S3 source documents)

**Procedure**:

```bash
# Step 1: List all documents in S3
aws s3 ls s3://rag-demo-documents-971778147952/uploads/ \
  > documents_list.txt

# Step 2: Create new Pinecone index (if needed)
# Via Pinecone console or API

# Step 3: Trigger reprocessing of all documents
# Option A: Via API (bulk)
for doc in $(cat documents_list.txt); do
  curl -X POST http://13.222.106.90:8000/reprocess \
    -H "Content-Type: application/json" \
    -d "{\"s3_key\": \"$doc\"}"
done

# Option B: Send S3 events to SQS manually
aws s3 ls s3://rag-demo-documents-971778147952/uploads/ \
  | awk '{print $4}' \
  | while read file; do
      aws sqs send-message \
        --queue-url https://sqs.us-east-1.amazonaws.com/.../rag-demo-document-chunking \
        --message-body "{\"Records\":[{\"s3\":{\"bucket\":{\"name\":\"rag-demo-documents-971778147952\"},\"object\":{\"key\":\"uploads/$file\"}}}]}"
    done

# Step 4: Monitor progress
aws logs tail /aws/lambda/rag-demo-embedder --follow

# Step 5: Verify embeddings in Pinecone
# Check Pinecone dashboard for vector count

# Total time: ~2 hours for 1000 documents
# (Parallelized via Lambda auto-scaling)
```

---

### Runbook 6: Complete AWS Region Failover

**Scenario**: us-east-1 region unavailable

**RTO**: 4 hours (manual redeployment)  
**RPO**: Zero (state in S3, can redeploy to new region)

**Current Status**: ⚠️ Manual process (future: automate with Route53)

**Procedure**:

```bash
# Step 1: Verify region outage
# Check AWS Service Health Dashboard
# https://status.aws.amazon.com/

# Step 2: Clone infrastructure to new region
cd infrastructure/terraform

# Step 3: Update region in variables
# Edit terraform.tfvars
aws_region = "us-west-2"  # or eu-west-1

# Step 4: Initialize Terraform for new region
terraform init -reconfigure

# Step 5: Plan deployment
terraform plan -out=failover.tfplan

# Step 6: Review and apply
terraform apply failover.tfplan

# Step 7: Wait for infrastructure (30-45 minutes)
# - VPC, subnets, security groups
# - ECS cluster, service, tasks
# - Lambda functions
# - DynamoDB tables (empty, will restore)

# Step 8: Restore DynamoDB from snapshot
# (Manual via console or automated script)

# Step 9: Copy S3 data to new region
aws s3 sync \
  s3://rag-demo-documents-971778147952 \
  s3://rag-demo-documents-NEWREGION \
  --source-region us-east-1 \
  --region us-west-2

# Step 10: Update DNS (if using custom domain)
# Point domain to new ECS task public IP

# Step 11: Update SSM parameters
# Copy Azure OpenAI configs to new region

# Step 12: Test end-to-end
curl http://NEW-IP:8000/health

# Total time: 3-4 hours
```

---

## 🧪 DR Testing Procedures

### Monthly DR Drill Checklist

**Duration**: 30 minutes  
**Frequency**: Monthly (first Tuesday)  
**Team**: Operations + 1 developer

**Test Scenarios**:

1. **Azure OpenAI Failover** (5 min)
   ```bash
   # Break us-east, verify eu-west takes over
   aws ssm put-parameter \
     --name "/rag-demo/azure-openai/us-east/endpoint" \
     --value "https://INVALID.openai.azure.com/" \
     --overwrite
   
   # Make request, check logs for failover
   curl -X POST http://13.222.106.90:8000/query \
     -H "Content-Type: application/json" \
     -d '{"query": "test"}'
   
   # Restore
   aws ssm put-parameter \
     --name "/rag-demo/azure-openai/us-east/endpoint" \
     --value "https://CORRECT.openai.azure.com/" \
     --overwrite
   ```

2. **ECS Container Failure** (10 min)
   ```bash
   # Stop running task manually
   TASK_ARN=$(aws ecs list-tasks --cluster rag-demo --query 'taskArns[0]' --output text)
   aws ecs stop-task --cluster rag-demo --task $TASK_ARN
   
   # Watch ECS start replacement
   aws ecs describe-services --cluster rag-demo --services rag-demo-service
   
   # Verify health endpoint
   curl http://13.222.106.90:8000/health
   ```

3. **Lambda Rollback** (5 min)
   ```bash
   # Deploy broken code (via test branch)
   # Verify failure in logs
   # Roll back to previous version
   aws lambda update-function-code \
     --function-name rag-demo-embedder \
     --s3-bucket previous-deploy-bucket \
     --s3-key embedder-v41.zip
   ```

4. **DynamoDB Restore** (10 min)
   ```bash
   # Restore to test table (don't touch prod)
   aws dynamodb restore-table-to-point-in-time \
     --source-table-name rag-demo-documents \
     --target-table-name rag-demo-documents-dr-test \
     --restore-date-time "2026-02-18T12:00:00Z"
   
   # Verify data
   # Delete test table when done
   ```

**Success Criteria**:
- ✅ All scenarios complete within expected RTO
- ✅ No data loss (RPO = 0)
- ✅ All automatic recoveries work
- ✅ Manual procedures documented and tested

---

## 📊 Incident Response Procedures

### Severity Levels

| Severity | Definition | Response Time | Escalation |
|----------|-----------|---------------|------------|
| **SEV1** | Complete outage | 5 minutes | Immediate (on-call) |
| **SEV2** | Partial outage | 15 minutes | Within 30 min |
| **SEV3** | Performance degraded | 1 hour | During business hours |
| **SEV4** | Minor issue | 1 day | Standard ticket |

### SEV1 Response Procedure

**Examples**: Complete system down, data loss, security breach

**Response**:
1. **Alert** (0-5 min)
   - PagerDuty/CloudWatch alarm triggers
   - On-call engineer notified

2. **Assess** (5-10 min)
   - Check health dashboard
   - Review CloudWatch metrics
   - Check AWS Service Health

3. **Communicate** (10-15 min)
   - Post to status page
   - Notify stakeholders
   - Start incident channel (Slack)

4. **Mitigate** (15-60 min)
   - Execute relevant runbook
   - Implement workaround if needed
   - Monitor recovery

5. **Resolve** (variable)
   - Verify full functionality
   - Update status page
   - Schedule post-mortem

6. **Post-Mortem** (within 48 hours)
   - Timeline of events
   - Root cause analysis
   - Action items to prevent recurrence

---

## 🔍 Monitoring for DR Readiness

### Health Indicators

**Green (Healthy)**:
- All health checks passing
- Both Azure regions responding
- ECS desired count = running count
- SQS DLQ message count = 0

**Yellow (Degraded)**:
- One Azure region down (using failover)
- ECS tasks restarting (but recovering)
- Lambda errors < 1%

**Red (Critical)**:
- Both Azure regions down
- ECS service unavailable
- Lambda errors > 5%
- DLQ message count > 10

### Alerts to Configure

```yaml
# CloudWatch Alarms
Alarms:
  - Name: ECSTaskCountLow
    Metric: RunningTaskCount
    Threshold: < 1
    Actions: [Page on-call]
  
  - Name: LambdaErrorRateHigh
    Metric: Errors
    Threshold: > 5%
    Actions: [Page on-call]
  
  - Name: DLQMessagesPresent
    Metric: ApproximateNumberOfMessagesVisible
    Threshold: > 10
    Actions: [Email team]
  
  - Name: AzureFailoverActive
    Metric: Custom/FailoverCount
    Threshold: > 5 in 5 min
    Actions: [Slack notification]
```

---

## 💰 Cost of DR Capabilities

### Current Costs

| Feature | Monthly Cost | Benefit |
|---------|-------------|----------|
| **DynamoDB PITR** | ~$2 | Restore to any second (35 days) |
| **S3 Versioning** | ~$1 | Protect against deletions |
| **Lambda Versions** | $0 | Free (metadata only) |
| **ECS Task Revisions** | $0 | Free (metadata only) |
| **SSM Parameter History** | $0 | Free (< 10k parameters) |
| **Azure OpenAI 2nd Region** | $0 | Pay-per-use (no idle cost) |

**Total DR Cost**: ~$3/month

**ROI**: Prevent hours of downtime worth thousands in lost productivity/revenue

---

## 🎓 Best Practices

### DO ✅
- Test DR procedures monthly
- Document all recovery steps
- Monitor backup success
- Set appropriate RPO/RTO targets
- Practice incident response
- Keep runbooks up to date
- Automate recovery where possible

### DON'T ❌
- Assume backups work without testing
- Set unrealistic RTO/RPO targets
- Skip DR drills to save time
- Forget to update runbooks after changes
- Store credentials in runbooks
- Panic during incidents
- Skip post-mortems

---

**Document Version**: 1.0  
**Last Updated**: February 19, 2026  
**Next Review**: March 19, 2026  
**Maintained By**: Operations Team

