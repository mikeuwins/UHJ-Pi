// FoaVHAP_ATK.sc - Proper ATK-style VHAP transform
// Following the exact ATK pattern used by FoaRotate, FoaTilt, etc.

FoaVHAP : Foa {
	*ar { |in, trim = 0, morph = 1, solo = 0, mul = 1, add = 0|
		var w, x, y, z;
		var zOut, trimLinear, zPrime;
		var isSolo, silence;
		
		// Use ATK validation (same as FoaRotate)
		in = this.checkChans(in);
		#w, x, y, z = in;
		
		// Convert trim from dB to linear
		trimLinear = trim.dbamp;
		
		// For now, simple VHAP processing (no convolution yet)
		// Apply trim and morph to Z channel
		zPrime = z * trimLinear;
		zOut = (z * (1 - morph)) + (zPrime * morph);
		
		// Solo switch: hard switch between normal and solo modes
		// Use > 0.5 threshold for boolean behavior
		isSolo = solo > 0.5;
		silence = DC.ar(0);
		
		^[
			(w * (1 - isSolo)) + (zOut * isSolo),       // W: normal W or Z in solo
			x * (1 - isSolo),                           // X: normal X or silence in solo  
			y * (1 - isSolo),                           // Y: normal Y or silence in solo
			zOut                                        // Z: always processed Z
		].madd(mul, add);
	}
}
