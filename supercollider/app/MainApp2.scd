// MainAppRefactored — Compose PhonoControl and Transcoder GUIs (reduced GUI variable clutter, audio untouched)
(
var win, phonoPanel, paddedView, isUpdating, leftSlider, rightSlider,
    labelLVal, labelRVal, linkButton, lastInputCmd, muteBtn, monBtn, lineBtn, mmBtn, mcBtn,
    linkFaders, font, fontBold, lastInL, lastInR, minIn, maxIn, lastFaderGroup,
    buttonHeight, buttonSpacing, faderHeight, linkBtnY,
    rotini, tltini, tumini, volini, ambini, voltmp,
    cond, sndbuf, synth, inputs, outputs, configKeyD, configKeyE;
// --- Initial values (GUI) ---
isUpdating = false;
linkFaders = true;
faderHeight = 220;
font = Font("Helvetica", 10);
fontBold = Font("Helvetica", 10).boldVariant;
lastInL = 96;
lastInR = 96;
minIn = 60;
maxIn = 127;
lastFaderGroup = \none;
buttonHeight = 18;
buttonSpacing = 6;
linkBtnY = 50 + 160 - buttonHeight;

// --- Window and panels with black background ---
win = Window("UHJ Ambisonic System", Rect(25, 25, 800, 480)).background_(Color.black);
paddedView = CompositeView(win, Rect(20, 20, 760, 440)).background_(Color.black);

/* ~title = StaticText(paddedView, Rect(100, 5, 400, 40)).background_(Color.black).align_(\center).string_(" TX-SC909PRO ").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24)); */

// --- Labels above faders ---
StaticText(paddedView, Rect(60, 10, 60, 18))
    .string_("INPUT").align_(\center)
    .font_(fontBold)
    .background_(Color.black)
    .stringColor_(Color.cyan);

StaticText(paddedView, Rect(60, 30, 20, 18))
    .string_("L").align_(\center)
    .font_(font)
    .background_(Color.black)
    .stringColor_(Color.cyan);

StaticText(paddedView, Rect(100, 30, 20, 18))
    .string_("R").align_(\center)
    .font_(font)
    .background_(Color.black)
    .stringColor_(Color.cyan);

// --- Value labels below faders ---
labelLVal = StaticText(paddedView, Rect(60, 50 + faderHeight, 20, 18))
    .align_(\center)
    .font_(font)
    .background_(Color.black)
    .stringColor_(Color.cyan);

labelRVal = StaticText(paddedView, Rect(100, 50 + faderHeight, 20, 18))
    .align_(\center)
    .font_(font)
    .background_(Color.black)
    .stringColor_(Color.cyan);

// --- Input sliders with two-way linking and CLI logic ---
// leftSlider = Slider(paddedView, Rect(60, 50, 20, faderHeight)).orientation_(\vertical);
// rightSlider = Slider(paddedView, Rect(100, 50, 20, faderHeight)).orientation_(\vertical);

leftSlider = Slider(paddedView, Rect(60, 50, 20, faderHeight))
    .orientation_(\vertical)
    .background_(Color.black)           // Track background
    .knobColor_(Color.cyan)  
    .focusColor_(Color.black)
    .thumbSize = 3        // Handle/knob color
    ; 

rightSlider = Slider(paddedView, Rect(100, 50, 20, faderHeight))
    .orientation_(\vertical)
    .background_(Color.black)
    .knobColor_(Color.cyan)
    .focusColor_(Color.black)
    .thumbSize = 3          // Handle/knob color
    ;
    


// Now update the value variables and labels
lastInL = (leftSlider.value.linlin(0,1,minIn,maxIn).round.asInteger);
lastInR = (rightSlider.value.linlin(0,1,minIn,maxIn).round.asInteger);
labelLVal.string = lastInL.asString;
labelRVal.string = lastInR.asString;

leftSlider.action_({ |sl|
    if(isUpdating.not) {
        isUpdating = true;
        lastFaderGroup = \input;
        lastInL = (sl.value.linlin(0,1,minIn,maxIn).round.asInteger);
        labelLVal.string = lastInL.asString;
        if(linkFaders) {
            rightSlider.value = sl.value;
            lastInR = lastInL;
            labelRVal.string = lastInR.asString;
        };
        isUpdating = false;
    } {
        lastInL = (sl.value.linlin(0,1,minIn,maxIn).round.asInteger);
        labelLVal.string = lastInL.asString;
    }
});

rightSlider.action_({ |sl|
    if(isUpdating.not) {
        isUpdating = true;
        lastFaderGroup = \input;
        lastInR = (sl.value.linlin(0,1,minIn,maxIn).round.asInteger);
        labelRVal.string = lastInR.asString;
        if(linkFaders) {
            leftSlider.value = sl.value;
            lastInL = lastInR;
            labelLVal.string = lastInL.asString;
        };
        isUpdating = false;
    } {
        lastInR = (sl.value.linlin(0,1,minIn,maxIn).round.asInteger);
        labelRVal.string = lastInR.asString;
    }
});

paddedView.mouseUpAction_({
    AppClock.sched(0.05, {
        if(lastFaderGroup == \input) {
            ("phono-control -l " ++ lastInL ++ " -r " ++ lastInR).unixCmd;
        };
        lastFaderGroup = \none;
    });
});

// --- Selector buttons (radio group) ---
lineBtn = Button(paddedView, Rect(2, 50, 38, 18))
    .states_([
        ["LINE", Color.cyan, Color.black], // inactive: cyan text, black bg
        ["LINE", Color.black, Color.cyan]  // active: black text, cyan bg
    ])
    .font_(fontBold)
    .action_({ |btn|
        if(btn.value == 1) {
            mmBtn.valueAction_(0);
            mcBtn.valueAction_(0);
            ("phono-control -c line").unixCmd;
        }
    });

mmBtn = Button(paddedView, Rect(2, 76, 38, 18))
    .states_([
        ["MM", Color.cyan, Color.black],
        ["MM", Color.black, Color.cyan]
    ])
    .font_(fontBold)
    .action_({ |btn|
        if(btn.value == 1) {
            lineBtn.valueAction_(0);
            mcBtn.valueAction_(0);
            ("phono-control -c mm").unixCmd;
        }
    });

mcBtn = Button(paddedView, Rect(2, 102, 38, 18))
    .states_([
        ["MC", Color.cyan, Color.black],
        ["MC", Color.black, Color.cyan]
    ])
    .font_(fontBold)
    .action_({ |btn|
        if(btn.value == 1) {
            lineBtn.valueAction_(0);
            mmBtn.valueAction_(0);
            ("phono-control -c mc").unixCmd;
        }
    });


// --- Second block: MON, MUTE, LINK buttons ---
monBtn = Button(paddedView, Rect(2, 200, 38, 18))
    .states_([
        ["MON", Color.cyan, Color.black],
        ["MON", Color.black, Color.cyan]
    ])
    .font_(fontBold)
    .action_({ |btn|
        var cmd = if(btn.value == 1) { "phono-control -M" } { "phono-control -m" };
        cmd.unixCmd;
    });

muteBtn = Button(paddedView, Rect(2, 226, 38, 18))
    .states_([
        ["MUTE", Color.cyan, Color.black],
        ["MUTE", Color.black, Color.cyan]
    ])
    .font_(fontBold)
    .action_({ |btn|
        if(btn.value == 1) {
            // Muting: remember the last input command
            if(lineBtn.value == 1) { lastInputCmd = "line"; };
            if(mmBtn.value == 1)   { lastInputCmd = "mm"; };
            if(mcBtn.value == 1)   { lastInputCmd = "mc"; };
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

linkButton = Button(paddedView, Rect(2, 252, 38, 18))
    .states_([
        ["LINK", Color.cyan, Color.black],
        ["LINK", Color.black, Color.cyan]
    ])
    .font_(fontBold)
    .value_(linkFaders.asInteger)
    .action_({ |btn| linkFaders = btn.value == 1; });


// --- Now set all defaults to match hardware/software state ---
lastInL = 86; // or whatever default phono-control -d sets
lastInR = 86;
leftSlider.value = (lastInL - minIn) / (maxIn - minIn);
rightSlider.value = (lastInR - minIn) / (maxIn - minIn);
labelLVal.string = lastInL.asString;
labelRVal.string = lastInR.asString;

lineBtn.value_(1);
mmBtn.value_(0);
mcBtn.value_(0);
monBtn.value_(0);

("phono-control -d").unixCmd;

// ...rest of your code unchanged...
// old variable declarations - cond, sndbuf, synth, inputs, outputs, configKeyD, configKeyE
rotini = 0.5;
tltini = 0.5;
tumini = 0.5;
volini = 0.5;
ambini = 0;
voltmp = 0.5;

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
         if ( HID.findBy(0,0,serial: "e4:e1:de:be:db:2f").size > 0 ){
            ~myhid = HID.open(0,0,serial: "e4:e1:de:be:db:2f");
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

Tdef( 'tryOpenHID' ).play;

HID.debug = true;

MIDIIn.connectAll;
MIDIFunc.trace(true);

~rotknob = Knob.new (paddedView, Rect(150,60,60,60)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);
~tltknob = Knob.new (paddedView, Rect(150,130,60,60)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);
~tumknob = Knob.new (paddedView, Rect(150,200,60,60)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan]).centered_(true);
~ambknob = Knob.new (paddedView, Rect(150,270,60,60)).enabled_(false).valueAction_(0.0).color_([Color.cyan (1, 0.1), Color.cyan, Color.cyan(0.5), Color.cyan]).centered_(false);
~volknob = Knob.new (paddedView, Rect(150,340,60,60)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan, Color.cyan(0.5), Color.cyan]).centered_(false);

~rotlabel = StaticText(paddedView, Rect(240,75,200,20)).background_(Color.clear).align_(\center).string_(" Rotate ").stringColor_(Color.cyan).font_( Font("LED Dot-Matrix", 24));
~tltlabel = StaticText(paddedView, Rect(240,175,200,20)).background_(Color.clear).align_(\center).string_(" Tilt ").stringColor_(Color.cyan).font_( Font("LED Dot-Matrix", 24));
~tumlabel = StaticText(paddedView, Rect(240,275,200,20)).background_(Color.clear).align_(\center).string_(" Tumble ").stringColor_(Color.cyan).font_( Font("LED Dot-Matrix", 24));
~amblabel = StaticText(paddedView, Rect(240,375,200,20)).background_(Color.clear).align_(\center).string_(" Ambience ").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));
~vollabel = StaticText(paddedView, Rect(240,475,200,20)).background_(Color.clear).align_(\center).string_(" Volume ").stringColor_(Color.cyan).font_( Font("LED Dot-Matrix", 24));

~rotval = StaticText(paddedView, Rect (440,90,100,40)).background_(Color.clear).align_(\center).string_("180.0").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));
~tltval = StaticText(paddedView, Rect (440,190,100,40)).background_(Color.clear).align_(\center).string_("0.0").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));
~tumval = StaticText(paddedView, Rect (440,290,100,40)).background_(Color.clear).align_(\center).string_("0.0").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));
~ambval = StaticText(paddedView, Rect (440,390,100,40)).background_(Color.clear).align_(\center).string_("0.0").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));
~volval = StaticText(paddedView, Rect (440,490,100,40)).background_(Color.clear).align_(\center).string_("5.0").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));

