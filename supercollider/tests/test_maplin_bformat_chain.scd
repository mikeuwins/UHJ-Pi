// MaplinMatrix B-Format Chain Test Script
// Tests: Stereo → MaplinMatrix → B-format encode → B-format decode → Quad output
// Uses GUI-controlled synth like test_maplin_live.scd for proper metering

(
// Server configuration
s.options.numInputBusChannels = 2;   // Stereo input
s.options.numOutputBusChannels = 4;  // Quad output
s.options.memSize = 65536;

s.reboot;

s.waitForBoot({
    
    "=== MaplinMatrix B-Format Chain Test ===".postln;
    "Testing: Stereo → MaplinMatrix → B-format → Quad".postln;
    "".postln;
    
    "Loading ATK encoders and decoders...".postln;
    
    // Wait for server then create the test
    AppClock.sched(2.0, {
        
        "Creating MaplinMatrix with B-format chain...".postln;
        
        // Set audio card volume
        ("amixer -c HD set PCM 80%").unixCmd;
        "✓ Audio card volume set to 80%".postln;
        
        // Create server meter for final output
        AppClock.sched(1.0, {
            ~meter = ServerMeter(s, 2, 4);  // 2 inputs, 4 outputs
            "✓ Server meter created - shows final ATK order output".postln;
            nil;
        });
        
        // Create the combined processing synth with GUI control
        AppClock.sched(2.0, {
            
            "Creating MaplinMatrix + B-format chain synth...".postln;
            
            // Create synth that does MaplinMatrix → B-format → output
            ~bFormatTest = {
                var stereoInput, maplinQuad, bFormatEncoded, quadDecoded;
                var encoder, decoder;
                
                // 1. Stereo input from audio interface
                stereoInput = SoundIn.ar([0, 1]);
                
                // 2. MaplinMatrix: stereo → quad processing
                maplinQuad = MaplinMatrix.ar(
                    leftIn: stereoInput[0],
                    rightIn: stereoInput[1],
                    surroundLevel: \surroundLevel.kr(0.8),
                    effectLevel: \effectLevel.kr(0.8),
                    delayTime: \delayTime.kr(0.4),
                    active: \active.kr(1)
                );
                
                // 3. Encode quad to B-format using conventional quad angles
                // MaplinMatrix outputs [FL, FR, RL, RR] = [-45°, 45°, -135°, 135°]
                encoder = FoaEncoderMatrix.newDirections([-45, 45, -135, 135].degrad);
                bFormatEncoded = FoaEncode.ar(maplinQuad, encoder);
                
                // 4. Decode B-format to quad using square decoder
                decoder = FoaDecoderMatrix.newQuad;
                quadDecoded = FoaDecode.ar(bFormatEncoded, decoder);
                
                // Output to speakers in ATK order: FL=0, RL=1, RR=2, FR=3
                Out.ar(0, quadDecoded);
                
            }.play;
            
            "✓ MaplinMatrix + B-format synth created".postln;
            nil;
        });
        
        // Create MaplinMatrix GUI to control the synth
        AppClock.sched(3.0, {
            ~maplinGUI = MaplinMatrix.gui(~bFormatTest);
            "✓ MaplinMatrix GUI opened - controls B-format chain".postln;
            nil;
        });
        
        "".postln;
        "=== B-FORMAT CHAIN TEST ACTIVE ===".postln;
        "Signal Path:".postln;
        "  1. Stereo input → MaplinMatrix (GUI controlled)".postln;
        "  2. MaplinMatrix quad → B-format encoding".postln;
        "  3. B-format → quad decoding → speakers".postln;
        "".postln;
        "Output: ATK order FL=0, RL=1, RR=2, FR=3".postln;
        "GUI: MaplinMatrix controls work + meters functional".postln;
        "Server Meter: Shows final quad output levels".postln;
        "".postln;
        
        nil;
    });
    
    nil;
});
)

// Clean up
// ~maplinGUI.close; ~bFormatTest.free; ~meter.remove; 