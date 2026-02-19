$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "CHUNKER LAMBDA REQUIREMENTS VERIFICATION" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Display requirements file
Write-Host ">>> requirements-minimal.txt CONTENT:" -ForegroundColor Yellow
Write-Host ""
Get-Content "C:\Users\seeta\IdeaProjects\agentic-ai\lambda\chunker\requirements-minimal.txt" | ForEach-Object {
    if ($_ -match "langchain") {
        Write-Host $_ -ForegroundColor Green
    } else {
        Write-Host $_
    }
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check what's installed in package directory
Write-Host ">>> INSTALLED LANGCHAIN PACKAGES:" -ForegroundColor Yellow
Write-Host ""

$packageDir = "C:\Users\seeta\IdeaProjects\agentic-ai\lambda\chunker\package"
if (Test-Path $packageDir) {
    $langchainDirs = Get-ChildItem $packageDir -Directory | Where-Object { $_.Name -like "*langchain*" -and $_.Name -notlike "*.dist-info" }
    if ($langchainDirs) {
        $langchainDirs | ForEach-Object {
            Write-Host "  ✓ $($_.Name)" -ForegroundColor Green
        }
    } else {
        Write-Host "  ✗ No langchain packages found!" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host ">>> ALL INSTALLED PACKAGES (first 50):" -ForegroundColor Yellow
    Write-Host ""
    Get-ChildItem $packageDir -Directory | Where-Object { $_.Name -notlike "*.dist-info" } | Select-Object -First 50 | ForEach-Object {
        Write-Host "  - $($_.Name)"
    }
} else {
    Write-Host "  ✗ Package directory not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan

