# Phase 3: Vector Database Setup

## 🎯 Goal
Set up vector storage for document embeddings with Chroma (local/MVP) and Pinecone (cloud/production).

## Option A: Chroma (Local - MVP)

### Pros
- Free, runs locally
- No API keys needed
- Great for development

### Cons
- Not scalable
- Data lost if not persisted

### Implementation

```python
# backend/app/vector_store.py
import chromadb
from chromadb.config import Settings

class ChromaVectorStore:
    def __init__(self, persist_dir="./chroma_db"):
        self.client = chromadb.PersistentClient(path=persist_dir)
        self.collection = self.client.get_or_create_collection(
            name="documents",
            metadata={"hnsw:space": "cosine"}
        )
    
    def add_documents(self, texts: list, embeddings: list, metadatas: list, ids: list):
        self.collection.add(
            documents=texts,
            embeddings=embeddings,
            metadatas=metadatas,
            ids=ids
        )
    
    def query(self, query_embedding: list, n_results: int = 5):
        results = self.collection.query(
            query_embeddings=[query_embedding],
            n_results=n_results
        )
        return results
    
    def get_document_count(self):
        return self.collection.count()
```

## Option B: Pinecone (Cloud - Production)

### Pros
- Fully managed, scalable
- Free tier available (100K vectors)
- Production-ready

### Cons
- Requires API key
- Network latency

### Implementation

```python
# backend/app/vector_store_pinecone.py
from pinecone import Pinecone, ServerlessSpec

class PineconeVectorStore:
    def __init__(self, api_key: str, index_name: str = "rag-demo"):
        self.pc = Pinecone(api_key=api_key)
        
        # Create index if not exists
        if index_name not in self.pc.list_indexes().names():
            self.pc.create_index(
                name=index_name,
                dimension=1536,  # OpenAI embedding dimension
                metric="cosine",
                spec=ServerlessSpec(cloud="aws", region="us-east-1")
            )
        
        self.index = self.pc.Index(index_name)
    
    def add_documents(self, texts: list, embeddings: list, metadatas: list, ids: list):
        vectors = [
            {
                "id": id,
                "values": embedding,
                "metadata": {**metadata, "text": text}
            }
            for id, text, embedding, metadata in zip(ids, texts, embeddings, metadatas)
        ]
        self.index.upsert(vectors=vectors)
    
    def query(self, query_embedding: list, n_results: int = 5):
        results = self.index.query(
            vector=query_embedding,
            top_k=n_results,
            include_metadata=True
        )
        return results
    
    def get_stats(self):
        return self.index.describe_index_stats()
```

## Unified Interface

```python
# backend/app/vector_store.py
from abc import ABC, abstractmethod
import os

class VectorStore(ABC):
    @abstractmethod
    def add_documents(self, texts, embeddings, metadatas, ids): pass
    
    @abstractmethod
    def query(self, query_embedding, n_results): pass

def get_vector_store() -> VectorStore:
    """Factory function to get configured vector store"""
    use_pinecone = os.getenv("USE_PINECONE", "false").lower() == "true"
    
    if use_pinecone:
        from .vector_store_pinecone import PineconeVectorStore
        return PineconeVectorStore(
            api_key=os.getenv("PINECONE_API_KEY"),
            index_name=os.getenv("PINECONE_INDEX", "rag-demo")
        )
    else:
        from .vector_store_chroma import ChromaVectorStore
        return ChromaVectorStore(
            persist_dir=os.getenv("CHROMA_PERSIST_DIR", "./chroma_db")
        )
```

## Embedding Generation

```python
# backend/app/embeddings.py
from openai import AzureOpenAI
import os

class EmbeddingGenerator:
    def __init__(self):
        self.client = AzureOpenAI(
            azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT_1"),
            api_key=os.getenv("AZURE_OPENAI_KEY_1"),
            api_version="2024-02-01"
        )
        self.model = "text-embedding-ada-002"
    
    def generate(self, texts: list[str]) -> list[list[float]]:
        response = self.client.embeddings.create(
            input=texts,
            model=self.model
        )
        return [item.embedding for item in response.data]
    
    def generate_single(self, text: str) -> list[float]:
        return self.generate([text])[0]
```

## ✅ Phase 3 Checklist

- [ ] Chroma local setup working
- [ ] Pinecone account created (free tier)
- [ ] Pinecone index created
- [ ] Embedding generation working
- [ ] Documents can be stored and queried
- [ ] Switch between Chroma/Pinecone via env var
