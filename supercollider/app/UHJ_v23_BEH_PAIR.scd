// ============================================================================
// UHJ v23 - AMBISONIC UHJ ENCODER/DECODER - BEHRINGER EDITION
// ============================================================================

// Using standard Knob class with custom 360-degree action handling
// Features automatic mouse/headtracker detection for intuitive control
// Added input switching: LINE (UCA202) / PHONO (UFO202)

var win, mainView,
    decoderChanged,
    isUpdating, lastInputCmd, linkFaders, lastInL, lastInR, minIn, maxIn, lastFaderGroup,
    voltmp, cond, sndbuf, synth, inputs, outputs, configKeyD, configKeyE,
    dbValue, cliToDb, cliToDbMaster, formatDbValue, gainToDb;
// --- Overlay GUI variables (must be declared at the top, per GUIPrototype) ---
~eqOverlay = nil; ~ambienceOverlay = nil; ~layoutOverlay = nil; ~maplinOverlay = nil;

~eqBtn = nil; ~ambienceBtn = nil; ~layoutBtn = nil; ~maplinBtn = nil;
// --- EQ overlay variables (from GUIPrototype) ---
~eqPresetMenu = nil; ~eqPresetNames = nil; ~eqPresetDict = nil; ~eqSliders = nil; ~eqValues = nil;
// --- Maplin overlay variables ---
~maplinSurroundKnob = nil; ~maplinEffectKnob = nil; ~maplinDelayKnob = nil; ~maplinActiveBtn = nil;
~maplinSurroundValue = nil; ~maplinEffectValue = nil; ~maplinDelayValue = nil;
// --- Headtracker overlays ---
~knobOverlay = nil; ~htBtnOverlay = nil; ~htResetOverlay = nil; ~htPairOverlay = nil;
// --- Headtracker pairing button reference ---
~headtrackPairBtn = nil;
// --- Maplin button overlay ---up 
~maplinBtnOverlay = nil;
// --- Power button state ---
~powerBtnPressed = false;
// --- AmbiVerbSC preset system variables ---
~ambiencePresetNames = nil; ~ambiencePresetDict = nil; ~ambiencePresetMenu = nil;

// --- Ambience state preservation variables ---
~ambienceState = Dictionary.newFrom([
    \sliderValues, [0.0, 0.2, 0.2, 0.2, 0.0, 0.0, 0.0],  // Default values
    \presetIndex, 0,  // Default preset index
    \lastMix, 0.5     // Remember last nonzero mix value
]);

// --- EQ state preservation variables ---
~eqState = Dictionary.newFrom([
    \sliderValues, [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],  // Default values (0dB = 0.5)
    \presetIndex, 0   // Default preset index
]);

// --- Maplin state preservation variables ---
~maplinState = Dictionary.newFrom([
    \surround, 0.8,   // Surround level
    \effect, 0.8,     // Effect level
    \delay, 0.4,      // Delay amount
    \active, 0        // Active/bypass (default OFF)
]);

// --- Behringer audio device variables ---
~currentInputMode = \line; // \line or \phono
~behringerUFOCard = nil;   // Will store UFO202 card number
~behringerUCACard = nil;   // Will store UCA202 card number
~visualMuteActive = false; // Track visual mute state for input meters

// --- Initial values for input section ---
isUpdating = false;
linkFaders = true;
lastInL = 106; // 0dB (unity gain) with full range
lastInR = 106; // 0dB (unity gain) with full range
minIn = 0;
maxIn = 127;
lastFaderGroup = \none;

// Audio engine initial values
voltmp = 1.0; // 0dB = 1.0 amplitude

// Encoder/Decoder configuration defaults
configKeyE = \uhj;      // Default encoder: UHJ
configKeyD = \stereo;   // Default decoder: Stereo
inputs = 4;             // 4 inputs total (2 phono + 2 line)
outputs = 2;            // Default output channels

// Full range dB conversion with improved resolution
cliToDb = { |cliValue|
    var dbValue;
    // Full range linear mapping: 0->-60dB, 127->+12dB, 0dB at ~106
    dbValue = cliValue.linlin(0, 127, -60, 12);
    // Round to 1dB resolution
    dbValue.round(1);
};

// Master dB conversion function - just use the simple one
cliToDbMaster = { |cliValue|
    cliToDb.value(cliValue);
};

// New dB conversion for Behringer input gain control
gainToDb = { |gainValue|
    var dbValue;
    // Convert gain to dB: 20 * log10(gain)
    dbValue = 20 * log10(gainValue);
    dbValue.round(1);
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
    };
    
    ~behringerUFOCard = ufoCard;
    ~behringerUCACard = ucaCard;
    
    ("Behringer device detection complete - UFO: " ++ ufoCard ++ ", UCA: " ++ ucaCard).postln;
};

// --- Behringer input mode switching ---
~setInputMode = { |mode|
    ~currentInputMode = mode;
    if(~synth.notNil) {
        if(mode == \phono) {
            ~synth.set(\inputMode, 1); // Use phono inputs (UFO202) - channels 2,3
            ("Input switched to PHONO (UFO202 - channels 2,3)").postln;
        } {
            ~synth.set(\inputMode, 0); // Use line inputs (UCA202) - channels 0,1
            ("Input switched to LINE (UCA202 - channels 0,1)").postln;
        };
        // Update visual mute if active
        ~updateVisualMute.value();
    };

    ("Current input mode: " ++ mode ++ ", UFO card: " ++ ~behringerUFOCard ++ ", UCA card: " ++ ~behringerUCACard).postln;
};

// --- Visual mute function for input meters ---
~updateVisualMute = {
    if(~meter.notNil && ~meter.view.notNil) {
        var meterViews = ~meter.view.children[0].children; // Access the inner view's children
        
        if(~visualMuteActive) {
            // Set input meters to black based on current input mode
            if(~currentInputMode == \line) {
                // Mute UCA input meters (channels 0,1) - skip first child (dB scale)
                if(meterViews.size >= 3) {
                    // Channel 0 - set all colors to black
                    meterViews[1].children[0].meterColor_(Color.black)
                        .warningColor_(Color.black).criticalColor_(Color.black);
                    // Channel 1 - set all colors to black
                    meterViews[2].children[0].meterColor_(Color.black)
                        .warningColor_(Color.black).criticalColor_(Color.black);
                };
                // Keep UFO meters visible (channels 2,3)
                if(meterViews.size >= 5) {
                    // Channel 2 - restore normal colors
                    meterViews[3].children[0].meterColor_(Color.cyan)
                        .warningColor_(Color.new(0.86,0.54,0.04,1)).criticalColor_(Color.red);
                    // Channel 3 - restore normal colors
                    meterViews[4].children[0].meterColor_(Color.cyan)
                        .warningColor_(Color.new(0.86,0.54,0.04,1)).criticalColor_(Color.red);
                };
            } {
                // Mute UFO input meters (channels 2,3)
                if(meterViews.size >= 5) {
                    // Channel 2 - set all colors to black
                    meterViews[3].children[0].meterColor_(Color.black)
                        .warningColor_(Color.black).criticalColor_(Color.black);
                    // Channel 3 - set all colors to black
                    meterViews[4].children[0].meterColor_(Color.black)
                        .warningColor_(Color.black).criticalColor_(Color.black);
                };
                // Keep UCA meters visible (channels 0,1)
                if(meterViews.size >= 3) {
                    // Channel 0 - restore normal colors
                    meterViews[1].children[0].meterColor_(Color.cyan)
                        .warningColor_(Color.new(0.86,0.54,0.04,1)).criticalColor_(Color.red);
                    // Channel 1 - restore normal colors
                    meterViews[2].children[0].meterColor_(Color.cyan)
                        .warningColor_(Color.new(0.86,0.54,0.04,1)).criticalColor_(Color.red);
                };
            };
        } {
            // Visual mute off - restore all input meters to normal colors
            if(meterViews.size >= 5) {
                // Restore all channels
                meterViews[1].children[0].meterColor_(Color.cyan)
                    .warningColor_(Color.new(0.86,0.54,0.04,1)).criticalColor_(Color.red);
                meterViews[2].children[0].meterColor_(Color.cyan)
                    .warningColor_(Color.new(0.86,0.54,0.04,1)).criticalColor_(Color.red);
                meterViews[3].children[0].meterColor_(Color.cyan)
                    .warningColor_(Color.new(0.86,0.54,0.04,1)).criticalColor_(Color.red);
                meterViews[4].children[0].meterColor_(Color.cyan)
                    .warningColor_(Color.new(0.86,0.54,0.04,1)).criticalColor_(Color.red);
            };
        };
    };
};

