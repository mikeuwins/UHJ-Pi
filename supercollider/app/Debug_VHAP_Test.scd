// Debug VHAP Test - Isolate the FoaVHAP issue
// Start with working B-format, then add VHAP step by step

(
var window, loadButton, playButton, stopButton, volumeSlider;
var statusLabel, fileLabel;
var synth, sfp, decoder, playerBus, testSynth;
var vhapButton;
var isPlaying = false, vhapEnabled = false;
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
        "Server booted - Debug VHAP test".postln;
        
        // Create player bus for 4-channel B-format
        playerBus = Bus.audio(s, 4);
        
        // Create window
        window = Window("Debug VHAP Test", Rect(100, 100, 500, 350))
            .background_(Color.grey(0.9))
            .onClose_({ 
                if(synth.notNil, { synth.free });
                if(sfp.notNil, { sfp.stop });
                if(testSynth.notNil, { testSynth.free });
            });
        
        // Status label
        statusLabel = StaticText(window, Rect(20, 20, 460, 20))
            .string_("Ready - Load a B-format file")
            .font_(Font("Arial", 12))
            .stringColor_(Color.black);
        
        // File label
        fileLabel = StaticText(window, Rect(20, 50, 460, 20))
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
                            // Create processing synth - start without VHAP
                            synth = {
                                var src, bformat, decoded;
                                
                                // Get 4-channel B-format from SFPlayer bus
                                src = In.ar(playerBus.index, 4);
                                
                                // For now, just pass through B-format (no VHAP)
                                bformat = src;
                                
                                // Binaural decode (outputs stereo)
                                decoded = FoaDecode.ar(bformat, decoder);
                                
                                // Apply volume
                                decoded = decoded * \vol.kr(-18.dbamp);
                                
                                // Output stereo (same as working test tone)
                                Out.ar(0, decoded[0]); // Left
                                Out.ar(1, decoded[1]); // Right
                            }.play;
                            
                            // Start SFPlayer
                            sfp.play;
                            
                            isPlaying = true;
                            statusLabel.string = "Playing B-format (no VHAP processing)";
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
        
        // VHAP Enable button (for testing)
        vhapButton = Button(window, Rect(290, 80, 100, 30))
            .states_([
                ["Enable VHAP", Color.black, Color.grey(0.8)],
                ["Disable VHAP", Color.white, Color.blue(0.8)]
            ])
            .enabled_(false)
            .action_({ |btn|
                "VHAP toggle not implemented yet - need to debug FoaVHAP class first".postln;
                statusLabel.string = "VHAP processing not ready - check FoaVHAP class";
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
        
        // Instructions
        StaticText(window, Rect(20, 170, 460, 150))
            .string_("Debug Instructions:\n1. Click 'Test Tone' to verify audio path\n2. Click 'Load File' to select a B-format audio file\n3. Click 'Play' to start B-format playback (no VHAP)\n4. Verify this works before adding VHAP processing\n\nThis version bypasses FoaVHAP to isolate the issue.\nOnce basic B-format works, we can debug the VHAP class.\n\nError was: 'Select input was not audio rate: 0'\nThis suggests an issue with the FoaVHAP implementation.")
            .font_(Font("Arial", 9))
            .stringColor_(Color.grey(0.4));
        
        window.front;
        
        "Debug VHAP Test ready - testing B-format without VHAP first".postln;
    });
});
)
