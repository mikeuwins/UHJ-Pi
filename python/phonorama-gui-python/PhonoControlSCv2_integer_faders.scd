(
    // Phono Control UI — with rounded border box and all controls
    var win, view, paddedView, isUpdating = false;
    var leftSlider, rightSlider, leftSlider2, rightSlider2;
    var labelLTop, labelRTop, labelLVal, labelRVal;
    var labelLTop2, labelRTop2, labelLVal2, labelRVal2;
    var labelInput, labelOutput, divider;
    var inputButtons, buttonLabels;
    var monitorButton, muteInputButton, muteOutputButton, linkButton, headphoneButton, resetButton;
    var linkFaders = true;
    var font = Font("Helvetica", 10), fontBold = Font("Helvetica", 10).boldVariant;

    var lastInL = 96, lastInR = 96, lastOutL = 145, lastOutR = 145;

    var faderWidth = 20, faderHeight = 230;
    var buttonWidth = 45, buttonHeight = 18, buttonSpacing = 6;
    var padding = 20, shift = 5, gapBetweenGroups = 25;

    var xInputL, xInputR, xOutputL, xOutputR, xDivider, rightButtonX;
    var yBtnLine, yBtnMM, yBtnMC;

    xInputL  = shift + 60;
    xInputR  = xInputL + faderWidth + 10;
    xDivider = xInputR + faderWidth + (gapBetweenGroups div: 2);
    xOutputL = xDivider + 15;
    xOutputR = xOutputL + faderWidth + 10;
    rightButtonX = shift + 202;

    yBtnLine = 46;
    yBtnMM   = yBtnLine + (buttonHeight + buttonSpacing);
    yBtnMC   = yBtnMM + (buttonHeight + buttonSpacing);

    Window.closeAll;
    win  = Window("Phonorama Control", Rect(100, 100, 295, 370));
    view = CompositeView(win, win.view.bounds);

    // --- Rounded border box (non-interactive) ---
    UserView(view, view.bounds)
        .background_(Color.clear)  // transparent to avoid blocking events
        .drawFunc_({ |v|
            Pen.width = 1.5;
            Pen.color = Color.gray;
            Pen.addRoundedRect(Rect(1, 1, v.bounds.width - 2, v.bounds.height - 2), 12, 12);
            Pen.stroke;
        });

    // Inner container with padding
    paddedView = CompositeView(view, Rect(padding, padding, win.view.bounds.width - 2*padding, win.view.bounds.height - 2*padding));

    // --- Ruler tick marks next to sliders ---
    UserView(paddedView, Rect(xInputL - 6, 45, 6, faderHeight))
        .background_(Color.clear)
        .drawFunc_({ |vu|
            Pen.width = 1;
            (0..(faderHeight/20).floor).do { |i|
                var y = i * 20;
                Pen.moveTo(Point(6, y));
                Pen.lineTo(Point(0, y));
            };
            Pen.stroke;
        });
    UserView(paddedView, Rect(xInputR + faderWidth, 45, 6, faderHeight))
        .background_(Color.clear)
        .drawFunc_({ |vu|
            Pen.width = 1;
            (0..(faderHeight/20).floor).do { |i|
                var y = i * 20;
                Pen.moveTo(Point(0, y));
                Pen.lineTo(Point(6, y));
            };
            Pen.stroke;
        });
    UserView(paddedView, Rect(xOutputL - 6, 45, 6, faderHeight))
        .background_(Color.clear)
        .drawFunc_({ |vu|
            Pen.width = 1;
            (0..(faderHeight/20).floor).do { |i|
                var y = i * 20;
                Pen.moveTo(Point(6, y));
                Pen.lineTo(Point(0, y));
            };
            Pen.stroke;
        });
    UserView(paddedView, Rect(xOutputR + faderWidth, 45, 6, faderHeight))
        .background_(Color.clear)
        .drawFunc_({ |vu|
            Pen.width = 1;
            (0..(faderHeight/20).floor).do { |i|
                var y = i * 20;
                Pen.moveTo(Point(0, y));
                Pen.lineTo(Point(6, y));
            };
            Pen.stroke;
        });

    // --- Input select buttons (LINE, MM, MC) ---
    inputButtons = List.new;
    buttonLabels = [["LINE", "line"], ["MM", "mm"], ["MC", "mc"]];
    buttonLabels.do { |pair, index|
        var label = pair[0];
        var cmd   = pair[1];
        var yPos  = [yBtnLine, yBtnMM, yBtnMC][index];
        var btn   = Button(paddedView, Rect(5, yPos, buttonWidth, buttonHeight))
            .states_([
                [ label, Color.black, Color.new(0.85, 0.85, 0.85) ],  // off state (gray)
                [ label, Color.black, Color.cyan ]                   // on state  (cyan)
            ])
            .font_(fontBold)
            .action_({
                // Deselect all and then select this one
                inputButtons.do { |b| b.value_(0) };
                btn.value_(1);
                ("phono-control -c " ++ cmd).unixCmd;  // send CLI command for input select
            });
        if (index == 0) { btn.value_(1) };  // default to LINE selected
        inputButtons.add(btn);
    };

    // --- Section labels (Input/Output and L/R) ---
    labelInput  = StaticText(paddedView, Rect(xInputL, 5, (faderWidth * 2) + 10, 20))
                   .string_("INPUT").align_(\center).font_(fontBold);
    labelOutput = StaticText(paddedView, Rect(xOutputL, 5, (faderWidth * 2) + 10, 20))
                   .string_("OUTPUT").align_(\center).font_(fontBold);
    labelLTop   = StaticText(paddedView, Rect(xInputL, 25, faderWidth, 20))
                   .string_("L").align_(\center).font_(font);
    labelRTop   = StaticText(paddedView, Rect(xInputR, 25, faderWidth, 20))
                   .string_("R").align_(\center).font_(font);
    labelLTop2  = StaticText(paddedView, Rect(xOutputL, 25, faderWidth, 20))
                   .string_("L").align_(\center).font_(font);
    labelRTop2  = StaticText(paddedView, Rect(xOutputR, 25, faderWidth, 20))
                   .string_("R").align_(\center).font_(font);

    // --- Value labels below faders (no decimals) ---
    labelLVal  = StaticText(paddedView, Rect(xInputL,  faderHeight + 50, faderWidth, 20))
                  .align_(\center).font_(font).string_(lastInL.asString);
    labelRVal  = StaticText(paddedView, Rect(xInputR,  faderHeight + 50, faderWidth, 20))
                  .align_(\center).font_(font).string_(lastInR.asString);
    labelLVal2 = StaticText(paddedView, Rect(xOutputL, faderHeight + 50, faderWidth, 20))
                  .align_(\center).font_(font).string_(lastOutL.asString);
    labelRVal2 = StaticText(paddedView, Rect(xOutputR, faderHeight + 50, faderWidth, 20))
                  .align_(\center).font_(font).string_(lastOutR.asString);

    // --- Input gain sliders (Left and Right) ---
    leftSlider = Slider(paddedView, Rect(xInputL, 45, faderWidth, faderHeight))
        .orientation_(\vertical)
        .canFocus_(false)
        .value_(lastInL / 127)   // normalize to 0-1 range
        .action_({ |s|
            lastInL = (s.value * 127).round;
            labelLVal.string_(lastInL.asInteger.asString);
            if (linkFaders) {
                // If linked, mirror to right slider
                rightSlider.value_(s.value);
                lastInR = lastInL;
                labelRVal.string_(lastInR.asInteger.asString);
            };
        });
    rightSlider = Slider(paddedView, Rect(xInputR, 45, faderWidth, faderHeight))
        .orientation_(\vertical)
        .canFocus_(false)
        .value_(lastInR / 127)
        .action_({ |s|
            lastInR = (s.value * 127).round;
            labelRVal.string_(lastInR.asInteger.asString);
            if (linkFaders) {
                // If linked, mirror to left slider
                leftSlider.value_(s.value);
                lastInL = lastInR;
                labelLVal.string_(lastInL.asInteger.asString);
            };
        });

    // --- Output volume sliders (Left and Right) ---
    leftSlider2 = Slider(paddedView, Rect(xOutputL, 45, faderWidth, faderHeight))
        .orientation_(\vertical)
        .canFocus_(false)
        .value_(lastOutL / 145)
        .action_({ |s|
            lastOutL = (s.value * 145).round;
            labelLVal2.string_(lastOutL.asInteger.asString);
            if (linkFaders) {
                // If linked, mirror to right output slider
                rightSlider2.value_(s.value);
                lastOutR = lastOutL;
                labelRVal2.string_(lastOutR.asInteger.asString);
            };
        });
    rightSlider2 = Slider(paddedView, Rect(xOutputR, 45, faderWidth, faderHeight))
        .orientation_(\vertical)
        .canFocus_(false)
        .value_(lastOutR / 145)
        .action_({ |s|
            lastOutR = (s.value * 145).round;
            labelRVal2.string_(lastOutR.asInteger.asString);
            if (linkFaders) {
                // If linked, mirror to left output slider
                leftSlider2.value_(s.value);
                lastOutL = lastOutR;
                labelLVal2.string_(lastOutL.asInteger.asString);
            };
        });

    // --- Divider line between Input and Output sections ---
    divider = UserView(paddedView, Rect(xDivider, 45, 1, faderHeight))
               .background_(Color.gray);

    // --- Monitor (MON) toggle button ---
    monitorButton = Button(paddedView, Rect(xInputL + 45, 5, 32, 18))
        .states_([
            [ "MON", Color.black, Color.new(0.85, 0.85, 0.85) ],   // off: gray background
            [ "MON", Color.black, Color.new(1.0, 0.647, 0.0) ]    // on: orange background
        ])
        .font_(fontBold)
        .value_(1)  // start in ON state (orange)
        .action_({ |btn|
            var cmd = if (btn.value == 1) { "phono-control -M" } { "phono-control -m" };
            cmd.unixCmd;
        });

    // --- Mute buttons for Input and Output ---
    muteInputButton = Button(paddedView, Rect(xInputL - 1, faderHeight + 75, (faderWidth * 2) + 10, 20))
        .states_([
            [ "MUTE", Color.black, Color.new(0.85, 0.85, 0.85) ],  // off: gray
            [ "MUTE", Color.white, Color.red ]                    // on: red (text white)
        ])
        .font_(fontBold)
        .value_(0)
        .action_({ "phono-control -c mute".unixCmd });
    muteOutputButton = Button(paddedView, Rect(xOutputL - 1, faderHeight + 75, (faderWidth * 2) + 10, 20))
        .states_([
            [ "MUTE", Color.black, Color.new(0.85, 0.85, 0.85) ],
            [ "MUTE", Color.white, Color.red ]
        ])
        .font_(fontBold)
        .value_(0)
        .action_({ "phono-control -c mute".unixCmd });

    // --- Link (L/R fader link) toggle button ---
    linkButton = Button(paddedView, Rect(rightButtonX, yBtnLine, buttonWidth, buttonHeight))
        .states_([
            [ "LINK", Color.black, Color.new(0.85, 0.85, 0.85) ],  // off: gray (independent)
            [ "LINK", Color.black, Color.new(1.0, 0.55, 0.0) ]    // on: orange (linked)
        ])
        .font_(fontBold)
        .value_(1)  // start linked
        .action_({ |btn|
            linkFaders = (btn.value == 1);
        });

    // --- Headphone (HP) monitor toggle button ---
    headphoneButton = Button(paddedView, Rect(rightButtonX, yBtnMM, buttonWidth, buttonHeight))
        .states_([
            [ "HP", Color.black, Color.new(0.85, 0.85, 0.85) ],   // off: gray
            [ "HP", Color.black, Color.new(1.0, 0.55, 0.0) ]     // on: orange
        ])
        .font_(fontBold)
        .value_(1)  // start ON
        .action_({ |btn|
            var cmd = if (btn.value == 1) { "phono-control -i" } { "phono-control -I" };
            cmd.unixCmd;
        });

    // --- Reset button (resets all faders to default) ---
    resetButton = Button(paddedView, Rect(rightButtonX, yBtnMC, buttonWidth, buttonHeight))
        .states_([
            [ "RESET", Color.black, Color.new(0.85, 0.85, 0.85) ],  // normal
            [ "RESET", Color.black, Color.new(0.7, 0.7, 0.7) ]     // pressed (darker gray)
        ])
        .font_(fontBold)
        .action_({
            isUpdating = true;   // flag to prevent immediate mouseUp trigger

            // Reset slider values (both UI and stored variables)
            leftSlider.value_(96 / 127);
            rightSlider.value_(96 / 127);
            leftSlider2.value_(1.0);
            rightSlider2.value_(1.0);

            lastInL  = 96;
            lastInR  = 96;
            lastOutL = 145;
            lastOutR = 145;

            // Update value label text
            labelLVal.string_(lastInL.asString);
            labelRVal.string_(lastInR.asString);
            labelLVal2.string_(lastOutL.asString);
            labelRVal2.string_(lastOutR.asString);

            // Send CLI commands to apply the reset values
            "phono-control -l 96 -r 96".unixCmd;
            "phono-control -L 145 -R 145".unixCmd;

            isUpdating = false;
        });
        

    // --- Mouse-up event to send CLI updates after slider moves ---
    view.mouseUpAction_({
        if (isUpdating.not) {  // only if not in a programmatic update
            ("phono-control -l " ++ lastInL ++ " -r " ++ lastInR).unixCmd;
            ("phono-control -L " ++ lastOutL ++ " -R " ++ lastOutR).unixCmd;
        }
    });

    win.front;
)

