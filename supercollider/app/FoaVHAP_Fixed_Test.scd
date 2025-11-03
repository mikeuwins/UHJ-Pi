// Fixed FoaVHAP Test - Proper kernel initialization
// This version loads kernels BEFORE starting audio processing

(
var window, fileButton, fileLabel, playButton, stopButton, vhapButton;
var trimSlider, morphSlider, volumeSlider;
var trimLabel, morphLabel, volumeLabel;
var synth, buffer, decoder;
var isPlaying = false, vhapEnabled = false;
var kernelsLoaded = false;

// Conservative server settings
s.options.numOutputBusChannels = 2;
s.options.memSize = 131072;
s.options.blockSize = 512;
s.options.hardwareBufferSize = 1024;

s.waitForBoot({
    
    "Creating binaural decoder...".postln;
    decoder = FoaDecoderKernel.newListen(1053);
    
    // Initialize VHAP kernels BEFORE creating GUI
    "Initializing VHAP kernels...".postln;
    FoaVHAP.initKernels(512, s);
    
    // Wait for kernel loading
    fork {
        3.wait; // Give time for async kernel loading
        kernelsLoaded = true;
        "VHAP kernels should be loaded now".postln;
        
        // Create GUI after kernels are loaded
        {
            // Create window
            window = Window("Fixed FoaVHAP Test", Rect(100, 100, 450, 400))
                .background_(Color.grey(0.9))
                .onClose_({ 
                    if(synth.notNil, { synth.free });
                    if(buffer.notNil, { buffer.free });
                    FoaVHAP.cleanup;
                });
            
            // File loading
            StaticText(window, Rect(20, 20, 410, 20))
                .string_("B-Format Audio File:")
                .font_(Font.default.size_(14).bold_(true));
            
            fileButton = Button(window, Rect(20, 50, 100, 30))
                .states_([["Load File"]])
                .action_({
                    Dialog.openPanel({ |path|
                        if(buffer.notNil, { buffer.free });
                        buffer = Buffer.read(s, path, action: { |buf|
                            AppClock.sched(0, {
                                if(buf.notNil, {
                                    fileLabel.string = "Loaded: " ++ PathName(path).fileName;
                                    ("File: % channels, % frames".format(
                                        buf.numChannels, buf.numFrames
                                    )).postln;
                                    playButton.enabled = true;
                                }, {
                                    fileLabel.string = "Failed to load";
                                });
                                nil;
                            });
                        });
                    });
                });
            
            fileLabel = StaticText(window, Rect(130, 55, 300, 20))
                .string_("No file loaded")
                .font_(Font.default.size_(11));
            
            // Transport
            StaticText(window, Rect(20, 100, 410, 20))
                .string_("Transport:")
                .font_(Font.default.size_(14).bold_(true));
            
            playButton = Button(window, Rect(20, 130, 80, 30))
                .states_([["Play"], ["Playing", Color.black, Color.green]])
                .enabled_(false)
                .action_({ |btn|
                    if(isPlaying.not, {
                        if(buffer.notNil, {
                            synth = {
                                var src, processed, decoded, volume;
                                
                                // Play B-format file
                                src = PlayBuf.ar(4, buffer, BufRateScale.kr(buffer), loop: 1);
                                
                                // Choose processing: bypass or VHAP
                                processed = Select.ar(\vhapEnabled.kr(0), [
                                    src, // Bypass
                                    FoaVHAP.ar(
                                        src, 
                                        trim: \trim.kr(0),
                                        morph: \morph.kr(0.8),
                                        partitionSize: 512
                                    )
                                ]);
                                
                                // Decode to binaural
                                decoded = FoaDecode.ar(processed, decoder);
                                
                                // Volume control
                                volume = \volume.kr(-12).dbamp;
                                
                                Out.ar(0, decoded * volume);
                            }.play;
                            
                            isPlaying = true;
                            stopButton.enabled = true;
                            vhapButton.enabled = true;
                            "Playback started (bypass mode)".postln;
                        });
                    });
                });
            
            stopButton = Button(window, Rect(110, 130, 80, 30))
                .states_([["Stop"]])
                .enabled_(false)
                .action_({
                    if(synth.notNil, { synth.free; synth = nil; });
                    isPlaying = false;
                    vhapEnabled = false;
                    playButton.value = 0;
                    vhapButton.value = 0;
                    stopButton.enabled = false;
                    vhapButton.enabled = false;
                    "Playback stopped".postln;
                });
            
            // VHAP toggle
            vhapButton = Button(window, Rect(200, 130, 100, 30))
                .states_([["VHAP Off"], ["VHAP On", Color.white, Color.blue]])
                .enabled_(false)
                .action_({ |btn|
                    vhapEnabled = btn.value == 1;
                    if(synth.notNil, { 
                        synth.set(\vhapEnabled, btn.value);
                        if(vhapEnabled, {
                            "VHAP processing enabled".postln;
                        }, {
                            "VHAP bypassed".postln;
                        });
                    });
                });
            
            // VHAP Controls
            StaticText(window, Rect(20, 180, 410, 20))
                .string_("VHAP Controls:")
                .font_(Font.default.size_(14).bold_(true));
            
            // Trim
            trimLabel = StaticText(window, Rect(20, 210, 100, 20))
                .string_("Trim: 0.0 dB")
                .font_(Font.default.size_(11));
            
            trimSlider = Slider(window, Rect(20, 235, 180, 20))
                .value_(0.5) // 0 dB
                .action_({ |sl|
                    var trimValue = sl.value.linlin(0, 1, -12, 12);
                    trimLabel.string = "Trim: % dB".format(trimValue.round(0.1));
                    if(synth.notNil, { synth.set(\trim, trimValue) });
                });
            
            // Morph
            morphLabel = StaticText(window, Rect(220, 210, 100, 20))
                .string_("Morph: 0.8")
                .font_(Font.default.size_(11));
            
            morphSlider = Slider(window, Rect(220, 235, 180, 20))
                .value_(0.8)
                .action_({ |sl|
                    var morphValue = sl.value;
                    morphLabel.string = "Morph: %".format(morphValue.round(0.01));
                    if(synth.notNil, { synth.set(\morph, morphValue) });
                });
            
            // Volume
            StaticText(window, Rect(20, 280, 410, 20))
                .string_("Output:")
                .font_(Font.default.size_(14).bold_(true));
            
            volumeLabel = StaticText(window, Rect(20, 310, 150, 20))
                .string_("Volume: -12.0 dB")
                .font_(Font.default.size_(11));
            
            volumeSlider = Slider(window, Rect(20, 335, 200, 20))
                .value_(0.3) // -12 dB
                .action_({ |sl|
                    var volumeValue = sl.value.linlin(0, 1, -30, 0);
                    volumeLabel.string = "Volume: % dB".format(volumeValue.round(0.1));
                    if(synth.notNil, { synth.set(\volume, volumeValue) });
                });
            
            // Instructions
            StaticText(window, Rect(20, 370, 410, 20))
                .string_("Load file → Play → Toggle VHAP On to test processing")
                .font_(Font.default.size_(11))
                .stringColor_(Color.grey(0.3));
            
            window.front;
            "Fixed FoaVHAP Test ready!".postln;
            
        }.defer; // Defer GUI creation to main thread
    };
});
)

