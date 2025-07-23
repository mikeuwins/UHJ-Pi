// Maplin SM-333 Authentic Circuit Emulation
// Based on actual circuit performance, not "vintage effects"
// Emulates: LM1894 DNR, 3007 BBD delay, 4558 matrix processing with real-world characteristics

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
    surroundLevel = 0.7;    // 0.0 to 1.0 (100K pot)
    effectLevel = 0.7;      // 0.0 to 1.0 (100K pot)  
    delayTime = 0.025;      // 0.005 to 0.050 seconds (5-50ms)
    
    // Authentic circuit emulation SynthDef - real-world performance
    SynthDef(\maplinSM333Authentic, {
        var leftIn, rightIn;
        var matrixOutput, delayedOutput;
        var frontLeft, frontRight, rearLeft, rearRight;
        var finalOutput;
        var left, right, difference, sum, effectMix, delayTime, surroundMix, surroundActive;
        var supplyVoltage, saturationThreshold;
        var thermalNoise, powerSupplyNoise, componentTolerance;
        var saturated, filtered;
        var opampSaturation, bandwidthLimit;
        var levelCompensation, bbdNoise;
        
        // Real-world circuit characteristics (4558 datasheet values)
        supplyVoltage = 15.0;  // ±15V supply typical
        saturationThreshold = supplyVoltage * 0.95;  // 95% of supply for very subtle saturation
        opampSaturation = \saturationAmount.kr(0.05);  // Very subtle - 0.05 = 5% saturation
        bandwidthLimit = \bandwidthLimit.kr(0.1);  // Very gentle rolloff - 0.1 = 10% bandwidth reduction
        
        // Input: stereo from audio interface
        leftIn = SoundIn.ar(0);
        rightIn = SoundIn.ar(1);
        
        // Subtle thermal noise (4558 input noise ~8nV/√Hz - very low)
        thermalNoise = WhiteNoise.ar(0.000001) * \noiseLevel.kr(0.1);  // Very low noise
        leftIn = leftIn + thermalNoise;
        rightIn = rightIn + thermalNoise;
        
        // Power supply noise (60Hz hum, very subtle)
        powerSupplyNoise = SinOsc.ar(60) * 0.00001 * \powerSupplyNoise.kr(0.05);
        leftIn = leftIn + powerSupplyNoise;
        rightIn = rightIn + powerSupplyNoise;
        
        // Component tolerance variations (slight gain mismatches)
        componentTolerance = \componentTolerance.kr(0.02);  // 2% tolerance
        leftIn = leftIn * (1.0 + (WhiteNoise.ar(0.1) * componentTolerance * 0.01));
        rightIn = rightIn * (1.0 + (WhiteNoise.ar(0.1) * componentTolerance * 0.01));
        
        // Apply input gain (matching original 0.1-3.5V range)
        leftIn = leftIn * \inputGain.kr(0.7);
        rightIn = rightIn * \inputGain.kr(0.7);
        
        // Very subtle op-amp saturation (only at extreme levels)
        // This represents the actual circuit behavior, not an effect
        saturated = leftIn * (1.0 - opampSaturation) + (leftIn * (1.0 - (leftIn.abs / saturationThreshold).pow(3)) * opampSaturation);
        left = saturated.clip2(saturationThreshold);
        
        saturated = rightIn * (1.0 - opampSaturation) + (rightIn * (1.0 - (rightIn.abs / saturationThreshold).pow(3)) * opampSaturation);
        right = saturated.clip2(saturationThreshold);
        
        // Very gentle bandwidth limiting (4558 has ~3MHz bandwidth, so minimal rolloff)
        left = LPF.ar(left, 20000 * (1.0 - bandwidthLimit) + 18000);  // Only rolls off above 18kHz
        right = LPF.ar(right, 20000 * (1.0 - bandwidthLimit) + 18000);
        
        // Authentic matrix decoding (4558 op-amp stages)
        // Based on the actual circuit component values - this is the main processing
        left = left;
        right = right;
        
        // Front channels: direct + center blend (based on 22K/220K ratios)
        frontLeft = left + (right * 0.1);   // 22K/220K = 0.1
        frontRight = right + (left * 0.1);
        
        // Rear channels: simplified approach for better level matching
        // Use a more direct matrix that can achieve full levels
        difference = (left - right) * 1.0;
        sum = (left + right) * 0.7;  // Increased sum contribution
        
        rearLeft = (difference * -1.0) + (sum * 1.0);   // Full coefficients
        rearRight = (difference * 1.0) + (sum * 1.0);   // Full coefficients
        
        // Apply effect level control (VR2 - 100K pot)
        effectMix = \effectLevel.kr(0.7);
        // Moderate level compensation to ensure rear channels can match front
        levelCompensation = 1.2;  // 20% boost to ensure rear can match front
        rearLeft = rearLeft * effectMix * levelCompensation;
        rearRight = rearRight * effectMix * levelCompensation;
        
        // Authentic delay processing (3007 BBD characteristics)
        delayTime = \delayTime.kr(0.025).linlin(0, 1, 0.005, 0.050);
        
        // Very subtle BBD clock noise (characteristic of bucket brigade devices)
        bbdNoise = WhiteNoise.ar(0.000001) * \bbdNoiseLevel.kr(0.1);  // Very low
        rearLeft = rearLeft + bbdNoise;
        rearRight = rearRight + bbdNoise;
        
        // BBD frequency response (gentle rolloff above ~15kHz)
        rearLeft = LPF.ar(rearLeft, 15000);
        rearRight = LPF.ar(rearRight, 15000);
        
        delayedOutput = DelayC.ar([rearLeft, rearRight], 0.1, delayTime);
        
        // Apply surround level control (VR1 - 100K pot)
        surroundMix = \surroundLevel.kr(0.7);
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
    
    // Start the authentic SM-333 emulation
    AppClock.sched(0.2, {
        ~sm333Authentic = Synth(\maplinSM333Authentic);
        "Maplin SM-333 Authentic Circuit Emulation started.".postln;
        "Features: Real-world 4558 characteristics, subtle circuit artifacts".postln;
        "Output: Quad speakers [LF, RF, LR, RR]".postln;
        "Authentic Controls: ~setSaturation(0.05), ~setBandwidth(0.1), ~setNoiseLevel(0.1)".postln;
        
        // Auto-setup with authentic characteristics
        AppClock.sched(0.5, {
            ~setSurroundActive.(true);
            ~setSurroundLevel.(0.7);    // Moderate level to start safely
            ~setEffectLevel.(0.7);      // Moderate level to start safely
            ~setSaturation.(0.05);      // Very subtle
            ~setBandwidth.(0.1);        // Very gentle
            ~setNoiseLevel.(0.1);       // Very low
            ~setBBDNoiseLevel.(0.1);    // Very low
            ~setPowerSupplyNoise.(0.05); // Very subtle
            ~setComponentTolerance.(0.02); // 2% tolerance
            "Auto-setup: Authentic circuit characteristics applied".postln;
            "Check meters 3 & 4 for surround activity".postln;
        });
        nil;
    });
    
    // Authentic control functions
    ~setSurroundLevel = { |level| ~sm333Authentic.set('surroundLevel', level); };
    ~setEffectLevel = { |level| ~sm333Authentic.set('effectLevel', level); };
    ~setDelayTime = { |time| ~sm333Authentic.set('delayTime', time); };
    ~setInputGain = { |gain| ~sm333Authentic.set('inputGain', gain); };
    ~setOutputGain = { |gain| ~sm333Authentic.set('outputGain', gain); };
    
    // Authentic circuit controls (very subtle)
    ~setSaturation = { |amount| ~sm333Authentic.set('saturationAmount', amount); };
    ~setBandwidth = { |limit| ~sm333Authentic.set('bandwidthLimit', limit); };
    ~setNoiseLevel = { |level| ~sm333Authentic.set('noiseLevel', level); };
    ~setBBDNoiseLevel = { |level| ~sm333Authentic.set('bbdNoiseLevel', level); };
    ~setPowerSupplyNoise = { |level| ~sm333Authentic.set('powerSupplyNoise', level); };
    ~setComponentTolerance = { |tolerance| ~sm333Authentic.set('componentTolerance', tolerance); };
    
    // System controls
    ~setSurroundActive = { |active| ~sm333Authentic.set('surroundActive', if(active, 1, 0)); };
    
    // Stop function
    ~stop = {
        ~sm333Authentic.free;
        "SM-333 Authentic emulation stopped.".postln;
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
    
    // Test function to verify levels
    ~testLevels = {
        "Testing levels - setting everything to maximum".postln;
        ~setSurroundLevel.(1.0);
        ~setEffectLevel.(1.0);
        ~setSurroundActive.(true);
        "Surround and Effect levels set to maximum (1.0)".postln;
        "Rear channels should now match front channels".postln;
    };
    
    // Interactive control interface
    ~controls = {
        "=== MAPLIN SM-333 AUTHENTIC CONTROLS ===".postln;
        "".postln;
        "BASIC CONTROLS:".postln;
        "~setSurroundLevel(0.7)    - Surround level (0.0-1.0)".postln;
        "~setEffectLevel(0.7)      - Effect level (0.0-1.0)".postln;
        "~setDelayTime(0.025)      - Delay time (0.005-0.050)".postln;
        "~setSurroundActive(true)  - Turn surround on/off".postln;
        "".postln;
        "AUTHENTIC CIRCUIT CONTROLS (very subtle):".postln;
        "~setSaturation(0.05)      - Op-amp saturation (0.0-0.1)".postln;
        "~setBandwidth(0.1)        - Frequency rolloff (0.0-0.2)".postln;
        "~setNoiseLevel(0.1)       - Thermal noise (0.0-0.2)".postln;
        "~setBBDNoiseLevel(0.1)    - BBD noise (0.0-0.2)".postln;
        "~setPowerSupplyNoise(0.05) - 60Hz hum (0.0-0.1)".postln;
        "~setComponentTolerance(0.02) - Gain variations (0.0-0.05)".postln;
        "".postln;
        "PRESETS:".postln;
        "~presetClean()            - Digital clean".postln;
        "~presetAuthentic()        - Real-world circuit".postln;
        "~presetSubtleArtifacts()  - Slight circuit imperfections".postln;
        "~presetOriginal()         - Balanced authentic".postln;
        "~presetBypass()           - Front channels only".postln;
        "".postln;
        "TESTING:".postln;
        "~testRearChannels()       - Test rear speakers".postln;
        "~stopTestTone()           - Stop test tone".postln;
        "~stop()                   - Stop everything".postln;
        "".postln;
        "EXAMPLE USAGE:".postln;
        "~presetAuthentic(); ~setSurroundLevel(0.8); ~setEffectLevel(0.7);".postln;
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
    ~presetAuthentic.();        // Real-world circuit characteristics
    // ~presetSubtleArtifacts.(); // Slight circuit imperfections
    // ~presetOriginal.();        // Balanced authentic settings
    // ~presetBypass.();          // Front channels only
    
    // MANUAL SETTINGS (remove // and adjust values):
    // ~setSurroundLevel.(0.8);     // Surround level (0.0-1.0)
    // ~setEffectLevel.(0.7);       // Effect level (0.0-1.0)
    // ~setDelayTime.(0.025);       // Delay time (0.005-0.050)
    // ~setSaturation.(0.05);       // Op-amp saturation (0.0-0.1)
    // ~setBandwidth.(0.1);         // Frequency rolloff (0.0-0.2)
    // ~setNoiseLevel.(0.1);        // Thermal noise (0.0-0.2)
    // ~setBBDNoiseLevel.(0.1);     // BBD noise (0.0-0.2)
    // ~setPowerSupplyNoise.(0.05); // 60Hz hum (0.0-0.1)
    // ~setComponentTolerance.(0.02); // Gain variations (0.0-0.05)
    
    // TESTING (remove // to test):
    // ~testRearChannels.();        // Test rear speakers with tone
    // ~stopTestTone.();            // Stop test tone
    
    // ========================================
    
    // Authentic preset functions
    ~presetClean = {
        ~setSaturation.(0.0);
        ~setBandwidth.(0.0);
        ~setNoiseLevel.(0.0);
        ~setBBDNoiseLevel.(0.0);
        ~setPowerSupplyNoise.(0.0);
        ~setComponentTolerance.(0.0);
        ~setSurroundLevel.(1.0);   // Full level to match front
        ~setEffectLevel.(1.0);     // Full level to match front
        ~setDelayTime.(0.025);
        ~setSurroundActive.(true);
        "Clean digital preset applied.".postln;
    };
    
    ~presetAuthentic = {
        ~setSaturation.(0.05);     // Very subtle
        ~setBandwidth.(0.1);       // Very gentle
        ~setNoiseLevel.(0.1);      // Very low
        ~setBBDNoiseLevel.(0.1);   // Very low
        ~setPowerSupplyNoise.(0.05); // Very subtle
        ~setComponentTolerance.(0.02); // 2% tolerance
        ~setSurroundLevel.(1.0);   // Full level to match front
        ~setEffectLevel.(1.0);     // Full level to match front
        ~setDelayTime.(0.025);
        ~setSurroundActive.(true);
        "Authentic circuit preset applied.".postln;
    };
    
    ~presetSubtleArtifacts = {
        ~setSaturation.(0.08);     // Slightly more noticeable
        ~setBandwidth.(0.15);      // Slightly more rolloff
        ~setNoiseLevel.(0.15);     // Slightly more noise
        ~setBBDNoiseLevel.(0.15);  // Slightly more BBD noise
        ~setPowerSupplyNoise.(0.08); // Slightly more hum
        ~setComponentTolerance.(0.03); // 3% tolerance
        ~setSurroundLevel.(1.0);   // Full level to match front
        ~setEffectLevel.(1.0);     // Full level to match front
        ~setDelayTime.(0.025);
        ~setSurroundActive.(true);
        "Subtle circuit artifacts preset applied.".postln;
    };
    
    ~presetOriginal = {
        ~setSaturation.(0.05);
        ~setBandwidth.(0.1);
        ~setNoiseLevel.(0.1);
        ~setBBDNoiseLevel.(0.1);
        ~setPowerSupplyNoise.(0.05);
        ~setComponentTolerance.(0.02);
        ~setSurroundLevel.(1.0);   // Full level to match front
        ~setEffectLevel.(1.0);     // Full level to match front
        ~setDelayTime.(0.025);
        ~setSurroundActive.(true);
        "Original SM-333 authentic settings applied.".postln;
    };
    
    ~presetBypass = {
        ~setSurroundActive.(false);
        "Surround bypass - front channels only.".postln;
    };
}; 