"""
Lambda Function: Document Chunker
Triggered by SQS when files are uploaded to S3

Flow: S3 Upload → SQS → Chunker Lambda → Chunks to SQS → Embedding Lambda

Uses:
- RecursiveCharacterTextSplitter with tiktoken encoding
- chunk_size=1000, chunk_overlap=200
"""
import json
import os
import logging
import sys

# Configure logging first
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Log Python version and environment
logger.info(f"Python version: {sys.version}")
logger.info(f"Lambda environment: {os.environ.get('AWS_EXECUTION_ENV', 'unknown')}")

try:
    import boto3
    import urllib.parse
    logger.info("✅ Successfully imported boto3 and urllib")
except Exception as e:
    logger.error(f"❌ Failed to import base dependencies: {e}")
    raise

# AWS Clients
try:
    s3 = boto3.client('s3')
    sqs = boto3.client('sqs')
    dynamodb = boto3.resource('dynamodb')
    logger.info("✅ Successfully initialized AWS clients")
except Exception as e:
    logger.error(f"❌ Failed to initialize AWS clients: {e}")
    raise

# Environment variables
EMBEDDING_QUEUE_URL = os.environ.get('EMBEDDING_QUEUE_URL', '')
DOCUMENTS_TABLE = os.environ.get('DYNAMODB_DOCUMENTS_TABLE', 'rag-demo-documents')

logger.info(f"Environment variables: EMBEDDING_QUEUE_URL={EMBEDDING_QUEUE_URL}, DOCUMENTS_TABLE={DOCUMENTS_TABLE}")


def lambda_handler(event, context):
    """
    Main Lambda handler - chunks documents from S3 via SQS trigger
    Sends chunks to embedding queue for processing
    """
    try:
        logger.info(f"🚀 Lambda handler started")
        logger.info(f"Received event: {json.dumps(event)}")
        logger.info(f"Context: {context}")

        processed_count = 0
        error_count = 0

        records = event.get('Records', [])
        logger.info(f"Processing {len(records)} SQS records")

        if not records:
            logger.warning("⚠️ No records in event!")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No records to process'})
            }

        for record in records:
            try:
                logger.info(f"Processing record: {json.dumps(record)}")

                # Parse SQS message body (contains S3 event)
                body = json.loads(record['body'])
                logger.info(f"Parsed SQS body: {json.dumps(body)}")

                for s3_record in body.get('Records', []):
                    bucket = s3_record['s3']['bucket']['name']
                    key = urllib.parse.unquote_plus(s3_record['s3']['object']['key'])

                    logger.info(f"Processing document: s3://{bucket}/{key}")

                    # Process the document
                    result = process_document(bucket, key)

                    if result['success']:
                        processed_count += 1
                        logger.info(f"✅ Successfully chunked: {key} into {result['chunks']} chunks")
                    else:
                        error_count += 1
                        logger.error(f"❌ Failed to process: {key} - {result['error']}")

            except Exception as e:
                error_count += 1
                logger.error(f"❌ Error processing record: {str(e)}", exc_info=True)

        logger.info(f"Processing complete: {processed_count} successful, {error_count} errors")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'processed': processed_count,
                'errors': error_count
            })
        }

    except Exception as e:
        logger.error(f"❌ FATAL ERROR in lambda_handler: {str(e)}", exc_info=True)
        raise


def process_document(bucket: str, key: str) -> dict:
    """
    Process a single document from S3 using LangChain loaders and splitters

    Steps:
    1. Download file from S3 to temp location
    2. Load document using PyPDFLoader or text loader
    3. Split using RecursiveCharacterTextSplitter (tiktoken encoding)
    4. Send chunks to embedding queue
    5. Update document metadata in DynamoDB
    """
    import tempfile

    try:
        # Download file from S3 to temp location
        with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(key)[1]) as tmp_file:
            s3.download_fileobj(bucket, key, tmp_file)
            tmp_path = tmp_file.name

        # Get file size
        file_size = os.path.getsize(tmp_path)

        # Load document using LangChain loaders
        documents = load_document(tmp_path, key)

        # Chunk using RecursiveCharacterTextSplitter with tiktoken (as per notebook)
        chunks = chunk_documents(documents)
        logger.info(f"Created {len(chunks)} chunks from {key}")

        # Generate document ID
        document_id = generate_document_id(bucket, key)

        # Save initial document metadata
        save_document_metadata(
            document_id=document_id,
            key=key,
            bucket=bucket,
            chunk_count=len(chunks),
            file_size=file_size,
            status='chunked'
        )

        # Send chunks to embedding queue
        send_chunks_to_queue(document_id, key, chunks)

        # Cleanup temp file
        os.unlink(tmp_path)

        return {'success': True, 'chunks': len(chunks), 'document_id': document_id}

    except Exception as e:
        logger.error(f"Error processing document {key}: {str(e)}")
        return {'success': False, 'error': str(e)}


