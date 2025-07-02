// Manual meter recreation using main GUI approach
// Instead of using ServerMeter2View, manually create meter elements using same style as main GUI

(
s.waitForBoot({
    var testWindow, meterNumbers, meterBars, updateTask;
    var meterValues = Array.fill(8, 0); // Store current meter values
    
    testWindow = Window("Manual Meter Test", Rect(400, 200, 300, 250));
    testWindow.view.background = Color.black;
    
    // Title
    StaticText(testWindow, Rect(10, 10, 100, 20))
    .string_("Manual Meter")
    .stringColor_(Color.cyan)
    .font_(Font("Helvetica", 12));
    
    // Channel numbers using exact main GUI style
    meterNumbers = Array.fill(8, { |i|
        StaticText(testWindow, Rect(20 + (i * 30), 40, 24, 20))
        .string_((i+1).asString)
        .align_(\center)
        .stringColor_(Color.cyan)
        .font_(Font("Helvetica", 12)); // Same as main GUI
    });
    
    // Meter bars using LevelIndicator (same as ServerMeter2View)
    meterBars = Array.fill(8, { |i|
        LevelIndicator(testWindow, Rect(25 + (i * 30), 70, 15, 120))
        .warning_(0.6)
        .critical_(0.9)
        .style_(\led)
        .stepWidth_(4)
        .meterColor_(Color.cyan)
        .backColor_(Color.black)
        .drawsPeak_(true)
        .numTicks_(10)
        .numMajorTicks_(0)
        .warningColor_(Color.new(0.86,0.54,0.04,1))
        .criticalColor_(Color.red);
    });
    
    // dB scale using exact same approach as main GUI
    [-10, -20, -40, -60].do { |db, i|
        StaticText(testWindow, Rect(5, 70 + (i * 30), 15, 15))
        .string_(db.asString)
        .stringColor_(Color.cyan)
        .font_(Font("Helvetica", 9)) // Smaller for scale
        .align_(\right);
    };
    
    // Start meter updates if server is running
    if(s.serverRunning, {
        // Create bus for monitoring
        ~meterSynth = {
            var sig = SoundIn.ar(Array.series(8, 0, 1));
            SendReply.ar(Impulse.ar(20), '/meter', Amplitude.ar(sig, 0.1, 0.3));
            sig
        }.play;
        
        // Receive meter data
        OSCdef(\meterReceiver, { |msg|
            var levels = msg[3..];
            {
                levels.do { |level, i|
                    if(meterBars[i].notNil, {
                        meterBars[i].value = level.ampdb.linlin(-80, 0, 0, 1);
                    });
                };
            }.defer;
        }, '/meter');
    });
    
    testWindow.front;
    testWindow.onClose = {
        if(~meterSynth.notNil, { ~meterSynth.free });
        OSCdef(\meterReceiver).free;
    };
});
)
