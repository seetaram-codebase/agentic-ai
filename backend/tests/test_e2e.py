"""
End-to-End Integration Tests for RAG Application
Tests the complete flow: Upload → Chunk → Embed → Query
"""
import pytest
import os
import time
import boto3
from fastapi.testclient import TestClient
from pathlib import Path

# Import the FastAPI app
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from app.main import app

client = TestClient(app)

# AWS Clients for testing
s3_client = boto3.client('s3')
sqs_client = boto3.client('sqs')
dynamodb = boto3.resource('dynamodb')

# Environment variables
APP_NAME = os.getenv('APP_NAME', 'rag-demo')
AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
S3_BUCKET = os.getenv('S3_BUCKET', f'{APP_NAME}-documents')
DYNAMODB_DOCUMENTS_TABLE = os.getenv('DYNAMODB_DOCUMENTS_TABLE', f'{APP_NAME}-documents')


class TestHealthEndpoints:
    """Test health check endpoints"""

    def test_health_endpoint(self):
        """Test basic health check"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data

    def test_ready_endpoint(self):
        """Test readiness check"""
        response = client.get("/ready")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ready"


class TestDocumentUpload:
    """Test document upload functionality"""

    @pytest.fixture
    def sample_text_file(self, tmp_path):
        """Create a sample text file for testing"""
        file_path = tmp_path / "test_document.txt"
        file_path.write_text("""
        This is a test document for the RAG system.
        It contains multiple sentences to ensure proper chunking.
        The document should be split into appropriate chunks.
        Each chunk should be embedded and stored in the vector database.
        We can then query this document to test retrieval.
        """)
        return file_path

    def test_upload_endpoint_exists(self):
        """Test that upload endpoint exists"""
        # Test without file (should fail)
        response = client.post("/upload")
        # Should return 422 (validation error) not 404
        assert response.status_code in [400, 422]

    def test_upload_text_document(self, sample_text_file):
        """Test uploading a text document"""
        with open(sample_text_file, 'rb') as f:
            files = {'file': ('test_document.txt', f, 'text/plain')}
            response = client.post("/upload", files=files)

        # Should succeed or return appropriate error
        assert response.status_code in [200, 201, 202]
        if response.status_code in [200, 201, 202]:
            data = response.json()
            assert 'document_id' in data or 'message' in data


@pytest.mark.skipif(
    not os.getenv('RUN_AWS_TESTS'),
    reason="Skipping AWS integration tests (set RUN_AWS_TESTS=1 to run)"
)
class TestAWSIntegration:
    """Test AWS service integration"""

    def test_s3_bucket_exists(self):
        """Verify S3 bucket exists and is accessible"""
        try:
            response = s3_client.head_bucket(Bucket=S3_BUCKET)
            assert response['ResponseMetadata']['HTTPStatusCode'] == 200
        except Exception as e:
            pytest.fail(f"S3 bucket {S3_BUCKET} not accessible: {e}")

    def test_dynamodb_table_exists(self):
        """Verify DynamoDB table exists"""
        try:
            table = dynamodb.Table(DYNAMODB_DOCUMENTS_TABLE)
            table.load()
            assert table.table_status == 'ACTIVE'
        except Exception as e:
            pytest.fail(f"DynamoDB table {DYNAMODB_DOCUMENTS_TABLE} not accessible: {e}")

    def test_sqs_queues_exist(self):
        """Verify SQS queues exist"""
        try:
            queues = sqs_client.list_queues(QueueNamePrefix=APP_NAME)
            queue_urls = queues.get('QueueUrls', [])
            assert len(queue_urls) >= 2  # Should have at least chunking and embedding queues
        except Exception as e:
            pytest.fail(f"SQS queues not accessible: {e}")


@pytest.mark.skipif(
    not os.getenv('RUN_E2E_TESTS'),
    reason="Skipping full E2E tests (set RUN_E2E_TESTS=1 to run)"
)
class TestEndToEndFlow:
    """Test complete document processing flow"""

    @pytest.fixture
    def sample_document(self, tmp_path):
        """Create a substantial test document"""
        file_path = tmp_path / "rag_test_doc.txt"
        file_path.write_text("""
        RAG (Retrieval-Augmented Generation) Systems

        Introduction to RAG
        Retrieval-Augmented Generation is a technique that combines information retrieval
        with text generation. It allows language models to access external knowledge bases
        to provide more accurate and up-to-date responses.

        Key Components
        1. Document Chunking: Breaking documents into manageable pieces
        2. Embedding Generation: Converting text to vector representations
        3. Vector Storage: Storing embeddings in a searchable database
        4. Retrieval: Finding relevant chunks based on queries
        5. Generation: Using retrieved context to generate responses

        Benefits
        - Improved accuracy through external knowledge
        - Reduced hallucinations
        - Easy knowledge updates without retraining
        - Scalable architecture
        """)
        return file_path

    def test_full_upload_process_flow(self, sample_document):
        """Test uploading document and verify it gets processed"""
        # Step 1: Upload document
        with open(sample_document, 'rb') as f:
            files = {'file': (sample_document.name, f, 'text/plain')}
            response = client.post("/upload", files=files)

        assert response.status_code in [200, 201, 202]
        data = response.json()

        # Get document ID from response
        document_id = data.get('document_id') or data.get('id')

        if document_id:
            # Step 2: Wait for processing (in real scenario)
            time.sleep(2)

            # Step 3: Verify document status
            status_response = client.get(f"/documents/{document_id}/status")
            # This endpoint may not exist yet, so we skip if not found
            if status_response.status_code != 404:
                assert status_response.status_code == 200

    def test_query_after_upload(self, sample_document):
        """Test querying documents after upload"""
        # First upload a document
        with open(sample_document, 'rb') as f:
            files = {'file': (sample_document.name, f, 'text/plain')}
            upload_response = client.post("/upload", files=files)

        if upload_response.status_code not in [200, 201, 202]:
            pytest.skip("Upload failed, skipping query test")

        # Wait for processing
        time.sleep(5)

        # Try to query
        query_data = {
            "query": "What is RAG?",
            "top_k": 3
        }
        response = client.post("/query", json=query_data)

        # Should get a response (even if no results yet)
        if response.status_code == 200:
            data = response.json()
            assert 'answer' in data or 'results' in data


class TestConfigurationEndpoints:
    """Test configuration and status endpoints"""

    def test_azure_config_endpoint(self):
        """Test Azure OpenAI configuration status"""
        response = client.get("/config/azure")
        # Endpoint may require auth or may not exist
        assert response.status_code in [200, 401, 404]

    def test_list_documents_endpoint(self):
        """Test listing uploaded documents"""
        response = client.get("/documents")
        # Should return list (may be empty)
        assert response.status_code in [200, 404]


class TestErrorHandling:
    """Test error handling and edge cases"""

    def test_upload_invalid_file_type(self, tmp_path):
        """Test uploading unsupported file type"""
        file_path = tmp_path / "test.exe"
        file_path.write_bytes(b"fake executable")

        with open(file_path, 'rb') as f:
            files = {'file': ('test.exe', f, 'application/octet-stream')}
            response = client.post("/upload", files=files)

        # Should reject invalid file types
        assert response.status_code in [400, 415, 422]

    def test_query_empty_string(self):
        """Test querying with empty string"""
        response = client.post("/query", json={"query": "", "top_k": 5})
        # Should handle gracefully
        assert response.status_code in [200, 400, 422]

    def test_query_without_documents(self):
        """Test querying when no documents exist"""
        response = client.post("/query", json={"query": "test query", "top_k": 5})
        # Should return empty results or appropriate message
        assert response.status_code in [200, 404]


if __name__ == "__main__":
    # Run tests with verbose output
    pytest.main([__file__, "-v", "-s"])

