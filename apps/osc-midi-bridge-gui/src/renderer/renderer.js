const state = {
  config: {
    listenPort: 7123,
    midiOutName: 'norns OSC MIDI',
    verbosePackets: true,
  },
  devices: [],
};

const el = {
  windowTitlebar: document.querySelector('.window-titlebar'),
  minimizeWindow: document.querySelector('#minimizeWindow'),
  maximizeWindow: document.querySelector('#maximizeWindow'),
  closeWindow: document.querySelector('#closeWindow'),
  midiOut: document.querySelector('#midiOut'),
  listenPort: document.querySelector('#listenPort'),
  verbosePackets: document.querySelector('#verbosePackets'),
  refreshButton: document.querySelector('#refreshButton'),
  startButton: document.querySelector('#startButton'),
  stopButton: document.querySelector('#stopButton'),
  testButton: document.querySelector('#testButton'),
  resetLoopMidiButton: document.querySelector('#resetLoopMidiButton'),
  resetLoopMidiBannerButton: document.querySelector('#resetLoopMidiBannerButton'),
  recoveryBanner: document.querySelector('#recoveryBanner'),
  recoveryMessage: document.querySelector('#recoveryMessage'),
  clearLogButton: document.querySelector('#clearLogButton'),
  bridgePill: document.querySelector('#bridgePill'),
  subtitle: document.querySelector('#subtitle'),
  logOutput: document.querySelector('#logOutput'),
  ipList: document.querySelector('#ipList'),
  loopMidiDot: document.querySelector('#loopMidiDot'),
  loopMidiStatus: document.querySelector('#loopMidiStatus'),
  portDot: document.querySelector('#portDot'),
  portStatus: document.querySelector('#portStatus'),
  udpDot: document.querySelector('#udpDot'),
  udpStatus: document.querySelector('#udpStatus'),
  abletonDot: document.querySelector('#abletonDot'),
  abletonStatus: document.querySelector('#abletonStatus'),
};

const windowControls = window.bridgeGui.windowControls;

function currentConfig() {
  return {
    listenPort: Number(el.listenPort.value || 7123),
    midiOutName: el.midiOut.value || state.config.midiOutName,
    verbosePackets: el.verbosePackets.checked,
  };
}

function setDot(dot, kind) {
  dot.className = `dot ${kind}`;
}

function setBridgeRunning(isRunning) {
  el.bridgePill.textContent = isRunning ? 'Running' : 'Stopped';
  el.bridgePill.className = isRunning ? 'pill pill-running' : 'pill pill-idle';
  el.startButton.disabled = isRunning;
  el.stopButton.disabled = !isRunning;
}

function setWindowState(windowState) {
  const isMaximized = Boolean(windowState?.maximized);
  el.maximizeWindow.title = isMaximized ? 'Restore' : 'Maximize';
  el.maximizeWindow.setAttribute('aria-label', isMaximized ? 'Restore' : 'Maximize');
  el.maximizeWindow.textContent = isMaximized ? '\u2750' : '\u25a1';
}

function showRecovery(recovery) {
  el.recoveryMessage.textContent = recovery?.reason || 'Reset loopMIDI, then start the bridge again.';
  el.recoveryBanner.classList.remove('hidden');
}

function hideRecovery() {
  el.recoveryBanner.classList.add('hidden');
}

function renderDevices(devices, selectedName) {
  state.devices = devices;
  const previous = selectedName || el.midiOut.value || state.config.midiOutName;
  el.midiOut.innerHTML = '';

  if (!devices.length) {
    const option = document.createElement('option');
    option.value = previous;
    option.textContent = `${previous} (not found)`;
    el.midiOut.append(option);
    return;
  }

  for (const device of devices) {
    const option = document.createElement('option');
    option.value = device.Name;
    option.textContent = `[${device.Index}] ${device.Name}`;
    el.midiOut.append(option);
  }

  const exact = [...el.midiOut.options].find((option) => option.value === previous);
  const fuzzy = [...el.midiOut.options].find((option) =>
    option.value.toLowerCase().includes(previous.toLowerCase())
  );
  el.midiOut.value = (exact || fuzzy || el.midiOut.options[0]).value;
}

function renderIps(ips) {
  el.ipList.innerHTML = '';
  if (!ips.length) {
    const chip = document.createElement('span');
    chip.className = 'chip muted';
    chip.textContent = 'No IPv4 address detected';
    el.ipList.append(chip);
    return;
  }

  for (const ip of ips) {
    const chip = document.createElement('button');
    chip.className = 'chip';
    chip.textContent = ip;
    chip.title = 'Copy IP';
    chip.addEventListener('click', () => navigator.clipboard?.writeText(ip));
    el.ipList.append(chip);
  }
}

