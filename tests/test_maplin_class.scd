// Test if MaplinSM333 class is loaded
"Testing MaplinSM333 class loading...".postln;

if(MaplinSM333.notNil) {
    "✓ MaplinSM333 class is loaded".postln;
    
    // Test the class method
    try {
        var testInput = [SinOsc.ar(440), SinOsc.ar(440), SinOsc.ar(440), SinOsc.ar(440)];
        var result = MaplinSM333.ar(testInput);
        "✓ MaplinSM333.ar method works".postln;
    } { |error|
        "✗ MaplinSM333.ar method failed: ".post; error.postln;
    };
} {
    "✗ MaplinSM333 class is NOT loaded".postln;
    "Available classes containing 'Maplin': ".post;
    Class.allClasses.select({ |c| c.name.asString.contains("Maplin") }).do({ |c| c.name.post; " ".post; });
    "".postln;
}; 