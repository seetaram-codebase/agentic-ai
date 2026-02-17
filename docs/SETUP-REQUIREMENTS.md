# Setup Requirements for RAG Demo

## ✅ Prerequisites Checklist

### 1. Azure OpenAI (REQUIRED)

You need **at least 1 Azure OpenAI subscription** (2 for failover demo).

#### Option A: Single Subscription (Minimum)
- 1 Azure OpenAI resource
- Cost: ~$0.50-2.00/hour during demo

#### Option B: Two Subscriptions (Full Failover Demo)
- 2 Azure OpenAI resources (different regions recommended)
- Cost: Same (only one active at a time)

#### Setup Steps:

1. **Go to Azure Portal**: https://portal.azure.com

2. **Create Azure OpenAI Resource**:
   - Search "Azure OpenAI" → Create
   - **Subscription**: Select your Azure subscription
   - **Resource Group**: Click "Create new" → name it `rag-demo-rg` (just a folder for organizing)
   - **Region**: East US (recommended)
   - **Name**: e.g., `my-openai-us-east-1` (must be globally unique)
   - **Pricing tier**: Standard S0
   - **Tags** (optional but recommended):
     | Name | Value |
     |------|-------|
     | `project` | `rag-demo` |
     | `environment` | `demo` |
     | `owner` | `your-name` |
     | `event` | `developer-week-2026` |
   - Click Review + Create → Create
   - Wait for deployment (~5 min)

3. **Deploy Models** (in Azure OpenAI Studio):
   - Go to your resource → "Model deployments" → "Manage Deployments"
   - You need **2 deployments**: one for chat, one for embeddings
   
   ---
   
   **DEPLOYMENT 1: Chat Model** (click "+ Create new deployment")
   | Model | Cost (per 1K tokens) | Speed | Recommendation |
   |-------|---------------------|-------|----------------|
   | `gpt-35-turbo` | $0.0015 in / $0.002 out | ⚡ Fast | 💰 **Cheapest** |
   | `gpt-4o-mini` | $0.00015 in / $0.0006 out | ⚡ Fast | 💰 **Best value** |
   | `gpt-4o` | $0.005 in / $0.015 out | ⚡ Fast | ⭐ Best for demo |
   | `gpt-4` | $0.03 in / $0.06 out | 🐢 Slower | Most capable (older) |
   | `gpt-5-mini` | ~$0.01 in / $0.03 out | ⚡ Fast | New, if available |
   | `gpt-5` | ~$0.05 in / $0.15 out | Medium | 🚀 Latest (expensive) |
   
   > **💡 Recommendation**: Use `gpt-4o-mini` for development/testing (cheapest), switch to `gpt-4o` for demo day.
   
   ---
   
   **DEPLOYMENT 2: Embedding Model** (click "+ Create new deployment" again)
   | Model | Cost (per 1M tokens) | Dimensions | Recommendation |
   |-------|---------------------|------------|----------------|
   | `text-embedding-3-small` | $0.02 | 1536 | 💰 **Cheapest - Use this!** |
   | `text-embedding-3-large` | $0.13 | 3072 | Better quality, 6x more expensive |
   | `text-embedding-ada-002` | $0.10 | 1536 | Older, reliable |
   
   > **💡 Pick `text-embedding-3-small`** - 5x cheaper than ada-002, same quality for RAG.
   
   ---
   
   **After creating both deployments, you should see:**
   | Deployment Name | Model |
   |-----------------|-------|
   | `gpt-4o-mini` | gpt-4o-mini |
   | `text-embedding-3-small` | text-embedding-3-small |
   
   - **Deployment name**: Use same as model name (e.g., `gpt-4o-mini`)
   - Note your deployment names for `.env` file!

4. **Get Your Credentials**:
   - Go to resource → "Keys and Endpoint"
   - Copy: **Endpoint URL** and **Key 1**

5. **For Failover (Optional)**:
   - Repeat steps 1-4 in a different region (West US)
   - Name it: `my-openai-us-west-1`
   - Or use a second Azure subscription

---

### 2. Local Software (REQUIRED)

| Software | Check Command | Install |
|----------|--------------|---------|
| Python 3.11+ | `python --version` | https://python.org |
| Node.js 18+ | `node --version` | https://nodejs.org |
| pip | `pip --version` | Comes with Python |
| npm | `npm --version` | Comes with Node.js |

---

### 3. Pinecone (OPTIONAL - Free Tier)

Only needed if you want cloud vector storage instead of local Chroma.

1. Sign up: https://www.pinecone.io (free tier = 100K vectors)
2. Create an index named "rag-demo"
3. Get your API key

---

### 4. AWS (OPTIONAL - Phase 2)

Only needed for full S3/SQS/Lambda pipeline (Day 2-3 work).

- AWS Account
- AWS CLI configured
- IAM permissions for S3, SQS, Lambda

---

## 🔧 Configuration

After getting Azure credentials, edit `backend/.env`:

```env
# Primary Azure OpenAI (REQUIRED)
AZURE_OPENAI_ENDPOINT_1=https://my-openai-us-east-1.openai.azure.com/
AZURE_OPENAI_KEY_1=your-api-key-here
AZURE_OPENAI_DEPLOYMENT_1=gpt-4o-mini

# Secondary Azure OpenAI (OPTIONAL - for failover demo)
AZURE_OPENAI_ENDPOINT_2=https://my-openai-us-west-1.openai.azure.com/
AZURE_OPENAI_KEY_2=your-backup-key-here
AZURE_OPENAI_DEPLOYMENT_2=gpt-4o-mini

# Embedding model (text-embedding-3-small is cheapest)
AZURE_OPENAI_EMBEDDING_DEPLOYMENT=text-embedding-3-small

# Vector DB (use Chroma locally - no setup needed)
USE_PINECONE=false
CHROMA_PERSIST_DIR=./chroma_db
```

---

## 💰 Cost Breakdown

| Item | Setup Cost | Running Cost |
|------|------------|--------------|
| Azure OpenAI resource | $0 | Pay per use |
| GPT-4 usage | - | ~$0.03/1K input + $0.06/1K output |
| Embeddings | - | ~$0.0001/1K tokens |
| Pinecone free tier | $0 | $0 |
| **Total for 1-hour demo** | **$0** | **~$1-3** |

---

## ⏱️ Setup Time Estimate

| Task | Time |
|------|------|
| Create Azure OpenAI resource | 10 min |
| Deploy models | 5 min |
| Configure .env file | 2 min |
| Install Python dependencies | 3 min |
| Install Node dependencies | 3 min |
| **Total** | **~25 min** |

---

## 🚀 Quick Setup Commands

After configuring `.env`:

```powershell
# 1. Install backend
cd C:\Users\seeta\IdeaProjects\agentic-ai\backend
pip install -r requirements.txt

# 2. Install frontend
cd ..\electron-ui
npm install

# 3. Start backend (Terminal 1)
cd ..\backend
uvicorn app.main:app --reload --port 8000

# 4. Start frontend (Terminal 2)
cd ..\electron-ui
npm run dev
```

---

## ❓ Don't Have Azure OpenAI Access?

Azure OpenAI requires approval. If you don't have access:

1. **Apply for access**: https://aka.ms/oai/access (takes 1-2 days)
2. **Alternative**: Use regular OpenAI API (requires code change)
3. **Alternative**: Use a mock/demo mode (I can add this)

**Do you have Azure OpenAI access, or should I add a fallback to regular OpenAI API?**
