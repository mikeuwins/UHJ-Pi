// ============================================================================
// UHJ v21 - AMBISONIC UHJ ENCODER/DECODER - BEHRINGER EDITION
// ============================================================================
// Adapted for Behringer UFO202/UCA202 setup with JACK + zita bridges
// LINE/PHONO switching via software input routing instead of hardware switching

var win, mainView,
    decoderChanged,
    isUpdating, lastInputCmd, linkFaders, lastInL, lastInR, minIn, maxIn, lastFaderGroup,
    voltmp, cond, sndbuf, synth, inputs, outputs, configKeyD, configKeyE,
    dbValue, cliToDb, cliToDbMaster, formatDbValue;

// --- Overlay GUI variables (must be declared at the top, per GUIPrototype) ---
~eqOverlay = nil; ~ambienceOverlay = nil; ~layoutOverlay = nil; ~maplinOverlay = nil;
~eqBtn = nil; ~ambienceBtn = nil; ~layoutBtn = nil; ~maplinBtn = nil;

// --- EQ overlay variables (from GUIPrototype) ---
~eqPresetMenu = nil; ~eqPresetNames = nil; ~eqPresetDict = nil; ~eqSliders = nil; ~eqValues = nil;

// --- Maplin overlay variables ---
~maplinSurroundKnob = nil; ~maplinEffectKnob = nil; ~maplinDelayKnob = nil; ~maplinActiveBtn = nil;
~maplinSurroundValue = nil; ~maplinEffectValue = nil; ~maplinDelayValue = nil;

// --- Headtracker overlays ---
~knobOverlay = nil; ~htBtnOverlay = nil;

// --- Maplin button overlay ---
~maplinBtnOverlay = nil;

// --- Power button state ---
~powerBtnPressed = false;

// --- AmbiVerbSC preset system variables ---
~ambiencePresetNames = nil; ~ambiencePresetDict = nil; ~ambiencePresetMenu = nil;

// --- Ambience state preservation variables ---
~ambienceState = Dictionary.newFrom([
    \sliderValues, [0.0, 0.2, 0.2, 0.2, 0.0, 0.0, 0.0], // Default values
    \presetIndex, 0, // Default preset index
    \lastMix, 0.5 // Remember last nonzero mix value
]);

// --- EQ state preservation variables ---
~eqState = Dictionary.newFrom([
    \sliderValues, [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5], // Default values (0dB = 0.5)
    \presetIndex, 0 // Default preset index
]);

// --- Maplin state preservation variables ---
~maplinState = Dictionary.newFrom([
    \surround, 0.8, // Surround level
    \effect, 0.8, // Effect level
    \delay, 0.4, // Delay amount
    \active, 0 // Active/bypass (default OFF)
]);

// --- Behringer audio device variables ---
~currentInputMode = \line; // \line or \phono
~behringerUFOCard = nil;   // Will store UFO202 card number
~behringerUCACard = nil;   // Will store UCA202 card number

// --- Initial values for input section ---
isUpdating = false;
linkFaders = true;
lastInL = 86;
lastInR = 86;
minIn = 60;
maxIn = 127;
lastFaderGroup = \none;

// Audio engine initial values
voltmp = 1.0; // 0dB = 1.0 amplitude

// Encoder/Decoder configuration defaults
configKeyE = \uhj;      // Default encoder: UHJ
configKeyD = \binaural; // Default decoder: Binaural
inputs = 4;             // 4 inputs total (2 phono + 2 line)
outputs = 2;            // Default output channels

// Honest dB conversion - work with the hardware resolution we actually have
cliToDb = { |cliValue|
    var dbValue;
    // Direct linear mapping: 60->-40dB, 127->+12dB
    dbValue = cliValue.linlin(60, 127, -40, 12);
    // Don't pretend we have 0.5dB resolution - round to 1dB which we can actually achieve
    dbValue.round(1);
};

// Master dB conversion function - just use the simple one
cliToDbMaster = { |cliValue|
    cliToDb.value(cliValue);
};

// Format dB value for consistent display (no need for .0 with whole numbers)
formatDbValue = { |dbValue|
    var intValue = dbValue.asInteger;
    if(intValue > 0) {
        "+" ++ intValue.asString;
    } {
        intValue.asString;
    };
};

// --- Behringer device detection ---
~detectBehringerDevices = {
    var ufoCard, ucaCard;
    var cards = "/proc/asound/cards".load;

    // Look for USB controller signatures
    ufoCard = nil; ucaCard = nil;

    // Parse /proc/asound/cards for our USB controllers
    try {
        var cardLines = "cat /proc/asound/cards".unixCmdGetStdOut.split($\n);
        cardLines.do({ |line|
            if(line.contains("1a.7")) { // UFO202 controller
                var cardNum = line.split($ )[0].asInteger;
                ufoCard = cardNum;
                ("Found UFO202 on card " ++ cardNum).postln;
            };
            if(line.contains("1d.7")) { // UCA202 controller
                var cardNum = line.split($ )[0].asInteger;
                ucaCard = cardNum;
                ("Found UCA202 on card " ++ cardNum).postln;
            };
        });
    } { |error|
        ("Error detecting devices: " ++ error).postln;
        // Fallback to common assignments
        ufoCard = 0; ucaCard = 1;
    };

    ~behringerUFOCard = ufoCard;
    ~behringerUCACard = ucaCard;
            ("Device detection complete: UFO202=card"++ufoCard++", UCA202=card"++ucaCard).postln;
};

// --- Behringer level control (synth-based gain control) ---
~setBehringerLevels = { |leftLevel, rightLevel, inputMode|
    var leftGain, rightGain;
    
    // Convert CLI values (60-127) to gain values (0.1-4.0)
    // 60 = -40dB = 0.01 gain, 127 = +12dB = 4.0 gain
    leftGain = leftLevel.linlin(60, 127, 0.01, 4.0);
    rightGain = rightLevel.linlin(60, 127, 0.01, 4.0);
    
    // Update synth input gain parameters
    if(~synth.notNil) {
        ~synth.set(\inputGainL, leftGain, \inputGainR, rightGain);
        ("Input gain set: L=" ++ leftGain.round(0.01) ++ " (" ++ formatDbValue.(leftLevel) ++ "), R=" ++ rightGain.round(0.01) ++ " (" ++ formatDbValue.(rightLevel) ++ ")").postln;
    };
};

// --- Input mode switching (software routing instead of hardware switching) ---
~setInputMode = { |mode|
    ~currentInputMode = mode;
    if(~synth.notNil) {
        // Update synth to use correct input bus
        if(mode == \phono) {
            ~synth.set(\inputMode, 1); // Use phono inputs (UFO202) - channels 2,3
            ("Input switched to PHONO (UFO202 - channels 2,3)").postln;
        } {
            ~synth.set(\inputMode, 0); // Use line inputs (UCA202) - channels 0,1
            ("Input switched to LINE (UCA202 - channels 0,1)").postln;
        };
    };
    // Update levels for the selected input device
    ~setBehringerLevels.(lastInL, lastInR, mode);
    
    // Debug: Check if devices are detected
    ("Current input mode: " ++ mode ++ ", UFO card: " ++ ~behringerUFOCard ++ ", UCA card: " ++ ~behringerUCACard).postln;
};

// Simple dB conversion for display
formatDbValue = { |cliValue|
    var dbValue = cliValue.linlin(60, 127, -40, 12).round(1);
    var intValue = dbValue.asInteger;
    if(intValue > 0) {
        "+" ++ intValue.asString;
    } {
        intValue.asString;
    };
};

// --- Window setup with platform-specific positioning ---
win = Window("UHJ Ambisonic System - Behringer Edition", Rect(0, 0, 800, 480)).background_(Color.black);

// Ensure server and interpreter quit when window is closed
win.onClose_({
    if(s.serverRunning) { s.quit; };
    0.exit;
});

// Position at visible top-left corner
if(Platform.name == \osx, {
    win.bounds_(Rect(0, 25, 800, 480)); // Account for macOS menu bar
}, {
    // Check if we're likely on a Pi (no desktop environment) or desktop Ubuntu
    var isPi = (Platform.architecture == \arm) ||
        (thisProcess.platform.name == "linux" &&
        File.exists("/proc/device-tree/model"));
    if(isPi, {
        win.bounds_(Rect(0, 0, 800, 480)); // Pi: true (0,0) for full screen
    }, {
        win.bounds_(Rect(0, 30, 800, 480)); // Ubuntu desktop: account for top panel
    });
});

mainView = CompositeView(win, Rect(0, 0, 800, 480)).background_(Color.black);

// --- INPUT FADERS SECTION (adapted for Behringer control) ---
StaticText(mainView, Rect(48, 10, 120, 28))
    .string_("INPUT")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

StaticText(mainView, Rect(70, 40, 24, 24)).string_("L").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 13));
StaticText(mainView, Rect(120, 40, 24, 24)).string_("R").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 13));

// Input faders with Behringer integration
~leftSlider = Slider(mainView, Rect(70, 70, 24, 300))
    .orientation_(\vertical)
    .background_(Color.black)
    .focusColor_(Color.clear)
    .knobColor_(Color.cyan)
    .action_({ |sl|
        if(isUpdating.not) {
            isUpdating = true;
            lastFaderGroup = \input;
            lastInL = (sl.value.linlin(0,1,minIn,maxIn).round.asInteger);
            dbValue = lastInL.linlin(60, 127, -40, 12);
            ~leftValue.string = formatDbValue.(lastInL);
            if(linkFaders) {
                ~rightSlider.value = sl.value;
                lastInR = lastInL;
                ~rightValue.string = formatDbValue.(lastInR);
            };
            isUpdating = false;
        } {
            lastInL = (sl.value.linlin(0,1,minIn,maxIn).round.asInteger);
            ~leftValue.string = formatDbValue.(lastInL);
        }
    });

~rightSlider = Slider(mainView, Rect(120, 70, 24, 300))
    .orientation_(\vertical)
    .background_(Color.black)
    .focusColor_(Color.clear)
    .knobColor_(Color.cyan)
    .action_({ |sl|
        if(isUpdating.not) {
            isUpdating = true;
            lastFaderGroup = \input;
            lastInR = (sl.value.linlin(0,1,minIn,maxIn).round.asInteger);
            dbValue = lastInR.linlin(60, 127, -40, 12);
            ~rightValue.string = formatDbValue.(lastInR);
            if(linkFaders) {
                ~leftSlider.value = sl.value;
                lastInL = lastInR;
                ~leftValue.string = formatDbValue.(lastInL);
            };
            isUpdating = false;
        } {
            lastInR = (sl.value.linlin(0,1,minIn,maxIn).round.asInteger);
            ~rightValue.string = formatDbValue.(lastInR);
        }
    });

~leftValue = StaticText(mainView, Rect(65, 380, 34, 24)).string_("-19").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 13));
~rightValue = StaticText(mainView, Rect(115, 380, 34, 24)).string_("-19").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 13));

// Add "dB" label between the faders
StaticText(mainView, Rect(95, 380, 24, 24)).string_("dB").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 13));

// Visual tick marks between faders
UserView(mainView, Rect(98, 70, 18, 300))
    .background_(Color.clear)
    .drawFunc_({ |view|
        Pen.color = Color.cyan;
        Pen.width = 1;
        [0, 50, 100, 150, 200, 250, 300].do({ |y|
            Pen.line(Point(6, y), Point(12, y));
            Pen.stroke;
        });
        [25, 75, 125, 175, 225, 275].do({ |y|
            Pen.line(Point(7, y), Point(11, y));
            Pen.stroke;
        });
    });

