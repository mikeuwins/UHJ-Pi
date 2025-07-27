// MaplinSM333.sc - B-Format Ambisonic Spatial Enhancement
// Simulates the Maplin SM-333 Surround Sound Matrix in B-format domain
// Compatible with any ambisonic encoder input

MaplinSM333 {
	
	*ar { |input, surround = 0.8, effect = 0.8, delay = 0.4, active = 1, 
		  saturation = 0.15, noise = 0.1, bandwidth = 0.5, bbdNoise = 0.1|
		
		var w, x, y, z;
		var processedW, processedX, processedY, processedZ;
		var thermalNoise, bbdNoiseSignal, actualDelayTime;
		var diffX, diffY, processedDiffX, processedDiffY;
		var lowBandX, midBandX, highBandX, lowBandY, midBandY, highBandY;
		var phaseDiffX, phaseDiffY;
		var surroundEnhanceX, surroundEnhanceY;
		
		// Extract B-format components
		w = input[0]; // W (omnidirectional)
		x = input[1]; // X (front-back)
		y = input[2]; // Y (left-right) 
		z = input[3]; // Z (up-down)
		
		// Add subtle thermal noise to all channels
		thermalNoise = WhiteNoise.ar(0.00001) * noise;
		w = w + thermalNoise;
		x = x + thermalNoise;
		y = y + thermalNoise;
		z = z + thermalNoise;
		
		// Bandwidth limiting (emulates op-amp frequency response)
		w = LPF.ar(w, 20000 * (1.0 - (bandwidth * 0.9)) + 2000);
		x = LPF.ar(x, 20000 * (1.0 - (bandwidth * 0.9)) + 2000);
		y = LPF.ar(y, 20000 * (1.0 - (bandwidth * 0.9)) + 2000);
		z = LPF.ar(z, 20000 * (1.0 - (bandwidth * 0.9)) + 2000);
		
		// Apply subtle op-amp saturation to all channels
		w = (w * (1.0 - saturation)) + (w.tanh * saturation);
		x = (x * (1.0 - saturation)) + (x.tanh * saturation);
		y = (y * (1.0 - saturation)) + (y.tanh * saturation);
		z = (z * (1.0 - saturation)) + (z.tanh * saturation);
		
		// Core Maplin processing: enhance spatial difference signals
		// The SM-333 primarily worked on L-R differences, which in B-format
		// corresponds to enhancing the directional components (X, Y)
		
		// Create enhanced directional signals through multi-stage processing
		diffX = x * 0.7071; // Scale for processing
		diffY = y * 0.7071;
		
		// Multi-stage all-pass filtering for phase shifts (emulates RC networks)
		phaseDiffX = diffX;
		phaseDiffX = AllpassN.ar(phaseDiffX, 0.01, 0.0015, 0.7); // ~1.5ms
		phaseDiffX = AllpassN.ar(phaseDiffX, 0.01, 0.0033, 0.7); // ~3.3ms
		phaseDiffX = AllpassN.ar(phaseDiffX, 0.01, 0.0072, 0.7); // ~7.2ms
		phaseDiffX = AllpassN.ar(phaseDiffX, 0.01, 0.0156, 0.7); // ~15.6ms
		
		phaseDiffY = diffY;
		phaseDiffY = AllpassN.ar(phaseDiffY, 0.01, 0.0018, 0.7); // Slightly different timing
		phaseDiffY = AllpassN.ar(phaseDiffY, 0.01, 0.0039, 0.7);
		phaseDiffY = AllpassN.ar(phaseDiffY, 0.01, 0.0084, 0.7);
		phaseDiffY = AllpassN.ar(phaseDiffY, 0.01, 0.0172, 0.7);
		
		// High-pass filter for spatial enhancement (circuit characteristic)
		phaseDiffX = HPF.ar(phaseDiffX, 80);
		phaseDiffY = HPF.ar(phaseDiffY, 80);
		
		// Frequency-dependent processing (different delays per band)
		// X-axis (front-back) processing
		lowBandX = LPF.ar(phaseDiffX, 800);
		midBandX = BPF.ar(phaseDiffX, 2000, 1.5);
		highBandX = HPF.ar(phaseDiffX, 4000);
		
		lowBandX = DelayC.ar(lowBandX, 0.1, 0.022); // 22ms
		midBandX = DelayC.ar(midBandX, 0.1, 0.018); // 18ms
		highBandX = DelayC.ar(highBandX, 0.1, 0.012); // 12ms
		
		// Y-axis (left-right) processing
		lowBandY = LPF.ar(phaseDiffY, 800);
		midBandY = BPF.ar(phaseDiffY, 2000, 1.5);
		highBandY = HPF.ar(phaseDiffY, 4000);
		
		lowBandY = DelayC.ar(lowBandY, 0.1, 0.024); // Slightly different delays
		midBandY = DelayC.ar(midBandY, 0.1, 0.020);
		highBandY = DelayC.ar(highBandY, 0.1, 0.014);
		
		// Recombine frequency bands with level matching
		processedDiffX = (lowBandX + midBandX + highBandX) * 0.6;
		processedDiffY = (lowBandY + midBandY + highBandY) * 0.6;
		
		// BBD (Bucket Brigade Device) delay emulation
		actualDelayTime = delay.linlin(0, 1, 0.005, 0.050); // 5-50ms range
		bbdNoiseSignal = WhiteNoise.ar(0.0003) * bbdNoise;
		
		// BBD frequency response and noise for enhanced signals
		processedDiffX = LPF.ar(processedDiffX + bbdNoiseSignal, 8000); // BBD bandwidth limit
		processedDiffY = LPF.ar(processedDiffY + bbdNoiseSignal, 8000);
		
		// Variable delay with slight modulation (BBD clock variations)
		processedDiffX = DelayC.ar(processedDiffX, 0.1, 
			actualDelayTime + LFNoise2.kr(0.5, 0.0002));
		processedDiffY = DelayC.ar(processedDiffY, 0.1, 
			actualDelayTime + LFNoise2.kr(0.3, 0.0002));
		
		// Create surround enhancement by modifying the directional components
		surroundEnhanceX = processedDiffX * effect * 1.4; // 1.4x scaling for effect level
		surroundEnhanceY = processedDiffY * effect * 1.4;
		
		// Apply surround level and blend with original
		// Keep original spatial components and ADD enhancement
		processedX = x + (surroundEnhanceX * surround);
		processedY = y + (surroundEnhanceY * surround);
		
		// W component gets subtle enhancement from the spatial processing
		processedW = w + ((surroundEnhanceX + surroundEnhanceY) * 0.05 * surround);
		
		// Z component (height) gets minimal processing
		processedZ = z + (processedDiffY * 0.1 * effect); // Slight Y->Z coupling
		
		// Final subtle saturation on all processed channels
		processedW = (processedW * 0.9) + (processedW.tanh * 0.1);
		processedX = (processedX * 0.9) + (processedX.tanh * 0.1);
		processedY = (processedY * 0.9) + (processedY.tanh * 0.1);
		processedZ = (processedZ * 0.9) + (processedZ.tanh * 0.1);
		
		// Bypass/Active control - blend between original and processed
		processedW = (w * (1 - active)) + (processedW * active);
		processedX = (x * (1 - active)) + (processedX * active);
		processedY = (y * (1 - active)) + (processedY * active);
		processedZ = (z * (1 - active)) + (processedZ * active);
		
		// Safety limiting and output
		[processedW, processedX, processedY, processedZ].collect(_.clip2(0.95));
	}
	
	// Convenience method with preset configurations
	*balanced { |input|
		^this.ar(input, 
			surround: 0.8, 
			effect: 0.8, 
			delay: 0.4, 
			active: 1,
			saturation: 0.15,
			noise: 0.1,
			bandwidth: 0.5,
			bbdNoise: 0.1
		);
	}
	
	*maximum { |input|
		^this.ar(input, 
			surround: 1.0, 
			effect: 1.0, 
			delay: 0.6, 
			active: 1,
			saturation: 0.1,
			noise: 0.05,
			bandwidth: 0.4,
			bbdNoise: 0.05
		);
	}
	
	*subtle { |input|
		^this.ar(input, 
			surround: 0.4, 
			effect: 0.6, 
			delay: 0.2, 
			active: 1,
			saturation: 0.08,
			noise: 0.15,
			bandwidth: 0.7,
			bbdNoise: 0.15
		);
	}
}