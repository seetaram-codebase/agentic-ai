# How to Access Your Deployed RAG Application

## 🌐 Accessing the Application

After successful deployment, you have **3 ways** to access your RAG application:

---

## Option 1: Direct ECS Task Access (Development)

### Step 1: Get ECS Task Public IP

```bash
# Method 1: Using AWS CLI
aws ecs list-tasks \
  --cluster rag-demo \
  --service-name backend \
  --region us-east-1

# Copy the task ARN from output, then:
aws ecs describe-tasks \
  --cluster rag-demo \
  --tasks <TASK_ARN> \
  --region us-east-1 \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text

# Get the network interface ID, then get the public IP:
aws ec2 describe-network-interfaces \
  --network-interface-ids <ENI_ID> \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text
```

```bash
# Method 2: Using AWS Console
1. Go to: https://console.aws.amazon.com/ecs
2. Select cluster: rag-demo
3. Click on service: backend
4. Click on Tasks tab
5. Click on the running task
6. Look for "Public IP" in the Network section
```

### Step 2: Access the API

```bash
# Once you have the public IP, access the API:
PUBLIC_IP="<your-public-ip>"

# Health check
curl http://$PUBLIC_IP:8000/health

# API documentation (Swagger UI)
open http://$PUBLIC_IP:8000/docs

# Or in browser:
http://<public-ip>:8000/docs
```

**Example**:
```bash
PUBLIC_IP="54.123.45.67"
curl http://54.123.45.67:8000/health
# Response: {"status":"healthy","timestamp":"...","service":"rag-demo-api"}
```

---

## Option 2: Application Load Balancer (Recommended for Production)

**Note**: Your Terraform configuration doesn't currently include an ALB. You can add one:

### Add Load Balancer to Terraform

Create `infrastructure/terraform/alb.tf`:

```hcl
# Application Load Balancer
resource "aws_lb" "backend" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.app_name}-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "backend" {
  name        = "${var.app_name}-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

# Listener
resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.backend.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-alb-sg"
  }
}

# Output the ALB DNS name
output "alb_dns_name" {
  value       = aws_lb.backend.dns_name
  description = "DNS name of the Application Load Balancer"
}
```

Then update ECS service in `ecs.tf` to use the target group.

### Access via Load Balancer

```bash
# Get ALB DNS name
aws elbv2 describe-load-balancers \
  --names rag-demo-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text

# Access the API
ALB_DNS="rag-demo-alb-123456789.us-east-1.elb.amazonaws.com"
curl http://$ALB_DNS/health

# API docs
open http://$ALB_DNS/docs
```

---

## Option 3: Electron Desktop App (For End Users)

### Build and Run the Electron UI

```bash
cd electron-ui

# Install dependencies
npm install

# Development mode
npm run dev

# Build for production
npm run build
```

### Configure API Endpoint

Update `electron-ui/src/api/client.ts`:

```typescript
// Use your ECS public IP or ALB DNS
const API_BASE_URL = process.env.VITE_API_URL || 'http://54.123.45.67:8000';
```

Or set environment variable:

```bash
# .env file in electron-ui/
VITE_API_URL=http://54.123.45.67:8000
```

---

## 🎯 Quick Start Guide

### 1. **Get Your API Endpoint**

**Via AWS Console** (Easiest):
1. Go to: https://console.aws.amazon.com/ecs
2. Select: `rag-demo` cluster
3. Click: `backend` service
4. Click: Tasks tab
5. Click: The running task
6. Copy: **Public IP** from Network section

**Via AWS CLI**:
```bash
# Run this script to get the public IP
cat > get-api-endpoint.sh << 'EOF'
#!/bin/bash
TASK_ARN=$(aws ecs list-tasks --cluster rag-demo --service-name backend --query 'taskArns[0]' --output text --region us-east-1)
ENI_ID=$(aws ecs describe-tasks --cluster rag-demo --tasks $TASK_ARN --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text --region us-east-1)
PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region us-east-1)
echo "Your API endpoint: http://$PUBLIC_IP:8000"
EOF

chmod +x get-api-endpoint.sh
./get-api-endpoint.sh
```

### 2. **Test the API**

```bash
# Set your endpoint
API_URL="http://YOUR_PUBLIC_IP:8000"

# Health check
curl $API_URL/health

# API documentation (open in browser)
echo "API Docs: $API_URL/docs"
```

### 3. **Use the API**

#### Upload a Document

```bash
# Upload PDF or TXT file
curl -X POST $API_URL/upload \
  -F "file=@sample-docs/product-features.txt"

# Response:
# {
#   "filename": "product-features.txt",
#   "document_id": "abc123xyz",
#   "status": "processing",
#   "message": "Check status at /documents/abc123xyz/status",
#   "s3_key": "uploads/abc123xyz_product-features.txt",
#   "bucket": "rag-demo-documents-971778147952"
# }
```

#### Check Processing Status

```bash
# Poll status (replace with your document_id)
DOC_ID="abc123xyz"

curl $API_URL/documents/$DOC_ID/status

# Response:
# {
#   "document_id": "abc123xyz",
#   "status": "embedding",  # or 'uploaded', 'chunked', 'completed'
#   "chunk_count": 25,
#   "chunks_embedded": 18,
#   "progress": 72
# }
```

#### Query the Document

```bash
# Once status is 'completed', query it
curl -X POST $API_URL/query \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What are the main features?",
    "n_results": 5
  }'

# Response:
# {
#   "response": "The main features include...",
#   "sources": [
#     {
#       "source": "product-features.txt",
#       "page": 0,
#       "chunk_index": 3
#     }
#   ],
#   "provider": "azure-openai-us-east"
# }
```

