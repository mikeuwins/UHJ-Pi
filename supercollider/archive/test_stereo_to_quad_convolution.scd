s.options.memSize = 262144; // Increase if needed
s.reboot;

s.waitForBoot {
    var irPath = Platform.userHomeDir ++ "/UHJ-Pi/assets/impulse-responses/maplin/";
    var bufNames = ["LtoLF", "LtoRF", "LtoLR", "LtoRR", "RtoLF", "RtoRF", "RtoLR", "RtoRR"];
    var bufs = Array.newClear(8);
    var loaded = 0;
    var fftSize = 2048; // For 16,384-sample IRs

    bufNames.do { |name, i|
        Buffer.read(s, irPath ++ name ++ ".aiff", action: { |buf|
            bufs[i] = buf;
            loaded = loaded + 1;
            if (loaded == 8) {
                // Print buffer info and first 10 samples for debugging
                bufs.do { |b, j| 
                    ("Buffer " ++ j ++ ": " ++ b.numFrames).postln;
                    b.getn(0, 10, { |data| ("First 10 samples of buffer " ++ j ++ ": " ++ data).postln; });
                    if (b.numFrames != 16384) {
                        ("WARNING: Buffer " ++ j ++ " is not 16384 samples!").warn;
                    }
                };
                // All buffers loaded, define and play Synth
                SynthDef(\stereoToQuadPartConv, {
                    var in = SoundIn.ar([0, 1]);
                    var lf = PartConv.ar(in[0], fftSize, bufs[0]) + PartConv.ar(in[1], fftSize, bufs[4]);
                    var rf = PartConv.ar(in[0], fftSize, bufs[1]) + PartConv.ar(in[1], fftSize, bufs[5]);
                    var lr = PartConv.ar(in[0], fftSize, bufs[2]) + PartConv.ar(in[1], fftSize, bufs[6]);
                    var rr = PartConv.ar(in[0], fftSize, bufs[3]) + PartConv.ar(in[1], fftSize, bufs[7]);
                    Out.ar(0, [lf, rf, lr, rr]);
                }).add;
                AppClock.sched(0.2, {
                    Synth(\stereoToQuadPartConv);
                    "All IRs loaded and PartConv synth started.".postln;
                    nil;
                });
            }
        });
    };
};

// Minimal impulse IR PartConv test
