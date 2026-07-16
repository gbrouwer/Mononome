# Colossus for norns

Colossus is a wide, slowly evolving drone instrument for norns and norns shield.

## Sound architecture

- **Root:** seven slowly drifting oscillators spread around the root pitch
- **Foundation:** centred sub-octaves for low-frequency mass
- **Fifth:** independently mixable voices at +7 semitones
- **Octave:** independently mixable voices at +12 semitones
- **Minor ninth:** independently mixable voices at +13 semitones
- Slow left/right filter movement, saturation, stereo decorrelation and long reverb
- Octave-up shimmer feedback and a near-infinite **Freeze** state
- Optional slow evolution of the interval balance and filter

The detune control spreads each cluster by small fractions of a semitone. The four harmonic levels are independent, so a patch can be consonant, hollow, bright or deliberately tense without choosing a fixed chord preset.

## Factory and user presets

Colossus includes 12 factory presets:

- Cathedral
- Glacier
- Black Sun
- Choir
- Minor Void
- Distant Machinery
- Deep Ocean
- Ascension
- Ember Field
- Glass Tundra
- Orbital Choir
- Sleeping Giant

It also provides **100 user slots**. User preset names are generated from two curated word lists, such as `Obsidian Weather` or `Distant Temple`. Before accepting a name, the script checks all factory and user names, so duplicate names are not generated.

Preset loading can be immediate or morphed over 2, 8 or 30 seconds. Drone and Freeze are performance states and are deliberately not stored in these presets. All sound controls remain ordinary norns parameters, so the normal PARAMETERS menu and standard norns PSET workflow remain available as well.

## Install

1. Copy the complete `colossus` folder to:

   ```text
   /home/we/dust/code/colossus
   ```

2. On norns, run **SYSTEM > RESTART** so SuperCollider recompiles the bundled custom engine.
3. Launch **SELECT > colossus > colossus**.

Do not keep another copy of `Engine_Colossus.sc` elsewhere under `dust/code`; duplicate custom engine class names can prevent SuperCollider from compiling.

## Main instrument controls

- **E1:** root note
- **E2:** select the displayed parameter
- **E3:** change the selected parameter
- **K2:** freeze/unfreeze
- **Hold K2:** open the preset browser
- **K3:** start/stop the drone

## Preset browser

- **K1:** switch between Factory and User banks
- **E1:** select a preset slot
- **E2:** jump through slots; by ten in the User bank
- **E3:** choose Immediate, Morph 2 s, Morph 8 s or Morph 30 s
- **K2:** load the selected preset
- **Hold K2:** leave the preset browser
- **K3:** generate another name for the selected user slot
- **Hold K3:** save or overwrite the selected user slot

Existing user slots preserve their names unless K3 is used to reroll before saving. Factory presets are read-only.

## First sound

Start quietly. Load **Cathedral**, press K3 and allow several seconds for the amplitude and reverb envelopes to open. Freeze is intentionally close to self-sustaining, so reduce the output before combining it with high shimmer feedback.

## User preset files

User presets are stored as readable Lua data files under the norns data directory:

```text
/home/we/dust/data/colossus/presets/
```

Each slot is a separate numbered file, making backups and transfers straightforward.

## Troubleshooting

- **Engine not found:** confirm the folder structure and run **SYSTEM > RESTART**.
- **Duplicate engine/class error:** delete every other copy of `Engine_Colossus.sc`.
- **No sound:** press K3 and check the norns mixer output and headphone levels.
- **SC compile error:** inspect Maiden's `sc` tab and verify that the engine file was transferred as plain text.
- **CPU trouble:** reduce shimmer first; pitch shifting and diffusion are the most expensive parts.

## Validation status

The Lua script passes a norns Lua 5.1 syntax check. The SuperCollider engine compiles on the norns shield with a temporary clean library configuration, and has passed structural, routing, command-interface and feedback-safety checks. It has not yet been auditioned as a loaded norns script on physical hardware, so Maiden's `sc` log and an on-device listening pass remain the definitive integration tests.

## Changelog

### 0.2.0

- Replaced fixed halo chord choices with independent Root, Fifth, Octave and Minor Ninth levels.
- Expanded the synthesis engine with lightly detuned interval clusters.
- Added 12 factory presets.
- Added 100 user preset slots.
- Added automatic unique two-word preset names.
- Added immediate, 2-second, 8-second and 30-second preset morphing.
- Added a long-press preset browser interface.
- Preset saves exclude transient Drone and Freeze states.
- Evolution now moves the interval balance and filter instead of switching fixed chords.

## Validation details

Performed in the artifact-generation environment:

- Simulated norns runtime initialization: passed.
- Norns encoder/key interaction smoke test: passed.
- User-slot save test for slots 001 and 002: passed.
- Generated-name uniqueness check across two saved slots: passed.
- Lua-to-SuperCollider command parity check: passed.
- Standalone DSP smoke test: passed.
- AddressSanitizer and UndefinedBehaviourSanitizer DSP run: passed.

Performed on the norns shield:

- Lua 5.1 syntax check with `/usr/bin/luac`: passed.
- SuperCollider class-library compile check for `Engine_Colossus.sc`: passed.

Not performed in this environment:

- Listening and CPU profiling on a norns shield.

Those remain the definitive integration tests.
