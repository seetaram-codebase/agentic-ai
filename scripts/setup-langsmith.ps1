# Setup LangSmith Integration (PowerShell)
# This script configures your LangSmith API key in AWS SSM

param(
    [Parameter(Mandatory=$true)]
    [string]$LangSmithApiKey,

    [Parameter(Mandatory=$false)]
    [string]$AppName = "rag-demo",

    [Parameter(Mandatory=$false)]
    [string]$AwsRegion = "us-east-1"
)

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          LangSmith Integration Setup                           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Validate API key format
if (-not ($LangSmithApiKey -match "^lsv2_")) {
    Write-Host "⚠️  Warning: API key doesn't start with 'lsv2_'" -ForegroundColor Yellow
    Write-Host "   Are you sure this is a LangSmith API key?"
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        exit 1
    }
}

Write-Host "Configuration:"
Write-Host "  App Name: $AppName"
Write-Host "  AWS Region: $AwsRegion"
Write-Host "  API Key: $($LangSmithApiKey.Substring(0, [Math]::Min(15, $LangSmithApiKey.Length)))..."
Write-Host ""

$response = Read-Host "Store LangSmith API key in AWS SSM? (y/N)"
if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Host "Cancelled."
    exit 0
}

Write-Host ""
Write-Host "Step 1: Storing LangSmith API key in SSM..." -ForegroundColor Blue

try {
    # Try to update existing parameter
    aws ssm put-parameter `
        --name "/$AppName/langsmith/api-key" `
        --value $LangSmithApiKey `
        --type "SecureString" `
        --region $AwsRegion `
        --overwrite

    Write-Host "✅ LangSmith API key stored in SSM" -ForegroundColor Green
} catch {
    Write-Host "❌ Error storing parameter: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Verifying parameter..." -ForegroundColor Blue

try {
    $storedValue = aws ssm get-parameter `
        --name "/$AppName/langsmith/api-key" `
        --with-decryption `
        --region $AwsRegion `
        --query 'Parameter.Value' `
        --output text

    if ($storedValue -eq $LangSmithApiKey) {
        Write-Host "✅ Verification successful" -ForegroundColor Green
    } else {
        Write-Host "❌ Verification failed - stored value doesn't match" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Error verifying parameter: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                    Setup Complete! ✅                         " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Deploy infrastructure with Terraform:"
Write-Host "   cd infrastructure\terraform"
Write-Host "   terraform apply"
Write-Host ""
Write-Host "2. Deploy backend (will use LangSmith automatically):"
Write-Host "   # Trigger via GitHub Actions or manually:"
Write-Host "   cd backend"
Write-Host "   docker build -t backend ."
Write-Host "   # ... deploy to ECS"
Write-Host ""
Write-Host "3. Make a test query:"
Write-Host '   Invoke-RestMethod -Uri "http://YOUR_ECS_IP:8000/query" `'
Write-Host '     -Method Post `'
Write-Host '     -ContentType "application/json" `'
Write-Host '     -Body ''{"question": "What is machine learning?"}'''
Write-Host ""
Write-Host "4. View trace in LangSmith:"
Write-Host "   https://smith.langchain.com/"
Write-Host ""
Write-Host "LangSmith is now configured for:" -ForegroundColor Green
Write-Host "  ✓ ECS Backend (FastAPI)"
Write-Host "  ✓ Embedder Lambda"
Write-Host ""
Write-Host "Usage example:" -ForegroundColor Cyan
Write-Host "  .\setup-langsmith.ps1 -LangSmithApiKey 'lsv2_pt_xxxxx'"
Write-Host ""

