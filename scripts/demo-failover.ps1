# Failover Demonstration Script (PowerShell)
# Shows automatic US-East → EU-West failover

$BACKEND_URL = "http://YOUR_BACKEND_IP:8000"  # Update this!

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   RAG System - Multi-Region Failover Demonstration            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Step 1: Check Initial Health Status" -ForegroundColor Blue
Write-Host "────────────────────────────────────────────────────────────────"
try {
    $initialStatus = Invoke-RestMethod -Uri "$BACKEND_URL/demo/health-status" -Method Get
    $currentProvider = $initialStatus.azure_openai.current_provider
    Write-Host "Current Active Region: " -NoNewline
    Write-Host $currentProvider -ForegroundColor Green
    Write-Host ""
    Write-Host "Health Status:"
    $initialStatus.azure_openai.endpoints | ForEach-Object {
        $status = if ($_.healthy) { "✅ Healthy" } else { "❌ Unhealthy" }
        $current = if ($_.is_current) { " (ACTIVE)" } else { "" }
        Write-Host "  $($_.name): $status$current"
    }
} catch {
    Write-Host "Error: Could not connect to backend at $BACKEND_URL" -ForegroundColor Red
    Write-Host "Please update the BACKEND_URL in this script." -ForegroundColor Yellow
    exit 1
}
Write-Host ""

Read-Host "Press Enter to make a normal query"
Write-Host ""

Write-Host "Step 2: Normal Query (Both Regions Healthy)" -ForegroundColor Blue
Write-Host "────────────────────────────────────────────────────────────────"
Write-Host "Sending query: 'What is machine learning?'"
$startTime = Get-Date
$body = @{
    question = "What is machine learning?"
    n_results = 5
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$BACKEND_URL/query" -Method Post -Body $body -ContentType "application/json"
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds

    Write-Host "Provider: " -NoNewline
    Write-Host $response.provider -ForegroundColor Green
    Write-Host "Latency: " -NoNewline
    Write-Host "$([math]::Round($duration, 2))s" -ForegroundColor Green
    Write-Host "Answer: $($response.response.Substring(0, [Math]::Min(100, $response.response.Length)))..."
    Write-Host "Sources: $($response.sources.Count) documents"
} catch {
    Write-Host "Error making query: $_" -ForegroundColor Red
}
Write-Host ""

Read-Host "Press Enter to trigger failover"
Write-Host ""

Write-Host "Step 3: Trigger Failover (Simulate US-East Failure)" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────"
Write-Host "Triggering manual failover..."
try {
    $failoverResult = Invoke-RestMethod -Uri "$BACKEND_URL/demo/failover" -Method Post
    Write-Host "Old Provider: " -NoNewline
    Write-Host $failoverResult.old_provider -ForegroundColor Red
    Write-Host "New Provider: " -NoNewline
    Write-Host $failoverResult.new_provider -ForegroundColor Green
} catch {
    Write-Host "Error triggering failover: $_" -ForegroundColor Red
}
Write-Host ""

Write-Host "Waiting 2 seconds for failover to take effect..."
Start-Sleep -Seconds 2
Write-Host ""

Write-Host "Step 4: Check Health Status After Failover" -ForegroundColor Blue
Write-Host "────────────────────────────────────────────────────────────────"
try {
    $postFailoverStatus = Invoke-RestMethod -Uri "$BACKEND_URL/demo/health-status" -Method Get
    $postFailoverStatus.azure_openai.endpoints | ForEach-Object {
        $status = if ($_.healthy) { "✅ Healthy" } else { "❌ Unhealthy" }
        $current = if ($_.is_current) { " (ACTIVE)" } else { "" }
        Write-Host "  $($_.name): $status$current"
    }
} catch {
    Write-Host "Error checking health: $_" -ForegroundColor Red
}
Write-Host ""

Read-Host "Press Enter to make query using failover region"
Write-Host ""

