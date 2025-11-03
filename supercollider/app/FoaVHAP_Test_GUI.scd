// FoaVHAP Test GUI
// Simple test application for the FoaVHAP SuperCollider extension
// Loads B-format files, applies VHAP processing, and outputs to binaural

(
var window, fileButton, fileLabel, playButton, stopButton;
var trimSlider, morphSlider, soloButton, volumeSlider;
var trimLabel, morphLabel, soloLabel, volumeLabel;
var synth, buffer, decoder;
var isPlaying = false;

// Configure server for heavy convolution processing
s.options.numOutputBusChannels = 2; // Stereo output for binaural
s.options.memSize = 131072; // Much more memory for convolution
s.options.blockSize = 512; // Larger block size for efficiency
s.options.hardwareBufferSize = 1024; // Larger hardware buffer
s.options.numBuffers = 2048; // More buffers

// Boot server and setup
s.waitForBoot({
    
    // Create binaural decoder
    decoder = FoaDecoderKernel.newListen(1053);
    
    // Pre-load VHAP kernels to avoid real-time allocation
    "Pre-loading VHAP kernels...".postln;
    {
        var testInput = [DC.ar(0), DC.ar(0), DC.ar(0), DC.ar(0)];
        var vhap = FoaVHAP.ar(testInput, partitionSize: 512); // Use smaller partition
        Silent.ar(4);
    }.play;
    
    // Wait a moment for kernel loading
    2.wait;
    
    // Create main window
    window = Window("FoaVHAP Test", Rect(100, 100, 500, 400))
        .background_(Color.grey(0.9))
        .onClose_({ 
            if(synth.notNil, { synth.free });
            if(buffer.notNil, { buffer.free });
            FoaVHAP.cleanup;
        });
    
    // File loading section
    StaticText(window, Rect(20, 20, 460, 20))
        .string_("B-Format Audio File:")
        .font_(Font.default.size_(14).bold_(true));
    
    fileButton = Button(window, Rect(20, 50, 100, 30))
        .states_([["Load File"]])
        .action_({
            Dialog.openPanel({ |path|
                // Load the selected file
                if(buffer.notNil, { buffer.free });
                buffer = Buffer.read(s, path, action: { |buf|
                    // Use AppClock to update GUI from audio thread
                    AppClock.sched(0, {
                        if(buf.notNil, {
                            fileLabel.string = "Loaded: " ++ PathName(path).fileName;
                            ("Loaded B-format file: " ++ path).postln;
                            ("Channels: % | Frames: % | Duration: %s".format(
                                buf.numChannels, buf.numFrames, 
                                (buf.numFrames / buf.sampleRate).round(0.1)
                            )).postln;
                            
                            // Enable play button
                            playButton.enabled = true;
                        }, {
                            "Failed to load file".warn;
                            fileLabel.string = "Failed to load file";
                        });
                        nil; // Return nil to AppClock
                    });
                });
            });
        });
    
    fileLabel = StaticText(window, Rect(130, 55, 350, 20))
        .string_("No file loaded")
        .font_(Font.default.size_(12));
    
    // Transport controls
    StaticText(window, Rect(20, 100, 460, 20))
        .string_("Transport:")
        .font_(Font.default.size_(14).bold_(true));
    
    playButton = Button(window, Rect(20, 130, 80, 30))
        .states_([["Play"], ["Playing", Color.black, Color.green]])
        .enabled_(false)
        .action_({ |btn|
            if(isPlaying.not, {
                // Start playback
                if(buffer.notNil, {
                    synth = {
                        var src, vhap, decoded, volume;
                        
                        // Play B-format file (loop)
                        src = PlayBuf.ar(4, buffer, BufRateScale.kr(buffer), loop: 1);
                        
                        // Apply VHAP processing with smaller partition for stability
                        vhap = FoaVHAP.ar(
                            src, 
                            trim: \trim.kr(0),
                            morph: \morph.kr(0.8), 
                            solo: \solo.kr(0),
                            partitionSize: 512
                        );
                        
                        // Decode to binaural
                        decoded = FoaDecode.ar(vhap, decoder);
                        
                        // Volume control
                        volume = \volume.kr(-6).dbamp;
                        
                        Out.ar(0, decoded * volume);
                    }.play;
                    
                    isPlaying = true;
                    stopButton.enabled = true;
                    "Playback started".postln;
                });
            });
        });
    
    stopButton = Button(window, Rect(110, 130, 80, 30))
        .states_([["Stop"]])
        .enabled_(false)
        .action_({ |btn|
            if(synth.notNil, { 
                synth.free; 
                synth = nil;
            });
            isPlaying = false;
            playButton.value = 0;
            stopButton.enabled = false;
            "Playback stopped".postln;
        });
    
    // VHAP Controls
    StaticText(window, Rect(20, 180, 460, 20))
        .string_("VHAP Controls:")
        .font_(Font.default.size_(14).bold_(true));
    
    // Trim control
    trimLabel = StaticText(window, Rect(20, 210, 100, 20))
        .string_("Trim: 0.0 dB")
        .font_(Font.default.size_(12));
    
    trimSlider = Slider(window, Rect(20, 235, 200, 20))
        .value_(0.5) // 0 dB (center of -12 to +12 range)
        .action_({ |sl|
            var trimValue = sl.value.linlin(0, 1, -12, 12);
            trimLabel.string = "Trim: % dB".format(trimValue.round(0.1));
            if(synth.notNil, { synth.set(\trim, trimValue) });
        });
    
    // Morph control  
    morphLabel = StaticText(window, Rect(250, 210, 100, 20))
        .string_("Morph: 0.8")
        .font_(Font.default.size_(12));
    
    morphSlider = Slider(window, Rect(250, 235, 200, 20))
        .value_(0.8)
        .action_({ |sl|
            var morphValue = sl.value;
            morphLabel.string = "Morph: %".format(morphValue.round(0.01));
            if(synth.notNil, { synth.set(\morph, morphValue) });
        });
    
    // Solo control
    soloLabel = StaticText(window, Rect(20, 270, 100, 20))
        .string_("Solo: Off")
        .font_(Font.default.size_(12));
    
    soloButton = Button(window, Rect(20, 295, 80, 30))
        .states_([["Solo Off"], ["Solo On", Color.white, Color.red]])
        .action_({ |btn|
            var soloValue = btn.value;
            soloLabel.string = if(soloValue == 1, "Solo: On", "Solo: Off");
            if(synth.notNil, { synth.set(\solo, soloValue) });
        });
    
    // Volume control
    volumeLabel = StaticText(window, Rect(250, 270, 150, 20))
        .string_("Volume: -6.0 dB")
        .font_(Font.default.size_(12));
    
    volumeSlider = Slider(window, Rect(250, 295, 200, 20))
        .value_(0.4) // -6 dB (reasonable default)
        .action_({ |sl|
            var volumeValue = sl.value.linlin(0, 1, -24, 6);
            volumeLabel.string = "Volume: % dB".format(volumeValue.round(0.1));
            if(synth.notNil, { synth.set(\volume, volumeValue) });
        });
    
    // Instructions
    StaticText(window, Rect(20, 340, 460, 40))
        .string_("Instructions: Load a 4-channel B-format WAV file, then press Play.\nUse the controls to test VHAP processing. Solo mode auditions synthesized Z'.")
        .font_(Font.default.size_(11))
        .stringColor_(Color.grey(0.3));
    
    // Show window
    window.front;
    
    "FoaVHAP Test GUI ready!".postln;
    "Load a B-format file to begin testing.".postln;
});
)

