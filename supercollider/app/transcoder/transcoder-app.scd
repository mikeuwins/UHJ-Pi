
/*
DEBUG:

-> Thu Apr 24 18:16:15 2025
JA
*/
(
var cond, sndbuf, synth, inputs, outputs, configKeyD, configKeyE, rotini = 0.5, tltini = 0.5, tumini = 0.5, volini = 0.5, ambini = 0, voltmp = 0.5;

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
);
Tdef( 'tryOpenHID' ).play;

// HID.closeAll;
// HID.findAvailable;
// HID.postAvailable;*/

// Open EdTracker 2;
// ~myhid = HID.open ( 9025 , 32822 );
// HID.open(1452, 781);
// HID.open (2362, 9488);
// HID.open (1133, 49684);

HID.debug = true;

MIDIIn.connectAll;
MIDIFunc.trace(true);

Window.closeAll;

w = Window.new("Decoder Configuration", Rect((Window.screenBounds.width),(Window.screenBounds.height),800,600), resizable:true, border:true).front;
w.alwaysOnTop_(true);
w.onClose_({~synth.free; Server.killAll});
w.background = Color.black;

~title = StaticText(w, Rect(180, 5, 400, 40)).background_(Color.black).align_(\center).string_(" TX-SC909PRO ").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 35));

~rotknob = Knob.new (w, Rect(60,60,80,80)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);
~tltknob = Knob.new (w, Rect(60,160,80,80)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);
~tumknob = Knob.new (w, Rect(60,260,80,80)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan]).centered_(true);
~ambknob = Knob.new (w, Rect(60,360,80,80)).enabled_(false).valueAction_(0.0).color_([Color.cyan (1, 0.1), Color.cyan, Color.cyan(0.5), Color.cyan]).centered_(false);
~volknob = Knob.new (w, Rect(60,460,80,80)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan, Color.cyan(0.5), Color.cyan]).centered_(false);

~rotlabel = StaticText(w, Rect(140,75,200,20)).background_(Color.clear).align_(\center).string_(" Rotate ").stringColor_(Color.cyan).font_( Font("LED Dot-Matrix", 24));
~tltlabel = StaticText(w, Rect(140,175,200,20)).background_(Color.clear).align_(\center).string_(" Tilt ").stringColor_(Color.cyan).font_( Font("LED Dot-Matrix", 24));
~tumlabel = StaticText(w, Rect(140,275,200,20)).background_(Color.clear).align_(\center).string_(" Tumble ").stringColor_(Color.cyan).font_( Font("LED Dot-Matrix", 24));
~amblabel = StaticText(w, Rect(140,375,200,20)).background_(Color.clear).align_(\center).string_(" Ambience ").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));
~vollabel = StaticText(w, Rect(140,475,200,20)).background_(Color.clear).align_(\center).string_(" Volume ").stringColor_(Color.cyan).font_( Font("LED Dot-Matrix", 24));

~rotval = StaticText(w, Rect (190,90,100,40)).background_(Color.clear).align_(\center).string_("180.0").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));
~tltval = StaticText(w, Rect (190,190,100,40)).background_(Color.clear).align_(\center).string_("0.0").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));
~tumval = StaticText(w, Rect (190,290,100,40)).background_(Color.clear).align_(\center).string_("0.0").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));
~ambval = StaticText(w, Rect (190,390,100,40)).background_(Color.clear).align_(\center).string_("0.0").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));
~volval = StaticText(w, Rect (190,490,100,40)).background_(Color.clear).align_(\center).string_("5.0").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));

