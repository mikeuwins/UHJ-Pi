// Test script to find available EQ classes
(
"Testing available EQ classes...".postln;

// Try different possible class names
[
    "DDWEQ", "DDWEqualizer", "MultiEQGUI", "DDWGUI", 
    "EQ", "Equalizer", "GraphicEQ", "ParaEQ"
].do({ |className|
    try {
        var class = className.asClass;
        if(class.notNil) {
            ("Found class: " ++ className).postln;
            // Try to see what methods it has
            class.class.methods.do({ |method|
                if(method.name.asString.contains("new")) {
                    ("  - " ++ method.name).postln;
                };
            });
        };
    } { |error|
        ("Class not found: " ++ className).postln;
    };
});

// Also check if ddwEQ quark classes are available
"Checking for ddwEQ quark classes...".postln;
Class.allClasses.select({ |class|
    class.name.asString.toLower.contains("eq") || 
    class.name.asString.toLower.contains("ddw")
}).do({ |class|
    ("Available EQ-related class: " ++ class.name).postln;
});
)
