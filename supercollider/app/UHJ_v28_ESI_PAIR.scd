// ============================================================================
// UHJ v23 - PSEUDO-SURROUND ENCODER WITH HEADTRACKER KNOBS
// ============================================================================

// Using standard Knob class with custom 360-degree action handling
// Features automatic mouse/headtracker detection for intuitive control

var win, mainView,
    decoderChanged,
    isUpdating, lastInputCmd, linkFaders, lastInL, lastInR, minIn, maxIn, lastFaderGroup,
    voltmp, cond, sndbuf, synth, inputs, outputs, configKeyD, configKeyE,
    dbValue, cliToDb, cliToDbMaster, formatDbValue;
// --- Overlay GUI variables (must be declared at the top, per GUIPrototype) ---
~eqOverlay = nil; ~ambienceOverlay = nil; ~layoutOverlay = nil; ~dimensionOverlay = nil;
~layoutTitleText = nil;
~eqBtn = nil; ~ambienceBtn = nil; ~layoutBtn = nil; ~dimensionBtn = nil;
// --- EQ overlay variables (from GUIPrototype) ---
~eqPresetMenu = nil; ~eqPresetNames = nil; ~eqPresetDict = nil; ~eqSliders = nil; ~eqValues = nil;
// --- Maplin overlay variables (for Maplin encoder only) ---
~maplinSurroundKnob = nil; ~maplinEffectKnob = nil; ~maplinDelayKnob = nil; ~maplinActiveBtn = nil;
~maplinSurroundValue = nil; ~maplinEffectValue = nil; ~maplinDelayValue = nil;

// --- Dimension overlay semi-transparent covers (hide controls based on encoder) ---
~dimensionRowOverlay = nil;  // Covers Dimension row when MAPLIN encoder selected
~maplinRowOverlay = nil;     // Covers Maplin row when UHJ/SUPERSTEREO/PHJ selected
// --- Headtracker overlanil; ~htBtnOverlay = nil; ~htResetOverlay = nil; ~htPairOverlay = nil;                                                                                                                                                                                                                                                                                                                
// --- Headtracker pairing button reference ---
~headtrackPairBtn = nil;
// --- Power button state ---
~powerBtnPressed = false;
// --- AmbiVerbSC preset system variables ---
~ambiencePresetNames = nil; ~ambiencePresetDict = nil; ~ambiencePresetMenu = nil;

// --- Ambience state preservation variables ---
~ambienceState = Dictionary.newFrom([
    \sliderValues, [0.0, 0.2, 0.0, 0.2, 0.0, 0.0, 0.0],  // Default values
    \presetIndex, 0,  // Default preset index
    \lastMix, 0.0     // Remember last nonzero mix value
]);

// --- EQ state preservation variables ---
~eqState = Dictionary.newFrom([
    \sliderValues, [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],  // Default values (0dB = 0.5)
    \presetIndex, 0   // Default preset index
]);

// --- Maplin state preservation variables (for Maplin encoder only) ---
~maplinState = Dictionary.newFrom([
    \surround, 0.8,   // Surround level
    \effect, 0.8,     // Effect level
    \delay, 0.4,      // Delay amount
    \active, 0        // Active/bypass (default OFF - 1 = active, 0 = bypass)
]);

// --- Dimension active state (shared with Maplin ON/OFF button) ---
~dimensionActive = 0;  // Default OFF (1 = active, 0 = bypass)

// --- Dimension state preservation variables ---
~dimensionState = Dictionary.newFrom([
    \sliderValues, [0.0, 0.5, 0.5],  // width, widthHPF (normalized), outputTrim (normalized 0-1) - LF/HF removed (shelves disabled)
    \presetIndex, 0   // Default preset index
]);

// --- ZSynth state preservation variables ---
~zsynthState = Dictionary.newFrom([
    \sliderValues, [0.3, 0.07, 0.5, 0.0, 0.625, 0.2, 0.7],  // heightAmount, heightDelay, heightTrim, heightSource, ambienceSize, ambienceDampening, ambienceMix
    \presetIndex, 0   // Default preset index
]);

// --- Dolby control state preservation variables ---
~dolbyState = Dictionary.newFrom([
    \centerGain, 0.0,      // Center gain in dB (0dB default)
    \subGain, 0.0,         // Sub/LFE gain in dB (0dB default)
    \heightGain, 0.0,      // Height gain in dB (0dB default)
    \flOn, 1,              // Front Left on/off (1 = on, 0 = off)
    \frOn, 1,              // Front Right on/off (1 = on, 0 = off)
    \rlOn, 1,              // Rear Left on/off (1 = on, 0 = off)
    \rrOn, 1,              // Rear Right on/off (1 = on, 0 = off)
    \centerOn, 1,          // Center on/off (1 = on, 0 = off)
    \subOn, 1,             // Sub on/off (1 = on, 0 = off)
    \tflOn, 1,             // Top Front Left on/off (1 = on, 0 = off)
    \tfrOn, 1              // Top Front Right on/off (1 = on, 0 = off)
]);

// --- Quad layout state preservation variables (independent per layout) ---
~quadSquareState = Dictionary.newFrom([
    \flOn, 1,              // Front Left on/off (1 = on, 0 = off)
    \frOn, 1,              // Front Right on/off (1 = on, 0 = off)
    \rlOn, 1,              // Rear Left on/off (1 = on, 0 = off)
    \rrOn, 1               // Rear Right on/off (1 = on, 0 = off)
]);
~quadNarrowState = Dictionary.newFrom([
    \flOn, 1,              // Front Left on/off (1 = on, 0 = off)
    \frOn, 1,              // Front Right on/off (1 = on, 0 = off)
    \rlOn, 1,              // Rear Left on/off (1 = on, 0 = off)
    \rrOn, 1               // Rear Right on/off (1 = on, 0 = off)
]);
~quadWideState = Dictionary.newFrom([
    \flOn, 1,              // Front Left on/off (1 = on, 0 = off)
    \frOn, 1,              // Front Right on/off (1 = on, 0 = off)
    \rlOn, 1,              // Rear Left on/off (1 = on, 0 = off)
    \rrOn, 1               // Rear Right on/off (1 = on, 0 = off)
]);

// --- Octagon layout state preservation variables ---
~octagonState = Dictionary.newFrom([
    \s1On, 1,              // Speaker 1 on/off (1 = on, 0 = off)
    \s2On, 1,              // Speaker 2 on/off (1 = on, 0 = off)
    \s3On, 1,              // Speaker 3 on/off (1 = on, 0 = off)
    \s4On, 1,              // Speaker 4 on/off (1 = on, 0 = off)
    \s5On, 1,              // Speaker 5 on/off (1 = on, 0 = off)
    \s6On, 1,              // Speaker 6 on/off (1 = on, 0 = off)
    \s7On, 1,              // Speaker 7 on/off (1 = on, 0 = off)
    \s8On, 1               // Speaker 8 on/off (1 = on, 0 = off)
]);

// --- Stereo/Binaural layout state preservation variables ---
~stereoState = Dictionary.newFrom([
    \lOn, 1,               // Left channel on/off (1 = on, 0 = off)
    \rOn, 1                // Right channel on/off (1 = on, 0 = off)
]);

~binauralState = Dictionary.newFrom([
    \lOn, 1,                // Left ear on/off (1 = on, 0 = off)
    \rOn, 1                 // Right ear on/off (1 = on, 0 = off)
]);

// --- Binaural HRTF selection (defaults) ---
~binauralIRCAMId = 1053; // IRCAM LISTEN subject id (no leading zeros)
~binauralCIPICId = 12;   // CIPIC subject id (no leading zeros)
~binauralIRCAMPendingId = ~binauralIRCAMId;
~binauralCIPICPendingId = ~binauralCIPICId;
~binauralIrcamSelectBtn = nil;
~binauralCipicSelectBtn = nil;
~binauralIrcamChooserWin = nil;
~binauralCipicChooserWin = nil;
~binauralIRCAMIds = nil;
~binauralCIPICIds = [3, 8, 9, 10, 11, 12, 15, 17, 18, 19, 20, 21, 27, 28, 33, 40, 44, 48, 50, 51, 58, 59, 60, 61, 65, 119, 124, 126, 127, 131, 133, 134, 135, 137, 147, 148, 152, 153, 154, 155, 156, 158, 162, 163, 165];
~binauralIrcamProfileLabel = nil;
~binauralCipicProfileLabel = nil;
~binauralLeftEarHit = nil;
~binauralRightEarHit = nil;
~stereoLeftHit = nil;
~stereoRightHit = nil;
~quadSquareFLHit = nil; ~quadSquareFRHit = nil; ~quadSquareRLHit = nil; ~quadSquareRRHit = nil;
~quadNarrowFLHit = nil; ~quadNarrowFRHit = nil; ~quadNarrowRLHit = nil; ~quadNarrowRRHit = nil;
~prevBinauralIRCAMId = ~binauralIRCAMId;
~prevBinauralCIPICId = ~binauralCIPICId;

// --- Dimension overlay variables ---
~dimensionWidthKnob = nil; ~dimensionWidthHPFKnob = nil; ~dimensionTrimKnob = nil;
~dimensionWidthValue = nil; ~dimensionWidthHPFValue = nil; ~dimensionTrimValue = nil;
~dimensionPresetMenu = nil; ~dimensionPresetNames = nil; ~dimensionPresetDict = nil;

// --- ZSynth overlay variables ---
~zsynthSliders = nil; ~zsynthValues = nil; ~zsynthPresetMenu = nil;
~zsynthPresetNames = nil; ~zsynthPresetDict = nil;



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
configKeyD = \stereo;   // Default decoder: Stereo
inputs = 2;             // Default input channels
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