~emenu = EZPopUpMenu.new(
	w,
	Rect(380,65,380,40),
	"INPUT:",
	[
		\UHJ-> {|a| ("this is item 0 of " ++ a).postln; configKeyE = \uhj },
		\STEREO-> {|a| ("this item 1 of " ++ a).postln; configKeyE = \superstereo }
	],

	globalAction: {

~dmenu = EZPopUpMenu.new(
	w,
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
				v = View(w, Rect(420,180,290,290)).background_(Color.cyan(0.2,0.4));
				~title = StaticText(v, Rect(0, 5, 290, 40)).background_(Color.clear).align_(\center).string_(" LEVEL METER ").stringColor_(Color.cyan).font_(Font("LED Dot-Matrix", 24));
				~meter.remove;												// close exiting meter
				~meter = ServerMeter2View.new(s, v, 0@50, inputs, 8);		// redraw new meter - note: using modified ServerMeter2View class

				~rotknob.close; ~rotknob = Knob.new (w, Rect(60,60,80,80)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);
				~tltknob.close; ~tltknob = Knob.new (w, Rect(60,160,80,80)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);
				~tumknob.close; ~tumknob = Knob.new (w, Rect(60,260,80,80)).enabled_(false).valueAction_(0.5).color_([Color.cyan (1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan]).centered_(true);
				~ambknob.close; ~ambknob = Knob.new (w, Rect(60,360,80,80)).enabled_(false).valueAction_(0.0).color_([Color.cyan (1, 0.1), Color.cyan, Color.cyan(0.5), Color.cyan]).centered_(false);
				~volknob.close;

				~rotval.string = "180.0";  	// reset value text
				~tltval.string = "0.0";
				~tumval.string = "0.0";
				~ambval.string = "0.0";
				~volval.string = ~fixDec.((voltmp*10),1);

				// redraw new knobs

			~rotbutn = Button.new (w, Rect(30,50,30,30)).states_([["OFF", Color.cyan, Color.black],["ON", Color.black, Color.cyan]]).action_({ arg butt; var val; val = butt.value;

					if ( val == 1,
						{ "rot true".postln; ~rotknob.close; ~rotknob = Knob.new (w, Rect(60,60,80,80)).enabled_(true).valueAction_(rotini)
							.action_({arg knob; var rotation; rotation = (knob.value.linlin(0,1, -pi, pi)).postln; rotini = knob.value; ~synth.set(\rotation, rotation);
									~rotval.string = ~fixDec.((~rotknob.value*360),1);}).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);},
						{ "rot false".postln; ~rotknob.enabled_(false)}
						);
					}).font_( Font("LED Dot-Matrix", 12));

			~tltbutn = Button.new (w, Rect(30,150,30,30)).states_([["OFF", Color.cyan, Color.black],["ON", Color.black, Color.cyan]]).action_({ arg butt; var val; val = butt.value;

					if ( val == 1,
						{ "tilt true".postln; ~tltknob.close; ~tltknob = Knob.new (w, Rect(60,160,80,80)).enabled_(true).valueAction_(tltini)
							.action_({arg knob; var tilt; tilt = (knob.value.linlin(0,1, -pi, pi)).postln; tltini = knob.value; ~synth.set(\tilt, tilt);
									~tltval.string = ~fixDec.((~tltknob.value*360),1);}).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);},
						{ "tilt false".postln; ~tltknob.enabled_(false)}
						);
					}).font_( Font("LED Dot-Matrix", 12));


			~tumbutn = Button.new (w, Rect(30,250,30,30)).states_([["OFF", Color.cyan, Color.black],["ON", Color.black, Color.cyan]]).action_({ arg butt; var val; val = butt.value;

					if ( val == 1,
						{ "tumble true".postln; ~tumknob.close; ~tumknob = Knob.new (w, Rect(60,260,80,80)).enabled_(true).valueAction_(tumini)
							.action_({arg knob; var tumble; tumble = (knob.value.linlin(0,1, -pi, pi)).postln; tumini = knob.value; ~synth.set(\tumble, tumble);
									~tumval.string = ~fixDec.((~tumknob.value*360),1);}).color_([Color.cyan (1, 0.1), Color.cyan (0.5), Color.cyan, Color.cyan]).centered_(true);},
						{ "tumble false".postln; ~tumknob.enabled_(false)}
						);
					}).font_( Font("LED Dot-Matrix", 12));


			~ambbutn = Button.new (w, Rect(30,350,30,30)).states_([["OFF", Color.cyan, Color.black],["ON", Color.black, Color.cyan]]).action_({ arg butt; var val; val = butt.value;

					if ( val == 1,
						{ "ambience true".postln; ~ambknob.close; ~ambknob = Knob.new (w, Rect(60,360,80,80)).enabled_(true).valueAction_(ambini)
										.action_({arg knob; var ambience; ambience = knob.value.linlin(0,1,0,0.5).postln; ambini = knob.value; ~synth.set(\ambience, ambience*0.1);
									~ambval.string = ~fixDec.((~ambknob.value*10),1);}).color_([Color.cyan (1, 0.1), Color.cyan, Color.cyan(0.5), Color.cyan]).centered_(false);},
						{ "ambience false".postln; ~ambknob.enabled_(false)}
						);
					}).font_( Font("LED Dot-Matrix", 12));

			~volknob = Knob.new (w, Rect(60,460,80,80)).valueAction_(voltmp).action_({arg knob; var volume; volume = knob.value.postln;
						~synth.set(\amp, volume); voltmp = volume; ~volval.string = ~fixDec.((~volknob.value*10),1);})
			.color_([Color.cyan (1, 0.1), Color.cyan, Color.cyan(0.5), Color.cyan]);

			~mutebutn = Button.new (w, Rect(30,450,30,30)).states_([["MUTE", Color.cyan, Color.black],["MUTE", Color.black, Color.cyan]]).action_({ arg butt; var val; val = butt.value;

					if ( val == 1,
							{ "mute true".postln; s.mute;},
							{ "mute false".postln; s.unmute;}
						);
					}).font_( Font("LED Dot-Matrix", 12));

/*			~mutebutn = Button.new (w, Rect(140,450,30,30)).states_([["MUTE", Color.cyan, Color.black],["MUTE", Color.black, Color.cyan]]).action_({ arg butt; var val; val = butt.value;

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

			// w.close;
				// press command period when done
				CmdPeriod.doOnce({
					~synth.free;
					Server.killAll;
					encoder.free;
					decoder.free;
					sndbuf.free;
					w.close
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

/*k.font = Font("LED Dot-Matrix", 16);
k.setColors(Color.black, Color.cyan, Color.black, Color.cyan, Color.cyan, Color.white, Color.green, Color.green);*/

)

/*n = NetAddr.new("127.0.0.1", 8000);    // create the NetAddr
// create the OSCFunc
o = OSCFunc({ arg msg, time, addr, recvPort; [msg, time, addr, recvPort].postln; }, '/goodbye', n);
o.free;    // remove the OSCFunc when you are done.

n = NetAddr.new("127.0.0.1", 8000);    // create the NetAddr
o = OSCFunc({ arg msg, time, addr, recvPort; [msg, time, addr, recvPort].postln; }, '/SceneRotator/pitch', n);
o.free;

OSCFunc.trace(true); // Turn posting on
OSCFunc.trace(false); // Turn posting on

(
OSCdef(\reciever, {
	arg msg;
	msg.postln;
}, '/SceneRotator/pitch')
)

(
OSCdef(\reciever, {
	arg msg;
	msg.postln;
}, '/SceneRotator/roll')
)


voltmp.postln;
