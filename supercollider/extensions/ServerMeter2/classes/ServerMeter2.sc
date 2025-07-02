"=== THIS IS THE REAL ServerMeter2.sc ===".postln;

ServerMeter2View {

	classvar serverMeter2Views, updateFreq = 10, dBLow = -80, meterWidth = 20, gapWidth = 2.5, <height = 230;
	classvar serverCleanupFuncs;

	var <view;
	var inresp, outresp, synthFunc, responderFunc, server, numIns, numOuts, inmeters, outmeters, startResponderFunc;

	*new { |aserver, parent, leftUp, numIns, numOuts|
		^super.new.init(aserver, parent, leftUp, numIns, numOuts)
	}

	*getWidth { arg numIns, numOuts, server;
		^20+((numIns + numOuts + 2) * (meterWidth + gapWidth))
	}

	init { arg aserver, parent, leftUp, anumIns, anumOuts;
		var innerView, viewWidth, levelIndic, palette;

		server = aserver;

		numIns = anumIns ?? { server.options.numInputBusChannels };
		numOuts = anumOuts ?? { server.options.numOutputBusChannels };

		viewWidth= this.class.getWidth(anumIns, anumOuts);

		leftUp = leftUp ? (0@0);

		view = CompositeView(parent, Rect(leftUp.x, leftUp.y, viewWidth, height) );
		view.onClose_( { this.stop });
		innerView = CompositeView(view, Rect(10, 20, viewWidth, height-20) );
		innerView.addFlowLayout(0@0, gapWidth@gapWidth);

		// dB scale - using StaticText instead of Pen.font for better font control
		StaticText(innerView, Rect(0, 0, meterWidth, 12))
			.string_("10")
			.font_(Font("Helvetica", 10))
			.stringColor_(Color.cyan)
			.align_(\center)
			.background_(Color.clear);
		StaticText(innerView, Rect(0, 148, meterWidth, 12))
			.string_("0")
			.font_(Font("Helvetica", 10))
			.stringColor_(Color.cyan)
			.align_(\center)
			.background_(Color.clear);

		// --- FONT DEBUG ---
		var labelFont;
		if(Font.availableFonts.includes("Helvetica-Bold")) {
			labelFont = Font("Helvetica-Bold", 10);
		} {
			labelFont = Font("Helvetica", 10).boldVariant;
		}
		("[ServerMeter2View] INPUT label font: " ++ labelFont.name).postln;
		StaticText(view, Rect(5, 25, 250, 20))
			.string_("[DEBUG] INPUT font: " ++ labelFont.name)
			.font_(Font("Helvetica", 12).boldVariant)
			.stringColor_(Color.red)
			.align_(\left);
		// --- END FONT DEBUG ---

		if(numIns > 0) {
			// ins - gui tweaks
			StaticText(view, Rect(10, 5, 100, 15))
			.font_(labelFont)
			.align_(\left)
			.stringColor_(Color.cyan)
			.string_("INPUT");
			inmeters = Array.fill( numIns, { arg i;
				var comp;
				comp = CompositeView(innerView, Rect(0, 0, meterWidth, 170)).resize_(5);
				StaticText(comp, Rect(0, 160, meterWidth, 10))
				.font_(Font("Helvetica", 9))
				.align_(\center)
				.stringColor_(Color.cyan)
				.string_((i+1).asString);
				levelIndic = LevelIndicator( comp, Rect(0, 0, meterWidth, 160) ).warning_(0.6).critical_(0.9)
				.style_(\led)
				.stepWidth_(4)
				.meterColor_(Color.cyan)
				.backColor_(Color.black)
				.drawsPeak_(true)
				.numTicks_(10)
				.numMajorTicks_(0)
				.warningColor_(Color.new(0.86,0.54,0.04,1))
				.criticalColor_(Color.red);
			});
		};

		if((numIns > 0) && (numOuts > 0)) {
			// divider - color tweaks
			UserView(innerView, Rect(0, 0, meterWidth, 160)).drawFunc_( {
				try {
					Pen.color = \QPalette.asClass.new.windowText;
				} {
					Pen.color = Color.white;
				};
				Pen.color = Color.clear;
				Pen.line(((meterWidth + gapWidth) * 0.5)@0, ((meterWidth + gapWidth) * 0.5)@160);
				Pen.stroke;
			});
		};

		// outs - gui tweaks
		if(numOuts > 0) {
			// Try Helvetica-Bold first, fallback to Helvetica boldVariant if not available
			var labelFont;
			if(Font.availableFonts.includes("Helvetica-Bold")) {
				labelFont = Font("Helvetica-Bold", 10);
			} {
				labelFont = Font("Helvetica", 10).boldVariant;
			}
			StaticText(view, Rect(10 + if(numIns > 0) { (numIns + 2) * (meterWidth + gapWidth) } { 0 }, 5, 100, 15))
			.font_(labelFont)
			.align_(\left)
			.stringColor_(Color.cyan)
			.string_("OUTPUT");
			outmeters = Array.fill( numOuts, { arg i;
				var comp;
				comp = CompositeView(innerView, Rect(0, 0, meterWidth, 170));
				StaticText(comp, Rect(0, 160, meterWidth, 10))
				.font_(Font("Helvetica", 9))
				.align_(\center)
				.stringColor_(Color.cyan)
				.string_((i+1).asString);
				levelIndic = LevelIndicator( comp, Rect(0, 0, meterWidth, 160) ).warning_(0.6).critical_(0.9)
				.style_(\led)
				.numSteps_(10)
				.stepWidth_(4)
				.meterColor_(Color.cyan)
				.backColor_(Color.black)
				.drawsPeak_(true)
				.numTicks_(10)
				.numMajorTicks_(0)
				.warningColor_(Color.new(0.86,0.54,0.04,1))
				.criticalColor_(Color.red);
			});
		};

		this.setSynthFunc(inmeters, outmeters);
		startResponderFunc = {this.startResponders};
		this.start;
	}

	setSynthFunc {
		var numRMSSamps, numRMSSampsRecip;

		synthFunc = {
			//responders and synths are started only once per server
			var numIns = server.options.numInputBusChannels;
			var numOuts = server.options.numOutputBusChannels;
			numRMSSamps = server.sampleRate / updateFreq;
			numRMSSampsRecip = 1 / numRMSSamps;

			server.bind( {
				var insynth, outsynth;
				if(numIns > 0, {
					insynth = SynthDef(server.name ++ "InputLevels", {
						var in = In.ar(NumOutputBuses.ir, numIns);
						SendPeakRMS.kr(in, updateFreq, 3, "/" ++ server.name ++ "InLevels")
					}).play(RootNode(server), nil, \addToHead);
				});
				if(numOuts > 0, {
					outsynth = SynthDef(server.name ++ "OutputLevels", {
						var in = In.ar(0, numOuts);
						SendPeakRMS.kr(in, updateFreq, 3, "/" ++ server.name ++ "OutLevels")
					}).play(RootNode(server), nil, \addToTail);
				});

				if (serverCleanupFuncs.isNil) {
					serverCleanupFuncs = IdentityDictionary.new;
				};
				serverCleanupFuncs.put(server, {
					insynth.free;
					outsynth.free;
					ServerTree.remove(synthFunc, server);
				});
			});
		};
	}

	startResponders {
		var numRMSSamps, numRMSSampsRecip;

		//responders and synths are started only once per server
		numRMSSamps = server.sampleRate / updateFreq;
		numRMSSampsRecip = 1 / numRMSSamps;
		if(numIns > 0) {
			inresp = OSCFunc( {|msg|
				{
					try {
						var channelCount = min(msg.size - 3 / 2, numIns);

						channelCount.do {|channel|
							var baseIndex = 3 + (2*channel);
							var peakLevel = msg.at(baseIndex);
							var rmsValue = msg.at(baseIndex + 1);
							var meter = inmeters.at(channel);
							if (meter.notNil) {
								if (meter.isClosed.not) {
									meter.peakLevel = peakLevel.ampdb.linlin(dBLow, 0, 0, 1, \min);
									meter.value = rmsValue.ampdb.linlin(dBLow, 0, 0, 1);
								}
							}
						}
					} { |error|
						if(error.isKindOf(PrimitiveFailedError).not) { error.throw }
					};
				}.defer;
			}, ("/" ++ server.name ++ "InLevels").asSymbol, server.addr).fix;
		};
		if(numOuts > 0) {
			outresp = OSCFunc( {|msg|
				{
					try {
						var channelCount = min(msg.size - 3 / 2, numOuts);

						channelCount.do {|channel|
							var baseIndex = 3 + (2*channel);
							var peakLevel = msg.at(baseIndex);
							var rmsValue = msg.at(baseIndex + 1);
							var meter = outmeters.at(channel);
							if (meter.notNil) {
								if (meter.isClosed.not) {
									meter.peakLevel = peakLevel.ampdb.linlin(dBLow, 0, 0, 1, \min);
									meter.value = rmsValue.ampdb.linlin(dBLow, 0, 0, 1);
								}
							}
						}
					} { |error|
						if(error.isKindOf(PrimitiveFailedError).not) { error.throw }
					};
				}.defer;
			}, ("/" ++ server.name ++ "OutLevels").asSymbol, server.addr).fix;
		};
	}

	start {
		if(serverMeter2Views.isNil) {
			serverMeter2Views = IdentityDictionary.new;
		};
		if(serverMeter2Views[server].isNil) {
			serverMeter2Views.put(server, List());
		};
		if(serverMeter2Views[server].size == 0) {
			ServerTree.add(synthFunc, server);
			if(server.serverRunning, synthFunc); // otherwise starts when booted
		};
		serverMeter2Views[server].add(this);
		if (server.serverRunning) {
			this.startResponders
		} {
			ServerBoot.add (startResponderFunc, server)
		}
	}

	stop {
		serverMeter2Views[server].remove(this);
		if(serverMeter2Views[server].size == 0 and: (serverCleanupFuncs.notNil)) {
			serverCleanupFuncs[server].value;
			serverCleanupFuncs.removeAt(server);
		};

		(numIns > 0).if( { inresp.free; });
		(numOuts > 0).if( { outresp.free; });

		ServerBoot.remove(startResponderFunc, server)
	}

	remove {
		view.remove
	}
}

ServerMeter2 {

	var <window, <meterView;

	*new { |server, numIns, numOuts|

		var window, meterView;

		numIns = numIns ?? { server.options.numInputBusChannels };
		numOuts = numOuts ?? { server.options.numOutputBusChannels };

		window = Window.new(server.name ++ " levels (dBFS)",
			Rect(5, 305, ServerMeter2View.getWidth(numIns, numOuts), ServerMeter2View.height),
			false);

		meterView = ServerMeter2View(server, window, 0@0, numIns, numOuts);
		meterView.view.keyDownAction_( { arg view, char, modifiers;
			if(modifiers & 16515072 == 0) {
				case
					{char === 27.asAscii } { window.close };
			};
		});

		window.front;

		^super.newCopyArgs(window, meterView)

	}

	close {
		window.close
	}

	isClosed {
		^window.isClosed
	}
}

