// Simple test to check if server boots
"Testing server boot...".postln;

s.boot;
s.waitForBoot({
    "Server booted successfully!".postln;
    "Server running: ".post; s.serverRunning.postln;
    "Sample rate: ".post; s.sampleRate.postln;
    "Output channels: ".post; s.options.numOutputBusChannels.postln;
    "Input channels: ".post; s.options.numInputBusChannels.postln;
    
    // Test a simple synth
    SynthDef(\test, { |freq = 440|
        Out.ar(0, SinOsc.ar(freq) * 0.1);
    }).add;
    
    "Test synth defined".postln;
    "Server boot test complete!".postln;
});

