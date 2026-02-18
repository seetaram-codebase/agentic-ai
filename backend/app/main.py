"""
FastAPI Main Application - RAG Demo API
"""
import os
import tempfile
import logging
import uuid
from typing import Optional, List
from contextlib import asynccontextmanager
from datetime import datetime

from fastapi import FastAPI, UploadFile, File, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
import boto3

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# AWS Configuration
USE_S3_UPLOAD = os.getenv('USE_S3_UPLOAD', 'true').lower() == 'true'
S3_BUCKET = os.getenv('S3_BUCKET', '')
AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
DYNAMODB_DOCUMENTS_TABLE = os.getenv('DYNAMODB_DOCUMENTS_TABLE', 'rag-demo-documents')

# Initialize AWS clients
s3_client = None
dynamodb_client = None
if USE_S3_UPLOAD:
    try:
        s3_client = boto3.client('s3', region_name=AWS_REGION)
        dynamodb_client = boto3.resource('dynamodb', region_name=AWS_REGION)
        logger.info(f"AWS clients initialized (S3 bucket: {S3_BUCKET})")
    except Exception as e:
        logger.warning(f"Failed to initialize AWS clients: {e}")
        USE_S3_UPLOAD = False


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler"""
    logger.info("Starting RAG Demo API...")
    yield
    logger.info("Shutting down RAG Demo API...")


# Create FastAPI app
app = FastAPI(
    title="RAG Demo API",
    description="Scalable RAG Application with Azure OpenAI Failover",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS for Electron app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request/Response Models
class QueryRequest(BaseModel):
    question: str
    n_results: Optional[int] = 5


class QueryResponse(BaseModel):
    response: str
    sources: list
    provider: str


class UploadResponse(BaseModel):
    filename: str
    document_id: str
    status: str
    message: str
    s3_key: str
    bucket: str


class DocumentStatus(BaseModel):
    document_id: str
    document_key: str
    status: str  # 'uploaded', 'chunked', 'embedding', 'completed', 'error'
    chunk_count: int
    chunks_embedded: int
    progress: int  # 0-100
    created_at: int
    updated_at: int


class DocumentListItem(BaseModel):
    document_id: str
    document_key: str
    status: str
    chunk_count: int
    created_at: int


class HealthResponse(BaseModel):
    status: str
    current_provider: str
    endpoints: list


class StatsResponse(BaseModel):
    vector_store: dict
    azure_openai: dict


# Lazy imports to avoid initialization issues
def get_rag():
    from .rag_engine import get_rag_engine
    return get_rag_engine()


def get_azure():
    from .azure_openai import get_azure_client
    return get_azure_client()


# API Endpoints
@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "RAG Demo API",
        "version": "1.0.0",
        "docs": "/docs"
    }


@app.get("/health")
async def health_check():
    """Basic health check - used by Docker and ECS"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "rag-demo-api"
    }


@app.get("/ready")
async def readiness_check():
    """Readiness check - verifies dependencies are available"""
    try:
        # Check if we can initialize RAG engine (lightweight check)
        status = {
            "status": "ready",
            "timestamp": datetime.utcnow().isoformat(),
            "checks": {
                "api": "ok"
            }
        }

        # Try to check vector store (optional, may fail if not initialized)
        try:
            rag = get_rag()
            status["checks"]["vector_store"] = "ok"
        except Exception as e:
            logger.warning(f"Vector store check failed: {e}")
            status["checks"]["vector_store"] = "initializing"

        return status
    except Exception as e:
        logger.error(f"Readiness check failed: {e}")
        raise HTTPException(status_code=503, detail="Service not ready")


@app.post("/upload", response_model=UploadResponse)
async def upload_document(file: UploadFile = File(...)):
    """
    Upload a document for async processing via S3 + Lambda.

    Supports PDF and TXT files.

    **Processing Flow**:
    1. File uploaded to S3 (uploads/ folder)
    2. S3 event triggers SQS notification
    3. Chunker Lambda processes document
    4. Embedder Lambda generates embeddings
    5. Check status via /documents/{id}/status
    """
    # Validate file type
    allowed_extensions = {'.pdf', '.txt'}
    file_ext = os.path.splitext(file.filename)[1].lower()

    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type. Allowed: {allowed_extensions}"
        )

    # Ensure S3 is configured
    if not USE_S3_UPLOAD or not s3_client:
        raise HTTPException(
            status_code=503,
            detail="S3 upload not configured. Set USE_S3_UPLOAD=true and configure AWS credentials."
        )

    try:
        # Generate unique document ID
        document_id = str(uuid.uuid4())[:16]
        s3_key = f"uploads/{document_id}_{file.filename}"

        # Upload file to S3
        content = await file.read()
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=content,
            ContentType=file.content_type or 'application/octet-stream',
            Metadata={
                'original_filename': file.filename,
                'document_id': document_id
            }
        )

        logger.info(f"Uploaded {file.filename} to S3: s3://{S3_BUCKET}/{s3_key}")

        # Create initial document record in DynamoDB
        if dynamodb_client:
            table = dynamodb_client.Table(DYNAMODB_DOCUMENTS_TABLE)
            timestamp = int(datetime.utcnow().timestamp())

            table.put_item(Item={
                'document_id': document_id,
                'document_key': s3_key,
                'bucket': S3_BUCKET,
                'original_filename': file.filename,
                'status': 'uploaded',
                'chunk_count': 0,
                'chunks_embedded': 0,
                'file_size': len(content),
                'created_at': timestamp,
                'updated_at': timestamp
            })

        return UploadResponse(
            filename=file.filename,
            document_id=document_id,
            status='processing',
            message=f'Document uploaded and queued for processing. Check status at /documents/{document_id}/status',
            s3_key=s3_key,
            bucket=S3_BUCKET
        )

    except Exception as e:
        logger.error(f"Error uploading to S3: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/query", response_model=QueryResponse)
