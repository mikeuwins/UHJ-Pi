// FOA→5.1.2 decoder test (minimal)
// - Load 4-channel UHJ WAV → encode PHJ → FOA → decode 5.1.2
// - ServerMeter for outputs (8 channels)

// Configure server for 8 output channels (decoded only - B-format metering uses SendPeakRMS)
s.options.numOutputBusChannels = 8;

s.waitForBoot({
		var cond = Condition.new;
		var win, player, buf;
		var fileLabel, playBtn, stopBtn;
		var encoder, decoder;
		var meterContainer, meter;
		var muteBtns, muteBusses;
		var inputMuteBtns, inputMuteBusses;
		var zAmpLabel;

		// Create PHJ encoder and 5.1.2 decoder
		encoder = FoaEncoderKernel.newPHJ;
		// Debug: check kernel structure
		"PHJ Encoder kernel shape: %".format(encoder.kernel.shape).postln;
		"PHJ Encoder kernel numInputs: %, numOutputs: %".format(encoder.numInputs, encoder.numOutputs).postln;
		decoder = FoaDecoderMatrix.new5_2(\equal, 45, \uhjpi);
		// Decoder outputs: [C, FL, RL, RR, FR, TFR, TFL] (ATK order, 7 channels)

		// Control busses for L, R, T, Q input mutes
		inputMuteBusses = Array.fill(4, { Bus.control(s, 1) });
		inputMuteBusses.do(_.set(0)); // Start unmuted
		// Control busses for W, X, Y, Z B-format mutes
		muteBusses = Array.fill(4, { Bus.control(s, 1) });
		muteBusses.do(_.set(0)); // Start unmuted

		s.sync;

		// SynthDef for UHJ → 5.1.2 (encoder and decoder captured from outer scope)
		SynthDef(\foa_512_test, { |buffer, muteLBus=0, muteRBus=0, muteTBus=0, muteQBus=0, muteWBus=0, muteXBus=0, muteYBus=0, muteZBus=0|
			var bfmt, dec, lfe;
			var inputMuteControls, muteControls;

			// Load file - 4-channel UHJ (L, R, T=0, Q=0) for PHJ encoder
			// If kernels are correct (as confirmed in Reaper), L/R with T=0,Q=0 should produce Z=0
			var fileChans = PlayBuf.ar(4, buffer, BufRateScale.kr(buffer), loop: 1); // Full PHJ (L,R,T,Q)
			// Apply input mutes (L, R, T, Q)
			inputMuteControls = [In.kr(muteLBus, 1), In.kr(muteRBus, 1), In.kr(muteTBus, 1), In.kr(muteQBus, 1)];
			fileChans = [fileChans[0] * (1 - inputMuteControls[0]), fileChans[1] * (1 - inputMuteControls[1]),
			             fileChans[2] * (1 - inputMuteControls[2]), fileChans[3] * (1 - inputMuteControls[3])];
			bfmt = FoaEncode.ar(fileChans, encoder);
			// Apply mutes to B-format components (read from control busses)
			muteControls = [In.kr(muteWBus, 1), In.kr(muteXBus, 1), In.kr(muteYBus, 1), In.kr(muteZBus, 1)];
			bfmt = [bfmt[0] * (1 - muteControls[0]), bfmt[1] * (1 - muteControls[1]), 
			        bfmt[2] * (1 - muteControls[2]), bfmt[3] * (1 - muteControls[3])];
			
			// DEBUG: Check Z amplitude (for UHJ input, should be ~0 if encoder fix is working)
			// Send Z amplitude to control bus for monitoring
			SendReply.kr(Impulse.kr(10), '/zAmp', [
				Amplitude.kr(bfmt[3], 0.01, 0.1),  // Z amplitude
				Amplitude.kr(fileChans[2], 0.01, 0.1),  // T channel amplitude
				Amplitude.kr(fileChans[3], 0.01, 0.1)   // Q channel amplitude
			]);
			
			// Decode using FoaDecode (matrix decoder)
			dec = FoaDecode.ar(bfmt, decoder);
			// new5_2 outputs 7 channels: [0]=C, [1]=FL, [2]=RL, [3]=RR, [4]=FR, [5]=TFR, [6]=TFL
			
			// LFE from FL+FR lowpass (dec[1]=FL, dec[4]=FR)
			lfe = BLowPass.ar(dec[1] + dec[4], 120, 1, 0.4);
			// Reorder to UHJ-Pi order (8 channels): FL, FR, C, RL, RR, LFE, TFL, TFR
			// Note: TFL and TFR are swapped compared to decoder output order
			dec = [dec[1], dec[4], dec[0], dec[2], dec[3], lfe, dec[6], dec[5]];
			// Output decoded channels (0-7) only - B-format metering reads from synth directly
			Out.ar(0, dec);
		}).add;

		s.sync;

	// Load test file automatically (4-channel UHJ: L, R, T=0, Q=0)
	buf = Buffer.read(s, "/home/michael-uwins/Dropbox/PhD/Practical Work/The Alan Parsons Project/Stereotomy/StereoEditUPHJ.wav");
	s.sync;

	// UI
	win = Window("PHJ → 5.1.2 Decoder Test", Rect(80, 80, 780, 480), false).front;
	win.view.background = Color.black;
	StaticText(win, Rect(10, 10, 200, 20)).stringColor_(Color.cyan).string_("PHJ → 5.1.2 Decoder Test");
	fileLabel = StaticText(win, Rect(10, 35, 380, 20)).stringColor_(Color.cyan).string_("StereoEditUPHJ.wav (4-ch UHJ)");
	playBtn = Button(win, Rect(10, 60, 80, 24)).states_([["PLAY", Color.cyan, Color.black]]).action_({
		if(buf.notNil && buf.numFrames > 0) {
			if(player.notNil) { player.free };
			player = Synth(\foa_512_test, [
				\buffer, buf,
				\muteLBus, inputMuteBusses[0].index,
				\muteRBus, inputMuteBusses[1].index,
				\muteTBus, inputMuteBusses[2].index,
				\muteQBus, inputMuteBusses[3].index,
				\muteWBus, muteBusses[0].index,
				\muteXBus, muteBusses[1].index,
				\muteYBus, muteBusses[2].index,
				\muteZBus, muteBusses[3].index
			]);
			// Create/update ServerMeter after synth starts
			{
				if(meter.notNil) { meter.remove };
				meter = ServerMeter2View.new(s, meterContainer, 0@0, 0, 8); // 0 inputs, 8 outputs (decoded)
			}.defer(0.1);
		};
	});
	stopBtn = Button(win, Rect(100, 60, 80, 24)).states_([["STOP", Color.cyan, Color.black]]).action_({ if(player.notNil) { player.free } });
	
	// Input (L, R, T, Q) mute buttons
	StaticText(win, Rect(10, 95, 120, 18)).stringColor_(Color.cyan).string_("Input mutes (L,R,T,Q):");
	inputMuteBtns = Array.fill(4, { |i|
		var x = 10 + (i * 60);
		var label = ["L", "R", "T", "Q"][i];
		StaticText(win, Rect(x, 115, 20, 18)).stringColor_(Color.cyan).align_(\center).string_(label);
		Button(win, Rect(x, 135, 50, 20))
			.states_([["MUTE", Color.black, Color.cyan], ["MUTE", Color.cyan, Color.black]])
			.action_({ |btn| inputMuteBusses[i].set(btn.value) });
	});
	
	// B-format mute buttons
	StaticText(win, Rect(10, 165, 120, 18)).stringColor_(Color.cyan).string_("B-format mutes (W,X,Y,Z):");
	muteBtns = Array.fill(4, { |i|
		var x = 10 + (i * 60);
		var label = ["W", "X", "Y", "Z"][i];
		StaticText(win, Rect(x, 185, 20, 18)).stringColor_(Color.cyan).align_(\center).string_(label);
		Button(win, Rect(x, 205, 50, 20))
			.states_([["MUTE", Color.black, Color.cyan], ["MUTE", Color.cyan, Color.black]])
			.action_({ |btn| muteBusses[i].set(btn.value) });
	});
	
	// Z amplitude monitor (to verify encoder fix)
	StaticText(win, Rect(10, 235, 200, 18)).stringColor_(Color.cyan).string_("Z Channel Amplitude:");
	zAmpLabel = StaticText(win, Rect(220, 235, 150, 18)).stringColor_(Color.yellow).string_("--");
	
	// Monitor Z amplitude and T/Q channels
	OSCdef(\zAmpMonitor, { |msg|
		var zAmp = msg[3];
		var tAmp = msg[4];
		var qAmp = msg[5];
		{
			zAmpLabel.string = if(zAmp > 0.001, {
				"⚠️ Z:%.4f T:%.4f Q:%.4f".format(zAmp.round(0.0001), tAmp.round(0.0001), qAmp.round(0.0001))
			}, {
				"✓ Z:%.6f T:%.4f Q:%.4f".format(zAmp.round(0.000001), tAmp.round(0.0001), qAmp.round(0.0001))
			});
			zAmpLabel.stringColor = if(zAmp > 0.001, { Color.red }, { Color.green });
		}.defer;
	}, '/zAmp');
	
	// ServerMeter container for decoded outputs
	StaticText(win, Rect(10, 260, 360, 20)).stringColor_(Color.cyan).align_(\center).string_("OUTPUT METERS (FL, FR, C, RL, RR, LFE, TFL, TFR)");
	meterContainer = View(win, Rect(10, 280, 360, 180)).background_(Color.black);

	win.onClose = {
		OSCdef(\zAmpMonitor).free;
		if(player.notNil) { player.free };
		if(buf.notNil) { buf.free };
	};
});


