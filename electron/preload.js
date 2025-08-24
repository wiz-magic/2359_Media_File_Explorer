const { contextBridge, ipcRenderer } = require('electron');

// 안전한 API를 웹 페이지에 노출
contextBridge.exposeInMainWorld('electronAPI', {
  getServerPort: () => ipcRenderer.invoke('get-server-port'),
  restartServer: () => ipcRenderer.invoke('restart-server'),
  
  onServerLog: (callback) => {
    ipcRenderer.on('server-log', (event, data) => callback(data));
  },
  
  onServerError: (callback) => {
    ipcRenderer.on('server-error', (event, data) => callback(data));
  },
  
  onNewScan: (callback) => {
    ipcRenderer.on('new-scan', () => callback());
  }
});