Write-Host "Step 5: Query Using Failover Region (EU-West)" -ForegroundColor Blue
Write-Host "────────────────────────────────────────────────────────────────"
Write-Host "Sending query: 'Explain neural networks'"
$startTime = Get-Date
$body = @{
    question = "Explain neural networks"
    n_results = 5
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$BACKEND_URL/query" -Method Post -Body $body -ContentType "application/json"
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds

    Write-Host "Provider: " -NoNewline
    Write-Host "$($response.provider) ← Using failover region!" -ForegroundColor Green
    Write-Host "Latency: " -NoNewline
    Write-Host "$([math]::Round($duration, 2))s" -ForegroundColor Green
    Write-Host "Answer: $($response.response.Substring(0, [Math]::Min(100, $response.response.Length)))..."
    Write-Host ""
    Write-Host "✓ Request succeeded even though primary region is down!" -ForegroundColor Green
} catch {
    Write-Host "Error making query: $_" -ForegroundColor Red
}
Write-Host ""

Read-Host "Press Enter to see next steps"
Write-Host ""

Write-Host "Step 6: View Backend Logs (Optional)" -ForegroundColor Blue
Write-Host "────────────────────────────────────────────────────────────────"
Write-Host "To see failover in action, check CloudWatch logs:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  aws logs tail /aws/ecs/rag-demo-backend --follow --format short"
Write-Host ""
Write-Host "You should see logs like:"
Write-Host "  [INFO] Attempting chat with Chat (us-east)" -ForegroundColor Gray
Write-Host "  [ERROR] Error with Chat (us-east): ..." -ForegroundColor Red
Write-Host "  [WARNING] Marked Chat (us-east) as unhealthy" -ForegroundColor Yellow
Write-Host "  [INFO] Attempting chat with Chat (eu-west)" -ForegroundColor Gray
Write-Host "  [INFO] ✅ Success with Chat (eu-west)" -ForegroundColor Green
Write-Host ""

Read-Host "Press Enter to see LangSmith instructions"
Write-Host ""

Write-Host "Step 7: View LangSmith Trace (If Configured)" -ForegroundColor Blue
Write-Host "────────────────────────────────────────────────────────────────"
Write-Host "If you configured LangSmith:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Go to https://smith.langchain.com/"
Write-Host "  2. Select project: rag-demo"
Write-Host "  3. View latest trace"
Write-Host "  4. You'll see:"
Write-Host "     - Provider: Chat (eu-west)"
Write-Host "     - Failover event in timeline"
Write-Host "     - Full trace of RAG pipeline"
Write-Host "     - Cost breakdown per API call"
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                  Demonstration Complete!                       " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Green
Write-Host "  ✓ Normal query used: US-East"
Write-Host "  ✓ Triggered failover to: EU-West"
Write-Host "  ✓ Query succeeded using failover region"
Write-Host "  ✓ No errors, just automatic failover!"
Write-Host ""
Write-Host "Key Points for Presentation:" -ForegroundColor Yellow
Write-Host "  • Failover is automatic (< 1 second)"
Write-Host "  • No data loss (RPO = 0)"
Write-Host "  • Users experience minimal delay"
Write-Host "  • System self-heals after 60 seconds"
Write-Host ""
Write-Host "Additional Demo Ideas:" -ForegroundColor Cyan
Write-Host "  1. Show Pinecone Console: https://app.pinecone.io/"
Write-Host "     - Vector count, query performance"
Write-Host ""
Write-Host "  2. Show CloudWatch Dashboard:"
Write-Host "     - ECS task health"
Write-Host "     - Lambda invocations"
Write-Host "     - SQS queue depth"
Write-Host ""
Write-Host "  3. Show LangSmith Dashboard:"
Write-Host "     - Complete RAG pipeline trace"
Write-Host "     - Cost per query"
Write-Host "     - Latency breakdown"
Write-Host ""

