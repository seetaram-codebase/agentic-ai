"""
Lambda Function: Embedding Generator
Triggered by SQS when chunks are ready for embedding

Flow: Chunker Lambda → SQS → Embedding Lambda → Chroma/Pinecone Vector Store

Uses:
- OpenAIEmbeddings with text-embedding-ada-002
- Chroma vectorstore
"""
import json
import os
import logging
import boto3
import urllib.request

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS Clients
dynamodb = boto3.resource('dynamodb')

# Environment variables
CONFIG_TABLE = os.environ.get('DYNAMODB_CONFIG_TABLE', 'rag-demo-config')
DOCUMENTS_TABLE = os.environ.get('DYNAMODB_DOCUMENTS_TABLE', 'rag-demo-documents')
VECTOR_STORE_API_URL = os.environ.get('VECTOR_STORE_API_URL', '')  # ECS backend URL
USE_CHROMA = os.environ.get('USE_CHROMA', 'true').lower() == 'true'
CHROMA_PERSIST_DIR = os.environ.get('CHROMA_PERSIST_DIR', '/tmp/chroma_db')


def lambda_handler(event, context):
    """
    Main Lambda handler - generates embeddings for chunks via SQS trigger
    Uses OpenAIEmbeddings (text-embedding-ada-002) as per notebook
    """
    logger.info(f"Received {len(event.get('Records', []))} records")

    processed_count = 0
    error_count = 0

    # Get Azure OpenAI config once for all chunks
    azure_config = get_azure_config()
    if not azure_config:
        logger.error("No Azure OpenAI embedding config found")
        raise Exception("Azure OpenAI config not found")

    # Initialize embedding model (like notebook)
    embedding_model = create_embedding_model(azure_config)

    for record in event.get('Records', []):
        try:
            # Parse SQS message body
            body = json.loads(record['body'])

            document_id = body['document_id']
            document_key = body['document_key']
            chunk = body['chunk']

            logger.info(f"Processing chunk {chunk['index']} for document {document_id}")

            # Generate embedding using LangChain (like notebook)
            embedding = generate_embedding_langchain(chunk['text'], embedding_model)

            if embedding:
                # Store embedding in vector store
                store_embedding(
                    document_id=document_id,
                    document_key=document_key,
                    chunk=chunk,
                    embedding=embedding,
                    embedding_model=embedding_model
                )

                # Update document progress
                update_document_progress(document_id)

                processed_count += 1
                logger.info(f"Successfully embedded chunk {chunk['index']} for {document_id}")
            else:
                error_count += 1
                logger.error(f"Failed to generate embedding for chunk {chunk['index']}")

        except Exception as e:
            error_count += 1
            logger.error(f"Error processing chunk: {str(e)}")

    return {
        'statusCode': 200,
        'body': json.dumps({
            'processed': processed_count,
            'errors': error_count
        })
    }


def get_azure_config() -> dict:
    """Get Azure OpenAI embedding configuration from DynamoDB"""
    try:
        table = dynamodb.Table(CONFIG_TABLE)

        # Get embedding config (priority 1)
        response = table.scan(
            FilterExpression='config_type = :type AND enabled = :enabled',
            ExpressionAttributeValues={
                ':type': 'embedding',
                ':enabled': True
            }
        )

        items = response.get('Items', [])
        if items:
            # Sort by priority and return first
            items.sort(key=lambda x: x.get('priority', 99))
            config = items[0]
            logger.info(f"Using embedding config: {config.get('config_id', 'unknown')}")
            return config

        return None

    except Exception as e:
        logger.error(f"Error getting Azure config: {str(e)}")
        return None


def create_embedding_model(config: dict):
    """
    Create embedding model using LangChain OpenAIEmbeddings

    Based on notebook:
    from langchain_openai import OpenAIEmbeddings
    embedding_model = OpenAIEmbeddings(model="text-embedding-ada-002")
    """
    from langchain_openai import AzureOpenAIEmbeddings

    # For Azure OpenAI
    embedding_model = AzureOpenAIEmbeddings(
        azure_endpoint=config['endpoint'],
        api_key=config['api_key'],
        azure_deployment=config['deployment'],
        api_version="2024-02-01"
    )

    logger.info(f"Created Azure OpenAI embedding model: {config['deployment']}")
    return embedding_model


def generate_embedding_langchain(text: str, embedding_model) -> list:
    """
    Generate embedding using LangChain embedding model

    Based on notebook approach using OpenAIEmbeddings
    """
    try:
        # LangChain embed_query returns a list of floats
        embedding = embedding_model.embed_query(text)
        return embedding
    except Exception as e:
        logger.error(f"Error generating embedding with LangChain: {str(e)}")

        # Fallback to direct API call
        return generate_embedding_direct(text)


def generate_embedding_direct(text: str) -> list:
    """Fallback: Generate embedding using direct Azure OpenAI API call"""
    config = get_azure_config()
    if not config:
        return None

    endpoint = config['endpoint']
    api_key = config['api_key']
    deployment = config['deployment']

    url = f"{endpoint}openai/deployments/{deployment}/embeddings?api-version=2024-02-01"

    data = json.dumps({'input': [text]}).encode('utf-8')

    req = urllib.request.Request(url, data=data)
    req.add_header('Content-Type', 'application/json')
    req.add_header('api-key', api_key)

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result['data'][0]['embedding']
    except Exception as e:
        logger.error(f"Error generating embedding via direct API: {str(e)}")
        return None


