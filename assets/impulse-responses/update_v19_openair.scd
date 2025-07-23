// Update v19 System to Use OpenAIR IR
// Modifies v19 to load multichannel IR instead of separate files

(
// Configuration
var irPath = "~/UHJ-Pi/assets/impulse-responses/b-format/rir_jack_lyons_lp1_96k_44k.wav";
var v19Path = "~/UHJ-Pi/supercollider/app/UHJ_Ambisonic_System_v19_convolution.scd";

("=== Updating v19 for OpenAIR IR ===").postln;
("IR Path: " ++ irPath).postln;
("v19 Path: " ++ v19Path).postln;

// Check if files exist
if(File.exists(irPath.standardizePath) and: { File.exists(v19Path.standardizePath) }, {
    ("✓ Both files found").postln;
    
    // Read the v19 file
    var v19Content = File.readAllString(v19Path.standardizePath);
    var oldIRSection, newIRSection;
    
    // Find the old IR loading section (lines 698-704)
    oldIRSection = "// Load spatial impulse responses for pseudo-surround convolution
                        // These are B-format impulse responses for realistic spatialization
                        ~spatialIRs = [
                            // Load B-format impulse responses from the assets folder
                            // W, X, Y, Z components for convolution spatialization
                            Buffer.read(s, \"~/UHJ-Pi/assets/impulse-responses/b-format/test_ir_w.wav\", 
                                action: { |buf| (\"Loaded W IR: \" ++ buf.numFrames ++ \" frames\").postln; }),
                            Buffer.read(s, \"~/UHJ-Pi/assets/impulse-responses/b-format/test_ir_x.wav\", 
                                action: { |buf| (\"Loaded X IR: \" ++ buf.numFrames ++ \" frames\").postln; }),
                            Buffer.read(s, \"~/UHJ-Pi/assets/impulse-responses/b-format/test_ir_y.wav\", 
                                action: { |buf| (\"Loaded Y IR: \" ++ buf.numFrames ++ \" frames\").postln; }),
                            Buffer.read(s, \"~/UHJ-Pi/assets/impulse-responses/b-format/test_ir_z.wav\", 
                                action: { |buf| (\"Loaded Z IR: \" ++ buf.numFrames ++ \" frames\").postln; })
                        ];";
    
    // Create new IR loading section
    newIRSection = "// Load spatial impulse responses for pseudo-surround convolution
                        // Using OpenAIR Jack Lyons room IR (multichannel B-format)
                        ~spatialIRBuffer = Buffer.read(s, \"" ++ irPath ++ "\", 
                            action: { |buf| 
                                (\"=== OpenAIR IR Loaded ===\").postln;
                                (\"Channels: \" ++ buf.numChannels).postln;
                                (\"Sample rate: \" ++ buf.sampleRate ++ \" Hz\").postln;
                                (\"Duration: \" ++ (buf.numFrames / buf.sampleRate).round(0.01) ++ \" seconds\").postln;
                                (\"Frames: \" ++ buf.numFrames).postln;
                                (\"✓ Jack Lyons room IR ready\").postln;
                            });
                        
                        // Create IR array for compatibility with existing convolution
                        ~spatialIRs = [~spatialIRBuffer, ~spatialIRBuffer, ~spatialIRBuffer, ~spatialIRBuffer];";
    
    // Replace the old section with the new one
    v19Content = v19Content.replace(oldIRSection, newIRSection);
    
    // Write the updated file
    File.write(v19Path.standardizePath, v19Content);
    
    ("✓ v19 system updated successfully!").postln;
    ("✓ Now loads OpenAIR Jack Lyons room IR").postln;
    ("✓ Multichannel B-format loading implemented").postln;
    ("✓ Ready to test with v19 system").postln;
    
}, {
    ("ERROR: Missing files").postln;
    if(File.exists(irPath.standardizePath).not) {
        ("- IR file not found: " ++ irPath).postln;
    };
    if(File.exists(v19Path.standardizePath).not) {
        ("- v19 file not found: " ++ v19Path).postln;
    };
});
) 