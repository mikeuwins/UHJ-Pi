// Print the 5.1.2 diametric decoder matrix to file
(
var file, matrix, i, j, decoder;

Routine.run({
    file = File("/tmp/matrix_512.txt", "w");
    file.write("5.1.2 Diametric Decoder Matrix (8x4):\n\n");

    decoder = FoaDecoderMatrix.newDiametric([
        [0, 0],      // Center
        [-30, 0],    // Front Left  
        [30, 0],     // Front Right
        [-30, 45]    // Top Front Left
    ].collect { |pos| [pos[0].degrad, pos[1].degrad] });

    matrix = decoder.matrix;

    8.do({ |i|
        file.write(format("Speaker %:  ", i));
        4.do({ |j|
            file.write(format("% ", matrix[i, j].round(0.0001)));
        });
        file.write("\n");
    });

    file.write("\nSpeaker mapping (from dirChannels):\n");
    decoder.dirChannels.do({ |dir, i|
        file.write(format("%: [%, %] degrees\n", i, dir[0].raddeg.round(1), dir[1].raddeg.round(1)));
    });

    file.close;
    "/tmp/matrix_512.txt created".postln;
});
)

