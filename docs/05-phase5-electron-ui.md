# Phase 5: Electron UI

## 🎯 Goal
Build a desktop application with Electron for the RAG demo.

## UI Mockup

```
┌─────────────────────────────────────────────────────────────┐
│  RAG Demo - Developer Week                    [─] [□] [×]   │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐│
│  │  📁 DOCUMENT UPLOAD                                     ││
│  │  ┌───────────────────────────────────────────────────┐ ││
│  │  │                                                   │ ││
│  │  │     Drag & Drop files here or click to browse    │ ││
│  │  │              PDF, TXT, DOCX supported             │ ││
│  │  │                                                   │ ││
│  │  └───────────────────────────────────────────────────┘ ││
│  │  Documents: 5 files │ Vectors: 1,234 chunks           ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  💬 ASK A QUESTION                                      ││
│  │  ┌───────────────────────────────────────────────────┐ ││
│  │  │ What are the key features of the product?         │ ││
│  │  └───────────────────────────────────────────────────┘ ││
│  │  [Ask Question]                                        ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  📝 RESPONSE                                            ││
│  │  Based on the documents, the key features are:         ││
│  │  1. Scalable architecture                              ││
│  │  2. Real-time processing                               ││
│  │  3. Multi-cloud support                                ││
│  │                                                         ││
│  │  Sources: doc1.pdf (page 3), doc2.pdf (page 7)        ││
│  └─────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  🔧 SYSTEM STATUS                                       ││
│  │  API: 🟢 Connected    Provider: 🟢 Primary (East US)   ││
│  │  [Trigger Failover] [Check Health]                     ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Project Setup

```bash
cd electron-ui
npm init -y
npm install electron electron-builder react react-dom axios
npm install -D @types/react typescript vite @vitejs/plugin-react
```

## File Structure

```
electron-ui/
├── package.json
├── main.js              # Electron main process
├── preload.js           # Preload script
├── src/
│   ├── index.html
│   ├── App.tsx
│   ├── components/
│   │   ├── FileUpload.tsx
│   │   ├── QueryInput.tsx
│   │   ├── ResponseDisplay.tsx
│   │   └── StatusPanel.tsx
│   └── api/
│       └── client.ts
└── vite.config.ts
```

## Main Process

```javascript
// electron-ui/main.js
const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  // In development, load from Vite dev server
  if (process.env.NODE_ENV === 'development') {
    mainWindow.loadURL('http://localhost:5173');
    mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadFile(path.join(__dirname, 'dist/index.html'));
  }
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
```

## React Components

### App.tsx
```tsx
// electron-ui/src/App.tsx
import React, { useState, useEffect } from 'react';
import FileUpload from './components/FileUpload';
import QueryInput from './components/QueryInput';
import ResponseDisplay from './components/ResponseDisplay';
import StatusPanel from './components/StatusPanel';
import { api } from './api/client';

function App() {
  const [response, setResponse] = useState('');
  const [sources, setSources] = useState([]);
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState({ connected: false, provider: '' });
  const [documentCount, setDocumentCount] = useState(0);

  useEffect(() => {
    checkHealth();
    refreshStats();
  }, []);

  const checkHealth = async () => {
    try {
      const health = await api.getHealth();
      setStatus({ connected: true, provider: health.current_provider });
    } catch (e) {
      setStatus({ connected: false, provider: 'Disconnected' });
    }
  };

  const refreshStats = async () => {
    try {
      const stats = await api.getStats();
      setDocumentCount(stats.document_count);
    } catch (e) {
      console.error(e);
    }
  };

  const handleQuery = async (query: string) => {
    setLoading(true);
    try {
      const result = await api.query(query);
      setResponse(result.response);
      setSources(result.sources);
      setStatus(s => ({ ...s, provider: result.provider }));
    } catch (e) {
      setResponse('Error: ' + e.message);
    }
    setLoading(false);
  };

  const handleUpload = async (files: File[]) => {
    for (const file of files) {
      await api.uploadFile(file);
    }
    refreshStats();
  };

  return (
    <div className="app">
      <h1>🤖 RAG Demo - Developer Week</h1>
      <FileUpload onUpload={handleUpload} documentCount={documentCount} />
      <QueryInput onQuery={handleQuery} loading={loading} />
      <ResponseDisplay response={response} sources={sources} />
      <StatusPanel status={status} onRefresh={checkHealth} />
    </div>
  );
}

export default App;
```

### API Client
```typescript
// electron-ui/src/api/client.ts
import axios from 'axios';

const BASE_URL = 'http://localhost:8000';

export const api = {
  async uploadFile(file: File) {
    const formData = new FormData();
    formData.append('file', file);
    const response = await axios.post(`${BASE_URL}/upload`, formData);
    return response.data;
  },

  async query(question: string) {
    const response = await axios.post(`${BASE_URL}/query`, { question });
    return response.data;
  },

  async getHealth() {
    const response = await axios.get(`${BASE_URL}/demo/health-status`);
    return response.data;
  },

  async getStats() {
    const response = await axios.get(`${BASE_URL}/stats`);
    return response.data;
  },

  async triggerFailover() {
    const response = await axios.post(`${BASE_URL}/demo/trigger-failover`);
    return response.data;
  }
};
```

## Styles

```css
/* electron-ui/src/styles.css */
:root {
  --primary: #4a90d9;
  --success: #28a745;
  --warning: #ffc107;
  --danger: #dc3545;
  --bg: #1a1a2e;
  --card: #16213e;
  --text: #eee;
}

body {
  font-family: 'Segoe UI', system-ui, sans-serif;
  background: var(--bg);
  color: var(--text);
  margin: 0;
  padding: 20px;
}

.app {
  max-width: 900px;
  margin: 0 auto;
}

.card {
  background: var(--card);
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 20px;
}

.drop-zone {
  border: 2px dashed var(--primary);
  border-radius: 8px;
  padding: 40px;
  text-align: center;
  cursor: pointer;
}

.drop-zone:hover {
  background: rgba(74, 144, 217, 0.1);
}

button {
  background: var(--primary);
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 6px;
  cursor: pointer;
}

button:hover {
  opacity: 0.9;
}

.status-indicator {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin-right: 8px;
}

.status-indicator.connected { background: var(--success); }
.status-indicator.failover { background: var(--warning); }
.status-indicator.disconnected { background: var(--danger); }
```

## Quick Start Commands

```bash
# Terminal 1: Start backend
cd backend
uvicorn app.main:app --reload --port 8000

# Terminal 2: Start Electron in dev mode
cd electron-ui
npm run dev
```

## ✅ Phase 5 Checklist

- [ ] Electron app scaffolded
- [ ] File upload component working
- [ ] Query input/response working
- [ ] Status panel showing provider
- [ ] Failover trigger button
- [ ] Styled and polished
