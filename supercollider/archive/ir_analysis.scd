// IR Analysis Script - Check if your Maplin IRs are different enough

s.waitForBoot {
    var basePath = Platform.userHomeDir +/+ "UHJ-Pi/assets/impulse-responses/maplin/";
    var irPaths = ["LtoLF.aiff", "LtoLR.aiff", "LtoRF.aiff", "LtoRR.aiff", "RtoLF.aiff", "RtoLR.aiff", "RtoRF.aiff", "RtoRR.aiff"];
    var irBuffers;
    
    // Load all IRs
    irBuffers = irPaths.collect { |path|
        Buffer.read(s, basePath +/+ path);
    };
    
    s.sync;
    
    // Analyze each IR
    "=== IR ANALYSIS ===".postln;
    irPaths.do { |path, i|
        var buffer = irBuffers[i];
        var data;
        
        // Get first 100 samples to check initial response
        buffer.getn(0, 100, { |samples|
            var maxVal = samples.maxItem;
            var rms = (samples.squared.mean).sqrt;
            var nonZeroCount = samples.count { |s| s.abs > 0.001 };
            
            ("\n" ++ path ++ ":").postln;
            ("  Max amplitude: " ++ maxVal.round(0.001)).postln;
            ("  RMS: " ++ rms.round(0.001)).postln;
            ("  Non-zero samples in first 100: " ++ nonZeroCount).postln;
            ("  First 10 samples: " ++ samples[0..9].round(0.001)).postln;
        });
    };
    
    // Create a simple test to hear IR differences
    SynthDef(\irTest, {
        var impulse = Impulse.ar(0.5);  // Impulse every 2 seconds
        var conv1 = PartConv.ar(impulse, 2048, irBuffers[0].bufnum, 0.5);  // LtoLF
        var conv2 = PartConv.ar(impulse, 2048, irBuffers[1].bufnum, 0.5);  // LtoLR
        var conv3 = PartConv.ar(impulse, 2048, irBuffers[2].bufnum, 0.5);  // LtoRF
        var conv4 = PartConv.ar(impulse, 2048, irBuffers[3].bufnum, 0.5);  // LtoRR
        
        // Output each IR response to different channels
        Out.ar(0, conv1);  // LtoLF
        Out.ar(1, conv2);  // LtoLR
        Out.ar(2, conv3);  // LtoRF
        Out.ar(3, conv4);  // LtoRR
    }).add;
    
    s.sync;
    
    "".postln;
    "=== IR TEST ===".postln;
    "Run this to hear IR differences:".postln;
    "~irTest = Synth(\\irTest);".postln;
    "~irTest.free;  // to stop".postln;
    "".postln;
    "You should hear different impulse responses every 2 seconds:".postln;
    "Channel 0: LtoLF, Channel 1: LtoLR, Channel 2: LtoRF, Channel 3: LtoRR".postln;
    
    ~irTest = { Synth(\irTest); };
    ~stopIrTest = { ~irTest.free; };

    // Load and analyze the Maplin IR files
    ~irPaths = [
        "assets/impulse-responses/b-format/rir_jack_lyons_lp1_96k_44k.wav"
    ];

    // Load the IR file
    ~irBuffer = Buffer.read(s, ~irPaths[0], action: {
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