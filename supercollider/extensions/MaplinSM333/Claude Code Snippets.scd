// In your SynthDef, after encoding but before AmbiVerbSC:
encode = FoaEncode.ar(eqed, encoder);

// Add Maplin B-format processing
enhanced = MaplinSM333.ar(encode,
    surround: \maplinSurround.kr(0.8),
    effect: \maplinEffect.kr(0.8),
    delay: \maplinDelay.kr(0.4),
    active: \maplinActive.kr(1)
);

// Then continue with AmbiVerbSC
ambient = AmbiVerbSC.ar(enhanced, ...




	// Your existing GUI knobs will control the class parameters
~maplinSurroundKnob.action_({ |knob|
    if(~synth.notNil) {
        ~synth.set(\maplinSurround, knob.value);
    };
});

~maplinEffectKnob.action_({ |knob|
    if(~synth.notNil) {
        ~synth.set(\maplinEffect, knob.value);
    };
});

// etc...


	// Add to your global variables at the top
~maplinState = Dictionary.newFrom([
    \surround, 0.8,
    \effect, 0.8,
    \delay, 0.4,
    \active, 1,
    \saturation, 0.15,
    \noise, 0.1,
    \bandwidth, 0.5,
    \bbdNoise, 0.1
]);

~saveMaplinState = {
    if(~maplinSurroundKnob.notNil) {
        ~maplinState[\surround] = ~maplinSurroundKnob.value;
        ~maplinState[\effect] = ~maplinEffectKnob.value;
        ~maplinState[\delay] = ~maplinDelayKnob.value;
        // ... save other controls
    };
};

~restoreMaplinState = {
    if(~maplinSurroundKnob.notNil) {
        ~maplinSurroundKnob.value_(~maplinState[\surround]);
        ~maplinEffectKnob.value_(~maplinState[\effect]);
        // ... restore other controls and trigger actions
    };
};


//UPDATED SYNTHDEF INTEGRATION//

	// Encode to ambisonic using selected encoder (any encoder works now)
encode = FoaEncode.ar(eqed, encoder);

// Maplin B-format processing (always available)
enhanced = MaplinSM333.ar(encode,
    surround: \maplinSurround.kr(0.8),
    effect: \maplinEffect.kr(0.8),
    delay: \maplinDelay.kr(0.4),
    active: \maplinActive.kr(1),
    saturation: \maplinSaturation.kr(0.15),
    noise: \maplinNoise.kr(0.1),
    bandwidth: \maplinBandwidth.kr(0.5),
    bbdNoise: \maplinBbdNoise.kr(0.1)
);

// Ambience processing
ambient = AmbiVerbSC.ar(enhanced, ...);