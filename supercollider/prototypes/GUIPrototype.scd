(
var win, mainView;

win = Window("GUI Prototype", Rect(0, 0, 800, 480)).background_(Color.black);
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

// --- Input Faders ---
StaticText(mainView, Rect(48, 10, 120, 28))
    .string_("INPUT")
    .align_(\center)
    .font_(Font("Helvetica", 14).boldVariant)
    .stringColor_(Color.cyan);

StaticText(mainView, Rect(70, 40, 24, 24)).string_("L").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 12)); // L label
StaticText(mainView, Rect(120, 40, 24, 24)).string_("R").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 12)); // R label

// Input faders with value tracking
~leftSlider = Slider(mainView, Rect(70, 70, 24, 300))
    .orientation_(\vertical)
    .background_(Color.black)
    .focusColor_(Color.clear)
    .knobColor_(Color.cyan)
    .action_({ |sl|
        var value = sl.value.linlin(0, 1, 60, 127).round.asInteger;
        ~leftValue.string = value.asString;
    });

~rightSlider = Slider(mainView, Rect(120, 70, 24, 300))
    .orientation_(\vertical)
    .background_(Color.black)
    .focusColor_(Color.clear)
    .knobColor_(Color.cyan)
    .action_({ |sl|
        var value = sl.value.linlin(0, 1, 60, 127).round.asInteger;
        ~rightValue.string = value.asString;
    });

~leftValue = StaticText(mainView, Rect(70, 380, 24, 24)).string_("96").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 12)); // L value
~rightValue = StaticText(mainView, Rect(120, 380, 24, 24)).string_("96").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 12)); // R value