function renderStatus(status) {
  state.config = status.config;
  el.listenPort.value = status.config.listenPort;
  el.verbosePackets.checked = status.config.verbosePackets;
  renderDevices(status.devices, status.config.midiOutName);
  setBridgeRunning(status.bridgeRunning);
  renderIps(status.localIps);

  if (status.loopMidiRunning) {
    setDot(el.loopMidiDot, 'ok');
    el.loopMidiStatus.textContent = 'Running';
  } else if (status.anyLoopMidiDevice) {
    setDot(el.loopMidiDot, 'warn');
    el.loopMidiStatus.textContent = 'Port exists, app not detected';
  } else {
    setDot(el.loopMidiDot, 'bad');
    el.loopMidiStatus.textContent = 'Not detected';
  }

  if (status.selectedDevice) {
    setDot(el.portDot, 'ok');
    el.portStatus.textContent = `[${status.selectedDevice.Index}] ${status.selectedDevice.Name}`;
  } else if (status.devicesError) {
    setDot(el.portDot, 'bad');
    el.portStatus.textContent = status.devicesError;
  } else if (status.anyLoopMidiDevice) {
    setDot(el.portDot, 'warn');
    el.portStatus.textContent = `Found ${status.anyLoopMidiDevice.Name}, not selected`;
  } else {
    setDot(el.portDot, 'bad');
    el.portStatus.textContent = 'norns OSC MIDI not found';
  }

  if (status.udpPort.ownedByBridge) {
    setDot(el.udpDot, 'ok');
    el.udpStatus.textContent = `${status.config.listenPort} owned by this bridge`;
  } else if (status.udpPort.available) {
    setDot(el.udpDot, 'ok');
    el.udpStatus.textContent = `${status.config.listenPort} available`;
  } else {
    setDot(el.udpDot, 'bad');
    el.udpStatus.textContent = `${status.config.listenPort} busy${status.udpPort.error ? ` (${status.udpPort.error})` : ''}`;
  }

  if (status.abletonRunning) {
    setDot(el.abletonDot, 'ok');
    el.abletonStatus.textContent = 'Running';
  } else {
    setDot(el.abletonDot, 'warn');
    el.abletonStatus.textContent = 'Not detected';
  }

  el.subtitle.textContent = `UDP ${status.config.listenPort} to ${el.midiOut.value || status.config.midiOutName}`;
}

function appendLog(message) {
  if (!message.text) return;
  const time = new Date(message.at).toLocaleTimeString();
  el.logOutput.textContent += `[${time}] ${message.text}\n`;
  el.logOutput.scrollTop = el.logOutput.scrollHeight;

  if (/midiOutShortMsg failed with code 1/i.test(message.text)) {
    showRecovery({
      reason: 'The Windows MIDI output handle failed. Reset loopMIDI, then start the bridge again.',
    });
  }
}

async function refresh() {
  el.refreshButton.disabled = true;
  try {
    const status = await window.bridgeGui.refreshStatus(currentConfig());
    renderStatus(status);
  } catch (error) {
    appendLog({ type: 'error', text: `Refresh failed: ${error.message || error}`, at: new Date().toISOString() });
  } finally {
    el.refreshButton.disabled = false;
  }
}

el.refreshButton.addEventListener('click', refresh);
el.startButton.addEventListener('click', async () => {
  hideRecovery();
  await window.bridgeGui.startBridge(currentConfig());
  setTimeout(refresh, 400);
});
el.stopButton.addEventListener('click', async () => {
  await window.bridgeGui.stopBridge();
  setTimeout(refresh, 400);
});
el.testButton.addEventListener('click', async () => {
  try {
    await window.bridgeGui.sendTestNote({ port: Number(el.listenPort.value || 7123) });
  } catch (error) {
    appendLog({ type: 'error', text: `Test note failed: ${error.message || error}`, at: new Date().toISOString() });
  }
});

async function resetLoopMidi() {
  const buttons = [el.resetLoopMidiButton, el.resetLoopMidiBannerButton];
  buttons.forEach((button) => {
    button.disabled = true;
    button.textContent = 'Resetting...';
  });

  try {
    const result = await window.bridgeGui.resetLoopMidi();
    appendLog({
      type: 'info',
      text: `loopMIDI restarted${result.Pid ? ` with PID ${result.Pid}` : ''}.`,
      at: new Date().toISOString(),
    });
    hideRecovery();
    setTimeout(refresh, 600);
  } catch (error) {
    appendLog({
      type: 'error',
      text: `loopMIDI reset failed: ${error.message || error}`,
      at: new Date().toISOString(),
    });
  } finally {
    buttons.forEach((button) => {
      button.disabled = false;
      button.textContent = 'Reset loopMIDI';
    });
  }
}

el.resetLoopMidiButton.addEventListener('click', resetLoopMidi);
el.resetLoopMidiBannerButton.addEventListener('click', resetLoopMidi);

el.clearLogButton.addEventListener('click', () => {
  el.logOutput.textContent = '';
});

el.minimizeWindow.addEventListener('click', () => windowControls.minimize());
el.maximizeWindow.addEventListener('click', async () => {
  const windowState = await windowControls.toggleMaximize();
  setWindowState(windowState);
});
el.closeWindow.addEventListener('click', () => windowControls.close());
el.windowTitlebar.addEventListener('dblclick', (event) => {
  if (event.target.closest('.window-controls')) return;
  windowControls.toggleMaximize().then(setWindowState);
});

window.bridgeGui.onLog(appendLog);
window.bridgeGui.onStatus(renderStatus);
window.bridgeGui.onRecovery(showRecovery);
windowControls.onState(setWindowState);
windowControls.getState().then(setWindowState);

refresh();
setInterval(refresh, 5000);
