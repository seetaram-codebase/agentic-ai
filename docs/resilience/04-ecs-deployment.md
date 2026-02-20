# 🐳 ECS Container Orchestration & Resilience

> **Resilience Feature**: Self-healing containerized backend with health checks  
> **RTO**: < 60 seconds (container replacement)  
> **RPO**: Zero (stateless containers)

---

## 📋 Overview

Our backend API runs on **AWS ECS (Elastic Container Service)** with Fargate, providing:
- **Self-healing**: Automatic unhealthy container replacement
- **Zero-downtime deployments**: Rolling updates
- **Auto-scaling**: CPU/memory-based scaling
- **Health monitoring**: Continuous health checks

---

## 🏗️ ECS Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      ECS Cluster                              │
│                      "rag-demo"                               │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │           ECS Service: rag-demo-service                 │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Desired Count: 1-3 (auto-scaling)               │  │  │
│  │  │  Launch Type: FARGATE (serverless)               │  │  │
│  │  │  Network: awsvpc (each task gets own ENI)        │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │                                                          │  │
│  │  ┌─────────────────────────────────────────────────┐   │  │
│  │  │  Task Definition: rag-demo-backend:42           │   │  │
│  │  │  ├─ CPU: 512 units (0.5 vCPU)                   │   │  │
│  │  │  ├─ Memory: 1024 MB                              │   │  │
│  │  │  ├─ Container: rag-demo-backend                  │   │  │
│  │  │  │  ├─ Image: ECR/rag-demo:latest                │   │  │
│  │  │  │  ├─ Port: 8000 (HTTP)                         │   │  │
│  │  │  │  └─ Environment: 20+ variables                │   │  │
│  │  │  └─ Health Check:                                │   │  │
│  │  │     ├─ Command: /health endpoint                 │   │  │
│  │  │     ├─ Interval: 30 seconds                      │   │  │
│  │  │     ├─ Timeout: 5 seconds                        │   │  │
│  │  │     └─ Retries: 3                                │   │  │
│  │  └─────────────────────────────────────────────────┘   │  │
│  │                                                          │  │
│  │  Running Tasks:                                          │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Task 1: rag-demo-backend-abc123                 │  │  │
│  │  │  ├─ Status: RUNNING                               │  │  │
│  │  │  ├─ Health: HEALTHY                               │  │  │
│  │  │  ├─ Public IP: 13.222.106.90                      │  │  │
│  │  │  └─ Uptime: 2 days                                │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │                                                          │  │
│  │  (Tasks 2-3 launch during high load or deployments)     │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

---

## 🔧 Health Check Configuration

### Container Health Check (Docker)

**File**: `backend/Dockerfile`

```dockerfile
# Health check runs inside container
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8000/health', timeout=5)"
```

**Parameters**:
- **Interval**: 30 seconds between checks
- **Timeout**: 5 seconds per check
- **Start Period**: 60 seconds grace period on startup
- **Retries**: 3 consecutive failures = unhealthy

### ECS Health Check

**File**: `infrastructure/terraform/ecs.tf`

```hcl
resource "aws_ecs_service" "backend" {
  health_check_grace_period_seconds = 60
  
  # ECS monitors task health via Docker health check
  # If unhealthy, ECS stops and replaces task
}
```

### FastAPI Health Endpoint

**File**: `backend/app/main.py`

```python
@app.get("/health")
async def health_check():
    """
    Comprehensive health check endpoint
    Returns 200 if all systems operational
    """
    try:
        # Check database connectivity
        dynamodb_status = check_dynamodb()
        
        # Check S3 connectivity
        s3_status = check_s3()
        
        # Check Azure OpenAI
        azure_status = check_azure_openai()
        
        # Overall health
        healthy = all([
            dynamodb_status.get('healthy'),
            s3_status.get('healthy'),
            azure_status.get('healthy')
        ])
        
        return {
            "status": "healthy" if healthy else "degraded",
            "timestamp": datetime.utcnow().isoformat(),
            "version": "1.0.0",
            "services": {
                "dynamodb": dynamodb_status,
                "s3": s3_status,
                "azure_openai": azure_status
            }
        }
    except Exception as e:
        # Return 500 on error (marks container unhealthy)
        raise HTTPException(status_code=500, detail=str(e))
```