// --- Window setup with platform-specific positioning ---
win = Window("UHJ Ambisonic System", Rect(0, 0, 800, 480), border: false).background_(Color.black);
// Ensure server and interpreter quit when window is closed
win.onClose_({
    // Stop connection monitor
    if(~connectionMonitor.notNil) { ~connectionMonitor.stop; };
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
        win.bounds_(Rect(
            (Window.screenBounds.width - 800) / 2,
            (Window.screenBounds.height - 480) / 2,
            800, 480
        ));
    });
});
"UHJ-Pi: Centered on %x% screen".format(Window.screenBounds.width, Window.screenBounds.height).postln;

mainView = CompositeView(win, Rect(0, 0, 800, 480)).background_(Color.black);

// --- INPUT FADERS SECTION (MainApp2 functionality with GUI prototype styling) ---
StaticText(mainView, Rect(48, 10, 120, 28))
    .string_("INPUT")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

StaticText(mainView, Rect(70, 40, 24, 24)).string_("L").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 13));
StaticText(mainView, Rect(120, 40, 24, 24)).string_("R").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 13));

// Input faders with MainApp2's smart linking logic
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
            // Display in dB using logarithmic scaling
            dbValue = cliToDbMaster.(lastInL);
            ~leftValue.string = formatDbValue.(dbValue);
            // Convert dB to gain and update synth
            if(~synth.notNil) {
                var gainL = 10.pow(dbValue / 20);
                ~synth.set(\inputGainL, gainL);
            };
            if(linkFaders) {
                ~rightSlider.value = sl.value;
                lastInR = lastInL;
                ~rightValue.string = formatDbValue.(dbValue);
                if(~synth.notNil) {
                    var gainR = 10.pow(dbValue / 20);
                    ~synth.set(\inputGainR, gainR);
                };
            };
            isUpdating = false;
        } {
            lastInL = (sl.value.linlin(0,1,minIn,maxIn).round.asInteger);
            dbValue = cliToDbMaster.(lastInL);
            ~leftValue.string = formatDbValue.(dbValue);
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
            // Display in dB using logarithmic scaling
            dbValue = cliToDbMaster.(lastInR);
            ~rightValue.string = formatDbValue.(dbValue);
            // Convert dB to gain and update synth
            if(~synth.notNil) {
                var gainR = 10.pow(dbValue / 20);
                ~synth.set(\inputGainR, gainR);
            };
            if(linkFaders) {
                ~leftSlider.value = sl.value;
                lastInL = lastInR;
                ~leftValue.string = formatDbValue.(dbValue);
                if(~synth.notNil) {
                    var gainL = 10.pow(dbValue / 20);
                    ~synth.set(\inputGainL, gainL);
                };
            };
            isUpdating = false;
        } {
            lastInR = (sl.value.linlin(0,1,minIn,maxIn).round.asInteger);
            dbValue = cliToDbMaster.(lastInR);
            ~rightValue.string = formatDbValue.(dbValue);
        }
    });

~leftValue = StaticText(mainView, Rect(65, 380, 34, 24)).string_("-19").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 13));
~rightValue = StaticText(mainView, Rect(115, 380, 34, 24)).string_("-19").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 13));

// Add "dB" label between the faders, vertically aligned with the values
StaticText(mainView, Rect(95, 380, 24, 24)).string_("dB").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 13));

// Visual tick marks between faders using proper drawn lines
UserView(mainView, Rect(98, 70, 18, 300))
    .background_(Color.clear)
    .drawFunc_({ |view|
        Pen.color = Color.cyan;
        Pen.width = 1;

        // Major tick marks every 50 pixels (evenly spaced)
        [0, 50, 100, 150, 200, 250, 300].do({ |y|
            Pen.line(Point(6, y), Point(12, y));
            Pen.stroke;
        });

        // Minor tick marks every 25 pixels (between majors)
        [25, 75, 125, 175, 225, 275].do({ |y|
            Pen.line(Point(7, y), Point(11, y));
            Pen.stroke;
        });
    });

// Mouse up action (no CLI commands needed for Behringer)
mainView.mouseUpAction_({
    AppClock.sched(0.05, {
        lastFaderGroup = \none;
    });
});

