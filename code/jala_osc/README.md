# jala_osc

Local OSC-output version of `jala`.

This keeps JALA's simple probabilistic melody behavior, but replaces hardware MIDI output with OSC messages for `tools/osc-midi-bridge.ps1`.

Default OSC target:

```text
PC IP:     192.168.178.220
OSC port:  7123
Channel:   1
```

Run the bridge on the PC before launching:

```powershell
.\tools\osc-midi-bridge.ps1 -MidiOutIndex 6 -ListenPort 7123 -VerbosePackets
```

Set `output` to `osc` or `audio + osc` in the norns params.
