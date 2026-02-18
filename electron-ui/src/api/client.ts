import axios from 'axios';

// Backend API URL - update this when backend endpoint changes
// For local development: 'http://localhost:8000'
// For deployed backend: 'http://<ECS-PUBLIC-IP>:8000'
const BASE_URL = import.meta.env.VITE_API_URL || 'http://54.89.127.74:8000';

console.log('🔗 API Base URL:', BASE_URL);

const client = axios.create({
  baseURL: BASE_URL,
  timeout: 60000
});

export interface UploadResponse {
  filename: string;
  chunks_created: number;
  document_id: string;
  provider: string;
  status: string;
}

export interface QueryResponse {
  response: string;
  sources: Array<{ source: string; page: number }>;
  provider: string;
}

export interface Endpoint {
  name: string;
  healthy: boolean;
  is_current: boolean;
  last_failure?: number;
}

export interface HealthStatus {
  status: string;
  current_provider: string;
  endpoints: Endpoint[];
}

export interface Stats {
  vector_store: {
    type: string;
    document_count: number;
  };
  azure_openai: {
    current_provider: string;
  };
}

export interface FailoverResult {
  message: string;
  from: string;
  to: string;
}

export const api = {
  async uploadFile(file: File): Promise<UploadResponse> {
    const formData = new FormData();
    formData.append('file', file);
    const response = await client.post<UploadResponse>('/upload', formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    });
    return response.data;
  },

  async query(question: string, nResults: number = 5): Promise<QueryResponse> {
    const response = await client.post<QueryResponse>('/query', {
      question,
      n_results: nResults
    });
    return response.data;
  },

  async getHealthStatus(): Promise<HealthStatus> {
    const response = await client.get<HealthStatus>('/demo/health-status');
    return response.data;
  },

  async getStats(): Promise<Stats> {
    const response = await client.get<Stats>('/stats');
    return response.data;
  },

  async triggerFailover(): Promise<FailoverResult> {
    const response = await client.post<FailoverResult>('/demo/trigger-failover');
    return response.data;
  },

  async performHealthCheck(): Promise<any> {
    const response = await client.post('/demo/health-check');
    return response.data;
  },

  async clearDocuments(): Promise<{ success: boolean; message: string }> {
    const response = await client.delete('/documents');
    return response.data;
  },

  async getDocuments(): Promise<{ document_count: number }> {
    const response = await client.get('/documents');
    return response.data;
  }
};
