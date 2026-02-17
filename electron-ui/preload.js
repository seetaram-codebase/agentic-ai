const { contextBridge } = require('electron');

// Expose any needed APIs to the renderer
contextBridge.exposeInMainWorld('electronAPI', {
  platform: process.platform,
  versions: {
    node: process.versions.node,
    electron: process.versions.electron
  }
});
