// Working ATK Transform Test - Using proven ATK transforms
// Built on the working B-format foundation with standard ATK processing

(
var window, loadButton, playButton, stopButton, volumeSlider;
var statusLabel, fileLabel;
var synth, sfp, decoder, playerBus, testSynth;
var rotateSlider, tiltSlider, tumbleSlider;
var isPlaying = false;
var filePath;
var outputs = 8; // Match HD interface
var inputs = 2;  // Match Phonorama

// Use exact same server setup as working UHJ v27
if(s.serverRunning.not, {
    s.options.memSize = 65536; // Exact same as UHJ v27
    s.options.numOutputBusChannels = outputs;
    s.options.numInputBusChannels = inputs;
    s.boot;
    
    s.waitForBoot({
        "Server booted - Working ATK Transform test".postln;
        
        // Create player bus for 4-channel B-format
        playerBus = Bus.audio(s, 4);
        
        // Create window
        window = Window("Working ATK Transform Test", Rect(100, 100, 600, 400))
            .background_(Color.grey(0.9))
            .onClose_({ 
                if(synth.notNil, { synth.free });
                if(sfp.notNil, { sfp.stop });
                if(testSynth.notNil, { testSynth.free });
            });
        
        // Status label
        statusLabel = StaticText(window, Rect(20, 20, 560, 20))
            .string_("Ready - Load a B-format file")
            .font_(Font("Arial", 12))
            .stringColor_(Color.black);
        
        // File label
        fileLabel = StaticText(window, Rect(20, 50, 560, 20))
            .string_("No file loaded")
            .font_(Font("Arial", 10))
            .stringColor_(Color.grey(0.3));
        
        // Test tone button
        Button(window, Rect(20, 80, 80, 30))
            .states_([
                ["Test Tone", Color.black, Color.yellow(0.7)],
                ["Stop Tone", Color.white, Color.red(0.7)]
            ])
            .action_({ |btn|
                if(btn.value == 1, {
                    testSynth = {
                        var tone = SinOsc.ar(440, 0, 0.1);
                        Out.ar(0, tone); // Left
                        Out.ar(1, tone); // Right
                    }.play;
                    statusLabel.string = "Test tone playing";
                }, {
                    if(testSynth.notNil, { testSynth.free; testSynth = nil });
                    statusLabel.string = "Test tone stopped";
                });
            });
        
        // Load button
        loadButton = Button(window, Rect(110, 80, 100, 30))
            .states_([["Load File", Color.black, Color.grey(0.8)]])
            .action_({
                Dialog.openPanel({ |path|
                    filePath = path;
                    
                    // Stop existing SFPlayer if it exists
                    if(sfp.notNil, { sfp.stop });
                    
                    // Create SFPlayer exactly like UHJ v27
                    sfp = SFPlayer.new(
                        filePath, 
                        outbus: playerBus.index, 
                        server: s, 
                        autoBootServer: false, 
                        autoSetSampleRate: false, 
                        autoSetOutputChannels: false
                    );
                    sfp.loop = false;
                    
                    // Update GUI
                    AppClock.sched(0, {
                        fileLabel.string = "Loaded: " ++ PathName(path).fileName;
                        statusLabel.string = "File loaded - Ready to play";
                        playButton.enabled_(true);
                        nil;
                    });
                    
                    "B-format file loaded with SFPlayer".postln;
                    
                }, {
                    "File loading cancelled".postln;
                });
            });
        
        // Play button
        playButton = Button(window, Rect(220, 80, 60, 30))
            .states_([
                ["Play", Color.black, Color.green(0.7)],
                ["Stop", Color.white, Color.red(0.7)]
            ])
            .enabled_(false)
            .action_({ |btn|
                if(btn.value == 1, {
                    // Start playback
                    if(sfp.notNil, {
                        // Create decoder
                        if(decoder.isNil, {
                            "Creating CIPIC binaural decoder...".postln;
                            decoder = FoaDecoderKernel.newCIPIC(12);
                        });
                        
                        // Use AppClock to delay synth creation
                        AppClock.sched(0.1, {
                            // Create ATK processing synth using proven transforms
                            synth = {
                                var src, bformat, rotated, tilted, tumbled, decoded;
                                var rotation, tilt, tumble;
                                
                                // Get controls
                                rotation = \rotation.kr(0);  // -180 to +180 degrees
                                tilt = \tilt.kr(0);         // -90 to +90 degrees  
                                tumble = \tumble.kr(0);     // -180 to +180 degrees
                                
                                // Get 4-channel B-format from SFPlayer bus
                                src = In.ar(playerBus.index, 4);
                                
                                // Input is already B-format [W, X, Y, Z]
                                bformat = src;
                                
                                // Apply ATK spatial transforms (same as UHJ Player)
                                rotated = FoaRotate.ar(bformat, rotation.degrad);
                                tilted = FoaTilt.ar(rotated, tilt.degrad);
                                tumbled = FoaTumble.ar(tilted, tumble.degrad);
                                
                                // Binaural decode (outputs stereo)
                                decoded = FoaDecode.ar(tumbled, decoder);
                                
                                // Apply volume
                                decoded = decoded * \vol.kr(-18.dbamp);
                                
                                // Output stereo (same as working test tone)
                                Out.ar(0, decoded[0]); // Left
                                Out.ar(1, decoded[1]); // Right
                            }.play;
                            
                            // Start SFPlayer
                            sfp.play;
                            
                            isPlaying = true;
                            statusLabel.string = "Playing B-format with ATK transforms";
                            nil;
                        });
                    });
                }, {
                    // Stop playback
                    if(sfp.notNil, { sfp.stop });
                    if(synth.notNil, { synth.free; synth = nil });
                    isPlaying = false;
                    statusLabel.string = "Stopped";
                });
            });
        
        // Volume slider
        StaticText(window, Rect(20, 130, 60, 20))
            .string_("Volume:")
            .font_(Font("Arial", 10));
        
        volumeSlider = Slider(window, Rect(80, 130, 200, 20))
            .value_(0.25) // Start at -18dB
            .action_({ |sl|
                var dbVal = sl.value.linlin(0, 1, -60, 0);
                if(synth.notNil, {
                    synth.set(\vol, dbVal.dbamp);
                });
                statusLabel.string = "Volume: " ++ dbVal.round(0.1) ++ " dB";
            });
        
        // ATK Transform Controls
        StaticText(window, Rect(20, 170, 100, 20))
            .string_("Rotation:")
            .font_(Font("Arial", 10));
        
        rotateSlider = Slider(window, Rect(120, 170, 200, 20))
            .value_(0.5) // 0 degrees
            .action_({ |sl|
                var rotVal = sl.value.linlin(0, 1, -180, 180);
                if(synth.notNil, {
                    synth.set(\rotation, rotVal);
                });
                statusLabel.string = "Rotation: " ++ rotVal.round(1) ++ "°";
            });
        
        StaticText(window, Rect(20, 200, 100, 20))
            .string_("Tilt:")
            .font_(Font("Arial", 10));
        
        tiltSlider = Slider(window, Rect(120, 200, 200, 20))
            .value_(0.5) // 0 degrees
            .action_({ |sl|
                var tiltVal = sl.value.linlin(0, 1, -90, 90);
                if(synth.notNil, {
                    synth.set(\tilt, tiltVal);
                });
                statusLabel.string = "Tilt: " ++ tiltVal.round(1) ++ "°";
            });
        
        StaticText(window, Rect(20, 230, 100, 20))
            .string_("Tumble:")
            .font_(Font("Arial", 10));
        
        tumbleSlider = Slider(window, Rect(120, 230, 200, 20))
            .value_(0.5) // 0 degrees
            .action_({ |sl|
                var tumbleVal = sl.value.linlin(0, 1, -180, 180);
                if(synth.notNil, {
                    synth.set(\tumble, tumbleVal);
                });
                statusLabel.string = "Tumble: " ++ tumbleVal.round(1) ++ "°";
            });
        
        // Instructions
        StaticText(window, Rect(20, 270, 560, 100))
            .string_("Instructions:\n1. Click 'Test Tone' to verify audio path\n2. Click 'Load File' to select a B-format audio file\n3. Click 'Play' to start B-format playback with ATK transforms\n4. Use Rotation to spin the soundfield horizontally\n5. Use Tilt to tip the soundfield up/down\n6. Use Tumble to roll the soundfield left/right\n\nUsing proven ATK transforms: FoaRotate, FoaTilt, FoaTumble")
            .font_(Font("Arial", 9))
            .stringColor_(Color.grey(0.4));
        
        window.front;
        
        "Working ATK Transform Test ready".postln;
    });
});
)