def load_document(file_path: str, key: str) -> list:
    """
    Load document using LangChain loaders (PyPDFLoader for PDF, TextLoader for txt)
    Based on notebook: PyPDFDirectoryLoader / PyPDFLoader
    """
    from langchain_community.document_loaders import PyPDFLoader, TextLoader

    if key.endswith('.pdf'):
        loader = PyPDFLoader(file_path)
        documents = loader.load()
    elif key.endswith('.txt'):
        loader = TextLoader(file_path, encoding='utf-8')
        documents = loader.load()
    else:
        raise ValueError(f"Unsupported file type: {key}")

    logger.info(f"Loaded {len(documents)} pages/documents from {key}")
    return documents


def chunk_documents(documents: list) -> list:
    """
    Split documents using RecursiveCharacterTextSplitter with tiktoken encoding

    Based on notebook:
    text_splitter = RecursiveCharacterTextSplitter.from_tiktoken_encoder(
        encoding_name='cl100k_base',
        chunk_size=1000,
        chunk_overlap=200
    )
    """
    from langchain.text_splitter import RecursiveCharacterTextSplitter

    # Create text splitter using tiktoken encoding (same as notebook)
    text_splitter = RecursiveCharacterTextSplitter.from_tiktoken_encoder(
        encoding_name='cl100k_base',  # GPT-4 / text-embedding-ada-002 encoding
        chunk_size=1000,              # Same as notebook
        chunk_overlap=200             # Same as notebook
    )

    # Split documents into chunks
    chunks = text_splitter.split_documents(documents)

    # Convert to serializable format with metadata
    chunk_list = []
    for i, chunk in enumerate(chunks):
        chunk_list.append({
            'index': i,
            'text': chunk.page_content,
            'metadata': {
                'source': chunk.metadata.get('source', ''),
                'page': chunk.metadata.get('page', 0)
            }
        })

    return chunk_list


def generate_document_id(bucket: str, key: str) -> str:
    """Generate a unique document ID"""
    import hashlib
    import time

    unique_string = f"{bucket}/{key}/{time.time()}"
    return hashlib.sha256(unique_string.encode()).hexdigest()[:16]


def send_chunks_to_queue(document_id: str, document_key: str, chunks: list):
    """Send chunks to the embedding queue in batches"""
    if not EMBEDDING_QUEUE_URL:
        logger.warning("EMBEDDING_QUEUE_URL not set, skipping queue")
        return

    # Send in batches (SQS batch limit is 10)
    batch_size = 10
    for i in range(0, len(chunks), batch_size):
        batch = chunks[i:i + batch_size]

        entries = []
        for j, chunk in enumerate(batch):
            entries.append({
                'Id': str(i + j),
                'MessageBody': json.dumps({
                    'document_id': document_id,
                    'document_key': document_key,
                    'chunk': chunk
                })
            })

        try:
            response = sqs.send_message_batch(
                QueueUrl=EMBEDDING_QUEUE_URL,
                Entries=entries
            )

            failed = response.get('Failed', [])
            if failed:
                logger.error(f"Failed to send {len(failed)} messages to queue")

        except Exception as e:
            logger.error(f"Error sending to queue: {str(e)}")
            raise

    logger.info(f"Sent {len(chunks)} chunks to embedding queue for document {document_id}")


def save_document_metadata(document_id: str, key: str, bucket: str,
                          chunk_count: int, file_size: int, status: str):
    """Save document metadata to DynamoDB"""
    try:
        table = dynamodb.Table(DOCUMENTS_TABLE)
        import time

        table.put_item(Item={
            'document_id': document_id,
            'document_key': key,
            'bucket': bucket,
            'chunk_count': chunk_count,
            'chunks_embedded': 0,
            'file_size': file_size,
            'status': status,
            'created_at': int(time.time()),
            'updated_at': int(time.time())
        })

        logger.info(f"Saved metadata for document {document_id}")

    except Exception as e:
        logger.error(f"Error saving document metadata: {str(e)}")
        raise
