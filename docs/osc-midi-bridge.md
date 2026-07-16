# OSC MIDI Bridge

This is a no-grid test path for sending notes from norns to Ableton over the network:

```text
norns Lua script -> OSC over UDP -> PC bridge -> Windows MIDI output -> Ableton MIDI input
```

On Windows, Ableton needs a MIDI input port. The clean path is a virtual MIDI port such as `loopMIDI`. The bridge sends to the Windows MIDI output side of that virtual port; Ableton receives from the input side.

## 1. List MIDI Outputs

From this repo:

```powershell
.\tools\osc-midi-bridge.ps1 -ListDevices
```

Pick the virtual MIDI output port index. If no virtual port exists yet, create one first. A physical output such as `Focusrite USB MIDI` sends to the DIN output jack, not directly into Ableton.

## 2. Start The Bridge

For the small Electron control panel:

```powershell
cd .\apps\osc-midi-bridge-gui
npm install
npm start
```

The GUI lists MIDI outputs, checks for loopMIDI, checks UDP port `7123`, starts/stops the bridge, can send a test note, and can reset loopMIDI if Windows leaves the virtual MIDI output in a stale state.

To build the portable Windows executable:

```powershell
cd .\apps\osc-midi-bridge-gui
npm run dist
```

Then launch:

```powershell
.\dist\NornsOSCBridge-0.1.0-portable.exe
```

For the raw PowerShell bridge, use the selected index:


```powershell
.\tools\osc-midi-bridge.ps1 -MidiOutIndex 1
```

Or by partial device name:

```powershell
.\tools\osc-midi-bridge.ps1 -MidiOutName loopMIDI
```

The bridge prints local PC IP candidates. Use the IP on the same network as norns, usually something like `192.168.x.x`.

## 3. Push The Test Script To Norns

```powershell
.\tools\norns-push.ps1 -Name osc_midi_test
```

Then launch `osc_midi_test` on norns.

In norns params, set:

```text
PC IP:     your PC IP printed by the bridge
OSC port:  7123
Channel:   1
```

Press `K3` to send one note or `K2` to start/stop the test pattern.

## 4. Ableton

In Ableton:

```text
Preferences > Link, Tempo & MIDI
```

Enable `Track` for the virtual MIDI input port.

Create a MIDI track:

```text
MIDI From: virtual MIDI port
Channel:  1
Monitor:  In
```

Put an instrument on the track. The MIDI meter should move when norns sends notes.

## OSC Message Contract

The bridge accepts:

```text
/midi/note     note velocity channel duration_ms
/midi/note_on  note velocity channel
/midi/note_off note velocity channel
/midi/cc       cc value channel
```

All MIDI values are clamped to valid ranges. `/midi/note` automatically sends note off after `duration_ms`.
