# Document Status Checker
# Usage: .\check-document-status.ps1 -DocumentId "b26fc7a6-d57f-46"

param(
    [Parameter(Mandatory=$false)]
    [string]$DocumentId = "b26fc7a6-d57f-46",

    [Parameter(Mandatory=$false)]
    [string]$ApiUrl = "http://localhost:8000"
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Document Processing Status Checker" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Document ID: " -NoNewline
Write-Host $DocumentId -ForegroundColor Yellow
Write-Host "API URL: " -NoNewline
Write-Host $ApiUrl -ForegroundColor Yellow
Write-Host "`nPress Ctrl+C to stop monitoring`n" -ForegroundColor Gray

$iteration = 0

while ($true) {
    $iteration++

    try {
        # Check if backend is running
        try {
            $null = Invoke-RestMethod -Uri "$ApiUrl/health" -TimeoutSec 2
        }
        catch {
            Write-Host "[ERROR] Backend is not running at $ApiUrl" -ForegroundColor Red
            Write-Host "        Start the backend with: cd backend; uvicorn app.main:app --reload`n" -ForegroundColor Yellow
            Start-Sleep -Seconds 5
            continue
        }

        # Get document status
        $response = Invoke-RestMethod -Uri "$ApiUrl/documents/$DocumentId/status" -ErrorAction Stop

        $timestamp = Get-Date -Format "HH:mm:ss"

        # Color-code based on status
        $statusColor = switch ($response.status) {
            "completed" { "Green" }
            "embedding" { "Yellow" }
            "chunked" { "Cyan" }
            "uploaded" { "Blue" }
            "error" { "Red" }
            default { "White" }
        }

        # Progress bar
        $barLength = 40
        $filledLength = [int](($response.progress / 100) * $barLength)
        $emptyLength = $barLength - $filledLength
        $progressBar = "█" * $filledLength + "░" * $emptyLength

        # Display status
        Write-Host "[$timestamp] " -NoNewline
        Write-Host "Status: " -NoNewline
        Write-Host $response.status.PadRight(10) -ForegroundColor $statusColor -NoNewline
        Write-Host " | " -NoNewline

        # Progress indicator
        if ($response.progress -eq 100) {
            Write-Host "[$progressBar] " -ForegroundColor Green -NoNewline
        }
        elseif ($response.progress -gt 0) {
            Write-Host "[$progressBar] " -ForegroundColor Yellow -NoNewline
        }
        else {
            Write-Host "[$progressBar] " -ForegroundColor Gray -NoNewline
        }

        Write-Host "$($response.progress)% " -NoNewline
        Write-Host "| Chunks: $($response.chunks_embedded)/$($response.chunk_count)"

        # Show helpful hints
        if ($iteration -eq 1 -or $iteration % 10 -eq 0) {
            Write-Host ""
            if ($response.progress -eq 0 -and $response.status -eq "uploaded") {
                Write-Host "  ℹ️  Document uploaded to S3, waiting for chunking..." -ForegroundColor Cyan
            }
            elseif ($response.progress -eq 0 -and $response.status -eq "chunked") {
                Write-Host "  ℹ️  Document chunked into $($response.chunk_count) pieces, waiting for embedding..." -ForegroundColor Cyan
            }
            elseif ($response.status -eq "embedding" -and $response.progress -lt 100) {
                $eta = [math]::Ceiling(($response.chunk_count - $response.chunks_embedded) / 5)
                Write-Host "  ⚡ Embeddings being generated (ETA: ~$eta seconds)..." -ForegroundColor Yellow
            }
            elseif ($response.status -eq "completed") {
                Write-Host "  ✅ Processing complete! Document ready for queries." -ForegroundColor Green
            }
            Write-Host ""
        }

        # Exit if completed or error
        if ($response.status -eq "completed") {
            Write-Host "`n╔══════════════════════════════════════╗" -ForegroundColor Green
            Write-Host "║   ✅ PROCESSING COMPLETED! ✅       ║" -ForegroundColor Green
            Write-Host "╚══════════════════════════════════════╝`n" -ForegroundColor Green

            Write-Host "Document Details:" -ForegroundColor Cyan
            Write-Host "  • Document ID: $($response.document_id)" -ForegroundColor White
            Write-Host "  • File: $($response.document_key)" -ForegroundColor White
            Write-Host "  • Total Chunks: $($response.chunk_count)" -ForegroundColor White
            Write-Host "  • All chunks embedded and indexed in Pinecone" -ForegroundColor White
            Write-Host "`nYou can now query this document!`n" -ForegroundColor Green
            break
        }

        if ($response.status -eq "error") {
            Write-Host "`n╔══════════════════════════════════════╗" -ForegroundColor Red
            Write-Host "║   ❌ PROCESSING FAILED! ❌          ║" -ForegroundColor Red
            Write-Host "╚══════════════════════════════════════╝`n" -ForegroundColor Red

            Write-Host "Check CloudWatch logs for details:" -ForegroundColor Yellow
            Write-Host "  • Chunking Lambda logs" -ForegroundColor White
            Write-Host "  • Embedder Lambda logs" -ForegroundColor White
            Write-Host "  • DynamoDB documents table`n" -ForegroundColor White
            break
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__

        if ($statusCode -eq 404) {
            Write-Host "`n[ERROR] Document not found: $DocumentId" -ForegroundColor Red
            Write-Host "        The document may not have been uploaded yet." -ForegroundColor Yellow
            Write-Host "        Check the document ID and try again.`n" -ForegroundColor Yellow
            break
        }
        else {
            Write-Host "[ERROR] Failed to get status: $_" -ForegroundColor Red
            Write-Host "        Retrying in 3 seconds...`n" -ForegroundColor Yellow
        }
    }

    Start-Sleep -Seconds 3
}

Write-Host "`nMonitoring stopped.`n" -ForegroundColor Gray

