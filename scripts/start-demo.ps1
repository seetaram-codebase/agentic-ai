# Start Backend and Electron UI
# Run from project root

Write-Host "🚀 Starting RAG Demo..." -ForegroundColor Cyan

# Start backend in background
Write-Host "Starting backend API..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd backend; uvicorn app.main:app --reload --port 8000"

# Wait for backend to start
Start-Sleep -Seconds 3

# Start Electron UI
Write-Host "Starting Electron UI..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd electron-ui; npm run dev"

Write-Host "`n✅ Demo started!" -ForegroundColor Green
Write-Host "   Backend: http://localhost:8000" -ForegroundColor White
Write-Host "   API Docs: http://localhost:8000/docs" -ForegroundColor White
Write-Host "   Electron UI will open automatically" -ForegroundColor White
