// Update v19 System for Multichannel B-format IR Loading
// This script shows the changes needed to use multichannel WAV files

// === CHANGES NEEDED IN UHJ_Ambisonic_System_v19_convolution.scd ===

// 1. REPLACE the separate IR loading section (around line 693-700):
/*
OLD CODE (separate files):
~spatialIRs = [
    Buffer.read(s, "~/UHJ-Pi/assets/impulse-responses/b-format/test_ir_w.wav", 
        action: { |buf| ("Loaded W IR: " ++ buf.numFrames ++ " frames").postln; }),
    Buffer.read(s, "~/UHJ-Pi/assets/impulse-responses/b-format/test_ir_x.wav", 
        action: { |buf| ("Loaded X IR: " ++ buf.numFrames ++ " frames").postln; }),
    Buffer.read(s, "~/UHJ-Pi/assets/impulse-responses/b-format/test_ir_y.wav", 
        action: { |buf| ("Loaded Y IR: " ++ buf.numFrames ++ " frames").postln; }),
    Buffer.read(s, "~/UHJ-Pi/assets/impulse-responses/b-format/test_ir_z.wav", 
        action: { |buf| ("Loaded Z IR: " ++ buf.numFrames ++ " frames").postln; })
];
*/

/*
NEW CODE (multichannel file):
~spatialIRBuffer = Buffer.read(s, "~/UHJ-Pi/assets/impulse-responses/b-format/your_openair_room_44k.wav", 
    action: { |buf| 
        ("Loaded multichannel B-format IR: " ++ buf.numChannels ++ " channels, " ++ 
         buf.numFrames ++ " frames, " ++ buf.sampleRate ++ " Hz").postln;
    });
*/

// 2. REPLACE the convolution processing section (around line 548-555):
/*
OLD CODE (separate buffers):
convolvedEncode = [
    PartConv.ar(basicEncode[0], 2048, ~spatialIRs[0]), // W (omnidirectional)
    PartConv.ar(basicEncode[1], 2048, ~spatialIRs[1]), // X (front-back)
    PartConv.ar(basicEncode[2], 2048, ~spatialIRs[2]), // Y (left-right)
    PartConv.ar(basicEncode[3], 2048, ~spatialIRs[3])  // Z (up-down)
];
*/

/*
NEW CODE (multichannel buffer):
convolvedEncode = [
    PartConv.ar(basicEncode[0], 2048, ~spatialIRBuffer.bufnum, 0), // W (channel 0)
    PartConv.ar(basicEncode[1], 2048, ~spatialIRBuffer.bufnum, 1), // X (channel 1)
    PartConv.ar(basicEncode[2], 2048, ~spatialIRBuffer.bufnum, 2), // Y (channel 2)
    PartConv.ar(basicEncode[3], 2048, ~spatialIRBuffer.bufnum, 3)  // Z (channel 3)
];
*/

// === COMPLETE UPDATED SECTIONS ===

// Updated IR loading section:
/*
// Load spatial impulse responses for pseudo-surround convolution
// Single multichannel B-format file (WXYZ order, Furse-Malham)
~spatialIRBuffer = Buffer.read(s, "~/UHJ-Pi/assets/impulse-responses/b-format/your_openair_room_44k.wav", 
    action: { |buf| 
        if(buf.numChannels == 4, {
            ("✓ Loaded multichannel B-format IR: " ++ buf.numChannels ++ " channels, " ++ 
             buf.numFrames ++ " frames, " ++ buf.sampleRate ++ " Hz").postln;
            ("✓ Channel order: W(0), X(1), Y(2), Z(3) - Furse-Malham/ATK standard").postln;
        }, {
            ("ERROR: Expected 4 channels, got " ++ buf.numChannels).postln;
            ("This is not a valid B-format file!").postln;
        });
    });
*/

// Updated convolution processing section:
/*
if(configKeyE == \pseudosurround, {
    // Use convolution-based spatialization for pseudo-surround
    var basicEncode, convolvedEncode, dry, wet, mix = 0.7;
    
    // Basic encoding first
    basicEncode = FoaEncode.ar(eqed, encoder);
    
    // Apply convolution to each B-format component using multichannel IR
    // Channel order: 0=W, 1=X, 2=Y, 3=Z (Furse-Malham/ATK standard)
    convolvedEncode = [
        PartConv.ar(basicEncode[0], 2048, ~spatialIRBuffer.bufnum, 0), // W (omnidirectional)
        PartConv.ar(basicEncode[1], 2048, ~spatialIRBuffer.bufnum, 1), // X (front-back)
        PartConv.ar(basicEncode[2], 2048, ~spatialIRBuffer.bufnum, 2), // Y (left-right)
        PartConv.ar(basicEncode[3], 2048, ~spatialIRBuffer.bufnum, 3)  // Z (up-down)
    ];
    
    // Mix dry (basic) and wet (convolved) signals
    encode = (basicEncode * (1 - mix)) + (convolvedEncode * mix);
}, {
    // Standard encoding for UHJ and SuperStereo
    encode = FoaEncode.ar(eqed, encoder);
});
*/

// === BENEFITS OF MULTICHANNEL APPROACH ===

/*
1. CLEANER: Single file instead of 4 separate files
2. PROFESSIONAL: Standard B-format format (WXYZ interleaved)
3. EFFICIENT: Single buffer load operation
4. CONSISTENT: All channels guaranteed to be same length/sample rate
5. PORTABLE: Easier to share and manage IR collections
6. STANDARD: Matches OpenAIR and other B-format libraries
*/

// === TESTING THE CONVERSION ===

// Test script to verify the converted IR works:
/*
(
s.boot;
s.waitForBoot({
    var testBuffer = Buffer.read(s, "~/UHJ-Pi/assets/impulse-responses/b-format/your_openair_room_44k.wav");
    
    testBuffer.loadToFloatArray(action: { |array|
        var numChannels = testBuffer.numChannels;
        var numFrames = testBuffer.numFrames;
        
        ("=== IR Verification ===").postln;
        ("Channels: " ++ numChannels).postln;
        ("Frames: " ++ numFrames).postln;
        ("Sample rate: " ++ testBuffer.sampleRate ++ " Hz").postln;
        ("Duration: " ++ (numFrames / testBuffer.sampleRate).round(0.01) ++ " seconds").postln;
        
        // Check for non-zero data in each channel
        numChannels.do({ |ch|
            var hasData = false;
            numFrames.do({ |i|
                if(array[i * numChannels + ch].abs > 0.001, { hasData = true; });
            });
            var channelName = switch(ch, 0, "W", 1, "X", 2, "Y", 3, "Z");
            ("Channel " ++ ch ++ " (" ++ channelName ++ "): " ++ if(hasData, "✓ Has data", "✗ No data")).postln;
        });
        
        testBuffer.free;
    });
});
)
*/ 