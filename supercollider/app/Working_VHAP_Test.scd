// Working VHAP Test - Built on proven B-format foundation
// Adds FoaVHAP processing to the working audio setup

(
var window, loadButton, playButton, stopButton, volumeSlider;
var statusLabel, fileLabel;
var synth, sfp, decoder, playerBus, testSynth;
var trimSlider, morphSlider, soloButton;
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
        "Server booted - Working VHAP test".postln;
        
        // Pre-load VHAP kernels to avoid real-time allocation
        "Pre-loading VHAP kernels...".postln;
        FoaVHAP.initKernels(512, s);
        
        // Wait a moment for kernel loading
        AppClock.sched(3, {
            "VHAP kernels loaded - ready for processing".postln;
            
            // Create player bus for 4-channel B-format
            playerBus = Bus.audio(s, 4);
            
            // Create window
            window = Window("Working VHAP Test", Rect(100, 100, 600, 400))
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
                                // Create VHAP processing synth
                                synth = {
                                    var src, bformat, vhapProcessed, decoded;
                                    var trim, morph, solo;
                                    
                                    // Get controls
                                    trim = \trim.kr(0);    // -12 to +12 dB
                                    morph = \morph.kr(1);  // 0 to 1
                                    solo = \solo.kr(0);    // 0 or 1
                                    
                                    // Get 4-channel B-format from SFPlayer bus
                                    src = In.ar(playerBus.index, 4);
                                    
                                    // Apply VHAP processing
                                    vhapProcessed = FoaVHAP.ar(src, trim, morph, solo, 512);
                                    
                                    // Binaural decode (outputs stereo)
                                    decoded = FoaDecode.ar(vhapProcessed, decoder);
                                    
                                    // Apply volume
                                    decoded = decoded * \vol.kr(-18.dbamp);
                                    
                                    // Output stereo (same as working test tone)
                                    Out.ar(0, decoded[0]); // Left
                                    Out.ar(1, decoded[1]); // Right
                                }.play;
                                
                                // Start SFPlayer
                                sfp.play;
                                
                                isPlaying = true;
                                statusLabel.string = "Playing B-format with VHAP processing";
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
            
            // VHAP Controls
            StaticText(window, Rect(20, 170, 100, 20))
                .string_("VHAP Trim:")
                .font_(Font("Arial", 10));
            
            trimSlider = Slider(window, Rect(120, 170, 200, 20))
                .value_(0.5) // 0 dB
                .action_({ |sl|
                    var dbVal = sl.value.linlin(0, 1, -12, 12);
                    if(synth.notNil, {
                        synth.set(\trim, dbVal);
                    });
                    statusLabel.string = "VHAP Trim: " ++ dbVal.round(0.1) ++ " dB";
                });
            
            StaticText(window, Rect(20, 200, 100, 20))
                .string_("VHAP Morph:")
                .font_(Font("Arial", 10));
            
            morphSlider = Slider(window, Rect(120, 200, 200, 20))
                .value_(1.0) // Full morph
                .action_({ |sl|
                    var morphVal = sl.value;
                    if(synth.notNil, {
                        synth.set(\morph, morphVal);
                    });
                    statusLabel.string = "VHAP Morph: " ++ (morphVal * 100).round(1) ++ "%";
                });
            
            soloButton = Button(window, Rect(20, 230, 100, 30))
                .states_([
                    ["VHAP Solo", Color.black, Color.grey(0.8)],
                    ["VHAP Solo", Color.white, Color.red(0.8)]
                ])
                .action_({ |btn|
                    if(synth.notNil, {
                        synth.set(\solo, btn.value);
                    });
                    if(btn.value == 1, {
                        statusLabel.string = "VHAP Solo ON - hearing synthesized height only";
                    }, {
                        statusLabel.string = "VHAP Solo OFF - hearing full mix";
                    });
                });
            
            // Instructions
            StaticText(window, Rect(20, 280, 560, 100))
                .string_("Instructions:\n1. Click 'Test Tone' to verify audio path\n2. Click 'Load File' to select a B-format audio file\n3. Click 'Play' to start B-format playback with VHAP processing\n4. Use VHAP Trim to match Z' level to original Z\n5. Use VHAP Morph to blend original and synthesized height\n6. Use VHAP Solo to isolate the synthesized height layer\n\nBuilt on working UHJ v27 foundation with FoaVHAP extension")
                .font_(Font("Arial", 9))
                .stringColor_(Color.grey(0.4));
            
            window.front;
            
            "Working VHAP Test ready".postln;
            nil;
        });
    });
});
)
