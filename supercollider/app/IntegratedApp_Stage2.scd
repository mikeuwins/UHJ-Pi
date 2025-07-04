// Integrated UHJ Ambisonic System - Combining polished GUI with working MainApp2 functionality
(
var win, mainView,
    // Input section variables (from MainApp2)
    isUpdating, leftSlider, rightSlider, labelLVal, labelRVal, linkButton, 
    lastInputCmd, muteBtn, monBtn, lineBtn, mmBtn, mcBtn, linkFaders, 
    lastInL, lastInR, minIn, maxIn, lastFaderGroup,
    // Audio engine variables (from MainApp2)
    rotini, tltini, tumini, volini, ambini, voltmp,
    cond, sndbuf, synth, inputs, outputs, configKeyD, configKeyE,
    // dB conversion variables and functions
    dbValue, cliToDb, cliToDbMaster, formatDbValue;

// --- Overlay GUI variables (must be declared at the top, per GUIPrototype) ---
~eqOverlay = nil; ~ambienceOverlay = nil; ~layoutOverlay = nil;
~eqBtn = nil; ~ambienceBtn = nil; ~layoutBtn = nil;

// --- Initial values for input section ---
isUpdating = false;
linkFaders = true;
lastInL = 86;
lastInR = 86;
minIn = 60;
maxIn = 127;
lastFaderGroup = \none;

// Audio engine initial values
rotini = 0.5;
tltini = 0.5;
tumini = 0.5;
volini = 0.5;
ambini = 0;
voltmp = 0.5;

// Encoder/Decoder configuration defaults
configKeyE = \uhj;      // Default encoder: UHJ
configKeyD = \binaural; // Default decoder: Binaural
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
win = Window("UHJ Ambisonic System", Rect(0, 0, 800, 480)).background_(Color.black);

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

// --- INPUT FADERS SECTION (MainApp2 functionality with GUI prototype styling) ---
StaticText(mainView, Rect(48, 10, 120, 28))
    .string_("INPUT")
    .align_(\center)
    .font_(Font("Helvetica", 14).boldVariant)
    .stringColor_(Color.cyan);

StaticText(mainView, Rect(70, 40, 24, 24)).string_("L").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 12));
StaticText(mainView, Rect(120, 40, 24, 24)).string_("R").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 12));

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

~leftValue = StaticText(mainView, Rect(65, 380, 34, 24)).string_("-19").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 12));
~rightValue = StaticText(mainView, Rect(115, 380, 34, 24)).string_("-19").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 12));

// Add "dB" label between the faders, vertically aligned with the values
StaticText(mainView, Rect(95, 380, 24, 24)).string_("dB").align_(\center).stringColor_(Color.cyan).font_(Font("Helvetica", 12));

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
    .font_(Font("Helvetica", 12))
    .action_({ |btn|
        if(btn.value == 1) {
            ~mmBtn.value_(0);
            ~mcBtn.value_(0);
            ("phono-control -c line").unixCmd;
        }
    });

