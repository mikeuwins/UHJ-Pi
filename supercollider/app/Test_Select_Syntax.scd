// Test Select.ar syntax to isolate the issue
// Run this first to test basic Select.ar functionality

(
// Use same server setup as working tests
var outputs = 8;
var inputs = 2;

if(s.serverRunning.not, {
    s.options.memSize = 65536;
    s.options.numOutputBusChannels = outputs;
    s.options.numInputBusChannels = inputs;
    s.boot;
    
    s.waitForBoot({
        "Server booted - testing Select.ar...".postln;
        
        // Test 1: Simple Select with constants
        {
            var w = SinOsc.ar(440, 0, 0.1);
            var zPrime = SinOsc.ar(880, 0, 0.1);
            var output;
            
            "Testing Select.ar with constants...".postln;
            output = Select.ar(0, [w, zPrime]); // Should select w (440Hz)
            
            Out.ar(0, output);
        }.play;
        
        "Select.ar test playing - should hear 440Hz tone".postln;
    });
});
)