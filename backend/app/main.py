"""
FastAPI Main Application - RAG Demo API
"""
import os
import tempfile
import logging
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


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
    chunks_created: int
    document_id: str
    provider: str
    status: str


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
    """Basic health check"""
    return {"status": "healthy"}


@app.post("/upload", response_model=UploadResponse)
async def upload_document(file: UploadFile = File(...)):
    """
    Upload a document for processing.

    Supports PDF and TXT files.
    """
    # Validate file type
    allowed_extensions = {'.pdf', '.txt'}
    file_ext = os.path.splitext(file.filename)[1].lower()

    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type. Allowed: {allowed_extensions}"
        )

    try:
        # Save to temp file
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_ext) as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = tmp.name

        # Process the document
        rag = get_rag()
        result = rag.process_file(tmp_path, file.filename)

        # Clean up temp file
        os.unlink(tmp_path)

        return UploadResponse(**result)

    except Exception as e:
        logger.error(f"Error processing upload: {e}")
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
async def list_documents():
    """List ingested documents (from vector store stats)"""
    try:
        rag = get_rag()
        stats = rag.get_stats()
        return {
            "document_count": stats["vector_store"].get("document_count", 0),
            "vector_store_type": stats["vector_store"].get("type", "unknown")
        }
    except Exception as e:
        logger.error(f"Error listing documents: {e}")
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
