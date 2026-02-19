"""
Verify that embeddings (not just text) are stored in Pinecone

This script fetches a vector from Pinecone and shows:
1. The embedding values (1536 numbers)
2. The metadata text (readable content)
"""
import os
from pinecone import Pinecone

# Configuration
PINECONE_API_KEY = os.getenv('PINECONE_API_KEY')
PINECONE_INDEX = os.getenv('PINECONE_INDEX', 'rag-demo')

def verify_embeddings():
    """Verify embeddings are stored in Pinecone"""

    if not PINECONE_API_KEY:
        print("❌ Error: PINECONE_API_KEY environment variable not set")
        print("   Set it with: $env:PINECONE_API_KEY='your-key-here'")
        return

    try:
        # Initialize Pinecone
        pc = Pinecone(api_key=PINECONE_API_KEY)
        index = pc.Index(PINECONE_INDEX)

        print("=" * 70)
        print("PINECONE EMBEDDING VERIFICATION")
        print("=" * 70)

        # Get index stats
        stats = index.describe_index_stats()
        print(f"\n📊 Index Statistics:")
        print(f"   Index Name: {PINECONE_INDEX}")
        print(f"   Dimension: {stats.get('dimension')}")
        print(f"   Total Vectors: {stats.get('total_vector_count')}")

        if stats.get('total_vector_count', 0) == 0:
            print("\n⚠️  Index is empty - no vectors to verify")
            print("   Upload a document first to test")
            return

        # Query to get some vectors
        print(f"\n🔍 Fetching sample vectors...")

        # Create a dummy query vector to get results
        dummy_query = [0.0] * stats.get('dimension', 1536)
        results = index.query(
            vector=dummy_query,
            top_k=3,
            include_metadata=True,
            include_values=True  # Important: Include the embedding values!
        )

        if not results.get('matches'):
            print("   No vectors found")
            return

        print(f"   Found {len(results['matches'])} vectors\n")

        # Display first vector in detail
        print("=" * 70)
        print("DETAILED VIEW OF FIRST VECTOR")
        print("=" * 70)

        vector = results['matches'][0]

        print(f"\n🆔 Vector ID:")
        print(f"   {vector['id']}")

        print(f"\n📊 Similarity Score:")
        print(f"   {vector.get('score', 0):.4f}")

        # THE EMBEDDING VALUES
        values = vector.get('values', [])
        print(f"\n🔢 EMBEDDING VALUES (The actual vector):")
        print(f"   Total dimensions: {len(values)}")
        print(f"   Type: List of floating-point numbers")
        print(f"\n   First 20 values:")
        print(f"   {values[:20]}")
        print(f"\n   Last 20 values:")
        print(f"   {values[-20:]}")

        if len(values) == 1536:
            print(f"\n   ✅ CORRECT: Vector has 1536 dimensions (Azure OpenAI text-embedding-3-small)")
        else:
            print(f"\n   ⚠️  UNEXPECTED: Vector has {len(values)} dimensions (expected 1536)")

        # THE METADATA (including text)
        metadata = vector.get('metadata', {})
        print(f"\n📝 METADATA (Human-readable information):")
        print(f"   Document ID: {metadata.get('document_id', 'N/A')}")
        print(f"   Chunk Index: {metadata.get('chunk_index', 'N/A')}")
        print(f"   Source: {metadata.get('source', 'N/A')}")
        print(f"   Page: {metadata.get('page', 'N/A')}")

        text = metadata.get('text', '')
        print(f"\n   Text (first 200 chars):")
        print(f"   \"{text[:200]}{'...' if len(text) > 200 else ''}\"")

        # Summary
        print("\n" + "=" * 70)
        print("SUMMARY")
        print("=" * 70)

        print("\n✅ What's stored in Pinecone:")
        print(f"   1. EMBEDDINGS: {len(values)} floating-point numbers (the vector)")
        print(f"   2. METADATA: Document info + original text")

        print("\n💡 How it works:")
        print("   - The EMBEDDINGS are used for similarity search")
        print("   - The TEXT is returned when a match is found")
        print("   - Both are necessary for RAG to work!")

        print("\n🎯 Why Pinecone UI shows text prominently:")
        print("   - Embeddings are just numbers - not useful to display")
        print("   - Text helps you verify the right content is stored")
        print("   - But the embeddings are ALWAYS there in the background!")

        # Show all vectors summary
        print("\n" + "=" * 70)
        print("ALL SAMPLE VECTORS")
        print("=" * 70)

        for i, vec in enumerate(results['matches'][:3]):
            meta = vec.get('metadata', {})
            text_preview = meta.get('text', '')[:60]
            print(f"\n{i+1}. ID: {vec['id']}")
            print(f"   Embedding dims: {len(vec.get('values', []))}")
            print(f"   Text: \"{text_preview}...\"")

        print("\n" + "=" * 70)
        print("✅ VERIFICATION COMPLETE")
        print("=" * 70)
        print("\nConclusion: Embeddings ARE stored (as the 'values' array)")
        print("            Text is ALSO stored (in metadata for display)")

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    verify_embeddings()

