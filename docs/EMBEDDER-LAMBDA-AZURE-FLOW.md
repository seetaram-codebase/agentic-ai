# Embedder Lambda: Azure OpenAI Integration

## YES! Embedder Lambda Calls Azure OpenAI ✅

The embedder lambda **absolutely calls Azure OpenAI** to generate embeddings.

## How It Works

### 1. Get Azure OpenAI Configuration from SSM

```python
def get_azure_config_from_env():
    """Loads Azure OpenAI config from SSM Parameter Store"""
    
    # Tries primary region first (us-east)
    # Falls back to failover region (eu-west) if primary fails
    
    # Gets from SSM:
    # - /rag-demo/azure-openai/us-east/embedding-key
    # - /rag-demo/azure-openai/us-east/embedding-endpoint  
    # - /rag-demo/azure-openai/us-east/embedding-deployment
```

### 2. Create Azure OpenAI Embedding Client

```python
def create_embedding_model(config: dict):
    """Creates LangChain Azure OpenAI embedding client"""
    
    from langchain_openai import AzureOpenAIEmbeddings
    
    embedding_model = AzureOpenAIEmbeddings(
        azure_endpoint=config['endpoint'],      # From SSM
        api_key=config['api_key'],              # From SSM
        azure_deployment=config['deployment'],   # text-embedding-3-small
        api_version="2024-02-01"
    )
    
    return embedding_model
```

### 3. Generate Embedding via Azure OpenAI API

```python
def generate_embedding_langchain(text: str, embedding_model) -> list:
    """Calls Azure OpenAI to generate embedding"""
    
    # This makes an HTTP request to Azure OpenAI:
    # POST https://<your-endpoint>.openai.azure.com/openai/deployments/text-embedding-3-small/embeddings
    
    embedding = embedding_model.embed_query(text)
    
    # Returns: [0.123, -0.456, 0.789, ...] (1536 floats)
    return embedding
```

### 4. Store in Pinecone

```python
def store_to_pinecone(document_id, document_key, chunk, embedding):
    """Stores the embedding in Pinecone"""
    
    pc = Pinecone(api_key=pinecone_api_key)
    index = pc.Index('rag-demo')
    
    index.upsert(vectors=[{
        'id': f"{document_id}_{chunk['index']}",
        'values': embedding,  # The 1536-dim vector from Azure OpenAI
        'metadata': {
            'document_id': document_id,
            'text': chunk['text'],
            'source': chunk['source']
        }
    }])
```

## Complete Flow

```
📄 Document Uploaded
    ↓
S3 → SQS → Chunker Lambda
    ↓
SQS (one message per chunk)
    ↓
🔥 EMBEDDER LAMBDA TRIGGERED
    ↓
┌─────────────────────────────────────┐
│ 1. Get chunk text from SQS message  │
│    "This is a sample document..."   │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 2. Get Azure OpenAI config from SSM │
│    - endpoint: https://xxx.openai.. │
│    - api_key: sk-xxx...             │
│    - deployment: text-embedding-..  │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 3. CALL AZURE OPENAI API            │
│    POST /embeddings                 │
│    Input: "This is a sample..."     │
│                                     │
│    Response: [0.123, -0.456, ...]   │
│    (1536-dimensional vector)        │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 4. Store in Pinecone                │
│    ID: doc123_0                     │
│    Values: [0.123, -0.456, ...]     │
│    Metadata: {text: "This is..."}   │
└─────────────────────────────────────┘
    ↓
✅ Embedding stored in Pinecone
```

## Key Points

### Azure OpenAI is Used For:

1. **Generating Embeddings** (Embedder Lambda)
   - Model: `text-embedding-3-small`
   - Converts text → 1536-dimensional vectors
   - Stored in Pinecone

2. **Generating Chat Responses** (Backend API)
   - Model: `gpt-4` or `gpt-35-turbo`
   - Uses retrieved context to answer questions
   - Runs in ECS backend

### What Gets Stored in Pinecone:

- **Vector**: The 1536 numbers from Azure OpenAI
- **Metadata**: Original text, document ID, source, etc.

### Failover Support:

The embedder lambda supports multi-region failover:
- Primary: `us-east` Azure OpenAI
- Failover: `eu-west` Azure OpenAI
- If primary fails, automatically tries failover region

## Verify Azure OpenAI is Being Called

### Check Lambda Logs

CloudWatch → Log Group: `/aws/lambda/rag-demo-embedder`

**Success logs:**
```
Created Azure OpenAI embedding model: text-embedding-3-small
Processing chunk 0 for document abc123
Successfully embedded chunk 0 for abc123
Stored embedding in Pinecone: abc123_0
```

**Failure logs:**
```
Error generating embedding with LangChain: Azure OpenAI API error
```

### SSM Parameters Required

The lambda needs these SSM parameters:

**Primary Region (us-east):**
```
/rag-demo/azure-openai/us-east/embedding-key
/rag-demo/azure-openai/us-east/embedding-endpoint
/rag-demo/azure-openai/us-east/embedding-deployment
```

**Failover Region (eu-west):**
```
/rag-demo/azure-openai/eu-west/embedding-key
/rag-demo/azure-openai/eu-west/embedding-endpoint
/rag-demo/azure-openai/eu-west/embedding-deployment
```

## Cost Implications

**Every chunk embedded costs money:**

- Model: `text-embedding-3-small`
- Cost: ~$0.00002 per 1K tokens
- Example: 100-page PDF → ~500 chunks → ~$0.01

**This is why embeddings are generated asynchronously:**
- Upload is instant (just puts file in S3)
- Lambda processes in background
- Can handle spikes without blocking UI

## Code Reference

**File:** `lambda/embedder/handler.py`

**Key Functions:**
- `get_azure_config_from_env()` - Gets Azure config from SSM
- `create_embedding_model()` - Creates AzureOpenAIEmbeddings client
- `generate_embedding_langchain()` - **Calls Azure OpenAI API**
- `store_to_pinecone()` - Stores result in Pinecone

## Summary

✅ **YES** - Embedder lambda calls Azure OpenAI  
✅ Uses `text-embedding-3-small` model  
✅ Generates 1536-dimensional vectors  
✅ Stores in Pinecone for fast retrieval  
✅ Supports multi-region failover  

The embeddings you saw in Pinecone were **generated by Azure OpenAI** via the embedder lambda!

