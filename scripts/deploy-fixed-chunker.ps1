# Deploy Fixed Chunker Lambda
# This fixes the DynamoDB update issue where Lambda was creating new records instead of updating existing ones

param(
    [Parameter(Mandatory=$false)]
    [string]$FunctionName = "rag-demo-chunker",

    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Deploy Fixed Chunker Lambda                ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "This will fix the DynamoDB update issue where:" -ForegroundColor Yellow
Write-Host "  ❌ Lambda was generating NEW document IDs" -ForegroundColor Red
Write-Host "  ❌ Creating NEW DynamoDB records" -ForegroundColor Red
Write-Host "  ❌ Backend's DynamoDB record never updated" -ForegroundColor Red
Write-Host ""
Write-Host "After fix:" -ForegroundColor Yellow
Write-Host "  ✅ Lambda extracts document ID from S3 key" -ForegroundColor Green
Write-Host "  ✅ Updates EXISTING DynamoDB record" -ForegroundColor Green
Write-Host "  ✅ Status tracking works correctly`n" -ForegroundColor Green

# Check if in correct directory
if (-not (Test-Path "lambda/chunker/handler.py")) {
    Write-Host "❌ Error: Must run from project root directory" -ForegroundColor Red
    Write-Host "   Current directory: $(Get-Location)" -ForegroundColor Yellow
    Write-Host "   Expected: C:\Users\seeta\IdeaProjects\agentic-ai`n" -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/6] Checking AWS credentials..." -NoNewline
try {
    $identity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
    if ($identity) {
        Write-Host " ✓" -ForegroundColor Green
        Write-Host "      Account: $($identity.Account)" -ForegroundColor Gray
    } else {
        throw "No credentials"
    }
}
catch {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "`n❌ AWS credentials not configured or expired" -ForegroundColor Red
    Write-Host "   Run: aws configure" -ForegroundColor Yellow
    Write-Host "   Or: aws sso login`n" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n[2/6] Creating deployment package..." -NoNewline
try {
    # Create package directory
    $packageDir = "lambda/chunker/package"
    if (Test-Path $packageDir) {
        Remove-Item -Recurse -Force $packageDir
    }
    New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

    # Install dependencies
    pip install -q -r lambda/chunker/requirements.txt -t $packageDir 2>&1 | Out-Null

    # Copy handler
    Copy-Item lambda/chunker/handler.py $packageDir/

    Write-Host " ✓" -ForegroundColor Green
    Write-Host "      Package size: $([math]::Round((Get-ChildItem $packageDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 2)) MB" -ForegroundColor Gray
}
catch {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "`n❌ Error creating package: $_`n" -ForegroundColor Red
    exit 1
}

Write-Host "`n[3/6] Creating deployment ZIP..." -NoNewline
try {
    $zipPath = "lambda/chunker/chunker-fixed.zip"
    if (Test-Path $zipPath) {
        Remove-Item -Force $zipPath
    }

    Compress-Archive -Path "$packageDir/*" -DestinationPath $zipPath -Force

    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    Write-Host " ✓" -ForegroundColor Green
    Write-Host "      ZIP size: $zipSize MB" -ForegroundColor Gray
}
catch {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "`n❌ Error creating ZIP: $_`n" -ForegroundColor Red
    exit 1
}

Write-Host "`n[4/6] Checking if Lambda exists..." -NoNewline
try {
    $lambdaConfig = aws lambda get-function-configuration --function-name $FunctionName --region $Region 2>$null | ConvertFrom-Json

    if ($lambdaConfig) {
        Write-Host " ✓" -ForegroundColor Green
        Write-Host "      Current code size: $([math]::Round($lambdaConfig.CodeSize / 1024, 2)) KB" -ForegroundColor Gray
    } else {
        throw "Lambda not found"
    }
}
catch {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "`n❌ Lambda function '$FunctionName' not found in region $Region" -ForegroundColor Red
    Write-Host "   Create it with Terraform first`n" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n[5/6] Uploading new code to Lambda..." -NoNewline
try {
    $updateResult = aws lambda update-function-code `
        --function-name $FunctionName `
        --zip-file "fileb://$zipPath" `
        --region $Region `
        2>&1 | ConvertFrom-Json

    Write-Host " ✓" -ForegroundColor Green
    Write-Host "      Updated code size: $([math]::Round($updateResult.CodeSize / 1024, 2)) KB" -ForegroundColor Gray
    Write-Host "      SHA256: $($updateResult.CodeSha256.Substring(0, 16))..." -ForegroundColor Gray
}
catch {
    Write-Host " ✗" -ForegroundColor Red
    Write-Host "`n❌ Error uploading code: $_`n" -ForegroundColor Red
    exit 1
}

Write-Host "`n[6/6] Waiting for Lambda to be ready..." -NoNewline
try {
    aws lambda wait function-updated --function-name $FunctionName --region $Region
    Write-Host " ✓" -ForegroundColor Green
}
catch {
    Write-Host " ⚠️  Timeout (Lambda may still be updating)" -ForegroundColor Yellow
}

Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✅ DEPLOYMENT SUCCESSFUL! ✅                  ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "What was fixed:" -ForegroundColor Cyan
Write-Host "  1. Document ID extraction from S3 key (no longer generates new ID)" -ForegroundColor White
Write-Host "  2. DynamoDB UPDATE instead of PUT (updates existing record)" -ForegroundColor White
Write-Host "  3. Status tracking now works correctly`n" -ForegroundColor White

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Upload a new test document" -ForegroundColor White
Write-Host "  2. Monitor CloudWatch logs:" -ForegroundColor White
Write-Host "     aws logs tail /aws/lambda/$FunctionName --since 1m --follow --region $Region" -ForegroundColor Gray
Write-Host "  3. Check DynamoDB for updated status" -ForegroundColor White
Write-Host "  4. Verify UI shows correct progress`n" -ForegroundColor White

Write-Host "Clean up:" -ForegroundColor Yellow
Write-Host "  Package directory: lambda/chunker/package (can delete)" -ForegroundColor Gray
Write-Host "  ZIP file: lambda/chunker/chunker-fixed.zip (can delete)`n" -ForegroundColor Gray

# Cleanup
Write-Host "Do you want to clean up build artifacts? [Y/N]: " -NoNewline -ForegroundColor Yellow
$cleanup = Read-Host

if ($cleanup -eq 'Y' -or $cleanup -eq 'y') {
    Write-Host "`nCleaning up..." -NoNewline
    Remove-Item -Recurse -Force $packageDir -ErrorAction SilentlyContinue
    Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
    Write-Host " ✓" -ForegroundColor Green
}

Write-Host "`n✨ Done!`n" -ForegroundColor Cyan

