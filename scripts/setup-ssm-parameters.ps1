#!/usr/bin/env pwsh
# Script to configure AWS SSM Parameter Store with Azure OpenAI credentials
# Run this script to set up secrets for the application

param(
    [Parameter(Mandatory=$false)]
    [string]$AppName = "rag-demo",

    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",

    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

Write-Host "================================" -ForegroundColor Cyan
Write-Host "AWS SSM Parameter Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check AWS CLI
try {
    $accountId = aws sts get-caller-identity --query Account --output text
    Write-Host "✓ AWS Account: $accountId" -ForegroundColor Green
    Write-Host "✓ Region: $Region" -ForegroundColor Green
} catch {
    Write-Host "✗ AWS CLI not configured. Please run: aws configure" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "This script will help you configure Azure OpenAI credentials in AWS SSM Parameter Store." -ForegroundColor Yellow
Write-Host ""

# Function to put parameter
function Set-SSMParameter {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Type = "String",
        [string]$Description
    )

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would create: $Name" -ForegroundColor Cyan
        return
    }

    try {
        aws ssm put-parameter `
            --name $Name `
            --type $Type `
            --value $Value `
            --description $Description `
            --region $Region `
            --overwrite 2>$null

        Write-Host "  ✓ Created: $Name" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to create: $Name" -ForegroundColor Red
    }
}

# Primary Azure OpenAI Configuration (US East)
Write-Host "Primary Azure OpenAI Configuration (US East)" -ForegroundColor Yellow
Write-Host "--------------------------------------------" -ForegroundColor Yellow

$endpoint1 = Read-Host "Enter Azure OpenAI Endpoint (US East)"
if (-not $endpoint1) { $endpoint1 = "https://your-openai-us-east.openai.azure.com/" }

$key1 = Read-Host "Enter Azure OpenAI API Key (US East)" -AsSecureString
$key1Plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($key1))
if (-not $key1Plain) { $key1Plain = "REPLACE_WITH_REAL_KEY" }

$deployment1 = Read-Host "Enter Deployment Name (default: gpt-4o-mini)"
if (-not $deployment1) { $deployment1 = "gpt-4o-mini" }

Set-SSMParameter -Name "/$AppName/azure-openai/us-east/endpoint" `
    -Value $endpoint1 `
    -Type "String" `
    -Description "Azure OpenAI endpoint for US East region"

Set-SSMParameter -Name "/$AppName/azure-openai/us-east/api-key" `
    -Value $key1Plain `
    -Type "SecureString" `
    -Description "Azure OpenAI API key for US East region"

Set-SSMParameter -Name "/$AppName/azure-openai/us-east/deployment" `
    -Value $deployment1 `
    -Type "String" `
    -Description "Azure OpenAI deployment name for chat"

Write-Host ""

# Secondary Azure OpenAI Configuration (EU West - Failover)
Write-Host "Secondary Azure OpenAI Configuration (EU West - Failover)" -ForegroundColor Yellow
Write-Host "---------------------------------------------------------" -ForegroundColor Yellow

$setupFailover = Read-Host "Set up failover configuration? (y/n)"
if ($setupFailover -eq "y") {
    $endpoint2 = Read-Host "Enter Azure OpenAI Endpoint (EU West)"
    if (-not $endpoint2) { $endpoint2 = "https://your-openai-eu-west.openai.azure.com/" }

    $key2 = Read-Host "Enter Azure OpenAI API Key (EU West)" -AsSecureString
    $key2Plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($key2))
    if (-not $key2Plain) { $key2Plain = "REPLACE_WITH_REAL_KEY" }

    $deployment2 = Read-Host "Enter Deployment Name (default: gpt-4o-mini)"
    if (-not $deployment2) { $deployment2 = "gpt-4o-mini" }

    Set-SSMParameter -Name "/$AppName/azure-openai/eu-west/endpoint" `
        -Value $endpoint2 `
        -Type "String" `
        -Description "Azure OpenAI endpoint for EU West region"

    Set-SSMParameter -Name "/$AppName/azure-openai/eu-west/api-key" `
        -Value $key2Plain `
        -Type "SecureString" `
        -Description "Azure OpenAI API key for EU West region"

    Set-SSMParameter -Name "/$AppName/azure-openai/eu-west/deployment" `
        -Value $deployment2 `
        -Type "String" `
        -Description "Azure OpenAI deployment name for chat"
}

Write-Host ""

# Embedding Configuration
Write-Host "Embedding Configuration" -ForegroundColor Yellow
Write-Host "----------------------" -ForegroundColor Yellow

$setupEmbedding = Read-Host "Set up embedding configuration? (y/n)"
if ($setupEmbedding -eq "y") {
    $embEndpoint = Read-Host "Enter Embedding Endpoint (default: same as chat endpoint)"
    if (-not $embEndpoint) { $embEndpoint = $endpoint1 }

    $embKey = Read-Host "Enter Embedding API Key (default: same as chat key)" -AsSecureString
    $embKeyPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($embKey))
    if (-not $embKeyPlain) { $embKeyPlain = $key1Plain }

    $embDeployment = Read-Host "Enter Embedding Deployment (default: text-embedding-ada-002)"
    if (-not $embDeployment) { $embDeployment = "text-embedding-ada-002" }

    Set-SSMParameter -Name "/$AppName/azure-openai/us-east/embedding-endpoint" `
        -Value $embEndpoint `
        -Type "String" `
        -Description "Azure OpenAI endpoint for embeddings"

    Set-SSMParameter -Name "/$AppName/azure-openai/us-east/embedding-key" `
        -Value $embKeyPlain `
        -Type "SecureString" `
        -Description "Azure OpenAI API key for embeddings"

    Set-SSMParameter -Name "/$AppName/azure-openai/us-east/embedding-deployment" `
        -Value $embDeployment `
        -Type "String" `
        -Description "Azure OpenAI embedding model deployment"
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# List all parameters
Write-Host "Verifying parameters..." -ForegroundColor Yellow
try {
    $parameters = aws ssm describe-parameters `
        --region $Region `
        --query "Parameters[?contains(Name, '/$AppName/azure-openai')].Name" `
        --output text

    if ($parameters) {
        Write-Host "✓ Created parameters:" -ForegroundColor Green
        $parameters -split "`t" | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor White
        }
    }
} catch {
    Write-Host "Could not verify parameters" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Update Lambda environment variables to use these parameters" -ForegroundColor White
Write-Host "2. Update ECS task definition to use these parameters" -ForegroundColor White
Write-Host "3. Ensure IAM roles have ssm:GetParameter permissions" -ForegroundColor White
Write-Host ""