// Create the source selector buttons and store them in variables
~lineBtn = Button(mainView, Rect(18, 70, 40, 20))
    .states_([["LINE", Color.cyan, Color.black], ["LINE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 12));

~mmBtn = Button(mainView, Rect(18, 110, 40, 20))
    .states_([["MM", Color.cyan, Color.black], ["MM", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 12));

~mcBtn = Button(mainView, Rect(18, 150, 40, 20))
    .states_([["MC", Color.cyan, Color.black], ["MC", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 12));

// Radio button logic
~lineBtn.action_({ |btn|
    if(btn.value == 1) {
        ~mmBtn.value_(0);
        ~mcBtn.value_(0);
    } {
        // Prevent unselecting all: always keep one selected
        btn.value_(1);
    }
});
~mmBtn.action_({ |btn|
    if(btn.value == 1) {
        ~lineBtn.value_(0);
        ~mcBtn.value_(0);
    } {
        btn.value_(1);
    }
});
~mcBtn.action_({ |btn|
    if(btn.value == 1) {
        ~lineBtn.value_(0);
        ~mmBtn.value_(0);
    } {
        btn.value_(1);
    }
});

// Optionally, set one as default selected
~lineBtn.valueAction_(1);

Button(mainView, Rect(18, 350, 40, 20)).states_([["LINK", Color.cyan, Color.black], ["LINK", Color.black, Color.cyan]]).font_(Font("Helvetica", 12));
Button(mainView, Rect(76, 410, 60, 35)).states_([["MUTE", Color.cyan, Color.black], ["MUTE", Color.black, Color.cyan]]).font_(Font("Helvetica", 12));
Button(mainView, Rect(18, 310, 40, 20)).states_([["MON", Color.cyan, Color.black], ["MON", Color.black, Color.cyan]]).font_(Font("Helvetica", 12));

// --- Dropdown Menus ---
// Add labels manually to match INPUT/OUTPUT styling
StaticText(mainView, Rect(180, 10, 140, 28))
    .string_("ENCODER")
    .align_(\center)
    .font_(Font("Helvetica", 14).boldVariant)
    .stringColor_(Color.cyan);

StaticText(mainView, Rect(360, 10, 140, 28))
    .string_("DECODER")
    .align_(\center)
    .font_(Font("Helvetica", 14).boldVariant)
    .stringColor_(Color.cyan);

~inputMenu = EZPopUpMenu.new(
    mainView,
    Rect(180, 45, 140, 35),
    "",
    [
        \UHJ -> {|a| ("Selected UHJ encoder" ++ a).postln; },
        \SUPERSTEREO -> {|a| ("Selected SUPERSTEREO encoder" ++ a).postln; }
    ],
    globalAction: { "Encoder menu changed".postln; },
    initVal: 0,
    initAction: false,
    labelWidth: 0,
    labelHeight: 0,
    layout: \horz,
    gap: 0@0
);

~outputMenu = EZPopUpMenu.new(
    mainView,
    Rect(360, 45, 140, 35),
    "",
    [
        \BINAURAL ++ " IRCAM" -> {|a| ("Selected BINAURAL IRCAM decoder" ++ a).postln; },
        \BINAURAL ++ " CIPIC" -> {|a| ("Selected BINAURAL CIPIC decoder" ++ a).postln; },
        \QUAD ++ " SQUARE" -> {|a| ("Selected QUAD SQUARE decoder" ++ a).postln; },
        \QUAD ++ " NARROW" -> {|a| ("Selected QUAD NARROW decoder" ++ a).postln; },
        \QUAD ++" WIDE" -> {|a| ("Selected QUAD WIDE decoder" ++ a).postln; },
        \DOLBY ++" 5.1" -> {|a| ("Selected DOLBY 5.1 decoder" ++ a).postln; },
        \OCTAGON -> {|a| ("Selected OCTAGON decoder" ++ a).postln; }
    ],
    globalAction: {
        var idx = ~outputMenu.value;
        var htIsOff = (~headtrackBtn.notNil and: { ~headtrackBtn.value == 0 });
        // Only QUAD, 5.1, OCTAGON should be dimmed/overlayed (idx 2,3,4,5,6)
        var shouldDim = (idx == 2 or: { idx == 3 } or: { idx == 4 } or: { idx == 5 } or: { idx == 6 });
        // Remove overlays if present
        if(~knobOverlay.notNil) { ~knobOverlay.remove; ~knobOverlay = nil; };
        if(~htBtnOverlay.notNil) { ~htBtnOverlay.remove; ~htBtnOverlay = nil; };
        if(~xyPannerOverlay.notNil) { ~xyPannerOverlay.remove; ~xyPannerOverlay = nil; };
        // --- Ambisonic knobs and HT buttons enable/disable logic ---
        if(shouldDim) {
            // For QUAD/5.1/OCT, always reset and disable knobs, force HT OFF
            ~rotateKnob.valueAction_(0.5);
            ~tiltKnob.valueAction_(0.5);
            ~tumbleKnob.valueAction_(0.5);
            ~rotateKnob.enabled_(false);
            ~tiltKnob.enabled_(false);
            ~tumbleKnob.enabled_(false);
            if(~headtrackBtn.notNil) { ~headtrackBtn.value_(0); };
            // Overlay covers knobs/titles/values (not HT buttons)
            ~knobOverlay = View(mainView, Rect(594, 60, 140, 224))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
            // Overlay covers HT buttons only
            ~htBtnOverlay = View(mainView, Rect(734, 60, 48, 80))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
        } {
            if((idx == 0) or: { idx == 1 }) {
                // BINAURAL decoders
                // Always remove overlay first to ensure it's not left over
                if(~knobOverlay.notNil) { ~knobOverlay.remove; ~knobOverlay = nil; };
                if(htIsOff) {
                    // HT OFF: hide all ambisonic controls (labels, knobs, values)
                    ~rotateKnob.enabled_(false);
                    ~tiltKnob.enabled_(false);
                    ~tumbleKnob.enabled_(false);
                    ~knobOverlay = View(mainView, Rect(594, 60, 140, 224))
                        .background_(Color.black.alpha_(0.7))
                        .alpha_(1.0)
                        .front;
                    // No overlay for HT buttons
                } {
                    // HT ON: show and enable knobs
                    ~rotateKnob.enabled_(true);
                    ~tiltKnob.enabled_(true);
                    ~tumbleKnob.enabled_(true);
                };
            } {
                // For all other decoders, set enabled state by HT
                if(htIsOff) {
                    ~rotateKnob.enabled_(false);
                    ~tiltKnob.enabled_(false);
                    ~tumbleKnob.enabled_(false);
                } {
                    ~rotateKnob.enabled_(true);
                    ~tiltKnob.enabled_(true);
                    ~tumbleKnob.enabled_(true);
                };
            };
        };
        // --- XY Panner overlay logic (robust, knob-style) ---
        // Only enable panner for QUAD decoders (idx 2, 3, 4)
        if((idx == 2) or: { idx == 3 } or: { idx == 4 }) {
            ~xyPannerView.enabled_(true);
            ~xyPannerEnabled = true;
        } {
            ~xyPannerView.enabled_(false);
            ~xyPannerEnabled = false;
            // Only create overlay if not enabled
            ~xyPannerOverlay = View(mainView, Rect(629, 299, 110, 145))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
        };
        
        // --- Update Layout overlay if it's open ---
        if(~layoutOverlay.notNil) {
            // Update the layout title and refresh the graphics
            var decoderNames = ["BINAURAL IRCAM", "BINAURAL CIPIC", "QUAD SQUARE", "QUAD NARROW", "QUAD WIDE", "DOLBY 5.1", "OCTAGON"];
            var decoderName = decoderNames[idx];
            
            // Find and update the title text
            ~layoutOverlay.children.do({ |child|
                if(child.class == StaticText and: { child.string.beginsWith("LAYOUT -") }) {
                    child.string_("LAYOUT - " ++ decoderName);
                };
            });
            
            // Refresh the graphics canvas
            ~layoutOverlay.children.do({ |child|
                if(child.class == UserView) {
                    child.refresh;
                };
            });
        };
    },
    initVal: 1,
    initAction: false,
    labelWidth: 0,
    labelHeight: 0,
    layout: \horz,
    gap: 0@0
);

// Style the menus to match your theme
~inputMenu.font = Font("Helvetica", 12);
~inputMenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);

~outputMenu.font = Font("Helvetica", 12);
~outputMenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);

// --- Level Meter Section --- (moved up to show channel labels)
~meterView = View(mainView, Rect(180, 107, 320, 275)).background_(Color.cyan(0.2, 0.4));

// Add a thin border around the meter view
~meterBorder = UserView(~meterView, Rect(0, 0, 320, 275))
    .background_(Color.clear)
    .drawFunc_({ |v|
        Pen.width = 0.5;
        Pen.color = Color.cyan;
        Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
        Pen.stroke;
    });

// Centered and larger LEVEL METER title
StaticText(~meterView, Rect(0, 5, 320, 30)).background_(Color.clear)
    .align_(\center)
    .string_("LEVEL METER")
    .stringColor_(Color.cyan)
    .font_(Font("Helvetica", 14).boldVariant);

// Initialize meter display area - increased height to show channel labels
~meterContainer = View(~meterView, Rect(10, 35, 300, 230)).background_(Color.black);

// Start server and load test file for 8-channel meter testing
if(Server.default.serverRunning.not) {
    ("Starting audio server...").postln;
    Server.default.options.numOutputBusChannels = 8; // Ensure 8 output channels
    Server.default.options.numInputBusChannels = 2;  // 2 input channels
    Server.default.boot;

    // Wait for server to boot, then setup meter and test playback
    Server.default.doWhenBooted({
        var testFilePath = "/home/michael-uwins/UHJ-Pi/supercollider/prototypes/8Channel.wav";

        ("Server booted, creating meter...").postln;

        // Create ServerMeter2View in our container for 8-channel monitoring
        ~serverMeter = ServerMeter2View(
            Server.default,
            ~meterContainer,
            0@0,
            2, // numIns - stereo input
            8  // numOuts - 8-channel output for testing
        );

        // Load and play the 8-channel test file
        if(File.exists(testFilePath)) {
            ("Loading 8-channel test file...").postln;
            ~testBuffer = Buffer.read(Server.default, testFilePath);

            Server.default.sync;

            // Debug: check buffer properties
            ("Buffer loaded - Channels: " ++ ~testBuffer.numChannels ++ ", Frames: " ++ ~testBuffer.numFrames).postln;

            // Create synth to play all 8 channels
            SynthDef(\play8channel, {
                var sig = PlayBuf.ar(8, ~testBuffer, BufRateScale.kr(~testBuffer), loop: 1);
                // Explicitly route each channel to its corresponding output
                8.do({ |i|
                    Out.ar(i, sig[i] * 0.5); // Each channel to its own output
                });
            }).add;

            Server.default.sync;

            // Start playback
            ~testSynth = Synth(\play8channel);
            ("8-channel test file is now playing - you should see all 8 meters active!").postln;
        } {
            ("8-channel test file not found at: " ++ testFilePath).postln;
            ("Please run Create8ChannelOffline.scd first to create the test file.").postln;
        };
    });
} {
    ("Server already running, creating meter...").postln;

    // Create ServerMeter2View in our container for 8-channel monitoring
    ~serverMeter = ServerMeter2View(
        Server.default,
        ~meterContainer,
        0@0,
        2, // numIns - stereo input
        8  // numOuts - 8-channel output for testing
    );
};

// Add cleanup when meter container is closed
~meterContainer.onClose_({
    if(~serverMeter.notNil) {
        try { ~serverMeter.stop; } { };
    };
    if(~testSynth.notNil) {
        try { ~testSynth.free; } { };
    };
    if(~testBuffer.notNil) {
        try { ~testBuffer.free; } { };
    };
});

// --- EQ, Ambience, and Layout Buttons (aligned, same width, under meter window) ---
// Meter window: x=180, width=320
// Three buttons: width = 320/3 = ~107 each (with small gaps between)
~eqBtn = Button(mainView, Rect(180, 410, 100, 35))
    .states_([["EQ", Color.cyan, Color.black], ["EQ", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 12))
    .action_({ |btn|
        var freqs, eqWidth, sliderWidth, sliderHeight, startX, gap;

        if(btn.value == 1) {
            // Close other overlays if open
            if(~ambienceOverlay.notNil) {
                ~ambienceOverlay.remove;
                ~ambienceOverlay = nil;
                ~ambienceBtn.value_(0);
            };
            if(~layoutOverlay.notNil) {
                ~layoutOverlay.remove;
                ~layoutOverlay = nil;
                ~layoutBtn.value_(0);
            };

            // Create EQ overlay directly in main window
            ~eqOverlay = View(mainView, Rect(180, 107, 320, 275)) // Vertically align with meter window
                .background_(Color.black);

            // Add border to match the meter styling
            UserView(~eqOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });

            // EQ Title (now left-aligned)
            StaticText(~eqOverlay, Rect(10, 5, 120, 20))
                .string_("GRAPHIC EQ")
                .align_(\left)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 12).boldVariant)
                .background_(Color.clear);

            // Preset dropdown (right side, styled like Ambience overlay)
            ~eqPresetNames = ["Flat", "Vocal", "Bass Boost", "Treble Boost", "Custom 1", "Custom 2"];
            ~eqPresetMenu = PopUpMenu(~eqOverlay, Rect(140, 7, 110, 20))
                .items_(~eqPresetNames)
                .font_(Font("Helvetica", 11))
                .background_(Color.black)
                .stringColor_(Color.cyan)
                .value_(0); // Default to first preset
            Button(~eqOverlay, Rect(255, 7, 58, 20))
                .states_([["SAVE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 10))
                .toolTip_("Save as preset") // Corrected method name
                .action_({
                    // Save current slider values as a new preset
                    var newName, values;
                    values = ~eqSliders.collect({ |slider| slider.value });
                    newName = "Custom " ++ (~eqPresetNames.size - 3 + 1); // Custom N
                    ~eqPresetNames = ~eqPresetNames.add(newName);
                    ~eqPresetMenu.items = ~eqPresetNames;
                    ~eqPresetMenu.value = ~eqPresetNames.size - 1;
                    // Optionally, store values in a dictionary for recall
                    if(~eqPresetDict.isNil) { ~eqPresetDict = IdentityDictionary.new; };
                    ~eqPresetDict[newName] = values;
                });
            // Recall preset values when a preset is selected
            ~eqPresetMenu.action_({
                var name = ~eqPresetNames[~eqPresetMenu.value];
                if(~eqPresetDict.notNil and: { ~eqPresetDict[name].notNil }) {
                    ~eqPresetDict[name].do({ |val, i| ~eqSliders[i].value_(val); });
                } {
                    // Flat and other built-ins: set to flat
                    if(~eqPresetMenu.value == 0) {
                        ~eqSliders.do({ |slider, i| slider.value_(0.5); ~eqValues[i].string_("0.0dB"); });
                    }
                }
            });

            // Use same layout as Ambience overlay for EQ faders
            freqs = [63, 160, 400, 1000, 2500, 6400, 16000]; // 7-band EQ
            sliderWidth = 32; sliderHeight = 140; startX = 12; gap = 44;

            // Create frequency labels (top)
            freqs.do({ |freq, i|
                var x = startX + (i * gap);
                StaticText(~eqOverlay, Rect(x, 35, sliderWidth, 16))
                    .string_(if(freq >= 1000, (freq/1000).asString ++ "k", freq.asString))
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 10))
                    .background_(Color.clear);
            });

            // Create EQ sliders (same Y/height as Ambience)
            ~eqSliders = freqs.collect({ |freq, i|
                var x = startX + (i * gap);
                var slider = Slider(~eqOverlay, Rect(x, 55, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .knobColor_(Color.cyan)
                    .value_(0.5) // 0 dB
                    .action_({ |sl|
                        var db = sl.value.linlin(0, 1, -12, 12);
                        ~eqValues[i].string = db.round(0.1).asString ++ "dB";
                    });
                slider;
            });

            // Value displays (underneath sliders, same as Ambience)
            ~eqValues = freqs.collect({ |freq, i|
                var x = startX + (i * gap);
                StaticText(~eqOverlay, Rect(x, 200, sliderWidth, 16))
                    .string_("0.0dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9))
                    .background_(Color.clear);
            });

            // Reset button (now matches Ambience overlay position/size)
            Button(~eqOverlay, Rect(18, 230, 80, 28))
                .states_([["RESET", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~eqSliders.do({ |slider, i|
                        slider.value_(0.5);
                        ~eqValues[i].string_("0.0dB");
                    });
                });
            // Close button (now matches Ambience overlay position/size)
            Button(~eqOverlay, Rect(222, 230, 80, 28))
                .states_([["CLOSE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~eqOverlay.remove;
                    ~eqOverlay = nil;
                    ~eqBtn.value_(0);
                });

            ~eqOverlay.front;
        } {
            if(~eqOverlay.notNil) {
                ~eqOverlay.remove;
                ~eqOverlay = nil;
            };
        }
    });

~ambienceBtn = Button(mainView, Rect(287, 410, 100, 35))
    .states_([["AMBIENCE", Color.cyan, Color.black], ["AMBIENCE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 12))
    .action_({ |btn|
        var params, sliderWidth, sliderHeight, startX, gap, i, x, slider, valDisp, roomNames, roomMenu;
        if(btn.value == 1) {
            // Close other overlays if open
            if(~eqOverlay.notNil) {
                ~eqOverlay.remove;
                ~eqOverlay = nil;
                ~eqBtn.value_(0);
            };
            if(~layoutOverlay.notNil) {
                ~layoutOverlay.remove;
                ~layoutOverlay = nil;
                ~layoutBtn.value_(0);
            };

            // Create Ambience overlay directly in main window - styled and compact
            ~ambienceOverlay = View(mainView, Rect(180, 107, 320, 275)) // Vertically align with meter window
                .background_(Color.black);

            // Border to match meter/EQ overlays
            UserView(~ambienceOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });

            // Title
            StaticText(~ambienceOverlay, Rect(10, 5, 120, 22))
                .string_("AMBIENCE")
                .align_(\left)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 12).boldVariant)
                .background_(Color.clear);

            // Room selector (dropdown)
            roomNames = ["Small Room", "Medium Room", "Large Hall", "Cathedral", "Plate", "Chamber", "Bright", "Dark"];
            roomMenu = PopUpMenu(~ambienceOverlay, Rect(140, 7, 170, 20))
                .items_(roomNames)
                .font_(Font("Helvetica", 11))
                .background_(Color.black)
                .stringColor_(Color.cyan)
                .value_(0); // Default to first room

            // Parameter names and default values (truncated labels)
            params = [
                ["Wet", 0.5],
                ["Dry", 0.5],
                ["Size", 0.7],
                ["Damp", 0.3],
                ["PreDly", 0.2],
                ["MRate", 0.5],
                ["MDep", 0.5]
            ];
            sliderWidth = 32; sliderHeight = 140; startX = 12; gap = 44; // User requested gap
            ~ambienceSliders = List[];
            ~ambienceValues = List[];

            params.do({ |pair, i|
                x = startX + (i * gap);
                // Label
                StaticText(~ambienceOverlay, Rect(x, 35, sliderWidth, 16))
                    .string_(pair[0])
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 10))
                    .background_(Color.clear);
                // Slider
                slider = Slider(~ambienceOverlay, Rect(x, 55, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .knobColor_(Color.cyan)
                    .value_(pair[1])
                    .action_({ |sl|
                        var val = (sl.value * 100).round(0.1);
                        ~ambienceValues[i].string = val.asString ++ "%";
                    });
                ~ambienceSliders.add(slider);
                // Value display
                valDisp = StaticText(~ambienceOverlay, Rect(x, 200, sliderWidth, 16))
                    .string_((pair[1] * 100).asString ++ "%")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9))
                    .background_(Color.clear);
                ~ambienceValues.add(valDisp);
            });

            // Freeze toggle
            ~freezeBtn = Button(~ambienceOverlay, Rect(18, 230, 80, 28))
                .states_([["FREEZE", Color.cyan, Color.black], ["FREEZE", Color.black, Color.cyan]])
                .font_(Font("Helvetica", 11));

            // Close button
            Button(~ambienceOverlay, Rect(222, 230, 80, 28))
                .states_([["CLOSE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~ambienceOverlay.remove;
                    ~ambienceOverlay = nil;
                    ~ambienceBtn.value_(0);
                });

            ~ambienceOverlay.front;
        } {
            if(~ambienceOverlay.notNil) {
                ~ambienceOverlay.remove;
                ~ambienceOverlay = nil;
            };
        }
    });

~layoutBtn = Button(mainView, Rect(394, 410, 100, 35))
    .states_([["LAYOUT", Color.cyan, Color.black], ["LAYOUT", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 12))
    .action_({ |btn|
        var currentDecoder, decoderNames, decoderName;
        
        if(btn.value == 1) {
            // Close other overlays if open
            if(~eqOverlay.notNil) {
                ~eqOverlay.remove;
                ~eqOverlay = nil;
                ~eqBtn.value_(0);
            };
            if(~ambienceOverlay.notNil) {
                ~ambienceOverlay.remove;
                ~ambienceOverlay = nil;
                ~ambienceBtn.value_(0);
            };

            // Create Layout overlay directly in main window
            ~layoutOverlay = View(mainView, Rect(180, 107, 320, 275)) // Vertically align with meter window
                .background_(Color.black);

            // Add border to match the meter/EQ/Ambience styling
            UserView(~layoutOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });

            // Get current decoder selection
            currentDecoder = ~outputMenu.value;
            decoderNames = ["BINAURAL IRCAM", "BINAURAL CIPIC", "QUAD SQUARE", "QUAD NARROW", "QUAD WIDE", "DOLBY 5.1", "OCTAGON"];
            decoderName = decoderNames[currentDecoder];
            
            // Layout Title with current decoder (centered)
            StaticText(~layoutOverlay, Rect(10, 5, 300, 22))
                .string_("LAYOUT - " ++ decoderName)
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 12).boldVariant)
                .background_(Color.clear);

            // Graphics canvas with finalized layout diagrams
            UserView(~layoutOverlay, Rect(10, 30, 300, 235))
                .background_(Color.clear)
                .drawFunc_({ |view|
                    var bounds = view.bounds;
                    var centerX = bounds.width / 2;
                    var centerY = bounds.height / 2;
                    var currentDecoderValue = ~outputMenu.value; // Get current decoder value dynamically
                    
                    // Fill background with black
                    Pen.color = Color.black;
                    Pen.addRect(Rect(0, 0, bounds.width, bounds.height));
                    Pen.fill;
                    
                    // Set consistent pen width for everything
                    Pen.width = 2;
                    
                    switch(currentDecoderValue,
                        0, {
                            // BINAURAL IRCAM - Headphone representation scaled for smaller canvas
                            
                            var earCupWidth = 20; // Width of each ear cup (scaled down from 24)
                            var earCupHeight = 27; // Height of each ear cup (scaled down from 32)
                            var earCupOffset = 55; // Distance from center to ear cup center (scaled down from 65)
                            var arcCenterY = centerY - 25; // Moved down (scaled from -30)
                            var arcRadius = 47; // Scaled radius (down from 55)
                            var leftEarX, leftEarY, rightEarX, rightEarY;
                            
                            // Left ear cup position (SVG: x="2" y="14")
                            leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                            leftEarY = centerY + 25; // Moved down 10 pixels (was +15)
                            
                            // Right ear cup position (SVG: x="16" y="14")  
                            rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                            rightEarY = centerY + 25; // Moved down 10 pixels (was +15)
                            
                            // Draw main headband arc (SVG path: semicircle from x=2 to x=22, center at x=12)
                            // SVG: "M2,18V12A10,10,0,0,1,12,2h0A10,10,0,0,1,22,12v6"
                            Pen.color = Color.cyan;
                            Pen.width = 2;
                            
                            // Draw the main headband arc (semicircle from 180° to 0°)
                            Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi);
                            Pen.stroke;
                            
                            // Draw vertical connectors from arc to ear cups (like the SVG "V12" and "v6" parts)
                            // Left connector
                            Pen.moveTo(Point(centerX - arcRadius, centerY - 30));
                            Pen.lineTo(Point(centerX - arcRadius, leftEarY));
                            Pen.stroke;
                            
                            // Right connector
                            Pen.moveTo(Point(centerX + arcRadius, centerY - 30));
                            Pen.lineTo(Point(centerX + arcRadius, rightEarY));
                            Pen.stroke;
                            
                            // Left ear cup (Speaker 1) - simple rectangle like SVG
                            Pen.color = Color.black;
                            Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.width = 2;
                            Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight));
                            Pen.stroke;
                            
                            Pen.stringAtPoint("1", Point(leftEarX + 8, leftEarY + 7), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Right ear cup (Speaker 2) - simple rectangle like SVG
                            Pen.color = Color.black;
                            Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.width = 2;
                            Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight));
                            Pen.stroke;
                            
                            Pen.stringAtPoint("2", Point(rightEarX + 8, rightEarY + 7), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);

                            // Descriptive text (centered)
                            Pen.stringAtPoint("Headphone Listening using IRCAM HTRF Library", Point(centerX - 135, 10), 
                                            Font("Helvetica", 12), Color.cyan);
                        },
                        1, {
                            // BINAURAL CIPIC - Same as IRCAM for visual representation, scaled for smaller canvas
                            
                            var earCupWidth = 20; // Width of each ear cup (scaled down from 24)
                            var earCupHeight = 27; // Height of each ear cup (scaled down from 32)
                            var earCupOffset = 55; // Distance from center to ear cup center (scaled down from 65)
                            var arcCenterY = centerY - 25; // Moved down (scaled from -30)
                            var arcRadius = 47; // Scaled radius (down from 55)
                            var leftEarX, leftEarY, rightEarX, rightEarY;
                            
                            // Left ear cup position (SVG: x="2" y="14")
                            leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                            leftEarY = centerY + 25; // Moved down 10 pixels (was +15)
                            
                            // Right ear cup position (SVG: x="16" y="14")  
                            rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                            rightEarY = centerY + 25; // Moved down 10 pixels (was +15)
                            
                            // Draw main headband arc (SVG path: semicircle from x=2 to x=22, center at x=12)
                            // SVG: "M2,18V12A10,10,0,0,1,12,2h0A10,10,0,0,1,22,12v6"
                            Pen.color = Color.cyan;
                            Pen.width = 2;
                            
                            // Draw the main headband arc (semicircle from 180° to 0°)
                            Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi);
                            Pen.stroke;
                            
                            // Draw vertical connectors from arc to ear cups (like the SVG "V12" and "v6" parts)
                            // Left connector
                            Pen.moveTo(Point(centerX - arcRadius, centerY - 25));
                            Pen.lineTo(Point(centerX - arcRadius, leftEarY));
                            Pen.stroke;
                            
                            // Right connector
                            Pen.moveTo(Point(centerX + arcRadius, centerY - 25));
                            Pen.lineTo(Point(centerX + arcRadius, rightEarY));
                            Pen.stroke;
                            
                            // Left ear cup (Speaker 1) - simple rectangle like SVG
                            Pen.color = Color.black;
                            Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.width = 2;
                            Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight));
                            Pen.stroke;
                            
                            Pen.stringAtPoint("1", Point(leftEarX + 8, leftEarY + 7), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Right ear cup (Speaker 2) - simple rectangle like SVG
                            Pen.color = Color.black;
                            Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.width = 2;
                            Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight));
                            Pen.stroke;
                            
                            Pen.stringAtPoint("2", Point(rightEarX + 8, rightEarY + 7), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);

                            // Descriptive text (centered)
                            Pen.stringAtPoint("Headphone Listening using CIPIC HTRF Library", Point(centerX - 135, 10), 
                                            Font("Helvetica", 12), Color.cyan);
                        },
                        2, {
                            // QUAD SQUARE - Final version, scaled for smaller canvas
                            
                            // Main square outline (scaled down from 180 to 140)
                            var squareSize = 140;
                            var halfSquare = squareSize / 2;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(centerX - halfSquare, centerY - halfSquare, squareSize, squareSize));
                            Pen.stroke;
                            
                            // Front Left (top-left corner) - reference position - Speaker 1
                            Pen.color = Color.black;
                            Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10, 20, 20));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10, 20, 20));
                            Pen.stroke;
                            Pen.stringAtPoint("1", Point(centerX - halfSquare - 10 + 7, centerY - halfSquare - 10 + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Back Left (140 pixels down from reference) - Speaker 2
                            Pen.color = Color.black;
                            Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + squareSize, 20, 20));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + squareSize, 20, 20));
                            Pen.stroke;
                            Pen.stringAtPoint("2", Point(centerX - halfSquare - 10 + 7, centerY - halfSquare - 10 + squareSize + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Back Right (140 pixels right and 140 pixels down) - Speaker 3
                            Pen.color = Color.black;
                            Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + squareSize, 20, 20));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + squareSize, 20, 20));
                            Pen.stroke;
                            Pen.stringAtPoint("3", Point(centerX - halfSquare - 10 + squareSize + 7, centerY - halfSquare - 10 + squareSize + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Front Right (140 pixels to the right) - Speaker 4
                            Pen.color = Color.black;
                            Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10, 20, 20));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10, 20, 20));
                            Pen.stroke;
                            Pen.stringAtPoint("4", Point(centerX - halfSquare - 10 + squareSize + 7, centerY - halfSquare - 10 + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Descriptive text (centered)
                            Pen.stringAtPoint("Equal distance between all speakers", Point(centerX - 97, 10), 
                                            Font("Helvetica", 12), Color.cyan);
                        },
                        3, {
                            // QUAD NARROW - Rectangle with width = 0.75 * height, scaled for smaller canvas
                            var rectHeight = 140; // Scaled down from 180
                            var rectWidth = (rectHeight * 0.75).asInteger; // 105 pixels
                            var rectLeft = centerX - (rectWidth / 2); // Center horizontally
                            var rectTop = centerY - (rectHeight / 2); // Center vertically
                            
                            // Main rectangle outline
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight));
                            Pen.stroke;
                            
                            // All four speakers using the rectangle corners
                            
                            // Front Left (top-left corner) - Speaker 1
                            Pen.color = Color.black;
                            Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20));
                            Pen.stroke;
                            Pen.stringAtPoint("1", Point(rectLeft - 10 + 7, rectTop - 10 + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Back Left (bottom-left corner) - Speaker 2
                            Pen.color = Color.black;
                            Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20));
                            Pen.stroke;
                            Pen.stringAtPoint("2", Point(rectLeft - 10 + 7, rectTop + rectHeight - 10 + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Back Right (bottom-right corner) - Speaker 3
                            Pen.color = Color.black;
                            Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20));
                            Pen.stroke;
                            Pen.stringAtPoint("3", Point(rectLeft + rectWidth - 10 + 7, rectTop + rectHeight - 10 + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Front Right (top-right corner) - Speaker 4
                            Pen.color = Color.black;
                            Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20));
                            Pen.stroke;
                            Pen.stringAtPoint("4", Point(rectLeft + rectWidth - 10 + 7, rectTop - 10 + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);

                            // Descriptive text (centered)
                            Pen.stringAtPoint("Narrow Quadraphonic arrangement (x ≤ 0.75y)", Point(centerX - 115, 10), 
                                            Font("Helvetica", 12), Color.cyan);                    
                        },
                        4, {
                            // QUAD WIDE - Rectangle with vertical at 105px and horizontal at 140px, scaled for smaller canvas
                            
                            var rectWidth = 140; // Scaled down from 180
                            var rectHeight = 105; // Scaled down from 135
                            var rectLeft = centerX - (rectWidth / 2);
                            // Adjust vertical centering to account for speaker box extensions (10px each side)
                            var totalHeight = rectHeight + 20; // rectangle + speaker extensions
                            var rectTop = centerY - (totalHeight / 2) + 10; // +10 to account for top speaker extension
                            
                            // Main rectangle outline
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight));
                            Pen.stroke;
                            
                            // All four speakers at rectangle corners
                            
                            // Front Left (top-left corner) - Speaker 1
                            Pen.color = Color.black;
                            Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20));
                            Pen.stroke;
                            Pen.stringAtPoint("1", Point(rectLeft - 10 + 7, rectTop - 10 + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Back Left (bottom-left corner) - Speaker 2
                            Pen.color = Color.black;
                            Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20));
                            Pen.stroke;
                            Pen.stringAtPoint("2", Point(rectLeft - 10 + 7, rectTop + rectHeight - 10 + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Back Right (bottom-right corner) - Speaker 3
                            Pen.color = Color.black;
                            Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20));
                            Pen.stroke;
                            Pen.stringAtPoint("3", Point(rectLeft + rectWidth - 10 + 7, rectTop + rectHeight - 10 + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Front Right (top-right corner) - Speaker 4
                            Pen.color = Color.black;
                            Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20));
                            Pen.stroke;
                            Pen.stringAtPoint("4", Point(rectLeft + rectWidth - 10 + 7, rectTop - 10 + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);

                            // Descriptive text (centered)
                            Pen.stringAtPoint("Wide Quadraphonic arrangement (x ≥ 1.33y)", Point(centerX - 114, 10), 
                                            Font("Helvetica", 12), Color.cyan);
                        },
                        5, {
                            // DOLBY 5.1 - Standard Wikipedia layout, scaled for smaller canvas
                            
                            var layoutSize = 140; // Main layout size (scaled down from 180)
                            var layoutLeft = centerX - (layoutSize / 2);
                            var layoutTop = centerY - (layoutSize / 2);
                            var speakerSize = 20; // Speaker box size
                            var frontLeftX = layoutLeft - 10;
                            var frontLeftY = layoutTop - 10;
                            var frontRightX = layoutLeft + layoutSize - 10;
                            var frontRightY = layoutTop - 10;
                            var centerX_speaker = layoutLeft + (layoutSize / 2) - 10;
                            var centerY_speaker = layoutTop - 10;
                            var surroundLeftX = layoutLeft - 10;
                            var surroundLeftY = layoutTop + layoutSize - 10;
                            var surroundRightX = layoutLeft + layoutSize - 10;
                            var surroundRightY = layoutTop + layoutSize - 10;
                            var subwooferX = layoutLeft + (layoutSize / 2) - 10;
                            var subwooferY = layoutTop + (layoutSize / 2) - 10;
                            
                            // Main layout rectangle outline
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize));
                            Pen.stroke;
                            
                            // Speaker 1: Front Left (top-left corner)
                            Pen.color = Color.black;
                            Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize));
                            Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 7, frontLeftY + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Speaker 2: Front Right (top-right corner)
                            Pen.color = Color.black;
                            Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize));
                            Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 7, frontRightY + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Speaker 3: Center (top-center)
                            Pen.color = Color.black;
                            Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize));
                            Pen.stroke;
                            Pen.stringAtPoint("3", Point(centerX_speaker + 7, centerY_speaker + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Speaker 4: Surround Left (bottom-left corner)
                            Pen.color = Color.black;
                            Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize));
                            Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundLeftX + 7, surroundLeftY + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Speaker 5: Surround Right (bottom-right corner)
                            Pen.color = Color.black;
                            Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize));
                            Pen.fill;
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize));
                            Pen.stroke;
                            Pen.stringAtPoint("5", Point(surroundRightX + 7, surroundRightY + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            
                            // Subwoofer: (center, outline only like Wikipedia, labeled as 6 with SUB to the right)
                            Pen.color = Color.cyan;
                            Pen.addRect(Rect(subwooferX, subwooferY, speakerSize, speakerSize));
                            Pen.stroke; // Only stroke, no fill (matches SVG fill-opacity="0")
                            Pen.stringAtPoint("6", Point(subwooferX + 7, subwooferY + 1), 
                                            Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.stringAtPoint("SUB", Point(subwooferX + 25, subwooferY + 3), 
                                            Font("Helvetica", 10).boldVariant, Color.cyan);

                            // Descriptive text (centered)
                            Pen.stringAtPoint("[1] 0°, [2] -30°, [3] +30° [4] -110°, [5] +110°, [6] Sub", Point(centerX - 136, 10), 
                                            Font("Helvetica", 12), Color.cyan); 
                                                 
                        },
                        6, {
                            // OCTAGON - 8 speakers arranged in octagonal pattern, scaled for smaller canvas
                            
                            var radius = 80; // Distance from center to each speaker (scaled down from 100)
                            var angleStep = 2 * pi / 8; // 45 degrees in radians
                            var startAngle = -22.5 * pi / 180; // Start at 22.5 degrees anti-clockwise from 0 degrees (3 o'clock)
                            
                            // Calculate speaker positions in anti-clockwise order starting from 22.5 degrees
                            var speakerPositions = Array.fill(8, { |i|
                                var angle = startAngle + (i * angleStep);
                                var x = centerX + (radius * cos(angle)) - 10; // -10 to center 20x20 speaker box
                                var y = centerY + (radius * sin(angle)) - 10; // -10 to center 20x20 speaker box
                                Point(x, y);
                            });
                            
                            // Draw circle outline behind the speakers
                            Pen.color = Color.cyan;
                            Pen.addOval(Rect(centerX - radius, centerY - radius, radius * 2, radius * 2));
                            Pen.stroke;
                            
                            // Draw speakers and numbers (anti-clockwise from 22.5 degrees)
                            // Shift numbering so current position 7 becomes 1, 6 becomes 2, etc.
                            speakerPositions.do({ |pos, i|
                                var speakerNum = ((i + 2) % 8) + 1; // Shift by 2 positions: 7->1, 6->2, 5->3, etc.
                                var angle = startAngle + (i * angleStep);
                                var rotationAngle = angle + (pi / 2); // Rotate 90 degrees to face center
                                
                                // Save current transform state
                                Pen.push;
                                
                                // Translate to speaker center, rotate, then translate back for drawing
                                Pen.translate(pos.x + 10, pos.y + 10); // Move to speaker center
                                Pen.rotate(rotationAngle); // Rotate to face center
                                Pen.translate(-10, -10); // Move back so rectangle draws centered
                                
                                // Speaker box (rotated to face center)
                                Pen.color = Color.black;
                                Pen.addRect(Rect(0, 0, 20, 20));
                                Pen.fill;
                                Pen.color = Color.cyan;
                                Pen.addRect(Rect(0, 0, 20, 20));
                                Pen.stroke;
                                
                                // Speaker number (also rotated)
                                Pen.stringAtPoint(speakerNum.asString, Point(7, 1), 
                                                Font("Helvetica", 12).boldVariant, Color.cyan);
                                
                                // Restore transform state
                                Pen.pop;
                            });

                            // Descriptive text (centered)
                            Pen.stringAtPoint("[1] -22.5°, Speakers @ 45°", Point(centerX - 69, 10), 
                                            Font("Helvetica", 12), Color.cyan);
                        }
                    );
                });

            // Close button (matches EQ/Ambience overlay position/size)
            Button(~layoutOverlay, Rect(222, 275, 80, 28))
                .states_([["CLOSE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~layoutOverlay.remove;
                    ~layoutOverlay = nil;
                    ~layoutBtn.value_(0);
                });

            ~layoutOverlay.front;
        } {
            if(~layoutOverlay.notNil) {
                ~layoutOverlay.remove;
                ~layoutOverlay = nil;
            };
        }
    });