// --- SIMPLIFIED SOURCE SELECTOR (LINE/PHONO only) ---
~lineBtn = Button(mainView, Rect(18, 70, 40, 20))
    .states_([["LINE", Color.cyan, Color.black], ["LINE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({ |btn|
        if(btn.value == 0) {
            // Prevent turning off - force it back to on
            btn.value_(1);
        } {
            // Turn off the other button and set input mode
            ~phonoBtn.value_(0);
            ~setInputMode.(\line);
        }
    });

~phonoBtn = Button(mainView, Rect(18, 110, 40, 20))
    .states_([["PHONO", Color.cyan, Color.black], ["PHONO", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({ |btn|
        if(btn.value == 0) {
            // Prevent turning off - force it back to on
            btn.value_(1);
        } {
            // Turn off the other button and set input mode
            ~lineBtn.value_(0);
            ~setInputMode.(\phono);
        }
    });

// RESET, MON, MUTE, LINK buttons with MainApp2 functionality
~resetBtn = Button(mainView, Rect(18, 310, 40, 20))
    .states_([["RESET", Color.cyan, Color.black]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({ |btn|
        // Reset GUI to match defaults
        AppClock.sched(0.1, {
            // Reset fader values to 0dB
            lastInL = 106; // 0dB with full range
            lastInR = 106; // 0dB with full range
            ~leftSlider.value = (lastInL - minIn) / (maxIn - minIn);
            ~rightSlider.value = (lastInR - minIn) / (maxIn - minIn);
            // Display in dB using logarithmic scaling
            dbValue = cliToDbMaster.(lastInL);
            ~leftValue.string = formatDbValue.(dbValue);
            ~rightValue.string = formatDbValue.(dbValue);

            // Reset synth parameters
            if(~synth.notNil) {
                // 0dB = gain of 1.0
                ~synth.set(\inputGainL, 1.0);
                ~synth.set(\inputGainR, 1.0);
                ~synth.set(\mute, 0);
            };

            // Reset button states to defaults
            ~lineBtn.value_(1);  // LINE selected by default
            ~phonoBtn.value_(0);
            ~muteBtn.value_(0);  // MUTE off by default
            // Note: LINK button retains its current state
        });
    });



~muteBtn = Button(mainView, Rect(76, 410, 60, 35))
    .states_([["MUTE", Color.cyan, Color.black], ["MUTE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
	.focusColor_(Color.clear)
    .action_({ |btn|
        if(~synth.notNil) {
            if(btn.value == 1) {
                // Muting: set synth mute parameter and activate visual mute
                ~synth.set(\mute, 1);
                ~visualMuteActive = true;
            } {
                // Unmuting: clear synth mute parameter and deactivate visual mute
                ~synth.set(\mute, 0);
                ~visualMuteActive = false;
            };
            // Update visual mute state
            ~updateVisualMute.value();
        };
        
    });

~linkBtn = Button(mainView, Rect(18, 350, 40, 20))
    .states_([["LINK", Color.cyan, Color.black], ["LINK", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .value_(linkFaders.asInteger)
    .action_({ |btn| linkFaders = btn.value == 1; });

// --- ENCODER/DECODER MENUS ---
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

// Encoder menu (Input format selection)
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
            ("Updated maplinMode to: " ++ if(configKeyE == \maplin, 1, 0)).postln;
        };

        // Show/hide SM-333 button overlay based on encoder selection
        if(~maplinBtn.notNil) {
            if(configKeyE == \maplin) {
                // Remove overlay to enable button
                ("Enabling SM-333 button for MAPLIN mode").postln;
                if(~maplinBtnOverlay.notNil) {
                    ~maplinBtnOverlay.remove;
                    ~maplinBtnOverlay = nil;
                    ("SM-333 button overlay removed").postln;
                };
            } {
                // Close maplin overlay if it's open when switching away from maplin encoder
                ("Disabling SM-333 button for non-MAPLIN mode").postln;
                if(~maplinOverlay.notNil) {
                    ~saveMaplinState.value();
                    ~maplinOverlay.remove; ~maplinOverlay = nil; ~maplinBtn.value_(0);
                };
                // Add overlay to dim button (only if not already present)
                if(~maplinBtnOverlay.isNil) {
                    ~maplinBtnOverlay = View(mainView, Rect(290, 410, 100, 35))
                        .background_(Color.black.alpha_(0.7))
                        .alpha_(1.0)
                        .front;
                    ("SM-333 button overlay added").postln;
                };
            };
        };
        ("Selected encoder: " ++ menu.item).postln;
        // Save current synth parameters before reinitializing
        ~saveSynthParams.value();
        // Always call audio engine init; it will reload only if needed
        ~initAudioEngine.value();
    },
    initVal: 0,
    initAction: false,
    labelWidth: 0,
    labelHeight: 0,
    layout: \horz,
    gap: 0@0
);

// Decoder menu (Output format selection)
~dmenu = EZPopUpMenu.new(
    mainView,
    Rect(360, 45, 140, 35),
    "",
    [
        \STEREO -> { |a| outputs = 2; configKeyD = \stereo; },
        \BINAURAL ++ " IRCAM" -> { |a| outputs = 2; configKeyD = \binaural; },
        \BINAURAL ++ " CIPIC" -> { |a| outputs = 2; configKeyD = \binaurac; },
        \QUAD ++ " SQUARE" -> { |a| outputs = 4; configKeyD = \quadsquare; },
        \QUAD ++ " NARROW" -> { |a| outputs = 4; configKeyD = \quadnarrow; },
        \QUAD ++" WIDE" -> { |a| outputs = 4; configKeyD = \quadwide; }
    ],
    globalAction: { |menu|
        var idx, decoderNames, decoderName, htIsOff, isBinaural, shouldDim;
        // --- Reset headtracking and quad panner settings on decoder change ---
        if(~headtrackBtn.notNil) { ~headtrackBtn.value_(0); };
        if(~rotateKnob.notNil) { ~rotateKnob.valueAction_(0.5); };
        if(~tiltKnob.notNil) { ~tiltKnob.valueAction_(0.5); };
        if(~tumbleKnob.notNil) { ~tumbleKnob.valueAction_(0.5); };
        if(~xyPanner.notNil) {
            ~xyPanner.x_(0.5); ~xyPanner.y_(0.5);
            ~xyPannerPos = Point(0.5, 0.5);
        };
        idx = menu.value;
        decoderNames = ["STEREO", "BINAURAL IRCAM", "BINAURAL CIPIC", "QUAD SQUARE", "QUAD NARROW", "QUAD WIDE"];
        decoderName = decoderNames[idx];
        htIsOff = (~headtrackBtn.notNil and: { ~headtrackBtn.value == 0 });
        isBinaural = (idx == 1) or: { idx == 2 };
        shouldDim = (idx == 3 or: { idx == 4 } or: { idx == 5 });

        // --- Overlay/enable logic for headtracker controls ---
        if(~knobOverlay.notNil) { ~knobOverlay.remove; ~knobOverlay = nil; };
        if(~htBtnOverlay.notNil) { ~htBtnOverlay.remove; ~htBtnOverlay = nil; };
        if(~htResetOverlay.notNil) { ~htResetOverlay.remove; ~htResetOverlay = nil; };
        if(~xyPannerOverlay.notNil) { ~xyPannerOverlay.remove; ~xyPannerOverlay = nil; };

        if(isBinaural) {
            ~headtrackBtn.enabled_(true);
            if(htIsOff) {
                // Headtracking OFF: disable controls and hide reset button
                ~headtrackResetBtn.enabled_(false);
                ~rotateKnob.enabled_(false);
                ~tiltKnob.enabled_(false);
                ~tumbleKnob.enabled_(false);
                ~knobOverlay = View(mainView, Rect(594, 60, 147, 224)) // width was 145, now 147
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
                ~htResetOverlay = View(mainView, Rect(734, 102, 48, 20)) // Cover RESET button
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
            } {
                // Headtracking ON: enable controls and show reset button
                ~headtrackResetBtn.enabled_(true);
                ~rotateKnob.enabled_(true);
                ~tiltKnob.enabled_(true);
                ~tumbleKnob.enabled_(true);
            };
        } {
            // Non-binaural mode (quad, 5.1, octagon)
            ~headtrackBtn.enabled_(false);
            ~rotateKnob.enabled_(false);
            ~tiltKnob.enabled_(false);
            ~tumbleKnob.enabled_(false);
            
            // Always hide knobs and ON/OFF button in non-binaural modes
            ~knobOverlay = View(mainView, Rect(594, 60, 147, 224)) // width was 145, now 147
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
            ~htBtnOverlay = View(mainView, Rect(734, 60, 48, 42)) // Cover only ON/OFF button (y=60-102)
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
                
            // Reset button always visible and enabled in non-binaural modes
            // (since all remaining modes are quad, which use the panner)
            ~headtrackResetBtn.enabled_(true);
        };
        // ... existing code ...
        // --- Quad panner logic ---
        if((idx == 3) or: { idx == 4 } or: { idx == 5 }) {
            ~xyPanner.enabled_(true);
            if(~xyPannerOverlay.notNil) { ~xyPannerOverlay.remove; ~xyPannerOverlay = nil; };
        } {
            ~xyPanner.enabled_(false);
            if(~xyPannerOverlay.notNil) { ~xyPannerOverlay.remove; ~xyPannerOverlay = nil; };
            ~xyPannerOverlay = View(mainView, Rect(629, 299, 110, 145))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
        };

        // --- Refresh layout overlay title and graphics if open ---
        if(~layoutOverlay.notNil) {
            ~layoutOverlay.children.do({ |child|
                if(child.class == StaticText and: { child.string.beginsWith("LAYOUT -") }) {
                    child.string_("LAYOUT - " ++ decoderName);
                };
            });
            ~layoutOverlay.children.do({ |child|
                if(child.class == UserView) { child.refresh; };
            });
        };
        // --- Audio engine reinitialization logic (must be last) ---
        if((configKeyD != (~prevConfigKeyD ? configKeyD)) or: ((inputs != (~prevInputs ? inputs)) or: (outputs != (~prevOutputs ? outputs)))) {
            // Save current synth parameters before reinitializing
            ~saveSynthParams.value();
            ~initAudioEngine.value();
            ~prevConfigKeyD = configKeyD;
        };
    },
    initVal: 0,
    initAction: false,
    labelWidth: 0,
    labelHeight: 0,
    layout: \horz,
    gap: 0@0
);

// Style the menus to match the GUI prototype
~emenu.font = Font("LCD 5x7 Segment Monospace", 11);
~emenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);

~dmenu.font = Font("LCD 5x7 Segment Monospace", 11);
~dmenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);

// --- Track previous channel counts for safe decoder switching ---
~prevInputs = inputs;
~prevOutputs = outputs;
// --- Track previous decoder and encoder key for always-reload logic ---
~prevConfigKeyD = configKeyD;
~prevConfigKeyE = configKeyE;

// --- Input Source Detection for Mouse vs Headtracker ---
// Track whether the last input was from mouse or headtracker
// This allows automatic behavior adjustment for intuitive mouse control
~lastInputSource = \headtracker;  // Default to headtracker
~mouseActive = false;  // Track if mouse is currently being used

// --- Pseudo-Surround Encoder ---
// Use ATK's built-in stereo encoder if available, otherwise create custom one
// This provides a clean foundation for convolution-based spatialization

// Audio engine initialization function (from MainApp2)
~initAudioEngine = {
    var encoder, decoder, trans, ambient, roton;
    var decoderDict, encoderDict;
    var tryBoot;
    var needReboot;
    // Always reload kernels and restart synth on decoder or encoder change
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
                    // Use default JACK device (SuperCollider will create its own ports)
                s.options.device = "jack_quad";
                ("Using default JACK device - SuperCollider will create SuperCollider:in_X/out_X ports").postln;
                s.boot;
                cond = Condition.new;
                s.waitForBoot({
                    // Set audio card volume after server boot
                    // ("amixer -c HD set PCM 80%").unixCmd;

                    // Define encoder kernels
                    encoderDict = Dictionary.newFrom([
                        \uhj, FoaEncoderKernel.newUHJ,
                        \superstereo, FoaEncoderKernel.newSuper,
                        \maplin, FoaEncoderMatrix.newDirections([-45, 45, -135, 135].degrad),  // MaplinMatrix quad encoder
                    ]);

                    // Define decoder kernels (matching MainApp2 exactly, excluding unused \none)
                    decoderDict = Dictionary.newFrom([
                        \stereo, FoaDecoderMatrix.newStereo,
                        \binaural, FoaDecoderKernel.newListen(1053),
                        \binaurac, FoaDecoderKernel.newCIPIC(12),
                        \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                        \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                        \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual')
                    ]);

                    // Get selected encoder and decoder
                    encoder = encoderDict.at(configKeyE ? \uhj);
                    decoder = decoderDict.at(configKeyD ? \stereo);

                    ("Audio engine initialized with encoder: " ++ configKeyE ++ " and decoder: " ++ configKeyD).postln;
                    
                    // Set up JACK connections after server boot
                    ~setupBehringerJACK.value();

                    // Load test audio file (same as MainApp2)
                    sndbuf = Buffer.read(s, Atk.userSoundsDir ++ "/uhj/01 Sodium Sunrise UHJ Render.wav");

                    // Load spatial impulse responses for pseudo-surround convolution
                    // These would be B-format impulse responses for realistic spatialization
                    ~spatialIRs = Array.fill(4, { |i|
                        // Placeholder for spatial IR loading
                        // In a full implementation, these would be loaded from files
                        Buffer.alloc(s, 2048, 1); // Temporary buffer
                    });

                    s.sync(cond);

                    // Define the main audio processing SynthDef (adapted from MainApp2)
                    SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, quadLR = 0, quadFR = 0, ambience = 0, preDelay = 0, lowRT = 0.2, highRT = 2, dispersion = 1, modWidth = 0.2, modRate = 0.3, eq1 = 0, eq2 = 0, eq3 = 0, eq4 = 0, eq5 = 0, eq6 = 0, eq7 = 0, maplinSurround = 0.8, maplinEffect = 0.8, maplinDelay = 0.4, maplinActive = 1, maplinMode = 0, inputMode = 0, inputGainL = 1.0, inputGainR = 1.0, mute = 0|
                        var out, src, trans, encode, ambient, eqed, frontStereo, rearStereo, quadOutFront, quadOutRear, maplinQuad, encodeInput;
                        
                        // Behringer input selection (LINE/PHONO mode)
                        // inputMode: 0 = line (UCA202), 1 = phono (UFO202)
                        var allInputs = SoundIn.ar([0,1,2,3]); // All 4 inputs for metering
                        src = Select.ar(inputMode, [
                            allInputs[0..1], // Line inputs (UCA202) - channels 0,1
                            allInputs[2..3]  // Phono inputs (UFO202) - channels 2,3
                        ]);
                        
                        // Input gain control (pre-EQ)
                        src = [src[0] * inputGainL, src[1] * inputGainR];
                        
                        // Mute control
                        src = src * (1 - mute);
                        // For file playback testing, use: src = PlayBuf.ar(sndbuf.numChannels, buffer, BufRateScale.kr(buffer), loop: 1);
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
                            // Correct quad mapping: LF=0, RF=1, LR=2, RR=3
                            frontStereo = Balance2.ar(out[0], out[3], quadLR); // LF, RF
                            rearStereo  = Balance2.ar(out[1], out[2], quadLR); // LR, RR
                            quadOutFront = frontStereo * ((quadFR + 1) * 0.5); // scale front by 0..1
                            quadOutRear  = rearStereo  * ((1 - quadFR) * 0.5); // scale rear by 1..0
                            out = [
                                quadOutFront[0], // LF = channel 0
                                quadOutFront[1], // RF = channel 1
                                quadOutRear[0],  // LR = channel 2
                                quadOutRear[1]   // RR = channel 3
                            ];
                        });
                        
                        // Output to audio bus
                        Out.ar(0, out);
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

                    // Restore saved parameters to new synth
                    ~restoreSynthParams.value();

                    // Create level meter after synth is started
                    {
                        ~meter.remove; // Remove any existing meter
                        ~meter = ServerMeter2View.new(s, ~meterContainer, 0@10, 4, 4); // Always show 4 inputs and 4 outputs - moved down 10px
                        // Apply visual mute state if active
                        ~updateVisualMute.value();
                    }.defer(0.1);

                    ("Audio synthesis started with level meter").postln;
                });
            }, {
                if(needReboot, {
                    s.options.memSize = 65536;
                    s.options.numOutputBusChannels = outputs;
                    s.options.numInputBusChannels = inputs;
                    // Use jack_quad device created by our setup script
                    s.options.device = "jack_quad";
                    s.reboot;
                    cond = Condition.new;
                    s.waitForBoot({
                        // Set audio card volume after server reboot
                        ("amixer -c HD set PCM 80%").unixCmd;

                        // Define encoder kernels
                        encoderDict = Dictionary.newFrom([
                            \uhj, FoaEncoderKernel.newUHJ,
                            \superstereo, FoaEncoderKernel.newSuper,
                            \maplin, FoaEncoderMatrix.newDirections([-45, 45, -135, 135].degrad),  // MaplinMatrix quad encoder
                        ]);

                        // Define decoder kernels (matching MainApp2 exactly, excluding unused \none)
                        decoderDict = Dictionary.newFrom([
                            \stereo, FoaDecoderMatrix.newStereo,
                            \binaural, FoaDecoderKernel.newListen(1053),
                            \binaurac, FoaDecoderKernel.newCIPIC(12),
                            \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                            \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                            \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual')
                        ]);

                        // Get selected encoder and decoder
                        encoder = encoderDict.at(configKeyE ? \uhj);
                        decoder = decoderDict.at(configKeyD ? \binaural);

                        ("Audio engine initialized with encoder: " ++ configKeyE ++ " and decoder: " ++ configKeyD).postln;
                        
                        // Set up JACK connections after server reboot
                        ~setupBehringerJACK.value();

                        // Load test audio file (same as MainApp2)
                        sndbuf = Buffer.read(s, Atk.userSoundsDir ++ "/uhj/Stereotomy.wav");

                        s.sync(cond);

                        // Define the main audio processing SynthDef (adapted from MainApp2)
                        SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, quadLR = 0, quadFR = 0, ambience = 0, preDelay = 0, lowRT = 0.2, highRT = 2, dispersion = 1, modWidth = 0.2, modRate = 0.3, eq1 = 0, eq2 = 0, eq3 = 0, eq4 = 0, eq5 = 0, eq6 = 0, eq7 = 0, maplinSurround = 0.8, maplinEffect = 0.8, maplinDelay = 0.4, maplinActive = 1, maplinMode = 0, inputMode = 0, inputGainL = 1.0, inputGainR = 1.0, mute = 0|
                            var out, src, trans, encode, ambient, eqed, frontStereo, rearStereo, quadOutFront, quadOutRear, maplinQuad, encodeInput;
                            
                            // Behringer input selection (LINE/PHONO mode)
                            // inputMode: 0 = line (UCA202), 1 = phono (UFO202)
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
                            // Spatial transformations (rotation, tilt, tumble)
                            trans = FoaRTT.ar(ambient, rotAngle: rotation, tilAngle: tilt, tumAngle: tumble);
                            // Decode using selected decoder
                            out = FoaDecode.ar(trans, decoder);

							// QUADRAPHONIC OUTPUT - STANDARD QUAD PANNING
							if(outputs == 4, {
								// --- Q-PANNER LOGIC (Balance2) ---
								// Correct quad mapping: LF=0, RF=1, LR=2, RR=3
								frontStereo = Balance2.ar(out[0], out[3], quadLR); // LF, RF
								rearStereo  = Balance2.ar(out[1], out[2], quadLR); // LR, RR
								quadOutFront = frontStereo * ((quadFR + 1) * 0.5); // scale front by 0..1
								quadOutRear  = rearStereo  * ((1 - quadFR) * 0.5); // scale rear by 1..0
								out = [
									quadOutFront[0], // LF
									quadOutFront[1], // RF
									quadOutRear[0],  // LR
									quadOutRear[1]   // RR
								];
							});

							// Output to audio bus
							Out.ar(0, out);
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

                        // Restore saved parameters to new synth
                        ~restoreSynthParams.value();

                        // Create level meter after synth is started
                        {
                            ~meter.remove; // Remove any existing meter
                            ~meter = ServerMeter2View.new(s, ~meterContainer, 0@10, 4, 4); // Always show 4 inputs and 4 outputs - moved down 10px
                            // Apply visual mute state if active
                            ~updateVisualMute.value();
                        }.defer(0.1);

                        ("Audio synthesis started with level meter").postln;
                    });
                });
            });
        });
    };
    tryBoot.value;
    // Update previous channel counts and decoder/encoder key
    ~prevInputs = inputs;
    ~prevOutputs = outputs;
    ~prevConfigKeyD = configKeyD;
    ~prevConfigKeyE = configKeyE;
};

