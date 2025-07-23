// v19 with OpenAIR IR - Combined Script
// Loads v19 system and then immediately loads the OpenAIR IR

(
// First, load the v19 system
// (You'll need to copy the v19 content here or include it)

// Then load the OpenAIR IR
var irPath = "~/UHJ-Pi/assets/impulse-responses/b-format/rir_jack_lyons_lp1_96k_44k.wav";

// Wait a moment for v19 to initialize, then load OpenAIR IR
{
    // Check if the converted IR file exists
    if(File.exists(irPath.standardizePath), {
        ("✓ Found converted IR: " ++ irPath).postln;
        
        // Load the OpenAIR IR as a single multichannel buffer
        ~spatialIRBuffer = Buffer.read(s, irPath, action: { |buf|
            ("=== OpenAIR IR Loaded ===").postln;
            ("Channels: " ++ buf.numChannels).postln;
            ("Sample rate: " ++ buf.sampleRate ++ " Hz").postln;
            ("Duration: " ++ (buf.numFrames / buf.sampleRate).round(0.01) ++ " seconds").postln;
            ("Frames: " ++ buf.numFrames).postln;
            
            if(buf.numChannels == 4, {
                ("✓ Valid 4-channel B-format IR").postln;
                ("✓ Ready for v19 system").postln;
                
                // If v19 is running, we can update the IRs
                if(~spatialIRs.notNil, {
                    ("Updating v19 system with OpenAIR IR...").postln;
                    
                    // Free the old test IRs
                    ~spatialIRs.do({ |ir| if(ir.notNil) { ir.free; } });
                    
                    // Create new IR array with the OpenAIR IR
                    ~spatialIRs = [buf, buf, buf, buf]; // Use same buffer for all channels
                    
                    ("✓ v19 system updated with OpenAIR IR").postln;
                    ("✓ Convolution should now use Jack Lyons room").postln;
                }, {
                    ("v19 system not running - load v19 first").postln;
                });
                
            }, {
                ("ERROR: Expected 4 channels, got " ++ buf.numChannels).postln;
            });
        });
        
    }, {
        ("ERROR: Converted IR not found: " ++ irPath).postln;
        ("Run ffmpeg conversion first").postln;
    });
}.defer(2.0); // Wait 2 seconds for v19 to initialize
) 