// --- Ambisonic/Spatial Controls (centered, equidistant, absolute positions, shifted right by 6px) ---
// Knob positions: x=654, y=60/142/224, width=60 (centered with XY panner at x=624, width=120)
~rotateKnob = Knob.new(mainView, Rect(654, 60, 60, 60)) // x=636 -> 654
    .valueAction_(0.5)
    .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
    .centered_(true)
    .enabled_(false)
    .action_({ |knob|
        var rotation = knob.value.linlin(0, 1, -180, 180);
        ~rotateValue.string = rotation.round.asInteger.asString;
    });
~tiltKnob = Knob.new(mainView, Rect(654, 142, 60, 60)) // x=636 -> 654
    .valueAction_(0.5)
    .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
    .centered_(true)
    .enabled_(false)
    .action_({ |knob|
        var tilt = knob.value.linlin(0, 1, -180, 180);
        ~tiltValue.string = tilt.round.asInteger.asString;
    });
~tumbleKnob = Knob.new(mainView, Rect(654, 224, 60, 60)) // x=636 -> 654
    .valueAction_(0.5)
    .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
    .centered_(true)
    .enabled_(false)
    .action_({ |knob|
        var tumble = knob.value.linlin(0, 1, -180, 180);
        ~tumbleValue.string = tumble.round.asInteger.asString;
    });