// Mouse up action for level setting
mainView.mouseUpAction_({
    AppClock.sched(0.05, {
        if(lastFaderGroup == \input) {
            ~setBehringerLevels.(lastInL, lastInR, ~currentInputMode);
        };
        lastFaderGroup = \none;
    });
});

// --- SIMPLIFIED SOURCE SELECTOR (LINE/PHONO only) ---
~lineBtn = Button(mainView, Rect(18, 70, 40, 20))
    .states_([["LINE", Color.cyan, Color.black], ["LINE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .action_({ |btn|
        if(btn.value == 1) {
            ~phonoBtn.value_(0);
            ~setInputMode.(\line);
        }
    });

~phonoBtn = Button(mainView, Rect(18, 110, 40, 20))
    .states_([["PHONO", Color.cyan, Color.black], ["PHONO", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .action_({ |btn|
        if(btn.value == 1) {
            ~lineBtn.value_(0);
            ~setInputMode.(\phono);
        }
    });

// RESET, MUTE, LINK buttons (adapted for Behringer)
~resetBtn = Button(mainView, Rect(18, 190, 40, 20))
    .states_([["RESET", Color.cyan, Color.black]])
    .font_(Font("Helvetica", 10))
    .action_({ |btn|
        // Reset to default values
        AppClock.sched(0.1, {
            lastInL = 86; // Reasonable default
            lastInR = 86;
            ~leftSlider.value = (lastInL - minIn) / (maxIn - minIn);
            ~rightSlider.value = (lastInR - minIn) / (maxIn - minIn);
            ~leftValue.string = formatDbValue.(lastInL);
            ~rightValue.string = formatDbValue.(lastInR);
            ~lineBtn.value_(1); // Default to LINE
            ~phonoBtn.value_(0);
            ~setInputMode.(\line);
        });
    });

~muteBtn = Button(mainView, Rect(76, 410, 60, 35))
    .states_([["MUTE", Color.cyan, Color.black], ["MUTE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
    .focusColor_(Color.clear)
    .action_({ |btn|
        if(~synth.notNil) {
            if(btn.value == 1) {
                ~synth.set(\mute, 1);
            } {
                ~synth.set(\mute, 0);
            };
        };
    });

~linkBtn = Button(mainView, Rect(18, 230, 40, 20))
    .states_([["LINK", Color.cyan, Color.black], ["LINK", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .value_(linkFaders.asInteger)
    .action_({ |btn| linkFaders = btn.value == 1; });

// --- ENCODER/DECODER MENUS (unchanged) ---
StaticText(mainView, Rect(180, 10, 140, 28))
    .string_("ENCODER")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

StaticText(mainView, Rect(360, 10, 140, 28))
    .string_("DECODER")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

// Encoder menu
~emenu = EZPopUpMenu.new(
    mainView,
    Rect(180, 45, 140, 35),
    "",
    [
        \UHJ -> { |a| configKeyE = \uhj; ("Encoder: UHJ").postln; },
        \SUPERSTEREO -> { |a| configKeyE = \superstereo; ("Encoder: SUPERSTEREO").postln; },
        \MAPLIN -> { |a| configKeyE = \maplin; ("Encoder: MAPLIN").postln; }
    ],
    globalAction: { |menu|
        // Update maplinMode on existing synth if it exists
        if(~synth.notNil) {
            ~synth.set(\maplinMode, if(configKeyE == \maplin, 1, 0));
        };

        // Show/hide SM-333 button based on encoder selection
        if(~maplinBtn.notNil) {
            if(configKeyE == \maplin) {
                if(~maplinBtnOverlay.notNil) {
                    ~maplinBtnOverlay.remove;
                    ~maplinBtnOverlay = nil;
                };
            } {
                if(~maplinOverlay.notNil) {
                    ~saveMaplinState.value();
                    ~maplinOverlay.remove;
                    ~maplinOverlay = nil;
                    ~maplinBtn.value_(0);
                };
                if(~maplinBtnOverlay.isNil) {
                    ~maplinBtnOverlay = View(mainView, Rect(290, 410, 100, 35))
                        .background_(Color.black.alpha_(0.7))
                        .alpha_(1.0)
                        .front;
                };
            };
        };

        ~saveSynthParams.value();
        ~initAudioEngine.value();
    },
    initVal: 0,
    initAction: false,
    labelWidth: 0,
    labelHeight: 0,
    layout: \horz,
    gap: 0@0
);

// Decoder menu (updated for quad output)
~dmenu = EZPopUpMenu.new(
    mainView,
    Rect(360, 45, 140, 35),
    "",
    [
        \BINAURAL ++ " IRCAM" -> { |a| inputs = 4; outputs = 2; configKeyD = \binaural; },
        \BINAURAL ++ " CIPIC" -> { |a| inputs = 4; outputs = 2; configKeyD = \binaurac; },
        \QUAD ++ " SQUARE" -> { |a| inputs = 4; outputs = 4; configKeyD = \quadsquare; },
        \QUAD ++ " NARROW" -> { |a| inputs = 4; outputs = 4; configKeyD = \quadnarrow; },
        \QUAD ++" WIDE" -> { |a| inputs = 4; outputs = 4; configKeyD = \quadwide; }
    ],
    globalAction: { |menu|
        var idx = menu.value;
        var isBinaural = (idx == 0) or: { idx == 1 };
        var isQuad = (idx == 2) or: { idx == 3 } or: { idx == 4 };
        
        // Reset headtracking and panner on decoder change
        if(~headtrackBtn.notNil) { ~headtrackBtn.value_(0); };
        if(~rotateKnob.notNil) { ~rotateKnob.valueAction_(0.5); };
        if(~tiltKnob.notNil) { ~tiltKnob.valueAction_(0.5); };
        if(~tumbleKnob.notNil) { ~tumbleKnob.valueAction_(0.5); };
        if(~xyPanner.notNil) {
            ~xyPanner.x_(0.5); ~xyPanner.y_(0.5);
            ~xyPannerPos = Point(0.5, 0.5);
        };

        // Update overlays based on decoder type
        if(~knobOverlay.notNil) { ~knobOverlay.remove; ~knobOverlay = nil; };
        if(~htBtnOverlay.notNil) { ~htBtnOverlay.remove; ~htBtnOverlay = nil; };
        if(~xyPannerOverlay.notNil) { ~xyPannerOverlay.remove; ~xyPannerOverlay = nil; };

        if(isBinaural) {
            ~headtrackBtn.enabled_(true);
            ~headtrackResetBtn.enabled_(true);
            ~xyPanner.enabled_(false);
            ~xyPannerOverlay = View(mainView, Rect(629, 299, 110, 145))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
        } {
            ~headtrackBtn.enabled_(false);
            ~headtrackResetBtn.enabled_(false);
            ~knobOverlay = View(mainView, Rect(594, 60, 147, 224))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
            ~htBtnOverlay = View(mainView, Rect(734, 60, 48, 80))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
        };

        if(isQuad) {
            ~xyPanner.enabled_(true);
            if(~xyPannerOverlay.notNil) { ~xyPannerOverlay.remove; ~xyPannerOverlay = nil; };
        } {
            ~xyPanner.enabled_(false);
            if(~xyPannerOverlay.isNil) {
                ~xyPannerOverlay = View(mainView, Rect(629, 299, 110, 145))
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
            };
        };

        if((configKeyD != (~prevConfigKeyD ? configKeyD)) or: ((inputs != (~prevInputs ? inputs)) or: (outputs != (~prevOutputs ? outputs)))) {
            ~saveSynthParams.value();
            ~initAudioEngine.value();
            ~prevConfigKeyD = configKeyD;
        };
    },
    initVal: 0, // Default to BINAURAL IRCAM
    initAction: false,
    labelWidth: 0,
    labelHeight: 0,
    layout: \horz,
    gap: 0@0
);

// Style the menus
~emenu.font = Font("LCD 5x7 Segment Monospace", 11);
~emenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);
~dmenu.font = Font("LCD 5x7 Segment Monospace", 11);
~dmenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);

// Audio engine initialization (adapted for Behringer/JACK setup)
~initAudioEngine = {
    var encoder, decoder, tryBoot, needReboot;

    needReboot = (inputs != (~prevInputs ? inputs)) or: (outputs != (~prevOutputs ? outputs)) or: (configKeyD != (~prevConfigKeyD ? configKeyD)) or: (configKeyE != (~prevConfigKeyE ? configKeyE));

    tryBoot = {
        if(s.serverBooting, {
            ("Server busy (booting), retrying audio engine init...").postln;
            AppClock.sched(0.2, { tryBoot.value });
        }, {
            if(s.serverRunning.not, {
                s.options.memSize = 65536;
                s.options.numOutputBusChannels = outputs;
                s.options.numInputBusChannels = inputs;
                // Use jack_quad device created by our setup script
                s.options.device = "jack_quad";
                s.boot;
                cond = Condition.new;
                s.waitForBoot({
                    var encoderDict, decoderDict;

                    // Define encoder kernels
                    encoderDict = Dictionary.newFrom([
                        \uhj, FoaEncoderKernel.newUHJ,
                        \superstereo, FoaEncoderKernel.newSuper,
                        \maplin, FoaEncoderMatrix.newDirections([-45, 45, -135, 135].degrad),
                    ]);

                    // Define decoder kernels
                    decoderDict = Dictionary.newFrom([
                        \binaural, FoaDecoderKernel.newListen(1053),
                        \binaurac, FoaDecoderKernel.newCIPIC(12),
                        \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                        \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                        \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual')
                    ]);

                    encoder = encoderDict.at(configKeyE ? \uhj);
                    decoder = decoderDict.at(configKeyD ? \quadsquare);

                    s.sync(cond);

                    // Define the main audio processing SynthDef (adapted for Behringer input routing)
                    SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, quadLR = 0, quadFR = 0, ambience = 0, preDelay = 0, lowRT = 0.2, highRT = 2, dispersion = 1, modWidth = 0.2, modRate = 0.3, eq1 = 0, eq2 = 0, eq3 = 0, eq4 = 0, eq5 = 0, eq6 = 0, eq7 = 0, maplinSurround = 0.8, maplinEffect = 0.8, maplinDelay = 0.4, maplinActive = 1, maplinMode = 0, inputMode = 0, inputGainL = 1.0, inputGainR = 1.0, mute = 0|
                        var out, src, trans, encode, ambient, eqed, frontStereo, rearStereo, quadOutFront, quadOutRear, maplinQuad, encodeInput;
                        
                        // Behringer input selection (LINE/PHONO mode)
                        var allInputs = SoundIn.ar([0,1,2,3]); // All 4 inputs for metering
                        src = Select.ar(inputMode, [
                            allInputs[0..1], // Line inputs (UCA202) - channels 0,1
                            allInputs[2..3]  // Phono inputs (UFO202) - channels 2,3
                        ]);
                        
                        // Input gain control (pre-EQ)
                        src = [src[0] * inputGainL, src[1] * inputGainR];
                        
                        // Mute control
                        src = src * (1 - mute);
                        
                        // Amplitude scaling
                        src = src * \amp.kr(0.dbamp); // 0dB default
                        
                        // --- 7-band graphic EQ before ambisonic encode ---
                        eqed = src;
                        eqed = BPeakEQ.ar(eqed, 63, 1, eq1);      // Band 1
                        eqed = BPeakEQ.ar(eqed, 160, 1, eq2);     // Band 2
                        eqed = BPeakEQ.ar(eqed, 400, 1, eq3);     // Band 3
                        eqed = BPeakEQ.ar(eqed, 1000, 1, eq4);    // Band 4
                        eqed = BPeakEQ.ar(eqed, 2500, 1, eq5);    // Band 5
                        eqed = BPeakEQ.ar(eqed, 6400, 1, eq6);    // Band 6
                        eqed = BPeakEQ.ar(eqed, 12000, 1, eq7);   // Band 7

                        // Pre-processing for maplin encoder: stereo to quad via MaplinMatrix
                        maplinQuad = MaplinMatrix.ar(
                            eqed[0], eqed[1],
                            surroundLevel: maplinSurround,
                            effectLevel: maplinEffect,
                            delayTime: maplinDelay,
                            active: maplinActive
                        );

                        // Select input for encoding: quad (if maplin) or stereo (others)
                        encodeInput = Select.ar(maplinMode, [eqed, maplinQuad]);

                        // Encode to ambisonic using selected encoder
                        encode = FoaEncode.ar(encodeInput, encoder);

                        // Ambience processing
                        ambient = AmbiVerbSC.ar(encode,
                            mix: ambience,
                            preDelay: preDelay,
                            crossoverFreq: 3000,
                            lowRT: lowRT,
                            highRT: highRT,
                            dispersion: dispersion,
                            size: \Brahmssaal, // Use a room that definitely exists in AmbiVerbSC
                            modWidth: modWidth,
                            modRate: modRate,
                            coupRate: 0.5,
                            coupAmt: 3,
                            phaseRotRate: 0.4,
                            phaseRotAmt: 6.2831853071796,
                            orientation: 'flu',
                            maxPreDelay: 10,
                            feedbackSpread: 1
                        );
                        
                        // Spatial transformations (rotation, tilt, tumble) - apply to all modes
                        trans = FoaRTT.ar(ambient, rotAngle: rotation, tilAngle: tilt, tumAngle: tumble);
                        
                        // Decode using selected decoder
                        out = FoaDecode.ar(trans, decoder);
                        
                        if(outputs == 4, {
                            // --- Q-PANNER LOGIC (Balance2) ---
                            // out[0]=LF, out[1]=LR, out[2]=RR, out[3]=RF
                            frontStereo = Balance2.ar(out[0], out[3], quadLR); // LF, RF
                            rearStereo  = Balance2.ar(out[1], out[2], quadLR); // LR, RR
                            quadOutFront = frontStereo * ((quadFR + 1) * 0.5); // scale front by 0..1
                            quadOutRear  = rearStereo  * ((1 - quadFR) * 0.5); // scale rear by 1..0
                            out = [
                                quadOutFront[0], // LF
                                quadOutRear[0],  // LR
                                quadOutRear[1],  // RR
                                quadOutFront[1]  // RF
                            ];
                        });
                        
                        if(outputs == 6, {
                            var lowpass = BLowPass.ar((out[1] + out[4]), 120, 1, 0.4); // Sum LF + RF for sub
                            // Reorder outputs to match desired speaker order: LF=1, RL=2, RR=3, FR=4, C=5, Sub=6
                            Out.ar(0, [out[1], out[2], out[3], out[4], out[0], lowpass]); // [LF, RL, RR, FR, C, Sub]
                        }, {
                            Out.ar(0, out);
                        });
                    }).add;

                    s.sync(cond);

                    // Start the synth
                    ~synth = Synth(\kernelEncodeDecode, [\buffer, sndbuf, \amp, voltmp,
                        \maplinSurround, ~maplinState[\surround],
                        \maplinEffect, ~maplinState[\effect],
                        \maplinDelay, ~maplinState[\delay],
                        \maplinActive, ~maplinState[\active],
                        \maplinMode, if(configKeyE == \maplin, 1, 0),
                        \inputMode, if(~currentInputMode == \phono, 1, 0),
                        \inputGainL, 1.0, \inputGainR, 1.0,
                        \mute, 0]);

                    // Restore saved parameters
                    ~restoreSynthParams.value();

                    // Create level meter
                    {
                        ~meter.remove;
                        ~meter = ServerMeter2View.new(s, ~meterContainer, 0@0, inputs, outputs);
                    }.defer(0.1);

                    ("Behringer audio synthesis started").postln;
                });
            }, {
                if(needReboot, {
                    s.options.memSize = 65536;
                    s.options.numOutputBusChannels = outputs;
                    s.options.numInputBusChannels = inputs;
                    s.options.device = "jack_quad";
                    s.reboot;
                    cond = Condition.new;
                    s.waitForBoot({
                        var encoderDict, decoderDict;

                        encoderDict = Dictionary.newFrom([
                            \uhj, FoaEncoderKernel.newUHJ,
                            \superstereo, FoaEncoderKernel.newSuper,
                            \maplin, FoaEncoderMatrix.newDirections([-45, 45, -135, 135].degrad),
                        ]);

                        decoderDict = Dictionary.newFrom([
                            \binaural, FoaDecoderKernel.newListen(1053),
                            \binaurac, FoaDecoderKernel.newCIPIC(12),
                            \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                            \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                            \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual')
                        ]);

                        encoder = encoderDict.at(configKeyE ? \uhj);
                        decoder = decoderDict.at(configKeyD ? \quadsquare);

                        s.sync(cond);


                        s.sync(cond);

                        // Start the synth
                        ~synth = Synth(\kernelEncodeDecode, [\buffer, sndbuf, \amp, voltmp,
                            \maplinSurround, ~maplinState[\surround],
                            \maplinEffect, ~maplinState[\effect],
                            \maplinDelay, ~maplinState[\delay],
                            \maplinActive, ~maplinState[\active],
                            \maplinMode, if(configKeyE == \maplin, 1, 0),
                            \inputMode, if(~currentInputMode == \phono, 1, 0),
                            \inputGainL, 1.0, \inputGainR, 1.0,
                            \mute, 0]);

                        ~restoreSynthParams.value();

                        {
                            ~meter.remove;
                            ~meter = ServerMeter2View.new(s, ~meterContainer, 0@0, inputs, outputs);
                                                }.defer(0.1);
                        
                        // Re-establish JACK connections after reboot
                        AppClock.sched(0.5, { ~setupBehringerJACK.value(); });
                        
                                                

                    });
                });
            });
        });
    };

    tryBoot.value;
    ~prevInputs = inputs;
    ~prevOutputs = outputs;
    ~prevConfigKeyD = configKeyD;
    ~prevConfigKeyE = configKeyE;
};

// --- Level Meter Section (adapted for 4 channels) ---
~meterView = View(mainView, Rect(180, 107, 320, 275)).background_(Color.clear);

~meterBorder = UserView(~meterView, Rect(0, 0, 320, 275))
    .background_(Color.clear)
    .drawFunc_({ |v|
        Pen.width = 0.5;
        Pen.color = Color.cyan;
        Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
        Pen.stroke;
    });

StaticText(~meterView, Rect(0, 5, 320, 30)).background_(Color.clear)
    .align_(\center)
    .string_("LEVEL METER")
    .stringColor_(Color.cyan)
    .font_(Font("Helvetica", 14).boldVariant);

~meterContainer = View(~meterView, Rect(10, 35, 300, 230)).background_(Color.black);

// Output label
StaticText(~meterContainer, Rect(97, 5, 180, 16))
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("OUTPUT");

// Input label
StaticText(~meterContainer, Rect(34, 5, 80, 16))
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\left)
    .stringColor_(Color.cyan)
    .string_("INPUT");

// Input channel numbers (4 inputs total)
~inputNumbers = Array.fill(4, { |i|
    var labelWidth = 24;
    var x = 42 + (i * ((80 / 4) + 2)) - (labelWidth / 2); // Moved 6px right total
    StaticText(~meterContainer, Rect(x, 206, labelWidth, 16))
        .background_(Color.clear)
        .font_(Font("Helvetica", 9).boldVariant)
        .align_(\center)
        .stringColor_(Color.cyan)
        .string_((i+1).asString);
});


// dB scale
StaticText(~meterContainer, Rect(8, 25, 24, 12))
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("0");

StaticText(~meterContainer, Rect(8, 195, 24, 12))
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("-60");

StaticText(~meterContainer, Rect(8, 110, 24, 14))
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("dB");

// Initialize defaults
lastInL = 86;
lastInR = 86;
~leftSlider.value = (lastInL - minIn) / (maxIn - minIn);
~rightSlider.value = (lastInR - minIn) / (maxIn - minIn);
~leftValue.string = formatDbValue.(lastInL);
~rightValue.string = formatDbValue.(lastInR);
~lineBtn.value_(1); // Default to LINE
~phonoBtn.value_(0);

// Set menu defaults
~emenu.value_(0); // UHJ encoder
~dmenu.value_(0); // BINAURAL IRCAM decoder

// --- HEADTRACKER CONTROLS (unchanged from original) ---
~rotateValue = StaticText(mainView, Rect(719, 80, 55, 20)).font_(Font("Helvetica", 11)).string_("0").align_(\left).stringColor_(Color.cyan);
~tiltValue = StaticText(mainView, Rect(719, 162, 55, 20)).font_(Font("Helvetica", 11)).string_("0").align_(\left).stringColor_(Color.cyan);
~tumbleValue = StaticText(mainView, Rect(719, 244, 55, 20)).font_(Font("Helvetica", 11)).string_("0").align_(\left).stringColor_(Color.cyan);

~lastInputSource = \headtracker;
~mouseActive = false;

~rotateKnob = Knob360(mainView, Rect(654, 60, 60, 60), 0.5, 0.0, 1.0)
    .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
    .enabled_(false)
    .action_({ |knob, val|
        var deg = val.linlin(0, 1, -180, 180).round.asInteger;
        if(~mouseActive, {
            deg = deg.neg;
            ~lastInputSource = \mouse;
        }, {
            ~lastInputSource = \headtracker;
        });
        ~rotateValue.string = (deg.asString ++ "°");
        if(~synth.notNil) { ~synth.set(\rotation, deg.degrad); }
    })
    .mouseDownAction_({ |view, x, y, mod, button, count|
        ~mouseActive = true;
        ~lastInputSource = \mouse;
    })
    .mouseUpAction_({ |view, x, y, mod, button, count|
        ~mouseActive = false;
    });

~tiltKnob = Knob360(mainView, Rect(654, 142, 60, 60), 0.5, 0.0, 1.0)
    .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
    .enabled_(false)
    .action_({ |knob, val|
        var deg = val.linlin(0, 1, -180, 180).round.asInteger;
        if(~mouseActive, {
            deg = deg.neg;
            ~lastInputSource = \mouse;
        }, {
            ~lastInputSource = \headtracker;
        });
        ~tiltValue.string = (deg.asString ++ "°");
        if(~synth.notNil) { ~synth.set(\tilt, deg.degrad); }
    })
    .mouseDownAction_({ |view, x, y, mod, button, count|
        ~mouseActive = true;
        ~lastInputSource = \mouse;
    })
    .mouseUpAction_({ |view, x, y, mod, button, count|
        ~mouseActive = false;
    });

~tumbleKnob = Knob360(mainView, Rect(654, 224, 60, 60), 0.5, 0.0, 1.0)
    .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
    .enabled_(false)
    .action_({ |knob, val|
        var deg = val.linlin(0, 1, -180, 180).round.asInteger;
        if(~mouseActive, {
            deg = deg.neg;
            ~lastInputSource = \mouse;
        }, {
            ~lastInputSource = \headtracker;
        });
        ~tumbleValue.string = (deg.asString ++ "°");
        if(~synth.notNil) { ~synth.set(\tumble, deg.degrad); }
    })
    .mouseDownAction_({ |view, x, y, mod, button, count|
        ~mouseActive = true;
        ~lastInputSource = \mouse;
    })
    .mouseUpAction_({ |view, x, y, mod, button, count|
        ~mouseActive = false;
    });

// Q-Panner for quad output
~xyPanner = Slider2D(mainView, Rect(629, 334, 110, 110))
    .x_(0.5).y_(0.5)
    .knobColor_(Color.cyan)
    .background_(Color.black)
    .canFocus_(false)
    .action_({ |sl|
        var angleLR = sl.x.linlin(0, 1, 0, pi/2);
        var quadLR = sin(angleLR) - cos(angleLR);
        var angleFR = sl.y.linlin(0, 1, 0, pi/2);
        var quadFR = sin(angleFR) - cos(angleFR);
        ~xyPannerPos = Point(sl.x, sl.y);
        if(~synth.notNil) {
            ~synth.set(\quadLR, quadLR, \quadFR, quadFR);
        }
    });

~xyPannerPos = Point(~xyPanner.x, ~xyPanner.y);

// GUI Labels
StaticText(mainView, Rect(618, 10, 140, 28))
    .string_("HEADTRACKER")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

StaticText(mainView, Rect(594, 80, 55, 20)).string_("ROTATE").align_(\right).stringColor_(Color.cyan).font_(Font("Helvetica", 11));
StaticText(mainView, Rect(594, 162, 55, 20)).string_("TILT").align_(\right).stringColor_(Color.cyan).font_(Font("Helvetica", 11));
StaticText(mainView, Rect(594, 244, 55, 20)).string_("TUMBLE").align_(\right).stringColor_(Color.cyan).font_(Font("Helvetica", 11));

~headtrackBtn = Button(mainView, Rect(742, 62, 40, 20))
    .states_([["OFF", Color.cyan, Color.black], ["ON", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({ |btn|
        var on = btn.value == 1;
        var idx = ~dmenu.value;
        var isBinaural = (idx == 0) or: { idx == 1 };

        if(~knobOverlay.notNil) { ~knobOverlay.remove; ~knobOverlay = nil; };
        if(isBinaural) {
            if(on) {
                ~rotateKnob.enabled_(true);
                ~tiltKnob.enabled_(true);
                ~tumbleKnob.enabled_(true);
            } {
                ~rotateKnob.enabled_(false);
                ~tiltKnob.enabled_(false);
                ~tumbleKnob.enabled_(false);
                ~knobOverlay = View(mainView, Rect(594, 60, 147, 224))
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
            }
        }
    })
    .value_(0);

~headtrackResetBtn = Button(mainView, Rect(742, 102, 40, 20))
    .states_([["RESET", Color.cyan, Color.black]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({
        ~rotateKnob.valueAction_(0.5); ~rotateKnob.enabled_(false);
        ~tiltKnob.valueAction_(0.5); ~tiltKnob.enabled_(false);
        ~tumbleKnob.valueAction_(0.5); ~tumbleKnob.enabled_(false);
    });

StaticText(mainView, Rect(629, 299, 110, 22))
    .string_("Q-PANNER")
    .align_(\center)
    .stringColor_(Color.cyan)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .background_(Color.clear);

// Output fader (unchanged)
StaticText(mainView, Rect(544, 40, 24, 24))
    .string_("dB")
    .align_(\center)
    .stringColor_(Color.cyan)
    .font_(Font("Helvetica", 13));

StaticText(mainView, Rect(520, 10, 72, 28))
    .string_("OUTPUT")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

~outputSlider = Slider(mainView, Rect(544, 70, 24, 300))
    .orientation_(\vertical)
    .background_(Color.black)
    .focusColor_(Color.clear)
    .knobColor_(Color.cyan)
    .action_({ |sl|
        var db = sl.value.linlin(0, 1, -60, 0).round(1).asInteger;
        ~outputValue.string_(db.asString);
        if(~synth.notNil) {
            var amp = 10.pow(db / 20);
            ~synth.set(\amp, amp);
        }
    });

~outputValue = StaticText(mainView, Rect(544, 380, 24, 24))
    .string_("0")
    .align_(\center)
    .stringColor_(Color.cyan)
    .font_(Font("Helvetica", 13));

~outputSlider.valueAction_(1.0);

// Output fader tick marks
UserView(mainView, Rect(537, 70, 4, 300))
    .background_(Color.clear)
    .drawFunc_({ |view|
        Pen.color = Color.cyan;
        Pen.width = 1;
        [0, 50, 100, 150, 200, 250, 300].do({ |y|
            Pen.line(Point(0, y), Point(4, y));
            Pen.stroke;
        });
        [25, 75, 125, 175, 225, 275].do({ |y|
            Pen.line(Point(1, y), Point(3, y));
            Pen.stroke;
        });
    });

UserView(mainView, Rect(571, 70, 4, 300))
    .background_(Color.clear)
    .drawFunc_({ |view|
        Pen.color = Color.cyan;
        Pen.width = 1;
        [0, 50, 100, 150, 200, 250, 300].do({ |y|
            Pen.line(Point(0, y), Point(4, y));
            Pen.stroke;
        });
        [25, 75, 125, 175, 225, 275].do({ |y|
            Pen.line(Point(1, y), Point(3, y));
            Pen.stroke;
        });
    });

// --- Synth Parameter State Management (for encoder/decoder changes) ---
~saveSynthParams = {
    var currentEqValues, currentAmbienceValues;

    ("Debug: Saving synth params. ~eqSliders = " ++ ~eqSliders ++ ", ~ambienceSliders = " ++ ~ambienceSliders).postln;

    // Always use stored state values - these are maintained by the GUI save/restore functions
    // Convert EQ slider values (0-1) to dB values (-12 to +12)
    if(~eqState[\sliderValues].notNil) {
        currentEqValues = ~eqState[\sliderValues].collect({ |sliderVal|
            if(sliderVal.notNil) {
                sliderVal.linlin(0, 1, -12, 12);
            } {
                0; // Default if value is nil
            };
        });
        ~eqState[\synthParams] = currentEqValues;
        ("Saved synth EQ params: " ++ currentEqValues).postln;
    } {
        // Use default flat EQ if no stored values
        ~eqState[\synthParams] = [0, 0, 0, 0, 0, 0, 0];
        ("Using default EQ params").postln;
    };

    // Use stored ambience values directly (they're already in synth parameter format)
    if(~ambienceState[\sliderValues].notNil) {
        ~ambienceState[\synthParams] = ~ambienceState[\sliderValues];
        ("Saved synth ambience params: " ++ ~ambienceState[\sliderValues]).postln;
    } {
        // Use default ambience settings if no stored values
        ~ambienceState[\synthParams] = [0.0, 0.2, 0.2, 0.2, 0.0, 0.0, 0.0];
        ("Using default ambience params").postln;
    };
};

~restoreSynthParams = {
    // Restore EQ parameters to new synth
    if(~synth.notNil and: { ~eqState[\synthParams].notNil }) {
        var eqParams = [\eq1, \eq2, \eq3, \eq4, \eq5, \eq6, \eq7];
        ~eqState[\synthParams].do({ |dbValue, i|
            if(dbValue.notNil and: { i < eqParams.size }) {
                ~synth.set(eqParams[i], dbValue);
            };
        });
        ("Restored synth EQ params: " ++ ~eqState[\synthParams]).postln;
    };

    // Restore ambience parameters to new synth
    if(~synth.notNil and: { ~ambienceState[\synthParams].notNil }) {
        var params = ~ambienceState[\synthParams];
        if(params.size >= 7) {
            // Convert slider values (0-1) to synth parameter ranges (matching GUI slider actions)
            ~synth.set(
                \ambience, (params[0] ? 0).linlin(0, 1, 0, 0.2),    // Mix: 0-20%
                \preDelay, params[1] ? 0,                            // PreDelay: direct value
                \lowRT, (params[2] ? 0.2).linlin(0, 1, 0.2, 4),     // LowRT: 0.2-4s
                \highRT, (params[3] ? 2).linlin(0, 1, 0.2, 4),      // HighRT: 0.2-4s
                \dispersion, params[4] ? 1,                          // Dispersion: direct value
                \modWidth, params[5] ? 0.2,                          // ModWidth: direct value
                \modRate, params[6] ? 0.3                            // ModRate: direct value
            );
            ("Restored synth ambience params (converted): mix=" ++ (params[0] ? 0).linlin(0, 1, 0, 0.2) ++ ", others=" ++ params[1..6]).postln;
        } {
            ("Warning: ambience params array too small: " ++ params).postln;
        };
    };
};

// --- AmbiVerbSC Preset Loading Function ---
~loadAmbiVerbSCPresets = {
    var presetDir, presetFiles, presetData, presetNames, presetDict;
    var extractParamValue, parsePresetFile, possiblePaths;

    // Try to find AmbiVerbSC preset files using multiple possible locations
    possiblePaths = [
        Quarks.folder ++ "/AmbiVerbSC/Data/Presets/",
        Quarks.folder ++ "/AmbiVerbSC/presets/",
        Quarks.folder ++ "/AmbiVerbSC/Data/",
        Platform.userExtensionDir ++ "/AmbiVerbSC/Data/Presets/",
        Platform.userExtensionDir ++ "/AmbiVerbSC/presets/",
        Platform.userExtensionDir ++ "/AmbiVerbSC/Data/",
        Platform.systemExtensionDir ++ "/AmbiVerbSC/Data/Presets/",
        Platform.systemExtensionDir ++ "/AmbiVerbSC/presets/",
        Platform.systemExtensionDir ++ "/AmbiVerbSC/Data/"
    ];

    presetDir = nil;
    presetFiles = [
        "default.txt",
        "high verb.txt",
        "huge hall.txt",
        "large hall.txt",
        "low verb.txt",
        "mod echo.txt",
        "spatial delay.txt",
        "time modulation .txt"
    ];

    // Function to extract parameter value from preset array
    extractParamValue = { |array, paramName|
        var index = array.indexOf(paramName);
        if(index.notNil and: { index + 1 < array.size }) {
            array[index + 1];
        } {
            nil;
        };
    };

    // Function to parse a single preset file using AmbiVerbSC's method
    parsePresetFile = { |filePath|
        var presetData, params;

        try {
            // Use AmbiVerbSC's own method to read preset files
            presetData = Object.readArchive(filePath);

            if(presetData.notNil) {
                // Extract the key parameters we need
                params = Dictionary.newFrom([
                    \roomName, presetData[\size] ? "Brahmssaal",
                    \mix, presetData[\mix] ? 0,
                    \preDelay, presetData[\preDelay] ? 0,
                    \lowRT, presetData[\lowRT] ? 0.01,
                    \highRT, presetData[\highRT] ? 0.01,
                    \dispersion, presetData[\dispersion] ? 1,
                    \modWidth, presetData[\modWidth] ? 0,
                    \modRate, presetData[\modRate] ? 0.01,
                    \coupRate, presetData[\coupRate] ? 0.001,
                    \coupAmt, presetData[\coupAmt] ? 0,
                    \phaseRotRate, presetData[\phaseRotRate] ? 0.001,
                    \phaseRotAmt, presetData[\phaseRotAmt] ? 0,
                    \phaseRotMix, presetData[\phaseRotMix] ? 1,
                    \crossoverFreq, presetData[\crossoverFreq] ? 1216.46,
                    \spread, presetData[\spread] ? 1,
                    \orient, presetData[\orient] ? 'flu'
                ]);
            } {
                params = Dictionary.new;
            };
        } { |error|
            ("Error loading preset file: " ++ filePath ++ " - " ++ error).postln;
            params = Dictionary.new;
        };

        params;
    };

    // Find the first valid path
    possiblePaths.do({ |path|
        if(presetDir.isNil and: { File.exists(path) }) {
            presetDir = path;
            ("Found AmbiVerbSC presets at: " ++ path).postln;
        };
    });

    if(presetDir.isNil) {
        ("AmbiVerbSC preset files not found in standard locations").postln;
        ("Using built-in room presets instead").postln;

        // Fallback to built-in room presets
        presetNames = List.new;
        presetDict = Dictionary.new;

        // Create simple presets using known AmbiVerbSC room names
        [
            ["default", "Brahmssaal", [0, 0, 0.01, 0.01, 1, 0, 0.01]],
            ["high verb", "Magna Auditorium", [0.63, 0, 0.01, 2.5, 0.76, 0.19, 0.037]],
            ["huge hall", "Goldener Saal", [0.8, 0.1, 0.5, 3.0, 0.5, 0.1, 0.02]],
            ["large hall", "Steinerner Saal", [0.6, 0.05, 0.3, 2.0, 0.8, 0.05, 0.01]],
            ["low verb", "Holzerner Saal", [0.3, 0, 0.1, 1.0, 0.9, 0.02, 0.005]]
        ].do({ |presetInfo|
            var name = presetInfo[0];
            var room = presetInfo[1];
            var params = presetInfo[2];

            presetNames.add(name);
            presetDict[name] = Dictionary.newFrom([
                \roomName, room,
                \mix, params[0],
                \preDelay, params[1],
                \lowRT, params[2],
                \highRT, params[3],
                \dispersion, params[4],
                \modWidth, params[5],
                \modRate, params[6]
            ]);
            ("Created built-in preset: " ++ name ++ " (Room: " ++ room ++ ")").postln;
        });

        [presetNames, presetDict];
    } {
        presetNames = List.new;
        presetDict = Dictionary.new;

        presetFiles.do({ |fileName|
            var filePath = presetDir ++ fileName;
            var presetName = fileName.replace(".txt", "");
            var presetData = parsePresetFile.(filePath);

            if(presetData.notEmpty) {
                presetNames.add(presetName);
                presetDict[presetName] = presetData;
                ("Loaded preset: " ++ presetName ++ " (Room: " ++ presetData[\roomName] ++ ")").postln;
            };
        });

        [presetNames, presetDict];
    };
};

// --- AmbiVerbSC Preset Recall Function ---
~recallAmbiVerbSCPreset = { |presetName|
    var presetData, roomName;

    if(~ambiencePresetDict.notNil and: { ~ambiencePresetDict[presetName].notNil }) {
        presetData = ~ambiencePresetDict[presetName];
        roomName = presetData[\roomName];

        // Ensure roomName is not nil
        if(roomName.isNil) {
            ("Warning: No room name found in preset " ++ presetName ++ ", using Brahmssaal").postln;
            roomName = "Brahmssaal";
        };

        // Update sliders with preset values
        if(~ambienceSliders.notNil) {
            // Map preset values to slider ranges
            ~ambienceSliders[0].value_(presetData[\mix].linlin(0, 1, 0, 1)); // Mix
            ~ambienceSliders[1].value_(presetData[\preDelay].linlin(0, 0.5, 0, 1)); // PreDelay
            ~ambienceSliders[2].value_(presetData[\lowRT].linlin(0.01, 2, 0, 1)); // LowRT
            ~ambienceSliders[3].value_(presetData[\highRT].linlin(0.01, 4, 0, 1)); // HighRT
            ~ambienceSliders[4].value_(presetData[\dispersion].linlin(0.1, 2, 0, 1)); // Dispersion
            ~ambienceSliders[5].value_(presetData[\modWidth].linlin(0, 1, 0, 1)); // ModWidth
            ~ambienceSliders[6].value_(presetData[\modRate].linlin(0, 1, 0, 1)); // ModRate

            // Trigger slider actions to update synth
            ~ambienceSliders.do({ |slider, i|
                if(slider.action.notNil) {
                    slider.action.value(slider);
                };
            });
        };

        // Update synth with new room and parameters (without breaking audio)
        if(~synth.notNil) {
            // Use synth.set() instead of recreating to avoid signal break
            ~synth.set(
                \ambience, presetData[\mix].linlin(0, 1, 0, 0.2),
                \preDelay, presetData[\preDelay].linlin(0, 0.5, 0, 1),
                \lowRT, presetData[\lowRT].linlin(0.01, 2, 0.1, 2),
                \highRT, presetData[\highRT].linlin(0.01, 4, 0.2, 4),
                \dispersion, presetData[\dispersion].linlin(0.1, 2, 0.1, 2),
                \modWidth, presetData[\modWidth].linlin(0, 1, 0, 1),
                \modRate, presetData[\modRate].linlin(0, 1, 0, 1),
                \size, roomName.asSymbol
            );
        };

        ("Applied preset: " ++ presetName ++ " (Room: " ++ roomName ++ ")").postln;
    };
};

// --- MAPLIN SM-333 CONTROL FUNCTIONS ---
~setMaplinSurround = { |level=0.8|
    if(~synth.notNil) { ~synth.set(\maplinSurround, level); };
    ~maplinState[\surround] = level;
    ("Maplin surround level: " ++ (level * 100).round(1) ++ "%").postln;
};

~setMaplinEffect = { |level=0.8|
    if(~synth.notNil) { ~synth.set(\maplinEffect, level); };
    ~maplinState[\effect] = level;
    ("Maplin effect level: " ++ (level * 100).round(1) ++ "%").postln;
};

~setMaplinDelay = { |time=0.4|
    var delayMs = time.linlin(0, 1, 5, 50);
    if(~synth.notNil) { ~synth.set(\maplinDelay, time); };
    ~maplinState[\delay] = time;
    ("Maplin delay time: " ++ delayMs.round(1) ++ "ms").postln;
};

~setMaplinActive = { |active=true|
    if(~synth.notNil) { ~synth.set(\maplinActive, if(active, 1, 0)); };
    ~maplinState[\active] = if(active, 1, 0);
    ("Maplin processing: " ++ if(active, "ACTIVE", "BYPASSED")).postln;
};

// --- MAPLIN PRESET FUNCTIONS ---
~maplinPresetBalanced = {
    ~setMaplinSurround.(0.8);
    ~setMaplinEffect.(0.8);
    ~setMaplinDelay.(0.4);  // ~25ms
    "Maplin balanced preset applied".postln;
};

~maplinPresetMax = {
    ~setMaplinSurround.(1.0);
    ~setMaplinEffect.(1.0);
    ~setMaplinDelay.(1.0);  // ~50ms
    "Maplin maximum preset applied".postln;
};

// --- MAPLIN STATE MANAGEMENT FUNCTIONS ---
~saveMaplinState = {
    if(~maplinSurroundKnob.notNil) {
        ~maplinState[\surround] = ~maplinSurroundKnob.value;
        ~maplinState[\effect] = ~maplinEffectKnob.value;
        ~maplinState[\delay] = ~maplinDelayKnob.value;
        ("Saved Maplin GUI state: surround=" ++ ~maplinState[\surround] ++ ", effect=" ++ ~maplinState[\effect] ++ ", delay=" ++ ~maplinState[\delay]).postln;
    };
};

~restoreMaplinState = {
    if(~maplinSurroundKnob.notNil) {
        ~maplinSurroundKnob.value_(~maplinState[\surround] ? 0.8);
        ~maplinEffectKnob.value_(~maplinState[\effect] ? 0.8);
        ~maplinDelayKnob.value_(~maplinState[\delay] ? 0.4);

        // Update value displays
        ~maplinSurroundValue.string_((~maplinState[\surround] * 100).round(1).asString ++ "%");
        ~maplinEffectValue.string_((~maplinState[\effect] * 100).round(1).asString ++ "%");
        ~maplinDelayValue.string_((~maplinState[\delay].linlin(0, 1, 5, 50).round(1).asString ++ " ms"));

        // Trigger actions to update synth
        if(~maplinSurroundKnob.action.notNil) { ~maplinSurroundKnob.action.value(~maplinSurroundKnob); };
        if(~maplinEffectKnob.action.notNil) { ~maplinEffectKnob.action.value(~maplinEffectKnob); };
        if(~maplinDelayKnob.action.notNil) { ~maplinDelayKnob.action.value(~maplinDelayKnob); };

        ("Restored Maplin GUI state: surround=" ++ ~maplinState[\surround] ++ ", effect=" ++ ~maplinState[\effect] ++ ", delay=" ++ ~maplinState[\delay]).postln;
    };
};

// --- Overlay Buttons (EQ, AMBIENCE, LAYOUT, SM-333) below meter area ---
~eqBtn = Button(mainView, Rect(180, 410, 100, 35))
    .states_([ ["EQ", Color.cyan, Color.black], ["EQ", Color.black, Color.cyan] ])
    .font_(Font("Helvetica", 13))
	.focusColor_(Color.clear)
    .action_({ |btn|
        var freqs, eqWidth, sliderWidth, sliderHeight, startX, gap;
        if(btn.value == 1) {
            // --- RADIO BUTTON BEHAVIOR: Only one overlay/button active at a time ---
            if(~ambienceOverlay.notNil) {
                ~saveAmbienceState.value(); // Save state before removing ambience overlay
                ~ambienceOverlay.remove; ~ambienceOverlay = nil; ~ambienceBtn.value_(0);
            };
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; ~layoutBtn.value_(0); };
            if(~maplinOverlay.notNil) {
                ~saveMaplinState.value(); // Save state before removing maplin overlay
                ~maplinOverlay.remove; ~maplinOverlay = nil; ~maplinBtn.value_(0);
            };
            // Set other buttons to 0 (radio group)
            ~ambienceBtn.value_(0);
            ~layoutBtn.value_(0);
            ~maplinBtn.value_(0);
            // --- Remove any previous EQ overlay and controls to prevent duplicates ---
            if(~eqOverlay.notNil) { ~eqOverlay.remove; ~eqOverlay = nil; };
            ~eqSliders = nil; ~eqValues = nil; ~eqPresetMenu = nil;
            // Create EQ overlay directly in main window
            ~eqOverlay = View(mainView, Rect(180, 107, 320, 275)).background_(Color.black);
            UserView(~eqOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });
            StaticText(~eqOverlay, Rect(10, 5, 120, 20))
                .string_("GRAPHIC EQ")
                .align_(\left)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);
            // Only built-in presets by default (use symbols for names and keys)
            ~eqPresetNames = [\Flat, \Vocal, \BassBoost, \TrebleBoost, \RIAA];
            ~eqPresetDict = IdentityDictionary.newFrom([
                \Flat,        [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],
                \Vocal,       [0.4, 0.45, 0.6, 0.7, 0.6, 0.45, 0.4], // gentle mid boost
                \BassBoost,   [0.8, 0.7, 0.6, 0.5, 0.5, 0.5, 0.5],  // low bands up
                \TrebleBoost, [0.5, 0.5, 0.5, 0.5, 0.6, 0.7, 0.8],  // high bands up
                \RIAA,        [0.95, 0.85, 0.7, 0.55, 0.4, 0.25, 0.1]
            ]);
            // Define recall function for EQ presets
            ~recallEqPreset = {
                var name = ~eqPresetNames[~eqPresetMenu.value].asSymbol;
                if(~eqOverlay.notNil and: (~eqSliders.notNil)) {
                    if(~eqPresetDict.notNil and: { ~eqPresetDict[name].notNil }) {
                        ~eqPresetDict[name].do({ |val, i|
                            ~eqSliders[i].value_(val);
                            if(~eqSliders[i].action.notNil) {
                                ~eqSliders[i].action.value(~eqSliders[i]);
                            }
                        });
                    } {
                        // Fallback to flat if preset not found
                        ~eqSliders.do({ |slider, i|
                            slider.value_(0.5);
                            if(slider.action.notNil) {
                                slider.action.value(slider);
                            }
                        });
                    }
                }
            };
            ~eqPresetMenu = PopUpMenu(~eqOverlay, Rect(140, 7, 110, 20))
                .items_(~eqPresetNames.collect(_.asString))
                .font_(Font("Helvetica", 11))
                .background_(Color.black)
                .stringColor_(Color.cyan)
                .value_(0)
                .action_({
                    ~recallEqPreset.value;
                });
            Button(~eqOverlay, Rect(255, 7, 58, 20))
                .states_([["SAVE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 10))
                .action_({
                    var newName, values, customNum;
                    values = ~eqSliders.collect({ |slider| slider.value });
                    // Find next available custom preset number
                    if(~eqPresetNames.select({ |n| n.asString.beginsWith("Custom ") }).isEmpty) {
                        customNum = 1;
                    } {
                        customNum = ~eqPresetNames.select({ |n| n.asString.beginsWith("Custom ") })
                            .collect({ |n| n.asString.drop(7).asInteger })
                            .maxItem + 1;
                    };
                    newName = ("Custom " ++ customNum).asSymbol;
                    ~eqPresetNames = ~eqPresetNames.add(newName);
                    ~eqPresetMenu.items = ~eqPresetNames.collect(_.asString);
                    ~eqPresetMenu.value = ~eqPresetNames.size - 1;
                    if(~eqPresetDict.isNil) { ~eqPresetDict = IdentityDictionary.new; };
                    ~eqPresetDict[newName] = values;
                    ~recallEqPreset.value; // Ensure recall after adding
                });
            freqs = [63, 160, 400, 1000, 2500, 6400, 12000];
            sliderWidth = 32; sliderHeight = 140; startX = 12; gap = 44;
            // --- Draw tick marks BETWEEN the sliders (6 sets, not behind sliders) ---
            [44, 88, 132, 176, 220, 264].do({ |x|
                UserView(~eqOverlay, Rect(x, 55, 12, sliderHeight))
                    .background_(Color.clear)
                    .drawFunc_({ |view|
                        // Use absolute values for tick drawing
                        Pen.color = Color.cyan;
                        Pen.width = 1.5;
                        // Major ticks
                        Pen.line(Point(2, 0), Point(10, 0)); Pen.stroke; // +12dB
                        Pen.line(Point(2, 70), Point(10, 70)); Pen.stroke; // 0dB (halfway)
                        Pen.line(Point(2, 140), Point(10, 140)); Pen.stroke; // -12dB
                        // Minor ticks
                        Pen.width = 1;
                        Pen.line(Point(4, 35), Point(9, 35)); Pen.stroke; // +6dB
                        Pen.line(Point(4, 105), Point(9, 105)); Pen.stroke; // -6dB
                    });
            });
            freqs.do({ |freq, i|
                var x = startX + (i * gap);
                // Frequency label
                StaticText(~eqOverlay, Rect(x, 35, sliderWidth, 16))
                    .string_(if(freq >= 1000, (freq/1000).asString ++ "k", freq.asString))
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 10))
                    .background_(Color.clear);
            });
            // Create value labels first so they exist for slider actions
            ~eqValues = freqs.collect({ |freq, i|
                var x = startX + (i * gap);
                StaticText(~eqOverlay, Rect(x, 200, sliderWidth, 16))
                    .string_("0.0dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9))
                    .background_(Color.clear);
            });
            ~eqSliders = freqs.collect({ |freq, i|
                var x = startX + (i * gap);
                var slider = Slider(~eqOverlay, Rect(x, 55, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .background_(Color.clear)
                    .focusColor_(Color.clear)
                    .knobColor_(Color.cyan)
                    .value_(0.5)
                    .toolTip_("EQ BAND " ++ (i+1).asString)
                    .action_({ |sl|
                        var db = sl.value.linlin(0, 1, -12, 12);
                        if(~eqValues.notNil and: { ~eqValues[i].notNil }) {
                            ~eqValues[i].string = db.round(0.1).asString ++ "dB";
                        };
                        if(~synth.notNil) {
                            var eqParams = [\eq1, \eq2, \eq3, \eq4, \eq5, \eq6, \eq7];
                            ~synth.set(eqParams[i], db);
                        }
                    });
                slider.toolTip = "EQ BAND " ++ (i+1).asString;
                slider;
            });
            // Assign the preset recall action after controls are created
            ~eqPresetMenu.action_({
                ~recallEqPreset.value;
            });
            // --- Add dB scale numbers to the right of the rightmost slider ---
            [
                ["+12", 55],
                ["+6", 55 + 35],
                [" 0", 55 + 70],
                ["-6", 55 + 105],
                ["-12", 55 + 140]
            ].do({ |pair|
                var label, y;
                label = pair[0];
                y = pair[1];
                StaticText(~eqOverlay, Rect(startX + (6 * gap) + sliderWidth + 0, y - 8, 32, 16)) // moved 3px left
                    .string_(label)
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 7))
                    .background_(Color.clear);
            });
            Button(~eqOverlay, Rect(18, 230, 80, 28))
                .states_([["RESET", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~eqSliders.do({ |slider, i|
                        slider.value_(0.5);
                        ~eqValues[i].string_("0.0dB");
                        if(~synth.notNil) {
                            var eqParams = [\eq1, \eq2, \eq3, \eq4, \eq5, \eq6, \eq7];
                            ~synth.set(eqParams[i], 0);
                        }
                    });
                });
            Button(~eqOverlay, Rect(222, 230, 80, 28))
                .states_([["CLOSE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~saveEqState.value(); // Save state before closing
                    ~eqOverlay.remove;
                    ~eqOverlay = nil;
                    ~eqBtn.value_(0);
                });
            ~eqOverlay.front;
            // --- Restore EQ state after controls are created ---
            ~restoreEqState.value();
            // --- On open, set synth EQ params to current slider values ---
            if(~synth.notNil) {
                var eqParams = [\eq1, \eq2, \eq3, \eq4, \eq5, \eq6, \eq7];
                ~eqSliders.do({ |slider, i|
                    var db = slider.value.linlin(0, 1, -12, 12);
                    ~synth.set(eqParams[i], db);
                });
            }
        } {
            if(~eqOverlay.notNil) { ~eqOverlay.remove; ~eqOverlay = nil; };
            ~eqSliders = nil; ~eqValues = nil; ~eqPresetMenu = nil;
        }
    });

// --- AMBIENCE BUTTON ---
~ambienceBtn = Button(mainView, Rect(399, 410, 100, 35))
    .states_([["AMBIENCE", Color.cyan, Color.black], ["AMBIENCE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
	.focusColor_(Color.clear)
    .action_({ |btn|
        var params, sliderLabels, sliderWidth, sliderHeight, startX, gap, x, slider, valDisp;
        if(btn.value == 1) {
            // --- RADIO BUTTON BEHAVIOR: Only one overlay/button active at a time ---
            if(~eqOverlay.notNil) {
                ~saveEqState.value(); // Save state before removing EQ overlay
                ~eqOverlay.remove; ~eqOverlay = nil; ~eqBtn.value_(0);
            };
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; ~layoutBtn.value_(0); };
            if(~maplinOverlay.notNil) {
                ~saveMaplinState.value(); // Save state before removing maplin overlay
                ~maplinOverlay.remove; ~maplinOverlay = nil; ~maplinBtn.value_(0);
            };
            // Set other buttons to 0 (radio group)
            ~eqBtn.value_(0);
            ~layoutBtn.value_(0);
            ~maplinBtn.value_(0);
            // --- Remove any previous Ambience overlay and controls to prevent duplicates ---
            if(~ambienceOverlay.notNil) { ~ambienceOverlay.remove; ~ambienceOverlay = nil; };
            // --- Initialize layout variables (fix nil error) ---
            sliderWidth = 32; sliderHeight = 140; startX = 12; gap = 44;
            // Create Ambience overlay directly in main window
            ~ambienceOverlay = View(mainView, Rect(180, 107, 320, 275)).background_(Color.black);
            UserView(~ambienceOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });
            StaticText(~ambienceOverlay, Rect(10, 5, 120, 22))
                .string_("AMBIENCE")
                .align_(\left)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);

            // Load AmbiVerbSC presets if not already loaded
            if(~ambiencePresetNames.isNil) {
                var presetData = ~loadAmbiVerbSCPresets.value();
                ~ambiencePresetNames = presetData[0];
                ~ambiencePresetDict = presetData[1];
            };

            // Preset selector (dropdown)
            ~ambiencePresetMenu = PopUpMenu(~ambienceOverlay, Rect(140, 7, 170, 20))
                .items_(["Default", "High Verb", "Huge Hall", "Large Hall", "Low Verb", "Mod Echo", "Spatial Delay", "Time Modulation"])
                .font_(Font("Helvetica", 11))
                .background_(Color.black)
                .stringColor_(Color.cyan)
                .value_(~ambienceState[\presetIndex] ? 0) // Use saved preset index
                .action_({ |menu|
                    var selectedPreset = ~ambiencePresetNames[menu.value];
                    ~recallAmbiVerbSCPreset.value(selectedPreset);
                });
            // Parameter labels and values (use saved state or defaults)
            sliderLabels = ["Reverb", "PreDly", "LoRT", "HiRT", "Disp", "MWid", "MRate"];
            params = ~ambienceState[\sliderValues] ? [0.0, 0.2, 0.2, 0.2, 0.0, 0.0, 0.0];
            ~ambienceLastMix = ~ambienceState[\lastMix] ? 0.5; // Remember last nonzero mix value
            ~ambienceSliders = List[];
            ~ambienceValues = List[];
            sliderLabels.do({ |label, i|
                x = startX + (i * gap);
                StaticText(~ambienceOverlay, Rect(x, 35, sliderWidth, 16))
                    .string_(label)
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 10))
                    .background_(Color.clear);
                slider = Slider(~ambienceOverlay, Rect(x, 55, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .knobColor_(Color.cyan)
                    .value_(params[i])
                    .action_({ |sl|
                        var val = (sl.value * 100).round(0.1);
                        ~ambienceValues[i].string = val.asString ++ "%";
                        if(~synth.notNil) {
                            switch(i,
                                0, {
                                    ~synth.set(\ambience, sl.value.linlin(0, 1, 0, 0.2));
                                    // --- Sync ON/OFF button with Mix slider ---
                                    if(sl.value > 0) {
                                        ~ambienceOnOffBtn.value_(1);
                                        ~ambienceLastMix = sl.value;
                                    } {
                                        ~ambienceOnOffBtn.value_(0);
                                    }
                                },
                                1, { ~synth.set(\preDelay, sl.value.linlin(0,1,0,0.5)); },
                                2, { ~synth.set(\lowRT, sl.value.linlin(0,1,0.1,2)); },
                                3, { ~synth.set(\highRT, sl.value.linlin(0,1,0.2,4)); },
                                4, { ~synth.set(\dispersion, sl.value.linlin(0,1,0.1,2)); },
                                5, { ~synth.set(\modWidth, sl.value); },
                                6, { ~synth.set(\modRate, sl.value); }
                            );
                        }
                    });
                ~ambienceSliders.add(slider);
                valDisp = StaticText(~ambienceOverlay, Rect(x, 200, sliderWidth, 16))
                    .string_((params[i] * 100).asString ++ "%")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9))
                    .background_(Color.clear);
                ~ambienceValues.add(valDisp);
            });
            // Close button
            Button(~ambienceOverlay, Rect(222, 230, 80, 28))
                .states_([["CLOSE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~saveAmbienceState.value(); // Save state before closing
                    ~ambienceOverlay.remove;
                    ~ambienceOverlay = nil;
                    ~ambienceBtn.value_(0);
                });
            // Place RESET button before CLOSE button in the Ambience overlay:
            Button(~ambienceOverlay, Rect(18, 230, 80, 28))
                .states_([ ["RESET", Color.cyan, Color.black] ])
                .font_(Font("Helvetica", 11))
                .action_({
                    // Reset to default preset
                    if(~ambiencePresetNames.notNil and: { ~ambiencePresetNames.size > 0 }) {
                        ~ambiencePresetMenu.value_(0); // Select first preset
                        ~recallAmbiVerbSCPreset.value(~ambiencePresetNames[0]);
                    }
                });
            ~ambienceOverlay.front;
            // Restore saved state or apply default preset on overlay open
            if(~ambienceState[\sliderValues].notNil and: { ~ambienceState[\sliderValues].size > 0 }) {
                ("Found saved state, restoring...").postln;
                ~restoreAmbienceState.value(); // Restore saved slider values
            } {
                ("No saved state, applying default preset...").postln;
                // Apply default preset if no saved state
                if(~ambiencePresetNames.notNil and: { ~ambiencePresetNames.size > 0 }) {
                    ~recallAmbiVerbSCPreset.value(~ambiencePresetNames[0]);
                }
            }
        } {
            if(~ambienceOverlay.notNil) { ~ambienceOverlay.remove; ~ambienceOverlay = nil; };
        }
    });

// --- LAYOUT BUTTON ---
~layoutBtn = Button(mainView, Rect(508, 410, 100, 35))
    .states_([["LAYOUT", Color.cyan, Color.black], ["LAYOUT", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
	.focusColor_(Color.clear)
    .action_({ |btn|
        var currentDecoder, decoderNames, decoderName;
        if(btn.value == 1) {
            // --- RADIO BUTTON BEHAVIOR: Only one overlay/button active at a time ---
            if(~eqOverlay.notNil) {
                ~saveEqState.value(); // Save state before removing EQ overlay
                ~eqOverlay.remove; ~eqOverlay = nil; ~eqBtn.value_(0);
            };
            if(~ambienceOverlay.notNil) {
                ~saveAmbienceState.value(); // Save state before removing ambience overlay
                ~ambienceOverlay.remove; ~ambienceOverlay = nil; ~ambienceBtn.value_(0);
            };
            if(~maplinOverlay.notNil) {
                ~saveMaplinState.value(); // Save state before removing maplin overlay
                ~maplinOverlay.remove; ~maplinOverlay = nil; ~maplinBtn.value_(0);
            };
            // Set other buttons to 0 (radio group)
            ~eqBtn.value_(0);
            ~ambienceBtn.value_(0);
            ~maplinBtn.value_(0);
            ~layoutOverlay = View(mainView, Rect(180, 107, 320, 275))
                .background_(Color.black); // Remove .alpha_(0.5) for full opacity
            // Add the title as StaticText at the top, centered
            StaticText(~layoutOverlay, Rect(10, 5, 300, 22))
                .string_("LAYOUT - " ++ (["BINAURAL IRCAM", "BINAURAL CIPIC", "QUAD SQUARE", "QUAD NARROW", "QUAD WIDE", "DOLBY 5.1", "OCTAGON"][~dmenu.value ? 0]))
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);
            UserView(~layoutOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |view|
                    var bounds = view.bounds;
                    var centerX = bounds.width / 2;
                    var centerY = bounds.height / 2;
                    var currentDecoderValue = ~dmenu.value;
                    // Draw cyan border
                    Pen.width = 0.5;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0.25, 0.25, bounds.width - 0.5, bounds.height - 0.5));
                    Pen.stroke;
                    Pen.width = 2;
                    switch(currentDecoderValue,
                        0, { // IRCAM Binaural
                            var earCupWidth = 20, earCupHeight = 27, earCupOffset = 55, arcCenterY = centerY - 25 + 25, arcRadius = 47, leftEarX, leftEarY, rightEarX, rightEarY;
                            leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                            leftEarY = centerY + 25 + 25;
                            rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                            rightEarY = centerY + 25 + 25;
                            Pen.color = Color.cyan; Pen.width = 2;
                            Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi); Pen.stroke;
                            Pen.moveTo(Point(centerX - arcRadius, centerY - 30 + 25)); Pen.lineTo(Point(centerX - arcRadius, leftEarY)); Pen.stroke;
                            Pen.moveTo(Point(centerX + arcRadius, centerY - 30 + 25)); Pen.lineTo(Point(centerX + arcRadius, rightEarY)); Pen.stroke;
                            Pen.color = Color.black; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(leftEarX + 6, leftEarY + 5), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rightEarX + 6, rightEarY + 5), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Do NOT move the description text
                            Pen.stringAtPoint("Headphone Listening using IRCAM HTRF Library", Point(centerX - 140, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        1, { // CIPIC Binaural
                            var earCupWidth = 20, earCupHeight = 27, earCupOffset = 55, arcCenterY = centerY - 25 + 25, arcRadius = 47, leftEarX, leftEarY, rightEarX, rightEarY;
                            leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                            leftEarY = centerY + 25 + 25;
                            rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                            rightEarY = centerY + 25 + 25;
                            Pen.color = Color.cyan; Pen.width = 2;
                            Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi); Pen.stroke;
                            Pen.moveTo(Point(centerX - arcRadius, centerY - 25 + 25)); Pen.lineTo(Point(centerX - arcRadius, leftEarY)); Pen.stroke;
                            Pen.moveTo(Point(centerX + arcRadius, centerY - 25 + 25)); Pen.lineTo(Point(centerX + arcRadius, rightEarY)); Pen.stroke;
                            Pen.color = Color.black; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(leftEarX + 6, leftEarY + 5), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rightEarX + 6, rightEarY + 5), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("Headphone Listening using CIPIC HTRF Library", Point(centerX - 138, 32), Font("Helvetica", 13), Color.cyan);
                        },
						2, { // Quad Square
    					var squareSize = 140, halfSquare = squareSize / 2;
    					Pen.color = Color.cyan;
    					Pen.addRect(Rect(centerX - halfSquare, centerY - halfSquare + 25, squareSize, squareSize));
    					Pen.stroke;

    					// Speaker 1: Front Left
    					Pen.color = Color.black;
    					Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + 25, 20, 20));
    					Pen.fill;
    					Pen.color = Color.cyan;
    					Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + 25, 20, 20));
    					Pen.stroke;
    					Pen.stringAtPoint("1", Point(centerX - halfSquare - 3, centerY - halfSquare - 9 + 25), Font("Helvetica", 13).boldVariant, Color.cyan);

    					// Speaker 2: Front Right
    					Pen.color = Color.black;
    					Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + 25, 20, 20));
    					Pen.fill;
    					Pen.color = Color.cyan;
    					Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + 25, 20, 20));
    					Pen.stroke;
    					Pen.stringAtPoint("2", Point(centerX - halfSquare - 3 + squareSize, centerY - halfSquare - 9 + 25), Font("Helvetica", 13).boldVariant, Color.cyan);

    					// Speaker 3: Rear Left
    					Pen.color = Color.black;
    					Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + squareSize + 25, 20, 20));
    					Pen.fill;
    					Pen.color = Color.cyan;
    					Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + squareSize + 25, 20, 20));
    					Pen.stroke;
    					Pen.stringAtPoint("3", Point(centerX - halfSquare - 3, centerY - halfSquare - 10 + squareSize + 1 + 25), Font("Helvetica", 13).boldVariant, Color.cyan);

    					// Speaker 4: Rear Right
    					Pen.color = Color.black;
    					Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + squareSize + 25, 20, 20));
    					Pen.fill;
    					Pen.color = Color.cyan;
    					Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + squareSize + 25, 20, 20));
    					Pen.stroke;
    					Pen.stringAtPoint("4", Point(centerX - halfSquare - 3 + squareSize, centerY - halfSquare - 10 + squareSize + 1 + 25), Font("Helvetica", 13).boldVariant, Color.cyan);

    					Pen.stringAtPoint("[1] FL, [2] FR, [3] RL, [4] RR", Point(centerX - 82, 32), Font("Helvetica", 13), Color.cyan);
						},
						3, { // Quad Narrow
    					var rectHeight = 140, rectWidth = (rectHeight * 0.75).asInteger, rectLeft = centerX - (rectWidth / 2), rectTop = centerY - (rectHeight / 2) + 25;
    					Pen.color = Color.cyan;
    					Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight));
   					 	Pen.stroke;

    					Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.fill;
    					Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.stroke;
    					Pen.stringAtPoint("1", Point(rectLeft - 3, rectTop - 9), Font("Helvetica", 13).boldVariant, Color.cyan);

    					Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.fill;
    					Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.stroke;
    					Pen.stringAtPoint("2", Point(rectLeft + rectWidth - 3, rectTop - 9), Font("Helvetica", 13).boldVariant, Color.cyan);

    					Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
    					Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
    					Pen.stringAtPoint("3", Point(rectLeft - 3, rectTop + rectHeight - 9), Font("Helvetica", 13).boldVariant, Color.cyan);

    					Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
    					Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
    					Pen.stringAtPoint("4", Point(rectLeft + rectWidth - 3, rectTop + rectHeight - 9), Font("Helvetica", 13).boldVariant, Color.cyan);

    					Pen.stringAtPoint("[1] FL, [2] FR, [3] RL, [4] RR", Point(centerX - 82, 32), Font("Helvetica", 13), Color.cyan);
						},
						4, { // Quad Wide
   						var rectWidth = 140, rectHeight = 105, rectLeft = centerX - (rectWidth / 2), 								totalHeight = rectHeight + 20, rectTop = centerY - (totalHeight / 2) + 10 + 25;
    					Pen.color = Color.cyan;
    					Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight));
    					Pen.stroke;

    					Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.fill;
    					Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.stroke;
    					Pen.stringAtPoint("1", Point(rectLeft - 3, rectTop - 9), Font("Helvetica", 13).boldVariant, Color.cyan);

    					Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.fill;
    					Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.stroke;
    					Pen.stringAtPoint("2", Point(rectLeft + rectWidth - 3, rectTop - 9), Font("Helvetica", 13).boldVariant, Color.cyan);

    					Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
    					Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
    					Pen.stringAtPoint("3", Point(rectLeft - 3, rectTop + rectHeight - 9), Font("Helvetica", 13).boldVariant, Color.cyan);

    					Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
    					Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
    					Pen.stringAtPoint("4", Point(rectLeft + rectWidth - 3, rectTop + rectHeight - 9), Font("Helvetica", 13).boldVariant, Color.cyan);

    					Pen.stringAtPoint("[1] FL, [2] FR, [3] RL, [4] RR", Point(centerX - 82, 32), Font("Helvetica", 13), Color.cyan);
},
                        5, { // Dolby 5.1
                            var layoutSize = 140, layoutLeft = centerX - (layoutSize / 2), layoutTop = centerY - (layoutSize / 2) + 25, speakerSize = 20, frontLeftX = layoutLeft - 10, frontLeftY = layoutTop - 10, frontRightX = layoutLeft + layoutSize - 10, frontRightY = layoutTop - 10, centerX_speaker = layoutLeft + (layoutSize / 2) - 10, centerY_speaker = layoutTop - 10, surroundLeftX = layoutLeft - 10, surroundLeftY = layoutTop + layoutSize - 10, surroundRightX = layoutLeft + layoutSize - 10, surroundRightY = layoutTop + layoutSize - 10, subwooferX = layoutLeft + (layoutSize / 2) - 10, subwooferY = layoutTop + (layoutSize / 2) - 10;
                            Pen.color = Color.cyan; Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize)); Pen.stroke;
                            // Speaker 1: Front Left (Left Front = 1)
                            Pen.color = Color.black; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 7, frontLeftY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 4: Front Right (Right Front = 4)
                            Pen.color = Color.black; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(frontRightX + 7, frontRightY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 5: Center (Center = 5)
                            Pen.color = Color.black; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("5", Point(centerX_speaker + 7, centerY_speaker + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 2: Surround Left (Left Rear = 2)
                            Pen.color = Color.black; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(surroundLeftX + 7, surroundLeftY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 3: Surround Right (Right Rear = 3)
                            Pen.color = Color.black; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(surroundRightX + 7, surroundRightY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Subwoofer (Sub = 6)
                            Pen.color = Color.cyan; Pen.addRect(Rect(subwooferX, subwooferY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("6", Point(subwooferX + 7, subwooferY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("SUB", Point(subwooferX + 25, subwooferY + 3), Font("Helvetica", 10).boldVariant, Color.cyan);
                            Pen.stringAtPoint("[1] FL, [2] RL, [3] RR, [4] FR, [5] C, [6] Sub", Point(centerX - 124, 32), Font("Helvetica", 13), Color.cyan); // description stays
                        },
6, {
    var radius = 80, angleStep = 2 * pi / 8, startAngle = -22.5 * pi / 180;

    Pen.color = Color.cyan;
    Pen.addOval(Rect(centerX - radius, centerY - radius + 25, radius * 2, radius * 2));
    Pen.stroke;

    8.do({ |i|
        var angle = startAngle - (i * angleStep);
        var x = centerX + (radius * cos(angle)) - 10;
        var y = centerY - (radius * sin(angle)) - 10 + 25;
        var speakerNum = ((i + 3) % 8) + 1; // Shift so speaker 1 is at front-left position

        Pen.push;
        Pen.translate(x + 10, y + 10);
        // Pen.rotate(pi / 4); // Rotate speaker boxes 45 degrees
        Pen.translate(-10, -10);
        Pen.color = Color.black;
        Pen.addRect(Rect(0, 0, 20, 20));
        Pen.fill;
        Pen.color = Color.cyan;
        Pen.addRect(Rect(0, 0, 20, 20));
        Pen.stroke;
        Pen.stringAtPoint(speakerNum.asString, Point(7, 1), Font("Helvetica", 13).boldVariant, Color.cyan);
        Pen.pop;
    });

    Pen.stringAtPoint("[1] FL (-22.5°), Clockwise @ 45°", Point(centerX - 84, 32), Font("Helvetica", 13), Color.cyan);
}
                    );
                });
            ~layoutOverlay.front;
        } {
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; };
        }
    });

// --- MAPLIN SM-333 OVERLAY BUTTON ---
~maplinBtn = Button(mainView, Rect(290, 410, 100, 35))
    .states_([["SM-333", Color.cyan, Color.black], ["SM-333", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
	.focusColor_(Color.clear)
    .action_({ |btn|
        if(btn.value == 1) {
            // --- RADIO BUTTON BEHAVIOR: Only one overlay/button active at a time ---
            if(~eqOverlay.notNil) {
                ~saveEqState.value(); // Save state before removing EQ overlay
                ~eqOverlay.remove; ~eqOverlay = nil; ~eqBtn.value_(0);
            };
            if(~ambienceOverlay.notNil) {
                ~saveAmbienceState.value(); // Save state before removing ambience overlay
                ~ambienceOverlay.remove; ~ambienceOverlay = nil; ~ambienceBtn.value_(0);
            };
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; ~layoutBtn.value_(0); };
            // Set other buttons to 0 (radio group)
            ~eqBtn.value_(0);
            ~ambienceBtn.value_(0);
            ~layoutBtn.value_(0);
            // --- Remove any previous Maplin overlay and controls to prevent duplicates ---
            if(~maplinOverlay.notNil) { ~maplinOverlay.remove; ~maplinOverlay = nil; };
            // Create Maplin overlay directly in main window
            ~maplinOverlay = View(mainView, Rect(180, 107, 320, 275)).background_(Color.black);
            UserView(~maplinOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });
            StaticText(~maplinOverlay, Rect(10, 5, 120, 20))
                .string_("MAPLIN SM-333")
                .align_(\left)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);
            // Create knobs and controls
            ~maplinSurroundKnob = Knob(~maplinOverlay, Rect(50, 50, 60, 60))
                .value_(~maplinState[\surround] ? 0.8)
                .action_({ |knob|
                    var level = knob.value;
                    ~setMaplinSurround.(level);
                    ~maplinSurroundValue.string_((level * 100).round(1).asString ++ "%");
                });
            ~maplinSurroundValue = StaticText(~maplinOverlay, Rect(50, 120, 60, 20))
                .string_((~maplinState[\surround] ? 0.8 * 100).round(1).asString ++ "%")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            StaticText(~maplinOverlay, Rect(50, 140, 60, 20))
                .string_("SURROUND")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 10))
                .background_(Color.clear);
            ~maplinEffectKnob = Knob(~maplinOverlay, Rect(130, 50, 60, 60))
                .value_(~maplinState[\effect] ? 0.8)
                .action_({ |knob|
                    var level = knob.value;
                    ~setMaplinEffect.(level);
                    ~maplinEffectValue.string_((level * 100).round(1).asString ++ "%");
                });
            ~maplinEffectValue = StaticText(~maplinOverlay, Rect(130, 120, 60, 20))
                .string_((~maplinState[\effect] ? 0.8 * 100).round(1).asString ++ "%")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            StaticText(~maplinOverlay, Rect(130, 140, 60, 20))
                .string_("EFFECT")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 10))
                .background_(Color.clear);
            ~maplinDelayKnob = Knob(~maplinOverlay, Rect(210, 50, 60, 60))
                .value_(~maplinState[\delay] ? 0.4)
                .action_({ |knob|
                    var time = knob.value;
                    ~setMaplinDelay.(time);
                    ~maplinDelayValue.string_((time.linlin(0, 1, 5, 50).round(1).asString ++ " ms"));
                });
            ~maplinDelayValue = StaticText(~maplinOverlay, Rect(210, 120, 60, 20))
                .string_((~maplinState[\delay] ? 0.4).linlin(0, 1, 5, 50).round(1).asString ++ " ms")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            StaticText(~maplinOverlay, Rect(210, 140, 60, 20))
                .string_("DELAY")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 10))
                .background_(Color.clear);
            // Active/Bypass button
            ~maplinActiveBtn = Button(~maplinOverlay, Rect(100, 200, 120, 30))
                .states_([["BYPASSED", Color.cyan, Color.black], ["ACTIVE", Color.black, Color.cyan]])
                .font_(Font("Helvetica", 12))
                .value_(~maplinState[\active] ? 0)
                .action_({ |btn|
                    var active = btn.value == 1;
                    ~setMaplinActive.(active);
                });
            // Preset buttons
            Button(~maplinOverlay, Rect(50, 250, 80, 25))
                .states_([["BALANCED", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 10))
                .action_({
                    ~maplinPresetBalanced.value();
                    // Update GUI
                    ~maplinSurroundKnob.value_(0.8);
                    ~maplinEffectKnob.value_(0.8);
                    ~maplinDelayKnob.value_(0.4);
                    ~maplinSurroundValue.string_("80.0%");
                    ~maplinEffectValue.string_("80.0%");
                    ~maplinDelayValue.string_("25.0 ms");
                });
            Button(~maplinOverlay, Rect(190, 250, 80, 25))
                .states_([["MAXIMUM", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 10))
                .action_({
                    ~maplinPresetMax.value();
                    // Update GUI
                    ~maplinSurroundKnob.value_(1.0);
                    ~maplinEffectKnob.value_(1.0);
                    ~maplinDelayKnob.value_(1.0);
                    ~maplinSurroundValue.string_("100.0%");
                    ~maplinEffectValue.string_("100.0%");
                    ~maplinDelayValue.string_("50.0 ms");
                });
            // Close button
            Button(~maplinOverlay, Rect(222, 230, 80, 28))
                .states_([["CLOSE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~saveMaplinState.value(); // Save state before closing
                    ~maplinOverlay.remove;
                    ~maplinOverlay = nil;
                    ~maplinBtn.value_(0);
                });
            ~maplinOverlay.front;
            // Restore saved state
            ~restoreMaplinState.value();
        } {
            if(~maplinOverlay.notNil) { ~maplinOverlay.remove; ~maplinOverlay = nil; };
        }
    });

