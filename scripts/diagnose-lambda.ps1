# Lambda Diagnostic Script
# Checks which Lambda is failing and why

param(
    [Parameter(Mandatory=$false)]
    [string]$AppName = "rag-demo"
)

Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Lambda Failure Diagnostic Tool            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$chunkerName = "$AppName-chunker"
$embedderName = "$AppName-embedder"

# Check AWS credentials
Write-Host "Checking AWS credentials..." -NoNewline
try {
    $identity = aws sts get-caller-identity | ConvertFrom-Json
    Write-Host " ✓" -ForegroundColor Green
    Write-Host "  Account: $($identity.Account)" -ForegroundColor Gray
    Write-Host "  User: $($identity.Arn)" -ForegroundColor Gray
}
catch {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "`nAWS credentials not configured or expired." -ForegroundColor Yellow
    Write-Host "Run: aws configure" -ForegroundColor Yellow
    Write-Host "Or: aws sso login`n" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# ============================================
# CHECK CHUNKER LAMBDA
# ============================================

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "CHUNKER LAMBDA ($chunkerName)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "`n[1/5] Checking if Lambda exists..." -NoNewline
try {
    $chunkerConfig = aws lambda get-function-configuration --function-name $chunkerName 2>$null | ConvertFrom-Json

    if ($chunkerConfig) {
        Write-Host " ✓" -ForegroundColor Green
        Write-Host "  Runtime: $($chunkerConfig.Runtime)" -ForegroundColor Gray
        Write-Host "  Timeout: $($chunkerConfig.Timeout) seconds" -ForegroundColor Gray
        Write-Host "  Memory: $($chunkerConfig.MemorySize) MB" -ForegroundColor Gray
        Write-Host "  Code Size: $([math]::Round($chunkerConfig.CodeSize / 1024, 2)) KB" -ForegroundColor Gray
        Write-Host "  Last Modified: $($chunkerConfig.LastModified)" -ForegroundColor Gray

        # Check if it's placeholder code (very small size)
        if ($chunkerConfig.CodeSize -lt 5000) {
            Write-Host "  ⚠️  WARNING: Code size is suspiciously small!" -ForegroundColor Yellow
            Write-Host "     This is likely the PLACEHOLDER code!" -ForegroundColor Yellow
            Write-Host "     Real code should be several MB with dependencies." -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "  Lambda function does not exist!" -ForegroundColor Red
    Write-Host "  Deploy with Terraform or GitHub Actions" -ForegroundColor Yellow
    $chunkerExists = $false
}

if ($chunkerConfig) {
    Write-Host "`n[2/5] Checking environment variables..." -NoNewline
    $envVars = $chunkerConfig.Environment.Variables

    $requiredVars = @("DYNAMODB_DOCUMENTS_TABLE", "EMBEDDING_QUEUE_URL", "S3_BUCKET")
    $missingVars = @()

    foreach ($var in $requiredVars) {
        if (-not $envVars.$var) {
            $missingVars += $var
        }
    }

    if ($missingVars.Count -eq 0) {
        Write-Host " ✓" -ForegroundColor Green
        Write-Host "  DYNAMODB_DOCUMENTS_TABLE: $($envVars.DYNAMODB_DOCUMENTS_TABLE)" -ForegroundColor Gray
        Write-Host "  EMBEDDING_QUEUE_URL: $($envVars.EMBEDDING_QUEUE_URL)" -ForegroundColor Gray
        Write-Host "  S3_BUCKET: $($envVars.S3_BUCKET)" -ForegroundColor Gray
    }
    else {
        Write-Host " ✗" -ForegroundColor Red
        Write-Host "  Missing variables: $($missingVars -join ', ')" -ForegroundColor Red
    }

    Write-Host "`n[3/5] Checking SQS trigger..." -NoNewline
    try {
        $chunkerMappings = aws lambda list-event-source-mappings --function-name $chunkerName 2>$null | ConvertFrom-Json

        if ($chunkerMappings.EventSourceMappings.Count -gt 0) {
            $mapping = $chunkerMappings.EventSourceMappings[0]
            Write-Host " ✓" -ForegroundColor Green
            Write-Host "  State: $($mapping.State)" -ForegroundColor $(if ($mapping.State -eq "Enabled") { "Green" } else { "Red" })
            Write-Host "  Batch Size: $($mapping.BatchSize)" -ForegroundColor Gray
            Write-Host "  Queue: $($mapping.EventSourceArn -replace '.*:', '')" -ForegroundColor Gray

            if ($mapping.State -ne "Enabled") {
                Write-Host "  ⚠️  WARNING: Trigger is DISABLED!" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host " ✗" -ForegroundColor Red
            Write-Host "  No SQS trigger configured!" -ForegroundColor Red
        }
    }
    catch {
        Write-Host " ✗" -ForegroundColor Red
    }

    Write-Host "`n[4/5] Checking recent invocations..." -NoNewline
    try {
        $logGroup = "/aws/lambda/$chunkerName"
        $recentLogs = aws logs filter-log-events --log-group-name $logGroup --start-time $([DateTimeOffset]::UtcNow.AddMinutes(-30).ToUnixTimeMilliseconds()) --limit 5 2>$null | ConvertFrom-Json

        if ($recentLogs.events.Count -gt 0) {
            Write-Host " ✓ Found $($recentLogs.events.Count) recent events" -ForegroundColor Green
            Write-Host "`n  Recent log entries:" -ForegroundColor Gray
            foreach ($event in $recentLogs.events | Select-Object -First 3) {
                $timestamp = [DateTimeOffset]::FromUnixTimeMilliseconds($event.timestamp).ToString("HH:mm:ss")
                Write-Host "  [$timestamp] $($event.message.Substring(0, [Math]::Min(80, $event.message.Length)))" -ForegroundColor Gray
            }
        }
        else {
            Write-Host " ⚠️  No recent invocations (last 30 min)" -ForegroundColor Yellow
            Write-Host "  Lambda has not been triggered recently!" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host " ⚠️  Could not read logs" -ForegroundColor Yellow
    }

    Write-Host "`n[5/5] Checking for errors..." -NoNewline
    try {
        $errors = aws logs filter-log-events --log-group-name $logGroup --filter-pattern "ERROR" --start-time $([DateTimeOffset]::UtcNow.AddHours(-1).ToUnixTimeMilliseconds()) 2>$null | ConvertFrom-Json

        if ($errors.events.Count -gt 0) {
            Write-Host " ✗ Found $($errors.events.Count) errors!" -ForegroundColor Red
            Write-Host "`n  Recent errors:" -ForegroundColor Red
            foreach ($error in $errors.events | Select-Object -First 3) {
                Write-Host "  - $($error.message)" -ForegroundColor Red
            }
        }
        else {
            Write-Host " ✓ No errors in last hour" -ForegroundColor Green
        }
    }
    catch {
        Write-Host " ⚠️  Could not check" -ForegroundColor Yellow
    }
}

# ============================================
# CHECK EMBEDDER LAMBDA
# ============================================

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "EMBEDDER LAMBDA ($embedderName)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "`n[1/3] Checking if Lambda exists..." -NoNewline
try {
    $embedderConfig = aws lambda get-function-configuration --function-name $embedderName 2>$null | ConvertFrom-Json

    if ($embedderConfig) {
        Write-Host " ✓" -ForegroundColor Green
        Write-Host "  Runtime: $($embedderConfig.Runtime)" -ForegroundColor Gray
        Write-Host "  Timeout: $($embedderConfig.Timeout) seconds" -ForegroundColor Gray
        Write-Host "  Memory: $($embedderConfig.MemorySize) MB" -ForegroundColor Gray
        Write-Host "  Code Size: $([math]::Round($embedderConfig.CodeSize / 1024, 2)) KB" -ForegroundColor Gray

        if ($embedderConfig.CodeSize -lt 5000) {
            Write-Host "  ⚠️  WARNING: Code size is suspiciously small (placeholder)!" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "  Lambda function does not exist!" -ForegroundColor Red
}

if ($embedderConfig) {
    Write-Host "`n[2/3] Checking SQS trigger..." -NoNewline
    try {
        $embedderMappings = aws lambda list-event-source-mappings --function-name $embedderName 2>$null | ConvertFrom-Json

        if ($embedderMappings.EventSourceMappings.Count -gt 0) {
            $mapping = $embedderMappings.EventSourceMappings[0]
            Write-Host " ✓" -ForegroundColor Green
            Write-Host "  State: $($mapping.State)" -ForegroundColor $(if ($mapping.State -eq "Enabled") { "Green" } else { "Red" })
            Write-Host "  Batch Size: $($mapping.BatchSize)" -ForegroundColor Gray
        }
        else {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
    catch {
        Write-Host " ✗" -ForegroundColor Red
    }

    Write-Host "`n[3/3] Checking recent activity..." -NoNewline
    try {
        $logGroup = "/aws/lambda/$embedderName"
        $recentLogs = aws logs filter-log-events --log-group-name $logGroup --start-time $([DateTimeOffset]::UtcNow.AddMinutes(-30).ToUnixTimeMilliseconds()) --limit 3 2>$null | ConvertFrom-Json

        if ($recentLogs.events.Count -gt 0) {
            Write-Host " ✓ Active (recent invocations)" -ForegroundColor Green
        }
        else {
            Write-Host " ⚠️  No recent activity" -ForegroundColor Yellow
            Write-Host "  (This is expected if chunker isn't working)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host " ⚠️  Could not check" -ForegroundColor Yellow
    }
}

# ============================================
# DIAGNOSIS & RECOMMENDATIONS
# ============================================

Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║   DIAGNOSIS & RECOMMENDATIONS                ║" -ForegroundColor Yellow
Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Yellow

if (-not $chunkerConfig) {
    Write-Host "🔴 CRITICAL: Chunker Lambda does not exist!" -ForegroundColor Red
    Write-Host "`nAction Required:" -ForegroundColor Yellow
    Write-Host "  1. Run Terraform to create Lambda:" -ForegroundColor White
    Write-Host "     cd infrastructure/terraform" -ForegroundColor Gray
    Write-Host "     terraform apply" -ForegroundColor Gray
    Write-Host "  2. Deploy Lambda code via GitHub Actions or manually" -ForegroundColor White
}
elseif ($chunkerConfig.CodeSize -lt 5000) {
    Write-Host "🔴 CRITICAL: Chunker Lambda has PLACEHOLDER code!" -ForegroundColor Red
    Write-Host "`nThe Lambda exists but won't process documents." -ForegroundColor Yellow
    Write-Host "`nAction Required - Deploy Real Code:" -ForegroundColor Yellow
    Write-Host "  Option A - GitHub Actions (Recommended):" -ForegroundColor White
    Write-Host "    1. Commit code to GitHub" -ForegroundColor Gray
    Write-Host "    2. Trigger workflow: .github/workflows/deploy-lambda-chunker.yml" -ForegroundColor Gray
    Write-Host "`n  Option B - Manual Deployment:" -ForegroundColor White
    Write-Host "    cd lambda/chunker" -ForegroundColor Gray
    Write-Host "    pip install -r requirements.txt -t package/" -ForegroundColor Gray
    Write-Host "    Copy-Item handler.py package/" -ForegroundColor Gray
    Write-Host "    Compress-Archive -Path package\* -DestinationPath chunker.zip" -ForegroundColor Gray
    Write-Host "    aws lambda update-function-code --function-name $chunkerName --zip-file fileb://chunker.zip" -ForegroundColor Gray
}
elseif ($chunkerMappings.EventSourceMappings[0].State -ne "Enabled") {
    Write-Host "🟡 WARNING: Chunker Lambda SQS trigger is DISABLED!" -ForegroundColor Yellow
    Write-Host "`nAction Required:" -ForegroundColor Yellow
    Write-Host "  aws lambda update-event-source-mapping --uuid $($chunkerMappings.EventSourceMappings[0].UUID) --enabled" -ForegroundColor Gray
}
elseif ($recentLogs.events.Count -eq 0) {
    Write-Host "🟡 WARNING: Chunker Lambda exists but hasn't been invoked!" -ForegroundColor Yellow
    Write-Host "`nPossible causes:" -ForegroundColor Yellow
    Write-Host "  1. S3 event notifications not configured" -ForegroundColor White
    Write-Host "  2. SQS queue not receiving messages" -ForegroundColor White
    Write-Host "  3. Documents not uploaded to correct prefix (uploads/)" -ForegroundColor White
    Write-Host "`nAction Required:" -ForegroundColor Yellow
    Write-Host "  1. Check S3 bucket notification: aws s3api get-bucket-notification-configuration --bucket $($envVars.S3_BUCKET)" -ForegroundColor Gray
    Write-Host "  2. Upload a test file and monitor logs immediately" -ForegroundColor Gray
}
else {
    Write-Host "✅ Chunker Lambda appears to be configured correctly!" -ForegroundColor Green
    Write-Host "`nIf documents are still stuck, check CloudWatch logs for specific errors:" -ForegroundColor Yellow
    Write-Host "  aws logs tail /aws/lambda/$chunkerName --since 10m --follow" -ForegroundColor Gray
}

Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   End of Diagnostic Report                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

