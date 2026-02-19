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
import time
import boto3
import urllib.request

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS Clients
dynamodb = boto3.resource('dynamodb')
ssm = boto3.client('ssm')

# Environment variables
CONFIG_TABLE = os.environ.get('DYNAMODB_CONFIG_TABLE', 'rag-demo-config')
DOCUMENTS_TABLE = os.environ.get('DYNAMODB_DOCUMENTS_TABLE', 'rag-demo-documents')

# Pinecone configuration
PINECONE_API_KEY_PARAM = os.environ.get('PINECONE_API_KEY_PARAM', '')
PINECONE_INDEX = os.environ.get('PINECONE_INDEX', 'rag-demo')
USE_PINECONE = os.environ.get('USE_PINECONE', 'false').lower() == 'true'

# Azure OpenAI configuration (from SSM Parameter Store)
# Supports multi-region with failover: us-east, eu-west
AZURE_REGION_PRIMARY = os.environ.get('AZURE_REGION_PRIMARY', 'us-east')
AZURE_REGION_FAILOVER = os.environ.get('AZURE_REGION_FAILOVER', 'eu-west')
AZURE_OPENAI_API_VERSION = os.environ.get('AZURE_OPENAI_API_VERSION', '2024-02-01')
APP_NAME = os.environ.get('APP_NAME', 'rag-demo')


def get_pinecone_api_key():
    """Get Pinecone API key from SSM Parameter Store"""
    if not PINECONE_API_KEY_PARAM:
        logger.warning("PINECONE_API_KEY_PARAM not set, Pinecone storage disabled")
        return None

    try:
        response = ssm.get_parameter(Name=PINECONE_API_KEY_PARAM, WithDecryption=True)
        return response['Parameter']['Value']
    except Exception as e:
        logger.error(f"Failed to get Pinecone API key from SSM: {e}")
        return None


def lambda_handler(event, context):
    """
    Main Lambda handler - generates embeddings for chunks via SQS trigger
    Uses OpenAIEmbeddings (text-embedding-ada-002) as per notebook
    """
    logger.info(f"🚀 Lambda handler started")
    logger.info(f"Received event: {json.dumps(event)}")
    logger.info(f"Context: {context}")
    logger.info(f"Received {len(event.get('Records', []))} records")

    processed_count = 0
    error_count = 0

    # Get Azure OpenAI config from environment or DynamoDB
    azure_config = get_azure_config_from_env() or get_azure_config()
    if not azure_config:
        logger.warning("No Azure OpenAI embedding config found - embeddings will be skipped")
        # Don't raise exception, just log warning and skip embedding generation
        # This allows the Lambda to complete without error
        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed': 0,
                'errors': 0,
                'message': 'No Azure OpenAI config - skipped embedding generation'
            })
        }

    # Initialize embedding model (like notebook)
    embedding_model = create_embedding_model(azure_config)

    for record in event.get('Records', []):
        try:
            logger.info(f"Processing record: {json.dumps(record)}")

            # Parse SQS message body
            body = json.loads(record['body'])
            logger.info(f"Parsed SQS body: {json.dumps(body)}")

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


def get_azure_config_from_env() -> dict:
    """
    Get Azure OpenAI configuration from SSM Parameter Store

    Uses existing parameter structure:
    - /{app_name}/azure-openai/{region}/embedding-key
    - /{app_name}/azure-openai/{region}/embedding-endpoint
    - /{app_name}/azure-openai/{region}/embedding-deployment

    Supports multi-region failover: us-east (primary) → eu-west (failover)
    """
    # Try primary region first
    config = try_get_azure_config_for_region(AZURE_REGION_PRIMARY)
    if config:
        return config

    # Failover to secondary region
    logger.warning(f"Primary region {AZURE_REGION_PRIMARY} failed, trying failover region {AZURE_REGION_FAILOVER}")
    config = try_get_azure_config_for_region(AZURE_REGION_FAILOVER)
    if config:
        return config

    logger.warning("No Azure OpenAI configuration found in any region")
    return None


def try_get_azure_config_for_region(region: str) -> dict:
    """Try to get Azure OpenAI config for a specific region from SSM"""
    try:
        # Parameter paths based on your existing structure
        key_param = f"/{APP_NAME}/azure-openai/{region}/embedding-key"
        endpoint_param = f"/{APP_NAME}/azure-openai/{region}/embedding-endpoint"
        deployment_param = f"/{APP_NAME}/azure-openai/{region}/embedding-deployment"

        logger.info(f"Trying to get Azure OpenAI config for region: {region}")

        # Get all parameters at once for efficiency
        response = ssm.get_parameters(
            Names=[key_param, endpoint_param, deployment_param],
            WithDecryption=True
        )

        if not response.get('Parameters'):
            logger.warning(f"No parameters found for region {region}")
            return None

        # Parse parameters
        params = {p['Name']: p['Value'] for p in response['Parameters']}

        # Check if we have all required parameters
        api_key = params.get(key_param)
        endpoint = params.get(endpoint_param)
        deployment = params.get(deployment_param)

        if not all([api_key, endpoint, deployment]):
            missing = []
            if not api_key: missing.append('api-key')
            if not endpoint: missing.append('endpoint')
            if not deployment: missing.append('deployment')
            logger.warning(f"Missing parameters for region {region}: {missing}")
            return None

        # Validate values are not placeholders
        if api_key.startswith('REPLACE_WITH_') or endpoint.startswith('https://YOUR_'):
            logger.warning(f"Region {region} has placeholder values - please update SSM parameters")
            return None

        config = {
            'endpoint': endpoint,
            'api_key': api_key,
            'deployment': deployment,
            'api_version': AZURE_OPENAI_API_VERSION,
            'config_id': f'ssm-{region}',
            'region': region,
            'priority': 1
        }

        logger.info(f"✅ Using Azure OpenAI config from region: {region}, deployment: {deployment}")
        return config

    except Exception as e:
        logger.error(f"Failed to get Azure OpenAI config for region {region}: {e}")
        return None


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
    Store embedding in Pinecone vector database
    """
    if not USE_PINECONE:
        logger.error("Pinecone is disabled - cannot store embeddings")
        return False

    try:
        logger.info(f"Storing embedding in Pinecone for chunk {chunk['index']}")
        store_to_pinecone(document_id, document_key, chunk, embedding)
        logger.info(f"✅ Stored embedding in Pinecone for chunk {chunk['index']}")
        return True
    except Exception as e:
        logger.error(f"Error storing in Pinecone: {e}")
        return False




def store_to_pinecone(document_id: str, document_key: str, chunk: dict, embedding: list):
    """Store embedding directly to Pinecone"""
    from pinecone import Pinecone

    # Get API key from SSM
    api_key = get_pinecone_api_key()
    if not api_key:
        logger.error("Pinecone API key not available")
        return

    pc = Pinecone(api_key=api_key)
    index = pc.Index(PINECONE_INDEX)

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
