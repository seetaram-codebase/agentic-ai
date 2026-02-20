"""
Quick test to verify backend is using Pinecone and can retrieve documents
"""
import requests
import json

# Backend URL - UPDATE THIS to your current backend IP
BACKEND_URL = "http://13.222.106.90:8000"

def test_stats():
    """Check which vector store the backend is using"""
    print("=" * 60)
    print("1. Checking Backend Vector Store Configuration")
    print("=" * 60)

    try:
        response = requests.get(f"{BACKEND_URL}/stats", timeout=10)
        response.raise_for_status()
        stats = response.json()

        print(f"\n✅ Backend is online\n")

        vector_store = stats.get("vector_store", {})
        print(f"Vector Store Type: {vector_store.get('type')}")

        if vector_store.get("type") == "pinecone":
            print(f"✅ Using Pinecone!")
            print(f"   Index Name: {vector_store.get('index_name')}")
            print(f"   Document Count: {vector_store.get('document_count')}")
            print(f"   Dimension: {vector_store.get('dimension')}")

            doc_count = vector_store.get('document_count', 0)
            if doc_count > 0:
                print(f"\n✅ Pinecone has {doc_count} vectors - ready for queries!")
                return True
            else:
                print(f"\n⚠️  Pinecone is empty - upload some documents first")
                return False
        else:
            print(f"❌ Using {vector_store.get('type')} instead of Pinecone!")
            print(f"   Document Count: {vector_store.get('document_count', 0)}")
            print(f"\n🔧 Fix: Set USE_PINECONE=true in ECS task definition")
            return False

    except requests.exceptions.RequestException as e:
        print(f"❌ Error connecting to backend: {e}")
        print(f"   Make sure backend URL is correct: {BACKEND_URL}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False


def test_query():
    """Test a sample query"""
    print("\n" + "=" * 60)
    print("2. Testing Query with RAG Context")
    print("=" * 60)

    query = "What is this about?"

    try:
        payload = {"question": query, "n_results": 5}
        response = requests.post(f"{BACKEND_URL}/query", json=payload, timeout=30)
        response.raise_for_status()
        result = response.json()

        print(f"\nQuery: {query}")
        print(f"\nResponse: {result.get('response', '')[:200]}...")
        print(f"\nSources: {len(result.get('sources', []))} documents found")

        if result.get('sources'):
            print("\nSource documents:")
            for i, source in enumerate(result.get('sources', [])[:3]):
                print(f"   {i+1}. {source.get('source')} (Page {source.get('page')})")
            print(f"\n✅ Query is retrieving context from YOUR documents!")
            return True
        else:
            print(f"\n⚠️  No sources found - query not using RAG context")
            print(f"   This means either:")
            print(f"   1. No documents uploaded yet")
            print(f"   2. Backend not querying Pinecone")
            return False

    except Exception as e:
        print(f"❌ Query failed: {e}")
        return False


def test_documents():
    """Check if documents are listed"""
    print("\n" + "=" * 60)
    print("3. Checking Uploaded Documents")
    print("=" * 60)

    try:
        response = requests.get(f"{BACKEND_URL}/documents", timeout=10)
        response.raise_for_status()
        docs = response.json()

        print(f"\nTotal documents: {len(docs)}")

        if docs:
            print("\nRecent documents:")
            for doc in docs[:5]:
                status = doc.get('status', 'unknown')
                chunk_count = doc.get('chunk_count', 0)
                doc_key = doc.get('document_key', '').split('/')[-1]
                print(f"   - {doc_key}: {status} ({chunk_count} chunks)")
            return True
        else:
            print("⚠️  No documents found in DynamoDB")
            print("   Upload a document via the UI to test end-to-end")
            return False

    except Exception as e:
        print(f"⚠️  Could not list documents: {e}")
        return False


if __name__ == "__main__":
    print("\n🔍 RAG Backend Diagnostics\n")
    print(f"Backend URL: {BACKEND_URL}\n")

    # Test 1: Check vector store type
    pinecone_ok = test_stats()

    # Test 2: Check documents
    test_documents()

    # Test 3: Test query only if Pinecone has data
    if pinecone_ok:
        test_query()
    else:
        print("\n⚠️  Skipping query test - Pinecone is empty or not configured")

    print("\n" + "=" * 60)
    print("Diagnostics Complete")
    print("=" * 60)

    if pinecone_ok:
        print("\n✅ Your RAG system is configured correctly!")
        print("   Embeddings are in Pinecone and backend can query them.")
    else:
        print("\n❌ Configuration issue detected")
        print("   Check the output above for details.")

