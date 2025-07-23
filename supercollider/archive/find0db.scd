// Realistic test - what can we actually achieve?
(
var cliToDb = { |cliValue|
    var dbValue;
    dbValue = cliValue.linlin(60, 127, -40, 12);
    dbValue.round(1);  // 1dB resolution
};

"=== REALISTIC dB MAPPING ===".postln;
"Hardware resolution: 68 CLI steps for 52dB range = 0.76dB per step".postln;
"Rounding to 1dB (achievable resolution)".postln;
"".postln;

"Finding CLI value for 0dB:".postln;
(60..127).do({ |cli|
    var db = cliToDb.value(cli);
    if (db == 0) {
        "✓ CLI % gives 0dB".format(cli).postln;
    };
});

"".postln;
"Sample mapping:".postln;
(60..127).do({ |cli|
    if (cli % 5 == 0) {
        var db = cliToDb.value(cli);
        "CLI % -> %dB".format(cli, db).postln;
    };
});

"".postln;
"Key values available:".postln;
[-10, -6, -3, 0, 3, 6, 10, 12].do({ |target|
    var found = false;
    (60..127).do({ |cli|
        if (cliToDb.value(cli) == target) {
            found = true;
        };
    });
    "%dB: %".format(target, if(found, "✓", "✗")).postln;
});
)
