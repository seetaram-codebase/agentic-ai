# Get ECS Backend Endpoint
# PowerShell script to retrieve the public IP of your deployed ECS backend

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🔍 Finding RAG Demo API Endpoint..." -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

try {
    # Get running task ARN
    Write-Host "Looking for ECS task..." -ForegroundColor Yellow
    $TASK_ARN = aws ecs list-tasks `
        --cluster rag-demo `
        --service-name backend `
        --query 'taskArns[0]' `
        --output text `
        --region us-east-1 2>&1

    if ($TASK_ARN -eq "None" -or $TASK_ARN -like "*error*") {
        Write-Host "❌ No running tasks found in ECS cluster 'rag-demo'" -ForegroundColor Red
        Write-Host ""
        Write-Host "Make sure you've deployed the backend:" -ForegroundColor Yellow
        Write-Host "  Actions → Deploy to ECS → Run workflow" -ForegroundColor White
        exit 1
    }

    Write-Host "✓ Found task: $TASK_ARN" -ForegroundColor Green

    # Get network interface ID
    Write-Host "Getting network interface..." -ForegroundColor Yellow
    $ENI_ID = aws ecs describe-tasks `
        --cluster rag-demo `
        --tasks $TASK_ARN `
        --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' `
        --output text `
        --region us-east-1 2>&1

    Write-Host "✓ Network interface: $ENI_ID" -ForegroundColor Green

    # Get public IP
    Write-Host "Retrieving public IP..." -ForegroundColor Yellow
    $PUBLIC_IP = aws ec2 describe-network-interfaces `
        --network-interface-ids $ENI_ID `
        --query 'NetworkInterfaces[0].Association.PublicIp' `
        --output text `
        --region us-east-1 2>&1

    if (-not $PUBLIC_IP -or $PUBLIC_IP -eq "None") {
        Write-Host "❌ No public IP assigned to the task" -ForegroundColor Red
        Write-Host ""
        Write-Host "The ECS task might be in a private subnet." -ForegroundColor Yellow
        Write-Host "Check your VPC/subnet configuration in Terraform." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "✓ Public IP: $PUBLIC_IP" -ForegroundColor Green
    Write-Host ""

    # Display results
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
        $response = Invoke-RestMethod -Uri "http://$PUBLIC_IP:8000/health" -Method Get -TimeoutSec 10
        Write-Host "✅ API is healthy!" -ForegroundColor Green
        Write-Host "   Service:   $($response.service)" -ForegroundColor White
        Write-Host "   Status:    $($response.status)" -ForegroundColor White
        Write-Host "   Timestamp: $($response.timestamp)" -ForegroundColor White
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host "✅ Your API is ready to use!" -ForegroundColor Green
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Try it out:" -ForegroundColor Yellow
        Write-Host "  1. Upload a document:" -ForegroundColor White
        Write-Host "     curl -X POST http://$PUBLIC_IP:8000/upload -F `"file=@test.pdf`"" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  2. Open API docs in browser:" -ForegroundColor White
        Write-Host "     http://$PUBLIC_IP:8000/docs" -ForegroundColor Gray
        Write-Host ""

    } catch {
        Write-Host "⚠️  API endpoint found but not responding yet" -ForegroundColor Yellow
        Write-Host "   This is normal if you just deployed." -ForegroundColor White
        Write-Host "   Wait 1-2 minutes for the container to start." -ForegroundColor White
        Write-Host ""
        Write-Host "   Then try: curl http://$PUBLIC_IP:8000/health" -ForegroundColor Gray
    }

} catch {
    Write-Host ""
    Write-Host "❌ Error occurred: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check AWS credentials: aws sts get-caller-identity" -ForegroundColor White
    Write-Host "  2. Verify ECS cluster exists: aws ecs list-clusters" -ForegroundColor White
    Write-Host "  3. Check if backend is deployed: aws ecs describe-services --cluster rag-demo --services backend" -ForegroundColor White
}