// --- Window setup with platform-specific positioning ---
win = Window("UHJ Ambisonic System", Rect(0, 0, 800, 480), border: false).background_(Color.black);
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
            if(linkFaders) {
                ~rightSlider.value = sl.value;
                lastInR = lastInL;
                ~rightValue.string = formatDbValue.(dbValue);
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
            if(linkFaders) {
                ~leftSlider.value = sl.value;
                lastInL = lastInR;
                ~leftValue.string = formatDbValue.(dbValue);
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

// Mouse up action for CLI commands (MainApp2 functionality)
mainView.mouseDownAction_({
    // Clear focus from all buttons when clicking on main view
    mainView.focus(nil);
});

mainView.mouseUpAction_({
    AppClock.sched(0.05, {
        if(lastFaderGroup == \input) {
            ("phono-control -l " ++ lastInL ++ " -r " ++ lastInR).unixCmd;
        };
        lastFaderGroup = \none;
    });
});

// Source selector buttons with MainApp2's CLI integration
~lineBtn = Button(mainView, Rect(18, 70, 40, 20))
    .states_([["LINE", Color.cyan, Color.black], ["LINE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({ |btn|
        if(btn.value == 1) {
            ~mmBtn.value_(0);
            ~mcBtn.value_(0);
            ("phono-control -c line").unixCmd;
        }
    });

~mmBtn = Button(mainView, Rect(18, 110, 40, 20))
    .states_([["MM", Color.cyan, Color.black], ["MM", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({ |btn|
        if(btn.value == 1) {
            ~lineBtn.value_(0);
            ~mcBtn.value_(0);
            ("phono-control -c mm").unixCmd;
        }
    });

~mcBtn = Button(mainView, Rect(18, 150, 40, 20))
    .states_([["MC", Color.cyan, Color.black], ["MC", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({ |btn|
        if(btn.value == 1) {
            ~lineBtn.value_(0);
            ~mmBtn.value_(0);
            ("phono-control -c mc").unixCmd;
        }
    });

// RESET, MON, MUTE, LINK buttons with MainApp2 functionality
~resetBtn = Button(mainView, Rect(18, 270, 40, 20))
    .states_([["RESET", Color.cyan, Color.black]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({ |btn|
        ("phono-control -d").unixCmd;
        // Reset GUI to match defaults
        AppClock.sched(0.1, {
            // Reset fader values
            lastInL = 112; // 0dB equivalent
            lastInR = 112; // 0dB equivalent
            ~leftSlider.value = (lastInL - minIn) / (maxIn - minIn);
            ~rightSlider.value = (lastInR - minIn) / (maxIn - minIn);
            // Display in dB using logarithmic scaling
            dbValue = cliToDbMaster.(lastInL);
            ~leftValue.string = formatDbValue.(dbValue);
            ~rightValue.string = formatDbValue.(dbValue);

            // Reset button states to defaults
            ~lineBtn.value_(1);  // LINE selected by default
            ~mmBtn.value_(0);
            ~mcBtn.value_(0);
            ~monBtn.value_(0);   // MON off by default
            ~muteBtn.value_(0);  // MUTE off by default
            // Note: LINK button retains its current state
        });
    });
~monBtn = Button(mainView, Rect(18, 310, 40, 20))
    .states_([["MON", Color.cyan, Color.black], ["MON", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({ |btn|
        var cmd = if(btn.value == 1) { "phono-control -M" } { "phono-control -m" };
        cmd.unixCmd;
    });

~muteBtn = Button(mainView, Rect(76, 410, 60, 35))
    .states_([["MUTE", Color.cyan, Color.black], ["MUTE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
    .focusColor_(Color.clear)
    .action_({ |btn|
        if(btn.value == 1) {
            // Muting: remember the last input command
            if(~lineBtn.value == 1) { lastInputCmd = "line"; };
            if(~mmBtn.value == 1)   { lastInputCmd = "mm"; };
            if(~mcBtn.value == 1)   { lastInputCmd = "mc"; };
            "phono-control -c mute".unixCmd;
        } {
            // Unmuting: restore previous input state and fader values
            if(lastInputCmd.notNil) {
                ("phono-control -c " ++ lastInputCmd).unixCmd;
            };
            AppClock.sched(0.3, {
                ("phono-control -l " ++ lastInL ++ " -r " ++ lastInR).unixCmd;
            });
        }
    });

~linkBtn = Button(mainView, Rect(18, 350, 40, 20))
    .states_([["LINK", Color.cyan, Color.black], ["LINK", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .value_(linkFaders.asInteger)
    .action_({ |btn| linkFaders = btn.value == 1; });

// --- ENCODER/DECODER MENUS ---
StaticText(mainView, Rect(188, 10, 140, 28))
    .string_("ENCODER")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

StaticText(mainView, Rect(345, 10, 140, 28))
    .string_("DECODER")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);
// Encoder menu (Input format selection)
~emenu = EZPopUpMenu.new(
    mainView,
    Rect(180, 45, 156, 35),
    "",
                    [
                        \UHJ -> { |a| configKeyE = \uhj; ("Encoder: UHJ").postln; },
                        \SUPERSTEREO -> { |a| configKeyE = \superstereo; ("Encoder: SUPERSTEREO").postln; },
                        \MAPLIN -> { |a| configKeyE = \maplin; ("Encoder: MAPLIN").postln; },
                        \PHJ -> { |a| configKeyE = \phj; ("Encoder: PHJ").postln; }
                    ],
    globalAction: { |menu|
        // Update maplinMode on existing synth if it exists (for Maplin encoder only)
        if(~synth.notNil) {
            ~synth.set(\maplinMode, if(configKeyE == \maplin, 1, 0));
            ("Updated maplinMode to: " ++ if(configKeyE == \maplin, 1, 0)).postln;
        };
        
        if(configKeyE == \maplin) {
            // Ensure Maplin processing is enabled when selecting the encoder
            ~maplinState[\active] = 1;
            ~dimensionActive = 1;
            ~setMaplinActive.(true);
            if(~maplinActiveBtn.notNil) {
                ~maplinActiveBtn.value_(0); // 0 = ON
            };
            if(~synth.notNil) {
                ~synth.set(
                    \maplinSurround, ~maplinState[\surround] ? 0.8,
                    \maplinEffect, ~maplinState[\effect] ? 0.8,
                    \maplinDelay, ~maplinState[\delay] ? 0.4,
                    \maplinActive, 1
                );
                ("Maplin parameters sent to synth: surround=" ++ (~maplinState[\surround] ? 0.8) ++ ", effect=" ++ (~maplinState[\effect] ? 0.8) ++ ", delay=" ++ (~maplinState[\delay] ? 0.4) ++ ", active=1").postln;
            };
        } {
            if(~synth.notNil) {
                ~synth.set(\dimensionActive, ~dimensionActive ? 1);
            };
        };
        
        // Dimension button is now always visible (not encoder-dependent)
        // Dimension controls work with Ambisonic material, so available for all encoders
        ("Selected encoder: " ++ menu.item).postln;
        
        // Update Dimension overlay visibility based on encoder selection
        ~updateDimensionOverlayVisibility.value();
        
        // If Maplin encoder is selected and Dimension overlay is open, ensure Maplin knobs send values
        if(configKeyE == \maplin and: { ~dimensionOverlay.notNil and: { ~maplinSurroundKnob.notNil } }) {
            // Trigger knob actions to send current values to synth
            ~maplinSurroundKnob.action.value(~maplinSurroundKnob);
            ~maplinEffectKnob.action.value(~maplinEffectKnob);
            ~maplinDelayKnob.action.value(~maplinDelayKnob);
            ("Maplin knobs updated for Maplin encoder").postln;
        };
        
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
~emenu.font = Font("LCD 5x7 Segment Monospace", 11);
~emenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);
// Decoder menu (Output format selection)
~dmenu = EZPopUpMenu.new(
    mainView,
    Rect(343, 45, 157, 35),
    "",
    [
        \STEREO -> { |a| inputs = if(configKeyE == \phj, 4, 2); outputs = 2; configKeyD = \stereo; },
        \BINAURAL ++ " IRCAM" -> { |a| inputs = if(configKeyE == \phj, 4, 2); outputs = 2; configKeyD = \binaural; },
        \BINAURAL ++ " CIPIC" -> { |a| inputs = if(configKeyE == \phj, 4, 2); outputs = 2; configKeyD = \binaurac; },
        \QUAD ++ " SQUARE" -> { |a| inputs = if(configKeyE == \phj, 4, 2); outputs = 4; configKeyD = \quadsquare; },
        \QUAD ++ " NARROW" -> { |a| inputs = if(configKeyE == \phj, 4, 2); outputs = 4; configKeyD = \quadnarrow; },
        \QUAD ++" WIDE" -> { |a| inputs = if(configKeyE == \phj, 4, 2); outputs = 4; configKeyD = \quadwide; },
        \DOLBY ++" 5.1" -> { |a| inputs = if(configKeyE == \phj, 4, 2); outputs = 6; configKeyD = \fivezero; },
        \DOLBY ++" 5.1.2" -> { |a| inputs = if(configKeyE == \phj, 4, 2); outputs = 8; configKeyD = \fiveonetwo; },
        \OCTAGON -> { |a| inputs = if(configKeyE == \phj, 4, 2); outputs = 8; configKeyD = \octagon; }
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
        decoderNames = ["STEREO", "BINAURAL IRCAM", "BINAURAL CIPIC", "QUAD SQUARE", "QUAD NARROW", "QUAD WIDE", "DOLBY 5.1", "DOLBY 5.1.2", "OCTAGON"];
        decoderName = decoderNames[idx];
        htIsOff = (~headtrackBtn.notNil and: { ~headtrackBtn.value == 0 });
        isBinaural = (idx == 1) or: { idx == 2 };
        shouldDim = (idx == 3 or: { idx == 4 } or: { idx == 5 } or: { idx == 6 } or: { idx == 7 } or: { idx == 8 });

        // Update Layout overlay title if visible
        if(~layoutOverlay.notNil and: { ~layoutTitleText.notNil }) {
            ~layoutTitleText.string = decoderName;
        };

        // --- Overlay/enable logic for headtracker controls ---
        if(~knobOverlay.notNil) { ~knobOverlay.remove; ~knobOverlay = nil; };
        if(~htBtnOverlay.notNil) { ~htBtnOverlay.remove; ~htBtnOverlay = nil; };
        if(~htResetOverlay.notNil) { ~htResetOverlay.remove; ~htResetOverlay = nil; };
        if(~xyPannerOverlay.notNil) { ~xyPannerOverlay.remove; ~xyPannerOverlay = nil; };

        if(isBinaural) {
            ~headtrackBtn.enabled_(true);
            ~headtrackResetBtn.enabled_(true);
            if(~headtrackPairBtn.notNil) { ~headtrackPairBtn.enabled_(true); };
            if(~htPairOverlay.notNil) { ~htPairOverlay.remove; ~htPairOverlay = nil; };
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
                ~htResetOverlay = View(mainView, Rect(734, 102, 51, 20)) // Cover RESET button, extended 3px right
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
            } {
                ~rotateKnob.enabled_(true);
                ~tiltKnob.enabled_(true);
                ~tumbleKnob.enabled_(true);
            };
        } {
            // Non-binaural modes
            ~headtrackBtn.enabled_(false);
            if(~headtrackPairBtn.notNil) { ~headtrackPairBtn.enabled_(false); };
            ~rotateKnob.enabled_(false);
            ~tiltKnob.enabled_(false);
            ~tumbleKnob.enabled_(false);
            // Dim PAIR button with overlay matching reset/knob overlay style
            if(~htPairOverlay.notNil) { ~htPairOverlay.remove; ~htPairOverlay = nil; };
            ~htPairOverlay = View(mainView, Rect(742, 142, 40, 20))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
            
            if((idx == 3) or: { idx == 4 } or: { idx == 5 }) {
                // Quad modes: reset button visible for panner control
                ~headtrackResetBtn.enabled_(true);
                // Hide knobs and ON/OFF button
                ~knobOverlay = View(mainView, Rect(594, 60, 147, 224)) // width was 145, now 147
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
                ~htBtnOverlay = View(mainView, Rect(734, 60, 51, 42)) // Cover only ON/OFF button (y=60-102), extended 3px right
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
            } {
                // Dolby 5.1/5.1.2/Octagon modes: BOTH buttons hidden (no headtracking, no panner)
                ~headtrackResetBtn.enabled_(false);
                ~htResetOverlay = View(mainView, Rect(734, 102, 51, 20)) // Cover reset button, extended 3px right
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
                // Hide knobs and ON/OFF button
                ~knobOverlay = View(mainView, Rect(594, 60, 147, 224)) // width was 145, now 147
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
                ~htBtnOverlay = View(mainView, Rect(734, 60, 51, 42)) // Cover only ON/OFF button (y=60-102), extended 3px right
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
            };
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

        // --- Update synth with correct state when switching decoders (before recreating overlay) ---
        if(~synth.notNil) {
            var currentState;
            if((idx >= 3) and: { idx <= 5 }, {
                // Quad layouts - use appropriate quad state
                currentState = if(idx == 3, { ~quadSquareState }, {
                    if(idx == 4, { ~quadNarrowState }, { ~quadWideState })
                });
                ~synth.set(
                    \flOn, currentState[\flOn] ? 1,
                    \frOn, currentState[\frOn] ? 1,
                    \rlOn, currentState[\rlOn] ? 1,
                    \rrOn, currentState[\rrOn] ? 1
                );
            }, {
                if((idx == 6) or: { idx == 7 }, {
                    // Dolby layouts - use dolby state
                    ~synth.set(
                        \flOn, ~dolbyState[\flOn] ? 1,
                        \frOn, ~dolbyState[\frOn] ? 1,
                        \rlOn, ~dolbyState[\rlOn] ? 1,
                        \rrOn, ~dolbyState[\rrOn] ? 1
                    );
                }, {
                    if(idx == 8, {
                        // Octagon layout - use octagon state
                        ~synth.set(
                            \s1On, ~octagonState[\s1On] ? 1,
                            \s2On, ~octagonState[\s2On] ? 1,
                            \s3On, ~octagonState[\s3On] ? 1,
                            \s4On, ~octagonState[\s4On] ? 1,
                            \s5On, ~octagonState[\s5On] ? 1,
                            \s6On, ~octagonState[\s6On] ? 1,
                            \s7On, ~octagonState[\s7On] ? 1,
                            \s8On, ~octagonState[\s8On] ? 1
                        );
                    });
                });
            });
        };
        
        // --- Recreate layout overlay controls if open (treat decoder change like reopening layout) ---
        if(~layoutOverlay.notNil and: { ~layoutBtn.notNil and: { ~layoutBtn.value == 1 } }) {
            // Close the layout overlay first (this cleans up controls)
            ~layoutBtn.value_(0);
            ~layoutBtn.doAction;
            // Then reopen it with the new decoder value (this recreates controls for new decoder)
            ~layoutBtn.value_(1);
            ~layoutBtn.doAction;
        };
        // --- Audio engine reinitialization logic (must be last) ---
        if((configKeyD != (~prevConfigKeyD ? configKeyD))
            || (inputs != (~prevInputs ? inputs))
            || (outputs != (~prevOutputs ? outputs))
            || (~binauralIRCAMId != (~prevBinauralIRCAMId ? ~binauralIRCAMId))
            || (~binauralCIPICId != (~prevBinauralCIPICId ? ~binauralCIPICId))) {
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
~prevBinauralIRCAMId = ~binauralIRCAMId;
~prevBinauralCIPICId = ~binauralCIPICId;

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
    needReboot = (inputs != (~prevInputs ? inputs))
        || (outputs != (~prevOutputs ? outputs))
        || (configKeyD != (~prevConfigKeyD ? configKeyD))
        || (configKeyE != (~prevConfigKeyE ? configKeyE))
        || (~binauralIRCAMId != (~prevBinauralIRCAMId ? ~binauralIRCAMId))
        || (~binauralCIPICId != (~prevBinauralCIPICId ? ~binauralCIPICId));
    tryBoot = {
        if(s.serverBooting, {
            ("Server busy (booting), retrying audio engine init...").postln;
            AppClock.sched(0.2, { tryBoot.value });
        }, {
            if(s.serverRunning.not, {
                s.options.memSize = 65536;
                s.options.numOutputBusChannels = outputs;
                s.options.numInputBusChannels = inputs;
                // Set audio device to UHJ aggregate device (macOS)
                s.options.device = "UHJ";
                s.boot;
                cond = Condition.new;
                s.waitForBoot({
                    var dimVals, zsynthVals, dimWidth, dimWidthHPF, dimTrim, zsAmount, zsDelay, zsTrim, zsSource, zsSize, zsDamp, zsMix;
                    
                    // Set audio card volume after server boot
                    ("amixer -c HD set PCM 80%").unixCmd;
                    
                    // Define encoder kernels
                    encoderDict = Dictionary.newFrom([
                        \uhj, FoaEncoderKernel.newUHJ,
                        \superstereo, FoaEncoderKernel.newSuper,
                        \maplin, FoaEncoderMatrix.newDirections([-45, 45, -135, 135].degrad),  // MaplinMatrix quad encoder
                        \phj, FoaEncoderKernel.newPHJ,  // PHJ encoder - kernel-based
                    ]);

                    // Define decoder kernels (matching MainApp2 exactly, excluding unused \none)
                    decoderDict = Dictionary.newFrom([
                        \binaural, FoaDecoderKernel.newListen(~binauralIRCAMId),
                        \binaurac, FoaDecoderKernel.newCIPIC(~binauralCIPICId),
                        \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                        \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                        \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual'),
                        \fivezero, FoaDecoderMatrix.new5_0(irregKind: 'focused'),
                        \octagon, FoaDecoderMatrix.newPanto(8, 'flat', k: 'single'),
                        \stereo, FoaDecoderMatrix.newStereo,
                        \fiveonetwo, FoaDecoderMatrix.new5_0_2(\equal)  // 5.1.2 decoder (outputs in ATK order, routed to UHJ-Pi layout in app)
                    ]);

                    // Get selected encoder and decoder
                    encoder = encoderDict.at(configKeyE ? \uhj);
                    decoder = decoderDict.at(configKeyD ? \stereo);

                    ("Audio engine initialized with encoder: " ++ configKeyE ++ " and decoder: " ++ configKeyD).postln;

                    // Load test audio file (same as MainApp2)
                    // sndbuf = Buffer.read(s, Atk.userSoundsDir ++ "/uhj/Sodium_Sunrise_UHJ.wav");
                    
                    // Load spatial impulse responses for pseudo-surround convolution
                    // These would be B-format impulse responses for realistic spatialization
                    ~spatialIRs = Array.fill(4, { |i|
                        // Placeholder for spatial IR loading
                        // In a full implementation, these would be loaded from files
                        Buffer.alloc(s, 2048, 1); // Temporary buffer
                    });
                    s.sync(cond);
                    // Define the main audio processing SynthDef (adapted from MainApp2)
                        SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, quadLR = 0, quadFR = 0, ambience = 0, preDelay = 0, lowRT = 0.2, highRT = 2, dispersion = 1, modWidth = 0.2, modRate = 0.3, eq1 = 0, eq2 = 0, eq3 = 0, eq4 = 0, eq5 = 0, eq6 = 0, eq7 = 0, maplinSurround = 0.8, maplinEffect = 0.8, maplinDelay = 0.4, maplinActive = 1, maplinMode = 0, dimensionWidth = 0.0, dimensionWidthHPF = 180, dimensionLFGain = 0, dimensionHFGain = 0, dimensionOutputTrim = 0, dimensionShelvesMode = 0, dimensionGerzonPresets = 0, dimensionActive = 1, zsynthHeightAmount = 30, zsynthHeightDelay = 7, zsynthHeightTrim = 0, zsynthHeightSource = 0, zsynthAmbienceSize = 2.5, zsynthAmbienceDampening = 0.2, zsynthAmbienceMix = 70, reverbTarget = 1, centerGain = 0, subGain = 0, heightGain = 0, flOn = 1, frOn = 1, rlOn = 1, rrOn = 1, centerOn = 1, subOn = 1, tflOn = 1, tfrOn = 1, subLPF = 120, topHPF = 180, s1On = 1, s2On = 1, s3On = 1, s4On = 1, s5On = 1, s6On = 1, s7On = 1, s8On = 1, lOn = 1, rOn = 1|
                        var out, src, trans, encode, dimensioned, zsynth, ambient, eqed, frontStereo, rearStereo, quadOutFront, quadOutRear, maplinQuad, encodeInput;
                        var wetSrcW, wetSrcX, wetSrcY, wetSrcZ, wetSrc, wetOnly, rtAr, zeroA;
                        // Audio source - live input from hardware
                        src = SoundIn.ar([0,1]);
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
                        eqed = BPeakEQ.ar(eqed, 6400, 1, eq6);     // Band 6
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
                        
                        // Dimension processing (Forward Preference + Psychoacoustic Shelves)
                        // shelvesMode=0 (off), gerzonPresets=0 (off) - handled in decoders if needed
                        // Bypass Dimension if dimensionActive is 0
                        dimensioned = if(dimensionActive > 0,
                            FoaDimension.ar(encode,
                                width: dimensionWidth,
                                widthHPF: dimensionWidthHPF,  // Control rate parameter
                                lfGain: dimensionLFGain,
                                hfGain: dimensionHFGain,
                                outputTrim: dimensionOutputTrim,
                                shelvesMode: dimensionShelvesMode,  // Control rate parameter (default 0)
                                gerzonPresets: dimensionGerzonPresets  // Control rate parameter (default 0)
                            ),
                            encode  // Bypass: pass through unchanged
                        );
                        
                        // Z Synthesis processing (synthesize Z from X/Y with decorrelation and ambience)
                        zsynth = FoaZSynthesis.ar(dimensioned,
                            heightAmount: zsynthHeightAmount,
                            heightDelay: zsynthHeightDelay,
                            heightTrim: zsynthHeightTrim,
                            heightSource: zsynthHeightSource,
                            ambienceSize: zsynthAmbienceSize,
                            ambienceDampening: zsynthAmbienceDampening,
                            ambienceMix: zsynthAmbienceMix
                        );
                        
                        // Ambience processing (AmbiVerbSC reverb) with routing target
                        // Build routed wet source per channel: 0=Lower(WXY), 1=All(WXYZ), 2=Height(Z)
                        rtAr = reverbTarget + DC.ar(0); // ensure audio-rate selector
                        zeroA = DC.ar(0);
                        wetSrcW = Select.ar(rtAr, [zsynth[0], zsynth[0], zeroA]);
                        wetSrcX = Select.ar(rtAr, [zsynth[1], zsynth[1], zeroA]);
                        wetSrcY = Select.ar(rtAr, [zsynth[2], zsynth[2], zeroA]);
                        wetSrcZ = Select.ar(rtAr, [zeroA,      zsynth[3], zsynth[3]]);
                        wetSrc = [wetSrcW, wetSrcX, wetSrcY, wetSrcZ];
                        // Compute wet component by subtracting input (to avoid double-dry)
                        wetOnly = AmbiVerbSC.ar(wetSrc,
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
                        ) - wetSrc;
                        // If HEIGHT is OFF (zsynthHeightSource == 0), suppress any wet Z contribution
                        wetOnly = [wetOnly[0], wetOnly[1], wetOnly[2], wetOnly[3] * (zsynthHeightSource > 0)];
                        ambient = zsynth + wetOnly;
                        // Spatial transformations (rotation, tilt, tumble) temporarily disabled
                        trans = ambient; // bypass FoaRTT
                        // Decode using selected decoder
                        out = FoaDecode.ar(trans, decoder);
                        if(outputs == 2, {
                            out = [
                                out[0] * lOn,
                                out[1] * rOn
                            ];
                        });
                        if(outputs == 4, {
                            // --- Q-PANNER LOGIC (Balance2) ---
                            // out[0]=LF, out[1]=FR, out[2]=RL, out[3]=RR
                            frontStereo = Balance2.ar(out[0], out[3], quadLR); // LF, FR
                            rearStereo  = Balance2.ar(out[1], out[2], quadLR); // RL, RR
                            quadOutFront = frontStereo * ((quadFR + 1) * 0.5); // scale front by 0..1
                            quadOutRear  = rearStereo  * ((1 - quadFR) * 0.5); // scale rear by 1..0
                            out = [
                                quadOutFront[0] * flOn, // LF (Speaker 1)
                                quadOutFront[1] * frOn, // FR (Speaker 2)
                                quadOutRear[0]  * rlOn, // RL (Speaker 3)
                                quadOutRear[1]  * rrOn  // RR (Speaker 4)
                            ];
                        });
                        if(outputs == 6, {
                            // --- UHJ-PI 5.1 OUTPUT MAPPING ---
                            // ATK 5.0 decoder: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR
                            // UHJ-Pi layout: [0] FL, [1] FR, [2] RL, [3] RR, [4] C, [5] SUB
                            // This aligns with Quad (1-4) and adds C and SUB
                            var lowpass = BLowPass.ar((out[1] + out[4]), subLPF, 1, 0.4); // Sum FL + FR for sub
                            var centerChan = out[0] * centerGain.dbamp * centerOn;
                            var subChan = lowpass * subGain.dbamp * subOn;
                            out = [
                                out[1] * flOn, // FL (Speaker 1) - Front Left
                                out[4] * frOn, // FR (Speaker 2) - Front Right
                                out[2] * rlOn, // RL (Speaker 3) - Rear Left
                                out[3] * rrOn, // RR (Speaker 4) - Rear Right
                                centerChan * centerOn, // C  (Speaker 5) - Center
                                subChan * subOn // SUB (Speaker 6) - Subwoofer
                            ];
                        });
                        
                        if(outputs == 8, {
                            if(configKeyD == \fiveonetwo, {
                                // --- UHJ-PI 5.1.2 OUTPUT MAPPING ---
                                // Decoder outputs: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR, out[5]=TFR, out[6]=TFL
                                // UHJ-Pi layout: [0] FL, [1] FR, [2] RL, [3] RR, [4] C, [5] SUB, [6] TFL, [7] TFR
                                // This aligns with Quad (1-4) and 5.1 (1-5), then adds height channels
                                var lowpass = BLowPass.ar((out[1] + out[4]), subLPF, 1, 0.4); // Sum FL + FR for LFE/SUB
                                var centerChan = out[0] * centerGain.dbamp * centerOn;
                                var subChan = lowpass * subGain.dbamp * subOn;
                                var heightTFL = HPF.ar(out[6], topHPF) * heightGain.dbamp * tflOn;
                                var heightTFR = HPF.ar(out[5], topHPF) * heightGain.dbamp * tfrOn;
                                out = [
                                    out[1] * flOn, // FL (Speaker 1) - Front Left
                                    out[4] * frOn, // FR (Speaker 2) - Front Right
                                    out[2] * rlOn, // RL (Speaker 3) - Rear Left
                                    out[3] * rrOn, // RR (Speaker 4) - Rear Right
                                    centerChan * centerOn, // C  (Speaker 5) - Center
                                    subChan * subOn, // SUB (Speaker 6) - Subwoofer/LFE
                                    heightTFL * tflOn, // TFL (Speaker 7) - Top Front Left
                                    heightTFR * tfrOn  // TFR (Speaker 8) - Top Front Right
                                ];
                            }, {
                                // --- OCTAGON OUTPUT MAPPING (Clockwise from Front Left) ---
                                // ATK 8.0 decoder: Anti-clockwise from front left out[0]
                                // Map to diagram: Clockwise from front left starting at Speaker 1
                                out = [
                                    out[0] * s1On, // Speaker 1: Front Left (FL)
                                    out[7] * s2On, // Speaker 2: Front Left Center (FLC)
                                    out[6] * s3On, // Speaker 3: Center (C)
                                    out[5] * s4On, // Speaker 4: Front Right Center (FRC)
                                    out[4] * s5On, // Speaker 5: Front Right (FR)
                                    out[3] * s6On, // Speaker 6: Rear Right Center (RRC)
                                    out[2] * s7On, // Speaker 7: Rear Right (RR)
                                    out[1] * s8On  // Speaker 8: Rear Left Center (RLC)
                                ];
                            });
                        });
                        
                        // Output routing for all modes
                        Out.ar(0, out);
                    }).add;

                    s.sync(cond);

                    // Start the synth
                    // Convert normalized state values to actual parameter ranges
                    dimVals = ~dimensionState[\sliderValues] ? [0.0, 0.5, 0.5];
                    // Legacy support: if old format with 2 values, add default widthHPF
                    if(dimVals.size == 2) {
                        dimVals = dimVals ++ [0.5]; // Add default widthHPF (180Hz = 0.5 normalized)
                    };
                    zsynthVals = ~zsynthState[\sliderValues] ? [0.3, 0.07, 0.5, 0.0, 0.625, 0.2, 0.7];
                    dimWidth = dimVals[0] * 0.70;
                    dimWidthHPF = dimVals[1].linlin(0, 1, 80, 400); // Convert normalized 0-1 to 80-400 Hz
                    dimTrim = dimVals[2].linlin(0, 1, -6, 6);  // Reduced from -18/+18 to -6/+6 dB
                    // LF/HF removed (shelves disabled)
                    zsAmount = zsynthVals[0] * 100;
                    zsDelay = zsynthVals[1].linlin(0, 1, 0, 30);
                    zsTrim = zsynthVals[2].linlin(0, 1, -12, 12);
                    zsSource = if(zsynthVals[3] < 0.5, 0, 1);
                    zsSize = zsynthVals[4].linlin(0, 1, 0.1, 3.0);
                    zsDamp = zsynthVals[5];
                    zsMix = zsynthVals[6] * 100;
                    
                    ~synth = Synth(\kernelEncodeDecode, [\buffer, sndbuf, \amp, voltmp, 
                        \maplinSurround, ~maplinState[\surround] ? 0.8, 
                        \maplinEffect, ~maplinState[\effect] ? 0.8,
                        \maplinDelay, ~maplinState[\delay] ? 0.4, 
                        \maplinActive, ~maplinState[\active] ? 1,  // 1 = active, 0 = bypass
                        \maplinMode, if(configKeyE == \maplin, 1, 0),
                        // Dimension parameters
                        \dimensionWidth, dimWidth,
                        \dimensionWidthHPF, dimWidthHPF,  // Width HPF (80-400 Hz)
                        \dimensionLFGain, 0,  // Not used (shelves disabled)
                        \dimensionHFGain, 0,  // Not used (shelves disabled)
                        \dimensionOutputTrim, dimTrim,
                        \dimensionShelvesMode, 0,  // Off - handled in decoders
                        \dimensionGerzonPresets, 0,  // Off - handled in decoders
                        \dimensionActive, ~dimensionActive ? 1,  // Active/bypass (default ON)
                        // ZSynth parameters
                        \zsynthHeightAmount, zsAmount,
                        \zsynthHeightDelay, zsDelay,
                        \zsynthHeightTrim, zsTrim,
                        \zsynthHeightSource, zsSource,
                        \zsynthAmbienceSize, zsSize,
                        \zsynthAmbienceDampening, zsDamp,
                        \zsynthAmbienceMix, zsMix,
                        // Dolby/Quad control parameters - use appropriate state based on decoder
                        \centerGain, ~dolbyState[\centerGain] ? 0.0,
                        \subGain, ~dolbyState[\subGain] ? 0.0,
                        \heightGain, ~dolbyState[\heightGain] ? 0.0,
                        \flOn, if((~dmenu.value >= 3) and: { ~dmenu.value <= 5 }, {
                            if(~dmenu.value == 3, { ~quadSquareState[\flOn] ? 1 }, {
                                if(~dmenu.value == 4, { ~quadNarrowState[\flOn] ? 1 }, { ~quadWideState[\flOn] ? 1 })
                            })
                        }, { ~dolbyState[\flOn] ? 1 }),
                        \frOn, if((~dmenu.value >= 3) and: { ~dmenu.value <= 5 }, {
                            if(~dmenu.value == 3, { ~quadSquareState[\frOn] ? 1 }, {
                                if(~dmenu.value == 4, { ~quadNarrowState[\frOn] ? 1 }, { ~quadWideState[\frOn] ? 1 })
                            })
                        }, { ~dolbyState[\frOn] ? 1 }),
                        \rlOn, if((~dmenu.value >= 3) and: { ~dmenu.value <= 5 }, {
                            if(~dmenu.value == 3, { ~quadSquareState[\rlOn] ? 1 }, {
                                if(~dmenu.value == 4, { ~quadNarrowState[\rlOn] ? 1 }, { ~quadWideState[\rlOn] ? 1 })
                            })
                        }, { ~dolbyState[\rlOn] ? 1 }),
                        \rrOn, if((~dmenu.value >= 3) and: { ~dmenu.value <= 5 }, {
                            if(~dmenu.value == 3, { ~quadSquareState[\rrOn] ? 1 }, {
                                if(~dmenu.value == 4, { ~quadNarrowState[\rrOn] ? 1 }, { ~quadWideState[\rrOn] ? 1 })
                            })
                        }, { ~dolbyState[\rrOn] ? 1 }),
                        \centerOn, ~dolbyState[\centerOn] ? 1,
                        \subOn, ~dolbyState[\subOn] ? 1,
                        \tflOn, ~dolbyState[\tflOn] ? 1,
                        \tfrOn, ~dolbyState[\tfrOn] ? 1,
                        \subLPF, 120,
                        \topHPF, 180,
                        // Octagon speaker mutes
                        \s1On, ~octagonState[\s1On] ? 1,
                        \s2On, ~octagonState[\s2On] ? 1,
                        \s3On, ~octagonState[\s3On] ? 1,
                        \s4On, ~octagonState[\s4On] ? 1,
                        \s5On, ~octagonState[\s5On] ? 1,
                        \s6On, ~octagonState[\s6On] ? 1,
                        \s7On, ~octagonState[\s7On] ? 1,
                        \s8On, ~octagonState[\s8On] ? 1,
                        \lOn, if((configKeyD == \binaural) or: { configKeyD == \binaurac }, { ~binauralState[\lOn] ? 1 }, { ~stereoState[\lOn] ? 1 }),
                        \rOn, if((configKeyD == \binaural) or: { configKeyD == \binaurac }, { ~binauralState[\rOn] ? 1 }, { ~stereoState[\rOn] ? 1 })
                    ]);
                    // Restore saved parameters to new synth
                    ~restoreSynthParams.value();

                    // Create level meter after synth is started
                    {
                        ~meter.remove; // Remove any existing meter
                        ~meter = ServerMeter2View.new(s, ~meterContainer, 0@0, inputs, outputs);
                        // --- Permanent row of 8 numbers below the meters, aligned with meter bars ---
                        ~meterNumbers = Array.fill(8, { |i|
                            var labelWidth = 24;
                            var x = 96 + ((i + 0.5) * (180 / 8)) - (labelWidth / 2); // x=95+1, move 1px right
                            StaticText(~meterContainer, Rect(x, 206, labelWidth, 16)) // y=206 (move up 4px)
                                .background_(Color.black)
                                .font_(Font("Helvetica", 9).boldVariant)
                                .align_(\center)
                                .stringColor_(Color.cyan)
                                .string_((i+1).asString);
                        });
                    }.defer(0.1);

                    ("Audio synthesis started with level meter").postln;
                });
            }, {
                if(needReboot, {
                    s.options.memSize = 65536;
                    s.options.numOutputBusChannels = outputs;
                    s.options.numInputBusChannels = inputs;
                    // Set audio device to UHJ aggregate device (macOS)
                    s.options.device = "UHJ";
                    s.reboot;
                    cond = Condition.new;
                    s.waitForBoot({
                var dimVals2, zsynthVals2, dimWidth2, dimWidthHPF2, dimTrim2, zsAmount2, zsDelay2, zsTrim2, zsSource2, zsSize2, zsDamp2, zsMix2;
                        // Set audio card volume after server reboot
                        ("amixer -c HD set PCM 80%").unixCmd;
                        
                        // Define encoder kernels
                        encoderDict = Dictionary.newFrom([
                            \uhj, FoaEncoderKernel.newUHJ,
                            \superstereo, FoaEncoderKernel.newSuper,
                            \maplin, FoaEncoderMatrix.newDirections([-45, 45, -135, 135].degrad),  // MaplinMatrix quad encoder
                            \phj, FoaEncoderKernel.newPHJ,  // PHJ encoder - kernel-based
                        ]);

                        // Define decoder kernels (matching MainApp2 exactly, excluding unused \none)
                        decoderDict = Dictionary.newFrom([
                            \binaural, FoaDecoderKernel.newListen(~binauralIRCAMId),
                            \binaurac, FoaDecoderKernel.newCIPIC(~binauralCIPICId),
                            \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                            \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                            \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual'),
                            \fivezero, FoaDecoderMatrix.new5_0(irregKind: 'focused'),
                            \octagon, FoaDecoderMatrix.newPanto(8, 'flat', k: 'single'),
                            \stereo, FoaDecoderMatrix.newStereo,
                            \fiveonetwo, FoaDecoderMatrix.new5_0_2(\equal)  // 5.1.2 decoder (outputs in ATK order, routed to UHJ-Pi layout in app)
                        ]);

                        // Get selected encoder and decoder
                        encoder = encoderDict.at(configKeyE ? \uhj);
                        decoder = decoderDict.at(configKeyD ? \stereo);

                        ("Audio engine initialized with encoder: " ++ configKeyE ++ " and decoder: " ++ configKeyD).postln;

                        // Load test audio file (same as MainApp2)
                        // sndbuf = Buffer.read(s, Atk.userSoundsDir ++ "/uhj/Sodium_Sunrise_UHJ.wav");

                        s.sync(cond);

                        // Define the main audio processing SynthDef (adapted from MainApp2)
                        SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, quadLR = 0, quadFR = 0, ambience = 0, preDelay = 0, lowRT = 0.2, highRT = 2, dispersion = 1, modWidth = 0.2, modRate = 0.3, eq1 = 0, eq2 = 0, eq3 = 0, eq4 = 0, eq5 = 0, eq6 = 0, eq7 = 0, maplinSurround = 0.8, maplinEffect = 0.8, maplinDelay = 0.4, maplinActive = 1, maplinMode = 0, dimensionWidth = 0.0, dimensionWidthHPF = 180, dimensionLFGain = 0, dimensionHFGain = 0, dimensionOutputTrim = 0, dimensionShelvesMode = 0, dimensionGerzonPresets = 0, dimensionActive = 1, zsynthHeightAmount = 30, zsynthHeightDelay = 7, zsynthHeightTrim = 0, zsynthHeightSource = 0, zsynthAmbienceSize = 2.5, zsynthAmbienceDampening = 0.2, zsynthAmbienceMix = 70, reverbTarget = 1, centerGain = 0, subGain = 0, heightGain = 0, flOn = 1, frOn = 1, rlOn = 1, rrOn = 1, centerOn = 1, subOn = 1, tflOn = 1, tfrOn = 1, subLPF = 120, topHPF = 180, s1On = 1, s2On = 1, s3On = 1, s4On = 1, s5On = 1, s6On = 1, s7On = 1, s8On = 1, lOn = 1, rOn = 1|
                            var out, src, trans, encode, dimensioned, zsynth, ambient, eqed, frontStereo, rearStereo, quadOutFront, quadOutRear, maplinQuad, encodeInput;
                            var wetSrcW2, wetSrcX2, wetSrcY2, wetSrcZ2, wetSrc2, wetOnly2, rtAr2, zeroA2;
                            // Audio source - live input from hardware
                            src = SoundIn.ar([0,1]);
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
                            
                            // Dimension processing (Forward Preference + Psychoacoustic Shelves)
                            // shelvesMode=0 (off), gerzonPresets=0 (off) - handled in decoders if needed
                            // Bypass Dimension if dimensionActive is 0
                            dimensioned = if(dimensionActive > 0,
                                FoaDimension.ar(encode,
                                    width: dimensionWidth,
                                    widthHPF: dimensionWidthHPF,  // Control rate parameter
                                    lfGain: dimensionLFGain,
                                    hfGain: dimensionHFGain,
                                    outputTrim: dimensionOutputTrim,
                                    shelvesMode: dimensionShelvesMode,  // Control rate parameter (default 0)
                                    gerzonPresets: dimensionGerzonPresets  // Control rate parameter (default 0)
                                ),
                                encode  // Bypass: pass through unchanged
                            );
                            
                            // Z Synthesis processing (synthesize Z from X/Y with decorrelation and ambience)
                            zsynth = FoaZSynthesis.ar(dimensioned,
                                heightAmount: zsynthHeightAmount,
                                heightDelay: zsynthHeightDelay,
                                heightTrim: zsynthHeightTrim,
                                heightSource: zsynthHeightSource,
                                ambienceSize: zsynthAmbienceSize,
                                ambienceDampening: zsynthAmbienceDampening,
                                ambienceMix: zsynthAmbienceMix
                            );
                            
                            // Ambience processing (AmbiVerbSC reverb) with routing target
                            rtAr2 = reverbTarget + DC.ar(0);
                            zeroA2 = DC.ar(0);
                            wetSrcW2 = Select.ar(rtAr2, [zsynth[0], zsynth[0], zeroA2]);
                            wetSrcX2 = Select.ar(rtAr2, [zsynth[1], zsynth[1], zeroA2]);
                            wetSrcY2 = Select.ar(rtAr2, [zsynth[2], zsynth[2], zeroA2]);
                            wetSrcZ2 = Select.ar(rtAr2, [zeroA2,      zsynth[3], zsynth[3]]);
                            wetSrc2 = [wetSrcW2, wetSrcX2, wetSrcY2, wetSrcZ2];
                            wetOnly2 = AmbiVerbSC.ar(wetSrc2,
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
                            ) - wetSrc2;
                            // Suppress wet Z when HEIGHT is OFF
                            wetOnly2 = [wetOnly2[0], wetOnly2[1], wetOnly2[2], wetOnly2[3] * (zsynthHeightSource > 0)];
                            ambient = zsynth + wetOnly2;
                            // Spatial transformations (rotation, tilt, tumble) temporarily disabled
                            trans = ambient; // bypass FoaRTT
                            // Decode using selected decoder
                            out = FoaDecode.ar(trans, decoder);
                            if(outputs == 2, {
                                out = [
                                    out[0] * lOn,
                                    out[1] * rOn
                                ];
                            });
                            if(outputs == 4, {
                                // --- Q-PANNER LOGIC (Balance2) ---
                                // out[0]=LF, out[1]=FR, out[2]=RL, out[3]=RR
                                frontStereo = Balance2.ar(out[0], out[3], quadLR); // LF, FR
                                rearStereo  = Balance2.ar(out[1], out[2], quadLR); // RL, RR
                                quadOutFront = frontStereo * ((quadFR + 1) * 0.5); // scale front by 0..1
                                quadOutRear  = rearStereo  * ((1 - quadFR) * 0.5); // scale rear by 1..0
                                out = [
                                quadOutFront[0] * flOn, // LF (Speaker 1)
                                quadOutFront[1] * frOn, // FR (Speaker 2)
                                quadOutRear[0]  * rlOn, // RL (Speaker 3)
                                quadOutRear[1]  * rrOn  // RR (Speaker 4)
                                ];
                            });
                            if(outputs == 6, {
                                // --- UHJ-PI 5.1 OUTPUT MAPPING ---
                                // ATK 5.0 decoder: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR
                                // UHJ-Pi layout: [0] FL, [1] FR, [2] RL, [3] RR, [4] C, [5] SUB
                                // This aligns with Quad (1-4) and adds C and SUB
                                var lowpass = BLowPass.ar((out[1] + out[4]), subLPF, 1, 0.4); // Sum FL + FR for sub
                                var centerChan = out[0] * centerGain.dbamp * centerOn;
                                var subChan = lowpass * subGain.dbamp * subOn;
                                out = [
                                    out[1] * flOn, // FL (Speaker 1) - Front Left
                                    out[4] * frOn, // FR (Speaker 2) - Front Right
                                    out[2] * rlOn, // RL (Speaker 3) - Rear Left
                                    out[3] * rrOn, // RR (Speaker 4) - Rear Right
                                    centerChan * centerOn, // C  (Speaker 5) - Center
                                    subChan * subOn // SUB (Speaker 6) - Subwoofer
                                ];
                            });
                            if(outputs == 8, {
                                if(configKeyD == \fiveonetwo, {
                                // --- UHJ-PI 5.1.2 OUTPUT MAPPING ---
                                // Decoder outputs: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR, out[5]=TFR, out[6]=TFL
                                // UHJ-Pi layout: [0] FL, [1] FR, [2] RL, [3] RR, [4] C, [5] SUB, [6] TFL, [7] TFR
                                // This aligns with Quad (1-4) and 5.1 (1-5), then adds height channels
                                    var lowpass = BLowPass.ar((out[1] + out[4]), subLPF, 1, 0.4); // Sum FL + FR for LFE/SUB
                                    var centerChan = out[0] * centerGain.dbamp * centerOn;
                                    var subChan = lowpass * subGain.dbamp * subOn;
                                    var heightTFL = HPF.ar(out[6], topHPF) * heightGain.dbamp * tflOn;
                                    var heightTFR = HPF.ar(out[5], topHPF) * heightGain.dbamp * tfrOn;
                                    out = [
                                        out[1] * flOn, // FL (Speaker 1) - Front Left
                                        out[4] * frOn, // FR (Speaker 2) - Front Right
                                        out[2] * rlOn, // RL (Speaker 3) - Rear Left
                                        out[3] * rrOn, // RR (Speaker 4) - Rear Right
                                        centerChan * centerOn, // C  (Speaker 5) - Center
                                        subChan * subOn, // SUB (Speaker 6) - Subwoofer/LFE
                                        heightTFL * tflOn, // TFL (Speaker 7) - Top Front Left
                                        heightTFR * tfrOn  // TFR (Speaker 8) - Top Front Right
                                    ];
                                }, {
                                    // --- OCTAGON OUTPUT MAPPING (Clockwise from Front Left) ---
                                    // ATK 8.0 decoder: Anti-clockwise from front left out[0]
                                    // Map to diagram: Clockwise from front left starting at Speaker 1
                                    out = [
                                        out[0] * s1On, // Speaker 1: Front Left (FL)
                                        out[7] * s2On, // Speaker 2: Front Left Center (FLC)
                                        out[6] * s3On, // Speaker 3: Center (C)
                                        out[5] * s4On, // Speaker 4: Front Right Center (FRC)
                                        out[4] * s5On, // Speaker 5: Front Right (FR)
                                        out[3] * s6On, // Speaker 6: Rear Right Center (RRC)
                                        out[2] * s7On, // Speaker 7: Rear Right (RR)
                                        out[1] * s8On  // Speaker 8: Rear Left Center (RLC)
                                    ];
                                });
                            });
                            
                            // Output routing for all modes
                            Out.ar(0, out);
                        }).add;
                        s.sync(cond);
                        // Start the synth
                        // Convert normalized state values to actual parameter ranges
                        dimVals2 = ~dimensionState[\sliderValues] ? [0.0, 0.5, 0.5];
                        // Legacy support: handle old formats
                        if(dimVals2.size == 2) {
                            // Old format: [width, outputTrim] - add default widthHPF
                            dimVals2 = [dimVals2[0], 0.5, dimVals2[1]]; // width, default widthHPF, outputTrim
                        } {
                            if(dimVals2.size >= 4) {
                                // Very old format: [width, lfGain, hfGain, outputTrim] - use first and last, add widthHPF
                                dimVals2 = [dimVals2[0], 0.5, dimVals2[3]]; // width, default widthHPF, outputTrim
                            };
                        };
                        zsynthVals2 = ~zsynthState[\sliderValues] ? [0.3, 0.07, 0.5, 0.0, 0.625, 0.2, 0.7];
                        dimWidth2 = dimVals2[0] * 0.70;
                        dimWidthHPF2 = dimVals2[1].linlin(0, 1, 80, 400); // Convert normalized 0-1 to 80-400 Hz
                        dimTrim2 = dimVals2[2].linlin(0, 1, -6, 6);  // Reduced from -18/+18 to -6/+6 dB
                        // LF/HF removed (shelves disabled)
                        zsAmount2 = zsynthVals2[0] * 100;
                        zsDelay2 = zsynthVals2[1].linlin(0, 1, 0, 30);
                        zsTrim2 = zsynthVals2[2].linlin(0, 1, -12, 12);
                        zsSource2 = if(zsynthVals2[3] < 0.5, 0, 1);
                        zsSize2 = zsynthVals2[4].linlin(0, 1, 0.1, 3.0);
                        zsDamp2 = zsynthVals2[5];
                        zsMix2 = zsynthVals2[6] * 100;
                        
                        ~synth = Synth(\kernelEncodeDecode, [\buffer, sndbuf, \amp, voltmp, 
                            \maplinSurround, ~maplinState[\surround] ? 0.8, 
                            \maplinEffect, ~maplinState[\effect] ? 0.8,
                            \maplinDelay, ~maplinState[\delay] ? 0.4, 
                            \maplinActive, ~maplinActive ? 1,  // 1 = active, 0 = bypass
                            \maplinMode, if(configKeyE == \maplin, 1, 0),
                            // Dimension parameters
                            \dimensionWidth, dimWidth2,
                            \dimensionWidthHPF, dimWidthHPF2,  // Width HPF (80-400 Hz)
                            \dimensionLFGain, 0,  // Not used (shelves disabled)
                            \dimensionHFGain, 0,  // Not used (shelves disabled)
                            \dimensionOutputTrim, dimTrim2,
                            \dimensionShelvesMode, 0,  // Off - handled in decoders
                            \dimensionGerzonPresets, 0,  // Off - handled in decoders
                            \dimensionActive, ~dimensionActive ? 1,  // Active/bypass (default ON)
                            // ZSynth parameters
                            \zsynthHeightAmount, zsAmount2,
                            \zsynthHeightDelay, zsDelay2,
                            \zsynthHeightTrim, zsTrim2,
                            \zsynthHeightSource, zsSource2,
                            \zsynthAmbienceSize, zsSize2,
                            \zsynthAmbienceDampening, zsDamp2,
                            \zsynthAmbienceMix, zsMix2,
                            // Dolby/Quad control parameters - use appropriate state based on decoder
                            \centerGain, ~dolbyState[\centerGain] ? 0.0,
                            \subGain, ~dolbyState[\subGain] ? 0.0,
                            \heightGain, ~dolbyState[\heightGain] ? 0.0,
                            \flOn, if((~dmenu.value >= 3) and: { ~dmenu.value <= 5 }, {
                                if(~dmenu.value == 3, { ~quadSquareState[\flOn] ? 1 }, {
                                    if(~dmenu.value == 4, { ~quadNarrowState[\flOn] ? 1 }, { ~quadWideState[\flOn] ? 1 })
                                })
                            }, { ~dolbyState[\flOn] ? 1 }),
                            \frOn, if((~dmenu.value >= 3) and: { ~dmenu.value <= 5 }, {
                                if(~dmenu.value == 3, { ~quadSquareState[\frOn] ? 1 }, {
                                    if(~dmenu.value == 4, { ~quadNarrowState[\frOn] ? 1 }, { ~quadWideState[\frOn] ? 1 })
                                })
                            }, { ~dolbyState[\frOn] ? 1 }),
                            \rlOn, if((~dmenu.value >= 3) and: { ~dmenu.value <= 5 }, {
                                if(~dmenu.value == 3, { ~quadSquareState[\rlOn] ? 1 }, {
                                    if(~dmenu.value == 4, { ~quadNarrowState[\rlOn] ? 1 }, { ~quadWideState[\rlOn] ? 1 })
                                })
                            }, { ~dolbyState[\rlOn] ? 1 }),
                            \rrOn, if((~dmenu.value >= 3) and: { ~dmenu.value <= 5 }, {
                                if(~dmenu.value == 3, { ~quadSquareState[\rrOn] ? 1 }, {
                                    if(~dmenu.value == 4, { ~quadNarrowState[\rrOn] ? 1 }, { ~quadWideState[\rrOn] ? 1 })
                                })
                            }, { ~dolbyState[\rrOn] ? 1 }),
                            \centerOn, ~dolbyState[\centerOn] ? 1,
                            \subOn, ~dolbyState[\subOn] ? 1,
                            \tflOn, ~dolbyState[\tflOn] ? 1,
                            \tfrOn, ~dolbyState[\tfrOn] ? 1,
                            \subLPF, 120,
                            \topHPF, 180,
                            \s1On, ~octagonState[\s1On] ? 1,
                            \s2On, ~octagonState[\s2On] ? 1,
                            \s3On, ~octagonState[\s3On] ? 1,
                            \s4On, ~octagonState[\s4On] ? 1,
                            \s5On, ~octagonState[\s5On] ? 1,
                            \s6On, ~octagonState[\s6On] ? 1,
                            \s7On, ~octagonState[\s7On] ? 1,
                            \s8On, ~octagonState[\s8On] ? 1,
                            \lOn, if((configKeyD == \binaural) or: { configKeyD == \binaurac }, { ~binauralState[\lOn] ? 1 }, { ~stereoState[\lOn] ? 1 }),
                            \rOn, if((configKeyD == \binaural) or: { configKeyD == \binaurac }, { ~binauralState[\rOn] ? 1 }, { ~stereoState[\rOn] ? 1 })
                        ]);
                        
                        // Restore saved parameters to new synth
                        ~restoreSynthParams.value();

                        // Create level meter after synth is started
                        {
                            ~meter.remove; // Remove any existing meter
                            ~meter = ServerMeter2View.new(s, ~meterContainer, 0@0, inputs, outputs);
                            // --- Permanent row of 8 numbers below the meters, aligned with meter bars ---
                            ~meterNumbers = Array.fill(8, { |i|
                                var labelWidth = 24;
                                var x = 96 + ((i + 0.5) * (180 / 8)) - (labelWidth / 2); // x=95+1, move 1px right
                                StaticText(~meterContainer, Rect(x, 206, labelWidth, 16)) // y=206 (move up 4px)
                                    .background_(Color.black)
                                    .font_(Font("Helvetica", 9).boldVariant)
                                    .align_(\center)
                                    .stringColor_(Color.cyan)
                                    .string_((i+1).asString);
                            });
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
    ~prevBinauralIRCAMId = ~binauralIRCAMId;
    ~prevBinauralCIPICId = ~binauralCIPICId;
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
~meterContainer = View(~meterView, Rect(10, 35, 300, 230)).background_(Color.black); // x=10, width=300

// --- Permanent OUTPUT label above the output numbers, always centered ---
StaticText(~meterContainer, Rect(97, 5, 180, 16)) // x=99-2, width=180, y=5
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("OUTPUT");
// --- Permanent row of 8 numbers below the meters, aligned with meter bars ---
~meterNumbers = Array.fill(8, { |i|
    var labelWidth = 24;
    var x = 96 + ((i + 0.5) * (180 / 8)) - (labelWidth / 2); // x=95+1, move 1px right
    StaticText(~meterContainer, Rect(x, 206, labelWidth, 16))
        .background_(Color.clear)
        .font_(Font("Helvetica", 9).boldVariant)
        .align_(\center)
        .stringColor_(Color.cyan)
        .string_((i+1).asString);
});

// --- Permanent INPUT label above the input numbers, always left-aligned ---
StaticText(~meterContainer, Rect(34, 5, 80, 16)) // x=32+2, width=80, y=5
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\left)
    .stringColor_(Color.cyan)
    .string_("INPUT");
// --- Permanent input channel numbers below the input meters ---
~inputNumbers = Array.fill(2, { |i| // Always show 2 input channels for now
    var labelWidth = 24;
    var spacing = 44;
    var x = 29 + ((i + 0.5) * (spacing / 2)) - (labelWidth / 2); // x=27+2
    StaticText(~meterContainer, Rect(x, 206, labelWidth, 16))
        .background_(Color.clear)
        .font_(Font("Helvetica", 9).boldVariant)
        .align_(\center)
        .stringColor_(Color.cyan)
        .string_((i+1).asString);
});
// --- Permanent vertical dB scale numbers (0 and -∞) ---
StaticText(~meterContainer, Rect(8, 25, 24, 12)) // x=6+2, y=18+7 (top)
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("0");
StaticText(~meterContainer, Rect(8, 195, 24, 12)) // x=6+2, y=188+7 (bottom)
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("-60");
// --- dB label halfway up the meter ---
StaticText(~meterContainer, Rect(8, 110, 24, 14)) // halfway up (approx)
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("dB");

// Initialize input defaults (from MainApp2)
lastInL = 112; // Default from phono-control -d (0dB equivalent)
lastInR = 112; // Default from phono-control -d (0dB equivalent)
~leftSlider.value = (lastInL - minIn) / (maxIn - minIn);
~rightSlider.value = (lastInR - minIn) / (maxIn - minIn);
// Display initial dB values using logarithmic scaling
dbValue = cliToDbMaster.(lastInL);
~leftValue.string = formatDbValue.(dbValue);
~rightValue.string = formatDbValue.(dbValue);

~lineBtn.value_(1);
~mmBtn.value_(0);
~mcBtn.value_(0);
~monBtn.value_(0);

// Set encoder/decoder menu defaults
~emenu.value_(0); // UHJ encoder
~dmenu.value_(0); // STEREO decoder

// Initialize hardware state
("phono-control -d").unixCmd;

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
~headtrackPairBtn = Button(mainView, Rect(742, 142, 40, 20))
    .states_([["PAIR", Color.cyan, Color.black]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({
        var out;
        // Run pairing script and capture stdout for post window
        out = "bash -lc 'auto_pair_headtracker.sh'".unixCmdGetStdOut;
        out.postln;
    });
// Ensure button is above overlays
~headtrackPairBtn.front;

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
                ~htResetOverlay = View(mainView, Rect(734, 102, 51, 20)) // Cover RESET button, extended 3px right
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
            if(~dimensionOverlay.notNil) { 
                ~saveDimensionState.value(); // Save state before removing dimension overlay
                ~dimensionOverlay.remove; ~dimensionOverlay = nil; ~dimensionBtn.value_(0); 
            };
            // Set other buttons to 0 (radio group)
            ~ambienceBtn.value_(0);
            ~layoutBtn.value_(0);
            ~dimensionBtn.value_(0);
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
            StaticText(~eqOverlay, Rect(10, 7, 120, 20))
                .string_("EQ PRESETS")
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
            // Preset menu enlarged slightly and kept clear of title
            ~eqPresetMenu = PopUpMenu(~eqOverlay, Rect(110, 7, 130, 20))
                .items_(~eqPresetNames.collect(_.asString))
                .font_(Font("Helvetica", 11))
                .background_(Color.black)
                .stringColor_(Color.cyan)
                .value_(0)
                .action_({
                    ~recallEqPreset.value;
                });
            // SAVE button kept at its original position/size
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

// --- Dimension State Management Functions ---
~saveDimensionState = {
    if(~dimensionWidthKnob.notNil) {
        ~dimensionState[\sliderValues] = [
            ~dimensionWidthKnob.value,
            ~dimensionWidthHPFKnob.value,
            ~dimensionTrimKnob.value
        ];
        ("Saved dimension state: " ++ ~dimensionState[\sliderValues]).postln;
    };
    if(~dimensionPresetMenu.notNil) {
        ~dimensionState[\presetIndex] = ~dimensionPresetMenu.value;
        ("Saved dimension preset index: " ++ ~dimensionState[\presetIndex]).postln;
    };
};

~restoreDimensionState = {
    if(~dimensionWidthKnob.notNil and: { ~dimensionState[\sliderValues].notNil }) {
        var savedVals = ~dimensionState[\sliderValues];
        ("Restoring dimension state: " ++ savedVals).postln;
        if(savedVals.size >= 3) {
            // New format: [width, widthHPF, outputTrim]
            ~dimensionWidthKnob.value_(savedVals[0] ? 0.0);
            ~dimensionWidthHPFKnob.value_(savedVals[1] ? 0.5); // Default 180Hz = 0.5 normalized
            ~dimensionTrimKnob.value_(savedVals[2] ? 0.5);
            ~dimensionWidthKnob.action.value(~dimensionWidthKnob);
            ~dimensionWidthHPFKnob.action.value(~dimensionWidthHPFKnob);
            ~dimensionTrimKnob.action.value(~dimensionTrimKnob);
        } {
            if(savedVals.size >= 2) {
                // Legacy format: [width, outputTrim] - add default widthHPF
                ~dimensionWidthKnob.value_(savedVals[0] ? 0.0);
                ~dimensionWidthHPFKnob.value_(0.5); // Default 180Hz
                ~dimensionTrimKnob.value_(savedVals[1] ? 0.5);
                ~dimensionWidthKnob.action.value(~dimensionWidthKnob);
                ~dimensionWidthHPFKnob.action.value(~dimensionWidthHPFKnob);
                ~dimensionTrimKnob.action.value(~dimensionTrimKnob);
            } {
                // Legacy support: if old format with 4 values, use first and last
                if(savedVals.size >= 4) {
                    ~dimensionWidthKnob.value_(savedVals[0] ? 0.0);
                    ~dimensionWidthHPFKnob.value_(0.5); // Default 180Hz
                    ~dimensionTrimKnob.value_(savedVals[3] ? 0.5);
                    ~dimensionWidthKnob.action.value(~dimensionWidthKnob);
                    ~dimensionWidthHPFKnob.action.value(~dimensionWidthHPFKnob);
                    ~dimensionTrimKnob.action.value(~dimensionTrimKnob);
                };
            };
        };
    };
    if(~dimensionPresetMenu.notNil and: { ~dimensionState[\presetIndex].notNil }) {
        ("Restoring dimension preset index: " ++ ~dimensionState[\presetIndex]).postln;
        ~dimensionPresetMenu.value_(~dimensionState[\presetIndex]);
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
    ~maplinState[\surround] = level;
    if(~synth.notNil and: { configKeyE == \maplin }) { 
        ~synth.set(\maplinSurround, level);
    ("Maplin surround level: " ++ (level * 100).round(1) ++ "%").postln;
    } {
        if(configKeyE != \maplin) {
            ("Maplin surround level: " ++ (level * 100).round(1) ++ "% (Maplin encoder not selected)").postln;
        } {
            ("Maplin surround level: " ++ (level * 100).round(1) ++ "% (synth not ready)").postln;
        };
    };
};
~setMaplinEffect = { |level=0.8|
    ~maplinState[\effect] = level;
    if(~synth.notNil and: { configKeyE == \maplin }) { 
        ~synth.set(\maplinEffect, level);
    ("Maplin effect level: " ++ (level * 100).round(1) ++ "%").postln;
    } {
        if(configKeyE != \maplin) {
            ("Maplin effect level: " ++ (level * 100).round(1) ++ "% (Maplin encoder not selected)").postln;
        } {
            ("Maplin effect level: " ++ (level * 100).round(1) ++ "% (synth not ready)").postln;
        };
    };
};

~setMaplinDelay = { |time=0.4|
    var delayMs = time.linlin(0, 1, 5, 50);
    ~maplinState[\delay] = time;
    if(~synth.notNil and: { configKeyE == \maplin }) { 
        ~synth.set(\maplinDelay, time);
    ("Maplin delay time: " ++ delayMs.round(1) ++ "ms").postln;
    } {
        if(configKeyE != \maplin) {
            ("Maplin delay time: " ++ delayMs.round(1) ++ "ms (Maplin encoder not selected)").postln;
        } {
            ("Maplin delay time: " ++ delayMs.round(1) ++ "ms (synth not ready)").postln;
        };
    };
};

~setMaplinActive = { |active=true|
    var activeVal = if(active, 1, 0);
    ~maplinState[\active] = activeVal;
    ~dimensionActive = activeVal;  // Also control Dimension active state
    
    if(~synth.notNil) {
        if(configKeyE == \maplin) {
            ~synth.set(\maplinActive, activeVal);
        };
        ~synth.set(\dimensionActive, activeVal);
        ("Maplin & Dimension: " ++ if(active, "ACTIVE", "BYPASSED")).postln;
    } {
        ("Maplin & Dimension: " ++ if(active, "ACTIVE", "BYPASSED") ++ " (synth not ready)").postln;
    };
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
        if(~maplinActiveBtn.notNil) {
            var activeVal = if(~maplinActiveBtn.value == 0, 1, 0); // Button 0 = ON (active=1), Button 1 = OFF (active=0)
            ~maplinState[\active] = activeVal;
            ~dimensionActive = activeVal;  // Also save Dimension active state
        };
        ("Saved Maplin GUI state: surround=" ++ ~maplinState[\surround] ++ ", effect=" ++ ~maplinState[\effect] ++ ", delay=" ++ ~maplinState[\delay] ++ ", active=" ++ ~maplinState[\active]).postln;
    };
};

~restoreMaplinState = {
    if(~maplinSurroundKnob.notNil) {
        ~maplinSurroundKnob.value_(~maplinState[\surround] ? 0.8);
        ~maplinEffectKnob.value_(~maplinState[\effect] ? 0.8);
        ~maplinDelayKnob.value_(~maplinState[\delay] ? 0.4);
        
        // Update ON/OFF button (0 = ON, 1 = OFF) - uses Dimension active state
        if(~maplinActiveBtn.notNil) {
            ~maplinActiveBtn.value_(if((~dimensionActive ? 1) == 1, 0, 1));
        };
        
        // Update value displays
        ~maplinSurroundValue.string_((~maplinState[\surround] * 100).round(1).asString ++ "%");
        ~maplinEffectValue.string_((~maplinState[\effect] * 100).round(1).asString ++ "%");
        ~maplinDelayValue.string_((~maplinState[\delay].linlin(0, 1, 5, 50).round(1).asString ++ " ms"));
        
        // Trigger actions to update synth
        if(~maplinSurroundKnob.action.notNil) { ~maplinSurroundKnob.action.value(~maplinSurroundKnob); };
        if(~maplinEffectKnob.action.notNil) { ~maplinEffectKnob.action.value(~maplinEffectKnob); };
        if(~maplinDelayKnob.action.notNil) { ~maplinDelayKnob.action.value(~maplinDelayKnob); };
        if(~maplinActiveBtn.notNil) { ~maplinActiveBtn.action.value(~maplinActiveBtn); };
        
        ("Restored Maplin GUI state: surround=" ++ ~maplinState[\surround] ++ ", effect=" ++ ~maplinState[\effect] ++ ", delay=" ++ ~maplinState[\delay] ++ ", active=" ++ ~maplinState[\active]).postln;
    };
};

// --- Dimension Overlay Encoder-Based Visibility Function ---
~updateDimensionOverlayVisibility = {
    // Only update if Dimension overlay is open
    if(~dimensionOverlay.notNil) {
        // Remove existing overlays
        if(~dimensionRowOverlay.notNil) { ~dimensionRowOverlay.remove; ~dimensionRowOverlay = nil; };
        if(~maplinRowOverlay.notNil) { ~maplinRowOverlay.remove; ~maplinRowOverlay = nil; };
        
        // Dimension row: covers labels (y=26), knobs (y=48), values (y=113) - moved up 4px
        // Height from 26 to 129 (113+16), so ~103px, make it 110 to be safe
        // Maplin row: covers labels (y=116), knobs (y=137), values (y=201) after upward shift
        // Values end at 217 (201+16), buttons start at 241, so stop well before buttons
        // ON/OFF and RESET buttons are at y=241, height=25 - these are ALWAYS VISIBLE (work for both Dimension and Maplin)
        // Leave 2px margin on left and right to avoid overlapping border (x=2, width=316)
        
        if(configKeyE == \maplin) {
            // MAPLIN encoder: hide Dimension row (show Maplin row, ON/OFF and RESET buttons always visible)
            ~dimensionRowOverlay = View(~dimensionOverlay, Rect(2, 28, 316, 110))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
        } {
            // UHJ, SUPERSTEREO, or PHJ: hide Maplin row only (show Dimension row, ON/OFF and RESET buttons always visible)
            // Cover Maplin row (y=116 to ~238) - stop before buttons at y=241
            // Keep previous height for safety
            ~maplinRowOverlay = View(~dimensionOverlay, Rect(2, 118, 316, 103))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
        };
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
        ~ambienceState[\synthParams] = [0.0, 0.2, 0.0, 0.2, 0.0, 0.0, 0.0];
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
    var presetData, roomName, baseRT;

    if(~ambiencePresetDict.notNil and: { ~ambiencePresetDict[presetName].notNil }) {
        presetData = ~ambiencePresetDict[presetName];
        roomName = presetData[\roomName];

        // Ensure roomName is not nil
        if(roomName.isNil) {
            ("Warning: No room name found in preset " ++ presetName ++ ", using Brahmssaal").postln;
            roomName = "Brahmssaal";
        };

        // Update sliders with preset values (only Reverb, RDelay, RSize, Spread)
        if(~ambienceSliders.notNil) {
            // Index mapping: 2=Reverb, 3=RDelay, 4=RSize, 5=Spread, 6=Target
            ~ambienceSliders[2].value_(presetData[\mix].linlin(0, 1, 0, 1)); // Reverb mix
            ~ambienceSliders[3].value_(presetData[\preDelay].linlin(0, 0.5, 0, 1)); // RDelay
            baseRT = (((presetData[\lowRT] / 0.7) + (presetData[\highRT] / 1.3)) * 0.5).clip(0.5, 2.5);
            ~ambienceSliders[4].value_(baseRT.linlin(0, 1, 0, 1)); // RSize macro
            ~ambienceSliders[5].value_(presetData[\dispersion].linlin(0.1, 2, 0, 1)); // Spread

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
                \preDelay, presetData[\preDelay],
                \lowRT, presetData[\lowRT].clip(0.1, 2),
                \highRT, presetData[\highRT].clip(0.2, 4),
                \dispersion, presetData[\dispersion].clip(0.1, 2),
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
            if(~dimensionOverlay.notNil) { 
                ~saveDimensionState.value(); // Save state before removing dimension overlay
                ~dimensionOverlay.remove; ~dimensionOverlay = nil; ~dimensionBtn.value_(0); 
            };
            // Set other buttons to 0 (radio group)
            ~eqBtn.value_(0);
            ~layoutBtn.value_(0);
            ~dimensionBtn.value_(0);
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
            // REVERB PRESETS label (matches EQ title placement)
            StaticText(~ambienceOverlay, Rect(10, 7, 160, 20))
                .string_("REVERB PRESETS")
                .align_(\left)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);

            // Load AmbiVerbSC presets if not already loaded
            if(~ambiencePresetDict.isNil) {
                var presetData = ~loadAmbiVerbSCPresets.value();
                ~ambiencePresetNames = presetData[0];
                ~ambiencePresetDict = presetData[1];
            };

            // Preset selector (dropdown)
            ~ambiencePresetMenu = PopUpMenu(~ambienceOverlay, Rect(160, 7, 150, 20))
                .items_(["Default", "High Verb", "Huge Hall", "Large Hall", "Low Verb", "Mod Echo", "Spatial Delay", "Time Modulation"])
                .font_(Font("Helvetica", 11))
                .background_(Color.black)
                .stringColor_(Color.cyan)
                .value_(~ambienceState[\presetIndex] ? 0) // Use saved preset index
                .action_({ |menu|
                    var selectedPreset = ~ambiencePresetNames[menu.value];
                    ~recallAmbiVerbSCPreset.value(selectedPreset);
                });
            // Add tick marks BETWEEN the sliders (visual guides, like EQ)
            [44, 88, 132, 176, 220, 264].do({ |tx|
                UserView(~ambienceOverlay, Rect(tx, 55, 12, sliderHeight))
                    .background_(Color.clear)
                    .drawFunc_({ |view|
                        Pen.color = Color.cyan;
                        Pen.width = 1.5;
                        // Major ticks (top/middle/bottom)
                        Pen.line(Point(2, 0), Point(10, 0)); Pen.stroke;
                        Pen.line(Point(2, 70), Point(10, 70)); Pen.stroke;
                        Pen.line(Point(2, 140), Point(10, 140)); Pen.stroke;
                        // Minor ticks
                        Pen.width = 1;
                        Pen.line(Point(4, 35), Point(9, 35)); Pen.stroke;
                        Pen.line(Point(4, 105), Point(9, 105)); Pen.stroke;
                    });
            });

            // Parameter labels and values (use saved state or defaults)
            // 7 faders (CamelCase, ≤6 chars): Height, HDelay, Reverb, RDelay, RSize, Spread, Target
            sliderLabels = ["Height", "HDelay", "Reverb", "RDelay", "RSize", "Spread", "Target"];
            params = ~ambienceState[\sliderValues] ? [0.0, 0.2, 0.0, 0.2, 0.0, 0.0, 0.0];
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
                        var valPct = (sl.value * 100).round(0.1);
                        var updateTargetReadout = { |snap|
                            // Sentence case labels
                            var label = if(snap <= 0.25, "Lower", if(snap >= 0.75, "Height", "All"));
                            ~ambienceValues[i].string = label;
                        };
                        if(~synth.notNil) {
                            switch(i,
                                0, { // HEIGHT amount (percent)
                                    ~ambienceValues[i].string = valPct.asString ++ "%";
                                    ~synth.set(\zsynthHeightAmount, (sl.value * 100));
                                },
                                1, { // HDELAY (ms)
                                    var ms = sl.value.linlin(0,1,0,30).round(0.1);
                                    ~ambienceValues[i].string = (ms.asString ++ "ms");
                                    ~synth.set(\zsynthHeightDelay, ms);
                                },
                                2, { // RMIX
                                    ~ambienceValues[i].string = valPct.asString ++ "%";
                                    ~synth.set(\ambience, sl.value.linlin(0, 1, 0, 0.2));
                                    if(sl.value > 0) { ~ambienceOnOffBtn.value_(1); ~ambienceLastMix = sl.value; } { ~ambienceOnOffBtn.value_(0); };
                                },
                                3, { // PREDLY (s)
                                    var pd = sl.value.linlin(0,1,0,0.5);
                                    ~ambienceValues[i].string = (pd.round(0.01).asString ++ "s");
                                    ~synth.set(\preDelay, pd);
                                },
                                4, { // SIZE macro (R-TIME)
                                    var base = sl.value.linlin(0,1,0.5,2.5);
                                    var low = (base * 0.7).clip(0.1, 2.0);
                                    var high = (base * 1.3).clip(0.2, 4.0);
                                    ~ambienceValues[i].string = (base.round(0.01).asString ++ "s");
                                    ~synth.set(\lowRT, low); ~synth.set(\highRT, high);
                                },
                                5, { // SPREAD (dispersion)
                                    var disp = sl.value.linlin(0,1,0.1,2.0);
                                    ~ambienceValues[i].string = (disp.round(0.01).asString);
                                    ~synth.set(\dispersion, disp);
                                },
                                6, { // TARGET (Lower / All / Height) with detents (Lower at bottom)
                                    var snap = if(sl.value < 0.25, 0.0, if(sl.value > 0.75, 1.0, 0.5));
                                    sl.value = snap; // snap slider
                                    updateTargetReadout.(snap);
                                    // Inverted mapping: 0.0=Lower, 0.5=All, 1.0=Height
                                    ~reverbTarget = if(snap == 0.0, \lower, if(snap == 1.0, \height, \all));
                                    if(~synth.notNil) {
                                        ~synth.set(\reverbTarget, if(snap == 0.0, 0, if(snap == 1.0, 2, 1)));
                                    };
                                }
                            );
                        } {
                            // Update value label even if synth not ready
                            switch(i,
                                0, { ~ambienceValues[i].string = valPct.asString ++ "%"; },
                                1, { ~ambienceValues[i].string = (sl.value.linlin(0,1,0,30).round(0.1).asString ++ " ms"); },
                                2, { ~ambienceValues[i].string = valPct.asString ++ "%"; },
                                3, { ~ambienceValues[i].string = (sl.value.linlin(0,1,0,0.5).round(0.01).asString ++ "s"); },
                                4, { ~ambienceValues[i].string = (sl.value.linlin(0,1,0.5,2.5).round(0.01).asString ++ "s"); },
                                5, { ~ambienceValues[i].string = (sl.value.linlin(0,1,0.1,2.0).round(0.01).asString); },
                                6, { updateTargetReadout.(if(sl.value < 0.25, 0.0, if(sl.value > 0.75, 1.0, 0.5))); }
                            );
                        }
                    });
                ~ambienceSliders.add(slider);
                valDisp = StaticText(~ambienceOverlay, Rect(x, 200, sliderWidth, 16))
                    .string_((params[i] * 100).asString ++ "%")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 10))
                    .background_(Color.clear);
                ~ambienceValues.add(valDisp);
            });
            // --- ON/OFF toggle for Ambience (controls Mix sent to synth, but does NOT move slider) ---
            // (Removed stray .states_, .font_, .value_, .action_ lines that were not attached to a Button)
            // --- Mix slider action: always updates value label and, if ON, sends to synth ---
            ~ambienceSliders[0].action_({ |sl|
                var val = (sl.value * 100).round(0.1);
                ~ambienceValues[0].string = val.asString ++ "%";
                if(~synth.notNil and: { ~ambienceOnOffBtn.notNil and: { ~ambienceOnOffBtn.value == 1 } }) {
                    // Only send to synth when ambience is ON
                    ~synth.set(\ambience, sl.value.linlin(0, 1, 0, 0.2));
                };
            });
            // --- Ensure ON/OFF button and Mix slider are visually independent on open ---
            if(~ambienceOnOffBtn.notNil) { ~ambienceOnOffBtn.value_(0); };
            if(~ambienceSliders.notNil and: { ~ambienceSliders[0].notNil }) { ~ambienceSliders[0].value = 0; };
            
            // REVERB button (gates mix; label fixed "REVERB")
            ~ambienceOnOffBtn = Button(~ambienceOverlay, Rect(120, 230, 80, 28))
                .states_([["REVERB", Color.cyan, Color.black], ["REVERB", Color.black, Color.cyan]])
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .value_(0) // default OFF
                .action_({ |btn|
                    if(~synth.notNil and: { ~ambienceSliders.notNil and: { ~ambienceSliders[0].notNil } }) {
                        if(btn.value == 1) {
                            // Turn ambience ON: apply current slider value to synth (no slider movement)
                            ~synth.set(\ambience, ~ambienceSliders[0].value.linlin(0, 1, 0, 0.2));
                        } {
                            // Turn ambience OFF: remember last mix (slider position) and bypass at synth
                            ~ambienceLastMix = ~ambienceSliders[0].value;
                            ~synth.set(\ambience, 0);
                        };
                    };
                });
            
            // RESET button moved to where CLOSE was
            Button(~ambienceOverlay, Rect(222, 230, 80, 28))
                .states_([["RESET", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .action_({
                    // Reset to default preset
                    if(~ambiencePresetNames.notNil and: { ~ambiencePresetNames.size > 0 }) {
                        ~ambiencePresetMenu.value_(0); // Select first preset
                        ~recallAmbiVerbSCPreset.value(~ambiencePresetNames[0]);
                    };
                });

            // HEIGHT button (left) - toggles Z source (Original vs Synthesized)
            // Always shows label "HEIGHT"; color indicates state
            ~ambienceEnhanceBtn = Button(~ambienceOverlay, Rect(18, 230, 80, 28))
                .states_([["HEIGHT", Color.cyan, Color.black], ["HEIGHT", Color.black, Color.cyan]])
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .value_(~zsynthState[\heightSource] ? 0) // default OFF if not saved
                .action_({ |btn|
                    var src = if(btn.value == 1, 1, 0); // 0=Original, 1=Synth
                    ~zsynthState[\heightSource] = src;
                    if(~synth.notNil) { ~synth.set(\zsynthHeightSource, src); };
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
        var currentDecoder, decoderNames, decoderName, titleWidth, titleX;
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
            if(~dimensionOverlay.notNil) { 
                ~saveDimensionState.value(); // Save state before removing dimension overlay
                ~saveMaplinState.value(); // Save Maplin state too
                // Remove overlays
                if(~dimensionRowOverlay.notNil) { ~dimensionRowOverlay.remove; ~dimensionRowOverlay = nil; };
                if(~maplinRowOverlay.notNil) { ~maplinRowOverlay.remove; ~maplinRowOverlay = nil; };
                ~dimensionOverlay.remove; ~dimensionOverlay = nil; ~dimensionBtn.value_(0); 
            };
            // Set other buttons to 0 (radio group)
            ~eqBtn.value_(0);
            ~ambienceBtn.value_(0);
            ~dimensionBtn.value_(0);
            // Remove old overlay first (this will remove all its children automatically)
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; };
            
            // Clean up layout-specific control references (in case they weren't children of overlay)
            // This ensures each layout is independent and controls don't persist between layouts
            // Layout 6 (Dolby 5.1) and Layout 7 (Dolby 5.1.2) controls cleanup
            if(~dolbyFLSquareBtn.notNil) { ~dolbyFLSquareBtn = nil; };
            if(~dolbyFRSquareBtn.notNil) { ~dolbyFRSquareBtn = nil; };
            if(~dolbyRLSquareBtn.notNil) { ~dolbyRLSquareBtn = nil; };
            if(~dolbyRRSquareBtn.notNil) { ~dolbyRRSquareBtn = nil; };
            if(~dolbyCenterSquareBtn.notNil) { ~dolbyCenterSquareBtn = nil; };
            if(~dolbySubSquareBtn.notNil) { ~dolbySubSquareBtn = nil; };
            if(~dolbyTopLeftSquareBtn.notNil) { ~dolbyTopLeftSquareBtn = nil; };
            if(~dolbyTopRightSquareBtn.notNil) { ~dolbyTopRightSquareBtn = nil; };
            if(~dolbyCenterGainSlider.notNil) { ~dolbyCenterGainSlider = nil; };
            if(~dolbyCenterGainLabel.notNil) { ~dolbyCenterGainLabel = nil; };
            if(~dolbySubGainSlider.notNil) { ~dolbySubGainSlider = nil; };
            if(~dolbySubGainLabel.notNil) { ~dolbySubGainLabel = nil; };
            if(~dolbyHeightGainSlider.notNil) { ~dolbyHeightGainSlider = nil; };
            if(~dolbyHeightGainLabel.notNil) { ~dolbyHeightGainLabel = nil; };
            // Add cleanup for other layout controls here as needed
            // Example for layout 0: if(~stereoControlBtn.notNil) { ~stereoControlBtn = nil; };
            
            ~layoutOverlay = View(mainView, Rect(180, 107, 320, 275))
                .background_(Color.black);
            ("Creating layout overlay, decoder value: " ++ ~dmenu.value).postln;
            // ONE UserView that draws both border AND diagrams (exactly like v27)
            // Create UserView FIRST (before controls) so it's beneath them
            ~layoutDiagramView = UserView(~layoutOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |view|
                    // All variable declarations must be at the top
                    var bounds = view.bounds;
                    var centerX = bounds.width / 2;
                    var centerY = bounds.height / 2;
                    var currentDecoderValue = ~dmenu.value;
                    
                    // Draw cyan border FIRST (like v27)
                    Pen.width = 0.5;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0.25, 0.25, bounds.width - 0.5, bounds.height - 0.5));
                    Pen.stroke;
                    Pen.width = 2;
                    switch(currentDecoderValue,
                        0, { // Stereo
                            var speakerWidth = 20, speakerHeight = 20, speakerSpacing = 120, leftSpeakerX, rightSpeakerX, speakerY;
                            var centerY_bottom = centerY + 80; // Center point further down at bottom of triangle
                            var leftRotationAngle, rightRotationAngle, leftCenterX, leftCenterY, rightCenterX, rightCenterY, leftOn, rightOn;
                            var speakerHalfWidth, speakerHalfHeight, speakerHalfSpacing;
                            speakerHalfWidth = speakerWidth * 0.5;
                            speakerHalfHeight = speakerHeight * 0.5;
                            speakerHalfSpacing = speakerSpacing * 0.5;
                            leftSpeakerX = centerX - speakerHalfSpacing - speakerHalfWidth;
                            rightSpeakerX = centerX + speakerHalfSpacing - speakerHalfWidth;
                            speakerY = centerY - 40; // Speakers at top of triangle
                            leftCenterX = leftSpeakerX + speakerHalfWidth;
                            leftCenterY = speakerY + speakerHalfHeight;
                            rightCenterX = rightSpeakerX + speakerHalfWidth;
                            rightCenterY = speakerY + speakerHalfHeight;
                            leftOn = ~stereoState[\lOn] ? 1;
                            rightOn = ~stereoState[\rOn] ? 1;
                            
                            // Calculate rotation angles based on speaker centres
                            leftRotationAngle = atan2(centerY_bottom - leftCenterY, centerX - leftCenterX) + (pi / 2);
                            rightRotationAngle = atan2(centerY_bottom - rightCenterY, centerX - rightCenterX) + (pi / 2);
                            
                            // Draw triangle guide lines
                            Pen.color = Color.cyan; Pen.width = 1;
                            // Left diagonal from center to left speaker
                            Pen.line(Point(centerX, centerY_bottom), Point(leftCenterX, leftCenterY));
                            Pen.stroke;
                            // Right diagonal from center to right speaker
                            Pen.line(Point(centerX, centerY_bottom), Point(rightCenterX, rightCenterY));
                            Pen.stroke;
                            
                            // Speaker 1: Left (mute button styling)
                            Pen.push;
                            Pen.translate(leftCenterX, leftCenterY);
                            Pen.rotate(leftRotationAngle + pi);
                            Pen.translate(0 - speakerHalfWidth, 0 - speakerHalfHeight);
                            if(leftOn == 1, {
                                Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.fill;
                                Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.stroke;
                                Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(0.5, 0.5, speakerWidth - 1, speakerHeight - 1), 2, 2); Pen.stroke;
                                Pen.stringAtPoint("1", Point(7, 4), Font("Helvetica", 13).boldVariant, Color.black);
                            }, {
                            Pen.color = Color.black; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.fill;
                                Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.stroke;
                                Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(0.5, 0.5, speakerWidth - 1, speakerHeight - 1), 2, 2); Pen.stroke;
                                Pen.stringAtPoint("1", Point(7, 4), Font("Helvetica", 13).boldVariant, Color.cyan);
                            });
                            Pen.pop;
                            
                            // Speaker 2: Right (mute button styling)
                            Pen.push;
                            Pen.translate(rightCenterX, rightCenterY);
                            Pen.rotate(rightRotationAngle + pi);
                            Pen.translate(0 - speakerHalfWidth, 0 - speakerHalfHeight);
                            if(rightOn == 1, {
                                Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.fill;
                                Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.stroke;
                                Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(0.5, 0.5, speakerWidth - 1, speakerHeight - 1), 2, 2); Pen.stroke;
                                Pen.stringAtPoint("2", Point(7, 4), Font("Helvetica", 13).boldVariant, Color.black);
                            }, {
                            Pen.color = Color.black; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.fill;
                                Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.stroke;
                                Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(0.5, 0.5, speakerWidth - 1, speakerHeight - 1), 2, 2); Pen.stroke;
                                Pen.stringAtPoint("2", Point(7, 4), Font("Helvetica", 13).boldVariant, Color.cyan);
                            });
                            Pen.pop;
                            
                            Pen.width = 1;
                            Pen.stringAtPoint("[1] L (-30°) & [2] R (+30°)", Point(centerX - 75, 32), Font("Helvetica", 13), Color.cyan);
                            Pen.stringAtPoint("Optimum listening angles", Point(centerX - 70, 50), Font("Helvetica", 12, italic: true), Color.cyan);
                            Pen.width = 2;
                        },
                        1, { // IRCAM Binaural
                            // Center graphic between top title (ends at y=32) and HRTF ID controls (at y=233): midpoint = 132.5
                            // Current graphic center is ~163.5, so move up by 16px
                            var moveUp = 16;
                            var earCupWidth = 20, earCupHeight = 27, earCupOffset = 55, arcCenterY = centerY - 25 + 25 - moveUp, arcRadius = 47, leftEarX, leftEarY, rightEarX, rightEarY, leftOn, rightOn;
                            leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                            leftEarY = centerY + 25 + 25 - moveUp;
                            rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                            rightEarY = centerY + 25 + 25 - moveUp;
                            leftOn = ~binauralState[
                                \lOn
                            ] ? 1;
                            rightOn = ~binauralState[
                                \rOn
                            ] ? 1;
                            Pen.color = Color.cyan; Pen.width = 2;
                            Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi); Pen.stroke;
                            Pen.moveTo(Point(centerX - arcRadius, centerY - 30 + 25 - moveUp)); Pen.lineTo(Point(centerX - arcRadius, leftEarY)); Pen.stroke;
                            Pen.moveTo(Point(centerX + arcRadius, centerY - 30 + 25 - moveUp)); Pen.lineTo(Point(centerX + arcRadius, rightEarY)); Pen.stroke;
                            Pen.color = if(leftOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(leftEarX + 0.5, leftEarY + 0.5, earCupWidth - 1, earCupHeight - 1), 2, 2); Pen.stroke;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(leftEarX + 6, leftEarY + 7), Font("Helvetica", 13).boldVariant, if(leftOn == 1, { Color.black }, { Color.cyan })); // Moved down 2px (5 -> 7)
                            Pen.color = if(rightOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(rightEarX + 0.5, rightEarY + 0.5, earCupWidth - 1, earCupHeight - 1), 2, 2); Pen.stroke;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rightEarX + 6, rightEarY + 7), Font("Helvetica", 13).boldVariant, if(rightOn == 1, { Color.black }, { Color.cyan })); // Moved down 2px (5 -> 7)
                            // Do NOT move the description text
                            Pen.stringAtPoint("Headphone Listening using IRCAM HRTF Library", Point(centerX - 140, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        2, { // CIPIC Binaural
                            // Center graphic between top title (ends at y=32) and HRTF ID controls (at y=233): midpoint = 132.5
                            // Current graphic center is ~163.5, so move up by 16px
                            var moveUp = 16;
                            var earCupWidth = 20, earCupHeight = 27, earCupOffset = 55, arcCenterY = centerY - 25 + 25 - moveUp, arcRadius = 47, leftEarX, leftEarY, rightEarX, rightEarY, leftOn, rightOn;
                            leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                            leftEarY = centerY + 25 + 25 - moveUp;
                            rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                            rightEarY = centerY + 25 + 25 - moveUp;
                            leftOn = ~binauralState[\lOn] ? 1;
                            rightOn = ~binauralState[\rOn] ? 1;
                            Pen.color = Color.cyan; Pen.width = 2;
                            Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi); Pen.stroke;
                            Pen.moveTo(Point(centerX - arcRadius, centerY - 25 + 25 - moveUp)); Pen.lineTo(Point(centerX - arcRadius, leftEarY)); Pen.stroke;
                            Pen.moveTo(Point(centerX + arcRadius, centerY - 25 + 25 - moveUp)); Pen.lineTo(Point(centerX + arcRadius, rightEarY)); Pen.stroke;
                            Pen.color = if(leftOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(leftEarX + 0.5, leftEarY + 0.5, earCupWidth - 1, earCupHeight - 1), 2, 2); Pen.stroke;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(leftEarX + 6, leftEarY + 7), Font("Helvetica", 13).boldVariant, if(leftOn == 1, { Color.black }, { Color.cyan }));
                            Pen.color = if(rightOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(rightEarX + 0.5, rightEarY + 0.5, earCupWidth - 1, earCupHeight - 1), 2, 2); Pen.stroke;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rightEarX + 6, rightEarY + 7), Font("Helvetica", 13).boldVariant, if(rightOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("Headphone Listening using CIPIC HRTF Library", Point(centerX - 138, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        3, { // Quad Square - larger square (similar to v27)
                            var layoutSize = 140, diagramCenterX = 160, layoutLeft = diagramCenterX - (layoutSize / 2), layoutTop = 70, speakerSize = 18;
                            var frontLeftX = layoutLeft - 9, frontLeftY = layoutTop - 9;
                            var frontRightX = layoutLeft + layoutSize - 9, frontRightY = layoutTop - 9;
                            var surroundLeftX = layoutLeft - 9, surroundLeftY = layoutTop + layoutSize - 9 + 10;
                            var surroundRightX = layoutLeft + layoutSize - 9, surroundRightY = layoutTop + layoutSize - 9 + 10;
                            var flOn = ~quadSquareState[\flOn] ? 1;
                            var frOn = ~quadSquareState[\frOn] ? 1;
                            var rlOn = ~quadSquareState[\rlOn] ? 1;
                            var rrOn = ~quadSquareState[\rrOn] ? 1;
                            Pen.color = Color.cyan; Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize + 10)); Pen.stroke;
                            // FL
                            Pen.color = if(flOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(frontLeftX + 0.5, frontLeftY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 5, frontLeftY + 2), Font("Helvetica", 13).boldVariant, if(flOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("FL", Point(frontLeftX + 3, frontLeftY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // FR
                            Pen.color = if(frOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(frontRightX + 0.5, frontRightY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 5, frontRightY + 2), Font("Helvetica", 13).boldVariant, if(frOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("FR", Point(frontRightX + 3, frontRightY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // RL
                            Pen.color = if(rlOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(surroundLeftX + 0.5, surroundLeftY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("3", Point(surroundLeftX + 5, surroundLeftY + 2), Font("Helvetica", 13).boldVariant, if(rlOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("RL", Point(surroundLeftX + 3, surroundLeftY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // RR
                            Pen.color = if(rrOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(surroundRightX + 0.5, surroundRightY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundRightX + 5, surroundRightY + 2), Font("Helvetica", 13).boldVariant, if(rrOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("RR", Point(surroundRightX + 2, surroundRightY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                        },
                        4, { // Quad Narrow - taller rectangle (similar proportions to v27)
                            var rectHeight = 160, rectWidth = 110, diagramCenterX = 160;
                            var rectLeft = diagramCenterX - (rectWidth / 2), rectTop = 60, speakerSize = 18;
                            var frontLeftX = rectLeft - 9, frontLeftY = rectTop - 9;
                            var frontRightX = rectLeft + rectWidth - 9, frontRightY = rectTop - 9;
                            var surroundLeftX = rectLeft - 9, surroundLeftY = rectTop + rectHeight - 9 + 8;
                            var surroundRightX = rectLeft + rectWidth - 9, surroundRightY = rectTop + rectHeight - 9 + 8;
                            var flOn = ~quadNarrowState[\flOn] ? 1;
                            var frOn = ~quadNarrowState[\frOn] ? 1;
                            var rlOn = ~quadNarrowState[\rlOn] ? 1;
                            var rrOn = ~quadNarrowState[\rrOn] ? 1;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight + 8)); Pen.stroke;
                            // FL
                            Pen.color = if(flOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(frontLeftX + 0.5, frontLeftY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 5, frontLeftY + 2), Font("Helvetica", 13).boldVariant, if(flOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("FL", Point(frontLeftX + 3, frontLeftY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // FR
                            Pen.color = if(frOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(frontRightX + 0.5, frontRightY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 5, frontRightY + 2), Font("Helvetica", 13).boldVariant, if(frOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("FR", Point(frontRightX + 3, frontRightY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // RL
                            Pen.color = if(rlOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(surroundLeftX + 0.5, surroundLeftY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("3", Point(surroundLeftX + 5, surroundLeftY + 2), Font("Helvetica", 13).boldVariant, if(rlOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("RL", Point(surroundLeftX + 3, surroundLeftY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // RR
                            Pen.color = if(rrOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(surroundRightX + 0.5, surroundRightY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundRightX + 5, surroundRightY + 2), Font("Helvetica", 13).boldVariant, if(rrOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("RR", Point(surroundRightX + 2, surroundRightY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                        },
                        5, { // Quad Wide - wider rectangle (similar proportions to v27)
                            var rectWidth = 170, rectHeight = 120, diagramCenterX = 160;
                            var rectLeft = diagramCenterX - (rectWidth / 2), rectTop = 78, speakerSize = 18;
                            var frontLeftX = rectLeft - 9, frontLeftY = rectTop - 9;
                            var frontRightX = rectLeft + rectWidth - 9, frontRightY = rectTop - 9;
                            var surroundLeftX = rectLeft - 9, surroundLeftY = rectTop + rectHeight - 9 + 8;
                            var surroundRightX = rectLeft + rectWidth - 9, surroundRightY = rectTop + rectHeight - 9 + 8;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight + 8)); Pen.stroke;
                            // Draw labels same as case 3
                            Pen.color = Color.black; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill; Pen.color = Color.cyan; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke; Pen.stringAtPoint("1", Point(frontLeftX + 5, frontLeftY + 2), Font("Helvetica", 13).boldVariant, Color.cyan); Pen.stringAtPoint("FL", Point(frontLeftX + 3, frontLeftY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill; Pen.color = Color.cyan; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke; Pen.stringAtPoint("2", Point(frontRightX + 5, frontRightY + 2), Font("Helvetica", 13).boldVariant, Color.cyan); Pen.stringAtPoint("FR", Point(frontRightX + 3, frontRightY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill; Pen.color = Color.cyan; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke; Pen.stringAtPoint("3", Point(surroundLeftX + 5, surroundLeftY + 2), Font("Helvetica", 13).boldVariant, Color.cyan); Pen.stringAtPoint("RL", Point(surroundLeftX + 3, surroundLeftY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill; Pen.color = Color.cyan; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke; Pen.stringAtPoint("4", Point(surroundRightX + 5, surroundRightY + 2), Font("Helvetica", 13).boldVariant, Color.cyan); Pen.stringAtPoint("RR", Point(surroundRightX + 2, surroundRightY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                        },
                        6, { // Dolby 5.1
                            var layoutSize = 100, diagramCenterX = 80, layoutLeft = diagramCenterX - (layoutSize / 2), layoutTop = 84, speakerSize = 18, frontLeftX = layoutLeft - 9, frontLeftY = layoutTop - 9, frontRightX = layoutLeft + layoutSize - 9, frontRightY = layoutTop - 9, centerX_speaker = layoutLeft + (layoutSize / 2) - 9, centerY_speaker = layoutTop - 9, surroundLeftX = layoutLeft - 9, surroundLeftY = layoutTop + layoutSize - 9 + 7, surroundRightX = layoutLeft + layoutSize - 9, surroundRightY = layoutTop + layoutSize - 9 + 7, subwooferX = layoutLeft + (layoutSize / 2) - 9, subwooferY = layoutTop + (layoutSize / 2) - 9 + 7;
                            Pen.color = Color.cyan; Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize + 7)); Pen.stroke;  // Extended box height by 7px to include RL/RR at corners
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 5, frontLeftY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("FL", Point(frontLeftX + 3, frontLeftY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 5, frontRightY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("FR", Point(frontRightX + 3, frontRightY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 3: Rear Left (RL)
                            Pen.color = Color.black; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(surroundLeftX + 5, surroundLeftY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("RL", Point(surroundLeftX + 3, surroundLeftY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 4: Rear Right (RR)
                            Pen.color = Color.black; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundRightX + 5, surroundRightY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("RR", Point(surroundRightX + 2, surroundRightY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 5: Center (C)
                            Pen.color = Color.black; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("5", Point(centerX_speaker + 5, centerY_speaker + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("C", Point(centerX_speaker + 5, centerY_speaker - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 6: Subwoofer (Sub = 6)
                            Pen.color = Color.cyan; Pen.addRect(Rect(subwooferX, subwooferY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("6", Point(subwooferX + 5, subwooferY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("SUB", Point(subwooferX - 1, subwooferY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                        },
                        7, { // Dolby Atmos 5.1.2
                            var layoutSize = 100, diagramCenterX = 80, layoutLeft = diagramCenterX - (layoutSize / 2), layoutTop = 84, speakerSize = 18;
                            var frontLeftX = layoutLeft - 9, frontLeftY = layoutTop - 9;
                            var frontRightX = layoutLeft + layoutSize - 9, frontRightY = layoutTop - 9;
                            var centerX_speaker = layoutLeft + (layoutSize / 2) - 9, centerY_speaker = layoutTop - 9;
                            var surroundLeftX = layoutLeft - 9, surroundLeftY = layoutTop + layoutSize - 9 + 7;
                            var surroundRightX = layoutLeft + layoutSize - 9, surroundRightY = layoutTop + layoutSize - 9 + 7;
                            var subwooferX = layoutLeft + (layoutSize / 2) - 9, subwooferY = layoutTop + (layoutSize / 2) - 9 + 7;
                            var topFrontLeftX = frontLeftX, topFrontLeftY = layoutTop - 49;  // Keep TL/TR in same position (compensate for layoutTop -2)
                            var topFrontRightX = frontRightX, topFrontRightY = layoutTop - 49;  // Keep TL/TR in same position (compensate for layoutTop -2)
                            
                            Pen.color = Color.cyan; Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize + 7)); Pen.stroke;  // Extended box height by 7px to include RL/RR at corners
                            
                            // --- EXACTLY THE SAME AS 5.1 LAYOUT ---
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 5, frontLeftY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("FL", Point(frontLeftX + 3, frontLeftY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 5, frontRightY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("FR", Point(frontRightX + 3, frontRightY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            
                            // Speaker 3: Rear Left (RL)
                            Pen.color = Color.black; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(surroundLeftX + 5, surroundLeftY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("RL", Point(surroundLeftX + 3, surroundLeftY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            
                            // Speaker 4: Rear Right (RR)
                            Pen.color = Color.black; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundRightX + 5, surroundRightY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("RR", Point(surroundRightX + 2, surroundRightY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            
                            // Speaker 5: Center (C)
                            Pen.color = Color.black; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("5", Point(centerX_speaker + 5, centerY_speaker + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("C", Point(centerX_speaker + 5, centerY_speaker - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            
                            // Speaker 6: Subwoofer (Sub = 6)
                            Pen.color = Color.cyan; Pen.addRect(Rect(subwooferX, subwooferY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("6", Point(subwooferX + 5, subwooferY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("SUB", Point(subwooferX - 1, subwooferY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            
                            // --- ADDITIONAL CEILING SPEAKERS FOR 5.1.2 ---
                            // Speaker 7: Top Front Left (overhead) - positioned above front left
                            Pen.color = Color.black; Pen.addRect(Rect(topFrontLeftX, topFrontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(topFrontLeftX, topFrontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("7", Point(topFrontLeftX + 5, topFrontLeftY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("TL", Point(topFrontLeftX + speakerSize + 4, topFrontLeftY + 5), Font("Helvetica", 10).boldVariant, Color.cyan);
                            
                            // Speaker 8: Top Front Right (overhead) - positioned above front right
                            Pen.color = Color.black; Pen.addRect(Rect(topFrontRightX, topFrontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(topFrontRightX, topFrontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("8", Point(topFrontRightX + 5, topFrontRightY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("TR", Point(topFrontRightX - 18, topFrontRightY + 5), Font("Helvetica", 10).boldVariant, Color.cyan);
                        },
                        8, { // Octagon
                            var radius = 80, angleStep = 2 * pi / 8, startAngle = -22.5 * pi / 180, speakerPositions;
                            speakerPositions = Array.fill(8, { |i|
                                var angle = startAngle + (i * angleStep);
                                var x = centerX + (radius * cos(angle)) - 10;
                                var y = centerY + (radius * sin(angle)) - 10 + 25;
                                Point(x, y);
                            });
                            Pen.color = Color.cyan; Pen.addOval(Rect(centerX - radius, centerY - radius + 25, radius * 2, radius * 2)); Pen.stroke;
                            speakerPositions.do({ |pos, i|
                                var speakerNum = ((i + 2) % 8) + 1; // Shift so speaker 1 is at front-left position (consumer standard)
                                var angle = startAngle + (i * angleStep);
                                var rotationAngle = angle + (pi / 2);
                                var isOn, key;
                                key = ("s" ++ speakerNum.asString ++ "On").asSymbol;
                                isOn = ~octagonState[key] ? 1;
                                Pen.push;
                                Pen.translate(pos.x + 10, pos.y + 10);
                                Pen.rotate(rotationAngle);
                                Pen.translate(-10, -10);
                                if(isOn == 1, {
                                    // ON: cyan box with black text
                                    Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, 20, 20)); Pen.fill;
                                    Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, 20, 20)); Pen.stroke;
                                    // subtle outer border like real buttons
                                    Pen.width = 1; Pen.color = Color.grey(0.6);
                                    Pen.addRoundedRect(Rect(0.5, 0.5, 19, 19), 2, 2); Pen.stroke;
                                    Pen.stringAtPoint(speakerNum.asString, Point(7, 4), Font("Helvetica", 13).boldVariant, Color.black);
                                }, {
                                    // OFF: black box with cyan text (dim outline optional)
                                Pen.color = Color.black; Pen.addRect(Rect(0, 0, 20, 20)); Pen.fill;
                                Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, 20, 20)); Pen.stroke;
                                    // subtle outer border like real buttons
                                    Pen.width = 1; Pen.color = Color.grey(0.6);
                                    Pen.addRoundedRect(Rect(0.5, 0.5, 19, 19), 2, 2); Pen.stroke;
                                    Pen.stringAtPoint(speakerNum.asString, Point(7, 4), Font("Helvetica", 13).boldVariant, Color.cyan);
                                });
                                Pen.pop;
                            });
                            Pen.stringAtPoint("[1] FL (-22.5°), Clockwise @ 45°", Point(centerX - 84, 32), Font("Helvetica", 13), Color.cyan);
                        }
                    );
                })
                .refresh;  // Force initial draw
            // Add the title as StaticText at the top, centered
            // Layout title showing encoder class only
            // For Dolby layouts, center over diagram (left side); for others, use full width
            ~layoutTitleText = StaticText(~layoutOverlay, Rect(
                if((~dmenu.value == 6) || (~dmenu.value == 7), 5, 0),  // For Dolby, align over left diagram
                10, // y position
                if((~dmenu.value == 6) || (~dmenu.value == 7), 150, 320), // Dolby: narrow width; others: full width
                22   // height
            ))
                .string_(([
                    "STEREO",
                    "BINAURAL IRCAM",
                    "BINAURAL CIPIC",
                    "QUAD SQUARE",
                    "QUAD NARROW",
                    "QUAD WIDE",
                    "DOLBY 5.1",
                    "DOLBY 5.1.2",
                    "OCTAGON"
                ][~dmenu.value ? 0]))
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);
            // Create controls for Dolby 5.1 (case 6)
            if(~dmenu.value == 6, {
                // All variable declarations must be at the absolute top of the block
                var layoutSize = 100, diagramCenterX = 80, layoutLeft = 30, layoutTop = 84, speakerSize = 18;
                var frontLeftX = 21, frontLeftY = 75;
                var frontRightX = 121, frontRightY = 75;
                var centerX_speaker = 71, centerY_speaker = 75;
                var surroundLeftX = 21, surroundLeftY = 182;
                var surroundRightX = 121, surroundRightY = 182;
                var subwooferX = 71, subwooferY = 132;
                var controlStartX = 170, controlY = 14, sliderWidth = 35, sliderHeight = 164, controlSpacing = 43;
                var rightmostFaderX;
                
                "Creating controls for Dolby 5.1 (case 6)".postln;
                
                // Speaker 1: Front Left (FL)
                ~dolbyFLSquareBtn = Button(~layoutOverlay, Rect(frontLeftX, frontLeftY, speakerSize, speakerSize))
                    .states_([
                        ["1", Color.black, Color.cyan],
                        ["1", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\flOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\flOn] = newState;
                        if(~synth.notNil) { ~synth.set(\flOn, newState) };
                        btn.focus(nil);
                    });
                
                // Speaker 2: Front Right (FR)
                ~dolbyFRSquareBtn = Button(~layoutOverlay, Rect(frontRightX, frontRightY, speakerSize, speakerSize))
                    .states_([
                        ["2", Color.black, Color.cyan],
                        ["2", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\frOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\frOn] = newState;
                        if(~synth.notNil) { ~synth.set(\frOn, newState) };
                        btn.focus(nil);
                    });
                
                // Speaker 3: Rear Left (RL)
                ~dolbyRLSquareBtn = Button(~layoutOverlay, Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize))
                    .states_([
                        ["3", Color.black, Color.cyan],
                        ["3", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\rlOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\rlOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rlOn, newState) };
                        btn.focus(nil);
                    });
                // Speaker 4: Rear Right (RR)
                ~dolbyRRSquareBtn = Button(~layoutOverlay, Rect(surroundRightX, surroundRightY, speakerSize, speakerSize))
                    .states_([
                        ["4", Color.black, Color.cyan],
                        ["4", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\rrOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\rrOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rrOn, newState) };
                        btn.focus(nil);
                    });
                
                // Speaker 5: Center (C)
                ~dolbyCenterSquareBtn = Button(~layoutOverlay, Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize))
                    .states_([
                        ["5", Color.black, Color.cyan],
                        ["5", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\centerOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\centerOn] = newState;
                        if(~synth.notNil) { ~synth.set(\centerOn, newState) };
                        btn.focus(nil);
                    });
                
                // Speaker 6: Subwoofer (SUB)
                ~dolbySubSquareBtn = Button(~layoutOverlay, Rect(subwooferX, subwooferY, speakerSize, speakerSize))
                    .states_([
                        ["6", Color.black, Color.cyan],
                        ["6", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\subOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\subOn] = newState;
                        if(~synth.notNil) { ~synth.set(\subOn, newState) };
                        btn.focus(nil);
                    });
                
                // Fader controls for CENTER (now middle slot after swapping with SUB)
                StaticText(~layoutOverlay, Rect(controlStartX + controlSpacing, controlY, sliderWidth, 15))
                    .string_("C")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                ~dolbyCenterGainSlider = Slider(~layoutOverlay, Rect(controlStartX + controlSpacing, controlY + 18, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\centerGain] ? 0.0).linlin(-12, 12, 0, 1))
                    .action_({ |sl|
                        var gain = sl.value.linlin(0, 1, -12, 12);
                        ~dolbyState[\centerGain] = gain;
                        if(~dolbyCenterGainLabel.notNil) {
                            ~dolbyCenterGainLabel.string = gain.round(0.1).asString ++ "dB";
                        };
                        if(~synth.notNil) { ~synth.set(\centerGain, gain) };
                    });
                
                ~dolbyCenterGainLabel = StaticText(~layoutOverlay, Rect(controlStartX + controlSpacing, 199, sliderWidth, 15))
                    .string_((~dolbyState[\centerGain] ? 0.0).round(0.1).asString ++ "dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                // Fader controls for SUB (moved to rightmost slot)
                StaticText(~layoutOverlay, Rect(controlStartX + (controlSpacing * 2), controlY, sliderWidth, 15))
                    .string_("SUB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                ~dolbySubGainSlider = Slider(~layoutOverlay, Rect(controlStartX + (controlSpacing * 2), controlY + 18, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\subGain] ? 0.0).linlin(-12, 12, 0, 1))
                    .action_({ |sl|
                        var gain = sl.value.linlin(0, 1, -12, 12);
                        ~dolbyState[\subGain] = gain;
                        if(~dolbySubGainLabel.notNil) {
                            ~dolbySubGainLabel.string = gain.round(0.1).asString ++ "dB";
                        };
                        if(~synth.notNil) { ~synth.set(\subGain, gain) };
                    });
                
                ~dolbySubGainLabel = StaticText(~layoutOverlay, Rect(controlStartX + (controlSpacing * 2), 199, sliderWidth, 15))
                    .string_((~dolbyState[\subGain] ? 0.0).round(0.1).asString ++ "dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                // TOP (height) fader is still drawn, but visually dimmed by overlay (moved to leftmost slot)
                StaticText(~layoutOverlay, Rect(controlStartX, controlY, sliderWidth, 15))
                    .string_("TOP")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                ~dolbyHeightGainSlider = Slider(~layoutOverlay, Rect(controlStartX, controlY + 18, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\heightGain] ? 0.0).linlin(-12, 12, 0, 1))
                    .action_({ |sl|
                        var gain = sl.value.linlin(0, 1, -12, 12);
                        ~dolbyState[\heightGain] = gain;
                        if(~dolbyHeightGainLabel.notNil) {
                            ~dolbyHeightGainLabel.string = gain.round(0.1).asString ++ "dB";
                        };
                        if(~synth.notNil) { ~synth.set(\heightGain, gain) };
                    });

                ~dolbyHeightGainLabel = StaticText(~layoutOverlay, Rect(controlStartX, 199, sliderWidth, 15))
                    .string_((~dolbyState[\heightGain] ? 0.0).round(0.1).asString ++ "dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                // dB scale labels (single set on the right, after TOP fader to match 5.1.2)
                rightmostFaderX = controlStartX + (controlSpacing * 2) + sliderWidth;
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 14, 20, 15))
                    .string_("+12")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + (sliderHeight / 4) - 7, 20, 15))
                    .string_("+6")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + (sliderHeight / 2) - 7, 20, 15))
                    .string_("0")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + (sliderHeight * 3 / 4) - 7, 20, 15))
                    .string_("-6")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + sliderHeight - 7, 20, 15))
                    .string_("-12")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                
                // Draw tick marks BETWEEN the faders (between CENTER and SUB)
                UserView(~layoutOverlay, Rect(controlStartX + sliderWidth, controlY + 18, 8, sliderHeight))
                    .background_(Color.clear)
                    .drawFunc_({ |view|
                        Pen.color = Color.cyan;
                        Pen.width = 1.5;
                        // Major ticks
                        Pen.line(Point(2, 0), Point(6, 0)); Pen.stroke; // +12dB
                        Pen.line(Point(2, sliderHeight / 2), Point(6, sliderHeight / 2)); Pen.stroke; // 0dB
                        Pen.line(Point(2, sliderHeight), Point(6, sliderHeight)); Pen.stroke; // -12dB
                        // Minor ticks
                        Pen.width = 1;
                        Pen.line(Point(3, sliderHeight / 4), Point(5, sliderHeight / 4)); Pen.stroke; // +6dB
                        Pen.line(Point(3, sliderHeight * 3 / 4), Point(5, sliderHeight * 3 / 4)); Pen.stroke; // -6dB
                    });
                
                // Draw tick marks BETWEEN the faders (between SUB and TOP)
                UserView(~layoutOverlay, Rect(controlStartX + controlSpacing + sliderWidth, controlY + 18, 8, sliderHeight))
                    .background_(Color.clear)
                    .drawFunc_({ |view|
                        Pen.color = Color.cyan;
                        Pen.width = 1.5;
                        // Major ticks
                        Pen.line(Point(2, 0), Point(6, 0)); Pen.stroke; // +12dB
                        Pen.line(Point(2, sliderHeight / 2), Point(6, sliderHeight / 2)); Pen.stroke; // 0dB
                        Pen.line(Point(2, sliderHeight), Point(6, sliderHeight)); Pen.stroke; // -12dB
                        // Minor ticks
                        Pen.width = 1;
                        Pen.line(Point(3, sliderHeight / 4), Point(5, sliderHeight / 4)); Pen.stroke; // +6dB
                        Pen.line(Point(3, sliderHeight * 3 / 4), Point(5, sliderHeight * 3 / 4)); Pen.stroke; // -6dB
                    });

                // Semi-transparent overlay covering the TOP label, slider, and bottom value (dim entire fader block), now at leftmost slot
                if(~dolbyHeightOverlay.notNil) { ~dolbyHeightOverlay.remove; ~dolbyHeightOverlay = nil; };
                ~dolbyHeightOverlay = View(~layoutOverlay, Rect(controlStartX, controlY, sliderWidth + 8, (199 + 15) - controlY))
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
                // Extra slender faders BELOW the diagram and vertical faders
                // Geometry: left aligns to right edge of speaker 3 box; right leaves space for value labels
                // TOP LPF - now top horizontal slender fader (swapped with SUB)
                ~dolbyTopHpfLabel = StaticText(~layoutOverlay, Rect((surroundLeftX + speakerSize) - 32 - 6 + 8, controlY + 18 + sliderHeight + 30 + 3, 56, 15))
                    .string_("TOP LPF")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                ~dolbyTopHpfSlider = Slider(~layoutOverlay, Rect((surroundLeftX + speakerSize) + 33, controlY + 18 + sliderHeight + 30, (((rightmostFaderX - 50) - (surroundLeftX + speakerSize)) - 9) - 2, 17))
                    .orientation_(\horizontal)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\topHPF] ? 180).linlin(80, 4000, 0, 1))
                    .action_({ |sl|
                        var hz = (sl.value.linlin(0, 1, 80, 4000) / 10).round * 10; // 80-4000 Hz, stepped in 10s
                        ~dolbyState[\topHPF] = hz;
                        if(~dolbyTopHpfValue.notNil) { ~dolbyTopHpfValue.string = hz.asInteger.asString ++ " Hz"; };
                        if(~synth.notNil) { ~synth.set(\topHPF, hz) };
                    });
                ~dolbyTopHpfValue = StaticText(~layoutOverlay, Rect(controlStartX + (rightmostFaderX - controlStartX) - 28, controlY + 18 + sliderHeight + 30 + 1, 44, 15))
                    .string_((((~dolbyState[\topHPF] ? 180) / 10).round * 10).asInteger.asString ++ " Hz")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                // SUB LPF - now bottom horizontal slender fader
                ~dolbySubLpfLabel = StaticText(~layoutOverlay, Rect((surroundLeftX + speakerSize) - 32 - 6 + 8, (controlY + 18 + sliderHeight + 30) + 18 + 6, 56, 15))
                    .string_("SUB LPF")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                ~dolbySubLpfSlider = Slider(~layoutOverlay, Rect((surroundLeftX + speakerSize) + 33, (controlY + 18 + sliderHeight + 30) + 22, (((rightmostFaderX - 50) - (surroundLeftX + speakerSize)) - 9) - 2, 17))
                    .orientation_(\horizontal)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\subLPF] ? 120).linlin(40, 200, 0, 1))
                    .action_({ |sl|
                        var hz = sl.value.linlin(0, 1, 40, 200); // 40-200 Hz
                        ~dolbyState[\subLPF] = hz;
                        if(~dolbySubLpfValue.notNil) { ~dolbySubLpfValue.string = hz.round.asInteger.asString ++ " Hz"; };
                        if(~synth.notNil) { ~synth.set(\subLPF, hz) };
                    });

                ~dolbySubLpfValue = StaticText(~layoutOverlay, Rect(controlStartX + (rightmostFaderX - controlStartX) - 28, (controlY + 18 + sliderHeight + 30 + 18) + 5, 44, 15))
                    .string_(((~dolbyState[\subLPF] ? 120)).round.asInteger.asString ++ " Hz")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                // Dim overlay for TOP LPF (label, fader, value) in Dolby 5.1 to match disabled TOP behavior (now top row)
                if(~dolbyTopLpfOverlay.notNil) { try { ~dolbyTopLpfOverlay.remove; }; ~dolbyTopLpfOverlay = nil; };
                ~dolbyTopLpfOverlay = View(
                    ~layoutOverlay,
                    Rect(
                        ((surroundLeftX + speakerSize) - 32 - 6 + 8) - 6, // a little left of label
                        (controlY + 18 + sliderHeight + 30) - 1,     // moved up 3px
                        ((controlStartX + (rightmostFaderX - controlStartX) + 44 + 6) - (((surroundLeftX + speakerSize) - 32 - 6 + 8) - 6)) - 34, // reduce right edge by 34px total
                        24 // reduce bottom by 10px (was 34)
                    )
                )
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;

                // Bring all buttons to front so they're clickable
                ~dolbyFLSquareBtn.front;
                ~dolbyFRSquareBtn.front;
                ~dolbyRLSquareBtn.front;
                ~dolbyRRSquareBtn.front;
                ~dolbyCenterSquareBtn.front;
                ~dolbySubSquareBtn.front;
            });
            // Stereo layout (case 0) – clickable mute buttons for speakers
            if(~dmenu.value == 0, {
                var layoutBounds, centerX, centerY, speakerWidth, speakerHeight, speakerSpacing, speakerY, leftSpeakerX, rightSpeakerX;
                var leftCenterX, leftCenterY, rightCenterX, rightCenterY, speakerHalfWidth, speakerHalfHeight, speakerHalfSpacing;
                layoutBounds = ~layoutOverlay.bounds;
                centerX = layoutBounds.width / 2;
                centerY = layoutBounds.height / 2;
                speakerWidth = 20;
                speakerHeight = 20;
                speakerSpacing = 120;
                speakerY = centerY - 40;
                speakerHalfWidth = speakerWidth * 0.5;
                speakerHalfHeight = speakerHeight * 0.5;
                speakerHalfSpacing = speakerSpacing * 0.5;
                leftSpeakerX = centerX - speakerHalfSpacing - speakerHalfWidth;
                rightSpeakerX = centerX + speakerHalfSpacing - speakerHalfWidth;
                leftCenterX = leftSpeakerX + speakerHalfWidth;
                leftCenterY = speakerY + speakerHalfHeight;
                rightCenterX = rightSpeakerX + speakerHalfWidth;
                rightCenterY = speakerY + speakerHalfHeight;

                if(~stereoLeftHit.notNil) { try { ~stereoLeftHit.remove; }; ~stereoLeftHit = nil; };
                if(~stereoRightHit.notNil) { try { ~stereoRightHit.remove; }; ~stereoRightHit = nil; };

                ~stereoLeftHit = UserView(~layoutOverlay, Rect(leftCenterX - speakerHalfWidth, leftCenterY - speakerHalfHeight, speakerWidth, speakerHeight))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~stereoState[\lOn] ? 1);
                        ~stereoState[\lOn] = newState;
                        if(~synth.notNil) { ~synth.set(\lOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~stereoLeftHit.front;

                ~stereoRightHit = UserView(~layoutOverlay, Rect(rightCenterX - speakerHalfWidth, rightCenterY - speakerHalfHeight, speakerWidth, speakerHeight))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~stereoState[\rOn] ? 1);
                        ~stereoState[\rOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~stereoRightHit.front;
            });

            if(~dmenu.value == 3, {
                var diagramCenterX = 160, layoutSize = 140, layoutLeft = diagramCenterX - (layoutSize / 2), layoutTop = 70, speakerSize = 18;
                var frontLeftX = layoutLeft - 9, frontLeftY = layoutTop - 9;
                var frontRightX = layoutLeft + layoutSize - 9, frontRightY = layoutTop - 9;
                var surroundLeftX = layoutLeft - 9, surroundLeftY = layoutTop + layoutSize - 9 + 10;
                var surroundRightX = layoutLeft + layoutSize - 9, surroundRightY = layoutTop + layoutSize - 9 + 10;

                if(~quadSquareFLHit.notNil) { try { ~quadSquareFLHit.remove; }; ~quadSquareFLHit = nil; };
                if(~quadSquareFRHit.notNil) { try { ~quadSquareFRHit.remove; }; ~quadSquareFRHit = nil; };
                if(~quadSquareRLHit.notNil) { try { ~quadSquareRLHit.remove; }; ~quadSquareRLHit = nil; };
                if(~quadSquareRRHit.notNil) { try { ~quadSquareRRHit.remove; }; ~quadSquareRRHit = nil; };

                ~quadSquareFLHit = UserView(~layoutOverlay, Rect(frontLeftX, frontLeftY, speakerSize, speakerSize))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~quadSquareState[\flOn] ? 1);
                        ~quadSquareState[\flOn] = newState;
                        if(~synth.notNil) { ~synth.set(\flOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~quadSquareFLHit.front;

                ~quadSquareFRHit = UserView(~layoutOverlay, Rect(frontRightX, frontRightY, speakerSize, speakerSize))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~quadSquareState[\frOn] ? 1);
                        ~quadSquareState[\frOn] = newState;
                        if(~synth.notNil) { ~synth.set(\frOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~quadSquareFRHit.front;

                ~quadSquareRLHit = UserView(~layoutOverlay, Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~quadSquareState[\rlOn] ? 1);
                        ~quadSquareState[\rlOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rlOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~quadSquareRLHit.front;

                ~quadSquareRRHit = UserView(~layoutOverlay, Rect(surroundRightX, surroundRightY, speakerSize, speakerSize))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~quadSquareState[\rrOn] ? 1);
                        ~quadSquareState[\rrOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rrOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~quadSquareRRHit.front;
            });

            if(~dmenu.value == 4, {
                var rectHeight = 160, rectWidth = 110, diagramCenterX = 160;
                var rectLeft = diagramCenterX - (rectWidth / 2), rectTop = 60, speakerSize = 18;
                var frontLeftX = rectLeft - 9, frontLeftY = rectTop - 9;
                var frontRightX = rectLeft + rectWidth - 9, frontRightY = rectTop - 9;
                var surroundLeftX = rectLeft - 9, surroundLeftY = rectTop + rectHeight - 9 + 8;
                var surroundRightX = rectLeft + rectWidth - 9, surroundRightY = rectTop + rectHeight - 9 + 8;

                if(~quadNarrowFLHit.notNil) { try { ~quadNarrowFLHit.remove; }; ~quadNarrowFLHit = nil; };
                if(~quadNarrowFRHit.notNil) { try { ~quadNarrowFRHit.remove; }; ~quadNarrowFRHit = nil; };
                if(~quadNarrowRLHit.notNil) { try { ~quadNarrowRLHit.remove; }; ~quadNarrowRLHit = nil; };
                if(~quadNarrowRRHit.notNil) { try { ~quadNarrowRRHit.remove; }; ~quadNarrowRRHit = nil; };

                ~quadNarrowFLHit = UserView(~layoutOverlay, Rect(frontLeftX, frontLeftY, speakerSize, speakerSize))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~quadNarrowState[\flOn] ? 1);
                        ~quadNarrowState[\flOn] = newState;
                        if(~synth.notNil) { ~synth.set(\flOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~quadNarrowFLHit.front;

                ~quadNarrowFRHit = UserView(~layoutOverlay, Rect(frontRightX, frontRightY, speakerSize, speakerSize))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~quadNarrowState[\frOn] ? 1);
                        ~quadNarrowState[\frOn] = newState;
                        if(~synth.notNil) { ~synth.set(\frOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~quadNarrowFRHit.front;

                ~quadNarrowRLHit = UserView(~layoutOverlay, Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~quadNarrowState[\rlOn] ? 1);
                        ~quadNarrowState[\rlOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rlOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~quadNarrowRLHit.front;

                ~quadNarrowRRHit = UserView(~layoutOverlay, Rect(surroundRightX, surroundRightY, speakerSize, speakerSize))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~quadNarrowState[\rrOn] ? 1);
                        ~quadNarrowState[\rrOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rrOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~quadNarrowRRHit.front;
            });

            // Binaural IRCAM (case 1) – HRTF selection menu and grid chooser
            if(~dmenu.value == 1, {
                var chooserWin, chooserView, cols, rows, cellW, cellH, padding, winWidth, winHeight, winX, winY, layoutBounds, mainViewBounds, winBounds, gridRows, gridSpacing, gridHeight, buttonH, labelWidth, dropdownWidth, totalWidth, groupStartX, labelX, dropdownX, yPos, centerX, centerY, moveUp, earCupWidth, earCupHeight, earCupOffset, leftEarX, leftEarY, rightEarX, rightEarY;
                // Hardcoded list of available IRCAM LISTEN subject IDs
                ~binauralIRCAMIds = [1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1012, 1013, 1014, 1015, 1016, 1017, 1018, 1020, 1021, 1022, 1023, 1025, 1026, 1028, 1029, 1030, 1031, 1032, 1033, 1034, 1037, 1038, 1039, 1040, 1041, 1042, 1043, 1044, 1045, 1046, 1047, 1048, 1049, 1050, 1051, 1052, 1053, 1054, 1055, 1056, 1057, 1058, 1059];
                ("Found " ++ ~binauralIRCAMIds.size ++ " IRCAM IDs").postln;
                ~binauralIRCAMPendingId = ~binauralIRCAMId; // pending selection (apply with LOAD)
                // Calculate button height to match grid buttons
                layoutBounds = ~layoutOverlay.bounds;
                gridRows = 8;
                gridSpacing = 3;
                gridHeight = layoutBounds.height - 3; // Same as winHeight calculation
                buttonH = ((gridHeight - (9 * gridSpacing)) / gridRows).floor;
                // Calculate positions: center label + dropdown together, then move up 7px
                labelWidth = 90; // Bigger box so "PROFILE" fits on one line
                dropdownWidth = 80;
                totalWidth = labelWidth + dropdownWidth;
                groupStartX = (320 - totalWidth) / 2; // Center the group
                labelX = groupStartX;
                dropdownX = groupStartX + labelWidth;
                yPos = 240 - 7; // Move up 7px
                // Profile label - bigger box, LCD font size 13 (one step down from ENCODER/DECODER titles)
                ~binauralIrcamProfileLabel = StaticText(~layoutOverlay, Rect(labelX, yPos, labelWidth, buttonH))
                    .string_("PROFILE")
                    .stringColor_(Color.cyan)
                    .font_(Font("LCD 5x7 Segment Monospace", 13))
                    .align_(\left)
                    .background_(Color.clear);
                ~binauralIrcamProfileLabel.front;
                 // Fake dropdown button (cyan text on black) that opens chooser - LCD font size 11 (same as encoder labels)
                 ~binauralIrcamSelectBtn = Button(~layoutOverlay, Rect(dropdownX, yPos, dropdownWidth, buttonH))
                     .states_([[ (~binauralIRCAMPendingId.asString.padLeft(4, "0")), Color.cyan, Color.black ],
                               [ (~binauralIRCAMPendingId.asString.padLeft(4, "0")), Color.cyan, Color.black ]])
                     .font_(Font("LCD 5x7 Segment Monospace", 11))
                     .focusColor_(Color.clear)
                     .action_({
                         var spacing, buttonW, totalUsedW, totalUsedH, extraW, extraH, startX, startY;
                         // Match red box exactly - get exact size and position of layoutOverlay
                         layoutBounds = ~layoutOverlay.bounds;
                         winWidth = layoutBounds.width - 3; // 2px less wide (was -1, now -3)
                         winHeight = layoutBounds.height - 3; // 2px less tall (was -1, now -3)
                         mainViewBounds = mainView.bounds;
                         winBounds = win.bounds;
                         winX = winBounds.left + mainViewBounds.left + layoutBounds.left + 2; // Move right 2px total
                         winY = winBounds.top + mainViewBounds.top + layoutBounds.top - 8; // Move down 8px total (in SuperCollider: -Y = down, +Y = up)
                         // 6x8 grid with even spacing
                         cols = 6; rows = 8;
                         spacing = 3; // Even spacing between buttons and to edges
                         // Calculate button size: 6 buttons with 7 spaces horizontally, 8 buttons with 9 spaces vertically
                         buttonW = ((winWidth - (7 * spacing)) / cols).floor;
                         buttonH = ((winHeight - (9 * spacing)) / rows).floor;
                         // Calculate total space used and distribute remainder evenly
                         totalUsedW = (cols * buttonW) + ((cols - 1) * spacing);
                         totalUsedH = (rows * buttonH) + ((rows - 1) * spacing);
                         extraW = (winWidth - totalUsedW) / 2; // Distribute remainder evenly left/right
                         extraH = (winHeight - totalUsedH) / 2; // Distribute remainder evenly top/bottom
                         startX = extraW.floor;
                         startY = extraH.floor;
                         chooserWin = Window.new("IRCAM IDs", Rect(winX, winY, winWidth, winHeight), border: false)
                             .alwaysOnTop_(true);
                         chooserView = CompositeView(chooserWin, chooserWin.view.bounds)
                             .background_(Color.black);
                         ~binauralIRCAMIds.do({ |id, i|
                             var r = (i / cols).floor; var c = i % cols;
                             if(r < rows) {
                                 var x = startX + (c * (buttonW + spacing));
                                 var y = startY + (r * (buttonH + spacing));
                                 var isLoaded = (id == ~binauralIRCAMId);
                                 Button(chooserView, Rect(x, y, buttonW, buttonH))
                                     .states_([
                                         [id.asString.padLeft(4, "0"), Color.cyan, Color.black], // Not loaded: cyan text on black
                                         [id.asString.padLeft(4, "0"), Color.black, Color.cyan]  // Loaded: black text on cyan
                                     ])
                                     .value_(if(isLoaded, 1, 0))
                                     .font_(Font("LCD 5x7 Segment Monospace", 11)) // Same size as encoder labels
                                     .focusColor_(Color.clear)
                                     .canFocus_(false) // Prevent focus to avoid border changes
                                     .action_({ |b|
                                         // Load HRTF directly when clicking grid button
                                         ~binauralIRCAMId = id;
                                         ~binauralIRCAMPendingId = id; // Keep in sync
                                         if(~binauralIrcamSelectBtn.notNil) {
                                             ~binauralIrcamSelectBtn.states_([[ (id.asString.padLeft(4, "0")), Color.cyan, Color.black ],
                                                                              [ (id.asString.padLeft(4, "0")), Color.cyan, Color.black ]]);
                                         };
                                         chooserWin.close;
                                         ~saveSynthParams.value();
                                         ~initAudioEngine.value();
                                     });
                             };
                         });
                         ~binauralIrcamChooserWin = chooserWin; // keep ref for cleanup
                         chooserWin.front;
                     });
                 ~binauralIrcamSelectBtn.front;

                // Clickable mute targets for headphone ears
                layoutBounds = ~layoutOverlay.bounds;
                centerX = layoutBounds.width / 2;
                centerY = layoutBounds.height / 2;
                moveUp = 16;
                earCupWidth = 20;
                earCupHeight = 27;
                earCupOffset = 55;
                leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                leftEarY = centerY + 25 + 25 - moveUp;
                rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                rightEarY = centerY + 25 + 25 - moveUp;

                if(~binauralLeftEarHit.notNil) { try { ~binauralLeftEarHit.remove; }; ~binauralLeftEarHit = nil; };
                if(~binauralRightEarHit.notNil) { try { ~binauralRightEarHit.remove; }; ~binauralRightEarHit = nil; };

                ~binauralLeftEarHit = UserView(~layoutOverlay, Rect(leftEarX, leftEarY, earCupWidth, earCupHeight))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~binauralState[\lOn] ? 1);
                        ~binauralState[\lOn] = newState;
                        if(~synth.notNil) { ~synth.set(\lOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~binauralLeftEarHit.front;

                ~binauralRightEarHit = UserView(~layoutOverlay, Rect(rightEarX, rightEarY, earCupWidth, earCupHeight))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~binauralState[\rOn] ? 1);
                        ~binauralState[\rOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~binauralRightEarHit.front;
             });
            // Binaural CIPIC (case 2) – HRTF selection menu and grid chooser
            if(~dmenu.value == 2, {
                var chooserWin, chooserView, cols, rows, cellW, cellH, padding, winWidth, winHeight, winX, winY, layoutBounds, mainViewBounds, winBounds, gridRows, gridSpacing, gridHeight, buttonH, labelWidth, dropdownWidth, totalWidth, groupStartX, labelX, dropdownX, yPos, centerX, centerY, moveUp, earCupWidth, earCupHeight, earCupOffset, leftEarX, leftEarY, rightEarX, rightEarY;
                ~binauralCIPICIds = [3, 8, 9, 10, 11, 12, 15, 17, 18, 19, 20, 21, 27, 28, 33, 40, 44, 48, 50, 51, 58, 59, 60, 61, 65, 119, 124, 126, 127, 131, 133, 134, 135, 137, 147, 148, 152, 153, 154, 155, 156, 158, 162, 163, 165];
                ~binauralCIPICPendingId = ~binauralCIPICId;

                layoutBounds = ~layoutOverlay.bounds;
                gridRows = 8; gridSpacing = 3;
                gridHeight = layoutBounds.height - 3;
                buttonH = ((gridHeight - (9 * gridSpacing)) / gridRows).floor;
                labelWidth = 90; dropdownWidth = 80; totalWidth = labelWidth + dropdownWidth;
                groupStartX = (320 - totalWidth) / 2;
                labelX = groupStartX;
                dropdownX = groupStartX + labelWidth;
                yPos = 240 - 7;

                ~binauralCipicProfileLabel = StaticText(~layoutOverlay, Rect(labelX, yPos, labelWidth, buttonH))
                    .string_("PROFILE")
                    .stringColor_(Color.cyan)
                    .font_(Font("LCD 5x7 Segment Monospace", 13))
                    .align_(\left)
                    .background_(Color.clear);
                ~binauralCipicProfileLabel.front;

                ~binauralCipicSelectBtn = Button(~layoutOverlay, Rect(dropdownX, yPos, dropdownWidth, buttonH))
                    .states_([[ (~binauralCIPICPendingId.asString.padLeft(4, "0")), Color.cyan, Color.black ],
                              [ (~binauralCIPICPendingId.asString.padLeft(4, "0")), Color.cyan, Color.black ]])
                    .font_(Font("LCD 5x7 Segment Monospace", 11))
                    .focusColor_(Color.clear)
                    .canFocus_(false)
                    .action_({
                        var spacing, buttonW, totalUsedW, totalUsedH, extraW, extraH, startX, startY;
                        spacing = 3; cols = 6; rows = 8;
                        layoutBounds = ~layoutOverlay.bounds;
                        winWidth = layoutBounds.width - 3;
                        winHeight = layoutBounds.height - 3;
                        mainViewBounds = mainView.bounds;
                        winBounds = win.bounds;
                        winX = winBounds.left + mainViewBounds.left + layoutBounds.left + 2; // Align with cyan box adjustments
                        winY = winBounds.top + mainViewBounds.top + layoutBounds.top - 8;
                        buttonW = ((winWidth - (7 * spacing)) / cols).floor;
                        buttonH = ((winHeight - (9 * spacing)) / rows).floor;
                        totalUsedW = (cols * buttonW) + ((cols - 1) * spacing);
                        totalUsedH = (rows * buttonH) + ((rows - 1) * spacing);
                        extraW = (winWidth - totalUsedW) / 2;
                        extraH = (winHeight - totalUsedH) / 2;
                        startX = extraW.floor;
                        startY = extraH.floor;
                        chooserWin = Window.new("CIPIC Profiles", Rect(winX, winY, winWidth, winHeight), border: false)
                            .alwaysOnTop_(true);
                        chooserView = CompositeView(chooserWin, chooserWin.view.bounds)
                            .background_(Color.black);
                        ~binauralCIPICIds.do({ |id, i|
                            var r = (i / cols).floor;
                            var c = i % cols;
                            if(r < rows) {
                                var cellX = startX + (c * (buttonW + spacing));
                                var cellY = startY + (r * (buttonH + spacing));
                                var isLoaded = (id == ~binauralCIPICId);
                                Button(chooserView, Rect(cellX, cellY, buttonW, buttonH))
                                    .states_([
                                        [id.asString.padLeft(4, "0"), Color.cyan, Color.black],
                                        [id.asString.padLeft(4, "0"), Color.black, Color.cyan]
                                    ])
                                    .value_(if(isLoaded, 1, 0))
                                    .font_(Font("LCD 5x7 Segment Monospace", 11))
                                    .focusColor_(Color.clear)
                                    .canFocus_(false)
                                    .action_({ |b|
                                        ~binauralCIPICId = id;
                                        ~binauralCIPICPendingId = id;
                                        if(~binauralCipicSelectBtn.notNil) {
                                            ~binauralCipicSelectBtn.states_([[ (id.asString.padLeft(4, "0")), Color.cyan, Color.black ],
                                                                             [ (id.asString.padLeft(4, "0")), Color.cyan, Color.black ]]);
                                        };
                                        chooserWin.close;
                                        ~saveSynthParams.value();
                                        ~initAudioEngine.value();
                                    });
                            };
                        });
                        ~binauralCipicChooserWin = chooserWin; // keep ref for cleanup
                        chooserWin.front;
                    });

                ~binauralCipicSelectBtn.front;

                // Clickable mute targets for headphone ears (CIPIC layout)
                layoutBounds = ~layoutOverlay.bounds;
                centerX = layoutBounds.width / 2;
                centerY = layoutBounds.height / 2;
                moveUp = 16;
                earCupWidth = 20;
                earCupHeight = 27;
                earCupOffset = 55;
                leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                leftEarY = centerY + 25 + 25 - moveUp;
                rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                rightEarY = centerY + 25 + 25 - moveUp;

                if(~binauralLeftEarHit.notNil) { try { ~binauralLeftEarHit.remove; }; ~binauralLeftEarHit = nil; };
                if(~binauralRightEarHit.notNil) { try { ~binauralRightEarHit.remove; }; ~binauralRightEarHit = nil; };

                ~binauralLeftEarHit = UserView(~layoutOverlay, Rect(leftEarX, leftEarY, earCupWidth, earCupHeight))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~binauralState[\lOn] ? 1);
                        ~binauralState[\lOn] = newState;
                        if(~synth.notNil) { ~synth.set(\lOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~binauralLeftEarHit.front;

                ~binauralRightEarHit = UserView(~layoutOverlay, Rect(rightEarX, rightEarY, earCupWidth, earCupHeight))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~binauralState[\rOn] ? 1);
                        ~binauralState[\rOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~binauralRightEarHit.front;
             });
            // QUAD WIDE (case 5) - positions match wider rectangle
            if(~dmenu.value == 5, {
                var rectWidth = 170, rectHeight = 120, diagramCenterX = 160;
                var rectLeft = diagramCenterX - (rectWidth / 2), rectTop = 78, speakerSize = 18;
                var frontLeftX = rectLeft - 9, frontLeftY = rectTop - 9;
                var frontRightX = rectLeft + rectWidth - 9, frontRightY = rectTop - 9;
                var surroundLeftX = rectLeft - 9, surroundLeftY = rectTop + rectHeight - 9 + 8;
                var surroundRightX = rectLeft + rectWidth - 9, surroundRightY = rectTop + rectHeight - 9 + 8;
                ~quadWideFLBtn = Button(~layoutOverlay, Rect(frontLeftX, frontLeftY, speakerSize, speakerSize))
                    .states_([["1", Color.black, Color.cyan],["1", Color.cyan, Color.black]]).font_(Font("Helvetica", 13).boldVariant).focusColor_(Color.clear)
                    .value_(if((~quadWideState[\flOn] ? 1) == 1, 0, 1)).action_({ |b| var ns=1-b.value; ~quadWideState[\flOn]=ns; if(~synth.notNil){~synth.set(\flOn,ns)}; b.focus(nil); });
                ~quadWideFRBtn = Button(~layoutOverlay, Rect(frontRightX, frontRightY, speakerSize, speakerSize))
                    .states_([["2", Color.black, Color.cyan],["2", Color.cyan, Color.black]]).font_(Font("Helvetica", 13).boldVariant).focusColor_(Color.clear)
                    .value_(if((~quadWideState[\frOn] ? 1) == 1, 0, 1)).action_({ |b| var ns=1-b.value; ~quadWideState[\frOn]=ns; if(~synth.notNil){~synth.set(\frOn,ns)}; b.focus(nil); });
                ~quadWideRLBtn = Button(~layoutOverlay, Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize))
                    .states_([["3", Color.black, Color.cyan],["3", Color.cyan, Color.black]]).font_(Font("Helvetica", 13).boldVariant).focusColor_(Color.clear)
                    .value_(if((~quadWideState[\rlOn] ? 1) == 1, 0, 1)).action_({ |b| var ns=1-b.value; ~quadWideState[\rlOn]=ns; if(~synth.notNil){~synth.set(\rlOn,ns)}; b.focus(nil); });
                ~quadWideRRBtn = Button(~layoutOverlay, Rect(surroundRightX, surroundRightY, speakerSize, speakerSize))
                    .states_([["4", Color.black, Color.cyan],["4", Color.cyan, Color.black]]).font_(Font("Helvetica", 13).boldVariant).focusColor_(Color.clear)
                    .value_(if((~quadWideState[\rrOn] ? 1) == 1, 0, 1)).action_({ |b| var ns=1-b.value; ~quadWideState[\rrOn]=ns; if(~synth.notNil){~synth.set(\rrOn,ns)}; b.focus(nil); });
                ~quadWideFLBtn.front; ~quadWideFRBtn.front; ~quadWideRLBtn.front; ~quadWideRRBtn.front;
            });
            // Octagon layout (case 8) - invisible hit targets for rotated squares
            if(~dmenu.value == 8, {
                var radius = 80, angleStep = 2 * pi / 8, startAngle = -22.5 * pi / 180;
                var centerX = 160, centerY = 137.5; // Match diagram center
                var speaker1Index, angle1, x1, y1, speaker2Index, angle2, x2, y2,
                    speaker3Index, angle3, x3, y3, speaker4Index, angle4, x4, y4,
                    speaker5Index, angle5, x5, y5, speaker6Index, angle6, x6, y6,
                    speaker7Index, angle7, x7, y7, speaker8Index, angle8, x8, y8; // declarations at top
                // Calculate position for speaker 1 (index 0 after shift: ((0 + 2) % 8) + 1 = 3, but we want 1, so need to find correct index)
                // Speaker 1 is at front-left: need to find which index gives speakerNum == 1
                speaker1Index = 6; // After shift: ((6 + 2) % 8) + 1 = 1
                angle1 = startAngle + (speaker1Index * angleStep);
                x1 = centerX + (radius * cos(angle1));
                y1 = centerY + (radius * sin(angle1)) + 25;
                // Invisible hit target for square 1 (20x20 square, centered on position)
                ~octagonS1Hit = UserView(~layoutOverlay, Rect(x1 - 10, y1 - 10, 20, 20))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~octagonState[\s1On] ? 1);
                        ~octagonState[\s1On] = newState;
                        // Apply mute to Speaker 1 in octagon mapping
                        if(~synth.notNil) { ~synth.set(\s1On, newState); };
                        // Refresh diagram to show new state
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~octagonS1Hit.front;
                
                // Invisible hit target for square 2 (20x20), mapped correctly
                speaker2Index = 7; // ((7 + 2) % 8) + 1 = 2
                angle2 = startAngle + (speaker2Index * angleStep);
                x2 = centerX + (radius * cos(angle2));
                y2 = centerY + (radius * sin(angle2)) + 25;
                ~octagonS2Hit = UserView(~layoutOverlay, Rect(x2 - 10, y2 - 10, 20, 20))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~octagonState[\s2On] ? 1);
                        ~octagonState[\s2On] = newState;
                        if(~synth.notNil) { ~synth.set(\s2On, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~octagonS2Hit.front;

                // Invisible hit target for square 3
                speaker3Index = 0; angle3 = startAngle + (speaker3Index * angleStep);
                x3 = centerX + (radius * cos(angle3));
                y3 = centerY + (radius * sin(angle3)) + 25;
                ~octagonS3Hit = UserView(~layoutOverlay, Rect(x3 - 10, y3 - 10, 20, 20))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~octagonState[\s3On] ? 1);
                        ~octagonState[\s3On] = newState;
                        if(~synth.notNil) { ~synth.set(\s3On, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~octagonS3Hit.front;
                // Invisible hit target for square 4
                speaker4Index = 1; angle4 = startAngle + (speaker4Index * angleStep);
                x4 = centerX + (radius * cos(angle4));
                y4 = centerY + (radius * sin(angle4)) + 25;
                ~octagonS4Hit = UserView(~layoutOverlay, Rect(x4 - 10, y4 - 10, 20, 20))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~octagonState[\s4On] ? 1);
                        ~octagonState[\s4On] = newState;
                        if(~synth.notNil) { ~synth.set(\s4On, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~octagonS4Hit.front;
                // Invisible hit target for square 5
                speaker5Index = 2; angle5 = startAngle + (speaker5Index * angleStep);
                x5 = centerX + (radius * cos(angle5));
                y5 = centerY + (radius * sin(angle5)) + 25;
                ~octagonS5Hit = UserView(~layoutOverlay, Rect(x5 - 10, y5 - 10, 20, 20))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~octagonState[\s5On] ? 1);
                        ~octagonState[\s5On] = newState;
                        if(~synth.notNil) { ~synth.set(\s5On, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~octagonS5Hit.front;

                // Invisible hit target for square 6
                speaker6Index = 3; angle6 = startAngle + (speaker6Index * angleStep);
                x6 = centerX + (radius * cos(angle6));
                y6 = centerY + (radius * sin(angle6)) + 25;
                ~octagonS6Hit = UserView(~layoutOverlay, Rect(x6 - 10, y6 - 10, 20, 20))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~octagonState[\s6On] ? 1);
                        ~octagonState[\s6On] = newState;
                        if(~synth.notNil) { ~synth.set(\s6On, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~octagonS6Hit.front;

                // Invisible hit target for square 7
                speaker7Index = 4; angle7 = startAngle + (speaker7Index * angleStep);
                x7 = centerX + (radius * cos(angle7));
                y7 = centerY + (radius * sin(angle7)) + 25;
                ~octagonS7Hit = UserView(~layoutOverlay, Rect(x7 - 10, y7 - 10, 20, 20))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~octagonState[\s7On] ? 1);
                        ~octagonState[\s7On] = newState;
                        if(~synth.notNil) { ~synth.set(\s7On, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~octagonS7Hit.front;
                // Invisible hit target for square 8
                speaker8Index = 5; angle8 = startAngle + (speaker8Index * angleStep);
                x8 = centerX + (radius * cos(angle8));
                y8 = centerY + (radius * sin(angle8)) + 25;
                ~octagonS8Hit = UserView(~layoutOverlay, Rect(x8 - 10, y8 - 10, 20, 20))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~octagonState[\s8On] ? 1);
                        ~octagonState[\s8On] = newState;
                        if(~synth.notNil) { ~synth.set(\s8On, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~octagonS8Hit.front;
            });
            // Create on/off buttons and faders for Dolby 5.1.2 (case 7)
            if(~dmenu.value == 7, {
                // All variable declarations must be at the absolute top of the block
                var layoutSize = 100, diagramCenterX = 80, layoutLeft = 30, layoutTop = 84, speakerSize = 18;
                var frontLeftX = 21, frontLeftY = 75;
                var frontRightX = 121, frontRightY = 75;
                var centerX_speaker = 71, centerY_speaker = 75;
                var surroundLeftX = 21, surroundLeftY = 182;
                var surroundRightX = 121, surroundRightY = 182;
                var subwooferX = 71, subwooferY = 132;
                var topFrontLeftX = 21, topFrontLeftY = 35;
                var topFrontRightX = 121, topFrontRightY = 35;
                var controlStartX = 170, controlY = 14, sliderWidth = 35, sliderHeight = 164, controlSpacing = 43;
                var rightmostFaderX;
                
                ("Creating controls for Dolby 5.1.2 (case 7), decoder value: " ++ ~dmenu.value).postln;
                // Speaker positions (matching drawFunc exactly for case 7)
                
                // Speaker 1: Front Left (FL)
                ~dolbyFLSquareBtn = Button(~layoutOverlay, Rect(frontLeftX, frontLeftY, speakerSize, speakerSize))
                    .states_([
                        ["1", Color.black, Color.cyan],
                        ["1", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\flOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\flOn] = newState;
                        if(~synth.notNil) { ~synth.set(\flOn, newState) };
                        btn.focus(nil);
                    });
                
                // Speaker 2: Front Right (FR)
                ~dolbyFRSquareBtn = Button(~layoutOverlay, Rect(frontRightX, frontRightY, speakerSize, speakerSize))
                    .states_([
                        ["2", Color.black, Color.cyan],
                        ["2", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\frOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\frOn] = newState;
                        if(~synth.notNil) { ~synth.set(\frOn, newState) };
                        btn.focus(nil);
                    });
                
                // Speaker 3: Rear Left (RL)
                ~dolbyRLSquareBtn = Button(~layoutOverlay, Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize))
                    .states_([
                        ["3", Color.black, Color.cyan],
                        ["3", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\rlOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\rlOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rlOn, newState) };
                        btn.focus(nil);
                    });
                
                // Speaker 4: Rear Right (RR)
                ~dolbyRRSquareBtn = Button(~layoutOverlay, Rect(surroundRightX, surroundRightY, speakerSize, speakerSize))
                    .states_([
                        ["4", Color.black, Color.cyan],
                        ["4", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\rrOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\rrOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rrOn, newState) };
                        btn.focus(nil);
                    });
                
                // Speaker 5: Center (C)
                ~dolbyCenterSquareBtn = Button(~layoutOverlay, Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize))
                    .states_([
                        ["5", Color.black, Color.cyan],
                        ["5", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\centerOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\centerOn] = newState;
                        if(~synth.notNil) { ~synth.set(\centerOn, newState) };
                        btn.focus(nil);
                    });
                
                // Speaker 6: Subwoofer (SUB)
                ~dolbySubSquareBtn = Button(~layoutOverlay, Rect(subwooferX, subwooferY, speakerSize, speakerSize))
                    .states_([
                        ["6", Color.black, Color.cyan],
                        ["6", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\subOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\subOn] = newState;
                        if(~synth.notNil) { ~synth.set(\subOn, newState) };
                        btn.focus(nil);
                    });
                // Speaker 7: Top Front Left (TL)
                ~dolbyTopLeftSquareBtn = Button(~layoutOverlay, Rect(topFrontLeftX, topFrontLeftY, speakerSize, speakerSize))
                    .states_([
                        ["7", Color.black, Color.cyan],
                        ["7", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\tflOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\tflOn] = newState;
                        if(~synth.notNil) { ~synth.set(\tflOn, newState) };
                        btn.focus(nil);
                    });
                
                // Speaker 8: Top Front Right (TR)
                ~dolbyTopRightSquareBtn = Button(~layoutOverlay, Rect(topFrontRightX, topFrontRightY, speakerSize, speakerSize))
                    .states_([
                        ["8", Color.black, Color.cyan],
                        ["8", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\tfrOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\tfrOn] = newState;
                        if(~synth.notNil) { ~synth.set(\tfrOn, newState) };
                        btn.focus(nil);
                    });
                
                // Fader controls for CENTER (now middle slot after swapping with SUB)
                StaticText(~layoutOverlay, Rect(controlStartX + controlSpacing, controlY, sliderWidth, 15))
                    .string_("C")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                ~dolbyCenterGainSlider = Slider(~layoutOverlay, Rect(controlStartX + controlSpacing, controlY + 18, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\centerGain] ? 0.0).linlin(-12, 12, 0, 1))
                    .action_({ |sl|
                        var gain = sl.value.linlin(0, 1, -12, 12);
                        ~dolbyState[\centerGain] = gain;
                        if(~dolbyCenterGainLabel.notNil) {
                            ~dolbyCenterGainLabel.string = gain.round(0.1).asString ++ "dB";
                        };
                        if(~synth.notNil) { ~synth.set(\centerGain, gain) };
                    });
                
                ~dolbyCenterGainLabel = StaticText(~layoutOverlay, Rect(controlStartX + controlSpacing, 199, sliderWidth, 15))
                    .string_((~dolbyState[\centerGain] ? 0.0).round(0.1).asString ++ "dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                // Fader controls for TOP (height/ceiling speakers) moved to leftmost slot
                StaticText(~layoutOverlay, Rect(controlStartX, controlY, sliderWidth, 15))
                    .string_("TOP")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                // Fader controls for SUB (moved to rightmost slot)
                StaticText(~layoutOverlay, Rect(controlStartX + (controlSpacing * 2), controlY, sliderWidth, 15))
                    .string_("SUB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                ~dolbySubGainSlider = Slider(~layoutOverlay, Rect(controlStartX + (controlSpacing * 2), controlY + 18, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\subGain] ? 0.0).linlin(-12, 12, 0, 1))
                    .action_({ |sl|
                        var gain = sl.value.linlin(0, 1, -12, 12);
                        ~dolbyState[\subGain] = gain;
                        if(~dolbySubGainLabel.notNil) {
                            ~dolbySubGainLabel.string = gain.round(0.1).asString ++ "dB";
                        };
                        if(~synth.notNil) { ~synth.set(\subGain, gain) };
                    });
                ~dolbySubGainLabel = StaticText(~layoutOverlay, Rect(controlStartX + (controlSpacing * 2), 199, sliderWidth, 15))
                    .string_((~dolbyState[\subGain] ? 0.0).round(0.1).asString ++ "dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                ~dolbyHeightGainSlider = Slider(~layoutOverlay, Rect(controlStartX, controlY + 18, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\heightGain] ? 0.0).linlin(-12, 12, 0, 1))
                    .action_({ |sl|
                        var gain = sl.value.linlin(0, 1, -12, 12);
                        ~dolbyState[\heightGain] = gain;
                        if(~dolbyHeightGainLabel.notNil) {
                            ~dolbyHeightGainLabel.string = gain.round(0.1).asString ++ "dB";
                        };
                        if(~synth.notNil) { ~synth.set(\heightGain, gain) };
                    });
                ~dolbyHeightGainLabel = StaticText(~layoutOverlay, Rect(controlStartX, 199, sliderWidth, 15))
                    .string_((~dolbyState[\heightGain] ? 0.0).round(0.1).asString ++ "dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                // dB scale labels (single set on the right, after TOP fader)
                rightmostFaderX = controlStartX + (controlSpacing * 2) + sliderWidth;
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 14, 20, 15))
                    .string_("+12")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + (sliderHeight / 4) - 7, 20, 15))
                    .string_("+6")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + (sliderHeight / 2) - 7, 20, 15))
                    .string_("0")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + (sliderHeight * 3 / 4) - 7, 20, 15))
                    .string_("-6")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + sliderHeight - 7, 20, 15))
                    .string_("-12")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                
                // Draw tick marks BETWEEN the faders (2 sets between the 3 faders)
                // Between CENTER and SUB
                UserView(~layoutOverlay, Rect(controlStartX + sliderWidth, controlY + 18, 8, sliderHeight))
                    .background_(Color.clear)
                    .drawFunc_({ |view|
                        Pen.color = Color.cyan;
                        Pen.width = 1.5;
                        // Major ticks
                        Pen.line(Point(2, 0), Point(6, 0)); Pen.stroke; // +12dB
                        Pen.line(Point(2, sliderHeight / 2), Point(6, sliderHeight / 2)); Pen.stroke; // 0dB
                        Pen.line(Point(2, sliderHeight), Point(6, sliderHeight)); Pen.stroke; // -12dB
                        // Minor ticks
                        Pen.width = 1;
                        Pen.line(Point(3, sliderHeight / 4), Point(5, sliderHeight / 4)); Pen.stroke; // +6dB
                        Pen.line(Point(3, sliderHeight * 3 / 4), Point(5, sliderHeight * 3 / 4)); Pen.stroke; // -6dB
                    });
                
                // Between SUB and TOP
                UserView(~layoutOverlay, Rect(controlStartX + controlSpacing + sliderWidth, controlY + 18, 8, sliderHeight))
                    .background_(Color.clear)
                    .drawFunc_({ |view|
                        Pen.color = Color.cyan;
                        Pen.width = 1.5;
                        // Major ticks
                        Pen.line(Point(2, 0), Point(6, 0)); Pen.stroke; // +12dB
                        Pen.line(Point(2, sliderHeight / 2), Point(6, sliderHeight / 2)); Pen.stroke; // 0dB
                        Pen.line(Point(2, sliderHeight), Point(6, sliderHeight)); Pen.stroke; // -12dB
                        // Minor ticks
                        Pen.width = 1;
                        Pen.line(Point(3, sliderHeight / 4), Point(5, sliderHeight / 4)); Pen.stroke; // +6dB
                        Pen.line(Point(3, sliderHeight * 3 / 4), Point(5, sliderHeight * 3 / 4)); Pen.stroke; // -6dB
                    });
                // Extra slender faders BELOW the diagram and vertical faders
                // TOP LPF - now top horizontal slender fader (swapped with SUB)
                ~dolbyTopHpfLabel = StaticText(~layoutOverlay, Rect((surroundLeftX + speakerSize) - 32 - 6 + 8, controlY + 18 + sliderHeight + 30 + 3, 56, 15))
                    .string_("TOP LPF")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                ~dolbyTopHpfSlider = Slider(~layoutOverlay, Rect((surroundLeftX + speakerSize) + 33, controlY + 18 + sliderHeight + 30, (((rightmostFaderX - 50) - (surroundLeftX + speakerSize)) - 9) - 2, 17))
                    .orientation_(\horizontal)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\topHPF] ? 180).linlin(80, 4000, 0, 1))
                    .action_({ |sl|
                        var hz = (sl.value.linlin(0, 1, 80, 4000) / 10).round * 10; // 80-4000 Hz, stepped in 10s
                        ~dolbyState[\topHPF] = hz;
                        if(~dolbyTopHpfValue.notNil) { ~dolbyTopHpfValue.string = hz.asInteger.asString ++ " Hz"; };
                        if(~synth.notNil) { ~synth.set(\topHPF, hz) };
                    });
                ~dolbyTopHpfValue = StaticText(~layoutOverlay, Rect(controlStartX + (rightmostFaderX - controlStartX) - 28, controlY + 18 + sliderHeight + 30 + 2, 44, 15))
                    .string_((((~dolbyState[\topHPF] ? 180) / 10).round * 10).asInteger.asString ++ " Hz")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                // SUB LPF - now bottom horizontal slender fader
                ~dolbySubLpfLabel = StaticText(~layoutOverlay, Rect((surroundLeftX + speakerSize) - 32 - 6 + 8, (controlY + 18 + sliderHeight + 30) + 18 + 6, 56, 15))
                    .string_("SUB LPF")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                ~dolbySubLpfSlider = Slider(~layoutOverlay, Rect((surroundLeftX + speakerSize) + 33, (controlY + 18 + sliderHeight + 30) + 22, (((rightmostFaderX - 50) - (surroundLeftX + speakerSize)) - 9) - 2, 17))
                    .orientation_(\horizontal)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\subLPF] ? 120).linlin(40, 200, 0, 1))
                    .action_({ |sl|
                        var hz = sl.value.linlin(0, 1, 40, 200); // 40-200 Hz
                        ~dolbyState[\subLPF] = hz;
                        if(~dolbySubLpfValue.notNil) { ~dolbySubLpfValue.string = hz.round.asInteger.asString ++ " Hz"; };
                        if(~synth.notNil) { ~synth.set(\subLPF, hz) };
                    });

                ~dolbySubLpfValue = StaticText(~layoutOverlay, Rect(controlStartX + (rightmostFaderX - controlStartX) - 28, (controlY + 18 + sliderHeight + 30 + 18) + 6, 44, 15))
                    .string_(((~dolbyState[\subLPF] ? 120)).round.asInteger.asString ++ " Hz")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                // Bring all buttons to front so they're clickable
                ~dolbyFLSquareBtn.front;
                ~dolbyFRSquareBtn.front;
                ~dolbyRLSquareBtn.front;
                ~dolbyRRSquareBtn.front;
                ~dolbyCenterSquareBtn.front;
                ~dolbySubSquareBtn.front;
                ~dolbyTopLeftSquareBtn.front;
                ~dolbyTopRightSquareBtn.front;
            });
            
            ~layoutOverlay.front;
        } {
            // Clean up all layout-specific controls when closing layout overlay
            // Remove Dolby controls overlay first (this removes all controls inside it)
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; };
            if(~binauralIrcamChooserWin.notNil) { try { ~binauralIrcamChooserWin.close; }; ~binauralIrcamChooserWin = nil; };
            if(~binauralCipicChooserWin.notNil) { try { ~binauralCipicChooserWin.close; }; ~binauralCipicChooserWin = nil; };
            if(~binauralIrcamSelectBtn.notNil) { try { ~binauralIrcamSelectBtn.remove; }; ~binauralIrcamSelectBtn = nil; };
            if(~binauralCipicSelectBtn.notNil) { try { ~binauralCipicSelectBtn.remove; }; ~binauralCipicSelectBtn = nil; };
            if(~binauralIrcamProfileLabel.notNil) { try { ~binauralIrcamProfileLabel.remove; }; ~binauralIrcamProfileLabel = nil; };
            if(~binauralCipicProfileLabel.notNil) { try { ~binauralCipicProfileLabel.remove; }; ~binauralCipicProfileLabel = nil; };
            if(~binauralLeftEarHit.notNil) { try { ~binauralLeftEarHit.remove; }; ~binauralLeftEarHit = nil; };
            if(~binauralRightEarHit.notNil) { try { ~binauralRightEarHit.remove; }; ~binauralRightEarHit = nil; };
            if(~stereoLeftHit.notNil) { try { ~stereoLeftHit.remove; }; ~stereoLeftHit = nil; };
            if(~stereoRightHit.notNil) { try { ~stereoRightHit.remove; }; ~stereoRightHit = nil; };
            if(~quadSquareFLHit.notNil) { try { ~quadSquareFLHit.remove; }; ~quadSquareFLHit = nil; };
            if(~quadSquareFRHit.notNil) { try { ~quadSquareFRHit.remove; }; ~quadSquareFRHit = nil; };
            if(~quadSquareRLHit.notNil) { try { ~quadSquareRLHit.remove; }; ~quadSquareRLHit = nil; };
            if(~quadSquareRRHit.notNil) { try { ~quadSquareRRHit.remove; }; ~quadSquareRRHit = nil; };
            if(~quadNarrowFLHit.notNil) { try { ~quadNarrowFLHit.remove; }; ~quadNarrowFLHit = nil; };
            if(~quadNarrowFRHit.notNil) { try { ~quadNarrowFRHit.remove; }; ~quadNarrowFRHit = nil; };
            if(~quadNarrowRLHit.notNil) { try { ~quadNarrowRLHit.remove; }; ~quadNarrowRLHit = nil; };
            if(~quadNarrowRRHit.notNil) { try { ~quadNarrowRRHit.remove; }; ~quadNarrowRRHit = nil; };
        }
    });
// --- DIMENSION OVERLAY BUTTON ---
~dimensionBtn = Button(mainView, Rect(290, 410, 100, 35))
    .states_([["DIMENSION", Color.cyan, Color.black], ["DIMENSION", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
    .focusColor_(Color.clear)
    .action_({ |btn|
        var knobWidth, knobHeight, knobSpacing, knobY, savedVals;
        var dimKnobSize, dimKnobY, dimLabelY, dimValueY, dimStartX, dimGap;
        var maplinKnobSize, maplinKnobY, maplinLabelY, maplinValueY, maplinStartX, maplinGap, maplinSavedVals;
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

            // Create Dimension overlay
            ~dimensionOverlay = View(mainView, Rect(180, 107, 320, 275)).background_(Color.black);

            // Border
            UserView(~dimensionOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });
            // (Removed center guide line)

            // (Removed title to reclaim vertical space)

            // Dimension controls: 3 knobs (Width, Width HPF, Output Trim) - Row 1
            // LF/HF Gain removed (only work with shelves, which are disabled)
            // Under-the-hood: shelvesMode, gerzonPresets, transitionFreq handled automatically
            // Layout: 320px overlay, 3 knobs @ 60px each, 10px gaps
            // 3 × 60px = 180px, 2 × 10px = 20px, total = 200px, margin = (320-200)/2 = 60px
            dimKnobSize = 60; dimGap = 10;
            dimStartX = 60; // Centered: (320 - (3*60 + 2*10))/2 = 60
            dimKnobY = 32; dimLabelY = 10; dimValueY = 97; // moved down by 2px
            
            savedVals = ~dimensionState[\sliderValues] ? [0.0, 0.5, 0.5]; // width, widthHPF (normalized), outputTrim (normalized 0-1)
            
            // Dimension labels above knobs (Row 1) - Positions adjusted: 35 (Width), 130 (Width HPF center), 225 (Trim)
            StaticText(~dimensionOverlay, Rect(35, dimLabelY, dimKnobSize, 16))
                .string_("WIDTH")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11).boldVariant)
                .background_(Color.clear);

            StaticText(~dimensionOverlay, Rect(130, dimLabelY, dimKnobSize, 16))
                .string_("W HPF")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11).boldVariant)
                .background_(Color.clear);
            
            StaticText(~dimensionOverlay, Rect(225, dimLabelY, dimKnobSize, 16))
                .string_("TRIM")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11).boldVariant)
                .background_(Color.clear);
            
            // Width knob (0.0 to 0.70) - Position: 35
            // Note: saved value is already normalized (0-1), where 1.0 = 0.70 width
            ~dimensionWidthKnob = Knob(~dimensionOverlay, Rect(35, dimKnobY, dimKnobSize, dimKnobSize))
                .value_(savedVals[0]) // Already normalized 0-1 (where 1.0 = 0.70 width)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    var val = knob.value * 0.70; // Convert normalized 0-1 to actual width 0.0-0.70
                    ~dimensionWidthValue.string_(val.round(0.01).asString);
                    ~dimensionState[\sliderValues][0] = knob.value; // Save normalized value
                    if(~synth.notNil) { ~synth.set(\dimensionWidth, val); };
                });
            
            // Width HPF knob (80 to 400 Hz) - Position: 130 (center)
            ~dimensionWidthHPFKnob = Knob(~dimensionOverlay, Rect(130, dimKnobY, dimKnobSize, dimKnobSize))
                .value_(savedVals[1]) // Already normalized 0-1
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    var val = knob.value.linlin(0, 1, 80, 400); // Convert normalized 0-1 to 80-400 Hz
                    ~dimensionWidthHPFValue.string_(val.round(1).asString ++ "Hz");
                    ~dimensionState[\sliderValues][1] = knob.value;
                    if(~synth.notNil) { ~synth.set(\dimensionWidthHPF, val); };
                });
            // Output Trim knob (-6 to +6 dB) - Position: 225
            ~dimensionTrimKnob = Knob(~dimensionOverlay, Rect(225, dimKnobY, dimKnobSize, dimKnobSize))
                .value_(savedVals[2]) // Already normalized 0-1
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    var val = knob.value.linlin(0, 1, -6, 6);  // Reduced from -18/+18 to -6/+6 dB
                    var displayVal = if(val >= 0, "+" ++ val.round(0.1).asString, val.round(0.1).asString);
                    ~dimensionTrimValue.string_(displayVal ++ "dB");
                    ~dimensionState[\sliderValues][2] = knob.value;
                    if(~synth.notNil) { ~synth.set(\dimensionOutputTrim, val); };
                });
            
            // Dimension value displays below knobs - Positions adjusted: 35 (Width), 130 (Width HPF center), 225 (Trim)
            ~dimensionWidthValue = StaticText(~dimensionOverlay, Rect(35, dimValueY - 3, dimKnobSize, 16))
                .string_("0.00")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            
            ~dimensionWidthHPFValue = StaticText(~dimensionOverlay, Rect(130, dimValueY - 3, dimKnobSize, 16))
                .string_("180Hz")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            
            ~dimensionTrimValue = StaticText(~dimensionOverlay, Rect(225, dimValueY - 3, dimKnobSize, 16))
                .string_("0.0dB")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            // Maplin SM-333 controls: 3 knobs (Surround, Effect, Delay) - Row 2
            // Layout: 320px overlay, 3 knobs @ 60px each, 10px gaps
            // 3 × 60px = 180px, 2 × 10px = 20px, total = 200px, margin = (320-200)/2 = 60px
            // All moved up by 4px; row previously moved 20px; now shift down 2px for alignment
            maplinKnobSize = 60; maplinKnobY = 139; maplinLabelY = 118; maplinValueY = 203;
            maplinStartX = 60; maplinGap = 10;
            maplinSavedVals = ~maplinState;
            
            // Maplin ON/OFF button will be placed at bottom (where RESET was)
            
            // Maplin labels above knobs (Row 2) - SURROUND expanded 2px each side (64px width, x=58)
            StaticText(~dimensionOverlay, Rect(33, maplinLabelY, 64, 16))
                .string_("SURROUND")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11).boldVariant)
                .background_(Color.clear);
            
            StaticText(~dimensionOverlay, Rect(130, maplinLabelY, maplinKnobSize, 16))
                .string_("EFFECT")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11).boldVariant)
                .background_(Color.clear);
            
            StaticText(~dimensionOverlay, Rect(225, maplinLabelY, maplinKnobSize, 16))
                .string_("DELAY")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11).boldVariant)
                .background_(Color.clear);
            
            // Maplin Surround knob - Position: 35
            ~maplinSurroundKnob = Knob(~dimensionOverlay, Rect(35, maplinKnobY, maplinKnobSize, maplinKnobSize))
                .value_(maplinSavedVals[\surround] ? 0.8)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    ~setMaplinSurround.(knob.value);
                    ~maplinSurroundValue.string_((knob.value * 100).round(1).asString ++ "%");
                });
            
            // Maplin Effect knob - Position: 130 (center)
            ~maplinEffectKnob = Knob(~dimensionOverlay, Rect(130, maplinKnobY, maplinKnobSize, maplinKnobSize))
                .value_(maplinSavedVals[\effect] ? 0.8)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    ~setMaplinEffect.(knob.value);
                    ~maplinEffectValue.string_((knob.value * 100).round(1).asString ++ "%");
                });
            
            // Maplin Delay knob - Position: 225
            ~maplinDelayKnob = Knob(~dimensionOverlay, Rect(225, maplinKnobY, maplinKnobSize, maplinKnobSize))
                .value_(maplinSavedVals[\delay] ? 0.4)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    ~setMaplinDelay.(knob.value);
                    ~maplinDelayValue.string_((knob.value.linlin(0, 1, 5, 50).round(1).asString ++ " ms"));
                });
            
            // Maplin value displays below knobs - Positions adjusted: 35, 110, 225
            ~maplinSurroundValue = StaticText(~dimensionOverlay, Rect(35, maplinValueY - 3, maplinKnobSize, 16))
                .string_("80%")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            
            ~maplinEffectValue = StaticText(~dimensionOverlay, Rect(130, maplinValueY - 3, maplinKnobSize, 16))
                .string_("80%")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            ~maplinDelayValue = StaticText(~dimensionOverlay, Rect(225, maplinValueY - 3, maplinKnobSize, 16))
                .string_("25 ms")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);

            // Initialize value displays
            ~dimensionWidthKnob.action.value(~dimensionWidthKnob);
            ~dimensionWidthHPFKnob.action.value(~dimensionWidthHPFKnob);
            ~dimensionTrimKnob.action.value(~dimensionTrimKnob);
            ~maplinSurroundKnob.action.value(~maplinSurroundKnob);
            ~maplinEffectKnob.action.value(~maplinEffectKnob);
            ~maplinDelayKnob.action.value(~maplinDelayKnob);

            // Maplin & Dimension ON/OFF button (where RESET was) - controls both Maplin and Dimension
            ~maplinActiveBtn = Button(~dimensionOverlay, Rect(18, 230, 80, 28))
                .states_([
                    ["ON", Color.black, Color.cyan],
                    ["ON", Color.cyan, Color.black]
                ])
                .action_({ |button|
                    ~setMaplinActive.(button.value == 0);  // Controls both Maplin and Dimension
                })
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .value_(if((maplinSavedVals[\active] ? 1) == 1, 0, 1)); // 0 = ON (button state 0), 1 = OFF (button state 1)

            // RESET button (where CLOSE was)
            Button(~dimensionOverlay, Rect(222, 230, 80, 28))
                .states_([["RESET", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .action_({
                    // Reset Dimension to default values
                    ~dimensionWidthKnob.value_(0.0);
                    ~dimensionWidthHPFKnob.value_(0.5); // Default 180Hz
                    ~dimensionTrimKnob.value_(0.5);
                    ~dimensionWidthKnob.action.value(~dimensionWidthKnob);
                    ~dimensionWidthHPFKnob.action.value(~dimensionWidthHPFKnob);
                    ~dimensionTrimKnob.action.value(~dimensionTrimKnob);
                    // Reset Maplin to default values
                    ~maplinSurroundKnob.value_(0.8);
                    ~maplinEffectKnob.value_(0.8);
                    ~maplinDelayKnob.value_(0.4);
                    if(~maplinActiveBtn.notNil) {
                        ~maplinActiveBtn.value_(0); // Default to ON (button state 0 = ON)
                        ~dimensionActive = 1;  // Reset Dimension active state to ON
                    };
                    ~maplinSurroundKnob.action.value(~maplinSurroundKnob);
                    ~maplinEffectKnob.action.value(~maplinEffectKnob);
                    ~maplinDelayKnob.action.value(~maplinDelayKnob);
                    if(~maplinActiveBtn.notNil) {
                        ~maplinActiveBtn.action.value(~maplinActiveBtn);
                    };
                });

            // CLOSE button removed - pressing Dimension button again closes the overlay
            ~dimensionOverlay.front;
            ~dimensionBtn.value_(1);
            
            // Restore saved state after overlay is created
            ~restoreDimensionState.value();
            ~restoreMaplinState.value(); // Restore Maplin state too
            
            // Update visibility based on current encoder selection
            ~updateDimensionOverlayVisibility.value();
            
            // If Maplin encoder is selected, ensure Maplin knobs send values to synth immediately
            if(configKeyE == \maplin and: { ~maplinSurroundKnob.notNil }) {
                // Trigger knob actions to send values to synth
                ~maplinSurroundKnob.action.value(~maplinSurroundKnob);
                ~maplinEffectKnob.action.value(~maplinEffectKnob);
                ~maplinDelayKnob.action.value(~maplinDelayKnob);
                
            };

        } {
            if(~dimensionOverlay.notNil) {
                // Remove overlays
                if(~dimensionRowOverlay.notNil) { ~dimensionRowOverlay.remove; ~dimensionRowOverlay = nil; };
                if(~maplinRowOverlay.notNil) { ~maplinRowOverlay.remove; ~maplinRowOverlay = nil; };
                ~dimensionOverlay.remove;
                ~dimensionOverlay = nil;
                ~dimensionBtn.value_(0);
            };
        }
    });
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

// ... existing code ...
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