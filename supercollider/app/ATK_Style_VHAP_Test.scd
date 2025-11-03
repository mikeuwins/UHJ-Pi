// ATK Style VHAP Test - Using proper ATK transform pattern
// Built on working foundation, following FoaRotate/FoaTilt pattern

(
var window, loadButton, playButton, stopButton, volumeSlider;
var statusLabel, fileLabel;
var synth, sfp, decoder, playerBus, testSynth;
var trimSlider, morphSlider, soloSlider;
var meterBusses, meterSynth, meterTask;
var wMeter, xMeter, yMeter, zMeter, zPrimeMeter;
var isPlaying = false;
var filePath;
var outputs = 8; // Match HD interface
var inputs = 2;  // Match Phonorama
 
// Use exact same server setup as working tests
if(s.serverRunning.not, { 
    s.options.memSize = 65536;
    s.options.numOutputBusChannels = outputs;
    s.options.numInputBusChannels = inputs;
    s.boot;
    
    s.waitForBoot({
        "Server booted - ATK Style VHAP test".postln;
        
        // Create player bus for 4-channel B-format
        playerBus = Bus.audio(s, 4);
        
        // Initialize VHAP kernels - use 1024 to match JSFX (BV_N = 1024)
        "Initializing VHAP kernels...".postln;
        FoaVHAP.initKernels(1024, s);
        
        // Wait a moment for kernel loading
        AppClock.sched(2.0, {
            "VHAP kernels should be ready".postln;
            nil;
        });
        
        // Create window
        window = Window("ATK Style VHAP Test", Rect(100, 100, 600, 400))
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
        
        // Load button
        loadButton = Button(window, Rect(20, 80, 100, 30))
            .states_([["Load File", Color.black, Color.grey(0.8)]])
            .action_({
                Dialog.openPanel({ |path|
                    filePath = path;
                    
                    // Stop existing SFPlayer if it exists
                    if(sfp.notNil, { sfp.stop });
                    
                    // Create SFPlayer exactly like working tests
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
        playButton = Button(window, Rect(130, 80, 60, 30))
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
                            // Create ATK-style VHAP processing synth
                            synth = {
                                var src, vhapProcessed, decoded;
                                var trim, morph, solo;
                                var isSolo, soloOutput, finalOutput;
                                var w, x, y, z, trimLinear, soloSignal, bFormatToDecode;
                                
                                // Get controls
                                trim = \trim.kr(0);    // -12 to +12 dB
                                morph = \morph.kr(1);  // 0 to 1
                                solo = \solo.kr(0);    // 0 to 1
                                
                                // Get 4-channel B-format from SFPlayer bus
                                src = In.ar(playerBus.index, 4);
                                
                                // Apply ATK-style VHAP processing - use solo parameter directly
                                vhapProcessed = FoaVHAP.ar(src, trim, morph, solo, 1024); // Use solo parameter, 1024 partition
                                
                                // Just use FoaVHAP class directly - it handles solo internally
                                decoded = FoaDecode.ar(vhapProcessed, decoder);
                                finalOutput = decoded;
                                
                                // Apply volume
                                finalOutput = finalOutput * \vol.kr(-18.dbamp);
                                
                                // Output stereo
                                Out.ar(0, finalOutput[0]); // Left
                                Out.ar(1, finalOutput[1]); // Right
                            }.play;
                            
                            // Start SFPlayer
                            sfp.play;
                            
                            isPlaying = true;
                            statusLabel.string = "Playing B-format with ATK-style VHAP";
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
        
        // ATK-style VHAP Controls
        StaticText(window, Rect(20, 170, 100, 20))
            .string_("VHAP Trim:")
            .font_(Font("Arial", 10));
        
        trimSlider = Slider(window, Rect(120, 170, 200, 20))
            .value_(0.5) // 0 dB
            .action_({ |sl|
                var dbVal = sl.value.linlin(0, 1, -48, 48);
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
        
        Button(window, Rect(20, 230, 100, 30))
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
        StaticText(window, Rect(20, 270, 560, 100))
            .string_("Instructions:\n1. Click 'Load File' to select a B-format audio file\n2. Click 'Play' to start B-format playback with ATK-style VHAP\n3. Use VHAP Trim to adjust Z channel level\n4. Use VHAP Morph to blend original and processed Z\n5. Use VHAP Solo slider for smooth crossfade to solo mode\n\nFollows proper ATK transform pattern like FoaRotate, FoaTilt, etc.")
            .font_(Font("Arial", 9))
            .stringColor_(Color.grey(0.4));
        
        window.front;
        
        "ATK Style VHAP Test ready".postln;
    });
});
)
