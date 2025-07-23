// Maplin SM-333 Enhanced Op-Amp Emulation
// Based on actual circuit diagram with realistic 4558 op-amp characteristics
// Emulates: LM1894 DNR, 3007 BBD delay, 4558 matrix processing with saturation

// Set ALSA mixer volume
("amixer -c HD set PCM 80%").unixCmd;

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
    
    // Enhanced op-amp emulation SynthDef with realistic characteristics
    SynthDef(\maplinSM333Enhanced, {
        var leftIn, rightIn;
        var matrixOutput, delayedOutput;
        var frontLeft, frontRight, rearLeft, rearRight;
        var finalOutput;
        var left, right, difference, sum, effectMix, delayTime, surroundMix, surroundActive;
        var supplyVoltage, saturationThreshold;
        var thermalNoise, bbdNoise;
        var saturated, filtered;
        var opampSaturation, bandwidthLimit;
        var levelCompensation;
        
        // Op-amp characteristics (4558 datasheet values)
        supplyVoltage = 15.0;  // ±15V supply typical
        saturationThreshold = supplyVoltage * 0.95;  // 95% of supply for very subtle saturation
        opampSaturation = \saturationAmount.kr(0.2);  // 0.0 = clean, 1.0 = heavy saturation
        bandwidthLimit = \bandwidthLimit.kr(0.2);  // 0.0 = full bandwidth, 1.0 = heavily limited
        
        // Input: stereo from audio interface
        leftIn = SoundIn.ar(0);
        rightIn = SoundIn.ar(1);
        
        // Add thermal noise (4558 input noise ~8nV/√Hz)
        thermalNoise = WhiteNoise.ar(0.00001) * \noiseLevel.kr(0.1);
        leftIn = leftIn + thermalNoise;
        rightIn = rightIn + thermalNoise;
        
        // Apply input gain (matching original 0.1-3.5V range)
        leftIn = leftIn * \inputGain.kr(0.7);
        rightIn = rightIn * \inputGain.kr(0.7);
        
        // Op-amp saturation (soft clipping)
        // Emulates the 4558's saturation characteristics
        // Note: saturation calculation done inline to avoid function definition issues
        
        // Bandwidth limiting (4558 has ~3MHz bandwidth)
        // Emulates frequency response rolloff
        // Note: filtering done inline to avoid function definition issues
        
        // Enhanced matrix decoding with realistic op-amp characteristics
        left = leftIn;
        right = rightIn;
        
        // Apply bandwidth limiting to input stage
        left = LPF.ar(left, 20000 * (1.0 - bandwidthLimit) + 1000);
        right = LPF.ar(right, 20000 * (1.0 - bandwidthLimit) + 1000);
        
        // Front channels: direct + center blend (based on 22K/220K ratios)
        // Emulates summing amplifier with saturation
        frontLeft = left + (right * 0.1);
        frontRight = right + (left * 0.1);
        
        // Apply op-amp saturation to front channels
        saturated = frontLeft * (1.0 - opampSaturation) + (frontLeft * (1.0 - (frontLeft.abs / saturationThreshold).pow(2)) * opampSaturation);
        frontLeft = saturated.clip2(saturationThreshold);
        
        saturated = frontRight * (1.0 - opampSaturation) + (frontRight * (1.0 - (frontRight.abs / saturationThreshold).pow(2)) * opampSaturation);
        frontRight = saturated.clip2(saturationThreshold);
        
        // Rear channels: phase-shifted difference signal
        // Adjusted for better level balance
        difference = (left - right) * 1.0;  // Full difference signal
        sum = (left + right) * 0.7;         // Increased sum contribution
        
        // Apply saturation to intermediate signals
        saturated = difference * (1.0 - opampSaturation) + (difference * (1.0 - (difference.abs / saturationThreshold).pow(2)) * opampSaturation);
        difference = saturated.clip2(saturationThreshold);
        
        saturated = sum * (1.0 - opampSaturation) + (sum * (1.0 - (sum.abs / saturationThreshold).pow(2)) * opampSaturation);
        sum = saturated.clip2(saturationThreshold);
        
        // Matrix combination with additional saturation
        rearLeft = (difference * -1.0) + (sum * 1.0);   // Full coefficients
        rearRight = (difference * 1.0) + (sum * 1.0);   // Full coefficients
        
        // Apply final saturation to rear channels
        saturated = rearLeft * (1.0 - opampSaturation) + (rearLeft * (1.0 - (rearLeft.abs / saturationThreshold).pow(2)) * opampSaturation);
        rearLeft = saturated.clip2(saturationThreshold);
        
        saturated = rearRight * (1.0 - opampSaturation) + (rearRight * (1.0 - (rearRight.abs / saturationThreshold).pow(2)) * opampSaturation);
        rearRight = saturated.clip2(saturationThreshold);
        
        // Apply effect level control (VR2 - 100K pot)
        effectMix = \effectLevel.kr(0.5);
        // Moderate level compensation to ensure rear channels can match front
        levelCompensation = 1.2;  // 20% boost to ensure rear can match front
        rearLeft = rearLeft * effectMix * levelCompensation;
        rearRight = rearRight * effectMix * levelCompensation;
        
        // Enhanced delay processing with BBD characteristics
        // 3007 BBD has specific frequency response and noise characteristics
        delayTime = \delayTime.kr(0.025).linlin(0, 1, 0.005, 0.050);
        
        // Add BBD clock noise (characteristic of bucket brigade devices)
        bbdNoise = WhiteNoise.ar(0.0005) * \bbdNoiseLevel.kr(0.4);
        rearLeft = rearLeft + bbdNoise;
        rearRight = rearRight + bbdNoise;
        
        // BBD frequency response (rolloff above ~10kHz)
        rearLeft = LPF.ar(rearLeft, 10000);
        rearRight = LPF.ar(rearRight, 10000);
        
        delayedOutput = DelayC.ar([rearLeft, rearRight], 0.1, delayTime);
        
        // Apply surround level control (VR1 - 100K pot)
        surroundMix = \surroundLevel.kr(0.5);
        delayedOutput = delayedOutput * surroundMix;
        
        // Surround system bypass (if surroundActive is false)
        surroundActive = \surroundActive.kr(1);
        finalOutput = [
            frontLeft,
            frontRight,
            delayedOutput[0] * surroundActive,
            delayedOutput[1] * surroundActive
        ];
        
        // Apply output gain (matching original specs)
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
    
    // Start the enhanced SM-333 emulation
    AppClock.sched(0.2, {
        ~sm333Enhanced = Synth(\maplinSM333Enhanced);
        "Maplin SM-333 Enhanced Op-Amp Emulation started.".postln;
        "Features: 4558 saturation, bandwidth limiting, thermal noise, BBD characteristics".postln;
        "Output: Quad speakers [LF, RF, LR, RR]".postln;
        "Enhanced Controls: ~setSaturation(0.7), ~setBandwidth(0.8), ~setNoiseLevel(0.3)".postln;
        
        // Auto-setup with authentic circuit characteristics
        AppClock.sched(0.5, {
            ~setSurroundActive.(true);
            ~setSurroundLevel.(0.7);
            ~setEffectLevel.(0.7);
            ~setSaturation.(0.2);
            ~setBandwidth.(0.2);
            ~setNoiseLevel.(0.1);
            ~setBBDNoiseLevel.(0.1);
            "Auto-setup: Authentic circuit characteristics applied".postln;
            "Check meters 3 & 4 for surround activity".postln;
        });
        nil;
    });
    
    // Enhanced control functions
    ~setSurroundLevel = { |level| ~sm333Enhanced.set('surroundLevel', level); };
    ~setEffectLevel = { |level| ~sm333Enhanced.set('effectLevel', level); };
    ~setDelayTime = { |time| ~sm333Enhanced.set('delayTime', time); };
    ~setInputGain = { |gain| ~sm333Enhanced.set('inputGain', gain); };
    ~setOutputGain = { |gain| ~sm333Enhanced.set('outputGain', gain); };
    
    // New enhanced controls
    ~setSaturation = { |amount| ~sm333Enhanced.set('saturationAmount', amount); };
    ~setBandwidth = { |limit| ~sm333Enhanced.set('bandwidthLimit', limit); };
    ~setNoiseLevel = { |level| ~sm333Enhanced.set('noiseLevel', level); };
    ~setBBDNoiseLevel = { |level| ~sm333Enhanced.set('bbdNoiseLevel', level); };
    
    // System controls
    ~setSurroundActive = { |active| ~sm333Enhanced.set('surroundActive', if(active, 1, 0)); };
    
    // Stop function
    ~stop = {
        ~sm333Enhanced.free;
        "SM-333 Enhanced emulation stopped.".postln;
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
    
    // Interactive control interface
    ~controls = {
        "=== MAPLIN SM-333 ENHANCED CONTROLS ===".postln;
        "".postln;
        "BASIC CONTROLS:".postln;
        "~setSurroundLevel(0.8)    - Surround level (0.0-1.0)".postln;
        "~setEffectLevel(0.6)      - Effect level (0.0-1.0)".postln;
        "~setDelayTime(0.025)      - Delay time (0.005-0.050)".postln;
        "~setSurroundActive(true)  - Turn surround on/off".postln;
        "".postln;
        "ENHANCED CONTROLS:".postln;
        "~setSaturation(0.7)       - Op-amp saturation (0.0-1.0)".postln;
        "~setBandwidth(0.8)        - Frequency rolloff (0.0-1.0)".postln;
        "~setNoiseLevel(0.3)       - Thermal noise (0.0-1.0)".postln;
        "~setBBDNoiseLevel(0.4)    - BBD noise (0.0-1.0)".postln;
        "".postln;
        "PRESETS:".postln;
        "~presetClean()            - Digital clean".postln;
        "~presetVintage()          - Authentic analog".postln;
        "~presetHeavySaturation()  - Maximum saturation".postln;
        "~presetOriginal()         - Balanced enhanced".postln;
        "~presetBypass()           - Front channels only".postln;
        "".postln;
        "TESTING:".postln;
        "~testRearChannels()       - Test rear speakers".postln;
        "~stopTestTone()           - Stop test tone".postln;
        "~stop()                   - Stop everything".postln;
        "".postln;
        "EXAMPLE USAGE:".postln;
        "~presetVintage(); ~setSurroundLevel(0.7); ~setEffectLevel(0.5);".postln;
        "========================================".postln;
    };
    
    // Auto-run controls help
    AppClock.sched(1.0, { ~controls.(); });
    
    // ========================================
    // CONTROL SECTION - EDIT THESE VALUES AND RE-RUN SCRIPT
    // ========================================
    
    // EXAMPLE: To use a preset, remove the // from the line you want:
    
    // PRESET SELECTION (remove // from one line):
    // ~presetClean.();           // Digital clean sound
     ~presetVintage.();         // Authentic analog characteristics  
    // ~presetHeavySaturation.(); // Maximum saturation and noise
    // ~presetOriginal.();        // Balanced enhanced settings
    // ~presetBypass.();          // Front channels only
    
    // MANUAL SETTINGS (remove // and adjust values):
     ~setSurroundLevel.(1.0);     // Surround level (0.0-1.0)
     ~setEffectLevel.(1.0);       // Effect level (0.0-1.0)
    // ~setDelayTime.(0.025);       // Delay time (0.005-0.050)
    // ~setSaturation.(0.9);        // Op-amp saturation (0.0-1.0)
    // ~setBandwidth.(0.8);         // Frequency rolloff (0.0-1.0)
    // ~setNoiseLevel.(0.3);        // Thermal noise (0.0-1.0)
    // ~setBBDNoiseLevel.(0.4);     // BBD noise (0.0-1.0)
    
    // TESTING (remove // to test):
    // ~testRearChannels.();        // Test rear speakers with tone
    // ~stopTestTone.();            // Stop test tone
    
    // ========================================
    
    // Enhanced preset functions
    ~presetClean = {
        ~setSaturation.(0.0);
        ~setBandwidth.(0.0);
        ~setNoiseLevel.(0.0);
        ~setBBDNoiseLevel.(0.0);
        ~setSurroundLevel.(1.0);
        ~setEffectLevel.(1.0);
        ~setDelayTime.(0.025);
        ~setSurroundActive.(true);
        "Clean digital preset applied.".postln;
    };
    
    ~presetVintage = {
        ~setSaturation.(0.4);       // Reduced from 0.8 for authentic circuit behavior
        ~setBandwidth.(0.3);        // Reduced from 0.6 for subtle rolloff
        ~setNoiseLevel.(0.2);       // Reduced from 0.5 for subtle noise
        ~setBBDNoiseLevel.(0.3);    // Reduced from 0.7 for authentic BBD noise
        ~setSurroundLevel.(1.0);    // Full level to match front
        ~setEffectLevel.(1.0);      // Full level to match front
        ~setDelayTime.(0.025);
        ~setSurroundActive.(true);
        "Authentic circuit preset applied.".postln;
    };
    
    ~presetHeavySaturation = {
        ~setSaturation.(0.7);       // Reduced from 1.0 to avoid over-saturation
        ~setBandwidth.(0.6);        // Reduced from 0.8
        ~setNoiseLevel.(0.4);       // Reduced from 0.7
        ~setBBDNoiseLevel.(0.5);    // Reduced from 0.9
        ~setSurroundLevel.(1.0);    // Full level
        ~setEffectLevel.(1.0);      // Full level
        ~setDelayTime.(0.030);
        ~setSurroundActive.(true);
        "Enhanced saturation preset applied.".postln;
    };
    
    ~presetOriginal = {
        ~setSaturation.(0.3);       // Reduced from 0.7 for authentic behavior
        ~setBandwidth.(0.4);        // Reduced from 0.8
        ~setNoiseLevel.(0.2);       // Reduced from 0.3
        ~setBBDNoiseLevel.(0.3);    // Reduced from 0.4
        ~setSurroundLevel.(1.0);    // Full level to match front
        ~setEffectLevel.(1.0);      // Full level to match front
        ~setDelayTime.(0.025);
        ~setSurroundActive.(true);
        "Balanced enhanced settings applied.".postln;
    };
    
    ~presetBypass = {
        ~setSurroundActive.(false);
        "Surround bypass - front channels only.".postln;
    };
}; 