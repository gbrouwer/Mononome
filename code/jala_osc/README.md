# jala_osc

Local OSC-output version of `jala`.

This keeps JALA's simple probabilistic melody behavior, but replaces hardware MIDI output with OSC messages for `tools/osc-midi-bridge.ps1`.

Default OSC target:

```text
OSC target: Amma
PC IP:      192.168.178.220
OSC port:  7123
Channel:   1
```

The `OSC target` option switches between:

```text
Amma:     192.168.178.220
MakeMake: 192.168.178.231
```

Run the bridge on the PC before launching:

```powershell
.\tools\osc-midi-bridge.ps1 -MidiOutIndex 6 -ListenPort 7123 -VerbosePackets
```

Set `output` to `osc` or `audio + osc` in the norns params.

Playback is gated by norns transport. With Ableton Link transport enabled, Live start/stop will start and stop note generation. Press `K2` on the norns to start/stop locally without Ableton. The OSC test note still sends immediately so the bridge can be checked while transport is stopped.