// Detect Behringer devices and initialize
~detectBehringerDevices.value();

// Set up JACK connections for Behringer devices (after SuperCollider boots)
~setupBehringerJACK = {
    // Wait for SuperCollider to boot and create jack_quad ports
    AppClock.sched(2.0, {
        // Clear any existing connections first
        "jack_disconnect system:capture_1 jack_quad:in_1 2>/dev/null".unixCmd;
        "jack_disconnect system:capture_2 jack_quad:in_2 2>/dev/null".unixCmd;
        "jack_disconnect ufo_phono:capture_1 jack_quad:in_3 2>/dev/null".unixCmd;
        "jack_disconnect ufo_phono:capture_2 jack_quad:in_4 2>/dev/null".unixCmd;
        
        // Connect UCA202 line inputs to channels 1 & 2 (SuperCollider 0 & 1) - JACK master
        "jack_connect system:capture_1 jack_quad:in_1".unixCmd;
        "jack_connect system:capture_2 jack_quad:in_2".unixCmd;
        
        // Connect UFO202 phono inputs to channels 3 & 4 (SuperCollider 2 & 3) - zita bridge
        "jack_connect ufo_phono:capture_1 jack_quad:in_3".unixCmd;
        "jack_connect ufo_phono:capture_2 jack_quad:in_4".unixCmd;
        
        // Connect outputs
        "jack_connect jack_quad:out_1 system:playback_1".unixCmd;
        "jack_connect jack_quad:out_2 system:playback_2".unixCmd;
        if(outputs >= 4, {
            "jack_connect jack_quad:out_3 ufo_out:playback_1".unixCmd;
            "jack_connect jack_quad:out_4 ufo_out:playback_2".unixCmd;
        });
        
        ("JACK connections established for Behringer devices").postln;
    });
};

