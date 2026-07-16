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
                body = 0.72,
                foundation = 0.55,
                halo = 0.34,
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
                freeze = 0,
                haloRatio1 = 1.5,
                haloRatio2 = 2.0;

            var positions;
            var movementRate;
            var bodyVoices;
            var bodySignal;
            var foundationSignal;
            var haloVoices;
            var haloSignal;
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

            bodyVoices = Array.fill(7, { arg i;
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

            bodySignal = Splay.ar(
                bodyVoices,
                spread: width,
                level: body,
                center: 0,
                levelComp: true
            );

            foundationSignal = (
                SinOsc.ar(freq * 0.5, mul: 0.30)
                + SinOsc.ar(freq * 0.25, mul: 0.13)
                + LFTri.ar(freq, mul: 0.055)
            ) * foundation;
            foundationSignal = foundationSignal ! 2;

            haloVoices = [
                SinOsc.ar(
                    freq * haloRatio1
                    * LFNoise2.kr(movementRate * 0.81).range(0.997, 1.003),
                    Rand(0, 2pi),
                    0.16
                ),
                VarSaw.ar(
                    freq * haloRatio2
                    * LFNoise2.kr(movementRate * 0.63).range(0.996, 1.004),
                    Rand(0, 1),
                    LFNoise2.kr(0.013).range(0.22, 0.72),
                    0.10
                ),
                BPF.ar(
                    PinkNoise.ar(0.085),
                    (freq * haloRatio2 * 4).clip(300, 9000),
                    0.18
                )
            ];

            haloSignal = Splay.ar(
                haloVoices,
                spread: width,
                level: halo,
                center: LFNoise2.kr(0.018).range(-0.25, 0.25) * width,
                levelComp: true
            );

            source = bodySignal + foundationSignal + haloSignal;
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
            \body, 0.72,
            \foundation, 0.55,
            \halo, 0.34,
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
            \freeze, 0,
            \haloRatio1, 1.5,
            \haloRatio2, 2.0
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
