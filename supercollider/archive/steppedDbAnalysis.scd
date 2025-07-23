// Analysis of Enhanced Stepped dB Mapping Resolution
(
// Test the enhanced stepped mapping
var dbSteps = [
    -40, -35, -30, -25, -20, -18, -15, -12, 
    -10, -9.5, -9, -8.5, -8, -7.5, -7, -6.5, -6, -5.5, -5, -4.5, -4, -3.5, -3, -2.5, -2, -1.5, -1, -0.5, 
    0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12
];

var cliToDbSteppedTest = { |cliValue|
    var stepIndex = cliValue.linlin(60, 127, 0, dbSteps.size - 1).round.clip(0, dbSteps.size - 1);
    dbSteps[stepIndex];
};

"=== ENHANCED STEPPED dB MAPPING ANALYSIS ===".postln;
"Total steps in array: %".format(dbSteps.size).postln;
"CLI range: 60-127 (% steps)".format(127-60+1).postln;
"Resolution: % CLI steps per dB value".format((127-60+1) / dbSteps.size).postln;
"".postln;

"Sample mapping (every 5th CLI value):".postln;
(60..127).do({ |cli|
    if (cli % 5 == 0) {
        var db = cliToDbSteppedTest.value(cli);
        "CLI % -> %dB".format(cli, db).postln;
    };
});

"".postln;
"Key values availability:".postln;
var keyValues = [-10, -6, -3, 0, 0.5, 3, 4, 4.5, 5, 5.5, 6];
keyValues.do({ |target|
    var found = false;
    var foundCli = nil;
    
    (60..127).do({ |cli|
        if (cliToDbSteppedTest.value(cli) == target) {
            found = true;
            foundCli = cli;
        };
    });
    
    "%dB: % (CLI %)".format(target, if(found, "✓", "✗"), foundCli ? "N/A").postln;
});

"".postln;
"0.5dB increment availability in critical range (-6 to +6dB):".postln;
(-6.0, -5.5 .. 6.0).do({ |target|
    var found = false;
    var foundCli = nil;
    
    (60..127).do({ |cli|
        if (cliToDbSteppedTest.value(cli) == target) {
            found = true;
            foundCli = cli;
        };
    });
    
    if (found) {
        "%dB: ✓ (CLI %)".format(target, foundCli).postln;
    };
});
)
