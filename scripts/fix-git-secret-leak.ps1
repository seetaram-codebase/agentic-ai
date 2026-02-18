#!/usr/bin/env pwsh
# Fix Git Secret Leak - Remove notes.txt from history

Write-Host "================================" -ForegroundColor Red
Write-Host "⚠️  SECRET DETECTED IN GIT HISTORY" -ForegroundColor Red
Write-Host "================================" -ForegroundColor Red
Write-Host ""
Write-Host "GitHub detected a Terraform Cloud API token in 'notes.txt'" -ForegroundColor Yellow
Write-Host "We need to remove this file from your git history." -ForegroundColor Yellow
Write-Host ""

# Check current status
Write-Host "Current situation:" -ForegroundColor Cyan
Write-Host "- Commits not yet pushed: 2 (cf8adac, 64d249d)" -ForegroundColor White
Write-Host "- Problem: notes.txt contains a secret token" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Do you want to fix this now? (y/n)"
if ($choice -ne "y") {
    Write-Host "Cancelled. You'll need to fix this before pushing." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Step 1: Adding notes.txt to .gitignore..." -ForegroundColor Yellow

# Add notes.txt to .gitignore if not already there
$gitignorePath = ".gitignore"
$notesPattern = "notes.txt"

if (Test-Path $gitignorePath) {
    $content = Get-Content $gitignorePath -Raw
    if ($content -notmatch "notes\.txt") {
        Add-Content $gitignorePath "`n# Local notes (may contain secrets)`nnotes.txt"
        Write-Host "✓ Added notes.txt to .gitignore" -ForegroundColor Green
    } else {
        Write-Host "✓ notes.txt already in .gitignore" -ForegroundColor Green
    }
} else {
    "notes.txt" | Out-File $gitignorePath
    Write-Host "✓ Created .gitignore with notes.txt" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 2: Resetting to the last good commit..." -ForegroundColor Yellow

# Reset to the commit before the problematic ones
try {
    git reset --soft origin/feature/agentic-ai-rag
    Write-Host "✓ Reset to origin/feature/agentic-ai-rag" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to reset" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Checking for notes.txt..." -ForegroundColor Yellow

# Remove notes.txt if it exists
if (Test-Path "notes.txt") {
    Write-Host "! notes.txt found in working directory" -ForegroundColor Yellow
    $delete = Read-Host "Delete notes.txt? (y/n)"
    if ($delete -eq "y") {
        Remove-Item "notes.txt" -Force
        Write-Host "✓ Deleted notes.txt" -ForegroundColor Green
    } else {
        Write-Host "! Keeping notes.txt (make sure it's in .gitignore)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Step 4: Re-staging your changes..." -ForegroundColor Yellow

# Stage all changes except notes.txt
try {
    git add -A
    git reset -- notes.txt 2>$null  # Unstage notes.txt if accidentally staged
    Write-Host "✓ Staged changes (excluding notes.txt)" -ForegroundColor Green
} catch {
    Write-Host "! Warning during staging: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 5: Creating new commit..." -ForegroundColor Yellow

# Create new commit
try {
    git commit -m "Add GitHub Actions CI/CD configuration and documentation

- Added deploy-full-stack.yml master workflow
- Added e2e-tests.yml for comprehensive testing
- Updated infrastructure.yml to be reusable
- Added E2E test suite
- Added health/ready endpoints to backend
- Created setup scripts and documentation
- Fixed Terraform Cloud organization name
- Added .env.example template"

    Write-Host "✓ Created new commit" -ForegroundColor Green
} catch {
    Write-Host "! No changes to commit or commit failed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================" -ForegroundColor Green
Write-Host "✅ FIXED!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""
Write-Host "What happened:" -ForegroundColor Cyan
Write-Host "1. Reset to last good commit (removed problematic commits)" -ForegroundColor White
Write-Host "2. Added notes.txt to .gitignore" -ForegroundColor White
Write-Host "3. Re-created commit without notes.txt" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Verify your changes: git status" -ForegroundColor White
Write-Host "2. Push to GitHub: git push origin feature/agentic-ai-rag" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  IMPORTANT: Store your Terraform token securely!" -ForegroundColor Red
Write-Host "   - Add it to GitHub Secrets (not in any file)" -ForegroundColor White
Write-Host "   - See: docs/TERRAFORM-TOKEN-GUIDE.md" -ForegroundColor White
Write-Host ""

