// Ultra Conservative B-Format Test - Step-by-step loading
// Isolates file loading from ATK processing to find the crash point

(
var window, step1Button, step2Button, step3Button, step4Button;
var statusLabel, fileLabel, volumeSlider;
var synth, buffer, decoder;
var isPlaying = false;
var filePath;

// Even more conservative server settings
s.options.numOutputBusChannels = 2;
s.options.memSize = 65536; // Start smaller
s.options.blockSize = 512; // Match Jack
s.options.hardwareBufferSize = 1536; // 3 * 512
s.options.numBuffers = 2048; // Fewer buffers initially

s.waitForBoot({
    
    "Server booted - ultra conservative mode".postln;
    
    // Create window
    window = Window("Ultra Conservative B-Format Test", Rect(100, 100, 500, 350))
        .background_(Color.grey(0.9))
        .onClose_({ 
            if(synth.notNil, { synth.free });
            if(buffer.notNil, { buffer.free });
        });
    
    // Status display
    statusLabel = StaticText(window, Rect(20, 20, 460, 30))
        .string_("Ready - Click Step 1 to begin")
        .font_(Font.default.size_(12))
        .background_(Color.white)
        .stringColor_(Color.black);
    
    // Step 1: File selection only (no loading)
    step1Button = Button(window, Rect(20, 70, 120, 30))
        .states_([["Step 1: Select File"]])
        .action_({
            Dialog.openPanel({ |path|
                filePath = path;
                fileLabel.string = "Selected: " ++ PathName(path).fileName;
                statusLabel.string = "✓ File selected - Click Step 2";
                statusLabel.background_(Color.green);
                step2Button.enabled = true;
            });
        });
    
    // Step 2: Create decoder only
    step2Button = Button(window, Rect(150, 70, 120, 30))
        .states_([["Step 2: Create Decoder"]])
        .enabled_(false)
        .action_({
            statusLabel.string = "Creating binaural decoder...";
            statusLabel.background_(Color.yellow);
            
            fork {
                try {
                    decoder = FoaDecoderKernel.newListen(1053);
                    2.wait; // Give it time to load
                    
                    AppClock.sched(0, {
                        statusLabel.string = "✓ Decoder ready - Click Step 3";
                        statusLabel.background_(Color.green);
                        step3Button.enabled = true;
                        nil;
                    });
                } { |error|
                    AppClock.sched(0, {
                        statusLabel.string = "✗ Decoder failed: " ++ error.errorString;
                        statusLabel.background_(Color.red);
                        nil;
                    });
                };
            };
        });
    
    // Step 3: Load file buffer only
    step3Button = Button(window, Rect(280, 70, 120, 30))
        .states_([["Step 3: Load Buffer"]])
        .enabled_(false)
        .action_({
            statusLabel.string = "Loading file buffer...";
            statusLabel.background_(Color.yellow);
            
            if(buffer.notNil, { buffer.free });
            
            // Load with minimal memory footprint
            buffer = Buffer.read(s, filePath, action: { |buf|
                AppClock.sched(0, {
                    if(buf.notNil, {
                        statusLabel.string = "✓ Buffer loaded: % ch, % frames".format(
                            buf.numChannels, buf.numFrames
                        );
                        statusLabel.background_(Color.green);
                        step4Button.enabled = true;
                        
                        if(buf.numChannels != 4, {
                            statusLabel.string = statusLabel.string ++ " (WARNING: Not 4-channel)";
                            statusLabel.background_(Color.yellow);
                        });
                    }, {
                        statusLabel.string = "✗ Buffer loading failed";
                        statusLabel.background_(Color.red);
                    });
                    nil;
                });
            });
        });
    
    // Step 4: Test playback
    step4Button = Button(window, Rect(410, 70, 120, 30))
        .states_([["Step 4: Test Play"], ["Playing", Color.black, Color.green]])
        .enabled_(false)
        .action_({ |btn|
            if(isPlaying.not, {
                statusLabel.string = "Starting ultra-conservative playback...";
                statusLabel.background_(Color.cyan);
                
                try {
                    synth = {
                        var src, decoded, volume;
                        
                        // Ultra-conservative B-format playback
                        src = PlayBuf.ar(4, buffer, BufRateScale.kr(buffer), loop: 1);
                        
                        // Decode with minimal processing
                        decoded = FoaDecode.ar(src, decoder);
                        
                        // Very quiet volume
                        volume = \volume.kr(-24).dbamp; // Even quieter
                        
                        Out.ar(0, decoded * volume);
                    }.play;
                    
                    isPlaying = true;
                    statusLabel.string = "✓ Playback active";
                    statusLabel.background_(Color.green);
                } { |error|
                    statusLabel.string = "✗ Playback failed: " ++ error.errorString;
                    statusLabel.background_(Color.red);
                };
            }, {
                if(synth.notNil, { synth.free; synth = nil; });
                isPlaying = false;
                btn.value = 0;
                statusLabel.string = "Playback stopped";
                statusLabel.background_(Color.white);
            });
        });
    
    // File info
    StaticText(window, Rect(20, 120, 460, 20))
        .string_("Selected File:")
        .font_(Font.default.size_(12).bold_(true));
    
    fileLabel = StaticText(window, Rect(20, 145, 460, 20))
        .string_("No file selected")
        .font_(Font.default.size_(11));
    
    // Volume control
    StaticText(window, Rect(20, 180, 460, 20))
        .string_("Volume Control:")
        .font_(Font.default.size_(12).bold_(true));
    
    volumeSlider = Slider(window, Rect(20, 205, 300, 20))
        .value_(0.1) // -24 dB
        .action_({ |sl|
            var volumeValue = sl.value.linlin(0, 1, -48, 0);
            if(synth.notNil, { synth.set(\volume, volumeValue) });
        });
    
    StaticText(window, Rect(330, 205, 150, 20))
        .string_("(-48dB to 0dB)")
        .font_(Font.default.size_(10));
    
    // Instructions
    StaticText(window, Rect(20, 240, 460, 60))
        .string_("Instructions:\n1. Select a B-format file (4-channel WAV)\n2. Create the binaural decoder\n3. Load the file into buffer\n4. Test playback")
        .font_(Font.default.size_(10))
        .background_(Color.grey(0.95));
    
    window.front;
    "Ultra Conservative Test ready!".postln;
    "This will isolate exactly where the crash occurs".postln;
});
)