// Set up JACK connections once at startup
~setupBehringerJACK.value();

// Set default input mode
~setInputMode.(\line);

// Initialize audio engine with delay
{
    ~initAudioEngine.value();
}.defer(0.5);

win.front;

// --- Headtracker HID Integration (added as per MainApp2 model, always active) ---
(
Tdef( 'tryOpenHID' , {
   var keepLooking = true;
   while ( { keepLooking } ){
      if ( ~myhid.notNil ){
         if ( ~myhid.isOpen ){
            keepLooking = false;
         }
      };
      if ( keepLooking ){
         HID.findAvailable;
         if ( HID.findBy(0,0).size > 0 ){
            ~myhid = HID.open(0,0);
            if ( ~myhid.notNil ){
               ~myhid.closeAction = {
                    "device closed".postln;
                    Tdef( \tryOpenHID ).reset.play;
               };
               keepLooking = false;
            }{
               3.0.wait;
            };
         }{
            3.0.wait;
         }
      }
   }
} );
);
Tdef( 'tryOpenHID' ).play;

// HID.debug = true;

// Map HID usages to GUI knobs (always active, no gating)
HIDdef.usage( \hidRotation, { |val|
    {
        //("Headtracker raw rotation: " ++ val).postln;  // <-- Add this line
        if(~rotateKnob.notNil and: { ~rotateKnob.enabled }) {
            ~rotateKnob.valueAction_(
                1 - val.linlin(0.060606062412262, 0.94037145376205, 0, 1)
            );
        };
    }.defer;
}, \Z );

HIDdef.usage( \hidTilt, { |val|
    {
        if(~tiltKnob.notNil and: { ~tiltKnob.enabled }) {
            ~tiltKnob.valueAction_(
                1 - val.linlin(0.060606062412262, 0.94037145376205, 0, 1)
            );
        };
    }.defer;
}, \Y );

HIDdef.usage( \hidTumble, { |val|
    {
        if(~tumbleKnob.notNil and: { ~tumbleKnob.enabled }) {
            ~tumbleKnob.valueAction_(
                1 - val.linlin(0.060606062412262, 0.94037145376205, 0, 1)
            );
        };
    }.defer;
}, \X );