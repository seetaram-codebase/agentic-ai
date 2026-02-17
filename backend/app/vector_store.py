"""
Vector Store Implementation - Chroma (Local) and Pinecone (Cloud)
"""
import os
import uuid
import logging
from typing import List, Dict, Any, Optional
from abc import ABC, abstractmethod

logger = logging.getLogger(__name__)


class VectorStore(ABC):
    """Abstract base class for vector stores"""

    @abstractmethod
    def add_documents(
        self,
        texts: List[str],
        embeddings: List[List[float]],
        metadatas: List[Dict[str, Any]],
        ids: Optional[List[str]] = None
    ) -> List[str]:
        """Add documents to the vector store"""
        pass

    @abstractmethod
    def query(
        self,
        query_embedding: List[float],
        n_results: int = 5
    ) -> Dict[str, Any]:
        """Query the vector store for similar documents"""
        pass

    @abstractmethod
    def get_stats(self) -> Dict[str, Any]:
        """Get statistics about the vector store"""
        pass

    @abstractmethod
    def delete_collection(self) -> bool:
        """Delete all documents in the collection"""
        pass


class ChromaVectorStore(VectorStore):
    """Local Chroma vector store implementation"""

    def __init__(self, persist_dir: str = "./chroma_db", collection_name: str = "documents"):
        import chromadb
        from chromadb.config import Settings

        self.persist_dir = persist_dir
        self.collection_name = collection_name

        # Create persistent client
        self.client = chromadb.PersistentClient(
            path=persist_dir,
            settings=Settings(anonymized_telemetry=False)
        )

        # Get or create collection
        self.collection = self.client.get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"}
        )

        logger.info(f"Initialized Chroma vector store at {persist_dir}")

    def add_documents(
        self,
        texts: List[str],
        embeddings: List[List[float]],
        metadatas: List[Dict[str, Any]],
        ids: Optional[List[str]] = None
    ) -> List[str]:
        """Add documents to Chroma"""
        if ids is None:
            ids = [str(uuid.uuid4()) for _ in texts]

        self.collection.add(
            documents=texts,
            embeddings=embeddings,
            metadatas=metadatas,
            ids=ids
        )

        logger.info(f"Added {len(texts)} documents to Chroma")
        return ids

    def query(
        self,
        query_embedding: List[float],
        n_results: int = 5
    ) -> Dict[str, Any]:
        """Query Chroma for similar documents"""
        results = self.collection.query(
            query_embeddings=[query_embedding],
            n_results=n_results,
            include=["documents", "metadatas", "distances"]
        )

        # Format results
        formatted = {
            "documents": results.get("documents", [[]])[0],
            "metadatas": results.get("metadatas", [[]])[0],
            "distances": results.get("distances", [[]])[0],
            "ids": results.get("ids", [[]])[0]
        }

        return formatted

    def get_stats(self) -> Dict[str, Any]:
        """Get Chroma collection statistics"""
        count = self.collection.count()
        return {
            "type": "chroma",
            "persist_dir": self.persist_dir,
            "collection_name": self.collection_name,
            "document_count": count
        }

    def delete_collection(self) -> bool:
        """Delete the collection"""
        try:
            self.client.delete_collection(self.collection_name)
            self.collection = self.client.get_or_create_collection(
                name=self.collection_name,
                metadata={"hnsw:space": "cosine"}
            )
            logger.info(f"Deleted and recreated collection: {self.collection_name}")
            return True
        except Exception as e:
            logger.error(f"Error deleting collection: {e}")
            return False


class PineconeVectorStore(VectorStore):
    """Pinecone cloud vector store implementation"""

    def __init__(
        self,
        api_key: str,
        index_name: str = "rag-demo",
        dimension: int = 1536
    ):
        from pinecone import Pinecone, ServerlessSpec

        self.index_name = index_name
        self.dimension = dimension

        # Initialize Pinecone
        self.pc = Pinecone(api_key=api_key)

        # Create index if not exists
        existing_indexes = [idx.name for idx in self.pc.list_indexes()]
        if index_name not in existing_indexes:
            self.pc.create_index(
                name=index_name,
                dimension=dimension,
                metric="cosine",
                spec=ServerlessSpec(cloud="aws", region="us-east-1")
            )
            logger.info(f"Created Pinecone index: {index_name}")

        self.index = self.pc.Index(index_name)
        logger.info(f"Connected to Pinecone index: {index_name}")

    def add_documents(
        self,
        texts: List[str],
        embeddings: List[List[float]],
        metadatas: List[Dict[str, Any]],
        ids: Optional[List[str]] = None
    ) -> List[str]:
        """Add documents to Pinecone"""
        if ids is None:
            ids = [str(uuid.uuid4()) for _ in texts]

        # Prepare vectors with metadata including text
        vectors = []
        for i, (id_, text, embedding, metadata) in enumerate(zip(ids, texts, embeddings, metadatas)):
            vectors.append({
                "id": id_,
                "values": embedding,
                "metadata": {**metadata, "text": text}
            })

        # Upsert in batches of 100
        batch_size = 100
        for i in range(0, len(vectors), batch_size):
            batch = vectors[i:i + batch_size]
            self.index.upsert(vectors=batch)

        logger.info(f"Added {len(texts)} documents to Pinecone")
        return ids

    def query(
        self,
        query_embedding: List[float],
        n_results: int = 5
    ) -> Dict[str, Any]:
        """Query Pinecone for similar documents"""
        results = self.index.query(
            vector=query_embedding,
            top_k=n_results,
            include_metadata=True
        )

        # Format results to match Chroma format
        documents = []
        metadatas = []
        distances = []
        ids = []

        for match in results.get("matches", []):
            metadata = match.get("metadata", {})
            documents.append(metadata.pop("text", ""))
            metadatas.append(metadata)
            distances.append(1 - match.get("score", 0))  # Convert similarity to distance
            ids.append(match.get("id", ""))

        return {
            "documents": documents,
            "metadatas": metadatas,
            "distances": distances,
            "ids": ids
        }

    def get_stats(self) -> Dict[str, Any]:
        """Get Pinecone index statistics"""
        stats = self.index.describe_index_stats()
        return {
            "type": "pinecone",
            "index_name": self.index_name,
            "document_count": stats.get("total_vector_count", 0),
            "dimension": self.dimension
        }

    def delete_collection(self) -> bool:
        """Delete all vectors in the index"""
        try:
            self.index.delete(delete_all=True)
            logger.info(f"Deleted all vectors in Pinecone index: {self.index_name}")
            return True
        except Exception as e:
            logger.error(f"Error deleting Pinecone vectors: {e}")
            return False


# Singleton instance
_vector_store: Optional[VectorStore] = None


def get_vector_store() -> VectorStore:
    """Get or create the singleton vector store"""
    global _vector_store

    if _vector_store is None:
        use_pinecone = os.getenv("USE_PINECONE", "false").lower() == "true"

        if use_pinecone:
            api_key = os.getenv("PINECONE_API_KEY")
            if not api_key:
                raise ValueError("PINECONE_API_KEY environment variable not set")

            _vector_store = PineconeVectorStore(
                api_key=api_key,
                index_name=os.getenv("PINECONE_INDEX", "rag-demo")
            )
        else:
            _vector_store = ChromaVectorStore(
                persist_dir=os.getenv("CHROMA_PERSIST_DIR", "./chroma_db")
            )

    return _vector_store
