// dB Mapping Test Script
// Run this to compare the different dB mapping strategies

// Test both mapping strategies
(
// Test linear mapping with smart rounding
var cliToDbLinear = { |cliValue|
    var dbValue, roundedValue;
    dbValue = cliValue.linlin(60, 127, -40, 12);
    roundedValue = dbValue.round(0.1);
    
    var niceValues = [-40, -30, -20, -15, -10, -6, -3, 0, 3, 6, 9, 12];
    var closestNice = niceValues.minItem({ |nice| (roundedValue - nice).abs });
    
    if ((roundedValue - closestNice).abs <= 0.3) {
        closestNice;
    } {
        roundedValue.round(0.5);
    };
};

// Test stepped mapping
var cliToDbStepped = { |cliValue|
    var dbSteps = [-40, -35, -30, -25, -20, -18, -15, -12, -10, -9, -8, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    var stepIndex = cliValue.linlin(60, 127, 0, dbSteps.size - 1).round.clip(0, dbSteps.size - 1);
    dbSteps[stepIndex];
};

"=== dB MAPPING COMPARISON ===".postln;
"CLI -> Linear -> Stepped".postln;
"".postln;

(60..127).do({ |cli|
    var linear = cliToDbLinear.value(cli);
    var stepped = cliToDbStepped.value(cli);
    
    if (cli % 3 == 0) {  // Show every 3rd value for readability
        "% -> %dB -> %dB".format(cli, linear, stepped).postln;
    };
});

"".postln;
"=== KEY VALUES AVAILABILITY ===".postln;
var keyValues = [0, -10, -6, -3, 3, 6, 4, 5];
keyValues.do({ |target|
    var foundLinear = false;
    var foundStepped = false;
    var linearCli = nil;
    var steppedCli = nil;
    
    (60..127).do({ |cli|
        if (cliToDbLinear.value(cli) == target) {
            foundLinear = true;
            linearCli = cli;
        };
        if (cliToDbStepped.value(cli) == target) {
            foundStepped = true;
            steppedCli = cli;
        };
    });
    
    "%dB: Linear=% (CLI %), Stepped=% (CLI %)".format(
        target, 
        foundLinear, linearCli ? "N/A",
        foundStepped, steppedCli ? "N/A"
    ).postln;
});
)
