# Run Backend Locally - Quick Start Guide

## Prerequisites Check

```powershell
# Check Python version (need 3.11+)
python --version

# Check if pip is available
pip --version
```

## Step 1: Install Dependencies

```powershell
cd backend

# Create virtual environment (if not exists)
python -m venv .venv

# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

## Step 2: Configure Environment

The `.env` file is already configured with:
- ✅ Azure OpenAI endpoints (us-east + eu-west)
- ✅ Embedding model: `text-embedding-3-small`
- ✅ Local ChromaDB (Pinecone disabled)

**No changes needed!**

## Step 3: Run Backend

```powershell
# From backend directory
cd backend

# Activate venv (if not already active)
.\.venv\Scripts\Activate.ps1

# Run the server
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Step 4: Verify Running

Open browser: http://localhost:8000/docs

You should see FastAPI Swagger UI with all endpoints.

## Step 5: Test Embedding Endpoint

```powershell
# Test health check
curl http://localhost:8000/health

# Test query (will test embeddings)
curl -X POST http://localhost:8000/query `
  -H "Content-Type: application/json" `
  -d '{"query": "test query"}'
```

## Common Issues & Solutions

### Issue 1: Port 8000 Already in Use

```powershell
# Use different port
python -m uvicorn app.main:app --reload --port 8001
```

### Issue 2: Module Not Found

```powershell
# Make sure you're in backend directory
cd C:\Users\seeta\IdeaProjects\agentic-ai\backend

# Reinstall dependencies
pip install -r requirements.txt
```

### Issue 3: Azure OpenAI API Keys Invalid

Check `.env` file and update with valid keys from Azure Portal.

## Watch Logs in Real-Time

The `--reload` flag shows live logs in terminal:

```
INFO:     Started server process [12345]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

When you make a request, you'll see:
```
INFO - Loaded configs from SSM: 2 chat, 2 embedding
INFO - Loaded embedding client: Embedding (us-east), model: text-embedding-3-small
INFO - generate_embeddings called with 1 texts
INFO - Generating embeddings with Embedding (us-east)
```

## Debug the Embedding Error

Once running locally, test the query endpoint and watch the terminal for the detailed logs we added:

```
INFO - Processing embedding client 0: (<AzureOpenAI...>, 'text-embedding-3-small', 'Embedding (us-east)')
INFO - Tuple length: 3, types: ['AzureOpenAI', 'str', 'str']
INFO - Unpacked - client type: AzureOpenAI, deployment: text-embedding-3-small, name: Embedding (us-east)
```

If you see the error, you'll see exactly which line fails!

## Advantages of Local Testing

✅ **Instant feedback** - No waiting for Docker builds or ECS deployments  
✅ **Live reload** - Code changes apply immediately  
✅ **Full logs** - See everything in terminal  
✅ **Easy debugging** - Can add print statements  
✅ **No AWS costs** - Test locally for free  

## Next Steps After Local Testing Works

1. Fix any issues found locally
2. Commit and push changes
3. GitHub Actions will deploy to ECS automatically
4. ECS will have the same working code

Ready to run! 🚀

