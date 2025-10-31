// FoaVHAP.sc - B-Format Virtual Hemispherical Amplitude Panning Transform
// SuperCollider extension for ATK FOA VHAP processing
// Based on B-VHAP theory and implementation

FoaVHAP {
	
	// Initialize kernels - call this before using FoaVHAP.ar
	*initKernels { |partitionSize = 512, server|
		var kernelPath;
		server = server ?? Server.default;
		
		// Build kernel path based on server sample rate and partition size
		kernelPath = "/home/michael-uwins/UHJ-Pi/reaper/kernels/FOA/transforms/b-vhap/%/%/0100/BVHAP_Z.wav".format(
			server.sampleRate.asInteger,
			partitionSize
		);
		
		"FoaVHAP: Loading kernel %".format(kernelPath).postln;
		
		// Load kernel buffer (4-channel interleaved: Zw, Zx, Zy, ZΔ)
		~vhapKernelBuffer = Buffer.read(server, 
			kernelPath,
			action: { |buf|
				if(buf.notNil, {
					"FoaVHAP: Loaded kernel (% frames, % channels)".format(
						buf.numFrames, buf.numChannels
					).postln;
					
					// Prepare PartConv buffer
					{
						var bufSize = PartConv.calcBufSize(partitionSize, buf);
						~vhapPartConvBuffer = Buffer.alloc(server, bufSize, buf.numChannels);
						~vhapPartConvBuffer.preparePartConv(buf, partitionSize);
						~vhapPartitionSize = partitionSize;
						"FoaVHAP: Kernels ready for processing".postln;
					}.value;
				}, {
					"FoaVHAP: Failed to load kernel %".format(kernelPath).warn;
				});
			}
		);
	}
	
	*ar { |input, trim = 0, morph = 1, solo = 0, partitionSize = 512|
		var w, x, y, z;
		var zw, zx, zy, zd, zPrime, zDelta, zOut;
		var trimLinear, output;
		var normalOutput, soloOutput;
		
		// Extract B-format components
		w = input[0]; // W (omnidirectional)
		x = input[1]; // X (front-back)
		y = input[2]; // Y (left-right) 
		z = input[3]; // Z (up-down)
		
		// Convert trim from dB to linear
		trimLinear = trim.dbamp;
		
		// Check if kernels are loaded and partition size matches
		if((~vhapPartConvBuffer.isNil) or: { ~vhapPartitionSize != partitionSize }, {
			"FoaVHAP: Kernels not loaded or partition size mismatch. Call FoaVHAP.initKernels(%) first".format(partitionSize).warn;
			// Return input unchanged as fallback
			^input;
		});
		
		// Perform 4-lane convolution using ATK multi-channel approach
		if(~vhapPartConvBuffer.notNil, {
			// Convolve each B-format input with its corresponding kernel lane
			// BVHAP_Z.wav contains 4 interleaved channels: [Zw, Zx, Zy, ZΔ]
			// Use PartConv with channel indexing to access each lane
			zw = PartConv.ar(w, partitionSize, ~vhapPartConvBuffer.bufnum, 0); // Lane 0: Zw
			zx = PartConv.ar(x, partitionSize, ~vhapPartConvBuffer.bufnum, 1); // Lane 1: Zx  
			zy = PartConv.ar(y, partitionSize, ~vhapPartConvBuffer.bufnum, 2); // Lane 2: Zy
			zd = PartConv.ar(z, partitionSize, ~vhapPartConvBuffer.bufnum, 3); // Lane 3: ZΔ
			
			// Sum all convolution outputs to synthesize Z'
			// Apply normalization factor (BV_G) - this should be calculated from kernel energy
			// For now, using a fixed normalization factor
			zPrime = (zw + zx + zy + zd) * 2.0; // Approximate BV_G normalization
			
			// Apply trim
			zPrime = zPrime * trimLinear;
			
			// Apply morph formula: Z_out = Z + morph * (Z' - Z)
			zDelta = zPrime - z;
			zOut = z + (morph * zDelta);
		}, {
			// Fallback if kernel not loaded
			zOut = z;
			zPrime = 0;
		});
		
		// Solo mode: use ATK pattern - Select between two complete arrays
		normalOutput = [w, x, y, zOut];  // Normal mode: W/X/Y passthrough, processed Z
		soloOutput = [zPrime * 0.707107, 0, 0, zPrime * 0.707107];  // Solo mode: Z' to W and Z
		
		output = Select.ar(solo, [normalOutput, soloOutput]);
		
		^output;
	}
	
	// Convenience method with balanced preset
	*balanced { |input, trim = 0, morph = 0.8|
		^this.ar(input, trim, morph, 0);
	}
	
	// Method to clean up global buffers
	*cleanup {
		if(~vhapKernelBuffer.notNil, {
			~vhapKernelBuffer.free;
			~vhapKernelBuffer = nil;
		});
		if(~vhapPartConvBuffer.notNil, {
			~vhapPartConvBuffer.free;
			~vhapPartConvBuffer = nil;
		});
		"FoaVHAP: Cleaned up kernel buffers".postln;
	}
}
