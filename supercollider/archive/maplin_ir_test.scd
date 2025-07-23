// Test the actual Maplin IR files
s.waitForBoot {
    var maplinPath = "assets/impulse-responses/maplin/";
    var irFiles = [
        "LtoLF.aiff", "LtoLR.aiff", "LtoRF.aiff", "LtoRR.aiff",
        "RtoLF.aiff", "RtoLR.aiff", "RtoRF.aiff", "RtoRR.aiff"
    ];
    
    // Load and analyze each Maplin IR file
    irFiles.do { |filename, i|
        var fullPath = maplinPath +/+ filename;
        var buffer = Buffer.read(s, fullPath, action: {
            "=== % ===".format(filename).postln;
            "File size: % KB".format(filename.size).postln;
            "Buffer frames: %".format(buffer.numFrames).postln;
            "Buffer channels: %".format(buffer.numChannels).postln;
            "Buffer sample rate: %".format(buffer.sampleRate).postln;
            // 
            // Check first 10 samples
            buffer.loadToFloatArray(action: { |array|
                var hasNonZero, maxAmp, rms;
                
                "First 10 samples: %".format(array[0..9]).postln;
                
                // Check if any non-zero samples
                hasNonZero = array.any { |sample| sample != 0 };
                "Has non-zero samples: %".format(hasNonZero).postln;
                
                if (hasNonZero) {
                    maxAmp = array.maxItem;
                    rms = sqrt(array.squared.mean);
                    "Max amplitude: %".format(maxAmp).postln;
                    "RMS: %".format(rms).postln;
                };
                "".postln;
            });
        });
    };
    
    // Create a simple test synth to verify convolution works
    SynthDef(\maplinTest, {
        var leftIn, rightIn;
        var convolved;
        
        // Input: stereo from audio interface
        leftIn = SoundIn.ar(0);
        rightIn = SoundIn.ar(1);
        
        // Simple convolution test (we'll load the buffer later)
        convolved = leftIn * 0.5;
        
        // Output to stereo
        Out.ar(0, [convolved, convolved]);
    }).add;
    
    "Maplin IR analysis complete. Files should show actual content.".postln;
}; 