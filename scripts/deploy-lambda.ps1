# PowerShell Lambda Deployment Script
# Usage: .\deploy-lambda.ps1 -Function chunker|embedder|both

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("chunker", "embedder", "both")]
    [string]$Function = "both",

    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"

function Deploy-ChunkerLambda {
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "Deploying Chunker Lambda" -ForegroundColor Green
    Write-Host "================================================`n" -ForegroundColor Cyan

    Set-Location lambda\chunker

    # Clean up
    if (Test-Path package) { Remove-Item -Recurse -Force package }
    if (Test-Path chunker-deployment.zip) { Remove-Item -Force chunker-deployment.zip }
    New-Item -ItemType Directory -Path package | Out-Null

    # Install dependencies
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt -t package\ --quiet

    # Copy handler
    Copy-Item handler.py package\

    # Create zip
    Write-Host "Creating deployment package..." -ForegroundColor Yellow
    Compress-Archive -Path package\* -DestinationPath chunker-deployment.zip -Force

    # Deploy
    Write-Host "Deploying to AWS Lambda..." -ForegroundColor Yellow
    aws lambda update-function-code `
        --function-name rag-demo-chunker `
        --zip-file fileb://chunker-deployment.zip `
        --region $Region

    Write-Host "Waiting for update to complete..." -ForegroundColor Yellow
    aws lambda wait function-updated `
        --function-name rag-demo-chunker `
        --region $Region

    Write-Host "✅ Chunker Lambda deployed successfully!`n" -ForegroundColor Green

    Set-Location ..\..
}

function Deploy-EmbedderLambda {
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "Deploying Embedder Lambda" -ForegroundColor Green
    Write-Host "================================================`n" -ForegroundColor Cyan

    Set-Location lambda\embedder

    # Clean up
    if (Test-Path package) { Remove-Item -Recurse -Force package }
    if (Test-Path embedder-deployment.zip) { Remove-Item -Force embedder-deployment.zip }
    New-Item -ItemType Directory -Path package | Out-Null

    # Install dependencies
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt -t package\ --quiet

    # Copy handler
    Copy-Item handler.py package\

    # Create zip
    Write-Host "Creating deployment package..." -ForegroundColor Yellow
    Compress-Archive -Path package\* -DestinationPath embedder-deployment.zip -Force

    # Deploy
    Write-Host "Deploying to AWS Lambda..." -ForegroundColor Yellow
    aws lambda update-function-code `
        --function-name rag-demo-embedder `
        --zip-file fileb://embedder-deployment.zip `
        --region $Region

    Write-Host "Waiting for update to complete..." -ForegroundColor Yellow
    aws lambda wait function-updated `
        --function-name rag-demo-embedder `
        --region $Region

    Write-Host "✅ Embedder Lambda deployed successfully!`n" -ForegroundColor Green

    Set-Location ..\..
}

# Main execution
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "RAG Demo - Lambda Deployment Script" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Function: $Function" -ForegroundColor White
Write-Host "Region: $Region`n" -ForegroundColor White

switch ($Function) {
    "chunker" {
        Deploy-ChunkerLambda
    }
    "embedder" {
        Deploy-EmbedderLambda
    }
    "both" {
        Deploy-ChunkerLambda
        Deploy-EmbedderLambda
    }
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "✅ Deployment Complete!" -ForegroundColor Green
Write-Host "================================================`n" -ForegroundColor Cyan

Write-Host "Test the deployment:" -ForegroundColor Yellow
Write-Host "  aws logs tail /aws/lambda/rag-demo-chunker --follow" -ForegroundColor Gray
Write-Host "  aws logs tail /aws/lambda/rag-demo-embedder --follow`n" -ForegroundColor Gray

