# Test Document Upload with Sync Mode
# This bypasses Lambda/SQS and processes immediately

param(
    [Parameter(Mandatory=$false)]
    [string]$FilePath = "C:\Users\seeta\IdeaProjects\agentic-ai\sample-docs\latest_news_file.txt",

    [Parameter(Mandatory=$false)]
    [string]$ApiUrl = "http://54.89.155.20:8000"
)

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "  Document Upload Test - SYNC MODE" -ForegroundColor Cyan
Write-Host "================================================`n" -ForegroundColor Cyan

Write-Host "This will upload and process the document IMMEDIATELY" -ForegroundColor Yellow
Write-Host "bypassing Lambda/SQS queues.`n" -ForegroundColor Yellow

Write-Host "File: " -NoNewline
Write-Host $FilePath -ForegroundColor White
Write-Host "API: " -NoNewline
Write-Host $ApiUrl -ForegroundColor White
Write-Host ""

# Check if file exists
if (-not (Test-Path $FilePath)) {
    Write-Host "[ERROR] File not found: $FilePath" -ForegroundColor Red
    Write-Host "`nPlease provide a valid file path.`n" -ForegroundColor Yellow
    exit 1
}

# Get file info
$fileInfo = Get-Item $FilePath
Write-Host "File size: " -NoNewline
Write-Host "$([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Cyan
Write-Host ""

# Check backend health
Write-Host "Checking backend health..." -NoNewline
try {
    $health = Invoke-RestMethod -Uri "$ApiUrl/health" -TimeoutSec 5
    Write-Host " ✅ Backend is running" -ForegroundColor Green
}
catch {
    Write-Host " ❌ Backend is not responding" -ForegroundColor Red
    Write-Host "`nError: $_`n" -ForegroundColor Yellow
    exit 1
}

# Upload in SYNC mode
Write-Host "`nUploading in SYNC mode (immediate processing)..." -ForegroundColor Cyan
Write-Host "This may take 10-30 seconds depending on document size...`n" -ForegroundColor Yellow

try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Create multipart form data
    $boundary = [System.Guid]::NewGuid().ToString()
    $fileContent = [System.IO.File]::ReadAllBytes($FilePath)
    $fileName = $fileInfo.Name

    # Build form data
    $bodyLines = @(
        "--$boundary",
        "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
        "Content-Type: text/plain",
        "",
        [System.Text.Encoding]::UTF8.GetString($fileContent),
        "--$boundary--"
    )

    $body = $bodyLines -join "`r`n"

    # Upload with sync mode
    $response = Invoke-RestMethod -Uri "$ApiUrl/upload?mode=sync" `
        -Method POST `
        -ContentType "multipart/form-data; boundary=$boundary" `
        -Body $body `
        -TimeoutSec 120

    $stopwatch.Stop()

    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║   ✅ UPLOAD SUCCESSFUL! ✅            ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Green

    Write-Host "Upload Response:" -ForegroundColor Cyan
    Write-Host "  • Filename: " -NoNewline; Write-Host $response.filename -ForegroundColor White
    Write-Host "  • Document ID: " -NoNewline; Write-Host $response.document_id -ForegroundColor Yellow
    Write-Host "  • Status: " -NoNewline; Write-Host $response.status -ForegroundColor Green
    Write-Host "  • Processing Mode: " -NoNewline; Write-Host $response.processing_mode -ForegroundColor Cyan
    Write-Host "  • Chunks Created: " -NoNewline; Write-Host $response.chunks_created -ForegroundColor White
    Write-Host "  • Provider: " -NoNewline; Write-Host $response.provider -ForegroundColor White
    Write-Host "  • Processing Time: " -NoNewline; Write-Host "$([math]::Round($stopwatch.Elapsed.TotalSeconds, 2)) seconds" -ForegroundColor Magenta
    Write-Host ""

    if ($response.status -eq "success") {
        Write-Host "✅ Document is now indexed and ready for queries!`n" -ForegroundColor Green

        Write-Host "Try querying it:" -ForegroundColor Cyan
        Write-Host '  $question = "What is this document about?"' -ForegroundColor Gray
        Write-Host '  Invoke-RestMethod -Uri "' -NoNewline -ForegroundColor Gray
        Write-Host "$ApiUrl/query" -NoNewline -ForegroundColor Yellow
        Write-Host '" -Method POST -Body (ConvertTo-Json @{question=$question; n_results=5}) -ContentType "application/json"' -ForegroundColor Gray
        Write-Host ""
    }
}
catch {
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║   ❌ UPLOAD FAILED! ❌                ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Red

    Write-Host "Error Details:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""

    if ($_.Exception.Response) {
        Write-Host "Response Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
        Write-Host ""
    }

    Write-Host "Troubleshooting:" -ForegroundColor Cyan
    Write-Host "  1. Verify backend is running: Invoke-WebRequest $ApiUrl/health" -ForegroundColor White
    Write-Host "  2. Check file path is correct" -ForegroundColor White
    Write-Host "  3. Ensure file is .txt or .pdf format" -ForegroundColor White
    Write-Host "  4. Check backend logs for errors`n" -ForegroundColor White

    exit 1
}

Write-Host "================================================`n" -ForegroundColor Cyan

