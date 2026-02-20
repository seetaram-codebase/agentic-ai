#!/usr/bin/env python3
"""
Quick Pinecone Setup Script for RAG Demo
Helps you create and configure Pinecone index
"""

import os
import sys

try:
    from pinecone import Pinecone, ServerlessSpec
except ImportError:
    print("❌ Pinecone client not installed!")
    print("Install it with: pip install pinecone-client")
    sys.exit(1)


def setup_pinecone():
    """Interactive Pinecone setup"""

    print("=" * 60)
    print("🚀 Pinecone Setup for RAG Demo")
    print("=" * 60)
    print()

    # Get API key
    api_key = os.getenv("PINECONE_API_KEY")
    if not api_key:
        print("ℹ️  PINECONE_API_KEY not found in environment")
        api_key = input("Enter your Pinecone API key: ").strip()

        if not api_key:
            print("❌ API key is required!")
            sys.exit(1)
    else:
        print(f"✅ Using API key from environment: {api_key[:10]}...")

    # Initialize Pinecone
    try:
        pc = Pinecone(api_key=api_key)
        print("✅ Connected to Pinecone successfully!")
    except Exception as e:
        print(f"❌ Failed to connect to Pinecone: {e}")
        sys.exit(1)

    print()

    # List existing indexes
    try:
        indexes = pc.list_indexes()
        if indexes:
            print("📋 Existing indexes:")
            for idx in indexes:
                print(f"   - {idx['name']}")
        else:
            print("📋 No existing indexes found")
    except Exception as e:
        print(f"⚠️  Could not list indexes: {e}")

    print()

    # Ask about index creation
    index_name = input("Index name (default: rag-demo): ").strip() or "rag-demo"

    # Check if index already exists
    existing_indexes = [idx['name'] for idx in pc.list_indexes()]
    if index_name in existing_indexes:
        print(f"ℹ️  Index '{index_name}' already exists")
        recreate = input("Recreate it? (yes/no): ").strip().lower()

        if recreate == 'yes':
            print(f"🗑️  Deleting existing index '{index_name}'...")
            try:
                pc.delete_index(index_name)
                print("✅ Index deleted")
                import time
                time.sleep(5)  # Wait for deletion to complete
            except Exception as e:
                print(f"❌ Failed to delete index: {e}")
                sys.exit(1)
        else:
            print("✅ Using existing index")
            return

    # Get configuration
    print()
    print("📝 Index Configuration:")
    print("   Embedding models and their dimensions:")
    print("   - OpenAI text-embedding-3-small: 1536")
    print("   - OpenAI text-embedding-3-large: 3072")
    print("   - Azure OpenAI ada-002: 1536")
    print()

    dimension = input("Dimension (default: 1536): ").strip()
    dimension = int(dimension) if dimension else 1536

    metric = input("Metric (cosine/euclidean/dotproduct, default: cosine): ").strip() or "cosine"

    cloud = input("Cloud provider (aws/gcp/azure, default: aws): ").strip() or "aws"

    region = input("Region (default: us-east-1): ").strip() or "us-east-1"

    print()
    print("Creating index with:")
    print(f"   Name: {index_name}")
    print(f"   Dimensions: {dimension}")
    print(f"   Metric: {metric}")
    print(f"   Cloud: {cloud}")
    print(f"   Region: {region}")
    print()

    confirm = input("Proceed? (yes/no): ").strip().lower()

    if confirm != 'yes':
        print("❌ Cancelled")
        sys.exit(0)

    # Create index
    try:
        print("🔨 Creating index...")
        pc.create_index(
            name=index_name,
            dimension=dimension,
            metric=metric,
            spec=ServerlessSpec(
                cloud=cloud,
                region=region
            )
        )
        print("✅ Index created successfully!")
    except Exception as e:
        print(f"❌ Failed to create index: {e}")
        sys.exit(1)

    # Wait for index to be ready
    print("⏳ Waiting for index to be ready...")
    import time
    max_wait = 60
    waited = 0

    while waited < max_wait:
        try:
            index = pc.Index(index_name)
            stats = index.describe_index_stats()
            print("✅ Index is ready!")
            print(f"   Dimension: {stats.get('dimension')}")
            print(f"   Total vectors: {stats.get('total_vector_count', 0)}")
            break
        except Exception:
            time.sleep(5)
            waited += 5
            print(f"   Still waiting... ({waited}s)")

    if waited >= max_wait:
        print("⚠️  Index creation timeout, but it may still be initializing")

    print()
    print("=" * 60)
    print("✅ Pinecone Setup Complete!")
    print("=" * 60)
    print()
    print("📝 Next Steps:")
    print()
    print("1. Save your API key to AWS SSM Parameter Store:")
    print(f"   aws ssm put-parameter \\")
    print(f"     --name '/rag-demo/pinecone-api-key' \\")
    print(f"     --value '{api_key}' \\")
    print(f"     --type 'SecureString' \\")
    print(f"     --region us-east-1")
    print()
    print("2. Add to GitHub Secrets:")
    print(f"   Repository → Settings → Secrets → New secret")
    print(f"   Name: PINECONE_API_KEY")
    print(f"   Value: {api_key}")
    print()
    print("3. Update Lambda environment variables:")
    print(f"   PINECONE_API_KEY={api_key}")
    print(f"   PINECONE_INDEX={index_name}")
    print()
    print("4. Deploy the embedder Lambda with updated configuration")
    print()


if __name__ == "__main__":
    try:
        setup_pinecone()
    except KeyboardInterrupt:
        print("\n\n❌ Cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

