// Analyze B-format Channel Order
// Determines WXYZ vs other channel orders by analyzing characteristics

(
s.boot;

s.waitForBoot({
    var inputPath, inputFile;
    var buffer;
    var channelNames = ["Channel 0", "Channel 1", "Channel 2", "Channel 3"];
    var channelStats;
    
    // Configuration
    inputPath = Platform.userHomeDir ++ "/Downloads/openair_irs/";
    inputFile = "rir_jack_lyons_lp1_96k.wav";
    
    ("=== B-Format Channel Analysis ===").postln;
    ("File: " ++ inputPath ++ inputFile).postln;
    
    // Load the file
    buffer = Buffer.read(s, inputPath ++ inputFile, action: { |buf|
        ("=== File Analysis ===").postln;
        ("Channels: " ++ buf.numChannels).postln;
        ("Sample rate: " ++ buf.sampleRate ++ " Hz").postln;
        ("Duration: " ++ (buf.numFrames / buf.sampleRate).round(0.01) ++ " seconds").postln;
        ("Frames: " ++ buf.numFrames).postln;
        
        if(buf.numChannels == 4, {
            ("✓ Valid 4-channel B-format file").postln;
            
            // Analyze each channel
            channelStats = Array.newClear(4);
            
            // Load audio data for analysis
            buf.loadToFloatArray(action: { |array|
                ("=== Channel Analysis ===").postln;
                
                // Analyze each channel
                4.do({ |ch|
                    var channelData, rms, peak, dc, energy;
                    var startFrame, endFrame;
                    
                    // Extract channel data
                    channelData = FloatArray.newClear(buf.numFrames);
                    buf.numFrames.do({ |i|
                        channelData[i] = array[i * 4 + ch];
                    });
                    
                    // Calculate statistics
                    rms = (channelData.squared.mean.sqrt * 1000).round(0.1);
                    peak = (channelData.abs.maxItem * 1000).round(0.1);
                    dc = (channelData.mean * 1000).round(0.1);
                    energy = channelData.squared.sum;
                    
                    // Store stats
                    channelStats[ch] = (
                        rms: rms,
                        peak: peak,
                        dc: dc,
                        energy: energy
                    );
                    
                    ("Channel " ++ ch ++ ":").postln;
                    ("  RMS: " ++ rms ++ " (x1000)").postln;
                    ("  Peak: " ++ peak ++ " (x1000)").postln;
                    ("  DC: " ++ dc ++ " (x1000)").postln;
                    ("  Energy: " ++ energy.round(0.01)).postln;
                });
                
                ("=== B-Format Channel Identification ===").postln;
                
                // Find W channel (highest energy, omnidirectional)
                var wChannel = channelStats.maxIndex({ |stats| stats.energy });
                ("W (Omnidirectional) - Channel " ++ wChannel ++ 
                 " (Energy: " ++ channelStats[wChannel].energy.round(0.01) ++ ")").postln;
                
                // Find X channel (front-back, second highest energy)
                var remainingChannels = [0, 1, 2, 3].remove(wChannel);
                var xChannel = remainingChannels.maxIndex({ |ch| channelStats[ch].energy });
                xChannel = remainingChannels[xChannel];
                ("X (Front-Back) - Channel " ++ xChannel ++ 
                 " (Energy: " ++ channelStats[xChannel].energy.round(0.01) ++ ")").postln;
                
                // Find Y channel (left-right, third highest energy)
                remainingChannels = remainingChannels.remove(xChannel);
                var yChannel = remainingChannels.maxIndex({ |ch| channelStats[ch].energy });
                yChannel = remainingChannels[yChannel];
                ("Y (Left-Right) - Channel " ++ yChannel ++ 
                 " (Energy: " ++ channelStats[yChannel].energy.round(0.01) ++ ")").postln;
                
                // Find Z channel (up-down, lowest energy)
                remainingChannels = remainingChannels.remove(yChannel);
                var zChannel = remainingChannels[0];
                ("Z (Up-Down) - Channel " ++ zChannel ++ 
                 " (Energy: " ++ channelStats[zChannel].energy.round(0.01) ++ ")").postln;
                
                ("=== Channel Order Conclusion ===").postln;
                if(wChannel == 0 and: { xChannel == 1 } and: { yChannel == 2 } and: { zChannel == 3 }, {
                    ("✓ WXYZ order confirmed (Furse-Malham/ATK standard)").postln;
                }, {
                    ("⚠ Non-standard channel order detected").postln;
                    ("Expected: WXYZ (0,1,2,3)").postln;
                    ("Found: W=" ++ wChannel ++ ", X=" ++ xChannel ++ 
                     ", Y=" ++ yChannel ++ ", Z=" ++ zChannel).postln;
                    ("Channel reordering may be required").postln;
                });
                
                // Clean up
                buf.free;
            });
            
        }, {
            ("ERROR: Expected 4 channels, got " ++ buf.numChannels).postln;
            buf.free;
        });
    });
});
) 