// --- Level Meter Section ---
~meterView = View(mainView, Rect(180, 107, 320, 275)).background_(Color.clear);

// Add a thin border around the meter view
~meterBorder = UserView(~meterView, Rect(0, 0, 320, 275))
    .background_(Color.clear)
    .drawFunc_({ |v|
        Pen.width = 0.5;
        Pen.color = Color.cyan;
        Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
        Pen.stroke;
    });

// Centered LEVEL METER title
StaticText(~meterView, Rect(0, 5, 320, 30)).background_(Color.clear)
    .align_(\center)
    .string_("LEVEL METER")
    .stringColor_(Color.cyan)
    .font_(Font("Helvetica", 14).boldVariant);

// Initialize meter display area
~meterContainer = View(~meterView, Rect(40, 35, 270, 230)).background_(Color.black); // x=40, width=270

// --- Permanent INPUT label above the input numbers, always left-aligned ---
StaticText(~meterContainer, Rect(59, -2, 80, 16)) // x=32+2, width=80, y=5 - moved up 10px, then down 3px, then right 18px, then right 9px, then left 5px, then right 3px
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\left)
    .stringColor_(Color.cyan)
    .string_("INPUT");

// --- Permanent OUTPUT label above the output numbers, always centered ---
StaticText(~meterContainer, Rect(96, -2, 180, 16)) // x=99-2, width=180, y=5 - moved up 10px, then down 3px, then right 3px, then left 3px, then left 3px, then right 2px
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("OUTPUT");

// --- Permanent UCA label centered above input meters 1-2 ---
StaticText(~meterContainer, Rect(10, 15, 80, 16)) // centered on meters 1-2, above meters - moved left 30px, then right 3px, then right 3px, then right 3px
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("UCA");