// ...existing code...
// --- All other code (audio, ambisonic, transcoder, MIDI, OSC, etc) is left UNTOUCHED below ---

// old variable declarations - cond, sndbuf, synth, inputs, outputs, configKeyD, configKeyE
rotini = 0.5;
tltini = 0.5;
tumini = 0.5;
volini = 0.5;
ambini = 0;
voltmp = 0.5;

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
         if ( HID.findBy(0,0,serial: "e4:e1:de:be:db:2f").size > 0 ){
            ~myhid = HID.open(0,0,serial: "e4:e1:de:be:db:2f");
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

Tdef( 'tryOpenHID' ).play;

HID.debug = true;

MIDIIn.connectAll;
MIDIFunc.trace(true);

// --- Retro LED-style border ---
// UserView(transcoderPanel, transcoderPanel.bounds)
//     .background_(Color.clear)
//     .drawFunc_({ |v|
//         Pen.width = 4;
//         Pen.color = Color.new(0.1, 1.0, 0.1);
//         Pen.addRoundedRect(Rect(2, 2, v.bounds.width - 4, v.bounds.height - 4), 24, 24);
//         Pen.stroke;
//    });


~emenu = EZPopUpMenu.new(
    paddedView,
    Rect(380,65,380,40),
    "INPUT:",
    [
        \UHJ-> {|a| ("this is item 0 of " ++ a).postln; configKeyE = \uhj },
        \STEREO-> {|a| ("this item 1 of " ++ a).postln; configKeyE = \superstereo }
    ],

    globalAction: {

~dmenu = EZPopUpMenu.new(
    paddedView,
    Rect(380,105,380,40),
    "OUTPUT:",
    [
        \NONE -> {|a| ("this is item 0 of " ++ a).postln; inputs = 2; outputs = 0; configKeyD = \none },
        \BINAURAL ++ " IRCAM" -> {|a| ("this is item 1 of " ++ a).postln; inputs = 2; outputs = 2; configKeyD = \binaural },
        \BINAURAL ++ " CIPIC" -> {|a| ("this is item 2 of " ++ a).postln; inputs = 2; outputs = 2; configKeyD = \binaurac },
        \QUAD ++ " SQUARE" -> {|a| ("this is item 3 of " ++ a).postln; inputs = 2; outputs = 4; configKeyD = \quadsquare },
        \QUAD ++ " NARROW" -> {|a| ("this is item 4 of " ++ a).postln; inputs = 2; outputs = 4; configKeyD = \quadnarrow },
        \QUAD ++" WIDE" -> {|a| ("this is item 5 of " ++ a).postln; inputs = 2; outputs = 4; configKeyD = \quadwide },
        \DOLBY ++" 5.1" -> {|a| ("this is item 6 of " ++ a).postln; inputs = 2; outputs = 6; configKeyD = \fivezero },
        \OCTAGON -> {|a| ("this is item 7 of " ++ a).postln; inputs = 2; outputs = 8; configKeyD = \octagon }
    ],

    globalAction: {|a|

        var encoder, decoder, trans, ambient, roton;
        var decoderDict, encoderDict;

        ("encoder = "++configKeyE).postln;
        ("outputs = "++outputs).postln; ("inputs = "++inputs).postln; ("config = "++configKeyD).postln;

        ServerQuit;
        s.boot;
        s.options.memSize = 65536;
        s.options.numOutputBusChannels = outputs; // must match no. of decoder channels
        s.options.numInputBusChannels = inputs;

        // choose aggregate device as "UHJ" - change if other soundcard
        Server.default.options.device_("UHJ");

        s.reboot;

        cond = Condition.new;

        ~fixDec= {|val, numDecimals= 2|  					// function float to string with fixed number of decimals
            var str= val.round(0.1**numDecimals).asString;
            var num= str.size-str.indexOf($.)-1;
            str.extend(str.size+numDecimals-num, $0);
        };

        s.waitForBoot({

                Routine.run({

                // define an UHJ encoder
                encoderDict = Dictionary.newFrom([
                \uhj, FoaEncoderKernel.newUHJ,
                \superstereo, FoaEncoderKernel.newSuper,
                ]);

                // define all decoders...
                decoderDict = Dictionary.newFrom([  							// key value pairs
                    \none, FoaDecoderKernel.newListen(1053),
                    \binaural, FoaDecoderKernel.newListen(1053),  				// 2 channel binaural (hrtf new listen)
                    \binaurac, FoaDecoderKernel.newCIPIC(12),					// 2 channel binaural (CIPC)
                    \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),  	// 4 channel quad square optimised
                    \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),  	// 4 channel quad narrow optimised
                    \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual'),  		// 4 channel quad wide optimised
                    \fivezero, FoaDecoderMatrix.new5_0 (irregKind: 'focused'),	// 5.0 channel surround
                    \octagon, FoaDecoderMatrix.newPanto(8, 'flat',k: 'single'),	// 8 channel psycho optimised octo
                ]);

                // ... now, select decoder
                /*
                NOTE: we have to instance -newListen within the Routine so that the kernels are loaded on the server
                */

                encoder = encoderDict[configKeyE];
                decoder = decoderDict[configKeyD];

                sndbuf = Buffer.read(s, Atk.userSoundsDir ++ "/uhj/01 Sodium Sunrise UHJ Render.wav");
                // Window.closeAll;

                s.sync(cond);

                // synth to encode a UHJ file, transform and decode using an binaral/quad/octo decoder
                SynthDef(\kernelEncodeDecode, {arg buffer, rotation = 0, tilt = 0, tumble = 0, ambience = 0;
                var out, src, trans, encode, volume;
                src = PlayBuf.ar(sndbuf.numChannels, buffer, BufRateScale.kr(buffer));	// load a UHJ sound file into a buffer
                //src = SoundIn.ar([0,1]);												// live UHJ stereo source signal from phono input
                src = src * \amp.kr(-6.dbamp);											// amplitude scaling
                encode = FoaEncode.ar(src, encoder);									// encode to ambisonic using a UHJ encoder

                // trans = FoaTransform.ar(encode, 'rotate', rotation);					// transformation

                ambient = AmbiVerbSC.ar(encode,
                        mix: ambience,
                        preDelay: 0, crossoverFreq: 3000,
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
                        feedbackSpread: 1);

                trans = FoaRTT.ar(ambient, rotAngle: rotation, tilAngle: tilt, tumAngle: tumble);	// transformation

                // AmbiVerbGUI.new(s);

                out = FoaDecode.ar(trans, decoder);		// decode using the chosen decoder (binaural/quad/octo)

                if ( outputs == 6, //output from decoder adding low passed copy of centre for 5.1 sub
                                { var lowpass; lowpass = BLowPass.ar((out[0]+out[4]), 120, 1, 0.4); "sub".postln;
                    Out.ar(0, out); Out.ar(5, lowpass)}, // truefn
                    { "nosub".postln; Out.ar(0, out)} // falsefn
                );

                   }).add;

                s.sync(cond);	// play the synth
                s.unmute;
                ~synth = Synth(\kernelEncodeDecode, [\buffer, sndbuf]);
                ~synth.set(\amp, voltmp);



                // gui
        {
                v = View(paddedView, Rect(420,180,290,290)).background_(Color.cyan(0.2,0.4));
                ~title = StaticText(v, Rect(0, 5, 290, 40)).background_(Color.clear).align_(\center).string_(" LEVEL METER ").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));
                ~meter.remove;												// close exiting meter
                ~meter = ServerMeter2View.new(s, v, 0@50, inputs, 8);		// redraw new meter - note: using modified ServerMeter2View class

                ~rotknob.close; ~rotknob = Knob.new (paddedView, Rect(150,60,60,60)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);
                ~tltknob.close; ~tltknob = Knob.new (paddedView, Rect(150,130,60,60)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);
                ~tumknob.close; ~tumknob = Knob.new (paddedView, Rect(150,200,60,60)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan]).centered_(true);
                ~ambknob.close; ~ambknob = Knob.new (paddedView, Rect(150,270,60,60)).enabled_(false).valueAction_(0.0).color_([Color.cyan (1, 0.1), Color.cyan, Color.cyan(0.5), Color.cyan]).centered_(false);
                ~volknob.close;

                ~rotval.string = "180.0";  	// reset value text
                ~tltval.string = "0.0";
                ~tumval.string = "0.0";
                ~ambval.string = "0.0";
                ~volval.string = ~fixDec.((voltmp*10),1);

                // redraw new knobs

            ~rotbutn = Button.new (paddedView, Rect(220,50,30,30)).states_([["OFF", Color.cyan, Color.black],["ON", Color.black, Color.cyan]]).action_({ arg butt; var val; val = butt.value;

                    if ( val == 1,
                        { "rot true".postln; ~rotknob.close; ~rotknob = Knob.new (paddedView, Rect(60,60,80,80)).enabled_(true).valueAction_(rotini)
                            .action_({arg knob; var rotation; rotation = (knob.value.linlin(0,1, -pi, pi)).postln; rotini = knob.value; ~synth.set(\rotation, rotation);
                                    ~rotval.string = ~fixDec.((~rotknob.value*360),1);}).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);},
                        { "rot false".postln; ~rotknob.enabled_(false)}
                        );
                    }).font_( Font("LED Dot-Matrix", 12));

            ~tltbutn = Button.new (paddedView, Rect(220,150,30,30)).states_([["OFF", Color.cyan, Color.black],["ON", Color.black, Color.cyan]]).action_({ arg butt; var val; val = butt.value;

                    if ( val == 1,
                        { "tilt true".postln; ~tltknob.close; ~tltknob = Knob.new (paddedView, Rect(60,160,80,80)).enabled_(true).valueAction_(tltini)
                            .action_({arg knob; var tilt; tilt = (knob.value.linlin(0,1, -pi, pi)).postln; tltini = knob.value; ~synth.set(\tilt, tilt);
                                    ~tltval.string = ~fixDec.((~tltknob.value*360),1);}).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);},
                        { "tilt false".postln; ~tltknob.enabled_(false)}
                        );
                    }).font_( Font("LED Dot-Matrix", 12));


            ~tumbutn = Button.new (paddedView, Rect(220,250,30,30)).states_([["OFF", Color.cyan, Color.black],["ON", Color.black, Color.cyan]]).action_({ arg butt; var val; val = butt.value;

                    if ( val == 1,
                        { "tumble true".postln; ~tumknob.close; ~tumknob = Knob.new (paddedView, Rect(60,260,80,80)).enabled_(true).valueAction_(tumini)
                            .action_({arg knob; var tumble; tumble = (knob.value.linlin(0,1, -pi, pi)).postln; tumini = knob.value; ~synth.set(\tumble, tumble);
                                    ~tumval.string = ~fixDec.((~tumknob.value*360),1);}).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);},
                        { "tumble false".postln; ~tumknob.enabled_(false)}
                        );
                    }).font_( Font("LED Dot-Matrix", 12));


            ~ambbutn = Button.new (paddedView, Rect(220,350,30,30)).states_([["OFF", Color.cyan, Color.black],["ON", Color.black, Color.cyan]]).action_({ arg butt; var val; val = butt.value;

                    if ( val == 1,
                        { "ambience true".postln; ~ambknob.close; ~ambknob = Knob.new (paddedView, Rect(60,360,80,80)).enabled_(true).valueAction_(ambini)
                                        .action_({arg knob; var ambience; ambience = knob.value.linlin(0,1,0,0.5).postln; ambini = knob.value; ~synth.set(\ambience, ambience*0.1);
                                    ~ambval.string = ~fixDec.((~ambknob.value*10),1);}).color_([Color.cyan (1, 0.1), Color.cyan, Color.cyan(0.5), Color.cyan]).centered_(false);},
                        { "ambience false".postln; ~ambknob.enabled_(false)}
                        );
                    }).font_( Font("LED Dot-Matrix", 12));

            ~volknob = Knob.new (paddedView, Rect(60,460,80,80)).valueAction_(voltmp).action_({arg knob; var volume; volume = knob.value.postln;
                        ~synth.set(\amp, volume); voltmp = volume; ~volval.string = ~fixDec.((~volknob.value*10),1);})
            .color_([Color.cyan (1, 0.1), Color.cyan, Color.cyan(0.5), Color.cyan]);

            ~mutebutn = Button.new (paddedView, Rect(30,450,30,30)).states_([["MUTE", Color.cyan, Color.black],["MUTE", Color.black, Color.cyan]]).action_({ arg butt; var val; val = butt.value;

                    if ( val == 1,
                            { "mute true".postln; s.mute;},
                            { "mute false".postln; s.unmute;}
                        );
                    }).font_( Font("LED Dot-Matrix", 12));

/*			~mutebutn = Button.new (paddedView, Rect(140,450,30,30)).states_([["MUTE", Color.cyan, Color.black],["MUTE", Color.black, Color.cyan]]).action_({ arg butt; var val; val = butt.value;

                    if ( val == 1,
                            { "mute true".postln; ~synth.set(\amp,0); ~volknob.enabled_(false);},
                            { "mute false".postln; ~synth.set(\amp,voltmp); ~volknob.enabled_(true)}
                        );
                    }).font_( Font("LED Dot-Matrix", 12));*/


            MIDIdef.noteOn(\rotationState, {
            arg val, num, chan, src;
                {val.postln; (num/num).postln;
                    if ( ~rotbutn.value == 1,
                        { "toggle true".postln; ~rotbutn.valueAction_(0); ~rotknob.enabled_(false)},   	// truefn
                        { "toggle false".postln; ~rotbutn.valueAction_(1);~rotknob.enabled_(true);} 	//falsefn
                    );
                }.defer;
            },67);

            MIDIdef.noteOn(\tiltState, {
            arg val, num, chan, src;
                {val.postln; (num/num).postln;
                    if ( ~tltbutn.value == 1,
                        { "toggle true".postln; ~tltbutn.valueAction_(0); ~tltknob.enabled_(false)},   	// truefn
                        { "toggle false".postln; ~tltbutn.valueAction_(1);~tltknob.enabled_(true);} 	//falsefn
                    );
                }.defer;
            },69);

            MIDIdef.noteOn(\tumbleState, {
            arg val, num, chan, src;
                {val.postln; (num/num).postln;
                    if ( ~tumbutn.value == 1,
                        { "toggle true".postln; ~tumbutn.valueAction_(0); ~tumknob.enabled_(false)},   	// truefn
                        { "toggle false".postln; ~tumbutn.valueAction_(1);~tumknob.enabled_(true);} 	//falsefn
                    );
                }.defer;
            },71);

            MIDIdef.noteOn(\ambienceState, {
            arg val, num, chan, src;
                {val.postln; (num/num).postln;
                    if ( ~ambbutn.value == 1,
                        { "volume true".postln; ~ambbutn.valueAction_(0); ~ambknob.enabled_(false)},   	// truefn
                        { "volume false".postln; ~ambbutn.valueAction_(1);~ambknob.enabled_(true);} 	//falsefn
                    );
                }.defer;
            },72);


/*			MIDIdef.noteOn(\volumeState, {
            arg val, num, chan, src;
                {val.postln; (num/num).postln;
                    if ( ~volbutn.value == 1,
                        { "volume true".postln; ~volbutn.valueAction_(0); ~volknob.enabled_(false)},   	// truefn
                        { "volume false".postln; ~volbutn.valueAction_(1);~volknob.enabled_(true);} 	//falsefn
                    );
                }.defer;
            },62);*/

            MIDIdef.noteOn(\muteState, {
            arg val, num, chan, src;
                {val.postln; (num/num).postln;
                    if ( ~mutebutn.value == 1,
                        { "volume true".postln; ~mutebutn.valueAction_(0); ~volknob.enabled_(false)},  // truefn
                        { "volume false".postln; ~mutebutn.valueAction_(1);~volknob.enabled_(true);} 	//falsefn
                    );
                }.defer;
            },60);


            MIDIdef.cc(\rotationKnob, {
            arg val, num, chan, src;
            {
            if (~rotbutn.value == 1,
                            {~rotknob.valueAction_(val/127);},
                        );
                    }.defer;
            }, 1);

            MIDIdef.cc(\tltKnob, {
            arg val, num, chan, src;
            {
            if (~tltbutn.value == 1,
                            {~tltknob.valueAction_(val/127);},
                        );
                    }.defer;
            }, 2);

            MIDIdef.cc(\tumbleKnob, {
            arg val, num, chan, src;
            {
            if (~tumbutn.value == 1,
                            {~tumknob.valueAction_(val/127);},
                        );
                    }.defer;
            }, 3);

            MIDIdef.cc(\ambienceKnob, {
            arg val, num, chan, src;
            {
            if (~ambbutn.value == 1,
                            {~ambknob.valueAction_(val/127);},
                        );
                    }.defer;
            }, 4);

            MIDIdef.cc(\volumeKnob, {
            arg val, num, chan, src;
            {~volknob.valueAction_(val/127);}.defer;
            }, 5);

            // thisProcess.openPorts;
            thisProcess.openUDPPort(8000);
            n = NetAddr.new("127.0.0.1", 8000);    // create the NetAddr
            o = OSCFunc({ arg msg, time, addr, recvPort; [msg, time, addr, recvPort].postln; }, '/nxosc', n);
            o.free;    // remove the OSCFunc when you are done.


            MIDIdef.cc(\rotationKnob, {
            arg val, num, chan, src;
            {
            if (~rotbutn.value == 1,
                            {~rotknob.valueAction_(val/127);},
                        );
                    }.defer;
            }, 1);

            /*OSCdef(\rotosc, {
            arg msg;
            {
            if (~rotbutn.value == 1,
                            {~rotknob.valueAction_(msg[2].linlin(-1, 1, 1, 0));},
                            );
                            }.defer;
            }, '/nxosc/quaternion');


            OSCdef(\tlttosc, {
            arg msg;
            {
            if (~tltbutn.value == 1,
                            {~tltknob.valueAction_(msg[3].linlin(-1, 1, 1, 0));},
                            );
                            }.defer;
            }, '/nxosc/quaternion');

            OSCdef(\tumosc, {
            arg msg;
            {
            if (~tumbutn.value == 1,
                            {~tumknob.valueAction_(msg[1].linlin(-1, 1, 1, 0));},
                            );
                            }.defer;
            }, '/nxosc/quaternion');*/


            HIDdef.usage( \hidRotation,
            { arg val;
                // ~synth.set(\rotation, ~rotateRange.map(value));
            {~rotknob.valueAction_(val.linlin(0, 1, 0, 1));}.defer;
            },
            \Z);

            HIDdef.usage( \hidVolume,
            { arg val;
                // ~synth.set(\rotation, ~rotateRange.map(value));
            {~tltknob.valueAction_(val.linlin(0, 1, 0, 1));}.defer;
            },
            \Y);

            }.defer;

            // No window to close in this panel version
            CmdPeriod.doOnce({
                ~synth.free;
                Server.killAll;
                encoder.free;
                decoder.free;
                sndbuf.free;
            });
            })
        })
    },

    initVal: 1,
    initAction: true,
    labelWidth: 120,
    labelHeight: 30,
    layout: \horz,
    gap: 2@2
);