// Labels for ambisonic controls (to the left of each knob, vertically aligned)
StaticText(mainView, Rect(594, 80, 55, 20)).string_("ROTATE").align_(\right).stringColor_(Color.cyan).font_(Font("Helvetica", 11)); // x=576 -> 594
StaticText(mainView, Rect(594, 162, 55, 20)).string_("TILT").align_(\right).stringColor_(Color.cyan).font_(Font("Helvetica", 11)); // x=576 -> 594
StaticText(mainView, Rect(594, 244, 55, 20)).string_("TUMBLE").align_(\right).stringColor_(Color.cyan).font_(Font("Helvetica", 11)); // x=576 -> 594
// Value displays for ambisonic controls (to the right of each knob, vertically aligned)
~rotateValue = StaticText(mainView, Rect(719, 80, 55, 20)).string_("0").align_(\left).stringColor_(Color.cyan).font_(Font("Helvetica", 11)); // x=701 -> 719
~tiltValue = StaticText(mainView, Rect(719, 162, 55, 20)).string_("0").align_(\left).stringColor_(Color.cyan).font_(Font("Helvetica", 11)); // x=701 -> 719
~tumbleValue = StaticText(mainView, Rect(719, 244, 55, 20)).string_("0").align_(\left).stringColor_(Color.cyan).font_(Font("Helvetica", 11));

