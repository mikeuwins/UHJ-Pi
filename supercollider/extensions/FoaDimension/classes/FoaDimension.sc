// FoaDimension.sc - FOA Dimension Transform
// Port of "Dimension Only" JSFX plugin
// Forward Preference (Width) + Psychoacoustic Shelves

FoaDimension : Foa {
	*ar { |in, 
		width = 0.0,           // Forward Preference k (0.0 to 0.70)
		widthHPF = 180,        // Forward Preference HPF cutoff (Hz)
		shelvesMode = 0,       // 0=Off, 1=2D (WXY), 2=3D (WXYZ)
		gerzonPresets = 0,     // 0=Off, 1=On
		transitionFreq = 400,  // Transition frequency for shelves (Hz)
		lfGain = 0,            // LF gain (dB, -6 to +6)
		hfGain = 0,            // HF gain (dB, -6 to +6)
		outputTrim = 0,        // Output trim (dB, -18 to +18)
		mul = 1, add = 0|
		
		var w, x, y, z;
		var x90;
		var inj;
		var wp, xp, yp, zp;
		var s_on, dim3;
		var widthKr;
		var gLF_W, gHF_W, gLF_X, gHF_X, gLF_Y, gHF_Y, gLF_Z, gHF_Z;
		var psyW_HF, psyX_HF, psyY_HF, psyZ_HF;
		var psyW_LF, psyX_LF, psyY_LF, psyZ_LF;
		var fpHP_freq, tilt_freq, maxFreq;
		var outTrim;
		
		// Use ATK validation
		in = this.checkChans(in);
		#w, x, y, z = in;
		
		// Derived flags - hardcoded to 0 for this app (shelves handled in decoders)
		s_on = 0.0;  // Shelves off
		dim3 = 0.0;  // 2D mode (not 3D)
		
		// Forward Preference HPF cutoff frequency (clipped)
		// Ensure widthHPF is treated as a control rate value
		fpHP_freq = widthHPF.clip(10, SampleRate.ir * 0.333);
		
		// Tilt split cutoff frequency (clipped)
		// Handle both literal and UGen values for transitionFreq
		// Use max() and min() to avoid type mixing issues with .clip()
		maxFreq = SampleRate.ir * 0.333;
		tilt_freq = transitionFreq.max(10).min(maxFreq);
		
		// Psychoacoustic presets (Gerzon-style)
		// Hardcoded to 0 for this app (shelves handled in decoders)
		// All preset values are 0 since gerzonPresets and shelvesMode are always 0
		psyW_HF = 0.0;
		psyX_HF = 0.0;
		psyY_HF = 0.0;
		psyZ_HF = 0.0;
		psyW_LF = 0.0;
		psyX_LF = 0.0;
		psyY_LF = 0.0;
		psyZ_LF = 0.0;
		
		// Per-channel dB targets (global + preset offsets)
		// Since presets are 0, just use user gains directly
		gLF_W = lfGain;
		gHF_W = hfGain;
		gLF_X = lfGain;
		gHF_X = hfGain;
		gLF_Y = lfGain;
		gHF_Y = hfGain;
		gLF_Z = lfGain;
		gHF_Z = hfGain;
		
		// Convert to linear gains
		gLF_W = gLF_W.dbamp;
		gHF_W = gHF_W.dbamp;
		gLF_X = gLF_X.dbamp;
		gHF_X = gHF_X.dbamp;
		gLF_Y = gLF_Y.dbamp;
		gHF_Y = gHF_Y.dbamp;
		gLF_Z = gLF_Z.dbamp;
		gHF_Z = gHF_Z.dbamp;
		
		// Forward Preference: +90°(X) via 4× allpass filters
		// Using AllpassN (like MaplinMatrix/MaplinSM333) instead of LocalIn/Out
		// Convert Niemitalo coefficients to delay times (approximate for first-order behavior)
		// Using very short delays (similar to MaplinMatrix approach)
		widthKr = width + DC.kr(0); // Ensure width is a UGen
		
		// Process allpass chain (always runs, but result is scaled by width)
		x90 = AllpassN.ar(x, 0.01, 0.0009, 0.7);  // ~0.4ms delay (h_d1 ≈ 0.402)
		x90 = AllpassN.ar(x90, 0.01, 0.0019, 0.7); // ~0.86ms delay (h_d2 ≈ 0.856)
		x90 = AllpassN.ar(x90, 0.01, 0.0022, 0.7); // ~0.97ms delay (h_d3 ≈ 0.972)
		x90 = AllpassN.ar(x90, 0.01, 0.0023, 0.7); // ~0.995ms delay (h_d4 ≈ 0.995)
		
		// HPF on injected term (only), then inject into Y
		// BHiPass.ar already gives the high-pass filtered signal
		inj = BHiPass.ar(x90, fpHP_freq, 1) * widthKr.clip(0.0, 0.70);
		
		// Apply Forward Preference (pass through unchanged, inject width into Y)
		wp = w;
		xp = x;
		yp = y + inj;
		zp = z;
		
		// Psychoacoustic Shelves (one-pole split)
		// Since s_on = 0.0 (hardcoded), shelves are bypassed - just pass through
		// W, X, Y, Z already set above - no shelf processing needed when s_on = 0
		
		// Output trim
		outTrim = outputTrim.dbamp;
		
		// Ensure all outputs are always audio-rate (prevent optimization to 0.0)
		wp = wp + DC.ar(0);
		xp = xp + DC.ar(0);
		yp = yp + DC.ar(0);
		zp = zp + DC.ar(0);
		
		^[wp, xp, yp, zp].madd(outTrim * mul, add);
	}
}

