// UHJ v27 Style Test - Copy exact server setup approach
// This copies the exact server initialization from the working UHJ v27 app

(
var outputs = 8; // Match HD interface
var inputs = 2;  // Match Phonorama

// Use exact same server setup as UHJ v27
if(s.serverRunning.not, {
    s.options.memSize = 65536; // Exact same as UHJ v27
    s.options.numOutputBusChannels = outputs;
    s.options.numInputBusChannels = inputs;
    s.boot;
    
    s.waitForBoot({
        "Server booted - UHJ v27 style".postln;
        
        // Create player bus (same as UHJ v27)
        ~playerBus = Bus.audio(s, 4); // 4-channel for B-format
        
        // Simple test tone first
        ~testSynth = {
            var tone = SinOsc.ar(440, 0, 0.1);
            Out.ar(0, tone); // Left
            Out.ar(1, tone); // Right
        }.play;
        
        "Test tone playing - check for audio signal".postln;
        "If you hear audio, press any key to stop tone and test B-format...".postln;
    });
});
)
