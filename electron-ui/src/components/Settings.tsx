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
          background: #f5f5f5;
          padding: 20px;
          border-radius: 8px;
          margin: 20px 0;
        }

        .settings-panel h3 {
          margin-top: 0;
          color: #333;
        }

        .setting-item {
          margin-bottom: 20px;
        }

        .setting-item label {
          display: block;
          margin-bottom: 8px;
          font-weight: 600;
          color: #555;
        }

        .url-display {
          display: flex;
          gap: 10px;
          align-items: center;
        }

        .url-display code {
          flex: 1;
          background: #fff;
          padding: 10px;
          border-radius: 4px;
          border: 1px solid #ddd;
          font-family: 'Courier New', monospace;
        }

        .url-edit {
          display: flex;
          flex-direction: column;
          gap: 10px;
        }

        .url-input {
          padding: 10px;
          border: 2px solid #4CAF50;
          border-radius: 4px;
          font-size: 14px;
          font-family: 'Courier New', monospace;
        }

        .button-group {
          display: flex;
          gap: 10px;
        }

        .btn-edit,
        .btn-save,
        .btn-reset,
        .btn-cancel {
          padding: 8px 16px;
          border: none;
          border-radius: 4px;
          cursor: pointer;
          font-weight: 600;
          transition: background-color 0.3s;
        }

        .btn-edit {
          background: #2196F3;
          color: white;
        }

        .btn-edit:hover {
          background: #0b7dda;
        }

        .btn-save {
          background: #4CAF50;
          color: white;
        }

        .btn-save:hover {
          background: #45a049;
        }

        .btn-reset {
          background: #ff9800;
          color: white;
        }

        .btn-reset:hover {
          background: #e68900;
        }

        .btn-cancel {
          background: #9e9e9e;
          color: white;
        }

        .btn-cancel:hover {
          background: #757575;
        }

        .success-message {
          margin-top: 10px;
          padding: 10px;
          background: #d4edda;
          border: 1px solid #c3e6cb;
          color: #155724;
          border-radius: 4px;
        }

        .setting-help {
          margin-top: 20px;
          padding: 15px;
          background: #fff3cd;
          border: 1px solid #ffeaa7;
          border-radius: 4px;
        }

        .setting-help p {
          margin: 5px 0;
          color: #856404;
        }

        .setting-help strong {
          color: #856404;
        }

        .setting-help ul {
          margin: 10px 0;
          padding-left: 20px;
        }

        .setting-help li {
          margin: 5px 0;
          color: #856404;
        }

        .setting-help code {
          background: #fff;
          padding: 2px 6px;
          border-radius: 3px;
          font-family: 'Courier New', monospace;
        }
      `}</style>
    </div>
  );
};