~dmenu.font = Font("LED Dot-Matrix", 24);
~dmenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);
},
    initVal:0,
    initAction: true,
    labelWidth: 120,
    labelHeight: 30,
    layout: \horz,
    gap: 2@2
);

~emenu.font = Font("LED Dot-Matrix", 24);
~emenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);

/* 

k.font = Font("LED Dot-Matrix", 16);
k.setColors(Color.black, Color.cyan, Color.black, Color.cyan, Color.cyan, Color.white, Color.green, Color.green);
*/




n = NetAddr.new("127.0.0.1", 8000);    // create the NetAddr
// create the OSCFunc
o = OSCFunc({ arg msg, time, addr, recvPort; [msg, time, addr, recvPort].postln; }, '/goodbye', n);
o.free;    // remove the OSCFunc when you are done.

n = NetAddr.new("127.0.0.1", 8000);    // create the NetAddr
o = OSCFunc({ arg msg, time, addr, recvPort; [msg, time, addr, recvPort].postln; }, '/SceneRotator/pitch', n);
o.free;

OSCFunc.trace(true); // Turn posting on
OSCFunc.trace(false); // Turn posting on

/*
OSCdef(\reciever, {
    arg msg;
    msg.postln;
}, '/SceneRotator/pitch');

OSCdef(\reciever, {
    arg msg;
    msg.postln;
}, '/SceneRotator/roll');
*/

voltmp.postln;
win.front;
)
