import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './styles.css';

console.log('🚀 Main.tsx loading...');

try {
  const rootElement = document.getElementById('root');
  if (!rootElement) {
    throw new Error('Root element not found!');
  }

  console.log('✅ Root element found, creating React root...');
  const root = ReactDOM.createRoot(rootElement);

  console.log('✅ Rendering App component...');
  root.render(
    <React.StrictMode>
      <App />
    </React.StrictMode>
  );

  console.log('✅ App rendered successfully!');
} catch (error) {
  console.error('❌ Fatal error loading app:', error);
  document.body.innerHTML = `
    <div style="color: white; padding: 40px; background: #1a1a2e; font-family: Arial;">
      <h1 style="color: #dc3545;">⚠️ Application Error</h1>
      <p style="font-size: 18px;">Failed to load the application.</p>
      <p><strong>Error:</strong> ${error}</p>
      <hr style="margin: 20px 0; border-color: #444;"/>
      <p><strong>Troubleshooting:</strong></p>
      <ul>
        <li>Press F12 to open DevTools and check Console for details</li>
        <li>Make sure all dependencies are installed: <code>npm install</code></li>
        <li>Try clearing cache: <code>npm run dev</code> after deleting node_modules/.vite</li>
      </ul>
    </div>
  `;
}