---

## 🔄 Self-Healing Process

### Automatic Container Replacement

**Timeline of Failure → Recovery**:

```
00:00 - Container running normally, health checks passing
00:30 - Health check #1 fails (app unresponsive)
01:00 - Health check #2 fails (consecutive failure)
01:30 - Health check #3 fails (3 consecutive = unhealthy)
01:31 - ECS marks task as UNHEALTHY
01:32 - ECS starts NEW task (replacement)
01:33 - New container starts up (60s grace period begins)
02:32 - Grace period ends, health checks start
02:33 - Health check #1 passes
03:03 - Health check #2 passes
03:33 - Health check #3 passes (3 consecutive = healthy)
03:34 - ECS marks new task as HEALTHY
03:35 - ECS stops OLD unhealthy task
03:36 - System fully recovered
```

**Total Downtime**: ~2 minutes (worst case, single task)

**With Multiple Tasks**: **Zero downtime** (other tasks still serving)

---

## 🚀 Deployment Strategy

### Rolling Update Configuration

**File**: `infrastructure/terraform/ecs.tf`

```hcl
resource "aws_ecs_service" "backend" {
  desired_count = 1  # Can scale 1-3
  
  deployment_configuration {
    minimum_healthy_percent = 50   # Allow 50% down during deploy
    maximum_percent         = 200  # Can have 2x tasks during deploy
  }
  
  deployment_circuit_breaker {
    enable   = true   # Auto-rollback on failure
    rollback = true
  }
}
```

### Zero-Downtime Deployment Process

**GitHub Actions**: `.github/workflows/deploy-ecs.yml`

```yaml
steps:
  1. Build new Docker image
  2. Tag with git SHA + 'latest'
  3. Push to Amazon ECR
  4. Create new ECS task definition revision
  5. Update ECS service
  
  # ECS Rolling Update:
  6. Start new task (revision N+1)
  7. Wait for new task health checks
  8. New task becomes HEALTHY
  9. Stop old task (revision N)
  10. Deployment complete
```

**Key Points**:
- ✅ Old version keeps running until new version healthy
- ✅ If new version fails health checks → auto-rollback
- ✅ Maximum tasks = 2x during deployment (200%)
- ✅ Minimum healthy = 50% (at least 1 task always up)

### Deployment Timeline

```
00:00 - GitHub Actions triggered (git push to main)
00:30 - Docker image built
01:00 - Image pushed to ECR
01:30 - New task definition created
01:35 - ECS starts new task
02:35 - New task health checks passing
02:40 - ECS stops old task
02:45 - Deployment complete

Total Time: ~3 minutes
User Impact: Zero (old task served requests until new ready)
```

---

## 📊 Auto-Scaling

### CPU-Based Scaling

**File**: `infrastructure/terraform/ecs.tf`

```hcl
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 3   # Scale up to 3 tasks
  min_capacity       = 1   # Minimum 1 task
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "scale_up" {
  name               = "${var.app_name}-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0  # Target 70% CPU
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300   # 5 min before scale down
    scale_out_cooldown = 60    # 1 min before scale up
  }
}
```

### Scaling Behavior

**Scale Up** (CPU > 70%):
```
00:00 - CPU hits 75% (above target)
00:15 - CloudWatch alarm triggers
00:20 - Auto-scaling starts task #2
01:20 - Task #2 health checks pass
01:25 - Task #2 starts receiving traffic
01:30 - CPU drops to 40% (2 tasks sharing load)
```

**Scale Down** (CPU < 70% for 5 min):
```
00:00 - CPU at 30% (below target)
05:00 - Cooldown period passes
05:01 - Auto-scaling stops 1 task
05:02 - Back to 1 task
05:03 - CPU at 60% (acceptable)
```

---

## 🔍 Monitoring & Troubleshooting

### CloudWatch Metrics

