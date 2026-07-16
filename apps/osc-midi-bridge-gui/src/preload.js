const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('bridgeGui', {
  refreshStatus: (config) => ipcRenderer.invoke('status:refresh', config),
  startBridge: (config) => ipcRenderer.invoke('bridge:start', config),
  stopBridge: () => ipcRenderer.invoke('bridge:stop'),
  sendTestNote: (payload) => ipcRenderer.invoke('bridge:test-note', payload),
  resetLoopMidi: () => ipcRenderer.invoke('loopmidi:reset'),
  onLog: (callback) => {
    const listener = (_event, message) => callback(message);
    ipcRenderer.on('bridge:log', listener);
    return () => ipcRenderer.removeListener('bridge:log', listener);
  },
  onStatus: (callback) => {
    const listener = (_event, status) => callback(status);
    ipcRenderer.on('status:update', listener);
    return () => ipcRenderer.removeListener('status:update', listener);
  },
  onRecovery: (callback) => {
    const listener = (_event, recovery) => callback(recovery);
    ipcRenderer.on('bridge:recovery', listener);
    return () => ipcRenderer.removeListener('bridge:recovery', listener);
  },
  windowControls: {
    minimize: () => ipcRenderer.invoke('window:minimize'),
    toggleMaximize: () => ipcRenderer.invoke('window:toggle-maximize'),
    close: () => ipcRenderer.invoke('window:close'),
    getState: () => ipcRenderer.invoke('window:get-state'),
    onState: (callback) => {
      const listener = (_event, state) => callback(state);
      ipcRenderer.on('window:state', listener);
      return () => ipcRenderer.removeListener('window:state', listener);
    },
  },
});
