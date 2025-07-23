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

// Audio engine initialization function (from MainApp2)
~initAudioEngine = {
    var encoder, decoder, trans, ambient, roton;
    var decoderDict, encoderDict;
    var tryBoot;
    
    tryBoot = {
        if(s.serverBooting, {
            // Server is busy, retry after 0.2s
            ("Server busy (booting), retrying audio engine init...").postln;
            AppClock.sched(0.2, { tryBoot.value });
        }, {
            // Server is ready
            if(s.serverRunning, {
                s.options.memSize = 65536;
                s.options.numOutputBusChannels = outputs;
                s.options.numInputBusChannels = inputs;
                s.reboot;
            }, {
                s.options.memSize = 65536;
                s.options.numOutputBusChannels = outputs;
                s.options.numInputBusChannels = inputs;
                s.boot;
            });
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
    };
    tryBoot.value;
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
)