// --- Volume Fader ---
StaticText(mainView, Rect(520, 10, 72, 28))
    .string_("OUTPUT")
    .align_(\center)
    .font_(Font("Helvetica", 14).boldVariant)
    .stringColor_(Color.cyan);

// --- Headtracker Heading ---
StaticText(mainView, Rect(618, 10, 140, 28))
    .string_("HEADTRACKER")
    .align_(\center)
    .font_(Font("Helvetica", 14).boldVariant)
    .stringColor_(Color.cyan);

StaticText(mainView, Rect(544, 40, 24, 24)).string_("MAX").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 12)); // Volume label

~volumeSlider = Slider(mainView, Rect(544, 70, 24, 300))
    .orientation_(\vertical)
    .background_(Color.black)
    .focusColor_(Color.clear)
    .knobColor_(Color.cyan)
    .action_({ |sl|
        var value = (sl.value * 10).round(0.1);
        ~volumeValue.string = value.asString;
    });

~volumeValue = StaticText(mainView, Rect(544, 380, 24, 24)).string_("5.0").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 12));

// Set initial values for faders
~leftSlider.value_((96 - 60) / (127 - 60));  // Set to 96 (default phono level)
~rightSlider.value_((96 - 60) / (127 - 60)); // Set to 96 (default phono level)
~volumeSlider.value_(0.5); // Set volume to middle

