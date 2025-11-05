/*
FoaDecoderMatrix Extension for 5.1.2 Decoder

Adds *new5_2 class method to FoaDecoderMatrix for 5.1.2 speaker layout:
- Lower ring: FL, FR, C, RL, RR (5 channels, horizontal decode)
- Heights: TFL, TFR (2 channels, periphonic decode)
- LFE: derived from FL+FR (not part of decoder matrix)

Based on JSFX plugin "5.1.2 Matrix Decode" implementation.
*/

// Extension to FoaDecoderMatrix to add *new5_2 class method
// Usage: FoaDecoderMatrix.new5_2(mode, heightElevation, outputLayout)
FoaDecoderMatrix {
    *new5_2 { |mode = \equal, heightElevation = 45, outputLayout = \uhjpi|
        var lowerRingMatrix, heightMatrix, fullMatrix, dirs;
        var filePath, file, lines, rows, m;
        var modeNames = [\equal, \focus, \four];
        var modeFileNames = ["equal.txt", "focused.txt", "four.txt"];
        var modeIndex = modeNames.indexOf(mode) ? 0;
        
        // Load lower ring matrix (5x4) from file or use hardcoded fallback
        filePath = Platform.userHomeDir +/+ ".local/share/ATK/matrices/FOA/decoders/5_1_2/" ++ modeFileNames[modeIndex];
        file = File(filePath, "r");
        
        if(file.isOpen, {
            lines = file.readAllString.split(Char.nl).select({ |line| line.stripWhiteSpace.size > 0 });
            file.close;
            
            if(lines.size >= 5, {
                rows = lines[0..4].collect({ |line|
                    var vals = line.split($ ).select({ |s| s.size > 0 });
                    vals.collect(_.asFloat)
                });
                rows = rows.collect({ |row|
                    if(row.size < 4, { row = row ++ Array.fill(4 - row.size, 0) });
                    row
                });
                lowerRingMatrix = Matrix.with(rows);
            });
        });
        
        // Fallback to hardcoded matrices (Ambisonic order: C, FL, RL, RR, FR)
        if(lowerRingMatrix.isNil, {
            switch(mode,
                \equal, {
                    lowerRingMatrix = Matrix.with([
                        [0.0,    0.085,  0.0,    0.0],
                        [0.365,  0.435,  0.34,   0.0],
                        [0.555, -0.285,  0.405,  0.0],
                        [0.555, -0.285, -0.405,  0.0],
                        [0.365,  0.435, -0.34,   0.0]
                    ]);
                },
                \focus, {
                    lowerRingMatrix = Matrix.with([
                        [0.2,    0.16,   0.0,    0.0],
                        [0.425,  0.36,   0.405,  0.0],
                        [0.47,  -0.33,   0.415,  0.0],
                        [0.47,  -0.33,  -0.415,  0.0],
                        [0.425,  0.36,  -0.405,  0.0]
                    ]);
                },
                \four, {
                    lowerRingMatrix = Matrix.with([
                        [0.0,    0.0,    0.0,    0.0],
                        [0.425,  0.385,  0.33,   0.0],
                        [0.63,  -0.275,  0.285,  0.0],
                        [0.63,  -0.275, -0.285,  0.0],
                        [0.425,  0.385, -0.33,   0.0]
                    ]);
                },
                {
                    "FoaDecoderMatrix.new5_2: invalid mode, using 'equal'".warn;
                    lowerRingMatrix = Matrix.with([
                        [0.0,    0.085,  0.0,    0.0],
                        [0.365,  0.435,  0.34,   0.0],
                        [0.555, -0.285,  0.405,  0.0],
                        [0.555, -0.285, -0.405,  0.0],
                        [0.365,  0.435, -0.34,   0.0]
                    ]);
                }
            );
        });
        
        // Calculate height matrix (2x4) - elevation-dependent
        var el = heightElevation.degrad;
        var g1 = 2.sqrt; // √2
        var y_coef = 0.34; // Constant Y coefficient
        var z_coef = g1 * el.sin; // Z coefficient scales with elevation
        
        // Try to load height matrix from file
        filePath = Platform.userHomeDir +/+ ".local/share/ATK/matrices/FOA/decoders/5_1_2/heights_topfront.txt";
        file = File(filePath, "r");
        
        if(file.isOpen, {
            lines = file.readAllString.split(Char.nl).select({ |line| line.stripWhiteSpace.size > 0 });
            file.close;
            
            if(lines.size >= 2, {
                rows = lines[0..1].collect({ |line|
                    var vals = line.split($ ).select({ |s| s.size > 0 });
                    vals.collect(_.asFloat)
                });
                rows = rows.collect({ |row|
                    if(row.size < 4, { row = row ++ Array.fill(4 - row.size, 0) });
                    row
                });
                // Override Z coefficient with elevation-dependent value
                rows[0][3] = z_coef;
                rows[1][3] = z_coef;
                heightMatrix = Matrix.with(rows);
            });
        });
        
        // Fallback to calculated height matrix
        if(heightMatrix.isNil, {
            heightMatrix = Matrix.with([
                [0.408248, 0.0, y_coef.neg, z_coef],  // TFL
                [0.408248, 0.0, y_coef, z_coef]      // TFR
            ]);
        });
        
        // Combine matrices (7x4): [C, FL, RL, RR, FR, TFL, TFR]
        fullMatrix = lowerRingMatrix ++ heightMatrix;
        
        // Reorder for ATK: [C, FL, RL, RR, FR, TFR, TFL]
        var reorderedMatrix = [
            fullMatrix.getRow(0).asArray,  // C
            fullMatrix.getRow(1).asArray,  // FL
            fullMatrix.getRow(2).asArray,  // RL
            fullMatrix.getRow(3).asArray,  // RR
            fullMatrix.getRow(4).asArray,  // FR
            fullMatrix.getRow(6).asArray,  // TFR
            fullMatrix.getRow(5).asArray   // TFL
        ];
        
        // Directions matching matrix order [C, FL, RL, RR, FR, TFR, TFL]
        dirs = [
            [0, 0],              // C: 0° (front)
            [(30).degrad, 0],    // FL: 30° anticlockwise (left)
            [(110).degrad, 0],   // RL: 110° anticlockwise (rear-left)
            [(-110).degrad, 0],  // RR: -110° (or 250°) clockwise (rear-right)
            [(-30).degrad, 0],   // FR: -30° (or 330°) clockwise (right)
            [(-30).degrad, heightElevation.degrad],  // TFR: -30° clockwise, elevated
            [(30).degrad, heightElevation.degrad]   // TFL: 30° anticlockwise, elevated
        ];
        
        ^FoaDecoderMatrix.newFromMatrix(Matrix.with(reorderedMatrix), dirs);
    }
}
