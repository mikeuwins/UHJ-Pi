// Simple test for WAV file writing to /tmp
(
var signal = FloatArray.fill(44100, { |i| sin(2 * pi * 440 * i / 44100) * 0.5 });
var soundFile = SoundFile.new;

soundFile.headerFormat = "WAV";
soundFile.sampleFormat = "int16";
soundFile.numChannels = 1;
soundFile.sampleRate = 44100;

"Attempting to write to /tmp/test.wav...".postln;

if(soundFile.openWrite("/tmp/test.wav")) {
    "File opened successfully".postln;
    soundFile.writeData(signal);
    soundFile.close;
    "File written and closed".postln;
} {
    "Failed to open file".postln;
};

"Test complete".postln;
) 