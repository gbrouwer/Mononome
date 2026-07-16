const { app, BrowserWindow, Menu, ipcMain } = require('electron');
const { spawn, execFile } = require('node:child_process');
const dgram = require('node:dgram');
const os = require('node:os');
const path = require('node:path');

const repoRoot = path.resolve(__dirname, '..', '..', '..');
const runtimeRoot = app.isPackaged ? process.resourcesPath : repoRoot;
const toolsRoot = app.isPackaged ? path.join(process.resourcesPath, 'tools') : path.join(repoRoot, 'tools');
const bridgePath = path.join(toolsRoot, 'osc-midi-bridge.ps1');
const testSenderPath = path.join(toolsRoot, 'send-osc-midi-test.ps1');
const defaultConfig = {
  listenPort: 7123,
  midiOutName: 'norns OSC MIDI',
  verbosePackets: true,
};

let mainWindow = null;
let bridgeProcess = null;
let bridgeConfig = { ...defaultConfig };
let bridgeHadMidiOutputError = false;
let recoverySent = false;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 760,
    height: 650,
    minWidth: 760,
    minHeight: 650,
    title: 'norns OSC MIDI Bridge',
    icon: path.join(__dirname, 'renderer', 'assets', 'AppIcon.png'),
    frame: false,
    autoHideMenuBar: true,
    backgroundColor: '#f4f7f9',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  mainWindow.on('maximize', sendWindowState);
  mainWindow.on('unmaximize', sendWindowState);
  mainWindow.on('restore', sendWindowState);
}

function powershell(args, options = {}) {
  return new Promise((resolve, reject) => {
    execFile(
      'powershell.exe',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', ...args],
      {
        cwd: runtimeRoot,
        windowsHide: true,
        timeout: options.timeout ?? 8000,
        maxBuffer: options.maxBuffer ?? 1024 * 1024,
      },
      (error, stdout, stderr) => {
        if (error) {
          error.stdout = stdout;
          error.stderr = stderr;
          reject(error);
          return;
        }
        resolve({ stdout, stderr });
      }
    );
  });
}

async function getMidiDevices() {
  const { stdout } = await powershell(['-File', bridgePath, '-ListDevicesJson']);
  const trimmed = stdout.trim();
  if (!trimmed) return [];
  const parsed = JSON.parse(trimmed);
  return Array.isArray(parsed) ? parsed : [parsed];
}

async function getProcessRunning(processName) {
  try {
    const command = [
      '$p = Get-Process -Name',
      JSON.stringify(processName),
      '-ErrorAction SilentlyContinue | Select-Object -First 1;',
      'if ($p) { "true" } else { "false" }',
    ].join(' ');
    const { stdout } = await powershell(['-Command', command], { timeout: 4000 });
    return stdout.trim().toLowerCase() === 'true';
  } catch {
    return false;
  }
}

async function getAbletonRunning() {
  try {
    const command = [
      '$p = Get-Process -ErrorAction SilentlyContinue |',
      'Where-Object { $_.ProcessName -like "Ableton*" -or $_.ProcessName -like "Live*" } |',
      'Select-Object -First 1;',
      'if ($p) { "true" } else { "false" }',
    ].join(' ');
    const { stdout } = await powershell(['-Command', command], { timeout: 4000 });
    return stdout.trim().toLowerCase() === 'true';
  } catch {
    return false;
  }
}

function getLocalIps() {
  const interfaces = os.networkInterfaces();
  const ips = [];
  for (const entries of Object.values(interfaces)) {
    for (const entry of entries ?? []) {
      if (entry.family === 'IPv4' && !entry.internal) {
        ips.push(entry.address);
      }
    }
  }
  return ips;
}

function checkUdpPort(port) {
  if (bridgeProcess) {
    return Promise.resolve({ available: false, ownedByBridge: true });
  }

  return new Promise((resolve) => {
    const socket = dgram.createSocket({ type: 'udp4', reuseAddr: false });
    let done = false;

    const finish = (result) => {
      if (done) return;
      done = true;
      try {
        socket.close();
      } catch {}
      resolve(result);
    };

    socket.once('error', (error) => {
      finish({ available: false, ownedByBridge: false, error: error.code || error.message });
    });

    socket.once('listening', () => {
      finish({ available: true, ownedByBridge: false });
    });

    socket.bind(port, '0.0.0.0');
  });
}

