// Maplin SM-333 Enhanced Circuit-Accurate Emulation - STABLE VERSION
// Simplified for reliability with proper level matching

// Configure server for quad output
s.options.numOutputBusChannels = 4;
s.options.memSize = 524288;
s.reboot;

s.waitForBoot {

    // Set ALSA mixer volume AFTER server boot
    ("amixer -c HD set PCM 80%").unixCmd;

    // Clean, stable SM-333 emulation
    SynthDef(\maplinSM333Stable, {
        // All variable declarations at top
        var leftIn, rightIn, sum, diff, processedDiff, phaseDiff;
        var frontLeft, frontRight, rearLeft, rearRight, finalOutput;
        var thermalNoise, bbdNoise, delayTime, surroundMix, effectMix, surroundActive;
        var opampSaturation, bandwidthLimit, lowBand, midBand, highBand;

        // Input from audio interface
        leftIn = SoundIn.ar(0);
        rightIn = SoundIn.ar(1);

        // Add subtle thermal noise
        thermalNoise = WhiteNoise.ar(0.00001) * \noiseLevel.kr(0.1);
        leftIn = leftIn + thermalNoise;
        rightIn = rightIn + thermalNoise;

        // Input gain and bandwidth limiting
        leftIn = leftIn * \inputGain.kr(0.7);
        rightIn = rightIn * \inputGain.kr(0.7);

        opampSaturation = \saturationAmount.kr(0.15);
        bandwidthLimit = \bandwidthLimit.kr(0.1);

        leftIn = LPF.ar(leftIn, 20000 * (1.0 - (bandwidthLimit * 0.9)) + 2000);
        rightIn = LPF.ar(rightIn, 20000 * (1.0 - (bandwidthLimit * 0.9)) + 2000);

        // Core matrix processing
        sum = (leftIn + rightIn) * 0.7071;
        diff = (leftIn - rightIn) * 0.7071;

        // Apply subtle saturation
        sum = (sum * (1.0 - opampSaturation)) + (sum.tanh * opampSaturation);
        diff = (diff * (1.0 - opampSaturation)) + (diff.tanh * opampSaturation);

        // Multi-stage phase shifting
        phaseDiff = diff;
        phaseDiff = AllpassN.ar(phaseDiff, 0.01, 0.0015, 0.7);
        phaseDiff = AllpassN.ar(phaseDiff, 0.01, 0.0033, 0.7);
        phaseDiff = AllpassN.ar(phaseDiff, 0.01, 0.0072, 0.7);
        phaseDiff = AllpassN.ar(phaseDiff, 0.01, 0.0156, 0.7);

        // High-pass filter rear channels
        phaseDiff = HPF.ar(phaseDiff, 80);

        // Band processing
        lowBand = LPF.ar(phaseDiff, 800);
        midBand = BPF.ar(phaseDiff, 2000, 1.5);
        highBand = HPF.ar(phaseDiff, 4000);

        lowBand = DelayC.ar(lowBand, 0.1, 0.022);
        midBand = DelayC.ar(midBand, 0.1, 0.018);
        highBand = DelayC.ar(highBand, 0.1, 0.012);

        processedDiff = (lowBand + midBand + highBand) * 0.6;

        // Output matrix with level matching
        frontLeft = leftIn + (sum * 0.1);
        frontRight = rightIn + (sum * 0.1);

        effectMix = \effectLevel.kr(0.5);

        // Increased scaling for better rear levels - but safe
        rearLeft = (processedDiff * -1.8 * effectMix) + (sum * 0.2);
        rearRight = (processedDiff * 1.8 * effectMix) + (sum * 0.2);

        // BBD delay processing
        delayTime = \delayTime.kr(0.025).linlin(0, 1, 0.005, 0.050);
        bbdNoise = WhiteNoise.ar(0.0003) * \bbdNoiseLevel.kr(0.1);

        rearLeft = LPF.ar(rearLeft + bbdNoise, 8000);
        rearRight = LPF.ar(rearRight + bbdNoise, 8000);

        rearLeft = DelayC.ar(rearLeft, 0.1, delayTime + LFNoise2.kr(0.5, 0.0002));
        rearRight = DelayC.ar(rearRight, 0.1, delayTime + LFNoise2.kr(0.3, 0.0002));

        // Apply surround level
        surroundMix = \surroundLevel.kr(0.5);
        rearLeft = rearLeft * surroundMix;
        rearRight = rearRight * surroundMix;

        // Final saturation
        frontLeft = (frontLeft * 0.9) + (frontLeft.tanh * 0.1);
        frontRight = (frontRight * 0.9) + (frontRight.tanh * 0.1);
        rearLeft = (rearLeft * 0.9) + (rearLeft.tanh * 0.1);
        rearRight = (rearRight * 0.9) + (rearRight.tanh * 0.1);

        // Surround bypass and output
        surroundActive = \surroundActive.kr(1);

        finalOutput = [
            frontLeft,
            frontRight,
            rearLeft * surroundActive,
            rearRight * surroundActive
        ];

        finalOutput = finalOutput * \outputGain.kr(0.8);
        finalOutput = finalOutput.clip2(0.95);  // Safety limiting

        Out.ar(0, finalOutput);

    }).add;

    // Simple test SynthDef
    SynthDef(\testSimple, {
        var testType = \testType.kr(0);
        var left, right;

        left = Select.ar(testType.clip(0, 2), [
            SinOsc.ar(440),           // Mono
            SinOsc.ar(440),           // Left only
            PinkNoise.ar(0.3)         // Noise
        ]) * 0.3;

        right = Select.ar(testType.clip(0, 2), [
            SinOsc.ar(440),           // Mono
            DC.ar(0),                 // Left only
            PinkNoise.ar(0.3)         // Noise
        ]) * 0.3;

        Out.ar(0, left);
        Out.ar(1, right);
    }).add;

    s.sync;

    // Start emulation
    AppClock.sched(0.2, {
        ~sm333 = Synth(\maplinSM333Stable);
        "Maplin SM-333 Stable Emulation started - rear channels boosted 2.2x".postln;
        nil;
    });

    // Control functions
    ~setSurroundLevel = { |level| ~sm333.set('surroundLevel', level); };
    ~setEffectLevel = { |level| ~sm333.set('effectLevel', level); };
    ~setDelayTime = { |time| ~sm333.set('delayTime', time); };
    ~setSaturation = { |amount| ~sm333.set('saturationAmount', amount); };
    ~setBandwidth = { |limit| ~sm333.set('bandwidthLimit', limit); };
    ~setNoiseLevel = { |level| ~sm333.set('noiseLevel', level); };
    ~setBBDNoiseLevel = { |level| ~sm333.set('bbdNoiseLevel', level); };
    ~setSurroundActive = { |active| ~sm333.set('surroundActive', if(active, 1, 0)); };

    ~testSimple = { |type = 0|
        ~testSynth = Synth(\testSimple, [\testType, type]);
        ["Mono", "Left only", "Pink noise"][type].postln;
    };
    ~stopTest = { ~testSynth.free; };
    ~stop = { ~sm333.free; };

    // Presets
    ~presetBalanced = {
        ~setSurroundLevel.(0.8);
        ~setEffectLevel.(0.8);
        ~setSaturation.(0.15);
        "Balanced preset - rear channels should match front better".postln;
    };

    ~presetMax = {
        ~setSurroundLevel.(1.0);
        ~setEffectLevel.(1.0);
        ~setSaturation.(0.1);
        "Maximum surround preset".postln;
    };

    // Auto-apply balanced preset
    AppClock.sched(1.0, { ~presetBalanced.(); });

    "=== CONTROLS ===".postln;
    "~presetBalanced() - Balanced levels".postln;
    "~presetMax() - Maximum surround".postln;
    "~testSimple(1) - Test left channel only".postln;
    "~stopTest() - Stop test".postln;
    "================".postln;
};