**Key Metrics to Monitor**:
1. **CPUUtilization**: Target < 70%
2. **MemoryUtilization**: Target < 80%
3. **HealthyTaskCount**: Should equal DesiredCount
4. **UnhealthyTaskCount**: Should be 0
5. **RunningTaskCount**: Actual running tasks

### CloudWatch Logs

**Log Groups**:
```
/aws/ecs/rag-demo-backend          ← Application logs
/aws/ecs/containerinsights         ← Performance metrics
```

**Useful Queries**:

```bash
# Find errors in last hour
aws logs filter-log-events \
  --log-group-name /aws/ecs/rag-demo-backend \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern "[ERROR]"

# Find health check failures
aws logs filter-log-events \
  --log-group-name /aws/ecs/rag-demo-backend \
  --filter-pattern "health check"

# Tail live logs
aws logs tail /aws/ecs/rag-demo-backend --follow
```

### Common Issues & Solutions

#### Issue 1: Task Keeps Restarting

**Symptoms**:
```
Task stopped (ESSENTIAL container exited)
Task started
Task stopped (ESSENTIAL container exited)
... (loop)
```

**Causes**:
- App crashes on startup
- Health check fails immediately
- Missing environment variables

**Solution**:
```bash
# Check logs for errors
aws logs tail /aws/ecs/rag-demo-backend --follow

# Check task definition
aws ecs describe-task-definition \
  --task-definition rag-demo-backend

# Roll back to previous version
aws ecs update-service \
  --cluster rag-demo \
  --service rag-demo-service \
  --task-definition rag-demo-backend:41  # Previous version
```

#### Issue 2: Health Checks Failing

**Symptoms**:
```
Health check failed: timeout
Task marked UNHEALTHY
```

**Causes**:
- /health endpoint slow (> 5s)
- Database connectivity issues
- Memory leak causing slowness

**Solution**:
```bash
# Check health endpoint directly
curl http://13.222.106.90:8000/health -v

# Check CPU/Memory
aws ecs describe-tasks \
  --cluster rag-demo \
  --tasks $(aws ecs list-tasks --cluster rag-demo --query 'taskArns[0]' --output text)

# Increase timeout if needed (terraform)
# Edit ecs.tf health_check timeout
```

#### Issue 3: Deployment Stuck

**Symptoms**:
```
Deployment in progress...
Waiting for tasks to reach steady state...
(hangs for > 10 minutes)
```

**Causes**:
- New version fails health checks
- Circuit breaker triggered
- Resource limits exceeded

**Solution**:
```bash
# Check deployment status
aws ecs describe-services \
  --cluster rag-demo \
  --services rag-demo-service \
  --query 'services[0].deployments'

# Force new deployment (rollback)
aws ecs update-service \
  --cluster rag-demo \
  --service rag-demo-service \
  --force-new-deployment

# Or update to specific version
aws ecs update-service \
  --cluster rag-demo \
  --service rag-demo-service \
  --task-definition rag-demo-backend:40
```

---

## 🛡️ Resilience Patterns

### Pattern 1: Graceful Degradation

**Implementation**:
```python
# Health endpoint returns partial health
@app.get("/health")
async def health():
    # Even if Azure OpenAI down, return 200
    # Just mark that service as degraded
    return {
        "status": "healthy",  # Overall OK
        "services": {
            "azure_openai": {
                "healthy": False,  # One service down
                "failover": "active"  # But failover working
            }
        }
    }
```

**Benefit**: Container stays up even if external service down

### Pattern 2: Circuit Breaker

**Implementation** (in code):
```python
# After N failures, stop trying for T seconds
class CircuitBreaker:
    def __init__(self, threshold=5, timeout=60):
        self.failure_count = 0
        self.threshold = threshold
        self.timeout = timeout
        self.last_failure = None
        self.state = "CLOSED"  # CLOSED, OPEN, HALF_OPEN
    
    def call(self, func):
        if self.state == "OPEN":
            if time.time() - self.last_failure > self.timeout:
                self.state = "HALF_OPEN"
            else:
                raise Exception("Circuit breaker OPEN")
        
        try:
            result = func()
            self.failure_count = 0
            self.state = "CLOSED"
            return result
        except:
            self.failure_count += 1
            if self.failure_count >= self.threshold:
                self.state = "OPEN"
                self.last_failure = time.time()
            raise
```

