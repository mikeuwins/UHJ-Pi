// PHJ Encoder Extension for ATK
// Adds newPHJ method to existing FoaEncoderKernel class

FoaEncoderKernel {
	*newPHJ { |kernelSize = nil, server = (Server.default), sampleRate, score|
		^super.newCopyArgs(\phj, 0).initKernel(kernelSize, server, sampleRate, score);
	}
}
