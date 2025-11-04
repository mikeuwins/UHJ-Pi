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
    \sliderValues, [0.0, 0.2, 0.2, 0.2, 0.0, 0.0, 0.0],  // Default values
    \presetIndex, 0,  // Default preset index
    \lastMix, 0.5     // Remember last nonzero mix value
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
                        \MAPLIN -> { |a| configKeyE = \maplin; ("Encoder: MAPLIN").postln; },
                        \PHJ -> { |a| configKeyE = \phj; ("Encoder: PHJ").postln; }
                    ],
    globalAction: { |menu|
        // Update maplinMode on existing synth if it exists (for Maplin encoder only)
        if(~synth.notNil) {
            ~synth.set(\maplinMode, if(configKeyE == \maplin, 1, 0));
            ("Updated maplinMode to: " ++ if(configKeyE == \maplin, 1, 0)).postln;
        
            // If switching to Maplin encoder, send current Maplin parameter values to synth
            if(configKeyE == \maplin) {
                ~synth.set(
                    \maplinSurround, ~maplinState[\surround] ? 0.8,
                    \maplinEffect, ~maplinState[\effect] ? 0.8,
                    \maplinDelay, ~maplinState[\delay] ? 0.4,
                    \maplinActive, ~maplinState[\active] ? 1  // 1 = active, 0 = bypass
                );
                ("Maplin parameters sent to synth: surround=" ++ (~maplinState[\surround] ? 0.8) ++ ", effect=" ++ (~maplinState[\effect] ? 0.8) ++ ", delay=" ++ (~maplinState[\delay] ? 0.4) ++ ", active=" ++ (~maplinState[\active] ? 1)).postln;
            };
            // Always send Dimension active state (works for all encoders)
            ~synth.set(\dimensionActive, ~dimensionActive ? 1);
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

// Decoder menu (Output format selection)
~dmenu = EZPopUpMenu.new(
    mainView,
    Rect(360, 45, 140, 35),
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
            }
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
                        \binaural, FoaDecoderKernel.newListen(1053),
                        \binaurac, FoaDecoderKernel.newCIPIC(12),
                        \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                        \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                        \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual'),
                        \fivezero, FoaDecoderMatrix.new5_0(irregKind: 'focused'),
                        \octagon, FoaDecoderMatrix.newPanto(8, 'flat', k: 'single'),
                        \stereo, FoaDecoderMatrix.newStereo,
                        \fiveonetwo, Foa512Matrix.newFoaDecoder(\equal, 45, \uhjpi)  // 5.1.2 decoder (custom matrix with heights, UHJ Pi layout, equal mode)
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
                    SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, quadLR = 0, quadFR = 0, ambience = 0, preDelay = 0, lowRT = 0.2, highRT = 2, dispersion = 1, modWidth = 0.2, modRate = 0.3, eq1 = 0, eq2 = 0, eq3 = 0, eq4 = 0, eq5 = 0, eq6 = 0, eq7 = 0, maplinSurround = 0.8, maplinEffect = 0.8, maplinDelay = 0.4, maplinActive = 1, maplinMode = 0, dimensionWidth = 0.0, dimensionWidthHPF = 180, dimensionLFGain = 0, dimensionHFGain = 0, dimensionOutputTrim = 0, dimensionShelvesMode = 0, dimensionGerzonPresets = 0, dimensionActive = 1, zsynthHeightAmount = 30, zsynthHeightDelay = 7, zsynthHeightTrim = 0, zsynthHeightSource = 0, zsynthAmbienceSize = 2.5, zsynthAmbienceDampening = 0.2, zsynthAmbienceMix = 70|
                        var out, src, trans, encode, dimensioned, zsynth, ambient, eqed, frontStereo, rearStereo, quadOutFront, quadOutRear, maplinQuad, encodeInput;
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
                        
                        // Ambience processing (AmbiVerbSC reverb)
                        ambient = AmbiVerbSC.ar(zsynth,
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
                            // out[0]=LF, out[1]=FR, out[2]=RL, out[3]=RR
                            frontStereo = Balance2.ar(out[0], out[3], quadLR); // LF, FR
                            rearStereo  = Balance2.ar(out[1], out[2], quadLR); // RL, RR
                            quadOutFront = frontStereo * ((quadFR + 1) * 0.5); // scale front by 0..1
                            quadOutRear  = rearStereo  * ((1 - quadFR) * 0.5); // scale rear by 1..0
                            out = [
                                quadOutFront[0], // LF (Speaker 1)
                                quadOutFront[1], // FR (Speaker 2)
                                quadOutRear[0],  // RL (Speaker 3)
                                quadOutRear[1]   // RR (Speaker 4)
                            ];
                        });
                        if(outputs == 6, {
                            // --- DOLBY 5.1 OUTPUT MAPPING (Consumer Standard) ---
                            // ATK 5.0 decoder: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR
                            // Map to consumer standard: [1] FL, [2] FR, [3] C, [4] RL, [5] RR, [6] Sub
                            var lowpass = BLowPass.ar((out[1] + out[4]), 120, 1, 0.4); // Sum FL + FR for sub
                            out = [
                                out[1], // FL (Speaker 1) - Front Left
                                out[4], // FR (Speaker 2) - Front Right  
                                out[0], // C  (Speaker 3) - Center
                                out[2], // RL (Speaker 4) - Rear Left
                                out[3], // RR (Speaker 5) - Rear Right
                                lowpass // Sub (Speaker 6) - Subwoofer
                            ];
                        });
                        
                        if(outputs == 8, {
                            if(configKeyD == \fiveonetwo, {
                                // --- UHJ-PI 5.1.2 OUTPUT MAPPING ---
                                // Decoder outputs: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR, out[5]=TFR, out[6]=TFL (correct for UHJ-Pi)
                                // UHJ-Pi layout: [0] FL, [1] FR, [2] C, [3] RL, [4] RR, [5] LFE, [6] TFL, [7] TFR
                                var lowpass = BLowPass.ar((out[1] + out[4]), 120, 1, 0.4); // Sum FL + FR for LFE
                                out = [
                                    out[1], // FL (Speaker 1) - Front Left
                                    out[4], // FR (Speaker 2) - Front Right  
                                    out[0], // C  (Speaker 3) - Center
                                    out[2], // RL (Speaker 4) - Rear Left
                                    out[3], // RR (Speaker 5) - Rear Right
                                    lowpass, // LFE (Speaker 6) - Low Frequency Effects
                                    out[6], // TFL (Speaker 7) - Top Front Left
                                    out[5]  // TFR (Speaker 8) - Top Front Right
                                ];
                            }, {
                                // --- OCTAGON OUTPUT MAPPING (Clockwise from Front Left) ---
                                // ATK 8.0 decoder: Anti-clockwise from front left out[0]
                                // Map to diagram: Clockwise from front left starting at Speaker 1
                                out = [
                                    out[0], // Speaker 1: Front Left (FL)
                                    out[7], // Speaker 2: Front Left Center (FLC)
                                    out[6], // Speaker 3: Center (C)
                                    out[5], // Speaker 4: Front Right Center (FRC)
                                    out[4], // Speaker 5: Front Right (FR)
                                    out[3], // Speaker 6: Rear Right Center (RRC)
                                    out[2], // Speaker 7: Rear Right (RR)
                                    out[1]  // Speaker 8: Rear Left Center (RLC)
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
                        \zsynthAmbienceMix, zsMix
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
                            \binaural, FoaDecoderKernel.newListen(1053),
                            \binaurac, FoaDecoderKernel.newCIPIC(12),
                            \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                            \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                            \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual'),
                            \fivezero, FoaDecoderMatrix.new5_0(irregKind: 'focused'),
                            \octagon, FoaDecoderMatrix.newPanto(8, 'flat', k: 'single'),
                            \stereo, FoaDecoderMatrix.newStereo,
                            \fiveonetwo, Foa512Matrix.newFoaDecoder(\equal, 45, \uhjpi)  // 5.1.2 decoder (custom matrix with heights, UHJ Pi layout, equal mode)
                        ]);

                        // Get selected encoder and decoder
                        encoder = encoderDict.at(configKeyE ? \uhj);
                        decoder = decoderDict.at(configKeyD ? \stereo);

                        ("Audio engine initialized with encoder: " ++ configKeyE ++ " and decoder: " ++ configKeyD).postln;

                        // Load test audio file (same as MainApp2)
                        // sndbuf = Buffer.read(s, Atk.userSoundsDir ++ "/uhj/Sodium_Sunrise_UHJ.wav");

                        s.sync(cond);

                        // Define the main audio processing SynthDef (adapted from MainApp2)
                        SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, quadLR = 0, quadFR = 0, ambience = 0, preDelay = 0, lowRT = 0.2, highRT = 2, dispersion = 1, modWidth = 0.2, modRate = 0.3, eq1 = 0, eq2 = 0, eq3 = 0, eq4 = 0, eq5 = 0, eq6 = 0, eq7 = 0, maplinSurround = 0.8, maplinEffect = 0.8, maplinDelay = 0.4, maplinActive = 1, maplinMode = 0, dimensionWidth = 0.0, dimensionWidthHPF = 180, dimensionLFGain = 0, dimensionHFGain = 0, dimensionOutputTrim = 0, dimensionShelvesMode = 0, dimensionGerzonPresets = 0, dimensionActive = 1, zsynthHeightAmount = 30, zsynthHeightDelay = 7, zsynthHeightTrim = 0, zsynthHeightSource = 0, zsynthAmbienceSize = 2.5, zsynthAmbienceDampening = 0.2, zsynthAmbienceMix = 70|
                            var out, src, trans, encode, dimensioned, zsynth, ambient, eqed, frontStereo, rearStereo, quadOutFront, quadOutRear, maplinQuad, encodeInput;
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
                            
                            // Ambience processing (AmbiVerbSC reverb)
                            ambient = AmbiVerbSC.ar(zsynth,
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
                            if(outputs == 4, {
                                // --- Q-PANNER LOGIC (Balance2) ---
                                // out[0]=LF, out[1]=FR, out[2]=RL, out[3]=RR
                                frontStereo = Balance2.ar(out[0], out[3], quadLR); // LF, FR
                                rearStereo  = Balance2.ar(out[1], out[2], quadLR); // RL, RR
                                quadOutFront = frontStereo * ((quadFR + 1) * 0.5); // scale front by 0..1
                                quadOutRear  = rearStereo  * ((1 - quadFR) * 0.5); // scale rear by 1..0
                                out = [
                                    quadOutFront[0], // LF (Speaker 1)
                                    quadOutFront[1], // FR (Speaker 2)
                                    quadOutRear[0],  // RL (Speaker 3)
                                    quadOutRear[1]   // RR (Speaker 4)
                                ];
                            });
                            if(outputs == 6, {
                                // --- DOLBY 5.1 OUTPUT MAPPING (Consumer Standard) ---
                                // ATK 5.0 decoder: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR
                                // Map to consumer standard: [1] FL, [2] FR, [3] C, [4] RL, [5] RR, [6] Sub
                                var lowpass = BLowPass.ar((out[1] + out[4]), 120, 1, 0.4); // Sum FL + FR for sub
                                out = [
                                    out[1], // FL (Speaker 1) - Front Left
                                    out[4], // FR (Speaker 2) - Front Right  
                                    out[0], // C  (Speaker 3) - Center
                                    out[2], // RL (Speaker 4) - Rear Left
                                    out[3], // RR (Speaker 5) - Rear Right
                                    lowpass // Sub (Speaker 6) - Subwoofer
                                ];
                            });
                            
                            if(outputs == 8, {
                                if(configKeyD == \fiveonetwo, {
                                    // --- UHJ-PI 5.1.2 OUTPUT MAPPING ---
                                    // Decoder outputs: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR, out[5]=TFL, out[6]=TFR (matches ATK 5.0 order)
                                    // UHJ-Pi layout: [0] FL, [1] FR, [2] C, [3] RL, [4] RR, [5] LFE, [6] TFL, [7] TFR
                                    var lowpass = BLowPass.ar((out[1] + out[4]), 120, 1, 0.4); // Sum FL + FR for LFE
                                    out = [
                                        out[1], // FL (Speaker 1) - Front Left
                                        out[4], // FR (Speaker 2) - Front Right  
                                        out[0], // C  (Speaker 3) - Center
                                        out[2], // RL (Speaker 4) - Rear Left
                                        out[3], // RR (Speaker 5) - Rear Right
                                        lowpass, // LFE (Speaker 6) - Low Frequency Effects
                                        out[5], // TFL (Speaker 7) - Top Front Left
                                        out[6]  // TFR (Speaker 8) - Top Front Right
                                    ];
                                }, {
                                    // --- OCTAGON OUTPUT MAPPING (Clockwise from Front Left) ---
                                    // ATK 8.0 decoder: Anti-clockwise from front left out[0]
                                    // Map to diagram: Clockwise from front left starting at Speaker 1
                                    out = [
                                        out[0], // Speaker 1: Front Left (FL)
                                        out[7], // Speaker 2: Front Left Center (FLC)
                                        out[6], // Speaker 3: Center (C)
                                        out[5], // Speaker 4: Front Right Center (FRC)
                                        out[4], // Speaker 5: Front Right (FR)
                                        out[3], // Speaker 6: Rear Right Center (RRC)
                                        out[2], // Speaker 7: Rear Right (RR)
                                        out[1]  // Speaker 8: Rear Left Center (RLC)
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
                            \maplinActive, ~maplinState[\active] ? 1,  // 1 = active, 0 = bypass
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
                            \zsynthAmbienceMix, zsMix2
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
            // AMBIENCE PRESETS label (matches EQ title placement)
            StaticText(~ambienceOverlay, Rect(10, 7, 160, 20))
                .string_("AMBIENCE PRESETS")
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
            
            // ON/OFF button (replaces RESET position) - same size/style as RESET, no focus border
            ~ambienceOnOffBtn = Button(~ambienceOverlay, Rect(18, 230, 80, 28))
                .states_([["ON", Color.cyan, Color.black], ["ON", Color.black, Color.cyan]])
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

            // ENHANCE button (centered) - toggles Z source (Original vs Synthesized)
            // Always shows label "ENHANCE"; color indicates state
            ~ambienceEnhanceBtn = Button(~ambienceOverlay, Rect(120, 230, 80, 28))
                .states_([["ENHANCE", Color.cyan, Color.black], ["ENHANCE", Color.black, Color.cyan]])
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
            ~layoutOverlay = View(mainView, Rect(180, 107, 320, 275))
                .background_(Color.black); // Remove .alpha_(0.5) for full opacity
            // Add the title as StaticText at the top, centered
            // Layout title showing encoder class only
            ~layoutTitleText = StaticText(~layoutOverlay, Rect(10, 5, 300, 22))
                .string_(([
                    "STEREO",
                    "BINAURAL IRCAM",
                    "BINAURAL CIPIC",
                    "QUADRAPHONIC SQUARE",
                    "QUADRAPHONIC NARROW",
                    "QUADRAPHONIC WIDE",
                    "DOLBY 5.1",
                    "DOLBY 5.1.2",
                    "OCTAGON"
                ][~dmenu.value ? 0]))
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
                            
                            // Draw triangle linestesting on 
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
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare, centerY - halfSquare + 25, squareSize, squareSize)); Pen.stroke;
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + 25, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + 25, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(centerX - halfSquare - 3, centerY - halfSquare - 9 + 25), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + 25, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + 25, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(centerX - halfSquare - 3 + squareSize, centerY - halfSquare - 9 + 25), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 3: Rear Left
                            Pen.color = Color.black; Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + squareSize + 25, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + squareSize + 25, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(centerX - halfSquare - 3, centerY - halfSquare - 10 + squareSize + 1 + 25), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 4: Rear Right
                            Pen.color = Color.black; Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + squareSize + 25, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + squareSize + 25, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(centerX - halfSquare - 3 + squareSize, centerY - halfSquare - 10 + squareSize + 1 + 25), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("[1] FL, [2] FR, [3] RL, [4] RR", Point(centerX - 82, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        4, { // Quad Narrow
                            var rectHeight = 140, rectWidth = (rectHeight * 0.75).asInteger, rectLeft = centerX - (rectWidth / 2), rectTop = centerY - (rectHeight / 2) + 25;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight)); Pen.stroke;
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(rectLeft - 3, rectTop - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rectLeft + rectWidth - 3, rectTop - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 3: Rear Left
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(rectLeft - 3, rectTop + rectHeight - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 4: Rear Right
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(rectLeft + rectWidth - 3, rectTop + rectHeight - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("[1] FL, [2] FR, [3] RL, [4] RR", Point(centerX - 82, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        5, { // Quad Wide
                            var rectWidth = 140, rectHeight = 105, rectLeft = centerX - (rectWidth / 2), totalHeight = rectHeight + 20, rectTop = centerY - (totalHeight / 2) + 10 + 25;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight)); Pen.stroke;
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(rectLeft - 3, rectTop - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rectLeft + rectWidth - 3, rectTop - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 3: Rear Left
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(rectLeft - 3, rectTop + rectHeight - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 4: Rear Right
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(rectLeft + rectWidth - 3, rectTop + rectHeight - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("[1] FL, [2] FR, [3] RL, [4] RR", Point(centerX - 82, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        6, { // Dolby 5.1
                            var layoutSize = 140, layoutLeft = centerX - (layoutSize / 2), layoutTop = centerY - (layoutSize / 2) + 25, speakerSize = 20, frontLeftX = layoutLeft - 10, frontLeftY = layoutTop - 10, frontRightX = layoutLeft + layoutSize - 10, frontRightY = layoutTop - 10, centerX_speaker = layoutLeft + (layoutSize / 2) - 10, centerY_speaker = layoutTop - 10, surroundLeftX = layoutLeft - 10, surroundLeftY = layoutTop + layoutSize - 10, surroundRightX = layoutLeft + layoutSize - 10, surroundRightY = layoutTop + layoutSize - 10, subwooferX = layoutLeft + (layoutSize / 2) - 10, subwooferY = layoutTop + (layoutSize / 2) - 10;
                            Pen.color = Color.cyan; Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize)); Pen.stroke;
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 7, frontLeftY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 7, frontRightY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 3: Center
                            Pen.color = Color.black; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(centerX_speaker + 7, centerY_speaker + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 4: Surround Left
                            Pen.color = Color.black; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundLeftX + 7, surroundLeftY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 5: Surround Right
                            Pen.color = Color.black; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("5", Point(surroundRightX + 7, surroundRightY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 6: Subwoofer (Sub = 6)
                            Pen.color = Color.cyan; Pen.addRect(Rect(subwooferX, subwooferY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("6", Point(subwooferX + 7, subwooferY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("SUB", Point(subwooferX + 25, subwooferY + 3), Font("Helvetica", 10).boldVariant, Color.cyan);
                            Pen.stringAtPoint("[1] FL, [2] FR, [3] C, [4] RL, [5] RR, [6] Sub", Point(centerX - 124, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        7, { // Dolby Atmos 5.1.2
                            var layoutSize = 140, layoutLeft = centerX - (layoutSize / 2), layoutTop = centerY - (layoutSize / 2) + 25, speakerSize = 20;
                            var frontLeftX = layoutLeft - 10, frontLeftY = layoutTop - 10;
                            var frontRightX = layoutLeft + layoutSize - 10, frontRightY = layoutTop - 10;
                            var centerX_speaker = layoutLeft + (layoutSize / 2) - 10, centerY_speaker = layoutTop - 10;
                            var surroundLeftX = layoutLeft - 10, surroundLeftY = layoutTop + layoutSize - 10;
                            var surroundRightX = layoutLeft + layoutSize - 10, surroundRightY = layoutTop + layoutSize - 10;
                            var subwooferX = layoutLeft + (layoutSize / 2) - 10, subwooferY = layoutTop + (layoutSize / 2) - 10;
                            var topFrontLeftX = frontLeftX, topFrontLeftY = layoutTop - 40;  // Directly above speaker 1 (FL)
                            var topFrontRightX = frontRightX, topFrontRightY = layoutTop - 40;  // Directly above speaker 2 (FR)
                            
                            Pen.color = Color.cyan; Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize)); Pen.stroke;
                            
                            // --- EXACTLY THE SAME AS 5.1 LAYOUT ---
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 7, frontLeftY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 7, frontRightY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            
                            // Speaker 3: Center
                            Pen.color = Color.black; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(centerX_speaker + 7, centerY_speaker + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            
                            // Speaker 4: Surround Left
                            Pen.color = Color.black; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundLeftX + 7, surroundLeftY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            
                            // Speaker 5: Surround Right
                            Pen.color = Color.black; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("5", Point(surroundRightX + 7, surroundRightY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            
                            // Speaker 6: Subwoofer (Sub = 6)
                            Pen.color = Color.cyan; Pen.addRect(Rect(subwooferX, subwooferY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("6", Point(subwooferX + 7, subwooferY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("SUB", Point(subwooferX + 25, subwooferY + 3), Font("Helvetica", 10).boldVariant, Color.cyan);
                            
                            // --- ADDITIONAL CEILING SPEAKERS FOR 5.1.2 ---
                            // Speaker 7: Top Front Left (overhead) - positioned above front left
                            Pen.color = Color.black; Pen.addRect(Rect(topFrontLeftX, topFrontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(topFrontLeftX, topFrontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("7", Point(topFrontLeftX + 7, topFrontLeftY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            
                            // Speaker 8: Top Front Right (overhead) - positioned above front right
                            Pen.color = Color.black; Pen.addRect(Rect(topFrontRightX, topFrontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(topFrontRightX, topFrontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("8", Point(topFrontRightX + 7, topFrontRightY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            
                            Pen.stringAtPoint("[1] FL, [2] FR, [3] C, [4] RL, [5] RR, [6] Sub", Point(centerX - 112, 28), Font("Helvetica", 12), Color.cyan);
                            Pen.stringAtPoint("[7] TFL, [8] TFR", Point(centerX - 42, 50), Font("Helvetica", 12), Color.cyan);
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
                                Pen.push;
                                Pen.translate(pos.x + 10, pos.y + 10);
                                Pen.rotate(rotationAngle);
                                Pen.translate(-10, -10);
                                Pen.color = Color.black; Pen.addRect(Rect(0, 0, 20, 20)); Pen.fill;
                                Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, 20, 20)); Pen.stroke;
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