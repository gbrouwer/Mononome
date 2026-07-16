# OSC MIDI Bridge GUI

Small Electron control panel for `tools/osc-midi-bridge.ps1`.

Run from this folder:

```powershell
npm install
npm start
```

Build a portable Windows executable:

```powershell
npm run dist
```

The executable is written to `dist\NornsOSCBridge-0.1.0-portable.exe`.

Build an installer instead:

```powershell
npm run dist:installer
```

The GUI can:

- list Windows MIDI output devices
- check for `loopMIDI`
- check whether the selected virtual port exists
- check whether UDP port `7123` is available
- start/stop the OSC MIDI bridge
- send a local test note to the running bridge
- reset `loopMIDI` if Windows leaves the virtual MIDI output in a stale state
- detect `midiOutShortMsg failed with code 1` and show a recovery action