def store_embedding(document_id: str, document_key: str, chunk: dict,
                   embedding: list, embedding_model=None):
    """
    Store embedding in vector store

    Based on notebook:
    vectorstore = Chroma.from_documents(
        ai_initiative_chunks,
        embedding_model,
        collection_name="AI_Initiatives"
    )
    """

    if USE_CHROMA and embedding_model:
        # Option 1: Store directly in Chroma (like notebook)
        try:
            store_to_chroma(document_id, document_key, chunk, embedding, embedding_model)
            return
        except Exception as e:
            logger.warning(f"Chroma storage failed: {str(e)}, trying API fallback")

    if VECTOR_STORE_API_URL:
        # Option 2: Send to ECS backend API
        try:
            store_via_api(document_id, document_key, chunk, embedding)
            return
        except Exception as e:
            logger.error(f"API storage failed: {str(e)}")

    # Option 3: Store to Pinecone
    try:
        store_to_pinecone(document_id, document_key, chunk, embedding)
    except Exception as e:
        logger.warning(f"Pinecone storage failed: {str(e)}")
        logger.info(f"Embedding generated for {document_key} chunk {chunk['index']} (storage pending)")


def store_to_chroma(document_id: str, document_key: str, chunk: dict,
                   embedding: list, embedding_model):
    """
    Store embedding directly to Chroma vectorstore

    Based on notebook:
    vectorstore = Chroma.from_documents(chunks, embedding_model, collection_name="...")
    """
    from langchain_community.vectorstores import Chroma
    from langchain.schema import Document

    # Create a Document object (LangChain format)
    doc = Document(
        page_content=chunk['text'],
        metadata={
            'document_id': document_id,
            'document_key': document_key,
            'chunk_index': chunk['index'],
            'source': chunk.get('metadata', {}).get('source', ''),
            'page': chunk.get('metadata', {}).get('page', 0)
        }
    )

    # Add to Chroma vectorstore
    # Using persistent storage with collection per document
    vectorstore = Chroma(
        collection_name="rag_documents",
        embedding_function=embedding_model,
        persist_directory=CHROMA_PERSIST_DIR
    )

    # Add the document with its pre-computed embedding
    vectorstore.add_documents([doc])

    logger.info(f"Stored chunk {chunk['index']} in Chroma for {document_key}")


def store_via_api(document_id: str, document_key: str, chunk: dict, embedding: list):
    """Store embedding via ECS backend API"""
    data = json.dumps({
        'document_id': document_id,
        'document_key': document_key,
        'chunk_index': chunk['index'],
        'chunk_text': chunk['text'],
        'embedding': embedding,
        'metadata': chunk.get('metadata', {})
    }).encode('utf-8')

    req = urllib.request.Request(
        f"{VECTOR_STORE_API_URL}/internal/store-embedding",
        data=data
    )
    req.add_header('Content-Type', 'application/json')

    with urllib.request.urlopen(req, timeout=30) as response:
        result = json.loads(response.read().decode('utf-8'))
        logger.info(f"Stored embedding via API: {result}")


def store_to_pinecone(document_id: str, document_key: str, chunk: dict, embedding: list):
    """Store embedding directly to Pinecone"""
    from pinecone import Pinecone

    pc = Pinecone(api_key=os.environ.get('PINECONE_API_KEY'))
    index = pc.Index(os.environ.get('PINECONE_INDEX', 'rag-demo'))

    vector_id = f"{document_id}_{chunk['index']}"

    index.upsert(vectors=[{
        'id': vector_id,
        'values': embedding,
        'metadata': {
            'document_id': document_id,
            'document_key': document_key,
            'chunk_index': chunk['index'],
            'text': chunk['text'][:1000],  # Limit metadata size
            'source': chunk.get('metadata', {}).get('source', ''),
            'page': chunk.get('metadata', {}).get('page', 0)
        }
    }])

    logger.info(f"Stored embedding in Pinecone: {vector_id}")


def update_document_progress(document_id: str):
    """Update the document's embedding progress in DynamoDB"""
    try:
        table = dynamodb.Table(DOCUMENTS_TABLE)
        import time

        # Increment chunks_embedded counter
        table.update_item(
            Key={'document_id': document_id},
            UpdateExpression='SET chunks_embedded = if_not_exists(chunks_embedded, :zero) + :inc, updated_at = :now',
            ExpressionAttributeValues={
                ':inc': 1,
                ':zero': 0,
                ':now': int(time.time())
            }
        )

        # Check if all chunks are embedded and update status
        response = table.get_item(Key={'document_id': document_id})
        item = response.get('Item', {})

        if item.get('chunks_embedded', 0) >= item.get('chunk_count', 0):
            table.update_item(
                Key={'document_id': document_id},
                UpdateExpression='SET #status = :status, completed_at = :now',
                ExpressionAttributeNames={'#status': 'status'},
                ExpressionAttributeValues={
                    ':status': 'completed',
                    ':now': int(time.time())
                }
            )
            logger.info(f"Document {document_id} fully embedded")

    except Exception as e:
        logger.error(f"Error updating document progress: {str(e)}")