~mmBtn = Button(mainView, Rect(18, 110, 40, 20))
    .states_([["MM", Color.cyan, Color.black], ["MM", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 12))
    .action_({ |btn|
        if(btn.value == 1) {
            ~lineBtn.value_(0);
            ~mcBtn.value_(0);
            ("phono-control -c mm").unixCmd;
        }
    });

~mcBtn = Button(mainView, Rect(18, 150, 40, 20))
    .states_([["MC", Color.cyan, Color.black], ["MC", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 12))
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
    .font_(Font("Helvetica", 12))
    .action_({ |btn|
        ("phono-control -d").unixCmd;
        // Reset GUI to match defaults
        AppClock.sched(0.1, {
            // Reset fader values
            lastInL = 86;
            lastInR = 86;
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
    .font_(Font("Helvetica", 12))
    .action_({ |btn|
        var cmd = if(btn.value == 1) { "phono-control -M" } { "phono-control -m" };
        cmd.unixCmd;
    });

~muteBtn = Button(mainView, Rect(76, 410, 60, 35))
    .states_([["MUTE", Color.cyan, Color.black], ["MUTE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 12))
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
    .font_(Font("Helvetica", 12))
    .value_(linkFaders.asInteger)
    .action_({ |btn| linkFaders = btn.value == 1; });

// --- ENCODER/DECODER MENUS ---
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

// Encoder menu (Input format selection)
~emenu = EZPopUpMenu.new(
    mainView,
    Rect(180, 45, 140, 35),
    "",
    [
        \UHJ -> { |a| configKeyE = \uhj; ("Encoder: UHJ").postln; },
        \SUPERSTEREO -> { |a| configKeyE = \superstereo; ("Encoder: SUPERSTEREO").postln; }
    ],
    globalAction: { |menu|
        ("Selected encoder: " ++ menu.item).postln;
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
        \BINAURAL ++ " IRCAM" -> { |a| inputs = 2; outputs = 2; configKeyD = \binaural; },
        \BINAURAL ++ " CIPIC" -> { |a| inputs = 2; outputs = 2; configKeyD = \binaurac; },
        \QUAD ++ " SQUARE" -> { |a| inputs = 2; outputs = 4; configKeyD = \quadsquare; },
        \QUAD ++ " NARROW" -> { |a| inputs = 2; outputs = 4; configKeyD = \quadnarrow; },
        \QUAD ++" WIDE" -> { |a| inputs = 2; outputs = 4; configKeyD = \quadwide; },
        \DOLBY ++" 5.1" -> { |a| inputs = 2; outputs = 6; configKeyD = \fivezero; },
        \OCTAGON -> { |a| inputs = 2; outputs = 8; configKeyD = \octagon; }
    ],
    globalAction: { |menu|
        var encoder, decoder, trans, ambient, roton;
        var decoderDict, encoderDict;
        
        ("Selected: " ++ menu.item).postln;
        ("Encoder: " ++ configKeyE).postln;
        ("Decoder: " ++ configKeyD).postln;
        ("Outputs: " ++ outputs).postln;
        ("Inputs: " ++ inputs).postln;
        
        // --- Update Layout overlay if it's open ---
        if(~layoutOverlay.notNil) {
            var decoderNames = ["BINAURAL IRCAM", "BINAURAL CIPIC", "QUAD SQUARE", "QUAD NARROW", "QUAD WIDE", "DOLBY 5.1", "OCTAGON"];
            var decoderName = decoderNames[menu.value];
            // Update the layout title
            ~layoutOverlay.children.do({ |child|
                if(child.class == StaticText and: { child.string.beginsWith("LAYOUT -") }) {
                    child.string_("LAYOUT - " ++ decoderName);
                };
            });
            // Refresh the graphics canvas
            ~layoutOverlay.children.do({ |child|
                if(child.class == UserView) { child.refresh; };
            });
        };
        
        // Initialize audio engine with selected configuration
        ~initAudioEngine.value();
    },
    initVal: 0,
    initAction: false,
    labelWidth: 0,
    labelHeight: 0,
    layout: \horz,
    gap: 0@0
);

// Style the menus to match the GUI prototype
~emenu.font = Font("Helvetica", 12);
~emenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);

~dmenu.font = Font("Helvetica", 12);
~dmenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);

// --- Track previous channel counts for safe decoder switching ---
~prevInputs = inputs;
~prevOutputs = outputs;

// Audio engine initialization function (from MainApp2)
~initAudioEngine = {
    var encoder, decoder, trans, ambient, roton;
    var decoderDict, encoderDict;
    var tryBoot;
    var needReboot;
    
    // Only reboot if channel counts have changed
    needReboot = (inputs != (~prevInputs ? inputs)) or: (outputs != (~prevOutputs ? outputs));
    
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
                    // Define encoder kernels
                    encoderDict = Dictionary.newFrom([
                        \uhj, FoaEncoderKernel.newUHJ,
                        \superstereo, FoaEncoderKernel.newSuper,
                    ]);
                    
                    // Define decoder kernels (matching MainApp2 exactly, excluding unused \none)
                    decoderDict = Dictionary.newFrom([
                        \binaural, FoaDecoderKernel.newListen(1053),
                        \binaurac, FoaDecoderKernel.newCIPIC(12),
                        \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                        \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                        \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual'),
                        \fivezero, FoaDecoderMatrix.new5_0(irregKind: 'focused'),
                        \octagon, FoaDecoderMatrix.newPanto(8, 'flat', k: 'single')
                    ]);
                    
                    // Get selected encoder and decoder
                    encoder = encoderDict.at(configKeyE ? \uhj);
                    decoder = decoderDict.at(configKeyD ? \binaural);
                    
                    ("Audio engine initialized with encoder: " ++ configKeyE ++ " and decoder: " ++ configKeyD).postln;
                    
                    // Load test audio file (same as MainApp2)
                    sndbuf = Buffer.read(s, Atk.userSoundsDir ++ "/uhj/01 Sodium Sunrise UHJ Render.wav");
                    
                    s.sync(cond);
                    
                    // Define the main audio processing SynthDef (adapted from MainApp2)
                    SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, ambience = 0|
                        var out, src, trans, encode, ambient;
                        
                        // Audio source - live input from hardware
                        src = SoundIn.ar([0,1]);
                        // For file playback testing, use: src = PlayBuf.ar(sndbuf.numChannels, buffer, BufRateScale.kr(buffer), loop: 1);
                        
                        // Amplitude scaling 
                        src = src * \amp.kr(-6.dbamp);
                        
                        // Encode to ambisonic using selected encoder (UHJ or SuperStereo)
                        encode = FoaEncode.ar(src, encoder);
                        
                        // Ambience processing
                        ambient = AmbiVerbSC.ar(encode,
                            mix: ambience,
                            preDelay: 0, 
                            crossoverFreq: 3000,
                            lowRT: 0.2,
                            highRT: 2,
                            dispersion: 1,
                            size: "Metallener Saal",
                            modWidth: 0.2,
                            modRate: 0.3,
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
                        
                        // Output handling - special case for 5.1 (add sub channel)
                        if(outputs == 6, {
                            var lowpass = BLowPass.ar((out[0] + out[4]), 120, 1, 0.4);
                            Out.ar(0, out); 
                            Out.ar(5, lowpass);
                        }, {
                            Out.ar(0, out);
                        });
                        
                    }).add;
                    
                    s.sync(cond);
                    
                    // Start the synth
                    s.unmute;
                    synth = Synth(\kernelEncodeDecode, [\buffer, sndbuf, \amp, voltmp]);
                    
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
                        // Define encoder kernels
                        encoderDict = Dictionary.newFrom([
                            \uhj, FoaEncoderKernel.newUHJ,
                            \superstereo, FoaEncoderKernel.newSuper,
                        ]);
                        
                        // Define decoder kernels (matching MainApp2 exactly, excluding unused \none)
                        decoderDict = Dictionary.newFrom([
                            \binaural, FoaDecoderKernel.newListen(1053),
                            \binaurac, FoaDecoderKernel.newCIPIC(12),
                            \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                            \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                            \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual'),
                            \fivezero, FoaDecoderMatrix.new5_0(irregKind: 'focused'),
                            \octagon, FoaDecoderMatrix.newPanto(8, 'flat', k: 'single')
                        ]);
                        
                        // Get selected encoder and decoder
                        encoder = encoderDict.at(configKeyE ? \uhj);
                        decoder = decoderDict.at(configKeyD ? \binaural);
                        
                        ("Audio engine initialized with encoder: " ++ configKeyE ++ " and decoder: " ++ configKeyD).postln;
                        
                        // Load test audio file (same as MainApp2)
                        sndbuf = Buffer.read(s, Atk.userSoundsDir ++ "/uhj/01 Sodium Sunrise UHJ Render.wav");
                        
                        s.sync(cond);
                        
                        // Define the main audio processing SynthDef (adapted from MainApp2)
                        SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, ambience = 0|
                            var out, src, trans, encode, ambient;
                            
                            // Audio source - live input from hardware
                            src = SoundIn.ar([0,1]);
                            // For file playback testing, use: src = PlayBuf.ar(sndbuf.numChannels, buffer, BufRateScale.kr(buffer), loop: 1);
                            
                            // Amplitude scaling 
                            src = src * \amp.kr(-6.dbamp);
                            
                            // Encode to ambisonic using selected encoder (UHJ or SuperStereo)
                            encode = FoaEncode.ar(src, encoder);
                            
                            // Ambience processing
                            ambient = AmbiVerbSC.ar(encode,
                                mix: ambience,
                                preDelay: 0, 
                                crossoverFreq: 3000,
                                lowRT: 0.2,
                                highRT: 2,
                                dispersion: 1,
                                size: "Metallener Saal",
                                modWidth: 0.2,
                                modRate: 0.3,
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
                            
                            // Output handling - special case for 5.1 (add sub channel)
                            if(outputs == 6, {
                                var lowpass = BLowPass.ar((out[0] + out[4]), 120, 1, 0.4);
                                Out.ar(0, out); 
                                Out.ar(5, lowpass);
                            }, {
                                Out.ar(0, out);
                            });
                            
                        }).add;
                        
                        s.sync(cond);
                        
                        // Start the synth
                        s.unmute;
                        synth = Synth(\kernelEncodeDecode, [\buffer, sndbuf, \amp, voltmp]);
                        
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
    // Update previous channel counts
    ~prevInputs = inputs;
    ~prevOutputs = outputs;
};

// --- Level Meter Section ---
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
lastInL = 86; // Default from phono-control -d
lastInR = 86;
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
~dmenu.value_(0); // BINAURAL IRCAM decoder

// Initialize hardware state
("phono-control -d").unixCmd;

// Start audio engine with initial configuration after a short delay
{
    ~initAudioEngine.value();
}.defer(0.5);

win.front;


// --- Overlay Buttons (EQ, AMBIENCE, LAYOUT) below meter area ---
~eqBtn = Button(mainView, Rect(180, 410, 100, 35))
    .states_([["EQ", Color.cyan, Color.black], ["EQ", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 12))
    .action_({ |btn|
        if(btn.value == 1) {
            if(~ambienceOverlay.notNil) { ~ambienceOverlay.remove; ~ambienceOverlay = nil; ~ambienceBtn.value_(0); };
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; ~layoutBtn.value_(0); };
            // TODO: Implement EQ overlay
        } {
            if(~eqOverlay.notNil) { ~eqOverlay.remove; ~eqOverlay = nil; };
        }
    });
~ambienceBtn = Button(mainView, Rect(287, 410, 100, 35))
    .states_([["AMBIENCE", Color.cyan, Color.black], ["AMBIENCE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 12))
    .action_({ |btn|
        if(btn.value == 1) {
            if(~eqOverlay.notNil) { ~eqOverlay.remove; ~eqOverlay = nil; ~eqBtn.value_(0); };
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; ~layoutBtn.value_(0); };
            // TODO: Implement Ambience overlay
        } {
            if(~ambienceOverlay.notNil) { ~ambienceOverlay.remove; ~ambienceOverlay = nil; };
        }
    });
~layoutBtn = Button(mainView, Rect(394, 410, 100, 35))
    .states_([["LAYOUT", Color.cyan, Color.black], ["LAYOUT", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 12))
    .action_({ |btn|
        var currentDecoder, decoderNames, decoderName;
        if(btn.value == 1) {
            if(~eqOverlay.notNil) { ~eqOverlay.remove; ~eqOverlay = nil; ~eqBtn.value_(0); };
            if(~ambienceOverlay.notNil) { ~ambienceOverlay.remove; ~ambienceOverlay = nil; ~ambienceBtn.value_(0); };
            ~layoutOverlay = View(mainView, Rect(180, 107, 320, 275))
                .background_(Color.black.alpha_(0.5)); // More transparent overlay
            UserView(~layoutOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });
            currentDecoder = ~dmenu.value;
            decoderNames = ["BINAURAL IRCAM", "BINAURAL CIPIC", "QUAD SQUARE", "QUAD NARROW", "QUAD WIDE", "DOLBY 5.1", "OCTAGON"];
            decoderName = decoderNames[currentDecoder];
            StaticText(~layoutOverlay, Rect(10, 5, 300, 22))
                .string_("LAYOUT - " ++ decoderName)
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 12).boldVariant)
                .background_(Color.clear);
            UserView(~layoutOverlay, Rect(10, 30, 300, 235))
                .background_(Color.clear)
                .drawFunc_({ |view|
                    var bounds = view.bounds;
                    var centerX = bounds.width / 2;
                    var centerY = bounds.height / 2;
                    var currentDecoderValue = ~dmenu.value;
                    Pen.color = Color.black;
                    Pen.addRect(Rect(0, 0, bounds.width, bounds.height));
                    Pen.fill;
                    Pen.width = 2;
                    switch(currentDecoderValue,
                        0, {
                            var earCupWidth = 20, earCupHeight = 27, earCupOffset = 55, arcCenterY = centerY - 25, arcRadius = 47, leftEarX, leftEarY, rightEarX, rightEarY;
                            leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                            leftEarY = centerY + 25;
                            rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                            rightEarY = centerY + 25;
                            Pen.color = Color.cyan; Pen.width = 2;
                            Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi); Pen.stroke;
                            Pen.moveTo(Point(centerX - arcRadius, centerY - 30)); Pen.lineTo(Point(centerX - arcRadius, leftEarY)); Pen.stroke;
                            Pen.moveTo(Point(centerX + arcRadius, centerY - 30)); Pen.lineTo(Point(centerX + arcRadius, rightEarY)); Pen.stroke;
                            Pen.color = Color.black; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(leftEarX + 6, leftEarY + 5), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rightEarX + 6, rightEarY + 5), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.stringAtPoint("Headphone Listening using IRCAM HTRF Library", Point(centerX - 135, 10), Font("Helvetica", 12), Color.cyan);
                        },
                        1, {
                            var earCupWidth = 20, earCupHeight = 27, earCupOffset = 55, arcCenterY = centerY - 25, arcRadius = 47, leftEarX, leftEarY, rightEarX, rightEarY;
                            leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                            leftEarY = centerY + 25;
                            rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                            rightEarY = centerY + 25;
                            Pen.color = Color.cyan; Pen.width = 2;
                            Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi); Pen.stroke;
                            Pen.moveTo(Point(centerX - arcRadius, centerY - 25)); Pen.lineTo(Point(centerX - arcRadius, leftEarY)); Pen.stroke;
                            Pen.moveTo(Point(centerX + arcRadius, centerY - 25)); Pen.lineTo(Point(centerX + arcRadius, rightEarY)); Pen.stroke;
                            Pen.color = Color.black; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(leftEarX + 6, leftEarY + 5), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rightEarX + 6, rightEarY + 5), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.stringAtPoint("Headphone Listening using CIPIC HTRF Library", Point(centerX - 135, 10), Font("Helvetica", 12), Color.cyan);
                        },
                        2, {
                            var squareSize = 140, halfSquare = squareSize / 2;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare, centerY - halfSquare, squareSize, squareSize)); Pen.stroke;
                            Pen.color = Color.black; Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(centerX - halfSquare - 10 + 7, centerY - halfSquare - 10 + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + squareSize, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + squareSize, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(centerX - halfSquare - 10 + 7, centerY - halfSquare - 10 + squareSize + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + squareSize, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + squareSize, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(centerX - halfSquare - 10 + squareSize + 7, centerY - halfSquare - 10 + squareSize + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(centerX - halfSquare - 10 + squareSize + 7, centerY - halfSquare - 10 + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.stringAtPoint("Equal distance between all speakers", Point(centerX - 97, 10), Font("Helvetica", 12), Color.cyan);
                        },
                        3, {
                            var rectHeight = 140, rectWidth = (rectHeight * 0.75).asInteger, rectLeft = centerX - (rectWidth / 2), rectTop = centerY - (rectHeight / 2);
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight)); Pen.stroke;
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(rectLeft - 10 + 7, rectTop - 10 + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rectLeft - 10 + 7, rectTop + rectHeight - 10 + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(rectLeft + rectWidth - 10 + 7, rectTop + rectHeight - 10 + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(rectLeft + rectWidth - 10 + 7, rectTop - 10 + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.stringAtPoint("Narrow Quadraphonic arrangement (x ≤ 0.75y)", Point(centerX - 115, 10), Font("Helvetica", 12), Color.cyan);
                        },
                        4, {
                            var rectWidth = 140, rectHeight = 105, rectLeft = centerX - (rectWidth / 2), totalHeight = rectHeight + 20, rectTop = centerY - (totalHeight / 2) + 10;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight)); Pen.stroke;
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(rectLeft - 10 + 7, rectTop - 10 + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rectLeft - 10 + 7, rectTop + rectHeight - 10 + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(rectLeft + rectWidth - 10 + 7, rectTop + rectHeight - 10 + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(rectLeft + rectWidth - 10 + 7, rectTop - 10 + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.stringAtPoint("Wide Quadraphonic arrangement (x ≥ 1.33y)", Point(centerX - 114, 10), Font("Helvetica", 12), Color.cyan);
                        },
                        5, {
                            var layoutSize = 140, layoutLeft = centerX - (layoutSize / 2), layoutTop = centerY - (layoutSize / 2), speakerSize = 20, frontLeftX = layoutLeft - 10, frontLeftY = layoutTop - 10, frontRightX = layoutLeft + layoutSize - 10, frontRightY = layoutTop - 10, centerX_speaker = layoutLeft + (layoutSize / 2) - 10, centerY_speaker = layoutTop - 10, surroundLeftX = layoutLeft - 10, surroundLeftY = layoutTop + layoutSize - 10, surroundRightX = layoutLeft + layoutSize - 10, surroundRightY = layoutTop + layoutSize - 10, subwooferX = layoutLeft + (layoutSize / 2) - 10, subwooferY = layoutTop + (layoutSize / 2) - 10;
                            Pen.color = Color.cyan; Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize)); Pen.stroke;
                            Pen.color = Color.black; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 7, frontLeftY + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 7, frontRightY + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(centerX_speaker + 7, centerY_speaker + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundLeftX + 7, surroundLeftY + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("5", Point(surroundRightX + 7, surroundRightY + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.color = Color.cyan; Pen.addRect(Rect(subwooferX, subwooferY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("6", Point(subwooferX + 7, subwooferY + 1), Font("Helvetica", 12).boldVariant, Color.cyan);
                            Pen.stringAtPoint("SUB", Point(subwooferX + 25, subwooferY + 3), Font("Helvetica", 10).boldVariant, Color.cyan);
                            Pen.stringAtPoint("[1] 0°, [2] -30°, [3] +30° [4] -110°, [5] +110°, [6] Sub", Point(centerX - 136, 10), Font("Helvetica", 12), Color.cyan);
                        },
                        6, {
                            var radius = 80, angleStep = 2 * pi / 8, startAngle = -22.5 * pi / 180, speakerPositions;
                            speakerPositions = Array.fill(8, { |i| var angle = startAngle + (i * angleStep); var x = centerX + (radius * cos(angle)) - 10; var y = centerY + (radius * sin(angle)) - 10; Point(x, y); });
                            // Revert: draw solid black oval fill for octagon layout (no transparency)
                            Pen.color = Color.black;
                            Pen.addOval(Rect(centerX - radius, centerY - radius, radius * 2, radius * 2));
                            Pen.fill;
                            // Draw oval border
                            Pen.color = Color.cyan; 
                            Pen.addOval(Rect(centerX - radius, centerY - radius, radius * 2, radius * 2)); 
                            Pen.stroke;
                            // Draw speaker boxes
                            speakerPositions.do({ |pos, i| 
                                var speakerNum = ((i + 2) % 8) + 1; 
                                var angle = startAngle + (i * angleStep); 
                                var rotationAngle = angle + (pi / 2); 
                                Pen.push; 
                                Pen.translate(pos.x + 10, pos.y + 10); 
                                Pen.rotate(rotationAngle); 
                                Pen.translate(-10, -10); 
                                Pen.color = Color.black; 
                                Pen.addRect(Rect(0, 0, 20, 20)); 
                                Pen.fill; 
                                Pen.color = Color.cyan; 
                                Pen.addRect(Rect(0, 0, 20, 20)); 
                                Pen.stroke; 
                                Pen.stringAtPoint(speakerNum.asString, Point(7, 1), Font("Helvetica", 12).boldVariant, Color.cyan); 
                                Pen.pop; 
                            });
                            Pen.stringAtPoint("[1] -22.5°, Speakers @ 45°", Point(centerX - 69, 10), Font("Helvetica", 12), Color.cyan);
                        }
                    );
                });
            ~layoutOverlay.front;
        } {
            if(~layoutOverlay.notNil) {
                ~layoutOverlay.remove;
                ~layoutOverlay = nil;
            };
        }
    });
)
