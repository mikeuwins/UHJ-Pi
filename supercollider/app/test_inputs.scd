// Input test for UHJ aggregate device
// This will help find which channels have your ESI interface (not webcam)

s.options.numInputBusChannels = 8;  // Test more channels to find the right ones
s.options.numOutputBusChannels = 2;
s.options.device = "UHJ";
s.options.memSize = 65536;

s.boot;

s.waitForBoot({
    "=== Input Channel Finder ===".postln;
    "Device: UHJ".postln;
    "Testing channels 0-7 to find ESI interface".postln;
    "Make noise into your ESI interface and watch for activity...".postln;
    "".postln;
    
    // Test all input channels
    ~inputTest = {
        var in = SoundIn.ar([0, 1, 2, 3, 4, 5, 6, 7]);
        var amp = Amplitude.kr(in);
        
        // Send amplitude to post window
        SendReply.kr(Impulse.kr(10), '/inputAmp', amp);
        
        // Output first 2 channels (so you can hear what's on 0-1)
        Out.ar(0, [in[0], in[1]]);
    }.play;
    
    OSCdef(\inputMonitor, { |msg|
        var amps = msg[3..10];
        var maxAmp = amps.maxItem;
        var maxIdx = amps.indexOf(maxAmp);
        
        if(maxAmp > 0.001, {
            ("Ch " ++ maxIdx ++ " active: " ++ maxAmp.round(0.001) ++ 
             " | All: " ++ amps.collect({ |a| a.round(0.001) }).asString).postln;
        });
    }, '/inputAmp');
    
    "Testing... Speak into ESI interface and watch for channel activity".postln;
    "Press cmd+. to stop".postln;
});

