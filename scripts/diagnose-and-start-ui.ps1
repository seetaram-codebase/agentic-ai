# Complete UI Diagnostic and Fix Script
# PowerShell version

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "RAG Demo - Complete Diagnostic and Startup" -ForegroundColor Green
Write-Host "============================================`n" -ForegroundColor Cyan

# 1. Kill stale processes
Write-Host "[1/8] Cleaning up stale processes..." -ForegroundColor Yellow
Get-Process -Name node,electron -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "Done.`n" -ForegroundColor Green

# 2. Setup environment
Write-Host "[2/8] Setting up environment..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
if (-not ($env:Path -like "*nodejs*")) {
    $env:Path += ";C:\Program Files\nodejs"
}
Write-Host "PATH configured.`n" -ForegroundColor Green

# 3. Check npm
Write-Host "[3/8] Checking npm..." -ForegroundColor Yellow
try {
    $npmVersion = npm --version
    Write-Host "npm version: $npmVersion`n" -ForegroundColor Green
} catch {
    Write-Host "ERROR: npm not found!" -ForegroundColor Red
    Write-Host "Please install Node.js from https://nodejs.org/`n" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# 4. Navigate to electron-ui
Write-Host "[4/8] Navigating to electron-ui directory..." -ForegroundColor Yellow
$projectRoot = "C:\Users\seeta\IdeaProjects\agentic-ai"
Set-Location "$projectRoot\electron-ui"
Write-Host "Current directory: $(Get-Location)`n" -ForegroundColor Green

# 5. Check dependencies
Write-Host "[5/8] Checking dependencies..." -ForegroundColor Yellow
if (-not (Test-Path "node_modules")) {
    Write-Host "Dependencies not found. Installing..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to install dependencies`n" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
} else {
    Write-Host "Dependencies already installed.`n" -ForegroundColor Green
}

# 6. Test backend
Write-Host "[6/8] Testing backend connection..." -ForegroundColor Yellow
Write-Host "Testing: http://54.91.39.84:8000/health" -ForegroundColor White
try {
    $response = Invoke-WebRequest -Uri "http://54.91.39.84:8000/health" -TimeoutSec 5 -UseBasicParsing
    Write-Host "Backend is responding! ✓`n" -ForegroundColor Green
    Write-Host "Backend response:" -ForegroundColor Cyan
    Write-Host $response.Content -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host "WARNING: Backend not responding!`n" -ForegroundColor Red
    Write-Host "The UI will still start, but may not function properly.`n" -ForegroundColor Yellow
    Write-Host "Please check:" -ForegroundColor White
    Write-Host "- Is the backend running in AWS ECS?" -ForegroundColor White
    Write-Host "- Is the security group allowing port 8000?" -ForegroundColor White
    Write-Host "- Check: http://54.91.39.84:8000/docs`n" -ForegroundColor White
}

# 7. Check critical files
Write-Host "[7/8] Checking critical files..." -ForegroundColor Yellow
$criticalFiles = @("package.json", "main.js", "src\App.tsx", "index.html", "src\main.tsx")
$allPresent = $true
foreach ($file in $criticalFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file MISSING!" -ForegroundColor Red
        $allPresent = $false
    }
}

if (-not $allPresent) {
    Write-Host "`nERROR: Some critical files are missing!`n" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "All critical files present ✓`n" -ForegroundColor Green

# 8. Start the UI
Write-Host "[8/8] Starting Electron UI..." -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Backend URL: http://54.91.39.84:8000" -ForegroundColor White
Write-Host ""
Write-Host "The Electron window should open in 15-20 seconds." -ForegroundColor Yellow
Write-Host ""
Write-Host "If you see a blank screen:" -ForegroundColor White
Write-Host "  1. Wait 10 more seconds (Vite is compiling)" -ForegroundColor White
Write-Host "  2. Press Ctrl+R to refresh" -ForegroundColor White
Write-Host "  3. Press F12 to check console for errors" -ForegroundColor White
Write-Host ""
Write-Host "To stop: Press Ctrl+C or close the Electron window" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Cyan

# Start npm dev
npm run dev

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nERROR: Failed to start UI`n" -ForegroundColor Red
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Check if port 5173 is already in use: netstat -ano | findstr :5173" -ForegroundColor White
    Write-Host "2. Try: npm cache clean --force" -ForegroundColor White
    Write-Host "3. Try: rm -r node_modules; npm install" -ForegroundColor White
    Write-Host "4. Check docs\UI-TROUBLESHOOTING.md`n" -ForegroundColor White
    Read-Host "Press Enter to exit"
    exit 1
}

