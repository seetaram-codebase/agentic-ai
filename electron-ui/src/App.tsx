import React, { useState, useEffect, useCallback } from 'react';
import { useDropzone } from 'react-dropzone';
import { api, HealthStatus, QueryResponse, UploadResponse, DocumentStatus } from './api/client';
import { Settings } from './components/Settings';

interface Source {
  source: string;
  page: number;
}

interface ProcessingDocument {
  documentId: string;
  filename: string;
  status: DocumentStatus | null;
}

function App() {
  // State
  const [question, setQuestion] = useState('');
  const [response, setResponse] = useState('');
  const [sources, setSources] = useState<Source[]>([]);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [status, setStatus] = useState<HealthStatus | null>(null);
  const [documentCount, setDocumentCount] = useState(0);
  const [uploadStatus, setUploadStatus] = useState<string>('');
  const [error, setError] = useState<string>('');
  const [processingDocs, setProcessingDocs] = useState<ProcessingDocument[]>([]);

  console.log('📱 App component rendered');

  // Fetch health status and stats on mount
  useEffect(() => {
    console.log('🔄 App mounted, initializing...');
    refreshStatus();
    refreshStats();
  }, []);

  const refreshStatus = async () => {
    try {
      console.log('🏥 Fetching backend health status...');
      const health = await api.getHealthStatus();
      console.log('✅ Backend health:', health);
      setStatus(health);
      setError('');
    } catch (e: any) {
      console.warn('⚠️ Cannot connect to backend:', e.message);
      setError('Backend offline - will retry. You can still use the UI.');
      setStatus(null);
    }
  };

  const refreshStats = async () => {
    try {
      console.log('📊 Fetching stats...');
      const stats = await api.getStats();
      console.log('✅ Stats:', stats);
      setDocumentCount(stats.vector_store?.document_count || 0);
    } catch (e) {
      console.warn('⚠️ Error fetching stats:', e);
    }
  };

  // Poll document status for documents still processing
  useEffect(() => {
    if (processingDocs.length === 0) return;

    const pollInterval = setInterval(async () => {
      const updatedDocs = await Promise.all(
        processingDocs.map(async (doc) => {
          try {
            const docStatus = await api.getDocumentStatus(doc.documentId);
            return { ...doc, status: docStatus };
          } catch (e) {
            console.warn(`⚠️ Error fetching status for ${doc.documentId}:`, e);
            return doc;
          }
        })
      );

      setProcessingDocs(updatedDocs);

      // Remove completed or errored documents after a delay
      const stillProcessing = updatedDocs.filter(
        doc => doc.status && !['completed', 'error'].includes(doc.status.status)
      );

      if (stillProcessing.length !== updatedDocs.length) {
        // Refresh stats when documents complete
        refreshStats();
      }

      setProcessingDocs(stillProcessing);
    }, 3000); // Poll every 3 seconds

    return () => clearInterval(pollInterval);
  }, [processingDocs]);

  // File upload handler
  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    setUploading(true);
    setUploadStatus('');
    setError('');

    try {
      const newProcessingDocs: ProcessingDocument[] = [];

      for (const file of acceptedFiles) {
        setUploadStatus(`Uploading ${file.name}...`);
        const result: UploadResponse = await api.uploadFile(file);
        setUploadStatus(`✅ ${file.name}: ${result.status} - ${result.message}`);
        console.log('📤 Upload response:', result);

        // Add to processing list for status tracking
        if (result.document_id) {
          newProcessingDocs.push({
            documentId: result.document_id,
            filename: file.name,
            status: null
          });
        }
      }

      // Add new documents to processing list
      setProcessingDocs(prev => [...prev, ...newProcessingDocs]);

      refreshStats();
      refreshStatus();
    } catch (e: any) {
      setError(`Upload failed: ${e.message}`);
    }

    setUploading(false);
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'application/pdf': ['.pdf'],
      'text/plain': ['.txt']
    }
  });

  // Query handler
  const handleQuery = async () => {
    if (!question.trim()) return;

    setLoading(true);
    setError('');
    setResponse('');
    setSources([]);

    try {
      const result: QueryResponse = await api.query(question);
      setResponse(result.response);
      setSources(result.sources);
      refreshStatus();
    } catch (e: any) {
      setError(`Query failed: ${e.message}`);
    }

    setLoading(false);
  };

  // Failover trigger handler
  const handleFailover = async () => {
    try {
      const result = await api.triggerFailover();
      setUploadStatus(`🔄 Failover: ${result.from} → ${result.to}`);
      refreshStatus();
    } catch (e: any) {
      setError(`Failover failed: ${e.message}`);
    }
  };

  // Clear documents handler
  const handleClear = async () => {
    if (!confirm('Are you sure you want to clear all documents?')) return;

    try {
      await api.clearDocuments();
      setDocumentCount(0);
      setUploadStatus('Documents cleared');
    } catch (e: any) {
      setError(`Clear failed: ${e.message}`);
    }
  };

  return (
    <div className="app">
      <header className="header">
        <div className="logo-container">
          <img src="/developer_week_logo.png" alt="Developer Week" className="logo" />
        </div>
        <h1>RAG Knowledge Assistant</h1>
        <p className="subtitle">Intelligent Document Q&A with Multi-Region Resilience</p>
      </header>

      {error && <div className="error-banner">{error}</div>}


      {/* Document Upload Section */}
      <section className="card">
        <h2>📁 Document Upload</h2>
        <div
          {...getRootProps()}
          className={`drop-zone ${isDragActive ? 'active' : ''}`}
        >
          <input {...getInputProps()} />
          {isDragActive ? (
            <p>Drop files here...</p>
          ) : (
            <p>Drag & drop PDF or TXT files here, or click to browse</p>
          )}
        </div>
        <div className="stats-row">
          <span>📄 Documents: <strong>{documentCount}</strong> chunks indexed</span>
          {uploadStatus && <span className="upload-status">{uploadStatus}</span>}
        </div>
        {uploading && <div className="loading-bar"></div>}
      </section>

      {/* Document Processing Status Section */}
      {processingDocs.length > 0 && (
        <section className="card processing-status-card">
          <h2>⏳ Processing Documents</h2>
          <div className="processing-list">
            {processingDocs.map((doc) => (
              <div key={doc.documentId} className="processing-item">
                <div className="processing-header">
                  <span className="doc-filename">📄 {doc.filename}</span>
                  <span className={`status-badge status-${doc.status?.status || 'loading'}`}>
                    {doc.status?.status || 'checking...'}
                  </span>
                </div>
                {doc.status && (
                  <>
                    <div className="progress-bar-container">
                      <div
                        className="progress-bar-fill"
                        style={{ width: `${doc.status.progress}%` }}
                      ></div>
                    </div>
                    <div className="processing-details">
                      <span>Progress: {doc.status.progress}%</span>
                      <span>Chunks: {doc.status.chunks_embedded} / {doc.status.chunk_count}</span>
                    </div>
                    {doc.status.progress === 0 && doc.status.status === 'uploaded' && (
                      <div className="status-hint">
                        ℹ️ Document uploaded to S3, waiting for chunking to begin...
                      </div>
                    )}
                    {doc.status.progress === 0 && doc.status.status === 'chunked' && (
                      <div className="status-hint">
                        ℹ️ Document chunked into {doc.status.chunk_count} pieces, waiting for embedding to start...
                      </div>
                    )}
                    {doc.status.status === 'embedding' && doc.status.progress < 100 && (
                      <div className="status-hint">
                        ⚡ Embeddings being generated in parallel - this usually takes {Math.ceil(doc.status.chunk_count / 5)}-{Math.ceil(doc.status.chunk_count / 2)} seconds
                      </div>
                    )}
                  </>
                )}
                {!doc.status && (
                  <div className="status-hint">
                    🔍 Checking processing status...
                  </div>
                )}
                <div className="document-id-display">
                  <small>ID: {doc.documentId}</small>
                </div>
              </div>
            ))}
          </div>
          <div className="processing-info">
            💡 <strong>Tip:</strong> Documents are processed automatically. Progress updates every 3 seconds.
            You can query the document once it reaches 100% or status shows "completed".
          </div>
        </section>
      )}

      {/* Query Section */}
      <section className="card">
        <h2>💬 Ask a Question</h2>
        <div className="query-input">
          <input
            type="text"
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleQuery()}
            placeholder="What would you like to know about your documents?"
            disabled={loading}
          />
          <button onClick={handleQuery} disabled={loading || !question.trim()}>
            {loading ? 'Thinking...' : 'Ask'}
          </button>
        </div>
      </section>

      {/* Response Section */}
      {(response || loading) && (
        <section className="card response-card">
          <h2>📝 Response</h2>
          {loading ? (
            <div className="loading-spinner">Processing your question...</div>
          ) : (
            <>
              <div className="response-text">{response}</div>
              {sources.length > 0 && (
                <div className="sources">
                  <strong>Sources:</strong>
                  {sources.map((s, i) => (
                    <span key={i} className="source-tag">
                      {s.source} (p.{s.page})
                    </span>
                  ))}
                </div>
              )}
            </>
          )}
        </section>
      )}

      {/* Status Panel */}
      <section className="card status-card">
        <h2>🔧 System Status</h2>
        <div className="status-grid">
          <div className="status-item">
            <span className={`indicator ${status ? 'connected' : 'disconnected'}`}></span>
            <span>API: {status ? 'Connected' : 'Disconnected'}</span>
          </div>
          <div className="status-item">
            <span className={`indicator ${status?.current_provider?.includes('Primary') ? 'primary' : 'failover'}`}></span>
            <span>Provider: {status?.current_provider || 'N/A'}</span>
          </div>
        </div>

        {status?.endpoints && (
          <div className="endpoints">
            {status.endpoints.map((ep, i) => (
              <div key={i} className={`endpoint ${ep.healthy ? 'healthy' : 'unhealthy'}`}>
                <span className={`indicator ${ep.healthy ? 'connected' : 'disconnected'}`}></span>
                <span>{ep.name}</span>
                {ep.is_current && <span className="current-badge">ACTIVE</span>}
              </div>
            ))}
          </div>
        )}

        <div className="status-actions">
          <button onClick={handleFailover} className="btn-warning">
            Trigger Failover
          </button>
          <button onClick={refreshStatus} className="btn-secondary">
            Refresh Status
          </button>
          <button onClick={handleClear} className="btn-danger">
            Clear Documents
          </button>
        </div>
      </section>

      {/* Settings Section - Moved to Bottom */}
      <Settings />

      <footer className="footer">
        <p>RAG Knowledge Assistant • Developer Week 2026 • Powered by Azure OpenAI & AWS</p>
      </footer>
    </div>
  );
}

export default App;
