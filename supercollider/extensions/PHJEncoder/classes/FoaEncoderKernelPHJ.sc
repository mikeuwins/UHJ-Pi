// PHJ Encoder Extension for ATK
// Creates a separate PHJEncoder class that follows FoaEncoderKernel interface

PHJEncoder {
	var <kind, <subjectID;
	var <kernel, kernelBundle, kernelInfo;
	var <dirChannels;
	var <op = \kernel;
	var <set = \FOA;

	*new { |kernelSize = nil, server = (Server.default), sampleRate, score|
		^super.newCopyArgs(\phj, 0).initKernel(kernelSize, server, sampleRate, score);
	}
	
	initPath {
		var kernelLibPath;
		var encodersPath;

		kernelLibPath = PathName.new(Atk.userKernelDir);

		if(kernelLibPath.isFolder.not, {		// is kernel lib installed for all users?
			PathName.new(Atk.systemKernelDir)	// no? set for single user
		});

		encodersPath = PathName.new("/FOA/encoders");

		^kernelLibPath +/+ encodersPath +/+ PathName.new(this.kind.asString)
	}

	initKernel { |kernelSize, server, sampleRate, score|
		var databasePath, subjectPath;
		var chans;
		var errorMsg;
		var sampleRateStr;

		if(sampleRate.notNil, {
			sampleRateStr = sampleRate.asInteger.asString
		});

		if((server.serverRunning.not and: { sampleRateStr.isNil and: { score.isNil } }), {
			Error(
				"Please boot server: %, or provide a CtkScore or Score.".format(
					server.name.asString
				)
			).throw
		});

		kernelBundle = [0.0];
		kernelInfo = [];

		// PHJ-specific configuration
		dirChannels = [inf, inf, inf, inf];  // 4 output channels: W, X, Y, Z
		if(sampleRateStr.isNil, {
			sampleRateStr = server.sampleRate.asInteger.asString
		});
		chans = 4;  // [w, x, y, z]

		// init kernelSize if need be
		if(kernelSize.isNil, {
			kernelSize = switch(sampleRateStr.asSymbol,
				\None, 512,
				\44100, 512,
				\48000, 512,
				\88200, 1024,
				\96000, 1024,
				\176400, 2048,
				\192000, 2048
			)
		});

		// init kernel root, generate subjectPath and kernelFiles
		databasePath = this.initPath;
		subjectPath = databasePath +/+ PathName.new(
			sampleRateStr ++ "/" ++
			kernelSize ++ "/" ++
			subjectID.asString.padLeft(4, "0")
		);

		// attempt to load kernel
		if(subjectPath.isFolder.not, {	// does kernel path exist?
			case(
				// --> missing kernel database
				{ databasePath.isFolder.not }, {
					errorMsg = "ATK kernel database missing!" +
					"Please install % database.".format(this.kind)
				},
				// --> unsupported SR
				{ PathName.new(subjectPath.parentLevelPath(2)).isFolder.not }, {
					"Supported samplerates:".warn;
					(PathName.new(subjectPath.parentLevelPath(3)).folders).do({
						|folder|
						("\t" + folder.folderName).postln
					});

					errorMsg = "Samplerate = % is not available for".format(sampleRateStr)
					+
					"% kernel encoder.".format(this.kind)
				},
				// --> unsupported kernelSize
				{ PathName.new(subjectPath.parentLevelPath(1)).isFolder.not }, {
					"Supported kernel sizes:".warn;
					(PathName.new(subjectPath.parentLevelPath(2)).folders).do({
						|folder|
						("\t" + folder.folderName).postln
					});

					errorMsg = "Kernel size = % is not available for".format(kernelSize)
					+
					"% kernel encoder.".format(this.kind)
				},
				// --> unsupported subject
				{ subjectPath.isFolder.not }, {
					"Supported subjects:".warn;
					(PathName.new(subjectPath.parentLevelPath(1)).folders).do({
						|folder|
						("\t" + folder.folderName).postln
					});

					errorMsg = "Subject % is not available for".format(subjectID)
					+
					"% kernel encoder.".format(this.kind)
				}
			);

			if(errorMsg.notNil, {
				Error(errorMsg).throw
			});
		});

		// load kernel files
		kernelInfo = Array.fill(chans, { |i|
			var kernelFile, kernelPath;
			kernelFile = switch(i,
				0, "UHJ_L.wav",
				1, "UHJ_R.wav", 
				2, "UHJ_T.wav",
				3, "UHJ_Q.wav"
			);
			kernelPath = subjectPath +/+ PathName.new(kernelFile);
			
			if(kernelPath.isFile, {
				Buffer.read(server, kernelPath.fullPath)
			}, {
				Error("Kernel file not found: %".format(kernelPath.fullPath)).throw
			});
		});

		^this;
	}
}