// --- Permanent UFO label centered above input meters 3-4 ---
StaticText(~meterContainer, Rect(55, 15, 80, 16)) // centered on meters 3-4, above meters - moved left 10px, then right 8px, then right 3px, then right 3px
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("UFO");

// --- Permanent UCA label centered above output meters 1-2 ---
StaticText(~meterContainer, Rect(125, 15, 80, 16)) // centered on meters 1-2, above meters
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("UCA");

// --- Permanent UFO label centered above output meters 3-4 ---
StaticText(~meterContainer, Rect(167, 15, 80, 16)) // centered on meters 3-4, above meters - moved right 3px, then left 6px, then left 2px
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("UFO");



// --- Permanent output channel letters (LRLR) to overwrite ServerMeter2View numbers ---
4.do({ |i|
    var labelWidth = 24;
    var meterWidth = 20; // ServerMeter2View meter width
    var gapWidth = 2.5;  // ServerMeter2View gap width
    // Calculate x position for output meters (after inputs + divider)
    var outputStartX = 30 + (4 * (meterWidth + gapWidth)) + 10; // inputs + divider space
    var x = outputStartX + (i * (meterWidth + gapWidth)) + (meterWidth / 2) - (labelWidth / 2) + (meterWidth / 2) + 2; // moved right by half meter width + 2px
    StaticText(~meterContainer, Rect(x, 216, labelWidth, 16)) // y=216 to match input meter labels
        .background_(Color.black) // Black background to cover underlying numbers
        .font_(Font("Helvetica", 9).boldVariant)
        .align_(\center)
        .stringColor_(Color.cyan)
        .string_(["L", "R", "L", "R"][i]);
});

// --- Permanent input channel numbers below the input meters ---
~inputNumbers = Array.fill(inputs, { |i| // Show all input channels
    var labelWidth = 24;
    var meterWidth = 20; // ServerMeter2View meter width
    var gapWidth = 2.5;  // ServerMeter2View gap width
    var x = 30 + (i * (meterWidth + gapWidth)) + (meterWidth / 2) - (labelWidth / 2); // Match meter spacing + 3px right, then left 2px
    StaticText(~meterContainer, Rect(x, 216, labelWidth, 16))
        .background_(Color.clear)
        .font_(Font("Helvetica", 9).boldVariant)
        .align_(\center)
        .stringColor_(Color.cyan)
        .string_(["L", "R", "L", "R"][i]);
});


// --- Permanent vertical dB scale numbers (0 and -∞) ---
StaticText(~meterContainer, Rect(8, 35, 24, 12)) // x=6+2, y=18+7 (top) - moved up 10px
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("0");
StaticText(~meterContainer, Rect(8, 210, 24, 12)) // x=6+2, y=188+7 (bottom) - moved up 10px, then down 5px
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("-60");
// --- dB label halfway up the meter ---
StaticText(~meterContainer, Rect(8, 120, 24, 14)) // halfway up (approx) - moved down 10px
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("dB");

// Initialize input defaults (from MainApp2)
lastInL = 106; // Default 0dB (unity gain) with full range
lastInR = 106; // Default 0dB (unity gain) with full range
~leftSlider.value = (lastInL - minIn) / (maxIn - minIn);
~rightSlider.value = (lastInR - minIn) / (maxIn - minIn);
// Display initial dB values using logarithmic scaling
dbValue = cliToDbMaster.(lastInL);
~leftValue.string = formatDbValue.(dbValue);
~rightValue.string = formatDbValue.(dbValue);

                        ~lineBtn.value_(1);
            ~phonoBtn.value_(0);

// Set encoder/decoder menu defaults
~emenu.value_(0); // UHJ encoder
~dmenu.value_(0); // STEREO decoder

// Initialize hardware state
// Behringer devices use ALSA mixer commands, no phono-control needed

// Start audio engine with initial configuration after a short delay
{
    ~initAudioEngine.value();
}.defer(0.5);

