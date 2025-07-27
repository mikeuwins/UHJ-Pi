MaplinMatrix {
	*ar { |leftIn, rightIn, surroundLevel = 0.8, effectLevel = 0.8, delayTime = 0.4, active = 1|
		var sum, diff, processedDiff, phaseDiff;
		var frontLeft, frontRight, rearLeft, rearRight;
		var thermalNoise, bbdNoise, actualDelayTime;
		var opampSaturation, bandwidthLimit, lowBand, midBand, highBand;
		var finalOutput;
		
		// Add subtle thermal noise
		thermalNoise = WhiteNoise.ar(0.00001) * 0.1;
		leftIn = leftIn + thermalNoise;
		rightIn = rightIn + thermalNoise;
		
		// Input gain and bandwidth limiting
		leftIn = leftIn * 0.7;
		rightIn = rightIn * 0.7;
		
		opampSaturation = 0.15;
		bandwidthLimit = 0.1;
		
		leftIn = LPF.ar(leftIn, 20000 * (1.0 - (bandwidthLimit * 0.9)) + 2000);
		rightIn = LPF.ar(rightIn, 20000 * (1.0 - (bandwidthLimit * 0.9)) + 2000);
		
		// Core matrix processing
		sum = (leftIn + rightIn) * 0.7071;
		diff = (leftIn - rightIn) * 0.7071;
		
		// Apply subtle saturation
		sum = (sum * (1.0 - opampSaturation)) + (sum.tanh * opampSaturation);
		diff = (diff * (1.0 - opampSaturation)) + (diff.tanh * opampSaturation);
		
		// Multi-stage phase shifting
		phaseDiff = diff;
		phaseDiff = AllpassN.ar(phaseDiff, 0.01, 0.0015, 0.7);
		phaseDiff = AllpassN.ar(phaseDiff, 0.01, 0.0033, 0.7);
		phaseDiff = AllpassN.ar(phaseDiff, 0.01, 0.0072, 0.7);
		phaseDiff = AllpassN.ar(phaseDiff, 0.01, 0.0156, 0.7);
		
		// High-pass filter rear channels
		phaseDiff = HPF.ar(phaseDiff, 80);
		
		// Band processing
		lowBand = LPF.ar(phaseDiff, 800);
		midBand = BPF.ar(phaseDiff, 2000, 1.5);
		highBand = HPF.ar(phaseDiff, 4000);
		
		lowBand = DelayC.ar(lowBand, 0.1, 0.022);
		midBand = DelayC.ar(midBand, 0.1, 0.018);
		highBand = DelayC.ar(highBand, 0.1, 0.012);
		
		processedDiff = (lowBand + midBand + highBand) * 0.6;
		
				// Output matrix with level matching (based on circuit analysis)
		frontLeft = leftIn + (sum * 0.1);
		frontRight = rightIn + (sum * 0.1);

		// Rear channels: original circuit-based approach (exact proven formula)
		rearLeft = (processedDiff * -1.8 * effectLevel) + (sum * 0.2);
		rearRight = (processedDiff * 1.8 * effectLevel) + (sum * 0.2);

		// BBD delay processing (original approach - whole rear signal)
		actualDelayTime = delayTime.linlin(0, 1, 0.005, 0.050);
		bbdNoise = WhiteNoise.ar(0.0003) * 0.1;

		rearLeft = LPF.ar(rearLeft + bbdNoise, 8000);
		rearRight = LPF.ar(rearRight + bbdNoise, 8000);

		rearLeft = DelayC.ar(rearLeft, 0.1, actualDelayTime + LFNoise2.kr(0.5, 0.0002));
		rearRight = DelayC.ar(rearRight, 0.1, actualDelayTime + LFNoise2.kr(0.3, 0.0002));

		// Final saturation
		frontLeft = (frontLeft * 0.9) + (frontLeft.tanh * 0.1);
		frontRight = (frontRight * 0.9) + (frontRight.tanh * 0.1);
		rearLeft = (rearLeft * 0.9) + (rearLeft.tanh * 0.1);
		rearRight = (rearRight * 0.9) + (rearRight.tanh * 0.1);

		// Apply surround level with boost to match front levels
		// When effect=0: rear=(sum*0.2), front=(leftIn+sum*0.1), so we need significant boost
		rearLeft = rearLeft * surroundLevel * 2.2;
		rearRight = rearRight * surroundLevel * 2.2;
		
		// Bypass/Active control - blend between original and processed
		frontLeft = (leftIn * (1 - active)) + (frontLeft * active);
		frontRight = (rightIn * (1 - active)) + (frontRight * active);
		rearLeft = (0 * (1 - active)) + (rearLeft * active);
		rearRight = (0 * (1 - active)) + (rearRight * active);
		
		// Return quad array in conventional order [FL, FR, RL, RR]
		^[frontLeft, frontRight, rearLeft, rearRight];
	}
	
	*gui { |synth|
		var window, surroundKnob, effectKnob, delayKnob, bypassButton;
		var balancedButton, maxButton;
		var inputMeterL, inputMeterR, outputMeterFL, outputMeterFR, outputMeterRL, outputMeterRR;
		var surroundValue, effectValue, delayValue;
		var meterResponders;
		
		// Create main window with v16 styling
		window = Window("MaplinMatrix", Rect(200, 200, 600, 400))
			.background_(Color.black)
			.alwaysOnTop_(false);
		
		// Main border (v16 style)
		UserView(window, Rect(0, 0, 600, 400))
			.background_(Color.clear)
			.drawFunc_({ |v|
				Pen.width = 0.5;
				Pen.color = Color.cyan;
				Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
				Pen.stroke;
			});
		
		// Title (v16 style)
		StaticText(window, Rect(10, 5, 300, 22))
			.string_("MAPLIN MATRIX PROCESSOR")
			.align_(\left)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 12).boldVariant)
			.background_(Color.clear);
		
		// Input meters section
		StaticText(window, Rect(20, 40, 100, 20))
			.string_("INPUT")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 11).boldVariant)
			.background_(Color.clear);
		
		StaticText(window, Rect(20, 60, 30, 15))
			.string_("L")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 10))
			.background_(Color.clear);
		
		StaticText(window, Rect(70, 60, 30, 15))
			.string_("R")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 10))
			.background_(Color.clear);
		
		inputMeterL = LevelIndicator(window, Rect(25, 80, 20, 120))
			.style_(\led)
			.numSteps_(12)
			.numTicks_(0)
			.numMajorTicks_(0)
			.background_(Color.black)
			.meterColor_(Color.cyan)
			.value_(0);
		
		inputMeterR = LevelIndicator(window, Rect(75, 80, 20, 120))
			.style_(\led)
			.numSteps_(12)
			.numTicks_(0)
			.numMajorTicks_(0)
			.background_(Color.black)
			.meterColor_(Color.cyan)
			.value_(0);
		
		// Control knobs section (v16 style)
		StaticText(window, Rect(160, 60, 80, 20))
			.string_("SURROUND")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 11).boldVariant)
			.background_(Color.clear);
		
		StaticText(window, Rect(260, 60, 80, 20))
			.string_("EFFECT")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 11).boldVariant)
			.background_(Color.clear);
		
		StaticText(window, Rect(360, 60, 80, 20))
			.string_("DELAY")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 11).boldVariant)
			.background_(Color.clear);
		
		surroundKnob = Knob(window, Rect(160, 90, 80, 80))
			.value_(0.8)
			.color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
			.action_({ |knob|
				if(synth.notNil) { synth.set(\surroundLevel, knob.value); };
				surroundValue.string_((knob.value * 100).round(1).asString ++ "%");
			});
		
		effectKnob = Knob(window, Rect(260, 90, 80, 80))
			.value_(0.8)
			.color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
			.action_({ |knob|
				if(synth.notNil) { synth.set(\effectLevel, knob.value); };
				effectValue.string_((knob.value * 100).round(1).asString ++ "%");
			});
		
		delayKnob = Knob(window, Rect(360, 90, 80, 80))
			.value_(0.4)
			.color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
			.action_({ |knob|
				if(synth.notNil) { synth.set(\delayTime, knob.value); };
				delayValue.string_((knob.value.linlin(0, 1, 5, 50).round(1).asString ++ " ms"));
			});
		
		// Value displays below knobs (v16 style)
		surroundValue = StaticText(window, Rect(160, 180, 80, 18))
			.string_("80%")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 12))
			.background_(Color.clear);
		
		effectValue = StaticText(window, Rect(260, 180, 80, 18))
			.string_("80%")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 12))
			.background_(Color.clear);
		
		delayValue = StaticText(window, Rect(360, 180, 80, 18))
			.string_("20.0 ms")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 12))
			.background_(Color.clear);
		
		// Output meters section
		StaticText(window, Rect(480, 40, 100, 20))
			.string_("OUTPUT")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 11).boldVariant)
			.background_(Color.clear);
		
		StaticText(window, Rect(480, 60, 20, 15))
			.string_("FL")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 9))
			.background_(Color.clear);
		
		StaticText(window, Rect(510, 60, 20, 15))
			.string_("FR")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 9))
			.background_(Color.clear);
		
		StaticText(window, Rect(540, 60, 20, 15))
			.string_("RL")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 9))
			.background_(Color.clear);
		
		StaticText(window, Rect(570, 60, 20, 15))
			.string_("RR")
			.align_(\center)
			.stringColor_(Color.cyan)
			.font_(Font("Helvetica", 9))
			.background_(Color.clear);
		
		outputMeterFL = LevelIndicator(window, Rect(485, 80, 15, 120))
			.style_(\led)
			.numSteps_(12)
			.numTicks_(0)
			.numMajorTicks_(0)
			.background_(Color.black)
			.meterColor_(Color.cyan)
			.value_(0);
		
		outputMeterFR = LevelIndicator(window, Rect(510, 80, 15, 120))
			.style_(\led)
			.numSteps_(12)
			.numTicks_(0)
			.numMajorTicks_(0)
			.background_(Color.black)
			.meterColor_(Color.cyan)
			.value_(0);
		
		outputMeterRL = LevelIndicator(window, Rect(540, 80, 15, 120))
			.style_(\led)
			.numSteps_(12)
			.numTicks_(0)
			.numMajorTicks_(0)
			.background_(Color.black)
			.meterColor_(Color.cyan)
			.value_(0);
		
		outputMeterRR = LevelIndicator(window, Rect(570, 80, 15, 120))
			.style_(\led)
			.numSteps_(12)
			.numTicks_(0)
			.numMajorTicks_(0)
			.background_(Color.black)
			.meterColor_(Color.cyan)
			.value_(0);
		
		// Control buttons (v16 style)
		bypassButton = Button(window, Rect(160, 220, 80, 28))
			.states_([
				["ACTIVE", Color.black, Color.cyan],
				["BYPASS", Color.cyan, Color.black]
			])
			.action_({ |button|
				if(synth.notNil) { synth.set(\active, if(button.value == 0, 1, 0)); };
				if(button.value == 0, {
					"Matrix processing ACTIVE".postln;
				}, {
					"Matrix processing BYPASSED".postln;
				});
			})
			.font_(Font("Helvetica", 11).boldVariant);
		
		balancedButton = Button(window, Rect(260, 220, 80, 28))
			.states_([["BALANCED", Color.cyan, Color.black]])
			.action_({
				surroundKnob.value_(0.8);
				effectKnob.value_(0.8);
				delayKnob.value_(0.4);
				if(synth.notNil) { synth.set(\surroundLevel, 0.8, \effectLevel, 0.8, \delayTime, 0.4); };
				surroundValue.string_("80%");
				effectValue.string_("80%");
				delayValue.string_("20.0 ms");
				"Balanced preset applied".postln;
			})
			.font_(Font("Helvetica", 11).boldVariant);
		
		maxButton = Button(window, Rect(360, 220, 80, 28))
			.states_([["MAXIMUM", Color.cyan, Color.black]])
			.action_({
				surroundKnob.value_(1.0);
				effectKnob.value_(1.0);
				delayKnob.value_(1.0);
				if(synth.notNil) { synth.set(\surroundLevel, 1.0, \effectLevel, 1.0, \delayTime, 1.0); };
				surroundValue.string_("100%");
				effectValue.string_("100%");
				delayValue.string_("50.0 ms");
				"Maximum preset applied".postln;
			})
			.font_(Font("Helvetica", 11).boldVariant);
		
		// Instructions (v16 style)
		StaticText(window, Rect(20, 350, 560, 30))
			.string_("MaplinMatrix Control Interface • Meters show levels when synth sends OSC messages • Create your own synth with MaplinMatrix.ar")
			.font_(Font("Helvetica", 10))
			.align_(\center)
			.stringColor_(Color.cyan)
			.background_(Color.clear);
		
		// Meter responders (only work if synth sends appropriate OSC)
		meterResponders = [
			OSCFunc({ |msg|
				var inputL = msg[3];
				var inputR = msg[4];
				{ 
					inputMeterL.value_(inputL.ampdb.linlin(-60, 0, 0, 1).clip(0, 1));
					inputMeterR.value_(inputR.ampdb.linlin(-60, 0, 0, 1).clip(0, 1));
				}.defer;
			}, '/inputMeter'),
			
			OSCFunc({ |msg|
				var outputFL = msg[3];
				var outputFR = msg[4];
				var outputRL = msg[5];
				var outputRR = msg[6];
				{ 
					outputMeterFL.value_(outputFL.ampdb.linlin(-60, 0, 0, 1).clip(0, 1));
					outputMeterFR.value_(outputFR.ampdb.linlin(-60, 0, 0, 1).clip(0, 1));
					outputMeterRL.value_(outputRL.ampdb.linlin(-60, 0, 0, 1).clip(0, 1));
					outputMeterRR.value_(outputRR.ampdb.linlin(-60, 0, 0, 1).clip(0, 1));
				}.defer;
			}, '/outputMeter')
		];
		
		window.onClose_({
			// Clean up meter responders
			meterResponders.do(_.free);
			"MaplinMatrix GUI closed".postln;
		});
		
		window.front;
		"MaplinMatrix GUI opened".postln;
		
		^window; // Return window for external control
	}
} 