'use strict';

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('launcher', {
  getApps:  ()        => ipcRenderer.invoke('get-apps'),
  launchApp:(id)      => ipcRenderer.invoke('launch-app', id),
  getKey:   ()        => ipcRenderer.invoke('get-gemini-key'),
  setKey:   (key)     => ipcRenderer.invoke('set-gemini-key', key),
  getLogs:  (appId)   => ipcRenderer.invoke('get-logs', appId),

  onStatus: (cb) => ipcRenderer.on('app-status', (_event, data) => cb(data)),
  onLog:    (cb) => ipcRenderer.on('app-log',    (_event, data) => cb(data)),

  offAll: () => {
    ipcRenderer.removeAllListeners('app-status');
    ipcRenderer.removeAllListeners('app-log');
  },
});
