Engine_Colossus : CroneEngine {
    var synth;
    var group;
    var values;

    alloc {
        SynthDef(\colossusDrone, {
            arg out = 0,
                gate = 1,
                freq = 55,
                amp = 0.26,
                rootLevel = 0.72,
                foundation = 0.55,
                fifthLevel = 0.28,
                octaveLevel = 0.22,
                minorNinthLevel = 0.08,
                detune = 18,
                movement = 0.32,
                width = 0.82,
                cutoff = 2400,
                resonance = 0.22,
                drive = 1.35,
                reverbMix = 0.72,
                decay = 0.88,
                damping = 0.38,
                shimmer = 0.30,
                shimmerFeedback = 0.34,
                freeze = 0;

            var positions;
            var movementRate;
            var rootVoices;
            var rootSignal;
            var foundationSignal;
            var fifthVoices;
            var fifthSignal;
            var octaveVoices;
            var octaveSignal;
            var minorNinthVoices;
            var minorNinthSignal;
            var air;
            var source;
            var driven;
            var filterDepth;
            var leftCutoff;
            var rightCutoff;
            var rq;
            var filtered;
            var haas;
            var wide;
            var freezeLag;
            var feedbackIn;
            var reverbInput;
            var diffused;
            var wet;
            var shifted;
            var shimmerWet;
            var normalFeedback;
            var frozenFeedback;
            var feedbackSignal;
            var space;
            var envelope;
            var signal;

            positions = [-1, -0.67, -0.34, 0, 0.31, 0.64, 1];
            movementRate = movement.linexp(0, 1, 0.004, 0.12);

            // Seven slowly drifting voices form the root/body cluster.
            rootVoices = Array.fill(7, { arg i;
                var driftCents;
                var oscillatorFrequency;
                var saw;
                var sine;

                driftCents = LFNoise2.kr(
                    movementRate * (0.74 + (i * 0.13))
                ).range(movement * -3.5, movement * 3.5);

                oscillatorFrequency = freq * (
                    ((positions[i] * detune) + driftCents) / 100
                ).midiratio;

                saw = VarSaw.ar(
                    oscillatorFrequency,
                    Rand(0, 1),
                    LFNoise2.kr(0.008 + (i * 0.002)).range(0.34, 0.66),
                    0.11
                );

                sine = SinOsc.ar(
                    oscillatorFrequency,
                    Rand(0, 2pi),
                    0.075
                );

                saw + sine;
            });

            rootSignal = Splay.ar(
                rootVoices,
                spread: width,
                level: rootLevel,
                center: 0,
                levelComp: true
            );

            // Sub-octaves stay near the centre so the low end remains solid.
            foundationSignal = (
                SinOsc.ar(freq * 0.5, mul: 0.30)
                + SinOsc.ar(freq * 0.25, mul: 0.13)
                + LFTri.ar(freq, mul: 0.055)
            ) * foundation;
            foundationSignal = foundationSignal ! 2;

            // Each harmonic interval gets its own lightly detuned mini-cluster.
            fifthVoices = Array.fill(3, { arg i;
                var position = i - 1;
                var cents = (position * detune * 0.34)
                    + LFNoise2.kr(movementRate * (0.61 + (i * 0.11)))
                    .range(movement * -2.0, movement * 2.0);
                var oscillatorFrequency = freq * 7.midiratio * (cents / 100).midiratio;

                SinOsc.ar(oscillatorFrequency, Rand(0, 2pi), 0.12)
                + VarSaw.ar(oscillatorFrequency, Rand(0, 1), 0.48, 0.045);
            });

            fifthSignal = Splay.ar(
                fifthVoices,
                spread: width * 0.84,
                level: fifthLevel,
                center: -0.08,
                levelComp: true
            );

            octaveVoices = Array.fill(3, { arg i;
                var position = i - 1;
                var cents = (position * detune * 0.27)
                    + LFNoise2.kr(movementRate * (0.53 + (i * 0.09)))
                    .range(movement * -1.8, movement * 1.8);
                var oscillatorFrequency = freq * 2 * (cents / 100).midiratio;

                SinOsc.ar(oscillatorFrequency, Rand(0, 2pi), 0.105)
                + VarSaw.ar(oscillatorFrequency, Rand(0, 1), 0.42, 0.035);
            });

            octaveSignal = Splay.ar(
                octaveVoices,
                spread: width,
                level: octaveLevel,
                center: 0.10,
                levelComp: true
            );

            minorNinthVoices = Array.fill(2, { arg i;
                var position = (i * 2) - 1;
                var cents = (position * detune * 0.22)
                    + LFNoise2.kr(movementRate * (0.47 + (i * 0.12)))
                    .range(movement * -1.5, movement * 1.5);
                var oscillatorFrequency = freq * 13.midiratio * (cents / 100).midiratio;

                SinOsc.ar(oscillatorFrequency, Rand(0, 2pi), 0.10)
                + VarSaw.ar(oscillatorFrequency, Rand(0, 1), 0.36, 0.028);
            });

            minorNinthSignal = Splay.ar(
                minorNinthVoices,
                spread: width,
                level: minorNinthLevel,
                center: LFNoise2.kr(0.014).range(-0.22, 0.22) * width,
                levelComp: true
            );

            air = BPF.ar(
                PinkNoise.ar(0.032 * (octaveLevel + minorNinthLevel + 0.08)),
                (freq * 8).clip(700, 7800),
                0.22
            ) ! 2;

            source = rootSignal
                + foundationSignal
                + fifthSignal
                + octaveSignal
                + minorNinthSignal
                + air;

            driven = (source * drive).tanh / drive.sqrt.max(1);

            filterDepth = movement.linlin(0, 1, 0, 0.46);
            leftCutoff = (
                cutoff * LFNoise2.kr(movementRate * 0.91)
                .range(1 - filterDepth, 1 + filterDepth)
            ).clip(45, 18000);
            rightCutoff = (
                cutoff * LFNoise2.kr(movementRate * 1.07)
                .range(1 - filterDepth, 1 + filterDepth)
            ).clip(45, 18000);
            rq = resonance.linlin(0, 1, 1, 0.075);

            filtered = [
                RLPF.ar(driven[0], leftCutoff, rq),
                RLPF.ar(driven[1], rightCutoff, rq)
            ];

            haas = [
                DelayC.ar(filtered[0], 0.035, 0.004 + (width * 0.004)),
                DelayC.ar(filtered[1], 0.035, 0.010 + (width * 0.006))
            ];

            wide = filtered + (haas * width * 0.34);
            wide = wide + (
                AllpassC.ar(
                    wide,
                    0.09,
                    [0.017, 0.029]
                    + (LFNoise2.kr([0.031, 0.027]).range(-0.004, 0.004) * width),
                    2.4
                ) * width * 0.24
            );

            freezeLag = Lag.kr(freeze, 0.25);
            feedbackIn = LocalIn.ar(2);
            reverbInput = (wide * (1 - freezeLag)) + feedbackIn;

            diffused = reverbInput;
            4.do({ arg i;
                diffused = AllpassC.ar(
                    diffused,
                    0.11,
                    [
                        0.011 + (i * 0.007),
                        0.016 + (i * 0.009)
                    ],
                    2.1 + (i * 0.55)
                );
            });

            wet = FreeVerb2.ar(
                diffused[0],
                diffused[1],
                mix: 1,
                room: decay.linlin(0, 1, 0.48, 1),
                damp: damping
            );

            shifted = PitchShift.ar(
                wet,
                windowSize: 0.24,
                pitchRatio: 2,
                pitchDispersion: 0.012,
                timeDispersion: 0.025
            );

            shimmerWet = AllpassC.ar(
                shifted,
                0.12,
                [0.031, 0.047],
                4.5
            );

            normalFeedback = shimmerWet
                * shimmer
                * shimmerFeedback.clip(0, 0.92);

            frozenFeedback = (
                (wet * 0.94)
                + (shimmerWet * shimmer * 0.20)
            ) * 0.992;

            feedbackSignal = XFade2.ar(
                normalFeedback,
                frozenFeedback,
                freezeLag.linlin(0, 1, -1, 1)
            );

            feedbackSignal = LPF.ar(
                LeakDC.ar(feedbackSignal),
                damping.linlin(0, 1, 13000, 2200)
            );
            feedbackSignal = HPF.ar(feedbackSignal, 30);
            feedbackSignal = Limiter.ar(feedbackSignal, 0.95, 0.02);
            LocalOut.ar(feedbackSignal);

            space = wet + (shimmerWet * shimmer);
            signal = XFade2.ar(
                wide,
                space,
                reverbMix.linlin(0, 1, -1, 1)
            );

            envelope = EnvGen.kr(
                Env.asr(3.5, 1, 8.0, curve: -3),
                gate,
                doneAction: 2
            );

            signal = HPF.ar(LeakDC.ar(signal), 24);
            signal = Limiter.ar(signal * envelope * amp, 0.88, 0.05);
            Out.ar(out, signal);
        }).add;

        context.server.sync;
        group = Group.head(context.xg);

        values = Dictionary.newFrom([
            \freq, 55,
            \amp, 0.26,
            \rootLevel, 0.72,
            \foundation, 0.55,
            \fifthLevel, 0.28,
            \octaveLevel, 0.22,
            \minorNinthLevel, 0.08,
            \detune, 18,
            \movement, 0.32,
            \width, 0.82,
            \cutoff, 2400,
            \resonance, 0.22,
            \drive, 1.35,
            \reverbMix, 0.72,
            \decay, 0.88,
            \damping, 0.38,
            \shimmer, 0.30,
            \shimmerFeedback, 0.34,
            \freeze, 0
        ]);

        values.keysDo({ arg key;
            this.addCommand(key, "f", { arg msg;
                var value = msg[1].asFloat;
                values[key] = value;
                if(synth.notNil, {
                    synth.set(key, value);
                });
            });
        });

        this.addCommand(\start, "", {
            if(synth.notNil, {
                synth.set(\gate, 0);
            });
            synth = Synth.new(
                \colossusDrone,
                [\out, context.out_b.index] ++ values.getPairs,
                group
            );
        });

        this.addCommand(\stop, "", {
            if(synth.notNil, {
                synth.set(\gate, 0);
                synth = nil;
            });
        });
    }

    free {
        if(group.notNil, {
            group.freeAll;
            group.free;
            group = nil;
        });
        synth = nil;
    }
}
