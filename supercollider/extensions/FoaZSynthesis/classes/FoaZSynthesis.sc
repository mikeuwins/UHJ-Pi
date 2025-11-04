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
		var zOut, zOut_final, heightSourceKr;
		var amt, d_samp, rev_wet, rev_rt60, rev_damp;
		var dry_w, wet_w;
		var vhap_fc;
		var kInvSqrt2, scale;
		var c1_len, c2_len, ap1_len;
		var c1_delay, c2_delay, ap1_delay;
		var combDecayTime;
		var a0_c1, a0_c2, a0_comb;
		var a1_c1, a1_c2, a1_comb;
		var a2_c1, a2_c2, a2_comb;
		var a3_c1, a3_c2, a3_comb;
		
		// Use ATK validation
		in = this.checkChans(in);
		#w, x, y, z = in;
		// Ensure zOrig is always audio-rate (use DC.ar addition to prevent optimization to 0.0)
		// DC.ar(0) creates an audio-rate constant that can't be optimized away
		zOrig = z + DC.ar(0);
		
		// Parameters
		amt = heightAmount * 0.01; // 0..1
		d_samp = (heightDelay * 0.001 * SampleRate.ir).clip(0, 30 * SampleRate.ir * 0.001);
		rev_wet = ambienceMix * 0.01; // 0..1
		rev_rt60 = ambienceSize.clip(0.1, 3.0);
		rev_damp = ambienceDampening.clip(0, 0.99);
		
		// VHAP split cutoff frequency (~1200 Hz)
		vhap_fc = 1200;
		
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
		// Ensure z_synth is always audio-rate (use max with tiny Silent to prevent optimization to 0.0)
		z_synth = (z_src * amt).max(Silent.ar(1) * 0.000001);
		
		// VHAP-style two-band split: lows pass direct, mid/high decorrelated
		z_lpf = BLowPass.ar(z_synth, vhap_fc, 1);
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
		// Ensure z_hpf is always audio-rate (even if zero) to prevent optimization
		kInvSqrt2 = 0.7071067811865476;
		// Ensure audio-rate by adding tiny Silent (prevents 0.0 optimization, doesn't affect value)
		// Use abs() to ensure positive for max, then restore sign
		a0 = (z_hpf * kInvSqrt2).abs.max(Silent.ar(1) * 0.000001) * (z_hpf * kInvSqrt2).sign;  // A0 = 0.707*Z
		a1 = (z_hpf * kInvSqrt2.neg).abs.max(Silent.ar(1) * 0.000001) * (z_hpf * kInvSqrt2.neg).sign; // A1 = -0.707*Z
		a2 = (z_hpf * kInvSqrt2).abs.max(Silent.ar(1) * 0.000001) * (z_hpf * kInvSqrt2).sign;    // A2 = 0.707*Z
		a3 = (z_hpf * kInvSqrt2.neg).abs.max(Silent.ar(1) * 0.000001) * (z_hpf * kInvSqrt2.neg).sign; // A3 = -0.707*Z
		
		// Lightweight ambience (Schroeder-style) per A channel
		// 4 parallel comb filters + 2 allpass stages per channel
		// Simplified: using DelayC for combs, AllpassC for allpass
		// Delay lengths scaled by sample rate and RT60
		// Reduced to 2 combs + 1 allpass to save interconnect buffers
		scale = SampleRate.ir / 44100;
		c1_len = max(32, (1116 * scale).floor);
		c2_len = max(32, (1277 * scale).floor);
		ap1_len = max(16, (225 * scale).floor);
		
		// Convert delay lengths to seconds
		c1_delay = c1_len / SampleRate.ir;
		c2_delay = c2_len / SampleRate.ir;
		ap1_delay = ap1_len / SampleRate.ir;
		
		// Simplified Schroeder-style reverb: 2 parallel comb filters + 1 allpass stage per channel
		// Reduced from 4 combs to save interconnect buffers
		// Adjust decayTime to account for damping: decayTime = rev_rt60 / (1 - rev_damp)
		combDecayTime = rev_rt60 / (1 - rev_damp).max(0.01);
		
		// Channel 0 reverb
		a0_c1 = CombC.ar(a0, 0.1, c1_delay, combDecayTime);
		a0_c2 = CombC.ar(a0, 0.1, c2_delay, combDecayTime);
		a0_comb = (a0_c1 + a0_c2) * 0.5;
		a0_comb = AllpassC.ar(a0_comb, 0.1, ap1_delay, 0.5);
		a0_rev = (a0 * (1 - rev_wet)) + (a0_comb * rev_wet);
		
		// Channel 1 reverb (slight delay variations for decorrelation)
		a1_c1 = CombC.ar(a1, 0.1, c1_delay * 1.01, combDecayTime);
		a1_c2 = CombC.ar(a1, 0.1, c2_delay * 1.01, combDecayTime);
		a1_comb = (a1_c1 + a1_c2) * 0.5;
		a1_comb = AllpassC.ar(a1_comb, 0.1, ap1_delay * 1.01, 0.5);
		a1_rev = (a1 * (1 - rev_wet)) + (a1_comb * rev_wet);
		
		// Channel 2 reverb
		a2_c1 = CombC.ar(a2, 0.1, c1_delay * 1.02, combDecayTime);
		a2_c2 = CombC.ar(a2, 0.1, c2_delay * 1.02, combDecayTime);
		a2_comb = (a2_c1 + a2_c2) * 0.5;
		a2_comb = AllpassC.ar(a2_comb, 0.1, ap1_delay * 1.02, 0.5);
		a2_rev = (a2 * (1 - rev_wet)) + (a2_comb * rev_wet);
		
		// Channel 3 reverb
		a3_c1 = CombC.ar(a3, 0.1, c1_delay * 1.03, combDecayTime);
		a3_c2 = CombC.ar(a3, 0.1, c2_delay * 1.03, combDecayTime);
		a3_comb = (a3_c1 + a3_c2) * 0.5;
		a3_comb = AllpassC.ar(a3_comb, 0.1, ap1_delay * 1.03, 0.5);
		a3_rev = (a3 * (1 - rev_wet)) + (a3_comb * rev_wet);
		
		// Post-ambience filtering: LPF ~4.5 kHz
		a0_rev = BLowPass.ar(a0_rev, 4500, 1);
		a1_rev = BLowPass.ar(a1_rev, 4500, 1);
		a2_rev = BLowPass.ar(a2_rev, 4500, 1);
		a3_rev = BLowPass.ar(a3_rev, 4500, 1);
		
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
		
		// Ensure both zOrig and zOut are always audio-rate (prevent optimization to 0.0)
		// Use DC.ar(0) addition to ensure audio-rate even when signals are zero
		zOrig = zOrig + DC.ar(0);
		zOut = zOut + DC.ar(0);
		
		// Select Z source using LinXFade2 (avoids Select.ar optimization issues)
		// heightSource: 0 = Original Z, 1 = Synthesized Z
		// Use LinXFade2 to crossfade between zOrig and zOut
		// heightSource is converted to crossfade control: 0->-1 (zOrig), 1->1 (zOut)
		heightSourceKr = heightSource + DC.kr(0); // Ensure UGen
		zOut_final = LinXFade2.ar(zOrig, zOut, (heightSourceKr * 2) - 1);
		
		// Apply Height trim
		zOut_final = zOut_final * heightTrim.dbamp;
		
		^[w, x, y, zOut_final].madd(mul, add);
	}
}

