import React, { useState, useEffect } from 'react';
import { getCurrentBackendUrl, setBackendUrl, resetBackendUrl } from '../api/client';

export const Settings: React.FC = () => {
  const [backendUrl, setBackendUrlState] = useState('');
  const [isEditing, setIsEditing] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);

  useEffect(() => {
    setBackendUrlState(getCurrentBackendUrl());
  }, []);

  const handleSave = () => {
    if (backendUrl.trim()) {
      setBackendUrl(backendUrl.trim());
      setIsEditing(false);
      setShowSuccess(true);
      setTimeout(() => setShowSuccess(false), 3000);
    }
  };

  const handleReset = () => {
    resetBackendUrl();
    setBackendUrlState(getCurrentBackendUrl());
    setIsEditing(false);
    setShowSuccess(true);
    setTimeout(() => setShowSuccess(false), 3000);
  };

  const handleCancel = () => {
    setBackendUrlState(getCurrentBackendUrl());
    setIsEditing(false);
  };

  return (
    <div className="settings-panel">
      <h3>⚙️ Settings</h3>

      <div className="setting-item">
        <label>Backend API URL:</label>

        {!isEditing ? (
          <div className="url-display">
            <code>{backendUrl}</code>
            <button onClick={() => setIsEditing(true)} className="btn-edit">
              Edit
            </button>
          </div>
        ) : (
          <div className="url-edit">
            <input
              type="text"
              value={backendUrl}
              onChange={(e) => setBackendUrlState(e.target.value)}
              placeholder="http://IP_ADDRESS:8000"
              className="url-input"
            />
            <div className="button-group">
              <button onClick={handleSave} className="btn-save">
                Save
              </button>
              <button onClick={handleReset} className="btn-reset">
                Reset to Default
              </button>
              <button onClick={handleCancel} className="btn-cancel">
                Cancel
              </button>
            </div>
          </div>
        )}

        {showSuccess && (
          <div className="success-message">
            ✅ Backend URL updated! Refresh the page to apply changes.
          </div>
        )}
      </div>

      <div className="setting-help">
        <p><strong>Common URLs:</strong></p>
        <ul>
          <li><code>http://localhost:8000</code> - Local development</li>
          <li><code>http://13.222.106.90:8000</code> - Current AWS ECS</li>
          <li><code>http://YOUR_NEW_IP:8000</code> - Custom deployment</li>
        </ul>
        <p><em>Note: After changing the URL, refresh the page to apply changes.</em></p>
      </div>

      <style>{`
        .settings-panel {
          background: var(--card);
          padding: 24px;
          border-radius: 12px;
          margin: 20px 0;
          border: 1px solid var(--border);
          box-shadow: 0 2px 12px var(--shadow);
        }

        .settings-panel h3 {
          margin-top: 0;
          margin-bottom: 20px;
          color: var(--text);
          font-weight: 600;
          font-size: 1.2rem;
        }

        .setting-item {
          margin-bottom: 20px;
        }

        .setting-item label {
          display: block;
          margin-bottom: 10px;
          font-weight: 600;
          color: var(--text-secondary);
          font-size: 0.95rem;
        }

        .url-display {
          display: flex;
          gap: 12px;
          align-items: center;
        }

        .url-display code {
          flex: 1;
          background: var(--bg-secondary);
          padding: 12px 16px;
          border-radius: 8px;
          border: 1px solid var(--border);
          font-family: 'Courier New', monospace;
          color: var(--primary);
          font-size: 0.9rem;
        }

        .url-edit {
          display: flex;
          flex-direction: column;
          gap: 12px;
        }

        .url-input {
          padding: 12px 16px;
          border: 2px solid var(--primary);
          border-radius: 8px;
          font-size: 0.95rem;
          font-family: 'Courier New', monospace;
          background: var(--bg);
          color: var(--text);
        }

        .url-input:focus {
          outline: none;
          box-shadow: 0 0 0 3px rgba(0, 102, 204, 0.1);
        }

        .button-group {
          display: flex;
          gap: 10px;
          flex-wrap: wrap;
        }

        .btn-edit,
        .btn-save,
        .btn-reset,
        .btn-cancel {
          padding: 10px 20px;
          border: none;
          border-radius: 8px;
          cursor: pointer;
          font-weight: 600;
          transition: all 0.3s ease;
          font-size: 0.9rem;
        }

        .btn-edit {
          background: var(--primary);
          color: white;
          box-shadow: 0 2px 8px rgba(0, 102, 204, 0.2);
        }

        .btn-edit:hover {
          background: var(--primary-dark);
          transform: translateY(-2px);
          box-shadow: 0 4px 12px rgba(0, 102, 204, 0.3);
        }

        .btn-save {
          background: var(--success);
          color: white;
          box-shadow: 0 2px 8px rgba(0, 200, 83, 0.2);
        }

        .btn-save:hover {
          background: #00B248;
          transform: translateY(-2px);
          box-shadow: 0 4px 12px rgba(0, 200, 83, 0.3);
        }

        .btn-reset {
          background: var(--warning);
          color: white;
          box-shadow: 0 2px 8px rgba(255, 152, 0, 0.2);
        }

        .btn-reset:hover {
          background: #F57C00;
          transform: translateY(-2px);
          box-shadow: 0 4px 12px rgba(255, 152, 0, 0.3);
        }

        .btn-cancel {
          background: var(--text-secondary);
          color: white;
          box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        }

        .btn-cancel:hover {
          background: var(--text);
          transform: translateY(-2px);
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        }

        .success-message {
          margin-top: 12px;
          padding: 12px 16px;
          background: #E8F5E9;
          border: 1px solid var(--success);
          color: #2E7D32;
          border-radius: 8px;
          font-weight: 500;
        }

        .setting-help {
          margin-top: 24px;
          padding: 20px;
          background: var(--bg-secondary);
          border: 1px solid var(--border);
          border-radius: 8px;
        }

        .setting-help p {
          margin: 8px 0;
          color: var(--text-secondary);
        }

        .setting-help strong {
          color: var(--text);
          font-weight: 600;
        }

        .setting-help ul {
          margin: 12px 0;
          padding-left: 24px;
        }

        .setting-help li {
          margin: 8px 0;
          color: var(--text-secondary);
        }

        .setting-help code {
          background: var(--card);
          padding: 4px 8px;
          border-radius: 4px;
          border: 1px solid var(--border);
          font-family: 'Courier New', monospace;
          color: var(--primary);
          font-size: 0.9rem;
        }

        .setting-help em {
          color: var(--text-muted);
          font-style: italic;
        }
      `}</style>
    </div>
  );
};

