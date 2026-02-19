# ECS Health Check Diagnostic Script

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "ECS Backend Health Check Diagnostic" -ForegroundColor Green
Write-Host "============================================`n" -ForegroundColor Cyan

# Test 1: Check if backend IP is responding at all
Write-Host "[1/5] Testing backend connectivity..." -ForegroundColor Yellow
Write-Host "Target: http://13.222.106.90:8000" -ForegroundColor White

try {
    $response = Test-NetConnection -ComputerName "13.222.106.90" -Port 8000 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($response) {
        Write-Host "✓ Port 8000 is OPEN and accepting connections`n" -ForegroundColor Green
    } else {
        Write-Host "✗ Port 8000 is CLOSED or FILTERED`n" -ForegroundColor Red
        Write-Host "Possible issues:" -ForegroundColor Yellow
        Write-Host "- ECS task not running" -ForegroundColor White
        Write-Host "- Security group blocking port 8000" -ForegroundColor White
        Write-Host "- Task failed health checks and was stopped`n" -ForegroundColor White
    }
} catch {
    Write-Host "✗ Cannot test connection: $($_.Exception.Message)`n" -ForegroundColor Red
}

# Test 2: Try to hit health endpoint
Write-Host "[2/5] Testing /health endpoint..." -ForegroundColor Yellow
try {
    $health = Invoke-WebRequest -Uri "http://13.222.106.90:8000/health" -TimeoutSec 10 -UseBasicParsing
    Write-Host "✓ Health endpoint responding!" -ForegroundColor Green
    Write-Host "Status Code: $($health.StatusCode)" -ForegroundColor Cyan
    Write-Host "Response: $($health.Content)`n" -ForegroundColor White
} catch {
    Write-Host "✗ Health endpoint NOT responding" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)`n" -ForegroundColor Yellow

    if ($_.Exception.Message -like "*timed out*") {
        Write-Host "DIAGNOSIS: Backend is timing out" -ForegroundColor Red
        Write-Host "- Backend might be starting up (wait 2-3 minutes)" -ForegroundColor Yellow
        Write-Host "- Container might be stuck in startup" -ForegroundColor Yellow
        Write-Host "- App might have crashed on startup`n" -ForegroundColor Yellow
    } elseif ($_.Exception.Message -like "*refused*") {
        Write-Host "DIAGNOSIS: Connection refused" -ForegroundColor Red
        Write-Host "- ECS task is not running" -ForegroundColor Yellow
        Write-Host "- Container failed to start" -ForegroundColor Yellow
        Write-Host "- Port 8000 not exposed`n" -ForegroundColor Yellow
    }
}

# Test 3: Try API docs
Write-Host "[3/5] Testing /docs endpoint..." -ForegroundColor Yellow
try {
    $docs = Invoke-WebRequest -Uri "http://13.222.106.90:8000/docs" -TimeoutSec 10 -UseBasicParsing
    Write-Host "✓ API docs accessible (Status: $($docs.StatusCode))`n" -ForegroundColor Green
} catch {
    Write-Host "✗ API docs NOT accessible: $($_.Exception.Message)`n" -ForegroundColor Red
}

# Test 4: IP Address Status
Write-Host "[4/5] IP Address Status..." -ForegroundColor Yellow
Write-Host "Current configured IP: 13.222.106.90" -ForegroundColor White
Write-Host "`nNote: ECS task IPs change when tasks restart!" -ForegroundColor Yellow
Write-Host "You may need to get the new IP from AWS Console.`n" -ForegroundColor Yellow

# Test 5: Recommendations
Write-Host "[5/5] Recommended Actions..." -ForegroundColor Yellow
Write-Host "`n✓ Quick Fixes to Try:" -ForegroundColor Cyan
Write-Host "1. Check AWS ECS Console:" -ForegroundColor White
Write-Host "   - Go to: ECS → Clusters → rag-demo → backend service" -ForegroundColor Gray
Write-Host "   - Check if task is RUNNING" -ForegroundColor Gray
Write-Host "   - Get new Public IP if task restarted`n" -ForegroundColor Gray

Write-Host "2. If task is STOPPED:" -ForegroundColor White
Write-Host "   - Check 'Stopped reason' in task details" -ForegroundColor Gray
Write-Host "   - Look for health check failure messages" -ForegroundColor Gray
Write-Host "   - Check CloudWatch logs: /ecs/rag-demo`n" -ForegroundColor Gray

Write-Host "3. Restart ECS Service:" -ForegroundColor White
Write-Host "   - In AWS Console, click 'Update Service'" -ForegroundColor Gray
Write-Host "   - Check 'Force new deployment'" -ForegroundColor Gray
Write-Host "   - Click 'Update'`n" -ForegroundColor Gray

Write-Host "4. Check Recent Deployment:" -ForegroundColor White
Write-Host "   - Was the backend redeployed recently?" -ForegroundColor Gray
Write-Host "   - Check GitHub Actions for deploy status" -ForegroundColor Gray
Write-Host "   - New deployment may have failed`n" -ForegroundColor Gray

Write-Host "`n✓ CloudWatch Logs Command:" -ForegroundColor Cyan
Write-Host "   aws logs tail /ecs/rag-demo --follow --region us-east-1`n" -ForegroundColor Gray

Write-Host "`n✓ Get New ECS Task IP:" -ForegroundColor Cyan
Write-Host "   Run: .\scripts\get-ecs-endpoint.ps1`n" -ForegroundColor Gray

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Diagnostic Complete" -ForegroundColor Green
Write-Host "============================================`n" -ForegroundColor Cyan

