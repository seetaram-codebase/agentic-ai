# Test LangSmith Integration
# Run this after Terraform apply to verify everything works

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          LangSmith Integration - Verification Test            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$BACKEND_IP = Read-Host "Enter your ECS backend IP address"

Write-Host "`nStep 1: Testing backend health..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://${BACKEND_IP}:8000/health" -TimeoutSec 10
    Write-Host "✅ Backend is healthy!" -ForegroundColor Green
    Write-Host "   Status: $($health.status)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Backend not responding" -ForegroundColor Red
    Write-Host "   Make sure ECS task is running and IP is correct" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nStep 2: Making a test query..." -ForegroundColor Yellow
$question = "What is machine learning?"
$body = @{
    question = $question
    n_results = 5
} | ConvertTo-Json

try {
    Write-Host "   Sending query: '$question'" -ForegroundColor Gray
    $response = Invoke-RestMethod -Uri "http://${BACKEND_IP}:8000/query" `
        -Method Post `
        -Body $body `
        -ContentType "application/json" `
        -TimeoutSec 30

    Write-Host "✅ Query successful!" -ForegroundColor Green
    Write-Host "`n   Response: $($response.response.Substring(0, [Math]::Min(100, $response.response.Length)))..." -ForegroundColor White
    Write-Host "   Provider: $($response.provider)" -ForegroundColor Gray
    Write-Host "   Sources: $($response.sources.Count) documents" -ForegroundColor Gray
} catch {
    Write-Host "❌ Query failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n   This might be expected if no documents are uploaded yet" -ForegroundColor Yellow
}

Write-Host "`n─────────────────────────────────────────────────────────────────" -ForegroundColor Cyan

Write-Host "`nStep 3: Check LangSmith for traces" -ForegroundColor Yellow
Write-Host "   1. Go to: https://smith.langchain.com/" -ForegroundColor White
Write-Host "   2. Login with your account" -ForegroundColor White
Write-Host "   3. Select project: 'rag-demo'" -ForegroundColor White
Write-Host "   4. Look for traces from the last minute`n" -ForegroundColor White

Write-Host "Expected traces:" -ForegroundColor Cyan
Write-Host "  • azure_openai.generate_embeddings" -ForegroundColor Gray
Write-Host "    - Input: '$question'" -ForegroundColor Gray
Write-Host "    - Model: text-embedding-3-small" -ForegroundColor Gray
Write-Host "    - Provider: Embedding (us-east or eu-west)" -ForegroundColor Gray
Write-Host "`n  • azure_openai.chat_completion" -ForegroundColor Gray
Write-Host "    - Model: gpt-4 or gpt-35-turbo" -ForegroundColor Gray
Write-Host "    - Provider: Chat (us-east or eu-west)" -ForegroundColor Gray
Write-Host "    - Response generated`n" -ForegroundColor Gray

Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Cyan

Write-Host "`nTroubleshooting if no traces appear:" -ForegroundColor Yellow
Write-Host "  1. Verify LangSmith API key in SSM:" -ForegroundColor White
Write-Host "     aws ssm get-parameter --name '/rag-demo/langsmith/api-key' --with-decryption --region us-east-1`n" -ForegroundColor Gray

Write-Host "  2. Check ECS environment variables:" -ForegroundColor White
Write-Host "     aws ecs describe-task-definition --task-definition rag-demo-backend --region us-east-1 --query 'taskDefinition.containerDefinitions[0].environment'`n" -ForegroundColor Gray

Write-Host "  3. Check ECS logs for errors:" -ForegroundColor White
Write-Host "     aws logs tail /aws/ecs/rag-demo-backend --follow --region us-east-1`n" -ForegroundColor Gray

Write-Host "  4. Verify langsmith package is installed:" -ForegroundColor White
Write-Host "     Should be in backend/requirements.txt`n" -ForegroundColor Gray

Write-Host "═════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    Test Complete!                                " -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "If traces appear in LangSmith, integration is successful! 🎉`n" -ForegroundColor Green

