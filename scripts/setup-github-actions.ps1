#!/usr/bin/env pwsh
# Quick Setup Script for GitHub Actions CI/CD
# This script helps configure the necessary components

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",

    [Parameter(Mandatory=$false)]
    [switch]$SkipAWS,

    [Parameter(Mandatory=$false)]
    [switch]$SkipTerraform
)

Write-Host "================================" -ForegroundColor Cyan
Write-Host "GitHub Actions CI/CD Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check AWS CLI
if (-not $SkipAWS) {
    try {
        $awsVersion = aws --version 2>$null
        Write-Host "✓ AWS CLI: $awsVersion" -ForegroundColor Green
    } catch {
        Write-Host "✗ AWS CLI not found. Please install: https://aws.amazon.com/cli/" -ForegroundColor Red
        exit 1
    }
}

# Check Terraform
if (-not $SkipTerraform) {
    try {
        $tfVersion = terraform version
        Write-Host "✓ Terraform: $($tfVersion[0])" -ForegroundColor Green
    } catch {
        Write-Host "✗ Terraform not found. Please install: https://www.terraform.io/downloads" -ForegroundColor Red
        exit 1
    }
}

# Check Python
try {
    $pythonVersion = python --version
    Write-Host "✓ Python: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Python not found. Please install Python 3.11+" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 1: Environment file setup
Write-Host "Step 1: Setting up environment file" -ForegroundColor Yellow
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "✓ Created .env from template" -ForegroundColor Green
    Write-Host "  Please edit .env and fill in your values!" -ForegroundColor Cyan
} else {
    Write-Host "✓ .env already exists" -ForegroundColor Green
}

Write-Host ""

# Step 2: AWS Account Info
if (-not $SkipAWS) {
    Write-Host "Step 2: Getting AWS account information" -ForegroundColor Yellow
    try {
        $accountId = aws sts get-caller-identity --query Account --output text
        $region = aws configure get region
        if (-not $region) { $region = "us-east-1" }

        Write-Host "✓ AWS Account ID: $accountId" -ForegroundColor Green
        Write-Host "✓ AWS Region: $region" -ForegroundColor Green

        # Update tfvars file
        $tfvarsFile = "infrastructure/terraform/environments/$Environment.tfvars"
        if (Test-Path $tfvarsFile) {
            $content = Get-Content $tfvarsFile -Raw
            $content = $content -replace 'aws_account_id\s*=\s*"[^"]*"', "aws_account_id = `"$accountId`""
            $content | Set-Content $tfvarsFile
            Write-Host "✓ Updated $tfvarsFile with account ID" -ForegroundColor Green
        }
    } catch {
        Write-Host "✗ Could not get AWS account info. Please check AWS credentials." -ForegroundColor Red
    }
}

Write-Host ""

# Step 3: GitHub repository check
Write-Host "Step 3: Checking GitHub repository" -ForegroundColor Yellow
try {
    $gitRemote = git remote get-url origin 2>$null
    if ($gitRemote) {
        Write-Host "✓ Git remote: $gitRemote" -ForegroundColor Green
    } else {
        Write-Host "! No git remote configured" -ForegroundColor Yellow
        Write-Host "  Run: git remote add origin <your-repo-url>" -ForegroundColor Cyan
    }
} catch {
    Write-Host "! Not a git repository" -ForegroundColor Yellow
}

Write-Host ""

# Step 4: Install Python dependencies
Write-Host "Step 4: Installing Python dependencies" -ForegroundColor Yellow
try {
    Push-Location backend
    pip install -r requirements.txt --quiet
    Write-Host "✓ Backend dependencies installed" -ForegroundColor Green
    Pop-Location
} catch {
    Write-Host "✗ Failed to install dependencies" -ForegroundColor Red
    Pop-Location
}

Write-Host ""

# Step 5: Terraform init check
if (-not $SkipTerraform) {
    Write-Host "Step 5: Checking Terraform configuration" -ForegroundColor Yellow
    try {
        Push-Location infrastructure/terraform

        # Check if backend is configured
        $providersContent = Get-Content "providers.tf" -Raw
        if ($providersContent -match 'organization\s*=\s*"([^"]+)"') {
            $tfOrg = $matches[1]
            Write-Host "✓ Terraform Cloud org: $tfOrg" -ForegroundColor Green
        }

        if ($providersContent -match 'name\s*=\s*"([^"]+)"') {
            $tfWorkspace = $matches[1]
            Write-Host "✓ Terraform workspace: $tfWorkspace" -ForegroundColor Green
        }

        Pop-Location
    } catch {
        Write-Host "✗ Could not check Terraform config" -ForegroundColor Red
        Pop-Location
    }
}

Write-Host ""

# Summary and next steps
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Configure GitHub Secrets:" -ForegroundColor Cyan
Write-Host "   - Go to: Settings > Secrets and variables > Actions" -ForegroundColor White
Write-Host "   - Add: AWS_ACCESS_KEY_ID" -ForegroundColor White
Write-Host "   - Add: AWS_SECRET_ACCESS_KEY" -ForegroundColor White
Write-Host "   - Add: TF_API_TOKEN" -ForegroundColor White
Write-Host ""
Write-Host "2. Configure Terraform Cloud:" -ForegroundColor Cyan
Write-Host "   - Create organization: agentic-ai-org" -ForegroundColor White
Write-Host "   - Create workspace: agentic-ai-rag-workspace" -ForegroundColor White
Write-Host "   - Add AWS credentials as environment variables" -ForegroundColor White
Write-Host ""
Write-Host "3. Add Azure OpenAI credentials to AWS SSM:" -ForegroundColor Cyan
Write-Host "   - Run: scripts/setup-ssm-parameters.ps1" -ForegroundColor White
Write-Host ""
Write-Host "4. Deploy infrastructure:" -ForegroundColor Cyan
Write-Host "   - Go to GitHub Actions > Deploy Full Stack" -ForegroundColor White
Write-Host "   - Run workflow with environment: $Environment" -ForegroundColor White
Write-Host ""
Write-Host "5. Test locally:" -ForegroundColor Cyan
Write-Host "   - cd backend" -ForegroundColor White
Write-Host "   - uvicorn app.main:app --reload" -ForegroundColor White
Write-Host ""
Write-Host "For detailed instructions, see: docs/GITHUB-ACTIONS-SETUP.md" -ForegroundColor Yellow
Write-Host ""

