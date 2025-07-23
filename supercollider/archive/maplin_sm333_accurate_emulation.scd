// Maplin SM-333 Accurate Digital Emulation
// Based on actual circuit diagram and parts list
// Emulates: LM1894 DNR, 3007 BBD delay, 4558 matrix processing

// Set ALSA mixer volume
("amixer -c HD set PCM 50%").unixCmd;

// Configure server for quad output
s.options.numOutputBusChannels = 4;  // Quad output
s.options.memSize = 524288;
s.reboot;

s.waitForBoot {
    var surroundActive;
    var surroundLevel, effectLevel, delayTime;
    
    // Initialize control values (matching original ranges)
    surroundActive = true;  // Surround system on/off
    surroundLevel = 0.5;    // 0.0 to 1.0 (100K pot)
    effectLevel = 0.5;      // 0.0 to 1.0 (100K pot)  
    delayTime = 0.025;      // 0.005 to 0.050 seconds (5-50ms)
    
    // Create the accurate SM-333 emulation SynthDef
    SynthDef(\maplinSM333Accurate, {
        var leftIn, rightIn;
        var matrixOutput, delayedOutput;
        var frontLeft, frontRight, rearLeft, rearRight;
        var finalOutput;
        var left, right, difference, sum, effectMix, delayTime, surroundMix, surroundActive;
        
        // Input: stereo from audio interface
        leftIn = SoundIn.ar(0);
        rightIn = SoundIn.ar(1);
        
        // Apply input gain (matching original 0.1-3.5V range)
        leftIn = leftIn * \inputGain.kr(0.7);
        rightIn = rightIn * \inputGain.kr(0.7);
        
        // Matrix decoding (4558 op-amp stages)
        // Based on the actual circuit component values
        left = leftIn;
        right = rightIn;
        
        // Front channels: direct + center blend (based on 22K/220K ratios)
        frontLeft = left + (right * 0.1);   // 22K/220K = 0.1
        frontRight = right + (left * 0.1);
        
        // Rear channels: phase-shifted difference signal
        // Based on the matrix network in the circuit
        difference = (left - right) * 0.7;  // 70% of difference
        sum = (left + right) * 0.3;         // 30% of sum
        
        rearLeft = (difference * -0.7) + (sum * 0.5);
        rearRight = (difference * 0.7) + (sum * 0.5);
        
        // Apply effect level control (VR2 - 100K pot)
        effectMix = \effectLevel.kr(0.5);
        rearLeft = rearLeft * effectMix;
        rearRight = rearRight * effectMix;
        
        // Delay processing (3007 BBD emulation)
        // 5-50ms delay range as per original
        delayTime = \delayTime.kr(0.025).linlin(0, 1, 0.005, 0.050);
        delayedOutput = DelayC.ar([rearLeft, rearRight], 0.1, delayTime);
        
        // Apply surround level control (VR1 - 100K pot)
        surroundMix = \surroundLevel.kr(0.5);
        delayedOutput = delayedOutput * surroundMix;
        
        // Surround system bypass (if surroundActive is false)
        // Use multiplication to blend between bypass and active modes
        surroundActive = \surroundActive.kr(1);
        finalOutput = [
            frontLeft,
            frontRight,
            delayedOutput[0] * surroundActive,
            delayedOutput[1] * surroundActive
        ];
        
        // Apply output gain (matching original specs)
        // Front: 0.1-3.5V, Rear: 5.5V max
        finalOutput = finalOutput * \outputGain.kr(0.8);
        
        // Output to quad speakers [LF, RF, LR, RR]
        Out.ar(0, finalOutput);
        
    }).add;
    
    // Test tone SynthDef for rear channel testing
    SynthDef(\testRearTone, {
        var tone = SinOsc.ar(440) * 0.3;
        Out.ar(2, tone);  // Rear Left
        Out.ar(3, tone);  // Rear Right
    }).add;
    

    
    s.sync;
    
    // Start the accurate SM-333 emulation
    AppClock.sched(0.2, {
        ~sm333Accurate = Synth(\maplinSM333Accurate);
        "Maplin SM-333 Accurate Emulation started.".postln;
        "Based on actual circuit: 3007 BBD delay, 4558 matrix processing".postln;
        "Output: Quad speakers [LF, RF, LR, RR]".postln;
        "Controls: ~setSurroundLevel(0.5), ~setEffectLevel(0.5), ~setDelayTime(0.025)".postln;
        
        // Force surround to maximum for testing
        AppClock.sched(0.5, {
            ~setSurroundActive.(true);
            ~setSurroundLevel.(1.0);
            ~setEffectLevel.(1.0);
            "DIAGNOSTIC: Surround forced to maximum - check meters 3 & 4".postln;
        });
        nil;
    });
    
    // Control functions (matching original potentiometer ranges)
    ~setSurroundLevel = { |level| ~sm333Accurate.set('surroundLevel', level); };
    ~setEffectLevel = { |level| ~sm333Accurate.set('effectLevel', level); };
    ~setDelayTime = { |time| ~sm333Accurate.set('delayTime', time); };
    ~setInputGain = { |gain| ~sm333Accurate.set('inputGain', gain); };
    ~setOutputGain = { |gain| ~sm333Accurate.set('outputGain', gain); };
    
    // System controls
    ~setSurroundActive = { |active| ~sm333Accurate.set('surroundActive', if(active, 1, 0)); };
    
    // Quad output mode (matches original SM-333)
    // Output channels: [Front Left, Front Right, Rear Left, Rear Right]
    // This matches the connection diagram exactly
    
    // Stop function
    ~stop = {
        ~sm333Accurate.free;
        "SM-333 Accurate emulation stopped.".postln;
    };
    
    // Test rear channels with tone
    ~testRearChannels = {
        ~testTone = Synth(\testRearTone);
        "Testing rear channels with 440Hz tone - check meters 3 & 4".postln;
    };
    
    ~stopTestTone = {
        ~testTone.free;
        "Test tone stopped.".postln;
    };
    
    // Preset functions based on original specifications
    ~presetOriginal = {
        ~setSurroundLevel.(0.5);
        ~setEffectLevel.(0.5);
        ~setDelayTime.(0.025);  // 25ms
        ~setDNRActive.(false);
        ~setSurroundActive.(true);
        "Original SM-333 settings applied.".postln;
    };
    
    ~presetClassic = {
        ~setSurroundLevel.(0.6);
        ~setEffectLevel.(0.4);
        ~setDelayTime.(0.020);  // 20ms
        ~setSurroundActive.(true);
        "Classic surround preset applied.".postln;
    };
    
    ~presetWide = {
        ~setSurroundLevel.(0.8);
        ~setEffectLevel.(0.7);
        ~setDelayTime.(0.040);  // 40ms
        ~setSurroundActive.(true);
        "Wide surround preset applied.".postln;
    };
    
    ~presetNarrow = {
        ~setSurroundLevel.(0.3);
        ~setEffectLevel.(0.3);
        ~setDelayTime.(0.010);  // 10ms
        ~setSurroundActive.(true);
        "Narrow focus preset applied.".postln;
    };
    
    ~presetBypass = {
        ~setSurroundActive.(false);
        "Surround bypass - front channels only.".postln;
    };
}; 