async function buildStatus() {
  const [devicesResult, loopMidiRunning, abletonRunning, udpPort] = await Promise.allSettled([
    getMidiDevices(),
    getProcessRunning('loopMIDI'),
    getAbletonRunning(),
    checkUdpPort(Number(bridgeConfig.listenPort)),
  ]);

  const devices = devicesResult.status === 'fulfilled' ? devicesResult.value : [];
  const devicesError = devicesResult.status === 'rejected'
    ? `${devicesResult.reason.message || devicesResult.reason}`
    : '';
  const selectedDevice = devices.find((device) =>
    String(device.Name || '').toLowerCase().includes(String(bridgeConfig.midiOutName).toLowerCase())
  );
  const anyLoopMidiDevice = devices.find((device) =>
    String(device.Name || '').toLowerCase().includes('loopmidi')
  );

  return {
    config: { ...bridgeConfig },
    bridgeRunning: Boolean(bridgeProcess),
    devices,
    devicesError,
    selectedDevice: selectedDevice || null,
    anyLoopMidiDevice: anyLoopMidiDevice || null,
    loopMidiRunning: loopMidiRunning.status === 'fulfilled' ? loopMidiRunning.value : false,
    abletonRunning: abletonRunning.status === 'fulfilled' ? abletonRunning.value : false,
    udpPort: udpPort.status === 'fulfilled'
      ? udpPort.value
      : { available: false, ownedByBridge: false, error: String(udpPort.reason) },
    localIps: getLocalIps(),
    platform: process.platform,
  };
}

function sendLog(type, text) {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  mainWindow.webContents.send('bridge:log', {
    type,
    text: String(text).trimEnd(),
    at: new Date().toISOString(),
  });
}

function sendRecovery(reason) {
  if (!mainWindow || mainWindow.isDestroyed() || recoverySent) return;
  recoverySent = true;
  mainWindow.webContents.send('bridge:recovery', {
    reason,
    at: new Date().toISOString(),
  });
}

function handleBridgeOutput(type, text) {
  const output = String(text);
  sendLog(type, output);
  if (/midiOutShortMsg failed with code 1/i.test(output)) {
    bridgeHadMidiOutputError = true;
    sendRecovery('The MIDI output handle failed. Reset loopMIDI, then start the bridge again.');
  }
}

function broadcastStatus() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  buildStatus()
    .then((status) => mainWindow.webContents.send('status:update', status))
    .catch((error) => sendLog('error', `Status check failed: ${error.message || error}`));
}

ipcMain.handle('status:refresh', async (_event, configPatch = {}) => {
  bridgeConfig = {
    ...bridgeConfig,
    ...configPatch,
    listenPort: Number(configPatch.listenPort ?? bridgeConfig.listenPort),
  };
  return buildStatus();
});

