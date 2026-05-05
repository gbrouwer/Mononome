// Engine_Repeater.sc
// Repeater Orchestra - multiple tempo-synced delay lines with random timing, gain, and panning
// Ported from https://codepen.io/barefootfunk/pen/ZWoLmo

Engine_Repeater : CroneEngine {
    classvar <numDelays = 50;   // Restored to 50 delays
    var <synth;
    var <buffers;               // Array of buffers for delays
    var <activeDelays = 20;     // currently active delays
    var <tempo = 80;            // BPM
    var <maxEighths = 60;       // max eighth notes for delay
    var <minGain = 0.2;
    var <maxGain = 2.0;
    var <gate = 0;
    var <inputGain = 0.5;
    var <masterGain = 0.5;
    var <dryWet = 1.0;
    var <delayEighths;          // array of random eighth note counts per delay
    var <delayGains;            // array of random gains per delay
    var <delayPans;             // array of pans per delay

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        var maxDelayTime = 25.0; // Fixed max delay time

        // Allocate buffers
        buffers = Array.fill(numDelays, {
            Buffer.alloc(context.server, context.server.sampleRate * maxDelayTime);
        });
        context.server.sync;

        // Initialize random arrays
        this.generateRandomParams;

        // Main SynthDef with fixed number of delays
        SynthDef(\repeater, { |gate = 0, freeze = 0, inputGain = 0.5, masterGain = 0.5, dryWet = 1.0, activeDelays = 20|
            var input, delays, output, dry;
            var nDelays = 50; // must match classvar numDelays
            var bufnums = NamedControl.kr(\bufnums, (0..nDelays-1).asArray);
            var decayTime = Select.kr(freeze, [0, 1000]); // 0 = single repeat, 1000 = infinite loop

            // Stereo input summed to mono, gated
            // When freezing, we mute the input to the delays so we only hear the loop
            input = SoundIn.ar([0, 1]).sum * Lag.kr(gate, 0.1) * inputGain * (1 - Lag.kr(freeze, 0.1));

            // Create delay lines
            delays = Array.fill(nDelays, { |i|
                var delayTime = NamedControl.kr(("delayTime" ++ i).asSymbol, 1);
                var gain = NamedControl.kr(("gain" ++ i).asSymbol, 0.5);
                var pan = NamedControl.kr(("pan" ++ i).asSymbol, 0);
                var isActive = (i < activeDelays);
                
                // Use BufCombL for delay with feedback (freeze)
                // decayTime 0 -> feedback 0 -> acts like BufDelayL (one repeat)
                var delayed = BufCombL.ar(bufnums[i], input, delayTime.clip(0.01, maxDelayTime), decayTime);
                
                Pan2.ar(delayed * gain * isActive, pan);
            }).sum;

            // Dry path (direct input, louder for monitoring)
            // Independent of gate to allow playing over the loop or using as insert effect
            dry = Pan2.ar(SoundIn.ar([0, 1]).sum * inputGain * 4, 0);

            // Mix delays and dry signal
            output = (delays * dryWet) + (dry * (1 - dryWet));

            // Compressor - Tuned to match Web Audio API defaults (Aggressive)
            output = Compander.ar(
                output * masterGain,
                output * masterGain,
                thresh: 0.1,        // -20dB (was 0.5) - catches quieter signals
                slopeBelow: 1,
                slopeAbove: 0.1,    // 10:1 Ratio (was 0.3) - squashes loud peaks, bringing up the tail
                clampTime: 0.003,   // Fast attack
                relaxTime: 0.25     // Slower release to sustain the cloud
            );

            // Final limiter
            output = Limiter.ar(output, 0.95);

            Out.ar(0, output);
        }).add;

        context.server.sync;

        // Create the synth with current parameters
        this.createSynth;

        // --- Commands ---

        // Gate on/off (1 or 0)
        this.addCommand(\gate, "i", { |msg|
            gate = msg[1];
            synth.set(\gate, gate);
        });

        // Freeze on/off (1 or 0)
        this.addCommand(\freeze, "i", { |msg|
            synth.set(\freeze, msg[1]);
        });

        // Input gain (0-1)
        this.addCommand(\inputGain, "f", { |msg|
            inputGain = msg[1];
            synth.set(\inputGain, inputGain);
        });

        // Master gain (0-1)
        this.addCommand(\masterGain, "f", { |msg|
            masterGain = msg[1];
            synth.set(\masterGain, masterGain);
        });

        // Dry/Wet Mix (0-1)
        this.addCommand(\dryWet, "f", { |msg|
            dryWet = msg[1];
            synth.set(\dryWet, dryWet);
        });

        // Set tempo (recalculates and updates delay times)
        this.addCommand(\tempo, "f", { |msg|
            tempo = msg[1];
            this.updateDelayTimes;
        });

        // Set number of active delays
        this.addCommand(\nDelays, "i", { |msg|
            activeDelays = msg[1].clip(1, numDelays);
            synth.set(\activeDelays, activeDelays);
        });

        // Randomize all delay parameters
        this.addCommand(\randomize, "", {
            this.generateRandomParams;
            this.updateAllParams;
        });

        // Clear delays (recreate synth to clear buffers)
        // Note: With BufDelayL, we should clear the buffers, not just recreate synth.
        this.addCommand(\clear, "", {
             buffers.do({ |b| b.zero });
        });
    }

    generateRandomParams {
        delayEighths = Array.fill(numDelays, { (1..maxEighths).choose });
        delayGains = Array.fill(numDelays, { rrand(minGain, maxGain) });
        delayPans = Array.fill(numDelays, { |i| (i % 10) / 5 - 1 }); // spread -1 to 1
    }

    calcDelayTime { |eighths|
        ^(eighths * 60 / tempo / 2);
    }

    getDelayParams {
        var params = [];
        numDelays.do { |i|
            params = params.add(("delayTime" ++ i).asSymbol);
            params = params.add(this.calcDelayTime(delayEighths[i]));
            params = params.add(("gain" ++ i).asSymbol);
            params = params.add(delayGains[i]);
            params = params.add(("pan" ++ i).asSymbol);
            params = params.add(delayPans[i]);
        };
        ^params;
    }

    updateDelayTimes {
        numDelays.do { |i|
            synth.set(("delayTime" ++ i).asSymbol, this.calcDelayTime(delayEighths[i]));
        };
    }

    updateAllParams {
        numDelays.do { |i|
            synth.set(
                ("delayTime" ++ i).asSymbol, this.calcDelayTime(delayEighths[i]),
                ("gain" ++ i).asSymbol, delayGains[i],
                ("pan" ++ i).asSymbol, delayPans[i]
            );
        };
    }

    createSynth {
        synth = Synth.new(\repeater, [
            \gate, gate,
            \inputGain, inputGain,
            \masterGain, masterGain,
            \dryWet, dryWet,
            \activeDelays, activeDelays,
            \bufnums, buffers.collect(_.bufnum)
        ] ++ this.getDelayParams, context.xg);
    }

    recreateSynth {
        synth.free;
        context.server.sync;
        this.createSynth;
    }

    free {
        synth.free;
        buffers.do(_.free);
    }
}
