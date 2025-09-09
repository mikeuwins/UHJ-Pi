SFPlayerMeterView {

	classvar SFPlayerMeterViews, updateFreq = 10, dBLow = -80, meterWidth = 20, gapWidth = 2.5, <height = 230;
	classvar serverCleanupFuncs;

	var <view;
	var inresp, outresp, synthFunc, responderFunc, server, numIns, numOuts, inmeters, outmeters, startResponderFunc;
	var <playerBus;

	*new { |aserver, parent, leftUp, numIns, numOuts, aplayerBus|
		^super.new.init(aserver, parent, leftUp, numIns, numOuts, aplayerBus)
	}

	*getWidth { arg numIns, numOuts, server;
		^20+((numIns + numOuts + 2) * (meterWidth + gapWidth))
	}

	init { arg aserver, parent, leftUp, anumIns, anumOuts, aplayerBus;
		var innerView, viewWidth, levelIndic, palette;

		server = aserver;
		playerBus = aplayerBus;

		numIns = anumIns ?? { 2 }; // Always 2 for player audio
		numOuts = anumOuts ?? { server.options.numOutputBusChannels };

		viewWidth= this.class.getWidth(anumIns, anumOuts);

		leftUp = leftUp ? (0@0);

		view = CompositeView(parent, Rect(leftUp.x, leftUp.y, viewWidth, height) );
		view.onClose_( { this.stop });
		innerView = CompositeView(view, Rect(10, 25, viewWidth, height) );
		innerView.addFlowLayout(0@0, gapWidth@gapWidth);

		// Restore dB scale
		UserView(innerView, Rect(0, 0, meterWidth, 195)).drawFunc_( {
			// Draw invisible dB scale numbers, but keep container for alignment
			Pen.color = Color.clear; // Make text fully invisible
			Pen.font = Font("Helvetica", 10).boldVariant;
			Pen.stringCenteredIn("10", Rect(0, 0, meterWidth, 12));
			Pen.stringCenteredIn("0", Rect(0, 170, meterWidth, 12));
		});

		if(numIns > 0) {
			// ins - gui tweaks
			inmeters = Array.fill( numIns, { arg i;
				var comp;
				comp = CompositeView(innerView, Rect(0, 0, meterWidth, 195)).resize_(5);
				levelIndic = LevelIndicator( comp, Rect(0, 0, meterWidth, 180) ).warning_(0.6).critical_(0.9)
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
			UserView(innerView, Rect(0, 0, meterWidth, 180)).drawFunc_( {
				try {
					Pen.color = \QPalette.asClass.new.windowText;
				} {
					Pen.color = Color.white;
				};
				Pen.color = Color.clear;
				Pen.line(((meterWidth + gapWidth) * 0.5)@0, ((meterWidth + gapWidth) * 0.5)@180);
				Pen.stroke;
			});
		};

		// outs - gui tweaks
		if(numOuts > 0) {
			outmeters = Array.fill( numOuts, { arg i;
				var comp;
				comp = CompositeView(innerView, Rect(0, 0, meterWidth, 195));
				// Output meter numbering commented out to allow custom LRLR labels
				// StaticText(comp, Rect(0, 180, meterWidth, 15))
				// .font_(Font("Helvetica", 9).boldVariant)
				// .align_(\center)
				// .stringColor_(Color.cyan)
				// .string_((i+1).asString);
				levelIndic = LevelIndicator( comp, Rect(0, 0, meterWidth, 180) ).warning_(0.6).critical_(0.9)
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
			var numIns = 2; // Always 2 for player audio
			// Use the instance variable numOuts directly
			numRMSSamps = server.sampleRate / updateFreq;
			numRMSSampsRecip = 1 / numRMSSamps;

			server.bind( {
				var insynth, outsynth;
				if(numIns > 0 and: { playerBus.notNil }, {
					("Creating SFPlayer input synth for bus " ++ playerBus.index).postln;
					insynth = SynthDef(server.name ++ "SFPlayerLevels", {
						var in = In.ar(playerBus.index, numIns); // Monitor player bus instead of input bus
						SendPeakRMS.kr(in, updateFreq, 3, "/" ++ server.name ++ "SFPlayerLevels")
					}).play(RootNode(server), nil, \addToHead);
				}, {
					("SFPlayer input synth not created - numIns: " ++ numIns ++ ", playerBus: " ++ playerBus).postln;
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
			("Starting SFPlayer input OSC responder for " ++ ("/" ++ server.name ++ "SFPlayerLevels")).postln;
			inresp = OSCFunc( {|msg|
				{
					try {
						var channelCount = min(msg.size - 3 / 2, numIns);
						// Debug: only post first few messages to avoid spam
						if(msg.at(3).abs > 0.001, { ("SFPlayer input level: " ++ msg.at(3)).postln; });
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
			}, ("/" ++ server.name ++ "SFPlayerLevels").asSymbol, server.addr).fix;
		};
		if(numOuts > 0) {
			outresp = OSCFunc( {|msg|
				{
					try {
						var channelCount = min((msg.size - 3) / 2, numOuts);
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
						};
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

SFPlayerMeter {

	var <window, <meterView;

	*new { |server, parent, leftUp, numIns, numOuts, playerBus|

		var window, meterView;

		numIns = numIns ?? { 2 }; // Always 2 for player audio
		numOuts = numOuts ?? { server.options.numOutputBusChannels };

		window = Window.new(server.name ++ " SFPlayer levels (dBFS)",
			Rect(5, 305, SFPlayerMeterView.getWidth(numIns, numOuts), SFPlayerMeterView.height),
			false);

		meterView = SFPlayerMeterView(server, window, 0@0, numIns, numOuts, playerBus);
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