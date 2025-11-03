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
		var x90, x90_ap1_fb, x90_ap1_out, x90_ap2_fb, x90_ap2_out;
		var x90_ap3_fb, x90_ap3_out, x90_ap4_fb, x90_ap4_out;
		var inj, inj_lp;
		var wp, xp, yp, zp;
		var w_lp, x_lp, y_lp, z_lp;
		var z_shelved, z_on;
		var s_on, dim3;
		var gLF_W, gHF_W, gLF_X, gHF_X, gLF_Y, gHF_Y, gLF_Z, gHF_Z;
		var psyW_HF, psyX_HF, psyY_HF, psyZ_HF;
		var psyW_LF, psyX_LF, psyY_LF, psyZ_LF;
		var fpHP_coeff, tilt_coeff;
		var outTrim;
		var gerzonOn, dim3Val, hf2d, hf3d;
		var h_d1, h_d2, h_d3, h_d4;
		var tiny;
		
		// Use ATK validation
		in = this.checkChans(in);
		#w, x, y, z = in;
		
		// Niemitalo (+90°) allpass coefficients (first-order)
		h_d1 = 0.4021921162426;
		h_d2 = 0.8561710882420;
		h_d3 = 0.9722909545651;
		h_d4 = 0.9952884791278;
		tiny = 1e-24;
		
		// Derived flags (UGen-compatible)
		s_on = shelvesMode > 0.5;
		dim3 = (shelvesMode - 1) > 0.5; // shelvesMode==2 -> dim3==1
		
		// Forward Preference HPF coefficient
		fpHP_coeff = OnePole.coef(1, widthHPF.clip(10, SampleRate.ir * 0.333));
		
		// Tilt split coefficient (one-pole LPF)
		tilt_coeff = OnePole.coef(1, transitionFreq.clip(10, SampleRate.ir * 0.333));
		
		// Psychoacoustic presets (Gerzon-style)
		// Calculate presets using conditional multiplication (works with both static and control-rate)
		gerzonOn = gerzonPresets > 0.5;
		dim3Val = (shelvesMode - 1) > 0.5; // 2D=0, 3D=1
		
		// 2D values: [1.76, -1.25, -1.25, 0.00]
		// 3D values: [3.01, 1.76, 1.76, 1.76]
		hf2d = [1.76, -1.25, -1.25, 0.00];
		hf3d = [3.01, 1.76, 1.76, 1.76];
		
		psyW_HF = gerzonOn * Select.kr(dim3Val, [hf2d[0], hf3d[0]]);
		psyX_HF = gerzonOn * Select.kr(dim3Val, [hf2d[1], hf3d[1]]);
		psyY_HF = gerzonOn * Select.kr(dim3Val, [hf2d[2], hf3d[2]]);
		psyZ_HF = gerzonOn * Select.kr(dim3Val, [hf2d[3], hf3d[3]]);
		
		// Counter-LF to keep overall power closer
		psyW_LF = psyW_HF.neg * 0.6;
		psyX_LF = psyX_HF.neg * 0.6;
		psyY_LF = psyY_HF.neg * 0.6;
		psyZ_LF = psyZ_HF.neg * 0.6;
		
		// Per-channel dB targets (global + preset offsets)
		gLF_W = lfGain + psyW_LF;
		gHF_W = hfGain + psyW_HF;
		gLF_X = lfGain + psyX_LF;
		gHF_X = hfGain + psyX_HF;
		gLF_Y = lfGain + psyY_LF;
		gHF_Y = hfGain + psyY_HF;
		gLF_Z = lfGain + psyZ_LF;
		gHF_Z = hfGain + psyZ_HF;
		
		// Convert to linear gains
		gLF_W = gLF_W.dbamp;
		gHF_W = gHF_W.dbamp;
		gLF_X = gLF_X.dbamp;
		gHF_X = gHF_X.dbamp;
		gLF_Y = gLF_Y.dbamp;
		gHF_Y = gHF_Y.dbamp;
		gLF_Z = gLF_Z.dbamp;
		gHF_Z = gHF_Z.dbamp;
		
		// Forward Preference: +90°(X) via 4× first-order allpass
		// First-order allpass: y[n] = -a*x[n] + x[n-1] + a*y[n-1]
		// Using LocalIn/Out for feedback state
		// Stage 1 allpass
		x90_ap1_fb = LocalIn.ar(1);
		x90_ap1_out = (x * h_d1.neg) + Delay1.ar(x) + (x90_ap1_fb * h_d1) + tiny;
		LocalOut.ar(x90_ap1_out);
		
		// Stage 2 allpass
		x90_ap2_fb = LocalIn.ar(1);
		x90_ap2_out = (x90_ap1_out * h_d2.neg) + Delay1.ar(x90_ap1_out) + (x90_ap2_fb * h_d2) + tiny;
		LocalOut.ar(x90_ap2_out);
		
		// Stage 3 allpass
		x90_ap3_fb = LocalIn.ar(1);
		x90_ap3_out = (x90_ap2_out * h_d3.neg) + Delay1.ar(x90_ap2_out) + (x90_ap3_fb * h_d3) + tiny;
		LocalOut.ar(x90_ap3_out);
		
		// Stage 4 allpass
		x90_ap4_fb = LocalIn.ar(1);
		x90_ap4_out = (x90_ap3_out * h_d4.neg) + Delay1.ar(x90_ap3_out) + (x90_ap4_fb * h_d4) + tiny;
		LocalOut.ar(x90_ap4_out);
		
		x90 = x90_ap4_out;
		
		// HPF on injected term (only), then inject into Y
		inj_lp = OnePole.ar(x90, fpHP_coeff);
		inj = (x90 - inj_lp) * width.clip(0.0, 0.70);
		
		// Apply Forward Preference
		wp = w;
		xp = x;
		yp = y + inj;
		zp = z;
		
		// Psychoacoustic Shelves (one-pole split)
		// Always compute shelves, then apply conditionally
		// W
		w_lp = OnePole.ar(wp, tilt_coeff);
		wp = wp * (1 - s_on) + ((w_lp * gLF_W) + ((wp - w_lp) * gHF_W)) * s_on;
		
		// X
		x_lp = OnePole.ar(xp, tilt_coeff);
		xp = xp * (1 - s_on) + ((x_lp * gLF_X) + ((xp - x_lp) * gHF_X)) * s_on;
		
		// Y
		y_lp = OnePole.ar(yp, tilt_coeff);
		yp = yp * (1 - s_on) + ((y_lp * gLF_Y) + ((yp - y_lp) * gHF_Y)) * s_on;
		
		// Z (3D only - apply shelves only if 3D mode)
		z_lp = OnePole.ar(zp, tilt_coeff);
		z_shelved = (z_lp * gLF_Z) + ((zp - z_lp) * gHF_Z);
		z_on = s_on * dim3;
		zp = zp * (1 - z_on) + z_shelved * z_on;
		
		// Output trim
		outTrim = outputTrim.dbamp;
		
		^[wp, xp, yp, zp].madd(outTrim * mul, add);
	}
}