// --- HEADTRACKER AND PANNER CONTROLS (with Standard Knobs) ---
        // Create value display labels first
        ~rotateValue = StaticText(mainView, Rect(719, 80, 55, 20)).font_(Font("Helvetica", 11)).string_("0").align_(\left).stringColor_(Color.cyan);
        ~tiltValue = StaticText(mainView, Rect(719, 162, 55, 20)) .font_(Font("Helvetica", 11)).string_("0").align_(\left).stringColor_(Color.cyan);
        ~tumbleValue = StaticText(mainView, Rect(719, 244, 55, 20)) .font_(Font("Helvetica", 11)).string_("0").align_(\left).stringColor_(Color.cyan);

        // Knob360 with 360-degree behavior and automatic mouse/headtracker detection
        ~rotateKnob = Knob360(mainView, Rect(654, 60, 60, 60), 0.5, 0.0, 1.0)
            .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
            .enabled_(false)
            .action_({ |knob, val|
                // 360-degree behavior: map 0-1 to -180 to +180 degrees
                var deg = val.linlin(0, 1, -180, 180).round.asInteger;

                // Automatic mouse/headtracker behavior adjustment
                if(~mouseActive, {
                    // Mouse input: invert direction for intuitive control
                    deg = deg.neg;
                    ~lastInputSource = \mouse;
                }, {
                    // Headtracker input: keep normal direction
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
                // 360-degree behavior: map 0-1 to -180 to +180 degrees
                var deg = val.linlin(0, 1, -180, 180).round.asInteger;

                // Automatic mouse/headtracker behavior adjustment
                if(~mouseActive, {
                    // Mouse input: invert direction for intuitive control
                    deg = deg.neg;
                    ~lastInputSource = \mouse;
                }, {
                    // Headtracker input: keep normal direction
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
                // 360-degree behavior: map 0-1 to -180 to +180 degrees
                var deg = val.linlin(0, 1, -180, 180).round.asInteger;

                // Automatic mouse/headtracker behavior adjustment
                if(~mouseActive, {
                    // Mouse input: invert direction for intuitive control
                    deg = deg.neg;
                    ~lastInputSource = \mouse;
                }, {
                    // Headtracker input: keep normal direction
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

// Value display labels already created above

~xyPanner = Slider2D(mainView, Rect(629, 334, 110, 110))
    .x_(0.5).y_(0.5)
    .knobColor_(Color.cyan)
    .background_(Color.black)
    .canFocus_(false)
    .action_({ |sl|
        // Equal-power law for left/right (x axis)
        var angleLR = sl.x.linlin(0, 1, 0, pi/2); // 0..1 → 0..π/2
        var quadLR = sin(angleLR) - cos(angleLR);  // -1..1 with equal power
        // Equal-power law for front/rear (y axis)
        var angleFR = sl.y.linlin(0, 1, 0, pi/2); // 0..1 → 0..π/2
        var quadFR = sin(angleFR) - cos(angleFR);  // -1..1 with equal power
        ~xyPannerPos = Point(sl.x, sl.y);
        if(~synth.notNil) {
            ~synth.set(\quadLR, quadLR, \quadFR, quadFR);
        }
    });
~xyPannerPos = Point(~xyPanner.x, ~xyPanner.y);

// --- Additional GUI Layout ---
// --- HEADTRACKER HEADING ---
StaticText(mainView, Rect(618, 10, 140, 28))
    .string_("HEADTRACKER")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

// --- BLUETOOTH PAIR BUTTON ---
~pairingInProgress = false;  // Flag to prevent multiple clicks
~headtrackPairBtn = Button(mainView, Rect(742, 142, 40, 20))
    .states_([
        ["PAIR", Color.cyan, Color.black],      // 0: Ready to pair
        ["...", Color.cyan, Color.black],       // 1: Pairing in progress  
        ["PAIR", Color.black, Color.cyan],      // 2: Success - cyan background like line button
        ["FAIL", Color.cyan, Color.black]       // 3: Failed
    ])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .value_(0)  // Explicitly set to PAIR state
    .action_({
        var scriptPath;
        
        // Check if pairing is already in progress
        if (~pairingInProgress) { 
            ^this 
        };
        
        // Check actual device status to determine action
        ~pairingInProgress = true;
        ~headtrackPairBtn.value_(1); // Show working
        
        Task({
            var deviceInfo, isPaired, isConnected, result, success = false;
            
            // First, check the ACTUAL device status
            deviceInfo = "bluetoothctl info E4:E1:DE:BE:DB:2F".unixCmdGetStdOut;
            isPaired = deviceInfo.contains("Paired: yes");
            isConnected = deviceInfo.contains("Connected: yes");
            
            if (isPaired) {
                // Device is paired - UNPAIR (remove device)
                ("Device is paired - removing...").postln;
                try {
                    // Disconnect first, then remove
                    ("Disconnecting headtracker...").postln;
                    result = "bluetoothctl disconnect E4:E1:DE:BE:DB:2F".unixCmdGetStdOut;
                    ("Disconnect result: " ++ result).postln;
                    1.wait; // Wait for disconnect to complete
                    
                    ("Removing headtracker...").postln;
                    result = "bluetoothctl remove E4:E1:DE:BE:DB:2F".unixCmdGetStdOut;
                    ("Remove result: " ++ result).postln;
                    1.wait; // Wait for removal to complete
                    
                    // Check if it's really gone
                    result = "bluetoothctl info E4:E1:DE:BE:DB:2F".unixCmdGetStdOut;
                    ("Final status: " ++ result).postln;
                    success = true;
                } { |error|
                    ("Unpair error: " ++ error).postln;
                    success = false;
                };
                
                {
                    ~pairingInProgress = false;
                    ~headtrackPairBtn.value_(0); // Reset to PAIR after unpair
                }.defer;
                
            } {
                // Device is not paired - PAIR the device
                ("Device not paired - pairing...").postln;
                
                // Run pairing script in background with timeout
                scriptPath = "/usr/local/bin/ble-ht.sh";
                
                // Safety timeout - reset button after 45 seconds if script hangs
                AppClock.sched(45, { 
                    if (~pairingInProgress) {
                        ~pairingInProgress = false;  // Reset flag
                        ~headtrackPairBtn.value_(3); // Show failed if still in progress
                        AppClock.sched(3, { ~headtrackPairBtn.value_(0); nil });
                    };
                    nil 
                });
                
                // First attempt
                try {
                    result = ("timeout 45 bash -c '" ++ scriptPath ++ "'").unixCmdGetStdOut;
                    success = result.contains("PAIRED_AND_CONNECTED");
                } { |error|
                    ("Pairing script error: " ++ error).postln;
                    success = false;
                };
                
                // If first attempt failed, automatically retry once
                if (success.not) {
                    ("First pairing attempt failed, retrying automatically...").postln;
                    1.wait; // Brief pause between attempts
                    
                    try {
                        result = ("timeout 45 bash -c '" ++ scriptPath ++ "'").unixCmdGetStdOut;
                        success = result.contains("PAIRED_AND_CONNECTED");
                        if (success) {
                            ("Second attempt succeeded!").postln;
                        } {
                            ("Both pairing attempts failed").postln;
                        };
                    } { |error|
                        ("Retry script error: " ++ error).postln;
                        success = false;
                    };
                };
                
                // Always update button, even if script failed
                {
                    ~pairingInProgress = false;  // Reset flag
                    if (success) {
                        ~headtrackPairBtn.value_(2); // Success - stay cyan to show paired
                    } {
                        ~headtrackPairBtn.value_(3); // Failed - red X
                        // Reset to PAIR after 3 seconds only on failure
                        AppClock.sched(3, { 
                            ~headtrackPairBtn.value_(0); 
                            nil 
                        });
                    };
                }.defer;
            };
        }).start;
    });
// Ensure button is above overlays
~headtrackPairBtn.front;

// Simple connection monitor - only checks when button shows paired
~connectionMonitor = Routine({
    var checkResult, isConnected, isPaired;
    
    // Wait a bit before starting monitoring to avoid startup delays
    3.wait;
    
    // Simple monitoring loop
    loop {
        5.wait; // Check every 5 seconds
        
        // Only check if button exists, shows paired status and not currently pairing
        if ((~headtrackPairBtn.notNil) && (~headtrackPairBtn.value == 2) && (~pairingInProgress.not)) {
            checkResult = "bluetoothctl info E4:E1:DE:BE:DB:2F".unixCmdGetStdOut;
            isConnected = checkResult.contains("Connected: yes");
            isPaired = checkResult.contains("Paired: yes");
            
            if (isPaired.not || isConnected.not) {
                // Device is disconnected/removed - reset button (GUI update on main thread)
                {
                    ~headtrackPairBtn.value_(0);
                }.defer;
            };
        };
    };
}).play;

// --- CONTROL LABELS ---
StaticText(mainView, Rect(594, 80, 55, 20)).string_("ROTATE").align_(\right).stringColor_(Color.cyan).font_(Font("Helvetica", 11));
StaticText(mainView, Rect(594, 162, 55, 20)).string_("TILT").align_(\right).stringColor_(Color.cyan).font_(Font("Helvetica", 11));
StaticText(mainView, Rect(594, 244, 55, 20)).string_("TUMBLE").align_(\right).stringColor_(Color.cyan).font_(Font("Helvetica", 11));

// --- ON/OFF TOGGLE BUTTON ---
~headtrackBtn = Button(mainView, Rect(742, 62, 40, 20))
    .states_([["OFF", Color.cyan, Color.black], ["ON", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({ |btn|
        var on = btn.value == 1;
        var idx = ~dmenu.value;
        var isBinaural = (idx == 1) or: { idx == 2 };
        // Remove overlays if present
        if(~knobOverlay.notNil) { ~knobOverlay.remove; ~knobOverlay = nil; };
        if(~htResetOverlay.notNil) { ~htResetOverlay.remove; ~htResetOverlay = nil; };
        if(isBinaural) {
            if(on) {
                // Headtracking ON: enable controls and show reset button
                ~headtrackResetBtn.enabled_(true);
                ~rotateKnob.enabled_(true);
                ~tiltKnob.enabled_(true);
                ~tumbleKnob.enabled_(true);
            } {
                // Headtracking OFF: disable controls and hide reset button
                ~headtrackResetBtn.enabled_(false);
                ~rotateKnob.enabled_(false);
                ~tiltKnob.enabled_(false);
                ~tumbleKnob.enabled_(false);
                ~knobOverlay = View(mainView, Rect(594, 60, 147, 224)) // width was 145, now 147
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
                ~htResetOverlay = View(mainView, Rect(734, 102, 48, 20)) // Cover RESET button
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
            }
        }
    })
    .value_(0); // default OFF

// --- RESET BUTTON ---
~headtrackResetBtn = Button(mainView, Rect(742, 102, 40, 20))
    .states_([["RESET", Color.cyan, Color.black]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({
        // Reset both headtracker and quad panner - only the active one will have any effect
        ~rotateKnob.valueAction_(0.5); ~rotateKnob.enabled_(false);
        ~tiltKnob.valueAction_(0.5); ~tiltKnob.enabled_(false);
        ~tumbleKnob.valueAction_(0.5); ~tumbleKnob.enabled_(false);
        ~xyPanner.setXYActive(0.5, 0.5);
    });

// --- Now trigger the overlay/enable logic for the correct initial state ---
~dmenu.globalAction.value(~dmenu);

// --- Q-PANNER LABEL ---
StaticText(mainView, Rect(629, 299, 110, 22))
    .string_("Q-PANNER")
    .align_(\center)
    .stringColor_(Color.cyan)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .background_(Color.clear);
win.front;


// --- Overlay Buttons (EQ, AMBIENCE, LAYOUT) below meter area ---
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
                .focusColor_(Color.clear)
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
                .focusColor_(Color.clear)
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
                .focusColor_(Color.clear)
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
            ~saveEqState.value(); // Save state before closing
            if(~eqOverlay.notNil) { ~eqOverlay.remove; ~eqOverlay = nil; };
            ~eqSliders = nil; ~eqValues = nil; ~eqPresetMenu = nil;
        }
    });
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

// --- Ambience State Management Functions ---
~saveAmbienceState = {
    if(~ambienceSliders.notNil) {
        ~ambienceState[\sliderValues] = ~ambienceSliders.collect({ |slider| slider.value });
        ("Saved ambience state: " ++ ~ambienceState[\sliderValues]).postln;
    };
    if(~ambiencePresetMenu.notNil) {
        ~ambienceState[\presetIndex] = ~ambiencePresetMenu.value;
        ("Saved preset index: " ++ ~ambienceState[\presetIndex]).postln;
    };
};

~restoreAmbienceState = {
    if(~ambienceSliders.notNil and: { ~ambienceState[\sliderValues].notNil }) {
        ("Restoring ambience state: " ++ ~ambienceState[\sliderValues]).postln;
        ~ambienceSliders.do({ |slider, i|
            var savedValue = ~ambienceState[\sliderValues][i] ? 0.0;
            slider.value_(savedValue);
            if(slider.action.notNil) {
                slider.action.value(slider);
            };
        });
    };
    if(~ambiencePresetMenu.notNil and: { ~ambienceState[\presetIndex].notNil }) {
        ("Restoring preset index: " ++ ~ambienceState[\presetIndex]).postln;
        ~ambiencePresetMenu.value_(~ambienceState[\presetIndex]);
    };
};

// --- EQ State Management Functions ---
~saveEqState = {
    if(~eqSliders.notNil) {
        ~eqState[\sliderValues] = ~eqSliders.collect({ |slider| slider.value });
        ("Saved EQ state: " ++ ~eqState[\sliderValues]).postln;
    };
    if(~eqPresetMenu.notNil) {
        ~eqState[\presetIndex] = ~eqPresetMenu.value;
        ("Saved EQ preset index: " ++ ~eqState[\presetIndex]).postln;
    };
};

~restoreEqState = {
    if(~eqSliders.notNil and: { ~eqState[\sliderValues].notNil }) {
        ("Restoring EQ state: " ++ ~eqState[\sliderValues]).postln;
        ~eqSliders.do({ |slider, i|
            var savedValue = ~eqState[\sliderValues][i] ? 0.5;
            slider.value_(savedValue);
            if(slider.action.notNil) {
                slider.action.value(slider);
            };
        });
    };
    if(~eqPresetMenu.notNil and: { ~eqState[\presetIndex].notNil }) {
        ("Restoring EQ preset index: " ++ ~eqState[\presetIndex]).postln;
        ~eqPresetMenu.value_(~eqState[\presetIndex]);
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
        ~maplinState[\active] = if(~maplinActiveBtn.value == 0, 1, 0); // Button value 0 = ON (active = 1)
        ("Saved Maplin GUI state: surround=" ++ ~maplinState[\surround] ++ ", effect=" ++ ~maplinState[\effect] ++ ", delay=" ++ ~maplinState[\delay] ++ ", active=" ++ ~maplinState[\active]).postln;
    };
};

~restoreMaplinState = {
    if(~maplinSurroundKnob.notNil) {
        ~maplinSurroundKnob.value_(~maplinState[\surround] ? 0.8);
        ~maplinEffectKnob.value_(~maplinState[\effect] ? 0.8);
        ~maplinDelayKnob.value_(~maplinState[\delay] ? 0.4);
        ~maplinActiveBtn.value_(if(~maplinState[\active] == 1, 0, 1)); // Active 1 = button value 0 (ON)

        // Update value displays
        ~maplinSurroundValue.string_((~maplinState[\surround] * 100).round(1).asString ++ "%");
        ~maplinEffectValue.string_((~maplinState[\effect] * 100).round(1).asString ++ "%");
        ~maplinDelayValue.string_((~maplinState[\delay].linlin(0, 1, 5, 50).round(1).asString ++ " ms"));

        // Trigger actions to update synth (including active button)
        if(~maplinSurroundKnob.action.notNil) { ~maplinSurroundKnob.action.value(~maplinSurroundKnob); };
        if(~maplinEffectKnob.action.notNil) { ~maplinEffectKnob.action.value(~maplinEffectKnob); };
        if(~maplinDelayKnob.action.notNil) { ~maplinDelayKnob.action.value(~maplinDelayKnob); };
        if(~maplinActiveBtn.action.notNil) { ~maplinActiveBtn.action.value(~maplinActiveBtn); };

        ("Restored Maplin GUI state: surround=" ++ ~maplinState[\surround] ++ ", effect=" ++ ~maplinState[\effect] ++ ", delay=" ++ ~maplinState[\delay] ++ ", active=" ++ ~maplinState[\active]).postln;
    };
};

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

            // --- ON/OFF toggle for Ambience (controls Mix sent to synth, but does NOT move slider) ---
            ~ambienceOnOffBtn = Button(~ambienceOverlay, Rect(18, 40, 80, 28))
                .states_([["OFF", Color.cyan, Color.black], ["ON", Color.black, Color.cyan]])
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .value_(0) // Default OFF
                .action_({ |btn|
                    if(btn.value == 1) {
                        // Turn ON: restore last mix value to synth
                        if(~ambienceLastMix.notNil and: { ~ambienceLastMix > 0 }) {
                            ~ambienceSliders[0].value_(~ambienceLastMix);
                            if(~synth.notNil) {
                                ~synth.set(\ambience, ~ambienceLastMix.linlin(0, 1, 0, 0.2));
                            };
                        } {
                            // No last mix, use current slider value
                            var currentMix = ~ambienceSliders[0].value;
                            if(currentMix > 0) {
                                ~ambienceLastMix = currentMix;
                                if(~synth.notNil) {
                                    ~synth.set(\ambience, currentMix.linlin(0, 1, 0, 0.2));
                                };
                            };
                        };
                    } {
                        // Turn OFF: remember current mix and set synth to 0
                        var currentMix = ~ambienceSliders[0].value;
                        if(currentMix > 0) {
                            ~ambienceLastMix = currentMix;
                        };
                        if(~synth.notNil) {
                            ~synth.set(\ambience, 0);
                        };
                    };
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

            // --- Mix slider action: always updates value label and, if ON, sends to synth ---
            ~ambienceSliders[0].action_({ |sl|
                var val = (sl.value * 100).round(0.1);
                ~ambienceValues[0].string = val.asString ++ "%";
                if(~synth.notNil and: { ~ambienceOnOffBtn.value == 1 }) {
                    ~synth.set(\ambience, sl.value.linlin(0, 1, 0, 0.2));
                };
            });

            // --- Ensure ON/OFF button and Mix slider are visually independent on open ---
            if(~ambienceOnOffBtn.notNil) { ~ambienceOnOffBtn.value_(0); };
            if(~ambienceSliders.notNil and: { ~ambienceSliders[0].notNil }) { ~ambienceSliders[0].value = 0; };

            // Close button
            Button(~ambienceOverlay, Rect(222, 230, 80, 28))
                .states_([["CLOSE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
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
                .focusColor_(Color.clear)
                .action_({
                    // Reset to default preset
                    if(~ambiencePresetNames.notNil and: { ~ambiencePresetNames.size > 0 }) {
                        ~ambiencePresetMenu.value_(0); // Select first preset
                        ~recallAmbiVerbSCPreset.value(~ambiencePresetNames[0]);
                    }
                });
            Button(~ambienceOverlay, Rect(222, 230, 80, 28))
                .states_([ ["CLOSE", Color.cyan, Color.black] ])
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .action_({
                    ~saveAmbienceState.value(); // Save state before closing
                    ~ambienceOverlay.remove;
                    ~ambienceOverlay = nil;
                    ~ambienceBtn.value_(0);
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
                .string_("LAYOUT - " ++ (["STEREO", "BINAURAL IRCAM", "BINAURAL CIPIC", "QUAD SQUARE", "QUAD NARROW", "QUAD WIDE"][~dmenu.value ? 0]))
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
                        0, { // Stereo
                            var speakerWidth = 20, speakerHeight = 20, speakerSpacing = 120, leftSpeakerX, rightSpeakerX, speakerY;
                            var centerY_bottom = centerY + 80; // Center point further down at bottom of triangle
                            var leftRotationAngle, rightRotationAngle;
                            leftSpeakerX = centerX - (speakerSpacing / 2) - (speakerWidth / 2);
                            rightSpeakerX = centerX + (speakerSpacing / 2) - (speakerWidth / 2);
                            speakerY = centerY - 40; // Speakers at top of triangle
                            
                            // Calculate rotation angles
                            leftRotationAngle = atan2(centerY_bottom - speakerY, centerX - leftSpeakerX) + (pi / 2);
                            rightRotationAngle = atan2(centerY_bottom - speakerY, centerX - rightSpeakerX) + (pi / 2);
                            
                            // Draw triangle lines
                            Pen.color = Color.cyan; Pen.width = 1;
                            // Left diagonal from center to left speaker
                            Pen.line(Point(centerX, centerY_bottom), Point(leftSpeakerX + (speakerWidth / 2), speakerY + (speakerHeight / 2)));
                            Pen.stroke;
                            // Right diagonal from center to right speaker
                            Pen.line(Point(centerX, centerY_bottom), Point(rightSpeakerX + (speakerWidth / 2), speakerY + (speakerHeight / 2)));
                            Pen.stroke;
                            
                            // Speaker 1: Left (rotated to face center + 180° for upright text)
                            Pen.push;
                            Pen.translate(leftSpeakerX + (speakerWidth / 2), speakerY + (speakerHeight / 2));
                            Pen.rotate(leftRotationAngle + pi);
                            Pen.translate(-10, -10);
                            Pen.color = Color.black; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(7, 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.pop;
                            
                            // Speaker 2: Right (rotated to face center + 180° for upright text)
                            Pen.push;
                            Pen.translate(rightSpeakerX + (speakerWidth / 2), speakerY + (speakerHeight / 2));
                            Pen.rotate(rightRotationAngle + pi);
                            Pen.translate(-10, -10);
                            Pen.color = Color.black; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(7, 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.pop;
                            
                            Pen.stringAtPoint("[1] L (-30°) & [2] R (+30°)", Point(centerX - 75, 32), Font("Helvetica", 13), Color.cyan);
                            Pen.stringAtPoint("Optimum listening angles", Point(centerX - 70, 50), Font("Helvetica", 12, italic: true), Color.cyan);
                        },
                        1, { // IRCAM Binaural
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
                        2, { // CIPIC Binaural
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
                        3, { // Quad Square
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

            // Create Maplin overlay
            ~maplinOverlay = View(mainView, Rect(180, 107, 320, 275)).background_(Color.black);

            // Border
            UserView(~maplinOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });

            // Title
            StaticText(~maplinOverlay, Rect(10, 5, 200, 22))
                .string_("MAPLIN SM-333")
                .align_(\left)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);

            // Labels above knobs
            StaticText(~maplinOverlay, Rect(18, 80, 80, 20))
                .string_("SURROUND")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);

            StaticText(~maplinOverlay, Rect(120, 80, 80, 20))
                .string_("EFFECT")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);

            StaticText(~maplinOverlay, Rect(222, 80, 80, 20))
                .string_("DELAY")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);

            // Three control knobs
            ~maplinSurroundKnob = Knob(~maplinOverlay, Rect(18, 110, 80, 80))
                .value_(~maplinState[\surround] ? 0.8)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob|
                    ~setMaplinSurround.(knob.value);
                    ~maplinSurroundValue.string_((knob.value * 100).round(1).asString ++ "%");
                });

            ~maplinEffectKnob = Knob(~maplinOverlay, Rect(120, 110, 80, 80))
                .value_(~maplinState[\effect] ? 0.8)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob|
                    ~setMaplinEffect.(knob.value);
                    ~maplinEffectValue.string_((knob.value * 100).round(1).asString ++ "%");
                });

            ~maplinDelayKnob = Knob(~maplinOverlay, Rect(222, 110, 80, 80))
                .value_(~maplinState[\delay] ? 0.4)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob|
                    ~setMaplinDelay.(knob.value);
                    ~maplinDelayValue.string_((knob.value.linlin(0, 1, 5, 50).round(1).asString ++ " ms"));
                });

            // Value displays below knobs
            ~maplinSurroundValue = StaticText(~maplinOverlay, Rect(18, 200, 80, 18))
                .string_("80%")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13))
                .background_(Color.clear);

            ~maplinEffectValue = StaticText(~maplinOverlay, Rect(120, 200, 80, 18))
                .string_("80%")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13))
                .background_(Color.clear);

            ~maplinDelayValue = StaticText(~maplinOverlay, Rect(222, 200, 80, 18))
                .string_("25 ms")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13))
                .background_(Color.clear);

            // On/Off button
            ~maplinActiveBtn = Button(~maplinOverlay, Rect(18, 40, 80, 28))
                .states_([
                    ["ON", Color.black, Color.cyan],
                    ["OFF", Color.cyan, Color.black]
                ])
                .action_({ |button|
                    ~setMaplinActive.(button.value == 0);
                })
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .value_(1); // Default to OFF (button state 1 = OFF)

            // Preset buttons
            Button(~maplinOverlay, Rect(120, 40, 80, 28))
                .states_([["BALANCED", Color.cyan, Color.black]])
                .action_({
                    ~maplinPresetBalanced.();
                    ~maplinSurroundKnob.value_(0.8);
                    ~maplinEffectKnob.value_(0.8);
                    ~maplinDelayKnob.value_(0.4);
                    ~maplinSurroundValue.string_("80%");
                    ~maplinEffectValue.string_("80%");
                    ~maplinDelayValue.string_("25 ms");
                })
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .background_(Color.black);

            Button(~maplinOverlay, Rect(222, 40, 80, 28))
                .states_([["MAXIMUM", Color.cyan, Color.black]])
                .action_({
                    ~maplinPresetMax.();
                    ~maplinSurroundKnob.value_(1.0);
                    ~maplinEffectKnob.value_(1.0);
                    ~maplinDelayKnob.value_(1.0);
                    ~maplinSurroundValue.string_("100%");
                    ~maplinEffectValue.string_("100%");
                    ~maplinDelayValue.string_("50 ms");
                })
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .background_(Color.black);

            // Close button
            Button(~maplinOverlay, Rect(222, 230, 80, 28))
                .states_([["CLOSE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .action_({
                    ~saveMaplinState.value(); // Save state before closing
                    ~maplinOverlay.remove;
                    ~maplinOverlay = nil;
                    ~maplinBtn.value_(0);
                });

            ~maplinOverlay.front;
            ~maplinBtn.value_(1);

            // Restore saved state after overlay is created
            ~restoreMaplinState.value();

        } {
            if(~maplinOverlay.notNil) {
                ~maplinOverlay.remove;
                ~maplinOverlay = nil;
            };
        }
    });

// Set initial SM-333 button state based on current encoder
if(configKeyE != \maplin) {
    // Add overlay to dim button if not in maplin mode
    ~maplinBtnOverlay = View(mainView, Rect(290, 410, 100, 35))
        .background_(Color.black.alpha_(0.7))
        .alpha_(1.0)
        .front;
};

// --- OUTPUT FADER (GRAPHICAL ONLY, GUIPrototype style) ---
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
        ~outputValue.string_(db.asString); // No decimal
        if(~synth.notNil) {
            var amp = 10.pow(db / 20);
            ~synth.set(\amp, amp);
        };
        // Persist current amp so decoder/server reboot starts new synth at same level
        voltmp = 10.pow(db / 20);
    });

~outputValue = StaticText(mainView, Rect(544, 380, 24, 24))
    .string_("0")
    .align_(\center)
    .stringColor_(Color.cyan)
    .font_(Font("Helvetica", 13));

// Ensure output fader starts at top (0dB) to match SynthDef default
~outputSlider.valueAction_(1.0); // Set to 0dB position (top)

// Tick marks for output fader (3px further from fader)
UserView(mainView, Rect(537, 70, 4, 300))
    .background_(Color.clear)
    .drawFunc_({ |view|
        Pen.color = Color.cyan;
        Pen.width = 1;
        // Major tick marks every 50 pixels
        [0, 50, 100, 150, 200, 250, 300].do({ |y|
            Pen.line(Point(0, y), Point(4, y));
            Pen.stroke;
        });
        // Minor tick marks every 25 pixels (between majors)
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
        // Major tick marks every 50 pixels
        [0, 50, 100, 150, 200, 250, 300].do({ |y|
            Pen.line(Point(0, y), Point(4, y));
            Pen.stroke;
        });
        // Minor tick marks every 25 pixels (between majors)
        [25, 75, 125, 175, 225, 275].do({ |y|
            Pen.line(Point(1, y), Point(3, y));
            Pen.stroke;
        });
    });

// --- JACK Connection Setup for Behringer Devices ---
~setupBehringerJACK = {
    // Wait for server to boot and jack_quad device to be ready
    AppClock.sched(2.0, {
        // First, disconnect any existing connections to avoid duplicates
        "jack_disconnect system:capture_1 jack_quad:in_1 2>/dev/null".unixCmd;
        "jack_disconnect system:capture_2 jack_quad:in_2 2>/dev/null".unixCmd;
        "jack_disconnect ufo_phono:capture_1 jack_quad:in_3 2>/dev/null".unixCmd;
        "jack_disconnect ufo_phono:capture_2 jack_quad:in_4 2>/dev/null";
        
        // Wait a moment for disconnections to complete
        AppClock.sched(0.1, {
            // Now establish the correct routing:
            // UCA202 line inputs (1&2) -> jack_quad:in_1 & jack_quad:in_2
            "jack_connect system:capture_1 jack_quad:in_1".unixCmd;
            "jack_connect system:capture_2 jack_quad:in_2".unixCmd;
            
            // UFO202 phono inputs (3&4) -> jack_quad:in_3 & jack_quad:in_4
            "jack_connect ufo_phono:capture_1 jack_quad:in_3".unixCmd;
            "jack_connect ufo_phono:capture_2 jack_quad:in_4".unixCmd;
            
            // Connect jack_quad outputs to playback devices
            "jack_connect jack_quad:out_1 system:playback_1".unixCmd;
            "jack_connect jack_quad:out_2 system:playback_2".unixCmd;
            if(outputs >= 4, {
                "jack_connect jack_quad:out_3 ufo_out:playback_1".unixCmd;
                "jack_connect jack_quad:out_4 ufo_out:playback_2".unixCmd;
            });
            
            ("JACK connections established through jack_quad device").postln;
            ("UCA202: Line inputs 1&2, UFO202: Phono inputs 3&4").postln;
        });
    });
};

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
// ... existing

// --- POWER BUTTON (bottom right corner) ---
~powerBtn = Button(mainView, Rect(760, 445, 20, 20))
    .states_([["X", Color.cyan, Color.black]]) // Match headtracking button style, uppercase X
    .font_(Font("Helvetica", 10)) // Same size as RESET button
    .focusColor_(Color.clear)
    .mouseDownAction_({ |view, x, y, modifiers, buttonNumber, clickCount|
        win.close;
    })
    .touchBeginAction_({ |view, x, y, pressure, id|
        win.close;
    });

// --- Initialize Behringer setup ---
~detectBehringerDevices.value();

// Set default input mode
~setInputMode.(\line);

// Initialize audio engine with delay
{
    ~initAudioEngine.value();
}.defer(0.5);

win.front;