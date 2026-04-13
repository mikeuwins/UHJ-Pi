(
// Phono Control UI — with rounded border box

var win, view, paddedView, isUpdating = false;
var leftSlider, rightSlider, leftSlider2, rightSlider2;
var labelLTop, labelRTop, labelLVal, labelRVal;
var labelLTop2, labelRTop2, labelLVal2, labelRVal2;
var labelInput, labelOutput, divider;
var inputButtons, buttonLabels;
var monitorButton, muteInputButton, muteOutputButton, linkButton, headphoneButton, resetButton;
var prevInputChannel = "line"; // default to "line"
var currentInputChannel = "line";
var linkFaders = true;
var font = Font("Helvetica", 10), fontBold = Font("Helvetica", 10).boldVariant;
var lastInL = 96, lastInR = 96, lastOutL = 145, lastOutR = 145;
var prevOutL = lastOutL, prevOutR = lastOutR;
var prevInL = lastInL, prevInR = lastInR; 
var minIn = 60, maxIn = 127; 
var lastFaderGroup = \none;
var faderWidth = 20, faderHeight = 230;
var buttonWidth = 45, buttonHeight = 18, buttonSpacing = 6;
var padding = 20, shift = 5, gapBetweenGroups = 25;

var xInputL, xInputR, xOutputL, xOutputR, xDivider, rightButtonX;
var yBtnLine, yBtnMM, yBtnMC;

xInputL = shift + 60;
xInputR = xInputL + faderWidth + 10;
xDivider = xInputR + faderWidth + (gapBetweenGroups div: 2);
xOutputL = xDivider + 15;
xOutputR = xOutputL + faderWidth + 10;
rightButtonX = shift + 202;

yBtnLine = 46;
yBtnMM = yBtnLine + (buttonHeight + buttonSpacing);
yBtnMC = yBtnMM + (buttonHeight + buttonSpacing);

Window.closeAll;
win = Window("Phonorama Control", Rect(100, 100, 295, 370));
view = CompositeView(win, win.view.bounds);

// --- Rounded border box ---
UserView(view, view.bounds)
    .background_(Color.clear)
    .drawFunc_({ |v|
        Pen.width = 1.5;
        Pen.color = Color.gray;
        Pen.addRoundedRect(Rect(1, 1, v.bounds.width - 2, v.bounds.height - 2), 12, 12);
        Pen.stroke;
    });

paddedView = CompositeView(view, Rect(padding, padding, win.view.bounds.width - 2*padding, win.view.bounds.height - 2*padding));

// --- Ruler ticks ---
UserView(paddedView, Rect(xInputL - 6, 45, 6, faderHeight))
    .drawFunc_({ |view|
        Pen.width = 1;
        (0..(faderHeight/20).floor).do { |i|
            var y = i * 20;
            Pen.moveTo(Point(6, y));
            Pen.lineTo(Point(0, y));
        };
        Pen.stroke;
    });

UserView(paddedView, Rect(xInputR + faderWidth, 45, 6, faderHeight))
    .drawFunc_({ |view|
        Pen.width = 1;
        (0..(faderHeight/20).floor).do { |i|
            var y = i * 20;
            Pen.moveTo(Point(0, y));
            Pen.lineTo(Point(6, y));
        };
        Pen.stroke;
    });

UserView(paddedView, Rect(xOutputL - 6, 45, 6, faderHeight))
    .drawFunc_({ |view|
        Pen.width = 1;
        (0..(faderHeight/20).floor).do { |i|
            var y = i * 20;
            Pen.moveTo(Point(6, y));
            Pen.lineTo(Point(0, y));
        };
        Pen.stroke;
    });

UserView(paddedView, Rect(xOutputR + faderWidth, 45, 6, faderHeight))
    .drawFunc_({ |view|
        Pen.width = 1;
        (0..(faderHeight/20).floor).do { |i|
            var y = i * 20;
            Pen.moveTo(Point(0, y));
            Pen.lineTo(Point(6, y));
        };
        Pen.stroke;
    });

// --- Select Buttons ---
inputButtons = List.new;
buttonLabels = [["LINE", "line"], ["MM", "mm"], ["MC", "mc"]];

buttonLabels.do { |pair, index|
    var label = pair[0];
    var cmd = pair[1];
    var y = [yBtnLine, yBtnMM, yBtnMC][index];
    var btn;

    btn = Button(paddedView, Rect(5, y, buttonWidth, buttonHeight))
    .states_([
        [label, Color.black, Color.new(0.85, 0.85, 0.85)],
        [label, Color.black, Color.cyan]
    ])
    .font_(fontBold)
    .action_({
        inputButtons.do { |b| b.value_(0) };
        btn.value_(1);
        currentInputChannel = cmd; // Track the current channel
        ("phono-control -c " ++ cmd).unixCmd;
    });

    if (index == 0) { btn.value_(1) };
    inputButtons.add(btn);
};

// --- Labels ---
labelInput = StaticText(paddedView, Rect(xInputL, 5, (faderWidth * 2) + 10, 20)).string_("INPUT").align_(\center).font_(fontBold);
labelOutput = StaticText(paddedView, Rect(xOutputL, 5, (faderWidth * 2) + 10, 20)).string_("OUTPUT").align_(\center).font_(fontBold);

labelLTop = StaticText(paddedView, Rect(xInputL, 25, faderWidth, 20)).string_("L").align_(\center).font_(font);
labelRTop = StaticText(paddedView, Rect(xInputR, 25, faderWidth, 20)).string_("R").align_(\center).font_(font);
labelLTop2 = StaticText(paddedView, Rect(xOutputL, 25, faderWidth, 20)).string_("L").align_(\center).font_(font);
labelRTop2 = StaticText(paddedView, Rect(xOutputR, 25, faderWidth, 20)).string_("R").align_(\center).font_(font);

// --- Value Labels (always integer) ---
labelLVal = StaticText(paddedView, Rect(xInputL, faderHeight + 50, faderWidth, 20)).align_(\center).font_(font).string_(lastInL.asInteger.asString);
labelRVal = StaticText(paddedView, Rect(xInputR, faderHeight + 50, faderWidth, 20)).align_(\center).font_(font).string_(lastInR.asInteger.asString);
labelLVal2 = StaticText(paddedView, Rect(xOutputL, faderHeight + 50, faderWidth, 20)).align_(\center).font_(font).string_(lastOutL.asInteger.asString);
labelRVal2 = StaticText(paddedView, Rect(xOutputR, faderHeight + 50, faderWidth, 20)).align_(\center).font_(font).string_(lastOutR.asInteger.asString);

// input sliders
leftSlider = Slider(paddedView, Rect(xInputL, 45, faderWidth, faderHeight))
    .orientation_(\vertical)
    .canFocus_(false)
    .value_((lastInL - minIn) / (maxIn - minIn))
    .action_({ |s|
        lastFaderGroup = \input;
        lastInL = ((s.value * (maxIn - minIn)) + minIn).round;
        labelLVal.string_(lastInL.asInteger.asString);
        if (linkFaders) {
            rightSlider.value_(s.value);
            lastInR = lastInL;
            labelRVal.string_(lastInR.asInteger.asString);
        };
    });

rightSlider = Slider(paddedView, Rect(xInputR, 45, faderWidth, faderHeight))
    .orientation_(\vertical)
    .canFocus_(false)
    .value_((lastInR - minIn) / (maxIn - minIn))
    .action_({ |s|
        lastFaderGroup = \input;
        lastInR = ((s.value * (maxIn - minIn)) + minIn).round;
        labelRVal.string_(lastInR.asInteger.asString);
        if (linkFaders) {
            leftSlider.value_(s.value);
            lastInL = lastInR;
            labelLVal.string_(lastInL.asInteger.asString);
        };
    });

// output sliders
leftSlider2 = Slider(paddedView, Rect(xOutputL, 45, faderWidth, faderHeight))
    .orientation_(\vertical)
    .canFocus_(false)
    .value_(lastOutL / 145)
    .action_({ |s|
        lastFaderGroup = \output;
        lastOutL = (s.value * 145).round;
        labelLVal2.string_(lastOutL.asInteger.asString);
        if (linkFaders) {
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
        lastFaderGroup = \output;
        lastOutR = (s.value * 145).round;
        labelRVal2.string_(lastOutR.asInteger.asString);
        if (linkFaders) {
            leftSlider2.value_(s.value);
            lastOutL = lastOutR;
            labelLVal2.string_(lastOutL.asInteger.asString);
        };
    });

// --- Divider ---
divider = UserView(paddedView, Rect(xDivider, 45, 1, faderHeight)).background_(Color.gray);

// --- Monitor Button ---
monitorButton = Button(paddedView, Rect(xInputL + 45, 5, 32, 18))
    .states_([
        ["MON", Color.black, Color.new(0.85, 0.85, 0.85)],
        ["MON", Color.black, Color.new(1.0, 0.647, 0.0)]
    ])
    .font_(fontBold)
    .value_(1)
    .action_({ |btn|
        var cmd = if (btn.value == 1) { "phono-control -M" } { "phono-control -m" };
        cmd.unixCmd;
    });

// --- Mute Buttons ---
muteInputButton = Button(paddedView, Rect(xInputL - 1, faderHeight + 75, (faderWidth * 2) + 10, 20))
    .states_([
        ["MUTE", Color.black, Color.new(0.85, 0.85, 0.85)],
        ["MUTE", Color.white, Color.red]
    ])
    .font_(fontBold)
    .value_(0)
    .action_({ |btn|
        if (btn.value == 1) {
            // Store previous input values and channel
            prevInL = lastInL;
            prevInR = lastInR;
            prevInputChannel = currentInputChannel;
            AppClock.sched(0.0, { "phono-control -c mute".unixCmd; });
        } {
            // Restore previous input channel and use current fader values
            AppClock.sched(0.0, { ("phono-control -c " ++ prevInputChannel).unixCmd; });
            AppClock.sched(0.3, { ("phono-control -l " ++ lastInL.asInteger ++ " -r " ++ lastInR.asInteger).unixCmd; });
        }
    });

muteOutputButton = Button(paddedView, Rect(xOutputL - 1, faderHeight + 75, (faderWidth * 2) + 10, 20))
    .states_([
        ["MUTE", Color.black, Color.new(0.85, 0.85, 0.85)],
        ["MUTE", Color.white, Color.red]
    ])
    .font_(fontBold)
    .value_(0)
    .action_({ |btn|
        if (btn.value == 1) {
            // Store previous output values
            prevOutL = lastOutL;
            prevOutR = lastOutR;
            // Only mute outputs, do not change monitor state
            ("phono-control -L 0 -R 0").unixCmd;
        } {
            // On unmute, send the current fader values instantly
            ("phono-control -L " ++ lastOutL.asInteger ++ " -R " ++ lastOutR.asInteger).unixCmd;
        }
    });

// --- Link Button ---
linkButton = Button(paddedView, Rect(rightButtonX, yBtnLine, buttonWidth, buttonHeight))
    .states_([
        ["LINK", Color.black, Color.new(0.85, 0.85, 0.85)],
        ["LINK", Color.black, Color.new(1.0, 0.55, 0.0)]
    ])
    .font_(fontBold)
    .value_(1)
    .action_({ |btn| linkFaders = btn.value == 1 });

// --- Headphone Button ---
headphoneButton = Button(paddedView, Rect(rightButtonX, yBtnMM, buttonWidth, buttonHeight))
    .states_([
        ["HP", Color.black, Color.new(0.85, 0.85, 0.85)],
        ["HP", Color.black, Color.new(1.0, 0.55, 0.0)]
    ])
    .font_(fontBold)
    .value_(1)
    .action_({ |btn|
        var cmd = if (btn.value == 1) { "phono-control -i" } { "phono-control -I" };
        cmd.unixCmd;
    });

// --- Reset Button ---
resetButton = Button(paddedView, Rect(rightButtonX, yBtnMC, buttonWidth, buttonHeight))
    .states_([
        ["RESET", Color.black, Color.new(0.85, 0.85, 0.85)],
        ["RESET", Color.black, Color.new(0.7, 0.7, 0.7)]
    ])
    .font_(fontBold)
    .action_({
        isUpdating = true;

        leftSlider.value_((96 - minIn) / (maxIn - minIn));
        rightSlider.value_((96 - minIn) / (maxIn - minIn));
        leftSlider2.value_(1.0);
        rightSlider2.value_(1.0);

        lastInL = 96;
        lastInR = 96;
        lastOutL = 145;
        lastOutR = 145;

        labelLVal.string_(lastInL.asInteger.asString);
        labelRVal.string_(lastInR.asInteger.asString);
        labelLVal2.string_(lastOutL.asInteger.asString);
        labelRVal2.string_(lastOutR.asInteger.asString);

        AppClock.sched(0.0, { "phono-control -l 96 -r 96".unixCmd; });
        AppClock.sched(0.3, { "phono-control -L 145 -R 145".unixCmd; });
        AppClock.sched(0.6, { "phono-control -M".unixCmd; });

        isUpdating = false;
    });

// --- Mouse-up CLI trigger ---
view.mouseUpAction_({
    if (isUpdating.not) {
        AppClock.sched(0.05, {
            if (lastFaderGroup == \input) {
                if (muteInputButton.value == 0) { // Only send if not muted
                    ("phono-control -l " ++ lastInL.asInteger ++ " -r " ++ lastInR.asInteger).unixCmd;
                }
            } {
                if (lastFaderGroup == \output) {
                    if (muteOutputButton.value == 0) { // Only send if not muted
                        ("phono-control -L " ++ lastOutL.asInteger ++ " -R " ++ lastOutR.asInteger).unixCmd;
                    }
                }
            };
            lastFaderGroup = \none;
        });
    }
});

win.front;
)