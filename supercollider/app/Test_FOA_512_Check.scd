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
	var zAmpLabel, logFile;

		// Create PHJ encoder and 5.1.2 decoder
		"Server sample rate: %".format(s.sampleRate).postln;
		encoder = FoaEncoderKernel.newPHJ;
		// Debug: check kernel structure
		"PHJ Encoder kernel shape: %".format(encoder.kernel.shape).postln;
		"PHJ Encoder kernel numInputs: %, numOutputs: %".format(encoder.numInputs, encoder.numOutputs).postln;
		// Check kernel info to see what files were loaded
		if(encoder.kernelInfo.notNil, {
			"PHJ Encoder kernel files loaded:".postln;
			encoder.kernelInfo.do({ |info, i|
				"  Input %: %".format(i, info[0]).postln;
			});
		});
		decoder = FoaDecoderMatrix.new5_0_2(\equal);
		// Decoder outputs (ATK order, 7 channels): [0]=C, [1]=FL, [2]=RL, [3]=RR, [4]=FR, [5]=TFR, [6]=TFL
		// Mapped to UHJ-Pi layout: [0] FL, [1] FR, [2] RL, [3] RR, [4] C, [5] SUB, [6] TFL, [7] TFR

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
			var zAbs, heightGateThreshold, heightGateGainKr, heightGateGain;
			var fileChans;

			// Load file - 4-channel UHJ (L, R, T=0, Q=0) for PHJ encoder
			// If kernels are correct (as confirmed in Reaper), L/R with T=0,Q=0 should produce Z=0
			fileChans = PlayBuf.ar(4, buffer, BufRateScale.kr(buffer), loop: 1); // Full PHJ (L,R,T,Q)
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
			// new5_0_2 decoder outputs 7 channels: [0]=C, [1]=FL, [2]=RL, [3]=RR, [4]=FR, [5]=TFR, [6]=TFL (ATK order)
			
			// Height gate: envelope follower on Z magnitude to mute height channels when Z≈0
			// This prevents W/X/Y leakage into height speakers for horizontal sources
			zAbs = Amplitude.kr(bfmt[3], 0.01, 0.05); // Z magnitude with envelope follower
			heightGateThreshold = 0.0001;
			heightGateGainKr = (zAbs > heightGateThreshold); // Control rate: 1 when Z present, 0 when Z absent
			heightGateGain = K2A.ar(heightGateGainKr); // Convert to audio rate
			
			// Apply gate to height channels (dec[5]=TFR, dec[6]=TFL)
			dec[5] = dec[5] * heightGateGain;
			dec[6] = dec[6] * heightGateGain;
			
			// LFE from FL+FR lowpass (dec[1]=FL, dec[4]=FR)
			lfe = BLowPass.ar(dec[1] + dec[4], 120, 1, 0.4);
			// Reorder to UHJ-Pi order (8 channels): FL, FR, RL, RR, C, SUB, TFL, TFR
			// This aligns with Quad (1-4) and 5.1 (1-5), then adds height channels
			// Note: TFL and TFR are swapped compared to decoder output order
			dec = [dec[1], dec[4], dec[2], dec[3], dec[0], lfe, dec[6], dec[5]];
			// Output decoded channels (0-7) only - B-format metering reads from synth directly
			Out.ar(0, dec);
		}).add;

		s.sync;

	// Load test file automatically
	// Option 1: UHJ file (L, R, T=0, Q=0) - should produce Z=0
	// buf = Buffer.read(s, "/Users/michaeluwins/Dropbox/PhD/Practical Work/The Alan Parsons Project/Stereotomy/StereoEditUPHJ.wav");
	// Option 2: PHJ file (L, R, T, Q all active) - should produce all 8 channels
	buf = Buffer.read(s, "/Users/michaeluwins/Dropbox/PhD/Practical Work/Rhombus Renders/PHJ/10 Love Is The Answer PHJ.wav");
	s.sync;

	// UI
	win = Window("PHJ → 5.1.2 Decoder Test", Rect(80, 80, 900, 520), false).front;
	win.view.background = Color.black;
	StaticText(win, Rect(10, 10, 200, 20)).stringColor_(Color.cyan).string_("PHJ → 5.1.2 Decoder Test");
	fileLabel = StaticText(win, Rect(10, 35, 850, 20)).stringColor_(Color.cyan).string_("10 Love Is The Answer PHJ.wav (4-ch PHJ)");
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
	StaticText(win, Rect(10, 95, 200, 18)).stringColor_(Color.cyan).string_("Input mutes (L,R,T,Q):");
	inputMuteBtns = Array.fill(4, { |i|
		var x = 10 + (i * 60);
		var label = ["L", "R", "T", "Q"][i];
		StaticText(win, Rect(x, 115, 20, 18)).stringColor_(Color.cyan).align_(\center).string_(label);
		Button(win, Rect(x, 135, 50, 20))
			.states_([["MUTE", Color.black, Color.cyan], ["MUTE", Color.cyan, Color.black]])
			.action_({ |btn| inputMuteBusses[i].set(btn.value) });
	});
	
	// B-format mute buttons
	StaticText(win, Rect(10, 165, 200, 18)).stringColor_(Color.cyan).string_("B-format mutes (W,X,Y,Z):");
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
	zAmpLabel = StaticText(win, Rect(220, 235, 250, 18)).stringColor_(Color.yellow).string_("--");
	
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
	StaticText(win, Rect(10, 260, 880, 20)).stringColor_(Color.cyan).align_(\center).string_("OUTPUT METERS (FL, FR, C, RL, RR, LFE, TFL, TFR)");
	meterContainer = View(win, Rect(10, 280, 880, 180)).background_(Color.black);

	// Diagnostics button: runs Z-leak probes and logs to file
	logFile = File.open("/Users/michaeluwins/UHJ-Pi/phj_z_diagnostics.log", "w");
	logFile.write("PHJ Z-Leak Diagnostics\n");
	logFile.write("=" ++ "\n");
	logFile.close;

	Button(win, Rect(200, 60, 110, 24)).states_([["DIAGNOSTICS", Color.cyan, Color.black]]).action_({
		{
			var e, d, unit, mk, x, in4, z0, zSwap, zSign;
			e = encoder; // reuse loaded encoder
			d = decoder; // reuse loaded decoder
			if(e.isNil or: { d.isNil }) {
				"[Diag] Encoder or decoder not initialised yet.".warn;
			} {
				logFile = File.open("/Users/michaeluwins/UHJ-Pi/phj_z_diagnostics.log", "a");
				logFile.write("\n" ++ Date.getDate.format("%Y-%m-%d %H:%M:%S") ++ "\n");
				logFile.write("Running Z-leak diagnostics...\n");
				logFile.close;
				
				// 1) Per-input Z contributions
				unit = 0.1;
				mk = { |l, r, t, q| [l, r, t, q].collect(_ * PinkNoise.ar(unit)) };
				{
					var zL = FoaEncode.ar(mk.(1,0,0,0), e)[3];
					var zR = FoaEncode.ar(mk.(0,1,0,0), e)[3];
					var zT = FoaEncode.ar(mk.(0,0,1,0), e)[3];
					var zQ = FoaEncode.ar(mk.(0,0,0,1), e)[3];
					SendReply.kr(Impulse.kr(5), '/zprobe', [
						Amplitude.kr(zL,0.01,0.1),
						Amplitude.kr(zR,0.01,0.1),
						Amplitude.kr(zT,0.01,0.1),
						Amplitude.kr(zQ,0.01,0.1)
					]);
					Out.ar(0, Silent.ar(2));
				}.play;

				// 2) L-only Z output (baseline test)
				{
					var x = PinkNoise.ar(0.1);
					var in4 = [x, Silent.ar, Silent.ar, Silent.ar];
					var z0 = FoaEncode.ar(in4, e)[3];
					SendReply.kr(Impulse.kr(5), '/zmap', [
						Amplitude.kr(z0,0.01,0.1),
						0, // placeholder for swap test (disabled)
						0  // placeholder for sign test (disabled)
					]);
					Out.ar(0, Silent.ar(2));
				}.play;

				// 3) B-format component diagnostics: What does L vs R produce?
				{
					var testSig = PinkNoise.ar(0.1);
					var bfmtL, bfmtR;
					
					// L-only: [L, 0, 0, 0]
					bfmtL = FoaEncode.ar([testSig, Silent.ar, Silent.ar, Silent.ar], e);
					
					// R-only: [0, R, 0, 0]
					bfmtR = FoaEncode.ar([Silent.ar, testSig, Silent.ar, Silent.ar], e);
					
					SendReply.kr(Impulse.kr(5), '/bfmtL', [
						Amplitude.kr(bfmtL[0], 0.01, 0.1), // W
						Amplitude.kr(bfmtL[1], 0.01, 0.1), // X
						Amplitude.kr(bfmtL[2], 0.01, 0.1), // Y
						Amplitude.kr(bfmtL[3], 0.01, 0.1)  // Z
					]);
					
					SendReply.kr(Impulse.kr(5), '/bfmtR', [
						Amplitude.kr(bfmtR[0], 0.01, 0.1), // W
						Amplitude.kr(bfmtR[1], 0.01, 0.1), // X
						Amplitude.kr(bfmtR[2], 0.01, 0.1), // Y
						Amplitude.kr(bfmtR[3], 0.01, 0.1)  // Z
					]);
					
					Out.ar(0, Silent.ar(2));
				}.play;

				// 4) Decoder routing diagnostics: L-only and R-only
				{
					var testSig = PinkNoise.ar(0.1);
					var bfmtL, bfmtR, decL, decR, lfeL, lfeR;
					
					// L-only: [L, 0, 0, 0]
					bfmtL = FoaEncode.ar([testSig, Silent.ar, Silent.ar, Silent.ar], e);
					decL = FoaDecode.ar(bfmtL, d);
					lfeL = BLowPass.ar(decL[1] + decL[4], 120, 1, 0.4);
					decL = [decL[1], decL[4], decL[0], decL[2], decL[3], lfeL, decL[6], decL[5]];
					
					// R-only: [0, R, 0, 0]
					bfmtR = FoaEncode.ar([Silent.ar, testSig, Silent.ar, Silent.ar], e);
					decR = FoaDecode.ar(bfmtR, d);
					lfeR = BLowPass.ar(decR[1] + decR[4], 120, 1, 0.4);
					decR = [decR[1], decR[4], decR[0], decR[2], decR[3], lfeR, decR[6], decR[5]];
					
					SendReply.kr(Impulse.kr(5), '/decoderL', [
						Amplitude.kr(decL[0], 0.01, 0.1), // FL
						Amplitude.kr(decL[1], 0.01, 0.1), // FR
						Amplitude.kr(decL[2], 0.01, 0.1), // C
						Amplitude.kr(decL[3], 0.01, 0.1), // RL
						Amplitude.kr(decL[4], 0.01, 0.1), // RR
						Amplitude.kr(decL[5], 0.01, 0.1), // LFE
						Amplitude.kr(decL[6], 0.01, 0.1), // TFL
						Amplitude.kr(decL[7], 0.01, 0.1)  // TFR
					]);
					
					SendReply.kr(Impulse.kr(5), '/decoderR', [
						Amplitude.kr(decR[0], 0.01, 0.1), // FL
						Amplitude.kr(decR[1], 0.01, 0.1), // FR
						Amplitude.kr(decR[2], 0.01, 0.1), // C
						Amplitude.kr(decR[3], 0.01, 0.1), // RL
						Amplitude.kr(decR[4], 0.01, 0.1), // RR
						Amplitude.kr(decR[5], 0.01, 0.1), // LFE
						Amplitude.kr(decR[6], 0.01, 0.1), // TFL
						Amplitude.kr(decR[7], 0.01, 0.1)  // TFR
					]);
					
					Out.ar(0, Silent.ar(8));
				}.play;
			}
		}.defer(0.05);
	});

	OSCdef(\zprobe, { |msg|
		var logStr = "[Diag] Z per-input (L,R,T,Q): %".format(msg[3..6]);
		logStr.postln;
		logFile = File.open("/Users/michaeluwins/UHJ-Pi/phj_z_diagnostics.log", "a");
		logFile.write(logStr ++ "\n");
		logFile.close;
	}, '/zprobe');

	OSCdef(\zmap, { |msg|
		var logStr = "[Diag] Z tests (baseline, swap, sign): %".format(msg[3..5]);
		logStr.postln;
		logFile = File.open("/Users/michaeluwins/UHJ-Pi/phj_z_diagnostics.log", "a");
		logFile.write(logStr ++ "\n");
		logFile.close;
	}, '/zmap');

	OSCdef(\decoderL, { |msg|
		var logStr = "[Diag] Decoder L-only outputs (FL,FR,C,RL,RR,LFE,TFL,TFR): %".format(msg[3..10]);
		logStr.postln;
		logFile = File.open("/Users/michaeluwins/UHJ-Pi/phj_z_diagnostics.log", "a");
		logFile.write(logStr ++ "\n");
		logFile.close;
	}, '/decoderL');

	OSCdef(\decoderR, { |msg|
		var logStr = "[Diag] Decoder R-only outputs (FL,FR,C,RL,RR,LFE,TFL,TFR): %".format(msg[3..10]);
		logStr.postln;
		logFile = File.open("/Users/michaeluwins/UHJ-Pi/phj_z_diagnostics.log", "a");
		logFile.write(logStr ++ "\n");
		logFile.close;
	}, '/decoderR');

	OSCdef(\bfmtL, { |msg|
		var logStr = "[Diag] B-format L-only (W,X,Y,Z): %".format(msg[3..6]);
		logStr.postln;
		logFile = File.open("/Users/michaeluwins/UHJ-Pi/phj_z_diagnostics.log", "a");
		logFile.write(logStr ++ "\n");
		logFile.close;
	}, '/bfmtL');

	OSCdef(\bfmtR, { |msg|
		var logStr = "[Diag] B-format R-only (W,X,Y,Z): %".format(msg[3..6]);
		logStr.postln;
		logFile = File.open("/Users/michaeluwins/UHJ-Pi/phj_z_diagnostics.log", "a");
		logFile.write(logStr ++ "\n");
		logFile.close;
	}, '/bfmtR');

	win.onClose = {
		OSCdef(\zAmpMonitor).free;
		OSCdef(\zprobe).free;
		OSCdef(\zmap).free;
		OSCdef(\decoderL).free;
		OSCdef(\decoderR).free;
		OSCdef(\bfmtL).free;
		OSCdef(\bfmtR).free;
		if(player.notNil) { player.free };
		if(buf.notNil) { buf.free };
	};
});


