/*
Foa512Matrix - 5.1.2 Matrix Decoder for First-Order Ambisonics

Converts FOA B-format (W, X, Y, Z) to 5.1.2 speaker layout:
- Lower ring: FL, FR, C, RL, RR (5 channels, horizontal decode)
- Heights: TFL, TFR (2 channels, periphonic decode)
- LFE: derived from FL+FR

Based on JSFX plugin "5.1.2 Matrix Decode" implementation.
*/

Foa512Matrix {
	classvar <>lowerRingModes;
	
	var mode, heightElevation, outputLayout;
	var <lowerRingMatrix, <heightMatrix;
	var <numOutputs = 8;
	
	*initClass {
		lowerRingModes = #[\equal, \focus, \four];
	}
	
	*new { |mode = \equal, heightElevation = 45, outputLayout = \uhjpi|
		^super.newCopyArgs(mode, heightElevation, outputLayout).init;
	}
	
	init {
		this.updateMatrices;
	}
	
	updateMatrices {
		lowerRingMatrix = this.prGetLowerRingMatrix(mode);
		heightMatrix = this.prGetHeightMatrix(heightElevation);
	}
	
	prGetLowerRingMatrix { |mode|
		var m;
		
		switch(mode,
			\equal, {
				// FL, FR, C, RL, RR
				m = Matrix.with([
					[0.365,  0.435,  0.34,   0.0],  // FL
					[0.365,  0.435, -0.34,   0.0],  // FR
					[0.0,    0.085,  0.0,    0.0],  // C
					[0.555, -0.285,  0.405,  0.0],  // RL
					[0.555, -0.285, -0.405,  0.0]   // RR
				]);
			},
			\focus, {
				m = Matrix.with([
					[0.425,  0.36,   0.405,  0.0],  // FL
					[0.425,  0.36,  -0.405,  0.0],  // FR
					[0.2,    0.16,   0.0,    0.0],  // C
					[0.47,  -0.33,   0.415,  0.0],  // RL
					[0.47,  -0.33,  -0.415,  0.0]   // RR
				]);
			},
			\four, {
				m = Matrix.with([
					[0.425,  0.385,  0.33,   0.0],   // FL
					[0.425,  0.385, -0.33,   0.0],   // FR
					[0.0,    0.0,    0.0,    0.0],   // C (zero)
					[0.63,  -0.275,  0.285,  0.0],   // RL
					[0.63,  -0.275, -0.285,  0.0]    // RR
				]);
			},
			{
				"Foa512Matrix: invalid mode, using 'equal'".warn;
				m = this.prGetLowerRingMatrix(\equal);
			}
		);
		
		^m;
	}
	
	prGetHeightMatrix { |elevationDeg|
		var el, g1, y_coef, z_coef;
		var m;
		
		// Elevation in radians
		el = elevationDeg.degrad;
		// First-order gain
		g1 = 2.sqrt; // √2 ≈ 1.414
		// Y coefficient: constant at 0.34 (matches front speakers at 30° elevation)
		y_coef = 0.34;
		// Z coefficient: scales with elevation
		z_coef = g1 * el.sin;
		// W component: fixed ambient component
		// X = 0.0 (removed for more ambient sound)
		
		// TFL, TFR
		m = Matrix.with([
			[0.408248, 0.0, y_coef.neg, z_coef],  // TFL
			[0.408248, 0.0, y_coef, z_coef]      // TFR
		]);
		
		^m;
	}
	
	// Get full 7x4 matrix (5 lower + 2 height, no LFE)
	matrix {
		^(lowerRingMatrix ++ heightMatrix);
	}
	
	// Getter methods
	mode { ^mode }
	heightElevation { ^heightElevation }
	outputLayout { ^outputLayout }
	
	// Set elevation and recalculate height matrix
	elevation_ { |deg|
		heightElevation = deg;
		this.updateMatrices;
	}
	
	outputLayout_ { |layout|
		outputLayout = layout;
	}
	
	// Set mode and recalculate lower ring matrix
	mode_ { |m|
		if(lowerRingModes.includes(m).not, {
			"Foa512Matrix: invalid mode, using 'equal'".warn;
			m = \equal;
		});
		mode = m;
		this.updateMatrices;
	}
	
	// Get output channel mapping based on layout
	// Returns array of indices mapping decoder outputs to physical outputs
	outputMapping {
		switch(outputLayout,
			\uhjpi, {
				// UHJ-Pi: FL, FR, C, RL, RR, LFE, TFL, TFR
				^[0, 1, 2, 3, 4, 5, 6, 7]; // decoder: [FL,FR,C,RL,RR,TFL,TFR], LFE=5, TFL=6, TFR=7
			},
			\dolby, {
				// Dolby: FL, FR, C, LFE, RL, RR, TFL, TFR
				^[0, 1, 2, 5, 3, 4, 6, 7]; // decoder: [FL,FR,C,RL,RR,TFL,TFR], LFE=3, RL=4, RR=5
			},
			{
				"Foa512Matrix: invalid outputLayout, using 'uhjpi'".warn;
				^[0, 1, 2, 3, 4, 5, 6, 7];
			}
		);
	}
	
	// Decode B-format input (W,X,Y,Z) to 7 channels (FL,FR,C,RL,RR,TFL,TFR)
	// Note: LFE is derived separately, not from matrix
	decode { |w, x, y, z|
		var m = this.matrix;
		var out = Array.newClear(7);
		
		7.do({ |i|
			out[i] = (w * m[i][0]) + (x * m[i][1]) + (y * m[i][2]) + (z * m[i][3]);
		});
		
		^out;
	}
	
    printOn { |stream|
		stream << this.class.name << "(" 
			<< "mode: " << mode << ", "
			<< "elevation: " << heightElevation << "°, "
			<< "layout: " << outputLayout
			<< ")";
	}
    
    // ATK-style: Provide a helper to obtain a FoaDecoderMatrix from this matrix
    *newFoaDecoder { |mode = \equal, heightElevation = 45, outputLayout = \uhjpi|
        var inst = Foa512Matrix.new(mode, heightElevation, outputLayout);
        var m = inst.matrix; // 7x4 matrix: [FL, FR, C, RL, RR, TFL, TFR]
        var dirs;
        // Reorder matrix and directions to match ATK 5.0 decoder order: [C, FL, RL, RR, FR]
        // Matrix rows need to be reordered to match directions
        // Use getRow() to extract rows as Arrays
        var reorderedMatrix = [
            m.getRow(2).asArray,  // C (was row 2)
            m.getRow(0).asArray,  // FL (was row 0)
            m.getRow(3).asArray,  // RL (was row 3)
            m.getRow(4).asArray,  // RR (was row 4)
            m.getRow(1).asArray,  // FR (was row 1)
            m.getRow(6).asArray,  // TFR (row 6) - correct order for UHJ-Pi
            m.getRow(5).asArray   // TFL (row 5) - correct order for UHJ-Pi
        ];
        // Directions: must match matrix row order [C, FL, RL, RR, FR, TFR, TFL] (correct for UHJ-Pi layout)
        // Ambisonic convention: angles measured anticlockwise from 0° (front)
        // 0° = front, positive = anticlockwise (left), negative = clockwise (right)
        dirs = [
            [0, 0],              // C: 0° (front)
            [(30).degrad, 0],    // FL: 30° anticlockwise (left)
            [(110).degrad, 0],   // RL: 110° anticlockwise (rear-left)
            [(-110).degrad, 0],  // RR: -110° (or 250°) clockwise (rear-right)
            [(-30).degrad, 0],   // FR: -30° (or 330°) clockwise (right)
            [(-30).degrad, heightElevation.degrad],  // TFR: -30° clockwise, elevated (correct for UHJ-Pi)
            [(30).degrad, heightElevation.degrad]   // TFL: 30° anticlockwise, elevated (correct for UHJ-Pi)
        ];
        ^FoaDecoderMatrix.newFromMatrix(Matrix.with(reorderedMatrix), dirs);
    }
}

