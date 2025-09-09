SFPlayerMeterView {

	classvar serverMeter2Views, updateFreq = 10, dBLow = -80, meterWidth = 20, gapWidth = 2.5, <height = 230;
	classvar serverCleanupFuncs;

	var <view;
	var inresp, outresp, synthFunc, responderFunc, server, numIns, numOuts, inmeters, outmeters, startResponderFunc;
	var <playerBus, <playerInputMeters, <playerBusSynth, <playerLevelResponder, <outputMeter;

	*new { |aserver, parent, leftUp, numIns, numOuts, aplayerBus|
		^super.new.init(aserver, parent, leftUp, numIns, numOuts, aplayerBus)
	}

	*getWidth { arg numIns, numOuts, server;
		^20+((numIns + numOuts + 2) * (meterWidth + gapWidth))
	}

	init { arg aserver, parent, leftUp, anumIns, anumOuts, aplayerBus;
		server = aserver;
		playerBus = aplayerBus;
		numIns = anumIns ?? { 2 }; // Always 2 for SFPlayer inputs
		numOuts = anumOuts ?? { server.options.numOutputBusChannels };

		leftUp = leftUp ? (0@0);

		// Create output meters using ServerMeter2View (0 inputs, numOuts outputs)
		outputMeter = ServerMeter2View.new(server, parent, leftUp, 0, numOuts);
		
		// Create custom input meters in ServerMeter2View style, fed from playerBus
		playerInputMeters = Array.fill(2, { |i|
			var meterWidth = 20; // Match ServerMeter2View width
			var meterHeight = 180;
			var x = 34 + (i * 22.5); // Position where old input meters were, adjusted right and down
			var y = 25;

			LevelIndicator(parent, Rect(x, y, meterWidth, meterHeight))
				.warning_(0.6)
				.critical_(0.9)
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

		// Create synth to monitor playerBus levels
		playerBusSynth = SynthDef(\playerBusMonitor, {
			var sig = In.ar(playerBus.index, 2);
			var levels = SendPeakRMS.kr(sig, 20, 3, "/" ++ server.name ++ "PlayerLevels");
			Out.ar(0, 0); // Silent output
		}).play(server);

		// Create OSC responder for playerBus levels
		playerLevelResponder = OSCFunc({|msg|
			{
				try {
					var channelCount = min(msg.size - 3 / 2, 2);
					channelCount.do {|channel|
						var baseIndex = 3 + (2*channel);
						var peakLevel = msg.at(baseIndex);
						var rmsValue = msg.at(baseIndex + 1);
						var meter = playerInputMeters.at(channel);
						if (meter.notNil) {
							if (meter.isClosed.not) {
								meter.peakLevel = peakLevel.ampdb.linlin(-80, 0, 0, 1, \min);
								meter.value = rmsValue.ampdb.linlin(-80, 0, 0, 1);
							}
						}
					}
				} { |error|
					if(error.isKindOf(PrimitiveFailedError).not) { error.throw }
				};
			}.defer;
		}, ("/" ++ server.name ++ "PlayerLevels").asSymbol, server.addr).fix;
	}

	remove {
		// Clean up custom input meters
		playerInputMeters.do { |meter| meter.remove };
		
		// Clean up output meter
		outputMeter.remove;
		
		// Clean up synth and responder
		playerBusSynth.free;
		playerLevelResponder.free;
	}
}

SFPlayerMeter {

	var <meterView;

	*new { |server, parent, leftUp, numIns, numOuts, playerBus|

		var meterView;

		numIns = numIns ?? { 2 }; // Always 2 for SFPlayer inputs
		numOuts = numOuts ?? { server.options.numOutputBusChannels };

		meterView = SFPlayerMeterView(server, parent, leftUp, numIns, numOuts, playerBus);

		^super.newCopyArgs(meterView)

	}

	remove {
		meterView.remove
	}
}