ipcMain.handle('bridge:start', async (_event, configPatch = {}) => {
  if (bridgeProcess) {
    return { ok: true, alreadyRunning: true };
  }

  bridgeConfig = {
    ...bridgeConfig,
    ...configPatch,
    listenPort: Number(configPatch.listenPort ?? bridgeConfig.listenPort),
    midiOutName: String(configPatch.midiOutName ?? bridgeConfig.midiOutName),
    verbosePackets: Boolean(configPatch.verbosePackets ?? bridgeConfig.verbosePackets),
  };

  const args = [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    bridgePath,
    '-MidiOutName',
    bridgeConfig.midiOutName,
    '-ListenPort',
    String(bridgeConfig.listenPort),
  ];

  if (bridgeConfig.verbosePackets) {
    args.push('-VerbosePackets');
  }

  bridgeHadMidiOutputError = false;
  recoverySent = false;
  sendLog('info', `Starting bridge on UDP ${bridgeConfig.listenPort} -> ${bridgeConfig.midiOutName}`);
  bridgeProcess = spawn('powershell.exe', args, {
    cwd: runtimeRoot,
    windowsHide: true,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  bridgeProcess.stdout.on('data', (chunk) => handleBridgeOutput('stdout', chunk.toString()));
  bridgeProcess.stderr.on('data', (chunk) => handleBridgeOutput('stderr', chunk.toString()));
  bridgeProcess.on('error', (error) => {
    sendLog('error', `Bridge process error: ${error.message}`);
  });
  bridgeProcess.on('exit', (code, signal) => {
    sendLog('info', `Bridge stopped${code === null ? '' : ` with code ${code}`}${signal ? ` (${signal})` : ''}.`);
    if (bridgeHadMidiOutputError) {
      sendRecovery('The bridge stopped after a Windows MIDI output error. Reset loopMIDI, then start the bridge again.');
    }
    bridgeProcess = null;
    broadcastStatus();
  });

  setTimeout(broadcastStatus, 300);
  return { ok: true };
});

ipcMain.handle('bridge:stop', async () => {
  if (!bridgeProcess) {
    return { ok: true, alreadyStopped: true };
  }

  sendLog('info', 'Stopping bridge process.');
  bridgeProcess.kill();
  return { ok: true };
});

async function resetLoopMidi() {
  const script = `
$ErrorActionPreference = 'Stop'
$proc = @(Get-Process -Name loopMIDI -ErrorAction SilentlyContinue)
$path = $null
if ($proc.Count -gt 0) {
    $path = $proc[0].Path
}
if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) {
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if (-not [string]::IsNullOrWhiteSpace($programFilesX86)) {
        $candidate = Join-Path $programFilesX86 'Tobias Erichsen\\loopMIDI\\loopMIDI.exe'
        if (Test-Path -LiteralPath $candidate) {
            $path = $candidate
        }
    }
}
if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) {
    throw 'loopMIDI.exe was not found. Start loopMIDI manually once, then try again.'
}
if ($proc.Count -gt 0) {
    $proc | Stop-Process -Force
    Start-Sleep -Milliseconds 1500
}
Start-Process -FilePath $path
Start-Sleep -Milliseconds 1500
$running = Get-Process -Name loopMIDI -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $running) {
    throw 'loopMIDI did not restart.'
}
[PSCustomObject]@{
    Path = $path
    Pid = $running.Id
} | ConvertTo-Json -Compress
`;

  const { stdout } = await powershell(['-Command', script], { timeout: 12000 });
  return JSON.parse(stdout.trim());
}

ipcMain.handle('loopmidi:reset', async () => {
  if (bridgeProcess) {
    sendLog('info', 'Stopping bridge before resetting loopMIDI.');
    bridgeProcess.kill();
    bridgeProcess = null;
    await new Promise((resolve) => setTimeout(resolve, 700));
  }

  sendLog('info', 'Resetting loopMIDI.');
  const result = await resetLoopMidi();
  recoverySent = false;
  bridgeHadMidiOutputError = false;
  sendLog('info', `loopMIDI restarted with PID ${result.Pid}.`);
  setTimeout(broadcastStatus, 500);
  return { ok: true, ...result };
});

ipcMain.handle('bridge:test-note', async (_event, payload = {}) => {
  const port = Number(payload.port ?? bridgeConfig.listenPort);
  const args = [
    '-File',
    testSenderPath,
    '-HostName',
    '127.0.0.1',
    '-Port',
    String(port),
    '-Note',
    String(payload.note ?? 60),
    '-Velocity',
    String(payload.velocity ?? 110),
    '-Channel',
    String(payload.channel ?? 1),
    '-DurationMs',
    String(payload.durationMs ?? 500),
  ];

  const { stdout, stderr } = await powershell(args, { timeout: 5000 });
  if (stdout.trim()) sendLog('stdout', stdout);
  if (stderr.trim()) sendLog('stderr', stderr);
  return { ok: true };
});

function sendWindowState() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  mainWindow.webContents.send('window:state', {
    maximized: mainWindow.isMaximized(),
  });
}

ipcMain.handle('window:minimize', () => {
  mainWindow?.minimize();
});

ipcMain.handle('window:toggle-maximize', () => {
  if (!mainWindow) return { maximized: false };
  if (mainWindow.isMaximized()) {
    mainWindow.unmaximize();
  } else {
    mainWindow.maximize();
  }
  sendWindowState();
  return { maximized: mainWindow.isMaximized() };
});

ipcMain.handle('window:close', () => {
  mainWindow?.close();
});

ipcMain.handle('window:get-state', () => ({
  maximized: mainWindow?.isMaximized() ?? false,
}));

const isSmokeTest = process.argv.includes('--smoke-test');

app.whenReady().then(async () => {
  Menu.setApplicationMenu(null);

  if (isSmokeTest) {
    const status = await buildStatus();
    console.log(JSON.stringify({
      bridgeRunning: status.bridgeRunning,
      midiDeviceCount: status.devices.length,
      selectedDevice: status.selectedDevice?.Name || null,
      loopMidiRunning: status.loopMidiRunning,
      udpPort: status.udpPort,
      localIps: status.localIps,
    }, null, 2));
    app.quit();
    return;
  }

  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (bridgeProcess) {
    bridgeProcess.kill();
    bridgeProcess = null;
  }
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
