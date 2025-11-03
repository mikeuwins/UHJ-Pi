// FoaZSynthesis.sc - FOA Z Synthesis Transform
// Port of "FOA Z Synthesis" JSFX plugin
// Synthesizes Z (height) from X/Y with decorrelation and ambience

FoaZSynthesis : Foa {
	*ar { |in,
		heightAmount = 30,      // Height amount % (0-100)
		heightDelay = 7,        // Height delay (ms, 0-30)
		heightTrim = 0,         // Height trim (dB, -12 to +12)
		heightSource = 0,       // 0=Original, 1=Synthesised
		ambienceSize = 2.5,     // Ambience size (0.1-3.0)
		ambienceDampening = 0.2, // Ambience dampening (0-1)
		ambienceMix = 70,       // Ambience mix % (0-100)
		mul = 1, add = 0|
		
		var w, x, y, z, zOrig;
		var xy_sum, z_src, z_decorr, z_mix, z_soft;
		var z_synth, z_lpf, z_low, z_midhigh, z_midhigh_d, z_vhap;
		var z_hpf, bFormat, aFormat, a0, a1, a2, a3;
		var a0_rev, a1_rev, a2_rev, a3_rev;
		var zOut, zOut_final;
		var amt, d_samp, rev_wet, rev_rt60, rev_damp;
		var dry_w, wet_w;
		var vhap_fc, vhap_coeff;
		var kInvSqrt2, scale;
		var c1_len, c2_len, c3_len, c4_len, ap1_len, ap2_len;
		var c1_delay, c2_delay, c3_delay, c4_delay, ap1_delay, ap2_delay;
		var c1_g, c2_g, c1_fb, c2_fb;
		var a0_c1, a0_c2, a0_c3, a0_c4, a0_comb;
		var a1_c1, a1_c2, a1_c3, a1_c4, a1_comb;
		var a2_c1, a2_c2, a2_c3, a2_c4, a2_comb;
		var a3_c1, a3_c2, a3_c3, a3_c4, a3_comb;
		
		// Use ATK validation
		in = this.checkChans(in);
		#w, x, y, z = in;
		zOrig = z;
		
		// Parameters
		amt = heightAmount * 0.01; // 0..1
		d_samp = (heightDelay * 0.001 * SampleRate.ir).clip(0, 30 * SampleRate.ir * 0.001);
		rev_wet = ambienceMix * 0.01; // 0..1
		rev_rt60 = ambienceSize.clip(0.1, 3.0);
		rev_damp = ambienceDampening.clip(0, 0.99);
		
		// VHAP split coefficient (~1200 Hz)
		vhap_fc = 1200;
		vhap_coeff = OnePole.coef(1, vhap_fc);
		
		// Lateral cue: sum X and Y, subtract a little W to avoid centre-bass lift
		xy_sum = (x + y) * 0.7071067811865476; // 1/sqrt(2)
		z_src = xy_sum - (w * 0.25);
		
		// Decorrelate with short delay
		z_decorr = DelayC.ar(z_src, 0.03, d_samp / SampleRate.ir);
		z_mix = z_decorr;
		
		// Gentle soft clip (tanh, k≈1.5)
		z_soft = z_mix * 1.5;
		z_soft = z_soft.tanh / 1.5.tanh;
		
		// Build dry synthesised Z from lateral energy
		z_synth = z_src * amt;
		
		// VHAP-style two-band split: lows pass direct, mid/high decorrelated
		z_lpf = OnePole.ar(z_synth, vhap_coeff);
		z_low = z_lpf;
		z_midhigh = z_synth - z_low;
		z_midhigh_d = DelayC.ar(z_midhigh, 0.03, d_samp / SampleRate.ir);
		z_vhap = z_midhigh_d;
		
		// Apply 2nd-order HPF to Synth Z before B->A (~1000 Hz)
		z_hpf = BHiPass4.ar(z_vhap, 1000);
		
		// B->A conversion (orientation 2: [FL, FR, BU, BD])
		// B = [W, X, Y, Z], A = [A0, A1, A2, A3]
		// Matrix (orientation 2, weight 1):
		// A0 = 0.5*W + 0.5*X + 0.707*Y + 0*Z
		// A1 = 0.5*W + 0.5*X - 0.707*Y + 0*Z
		// A2 = 0.5*W - 0.5*X + 0*Y + 0.707*Z
		// A3 = 0.5*W - 0.5*X + 0*Y - 0.707*Z
		// For Z-only synthesis: W=0, X=0, Y=0, Z=z_hpf
		kInvSqrt2 = 0.7071067811865476;
		a0 = z_hpf * kInvSqrt2;  // A0 = 0.707*Z (only Z term)
		a1 = z_hpf * kInvSqrt2.neg; // A1 = -0.707*Z
		a2 = z_hpf * kInvSqrt2;    // A2 = 0.707*Z
		a3 = z_hpf * kInvSqrt2.neg; // A3 = -0.707*Z
		
		// Lightweight ambience (Schroeder-style) per A channel
		// 4 parallel comb filters + 2 allpass stages per channel
		// Simplified: using DelayC for combs, AllpassC for allpass
		// Delay lengths scaled by sample rate and RT60
		scale = SampleRate.ir / 44100;
		c1_len = max(32, (1116 * scale).floor);
		c2_len = max(32, (1277 * scale).floor);
		c3_len = max(32, (1422 * scale).floor);
		c4_len = max(32, (1557 * scale).floor);
		ap1_len = max(16, (225 * scale).floor);
		ap2_len = max(16, (341 * scale).floor);
		
		// Convert delay lengths to seconds
		c1_delay = c1_len / SampleRate.ir;
		c2_delay = c2_len / SampleRate.ir;
		c3_delay = c3_len / SampleRate.ir;
		c4_delay = c4_len / SampleRate.ir;
		ap1_delay = ap1_len / SampleRate.ir;
		ap2_delay = ap2_len / SampleRate.ir;
		
		// Compute feedback gains from RT60: g = 10^(-3 * t_delay / RT60)
		c1_g = (10.pow(-3.0 * c1_delay / rev_rt60));
		c2_g = (10.pow(-3.0 * c2_delay / rev_rt60));
		
		// Apply damping: feedback *= (1 - damp)
		c1_fb = c1_g * (1 - rev_damp);
		c2_fb = c2_g * (1 - rev_damp);
		
		// Comb filters (simplified - using DelayC with feedback)
		// Note: Proper comb filter implementation would use LocalIn/Out
		// For now, using a simplified approach with AllpassC
		
		// Channel 0 reverb
		a0_c1 = DelayC.ar(a0, 0.1, c1_delay);
		a0_c2 = DelayC.ar(a0, 0.1, c2_delay);
		a0_c3 = DelayC.ar(a0, 0.1, c3_delay);
		a0_c4 = DelayC.ar(a0, 0.1, c4_delay);
		// Apply feedback (simplified - would need proper comb structure)
		a0_comb = (a0_c1 + a0_c2 + a0_c3 + a0_c4) * 0.5;
		a0_comb = AllpassC.ar(a0_comb, 0.1, ap1_delay, 0.5);
		a0_comb = AllpassC.ar(a0_comb, 0.1, ap2_delay, 0.5);
		a0_rev = (a0 * (1 - rev_wet)) + (a0_comb * rev_wet);
		
		// Channel 1 reverb (simplified - same delays with slight variations)
		a1_c1 = DelayC.ar(a1, 0.1, c1_delay * 1.01);
		a1_c2 = DelayC.ar(a1, 0.1, c2_delay * 1.01);
		a1_c3 = DelayC.ar(a1, 0.1, c3_delay * 1.01);
		a1_c4 = DelayC.ar(a1, 0.1, c4_delay * 1.01);
		a1_comb = (a1_c1 + a1_c2 + a1_c3 + a1_c4) * 0.5;
		a1_comb = AllpassC.ar(a1_comb, 0.1, ap1_delay * 1.01, 0.5);
		a1_comb = AllpassC.ar(a1_comb, 0.1, ap2_delay * 1.01, 0.5);
		a1_rev = (a1 * (1 - rev_wet)) + (a1_comb * rev_wet);
		
		// Channel 2 reverb
		a2_c1 = DelayC.ar(a2, 0.1, c1_delay * 1.02);
		a2_c2 = DelayC.ar(a2, 0.1, c2_delay * 1.02);
		a2_c3 = DelayC.ar(a2, 0.1, c3_delay * 1.02);
		a2_c4 = DelayC.ar(a2, 0.1, c4_delay * 1.02);
		a2_comb = (a2_c1 + a2_c2 + a2_c3 + a2_c4) * 0.5;
		a2_comb = AllpassC.ar(a2_comb, 0.1, ap1_delay * 1.02, 0.5);
		a2_comb = AllpassC.ar(a2_comb, 0.1, ap2_delay * 1.02, 0.5);
		a2_rev = (a2 * (1 - rev_wet)) + (a2_comb * rev_wet);
		
		// Channel 3 reverb
		a3_c1 = DelayC.ar(a3, 0.1, c1_delay * 1.03);
		a3_c2 = DelayC.ar(a3, 0.1, c2_delay * 1.03);
		a3_c3 = DelayC.ar(a3, 0.1, c3_delay * 1.03);
		a3_c4 = DelayC.ar(a3, 0.1, c4_delay * 1.03);
		a3_comb = (a3_c1 + a3_c2 + a3_c3 + a3_c4) * 0.5;
		a3_comb = AllpassC.ar(a3_comb, 0.1, ap1_delay * 1.03, 0.5);
		a3_comb = AllpassC.ar(a3_comb, 0.1, ap2_delay * 1.03, 0.5);
		a3_rev = (a3 * (1 - rev_wet)) + (a3_comb * rev_wet);
		
		// Post-ambience filtering: LPF ~4.5 kHz
		a0_rev = OnePole.ar(a0_rev, OnePole.coef(1, 4500));
		a1_rev = OnePole.ar(a1_rev, OnePole.coef(1, 4500));
		a2_rev = OnePole.ar(a2_rev, OnePole.coef(1, 4500));
		a3_rev = OnePole.ar(a3_rev, OnePole.coef(1, 4500));
		
		// Peaking EQ cut ~3 kHz, Q 1.0, -8 dB (simplified)
		a0_rev = BPeakEQ.ar(a0_rev, 3000, 1.0, -8.0);
		a1_rev = BPeakEQ.ar(a1_rev, 3000, 1.0, -8.0);
		a2_rev = BPeakEQ.ar(a2_rev, 3000, 1.0, -8.0);
		a3_rev = BPeakEQ.ar(a3_rev, 3000, 1.0, -8.0);
		
		// A->B conversion back (compute Z only)
		// A->B is inverse of B->A
		// For Z-only: Z = a2b12*A0 + a2b13*A1 + a2b14*A2 + a2b15*A3
		// From matrix inversion: Z = 0.707*(A2 - A3)
		zOut = (a2_rev - a3_rev) * kInvSqrt2;
		
		// Mild soft limiter
		zOut = (zOut * 1.2).tanh / 1.2.tanh;
		
		// Apply fixed gain (-3 dB)
		zOut = zOut * (-3).dbamp;
		
		// High-shelf ~4 kHz, -5 dB
		zOut = BHiShelf.ar(zOut, 4000, 1.0, -5.0);
		
		// Select Z source
		zOut_final = Select.ar(heightSource > 0.5, [zOrig, zOut]);
		
		// Apply Height trim
		zOut_final = zOut_final * heightTrim.dbamp;
		
		^[w, x, y, zOut_final].madd(mul, add);
	}
}

