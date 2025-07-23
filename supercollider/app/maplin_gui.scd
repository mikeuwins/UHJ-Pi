// Maplin SM-333 Authentic Front Panel GUI
// Based on original front panel layout from brochure

~createSM333GUI = {
    var window, surroundKnob, effectKnob, delayKnob, bypassButton;
    var powerLED, surroundLED;
    var titleText, modelText;
    var knobSpecs, currentValues;

    // Store current values
    currentValues = (
        surround: 0.8,
        effect: 0.8,
        delay: 0.025,
        bypass: false,
        power: true
    );

    // Create main window - sized to match proportions of original
    window = Window("Maplin SM-333 Surround Sound Processor",
        Rect(100, 100, 480, 200))
        .background_(Color.grey(0.85))
        .alwaysOnTop_(false);

    // Title and model number (top left area)
    StaticText(window, Rect(20, 15, 300, 16))
        .string_("SURROUND SOUND PROCESSOR")
        .font_(Font("Arial", 11, true))
        .stringColor_(Color.black);

    StaticText(window, Rect(380, 15, 80, 16))
        .string_("SM-333")
        .font_(Font("Arial", 11, true))
        .stringColor_(Color.black);

    // Power section (left side)
    StaticText(window, Rect(30, 50, 50, 14))
        .string_("POWER")
        .font_(Font("Arial", 9, true))
        .stringColor_(Color.black);

    // Power LED indicator
    powerLED = UserView(window, Rect(45, 70, 12, 12))
        .background_(Color.green)
        .drawFunc_({
            Pen.addOval(Rect(2, 2, 8, 8));
            Pen.fill;
        });

    // Function section labels (center)
    StaticText(window, Rect(120, 40, 60, 14))
        .string_("FUNCTION")
        .font_(Font("Arial", 9, true))
        .stringColor_(Color.black);

    // Bypass button (styled like original switch)
    bypassButton = Button(window, Rect(130, 60, 60, 25))
        .states_([
            ["SURROUND", Color.black, Color.grey(0.9)],
            ["BYPASS", Color.white, Color.red(0.7)]
        ])
        .font_(Font("Arial", 8, true))
        .action_({ |btn|
            currentValues.bypass = btn.value == 1;
            ~setSurroundActive.(currentValues.bypass.not);
            if(currentValues.bypass, {
                "Surround BYPASSED - front channels only".postln;
            }, {
                "Surround ACTIVE".postln;
            });
        });

    // Control knobs section (right side)

    // Surround Level Knob
    StaticText(window, Rect(240, 40, 80, 14))
        .string_("SURROUND LEVEL")
        .font_(Font("Arial", 8, true))
        .stringColor_(Color.black)
        .align_(\center);

    surroundKnob = Knob(window, Rect(255, 60, 50, 50))
        .background_(Color.grey(0.3))
        .color_([Color.grey(0.7), Color.white, Color.black, Color.blue])
        .value_(0.8)
        .action_({ |knob|
            currentValues.surround = knob.value;
            ~setSurroundLevel.(knob.value);
            ("Surround Level: " ++ (knob.value * 100).round(1) ++ "%").postln;
        });

    // Min/Max labels for Surround
    StaticText(window, Rect(240, 115, 25, 10))
        .string_("MIN")
        .font_(Font("Arial", 7))
        .stringColor_(Color.black);
    StaticText(window, Rect(280, 115, 25, 10))
        .string_("MAX")
        .font_(Font("Arial", 7))
        .stringColor_(Color.black);

    // Effect Level Knob
    StaticText(window, Rect(320, 40, 50, 14))
        .string_("EFFECT")
        .font_(Font("Arial", 8, true))
        .stringColor_(Color.black)
        .align_(\center);

    effectKnob = Knob(window, Rect(332, 60, 50, 50))
        .background_(Color.grey(0.3))
        .color_([Color.grey(0.7), Color.white, Color.black, Color.blue])
        .value_(0.8)
        .action_({ |knob|
            currentValues.effect = knob.value;
            ~setEffectLevel.(knob.value);
            ("Effect Level: " ++ (knob.value * 100).round(1) ++ "%").postln;
        });

    // Min/Max labels for Effect
    StaticText(window, Rect(317, 115, 25, 10))
        .string_("MIN")
        .font_(Font("Arial", 7))
        .stringColor_(Color.black);
    StaticText(window, Rect(357, 115, 25, 10))
        .string_("MAX")
        .font_(Font("Arial", 7))
        .stringColor_(Color.black);

    // Delay Time Knob
    StaticText(window, Rect(395, 40, 60, 14))
        .string_("DELAY TIME")
        .font_(Font("Arial", 8, true))
        .stringColor_(Color.black)
        .align_(\center);

    delayKnob = Knob(window, Rect(410, 60, 50, 50))
        .background_(Color.grey(0.3))
        .color_([Color.grey(0.7), Color.white, Color.black, Color.blue])
        .value_(0.44)  // 0.025 is roughly in middle of 0.005-0.050 range
        .action_({ |knob|
            var delayMs = knob.value.linlin(0, 1, 5, 50);
            var delaySec = delayMs / 1000;
            currentValues.delay = delaySec;
            ~setDelayTime.(knob.value);  // Send 0-1 value as expected
            ("Delay Time: " ++ delayMs.round(1) ++ "ms").postln;
        });

    // Min/Max labels for Delay
    StaticText(window, Rect(395, 115, 25, 10))
        .string_("MIN")
        .font_(Font("Arial", 7))
        .stringColor_(Color.black);
    StaticText(window, Rect(435, 115, 25, 10))
        .string_("MAX")
        .font_(Font("Arial", 7))
        .stringColor_(Color.black);

    // Add some vintage styling - simulated panel lines
    UserView(window, Rect(10, 35, 460, 1))
        .background_(Color.grey(0.6));
    UserView(window, Rect(10, 140, 460, 1))
        .background_(Color.grey(0.6));

    // Status display area
    StaticText(window, Rect(20, 150, 200, 14))
        .string_("Ready - Surround Active")
        .font_(Font("Arial", 9))
        .stringColor_(Color.black);

    // Preset buttons (additional convenience)
    Button(window, Rect(20, 170, 60, 20))
        .states_([["PRESET 1", Color.black, Color.grey(0.9)]])
        .font_(Font("Arial", 8))
        .action_({
            surroundKnob.value_(0.7);
            effectKnob.value_(0.7);
            delayKnob.value_(0.4);
            currentValues.surround = 0.7;
            currentValues.effect = 0.7;
            currentValues.delay = 0.025;
            ~setSurroundLevel.(0.7);
            ~setEffectLevel.(0.7);
            ~setDelayTime.(0.4);
            "Preset 1: Balanced settings loaded".postln;
        });

    Button(window, Rect(85, 170, 60, 20))
        .states_([["PRESET 2", Color.black, Color.grey(0.9)]])
        .font_(Font("Arial", 8))
        .action_({
            surroundKnob.value_(1.0);
            effectKnob.value_(1.0);
            delayKnob.value_(0.6);
            currentValues.surround = 1.0;
            currentValues.effect = 1.0;
            currentValues.delay = 0.035;
            ~setSurroundLevel.(1.0);
            ~setEffectLevel.(1.0);
            ~setDelayTime.(0.6);
            "Preset 2: Maximum surround loaded".postln;
        });

    // Close action
    window.onClose_({
        "SM-333 GUI closed".postln;
    });

    // Make window visible
    window.front;

    // Store window reference
    ~sm333Window = window;

    "Maplin SM-333 Front Panel GUI created".postln;
    "Use the knobs and bypass button just like the original hardware!".postln;

    // Return the window
    window;
};

// Auto-create GUI function to add to your existing code
// Add this after your existing control functions:

~showGUI = {
    if(~sm333Window.notNil and: { ~sm333Window.isClosed.not }, {
        ~sm333Window.front;
        "GUI already open - bringing to front".postln;
    }, {
        ~createSM333GUI.();
    });
};

// Add to your help display:
"~showGUI() - Open authentic SM-333 front panel".postln;