---

## 🔧 PowerShell Script for Windows

Create `get-ecs-endpoint.ps1`:

```powershell
# Get ECS backend endpoint
$TASK_ARN = aws ecs list-tasks `
    --cluster rag-demo `
    --service-name backend `
    --query 'taskArns[0]' `
    --output text `
    --region us-east-1

$ENI_ID = aws ecs describe-tasks `
    --cluster rag-demo `
    --tasks $TASK_ARN `
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' `
    --output text `
    --region us-east-1

$PUBLIC_IP = aws ec2 describe-network-interfaces `
    --network-interface-ids $ENI_ID `
    --query 'NetworkInterfaces[0].Association.PublicIp' `
    --output text `
    --region us-east-1

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🚀 RAG Demo API Endpoint" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "API Base URL:  " -NoNewline
Write-Host "http://$PUBLIC_IP:8000" -ForegroundColor Yellow
Write-Host "Health Check:  " -NoNewline
Write-Host "http://$PUBLIC_IP:8000/health" -ForegroundColor Yellow
Write-Host "API Docs:      " -NoNewline
Write-Host "http://$PUBLIC_IP:8000/docs" -ForegroundColor Yellow
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Test the endpoint
Write-Host ""
Write-Host "Testing endpoint..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "http://$PUBLIC_IP:8000/health" -Method Get
    Write-Host "✅ API is healthy!" -ForegroundColor Green
    Write-Host "   Service: $($response.service)" -ForegroundColor White
    Write-Host "   Status: $($response.status)" -ForegroundColor White
} catch {
    Write-Host "❌ API not accessible yet. Wait a few minutes for deployment." -ForegroundColor Red
}
```

Run it:
```powershell
./scripts/get-ecs-endpoint.ps1
```

---

## 📱 API Endpoints Summary

Once you have your endpoint (`http://<PUBLIC_IP>:8000`):

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check |
| `/ready` | GET | Readiness check |
| `/upload` | POST | Upload document (PDF/TXT) |
| `/documents` | GET | List all documents |
| `/documents/{id}/status` | GET | Check processing status |
| `/query` | POST | Query documents with RAG |
| `/docs` | GET | Swagger UI (API documentation) |

---

## 🌍 Making it Accessible from Anywhere

### Option 1: Keep Public IP (Development)

The ECS task has a public IP that changes when the task restarts.

**Pros**:
- ✅ Free
- ✅ Simple
- ✅ Good for development

**Cons**:
- ❌ IP changes when task restarts
- ❌ No HTTPS
- ❌ Not production-ready

### Option 2: Add Application Load Balancer (Production)

**Benefits**:
- ✅ Stable DNS name
- ✅ Can add HTTPS (with ACM certificate)
- ✅ Health checks
- ✅ Multiple tasks (auto-scaling)

**Cost**: ~$16/month

### Option 3: Add Custom Domain (Production)

1. Get domain from Route 53
2. Create ACM certificate
3. Add HTTPS listener to ALB
4. Point domain to ALB

**Example**: `https://rag-demo.yourdomain.com`

---

## 🔒 Security Notes

### Current Setup (Development)

- ⚠️ **No authentication** - Anyone with IP can access
- ⚠️ **No HTTPS** - Traffic not encrypted
- ⚠️ **Public IP** - Exposed to internet

### For Production

Add to your infrastructure:

1. **API Gateway** with API keys
2. **Cognito** for user authentication
3. **WAF** for DDoS protection
4. **VPC with private subnets** for ECS
5. **ALB in public subnet** with HTTPS

---

## 📊 Monitoring Access

### CloudWatch Logs

```bash
# View backend logs
aws logs tail /ecs/rag-demo --follow

# Search for access logs
aws logs filter-log-events \
  --log-group-name /ecs/rag-demo \
  --filter-pattern "POST /upload"
```

### ECS Metrics

```bash
# View in console
https://console.aws.amazon.com/ecs/home?region=us-east-1#/clusters/rag-demo/services/backend/metrics
```

---

## 🎯 Complete Example

```bash
# 1. Get endpoint
API_URL=$(./scripts/get-ecs-endpoint.ps1 | grep "API Base URL" | cut -d: -f2- | xargs)

# 2. Upload document
curl -X POST $API_URL/upload \
  -F "file=@sample-docs/architecture-overview.txt" \
  | jq .

# Output:
# {
#   "filename": "architecture-overview.txt",
#   "document_id": "xyz789",
#   "status": "processing",
#   ...
# }

# 3. Wait for processing (30-60 seconds)
sleep 30

# 4. Check status
curl $API_URL/documents/xyz789/status | jq .

# 5. Query when complete
curl -X POST $API_URL/query \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What is the architecture?",
    "n_results": 5
  }' | jq .
```

---

## 🚀 Next Steps

1. ✅ **Get your endpoint** using the scripts above
2. ✅ **Test the API** with health check
3. ✅ **Upload a sample document**
4. ✅ **Query the document**
5. ✅ **Build Electron UI** for end users (optional)
6. ✅ **Add ALB** for production (optional)
7. ✅ **Add custom domain** for production (optional)

---

## 📚 Related Documentation

- **API Usage Guide**: `docs/API-USAGE-GUIDE.md`
- **ECS Deployment**: `docs/ECS-DEPLOYMENT-EXPLAINED.md`
- **Processing Flow**: `docs/DEPLOYMENT-AND-PROCESSING-FLOW.md`
- **Troubleshooting**: `docs/GITHUB-ACTIONS-TROUBLESHOOTING.md`

