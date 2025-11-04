// FOA→5.1.2 decoder test harness with UHJ/PHJ, WAV load, B-format and speaker meters, pre/post mute/solo

s.waitForBoot({
	var win, main, encMenu, loadBtn, playBtn, stopBtn, fileLabel;
	var preMuteBtns = Array.newClear(4), preSoloBtns = Array.newClear(4); // W X Y Z
	var postMuteBtns = Array.newClear(8), postSoloBtns = Array.newClear(8); // 8 speakers
	var buf = Buffer.alloc(s, 1, 2); // stereo placeholder
	var encoderDict, decoder, encoder, player;
	var bfmtMeterViews = Array.newClear(4), outMeterViews = Array.newClear(8);
	var meterTask;
	// control busses for pre/post mute/solo and meters
	var busPreMute = Array.fill(4, { Bus.control(s, 1) });
	var busPreSolo = Array.fill(4, { Bus.control(s, 1) });
	var busPostMute = Array.fill(8, { Bus.control(s, 1) });
	var busPostSolo = Array.fill(8, { Bus.control(s, 1) });
	var busBfmtMeters = Bus.control(s, 4);
	var busOutMeters = Bus.control(s, 8);

	// Init busses to 0 (no mute/solo)
	{ busPreMute.do(_.set(0)); busPreSolo.do(_.set(0)); busPostMute.do(_.set(0)); busPostSolo.do(_.set(0)); }.defer;

	// Build encoder/decoder
	encoderDict = Dictionary.newFrom([
		\uhj, FoaEncoderKernel.newUHJ,
		\phj, FoaEncoderKernel.newPHJ
	]);
	decoder = Foa512Matrix.newFoaDecoder(\equal, 45, \uhjpi);
	encoder = encoderDict.at(\uhj);

	win = Window("FOA→5.1.2 Test", Rect(40, 40, 820, 520), false).front;
	main = CompositeView(win, win.view.bounds).background_(Color.black);

	StaticText(main, Rect(12, 8, 80, 18)).stringColor_(Color.cyan).string_("Encoder");
	encMenu = PopUpMenu(main, Rect(12, 28, 120, 20))
		.items_(["UHJ", "PHJ"]) 
		.action_({ |m|
			encoder = encoderDict.at((m.value == 1).if(\phj, \uhj));
		});

	fileLabel = StaticText(main, Rect(150, 28, 640, 20)).stringColor_(Color.cyan).string_("No file loaded");
	loadBtn = Button(main, Rect(12, 60, 90, 22))
		.states_([["LOAD", Color.cyan, Color.black]])
		.action_({
			var path = Dialog.openPanel("Choose stereo WAV");
			if(path.notNil) {
				if(buf.notNil) { buf.free };
				buf = Buffer.read(s, path);
				fileLabel.string = (PathName(path).fileName);
				("Loaded: " ++ path).postln;
			};
		});
	playBtn = Button(main, Rect(110, 60, 90, 22))
		.states_([["PLAY", Color.cyan, Color.black]])
		.action_({
			if(player.notNil) { player.free };
			player = Synth(\foa_512_test,
				[\buffer, buf,
				 \encSel, (encMenu.value == 1).if(1, 0),
				 // pass bus indices
				 \preMuteBus0, busPreMute[0].index, \preMuteBus1, busPreMute[1].index, \preMuteBus2, busPreMute[2].index, \preMuteBus3, busPreMute[3].index,
				 \preSoloBus0, busPreSolo[0].index, \preSoloBus1, busPreSolo[1].index, \preSoloBus2, busPreSolo[2].index, \preSoloBus3, busPreSolo[3].index,
				 \postMuteBus0, busPostMute[0].index, \postMuteBus1, busPostMute[1].index, \postMuteBus2, busPostMute[2].index, \postMuteBus3, busPostMute[3].index,
				 \postMuteBus4, busPostMute[4].index, \postMuteBus5, busPostMute[5].index, \postMuteBus6, busPostMute[6].index, \postMuteBus7, busPostMute[7].index,
				 \postSoloBus0, busPostSolo[0].index, \postSoloBus1, busPostSolo[1].index, \postSoloBus2, busPostSolo[2].index, \postSoloBus3, busPostSolo[3].index,
				 \postSoloBus4, busPostSolo[4].index, \postSoloBus5, busPostSolo[5].index, \postSoloBus6, busPostSolo[6].index, \postSoloBus7, busPostSolo[7].index,
				 \bfmtMeterBus, busBfmtMeters.index, \outMeterBus, busOutMeters.index
			]);
		});
	stopBtn = Button(main, Rect(208, 60, 90, 22))
		.states_([["STOP", Color.cyan, Color.black]])
		.action_({ if(player.notNil) { player.free } });

	// Pre (W/X/Y/Z) mute/solo
	StaticText(main, Rect(12, 100, 200, 16)).stringColor_(Color.cyan).string_("B-format Mute/Solo (W/X/Y/Z)");
	4.do({ |i|
		var y = 122 + i * 22;
		StaticText(main, Rect(12, y, 20, 16)).stringColor_(Color.cyan).align_(\center).string_(["W","X","Y","Z"][i]);
		preMuteBtns[i] = Button(main, Rect(40, y, 50, 18))
			.states_([["MUTE", Color.black, Color.cyan],["MUTE", Color.cyan, Color.black]])
			.action_({ |b| busPreMute[i].set((b.value==1).if(1,0)); });
		preSoloBtns[i] = Button(main, Rect(94, y, 50, 18))
			.states_([["SOLO", Color.black, Color.cyan],["SOLO", Color.cyan, Color.black]])
			.action_({ |b| busPreSolo[i].set((b.value==1).if(1,0)); });
		bfmtMeterViews[i] = StaticText(main, Rect(160, y, 100, 16)).stringColor_(Color.cyan).string_("-inf dB");
	});

	// Post (8 speakers) mute/solo
	StaticText(main, Rect(12, 230, 220, 16)).stringColor_(Color.cyan).string_("Speaker Mute/Solo (1..8, 7/8=Tops)");
	8.do({ |i|
		var y = 252 + i * 22;
		StaticText(main, Rect(12, y, 20, 16)).stringColor_(Color.cyan).align_(\center).string_((i+1).asString);
		postMuteBtns[i] = Button(main, Rect(40, y, 50, 18))
			.states_([["MUTE", Color.black, Color.cyan],["MUTE", Color.cyan, Color.black]])
			.action_({ |b| busPostMute[i].set((b.value==1).if(1,0)); });
		postSoloBtns[i] = Button(main, Rect(94, y, 50, 18))
			.states_([["SOLO", Color.black, Color.cyan],["SOLO", Color.cyan, Color.black]])
			.action_({ |b| busPostSolo[i].set((b.value==1).if(1,0)); });
		outMeterViews[i] = StaticText(main, Rect(160, y, 100, 16)).stringColor_(Color.cyan).string_("-inf dB");
	});

	// Meter polling
	meterTask = Routine({
		var bvals = FloatArray.newClear(4);
		var ovals = FloatArray.newClear(8);
		{
			loop {
				busBfmtMeters.getn(4, { |arr|
					bvals = arr;
					{ 4.do({ |i|
						var db = (bvals[i].max(1e-6)).ampdb;
						bfmtMeterViews[i].string = (db.round(0.1).asString ++ " dB");
					}); }.defer;
				});
				busOutMeters.getn(8, { |arr|
					ovals = arr;
					{ 8.do({ |i|
						var db2 = (ovals[i].max(1e-6)).ampdb;
						outMeterViews[i].string = (db2.round(0.1).asString ++ " dB");
					}); }.defer;
				});
				0.1.wait;
			}
		}.fork(AppClock);
	});

	// SynthDef: FOA test path (stereo WAV → FOA via encoder → 5.1.2 decode), with pre/post mute/solo and meters
	SynthDef(\foa_512_test, { |buffer, encSel=0,
		preMuteBus0=0, preMuteBus1=0, preMuteBus2=0, preMuteBus3=0,
		preSoloBus0=0, preSoloBus1=0, preSoloBus2=0, preSoloBus3=0,
		postMuteBus0=0, postMuteBus1=0, postMuteBus2=0, postMuteBus3=0,
		postMuteBus4=0, postMuteBus5=0, postMuteBus6=0, postMuteBus7=0,
		postSoloBus0=0, postSoloBus1=0, postSoloBus2=0, postSoloBus3=0,
		postSoloBus4=0, postSoloBus5=0, postSoloBus6=0, postSoloBus7=0,
		bfmtMeterBus=0, outMeterBus=0|
		var stereo, bfmt, dec, enc, // audio
			preM = Array.fill(4, 0), preS = Array.fill(4, 0), preMask, anySoloPre,
			postM = Array.fill(8, 0), postS = Array.fill(8, 0), postMask, anySoloPost,
			bfmtMasked, outSig, ampsB, ampsO;
		stereo = PlayBuf.ar(2, buffer, BufRateScale.kr(buffer), loop: 1);
		enc = Select.kr(encSel, [FoaEncoderKernel.newUHJ, FoaEncoderKernel.newPHJ]);
		bfmt = FoaEncode.ar(stereo, enc);
		// read pre mute/solo busses
		preM = [In.kr(preMuteBus0,1), In.kr(preMuteBus1,1), In.kr(preMuteBus2,1), In.kr(preMuteBus3,1)];
		preS = [In.kr(preSoloBus0,1), In.kr(preSoloBus1,1), In.kr(preSoloBus2,1), In.kr(preSoloBus3,1)];
		anySoloPre = (preS.sum > 0);
		preMask = (1 - preM) * (anySoloPre.if({ preS }, { [1,1,1,1] }));
		bfmtMasked = [bfmt[0]*preMask[0], bfmt[1]*preMask[1], bfmt[2]*preMask[2], bfmt[3]*preMask[3]];
		// meters for bfmt
		ampsB = [Amplitude.kr(bfmtMasked[0], 0.01, 0.5), Amplitude.kr(bfmtMasked[1], 0.01, 0.5), Amplitude.kr(bfmtMasked[2], 0.01, 0.5), Amplitude.kr(bfmtMasked[3], 0.01, 0.5)];
		Out.kr(bfmtMeterBus, ampsB);
		// decode
		dec = FoaDecode.ar(bfmtMasked, Foa512Matrix.newFoaDecoder(\equal, 45, \uhjpi));
		// read post mute/solo busses
		postM = [In.kr(postMuteBus0,1),In.kr(postMuteBus1,1),In.kr(postMuteBus2,1),In.kr(postMuteBus3,1),In.kr(postMuteBus4,1),In.kr(postMuteBus5,1),In.kr(postMuteBus6,1),In.kr(postMuteBus7,1)];
		postS = [In.kr(postSoloBus0,1),In.kr(postSoloBus1,1),In.kr(postSoloBus2,1),In.kr(postSoloBus3,1),In.kr(postSoloBus4,1),In.kr(postSoloBus5,1),In.kr(postSoloBus6,1),In.kr(postSoloBus7,1)];
		anySoloPost = (postS.sum > 0);
		postMask = (1 - postM) * (anySoloPost.if({ postS }, { [1,1,1,1,1,1,1,1] }));
		outSig = [dec[0]*postMask[0],dec[1]*postMask[1],dec[2]*postMask[2],dec[3]*postMask[3],dec[4]*postMask[4],dec[5]*postMask[5],dec[6]*postMask[6],dec[7]*postMask[7]];
		// meters for outputs
		ampsO = Mix.new([Amplitude.kr(outSig, 0.01, 0.5)]); // not used
		Out.kr(outMeterBus, Amplitude.kr(outSig, 0.01, 0.5));
		Out.ar(0, outSig);
	}).add;

	win.onClose = {
		if(player.notNil) { player.free };
		if(buf.notNil) { buf.free };
		if(meterTask.notNil) { meterTask.stop };
	};
});


