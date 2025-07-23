// Stereo-to-Quad Convolution System using Maplin IRs
// Uses PartConv for efficient real-time convolution with long IRs
// Includes B-format encoding and binaural decoding

// Set ALSA mixer volume to maximum
("amixer -c HD set PCM 80%").unixCmd;

// Configure server for binaural output
s.options.numOutputBusChannels = 2;  // Set to 2 outputs for binaural
s.options.memSize = 524288;  // Increased memory for multiple convolutions
s.reboot;

s.waitForBoot {
    var fftsize = 2048;
    var irPaths, irBuffers, partConvBuffers;
    var basePath;
    var quadEncoder;
    
    // Create binaural decoder for final output
    var binauralDecoder = FoaDecoderKernel.newListen(1053);
    
    // Create quad encoder for B-format encoding
    // ATK standard quad positions: FL(45°), FR(-45°), RL(135°), RR(-135°)
    quadEncoder = FoaEncoderMatrix.newQuad(pi/4, k: 'dual');
    
    // Base path for IR files
    basePath = "assets/impulse-responses/maplin/";
    
    // Define all 8 IR file paths (stereo to quad transfer functions)
    irPaths = [
        "LtoLF.aiff",  // Left input to Left-Front output
        "LtoLR.aiff",  // Left input to Left-Rear output  
        "LtoRF.aiff",  // Left input to Right-Front output
        "LtoRR.aiff",  // Left input to Right-Rear output
        "RtoLF.aiff",  // Right input to Left-Front output
        "RtoLR.aiff",  // Right input to Left-Rear output
        "RtoRF.aiff",  // Right input to Right-Front output
        "RtoRR.aiff"   // Right input to Right-Rear output
    ];
    
    // Load all IR buffers
    irBuffers = irPaths.collect { |path|
        Buffer.read(s, basePath +/+ path);
    };
    
    s.sync;
    
    // Prepare PartConv buffers for all IRs
    partConvBuffers = irBuffers.collect { |irBuffer|
        var bufsize = PartConv.calcBufSize(fftsize, irBuffer);
        var partConvBuffer = Buffer.alloc(s, bufsize, 1);
        partConvBuffer.preparePartConv(irBuffer, fftsize);
        partConvBuffer;
    };
    
    s.sync;
    
    // Free original IR buffers (we only need the spectral versions)
    irBuffers.do { |buf| buf.free; };
    
    // Create the main stereo-to-quad convolution with B-format encoding SynthDef
    SynthDef(\stereoToQuadConv, {
        var leftIn, rightIn;
        var leftToLF, leftToLR, leftToRF, leftToRR;
        var rightToLF, rightToLR, rightToRF, rightToRR;
        var leftFront, leftRear, rightFront, rightRear;
        var quadOutput, bFormat, binauralOutput;
        
        // Input: stereo from audio interface
        leftIn = SoundIn.ar(0);
        rightIn = SoundIn.ar(1);
        
        // Apply input gain
        leftIn = leftIn * \inputGain.kr(0.5);
        rightIn = rightIn * \inputGain.kr(0.5);
        
        // Convolve left input with all 4 transfer functions
        leftToLF = PartConv.ar(leftIn, fftsize, partConvBuffers[0].bufnum, 0.5);
        leftToLR = PartConv.ar(leftIn, fftsize, partConvBuffers[1].bufnum, 0.5);
        leftToRF = PartConv.ar(leftIn, fftsize, partConvBuffers[2].bufnum, 0.5);
        leftToRR = PartConv.ar(leftIn, fftsize, partConvBuffers[3].bufnum, 0.5);
        
        // Convolve right input with all 4 transfer functions
        rightToLF = PartConv.ar(rightIn, fftsize, partConvBuffers[4].bufnum, 0.5);
        rightToLR = PartConv.ar(rightIn, fftsize, partConvBuffers[5].bufnum, 0.5);
        rightToRF = PartConv.ar(rightIn, fftsize, partConvBuffers[6].bufnum, 0.5);
        rightToRR = PartConv.ar(rightIn, fftsize, partConvBuffers[7].bufnum, 0.5);
        
        // Sum the contributions to each output channel
        leftFront = leftToLF + rightToLF;
        leftRear = leftToLR + rightToLR;
        rightFront = leftToRF + rightToRF;
        rightRear = leftToRR + rightToRR;
        
        // Apply output gain
        leftFront = leftFront * \outputGain.kr(0.7);
        leftRear = leftRear * \outputGain.kr(0.7);
        rightFront = rightFront * \outputGain.kr(0.7);
        rightRear = rightRear * \outputGain.kr(0.7);
        
        // Create quad output array [LF, RF, LR, RR] - matching ATK convention
        quadOutput = [leftFront, rightFront, leftRear, rightRear];
        
        // Encode to B-format using FoaEncodeMatrix
        bFormat = FoaEncode.ar(quadOutput, quadEncoder);
        
        // Decode B-format to binaural using FoaDecoderKernel
        binauralOutput = FoaDecode.ar(bFormat, binauralDecoder);
        
        // Output binaural (stereo) to channels 0,1
        Out.ar(0, binauralOutput);
        
    }).add;
    
    // Create diagnostic SynthDefs to test different stages
    SynthDef(\testQuadOnly, {
        var leftIn, rightIn;
        var leftToLF, leftToLR, leftToRF, leftToRR;
        var rightToLF, rightToLR, rightToRF, rightToRR;
        var leftFront, leftRear, rightFront, rightRear;
        
        // Input: stereo from audio interface
        leftIn = SoundIn.ar(0);
        rightIn = SoundIn.ar(1);
        
        // Apply input gain
        leftIn = leftIn * \inputGain.kr(0.5);
        rightIn = rightIn * \inputGain.kr(0.5);
        
        // Convolve left input with all 4 transfer functions
        leftToLF = PartConv.ar(leftIn, fftsize, partConvBuffers[0].bufnum, 0.5);
        leftToLR = PartConv.ar(leftIn, fftsize, partConvBuffers[1].bufnum, 0.5);
        leftToRF = PartConv.ar(leftIn, fftsize, partConvBuffers[2].bufnum, 0.5);
        leftToRR = PartConv.ar(leftIn, fftsize, partConvBuffers[3].bufnum, 0.5);
        
        // Convolve right input with all 4 transfer functions
        rightToLF = PartConv.ar(rightIn, fftsize, partConvBuffers[4].bufnum, 0.5);
        rightToLR = PartConv.ar(rightIn, fftsize, partConvBuffers[5].bufnum, 0.5);
        rightToRF = PartConv.ar(rightIn, fftsize, partConvBuffers[6].bufnum, 0.5);
        rightToRR = PartConv.ar(rightIn, fftsize, partConvBuffers[7].bufnum, 0.5);
        
        // Sum the contributions to each output channel
        leftFront = leftToLF + rightToLF;
        leftRear = leftToLR + rightToLR;
        rightFront = leftToRF + rightToRF;
        rightRear = leftToRR + rightToRR;
        
        // Apply output gain
        leftFront = leftFront * \outputGain.kr(0.7);
        leftRear = leftRear * \outputGain.kr(0.7);
        rightFront = rightFront * \outputGain.kr(0.7);
        rightRear = rightRear * \outputGain.kr(0.7);
        
        // Output quad directly (bypass B-format encoding/decoding)
        Out.ar(0, [leftFront, rightFront, leftRear, rightRear]);
        
    }).add;
    
    SynthDef(\testBFormatOnly, {
        var leftIn, rightIn;
        var quadOutput, bFormat, binauralOutput;
        
        // Input: stereo from audio interface
        leftIn = SoundIn.ar(0);
        rightIn = SoundIn.ar(1);
        
        // Apply input gain
        leftIn = leftIn * \inputGain.kr(0.5);
        rightIn = rightIn * \inputGain.kr(0.5);
        
        // Create simple quad output [LF, RF, LR, RR] without convolution
        quadOutput = [leftIn, rightIn, leftIn, rightIn] * \outputGain.kr(0.7);
        
        // Encode to B-format using FoaEncodeMatrix
        bFormat = FoaEncode.ar(quadOutput, quadEncoder);
        
        // Decode B-format to binaural using FoaDecoderKernel
        binauralOutput = FoaDecode.ar(bFormat, binauralDecoder);
        
        // Output binaural (stereo) to channels 0,1
        Out.ar(0, binauralOutput);
        
    }).add;
    
    s.sync;
    
    // Start the stereo-to-quad convolution with B-format encoding and binaural decoding
    AppClock.sched(0.2, {
        ~stereoToQuad = Synth(\stereoToQuadConv);
        "Stereo-to-Binaural convolution system started.".postln;
        "Input: Stereo from audio interface (channels 0,1)".postln;
        "Output: Binaural (stereo) on channels 0,1".postln;
        "Use ~stereoToQuad.set('inputGain', value) to adjust input level".postln;
        "Use ~stereoToQuad.set('outputGain', value) to adjust output level".postln;
        "Use ~stop to stop the system".postln;
        nil;
    });
    
    // Cleanup function
    ~cleanup = {
        ~stereoToQuad.free;
        partConvBuffers.do { |buf| buf.free; };
        "Stereo-to-Binaural system stopped and buffers freed.".postln;
    };
    
    // Control functions
    ~setInputGain = { |gain| ~stereoToQuad.set('inputGain', gain); };
    ~setOutputGain = { |gain| ~stereoToQuad.set('outputGain', gain); };
    ~stop = { ~cleanup.value; };
    
    // Diagnostic functions
    ~testQuadOnly = { 
        ~stereoToQuad.free;
        ~stereoToQuad = Synth(\testQuadOnly);
        "Testing QUAD ONLY (bypass B-format encoding/decoding)".postln;
        "You should hear spatial differences in the quad outputs".postln;
    };
    
    ~testBFormatOnly = { 
        ~stereoToQuad.free;
        ~stereoToQuad = Synth(\testBFormatOnly);
        "Testing B-FORMAT ONLY (bypass convolution)".postln;
        "You should hear basic spatial encoding/decoding".postln;
    };
    
    ~testFull = { 
        ~stereoToQuad.free;
        ~stereoToQuad = Synth(\stereoToQuadConv);
        "Testing FULL SYSTEM (convolution + B-format + binaural)".postln;
    };
    
    ~stop = { 
        ~stereoToQuad.free;
        partConvBuffers.do { |buf| buf.free; };
        "System stopped and buffers freed.".postln;
    };
}; 