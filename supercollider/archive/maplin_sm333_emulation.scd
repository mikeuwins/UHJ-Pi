// Maplin SM-333 Surround Sound Processor Emulation
// Matrix-based quadraphonic decoder with manual controls
// Emulates the vintage analog surround processor

// Set ALSA mixer volume
("amixer -c HD set PCM 80%").unixCmd;

// Configure server for quad output
s.options.numOutputBusChannels = 4;  // Quad output
s.options.memSize = 524288;
s.reboot;

s.waitForBoot {
    var frontLevel, rearLevel, centerLevel, surroundLevel;
    var frontWidth, rearWidth, centerWidth;
    var delayTime, reverbMix;
    
    // Initialize control values (0.0 to 1.0)
    frontLevel = 0.8;    // Front speaker level
    rearLevel = 0.6;     // Rear speaker level  
    centerLevel = 0.4;   // Center channel level
    surroundLevel = 0.7; // Surround channel level
    frontWidth = 0.8;    // Front stereo width
    rearWidth = 0.6;     // Rear stereo width
    centerWidth = 0.3;   // Center channel width
    delayTime = 0.02;    // Delay time for surround effect
    reverbMix = 0.3;     // Reverb mix for ambience
    
    // Create the main SM-333 emulation SynthDef
    SynthDef(\maplinSM333, {
        var leftIn, rightIn;
        var leftFront, rightFront, leftRear, rightRear;
        var center, surround;
        var frontOut, rearOut, centerOut, surroundOut;
        var delayed, reverbed;
        
        // Input: stereo from audio interface
        leftIn = SoundIn.ar(0);
        rightIn = SoundIn.ar(1);
        
        // Apply input gain
        leftIn = leftIn * \inputGain.kr(0.7);
        rightIn = rightIn * \inputGain.kr(0.7);
        
        // Matrix decoding (similar to SQ/QS systems)
        // Front channels: direct + some center
        leftFront = leftIn + (rightIn * \centerWidth.kr(0.3));
        rightFront = rightIn + (leftIn * \centerWidth.kr(0.3));
        
        // Rear channels: phase-shifted and delayed
        leftRear = (leftIn * 0.7) + (rightIn * -0.7);
        rightRear = (rightIn * 0.7) + (leftIn * -0.7);
        
        // Center channel: sum of left and right
        center = (leftIn + rightIn) * 0.5;
        
        // Surround channel: difference signal
        surround = (leftIn - rightIn) * 0.5;
        
        // Apply stereo width controls
        leftFront = leftFront * \frontWidth.kr(0.8);
        rightFront = rightFront * \frontWidth.kr(0.8);
        leftRear = leftRear * \rearWidth.kr(0.6);
        rightRear = rightRear * \rearWidth.kr(0.6);
        
        // Add delay for surround effect
        delayed = DelayC.ar([leftRear, rightRear], 0.1, \delayTime.kr(0.02));
        
        // Add reverb for ambience
        reverbed = FreeVerb.ar(delayed, \reverbMix.kr(0.3), 0.8, 0.5);
        
        // Apply level controls
        frontOut = [leftFront, rightFront] * \frontLevel.kr(0.8);
        rearOut = reverbed * \rearLevel.kr(0.6);
        centerOut = center * \centerLevel.kr(0.4);
        surroundOut = surround * \surroundLevel.kr(0.7);
        
        // Output to quad speakers [LF, RF, LR, RR]
        Out.ar(0, [frontOut[0], frontOut[1], rearOut[0], rearOut[1]]);
        
    }).add;
    
    // Create a binaural version for headphone listening
    SynthDef(\maplinSM333Binaural, {
        var leftIn, rightIn;
        var leftFront, rightFront, leftRear, rightRear;
        var center, surround;
        var frontOut, rearOut, centerOut, surroundOut;
        var delayed, reverbed;
        var quadOutput, bFormat, binauralOutput;
        
        // Input: stereo from audio interface
        leftIn = SoundIn.ar(0);
        rightIn = SoundIn.ar(1);
        
        // Apply input gain
        leftIn = leftIn * \inputGain.kr(0.7);
        rightIn = rightIn * \inputGain.kr(0.7);
        
        // Matrix decoding (same as above)
        leftFront = leftIn + (rightIn * \centerWidth.kr(0.3));
        rightFront = rightIn + (leftIn * \centerWidth.kr(0.3));
        leftRear = (leftIn * 0.7) + (rightIn * -0.7);
        rightRear = (rightIn * 0.7) + (leftIn * -0.7);
        center = (leftIn + rightIn) * 0.5;
        surround = (leftIn - rightIn) * 0.5;
        
        // Apply stereo width controls
        leftFront = leftFront * \frontWidth.kr(0.8);
        rightFront = rightFront * \frontWidth.kr(0.8);
        leftRear = leftRear * \rearWidth.kr(0.6);
        rightRear = rightRear * \rearWidth.kr(0.6);
        
        // Add delay and reverb
        delayed = DelayC.ar([leftRear, rightRear], 0.1, \delayTime.kr(0.02));
        reverbed = FreeVerb.ar(delayed, \reverbMix.kr(0.3), 0.8, 0.5);
        
        // Apply level controls
        frontOut = [leftFront, rightFront] * \frontLevel.kr(0.8);
        rearOut = reverbed * \rearLevel.kr(0.6);
        centerOut = center * \centerLevel.kr(0.4);
        surroundOut = surround * \surroundLevel.kr(0.7);
        
        // Create quad output [LF, RF, LR, RR]
        quadOutput = [frontOut[0], frontOut[1], rearOut[0], rearOut[1]];
        
        // Encode to B-format for binaural decoding
        var quadEncoder = FoaEncoderMatrix.newQuad(pi/4, k: 'dual');
        var binauralDecoder = FoaDecoderKernel.newListen(1053);
        
        bFormat = FoaEncode.ar(quadOutput, quadEncoder);
        binauralOutput = FoaDecode.ar(bFormat, binauralDecoder);
        
        // Output binaural (stereo)
        Out.ar(0, binauralOutput);
        
    }).add;
    
    s.sync;
    
    // Start the SM-333 emulation
    AppClock.sched(0.2, {
        ~sm333 = Synth(\maplinSM333);
        "Maplin SM-333 emulation started.".postln;
        "Output: Quad speakers [LF, RF, LR, RR]".postln;
        "Use control functions to adjust parameters:".postln;
        "~setFrontLevel(0.8), ~setRearLevel(0.6), etc.".postln;
        nil;
    });
    
    // Control functions
    ~setFrontLevel = { |level| ~sm333.set('frontLevel', level); };
    ~setRearLevel = { |level| ~sm333.set('rearLevel', level); };
    ~setCenterLevel = { |level| ~sm333.set('centerLevel', level); };
    ~setSurroundLevel = { |level| ~sm333.set('surroundLevel', level); };
    ~setFrontWidth = { |width| ~sm333.set('frontWidth', width); };
    ~setRearWidth = { |width| ~sm333.set('rearWidth', width); };
    ~setCenterWidth = { |width| ~sm333.set('centerWidth', width); };
    ~setDelayTime = { |time| ~sm333.set('delayTime', time); };
    ~setReverbMix = { |mix| ~sm333.set('reverbMix', mix); };
    ~setInputGain = { |gain| ~sm333.set('inputGain', gain); };
    
    // Switch to binaural mode
    ~switchToBinaural = {
        ~sm333.free;
        s.options.numOutputBusChannels = 2;
        ~sm333 = Synth(\maplinSM333Binaural);
        "Switched to binaural mode for headphones.".postln;
    };
    
    // Switch to quad mode
    ~switchToQuad = {
        ~sm333.free;
        s.options.numOutputBusChannels = 4;
        ~sm333 = Synth(\maplinSM333);
        "Switched to quad mode for speakers.".postln;
    };
    
    // Stop function
    ~stop = {
        ~sm333.free;
        "SM-333 emulation stopped.".postln;
    };
    
    // Preset functions for different "vintage" sounds
    ~presetClassic = {
        ~setFrontLevel.(0.8);
        ~setRearLevel.(0.6);
        ~setCenterLevel.(0.4);
        ~setSurroundLevel.(0.7);
        ~setFrontWidth.(0.8);
        ~setRearWidth.(0.6);
        ~setCenterWidth.(0.3);
        ~setDelayTime.(0.02);
        ~setReverbMix.(0.3);
        "Classic SM-333 preset applied.".postln;
    };
    
    ~presetWide = {
        ~setFrontLevel.(0.7);
        ~setRearLevel.(0.8);
        ~setCenterLevel.(0.2);
        ~setSurroundLevel.(0.9);
        ~setFrontWidth.(1.0);
        ~setRearWidth.(0.8);
        ~setCenterWidth.(0.1);
        ~setDelayTime.(0.03);
        ~setReverbMix.(0.4);
        "Wide surround preset applied.".postln;
    };
    
    ~presetNarrow = {
        ~setFrontLevel.(0.9);
        ~setRearLevel.(0.4);
        ~setCenterLevel.(0.6);
        ~setSurroundLevel.(0.5);
        ~setFrontWidth.(0.6);
        ~setRearWidth.(0.4);
        ~setCenterWidth.(0.5);
        ~setDelayTime.(0.01);
        ~setReverbMix.(0.2);
        "Narrow focus preset applied.".postln;
    };
}; 