// --- QUAD PANNER label ---
StaticText(mainView, Rect(629, 299, 110, 22)) // x=629, y=299 (up 6px), width=110, above panner
    .string_("QUAD PANNER")
    .align_(\center)
    .stringColor_(Color.cyan)
    .font_(Font("Helvetica", 14).boldVariant)
    .background_(Color.clear);

// --- XY Panner (using SuperCollider's Slider2D, with manual overlay for DIM) ---
UserView(mainView, Rect(629, 334, 110, 110)) // x=629, y=334 (down 3px), centers 110px at x=684
    .background_(Color.clear)
    .drawFunc_({ |v|
        Pen.width = 0.5;
        Pen.color = Color.cyan;
        Pen.addRect(Rect(0.25, 0.25, v.bounds.width-0.5, v.bounds.height-0.5));
        Pen.stroke;
    });
~xyPannerView = Slider2D(mainView, Rect(629, 334, 110, 110)) // x=629, y=334 (down 3px)
    .x_(0.5)
    .y_(0.5)
    .knobColor_(Color.cyan)
    .background_(Color.black)
    .canFocus_(false)
    .action_({ |sl|
        ~xyPannerPos = Point(sl.x, sl.y);
    });
~xyPannerPos = Point(~xyPannerView.x, ~xyPannerView.y);
~xyPannerEnabled = true;
~xyPannerOverlay = nil;