async def query_documents(request: QueryRequest):
    """
    Query the RAG system with a question.

    Returns an answer based on uploaded documents.
    """
    if not request.question.strip():
        raise HTTPException(status_code=400, detail="Question cannot be empty")

    try:
        rag = get_rag()
        result = rag.query(
            question=request.question,
            n_results=request.n_results
        )

        return QueryResponse(
            response=result.response,
            sources=result.sources,
            provider=result.provider
        )

    except Exception as e:
        logger.error(f"Error processing query: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/stats", response_model=StatsResponse)
async def get_stats():
    """Get system statistics"""
    try:
        rag = get_rag()
        stats = rag.get_stats()
        return StatsResponse(**stats)
    except Exception as e:
        logger.error(f"Error getting stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/documents")
async def list_documents(limit: int = Query(100, le=500)) -> List[DocumentListItem]:
    """
    List all documents from DynamoDB.

    Returns documents sorted by creation date (newest first).
    """
    if not dynamodb_client:
        raise HTTPException(
            status_code=503,
            detail="Document listing requires DynamoDB. Configure AWS credentials and DynamoDB table."
        )

    try:
        table = dynamodb_client.Table(DYNAMODB_DOCUMENTS_TABLE)
        response = table.scan(Limit=limit)

        items = response.get('Items', [])
        # Sort by created_at descending
        items.sort(key=lambda x: x.get('created_at', 0), reverse=True)

        documents = [
            DocumentListItem(
                document_id=item['document_id'],
                document_key=item.get('document_key', ''),
                status=item.get('status', 'unknown'),
                chunk_count=item.get('chunk_count', 0),
                created_at=item.get('created_at', 0)
            )
            for item in items
        ]

        logger.info(f"Listed {len(documents)} documents")
        return documents

    except Exception as e:
        logger.error(f"Error listing documents: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/documents/{document_id}/status", response_model=DocumentStatus)
