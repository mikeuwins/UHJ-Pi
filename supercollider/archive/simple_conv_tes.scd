s.options.memSize = 262144;
s.reboot;

s.waitForBoot {
    var b = Buffer.alloc(s, 16384, 1);
    b.set(0, 1.0); // Set first sample to 1.0 (impulse)
    SynthDef(\testImpulseConv, {
        var in = WhiteNoise.ar(0.1) ! 2;
        var out = PartConv.ar(in, 2048, b);
        Out.ar(0, out ! 2);
    }).add;
    AppClock.sched(0.2, {
        Synth(\testImpulseConv);
        "Impulse IR PartConv test started.".postln;
        nil;
    });
};
