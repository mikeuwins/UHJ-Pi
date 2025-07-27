// MaplinMatrix Live Test Script
// Simple stereo input to quad output test with GUI
// Speaker order: LF-1, RF-2, LR-3, RR-4

(
// Server configuration
s.options.numInputBusChannels = 2;   // Stereo input
s.options.numOutputBusChannels = 4;  // Quad output
s.options.memSize = 65536;

// Set your audio device here if needed
// s.options.device_("hw:HD");  // Uncomment and modify for your interface

s.reboot;

s.waitForBoot({
    
    "=== MaplinMatrix Live Test ===".postln;
    "Server configured: 2 inputs, 4 outputs".postln;
    "Speaker mapping: 1=LF, 2=RF, 3=LR, 4=RR".postln;
    "".postln;
    
    // Wait for server to fully stabilize
    AppClock.sched(1.0, {
        
        "Creating MaplinMatrix synth for testing...".postln;
        
        // Create the processing synth
        ~maplinSynth = {
            var input, output;
            
            // Get stereo input
            input = SoundIn.ar([0, 1]);
            
            // Apply MaplinMatrix processing
            output = MaplinMatrix.ar(
                leftIn: input[0],
                rightIn: input[1],
                surroundLevel: \surroundLevel.kr(0.8),
                effectLevel: \effectLevel.kr(0.8),
                delayTime: \delayTime.kr(0.4),
                active: \active.kr(1)
            );
            
            // Send meter data to GUI
            SendReply.kr(Impulse.kr(30), '/inputMeter', [
                Amplitude.kr(input[0]), 
                Amplitude.kr(input[1])
            ]);
            SendReply.kr(Impulse.kr(30), '/outputMeter', [
                Amplitude.kr(output[0]), 
                Amplitude.kr(output[1]), 
                Amplitude.kr(output[2]), 
                Amplitude.kr(output[3])
            ]);
            
            // Output to speakers: LF, RF, LR, RR
            Out.ar(0, output);
            
        }.play;
        
        "✓ MaplinMatrix synth created!".postln;
        
        // Set audio card volume
        ("amixer -c HD set PCM 80%").unixCmd;
        "✓ Audio card volume set to 80%".postln;
        
        // Wait a moment then open GUI
        AppClock.sched(1.0, {
            "Opening MaplinMatrix control GUI...".postln;
            
            try {
                ~maplinGUI = MaplinMatrix.gui(~maplinSynth);
                "✓ GUI opened successfully!".postln;
                "".postln;
                "=== READY FOR TESTING ===".postln;
                "• Watch the input/output meters".postln;
                "• Adjust SURROUND knob to control rear channels".postln;
                "• Adjust EFFECT knob to control matrix intensity".postln;
                "• Adjust DELAY knob for BBD characteristics".postln;
                "• Use ACTIVE/BYPASS button to compare with/without effect".postln;
                "• Use BALANCED/MAXIMUM preset buttons".postln;
                "".postln;
                "To stop: ~stop.();".postln;
                "".postln;
            } { |error|
                "GUI failed to open:".postln;
                error.postln;
                "You can try manually: MaplinMatrix.gui(~maplinSynth);".postln;
            };
            
            nil;
        });
        
        nil;
    });
});

// === CONTROL FUNCTIONS ===

~balanced = {
    if(~maplinSynth.notNil) {
        ~maplinSynth.set(\surroundLevel, 0.8, \effectLevel, 0.8, \delayTime, 0.4);
        "✓ Balanced preset applied (80% surround)".postln;
    } {
        "Error: MaplinMatrix synth not running. Run the main script first.".postln;
    };
};

~maximum = {
    if(~maplinSynth.notNil) {
        ~maplinSynth.set(\surroundLevel, 1.0, \effectLevel, 1.0, \delayTime, 1.0);
        "✓ Maximum preset applied (100% surround)".postln;
    } {
        "Error: MaplinMatrix synth not running. Run the main script first.".postln;
    };
};

~bypass = {
    if(~maplinSynth.notNil) {
        ~maplinSynth.set(\active, 0);
        "✓ Matrix processing BYPASSED - stereo only".postln;
    } {
        "Error: MaplinMatrix synth not running. Run the main script first.".postln;
    };
};

~activate = {
    if(~maplinSynth.notNil) {
        ~maplinSynth.set(\active, 1);
        "✓ Matrix processing ACTIVATED".postln;
    } {
        "Error: MaplinMatrix synth not running. Run the main script first.".postln;
    };
};

~stop = {
    if(~maplinSynth.notNil) {
        ~maplinSynth.free;
        ~maplinSynth = nil;
        "✓ MaplinMatrix synth stopped".postln;
    };
    if(~maplinGUI.notNil) {
        ~maplinGUI.close;
        ~maplinGUI = nil;
        "✓ MaplinMatrix GUI closed".postln;
    };
};

// === HELP ===
~help = {
    "".postln;
    "=== MaplinMatrix GUI Test Help ===".postln;
    "".postln;
    "GUI CONTROLS:".postln;
    "• SURROUND knob - controls rear channel level (0-100%)".postln;
    "• EFFECT knob - controls matrix processing intensity".postln;
    "• DELAY knob - controls BBD delay time (5-50ms)".postln;
    "• ACTIVE/BYPASS button - enables/disables processing".postln;
    "• BALANCED/MAXIMUM buttons - preset configurations".postln;
    "".postln;
    "COMMAND LINE PRESETS:".postln;
    "~balanced.();   // 80% surround level, good starting point".postln;
    "~maximum.();    // 100% surround level, maximum effect".postln;
    "~bypass.();     // Turn off matrix, stereo passthrough only".postln;
    "~activate.();   // Turn matrix back on".postln;
    "".postln;
    "MANUAL CONTROL:".postln;
    "~maplinSynth.set(\\surroundLevel, 0.5);  // 50% rear level".postln;
    "~maplinSynth.set(\\effectLevel, 0.6);    // 60% effect intensity".postln;
    "~maplinSynth.set(\\delayTime, 0.8);      // Longer delay (~40ms)".postln;
    "".postln;
    "TESTING PROCEDURE:".postln;
    "1. Run the main script block".postln;
    "2. Play stereo audio into inputs 1&2".postln;
    "3. Watch INPUT meters (L/R) for signal levels".postln;
    "4. Watch OUTPUT meters (FL/FR/RL/RR) to see matrix effect".postln;
    "5. Adjust SURROUND knob - rear meters should respond".postln;
    "6. Use BYPASS to compare stereo vs matrix processing".postln;
    "".postln;
    "~stop.();       // Stop when done".postln;
    "".postln;
};

// Show help automatically
AppClock.sched(0.1, { ~help.(); nil; });

)