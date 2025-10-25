// Test PHJ Encoder Implementation
// Tests that FoaEncoderKernel.newPHJ is defined and can be instantiated

"Testing PHJ Encoder...".postln;

// Test 1: Check if method exists
"Test 1: Checking if newPHJ method exists...".postln;
if(FoaEncoderKernel.respondsTo(\newPHJ), {
	"  ✓ newPHJ method exists".postln;
}, {
	"  ✗ newPHJ method NOT FOUND".postln;
});

// Test 2: Try to create an encoder instance
"Test 2: Attempting to create PHJ encoder instance...".postln;
try {
	var encoder;
	encoder = FoaEncoderKernel.newPHJ(2048, s);
	if(encoder.notNil, {
		"  ✓ Encoder created successfully".postln;
		"  ✓ Kind: %".format(encoder.kind).postln;
		"  ✓ Outputs: %".format(encoder.numOutputs).postln;
		"  ✓ Channels: %".format(encoder.numChannels).postln;
		encoder.free;
		"  ✓ Encoder freed successfully".postln;
	}, {
		"  ✗ Encoder is nil".postln;
	});
}, { |error|
	"  ✗ Error creating encoder: %".format(error.errorString).postln;
};

"Test complete!".postln;
