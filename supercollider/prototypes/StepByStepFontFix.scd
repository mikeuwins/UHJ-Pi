// STEP-BY-STEP FONT FIX
// Do these steps one at a time in the SuperCollider IDE

// STEP 1: Recompile class library (run this first and wait for completion)
(
"Recompiling class library...".postln;
thisProcess.recompile;
)

// STEP 2: After recompilation is done, run this to test fonts
// (Wait for "compiling class library" message to finish, then run this)
/*
(
s.waitForBoot({
    var w = Window("Quick Font Test", Rect(300, 300, 400, 200));
    w.view.background = Color.black;
    
    // Test main GUI font
    StaticText(w, Rect(20, 20, 100, 20))
    .string_("Main GUI: 1 2 3")
    .font_(Font("Helvetica", 9))
    .stringColor_(Color.cyan);
    
    // Test ServerMeter2View
    if(s.serverRunning, {
        ServerMeter2View(s, w, 20@50, 3, 0);
        StaticText(w, Rect(20, 150, 300, 20))
        .string_("Do the numbers above look the same?")
        .font_(Font("Helvetica", 10))
        .stringColor_(Color.white);
    });
    
    w.front;
});
)
*/

// STEP 3: If fonts still don't match, there may be a deeper SuperCollider font issue
// Try this alternative approach:
/*
(
"Checking font alternatives...".postln;
Font.availableFonts.select({ |name| 
    name.toLower.contains("sans") || name.toLower.contains("mono")
}).do(_.postln);
)
*/