async def get_document_status(document_id: str):
    """
    Get processing status of a document.

    Use this to check if a document has completed processing.

    **Status values**:
    - `uploaded`: File uploaded to S3, waiting for chunking
    - `chunked`: Document chunked, waiting for embedding
    - `embedding`: Embeddings being generated
    - `completed`: All chunks embedded, ready for querying
    - `error`: Processing failed
    """
    if not dynamodb_client:
        raise HTTPException(
            status_code=503,
            detail="Status tracking requires DynamoDB. Configure AWS credentials and DynamoDB table."
        )

    try:
        table = dynamodb_client.Table(DYNAMODB_DOCUMENTS_TABLE)
        response = table.get_item(Key={'document_id': document_id})

        if 'Item' not in response:
            raise HTTPException(status_code=404, detail=f"Document {document_id} not found")

        item = response['Item']
        chunk_count = item.get('chunk_count', 0)
        chunks_embedded = item.get('chunks_embedded', 0)

        # Calculate progress
        if chunk_count > 0:
            progress = int((chunks_embedded / chunk_count) * 100)
        else:
            progress = 0

        # Determine status
        status = item.get('status', 'unknown')
        if status == 'chunked' and chunks_embedded == chunk_count and chunk_count > 0:
            status = 'completed'
        elif status == 'chunked' and chunks_embedded > 0:
            status = 'embedding'

        return DocumentStatus(
            document_id=document_id,
            document_key=item.get('document_key', ''),
            status=status,
            chunk_count=chunk_count,
            chunks_embedded=chunks_embedded,
            progress=progress,
            created_at=item.get('created_at', 0),
            updated_at=item.get('updated_at', 0)
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting document status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/documents")
async def clear_documents():
    """Clear all documents from the vector store"""
    try:
        rag = get_rag()
        success = rag.clear_documents()
        return {"success": success, "message": "Documents cleared" if success else "Failed to clear"}
    except Exception as e:
        logger.error(f"Error clearing documents: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/embeddings")
async def store_embedding_api(
    document_id: str,
    chunk_index: int,
    text: str,
    embedding: List[float],
    metadata: dict = {}
):
    """
    Store embedding in vector database.

    Called by Embedder Lambda to store embeddings.
    Lambda can't run ChromaDB (too large), so it calls this API.
    """
    try:
        vector_store = get_vector_store()

        # Store in vector database (ChromaDB/Pinecone)
        vector_store.add_documents(
            texts=[text],
            embeddings=[embedding],
            metadatas=[{
                'document_id': document_id,
                'chunk_index': chunk_index,
                **metadata
            }],
            ids=[f"{document_id}_{chunk_index}"]
        )

        logger.info(f"Stored embedding for document {document_id}, chunk {chunk_index}")
        return {"status": "success", "chunk_index": chunk_index, "document_id": document_id}

    except Exception as e:
        logger.error(f"Error storing embedding: {e}")
        raise HTTPException(status_code=500, detail=str(e))


def get_vector_store():
    """Get vector store instance"""
    from .vector_store import get_vector_store as _get_vector_store
    return _get_vector_store()


# Demo endpoints for failover demonstration
@app.get("/demo/health-status", response_model=HealthResponse)
async def get_health_status():
    """Get detailed health status of Azure OpenAI endpoints"""
    try:
        azure = get_azure()
        status = azure.get_status()

        return HealthResponse(
            status="healthy",
            current_provider=status["current_provider"],
            endpoints=status["endpoints"]
        )
    except Exception as e:
        logger.error(f"Error getting health status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/demo/trigger-failover")
async def trigger_failover():
    """
    Manually trigger a failover for demo purposes.

    This simulates a failure of the current Azure OpenAI endpoint.
    """
    try:
        azure = get_azure()
        result = azure.trigger_failover()
        return result
    except Exception as e:
        logger.error(f"Error triggering failover: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/demo/health-check")
async def perform_health_check():
    """Perform active health check on all Azure OpenAI endpoints"""
    try:
        azure = get_azure()
        results = azure.health_check()
        return {
            "current_provider": azure.get_current_provider(),
            "health": results
        }
    except Exception as e:
        logger.error(f"Error performing health check: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================
# DynamoDB Config Management Endpoints
# ============================================

class ConfigCreate(BaseModel):
    config_id: str
    config_type: str  # "chat" or "embedding"
    endpoint: str
    api_key: str
    deployment: str
    region: str
    priority: int
    enabled: bool = True


@app.get("/config/list")
async def list_configs():
    """List all Azure OpenAI configurations from DynamoDB"""
    try:
        from .dynamodb_config import DynamoDBConfigStore
        store = DynamoDBConfigStore()

        chat_configs = store.get_chat_configs()
        embedding_configs = store.get_embedding_configs()

        return {
            "chat": [{"config_id": c.config_id, "region": c.region, "deployment": c.deployment, "priority": c.priority, "enabled": c.enabled} for c in chat_configs],
            "embedding": [{"config_id": c.config_id, "region": c.region, "deployment": c.deployment, "priority": c.priority, "enabled": c.enabled} for c in embedding_configs]
        }
    except Exception as e:
        logger.error(f"Error listing configs: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/config/create")
async def create_config(config: ConfigCreate):
    """Create a new Azure OpenAI configuration in DynamoDB"""
    try:
        from .dynamodb_config import DynamoDBConfigStore, AzureOpenAIConfig
        store = DynamoDBConfigStore()

        azure_config = AzureOpenAIConfig(
            config_id=config.config_id,
            config_type=config.config_type,
            endpoint=config.endpoint,
            api_key=config.api_key,
            deployment=config.deployment,
            region=config.region,
            priority=config.priority,
            enabled=config.enabled
        )

        success = store.put_config(azure_config)
        return {"success": success, "config_id": config.config_id}
    except Exception as e:
        logger.error(f"Error creating config: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/config/seed-from-env")
async def seed_configs_from_environment():
    """Seed DynamoDB with configurations from environment variables"""
    try:
        from .dynamodb_config import DynamoDBConfigStore, seed_configs_from_env
        store = DynamoDBConfigStore()
        store.create_table_if_not_exists()
        seed_configs_from_env(store)
        return {"success": True, "message": "Configs seeded from environment variables"}
    except Exception as e:
        logger.error(f"Error seeding configs: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/config/{config_id}/enable")
async def enable_config(config_id: str):
    """Enable a configuration"""
    try:
        from .dynamodb_config import DynamoDBConfigStore
        store = DynamoDBConfigStore()
        success = store.enable_config(config_id)
        return {"success": success, "config_id": config_id, "enabled": True}
    except Exception as e:
        logger.error(f"Error enabling config: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/config/{config_id}/disable")
async def disable_config(config_id: str):
    """Disable a configuration"""
    try:
        from .dynamodb_config import DynamoDBConfigStore
        store = DynamoDBConfigStore()
        success = store.disable_config(config_id)
        return {"success": success, "config_id": config_id, "enabled": False}
    except Exception as e:
        logger.error(f"Error disabling config: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/config/{config_id}")
async def delete_config(config_id: str):
    """Delete a configuration"""
    try:
        from .dynamodb_config import DynamoDBConfigStore
        store = DynamoDBConfigStore()
        success = store.delete_config(config_id)
        return {"success": success, "config_id": config_id}
    except Exception as e:
        logger.error(f"Error deleting config: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Run with uvicorn
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=os.getenv("API_HOST", "0.0.0.0"),
        port=int(os.getenv("API_PORT", "8000")),
        reload=True
    )
