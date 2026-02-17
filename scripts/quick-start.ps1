# Quick Start Script for RAG Demo
# Run this in PowerShell from the project root

Write-Host "🚀 RAG Demo - Quick Start" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# Check if .env exists
if (-not (Test-Path "backend\.env")) {
    Write-Host "⚠️  Creating .env file from template..." -ForegroundColor Yellow
    Copy-Item "backend\.env.example" "backend\.env"
    Write-Host "📝 Please edit backend\.env with your Azure OpenAI credentials" -ForegroundColor Yellow
    Write-Host "   Then run this script again." -ForegroundColor Yellow
    exit
}

# Step 1: Install Python dependencies
Write-Host "`n📦 Installing Python dependencies..." -ForegroundColor Green
Set-Location backend
pip install -r requirements.txt
Set-Location ..

# Step 2: Install Node dependencies
Write-Host "`n📦 Installing Electron dependencies..." -ForegroundColor Green
Set-Location electron-ui
npm install
Set-Location ..

Write-Host "`n✅ Installation complete!" -ForegroundColor Green
Write-Host "`n📋 To start the demo:" -ForegroundColor Cyan
Write-Host "   Terminal 1: cd backend; uvicorn app.main:app --reload --port 8000" -ForegroundColor White
Write-Host "   Terminal 2: cd electron-ui; npm run dev" -ForegroundColor White
Write-Host "`n🌐 Or use the FastAPI docs at: http://localhost:8000/docs" -ForegroundColor Cyan