// --- Headtracker ON/OFF and RESET buttons (absolute positions, right-aligned) ---
~headtrackBtn = Button(mainView, Rect(742, 62, 40, 20)) // moved up by 8px (70 -> 62)
    .states_([[
        "OFF", Color.cyan, Color.black
    ], [
        "ON", Color.black, Color.cyan
    ]])
    .font_(Font("Helvetica", 12))
    .action_({ |btn|
        var on = btn.value == 1;
        ~rotateKnob.enabled_(on);
        ~tiltKnob.enabled_(on);
        ~tumbleKnob.enabled_(on);
        // Force overlay/global state update when HT toggled
        ~outputMenu.globalAction.value;
    })
    .value_(0); // Default to OFF

~headtrackResetBtn = Button(mainView, Rect(742, 102, 40, 20)) // moved up by 8px (110 -> 102)
    .states_([["RESET", Color.cyan, Color.black]])
    .font_(Font("Helvetica", 12))
    .action_({
        ~rotateKnob.valueAction_(0.5);
        ~tiltKnob.valueAction_(0.5);
        ~tumbleKnob.valueAction_(0.5);
    });

// Ensure overlay logic is always in sync with both menu and HT button
// Only use globalAction for overlay logic
~outputMenu.action_({}); // No-op, disables old debug logic

// Call once at startup to set initial state
~outputMenu.globalAction.value;



win.front;
)