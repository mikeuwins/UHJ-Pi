// Create Test B-Format Impulse Responses
// This script generates simple test impulse responses for the PSEUDO encoder

(
s.boot;

s.waitForBoot({
    var irPath, sampleRate, duration, numSamples, writeCount, totalToWrite, createIR;
    
    // Initialize variables
    irPath = "assets/impulse-responses/b-format/";
    sampleRate = 44100;
    duration = 0.5;
    numSamples = (sampleRate * duration).asInteger;
    writeCount = 0;
    totalToWrite = 4;
    
    // Create directory if it doesn't exist
    ("mkdir -p " ++ irPath).unixCmd;
    
    // Create spatially distinct test IRs with simple but audible differences
    createIR = { |filename, baseFreq, decayRate|
        var buffer, signal, i;
        buffer = Buffer.alloc(s, numSamples, 1);
        signal = FloatArray.fill(numSamples, 0);
        
        // Create a simple tone with decay - each IR has different frequency and decay
        numSamples.do({ |i|
            signal[i] = sin(2 * pi * baseFreq * i / sampleRate) * (i / (sampleRate * decayRate)).neg.exp * 0.8;
        });
        
        buffer.loadCollection(signal, action: {
            // Use proper WAV format parameters based on SuperCollider documentation
            buffer.write(irPath ++ filename, "WAV", "int16", 0, 0, true, {
                ("Created: " ++ filename).postln;
                buffer.free;
                writeCount = writeCount + 1;
            });
        });
        buffer;
    };
    
    // Create the 4 spatially distinct test IRs with different frequencies and decay rates
    
    // W (omnidirectional) - low frequency, slow decay
    createIR.value("test_ir_w.wav", 200, 0.3);
    
    // X (front-back) - mid frequency, medium decay  
    createIR.value("test_ir_x.wav", 800, 0.2);
    
    // Y (left-right) - high frequency, fast decay
    createIR.value("test_ir_y.wav", 1500, 0.1);
    
    // Z (up-down) - very high frequency, very fast decay
    createIR.value("test_ir_z.wav", 3000, 0.05);
    
    // Wait for all writes to finish (up to 5 seconds)
    Routine({
        var waited = 0;
        while({ writeCount < totalToWrite and: { waited < 5 } }, {
            0.2.wait;
            waited = waited + 0.2;
        });
        if(writeCount == totalToWrite) {
            "Test B-format impulse responses created successfully!".postln;
        } {
            ("Warning: Only " ++ writeCount ++ " of " ++ totalToWrite ++ " files written!").postln;
        };
        "Files saved to: ".postln;
        irPath.postln;
        "Done!".postln;
    }).play;
});
) 