// FoaVHAP_Simple.sc - Minimal VHAP implementation to isolate issues
// Bypasses complex Select.ar and PartConv to test basic functionality

FoaVHAP_Simple {
	
	*ar { |input, trim = 0, morph = 1, solo = 0|
		var w, x, y, z;
		var zOut, trimLinear;
		
		// Extract B-format components
		w = input[0]; // W (omnidirectional)
		x = input[1]; // X (front-back)
		y = input[2]; // Y (left-right) 
		z = input[3]; // Z (up-down)
		
		// Convert trim from dB to linear
		trimLinear = trim.dbamp;
		
		// For now, just apply trim to Z channel (no convolution)
		// This tests if the basic structure works
		zOut = z * trimLinear;
		
		// Simple morph: blend original Z with modified Z
		zOut = (z * (1 - morph)) + (zOut * morph);
		
		// Simple solo: use LinXFade2 to crossfade between normal and solo
		// This avoids the boolean/Select.ar issues
		var normalOutput = [w, x, y, zOut];
		var soloOutput = [zOut, 0, 0, zOut];
		
		// Use LinXFade2 to blend between normal and solo based on solo parameter
		// solo = 0 -> normal, solo = 1 -> solo
		^[
			LinXFade2.ar(normalOutput[0], soloOutput[0], solo * 2 - 1),
			LinXFade2.ar(normalOutput[1], soloOutput[1], solo * 2 - 1),
			LinXFade2.ar(normalOutput[2], soloOutput[2], solo * 2 - 1),
			LinXFade2.ar(normalOutput[3], soloOutput[3], solo * 2 - 1)
		];
	}
}
