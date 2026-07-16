# lorenz_osc

Chaotic attractor MIDI over OSC, based on `lorenz`.

The script keeps the original attractor visualization and optional crow CV outputs, but adds an OSC MIDI layer for driving a PC through the `osc-midi-bridge` tool. It can generate notes from Lorenz, Rossler, Sprott-Linz F, and Halvorsen attractors.

## Quick Start

- Start the PC bridge on port `7123`.
- On norns, open `PARAMS > EDIT` and choose the OSC target: `Amma` or `MakeMake`.
- Press `K1`, or start Ableton Link transport, to start OSC MIDI generation.

## Controls

- `K1`: start/stop OSC MIDI.
- Ableton Link start/stop also starts/stops OSC MIDI through norns transport callbacks.
- `K1+E1`: adjust simulation speed (`dt`).
- `E1`: adjust sigma/a.
- `E2`: adjust rho/b.
- `E3`: adjust beta/c.
- `K2`: switch selected crow output.
- `K2+E3`: adjust selected crow output attenuation.
- `K2+K3`: cycle attractor.
- `K3`: randomize attractor parameters.

## OSC MIDI Params

- `output`: `osc`, `crow`, or `osc + crow`.
- `OSC target`: `Amma` (`192.168.178.220`) or `MakeMake` (`192.168.178.231`).
- `PC IP`: manual override for the OSC destination IP.
- `OSC port`: default `7123`.
- `MIDI channel`: default `1`.
- `send OSC test note`: sends middle C through the bridge.

## Attractor MIDI Params

- `trigger mode`: clocked, x crossing, turning point, or distance.
- `note source`: x, y, z, distance, or orbit.
- `note division`: tempo-synced note trigger interval.
- `probability`: chance of emitting a note on each trigger.
- `note length %`: note duration relative to the selected division.
- `activity threshold`: threshold used by distance trigger mode.
- `velocity min/max`: MIDI velocity range.
- `avoid repeats`: nudges repeated notes to the next scale degree.
- `scale`, `root note`, `octave span`: pitch mapping. Defaults to C minor pentatonic across two octaves.

## Crow Outputs

When `output` includes crow:

- `OUT1`: x coordinate (-5V to 5V).
- `OUT2`: y coordinate (-5V to 5V).
- `OUT3`: z coordinate (-5V to 5V).
- `OUT4`: distance from origin (0V to 5V).
