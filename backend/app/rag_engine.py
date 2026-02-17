"""
RAG Engine - Document Processing and Query Handling
"""
import os
import uuid
import logging
from typing import List, Dict, Any, Tuple
from dataclasses import dataclass

from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.document_loaders import PyPDFLoader, TextLoader

from .azure_openai import get_azure_client
from .vector_store import get_vector_store

logger = logging.getLogger(__name__)


@dataclass
class DocumentChunk:
    """Represents a chunk of a document"""
    text: str
    metadata: Dict[str, Any]
    embedding: List[float] = None


@dataclass
class QueryResult:
    """Result from a RAG query"""
    response: str
    sources: List[Dict[str, Any]]
    provider: str


class RAGEngine:
    """
    RAG Engine for document ingestion and querying.

    Features:
    - PDF and text file processing
    - Document chunking with overlap
    - Embedding generation via Azure OpenAI
    - Vector storage in Chroma/Pinecone
    - Context-aware response generation
    """

    def __init__(
        self,
        chunk_size: int = 1000,
        chunk_overlap: int = 200
    ):
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap

        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=chunk_size,
            chunk_overlap=chunk_overlap,
            length_function=len,
            separators=["\n\n", "\n", " ", ""]
        )

        self.azure_client = get_azure_client()
        self.vector_store = get_vector_store()

        logger.info("RAG Engine initialized")

    def process_file(self, file_path: str, filename: str) -> Dict[str, Any]:
        """
        Process a file and add it to the vector store.

        Args:
            file_path: Path to the uploaded file
            filename: Original filename

        Returns:
            Processing result with statistics
        """
        logger.info(f"Processing file: {filename}")

        # Load document based on file type
        if filename.lower().endswith('.pdf'):
            loader = PyPDFLoader(file_path)
        elif filename.lower().endswith('.txt'):
            loader = TextLoader(file_path, encoding='utf-8')
        else:
            raise ValueError(f"Unsupported file type: {filename}")

        # Load and split documents
        documents = loader.load()
        chunks = self.text_splitter.split_documents(documents)

        logger.info(f"Split {filename} into {len(chunks)} chunks")

        # Extract texts and metadata
        texts = [chunk.page_content for chunk in chunks]
        metadatas = [
            {
                "source": filename,
                "page": chunk.metadata.get("page", 0),
                "chunk_index": i
            }
            for i, chunk in enumerate(chunks)
        ]

        # Generate embeddings
        embeddings, provider = self.azure_client.generate_embeddings(texts)

        # Generate unique IDs
        doc_id = str(uuid.uuid4())[:8]
        ids = [f"{doc_id}_{i}" for i in range(len(texts))]

        # Store in vector database
        self.vector_store.add_documents(
            texts=texts,
            embeddings=embeddings,
            metadatas=metadatas,
            ids=ids
        )

        result = {
            "filename": filename,
            "chunks_created": len(chunks),
            "document_id": doc_id,
            "provider": provider,
            "status": "success"
        }

        logger.info(f"Successfully processed {filename}: {len(chunks)} chunks")
        return result

    def query(
        self,
        question: str,
        n_results: int = 5,
        include_sources: bool = True
    ) -> QueryResult:
        """
        Query the RAG system with a question.

        Args:
            question: User's question
            n_results: Number of context chunks to retrieve
            include_sources: Whether to include source references

        Returns:
            QueryResult with response and sources
        """
        logger.info(f"Processing query: {question[:50]}...")

        # Generate query embedding
        query_embeddings, embed_provider = self.azure_client.generate_embeddings([question])
        query_embedding = query_embeddings[0]

        # Retrieve relevant documents
        results = self.vector_store.query(
            query_embedding=query_embedding,
            n_results=n_results
        )

        documents = results.get("documents", [])
        metadatas = results.get("metadatas", [])

        if not documents:
            return QueryResult(
                response="I couldn't find any relevant information in the uploaded documents. Please upload some documents first.",
                sources=[],
                provider=embed_provider
            )

        # Build context from retrieved documents
        context_parts = []
        for i, (doc, meta) in enumerate(zip(documents, metadatas)):
            source = meta.get("source", "Unknown")
            page = meta.get("page", 0)
            context_parts.append(f"[Source: {source}, Page {page + 1}]\n{doc}")

        context = "\n\n---\n\n".join(context_parts)

        # Build prompt
        system_prompt = """You are a helpful assistant that answers questions based on the provided context. 
Use the context to answer the user's question accurately. 
If the context doesn't contain relevant information, say so.
Always cite the sources when providing information."""

        user_prompt = f"""Context from documents:
{context}

---

Question: {question}

Please provide a comprehensive answer based on the context above. Include source references."""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ]

        # Generate response
        response_text, chat_provider = self.azure_client.chat_completion(
            messages=messages,
            temperature=0.7,
            max_tokens=1000
        )

        # Format sources
        sources = []
        if include_sources:
            seen_sources = set()
            for meta in metadatas:
                source_key = f"{meta.get('source', 'Unknown')}_{meta.get('page', 0)}"
                if source_key not in seen_sources:
                    sources.append({
                        "source": meta.get("source", "Unknown"),
                        "page": meta.get("page", 0) + 1
                    })
                    seen_sources.add(source_key)

        return QueryResult(
            response=response_text,
            sources=sources,
            provider=chat_provider
        )

    def get_stats(self) -> Dict[str, Any]:
        """Get statistics about the RAG system"""
        vector_stats = self.vector_store.get_stats()
        azure_status = self.azure_client.get_status()

        return {
            "vector_store": vector_stats,
            "azure_openai": azure_status
        }

    def clear_documents(self) -> bool:
        """Clear all documents from the vector store"""
        return self.vector_store.delete_collection()


# Singleton instance
_rag_engine = None


def get_rag_engine() -> RAGEngine:
    """Get or create the singleton RAG engine"""
    global _rag_engine
    if _rag_engine is None:
        _rag_engine = RAGEngine()
    return _rag_engine