**Benefit**: Prevents cascade failures

### Pattern 3: Retry with Exponential Backoff

**Implementation**:
```python
async def upload_to_s3_with_retry(file, max_retries=3):
    for attempt in range(max_retries):
        try:
            return await s3_client.upload_fileobj(file)
        except Exception as e:
            if attempt == max_retries - 1:
                raise  # Last attempt, give up
            
            wait_time = 2 ** attempt  # 1s, 2s, 4s
            logger.warning(f"S3 upload failed, retry {attempt+1}/{max_retries} in {wait_time}s")
            await asyncio.sleep(wait_time)
```

**Benefit**: Handles transient failures

---

## 📈 Performance Tuning

### CPU Allocation

**Current**: 512 CPU units (0.5 vCPU)

**When to Increase**:
- Sustained CPU > 80%
- Response time > 5 seconds
- Auto-scaling triggering frequently

**How to Update** (`ecs.tf`):
```hcl
resource "aws_ecs_task_definition" "backend" {
  cpu    = "1024"  # 1 vCPU (was 512)
  memory = "2048"  # 2 GB (was 1024)
}
```

### Memory Allocation

**Current**: 1024 MB

**Monitoring Memory**:
```bash
# Get memory utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=rag-demo-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Memory Leak Detection**:
- Gradually increasing memory over hours/days
- OOMKilled in logs
- Container restarts

---

## 🎓 Best Practices

### DO ✅
- Keep health check endpoint fast (< 1s)
- Monitor health check success rate
- Set appropriate resource limits (CPU/memory)
- Use rolling deployments
- Enable circuit breaker
- Log all health check failures
- Test deployments in dev first
- Keep task count > 1 in production

### DON'T ❌
- Make health checks too strict (fails on minor issues)
- Set timeout too low (< 5s)
- Ignore memory leaks
- Deploy without testing
- Run single task in production
- Hardcode resource limits
- Skip health check grace period
- Log excessive data (fills disk)

---

## 🎬 Demo for Presentation

**Duration**: 3 minutes

**Setup**:
```bash
# Terminal 1: Watch tasks
watch -n 2 'aws ecs list-tasks --cluster rag-demo --query "taskArns" --output table'

# Terminal 2: Tail logs
aws logs tail /aws/ecs/rag-demo-backend --follow

# Browser: Health endpoint
http://13.222.106.90:8000/health
```

**Demo Steps**:

1. **Show Healthy State** (30s)
   - Show health endpoint returns 200
   - Show task running in ECS console

2. **Simulate Failure** (1 min)
   - Update code to make health check fail
   - Deploy via GitHub Actions
   - Show ECS detecting unhealthy task

3. **Show Auto-Recovery** (1 min)
   - ECS stops unhealthy task
   - ECS starts replacement task
   - New task becomes healthy

4. **Show Rolling Deployment** (30s)
   - Deploy new version
   - Show old task stays up
   - New task starts, health checks
   - Old task stops when new is healthy

---

## 💰 Cost Analysis

### Current Configuration

**Monthly Cost**:
```
Fargate (0.5 vCPU, 1 GB RAM, 24/7):
- 730 hours/month × $0.04048 (vCPU) = $29.55
- 730 hours/month × $0.004445 (memory) = $3.24
Total: ~$33/month (1 task)

With auto-scaling (average 1.5 tasks):
Total: ~$50/month
```

**Compared to EC2**:
- EC2 t3.small: ~$15/month
- But: No auto-scaling, manual management, less resilient
- **Fargate Premium**: $18/month for serverless convenience

---

**Document Version**: 1.0  
**Last Updated**: February 19, 2026  
**Related Docs**:
- `01-overview.md` - Full system architecture
- `03-lambda-resilience.md` - Serverless resilience patterns

