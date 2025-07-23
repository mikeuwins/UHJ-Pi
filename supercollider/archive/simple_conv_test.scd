// PartConv Test Script - Based on Official SuperCollider Documentation
// This follows the exact workflow from the PartConv help file

s.options.memSize = 262144;
s.reboot;

s.waitForBoot {
    var fftsize = 2048;  // Official example uses 2048
    var irbuffer, bufsize, irspectrum;
    var irPath;
    
    // Use a real Maplin IR file
    irPath = Platform.userHomeDir +/+ "UHJ-Pi/assets/impulse-responses/maplin/LtoLF.aiff";
    
    // Load the IR file
    ~irBuffer = Buffer.read(s, "assets/impulse-responses/b-format/rir_jack_lyons_lp1_96k_44k.wav", action: {
        "IR loaded successfully".postln;
        "IR length: % samples".format(~irBuffer.numFrames).postln;
        "IR channels: %".format(~irBuffer.numChannels).postln;
        "IR sample rate: %".format(~irBuffer.sampleRate).postln;
        
        // Check first 20 samples
        "First 20 samples:".postln;
        ~irBuffer.loadToFloatArray(action: { |array|
            var firstNonZero, hasNonZero;
            
            array[0..19].do { |sample, i|
                "Sample %: %".format(i, sample).postln;
            };
            
            // Find first non-zero sample
            firstNonZero = array.detectIndex { |sample| sample != 0 };
            "First non-zero sample at index: %".format(firstNonZero).postln;
            
            // Check if there are any non-zero samples
            hasNonZero = array.any { |sample| sample != 0 };
            "Has non-zero samples: %".format(hasNonZero).postln;
        });
    });
    
    s.sync;
    
    // Print info about the loaded IR
    ("Loaded IR: " ++ irPath).postln;
    ("IR frames: " ++ irbuffer.numFrames).postln;
    ("IR channels: " ++ irbuffer.numChannels).postln;
    
    // Calculate buffer size for PartConv
    bufsize = PartConv.calcBufSize(fftsize, irbuffer);
    ("PartConv buffer size: " ++ bufsize).postln;
    
    // Allocate and prepare the PartConv buffer
    irspectrum = Buffer.alloc(s, bufsize, 1);
    irspectrum.preparePartConv(irbuffer, fftsize);
    
    s.sync;
    
    // Free the original IR buffer (we only need the spectral version)
    irbuffer.free;
    
    // Create SynthDef for PartConv
    SynthDef(\partConvTest, {
        var input = WhiteNoise.ar(0.1);  // Test with white noise
        var output = PartConv.ar(input, fftsize, irspectrum.bufnum, 0.5);
        Out.ar(0, output ! 2);  // Stereo output
    }).add;
    
    s.sync;
    
    // Start the test
    AppClock.sched(0.2, {
        Synth(\partConvTest);
        "PartConv test started with real Maplin IR.".postln;
        "You should hear white noise convolved with LtoLF transfer function.".postln;
        nil;
    });
    
    // Cleanup function
    ~cleanup = {
        irspectrum.free;
        "PartConv buffers freed.".postln;
    };

    // Create a test with impulse signals
    SynthDef(\impulseTest, {
        var impulse, convolved;
        
        // Create an impulse every 2 seconds
        impulse = Impulse.ar(0.5);
        
        // Convolve with the IR
        convolved = PartConv.ar(impulse, 2048, ~irBuffer.bufnum, 0.5);
        
        // Output to stereo
        Out.ar(0, [convolved, convolved]);
    }).add;

    // Test function
    ~testImpulse = {
        ~impulseTest = Synth(\impulseTest);
        "Playing impulse test - you should hear the IR response".postln;
    };

    ~stopImpulse = {
        ~impulseTest.free;
        "Impulse test stopped".postln;
    };
};

