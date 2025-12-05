// ============================================================================
// UHJ v25_SF - PSEUDO-SURROUND ENCODER WITH UNIFIED SFPlayerMeter
// ============================================================================

// Using standard Knob class with custom 360-degree action handling
// Features automatic mouse/headtracker detection for intuitive control

var win, mainView,
    decoderChanged,
    lastInL, lastInR, minIn, maxIn,
    voltmp, cond, sndbuf, synth, inputs, outputs, configKeyD, configKeyE,
    dbValue, cliToDb, cliToDbMaster, formatDbValue;
// --- Overlay GUI variables (must be declared at the top, per GUIPrototype) ---
~eqOverlay = nil; ~ambienceOverlay = nil; ~layoutOverlay = nil; ~dimensionOverlay = nil;
~layoutTitleText = nil;
~eqBtn = nil; ~ambienceBtn = nil; ~layoutBtn = nil; ~dimensionBtn = nil;
// --- EQ overlay variables (from GUIPrototype) ---
~eqPresetMenu = nil; ~eqPresetNames = nil; ~eqPresetDict = nil; ~eqSliders = nil; ~eqValues = nil;
// --- Maplin overlay variables ---
~maplinSurroundKnob = nil; ~maplinEffectKnob = nil; ~maplinDelayKnob = nil; ~maplinActiveBtn = nil;
~maplinSurroundValue = nil; ~maplinEffectValue = nil; ~maplinDelayValue = nil;
// --- Dimension overlay variables ---
~dimensionWidthKnob = nil; ~dimensionWidthHPFKnob = nil; ~dimensionTrimKnob = nil;
~dimensionWidthValue = nil; ~dimensionWidthHPFValue = nil; ~dimensionTrimValue = nil;
~dimensionPresetMenu = nil; ~dimensionPresetNames = nil; ~dimensionPresetDict = nil;
~dimensionRowOverlay = nil; ~maplinRowOverlay = nil;
// --- Headtracker overlays ---
~knobOverlay = nil; ~htBtnOverlay = nil; ~htResetOverlay = nil; ~htPairOverlay = nil;                                                                                                                                                                                                                                                                                                                
// --- Headtracker pairing button reference ---
~headtrackPairBtn = nil;
// --- Headtracker MAC address (detected at startup) ---
~headtrackerMac = "bluetoothctl devices | grep 'HT' | awk '{print $2}'".unixCmdGetStdOut.stripWhiteSpace;
// --- Power button state ---
~powerBtnPressed = false;
// --- Player button state storage ---
~savedPlayerPlayState = -1; ~savedPlayerLoopState = -1;

Platform.case(
    \osx, { "Running on macOS".postln },
    \linux, { "Running on Linux".postln },
    \windows, { "Running on Windows".postln }
);
thisProcess.platform.name.postln;

// --- Default album configuration ---
// Change this to your preferred default album name (case-insensitive)
~preferredDefaultAlbum = "THE LONGEST DAY";

// Function to find smart default artist and album
~findSmartDefaults = {
    var isUSB = if(~sourceToggleBtn.notNil) { ~sourceToggleBtn.value == 1 } { false };
    var basePath, artists, foundArtist, foundAlbum;
    
    // Get base path based on source
    if(isUSB, {
        basePath = ~usbBasePath.value;
        if(basePath.isNil and: { Platform.name == \osx }, {
            basePath = "/Volumes/UHJ";
        });
        if(basePath.isNil, {
            basePath = Atk.userSoundsDir ++ "/uhj";
        });
    }, {
        basePath = Atk.userSoundsDir ++ "/uhj";
    });
    
    // Get available artists
    artists = PathName(basePath).entries.select { |entry| entry.isFolder };
    
    if(artists.isEmpty, {
        // No artists found
        foundArtist = nil;
        foundAlbum = "<NO ARTISTS>"
    }, {
        // Look for preferred album first
        foundArtist = nil;
        foundAlbum = nil;
        
        artists.do { |artist|
                var artistPath = artist.fullPath;
                var albums = PathName(artistPath).entries.select { |entry| entry.isFolder };
                var looseFiles = PathName(artistPath).entries.select { |entry| 
                    entry.isFile and: { 
                        var ext = entry.extension.asString.toLower;
                        (ext == "wav") or: (ext == "flac") or: (ext == "mp3") or: (ext == "aif") or: (ext == "aiff") or: (ext == "ogg") or: (ext == "m4a");
                    };
                };
                
                // Check if preferred album exists
                var preferredAlbum = albums.detect { |album| 
                    album.folderName.asString.toUpper == ~preferredDefaultAlbum.toUpper 
                };
                
                if(preferredAlbum.notNil, {
                    foundArtist = artist.folderName.asString.toUpper;
                    foundAlbum = preferredAlbum.folderName.asString.toUpper;
                }, {
                // No preferred album in this artist, use first available as fallback only if no preferred album found yet
                    if(foundArtist.isNil, {
                        foundArtist = artist.folderName.asString.toUpper;
                        if(albums.size > 0, {
                            foundAlbum = albums[0].folderName.asString.toUpper;
                        }, {
                            if(looseFiles.size > 0, {
                                foundAlbum = "<NO ALBUMS>";
                            }, {
                            foundAlbum = "<NO ARTISTS>";
                        });
                    });
                });
            });
        };
    });
    
    [foundArtist, foundAlbum];
};

// Find artwork file with priority search
~findArtworkFile = { |albumPath, currentTrackPath|
    var foundPath, artworkNames, extensions, entries;
    
    "findArtworkFile called with: ".post; albumPath.postln; currentTrackPath.postln;
    
    if(currentTrackPath.notNil, {
        "Trying FLAC artwork extraction...".postln;
        foundPath = ~findArtworkForTrack.value(currentTrackPath, albumPath);
        "FLAC artwork result: ".post; foundPath.postln;
        if(foundPath.notNil, {
            "findArtworkFile returning FLAC artwork: ".post; foundPath.postln;
            foundPath;
        });
    });
    
    if(foundPath.isNil, {
        artworkNames = ["artwork", "cover", "folder"];
        extensions = ["png", "jpg", "jpeg"];
        
        artworkNames.do { |name|
            extensions.do { |ext|
                if(foundPath.isNil, {
                    var testPath = albumPath +/+ (name ++ "." ++ ext);
                    if(File.exists(testPath), {
                        foundPath = testPath;
                    });
                });
            };
        };
        
        if(foundPath.isNil, {
            entries = PathName(albumPath).entries.select { |entry| 
                entry.isFile and: { 
                    var ext = entry.extension.asString.toLower;
                    (ext == "png") or: (ext == "jpg") or: (ext == "jpeg");
                };
            };
            if(entries.size > 0, {
                foundPath = entries[0].fullPath;
            });
        });
    });
    
    foundPath;
};

// --- AmbiVerbSC preset system variables ---
~ambiencePresetNames = nil; ~ambiencePresetDict = nil; ~ambiencePresetMenu = nil;

// --- Ambience state preservation variables ---
~ambienceState = Dictionary.newFrom([
    \sliderValues, [0.0, 0.2, 0.0, 0.2, 0.0, 0.0, 0.0],  // Height, HDelay, Reverb, RDelay, RSize, Spread, Target
    \presetIndex, 0,  // Default preset index
    \lastMix, 0.0,    // Remember last nonzero mix value
    \active, 0        // Reverb on/off state (0 = off, 1 = on)
]);
~ambienceLastMix = ~ambienceState[\lastMix];
~ambienceRestoring = false;

// --- ZSynth state preservation variables ---
~zsynthState = Dictionary.newFrom([
    \sliderValues, [0.3, 0.07, 0.5, 0.0, 0.625, 0.2, 0.7],
    \heightSource, 0,
    \presetIndex, 0
]);
~zsynthSliders = nil; ~zsynthValues = nil; ~zsynthPresetMenu = nil;

// --- EQ state preservation variables ---
~eqState = Dictionary.newFrom([
    \sliderValues, [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],  // Default values (0dB = 0.5)
    \presetIndex, 0   // Default preset index
]);

// --- Maplin state preservation variables ---
~maplinState = Dictionary.newFrom([
    \surround, 0.8,   // Surround level
    \effect, 0.8,     // Effect level
    \delay, 0.4,      // Delay amount
    \active, 0        // Active/bypass (default OFF - 1 = active, 0 = bypass)
]);
// --- Dimension processing state preservation variables ---
~dimensionActive = 0;  // Default OFF (1 = active, 0 = bypass)
~dimensionState = Dictionary.newFrom([
    \sliderValues, [0.0, 0.5, 0.5],  // width, widthHPF (normalized), outputTrim (normalized 0-1)
    \presetIndex, 0   // Default preset index
]);

// --- Stereo/Binaural layout state preservation variables ---
~stereoState = Dictionary.newFrom([
    \lOn, 1,
    \rOn, 1
]);

~binauralState = Dictionary.newFrom([
    \lOn, 1,
    \rOn, 1
]);

// --- Quad layout state preservation variables ---
~quadSquareState = Dictionary.newFrom([
    \flOn, 1,
    \frOn, 1,
    \rlOn, 1,
    \rrOn, 1
]);

~quadNarrowState = Dictionary.newFrom([
    \flOn, 1,
    \frOn, 1,
    \rlOn, 1,
    \rrOn, 1
]);

~quadWideState = Dictionary.newFrom([
    \flOn, 1,
    \frOn, 1,
    \rlOn, 1,
    \rrOn, 1
]);

// --- Dolby (5.1 / 5.1.2) state preservation variables ---
~dolbyState = Dictionary.newFrom([
    \centerGain, 0.0,
    \subGain, 0.0,
    \heightGain, 0.0,
    \flOn, 1,
    \frOn, 1,
    \rlOn, 1,
    \rrOn, 1,
    \centerOn, 1,
    \subOn, 1,
    \tflOn, 1,
    \tfrOn, 1,
    \subLPF, 120,
    \topHPF, 2000
]);

// --- Octagon layout state preservation variables ---
~octagonState = Dictionary.newFrom([
    \s1On, 1,
    \s2On, 1,
    \s3On, 1,
    \s4On, 1,
    \s5On, 1,
    \s6On, 1,
    \s7On, 1,
    \s8On, 1
]);

// --- Layout overlay helper references ---
~layoutDiagramView = nil;
~layoutTitleText = nil;
~stereoLeftHit = nil; ~stereoRightHit = nil;
~binauralLeftHit = nil; ~binauralRightHit = nil;
~quadSquareFLHit = nil; ~quadSquareFRHit = nil; ~quadSquareRLHit = nil; ~quadSquareRRHit = nil;
~quadNarrowFLHit = nil; ~quadNarrowFRHit = nil; ~quadNarrowRLHit = nil; ~quadNarrowRRHit = nil;
~quadWideFLHit = nil; ~quadWideFRHit = nil; ~quadWideRLHit = nil; ~quadWideRRHit = nil;
~dolbyFLSquareBtn = nil; ~dolbyFRSquareBtn = nil; ~dolbyRLSquareBtn = nil; ~dolbyRRSquareBtn = nil;
~dolbyCenterSquareBtn = nil; ~dolbySubSquareBtn = nil; ~dolbyTopLeftSquareBtn = nil; ~dolbyTopRightSquareBtn = nil;
~dolbyCenterGainSlider = nil; ~dolbySubGainSlider = nil; ~dolbyHeightGainSlider = nil;
~dolbyCenterGainLabel = nil; ~dolbySubGainLabel = nil; ~dolbyHeightGainLabel = nil;
~dolbyTopHpfSlider = nil; ~dolbyTopHpfLabel = nil; ~dolbyTopHpfValue = nil;
~dolbySubLpfSlider = nil; ~dolbySubLpfLabel = nil; ~dolbySubLpfValue = nil;
~dolbyHeightOverlay = nil; ~dolbyTopLpfOverlay = nil;
~octagonS1Hit = nil; ~octagonS2Hit = nil; ~octagonS3Hit = nil; ~octagonS4Hit = nil;
~octagonS5Hit = nil; ~octagonS6Hit = nil; ~octagonS7Hit = nil; ~octagonS8Hit = nil;

// --- Initial values for input section ---
// lastInL = 127; // Start at max (0dB)
// lastInR = 127; // Start at max (0dB)
// minIn = 0;   // ALSA: 0 = -60dB
// maxIn = 127; // ALSA: 127 = 0dB

// (ALSA input control removed for PLAYER)


// Audio engine initial values
voltmp = 1.0; // 0dB = 1.0 amplitude

// Encoder/Decoder configuration defaults
configKeyE = \uhj;      // Default encoder: UHJ
configKeyD = \stereo;   // Default decoder: Stereo
inputs = 2;             // Default input channels
outputs = 2;            // Default output channels

// Honest dB conversion - work with the hardware resolution we actually have
// cliToDb = { |cliValue|
//    var dbValue;
    // ALSA mapping: 0->-60dB, 127->0dB
//    dbValue = cliValue.linlin(0, 127, -60, 0);
    // Don't pretend we have 0.5dB resolution - round to 1dB which we can actually achieve
//    dbValue.round(1);
//};

// Master dB conversion function - just use the simple one
cliToDbMaster = { |cliValue|
    cliToDb.value(cliValue);
};

// Format dB value for consistent display (no need for .0 with whole numbers)
formatDbValue = { |dbValue|
    var intValue = dbValue.asInteger;
    if(intValue > 0) {
        "+" ++ intValue.asString;
    } {
        intValue.asString;
    };
};

// --- Window setup with platform-specific positioning ---
win = Window("UHJ Ambisonic System", Rect(0, 0, 800, 480), border: false).background_(Color.black);

// Create initialization overlay - full screen black semi-transparent with logo and "INITIALISING..." text
~initOverlay = View(win, Rect(0, 0, 800, 480))
    .background_(Color.black.alpha_(0.8))
    .alpha_(1.0)
    .front;

// Add UHJ-Pi-C logo (maintaining square aspect ratio)
~initLogo = UserView(~initOverlay, Rect(200, 80, 400, 200))
    .background_(Color.clear)
    .drawFunc_({ |view|
        try {
            var image = Image.open("assets/UHJ-Pi-180.png");
            if(image.notNil, {
                // Calculate square size that fits within the view bounds
                var maxSize = min(view.bounds.width, view.bounds.height);
                var xOffset = (view.bounds.width - maxSize) / 2;
                var yOffset = (view.bounds.height - maxSize) / 2;
                
                // Draw image maintaining square aspect ratio, centered
                image.drawInRect(Rect(xOffset, yOffset, maxSize, maxSize), 
                               Rect(0, 0, image.width, image.height), 2);
            });
        } { |error|
            // Fallback if logo fails to load
            Pen.color = Color.cyan;
            Pen.font = Font("Helvetica", 24);
            Pen.stringAtPoint("UHJ-Pi-C", Point(100, 40));
        };
    });

StaticText(~initOverlay, Rect(0, 292, 800, 30))
    .string_("PLAYER v1.0")
    .font_(Font("LCD 5x7 Segment Monospace", 20))
    .align_(\center)
    .stringColor_(Color.cyan)
    .background_(Color.clear);

~initText = StaticText(~initOverlay, Rect(0, 330, 800, 80))
    .string_("LOADING...")
    .font_(Font("LCD 5x7 Segment Monospace", 20))
    .align_(\center)
    .stringColor_(Color.cyan)
    .background_(Color.clear);

// Ensure server and interpreter quit when window is closed
win.onClose_({
    // Stop connection monitor and close pipe
    if(~connectionMonitor.notNil) { ~connectionMonitor.stop; };
    if(~bluetoothMonitorPipe.notNil) { ~bluetoothMonitorPipe.close; };
    if(s.serverRunning) { s.quit; };
    0.exit;
});

// Position at visible top-left corner
if(Platform.name == \osx, {
    win.bounds_(Rect(0, 25, 800, 480)); // Account for macOS menu bar
}, {
    // Check if we're likely on a Pi (no desktop environment) or desktop Ubuntu
    var isPi = (Platform.architecture == \arm) ||
               (thisProcess.platform.name == "linux" &&
                File.exists("/proc/device-tree/model"));

    if(isPi, {
        win.bounds_(Rect(0, 0, 800, 480)); // Pi: true (0,0) for full screen
    }, {
        win.bounds_(Rect(
            (Window.screenBounds.width - 800) / 2,
            (Window.screenBounds.height - 480) / 2,
            800, 480
        ));
    });
});
"UHJ-Pi: Centered on %x% screen".format(Window.screenBounds.width, Window.screenBounds.height).postln;
mainView = CompositeView(win, Rect(0, 0, 800, 480)).background_(Color.black);

// --- INPUT FADERS SECTION ---
StaticText(mainView, Rect(38, 10, 120, 28))
    .string_("FILE")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

// --- MINI PLAYER CONTROLS (derived from SFPlayer logic) ---
// Placed in the cleared FILE area
// Artist/Album menus feeding the file list

// Determine media root - default to UHJ directory for now
~getMediaRoot = {
    var root = Atk.userSoundsDir;
    var base, sub, result;
    ("Atk.userSoundsDir: " ++ root).postln;
    base = PathName(root);
    sub = "uhj"; // default to UHJ
    result = (base +/+ sub).fullPath;
    ("Media root result: " ++ result).postln;
    result;
};

// Build list of artist directories inside 'uhj'
~buildArtistList = {
    ["Rhombus", "Various", "Test Artist"]; // hardcoded for now to test
};

// Build album list for currently selected artist
~buildAlbumList = {
    ["The Longest Day"]; // hardcoded for now to test
};

// FLAC metadata functions
~getFLACMetadata = { |filePath|
    var command, output, lines, metadata, line, key, value, colonIndex;
    command = "metaflac --export-tags-to=- \"" ++ filePath ++ "\" 2>/dev/null";
    output = unixCmdGetStdOut(command);
    if(output.isEmpty, { ^nil });
    
    lines = output.split($\n);
    metadata = Dictionary.new;
    
    lines.do { |line|
        if(line.notEmpty, {
            colonIndex = line.find("=");
            if(colonIndex.notNil, {
                key = line.copyRange(0, colonIndex - 1);
                value = line.copyRange(colonIndex + 1, line.size - 1);
                metadata.put(key, value);
            });
        });
    };
    
    metadata;
};

~getFLACTrackNumber = { |filePath|
    var metadata, trackNumber, slashIndex;
    metadata = ~getFLACMetadata.value(filePath);
    if(metadata.isNil, { ^nil });
    
    trackNumber = metadata["TRACKNUMBER"];
    if(trackNumber.isNil, { ^nil });
    
    slashIndex = trackNumber.find("/");
    if(slashIndex.notNil, {
        trackNumber = trackNumber.copyRange(0, slashIndex - 1);
    });
    
    trackNumber.asInteger;
};

~extractFLACArtwork = { |filePath, outputPath|
    // Extract artwork from FLAC file using metaflac
    var command, success;
    command = "metaflac --export-picture-to=\"" ++ outputPath ++ "\" \"" ++ filePath ++ "\" 2>/dev/null && echo 'SUCCESS'";
    // Use unixCmdGetStdOut and check if SUCCESS is in output or file exists
    success = (unixCmdGetStdOut(command).contains("SUCCESS")) or: File.exists(outputPath);
    success;
};
~findArtworkForTrack = { |currentTrackPath, albumPath|
    // Find artwork with priority: track -> album -> folder -> default
    var artworkPath, tempPath, firstFlacPath, folderArtwork, result;
    
    "findArtworkForTrack called with: ".post; currentTrackPath.postln; albumPath.postln;
    
    result = nil;
    tempPath = "/tmp/track_artwork.jpg";
    
    // 1. Try current track artwork
    if(result.isNil and: File.exists(currentTrackPath) and: { 
        var ext = PathName(currentTrackPath).extension.asString.toLower;
        ext == "flac";
    }, {
        "Trying to extract from current FLAC track...".postln;
        if(~extractFLACArtwork.value(currentTrackPath, tempPath), {
            "SUCCESS: Extracted artwork from current track".postln;
            "Returning artwork path: ".post; tempPath.postln;
            result = tempPath;
        }, {
            "FAILED: Could not extract from current track".postln;
        });
    }, {
        "Current track is not FLAC or doesn't exist".postln;
    });
    
    // 2. Try first FLAC file in album
    if(result.isNil and: File.exists(albumPath), {
        var pn = PathName(albumPath);
        var flacFiles = pn.entries.select { |f| 
            f.isFile and: { f.extension.asString.toLower == "flac" };
        };
        if(flacFiles.size > 0, {
            firstFlacPath = flacFiles[0].fullPath;
            "Trying to extract from first FLAC in album: ".post; firstFlacPath.postln;
            if(~extractFLACArtwork.value(firstFlacPath, tempPath), {
                "SUCCESS: Extracted artwork from first FLAC in album".postln;
                result = tempPath;
            }, {
                "FAILED: Could not extract from first FLAC in album".postln;
            });
        });
    });
    
    // 3. Try folder artwork (cover.jpg, folder.jpg, etc.)
    if(result.isNil and: File.exists(albumPath), {
        var pn = PathName(albumPath);
        var imageFiles = pn.entries.select { |f| 
            f.isFile and: { 
                var ext = f.extension.asString.toLower;
                (ext == "jpg") or: (ext == "jpeg") or: (ext == "png") or: (ext == "gif") or: (ext == "bmp");
            };
        };
        // Look for common artwork filenames
        folderArtwork = imageFiles.detect { |f|
            var name = f.fileNameWithoutExtension.asString.toLower;
            (name == "cover") or: (name == "folder") or: (name == "album") or: (name == "artwork");
        };
        if(folderArtwork.notNil, {
            "SUCCESS: Found folder artwork: ".post; folderArtwork.fullPath.postln;
            result = folderArtwork.fullPath;
        }, {
            // If no specific artwork file, use first image
            if(imageFiles.size > 0, {
                "SUCCESS: Found generic folder image: ".post; imageFiles[0].fullPath.postln;
                result = imageFiles[0].fullPath;
            });
        });
    });
    
    // 4. Return result (nil if no artwork found, will fall back to UHJ-Pi default)
    if(result.isNil, {
        "No artwork found".postln;
    }, {
        "FINAL RESULT: ".post; result.postln;
    });
    result;
};
// Artist and Album menus (will be created after window is visible)



// Set initial values (moved to after menu creation)
~buildFileList = {
    // Build file list based on current artist and album selection
    var artistName, albumName, albumPath, pn, files, paths, audioExtensions, ext;
    
    // Get current selections directly from menus
    artistName = if(~artistMenu.notNil) { ~artistMenu.items[~artistMenu.value] } { "RHOMBUS" };
    albumName = if(~albumMenu.notNil) { ~albumMenu.items[~albumMenu.value] } { "THE LONGEST DAY" };
    
    "Building file list for: ".post; artistName.post; " / ".post; albumName.postln;
    
    // Use the buildAlbumPath function to get the correct path for both ATK and USB
    albumPath = ~buildAlbumPath.value;
    
    // Safety check - if buildAlbumPath returns nil, use fallback
    if(albumPath.isNil, {
        albumPath = "/tmp/";
    });
    
    pn = PathName(albumPath);
    if(pn.isFolder.not) { ~filePaths = []; ^["(no files)"]; };
    
    // Filter for audio files only, then hide extensions in display
    files = pn.entries.select({ |f| 
        f.isFile and: { 
            ext = f.extension.asString.toLower;
            (ext == "wav") or: (ext == "flac") or: (ext == "mp3") or: (ext == "aif") or: (ext == "aiff") or: (ext == "ogg") or: (ext == "m4a");
        };
    });

    // Sort files by FLAC track number if available, otherwise by filename
    files = files.sort({ |a, b|
        var aTrack, bTrack, aExt, bExt;
        aExt = a.extension.asString.toLower;
        bExt = b.extension.asString.toLower;
        
        // Check if both files are FLAC
        if((aExt == "flac") and: (bExt == "flac"), {
            aTrack = ~getFLACTrackNumber.value(a.fullPath);
            bTrack = ~getFLACTrackNumber.value(b.fullPath);
            
            // If both have track numbers, sort by track number
            if((aTrack.notNil) and: (bTrack.notNil), {
                aTrack < bTrack;
            }, {
                // If only one has track number, it comes first
                if(aTrack.notNil, { true }, {
                    if(bTrack.notNil, { false }, {
                        // Neither has track number, sort alphabetically
                        a.fileName.asString.toLower < b.fileName.asString.toLower;
                    });
                });
            });
        }, {
            // Not both FLAC files, sort alphabetically
            a.fileName.asString.toLower < b.fileName.asString.toLower;
        });
    });
    
    // Store sorted file paths after sorting
    ~filePaths = files.collect(_.fullPath);
    
    // Extract display names (hide extensions)
    files.collect({ |f| 
        var name = f.fileName.asString;
        var ext = f.extension;
        if(ext.notNil, {
            var endIdx = name.size - ext.asString.size - 2;
            if(endIdx >= 0, { name.copyRange(0, endIdx) }, { name });
        }, { name });
    });
};
// Thin cyan border first, then file list above it (to keep list clickable)
// Up/Down buttons flanking the file list vertically
// Up button: full width of file picker, positioned higher due to single menu
~trackUpBtn = Button(mainView, Rect(28, 169, 140, 29))
    .states_([["▲", Color.cyan, Color.black], ["▲", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 18).boldVariant)
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({
        if(~fileList.notNil) {
            var currentIdx = ~fileList.value ? 0;
            var newIdx = (currentIdx - 1).max(0);
            ~fileList.value_(newIdx);
        };
        { ~trackUpBtn.value_(0); }.defer(0.1);
    });

// Scrollable file list with hidden scrollbars - moved up due to single menu
~fileListScrollView = ScrollView(mainView, Rect(28, 198, 140, 155))
    .background_(Color.black)
    .autohidesScrollers_(false)
    .focusColor_(Color.clear)
    .canFocus_(false)
    .canvas_(
        ListView()
            .fixedHeight_(155)
            .items_(~buildFileList.value)
            .font_(Font("Arial", 12))
            .focusColor_(Color.clear)
            .action_({ |view|
                // Refresh artwork when track selection changes
                if(~playerArtwork.notNil, { ~playerArtwork.refresh; });
            })
            .background_(Color.black)
            .stringColor_(Color.cyan)
            .selectedStringColor_(Color.black)
            .hiliteColor_(Color.cyan)
            .canFocus_(false)
                .selectionAction_({ |view|
                    var idx = view.value ? -1;
                    if(idx >= 0 and: { ~filePaths.notNil and: { idx < ~filePaths.size } }, {
                        var path = ~filePaths[idx];
                    ~resetTransportState.value(idx, path);
                    });
                })
    );

// Scrollbars are persistent - may need to accept them or use custom approach

~fileList = ~fileListScrollView.canvas;

// Down button: full width of file picker, positioned beneath the expanded picker
~trackDownBtn = Button(mainView, Rect(28, 353, 140, 29))
    .states_([["▼", Color.cyan, Color.black], ["▼", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 18).boldVariant)
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({
        if(~fileList.notNil) {
            var currentIdx = ~fileList.value ? 0;
            var maxIdx = ~fileList.items.size - 1;
            var newIdx = (currentIdx + 1).min(maxIdx);
            ~fileList.value_(newIdx);
        };
        { ~trackDownBtn.value_(0); }.defer(0.1);
    });

// Time display removed from main screen - now in PLAYER panel

// Function to format time in MM:SS
~formatTime = { |seconds|
    var mins, secs;
    // Safety check for nil values
    if(seconds.isNil, { seconds = 0 });
    // Ensure we have a clean integer value
    seconds = seconds.asFloat;
    mins = (seconds / 60).floor.asInteger;
    secs = (seconds % 60).floor.asInteger;
    if(mins < 10) { mins = "0" ++ mins.asString } { mins = mins.asString };
    if(secs < 10) { secs = "0" ++ secs.asString } { secs = secs.asString };
    mins ++ ":" ++ secs;
};
// Timer synced with play button
~playStartTime = 0;
~pausedTime = 0;
~isPlaying = false;

~updateTimeDisplay = {
    if(~sfp.notNil and: { ~playerTimeDisplay.notNil }, {
        var elapsed, total, elapsedStr, totalStr;
        if(~isPlaying, {
            if(~playStartTime == 0, { ~playStartTime = SystemClock.seconds; });
            elapsed = (SystemClock.seconds - ~playStartTime) + ~pausedTime;
        }, {
            if(~playStartTime > 0, {
                ~pausedTime = ~pausedTime + (SystemClock.seconds - ~playStartTime);
                ~playStartTime = 0;
            });
            elapsed = ~pausedTime;
        });
        total = if(~sfp.sf.notNil and: { ~sfp.sf.duration.notNil }) { ~sfp.sf.duration } { 0 };
        elapsedStr = ~formatTime.value(elapsed);
        totalStr = ~formatTime.value(total);
        
        // Check for track end or loop
        if(~isPlaying and: { total > 0 and: { elapsed >= total } }, {
            // Track has ended
            if(~sfp.loop.not, {
                // Loop is off - advance to next track
                if(~fileList.notNil and: { ~filePaths.notNil }, {
                    var currentIdx = ~fileList.value ? 0;
                    var nextIdx = currentIdx + 1;
                    if(nextIdx < ~filePaths.size, {
                        // Load next track
                        var nextPath = ~filePaths[nextIdx];
                        // Load the next track directly
                        ~sfp.load(nextPath);
                        ~fileList.value_(nextIdx);
                        // Reset timer state for new track
                        ~playStartTime = SystemClock.seconds;
                        ~pausedTime = 0;
                        // Update slider position
                        if(~playerPositionSlider.notNil, {
                            ~playerPositionSlider.value_(0);
                        });
                        // Wait a moment for the track to load, then continue playing from beginning
                        AppClock.sched(0.1, {
                            if(~sfp.notNil, {
                                ~sfp.startTime = 0; // Ensure we start from beginning
                                ~sfp.play;
                                // Ensure our internal state is correct
                                ~isPlaying = true;
                                ~playerPlayBtn.value_(0); // Play state
                            });
                            nil; // Don't reschedule
                        });
                    }, {
                        // No more tracks - stop playback
                        ~sfp.pause;
                        ~isPlaying = false;
                        ~playerPlayBtn.value_(1); // Pause state
                    });
                });
            }, {
                // Loop is on - reset timer and slider to beginning
                ~playStartTime = SystemClock.seconds;
                ~pausedTime = 0;
                if(~playerPositionSlider.notNil, {
                    ~playerPositionSlider.value_(0);
                });
            });
        });
        
        // Update player time display
        if(~playerTimeDisplay.notNil, {
            ~playerTimeDisplay.string_(elapsedStr ++ " / " ++ totalStr);
        });
        
        if(~playerPositionSlider.notNil and: { total > 0 }, {
            // Only update slider if we're not in the middle of a user drag
            // Check if slider value is significantly different from calculated position
            var calculatedPos = elapsed / total;
            var currentSliderPos = ~playerPositionSlider.value;
            // Only update if the difference is significant (not user dragging)
            // Check that currentSliderPos is not nil before doing the calculation
            if(currentSliderPos.notNil and: { (calculatedPos - currentSliderPos).abs < 0.01 }, {
                ~playerPositionSlider.value_(calculatedPos);
            });
        });
    });
};

// Task to update time display more frequently using AppClock
~timeUpdateTask = AppClock.sched(0, {
    ~updateTimeDisplay.value;
    0.1; // return 0.1 second for next scheduling (10 times per second)
});

~resetTransportState = { |targetIdx, targetPath|
    var path, index, currentSelection;
    
    path = targetPath;
    index = targetIdx;
    
    if(path.isNil) {
        if(index.isNil) {
            index = if(~fileList.notNil, { ~fileList.value ? 0 }, { 0 });
        };
        if(~filePaths.notNil and: { ~filePaths.size > 0 }) {
            index = (index ? 0).clip(0, ~filePaths.size - 1);
            path = ~filePaths[index];
            if(~fileList.notNil) {
                currentSelection = ~fileList.value ? -1;
                if(currentSelection != index) {
                    ~fileList.value_(index);
                };
            };
        };
    };
    
    if(~sfp.notNil) {
        ~sfp.stop;
        if(path.notNil) {
            ~sfp.load(path);
        };
        ~sfp.loop = false;
    };
    
    ~playStartTime = 0;
    ~pausedTime = 0;
    ~isPlaying = false;
    
    ~savedPlayerPlayState = 1;
    ~savedPlayerLoopState = 0;
    
    if(~playerPlayBtn.notNil) { ~playerPlayBtn.value_(1); };
    if(~playerLoopBtn.notNil) { ~playerLoopBtn.value_(0); };
    if(~playerPositionSlider.notNil) { ~playerPositionSlider.value_(0); };
    
    if(~playerOverlay.notNil or: { ~playerTimeDisplay.notNil }) {
        {
            ~updateTimeDisplay.value;
            if(~playerOverlay.notNil) { ~playerOverlay.refresh; };
        }.defer(0.1);
    };
};

// ~fileList.front; // ensure on top of border

// Helper to locate mounted UHJ USB volume (case-insensitive, handles spaces)
~usbBasePath = {
    var path, searchRoots, found, volumes, userVolumes, uhjEntry;
    var platform = thisProcess.platform.name;
    ("~usbBasePath evaluating for platform: " ++ platform.asString).postln;
    if(platform == \linux, {
        searchRoots = [
            "/media/" ++ Platform.userHomeDir.basename ++ "/",
            "/media/pi/",
            "/mnt/",
            "/media/"
        ];
        searchRoots.do { |root|
            if(found.isNil and: { File.exists(root) }, {
                var dirs = PathName(root).entries.select { |entry|
                    entry.isFolder and: {
                        entry.folderName != "root" and:
                        entry.folderName != Platform.userHomeDir.basename and:
                        entry.folderName != "pi" and:
                        PathName(entry.fullPath).entries.size > 0
                    }
                };
                if(dirs.size > 0) {
                    found = dirs[0].fullPath;
                };
            });
        };
        path = found;
    }, {
        volumes = PathName("/Volumes").entries.select { |entry| entry.isFolder };
        userVolumes = volumes.reject { |entry|
            var name = entry.folderName.asString;
            name.beginsWith(".") or: {
                [
                    Platform.userHomeDir.basename.asString,
                    "Macintosh HD",
                    "MacintoshHD",
                    "Time Machine",
                    "TimeMachine",
                    "Preboot",
                    "Recovery"
                ].includes(name) or: { entry.fullPath == "/" }
            }
        };
        uhjEntry = userVolumes.detect { |entry| entry.folderName.asString.toLower.beginsWith("uhj") };
        if(uhjEntry.notNil) {
            path = uhjEntry.fullPath;
        };
        if(path.isNil and: { File.exists("/Volumes/UHJ") }) {
            path = "/Volumes/UHJ";
        };
        if(path.isNil and: { File.exists("/Volumes/uhj") }) {
            path = "/Volumes/uhj";
        };
    });
    ("~usbBasePath returning: " ++ (path ? "nil")).postln;
    path;
};

// Function to get USB folder options
~getUSBFolderOptions = {
    var usbBase = ~usbBasePath.value;
    var folders;
    var usbEntries;
    
    if(usbBase.isNil and: { Platform.name == \osx }, {
        usbBase = "/Volumes/UHJ";
    });
    
    if(usbBase.isNil, {
        folders = ["<NO DRIVE>"];
    }, {
        // USB drive found - use the first folder inside the drive as content directory
        folders = [];
            if(File.exists(usbBase), {
                usbEntries = PathName(usbBase).entries.select { |entry|
                    entry.isFolder and: { entry.folderName.asString.beginsWith(".").not }
                };
                usbEntries.do { |entry|
                    folders = folders.add(entry.folderName.asString.toUpper);
                };
    });
    });
    
    folders;
};
// Function to get ATK folder options (mirror USB scan on local ATK tree)
~getATKFolderOptions = {
    var atkBase = Atk.userSoundsDir ++ "/uhj";
    var folders;
    var atkEntries;
    
    if(File.exists(atkBase).not, {
        // No ATK directory found
        folders = ["<NO DRIVE>"];
    }, {
        // ATK directory found - look inside it for artist folders
        folders = [];
        if(File.exists(atkBase), {
            // Look inside the ATK directory for actual content folders
            atkEntries = PathName(atkBase).entries.select { |entry| entry.isFolder };
            atkEntries.do { |entry|
                folders = folders.add(entry.folderName.asString.toUpper);
            };
        });
    });
    
    folders;
};
// Function to build current album path
~buildAlbumPath = {
    var artistName, albumName, albumPath, isUSB;
    
    // Check if we're in USB mode
    isUSB = if(~sourceToggleBtn.notNil) { ~sourceToggleBtn.value == 1 } { false };
    
    artistName = if(~artistMenu.notNil) { ~artistMenu.items[~artistMenu.value] } { "RHOMBUS" };
    albumName = if(~albumMenu.notNil) { ~albumMenu.items[~albumMenu.value] } { "THE LONGEST DAY" };
    
    // Safety check - if menus aren't ready yet, use defaults
    if(artistName.isNil, { artistName = "RHOMBUS"; });
    if(albumName.isNil, { albumName = "THE LONGEST DAY"; });
    
    // Build path based on source and selections
    if(isUSB, {
        // USB mode - resolve content directory first
        var usbBase = ~usbBasePath.value;
        if(usbBase.isNil and: { Platform.name == \osx }, {
            usbBase = "/Volumes/UHJ";
        });
        if(usbBase.isNil or: { artistName == "<NO DRIVE>" }, {
            albumPath = "/tmp/"; // fallback path
        }, {
            var usbEntries = PathName(usbBase).entries.select { |entry| entry.isFolder };
            var actualArtistName = usbEntries.detect { |entry|
                entry.folderName.asString.toUpper == artistName
            };
            var artistPath = if(actualArtistName.notNil) { actualArtistName.fullPath } { usbBase +/+ artistName };
            if(albumName == "<NO ALBUMS>", {
                // No album folders, just files in artist folder
                albumPath = artistPath +/+ "/";
            }, {
                var albumEntries = PathName(artistPath).entries.select { |entry| entry.isFolder };
                var actualAlbumName = albumEntries.detect { |entry|
                    entry.folderName.asString.toUpper == albumName
                };
                var actualAlbumPath = if(actualAlbumName.notNil) { actualAlbumName.fullPath } { artistPath +/+ albumName };
                albumPath = actualAlbumPath +/+ "/";
            });
        });
    }, {
        // ATK mode - use same logic as USB
        var atkBase = Atk.userSoundsDir ++ "/uhj";
        if(artistName == "<NO DRIVE>", {
            albumPath = "/tmp/"; // fallback path
            }, {
                // Find actual artist folder by case-insensitive matching
                var actualArtistName = PathName(atkBase).entries.select { |entry| entry.isFolder }.detect { |entry| 
                    entry.folderName.asString.toUpper == artistName 
                };
                var actualArtistPath = if(actualArtistName.notNil) { actualArtistName.fullPath } { atkBase +/+ artistName };
                
                if(albumName == "<NO ALBUMS>", {
                    // No album folders, just files in artist folder
                    albumPath = actualArtistPath +/+ "/";
                }, {
                    // Find actual album folder by case-insensitive matching
                    var actualAlbumName = PathName(actualArtistPath).entries.select { |entry| entry.isFolder }.detect { |entry| 
                        entry.folderName.asString.toUpper == albumName 
                    };
                    var actualAlbumPath = if(actualAlbumName.notNil) { actualAlbumName.fullPath } { actualArtistPath +/+ albumName };
                    albumPath = actualAlbumPath +/+ "/";
            });
        });
    });
    
    // Final safety check - ensure we always return a valid path
    albumPath ? "/tmp/";
};


// Initialize current album path and ensure file list populates after GUI is up
{ 
    ~currentAlbumPath = ~buildAlbumPath.value;
    if(~fileList.notNil, { ~fileList.items_(~buildFileList.value); });
    if(~albumArtwork.notNil, { ~albumArtwork.refresh; });
}.defer(0.6);

// Transport buttons removed from main screen - now only in PLAYER panel

// (Removed old small up/down buttons)

// (Forward button removed)

// Set file menu to current track if present in list (without reloading)
{
    if(~sfp.notNil and: { ~sfp.path.notNil and: { ~fileList.notNil and: { ~filePaths.notNil } } }, {
        var cur = PathName(~sfp.path).fileName.asString;
        var idx = ~filePaths.detectIndex({ |p| p.fileName.asString == cur });
        if(idx.notNil and: { idx >= 0 }, { ~fileList.value_(idx); });
    });
}.defer(1.0);

// Input faders removed in PLAYER

// Mouse up action for CLI commands (MainApp2 functionality)




// --- ENCODER/DECODER MENUS ---
StaticText(mainView, Rect(180, 10, 154, 28))
    .string_("ENCODER")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

StaticText(mainView, Rect(346, 10, 154, 28))
    .string_("DECODER")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

// Encoder menu (Input format selection)
~emenu = EZPopUpMenu.new(
    mainView,
    Rect(180, 45, 154, 35),
    "",
    [
        \UHJ -> { |a| configKeyE = \uhj; inputs = 2; ("Encoder: UHJ (2-channel)").postln; },
        \SUPERSTEREO -> { |a| configKeyE = \superstereo; inputs = 2; ("Encoder: SUPERSTEREO (2-channel)").postln; },
        \MAPLIN -> { |a| configKeyE = \maplin; inputs = 2; ("Encoder: MAPLIN (2-channel)").postln; },
        \PHJ -> { |a| configKeyE = \phj; inputs = 4; ("Encoder: PHJ (4-channel input: L,R,T,Q)").postln; }
    ],
    globalAction: { |menu|
        // Update maplinMode on existing synth if it exists
        if(~synth.notNil) {
            ~synth.set(\maplinMode, if(configKeyE == \maplin, 1, 0));
            ("Updated maplinMode to: " ++ if(configKeyE == \maplin, 1, 0)).postln;
        };
        
            if(configKeyE == \maplin) {
            ~maplinState[\active] = 1;
            ~dimensionActive = 1;
            ~setMaplinActive.(true);
            if(~maplinActiveBtn.notNil) {
                ~maplinActiveBtn.value_(0);
            };
            if(~synth.notNil) {
                ~synth.set(
                    \maplinSurround, ~maplinState[\surround] ? 0.8,
                    \maplinEffect, ~maplinState[\effect] ? 0.8,
                    \maplinDelay, ~maplinState[\delay] ? 0.4,
                    \maplinActive, 1
                );
                ("Maplin parameters sent to synth: surround=" ++ (~maplinState[\surround] ? 0.8) ++ ", effect=" ++ (~maplinState[\effect] ? 0.8) ++ ", delay=" ++ (~maplinState[\delay] ? 0.4) ++ ", active=1").postln;
            };
        } {
            if(~synth.notNil) {
                ~synth.set(\dimensionActive, ~dimensionActive ? 1);
            };
        };
        
        ("Selected encoder: " ++ menu.item).postln;

        ~updateDimensionOverlayVisibility.value();
        
        if(configKeyE == \maplin and: { ~dimensionOverlay.notNil and: { ~maplinSurroundKnob.notNil } }) {
            ~maplinSurroundKnob.action.value(~maplinSurroundKnob);
            ~maplinEffectKnob.action.value(~maplinEffectKnob);
            ~maplinDelayKnob.action.value(~maplinDelayKnob);
            ("Maplin knobs updated for Maplin encoder").postln;
        };

        // Save current synth parameters before reinitializing
        ~saveSynthParams.value();
        // Always call audio engine init; it will reload only if needed
        ~initAudioEngine.value();
    },
    initVal: 0,
    initAction: false,
    labelWidth: 0,
    labelHeight: 0,
    layout: \horz,
    gap: 0@0
);
// Function to detect available JACK outputs and build decoder menu
~buildDecoderMenu = {
    var availableOutputs, decoderItems, platform;
    
    platform = thisProcess.platform.name;
    if(platform == \osx) {
        availableOutputs = 8;
        "macOS detected – assuming 8 output channels".postln;
    } {
    availableOutputs = "jack_lsp | grep 'system:playback' | wc -l".unixCmdGetStdOut.asInteger;
    if(availableOutputs == 0) {
        availableOutputs = 2;
        ("Warning: Could not detect JACK outputs, assuming stereo").postln;
        };
    };
    
    ("Detected " ++ availableOutputs ++ " output channels").postln;
    
    // Build decoder list based on available outputs
    decoderItems = [];
    
    // Always available: 2-channel decoders
    decoderItems = decoderItems ++ [
        \STEREO -> { |a| inputs = 2; outputs = 2; configKeyD = \stereo; },
        \BINAURAL ++ " IRCAM" -> { |a| inputs = 2; outputs = 2; configKeyD = \binaural; },
        \BINAURAL ++ " CIPIC" -> { |a| inputs = 2; outputs = 2; configKeyD = \binaurac; }
    ];
    
    // Add 4-channel decoders if 4+ outputs available
    if(availableOutputs >= 4) {
        decoderItems = decoderItems ++ [
            \QUAD ++ " SQUARE" -> { |a| inputs = 2; outputs = 4; configKeyD = \quadsquare; },
            \QUAD ++ " NARROW" -> { |a| inputs = 2; outputs = 4; configKeyD = \quadnarrow; },
            \QUAD ++" WIDE" -> { |a| inputs = 2; outputs = 4; configKeyD = \quadwide; }
        ];
    };
    
    // Add 6-channel decoder if 6+ outputs available
    if(availableOutputs >= 6) {
        decoderItems = decoderItems ++ [
            \DOLBY ++" 5.1" -> { |a| inputs = 2; outputs = 6; configKeyD = \fivezero; }
        ];
    };
    
    // Add 8-channel decoder if 8+ outputs available
    if(availableOutputs >= 8) {
        decoderItems = decoderItems ++ [
            \DOLBY ++" 5.1.2" -> { |a| inputs = 2; outputs = 8; configKeyD = \fiveonetwo; },
            \OCTAGON -> { |a| inputs = 2; outputs = 8; configKeyD = \octagon; }
        ];
    };
    
    decoderItems;
};
// Decoder menu (Output format selection) - dynamically built
~dmenu = EZPopUpMenu.new(
    mainView,
    Rect(346, 45, 154, 35),
    "",
    ~buildDecoderMenu.value,
    globalAction: { |menu|
        var idx, decoderNames, decoderName, htIsOff, isBinaural, shouldDim, needRebuild;
        // --- Reset headtracking and quad panner settings on decoder change ---
        if(~headtrackBtn.notNil) { ~headtrackBtn.value_(0); };
        if(~rotateKnob.notNil) { ~rotateKnob.valueAction_(0.5); };
        if(~tiltKnob.notNil) { ~tiltKnob.valueAction_(0.5); };
        if(~tumbleKnob.notNil) { ~tumbleKnob.valueAction_(0.5); };
        if(~xyPanner.notNil) {
            ~xyPanner.x_(0.5); ~xyPanner.y_(0.5);
            ~xyPannerPos = Point(0.5, 0.5);
        };
        idx = menu.value;
        decoderNames = ["STEREO", "BINAURAL IRCAM", "BINAURAL CIPIC", "QUAD SQUARE", "QUAD NARROW", "QUAD WIDE", "DOLBY 5.1", "DOLBY 5.1.2", "OCTAGON"];
        decoderName = decoderNames[idx];
        htIsOff = (~headtrackBtn.notNil and: { ~headtrackBtn.value == 0 });
        isBinaural = (idx == 1) or: { idx == 2 };
        shouldDim = (idx == 3 or: { idx == 4 } or: { idx == 5 } or: { idx == 6 } or: { idx == 7 });

        // --- Overlay/enable logic for headtracker controls ---
        if(~knobOverlay.notNil) { ~knobOverlay.remove; ~knobOverlay = nil; };
        if(~htBtnOverlay.notNil) { ~htBtnOverlay.remove; ~htBtnOverlay = nil; };
        if(~htResetOverlay.notNil) { ~htResetOverlay.remove; ~htResetOverlay = nil; };
        if(~xyPannerOverlay.notNil) { ~xyPannerOverlay.remove; ~xyPannerOverlay = nil; };

        if(isBinaural) {
            ~headtrackBtn.enabled_(true);
            ~headtrackResetBtn.enabled_(true);
            if(~headtrackPairBtn.notNil) { ~headtrackPairBtn.enabled_(true); };
            if(~htPairOverlay.notNil) { ~htPairOverlay.remove; ~htPairOverlay = nil; };
            if(htIsOff) {
                // Headtracking OFF: disable controls and hide reset button
                ~headtrackResetBtn.enabled_(false);
                ~rotateKnob.enabled_(false);
                ~tiltKnob.enabled_(false);
                ~tumbleKnob.enabled_(false);
                ~knobOverlay = View(mainView, Rect(594, 60, 147, 224)) // width was 145, now 147
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
                ~htResetOverlay = View(mainView, Rect(734, 102, 51, 20)) // Cover RESET button, extended 3px right
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
            } {
                ~rotateKnob.enabled_(true);
                ~tiltKnob.enabled_(true);
                ~tumbleKnob.enabled_(true);
            };
        } {
            // Non-binaural modes
            ~headtrackBtn.enabled_(false);
            if(~headtrackPairBtn.notNil) { ~headtrackPairBtn.enabled_(false); };
            ~rotateKnob.enabled_(false);
            ~tiltKnob.enabled_(false);
            ~tumbleKnob.enabled_(false);
            // Dim PAIR button with overlay matching reset/knob overlay style
            if(~htPairOverlay.notNil) { ~htPairOverlay.remove; ~htPairOverlay = nil; };
            ~htPairOverlay = View(mainView, Rect(742, 142, 40, 20))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
            
            if((idx == 3) or: { idx == 4 } or: { idx == 5 }) {
                // Quad modes: reset button visible for panner control
                ~headtrackResetBtn.enabled_(true);
                // Hide knobs and ON/OFF button
                ~knobOverlay = View(mainView, Rect(594, 60, 147, 224)) // width was 145, now 147
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
                ~htBtnOverlay = View(mainView, Rect(734, 60, 51, 42)) // Cover only ON/OFF button (y=60-102), extended 3px right
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
            } {
                // Dolby/Octagon modes: BOTH buttons hidden (no headtracking, no panner)
                ~headtrackResetBtn.enabled_(false);
                ~htResetOverlay = View(mainView, Rect(734, 102, 51, 20)) // Cover reset button, extended 3px right
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
                // Hide knobs and ON/OFF button
                ~knobOverlay = View(mainView, Rect(594, 60, 147, 224)) // width was 145, now 147
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
                ~htBtnOverlay = View(mainView, Rect(734, 60, 51, 42)) // Cover only ON/OFF button (y=60-102), extended 3px right
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
            }
        };
        // ... existing code ...
        // --- Quad panner logic ---
        if((idx == 3) or: { idx == 4 } or: { idx == 5 }) {
            ~xyPanner.enabled_(true);
            if(~xyPannerOverlay.notNil) { ~xyPannerOverlay.remove; ~xyPannerOverlay = nil; };
        } {
            ~xyPanner.enabled_(false);
            if(~xyPannerOverlay.notNil) { ~xyPannerOverlay.remove; ~xyPannerOverlay = nil; };
            ~xyPannerOverlay = View(mainView, Rect(629, 299, 110, 145))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
        };

        // --- Refresh layout overlay title and graphics if open ---
        if(~layoutOverlay.notNil) {
            ~layoutOverlay.children.do({ |child|
                if(child.class == StaticText and: { child.string.beginsWith("LAYOUT -") }) {
                    child.string_(decoderName);
                };
            });
            ~layoutOverlay.children.do({ |child|
                if(child.class == UserView) { child.refresh; };
            });
        };
        // --- Audio engine reinitialization logic (must be last) ---
        needRebuild = (configKeyD != (~prevConfigKeyD ? configKeyD));
        needRebuild = needRebuild or: { inputs != (~prevInputs ? inputs) };
        needRebuild = needRebuild or: { outputs != (~prevOutputs ? outputs) };
        needRebuild = needRebuild or: { configKeyE != (~prevConfigKeyE ? configKeyE) };
        needRebuild = needRebuild or: { ~binauralIRCAMId != (~prevBinauralIRCAMId ? ~binauralIRCAMId) };
        needRebuild = needRebuild or: { ~binauralCIPICId != (~prevBinauralCIPICId ? ~binauralCIPICId) };
        if(needRebuild, {
            // Save current synth parameters before reinitializing
            ~saveSynthParams.value();
            ~initAudioEngine.value();
            ~prevConfigKeyD = configKeyD;
            ~prevInputs = inputs;
            ~prevOutputs = outputs;
            ~prevConfigKeyE = configKeyE;
            ~prevBinauralIRCAMId = ~binauralIRCAMId;
            ~prevBinauralCIPICId = ~binauralCIPICId;
        });

        if(~layoutOverlay.notNil and: { ~layoutBtn.notNil } and: { ~layoutBtn.value == 1 }) {
            AppClock.sched(0.0, {
                if(~layoutBtn.notNil) {
                    ~layoutBtn.valueAction_(0);
                    ~layoutBtn.valueAction_(1);
                };
                nil;
            });
        };
    },
    initVal: 0,
    initAction: false,
    labelWidth: 0,
    labelHeight: 0,
    layout: \horz,
    gap: 0@0
);
// Style the menus to match the GUI prototype
~emenu.font = Font("LCD 5x7 Segment Monospace", 11);
~emenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);
~dmenu.font = Font("LCD 5x7 Segment Monospace", 11);
~dmenu.setColors(Color.black, Color.cyan, Color.black, Color.cyan);
// --- Track previous channel counts for safe decoder switching ---
~prevInputs = inputs;
~prevOutputs = outputs;
~prevConfigKeyD = configKeyD;
~prevConfigKeyE = configKeyE;
~prevBinauralIRCAMId = ~binauralIRCAMId;
~prevBinauralCIPICId = ~binauralCIPICId;
// --- Input Source Detection for Mouse vs Headtracker ---
// Track whether the last input was from mouse or headtracker
// This allows automatic behavior adjustment for intuitive mouse control
~lastInputSource = \headtracker;  // Default to headtracker
~mouseActive = false;  // Track if mouse is currently being used
// --- Pseudo-Surround Encoder ---
// Use ATK's built-in stereo encoder if available, otherwise create custom one
// This provides a clean foundation for convolution-based spatialization
// Audio engine initialization function (from MainApp2)
~initAudioEngine = {
    var encoder, decoder, trans, ambient, roton;
    var decoderDict, encoderDict;
    var tryBoot;
    var needReboot;
    var dimVals, dimWidth, dimWidthHPF, dimTrim;
    var ambienceVals, zsynthVals, zsAmount, zsDelay, zsTrim, zsSource, zsSize, zsDamp, zsMix, leftOnState, rightOnState, flState, frState, rlState, rrState, centerState, subState, tflState, tfrState, centerGainVal, subGainVal, heightGainVal, subLpfVal, topHpfVal, s1State, s2State, s3State, s4State, s5State, s6State, s7State, s8State;
    // Always reload kernels and restart synth on decoder or encoder change
    needReboot = (inputs != (~prevInputs ? inputs)) or: (outputs != (~prevOutputs ? outputs)) or: (configKeyD != (~prevConfigKeyD ? configKeyD)) or: (configKeyE != (~prevConfigKeyE ? configKeyE)) or: (~binauralIRCAMId != (~prevBinauralIRCAMId ? ~binauralIRCAMId)) or: (~binauralCIPICId != (~prevBinauralCIPICId ? ~binauralCIPICId));
    tryBoot = {
        if(s.serverBooting, {
            ("Server busy (booting), retrying audio engine init...").postln;
            AppClock.sched(0.2, { tryBoot.value });
        }, {
            if(s.serverRunning.not, {
                s.options.memSize = 65536;
                s.options.numOutputBusChannels = outputs;
                s.options.numInputBusChannels = inputs;
                s.options.device = "UHJ"; // Use UHJ aggregate device on macOS during development
                s.boot;
                cond = Condition.new;
                s.waitForBoot({
                    // Set audio card volume after server boot (vinyl deck setup)
                    ("echo 'Audio volume controlled by output interface'").postln;
                    // Create player bus and start SFPlayer
                    ~playerBus = Bus.audio(s, 2);
                    ~sfp = SFPlayer.new(Atk.userSoundsDir ++ "/uhj/Various/AJH_eight-positions-uhj.wav", outbus: ~playerBus.index, server: s, autoBootServer: false, autoSetSampleRate: false, autoSetOutputChannels: false);
                    ~sfp.loop = false;
                    // Don't start playback yet - wait for main synth to be ready 
                    
                    { if(~playBtn.notNil, { ~playBtn.value_(0); }); }.defer(0.1);
                    
                    // Define encoder kernels
                    encoderDict = Dictionary.newFrom([
                        \uhj, FoaEncoderKernel.newUHJ,
                        \superstereo, FoaEncoderKernel.newSuper,
                        \maplin, FoaEncoderMatrix.newDirections([-45, 45, -135, 135].degrad),  // MaplinMatrix quad encoder
                        \phj, FoaEncoderKernel.newPHJ   // PHJ encoder (kernel-based)
                    ]);

                    // Define decoder kernels (matching MainApp2 exactly, excluding unused \none)
                    decoderDict = Dictionary.newFrom([
                        \binaural, FoaDecoderKernel.newListen(~binauralIRCAMId),
                        \binaurac, FoaDecoderKernel.newCIPIC(~binauralCIPICId),
                        \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                        \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                        \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual'),
                        \fivezero, FoaDecoderMatrix.new5_0(irregKind: 'focused'),
                        \octagon, FoaDecoderMatrix.newPanto(8, 'flat', k: 'dual'),
                        \stereo, FoaDecoderMatrix.newStereo,
                        \fiveonetwo, FoaDecoderMatrix.new5_0_2(\equal)  // 5.1.2 decoder (ATK order, routed in app)
                    ]);

                    // Get selected encoder and decoder
                    encoder = encoderDict.at(configKeyE ? \uhj);
                    decoder = decoderDict.at(configKeyD ? \stereo);

                    ("Audio engine initialized with encoder: " ++ configKeyE ++ " and decoder: " ++ configKeyD).postln;
                    // Start SFPlayer only after main processing synth is created

                    // Load test audio file (same as MainApp2)
                    // sndbuf = Buffer.read(s, Atk.userSoundsDir ++ "/uhj/Sodium_Sunrise_UHJ.wav");
                    
                    // Load spatial impulse responses for pseudo-surround convolution
                    // These would be B-format impulse responses for realistic spatialization
                    ~spatialIRs = Array.fill(4, { |i|
                        // Placeholder for spatial IR loading
                        // In a full implementation, these would be loaded from files
                        Buffer.alloc(s, 2048, 1); // Temporary buffer
                    });

                    s.sync(cond);

                    // Define the main audio processing SynthDef (adapted from MainApp2)
                    SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, quadLR = 0, quadFR = 0, ambience = 0, preDelay = 0, lowRT = 0.2, highRT = 2, dispersion = 1, modWidth = 0.2, modRate = 0.3, reverbTarget = 1, eq1 = 0, eq2 = 0, eq3 = 0, eq4 = 0, eq5 = 0, eq6 = 0, eq7 = 0, maplinSurround = 0.8, maplinEffect = 0.8, maplinDelay = 0.4, maplinActive = 1, maplinMode = 0, dimensionWidth = 0.0, dimensionWidthHPF = 180, dimensionOutputTrim = 0, dimensionActive = 0, zsynthHeightAmount = 30, zsynthHeightDelay = 7, zsynthHeightTrim = 0, zsynthHeightSource = 0, zsynthAmbienceSize = 2.5, zsynthAmbienceDampening = 0.2, zsynthAmbienceMix = 70, centerGain = 0, subGain = 0, heightGain = 0, subLPF = 120, topHPF = 2000, centerOn = 1, subOn = 1, tflOn = 1, tfrOn = 1, lOn = 1, rOn = 1, flOn = 1, frOn = 1, rlOn = 1, rrOn = 1, s1On = 1, s2On = 1, s3On = 1, s4On = 1, s5On = 1, s6On = 1, s7On = 1, s8On = 1|
                        var out, src, trans, encode, dimensioned, zsynth, ambient, eqed, frontStereo, rearStereo, quadOutFront, quadOutRear, maplinQuad, encodeInput, rtAr, zeroA, wetSrcW, wetSrcX, wetSrcY, wetSrcZ, wetSrc, wetOnly, centerChan, subChan, heightTFL, heightTFR, lowpass;
                        // Audio source from SFPlayer bus - variable channels based on encoder
                        src = In.ar(~playerBus.index, inputs);
                        // Amplitude scaling
                        src = src * \amp.kr(0.dbamp); // 0dB default
                        // --- 7-band graphic EQ before ambisonic encode ---
                        eqed = src;
                        // Apply EQ to each channel individually
                        eqed = eqed.collect { |channel|
                            var eqChannel = channel;
                            eqChannel = BPeakEQ.ar(eqChannel, 63, 1, eq1);      // Band 1
                            eqChannel = BPeakEQ.ar(eqChannel, 160, 1, eq2);     // Band 2
                            eqChannel = BPeakEQ.ar(eqChannel, 400, 1, eq3);     // Band 3
                            eqChannel = BPeakEQ.ar(eqChannel, 1000, 1, eq4);    // Band 4
                            eqChannel = BPeakEQ.ar(eqChannel, 2500, 1, eq5);    // Band 5
                            eqChannel = BPeakEQ.ar(eqChannel, 6400, 1, eq6);    // Band 6
                            eqChannel = BPeakEQ.ar(eqChannel, 12000, 1, eq7);   // Band 7
                            eqChannel;
                        };
                        
                        // Pre-processing for maplin encoder: stereo to quad via MaplinMatrix
                        maplinQuad = MaplinMatrix.ar(
                            eqed[0], eqed[1],
                            surroundLevel: maplinSurround,
                            effectLevel: maplinEffect,
                            delayTime: maplinDelay,
                            active: maplinActive
                        );
                        // Select input for encoding: quad (if maplin) or variable channels (others)
                        encodeInput = Select.ar(maplinMode, [eqed, maplinQuad]);
                        
                        // Encode to ambisonic using selected encoder
                        encode = FoaEncode.ar(encodeInput, encoder);
                        
                        // Dimension processing with bypass support
                        dimensioned = if(dimensionActive > 0,
                            FoaDimension.ar(
                                encode,
                                width: dimensionWidth,
                                widthHPF: dimensionWidthHPF,
                                lfGain: 0,
                                hfGain: 0,
                                outputTrim: dimensionOutputTrim
                            ),
                            encode
                        );
                        
                        // Z Synthesis processing (synthesize Z from X/Y with decorrelation and ambience)
                        zsynth = FoaZSynthesis.ar(dimensioned,
                            heightAmount: zsynthHeightAmount,
                            heightDelay: zsynthHeightDelay,
                            heightTrim: zsynthHeightTrim,
                            heightSource: zsynthHeightSource,
                            ambienceSize: zsynthAmbienceSize,
                            ambienceDampening: zsynthAmbienceDampening,
                            ambienceMix: zsynthAmbienceMix
                        );
                        
                        // Ambience processing with routing target
                        rtAr = reverbTarget + DC.ar(0);
                        zeroA = DC.ar(0);
                        wetSrcW = Select.ar(rtAr, [zsynth[0], zsynth[0], zeroA]);
                        wetSrcX = Select.ar(rtAr, [zsynth[1], zsynth[1], zeroA]);
                        wetSrcY = Select.ar(rtAr, [zsynth[2], zsynth[2], zeroA]);
                        wetSrcZ = Select.ar(rtAr, [zeroA,      zsynth[3], zsynth[3]]);
                        wetSrc = [wetSrcW, wetSrcX, wetSrcY, wetSrcZ];
                        wetOnly = AmbiVerbSC.ar(wetSrc,
                            mix: ambience,
                            preDelay: preDelay,
                            crossoverFreq: 3000,
                            lowRT: lowRT,
                            highRT: highRT,
                            dispersion: dispersion,
                            size: \Brahmssaal,
                            modWidth: modWidth,
                            modRate: modRate,
                            coupRate: 0.5,
                            coupAmt: 3,
                            phaseRotRate: 0.4,
                            phaseRotAmt: 6.2831853071796,
                            orientation: 'flu',
                            maxPreDelay: 10,
                            feedbackSpread: 1
                        ) - wetSrc;
                        wetOnly = [wetOnly[0], wetOnly[1], wetOnly[2], wetOnly[3] * (zsynthHeightSource > 0)];
                        ambient = zsynth + wetOnly;
                        // Spatial transformations (rotation, tilt, tumble) - apply to all modes
                        trans = FoaRTT.ar(ambient, rotAngle: rotation, tilAngle: tilt, tumAngle: tumble);
                        // Decode using selected decoder
                        out = FoaDecode.ar(trans, decoder);
                        if(outputs == 2, {
                            out = [
                                out[0] * lOn,
                                out[1] * rOn
                            ];
                        });
                        if(outputs == 4, {
                            // --- Q-PANNER LOGIC (Balance2) ---
                            // out[0]=LF, out[1]=FR, out[2]=RL, out[3]=RR
                            frontStereo = Balance2.ar(out[0], out[3], quadLR); // LF, FR
                            rearStereo  = Balance2.ar(out[1], out[2], quadLR); // RL, RR
                            quadOutFront = frontStereo * ((quadFR + 1) * 0.5); // scale front by 0..1
                            quadOutRear  = rearStereo  * ((1 - quadFR) * 0.5); // scale rear by 1..0
                            out = [
                                quadOutFront[0] * flOn, // LF (Speaker 1)
                                quadOutFront[1] * frOn, // FR (Speaker 2)
                                quadOutRear[0]  * rlOn, // RL (Speaker 3)
                                quadOutRear[1]  * rrOn  // RR (Speaker 4)
                            ];
                        });
                        if(outputs == 6, {
                            // --- DOLBY 5.1 OUTPUT MAPPING (Consumer Standard) ---
                            // ATK 5.0 decoder: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR
                            // Map to consumer standard: [1] FL, [2] FR, [3] RL, [4] RR, [5] C, [6] Sub
                            lowpass = BLowPass.ar((out[1] + out[4]), subLPF, 1, 0.4);
                            centerChan = out[0] * centerGain.dbamp * centerOn;
                            subChan = lowpass * subGain.dbamp * subOn;
                            out = [
                                out[1] * flOn, // FL (Speaker 1) - Front Left
                                out[4] * frOn, // FR (Speaker 2) - Front Right  
                                out[2] * rlOn, // RL (Speaker 3) - Rear Left
                                out[3] * rrOn, // RR (Speaker 4) - Rear Right
                                centerChan,    // C  (Speaker 5) - Center
                                subChan        // Sub (Speaker 6) - Subwoofer
                            ];
                        });
                        
                        if(outputs == 8, {
                            if(configKeyD == \fiveonetwo, {
                                // --- DOLBY 5.1.2 OUTPUT MAPPING (UHJ-Pi layout) ---
                                // Decoder outputs: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR, out[5]=TFR, out[6]=TFL
                                centerChan = out[0] * centerGain.dbamp * centerOn;
                                lowpass = BLowPass.ar((out[1] + out[4]), subLPF, 1, 0.4);
                                subChan = lowpass * subGain.dbamp * subOn;
                                heightTFL = HPF.ar(out[6], topHPF) * heightGain.dbamp * tflOn;
                                heightTFR = HPF.ar(out[5], topHPF) * heightGain.dbamp * tfrOn;
                                out = [
                                    out[1] * flOn, // FL (Speaker 1) - Front Left
                                    out[4] * frOn, // FR (Speaker 2) - Front Right
                                    out[2] * rlOn, // RL (Speaker 3) - Rear Left
                                    out[3] * rrOn, // RR (Speaker 4) - Rear Right
                                    centerChan,    // C  (Speaker 5) - Center
                                    subChan,       // SUB (Speaker 6) - Subwoofer/LFE
                                    heightTFL,     // TFL (Speaker 7) - Top Front Left
                                    heightTFR      // TFR (Speaker 8) - Top Front Right
                                ];
                            }, {
                                // --- OCTAGON OUTPUT MAPPING (Clockwise from Front Left) ---
                                // ATK 8.0 decoder: Anti-clockwise from front left out[0]
                                // Map to diagram: Clockwise from front left starting at Speaker 1
                                out = [
                                    out[0] * s1On, // Speaker 1: Front Left (FL)
                                    out[7] * s2On, // Speaker 2: Front Left Center (FLC)
                                    out[6] * s3On, // Speaker 3: Center (C)
                                    out[5] * s4On, // Speaker 4: Front Right Center (FRC)
                                    out[4] * s5On, // Speaker 5: Front Right (FR)
                                    out[3] * s6On, // Speaker 6: Rear Right Center (RRC)
                                    out[2] * s7On, // Speaker 7: Rear Right (RR)
                                    out[1] * s8On  // Speaker 8: Rear Left Center (RLC)
                                ];
                            });
                        });
                        
                        // Output routing for all modes
                        Out.ar(0, out);
                    }).add;

                    s.sync(cond);

                    // Start the synth
                    dimVals = ~dimensionState[\sliderValues] ? [0.0, 0.5, 0.5];
                    if(dimVals.size == 2) {
                        dimVals = [dimVals[0], 0.5, dimVals[1]];
                    } {
                        if(dimVals.size >= 4) {
                            dimVals = [dimVals[0], 0.5, dimVals[3]];
                        };
                    };
                    ambienceVals = ~ambienceState[\sliderValues] ? [0.0, 0.2, 0.0, 0.2, 0.0, 0.0, 0.0];
                    zsynthVals = ~zsynthState[\sliderValues] ? [0.3, 0.07, 0.5, 0.0, 0.625, 0.2, 0.7];
                    dimWidth = (dimVals[0] ? 0.0) * 0.70;
                    dimWidthHPF = (dimVals[1] ? 0.5).linlin(0, 1, 80, 400);
                    dimTrim = (dimVals[2] ? 0.5).linlin(0, 1, -6, 6);
                    leftOnState = if((configKeyD == \binaural) or: { configKeyD == \binaurac }, { ~binauralState[\lOn] ? 1 }, { ~stereoState[\lOn] ? 1 });
                    rightOnState = if((configKeyD == \binaural) or: { configKeyD == \binaurac }, { ~binauralState[\rOn] ? 1 }, { ~stereoState[\rOn] ? 1 });
                    flState = 1; frState = 1; rlState = 1; rrState = 1;
                    if(configKeyD == \quadsquare, {
                        flState = ~quadSquareState[\flOn] ? 1;
                        frState = ~quadSquareState[\frOn] ? 1;
                        rlState = ~quadSquareState[\rlOn] ? 1;
                        rrState = ~quadSquareState[\rrOn] ? 1;
                    }, {
                        if(configKeyD == \quadnarrow, {
                            flState = ~quadNarrowState[\flOn] ? 1;
                            frState = ~quadNarrowState[\frOn] ? 1;
                            rlState = ~quadNarrowState[\rlOn] ? 1;
                            rrState = ~quadNarrowState[\rrOn] ? 1;
                        }, {
                            if(configKeyD == \quadwide, {
                                flState = ~quadWideState[\flOn] ? 1;
                                frState = ~quadWideState[\frOn] ? 1;
                                rlState = ~quadWideState[\rlOn] ? 1;
                                rrState = ~quadWideState[\rrOn] ? 1;
                            });
                        });
                    });
                    if((configKeyD == \fivezero) or: { configKeyD == \fiveonetwo }, {
                        flState = ~dolbyState[\flOn] ? 1;
                        frState = ~dolbyState[\frOn] ? 1;
                        rlState = ~dolbyState[\rlOn] ? 1;
                        rrState = ~dolbyState[\rrOn] ? 1;
                    });
                    s1State = 1; s2State = 1; s3State = 1; s4State = 1; s5State = 1; s6State = 1; s7State = 1; s8State = 1;
                    if(configKeyD == \octagon, {
                        s1State = ~octagonState[\s1On] ? 1;
                        s2State = ~octagonState[\s2On] ? 1;
                        s3State = ~octagonState[\s3On] ? 1;
                        s4State = ~octagonState[\s4On] ? 1;
                        s5State = ~octagonState[\s5On] ? 1;
                        s6State = ~octagonState[\s6On] ? 1;
                        s7State = ~octagonState[\s7On] ? 1;
                        s8State = ~octagonState[\s8On] ? 1;
                    });
                    zsAmount = (ambienceVals[0] ? 0.0) * 100;
                    zsDelay = (ambienceVals[1] ? 0.2).linlin(0, 1, 0, 30);
                    zsTrim = (zsynthVals[2] ? 0.5).linlin(0, 1, -12, 12);
                    zsSource = if((~zsynthState[\heightSource] ? 0) == 0, 0, 1);
                    zsSize = (zsynthVals[4] ? 0.625).linlin(0, 1, 0.1, 3.0);
                    zsDamp = zsynthVals[5] ? 0.2;
                    zsMix = (zsynthVals[6] ? 0.7) * 100;
                    centerState = ~dolbyState[\centerOn] ? 1;
                    subState = ~dolbyState[\subOn] ? 1;
                    tflState = if(configKeyD == \fiveonetwo, { ~dolbyState[\tflOn] ? 1 }, { 1 });
                    tfrState = if(configKeyD == \fiveonetwo, { ~dolbyState[\tfrOn] ? 1 }, { 1 });
                    centerGainVal = ~dolbyState[\centerGain] ? 0.0;
                    subGainVal = ~dolbyState[\subGain] ? 0.0;
                    heightGainVal = ~dolbyState[\heightGain] ? 0.0;
                    subLpfVal = ~dolbyState[\subLPF] ? 120;
                    topHpfVal = ~dolbyState[\topHPF] ? 2000;

                    ~synth = Synth(\kernelEncodeDecode, [\buffer, sndbuf, \amp, voltmp, 
                        \maplinSurround, ~maplinState[\surround] ? 0.8, 
                        \maplinEffect, ~maplinState[\effect] ? 0.8,
                        \maplinDelay, ~maplinState[\delay] ? 0.4, 
                        \maplinActive, ~maplinState[\active] ? 1,
                        \maplinMode, if(configKeyE == \maplin, 1, 0),
                        \dimensionWidth, dimWidth,
                        \dimensionWidthHPF, dimWidthHPF,
                        \dimensionOutputTrim, dimTrim,
                        \dimensionActive, ~dimensionActive ? 1,
                        \zsynthHeightAmount, zsAmount,
                        \zsynthHeightDelay, zsDelay,
                        \zsynthHeightTrim, zsTrim,
                        \zsynthHeightSource, zsSource,
                        \zsynthAmbienceSize, zsSize,
                        \zsynthAmbienceDampening, zsDamp,
                        \zsynthAmbienceMix, zsMix,
                        \reverbTarget, if(~reverbTarget == \lower, 0, if(~reverbTarget == \height, 2, 1)),
                        \lOn, leftOnState,
                        \rOn, rightOnState,
                        \flOn, flState,
                        \frOn, frState,
                        \rlOn, rlState,
                        \rrOn, rrState,
                        \centerOn, centerState,
                        \subOn, subState,
                        \tflOn, tflState,
                        \tfrOn, tfrState,
                        \centerGain, centerGainVal,
                        \subGain, subGainVal,
                        \heightGain, heightGainVal,
                        \subLPF, subLpfVal,
                        \topHPF, topHpfVal,
                        \s1On, s1State,
                        \s2On, s2State,
                        \s3On, s3State,
                        \s4On, s4State,
                        \s5On, s5State,
                        \s6On, s6State,
                        \s7On, s7State,
                        \s8On, s8State
                    ]);
                    // Load first track from file list (if available) but don't start playing
                    { ~resetTransportState.value; }.defer(0.2);
                    
                    // Restore saved parameters to new synth
                    ~restoreSynthParams.value();

                    // Create unified SFPlayerMeter (handles both input and output meters)
                    {
                        ~meter.remove; // Remove any existing meter
                        ("Creating unified SFPlayerMeter with outputs=" ++ outputs).postln;
                        ~meter = SFPlayerMeter.new(s, ~meterContainer, 68@0, 2, outputs, ~playerBus);
                    }.defer;
                    ("Audio synthesis started with level meter").postln;
                    
                    // Remove initialization overlay - server is ready
                    if(~initOverlay.notNil, {
                        ~initOverlay.remove;
                        ~initOverlay = nil;
                        ~initText = nil;
                        ~initLogo = nil;
                    });
                });
            }, {
                if(needReboot, {
                    // Free synth before reboot to avoid "Node not found" errors
                    if(~synth.notNil and: { s.serverRunning }) {
                        ~synth.free;
                    };
                    ~synth = nil; // Always nil the reference
                    s.options.memSize = 65536;
                    s.options.numOutputBusChannels = outputs;
                    s.options.numInputBusChannels = inputs;
                    s.options.device = "UHJ"; // Use UHJ aggregate device on macOS during development
                    s.reboot;
                    cond = Condition.new;
                    s.waitForBoot({
                        // Set audio card volume after server reboot (vinyl deck setup)
                        ("echo 'Audio volume controlled by output interface'").postln;
                        
                        // Recreate player bus after server reboot
                        ~playerBus = Bus.audio(s, 2);
                        
                        // Recreate SFPlayer after server reboot
                        if(~filePaths.notNil and: { ~filePaths.size > 0 }, {
                            // Stop existing SFPlayer if it exists
                            if(~sfp.notNil, { ~sfp.stop; });
                            ~sfp = SFPlayer.new(~filePaths[0], outbus: ~playerBus.index, server: s, autoBootServer: false, autoSetSampleRate: false, autoSetOutputChannels: false);
                            ~sfp.loop = false;
                        });
                        ~resetTransportState.value;
                        
                        // Define encoder kernels
                        encoderDict = Dictionary.newFrom([
                            \uhj, FoaEncoderKernel.newUHJ,
                            \superstereo, FoaEncoderKernel.newSuper,
                            \maplin, FoaEncoderMatrix.newDirections([-45, 45, -135, 135].degrad),  // MaplinMatrix quad encoder
                        ]);

                        // Define decoder kernels (matching MainApp2 exactly, excluding unused \none)
                        decoderDict = Dictionary.newFrom([
                            \binaural, FoaDecoderKernel.newListen(~binauralIRCAMId),
                            \binaurac, FoaDecoderKernel.newCIPIC(~binauralCIPICId),
                            \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                            \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                            \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual'),
                            \fivezero, FoaDecoderMatrix.new5_0(irregKind: 'focused'),
                            \octagon, FoaDecoderMatrix.newPanto(8, 'flat', k: 'dual'),
                            \stereo, FoaDecoderMatrix.newStereo,
                            \fiveonetwo, FoaDecoderMatrix.new5_0_2(\equal)  // 5.1.2 decoder (ATK order, routed in app)
                        ]);

                        // Get selected encoder and decoder
                        encoder = encoderDict.at(configKeyE ? \uhj);
                        decoder = decoderDict.at(configKeyD ? \stereo);

                        ("Audio engine initialized with encoder: " ++ configKeyE ++ " and decoder: " ++ configKeyD).postln;

                        // Load test audio file (same as MainApp2)
                        // sndbuf = Buffer.read(s, Atk.userSoundsDir ++ "/uhj/Sodium_Sunrise_UHJ.wav");

                        s.sync(cond);

                        // Define the main audio processing SynthDef (adapted from MainApp2)
                        SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, quadLR = 0, quadFR = 0, ambience = 0, preDelay = 0, lowRT = 0.2, highRT = 2, dispersion = 1, modWidth = 0.2, modRate = 0.3, eq1 = 0, eq2 = 0, eq3 = 0, eq4 = 0, eq5 = 0, eq6 = 0, eq7 = 0, maplinSurround = 0.8, maplinEffect = 0.8, maplinDelay = 0.4, maplinActive = 1, maplinMode = 0, dimensionWidth = 0.0, dimensionWidthHPF = 180, dimensionOutputTrim = 0, dimensionActive = 0, zsynthHeightAmount = 30, zsynthHeightDelay = 7, zsynthHeightTrim = 0, zsynthHeightSource = 0, zsynthAmbienceSize = 2.5, zsynthAmbienceDampening = 0.2, zsynthAmbienceMix = 70, centerGain = 0, subGain = 0, heightGain = 0, subLPF = 120, topHPF = 2000, centerOn = 1, subOn = 1, tflOn = 1, tfrOn = 1, lOn = 1, rOn = 1, flOn = 1, frOn = 1, rlOn = 1, rrOn = 1, s1On = 1, s2On = 1, s3On = 1, s4On = 1, s5On = 1, s6On = 1, s7On = 1, s8On = 1|
                            var out, src, trans, encode, dimensioned, zsynth, ambient, eqed, frontStereo, rearStereo, quadOutFront, quadOutRear, maplinQuad, encodeInput, centerChan, subChan, heightTFL, heightTFR, lowpass;
                            // Audio source from SFPlayer bus - variable channels based on encoder
                            src = In.ar(~playerBus.index, inputs);
                            // Amplitude scaling
                            src = src * \amp.kr(0.dbamp); // 0dB default
                            // --- 7-band graphic EQ before ambisonic encode ---
                            eqed = src;
                            // Apply EQ to each channel individually
                            eqed = eqed.collect { |channel|
                                var eqChannel = channel;
                                eqChannel = BPeakEQ.ar(eqChannel, 63, 1, eq1);      // Band 1
                                eqChannel = BPeakEQ.ar(eqChannel, 160, 1, eq2);     // Band 2
                                eqChannel = BPeakEQ.ar(eqChannel, 400, 1, eq3);     // Band 3
                                eqChannel = BPeakEQ.ar(eqChannel, 1000, 1, eq4);    // Band 4
                                eqChannel = BPeakEQ.ar(eqChannel, 2500, 1, eq5);     // Band 5
                                eqChannel = BPeakEQ.ar(eqChannel, 6400, 1, eq6);     // Band 6
                                eqChannel = BPeakEQ.ar(eqChannel, 12000, 1, eq7);    // Band 7
                                eqChannel;
                            };
                            
                            // Pre-processing for maplin encoder: stereo to quad via MaplinMatrix
                            maplinQuad = MaplinMatrix.ar(
                                eqed[0], eqed[1],
                                surroundLevel: maplinSurround,
                                effectLevel: maplinEffect,
                                delayTime: maplinDelay,
                                active: maplinActive
                            );
                            
                            // Select input for encoding: quad (if maplin) or variable channels (others)
                            encodeInput = Select.ar(maplinMode, [eqed, maplinQuad]);
                            
                            // Encode to ambisonic using selected encoder
                            encode = FoaEncode.ar(encodeInput, encoder);
                            // Ambience processing stays as-is in this branch
                            ambient = AmbiVerbSC.ar(encode,
                                mix: ambience,
                                preDelay: preDelay,
                                crossoverFreq: 3000,
                                lowRT: lowRT,
                                highRT: highRT,
                                dispersion: dispersion,
                                size: \Brahmssaal,
                                modWidth: modWidth,
                                modRate: modRate,
                                coupRate: 0.5,
                                coupAmt: 3,
                                phaseRotRate: 0.4,
                                phaseRotAmt: 6.2831853071796,
                                orientation: 'flu',
                                maxPreDelay: 10,
                                feedbackSpread: 1
                            );
                            // Apply rotation/tilt/tumble
                            trans = FoaRTT.ar(ambient, rotAngle: rotation, tilAngle: tilt, tumAngle: tumble);
                            // Decode using selected decoder
                            out = FoaDecode.ar(trans, decoder);
                            if(outputs == 2, {
                                out = [
                                    out[0] * lOn,
                                    out[1] * rOn
                                ];
                            });
                            if(outputs == 4, {
                                // --- Q-PANNER LOGIC (Balance2) ---
                                // out[0]=LF, out[1]=FR, out[2]=RL, out[3]=RR
                                frontStereo = Balance2.ar(out[0], out[3], quadLR); // LF, FR
                                rearStereo  = Balance2.ar(out[1], out[2], quadLR); // RL, RR
                                quadOutFront = frontStereo * ((quadFR + 1) * 0.5); // scale front by 0..1
                                quadOutRear  = rearStereo  * ((1 - quadFR) * 0.5); // scale rear by 1..0
                                out = [
                                quadOutFront[0] * flOn, // LF (Speaker 1)
                                quadOutFront[1] * frOn, // FR (Speaker 2)
                                quadOutRear[0]  * rlOn, // RL (Speaker 3)
                                quadOutRear[1]  * rrOn  // RR (Speaker 4)
                                ];
                            });
                            if(outputs == 6, {
                                // --- DOLBY 5.1 OUTPUT MAPPING (Consumer Standard) ---
                                // ATK 5.0 decoder: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR
                                // Map to consumer standard: [1] FL, [2] FR, [3] RL, [4] RR, [5] C, [6] Sub
                                lowpass = BLowPass.ar((out[1] + out[4]), subLPF, 1, 0.4);
                                centerChan = out[0] * centerGain.dbamp * centerOn;
                                subChan = lowpass * subGain.dbamp * subOn;
                                out = [
                                    out[1] * flOn, // FL (Speaker 1) - Front Left
                                    out[4] * frOn, // FR (Speaker 2) - Front Right  
                                    out[2] * rlOn, // RL (Speaker 3) - Rear Left
                                    out[3] * rrOn, // RR (Speaker 4) - Rear Right
                                    centerChan,    // C  (Speaker 5) - Center
                                    subChan        // Sub (Speaker 6) - Subwoofer
                                ];
                            });
                            
                            if(outputs == 8, {
                                if(configKeyD == \fiveonetwo, {
                                    // --- DOLBY 5.1.2 OUTPUT MAPPING ---
                                    lowpass = BLowPass.ar((out[1] + out[4]), subLPF, 1, 0.4);
                                    centerChan = out[0] * centerGain.dbamp * centerOn;
                                    subChan = lowpass * subGain.dbamp * subOn;
                                    heightTFL = HPF.ar(out[6], topHPF) * heightGain.dbamp * tflOn;
                                    heightTFR = HPF.ar(out[5], topHPF) * heightGain.dbamp * tfrOn;
                                    out = [
                                        out[1] * flOn, // FL (Speaker 1) - Front Left
                                        out[4] * frOn, // FR (Speaker 2) - Front Right
                                        out[2] * rlOn, // RL (Speaker 3) - Rear Left
                                        out[3] * rrOn, // RR (Speaker 4) - Rear Right
                                        centerChan,    // C  (Speaker 5) - Center
                                        subChan,       // SUB (Speaker 6) - Subwoofer
                                        heightTFL,     // TFL (Speaker 7) - Top Front Left
                                        heightTFR      // TFR (Speaker 8) - Top Front Right
                                    ];
                                }, {
                                    // --- OCTAGON OUTPUT MAPPING (Clockwise from Front Left) ---
                                    // ATK 8.0 decoder: Anti-clockwise from front left out[0]
                                    // Map to diagram: Clockwise from front left starting at Speaker 1
                                    out = [
                                        out[0] * s1On, // Speaker 1: Front Left (FL)
                                        out[7] * s2On, // Speaker 2: Front Left Center (FLC)
                                        out[6] * s3On, // Speaker 3: Center (C)
                                        out[5] * s4On, // Speaker 4: Front Right Center (FRC)
                                        out[4] * s5On, // Speaker 5: Front Right (FR)
                                        out[3] * s6On, // Speaker 6: Rear Right Center (RRC)
                                        out[2] * s7On, // Speaker 7: Rear Right (RR)
                                        out[1] * s8On  // Speaker 8: Rear Left Center (RLC)
                                    ];
                                });
                            });
                            // Output routing for all modes
                            Out.ar(0, out);
                        }).add;

                        s.sync(cond);

                        // Start the synth
                        dimVals = ~dimensionState[\sliderValues] ? [0.0, 0.5, 0.5];
                        if(dimVals.size == 2) {
                            dimVals = [dimVals[0], 0.5, dimVals[1]];
                        } {
                            if(dimVals.size >= 4) {
                                dimVals = [dimVals[0], 0.5, dimVals[3]];
                            };
                        };
                        dimWidth = (dimVals[0] ? 0.0) * 0.70;
                        dimWidthHPF = (dimVals[1] ? 0.5).linlin(0, 1, 80, 400);
                        dimTrim = (dimVals[2] ? 0.5).linlin(0, 1, -6, 6);
                        leftOnState = if((configKeyD == \binaural) or: { configKeyD == \binaurac }, { ~binauralState[\lOn] ? 1 }, { ~stereoState[\lOn] ? 1 });
                        rightOnState = if((configKeyD == \binaural) or: { configKeyD == \binaurac }, { ~binauralState[\rOn] ? 1 }, { ~stereoState[\rOn] ? 1 });
                        flState = 1; frState = 1; rlState = 1; rrState = 1;
                        if(configKeyD == \quadsquare, {
                            flState = ~quadSquareState[\flOn] ? 1;
                            frState = ~quadSquareState[\frOn] ? 1;
                            rlState = ~quadSquareState[\rlOn] ? 1;
                            rrState = ~quadSquareState[\rrOn] ? 1;
                        }, {
                            if(configKeyD == \quadnarrow, {
                                flState = ~quadNarrowState[\flOn] ? 1;
                                frState = ~quadNarrowState[\frOn] ? 1;
                                rlState = ~quadNarrowState[\rlOn] ? 1;
                                rrState = ~quadNarrowState[\rrOn] ? 1;
                            }, {
                                if(configKeyD == \quadwide, {
                                    flState = ~quadWideState[\flOn] ? 1;
                                    frState = ~quadWideState[\frOn] ? 1;
                                    rlState = ~quadWideState[\rlOn] ? 1;
                                    rrState = ~quadWideState[\rrOn] ? 1;
                                });
                            });
                        });
                if((configKeyD == \fivezero) or: { configKeyD == \fiveonetwo }, {
                    flState = ~dolbyState[\flOn] ? 1;
                    frState = ~dolbyState[\frOn] ? 1;
                    rlState = ~dolbyState[\rlOn] ? 1;
                    rrState = ~dolbyState[\rrOn] ? 1;
                });
                ambienceVals = ~ambienceState[\sliderValues] ? [0.0, 0.2, 0.0, 0.2, 0.0, 0.0, 0.0];
                zsynthVals = ~zsynthState[\sliderValues] ? [0.3, 0.07, 0.5, 0.0, 0.625, 0.2, 0.7];
                zsAmount = (ambienceVals[0] ? 0.0) * 100;
                zsDelay = (ambienceVals[1] ? 0.2).linlin(0, 1, 0, 30);
                zsTrim = (zsynthVals[2] ? 0.5).linlin(0, 1, -12, 12);
                zsSource = if((~zsynthState[\heightSource] ? 0) == 0, 0, 1);
                zsSize = (zsynthVals[4] ? 0.625).linlin(0, 1, 0.1, 3.0);
                zsDamp = zsynthVals[5] ? 0.2;
                zsMix = (zsynthVals[6] ? 0.7) * 100;
                centerState = ~dolbyState[\centerOn] ? 1;
                subState = ~dolbyState[\subOn] ? 1;
                tflState = if(configKeyD == \fiveonetwo, { ~dolbyState[\tflOn] ? 1 }, { 1 });
                tfrState = if(configKeyD == \fiveonetwo, { ~dolbyState[\tfrOn] ? 1 }, { 1 });
                centerGainVal = ~dolbyState[\centerGain] ? 0.0;
                subGainVal = ~dolbyState[\subGain] ? 0.0;
                heightGainVal = ~dolbyState[\heightGain] ? 0.0;
                subLpfVal = ~dolbyState[\subLPF] ? 120;
                topHpfVal = ~dolbyState[\topHPF] ? 180;
                s1State = 1; s2State = 1; s3State = 1; s4State = 1; s5State = 1; s6State = 1; s7State = 1; s8State = 1;
                if(configKeyD == \octagon, {
                    s1State = ~octagonState[\s1On] ? 1;
                    s2State = ~octagonState[\s2On] ? 1;
                    s3State = ~octagonState[\s3On] ? 1;
                    s4State = ~octagonState[\s4On] ? 1;
                    s5State = ~octagonState[\s5On] ? 1;
                    s6State = ~octagonState[\s6On] ? 1;
                    s7State = ~octagonState[\s7On] ? 1;
                    s8State = ~octagonState[\s8On] ? 1;
                });

                        ~synth = Synth(\kernelEncodeDecode, [\buffer, sndbuf, \amp, voltmp, 
                            \maplinSurround, ~maplinState[\surround] ? 0.8, 
                            \maplinEffect, ~maplinState[\effect] ? 0.8,
                            \maplinDelay, ~maplinState[\delay] ? 0.4, 
                            \maplinActive, ~maplinState[\active] ? 1,
                            \maplinMode, if(configKeyE == \maplin, 1, 0),
                            \dimensionWidth, dimWidth,
                            \dimensionWidthHPF, dimWidthHPF,
                            \dimensionOutputTrim, dimTrim,
                            \dimensionActive, ~dimensionActive ? 1,
                            \zsynthHeightAmount, zsAmount,
                            \zsynthHeightDelay, zsDelay,
                            \zsynthHeightTrim, zsTrim,
                            \zsynthHeightSource, zsSource,
                            \zsynthAmbienceSize, zsSize,
                            \zsynthAmbienceDampening, zsDamp,
                            \zsynthAmbienceMix, zsMix,
                            \lOn, leftOnState,
                            \rOn, rightOnState,
                            \flOn, flState,
                            \frOn, frState,
                            \rlOn, rlState,
                    \rrOn, rrState,
                    \centerOn, centerState,
                    \subOn, subState,
                    \tflOn, tflState,
                    \tfrOn, tfrState,
                    \centerGain, centerGainVal,
                    \subGain, subGainVal,
                    \heightGain, heightGainVal,
                    \subLPF, subLpfVal,
                    \topHPF, topHpfVal,
                    \s1On, s1State,
                    \s2On, s2State,
                    \s3On, s3State,
                    \s4On, s4State,
                    \s5On, s5State,
                    \s6On, s6State,
                    \s7On, s7State,
                    \s8On, s8State]);
                        
                        // Restore saved parameters to new synth
                        ~restoreSynthParams.value();

                    // Create unified SFPlayerMeter (handles both input and output meters)
                    {
                        ~meter.remove; // Remove any existing meter
                        ("Creating unified SFPlayerMeter with outputs=" ++ outputs).postln;
                        ~meter = SFPlayerMeter.new(s, ~meterContainer, 68@0, 2, outputs, ~playerBus);
                    }.defer;

                        ("Audio synthesis started with level meter").postln;
                        
                        // Remove initialization overlay - server is ready after reboot
                        if(~initOverlay.notNil, {
                            ~initOverlay.remove;
                            ~initOverlay = nil;
                            ~initText = nil;
                            ~initLogo = nil;
                        });
                    });
                });
            });
        });
    };
    tryBoot.value;
    // Update previous channel counts and decoder/encoder key
    ~prevInputs = inputs;
    ~prevOutputs = outputs;
    ~prevConfigKeyD = configKeyD;
    ~prevConfigKeyE = configKeyE;
    ~prevBinauralIRCAMId = ~binauralIRCAMId;
    ~prevBinauralCIPICId = ~binauralCIPICId;
};

// --- Custom Meter Function ---
~createCustomMeter = {
    // Create SFPlayerMeter for both inputs (player audio) and outputs (processed audio)
    ~meter = SFPlayerMeterView.new(s, ~meterContainer, 0@0, 2, outputs, ~playerBus);
};

// --- Level Meter Section ---
~meterView = View(mainView, Rect(180, 107, 320, 275)).background_(Color.clear);

// Add a thin border around the meter view
~meterBorder = UserView(~meterView, Rect(0, 0, 320, 275))
    .background_(Color.clear)
    .drawFunc_({ |v|
        Pen.width = 0.5;
        Pen.color = Color.white;
        Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
        Pen.stroke;
    });

// Centered LEVEL METER title
StaticText(~meterView, Rect(0, 5, 320, 30)).background_(Color.clear)
    .align_(\center)
    .string_("LEVEL METER")
    .stringColor_(Color.cyan)
    .font_(Font("Helvetica", 14).boldVariant);

// Initialize meter display area
~meterContainer = View(~meterView, Rect(10, 35, 300, 230)).background_(Color.black); // x=10, width=300

// --- Permanent OUTPUT label above the output numbers, always centered ---
StaticText(~meterContainer, Rect(97, 5, 180, 16)) // x=99-2, width=180, y=5
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("OUTPUT");
// --- Permanent row of 8 numbers below the meters, aligned with meter bars ---
~meterNumbers = Array.fill(8, { |i|
    var labelWidth = 24;
    var x = 96 + ((i + 0.5) * (180 / 8)) - (labelWidth / 2); // x=95+1, move 1px right
    StaticText(~meterContainer, Rect(x, 206, labelWidth, 16))
        .background_(Color.clear)
        .font_(Font("Helvetica", 9).boldVariant)
        .align_(\center)
        .stringColor_(Color.cyan)
        .string_((i+1).asString);
});

// --- Permanent INPUT label above the player audio, always left-aligned ---
StaticText(~meterContainer, Rect(36, 5, 80, 16)) // x=32+2+2, width=80, y=5
    .background_(Color.clear)
    .font_(Font("Helvetica", 10).boldVariant)
    .align_(\left)
    .stringColor_(Color.cyan)
    .string_("INPUT");
// --- Permanent input channel numbers below the input meters ---
~inputNumbers = Array.fill(2, { |i| // Always show 2 input channels for now
    var labelWidth = 24;
    var spacing = 44;
    var x = 29 + ((i + 0.5) * (spacing / 2)) - (labelWidth / 2); // x=27+2
    StaticText(~meterContainer, Rect(x, 206, labelWidth, 16))
        .background_(Color.clear)
        .font_(Font("Helvetica", 9).boldVariant)
        .align_(\center)
        .stringColor_(Color.cyan)
        .string_((i+1).asString);
});
// --- Permanent vertical dB scale numbers (0 and -∞) ---
StaticText(~meterContainer, Rect(8, 25, 24, 12)) // x=6+2, y=18+7 (top)
    .background_(Color.clear)
    .font_(Font("Helvetica", 9).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("0");
StaticText(~meterContainer, Rect(8, 195, 24, 12)) // x=6+2, y=188+7 (bottom)
    .background_(Color.clear)
    .font_(Font("Helvetica", 9).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("-60");
// --- dB label halfway up the meter ---
StaticText(~meterContainer, Rect(8, 110, 24, 14)) // halfway up (approx)
    .background_(Color.clear)
    .font_(Font("Helvetica", 9).boldVariant)
    .align_(\center)
    .stringColor_(Color.cyan)
    .string_("dB");

// Initialize input defaults (vinyl deck)
//lastInL = 127; // 0dB equivalent (ALSA: 127 = 0dB)
//lastInR = 127; // 0dB equivalent (ALSA: 127 = 0dB)
//~leftSlider.value = (lastInL - minIn) / (maxIn - minIn);
//~rightSlider.value = (lastInR - minIn) / (maxIn - minIn);
// Display initial dB values using logarithmic scaling (labels removed)
dbValue = cliToDbMaster.(lastInL);

// Initialize USB input indicator as active
// ~usbBtn.value_(0);  // USB input active (cyan background)

// Set encoder/decoder menu defaults
~emenu.value_(0); // UHJ encoder
~dmenu.value_(0); // STEREO decoder



// Start audio engine with initial configuration after a short delay
{
    ~initAudioEngine.value();
}.defer(0.5);

// --- HEADTRACKER AND PANNER CONTROLS (with Standard Knobs) ---
        // Create value display labels first
        ~rotateValue = StaticText(mainView, Rect(719, 80, 55, 20)).font_(Font("Helvetica", 11)).string_("0").align_(\left).stringColor_(Color.cyan);
        ~tiltValue = StaticText(mainView, Rect(719, 162, 55, 20)) .font_(Font("Helvetica", 11)).string_("0").align_(\left).stringColor_(Color.cyan);
        ~tumbleValue = StaticText(mainView, Rect(719, 244, 55, 20)) .font_(Font("Helvetica", 11)).string_("0").align_(\left).stringColor_(Color.cyan);
        
        // Knob360 with 360-degree behavior and automatic mouse/headtracker detection
        ~rotateKnob = Knob360(mainView, Rect(654, 60, 60, 60), 0.5, 0.0, 1.0)
            .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
            .enabled_(false)
            .action_({ |knob, val|
                // 360-degree behavior: map 0-1 to -180 to +180 degrees
                var deg = val.linlin(0, 1, -180, 180).round.asInteger;
                
                // Automatic mouse/headtracker behavior adjustment
                if(~mouseActive, {
                    // Mouse input: invert direction for intuitive control
                    deg = deg.neg;
                    ~lastInputSource = \mouse;
                }, {
                    // Headtracker input: keep normal direction
                    ~lastInputSource = \headtracker;
                });
                
                ~rotateValue.string = (deg.asString ++ "°");
                if(~synth.notNil) { ~synth.set(\rotation, deg.degrad); }
            })
            .mouseDownAction_({ |view, x, y, mod, button, count|
                ~mouseActive = true;
                ~lastInputSource = \mouse;
            })
            .mouseUpAction_({ |view, x, y, mod, button, count|
                ~mouseActive = false;
            });

        ~tiltKnob = Knob360(mainView, Rect(654, 142, 60, 60), 0.5, 0.0, 1.0)
            .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
            .enabled_(false)
            .action_({ |knob, val|
                // 360-degree behavior: map 0-1 to -180 to +180 degrees
                var deg = val.linlin(0, 1, -180, 180).round.asInteger;
                
                // Automatic mouse/headtracker behavior adjustment
                if(~mouseActive, {
                    // Mouse input: invert direction for intuitive control
                    deg = deg.neg;
                    ~lastInputSource = \mouse;
                }, {
                    // Headtracker input: keep normal direction
                    ~lastInputSource = \headtracker;
                });
                
                ~tiltValue.string = (deg.asString ++ "°");
                if(~synth.notNil) { ~synth.set(\tilt, deg.degrad); }
            })
            .mouseDownAction_({ |view, x, y, mod, button, count|
                ~mouseActive = true;
                ~lastInputSource = \mouse;
            })
            .mouseUpAction_({ |view, x, y, mod, button, count|
                ~mouseActive = false;
            });

        ~tumbleKnob = Knob360(mainView, Rect(654, 224, 60, 60), 0.5, 0.0, 1.0)
            .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
            .enabled_(false)
            .action_({ |knob, val|
                // 360-degree behavior: map 0-1 to -180 to +180 degrees
                var deg = val.linlin(0, 1, -180, 180).round.asInteger;
                
                // Automatic mouse/headtracker behavior adjustment
                if(~mouseActive, {
                    // Mouse input: invert direction for intuitive control
                    deg = deg.neg;
                    ~lastInputSource = \mouse;
                }, {
                    // Headtracker input: keep normal direction
                    ~lastInputSource = \headtracker;
                });
                
                ~tumbleValue.string = (deg.asString ++ "°");
                if(~synth.notNil) { ~synth.set(\tumble, deg.degrad); }
            })
            .mouseDownAction_({ |view, x, y, mod, button, count|
                ~mouseActive = true;
                ~lastInputSource = \mouse;
            })
            .mouseUpAction_({ |view, x, y, mod, button, count|
                ~mouseActive = false;
            });

// Value display labels already created above

// --- Headtracker HID Integration (moved earlier for better timing) ---
(
Tdef( 'tryOpenHID' , {
   var keepLooking = true;
   while ( { keepLooking } ){
      if ( ~myhid.notNil ){
         if ( ~myhid.isOpen ){
            keepLooking = false;
         }
      };
      if ( keepLooking ){
         HID.findAvailable;
         if ( HID.findBy(0,0).size > 0 ){
            ~myhid = HID.open(0,0);
            if ( ~myhid.notNil ){
               ~myhid.closeAction = {
                    "device closed".postln;
                    Tdef( \tryOpenHID ).reset.play;
               };
               keepLooking = false;
            }{
               1.0.wait;
            };
         }{
            3.0.wait;
         }
      }
   }
} );
);
Tdef( 'tryOpenHID' ).play;
// HID.debug = true;

// Headtracker drift compensation variables
~htRotateSmoothed = 0.5;  // Smoothed rotation value (0-1, center = 0.5)
~htRotateLast = 0.5;      // Last rotation value for change detection
~htSmoothFactor = 0.15;   // Smoothing factor (0-1, lower = more smoothing)
~htDeadZone = 0.02;       // Dead zone around center (ignore changes smaller than this)
~htChangeThreshold = 0.005; // Minimum change threshold to update

// Map HID usages to GUI knobs (always active, no gating)
HIDdef.usage( \hidRotation, { |val|
    var mappedVal, change, distFromCenter;
    {
        if(~rotateKnob.notNil and: { ~rotateKnob.enabled }) {
            // Map raw HID value to 0-1 range
            mappedVal = 1 - val.linlin(0.060606062412262, 0.94037145376205, 0, 1);
            
            // Apply exponential smoothing
            ~htRotateSmoothed = (~htRotateSmoothed * (1 - ~htSmoothFactor)) + (mappedVal * ~htSmoothFactor);
            
            // Calculate change from last value
            change = (~htRotateSmoothed - ~htRotateLast).abs;
            
            // Only update if change is significant (above threshold)
            if(change > ~htChangeThreshold) {
                // Check if we're in dead zone around center (0.5)
                distFromCenter = (~htRotateSmoothed - 0.5).abs;
                
                if(distFromCenter > ~htDeadZone) {
                    // Outside dead zone - update knob
                    ~rotateKnob.valueAction_(~htRotateSmoothed);
                    ~htRotateLast = ~htRotateSmoothed;
                } {
                    // In dead zone - snap to center if we were outside before
                    if((~htRotateLast - 0.5).abs > ~htDeadZone) {
                        ~rotateKnob.valueAction_(0.5);
                        ~htRotateLast = 0.5;
                        ~htRotateSmoothed = 0.5; // Reset smoothed value to center
                    };
                };
            };
        };
    }.defer;
}, \Z );

HIDdef.usage( \hidTilt, { |val|
    {
        if(~tiltKnob.notNil and: { ~tiltKnob.enabled }) {
            ~tiltKnob.valueAction_(
                1 - val.linlin(0.060606062412262, 0.94037145376205, 0, 1)
            );
        };
    }.defer;
}, \Y );

HIDdef.usage( \hidTumble, { |val|
    {
        if(~tumbleKnob.notNil and: { ~tumbleKnob.enabled }) {
            ~tumbleKnob.valueAction_(
                1 - val.linlin(0.060606062412262, 0.94037145376205, 0, 1)
            );
        };
    }.defer;
}, \X );

~xyPanner = Slider2D(mainView, Rect(629, 334, 110, 110))
    .x_(0.5).y_(0.5)
    .knobColor_(Color.cyan)
    .background_(Color.black)
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({ |sl|
        // Equal-power law for left/right (x axis)
        var angleLR = sl.x.linlin(0, 1, 0, pi/2); // 0..1 → 0..π/2
        var quadLR = sin(angleLR) - cos(angleLR);  // -1..1 with equal power
        // Equal-power law for front/rear (y axis)
        var angleFR = sl.y.linlin(0, 1, 0, pi/2); // 0..1 → 0..π/2
        var quadFR = sin(angleFR) - cos(angleFR);  // -1..1 with equal power
        ~xyPannerPos = Point(sl.x, sl.y);
        if(~synth.notNil) {
            ~synth.set(\quadLR, quadLR, \quadFR, quadFR);
        }
    });
~xyPannerPos = Point(~xyPanner.x, ~xyPanner.y);

// --- Additional GUI Layout ---
// --- HEADTRACKER HEADING ---
StaticText(mainView, Rect(618, 10, 140, 28))
    .string_("HEADTRACKER")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);
// --- BLUETOOTH PAIR BUTTON ---
~pairingInProgress = false;  // Flag to prevent multiple clicks
~headtrackPairBtn = Button(mainView, Rect(742, 142, 40, 20))
    .states_([
        ["PAIR", Color.cyan, Color.black],      // 0: Ready to pair
        ["...", Color.cyan, Color.black],       // 1: Pairing in progress  
        ["PAIR", Color.black, Color.cyan],      // 2: Success - cyan background like line button
        ["FAIL", Color.cyan, Color.black]       // 3: Failed
    ])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .value_(0)  // Explicitly set to PAIR state
    .action_({
        var scriptPath;
        
        // Check if pairing is already in progress
        if (~pairingInProgress) { 
            ^this 
        };
        
        // Check actual device status to determine action
        ~pairingInProgress = true;
        ~headtrackPairBtn.value_(1); // Show working
        
        Task({
            var deviceInfo, isPaired, isConnected, result, success = false;
            
            // Use the MAC address detected at startup
            if (~headtrackerMac.notEmpty) {
                // Check the ACTUAL device status using startup MAC
                deviceInfo = ("bluetoothctl info " ++ ~headtrackerMac).unixCmdGetStdOut;
                isPaired = deviceInfo.contains("Paired: yes");
                isConnected = deviceInfo.contains("Connected: yes");
            } {
                // No headtracker found - proceed to pair
                isPaired = false;
                isConnected = false;
            };
            
            if (isPaired) {
                // Device is paired - UNPAIR (remove device)
                ("Device is paired - removing...").postln;
                try {
                    // Disconnect first, then remove
                    ("Disconnecting headtracker...").postln;
                    result = ("bluetoothctl disconnect " ++ ~headtrackerMac).unixCmdGetStdOut;
                    ("Disconnect result: " ++ result).postln;
                    1.wait; // Wait for disconnect to complete
                    
                    ("Removing headtracker...").postln;
                    result = ("bluetoothctl remove " ++ ~headtrackerMac).unixCmdGetStdOut;
                    ("Remove result: " ++ result).postln;
                    1.wait; // Wait for removal to complete
                    
                    // Check if it's really gone
                    result = ("bluetoothctl info " ++ ~headtrackerMac).unixCmdGetStdOut;
                    ("Final status: " ++ result).postln;
                    success = true;
                } { |error|
                    ("Unpair error: " ++ error).postln;
                    success = false;
                };
                
                {
                    ~pairingInProgress = false;
                    if (success) {
                        // Clear MAC address so it gets re-detected on next pairing attempt
                        ~headtrackerMac = "";
                        ("MAC address cleared - device ready for re-pairing").postln;
                        ~headtrackPairBtn.value_(0); // Reset to PAIR only if unpair succeeded
                    } {
                        ~headtrackPairBtn.value_(2); // Keep paired state if unpair failed
                    };
                }.defer;
                
            } {
                // Device is not paired - PAIR the device
                ("Device not paired - pairing...").postln;
                
                // Run pairing script in background with timeout
                scriptPath = "/usr/local/bin/ble-ht.sh";
                
                // Safety timeout - reset button after 30 seconds if script hangs
                AppClock.sched(30, { 
                    if (~pairingInProgress) {
                        ~pairingInProgress = false;  // Reset flag
                        ~headtrackPairBtn.value_(3); // Show failed if still in progress
                        AppClock.sched(3, { ~headtrackPairBtn.value_(0); nil });
                    };
                    nil 
                });
                
                // First attempt
                try {
                    result = ("timeout 30 bash -c '" ++ scriptPath ++ "'").unixCmdGetStdOut;
                    success = result.contains("PAIRED_AND_CONNECTED");
                } { |error|
                    ("Pairing script error: " ++ error).postln;
                    success = false;
                };
                
                // If first attempt failed, automatically retry once
                if (success.not) {
                    ("First pairing attempt failed, retrying automatically...").postln;
                    1.wait; // Brief pause between attempts
                    
                    try {
                        result = ("timeout 30 bash -c '" ++ scriptPath ++ "'").unixCmdGetStdOut;
                        success = result.contains("PAIRED_AND_CONNECTED");
                        if (success) {
                            ("Second attempt succeeded!").postln;
                        } {
                            ("Both pairing attempts failed").postln;
                        };
                    } { |error|
                        ("Retry script error: " ++ error).postln;
                        success = false;
                    };
                };
                
                // Always update button, even if script failed
                {
                    ~pairingInProgress = false;  // Reset flag
                    if (success) {
                        // Re-detect MAC address after successful pairing
                        ~headtrackerMac = "bluetoothctl devices | grep 'HT' | awk '{print $2}'".unixCmdGetStdOut.stripWhiteSpace;
                        if (~headtrackerMac.isEmpty) {
                            ("Warning: Could not detect headtracker MAC after pairing").postln;
                        } {
                            ("Headtracker MAC detected: " ++ ~headtrackerMac).postln;
                        };
                        ~headtrackPairBtn.value_(2); // Success - stay cyan to show paired
                    } {
                        ~headtrackPairBtn.value_(3); // Failed - red X
                        // Reset to PAIR after 3 seconds only on failure
                        AppClock.sched(3, { 
                            ~headtrackPairBtn.value_(0); 
                            nil 
                        });
                    };
                }.defer;
            };
        }).start;
    });
// Ensure button is above overlays
~headtrackPairBtn.front;

// Simple connection monitor - checks initial status and monitors ongoing
~connectionMonitor = Routine({
    var checkResult, isConnected, isPaired, htMac;
    
    // Wait a bit before starting monitoring to avoid startup delays
    3.wait;
    
    // Additional short delay for headtracker detection to stabilize
    2.wait;
    
    // Check initial pairing status on first run
    if (~headtrackerMac.notEmpty) {
        checkResult = ("bluetoothctl info " ++ ~headtrackerMac).unixCmdGetStdOut;
        isConnected = checkResult.contains("Connected: yes");
        isPaired = checkResult.contains("Paired: yes");
    } {
        isConnected = false;
        isPaired = false;
    };
    
    if (isPaired && isConnected) {
        // Device is already paired and connected - show paired state
        {
            ~headtrackPairBtn.value_(2); // Show paired state
        }.defer;
    };
    
    // Simple monitoring loop
    loop {
        5.wait; // Check every 5 seconds
        
        // Check if button exists and not currently pairing
        // Use defer to access GUI elements from background thread
        {
            if ((~headtrackPairBtn.notNil) && (~pairingInProgress.not)) {
                // If MAC is empty, try to detect it (device might have reconnected)
                if (~headtrackerMac.isEmpty) {
                    ~headtrackerMac = "bluetoothctl devices | grep 'HT' | awk '{print $2}'".unixCmdGetStdOut.stripWhiteSpace;
                };
                
                if (~headtrackerMac.notEmpty) {
                    checkResult = ("bluetoothctl info " ++ ~headtrackerMac).unixCmdGetStdOut;
                    isConnected = checkResult.contains("Connected: yes");
                    isPaired = checkResult.contains("Paired: yes");
                    
                    if (isPaired && isConnected) {
                        // Device is paired and connected - show paired state
                        if (~headtrackPairBtn.value != 2) {
                            ~headtrackPairBtn.value_(2);
                        };
                    } {
                        if (isPaired.not || isConnected.not) {
                            // Device is disconnected/removed - reset button
                            if (~headtrackPairBtn.value != 0) {
                                ~headtrackPairBtn.value_(0);
                            };
                        };
                    };
                } {
                    // No headtracker MAC - reset button if not already reset
                    if (~headtrackPairBtn.value != 0) {
                        ~headtrackPairBtn.value_(0);
                    };
                };
            };
        }.defer;
    };
}).play;

// --- CONTROL LABELS ---
StaticText(mainView, Rect(594, 80, 55, 20)).string_("ROTATE").align_(\right).stringColor_(Color.cyan).font_(Font("Helvetica", 11));
StaticText(mainView, Rect(594, 162, 55, 20)).string_("TILT").align_(\right).stringColor_(Color.cyan).font_(Font("Helvetica", 11));
StaticText(mainView, Rect(594, 244, 55, 20)).string_("TUMBLE").align_(\right).stringColor_(Color.cyan).font_(Font("Helvetica", 11));

// --- ON/OFF TOGGLE BUTTON ---
~headtrackBtn = Button(mainView, Rect(742, 62, 40, 20))
    .states_([["OFF", Color.cyan, Color.black], ["ON", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({ |btn|
        var on = btn.value == 1;
        var idx = ~dmenu.value;
        var isBinaural = (idx == 1) or: { idx == 2 };
        // Remove overlays if present
        if(~knobOverlay.notNil) { ~knobOverlay.remove; ~knobOverlay = nil; };
        if(~htResetOverlay.notNil) { ~htResetOverlay.remove; ~htResetOverlay = nil; };
        if(isBinaural) {
            if(on) {
                // Headtracking ON: enable controls and show reset button
                ~headtrackResetBtn.enabled_(true);
                ~rotateKnob.enabled_(true);
                ~tiltKnob.enabled_(true);
                ~tumbleKnob.enabled_(true);
            } {
                // Headtracking OFF: disable controls and hide reset button
                ~headtrackResetBtn.enabled_(false);
                ~rotateKnob.enabled_(false);
                ~tiltKnob.enabled_(false);
                ~tumbleKnob.enabled_(false);
                ~knobOverlay = View(mainView, Rect(594, 60, 147, 224)) // width was 145, now 147
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
                ~htResetOverlay = View(mainView, Rect(734, 102, 51, 20)) // Cover RESET button, extended 3px right
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
            }
        }
    })
    .value_(0); // default OFF

// --- RESET BUTTON ---
~headtrackResetBtn = Button(mainView, Rect(742, 102, 40, 20))
    .states_([["RESET", Color.cyan, Color.black]])
    .font_(Font("Helvetica", 10))
    .focusColor_(Color.clear)
    .action_({
        // Reset both headtracker and quad panner - only the active one will have any effect
        ~rotateKnob.valueAction_(0.5); ~rotateKnob.enabled_(false);
        ~tiltKnob.valueAction_(0.5); ~tiltKnob.enabled_(false);
        ~tumbleKnob.valueAction_(0.5); ~tumbleKnob.enabled_(false);
        ~xyPanner.setXYActive(0.5, 0.5);
    });

// --- Now trigger the overlay/enable logic for the correct initial state ---
~dmenu.globalAction.value(~dmenu);

// --- Q-PANNER LABEL ---
StaticText(mainView, Rect(629, 299, 110, 22))
    .string_("Q-PANNER")
    .align_(\center)
    .stringColor_(Color.cyan)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .background_(Color.clear);
win.front;


// USB/ATK toggle button - aligned with encoder menu
~sourceToggleBtn = Button(mainView, Rect(28, 45, 140, 35))
    .states_([
        ["FOLDER : ATK", Color.cyan, Color.black],
        ["FOLDER : USB", Color.black, Color.cyan]
    ])
    .font_(Font("LCD 5x7 Segment Monospace", 11))
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({ |view|
        var isUSB, usbOptions;
        isUSB = view.value == 1;
        "Source switched to: ".post; (isUSB ? "USB" : "ATK").postln;
        
        // Stop playback immediately when switching folders
        if(~sfp.notNil, {
            ~sfp.pause;
            ~isPlaying = false;
            ~playerPlayBtn.value_(1); // Set to pause state
            ~playStartTime = 0;
            ~pausedTime = 0;
            if(~playerPositionSlider.notNil, {
                ~playerPositionSlider.value_(0);
            });
        });
        
        
        // Update artist menu based on source
        if(isUSB, {
            // USB mode - quietly run mount helper if present, then refresh folders
            var usbBase = ~usbBasePath.value;
            "are you there?".postln;
            "USB base resolved: ".post;
            if(usbBase.notNil) { usbBase.postln; } { "nil".postln; };
            if(usbBase.isNil, {
                "USB base not found".postln;
            });
            if(File.exists("/usr/local/bin/mount-usb"), {
                ("/usr/local/bin/mount-usb").unixCmdGetStdOut;
            });
            usbOptions = ~getUSBFolderOptions.value;
            ~artistMenu.items_(usbOptions);
        }, {
            // ATK mode - use same discovery logic as USB
            ~artistMenu.items_(~getATKFolderOptions.value);
        });
        // Reset artist menu selection and update album menu based on mode
        ~artistMenu.value_(0);
        
        if(isUSB, {
            // USB mode - build album list based on selected artist (same logic as ATK)
            var artistName = ~artistMenu.items[~artistMenu.value];
            var albumList;
            // Build album list for the selected artist
            var usbBase = ~usbBasePath.value;
            var artistPath;
            if(usbBase.isNil and: { Platform.name == \osx }, {
                usbBase = "/Volumes/UHJ";
            });
            if(usbBase.notNil, {
                var actualArtistName = PathName(usbBase).entries.select { |entry| entry.isFolder }.detect { |entry| 
                    entry.folderName.asString.toUpper == artistName 
                };
                artistPath = if(actualArtistName.notNil) { actualArtistName.fullPath } { usbBase +/+ artistName };
            }, {
                artistPath = "/tmp/";
            });
            
            if(File.exists(artistPath), {
                var entries = PathName(artistPath).entries.select { |entry| entry.isFolder and: { entry.folderName.asString.beginsWith(".").not } };
                var audioFiles = PathName(artistPath).entries.select { |entry| 
                    entry.isFile and: { 
                        var ext = entry.extension.asString.toLower;
                        (ext == "wav") or: (ext == "flac") or: (ext == "mp3") or: (ext == "aif") or: (ext == "aiff") or: (ext == "ogg") or: (ext == "m4a");
                    };
                };
                albumList = [];
                // Add album folders if they exist
                if(entries.size > 0) {
                    albumList = albumList ++ entries.collect { |entry| entry.folderName.asString.toUpper };
                };
                // Add <NO ALBUMS> if there are files outside album folders
                if(audioFiles.size > 0) {
                    albumList = albumList ++ ["<NO ALBUMS>"];
                };
                // Fallback if nothing found
                if(albumList.isEmpty) {
                    albumList = ["..."];
                };
            }, {
                albumList = ["..."];
            });
            
            ~albumMenu.items_(albumList);
            ~albumMenu.value_(0);
        }, {
            // ATK mode - build album list based on selected artist
            var artistName = ~artistMenu.items[~artistMenu.value];
            var albumList;
            // Build album list for the selected artist
            var atkBase = Atk.userSoundsDir ++ "/uhj";
            var actualArtistName = PathName(atkBase).entries.select { |entry| entry.isFolder }.detect { |entry| 
                entry.folderName.asString.toUpper == artistName 
            };
            var artistPath = if(actualArtistName.notNil) { actualArtistName.fullPath } { atkBase +/+ artistName };
            
            if(File.exists(artistPath), {
                var entries = PathName(artistPath).entries.select { |entry| entry.isFolder };
                var audioFiles = PathName(artistPath).entries.select { |entry| 
                    entry.isFile and: { 
                        var ext = entry.extension.asString.toLower;
                        (ext == "wav") or: (ext == "flac") or: (ext == "mp3") or: (ext == "aif") or: (ext == "aiff") or: (ext == "ogg") or: (ext == "m4a");
                    };
                };
                albumList = [];
                // Add album folders if they exist
                if(entries.size > 0) {
                    albumList = albumList ++ entries.collect { |entry| entry.folderName.asString.toUpper };
                };
                // Add <NO ALBUMS> if there are files outside album folders
                if(audioFiles.size > 0) {
                    albumList = albumList ++ ["<NO ALBUMS>"];
                };
                // Fallback if nothing found
                if(albumList.isEmpty) {
                    albumList = ["..."];
                };
            }, {
                albumList = ["..."];
            });
            ~albumMenu.items_(albumList);
            ~albumMenu.value_(0);
        });
        
        
        // Update file list and current path
        if(~fileList.notNil) { ~fileList.items_(~buildFileList.value); };
        ~currentAlbumPath = ~buildAlbumPath.value;
        // Refresh artwork when album path changes
        if(~updatePlayerControls.notNil, { ~updatePlayerControls.value; });
    });
// Create Artist and Album menus after window is visible
~artistMenu = PopUpMenu(mainView, Rect(28, 86, 140, 35))
    .items_( ~getATKFolderOptions.value )
    .font_(Font("LCD 5x7 Segment Monospace", 11))
    .background_(Color.black)
    .stringColor_(Color.cyan)
    .visible_(true)
    .canFocus_(true)
    .mouseDownAction_({ |view, x, y, modifiers, buttonNumber, clickCount|
        view.focus(true);
    })
    .action_({ |view|
        var artistName, albumList, isUSB, oldAction, albumMenuKey, artistMenuKey;
        "Artist menu clicked, value: ".post; view.value.postln;
        artistName = view.items[view.value];
        "Selected artist: ".post; artistName.postln;
        
        // Check if we're in USB mode
        isUSB = if(~sourceToggleBtn.notNil) { ~sourceToggleBtn.value == 1 } { false };
        
        if(~albumMenu.notNil) {
            if(isUSB, {
                // USB mode - show actual albums/folders in selected artist directory
                case 
                { artistName == "<NO DRIVE>" } { albumList = ["..."]; }
                {
                    // Get actual subdirectories in the artist folder (account for USB drive name being ignored)
                    var usbBase = ~usbBasePath.value;
                    var artistPath;
                    if(usbBase.isNil and: { Platform.name == \osx }, {
                        usbBase = "/Volumes/UHJ";
                    });
                    if(usbBase.notNil, {
                        var actualArtistName = PathName(usbBase).entries.select { |entry| entry.isFolder }.detect { |entry|
                            entry.folderName.asString.toUpper == artistName
                        };
                        artistPath = if(actualArtistName.notNil) { actualArtistName.fullPath } { usbBase +/+ artistName };
                    }, {
                        artistPath = "/tmp/" +/+ artistName;
                    });
                    
                    if(File.exists(artistPath), {
                        var entries = PathName(artistPath).entries.select { |entry| entry.isFolder and: { entry.folderName.asString.beginsWith(".").not } };
                        var audioFiles = PathName(artistPath).entries.select { |entry| 
                            entry.isFile and: { 
                                var ext = entry.extension.asString.toLower;
                                (ext == "wav") or: (ext == "flac") or: (ext == "mp3") or: (ext == "aif") or: (ext == "aiff") or: (ext == "ogg") or: (ext == "m4a");
                            };
                        };
                        albumList = [];
                        // Add album folders if they exist
                        if(entries.size > 0) {
                            albumList = albumList ++ entries.collect { |entry| entry.folderName.asString.toUpper };
                        };
                        // Add <NO ALBUMS> if there are files outside album folders
                        if(audioFiles.size > 0) {
                            albumList = albumList ++ ["<NO ALBUMS>"];
                        };
                        // Fallback if nothing found
                        if(albumList.isEmpty) {
                            albumList = ["..."];
                        };
                    }, {
                        albumList = ["..."];
                    });
                };
            }, {
                // ATK mode - show actual albums/folders in selected artist directory
                case 
                { artistName == "<NO DRIVE>" } { albumList = ["..."]; }
                {
                    // Get actual subdirectories in the artist folder (ATK base is the uhj folder directly)
                    var atkBase = Atk.userSoundsDir ++ "/uhj";
                    // Find the actual folder by case-insensitive matching
                    var actualArtistName = PathName(atkBase).entries.select { |entry| entry.isFolder }.detect { |entry| 
                        entry.folderName.asString.toUpper == artistName 
                    };
                    var artistPath = if(actualArtistName.notNil) { actualArtistName.fullPath } { atkBase +/+ artistName };
                    
                    if(File.exists(artistPath), {
                        var entries = PathName(artistPath).entries.select { |entry| entry.isFolder };
                        var audioFiles = PathName(artistPath).entries.select { |entry| 
                            entry.isFile and: { 
                                var ext = entry.extension.asString.toLower;
                                (ext == "wav") or: (ext == "flac") or: (ext == "mp3") or: (ext == "aif") or: (ext == "aiff") or: (ext == "ogg") or: (ext == "m4a");
                            };
                        };
                        albumList = [];
                        // Add album folders if they exist
                        if(entries.size > 0) {
                            albumList = albumList ++ entries.collect { |entry| entry.folderName.asString.toUpper };
                        };
                        // Add <NO ALBUMS> if there are files outside album folders
                        if(audioFiles.size > 0) {
                            albumList = albumList ++ ["<NO ALBUMS>"];
                        };
                        // Fallback if nothing found
                        if(albumList.isEmpty) {
                            albumList = ["..."];
                        };
                    }, {
                        albumList = ["..."];
                    });
                };
            });
            // Always clear and update album menu
            ~albumMenu.items_(albumList);
            // Temporarily disable action to prevent interference
            oldAction = ~albumMenu.action;
            ~albumMenu.action_(nil);
            ~albumMenu.value_(0);
            ~albumMenu.action_(oldAction);
            // Force refresh to ensure display updates
            ~albumMenu.refresh;
        };
        
        if(~fileList.notNil) { ~fileList.items_(~buildFileList.value); };
        ~currentAlbumPath = ~buildAlbumPath.value;
        // Refresh artwork when album path changes
        if(~updatePlayerControls.notNil, { ~updatePlayerControls.value; });
    });

~albumMenu = PopUpMenu(mainView, Rect(28, 127, 140, 35))
    .items_( ["..."] )
    .font_(Font("LCD 5x7 Segment Monospace", 11))
    .background_(Color.black)
    .stringColor_(Color.cyan)
    .visible_(true)
    .canFocus_(true)
    .mouseDownAction_({ |view, x, y, modifiers, buttonNumber, clickCount|
        view.focus(true);
    })
    .action_({ |view|
        "Album menu clicked, value: ".post; view.value.postln;
        if(~fileList.notNil) { ~fileList.items_(~buildFileList.value); };
        ~currentAlbumPath = ~buildAlbumPath.value;
        // Refresh artwork when album path changes
        if(~updatePlayerControls.notNil, { ~updatePlayerControls.value; });
    });

"Artist menu created: ".post; ~artistMenu.postln;
"Album menu created: ".post; ~albumMenu.postln;

// Debug menu properties
"Artist menu items: ".post; ~artistMenu.items.postln;
"Artist menu value: ".post; ~artistMenu.value.postln;
"Artist menu enabled: ".post; ~artistMenu.enabled.postln;
"Artist menu visible: ".post; ~artistMenu.visible.postln;
"Album menu items: ".post; ~albumMenu.items.postln;
"Album menu value: ".post; ~albumMenu.value.postln;
"Album menu enabled: ".post; ~albumMenu.enabled.postln;
"Album menu visible: ".post; ~albumMenu.visible.postln;

// Set smart default values with delay to ensure menus are ready
AppClock.sched(0.1, {
    var smartDefaults, defaultArtist, defaultAlbum, artistIndex, albumIndex, defaultArtistStr;
    smartDefaults = ~findSmartDefaults.value;
    defaultArtist = smartDefaults[0];
    defaultAlbum = smartDefaults[1];
    
    // Smart defaults found and will be applied
    
    // Find the index of the default artist in the menu using detectIndex (more reliable than indexOf)
    defaultArtistStr = defaultArtist.asString;
    artistIndex = ~artistMenu.items.detectIndex { |item| 
        item.asString == defaultArtistStr 
    };
    if(artistIndex.isNil, { artistIndex = 0; });
    
    ~artistMenu.value_(artistIndex);
    
    // Trigger artist menu action to populate album menu
    ~artistMenu.doAction;
    
    // Small delay to ensure album menu is populated
    AppClock.sched(0.05, {
        // Find the index of the default album in the populated menu
        albumIndex = ~albumMenu.items.detectIndex { |item| 
            item.asString == defaultAlbum.asString 
        };
        if(albumIndex.isNil, { albumIndex = 0; });
        
        ~albumMenu.value_(albumIndex);
        
        
        nil; // Don't repeat
    });
    
    nil; // Don't repeat
});
// --- Overlay Buttons (EQ, AMBIENCE, LAYOUT) below meter area ---
~eqBtn = Button(mainView, Rect(220, 410, 96, 35))
    .states_([ ["EQ", Color.cyan, Color.black], ["EQ", Color.black, Color.cyan] ])
    .font_(Font("Helvetica", 13))
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({ |btn|
        var freqs, eqWidth, sliderWidth, sliderHeight, startX, gap;
        if(btn.value == 0) {
            btn.value_(1);
            btn.focus(nil);
        };
        if(btn.value == 1) {
            // --- RADIO BUTTON BEHAVIOR: Only one overlay/button active at a time ---
            if(~ambienceOverlay.notNil) { 
                ~saveAmbienceState.value(); // Save state before removing ambience overlay
                ~ambienceOverlay.remove; ~ambienceOverlay = nil; ~ambienceBtn.value_(0); 
            };
            if(~layoutOverlay.notNil) { 
                ~layoutOverlay.remove; 
                ~layoutOverlay = nil; 
                ~layoutDiagramView = nil;
                ~layoutTitleText = nil;
                ~stereoLeftHit = nil; 
                ~stereoRightHit = nil;
                ~binauralLeftHit = nil;
                ~binauralRightHit = nil;
                ~binauralIrcamProfileLabel = nil;
                ~binauralIrcamSelectBtn = nil;
                if(~binauralIrcamChooserWin.notNil) { try { ~binauralIrcamChooserWin.close; }; ~binauralIrcamChooserWin = nil; };
                ~binauralCipicProfileLabel = nil;
                ~binauralCipicSelectBtn = nil;
                if(~binauralCipicChooserWin.notNil) { try { ~binauralCipicChooserWin.close; }; ~binauralCipicChooserWin = nil; };
                ~octagonS1Hit = nil;
                ~octagonS2Hit = nil;
                ~octagonS3Hit = nil;
                ~octagonS4Hit = nil;
                ~octagonS5Hit = nil;
                ~octagonS6Hit = nil;
                ~octagonS7Hit = nil;
                ~octagonS8Hit = nil;
                ~octagonS1Hit = nil;
                ~octagonS2Hit = nil;
                ~octagonS3Hit = nil;
                ~octagonS4Hit = nil;
                ~octagonS5Hit = nil;
                ~octagonS6Hit = nil;
                ~octagonS7Hit = nil;
                ~octagonS8Hit = nil;
        ~octagonS1Hit = nil;
        ~octagonS2Hit = nil;
        ~octagonS3Hit = nil;
        ~octagonS4Hit = nil;
        ~octagonS5Hit = nil;
        ~octagonS6Hit = nil;
        ~octagonS7Hit = nil;
        ~octagonS8Hit = nil;
                ~octagonS1Hit = nil;
                ~octagonS2Hit = nil;
                ~octagonS3Hit = nil;
                ~octagonS4Hit = nil;
                ~octagonS5Hit = nil;
                ~octagonS6Hit = nil;
                ~octagonS7Hit = nil;
                ~octagonS8Hit = nil;
                ~quadSquareFLHit = nil;
                ~quadSquareFRHit = nil;
                ~quadSquareRLHit = nil;
                ~quadSquareRRHit = nil;
                ~quadNarrowFLHit = nil;
                ~quadNarrowFRHit = nil;
                ~quadNarrowRLHit = nil;
                ~quadNarrowRRHit = nil;
                ~quadWideFLHit = nil;
                ~quadWideFRHit = nil;
                ~quadWideRLHit = nil;
                ~quadWideRRHit = nil;
            };
            if(~dimensionOverlay.notNil) { 
                ~saveDimensionState.value();
                ~saveMaplinState.value(); // Save state before removing maplin overlay
                ~dimensionOverlay.remove; ~dimensionOverlay = nil; ~dimensionBtn.value_(0); 
            };
            if(~playerOverlay.notNil) { 
                // Save button states before removing overlay
                if(~playerPlayBtn.notNil, { ~savedPlayerPlayState = ~playerPlayBtn.value; });
                if(~playerLoopBtn.notNil, { ~savedPlayerLoopState = ~playerLoopBtn.value; });
                ~playerOverlay.remove; ~playerOverlay = nil; ~playerBtn.value_(0); 
            };
            // Set other buttons to 0 (radio group)
            ~ambienceBtn.value_(0);
            ~layoutBtn.value_(0);
            ~dimensionBtn.value_(0);
            ~metersBtn.value_(0);
            ~playerBtn.value_(0);
            
            // Remove meters overlay when EQ is active
            if(~metersOverlay.notNil) { 
                ~metersOverlay.remove; ~metersOverlay = nil; 
            };
            // --- Remove any previous EQ overlay and controls to prevent duplicates ---
            if(~eqOverlay.notNil) { ~eqOverlay.remove; ~eqOverlay = nil; };
            ~eqSliders = nil; ~eqValues = nil; ~eqPresetMenu = nil;
            // Create EQ overlay directly in main window
            ~eqOverlay = View(mainView, Rect(180, 107, 320, 275)).background_(Color.black);
            UserView(~eqOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.white;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });
            StaticText(~eqOverlay, Rect(10, 5, 120, 20))
                .string_("GRAPHIC EQ")
                .align_(\left)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);
            // Only built-in presets by default (use symbols for names and keys)
            ~eqPresetNames = [\Flat, \Vocal, \BassBoost, \TrebleBoost, \RIAA];
            ~eqPresetDict = IdentityDictionary.newFrom([
                \Flat,        [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],
                \Vocal,       [0.4, 0.45, 0.6, 0.7, 0.6, 0.45, 0.4], // gentle mid boost
                \BassBoost,   [0.8, 0.7, 0.6, 0.5, 0.5, 0.5, 0.5],  // low bands up
                \TrebleBoost, [0.5, 0.5, 0.5, 0.5, 0.6, 0.7, 0.8],  // high bands up
                \RIAA,        [0.95, 0.85, 0.7, 0.55, 0.4, 0.25, 0.1]
            ]);
            // Define recall function for EQ presets
            ~recallEqPreset = {
                var name = ~eqPresetNames[~eqPresetMenu.value].asSymbol;
                if(~eqOverlay.notNil and: (~eqSliders.notNil)) {
                    if(~eqPresetDict.notNil and: { ~eqPresetDict[name].notNil }) {
                        ~eqPresetDict[name].do({ |val, i|
                            ~eqSliders[i].value_(val);
                            if(~eqSliders[i].action.notNil) {
                                ~eqSliders[i].action.value(~eqSliders[i]);
                            }
                        });
                    } {
                        // Fallback to flat if preset not found
                        ~eqSliders.do({ |slider, i|
                            slider.value_(0.5);
                            if(slider.action.notNil) {
                                slider.action.value(slider);
                            }
                        });
                    }
                }
            };
            ~eqPresetMenu = PopUpMenu(~eqOverlay, Rect(140, 7, 110, 20))
                .items_(~eqPresetNames.collect(_.asString))
                .font_(Font("Helvetica", 11))
                .background_(Color.black)
                .stringColor_(Color.cyan)
                .value_(0)
                .action_({
                    ~recallEqPreset.value;
                });
            Button(~eqOverlay, Rect(255, 7, 58, 20))
                .states_([["SAVE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 10))
                .action_({
                    var newName, values, customNum;
                    values = ~eqSliders.collect({ |slider| slider.value });
                    // Find next available custom preset number
                    if(~eqPresetNames.select({ |n| n.asString.beginsWith("Custom ") }).isEmpty) {
                        customNum = 1;
                    } {
                        customNum = ~eqPresetNames.select({ |n| n.asString.beginsWith("Custom ") })
                            .collect({ |n| n.asString.drop(7).asInteger })
                            .maxItem + 1;
                    };
                    newName = ("Custom " ++ customNum).asSymbol;
                    ~eqPresetNames = ~eqPresetNames.add(newName);
                    ~eqPresetMenu.items = ~eqPresetNames.collect(_.asString);
                    ~eqPresetMenu.value = ~eqPresetNames.size - 1;
                    if(~eqPresetDict.isNil) { ~eqPresetDict = IdentityDictionary.new; };
                    ~eqPresetDict[newName] = values;
                    ~recallEqPreset.value; // Ensure recall after adding
                });
            freqs = [63, 160, 400, 1000, 2500, 6400, 12000];
            sliderWidth = 32; sliderHeight = 140; startX = 12; gap = 44;
            // --- Draw tick marks BETWEEN the sliders (6 sets, not behind sliders) ---
            [44, 88, 132, 176, 220, 264].do({ |x|
                UserView(~eqOverlay, Rect(x, 55, 12, sliderHeight))
                    .background_(Color.clear)
                    .drawFunc_({ |view|
                        // Use absolute values for tick drawing
                        Pen.color = Color.cyan;
                        Pen.width = 1.5;
                        // Major ticks
                        Pen.line(Point(2, 0), Point(10, 0)); Pen.stroke; // +12dB
                        Pen.line(Point(2, 70), Point(10, 70)); Pen.stroke; // 0dB (halfway)
                        Pen.line(Point(2, 140), Point(10, 140)); Pen.stroke; // -12dB
                        // Minor ticks
                        Pen.width = 1;
                        Pen.line(Point(4, 35), Point(9, 35)); Pen.stroke; // +6dB
                        Pen.line(Point(4, 105), Point(9, 105)); Pen.stroke; // -6dB
                    });
            });
            freqs.do({ |freq, i|
                var x = startX + (i * gap);
                // Frequency label
                StaticText(~eqOverlay, Rect(x, 35, sliderWidth, 16))
                    .string_(if(freq >= 1000, (freq/1000).asString ++ "k", freq.asString))
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 10))
                    .background_(Color.clear);
            });
            // Create value labels first so they exist for slider actions
            ~eqValues = freqs.collect({ |freq, i|
                var x = startX + (i * gap);
                StaticText(~eqOverlay, Rect(x, 200, sliderWidth, 16))
                    .string_("0.0dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9))
                    .background_(Color.clear);
            });
            ~eqSliders = freqs.collect({ |freq, i|
                var x = startX + (i * gap);
                var slider = Slider(~eqOverlay, Rect(x, 55, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .background_(Color.clear)
                    .focusColor_(Color.clear)
                    .knobColor_(Color.cyan)
                    .value_(0.5)
                    .toolTip_("EQ BAND " ++ (i+1).asString)
                    .action_({ |sl|
                        var db = sl.value.linlin(0, 1, -12, 12);
                        if(~eqValues.notNil and: { ~eqValues[i].notNil }) {
                            ~eqValues[i].string = db.round(0.1).asString ++ "dB";
                        };
                        if(~synth.notNil) {
                            var eqParams = [\eq1, \eq2, \eq3, \eq4, \eq5, \eq6, \eq7];
                            ~synth.set(eqParams[i], db);
                        }
                    });
                slider.toolTip = "EQ BAND " ++ (i+1).asString;
                slider;
            });
            // Assign the preset recall action after controls are created
            ~eqPresetMenu.action_({
                ~recallEqPreset.value;
            });
            // --- Add dB scale numbers to the right of the rightmost slider ---
            [
                ["+12", 55],
                ["+6", 55 + 35],
                [" 0", 55 + 70],
                ["-6", 55 + 105],
                ["-12", 55 + 140]
            ].do({ |pair|
                var label, y;
                label = pair[0];
                y = pair[1];
                StaticText(~eqOverlay, Rect(startX + (6 * gap) + sliderWidth + 0, y - 8, 32, 16)) // moved 3px left
                    .string_(label)
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 7))
                    .background_(Color.clear);
            });
            Button(~eqOverlay, Rect(18, 230, 80, 28))
                .states_([["RESET", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~eqSliders.do({ |slider, i|
                        slider.value_(0.5);
                        ~eqValues[i].string_("0.0dB");
                        if(~synth.notNil) {
                            var eqParams = [\eq1, \eq2, \eq3, \eq4, \eq5, \eq6, \eq7];
                            ~synth.set(eqParams[i], 0);
                        }
                    });
                });
            Button(~eqOverlay, Rect(222, 230, 80, 28))
                .states_([["CLOSE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~saveEqState.value(); // Save state before closing
                    ~eqOverlay.remove;
                    ~eqOverlay = nil;
                    ~eqBtn.value_(0);
                });
            ~eqOverlay.front;
            // --- Restore EQ state after controls are created ---
            ~restoreEqState.value();
            // --- On open, set synth EQ params to current slider values ---
            if(~synth.notNil) {
                var eqParams = [\eq1, \eq2, \eq3, \eq4, \eq5, \eq6, \eq7];
                ~eqSliders.do({ |slider, i|
                    var db = slider.value.linlin(0, 1, -12, 12);
                    ~synth.set(eqParams[i], db);
                });
            }
        } {
            if(~eqOverlay.notNil) { ~eqOverlay.remove; ~eqOverlay = nil; };
            ~eqSliders = nil; ~eqValues = nil; ~eqPresetMenu = nil;
        }
    });
// --- AmbiVerbSC Preset Loading Function ---
~loadAmbiVerbSCPresets = {
    var presetDir, presetFiles, presetData, presetNames, presetDict;
    var extractParamValue, parsePresetFile, possiblePaths;

    // Try to find AmbiVerbSC preset files using multiple possible locations
    possiblePaths = [
        Quarks.folder ++ "/AmbiVerbSC/Data/Presets/",
        Quarks.folder ++ "/AmbiVerbSC/presets/",
        Quarks.folder ++ "/AmbiVerbSC/Data/",
        Platform.userExtensionDir ++ "/AmbiVerbSC/Data/Presets/",
        Platform.userExtensionDir ++ "/AmbiVerbSC/presets/",
        Platform.userExtensionDir ++ "/AmbiVerbSC/Data/",
        Platform.systemExtensionDir ++ "/AmbiVerbSC/Data/Presets/",
        Platform.systemExtensionDir ++ "/AmbiVerbSC/presets/",
        Platform.systemExtensionDir ++ "/AmbiVerbSC/Data/"
    ];

    presetDir = nil;
    presetFiles = [
        "default.txt",
        "high verb.txt",
        "huge hall.txt",
        "large hall.txt",
        "low verb.txt",
        "mod echo.txt",
        "spatial delay.txt",
        "time modulation .txt"
    ];

    // Function to extract parameter value from preset array
    extractParamValue = { |array, paramName|
        var index = array.indexOf(paramName);
        if(index.notNil and: { index + 1 < array.size }) {
            array[index + 1];
        } {
            nil;
        };
    };

    // Function to parse a single preset file using AmbiVerbSC's method
    parsePresetFile = { |filePath|
        var presetData, params;

        try {
            // Use AmbiVerbSC's own method to read preset files
            presetData = Object.readArchive(filePath);

            if(presetData.notNil) {
                // Extract the key parameters we need
                params = Dictionary.newFrom([
                    \roomName, presetData[\size] ? "Brahmssaal",
                    \mix, presetData[\mix] ? 0,
                    \preDelay, presetData[\preDelay] ? 0,
                    \lowRT, presetData[\lowRT] ? 0.01,
                    \highRT, presetData[\highRT] ? 0.01,
                    \dispersion, presetData[\dispersion] ? 1,
                    \modWidth, presetData[\modWidth] ? 0,
                    \modRate, presetData[\modRate] ? 0.01,
                    \coupRate, presetData[\coupRate] ? 0.001,
                    \coupAmt, presetData[\coupAmt] ? 0,
                    \phaseRotRate, presetData[\phaseRotRate] ? 0.001,
                    \phaseRotAmt, presetData[\phaseRotAmt] ? 0,
                    \phaseRotMix, presetData[\phaseRotMix] ? 1,
                    \crossoverFreq, presetData[\crossoverFreq] ? 1216.46,
                    \spread, presetData[\spread] ? 1,
                    \orient, presetData[\orient] ? 'flu'
                ]);
            } {
                params = Dictionary.new;
            };
        } { |error|
            ("Error loading preset file: " ++ filePath ++ " - " ++ error).postln;
            params = Dictionary.new;
        };

        params;
    };

    // Find the first valid path
    possiblePaths.do({ |path|
        if(presetDir.isNil and: { File.exists(path) }) {
            presetDir = path;
            ("Found AmbiVerbSC presets at: " ++ path).postln;
        };
    });

    if(presetDir.isNil) {
        ("AmbiVerbSC preset files not found in standard locations").postln;
        ("Using built-in room presets instead").postln;

        // Fallback to built-in room presets
        presetNames = List.new;
        presetDict = Dictionary.new;

        // Create simple presets using known AmbiVerbSC room names
        [
            ["default", "Brahmssaal", [0, 0, 0.01, 0.01, 1, 0, 0.01]],
            ["high verb", "Magna Auditorium", [0.63, 0, 0.01, 2.5, 0.76, 0.19, 0.037]],
            ["huge hall", "Goldener Saal", [0.8, 0.1, 0.5, 3.0, 0.5, 0.1, 0.02]],
            ["large hall", "Steinerner Saal", [0.6, 0.05, 0.3, 2.0, 0.8, 0.05, 0.01]],
            ["low verb", "Holzerner Saal", [0.3, 0, 0.1, 1.0, 0.9, 0.02, 0.005]]
        ].do({ |presetInfo|
            var name = presetInfo[0];
            var room = presetInfo[1];
            var params = presetInfo[2];

            presetNames.add(name);
            presetDict[name] = Dictionary.newFrom([
                \roomName, room,
                \mix, params[0],
                \preDelay, params[1],
                \lowRT, params[2],
                \highRT, params[3],
                \dispersion, params[4],
                \modWidth, params[5],
                \modRate, params[6]
            ]);
            ("Created built-in preset: " ++ name ++ " (Room: " ++ room ++ ")").postln;
        });

        [presetNames, presetDict];
    } {
        presetNames = List.new;
        presetDict = Dictionary.new;

        presetFiles.do({ |fileName|
            var filePath = presetDir ++ fileName;
            var presetName = fileName.replace(".txt", "");
            var presetData = parsePresetFile.(filePath);

            if(presetData.notEmpty) {
                presetNames.add(presetName);
                presetDict[presetName] = presetData;
                ("Loaded preset: " ++ presetName ++ " (Room: " ++ presetData[\roomName] ++ ")").postln;
            };
        });

        [presetNames, presetDict];
    };
};

// --- Ambience State Management Functions ---
~saveAmbienceState = {
    if(~ambienceSliders.notNil) {
        ~ambienceState[\sliderValues] = ~ambienceSliders.collect({ |slider| slider.value });
        ("Saved ambience state: " ++ ~ambienceState[\sliderValues]).postln;
    };
    if(~ambiencePresetMenu.notNil) {
        ~ambienceState[\presetIndex] = ~ambiencePresetMenu.value;
        ("Saved preset index: " ++ ~ambienceState[\presetIndex]).postln;
    };
    if(~ambienceLastMix.notNil) {
        ~ambienceState[\lastMix] = ~ambienceLastMix;
    };
    if(~ambienceOnOffBtn.notNil) {
        ~ambienceState[\active] = ~ambienceOnOffBtn.value;
    };
};

~restoreAmbienceState = {
    ~ambienceRestoring = true;
    if(~ambienceSliders.notNil and: { ~ambienceState[\sliderValues].notNil }) {
        ("Restoring ambience state: " ++ ~ambienceState[\sliderValues]).postln;
        ~ambienceSliders.do({ |slider, i|
            var savedValue = ~ambienceState[\sliderValues][i] ? 0.0;
            slider.value_(savedValue);
            if(slider.action.notNil) {
                slider.action.value(slider);
            };
        });
    };
    if(~ambiencePresetMenu.notNil and: { ~ambienceState[\presetIndex].notNil }) {
        ("Restoring preset index: " ++ ~ambienceState[\presetIndex]).postln;
        ~ambiencePresetMenu.value_(~ambienceState[\presetIndex]);
    };
    ~ambienceRestoring = false;
    if(~ambienceOnOffBtn.notNil) {
        var active = ~ambienceState[\active] ? 0;
        var mixSlider = if(~ambienceSliders.notNil and: { ~ambienceSliders.size > 2 }, { ~ambienceSliders[2] }, { nil });
        var mixVal = if(mixSlider.notNil, { mixSlider.value }, { ~ambienceLastMix ? 0 });
        ~ambienceOnOffBtn.value_(active);
        ~ambienceState[\active] = active;
        if(~synth.notNil) {
            if(active == 1) {
                ~synth.set(\ambience, mixVal.linlin(0, 1, 0, 0.2));
            } {
                ~synth.set(\ambience, 0);
            };
        };
    };
};
// --- EQ State Management Functions ---
~saveEqState = {
    if(~eqSliders.notNil) {
        ~eqState[\sliderValues] = ~eqSliders.collect({ |slider| slider.value });
        ("Saved EQ state: " ++ ~eqState[\sliderValues]).postln;
    };
    if(~eqPresetMenu.notNil) {
        ~eqState[\presetIndex] = ~eqPresetMenu.value;
        ("Saved EQ preset index: " ++ ~eqState[\presetIndex]).postln;
    };
};

~restoreEqState = {
    if(~eqSliders.notNil and: { ~eqState[\sliderValues].notNil }) {
        ("Restoring EQ state: " ++ ~eqState[\sliderValues]).postln;
        ~eqSliders.do({ |slider, i|
            var savedValue = ~eqState[\sliderValues][i] ? 0.5;
            slider.value_(savedValue);
            if(slider.action.notNil) {
                slider.action.value(slider);
            };
        });
    };
    if(~eqPresetMenu.notNil and: { ~eqState[\presetIndex].notNil }) {
        ("Restoring EQ preset index: " ++ ~eqState[\presetIndex]).postln;
        ~eqPresetMenu.value_(~eqState[\presetIndex]);
    };
};

// --- Dimension State Management Functions ---
~saveDimensionState = {
    if(~dimensionWidthKnob.notNil) {
        ~dimensionState[\sliderValues] = [
            ~dimensionWidthKnob.value,
            ~dimensionWidthHPFKnob.value,
            ~dimensionTrimKnob.value
        ];
        ("Saved dimension state: " ++ ~dimensionState[\sliderValues]).postln;
    };
    if(~dimensionPresetMenu.notNil) {
        ~dimensionState[\presetIndex] = ~dimensionPresetMenu.value;
        ("Saved dimension preset index: " ++ ~dimensionState[\presetIndex]).postln;
    };
};

~restoreDimensionState = {
    if(~dimensionWidthKnob.notNil and: { ~dimensionState[\sliderValues].notNil }) {
        var savedVals = ~dimensionState[\sliderValues];
        ("Restoring dimension state: " ++ savedVals).postln;
        if(savedVals.size >= 3) {
            ~dimensionWidthKnob.value_(savedVals[0] ? 0.0);
            ~dimensionWidthHPFKnob.value_(savedVals[1] ? 0.5);
            ~dimensionTrimKnob.value_(savedVals[2] ? 0.5);
            ~dimensionWidthKnob.action.value(~dimensionWidthKnob);
            ~dimensionWidthHPFKnob.action.value(~dimensionWidthHPFKnob);
            ~dimensionTrimKnob.action.value(~dimensionTrimKnob);
        } {
            if(savedVals.size >= 2) {
                ~dimensionWidthKnob.value_(savedVals[0] ? 0.0);
                ~dimensionWidthHPFKnob.value_(0.5);
                ~dimensionTrimKnob.value_(savedVals[1] ? 0.5);
                ~dimensionWidthKnob.action.value(~dimensionWidthKnob);
                ~dimensionWidthHPFKnob.action.value(~dimensionWidthHPFKnob);
                ~dimensionTrimKnob.action.value(~dimensionTrimKnob);
            } {
                if(savedVals.size >= 4) {
                    ~dimensionWidthKnob.value_(savedVals[0] ? 0.0);
                    ~dimensionWidthHPFKnob.value_(0.5);
                    ~dimensionTrimKnob.value_(savedVals[3] ? 0.5);
                    ~dimensionWidthKnob.action.value(~dimensionWidthKnob);
                    ~dimensionWidthHPFKnob.action.value(~dimensionWidthHPFKnob);
                    ~dimensionTrimKnob.action.value(~dimensionTrimKnob);
                };
            };
        };
    };
    if(~dimensionPresetMenu.notNil and: { ~dimensionState[\presetIndex].notNil }) {
        ("Restoring dimension preset index: " ++ ~dimensionState[\presetIndex]).postln;
        ~dimensionPresetMenu.value_(~dimensionState[\presetIndex]);
    };
};

// --- MAPLIN SM-333 CONTROL FUNCTIONS ---
~setMaplinSurround = { |level=0.8|
    ~maplinState[\surround] = level;
    if(~synth.notNil and: { configKeyE == \maplin }) { 
        ~synth.set(\maplinSurround, level);
    ("Maplin surround level: " ++ (level * 100).round(1) ++ "%").postln;
    } {
        if(configKeyE != \maplin) {
            ("Maplin surround level: " ++ (level * 100).round(1) ++ "% (Maplin encoder not selected)").postln;
        } {
            ("Maplin surround level: " ++ (level * 100).round(1) ++ "% (synth not ready)").postln;
        };
    };
};

~setMaplinEffect = { |level=0.8|
    ~maplinState[\effect] = level;
    if(~synth.notNil and: { configKeyE == \maplin }) { 
        ~synth.set(\maplinEffect, level);
    ("Maplin effect level: " ++ (level * 100).round(1) ++ "%").postln;
    } {
        if(configKeyE != \maplin) {
            ("Maplin effect level: " ++ (level * 100).round(1) ++ "% (Maplin encoder not selected)").postln;
        } {
            ("Maplin effect level: " ++ (level * 100).round(1) ++ "% (synth not ready)").postln;
        };
    };
};

~setMaplinDelay = { |time=0.4|
    var delayMs = time.linlin(0, 1, 5, 50);
    ~maplinState[\delay] = time;
    if(~synth.notNil and: { configKeyE == \maplin }) { 
        ~synth.set(\maplinDelay, time);
    ("Maplin delay time: " ++ delayMs.round(1) ++ "ms").postln;
    } {
        if(configKeyE != \maplin) {
            ("Maplin delay time: " ++ delayMs.round(1) ++ "ms (Maplin encoder not selected)").postln;
        } {
            ("Maplin delay time: " ++ delayMs.round(1) ++ "ms (synth not ready)").postln;
        };
    };
};

~setMaplinActive = { |active=true|
    var activeVal = if(active, 1, 0);
    ~maplinState[\active] = activeVal;
    ~dimensionActive = activeVal;
    
    if(~synth.notNil) {
        if(configKeyE == \maplin) {
            ~synth.set(\maplinActive, activeVal);
        };
        ~synth.set(\dimensionActive, activeVal);
        ("Maplin & Dimension: " ++ if(active, "ACTIVE", "BYPASSED")).postln;
    } {
        ("Maplin & Dimension: " ++ if(active, "ACTIVE", "BYPASSED") ++ " (synth not ready)").postln;
    };
};

// --- MAPLIN PRESET FUNCTIONS ---
~maplinPresetBalanced = {
    ~setMaplinSurround.(0.8);
    ~setMaplinEffect.(0.8);
    ~setMaplinDelay.(0.4);  // ~25ms
    "Maplin balanced preset applied".postln;
};

~maplinPresetMax = {
    ~setMaplinSurround.(1.0);
    ~setMaplinEffect.(1.0);
    ~setMaplinDelay.(1.0);  // ~50ms
    "Maplin maximum preset applied".postln;
};

// --- MAPLIN STATE MANAGEMENT FUNCTIONS ---
~saveMaplinState = {
    if(~maplinSurroundKnob.notNil) {
        ~maplinState[\surround] = ~maplinSurroundKnob.value;
        ~maplinState[\effect] = ~maplinEffectKnob.value;
        ~maplinState[\delay] = ~maplinDelayKnob.value;
        if(~maplinActiveBtn.notNil) {
            var activeVal = if(~maplinActiveBtn.value == 0, 1, 0);
            ~maplinState[\active] = activeVal;
            ~dimensionActive = activeVal;
    };
        ("Saved Maplin GUI state: surround=" ++ ~maplinState[\surround] ++ ", effect=" ++ ~maplinState[\effect] ++ ", delay=" ++ ~maplinState[\delay] ++ ", active=" ++ ~maplinState[\active]).postln;
};
};
~restoreMaplinState = {
    if(~maplinSurroundKnob.notNil) {
        ~maplinSurroundKnob.value_(~maplinState[\surround] ? 0.8);
        ~maplinEffectKnob.value_(~maplinState[\effect] ? 0.8);
        ~maplinDelayKnob.value_(~maplinState[\delay] ? 0.4);
        
        if(~maplinActiveBtn.notNil) {
            ~maplinActiveBtn.value_(if((~dimensionActive ? 1) == 1, 0, 1));
        };
        
        ~maplinSurroundValue.string_((~maplinState[\surround] * 100).round(1).asString ++ "%");
        ~maplinEffectValue.string_((~maplinState[\effect] * 100).round(1).asString ++ "%");
        ~maplinDelayValue.string_((~maplinState[\delay].linlin(0, 1, 5, 50).round(1).asString ++ " ms"));
        
        if(~maplinSurroundKnob.action.notNil) { ~maplinSurroundKnob.action.value(~maplinSurroundKnob); };
        if(~maplinEffectKnob.action.notNil) { ~maplinEffectKnob.action.value(~maplinEffectKnob); };
        if(~maplinDelayKnob.action.notNil) { ~maplinDelayKnob.action.value(~maplinDelayKnob); };
        if(~maplinActiveBtn.notNil) { ~maplinActiveBtn.action.value(~maplinActiveBtn); };
        
        ("Restored Maplin GUI state: surround=" ++ ~maplinState[\surround] ++ ", effect=" ++ ~maplinState[\effect] ++ ", delay=" ++ ~maplinState[\delay] ++ ", active=" ++ ~maplinState[\active]).postln;
    };
};
// --- Dimension overlay visibility helper ---
~updateDimensionOverlayVisibility = {
    if(~dimensionOverlay.notNil) {
        if(~dimensionRowOverlay.notNil) { ~dimensionRowOverlay.remove; ~dimensionRowOverlay = nil; };
        if(~maplinRowOverlay.notNil) { ~maplinRowOverlay.remove; ~maplinRowOverlay = nil; };
        
        if(configKeyE == \maplin) {
            ~dimensionRowOverlay = View(~dimensionOverlay, Rect(2, 28, 316, 110))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
        } {
            ~maplinRowOverlay = View(~dimensionOverlay, Rect(2, 118, 316, 103))
                .background_(Color.black.alpha_(0.7))
                .alpha_(1.0)
                .front;
        };
    };
};
// --- Synth Parameter State Management (for encoder/decoder changes) ---
~saveSynthParams = {
    var currentEqValues, currentAmbienceValues;
    
    ("Debug: Saving synth params. ~eqSliders = " ++ ~eqSliders ++ ", ~ambienceSliders = " ++ ~ambienceSliders).postln;
    
    // Always use stored state values - these are maintained by the GUI save/restore functions
    // Convert EQ slider values (0-1) to dB values (-12 to +12)
    if(~eqState[\sliderValues].notNil) {
        currentEqValues = ~eqState[\sliderValues].collect({ |sliderVal|
            if(sliderVal.notNil) {
                sliderVal.linlin(0, 1, -12, 12);
            } {
                0; // Default if value is nil
            };
        });
        ~eqState[\synthParams] = currentEqValues;
        ("Saved synth EQ params: " ++ currentEqValues).postln;
    } {
        // Use default flat EQ if no stored values
        ~eqState[\synthParams] = [0, 0, 0, 0, 0, 0, 0];
        ("Using default EQ params").postln;
    };
    
    // Use stored ambience values directly (they're already in synth parameter format)
    if(~ambienceState[\sliderValues].notNil) {
        ~ambienceState[\synthParams] = ~ambienceState[\sliderValues];
        ("Saved synth ambience params: " ++ ~ambienceState[\sliderValues]).postln;
    } {
        // Use default ambience settings if no stored values
        ~ambienceState[\synthParams] = [0.0, 0.2, 0.2, 0.2, 0.0, 0.0, 0.0];
        ("Using default ambience params").postln;
    };
};

~restoreSynthParams = {
    // Restore EQ parameters to new synth
    if(~synth.notNil and: { ~eqState[\synthParams].notNil }) {
        var eqParams = [\eq1, \eq2, \eq3, \eq4, \eq5, \eq6, \eq7];
        ~eqState[\synthParams].do({ |dbValue, i|
            if(dbValue.notNil and: { i < eqParams.size }) {
                ~synth.set(eqParams[i], dbValue);
            };
        });
        ("Restored synth EQ params: " ++ ~eqState[\synthParams]).postln;
    };
    
    // Restore ambience parameters to new synth
    if(~synth.notNil and: { ~ambienceState[\synthParams].notNil }) {
        var params, heightVal, heightDelayVal, mixVal, preDelayVal, sizeBase, lowRT, highRT, spreadVal, targetSnap;
        params = ~ambienceState[\synthParams];
        if(params.size >= 7) {
            heightVal = params[0] ? 0.0;
            heightDelayVal = params[1] ? 0.0;
            mixVal = params[2] ? 0.0;
            preDelayVal = params[3] ? 0.0;
            sizeBase = (params[4] ? 0.0).linlin(0, 1, 0.5, 2.5);
            lowRT = (sizeBase * 0.7).clip(0.1, 2.0);
            highRT = (sizeBase * 1.3).clip(0.2, 4.0);
            spreadVal = (params[5] ? 0.0).linlin(0, 1, 0.1, 2.0);
            targetSnap = if(params[6] < 0.25, 0.0, if(params[6] > 0.75, 1.0, 0.5));

            ~synth.set(
                \zsynthHeightAmount, heightVal * 100,
                \zsynthHeightDelay, heightDelayVal.linlin(0, 1, 0, 30),
                \ambience, if((~ambienceState[\active] ? 0) == 1, { mixVal.linlin(0, 1, 0, 0.2) }, { 0 }),
                \preDelay, preDelayVal.linlin(0, 1, 0, 0.5),
                \lowRT, lowRT,
                \highRT, highRT,
                \dispersion, spreadVal,
                \reverbTarget, if(targetSnap == 0.0, 0, if(targetSnap == 1.0, 2, 1))
            );
            if(~zsynthState[\heightSource].notNil) {
                ~synth.set(\zsynthHeightSource, ~zsynthState[\heightSource]);
            };
            ~ambienceLastMix = mixVal;
            ("Restored synth ambience/Z params: height=" ++ (heightVal * 100) ++ "%, mix=" ++ if((~ambienceState[\active] ? 0) == 1, { mixVal.linlin(0, 1, 0, 0.2) }, { 0 })).postln;
        } {
            ("Warning: ambience params array too small: " ++ params).postln;
        };
    };

    if(~synth.notNil and: { ~dimensionState[\sliderValues].notNil }) {
        var dimVals, width, widthHPF, trim;
        dimVals = ~dimensionState[\sliderValues];
        if(dimVals.size == 2) {
            dimVals = [dimVals[0], 0.5, dimVals[1]];
        } {
            if(dimVals.size >= 4) {
                dimVals = [dimVals[0], 0.5, dimVals[3]];
            };
        };
        width = (dimVals[0] ? 0.0) * 0.70;
        widthHPF = (dimVals[1] ? 0.5).linlin(0, 1, 80, 400);
        trim = (dimVals[2] ? 0.5).linlin(0, 1, -6, 6);
        ~synth.set(
            \dimensionWidth, width,
            \dimensionWidthHPF, widthHPF,
            \dimensionOutputTrim, trim,
            \dimensionActive, ~dimensionActive ? 1
        );
        ("Restored Dimension params: width=" ++ width ++ ", hpf=" ++ widthHPF ++ ", trim=" ++ trim ++ ", active=" ++ (~dimensionActive ? 1)).postln;
    };
    if(~synth.notNil) {
        var leftState, rightState, flGate, frGate, rlGate, rrGate, centerGate, subGate, tflGate, tfrGate, s1Gate, s2Gate, s3Gate, s4Gate, s5Gate, s6Gate, s7Gate, s8Gate;
        leftState = if((configKeyD == \binaural) or: { configKeyD == \binaurac }, { ~binauralState[\lOn] ? 1 }, { ~stereoState[\lOn] ? 1 });
        rightState = if((configKeyD == \binaural) or: { configKeyD == \binaurac }, { ~binauralState[\rOn] ? 1 }, { ~stereoState[\rOn] ? 1 });
        flGate = 1; frGate = 1; rlGate = 1; rrGate = 1;
        if(configKeyD == \quadsquare, {
            flGate = ~quadSquareState[\flOn] ? 1;
            frGate = ~quadSquareState[\frOn] ? 1;
            rlGate = ~quadSquareState[\rlOn] ? 1;
            rrGate = ~quadSquareState[\rrOn] ? 1;
        }, {
            if(configKeyD == \quadnarrow, {
                flGate = ~quadNarrowState[\flOn] ? 1;
                frGate = ~quadNarrowState[\frOn] ? 1;
                rlGate = ~quadNarrowState[\rlOn] ? 1;
                rrGate = ~quadNarrowState[\rrOn] ? 1;
            }, {
                if(configKeyD == \quadwide, {
                    flGate = ~quadWideState[\flOn] ? 1;
                    frGate = ~quadWideState[\frOn] ? 1;
                    rlGate = ~quadWideState[\rlOn] ? 1;
                    rrGate = ~quadWideState[\rrOn] ? 1;
                });
            });
        });
        centerGate = 1; subGate = 1; tflGate = 1; tfrGate = 1;
        s1Gate = 1; s2Gate = 1; s3Gate = 1; s4Gate = 1; s5Gate = 1; s6Gate = 1; s7Gate = 1; s8Gate = 1;
        if((configKeyD == \fivezero) or: { configKeyD == \fiveonetwo }) {
            flGate = ~dolbyState[\flOn] ? 1;
            frGate = ~dolbyState[\frOn] ? 1;
            rlGate = ~dolbyState[\rlOn] ? 1;
            rrGate = ~dolbyState[\rrOn] ? 1;
            centerGate = ~dolbyState[\centerOn] ? 1;
            subGate = ~dolbyState[\subOn] ? 1;
            tflGate = ~dolbyState[\tflOn] ? 1;
            tfrGate = ~dolbyState[\tfrOn] ? 1;
        };
        if(configKeyD == \octagon) {
            s1Gate = ~octagonState[\s1On] ? 1;
            s2Gate = ~octagonState[\s2On] ? 1;
            s3Gate = ~octagonState[\s3On] ? 1;
            s4Gate = ~octagonState[\s4On] ? 1;
            s5Gate = ~octagonState[\s5On] ? 1;
            s6Gate = ~octagonState[\s6On] ? 1;
            s7Gate = ~octagonState[\s7On] ? 1;
            s8Gate = ~octagonState[\s8On] ? 1;
        };
        ~synth.set(\lOn, leftState, \rOn, rightState, \flOn, flGate, \frOn, frGate, \rlOn, rlGate, \rrOn, rrGate);
        if((configKeyD == \fivezero) or: { configKeyD == \fiveonetwo }) {
            ~synth.set(
                \centerOn, ~dolbyState[\centerOn] ? 1,
                \subOn, ~dolbyState[\subOn] ? 1,
                \centerGain, ~dolbyState[\centerGain] ? 0.0,
                \subGain, ~dolbyState[\subGain] ? 0.0,
                \subLPF, ~dolbyState[\subLPF] ? 120
            );
            if(configKeyD == \fiveonetwo, {
                ~synth.set(
                    \tflOn, ~dolbyState[\tflOn] ? 1,
                    \tfrOn, ~dolbyState[\tfrOn] ? 1,
                    \heightGain, ~dolbyState[\heightGain] ? 0.0,
                    \topHPF, ~dolbyState[\topHPF] ? 2000
                );
            });
        };
        if(configKeyD == \octagon) {
            ~synth.set(
                \s1On, s1Gate,
                \s2On, s2Gate,
                \s3On, s3Gate,
                \s4On, s4Gate,
                \s5On, s5Gate,
                \s6On, s6Gate,
                \s7On, s7Gate,
                \s8On, s8Gate
            );
        };
    };
};
// --- AmbiVerbSC Preset Recall Function ---
~recallAmbiVerbSCPreset = { |presetName|
    var presetData, roomName, baseRT;

    if(~ambiencePresetDict.notNil and: { ~ambiencePresetDict[presetName].notNil }) {
        presetData = ~ambiencePresetDict[presetName];
        roomName = presetData[\roomName];

        if(roomName.isNil) {
            ("Warning: No room name found in preset " ++ presetName ++ ", using Brahmssaal").postln;
            roomName = "Brahmssaal";
        };

        if(~ambienceSliders.notNil) {
            // Index mapping: 2=Reverb, 3=RDelay, 4=RSize, 5=Spread
            ~ambienceSliders[2].value_(presetData[\mix].linlin(0, 1, 0, 1)); // Reverb mix
            ~ambienceSliders[3].value_((presetData[\preDelay] ? 0.0).clip(0, 0.25).linlin(0, 0.25, 0, 1)); // RDelay (clip 0-250ms)
            baseRT = (((presetData[\lowRT] / 0.7) + (presetData[\highRT] / 1.3)) * 0.5).clip(0.5, 2.5);
            ~ambienceSliders[4].value_(baseRT.linlin(0, 1, 0, 1)); // RSize macro
            ~ambienceSliders[5].value_(presetData[\dispersion].linlin(0.1, 2, 0, 1)); // Spread

            ~ambienceSliders.do({ |slider, i|
                if(slider.action.notNil) {
                    slider.action.value(slider);
                };
            });
        };

        if(~synth.notNil) {
            ~synth.set(
                \ambience, presetData[\mix].linlin(0, 1, 0, 0.2),
                \preDelay, presetData[\preDelay],
                \lowRT, presetData[\lowRT].clip(0.1, 2),
                \highRT, presetData[\highRT].clip(0.2, 4),
                \dispersion, presetData[\dispersion].clip(0.1, 2),
                \size, roomName.asSymbol
            );
        };

        ("Applied preset: " ++ presetName ++ " (Room: " ++ roomName ++ ")").postln;
    };
};

~ambienceBtn = Button(mainView, Rect(412, 410, 96, 35))
    .states_([["AMBIENCE", Color.cyan, Color.black], ["AMBIENCE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({ |btn|
        var params, sliderLabels, sliderWidth, sliderHeight, startX, gap, x, slider, valDisp;
        if(btn.value == 0) {
            btn.value_(1);
            btn.focus(nil);
        };
        if(btn.value == 1) {
            if(~eqOverlay.notNil) { 
                ~saveEqState.value();
                ~eqOverlay.remove; ~eqOverlay = nil; ~eqBtn.value_(0); 
            };
            if(~layoutOverlay.notNil) { 
                ~layoutOverlay.remove; 
                ~layoutOverlay = nil; 
                ~layoutDiagramView = nil;
                ~layoutTitleText = nil;
                ~stereoLeftHit = nil; 
                ~stereoRightHit = nil;
                ~binauralLeftHit = nil;
                ~binauralRightHit = nil;
                ~binauralIrcamProfileLabel = nil;
                ~binauralIrcamSelectBtn = nil;
                if(~binauralIrcamChooserWin.notNil) { try { ~binauralIrcamChooserWin.close; }; ~binauralIrcamChooserWin = nil; };
                ~binauralCipicProfileLabel = nil;
                ~binauralCipicSelectBtn = nil;
                if(~binauralCipicChooserWin.notNil) { try { ~binauralCipicChooserWin.close; }; ~binauralCipicChooserWin = nil; };
                ~octagonS1Hit = nil;
                ~octagonS2Hit = nil;
                ~octagonS3Hit = nil;
                ~octagonS4Hit = nil;
                ~octagonS5Hit = nil;
                ~octagonS6Hit = nil;
                ~octagonS7Hit = nil;
                ~octagonS8Hit = nil;
            };
            if(~dimensionOverlay.notNil) { 
                ~saveDimensionState.value();
                ~saveMaplinState.value();
                ~dimensionOverlay.remove; ~dimensionOverlay = nil; ~dimensionBtn.value_(0); 
            };
            if(~playerOverlay.notNil) { 
                if(~playerPlayBtn.notNil, { ~savedPlayerPlayState = ~playerPlayBtn.value; });
                if(~playerLoopBtn.notNil, { ~savedPlayerLoopState = ~playerLoopBtn.value; });
                ~playerOverlay.remove; ~playerOverlay = nil; ~playerBtn.value_(0); 
            };
            ~eqBtn.value_(0);
            ~layoutBtn.value_(0);
            ~dimensionBtn.value_(0);
            ~metersBtn.value_(0);
            ~playerBtn.value_(0);
            if(~metersOverlay.notNil) { 
                ~metersOverlay.remove; ~metersOverlay = nil; 
            };
            if(~ambienceOverlay.notNil) { ~ambienceOverlay.remove; ~ambienceOverlay = nil; };
            sliderWidth = 32; sliderHeight = 140; startX = 12; gap = 44;
            ~ambienceOverlay = View(mainView, Rect(180, 107, 320, 275)).background_(Color.black);
            UserView(~ambienceOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.white;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });
            StaticText(~ambienceOverlay, Rect(10, 7, 160, 20))
                .string_("REVERB PRESETS")
                .align_(\left)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);

            if(~ambiencePresetDict.isNil) {
                var presetData = ~loadAmbiVerbSCPresets.value();
                ~ambiencePresetNames = presetData[0];
                ~ambiencePresetDict = presetData[1];
            };

            ~ambiencePresetMenu = PopUpMenu(~ambienceOverlay, Rect(160, 7, 150, 20))
                .items_(["Default", "High Verb", "Huge Hall", "Large Hall", "Low Verb", "Mod Echo", "Spatial Delay", "Time Modulation"])
                .font_(Font("Helvetica", 11))
                .background_(Color.black)
                .stringColor_(Color.cyan)
                .value_(~ambienceState[\presetIndex] ? 0)
                .action_({ |menu|
                    var selectedPreset = ~ambiencePresetNames[menu.value];
                    ~recallAmbiVerbSCPreset.value(selectedPreset);
                });
            [44, 88, 132, 176, 220, 264].do({ |tx|
                UserView(~ambienceOverlay, Rect(tx, 55, 12, sliderHeight))
                    .background_(Color.clear)
                    .drawFunc_({ |view|
                        Pen.color = Color.cyan;
                        Pen.width = 1.5;
                        Pen.line(Point(2, 0), Point(10, 0)); Pen.stroke;
                        Pen.line(Point(2, 70), Point(10, 70)); Pen.stroke;
                        Pen.line(Point(2, 140), Point(10, 140)); Pen.stroke;
                        Pen.width = 1;
                        Pen.line(Point(4, 35), Point(9, 35)); Pen.stroke;
                        Pen.line(Point(4, 105), Point(9, 105)); Pen.stroke;
                    });
            });

            sliderLabels = ["Height", "HDelay", "Reverb", "RDelay", "RSize", "Spread", "Target"];
            params = ~ambienceState[\sliderValues] ? [0.3, 0.0, 0.0, 0.2, 0.0, 0.0, 0.0];
            ~ambienceLastMix = ~ambienceState[\lastMix] ? 0.5;
            ~ambienceSliders = List[];
            ~ambienceValues = List[];
            sliderLabels.do({ |label, i|
                x = startX + (i * gap);
                StaticText(~ambienceOverlay, Rect(x, 35, sliderWidth, 16))
                    .string_(label)
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 10))
                    .background_(Color.clear);
                slider = Slider(~ambienceOverlay, Rect(x, 55, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .knobColor_(Color.cyan)
                    .value_(params[i])
                    .action_({ |sl|
                        var valPct = (sl.value * 100).round(0.1);
                        var updateTargetReadout = { |snap|
                            var labelText = if(snap <= 0.25, "Lower", if(snap >= 0.75, "Height", "All"));
                            ~ambienceValues[i].string = labelText;
                        };
                        if(~synth.notNil) {
                            switch(i,
                                0, {
                                    ~ambienceValues[i].string = valPct.asString ++ "%";
                                    ~synth.set(\zsynthHeightAmount, (sl.value * 100));
                                },
                                1, {
                                    var ms = sl.value.linlin(0,1,0,30).round(0.1);
                                    ~ambienceValues[i].string = (ms.asString ++ "ms");
                                    ~synth.set(\zsynthHeightDelay, ms);
                                },
                                2, {
                                    var currentMix = sl.value;
                                    ~ambienceValues[i].string = valPct.asString ++ "%";
                                    if(~ambienceOnOffBtn.notNil and: { ~ambienceOnOffBtn.value == 1 }) {
                                        if(~synth.notNil) { ~synth.set(\ambience, currentMix.linlin(0, 1, 0, 0.2)); };
                                        ~ambienceLastMix = currentMix;
                                    } {
                                        ~ambienceLastMix = currentMix;
                                    };
                                    if(~ambienceRestoring.not and: { ~ambienceOnOffBtn.notNil }) {
                                        if(currentMix > 0 and: { ~ambienceOnOffBtn.value == 0 }) {
                                            ~ambienceOnOffBtn.valueAction_(1);
                                        } {
                                            if(currentMix <= 0 and: { ~ambienceOnOffBtn.value == 1 }) {
                                                ~ambienceOnOffBtn.valueAction_(0);
                                            };
                                        };
                                    };
                                },
                                3, {
                                    var pd = sl.value.linlin(0,1,0,0.25);
                                    ~ambienceValues[i].string = ((pd * 1000).round.asInteger.asString ++ "ms");
                                    ~synth.set(\preDelay, pd);
                                },
                                4, {
                                    var base = sl.value.linlin(0,1,0.5,2.5);
                                    var low = (base * 0.7).clip(0.1, 2.0);
                                    var high = (base * 1.3).clip(0.2, 4.0);
                                    ~ambienceValues[i].string = (base.round(0.01).asString ++ "s");
                                    ~synth.set(\lowRT, low); ~synth.set(\highRT, high);
                                },
                                5, {
                                    var disp = sl.value.linlin(0,1,0.1,2.0);
                                    ~ambienceValues[i].string = (disp.round(0.01).asString);
                                    ~synth.set(\dispersion, disp);
                                },
                                6, {
                                    var snap = if(sl.value < 0.25, 0.0, if(sl.value > 0.75, 1.0, 0.5));
                                    sl.value = snap;
                                    updateTargetReadout.(snap);
                                    ~reverbTarget = if(snap == 0.0, \lower, if(snap == 1.0, \height, \all));
                                    if(~synth.notNil) {
                                        ~synth.set(\reverbTarget, if(snap == 0.0, 0, if(snap == 1.0, 2, 1)));
                                    };
                                }
                            );
                        } {
                            switch(i,
                                0, { ~ambienceValues[i].string = valPct.asString ++ "%"; },
                                1, { ~ambienceValues[i].string = (sl.value.linlin(0,1,0,30).round(0.1).asString ++ " ms"); },
                                2, { ~ambienceValues[i].string = valPct.asString ++ "%"; },
                                3, { ~ambienceValues[i].string = (sl.value.linlin(0,1,0,0.5).round(0.01).asString ++ "s"); },
                                4, { ~ambienceValues[i].string = (sl.value.linlin(0,1,0.5,2.5).round(0.01).asString ++ "s"); },
                                5, { ~ambienceValues[i].string = (sl.value.linlin(0,1,0.1,2.0).round(0.01).asString); },
                                6, { updateTargetReadout.(if(sl.value < 0.25, 0.0, if(sl.value > 0.75, 1.0, 0.5))); }
                            );
                        }
                    });
                ~ambienceSliders.add(slider);
                valDisp = StaticText(~ambienceOverlay, Rect(x, 200, sliderWidth, 16))
                    .string_((params[i] * 100).asString ++ "%")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 10))
                    .background_(Color.clear);
                ~ambienceValues.add(valDisp);
            });
            ~ambienceSliders[0].action_({ |sl|
                var val = (sl.value * 100).round(0.1);
                ~ambienceValues[0].string = val.asString ++ "%";
                if(~synth.notNil and: { ~ambienceOnOffBtn.notNil and: { ~ambienceOnOffBtn.value == 1 } }) {
                    ~synth.set(\ambience, sl.value.linlin(0, 1, 0, 0.2));
                };
            });
            
            ~ambienceOnOffBtn = Button(~ambienceOverlay, Rect(120, 230, 80, 28))
                .states_([["REVERB", Color.cyan, Color.black], ["REVERB", Color.black, Color.cyan]])
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .value_(0)
                .action_({ |btn|
                    var mixSlider = if(~ambienceSliders.notNil and: { ~ambienceSliders.size > 2 }, { ~ambienceSliders[2] }, { nil });
                    if(btn.value == 1) {
                        var mixVal = if(mixSlider.notNil, { mixSlider.value }, { ~ambienceLastMix ? 0 });
                        if(mixVal <= 0 and: { ~ambienceLastMix.notNil and: { ~ambienceLastMix > 0 } }) {
                            mixVal = ~ambienceLastMix;
                            if(mixSlider.notNil) { mixSlider.value_(mixVal); };
                        };
                        ~ambienceLastMix = mixVal;
                        ~ambienceState[\active] = 1;
                        if(~synth.notNil) { ~synth.set(\ambience, mixVal.linlin(0, 1, 0, 0.2)); };
                    } {
                        var currentMix = if(mixSlider.notNil, { mixSlider.value }, { ~ambienceLastMix ? 0 });
                        ~ambienceLastMix = currentMix;
                        ~ambienceState[\active] = 0;
                        if(~synth.notNil) { ~synth.set(\ambience, 0); };
                    };
                });
            
            Button(~ambienceOverlay, Rect(222, 230, 80, 28))
                .states_([["RESET", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .action_({
                    if(~ambiencePresetNames.notNil and: { ~ambiencePresetNames.size > 0 }) {
                        ~ambiencePresetMenu.value_(0);
                        ~recallAmbiVerbSCPreset.value(~ambiencePresetNames[0]);
                    };
                });

            ~ambienceEnhanceBtn = Button(~ambienceOverlay, Rect(18, 230, 80, 28))
                .states_([["HEIGHT", Color.cyan, Color.black], ["HEIGHT", Color.black, Color.cyan]])
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .value_(~zsynthState[\heightSource] ? 0)
                .action_({ |btn|
                    var src = if(btn.value == 1, 1, 0);
                    ~zsynthState[\heightSource] = src;
                    if(~synth.notNil) { ~synth.set(\zsynthHeightSource, src); };
                });
            ~ambienceOverlay.front;
            if(~ambienceState[\sliderValues].notNil and: { ~ambienceState[\sliderValues].size > 0 }) {
                ("Found saved state, restoring...").postln;
                ~restoreAmbienceState.value();
            } {
                ("No saved state, applying default preset...").postln;
                if(~ambiencePresetNames.notNil and: { ~ambiencePresetNames.size > 0 }) {
                    ~recallAmbiVerbSCPreset.value(~ambiencePresetNames[0]);
                }
            }
        } {
            if(~ambienceOverlay.notNil) { ~ambienceOverlay.remove; ~ambienceOverlay = nil; };
        }
    });
// PLAYER button - aligned with left edge of picker windows
~playerBtn = Button(mainView, Rect(28, 410, 96, 35))
    .states_([["PLAYER", Color.cyan, Color.black], ["PLAYER", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({ |btn|
        if(btn.value == 0) {
            btn.value_(1);
            btn.focus(nil);
        };
        if(btn.value == 1) {
            // --- RADIO BUTTON BEHAVIOR: Only one overlay/button active at a time ---
            if(~eqOverlay.notNil) { 
                ~saveEqState.value(); // Save state before removing EQ overlay
                ~eqOverlay.remove; ~eqOverlay = nil; ~eqBtn.value_(0); 
            };
            if(~ambienceOverlay.notNil) { 
                ~saveAmbienceState.value(); // Save state before removing ambience overlay
                ~ambienceOverlay.remove; ~ambienceOverlay = nil; ~ambienceBtn.value_(0); 
            };
            if(~layoutOverlay.notNil) { 
                ~layoutOverlay.remove; 
                ~layoutOverlay = nil; 
                ~layoutDiagramView = nil;
                ~layoutTitleText = nil;
                ~stereoLeftHit = nil; 
                ~stereoRightHit = nil;
                ~binauralLeftHit = nil;
                ~binauralRightHit = nil;
                ~binauralIrcamProfileLabel = nil;
                ~binauralIrcamSelectBtn = nil;
                if(~binauralIrcamChooserWin.notNil) { try { ~binauralIrcamChooserWin.close; }; ~binauralIrcamChooserWin = nil; };
                ~binauralCipicProfileLabel = nil;
                ~binauralCipicSelectBtn = nil;
                if(~binauralCipicChooserWin.notNil) { try { ~binauralCipicChooserWin.close; }; ~binauralCipicChooserWin = nil; };
            };
            if(~dimensionOverlay.notNil) { 
                ~saveDimensionState.value();
                ~saveMaplinState.value(); // Save state before removing maplin overlay
                ~dimensionOverlay.remove; ~dimensionOverlay = nil; ~dimensionBtn.value_(0); 
            };
            // Set other buttons to 0 (radio group) - only if they exist
            if(~eqBtn.notNil, { ~eqBtn.value_(0); });
            if(~ambienceBtn.notNil, { ~ambienceBtn.value_(0); });
            if(~layoutBtn.notNil, { ~layoutBtn.value_(0); });
            if(~dimensionBtn.notNil, { ~dimensionBtn.value_(0); });
            if(~metersBtn.notNil, { ~metersBtn.value_(0); });
            
            // Remove meters overlay when player is active
            if(~metersOverlay.notNil) { 
                ~metersOverlay.remove; ~metersOverlay = nil; 
            };
            
            // Create PLAYER overlay in central area (only if it doesn't exist)
            if(~playerOverlay.isNil, {
            ~playerOverlay = View(mainView, Rect(180, 107, 320, 275)).background_(Color.black);
            
            // Add border around player panel
            UserView(~playerOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.white;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });
            
            // Title aligned with left edge of artwork
            StaticText(~playerOverlay, Rect(20, 5, 180, 30))
                .background_(Color.clear)
                .align_(\left)
                .string_("PLAYER")
                .font_(Font("Helvetica", 13).boldVariant)
                .stringColor_(Color.cyan);
            
            // Time display at top right, aligned with right edge of buttons
            ~playerTimeDisplay = StaticText(~playerOverlay, Rect(172, 5, 128, 30))
                .string_("00:00 / 00:00")
                .font_(Font("LCD 5x7 Segment Monospace", 11))
                .stringColor_(Color.cyan)
                .background_(Color.black)
                .align_(\center);
            
            // Large artwork positioned left in the panel
            ~playerArtwork = UserView(~playerOverlay, Rect(20, 40, 180, 180))
                .background_(Color.black)
                .drawFunc_({ |view|
                    var artworkPath, currentTrackPath, margin, imageSize, xOffset, yOffset, fallbackImage;
                    if(~currentAlbumPath.notNil, {
                        currentTrackPath = if(~filePaths.notNil and: { ~filePaths.size > 0 } and: { ~fileList.notNil }, {
                            var currentIdx = ~fileList.value ? 0;
                            ~filePaths[currentIdx];
                        });
                        artworkPath = ~findArtworkFile.value(~currentAlbumPath, currentTrackPath);
                        "=== DRAW FUNC CALLED ===".postln;
                        "Artwork debug - Album path: ".post; ~currentAlbumPath.postln;
                        "Artwork debug - Current track: ".post; currentTrackPath.postln;
                        "Artwork debug - Found artwork: ".post; artworkPath.postln;
                        "Artwork debug - artworkPath isNil: ".post; artworkPath.isNil.postln;
                        if(artworkPath.notNil, {
                            try {
                                var image = Image.open(artworkPath);
                                if(image.notNil, {
                                    image.drawInRect(
                                        Rect(0, 0, view.bounds.width, view.bounds.height),
                                        Rect(0, 0, image.width, image.height),
                                        2
                                    );
                                }, {
                                    Pen.color = Color.cyan;
                                    Pen.stringAtPoint("LOAD FAIL", Point(80, 100));
                                });
                            } { |error|
                                Pen.color = Color.cyan;
                                Pen.stringAtPoint("ERROR", Point(90, 100));
                            };
                        }, {
                            try {
                                fallbackImage = Image.open("assets/UHJ-Pi-180.png");
                                if(fallbackImage.notNil, {
                                    margin = 10;
                                    imageSize = view.bounds.width - (margin * 2);
                                    xOffset = margin;
                                    yOffset = (view.bounds.height - imageSize) / 2;
                                    fallbackImage.drawInRect(
                                        Rect(xOffset, yOffset, imageSize, imageSize),
                                        Rect(0, 0, fallbackImage.width, fallbackImage.height),
                                        0
                                    );
                        }, {
                            Pen.color = Color.cyan;
                            Pen.stringAtPoint("NO ART", Point(85, 100));
                                });
                            } { |error|
                                Pen.color = Color.cyan;
                                Pen.stringAtPoint("NO ART", Point(85, 100));
                            };
                        });
                    }, {
                        Pen.color = Color.cyan;
                        Pen.stringAtPoint("ARTWORK", Point(80, 100));
                    });
                });
            
            // Transport controls - stacked vertically to the right of artwork
            ~playerSkipToStartBtn = Button(~playerOverlay, Rect(220, 40, 80, 35))
                .states_([["", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 16).boldVariant)
                .canFocus_(false)
                .focusColor_(Color.clear)
                .action_({
                    if(~sfp.notNil, {
                        // Check if currently playing
                        var wasPlaying = ~sfp.isPlaying;
                        // Reset cursor to beginning and restart if was playing
                        ~sfp.startTime = 0; // Reset cursor to beginning
                        if(wasPlaying, { 
                            ~sfp.play; 
                        });
                        // Reset our timer
                        ~playStartTime = 0;
                        ~pausedTime = 0;
                        // Update slider position to reflect cursor reset
                        if(~playerPositionSlider.notNil, {
                            ~playerPositionSlider.value_(0);
                        });
                    });
                });


            ~playerPlayBtn = Button(~playerOverlay, Rect(220, 88, 80, 35))
                .states_([["", Color.black, Color.cyan], ["", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 16).boldVariant)
                .canFocus_(false)
                .focusColor_(Color.clear)
                .action_({ |btn|
                    var currentSeekTime;
                    if(~sfp.notNil, {
                        if(btn.value == 0, {
                            // Play (black icon on cyan background)
                            ~sfp.play;
                            ~isPlaying = true;
                            // Use existing timer state set by slider, or start from beginning
                            if(~pausedTime > 0, {
                                // Resume from paused position
                                ~playStartTime = SystemClock.seconds - ~pausedTime;
                                ~pausedTime = 0;
                            }, {
                                // Start from beginning if no paused position
                            ~playStartTime = SystemClock.seconds;
                            ~pausedTime = 0;
                            });
                        }, {
                            // Pause (cyan icon on black background)
                            ~sfp.pause;
                            ~isPlaying = false;
                            ~pausedTime = SystemClock.seconds - ~playStartTime;
                        });
                        // Refresh the play icon to update color
                        if(~playerOverlay.notNil, { ~playerOverlay.refresh; });
                    });
                })
                .value_(1); // Start in pause state (cyan icon on black background)
            ~playerStopBtn = Button(~playerOverlay, Rect(220, 136, 80, 35))
                .states_([["", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 16).boldVariant)
                .canFocus_(false)
                .focusColor_(Color.clear)
                .action_({
                    if(~sfp.notNil, {
                        // Stop playback and reset cursor to beginning
                        ~sfp.pause; // Stop playback
                        ~sfp.startTime = 0; // Reset cursor to beginning
                        // Stay stopped/paused
                        ~playerPlayBtn.value_(1); // Pause state (cyan icon on black background)
                        ~isPlaying = false;
                        // Reset internal timer state to match SFPlayer's cursor at zero
                        ~playStartTime = 0;
                        ~pausedTime = 0;
                        // Update slider position to reflect cursor reset
                        if(~playerPositionSlider.notNil, {
                            ~playerPositionSlider.value_(0);
                        });
                        // Refresh the play icon to update color
                        if(~playerOverlay.notNil, { ~playerOverlay.refresh; });
                    });
                });
            ~playerLoopBtn = Button(~playerOverlay, Rect(220, 184, 80, 35))
                .states_([["⟲", Color.cyan, Color.black], ["⟲", Color.black, Color.cyan]])
                .font_(Font("Helvetica", 30).boldVariant)
                .canFocus_(false)
                .focusColor_(Color.clear)
                .action_({ |btn|
                    if(~sfp.notNil, {
                        if(btn.value == 0, {
                            ~sfp.loop = false;
                        }, {
                            ~sfp.loop = true;
                        });
                    });
                })
                .value_(0); // Start with loop off


            // Position slider - positioned below buttons
            ~playerPositionSlider = Slider(~playerOverlay, Rect(20, 235, 280, 20))
                .background_(Color.black)
                .knobColor_(Color.cyan)
                .value_(0)
                .focusColor_(Color.clear)
                .action_({ |slider|
                    if(~sfp.notNil and: { ~sfp.sf.notNil and: { ~sfp.sf.duration > 0 } }, {
                        var seekTime = slider.value * ~sfp.sf.duration;
                        var wasPlaying = ~sfp.isPlaying;
                        // Set the start time to seek to position (like SFPlayer waveform click)
                        ~sfp.startTime = seekTime;
                        // Update our timer to match the seek position
                        if(~isPlaying, {
                            // If playing, calculate playStartTime so elapsed time equals seekTime
                        ~playStartTime = SystemClock.seconds - seekTime;
                        ~pausedTime = 0;
                        }, {
                            // If paused, just set the paused time to the seek position
                            ~playStartTime = 0;
                            ~pausedTime = seekTime;
                        });
                        // Force immediate time display update
                        ~updateTimeDisplay.value;
                    });
                });
            

            // Custom drawn icons - created after all buttons
            // Skip to start icon (bar + triangle)
            UserView(~playerOverlay, Rect(220, 40, 80, 35))
                .background_(Color.clear)
                .canFocus_(false)
                .mouseDownAction_({ 
                    if(~playerSkipToStartBtn.notNil, { 
                        ~playerSkipToStartBtn.doAction; 
                    });
                })
                .drawFunc_({ |v|
                    var w = v.bounds.width, h = v.bounds.height;
                    var centerX = w * 0.5;
                    var centerY = h * 0.5;
                    var iconSize = 20.0;
                    var barWidth = 3.0;
                    var barHeight = iconSize * 0.8;
                    
                    // Draw vertical bar
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(centerX - 8, centerY - (barHeight * 0.5), barWidth, barHeight));
                    Pen.fill;
                    
                    // Draw left-pointing triangle
                    Pen.color = Color.cyan;
                    Pen.moveTo(Point(centerX + 12, centerY - 8));
                    Pen.lineTo(Point(centerX - 4, centerY));
                    Pen.lineTo(Point(centerX + 12, centerY + 8));
                    Pen.fill;
                });

            // Play icon
            UserView(~playerOverlay, Rect(220, 88, 80, 35))
                .background_(Color.clear)
                .canFocus_(false)
                .mouseDownAction_({ 
                    if(~playerPlayBtn.notNil, {
                        ~playerPlayBtn.value_(if(~playerPlayBtn.value == 0, { 1 }, { 0 }));
                        ~playerPlayBtn.doAction; 
                    });
                })
                .drawFunc_({ |v|
                    var w = v.bounds.width, h = v.bounds.height;
                    var centerX = w * 0.5;
                    var centerY = h * 0.5;
                    var iconSize = 20.0;
                    var barWidth = 3.0;
                    var barHeight = iconSize * 0.8;
                    var iconColor = if(~playerPlayBtn.notNil and: { ~playerPlayBtn.value == 0 }, { Color.black }, { Color.cyan });
                    
                    // Draw vertical bar
                    Pen.color = iconColor;
                    Pen.addRect(Rect(centerX - 8, centerY - (barHeight * 0.5), barWidth, barHeight));
                    Pen.fill;
                    
                    // Draw right-pointing triangle
                    Pen.color = iconColor;
                    Pen.moveTo(Point(centerX - 3, centerY - 8));
                    Pen.lineTo(Point(centerX + 13, centerY));
                    Pen.lineTo(Point(centerX - 3, centerY + 8));
                    Pen.fill;
                });

            // Stop icon
            UserView(~playerOverlay, Rect(220, 136, 80, 35))
                .background_(Color.clear)
                .canFocus_(false)
                .mouseDownAction_({ 
                    if(~playerStopBtn.notNil, { ~playerStopBtn.doAction; });
                })
                .drawFunc_({ |v|
                    var w = v.bounds.width, h = v.bounds.height;
                    var centerX = w * 0.5;
                    var centerY = h * 0.5;
                    var iconSize = 16.0;
                    
                    // Draw square
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(centerX - (iconSize * 0.5), centerY - (iconSize * 0.5), iconSize, iconSize));
                    Pen.fill;
                });
            
            // Update player controls when track changes
            ~updatePlayerControls = {
                if(~playerArtwork.notNil, { ~playerArtwork.refresh; });
                // Button states are managed manually, not synced with SFPlayer
            };
            
            // Restore saved button color states (only if we have actually saved states)
            if(~playerPlayBtn.notNil and: { ~savedPlayerPlayState != -1 }, { ~playerPlayBtn.value_(~savedPlayerPlayState); });
            if(~playerLoopBtn.notNil and: { ~savedPlayerLoopState != -1 }, { ~playerLoopBtn.value_(~savedPlayerLoopState); });
            });
            
            // Make sure player overlay is visible
            if(~playerOverlay.notNil, { ~playerOverlay.front; });
        } {
            if(~playerOverlay.notNil) { ~playerOverlay.remove; ~playerOverlay = nil; };
        }
    })
    .valueAction_(1); // Start in player view and trigger action
// METERS button - between PLAYER and EQ buttons
~metersBtn = Button(mainView, Rect(124, 410, 96, 35))
    .states_([["METERS", Color.cyan, Color.black], ["METERS", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({ |btn|
        if(btn.value == 0) {
            btn.value_(1);
            btn.focus(nil);
        };
        if(btn.value == 1) {
            // Remove other overlays and reset their buttons
            if(~eqOverlay.notNil) { ~eqOverlay.remove; ~eqOverlay = nil; ~eqBtn.value_(0); };
            if(~ambienceOverlay.notNil) { ~ambienceOverlay.remove; ~ambienceOverlay = nil; ~ambienceBtn.value_(0); };
            if(~layoutOverlay.notNil) { 
                ~layoutOverlay.remove; 
                ~layoutOverlay = nil; 
                ~layoutDiagramView = nil;
                ~layoutTitleText = nil;
                ~stereoLeftHit = nil; 
                ~stereoRightHit = nil;
                ~binauralLeftHit = nil;
                ~binauralRightHit = nil;
                ~binauralIrcamProfileLabel = nil;
                ~binauralIrcamSelectBtn = nil;
                if(~binauralIrcamChooserWin.notNil) { try { ~binauralIrcamChooserWin.close; }; ~binauralIrcamChooserWin = nil; };
                ~binauralCipicProfileLabel = nil;
                ~binauralCipicSelectBtn = nil;
                if(~binauralCipicChooserWin.notNil) { try { ~binauralCipicChooserWin.close; }; ~binauralCipicChooserWin = nil; };
            };
            if(~dimensionOverlay.notNil) { ~dimensionOverlay.remove; ~dimensionOverlay = nil; ~dimensionBtn.value_(0); };
            if(~playerOverlay.notNil) { 
                // Save button states before removing overlay
                if(~playerPlayBtn.notNil, { ~savedPlayerPlayState = ~playerPlayBtn.value; });
                if(~playerLoopBtn.notNil, { ~savedPlayerLoopState = ~playerLoopBtn.value; });
                ~playerOverlay.remove; ~playerOverlay = nil; ~playerBtn.value_(0); 
            };
            
            // Create meters overlay (same area as other overlays)
            if(~metersOverlay.isNil) {
                ~metersOverlay = View(mainView, Rect(180, 107, 320, 275)).background_(Color.black);
                
                // Show meter view on top of overlay
                if(~meterView.notNil) {
                    ~meterView.front;
                };
            };
        } {
            // METERS button OFF - remove meters overlay
            if(~metersOverlay.notNil) { 
                ~metersOverlay.remove; ~metersOverlay = nil; 
            };
        }
    });
~layoutBtn = Button(mainView, Rect(508, 410, 100, 35))
    .states_([["LAYOUT", Color.cyan, Color.black], ["LAYOUT", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({ |btn|
        var currentDecoder, decoderNames, decoderName;
        if(btn.value == 0) {
            btn.value_(1);
            btn.focus(nil);
        };
        if(btn.value == 1) {
            // --- RADIO BUTTON BEHAVIOR: Only one overlay/button active at a time ---
            if(~eqOverlay.notNil) { 
                ~saveEqState.value(); // Save state before removing EQ overlay
                ~eqOverlay.remove; ~eqOverlay = nil; ~eqBtn.value_(0); 
            };
            if(~ambienceOverlay.notNil) { 
                ~saveAmbienceState.value(); // Save state before removing ambience overlay
                ~ambienceOverlay.remove; ~ambienceOverlay = nil; ~ambienceBtn.value_(0); 
            };
            if(~dimensionOverlay.notNil) { 
                ~saveDimensionState.value();
                ~saveMaplinState.value(); // Save state before removing maplin overlay
                ~dimensionOverlay.remove; ~dimensionOverlay = nil; ~dimensionBtn.value_(0); 
            };
            // Set other buttons to 0 (radio group)
            ~eqBtn.value_(0);
            ~ambienceBtn.value_(0);
            ~dimensionBtn.value_(0);
            ~metersBtn.value_(0);
            ~playerBtn.value_(0);
            
            // Remove meters overlay when LAYOUT is active
            if(~metersOverlay.notNil) { 
                ~metersOverlay.remove; ~metersOverlay = nil; 
            };
            if(~layoutOverlay.notNil) { 
                ~layoutOverlay.remove; 
                ~layoutOverlay = nil; 
            };
            if(~dolbyFLSquareBtn.notNil) { ~dolbyFLSquareBtn = nil; };
            if(~dolbyFRSquareBtn.notNil) { ~dolbyFRSquareBtn = nil; };
            if(~dolbyRLSquareBtn.notNil) { ~dolbyRLSquareBtn = nil; };
            if(~dolbyRRSquareBtn.notNil) { ~dolbyRRSquareBtn = nil; };
            if(~dolbyCenterSquareBtn.notNil) { ~dolbyCenterSquareBtn = nil; };
            if(~dolbySubSquareBtn.notNil) { ~dolbySubSquareBtn = nil; };
            if(~dolbyTopLeftSquareBtn.notNil) { ~dolbyTopLeftSquareBtn = nil; };
            if(~dolbyTopRightSquareBtn.notNil) { ~dolbyTopRightSquareBtn = nil; };
            if(~dolbyCenterGainSlider.notNil) { ~dolbyCenterGainSlider = nil; };
            if(~dolbyCenterGainLabel.notNil) { ~dolbyCenterGainLabel = nil; };
            if(~dolbySubGainSlider.notNil) { ~dolbySubGainSlider = nil; };
            if(~dolbySubGainLabel.notNil) { ~dolbySubGainLabel = nil; };
            if(~dolbyHeightGainSlider.notNil) { ~dolbyHeightGainSlider = nil; };
            if(~dolbyHeightGainLabel.notNil) { ~dolbyHeightGainLabel = nil; };
            if(~dolbyTopHpfSlider.notNil) { ~dolbyTopHpfSlider = nil; };
            if(~dolbyTopHpfLabel.notNil) { ~dolbyTopHpfLabel = nil; };
            if(~dolbyTopHpfValue.notNil) { ~dolbyTopHpfValue = nil; };
            if(~dolbySubLpfSlider.notNil) { ~dolbySubLpfSlider = nil; };
            if(~dolbySubLpfLabel.notNil) { ~dolbySubLpfLabel = nil; };
            if(~dolbySubLpfValue.notNil) { ~dolbySubLpfValue = nil; };
            if(~dolbyHeightOverlay.notNil) { try { ~dolbyHeightOverlay.remove; }; ~dolbyHeightOverlay = nil; };
            if(~dolbyTopLpfOverlay.notNil) { try { ~dolbyTopLpfOverlay.remove; }; ~dolbyTopLpfOverlay = nil; };
            if(~stereoLeftHit.notNil) { try { ~stereoLeftHit.remove; }; ~stereoLeftHit = nil; };
            if(~stereoRightHit.notNil) { try { ~stereoRightHit.remove; }; ~stereoRightHit = nil; };
            if(~binauralLeftHit.notNil) { try { ~binauralLeftHit.remove; }; ~binauralLeftHit = nil; };
            if(~binauralRightHit.notNil) { try { ~binauralRightHit.remove; }; ~binauralRightHit = nil; };
            if(~binauralIrcamProfileLabel.notNil) { try { ~binauralIrcamProfileLabel.remove; }; ~binauralIrcamProfileLabel = nil; };
            if(~binauralIrcamSelectBtn.notNil) { try { ~binauralIrcamSelectBtn.remove; }; ~binauralIrcamSelectBtn = nil; };
            if(~binauralIrcamChooserWin.notNil) { try { ~binauralIrcamChooserWin.close; }; ~binauralIrcamChooserWin = nil; };
            if(~binauralCipicProfileLabel.notNil) { try { ~binauralCipicProfileLabel.remove; }; ~binauralCipicProfileLabel = nil; };
            if(~binauralCipicSelectBtn.notNil) { try { ~binauralCipicSelectBtn.remove; }; ~binauralCipicSelectBtn = nil; };
            if(~binauralCipicChooserWin.notNil) { try { ~binauralCipicChooserWin.close; }; ~binauralCipicChooserWin = nil; };
            ~octagonS1Hit = nil;
            ~octagonS2Hit = nil;
            ~octagonS3Hit = nil;
            ~octagonS4Hit = nil;
            ~octagonS5Hit = nil;
            ~octagonS6Hit = nil;
            ~octagonS7Hit = nil;
            ~octagonS8Hit = nil;
            ~octagonS1Hit = nil;
            ~octagonS2Hit = nil;
            ~octagonS3Hit = nil;
            ~octagonS4Hit = nil;
            ~octagonS5Hit = nil;
            ~octagonS6Hit = nil;
            ~octagonS7Hit = nil;
            ~octagonS8Hit = nil;

            ~layoutOverlay = View(mainView, Rect(180, 107, 320, 275))
                .background_(Color.black); // Remove .alpha_(0.5) for full opacity
            // Add the title as StaticText at the top, centered
            StaticText(~layoutOverlay, Rect(
                if((~dmenu.value == 6) || (~dmenu.value == 7), 5, 10),
                5,
                if((~dmenu.value == 6) || (~dmenu.value == 7), 150, 300),
                22
            ))
                .string_((["STEREO", "BINAURAL IRCAM", "BINAURAL CIPIC", "QUAD SQUARE", "QUAD NARROW", "QUAD WIDE", "DOLBY 5.1", "DOLBY 5.1.2", "OCTAGON"][~dmenu.value ? 0]))
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);
            ~layoutDiagramView = UserView(~layoutOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |view|
                    var bounds = view.bounds;
                    var centerX = bounds.width / 2;
                    var centerY = bounds.height / 2;
                    var currentDecoderValue = ~dmenu.value;
                    // Draw cyan border (matching v28_ESI)
                    Pen.width = 0.5;
                    Pen.color = Color.cyan;
                    Pen.addRect(Rect(0.25, 0.25, bounds.width - 0.5, bounds.height - 0.5));
                    Pen.stroke;
                    Pen.width = 2;
                    switch(currentDecoderValue,
                        0, { // Stereo
                            var speakerWidth = 20, speakerHeight = 20, speakerSpacing = 120, leftSpeakerX, rightSpeakerX, speakerY;
                            var centerY_bottom = centerY + 80; // Center point further down at bottom of triangle
                            var leftRotationAngle, rightRotationAngle, leftCenterX, leftCenterY, rightCenterX, rightCenterY, leftOn, rightOn;
                            var speakerHalfWidth, speakerHalfHeight, speakerHalfSpacing;
                            speakerHalfWidth = speakerWidth * 0.5;
                            speakerHalfHeight = speakerHeight * 0.5;
                            speakerHalfSpacing = speakerSpacing * 0.5;
                            leftSpeakerX = centerX - speakerHalfSpacing - speakerHalfWidth;
                            rightSpeakerX = centerX + speakerHalfSpacing - speakerHalfWidth;
                            speakerY = centerY - 40; // Speakers at top of triangle
                            leftCenterX = leftSpeakerX + speakerHalfWidth;
                            leftCenterY = speakerY + speakerHalfHeight;
                            rightCenterX = rightSpeakerX + speakerHalfWidth;
                            rightCenterY = speakerY + speakerHalfHeight;
                            leftOn = ~stereoState[\lOn] ? 1;
                            rightOn = ~stereoState[\rOn] ? 1;
                            
                            // Calculate rotation angles based on speaker centres
                            leftRotationAngle = atan2(centerY_bottom - leftCenterY, centerX - leftCenterX) + (pi / 2);
                            rightRotationAngle = atan2(centerY_bottom - rightCenterY, centerX - rightCenterX) + (pi / 2);
                            
                            // Draw triangle guide lines
                            Pen.color = Color.cyan; Pen.width = 1;
                            // Left diagonal from center to left speaker
                            Pen.line(Point(centerX, centerY_bottom), Point(leftCenterX, leftCenterY));
                            Pen.stroke;
                            // Right diagonal from center to right speaker
                            Pen.line(Point(centerX, centerY_bottom), Point(rightCenterX, rightCenterY));
                            Pen.stroke;
                            
                            // Speaker 1: Left (mute button styling)
                            Pen.push;
                            Pen.translate(leftCenterX, leftCenterY);
                            Pen.rotate(leftRotationAngle + pi);
                            Pen.translate(0 - speakerHalfWidth, 0 - speakerHalfHeight);
                            if(leftOn == 1, {
                                Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.fill;
                                Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.stroke;
                                Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(0.5, 0.5, speakerWidth - 1, speakerHeight - 1), 2, 2); Pen.stroke;
                                Pen.stringAtPoint("1", Point(7, 4), Font("Helvetica", 13).boldVariant, Color.black);
                            }, {
                            Pen.color = Color.black; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.fill;
                                Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.stroke;
                                Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(0.5, 0.5, speakerWidth - 1, speakerHeight - 1), 2, 2); Pen.stroke;
                                Pen.stringAtPoint("1", Point(7, 4), Font("Helvetica", 13).boldVariant, Color.cyan);
                            });
                            Pen.pop;
                            // Speaker 2: Right (mute button styling)
                            Pen.push;
                            Pen.translate(rightCenterX, rightCenterY);
                            Pen.rotate(rightRotationAngle + pi);
                            Pen.translate(0 - speakerHalfWidth, 0 - speakerHalfHeight);
                            if(rightOn == 1, {
                                Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.fill;
                                Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.stroke;
                                Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(0.5, 0.5, speakerWidth - 1, speakerHeight - 1), 2, 2); Pen.stroke;
                                Pen.stringAtPoint("2", Point(7, 4), Font("Helvetica", 13).boldVariant, Color.black);
                            }, {
                            Pen.color = Color.black; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.fill;
                                Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.stroke;
                                Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(0.5, 0.5, speakerWidth - 1, speakerHeight - 1), 2, 2); Pen.stroke;
                                Pen.stringAtPoint("2", Point(7, 4), Font("Helvetica", 13).boldVariant, Color.cyan);
                            });
                            Pen.pop;
                            
                            Pen.stringAtPoint("[1] L (-30°) & [2] R (+30°)", Point(centerX - 75, 32), Font("Helvetica", 13), Color.cyan);
                            Pen.stringAtPoint("Optimum listening angles", Point(centerX - 70, 50), Font("Helvetica", 12, italic: true), Color.cyan);
                        },
                        1, { // IRCAM Binaural
                            var moveUp = 16;
                            var earCupWidth = 20, earCupHeight = 27, earCupOffset = 55, arcCenterY = centerY - 25 + 25 - moveUp, arcRadius = 47, leftEarX, leftEarY, rightEarX, rightEarY, leftOn, rightOn;
                            leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                            leftEarY = centerY + 25 + 25 - moveUp;
                            rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                            rightEarY = centerY + 25 + 25 - moveUp;
                            leftOn = ~binauralState[\lOn] ? 1;
                            rightOn = ~binauralState[\rOn] ? 1;
                            Pen.color = Color.cyan; Pen.width = 2;
                            Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi); Pen.stroke;
                            Pen.moveTo(Point(centerX - arcRadius, centerY - 30 + 25 - moveUp)); Pen.lineTo(Point(centerX - arcRadius, leftEarY)); Pen.stroke;
                            Pen.moveTo(Point(centerX + arcRadius, centerY - 30 + 25 - moveUp)); Pen.lineTo(Point(centerX + arcRadius, rightEarY)); Pen.stroke;
                            Pen.color = if(leftOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(leftEarX + 0.5, leftEarY + 0.5, earCupWidth - 1, earCupHeight - 1), 2, 2); Pen.stroke;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(leftEarX + 6, leftEarY + 7), Font("Helvetica", 13).boldVariant, if(leftOn == 1, { Color.black }, { Color.cyan }));
                            Pen.color = if(rightOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(rightEarX + 0.5, rightEarY + 0.5, earCupWidth - 1, earCupHeight - 1), 2, 2); Pen.stroke;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rightEarX + 6, rightEarY + 7), Font("Helvetica", 13).boldVariant, if(rightOn == 1, { Color.black }, { Color.cyan }));
                            // Do NOT move the description text
                            Pen.stringAtPoint("Headphone Listening using IRCAM HRTF Library", Point(centerX - 140, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        2, { // CIPIC Binaural
                            var moveUp = 16;
                            var earCupWidth = 20, earCupHeight = 27, earCupOffset = 55, arcCenterY = centerY - 25 + 25 - moveUp, arcRadius = 47, leftEarX, leftEarY, rightEarX, rightEarY, leftOn, rightOn;
                            leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                            leftEarY = centerY + 25 + 25 - moveUp;
                            rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                            rightEarY = centerY + 25 + 25 - moveUp;
                            leftOn = ~binauralState[\lOn] ? 1;
                            rightOn = ~binauralState[\rOn] ? 1;
                            Pen.color = Color.cyan; Pen.width = 2;
                            Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi); Pen.stroke;
                            Pen.moveTo(Point(centerX - arcRadius, centerY - 25 + 25 - moveUp)); Pen.lineTo(Point(centerX - arcRadius, leftEarY)); Pen.stroke;
                            Pen.moveTo(Point(centerX + arcRadius, centerY - 25 + 25 - moveUp)); Pen.lineTo(Point(centerX + arcRadius, rightEarY)); Pen.stroke;
                            Pen.color = if(leftOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(leftEarX + 0.5, leftEarY + 0.5, earCupWidth - 1, earCupHeight - 1), 2, 2); Pen.stroke;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(leftEarX + 6, leftEarY + 7), Font("Helvetica", 13).boldVariant, if(leftOn == 1, { Color.black }, { Color.cyan }));
                            Pen.color = if(rightOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(rightEarX + 0.5, rightEarY + 0.5, earCupWidth - 1, earCupHeight - 1), 2, 2); Pen.stroke;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rightEarX + 6, rightEarY + 7), Font("Helvetica", 13).boldVariant, if(rightOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("Headphone Listening using CIPIC HRTF Library", Point(centerX - 138, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        3, { // Quad Square - larger square (similar to v27)
                            var layoutSize = 140, diagramCenterX = 160, layoutLeft = diagramCenterX - (layoutSize / 2), layoutTop = 70, speakerSize = 18;
                            var frontLeftX = layoutLeft - 9, frontLeftY = layoutTop - 9;
                            var frontRightX = layoutLeft + layoutSize - 9, frontRightY = layoutTop - 9;
                            var surroundLeftX = layoutLeft - 9, surroundLeftY = layoutTop + layoutSize - 9 + 10;
                            var surroundRightX = layoutLeft + layoutSize - 9, surroundRightY = layoutTop + layoutSize - 9 + 10;
                            var flOn = ~quadSquareState[\flOn] ? 1;
                            var frOn = ~quadSquareState[\frOn] ? 1;
                            var rlOn = ~quadSquareState[\rlOn] ? 1;
                            var rrOn = ~quadSquareState[\rrOn] ? 1;
                            Pen.color = Color.cyan; Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize + 10)); Pen.stroke;
                            // FL
                            Pen.color = if(flOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(frontLeftX + 0.5, frontLeftY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 5, frontLeftY + 2), Font("Helvetica", 13).boldVariant, if(flOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("FL", Point(frontLeftX + 3, frontLeftY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // FR
                            Pen.color = if(frOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(frontRightX + 0.5, frontRightY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 5, frontRightY + 2), Font("Helvetica", 13).boldVariant, if(frOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("FR", Point(frontRightX + 3, frontRightY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // RL
                            Pen.color = if(rlOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(surroundLeftX + 0.5, surroundLeftY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("3", Point(surroundLeftX + 5, surroundLeftY + 2), Font("Helvetica", 13).boldVariant, if(rlOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("RL", Point(surroundLeftX + 3, surroundLeftY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // RR
                            Pen.color = if(rrOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(surroundRightX + 0.5, surroundRightY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundRightX + 5, surroundRightY + 2), Font("Helvetica", 13).boldVariant, if(rrOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("RR", Point(surroundRightX + 2, surroundRightY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                        },
                        4, { // Quad Narrow - taller rectangle (similar to v27)
                            var rectHeight = 160, rectWidth = 110, diagramCenterX = 160;
                            var rectLeft = diagramCenterX - (rectWidth / 2), rectTop = 60, speakerSize = 18;
                            var frontLeftX = rectLeft - 9, frontLeftY = rectTop - 9;
                            var frontRightX = rectLeft + rectWidth - 9, frontRightY = rectTop - 9;
                            var surroundLeftX = rectLeft - 9, surroundLeftY = rectTop + rectHeight - 9 + 8;
                            var surroundRightX = rectLeft + rectWidth - 9, surroundRightY = rectTop + rectHeight - 9 + 8;
                            var flOn = ~quadNarrowState[\flOn] ? 1;
                            var frOn = ~quadNarrowState[\frOn] ? 1;
                            var rlOn = ~quadNarrowState[\rlOn] ? 1;
                            var rrOn = ~quadNarrowState[\rrOn] ? 1;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight + 8)); Pen.stroke;
                            // FL
                            Pen.color = if(flOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(frontLeftX + 0.5, frontLeftY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 5, frontLeftY + 2), Font("Helvetica", 13).boldVariant, if(flOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("FL", Point(frontLeftX + 3, frontLeftY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // FR
                            Pen.color = if(frOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(frontRightX + 0.5, frontRightY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 5, frontRightY + 2), Font("Helvetica", 13).boldVariant, if(frOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("FR", Point(frontRightX + 3, frontRightY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // RL
                            Pen.color = if(rlOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(surroundLeftX + 0.5, surroundLeftY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("3", Point(surroundLeftX + 5, surroundLeftY + 2), Font("Helvetica", 13).boldVariant, if(rlOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("RL", Point(surroundLeftX + 3, surroundLeftY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // RR
                            Pen.color = if(rrOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(surroundRightX + 0.5, surroundRightY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundRightX + 5, surroundRightY + 2), Font("Helvetica", 13).boldVariant, if(rrOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("RR", Point(surroundRightX + 2, surroundRightY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                        },
                        5, { // Quad Wide - wider rectangle (similar proportions to v27)
                            var rectWidth = 170, rectHeight = 120, diagramCenterX = 160;
                            var rectLeft = diagramCenterX - (rectWidth / 2), rectTop = 78, speakerSize = 18;
                            var frontLeftX = rectLeft - 9, frontLeftY = rectTop - 9;
                            var frontRightX = rectLeft + rectWidth - 9, frontRightY = rectTop - 9;
                            var surroundLeftX = rectLeft - 9, surroundLeftY = rectTop + rectHeight - 9 + 8;
                            var surroundRightX = rectLeft + rectWidth - 9, surroundRightY = rectTop + rectHeight - 9 + 8;
                            var flOn = ~quadWideState[\flOn] ? 1;
                            var frOn = ~quadWideState[\frOn] ? 1;
                            var rlOn = ~quadWideState[\rlOn] ? 1;
                            var rrOn = ~quadWideState[\rrOn] ? 1;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight + 8)); Pen.stroke;
                            // FL
                            Pen.color = if(flOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(frontLeftX + 0.5, frontLeftY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 5, frontLeftY + 2), Font("Helvetica", 13).boldVariant, if(flOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("FL", Point(frontLeftX + 3, frontLeftY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // FR
                            Pen.color = if(frOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(frontRightX + 0.5, frontRightY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 5, frontRightY + 2), Font("Helvetica", 13).boldVariant, if(frOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("FR", Point(frontRightX + 3, frontRightY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // RL
                            Pen.color = if(rlOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(surroundLeftX + 0.5, surroundLeftY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("3", Point(surroundLeftX + 5, surroundLeftY + 2), Font("Helvetica", 13).boldVariant, if(rlOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("RL", Point(surroundLeftX + 3, surroundLeftY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // RR
                            Pen.color = if(rrOn == 1, { Color.cyan }, { Color.black }); Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(surroundRightX + 0.5, surroundRightY + 0.5, speakerSize - 1, speakerSize - 1), 2, 2); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundRightX + 5, surroundRightY + 2), Font("Helvetica", 13).boldVariant, if(rrOn == 1, { Color.black }, { Color.cyan }));
                            Pen.stringAtPoint("RR", Point(surroundRightX + 2, surroundRightY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                        },
                        6, { // Dolby 5.1
                            var layoutSize = 100, diagramCenterX = 80, layoutLeft = diagramCenterX - (layoutSize / 2), layoutTop = 84, speakerSize = 18;
                            var frontLeftX = layoutLeft - 9, frontLeftY = layoutTop - 9;
                            var frontRightX = layoutLeft + layoutSize - 9, frontRightY = layoutTop - 9;
                            var centerX_speaker = layoutLeft + (layoutSize / 2) - 9, centerY_speaker = layoutTop - 9;
                            var surroundLeftX = layoutLeft - 9, surroundLeftY = layoutTop + layoutSize - 9 + 7;
                            var surroundRightX = layoutLeft + layoutSize - 9, surroundRightY = layoutTop + layoutSize - 9 + 7;
                            var subwooferX = layoutLeft + (layoutSize / 2) - 9, subwooferY = layoutTop + (layoutSize / 2) - 9 + 7;
                            Pen.color = Color.cyan; Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize + 7)); Pen.stroke;
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 5, frontLeftY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("FL", Point(frontLeftX + 3, frontLeftY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 5, frontRightY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("FR", Point(frontRightX + 3, frontRightY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 3: Rear Left (RL)
                            Pen.color = Color.black; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(surroundLeftX + 5, surroundLeftY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("RL", Point(surroundLeftX + 3, surroundLeftY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 4: Rear Right (RR)
                            Pen.color = Color.black; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundRightX + 5, surroundRightY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("RR", Point(surroundRightX + 2, surroundRightY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 5: Center (C)
                            Pen.color = Color.black; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("5", Point(centerX_speaker + 5, centerY_speaker + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("C", Point(centerX_speaker + 5, centerY_speaker - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 6: Subwoofer (Sub = 6)
                            Pen.color = Color.cyan; Pen.addRect(Rect(subwooferX, subwooferY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("6", Point(subwooferX + 5, subwooferY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("SUB", Point(subwooferX - 1, subwooferY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                        },
                        7, { // Dolby 5.1.2
                            var layoutSize = 100, diagramCenterX = 80, layoutLeft = diagramCenterX - (layoutSize / 2), layoutTop = 84, speakerSize = 18;
                            var frontLeftX = layoutLeft - 9, frontLeftY = layoutTop - 9;
                            var frontRightX = layoutLeft + layoutSize - 9, frontRightY = layoutTop - 9;
                            var centerX_speaker = layoutLeft + (layoutSize / 2) - 9, centerY_speaker = layoutTop - 9;
                            var surroundLeftX = layoutLeft - 9, surroundLeftY = layoutTop + layoutSize - 9 + 7;
                            var surroundRightX = layoutLeft + layoutSize - 9, surroundRightY = layoutTop + layoutSize - 9 + 7;
                            var subwooferX = layoutLeft + (layoutSize / 2) - 9, subwooferY = layoutTop + (layoutSize / 2) - 9 + 7;
                            Pen.color = Color.cyan; Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize + 7)); Pen.stroke;
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 5, frontLeftY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("FL", Point(frontLeftX + 3, frontLeftY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 5, frontRightY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("FR", Point(frontRightX + 3, frontRightY - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 3: Rear Left (RL)
                            Pen.color = Color.black; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(surroundLeftX + 5, surroundLeftY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("RL", Point(surroundLeftX + 3, surroundLeftY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 4: Rear Right (RR)
                            Pen.color = Color.black; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundRightX + 5, surroundRightY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("RR", Point(surroundRightX + 2, surroundRightY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 5: Center (C)
                            Pen.color = Color.black; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("5", Point(centerX_speaker + 5, centerY_speaker + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("C", Point(centerX_speaker + 5, centerY_speaker - 12), Font("Helvetica", 10).boldVariant, Color.cyan);
                            // Speaker 6: Subwoofer (Sub = 6)
                            Pen.color = Color.cyan; Pen.addRect(Rect(subwooferX, subwooferY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("6", Point(subwooferX + 5, subwooferY + 2), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("SUB", Point(subwooferX - 1, subwooferY + speakerSize + 2), Font("Helvetica", 10).boldVariant, Color.cyan);
                        },
                        8, { // Octagon
                            var radius = 80, angleStep = 2 * pi / 8, startAngle = -22.5 * pi / 180, speakerPositions;
                            speakerPositions = Array.fill(8, { |i|
                                var angle = startAngle + (i * angleStep);
                                var x = centerX + (radius * cos(angle)) - 10;
                                var y = centerY + (radius * sin(angle)) - 10 + 25;
                                Point(x, y);
                            });
                            Pen.color = Color.cyan; Pen.addOval(Rect(centerX - radius, centerY - radius + 25, radius * 2, radius * 2)); Pen.stroke;
                            speakerPositions.do({ |pos, i|
                                var speakerNum = ((i + 2) % 8) + 1; // Shift so speaker 1 is front-left
                                var angle = startAngle + (i * angleStep);
                                var rotationAngle = angle + (pi / 2);
                                var key = ("s" ++ speakerNum.asString ++ "On").asSymbol;
                                var isOn = ~octagonState[key] ? 1;
                                Pen.push;
                                Pen.translate(pos.x + 10, pos.y + 10);
                                Pen.rotate(rotationAngle);
                                Pen.translate(-10, -10);
                                if(isOn == 1, {
                                    Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, 20, 20)); Pen.fill;
                                    Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, 20, 20)); Pen.stroke;
                                    Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(0.5, 0.5, 19, 19), 2, 2); Pen.stroke;
                                    Pen.stringAtPoint(speakerNum.asString, Point(7, 4), Font("Helvetica", 13).boldVariant, Color.black);
                                }, {
                                Pen.color = Color.black; Pen.addRect(Rect(0, 0, 20, 20)); Pen.fill;
                                Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, 20, 20)); Pen.stroke;
                                    Pen.width = 1; Pen.color = Color.grey(0.6); Pen.addRoundedRect(Rect(0.5, 0.5, 19, 19), 2, 2); Pen.stroke;
                                    Pen.stringAtPoint(speakerNum.asString, Point(7, 4), Font("Helvetica", 13).boldVariant, Color.cyan);
                                });
                                Pen.pop;
                            });
                            Pen.stringAtPoint("[1] FL (-22.5°), Clockwise @ 45°", Point(centerX - 84, 32), Font("Helvetica", 13), Color.cyan);
                        }
                    );
                });
            ~layoutOverlay.front;

            if(~dmenu.value == 6, {
                // All variable declarations must be at the absolute top of the block
                var layoutSize = 100, diagramCenterX = 80, layoutLeft = 30, layoutTop = 84, speakerSize = 18;
                var frontLeftX = 21, frontLeftY = 75;
                var frontRightX = 121, frontRightY = 75;
                var centerX_speaker = 71, centerY_speaker = 75;
                var surroundLeftX = 21, surroundLeftY = 182;
                var surroundRightX = 121, surroundRightY = 182;
                var subwooferX = 71, subwooferY = 132;
                var controlStartX = 170, controlY = 14, sliderWidth = 35, sliderHeight = 164, controlSpacing = 43;
                var rightmostFaderX;
                
                "Creating controls for Dolby 5.1 (case 6)".postln;
                
                // Speaker 1: Front Left (FL)
                ~dolbyFLSquareBtn = Button(~layoutOverlay, Rect(frontLeftX, frontLeftY, speakerSize, speakerSize))
                    .states_([
                        ["1", Color.black, Color.cyan],
                        ["1", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\flOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\flOn] = newState;
                        if(~synth.notNil) { ~synth.set(\flOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });
                
                // Speaker 2: Front Right (FR)
                ~dolbyFRSquareBtn = Button(~layoutOverlay, Rect(frontRightX, frontRightY, speakerSize, speakerSize))
                    .states_([
                        ["2", Color.black, Color.cyan],
                        ["2", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\frOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\frOn] = newState;
                        if(~synth.notNil) { ~synth.set(\frOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });
                
                // Speaker 3: Rear Left (RL)
                ~dolbyRLSquareBtn = Button(~layoutOverlay, Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize))
                    .states_([
                        ["3", Color.black, Color.cyan],
                        ["3", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\rlOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\rlOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rlOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });
                // Speaker 4: Rear Right (RR)
                ~dolbyRRSquareBtn = Button(~layoutOverlay, Rect(surroundRightX, surroundRightY, speakerSize, speakerSize))
                    .states_([
                        ["4", Color.black, Color.cyan],
                        ["4", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\rrOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\rrOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rrOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });
                // Speaker 5: Center (C)
                ~dolbyCenterSquareBtn = Button(~layoutOverlay, Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize))
                    .states_([
                        ["5", Color.black, Color.cyan],
                        ["5", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\centerOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\centerOn] = newState;
                        if(~synth.notNil) { ~synth.set(\centerOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });
                
                // Speaker 6: Subwoofer (SUB)
                ~dolbySubSquareBtn = Button(~layoutOverlay, Rect(subwooferX, subwooferY, speakerSize, speakerSize))
                    .states_([
                        ["6", Color.black, Color.cyan],
                        ["6", Color.cyan, Color.black]
                    ])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\subOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\subOn] = newState;
                        if(~synth.notNil) { ~synth.set(\subOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });
                
                // Fader controls for CENTER (now middle slot after swapping with SUB)
                StaticText(~layoutOverlay, Rect(controlStartX + controlSpacing, controlY, sliderWidth, 15))
                    .string_("C")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                ~dolbyCenterGainSlider = Slider(~layoutOverlay, Rect(controlStartX + controlSpacing, controlY + 18, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\centerGain] ? 0.0).linlin(-12, 12, 0, 1))
                    .action_({ |sl|
                        var gain = sl.value.linlin(0, 1, -12, 12);
                        ~dolbyState[\centerGain] = gain;
                        if(~dolbyCenterGainLabel.notNil) {
                            ~dolbyCenterGainLabel.string = gain.round(0.1).asString ++ "dB";
                        };
                        if(~synth.notNil) { ~synth.set(\centerGain, gain) };
                    });
                
                ~dolbyCenterGainLabel = StaticText(~layoutOverlay, Rect(controlStartX + controlSpacing, 199, sliderWidth, 15))
                    .string_((~dolbyState[\centerGain] ? 0.0).round(0.1).asString ++ "dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                // Fader controls for SUB (moved to rightmost slot)
                StaticText(~layoutOverlay, Rect(controlStartX + (controlSpacing * 2), controlY, sliderWidth, 15))
                    .string_("SUB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                ~dolbySubGainSlider = Slider(~layoutOverlay, Rect(controlStartX + (controlSpacing * 2), controlY + 18, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\subGain] ? 0.0).linlin(-12, 12, 0, 1))
                    .action_({ |sl|
                        var gain = sl.value.linlin(0, 1, -12, 12);
                        ~dolbyState[\subGain] = gain;
                        if(~dolbySubGainLabel.notNil) {
                            ~dolbySubGainLabel.string = gain.round(0.1).asString ++ "dB";
                        };
                        if(~synth.notNil) { ~synth.set(\subGain, gain) };
                    });
                
                ~dolbySubGainLabel = StaticText(~layoutOverlay, Rect(controlStartX + (controlSpacing * 2), 199, sliderWidth, 15))
                    .string_((~dolbyState[\subGain] ? 0.0).round(0.1).asString ++ "dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                
                // TOP (height) fader is still drawn, but visually dimmed by overlay (moved to leftmost slot)
                StaticText(~layoutOverlay, Rect(controlStartX, controlY, sliderWidth, 15))
                    .string_("TOP")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                ~dolbyHeightGainSlider = Slider(~layoutOverlay, Rect(controlStartX, controlY + 18, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\heightGain] ? 0.0).linlin(-12, 12, 0, 1))
                    .action_({ |sl|
                        var gain = sl.value.linlin(0, 1, -12, 12);
                        ~dolbyState[\heightGain] = gain;
                        if(~dolbyHeightGainLabel.notNil) {
                            ~dolbyHeightGainLabel.string = gain.round(0.1).asString ++ "dB";
                        };
                        if(~synth.notNil) { ~synth.set(\heightGain, gain) };
                    });

                ~dolbyHeightGainLabel = StaticText(~layoutOverlay, Rect(controlStartX, 199, sliderWidth, 15))
                    .string_((~dolbyState[\heightGain] ? 0.0).round(0.1).asString ++ "dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                // dB scale labels (single set on the right, after TOP fader to match 5.1.2)
                rightmostFaderX = controlStartX + (controlSpacing * 2) + sliderWidth;
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 14, 20, 15))
                    .string_("+12")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + (sliderHeight / 4) - 7, 20, 15))
                    .string_("+6")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + (sliderHeight / 2) - 7, 20, 15))
                    .string_("0")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + (sliderHeight * 3 / 4) - 7, 20, 15))
                    .string_("-6")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + sliderHeight - 7, 20, 15))
                    .string_("-12")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                
                // Draw tick marks BETWEEN the faders (between CENTER and SUB)
                UserView(~layoutOverlay, Rect(controlStartX + sliderWidth, controlY + 18, 8, sliderHeight))
                    .background_(Color.clear)
                    .drawFunc_({ |view|
                        Pen.color = Color.cyan;
                        Pen.width = 1.5;
                        // Major ticks
                        Pen.line(Point(2, 0), Point(6, 0)); Pen.stroke; // +12dB
                        Pen.line(Point(2, sliderHeight / 2), Point(6, sliderHeight / 2)); Pen.stroke; // 0dB
                        Pen.line(Point(2, sliderHeight), Point(6, sliderHeight)); Pen.stroke; // -12dB
                        // Minor ticks
                        Pen.width = 1;
                        Pen.line(Point(3, sliderHeight / 4), Point(5, sliderHeight / 4)); Pen.stroke; // +6dB
                        Pen.line(Point(3, sliderHeight * 3 / 4), Point(5, sliderHeight * 3 / 4)); Pen.stroke; // -6dB
                    });
                
                // Draw tick marks BETWEEN the faders (between SUB and TOP)
                UserView(~layoutOverlay, Rect(controlStartX + controlSpacing + sliderWidth, controlY + 18, 8, sliderHeight))
                    .background_(Color.clear)
                    .drawFunc_({ |view|
                        Pen.color = Color.cyan;
                        Pen.width = 1.5;
                        // Major ticks
                        Pen.line(Point(2, 0), Point(6, 0)); Pen.stroke; // +12dB
                        Pen.line(Point(2, sliderHeight / 2), Point(6, sliderHeight / 2)); Pen.stroke; // 0dB
                        Pen.line(Point(2, sliderHeight), Point(6, sliderHeight)); Pen.stroke; // -12dB
                        // Minor ticks
                        Pen.width = 1;
                        Pen.line(Point(3, sliderHeight / 4), Point(5, sliderHeight / 4)); Pen.stroke; // +6dB
                        Pen.line(Point(3, sliderHeight * 3 / 4), Point(5, sliderHeight * 3 / 4)); Pen.stroke; // -6dB
                    });

                // Semi-transparent overlay covering the TOP label, slider, and bottom value (dim entire fader block), now at leftmost slot
                if(~dolbyHeightOverlay.notNil) { ~dolbyHeightOverlay.remove; ~dolbyHeightOverlay = nil; };
                ~dolbyHeightOverlay = View(~layoutOverlay, Rect(controlStartX, controlY, sliderWidth + 8, (199 + 15) - controlY))
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;
                // Extra slender faders BELOW the diagram and vertical faders
                // Geometry: left aligns to right edge of speaker 3 box; right leaves space for value labels
                // TOP HPF - now top horizontal slender fader (swapped with SUB)
                ~dolbyTopHpfLabel = StaticText(~layoutOverlay, Rect((surroundLeftX + speakerSize) - 32 - 6 + 8, controlY + 18 + sliderHeight + 30 + 3, 56, 15))
                    .string_("TOP HPF")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                ~dolbyTopHpfSlider = Slider(~layoutOverlay, Rect((surroundLeftX + speakerSize) + 33, controlY + 18 + sliderHeight + 30, (((rightmostFaderX - 50) - (surroundLeftX + speakerSize)) - 9) - 2, 17))
                    .orientation_(\horizontal)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\topHPF] ? 2000).linlin(80, 4000, 0, 1))
                    .action_({ |sl|
                        var hz = (sl.value.linlin(0, 1, 80, 4000) / 10).round * 10; // 80-4000 Hz, stepped in 10s
                        ~dolbyState[\topHPF] = hz;
                        if(~dolbyTopHpfValue.notNil) { ~dolbyTopHpfValue.string = hz.asInteger.asString ++ " Hz"; };
                        if(~synth.notNil) { ~synth.set(\topHPF, hz) };
                    });
                ~dolbyTopHpfValue = StaticText(~layoutOverlay, Rect(controlStartX + (rightmostFaderX - controlStartX) - 28, controlY + 18 + sliderHeight + 30 + 1, 44, 15))
                    .string_((((~dolbyState[\topHPF] ? 2000) / 10).round * 10).asInteger.asString ++ " Hz")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                // SUB LPF - now bottom horizontal slender fader
                ~dolbySubLpfLabel = StaticText(~layoutOverlay, Rect((surroundLeftX + speakerSize) - 32 - 6 + 8, (controlY + 18 + sliderHeight + 30) + 18 + 6, 56, 15))
                    .string_("SUB LPF")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                ~dolbySubLpfSlider = Slider(~layoutOverlay, Rect((surroundLeftX + speakerSize) + 33, (controlY + 18 + sliderHeight + 30) + 22, (((rightmostFaderX - 50) - (surroundLeftX + speakerSize)) - 9) - 2, 17))
                    .orientation_(\horizontal)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\subLPF] ? 120).linlin(40, 200, 0, 1))
                    .action_({ |sl|
                        var hz = sl.value.linlin(0, 1, 40, 200); // 40-200 Hz
                        ~dolbyState[\subLPF] = hz;
                        if(~dolbySubLpfValue.notNil) { ~dolbySubLpfValue.string = hz.round.asInteger.asString ++ " Hz"; };
                        if(~synth.notNil) { ~synth.set(\subLPF, hz) };
                    });

                ~dolbySubLpfValue = StaticText(~layoutOverlay, Rect(controlStartX + (rightmostFaderX - controlStartX) - 28, (controlY + 18 + sliderHeight + 30 + 18) + 5, 44, 15))
                    .string_(((~dolbyState[\subLPF] ? 120)).round.asInteger.asString ++ " Hz")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                // Dim overlay for TOP HPF (label, fader, value) in Dolby 5.1 to match disabled TOP behavior (now top row)
                if(~dolbyTopLpfOverlay.notNil) { try { ~dolbyTopLpfOverlay.remove; }; ~dolbyTopLpfOverlay = nil; };
                ~dolbyTopLpfOverlay = View(
                    ~layoutOverlay,
                    Rect(
                        ((surroundLeftX + speakerSize) - 32 - 6 + 8) - 6, // a little left of label
                        (controlY + 18 + sliderHeight + 30) - 1,     // moved up 3px
                        ((controlStartX + (rightmostFaderX - controlStartX) + 44 + 6) - (((surroundLeftX + speakerSize) - 32 - 6 + 8) - 6)) - 34, // reduce right edge by 34px total
                        24 // reduce bottom by 10px (was 34)
                    )
                )
                    .background_(Color.black.alpha_(0.7))
                    .alpha_(1.0)
                    .front;

                // Bring all buttons to front so they're clickable
                ~dolbyFLSquareBtn.front;
                ~dolbyFRSquareBtn.front;
                ~dolbyRLSquareBtn.front;
                ~dolbyRRSquareBtn.front;
                ~dolbyCenterSquareBtn.front;
                ~dolbySubSquareBtn.front;
            });

            if(~dmenu.value == 7, {
                var layoutSize = 100, diagramCenterX = 80, layoutLeft = 30, layoutTop = 84, speakerSize = 18;
                var frontLeftX = 21, frontLeftY = 75;
                var frontRightX = 121, frontRightY = 75;
                var centerX_speaker = 71, centerY_speaker = 75;
                var surroundLeftX = 21, surroundLeftY = 182;
                var surroundRightX = 121, surroundRightY = 182;
                var subwooferX = 71, subwooferY = 132;
                var topFrontLeftX = 21, topFrontLeftY = 35;
                var topFrontRightX = 121, topFrontRightY = 35;
                var controlStartX = 170, controlY = 14, sliderWidth = 35, sliderHeight = 164, controlSpacing = 43;
                var rightmostFaderX;

                ("Creating controls for Dolby 5.1.2 (case 7), decoder value: " ++ ~dmenu.value).postln;

                ~dolbyFLSquareBtn = Button(~layoutOverlay, Rect(frontLeftX, frontLeftY, speakerSize, speakerSize))
                    .states_([["1", Color.black, Color.cyan], ["1", Color.cyan, Color.black]])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\flOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\flOn] = newState;
                        if(~synth.notNil) { ~synth.set(\flOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });

                ~dolbyFRSquareBtn = Button(~layoutOverlay, Rect(frontRightX, frontRightY, speakerSize, speakerSize))
                    .states_([["2", Color.black, Color.cyan], ["2", Color.cyan, Color.black]])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\frOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\frOn] = newState;
                        if(~synth.notNil) { ~synth.set(\frOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });

                ~dolbyRLSquareBtn = Button(~layoutOverlay, Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize))
                    .states_([["3", Color.black, Color.cyan], ["3", Color.cyan, Color.black]])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\rlOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\rlOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rlOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });

                ~dolbyRRSquareBtn = Button(~layoutOverlay, Rect(surroundRightX, surroundRightY, speakerSize, speakerSize))
                    .states_([["4", Color.black, Color.cyan], ["4", Color.cyan, Color.black]])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\rrOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\rrOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rrOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });

                ~dolbyCenterSquareBtn = Button(~layoutOverlay, Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize))
                    .states_([["5", Color.black, Color.cyan], ["5", Color.cyan, Color.black]])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\centerOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\centerOn] = newState;
                        if(~synth.notNil) { ~synth.set(\centerOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });

                ~dolbySubSquareBtn = Button(~layoutOverlay, Rect(subwooferX, subwooferY, speakerSize, speakerSize))
                    .states_([["6", Color.black, Color.cyan], ["6", Color.cyan, Color.black]])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\subOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\subOn] = newState;
                        if(~synth.notNil) { ~synth.set(\subOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });

                ~dolbyTopLeftSquareBtn = Button(~layoutOverlay, Rect(topFrontLeftX, topFrontLeftY, speakerSize, speakerSize))
                    .states_([["7", Color.black, Color.cyan], ["7", Color.cyan, Color.black]])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\tflOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\tflOn] = newState;
                        if(~synth.notNil) { ~synth.set(\tflOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });

                ~dolbyTopRightSquareBtn = Button(~layoutOverlay, Rect(topFrontRightX, topFrontRightY, speakerSize, speakerSize))
                    .states_([["8", Color.black, Color.cyan], ["8", Color.cyan, Color.black]])
                    .font_(Font("Helvetica", 13).boldVariant)
                    .focusColor_(Color.clear)
                    .value_(if((~dolbyState[\tfrOn] ? 1) == 1, 0, 1))
                    .action_({ |btn|
                        var newState = 1 - btn.value;
                        ~dolbyState[\tfrOn] = newState;
                        if(~synth.notNil) { ~synth.set(\tfrOn, newState) };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                        btn.focus(nil);
                    });

                StaticText(~layoutOverlay, Rect(controlStartX, controlY, sliderWidth, 15))
                    .string_("TOP")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                StaticText(~layoutOverlay, Rect(controlStartX + controlSpacing, controlY, sliderWidth, 15))
                    .string_("C")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);
                StaticText(~layoutOverlay, Rect(controlStartX + (controlSpacing * 2), controlY, sliderWidth, 15))
                    .string_("SUB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                ~dolbyHeightGainSlider = Slider(~layoutOverlay, Rect(controlStartX, controlY + 18, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\heightGain] ? 0.0).linlin(-12, 12, 0, 1))
                    .action_({ |sl|
                        var gain = sl.value.linlin(0, 1, -12, 12);
                        ~dolbyState[\heightGain] = gain;
                        if(~dolbyHeightGainLabel.notNil) { ~dolbyHeightGainLabel.string = gain.round(0.1).asString ++ "dB"; };
                        if(~synth.notNil) { ~synth.set(\heightGain, gain) };
                    });

                ~dolbyHeightGainLabel = StaticText(~layoutOverlay, Rect(controlStartX, 199, sliderWidth, 15))
                    .string_((~dolbyState[\heightGain] ? 0.0).round(0.1).asString ++ "dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                ~dolbyCenterGainSlider = Slider(~layoutOverlay, Rect(controlStartX + controlSpacing, controlY + 18, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\centerGain] ? 0.0).linlin(-12, 12, 0, 1))
                    .action_({ |sl|
                        var gain = sl.value.linlin(0, 1, -12, 12);
                        ~dolbyState[\centerGain] = gain;
                        if(~dolbyCenterGainLabel.notNil) { ~dolbyCenterGainLabel.string = gain.round(0.1).asString ++ "dB"; };
                        if(~synth.notNil) { ~synth.set(\centerGain, gain) };
                    });

                ~dolbyCenterGainLabel = StaticText(~layoutOverlay, Rect(controlStartX + controlSpacing, 199, sliderWidth, 15))
                    .string_((~dolbyState[\centerGain] ? 0.0).round(0.1).asString ++ "dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                ~dolbySubGainSlider = Slider(~layoutOverlay, Rect(controlStartX + (controlSpacing * 2), controlY + 18, sliderWidth, sliderHeight))
                    .orientation_(\vertical)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\subGain] ? 0.0).linlin(-12, 12, 0, 1))
                    .action_({ |sl|
                        var gain = sl.value.linlin(0, 1, -12, 12);
                        ~dolbyState[\subGain] = gain;
                        if(~dolbySubGainLabel.notNil) { ~dolbySubGainLabel.string = gain.round(0.1).asString ++ "dB"; };
                        if(~synth.notNil) { ~synth.set(\subGain, gain) };
                    });

                ~dolbySubGainLabel = StaticText(~layoutOverlay, Rect(controlStartX + (controlSpacing * 2), 199, sliderWidth, 15))
                    .string_((~dolbyState[\subGain] ? 0.0).round(0.1).asString ++ "dB")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                rightmostFaderX = controlStartX + (controlSpacing * 2) + sliderWidth;
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 14, 20, 15))
                    .string_("+12")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + (sliderHeight / 4) - 7, 20, 15))
                    .string_("+6")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + (sliderHeight / 2) - 7, 20, 15))
                    .string_("0")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + (sliderHeight * 3 / 4) - 7, 20, 15))
                    .string_("-6")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));
                StaticText(~layoutOverlay, Rect(rightmostFaderX + 4, controlY + 18 + sliderHeight - 7, 20, 15))
                    .string_("-12")
                    .align_(\left)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9));

                UserView(~layoutOverlay, Rect(controlStartX + sliderWidth, controlY + 18, 8, sliderHeight))
                    .background_(Color.clear)
                    .drawFunc_({ |view|
                        Pen.color = Color.cyan;
                        Pen.width = 1.5;
                        Pen.line(Point(2, 0), Point(6, 0)); Pen.stroke;
                        Pen.line(Point(2, sliderHeight / 2), Point(6, sliderHeight / 2)); Pen.stroke;
                        Pen.line(Point(2, sliderHeight), Point(6, sliderHeight)); Pen.stroke;
                        Pen.width = 1;
                        Pen.line(Point(3, sliderHeight / 4), Point(5, sliderHeight / 4)); Pen.stroke;
                        Pen.line(Point(3, sliderHeight * 3 / 4), Point(5, sliderHeight * 3 / 4)); Pen.stroke;
                    });

                UserView(~layoutOverlay, Rect(controlStartX + controlSpacing + sliderWidth, controlY + 18, 8, sliderHeight))
                    .background_(Color.clear)
                    .drawFunc_({ |view|
                        Pen.color = Color.cyan;
                        Pen.width = 1.5;
                        Pen.line(Point(2, 0), Point(6, 0)); Pen.stroke;
                        Pen.line(Point(2, sliderHeight / 2), Point(6, sliderHeight / 2)); Pen.stroke;
                        Pen.line(Point(2, sliderHeight), Point(6, sliderHeight)); Pen.stroke;
                        Pen.width = 1;
                        Pen.line(Point(3, sliderHeight / 4), Point(5, sliderHeight / 4)); Pen.stroke;
                        Pen.line(Point(3, sliderHeight * 3 / 4), Point(5, sliderHeight * 3 / 4)); Pen.stroke;
                    });

                if(~dolbyHeightOverlay.notNil) { try { ~dolbyHeightOverlay.remove; }; ~dolbyHeightOverlay = nil; };
                if(~dolbyTopLpfOverlay.notNil) { try { ~dolbyTopLpfOverlay.remove; }; ~dolbyTopLpfOverlay = nil; };

                ~dolbyTopHpfLabel = StaticText(~layoutOverlay, Rect((surroundLeftX + speakerSize) - 32 - 6 + 8, controlY + 18 + sliderHeight + 30 + 3, 56, 15))
                    .string_("TOP HPF")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                ~dolbyTopHpfSlider = Slider(~layoutOverlay, Rect((surroundLeftX + speakerSize) + 33, controlY + 18 + sliderHeight + 30, (((rightmostFaderX - 50) - (surroundLeftX + speakerSize)) - 9) - 2, 17))
                    .orientation_(\horizontal)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\topHPF] ? 2000).linlin(80, 4000, 0, 1))
                    .action_({ |sl|
                        var hz = (sl.value.linlin(0, 1, 80, 4000) / 10).round * 10;
                        ~dolbyState[\topHPF] = hz;
                        if(~dolbyTopHpfValue.notNil) { ~dolbyTopHpfValue.string = hz.asInteger.asString ++ " Hz"; };
                        if(~synth.notNil) { ~synth.set(\topHPF, hz) };
                    });

                ~dolbyTopHpfValue = StaticText(~layoutOverlay, Rect(controlStartX + (rightmostFaderX - controlStartX) - 28, controlY + 18 + sliderHeight + 30 + 2, 44, 15))
                    .string_((((~dolbyState[\topHPF] ? 2000) / 10).round * 10).asInteger.asString ++ " Hz")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                ~dolbySubLpfLabel = StaticText(~layoutOverlay, Rect((surroundLeftX + speakerSize) - 32 - 6 + 8, (controlY + 18 + sliderHeight + 30) + 18 + 6, 56, 15))
                    .string_("SUB LPF")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                ~dolbySubLpfSlider = Slider(~layoutOverlay, Rect((surroundLeftX + speakerSize) + 33, (controlY + 18 + sliderHeight + 30) + 22, (((rightmostFaderX - 50) - (surroundLeftX + speakerSize)) - 9) - 2, 17))
                    .orientation_(\horizontal)
                    .knobColor_(Color.cyan)
                    .background_(Color.black)
                    .focusColor_(Color.clear)
                    .value_((~dolbyState[\subLPF] ? 120).linlin(40, 200, 0, 1))
                    .action_({ |sl|
                        var hz = sl.value.linlin(0, 1, 40, 200);
                        ~dolbyState[\subLPF] = hz;
                        if(~dolbySubLpfValue.notNil) { ~dolbySubLpfValue.string = hz.round.asInteger.asString ++ " Hz"; };
                        if(~synth.notNil) { ~synth.set(\subLPF, hz) };
                    });

                ~dolbySubLpfValue = StaticText(~layoutOverlay, Rect(controlStartX + (rightmostFaderX - controlStartX) - 28, (controlY + 18 + sliderHeight + 30 + 18) + 6, 44, 15))
                    .string_(((~dolbyState[\subLPF] ? 120)).round.asInteger.asString ++ " Hz")
                    .align_(\right)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 11).boldVariant);

                ~dolbyFLSquareBtn.front;
                ~dolbyFRSquareBtn.front;
                ~dolbyRLSquareBtn.front;
                ~dolbyRRSquareBtn.front;
                ~dolbyCenterSquareBtn.front;
                ~dolbySubSquareBtn.front;
                ~dolbyTopLeftSquareBtn.front;
                ~dolbyTopRightSquareBtn.front;
            });

            if(~dmenu.value == 0) {
                var layoutBounds = ~layoutOverlay.bounds;
                var centerX = layoutBounds.width / 2;
                var centerY = layoutBounds.height / 2;
                var speakerWidth = 20;
                var speakerHeight = 20;
                var speakerSpacing = 120;
                var speakerHalfWidth = speakerWidth * 0.5;
                var speakerHalfHeight = speakerHeight * 0.5;
                var speakerHalfSpacing = speakerSpacing * 0.5;
                var speakerY = centerY - 40;
                var leftCenterX = centerX - speakerHalfSpacing;
                var leftCenterY = speakerY + speakerHalfHeight;
                var rightCenterX = centerX + speakerHalfSpacing;
                var rightCenterY = speakerY + speakerHalfHeight;

                if(~stereoLeftHit.notNil) { try { ~stereoLeftHit.remove; }; ~stereoLeftHit = nil; };
                if(~stereoRightHit.notNil) { try { ~stereoRightHit.remove; }; ~stereoRightHit = nil; };

                ~stereoLeftHit = UserView(~layoutOverlay, Rect(leftCenterX - speakerHalfWidth, leftCenterY - speakerHalfHeight, speakerWidth, speakerHeight))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~stereoState[\lOn] ? 1);
                        ~stereoState[\lOn] = newState;
                        if(~synth.notNil) { ~synth.set(\lOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~stereoLeftHit.front;

                ~stereoRightHit = UserView(~layoutOverlay, Rect(rightCenterX - speakerHalfWidth, rightCenterY - speakerHalfHeight, speakerWidth, speakerHeight))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~stereoState[\rOn] ? 1);
                        ~stereoState[\rOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~stereoRightHit.front;
            };

            if(~dmenu.value == 1) {
                var layoutBounds_b = ~layoutOverlay.bounds;
                var centerX_b = layoutBounds_b.width / 2;
                var centerY_b = layoutBounds_b.height / 2;
                var moveUp = 16;
                var earCupWidth = 20;
                var earCupHeight = 27;
                var earCupOffset = 55;
                var leftEarX = centerX_b - earCupOffset - (earCupWidth / 2);
                var leftEarY = centerY_b + 25 + 25 - moveUp;
                var rightEarX = centerX_b + earCupOffset - (earCupWidth / 2);
                var rightEarY = centerY_b + 25 + 25 - moveUp;
                var labelWidth, dropdownWidth, totalWidth, groupStartX, labelX, dropdownX, buttonH, gridRows, gridSpacing, yPos;

                if(~binauralIRCAMIds.isNil) {
                    ~binauralIRCAMIds = [1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1012, 1013, 1014, 1015, 1016, 1017, 1018, 1020, 1021, 1022, 1023, 1025, 1026, 1028, 1029, 1030, 1031, 1032, 1033, 1034, 1037, 1038, 1039, 1040, 1041, 1042, 1043, 1044, 1045, 1046, 1047, 1048, 1049, 1050, 1051, 1052, 1053, 1054, 1055, 1056, 1057, 1058, 1059];
                };
                ~binauralIRCAMPendingId = ~binauralIRCAMId;

                gridRows = 8;
                gridSpacing = 3;
                buttonH = ((layoutBounds_b.height - 3 - (9 * gridSpacing)) / gridRows).floor;
                labelWidth = 90;
                dropdownWidth = 80;
                totalWidth = labelWidth + dropdownWidth;
                groupStartX = (320 - totalWidth) / 2;
                labelX = groupStartX;
                dropdownX = groupStartX + labelWidth;
                yPos = 240 - 7;

                ~binauralIrcamProfileLabel = StaticText(~layoutOverlay, Rect(labelX, yPos, labelWidth, buttonH))
                    .string_("PROFILE")
                    .stringColor_(Color.cyan)
                    .font_(Font("LCD 5x7 Segment Monospace", 13))
                    .align_(\left)
                    .background_(Color.clear);
                ~binauralIrcamProfileLabel.front;

                ~binauralIrcamSelectBtn = Button(~layoutOverlay, Rect(dropdownX, yPos, dropdownWidth, buttonH))
                    .states_([[ (~binauralIRCAMPendingId.asString.padLeft(4, "0")), Color.cyan, Color.black ],
                              [ (~binauralIRCAMPendingId.asString.padLeft(4, "0")), Color.cyan, Color.black ]])
                    .font_(Font("LCD 5x7 Segment Monospace", 11))
                    .focusColor_(Color.clear)
                    .canFocus_(false)
                    .action_({
                        var layoutBounds, winWidth, winHeight, mainViewBounds, winBounds, winX, winY, cols, rows, spacing, buttonW, totalUsedW, totalUsedH, extraW, extraH, startX, startY, chooserView;

                        if(~binauralIrcamChooserWin.notNil) { try { ~binauralIrcamChooserWin.close; }; ~binauralIrcamChooserWin = nil; };

                        layoutBounds = ~layoutOverlay.bounds;
                        winWidth = layoutBounds.width - 3;
                        winHeight = layoutBounds.height - 3;
                        mainViewBounds = mainView.bounds;
                        winBounds = win.bounds;
                        winX = winBounds.left + mainViewBounds.left + layoutBounds.left + 2;
                        winY = winBounds.top + mainViewBounds.top + layoutBounds.top - 8;
                        cols = 6; rows = 8; spacing = 3;
                        buttonW = ((winWidth - (7 * spacing)) / cols).floor;
                        buttonH = ((winHeight - (9 * spacing)) / rows).floor;
                        totalUsedW = (cols * buttonW) + ((cols - 1) * spacing);
                        totalUsedH = (rows * buttonH) + ((rows - 1) * spacing);
                        extraW = (winWidth - totalUsedW) / 2;
                        extraH = (winHeight - totalUsedH) / 2;
                        startX = extraW.floor;
                        startY = extraH.floor;

                        ~binauralIrcamChooserWin = Window.new("IRCAM IDs", Rect(winX, winY, winWidth, winHeight), border: false)
                            .alwaysOnTop_(true);
                        chooserView = CompositeView(~binauralIrcamChooserWin, ~binauralIrcamChooserWin.view.bounds)
                            .background_(Color.black);

                        ~binauralIRCAMIds.do({ |id, i|
                            var r = (i / cols).floor;
                            var c = i % cols;
                            if(r < rows) {
                                var x = startX + (c * (buttonW + spacing));
                                var y = startY + (r * (buttonH + spacing));
                                var isLoaded = (id == ~binauralIRCAMId);
                                Button(chooserView, Rect(x, y, buttonW, buttonH))
                                    .states_([[id.asString.padLeft(4, "0"), Color.cyan, Color.black],
                                              [id.asString.padLeft(4, "0"), Color.black, Color.cyan]])
                                    .value_(if(isLoaded, 1, 0))
                                    .font_(Font("LCD 5x7 Segment Monospace", 11))
                                    .focusColor_(Color.clear)
                                    .canFocus_(false)
                                    .action_({
                                        ~binauralIRCAMId = id;
                                        ~binauralIRCAMPendingId = id;
                                        if(~binauralIrcamSelectBtn.notNil) {
                                            ~binauralIrcamSelectBtn.states_([[ (id.asString.padLeft(4, "0")), Color.cyan, Color.black ],
                                                                              [ (id.asString.padLeft(4, "0")), Color.cyan, Color.black ]]);
                                        };
                                        if(~binauralIrcamChooserWin.notNil) {
                                            ~binauralIrcamChooserWin.close;
                                            ~binauralIrcamChooserWin = nil;
                                        };
                                        ~saveSynthParams.value();
                                        ~initAudioEngine.value();
                                    });
                            };
                        });

                        if(~binauralIrcamChooserWin.notNil) {
                            ~binauralIrcamChooserWin.front;
                        };
                    });
                ~binauralIrcamSelectBtn.front;

                if(~binauralLeftHit.notNil) { try { ~binauralLeftHit.remove; }; ~binauralLeftHit = nil; };
                if(~binauralRightHit.notNil) { try { ~binauralRightHit.remove; }; ~binauralRightHit = nil; };

                ~binauralLeftHit = UserView(~layoutOverlay, Rect(leftEarX, leftEarY, earCupWidth, earCupHeight))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~binauralState[\lOn] ? 1);
                        ~binauralState[\lOn] = newState;
                        if(~synth.notNil) { ~synth.set(\lOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~binauralLeftHit.front;

                ~binauralRightHit = UserView(~layoutOverlay, Rect(rightEarX, rightEarY, earCupWidth, earCupHeight))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~binauralState[\rOn] ? 1);
                        ~binauralState[\rOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~binauralRightHit.front;
        };

        if(~dmenu.value == 3, {
            var diagramCenterX = 160, layoutSize = 140, layoutLeft = diagramCenterX - (layoutSize / 2), layoutTop = 70, speakerSize = 18;
            var frontLeftX = layoutLeft - 9, frontLeftY = layoutTop - 9;
            var frontRightX = layoutLeft + layoutSize - 9, frontRightY = layoutTop - 9;
            var surroundLeftX = layoutLeft - 9, surroundLeftY = layoutTop + layoutSize - 9 + 10;
            var surroundRightX = layoutLeft + layoutSize - 9, surroundRightY = layoutTop + layoutSize - 9 + 10;

            if(~quadSquareFLHit.notNil) { try { ~quadSquareFLHit.remove; }; ~quadSquareFLHit = nil; };
            if(~quadSquareFRHit.notNil) { try { ~quadSquareFRHit.remove; }; ~quadSquareFRHit = nil; };
            if(~quadSquareRLHit.notNil) { try { ~quadSquareRLHit.remove; }; ~quadSquareRLHit = nil; };
            if(~quadSquareRRHit.notNil) { try { ~quadSquareRRHit.remove; }; ~quadSquareRRHit = nil; };
            if(~quadNarrowFLHit.notNil) { try { ~quadNarrowFLHit.remove; }; ~quadNarrowFLHit = nil; };
            if(~quadNarrowFRHit.notNil) { try { ~quadNarrowFRHit.remove; }; ~quadNarrowFRHit = nil; };
            if(~quadNarrowRLHit.notNil) { try { ~quadNarrowRLHit.remove; }; ~quadNarrowRLHit = nil; };
            if(~quadNarrowRRHit.notNil) { try { ~quadNarrowRRHit.remove; }; ~quadNarrowRRHit = nil; };
            if(~quadWideFLHit.notNil) { try { ~quadWideFLHit.remove; }; ~quadWideFLHit = nil; };
            if(~quadWideFRHit.notNil) { try { ~quadWideFRHit.remove; }; ~quadWideFRHit = nil; };
            if(~quadWideRLHit.notNil) { try { ~quadWideRLHit.remove; }; ~quadWideRLHit = nil; };
            if(~quadWideRRHit.notNil) { try { ~quadWideRRHit.remove; }; ~quadWideRRHit = nil; };

            ~quadSquareFLHit = UserView(~layoutOverlay, Rect(frontLeftX, frontLeftY, speakerSize, speakerSize))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~quadSquareState[\flOn] ? 1);
                    ~quadSquareState[\flOn] = newState;
                    if(~synth.notNil) { ~synth.set(\flOn, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~quadSquareFLHit.front;

            ~quadSquareFRHit = UserView(~layoutOverlay, Rect(frontRightX, frontRightY, speakerSize, speakerSize))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~quadSquareState[\frOn] ? 1);
                    ~quadSquareState[\frOn] = newState;
                    if(~synth.notNil) { ~synth.set(\frOn, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~quadSquareFRHit.front;

            ~quadSquareRLHit = UserView(~layoutOverlay, Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~quadSquareState[\rlOn] ? 1);
                    ~quadSquareState[\rlOn] = newState;
                    if(~synth.notNil) { ~synth.set(\rlOn, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~quadSquareRLHit.front;

            ~quadSquareRRHit = UserView(~layoutOverlay, Rect(surroundRightX, surroundRightY, speakerSize, speakerSize))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~quadSquareState[\rrOn] ? 1);
                    ~quadSquareState[\rrOn] = newState;
                    if(~synth.notNil) { ~synth.set(\rrOn, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~quadSquareRRHit.front;
        });
        if(~dmenu.value == 4, {
            var rectHeight = 160, rectWidth = 110, diagramCenterX = 160;
            var rectLeft = diagramCenterX - (rectWidth / 2), rectTop = 60, speakerSize = 18;
            var frontLeftX = rectLeft - 9, frontLeftY = rectTop - 9;
            var frontRightX = rectLeft + rectWidth - 9, frontRightY = rectTop - 9;
            var surroundLeftX = rectLeft - 9, surroundLeftY = rectTop + rectHeight - 9 + 8;
            var surroundRightX = rectLeft + rectWidth - 9, surroundRightY = rectTop + rectHeight - 9 + 8;

            if(~quadNarrowFLHit.notNil) { try { ~quadNarrowFLHit.remove; }; ~quadNarrowFLHit = nil; };
            if(~quadNarrowFRHit.notNil) { try { ~quadNarrowFRHit.remove; }; ~quadNarrowFRHit = nil; };
            if(~quadNarrowRLHit.notNil) { try { ~quadNarrowRLHit.remove; }; ~quadNarrowRLHit = nil; };
            if(~quadNarrowRRHit.notNil) { try { ~quadNarrowRRHit.remove; }; ~quadNarrowRRHit = nil; };

            ~quadNarrowFLHit = UserView(~layoutOverlay, Rect(frontLeftX, frontLeftY, speakerSize, speakerSize))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~quadNarrowState[\flOn] ? 1);
                    ~quadNarrowState[\flOn] = newState;
                    if(~synth.notNil) { ~synth.set(\flOn, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~quadNarrowFLHit.front;

            ~quadNarrowFRHit = UserView(~layoutOverlay, Rect(frontRightX, frontRightY, speakerSize, speakerSize))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~quadNarrowState[\frOn] ? 1);
                    ~quadNarrowState[\frOn] = newState;
                    if(~synth.notNil) { ~synth.set(\frOn, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~quadNarrowFRHit.front;

            ~quadNarrowRLHit = UserView(~layoutOverlay, Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~quadNarrowState[\rlOn] ? 1);
                    ~quadNarrowState[\rlOn] = newState;
                    if(~synth.notNil) { ~synth.set(\rlOn, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~quadNarrowRLHit.front;

            ~quadNarrowRRHit = UserView(~layoutOverlay, Rect(surroundRightX, surroundRightY, speakerSize, speakerSize))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~quadNarrowState[\rrOn] ? 1);
                    ~quadNarrowState[\rrOn] = newState;
                    if(~synth.notNil) { ~synth.set(\rrOn, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~quadNarrowRRHit.front;
        });
        if(~dmenu.value == 5, {
            var rectWidth_w = 170, rectHeight_w = 120, diagramCenterX_w = 160;
            var rectLeft_w = diagramCenterX_w - (rectWidth_w / 2), rectTop_w = 78, speakerSize_w = 18;
            var frontLeftX_w = rectLeft_w - 9, frontLeftY_w = rectTop_w - 9;
            var frontRightX_w = rectLeft_w + rectWidth_w - 9, frontRightY_w = rectTop_w - 9;
            var surroundLeftX_w = rectLeft_w - 9, surroundLeftY_w = rectTop_w + rectHeight_w - 9 + 8;
            var surroundRightX_w = rectLeft_w + rectWidth_w - 9, surroundRightY_w = rectTop_w + rectHeight_w - 9 + 8;

            if(~quadWideFLHit.notNil) { try { ~quadWideFLHit.remove; }; ~quadWideFLHit = nil; };
            if(~quadWideFRHit.notNil) { try { ~quadWideFRHit.remove; }; ~quadWideFRHit = nil; };
            if(~quadWideRLHit.notNil) { try { ~quadWideRLHit.remove; }; ~quadWideRLHit = nil; };
            if(~quadWideRRHit.notNil) { try { ~quadWideRRHit.remove; }; ~quadWideRRHit = nil; };

            ~quadWideFLHit = UserView(~layoutOverlay, Rect(frontLeftX_w, frontLeftY_w, speakerSize_w, speakerSize_w))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~quadWideState[\flOn] ? 1);
                    ~quadWideState[\flOn] = newState;
                    if(~synth.notNil) { ~synth.set(\flOn, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~quadWideFLHit.front;

            ~quadWideFRHit = UserView(~layoutOverlay, Rect(frontRightX_w, frontRightY_w, speakerSize_w, speakerSize_w))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~quadWideState[\frOn] ? 1);
                    ~quadWideState[\frOn] = newState;
                    if(~synth.notNil) { ~synth.set(\frOn, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~quadWideFRHit.front;

            ~quadWideRLHit = UserView(~layoutOverlay, Rect(surroundLeftX_w, surroundLeftY_w, speakerSize_w, speakerSize_w))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~quadWideState[\rlOn] ? 1);
                    ~quadWideState[\rlOn] = newState;
                    if(~synth.notNil) { ~synth.set(\rlOn, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~quadWideRLHit.front;

            ~quadWideRRHit = UserView(~layoutOverlay, Rect(surroundRightX_w, surroundRightY_w, speakerSize_w, speakerSize_w))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~quadWideState[\rrOn] ? 1);
                    ~quadWideState[\rrOn] = newState;
                    if(~synth.notNil) { ~synth.set(\rrOn, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~quadWideRRHit.front;
        });
        if(~dmenu.value == 8, {
            var radius = 80, angleStep = 2 * pi / 8, startAngle = -22.5 * pi / 180;
            var centerX_o = 160, centerY_o = 137.5;
            var speaker1Index, speaker2Index, speaker3Index, speaker4Index, speaker5Index, speaker6Index, speaker7Index, speaker8Index;
            var angle1, angle2, angle3, angle4, angle5, angle6, angle7, angle8;
            var x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6, x7, y7, x8, y8;
            if(~octagonS1Hit.notNil) { try { ~octagonS1Hit.remove; }; ~octagonS1Hit = nil; };
            if(~octagonS2Hit.notNil) { try { ~octagonS2Hit.remove; }; ~octagonS2Hit = nil; };
            if(~octagonS3Hit.notNil) { try { ~octagonS3Hit.remove; }; ~octagonS3Hit = nil; };
            if(~octagonS4Hit.notNil) { try { ~octagonS4Hit.remove; }; ~octagonS4Hit = nil; };
            if(~octagonS5Hit.notNil) { try { ~octagonS5Hit.remove; }; ~octagonS5Hit = nil; };
            if(~octagonS6Hit.notNil) { try { ~octagonS6Hit.remove; }; ~octagonS6Hit = nil; };
            if(~octagonS7Hit.notNil) { try { ~octagonS7Hit.remove; }; ~octagonS7Hit = nil; };
            if(~octagonS8Hit.notNil) { try { ~octagonS8Hit.remove; }; ~octagonS8Hit = nil; };

            speaker1Index = 6;
            angle1 = startAngle + (speaker1Index * angleStep);
            x1 = centerX_o + (radius * cos(angle1));
            y1 = centerY_o + (radius * sin(angle1)) + 25;
            ~octagonS1Hit = UserView(~layoutOverlay, Rect(x1 - 10, y1 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s1On] ? 1);
                    ~octagonState[\s1On] = newState;
                    if(~synth.notNil) { ~synth.set(\s1On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS1Hit.front;

            speaker2Index = 7;
            angle2 = startAngle + (speaker2Index * angleStep);
            x2 = centerX_o + (radius * cos(angle2));
            y2 = centerY_o + (radius * sin(angle2)) + 25;
            ~octagonS2Hit = UserView(~layoutOverlay, Rect(x2 - 10, y2 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s2On] ? 1);
                    ~octagonState[\s2On] = newState;
                    if(~synth.notNil) { ~synth.set(\s2On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS2Hit.front;

            speaker3Index = 0;
            angle3 = startAngle + (speaker3Index * angleStep);
            x3 = centerX_o + (radius * cos(angle3));
            y3 = centerY_o + (radius * sin(angle3)) + 25;
            ~octagonS3Hit = UserView(~layoutOverlay, Rect(x3 - 10, y3 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s3On] ? 1);
                    ~octagonState[\s3On] = newState;
                    if(~synth.notNil) { ~synth.set(\s3On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS3Hit.front;

            speaker4Index = 1;
            angle4 = startAngle + (speaker4Index * angleStep);
            x4 = centerX_o + (radius * cos(angle4));
            y4 = centerY_o + (radius * sin(angle4)) + 25;
            ~octagonS4Hit = UserView(~layoutOverlay, Rect(x4 - 10, y4 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s4On] ? 1);
                    ~octagonState[\s4On] = newState;
                    if(~synth.notNil) { ~synth.set(\s4On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS4Hit.front;

            speaker5Index = 2;
            angle5 = startAngle + (speaker5Index * angleStep);
            x5 = centerX_o + (radius * cos(angle5));
            y5 = centerY_o + (radius * sin(angle5)) + 25;
            ~octagonS5Hit = UserView(~layoutOverlay, Rect(x5 - 10, y5 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s5On] ? 1);
                    ~octagonState[\s5On] = newState;
                    if(~synth.notNil) { ~synth.set(\s5On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS5Hit.front;

            speaker6Index = 3;
            angle6 = startAngle + (speaker6Index * angleStep);
            x6 = centerX_o + (radius * cos(angle6));
            y6 = centerY_o + (radius * sin(angle6)) + 25;
            ~octagonS6Hit = UserView(~layoutOverlay, Rect(x6 - 10, y6 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s6On] ? 1);
                    ~octagonState[\s6On] = newState;
                    if(~synth.notNil) { ~synth.set(\s6On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS6Hit.front;

            speaker7Index = 4;
            angle7 = startAngle + (speaker7Index * angleStep);
            x7 = centerX_o + (radius * cos(angle7));
            y7 = centerY_o + (radius * sin(angle7)) + 25;
            ~octagonS7Hit = UserView(~layoutOverlay, Rect(x7 - 10, y7 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s7On] ? 1);
                    ~octagonState[\s7On] = newState;
                    if(~synth.notNil) { ~synth.set(\s7On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS7Hit.front;

            speaker8Index = 5;
            angle8 = startAngle + (speaker8Index * angleStep);
            x8 = centerX_o + (radius * cos(angle8));
            y8 = centerY_o + (radius * sin(angle8)) + 25;
            ~octagonS8Hit = UserView(~layoutOverlay, Rect(x8 - 10, y8 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s8On] ? 1);
                    ~octagonState[\s8On] = newState;
                    if(~synth.notNil) { ~synth.set(\s8On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS8Hit.front;
        });
        if(~dmenu.value == 8, {
            var radius = 80, angleStep = 2 * pi / 8, startAngle = -22.5 * pi / 180;
            var centerX_o = 160, centerY_o = 137.5;
            var speaker1Index, speaker2Index, speaker3Index, speaker4Index, speaker5Index, speaker6Index, speaker7Index, speaker8Index;
            var angle1, angle2, angle3, angle4, angle5, angle6, angle7, angle8;
            var x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, x6, y6, x7, y7, x8, y8;
            // Remove any existing octagon hit targets
            if(~octagonS1Hit.notNil) { try { ~octagonS1Hit.remove; }; ~octagonS1Hit = nil; };
            if(~octagonS2Hit.notNil) { try { ~octagonS2Hit.remove; }; ~octagonS2Hit = nil; };
            if(~octagonS3Hit.notNil) { try { ~octagonS3Hit.remove; }; ~octagonS3Hit = nil; };
            if(~octagonS4Hit.notNil) { try { ~octagonS4Hit.remove; }; ~octagonS4Hit = nil; };
            if(~octagonS5Hit.notNil) { try { ~octagonS5Hit.remove; }; ~octagonS5Hit = nil; };
            if(~octagonS6Hit.notNil) { try { ~octagonS6Hit.remove; }; ~octagonS6Hit = nil; };
            if(~octagonS7Hit.notNil) { try { ~octagonS7Hit.remove; }; ~octagonS7Hit = nil; };
            if(~octagonS8Hit.notNil) { try { ~octagonS8Hit.remove; }; ~octagonS8Hit = nil; };

            speaker1Index = 6;
            angle1 = startAngle + (speaker1Index * angleStep);
            x1 = centerX_o + (radius * cos(angle1));
            y1 = centerY_o + (radius * sin(angle1)) + 25;
            ~octagonS1Hit = UserView(~layoutOverlay, Rect(x1 - 10, y1 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s1On] ? 1);
                    ~octagonState[\s1On] = newState;
                    if(~synth.notNil) { ~synth.set(\s1On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS1Hit.front;

            speaker2Index = 7;
            angle2 = startAngle + (speaker2Index * angleStep);
            x2 = centerX_o + (radius * cos(angle2));
            y2 = centerY_o + (radius * sin(angle2)) + 25;
            ~octagonS2Hit = UserView(~layoutOverlay, Rect(x2 - 10, y2 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s2On] ? 1);
                    ~octagonState[\s2On] = newState;
                    if(~synth.notNil) { ~synth.set(\s2On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS2Hit.front;

            speaker3Index = 0;
            angle3 = startAngle + (speaker3Index * angleStep);
            x3 = centerX_o + (radius * cos(angle3));
            y3 = centerY_o + (radius * sin(angle3)) + 25;
            ~octagonS3Hit = UserView(~layoutOverlay, Rect(x3 - 10, y3 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s3On] ? 1);
                    ~octagonState[\s3On] = newState;
                    if(~synth.notNil) { ~synth.set(\s3On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS3Hit.front;

            speaker4Index = 1;
            angle4 = startAngle + (speaker4Index * angleStep);
            x4 = centerX_o + (radius * cos(angle4));
            y4 = centerY_o + (radius * sin(angle4)) + 25;
            ~octagonS4Hit = UserView(~layoutOverlay, Rect(x4 - 10, y4 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s4On] ? 1);
                    ~octagonState[\s4On] = newState;
                    if(~synth.notNil) { ~synth.set(\s4On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS4Hit.front;

            speaker5Index = 2;
            angle5 = startAngle + (speaker5Index * angleStep);
            x5 = centerX_o + (radius * cos(angle5));
            y5 = centerY_o + (radius * sin(angle5)) + 25;
            ~octagonS5Hit = UserView(~layoutOverlay, Rect(x5 - 10, y5 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s5On] ? 1);
                    ~octagonState[\s5On] = newState;
                    if(~synth.notNil) { ~synth.set(\s5On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS5Hit.front;

            speaker6Index = 3;
            angle6 = startAngle + (speaker6Index * angleStep);
            x6 = centerX_o + (radius * cos(angle6));
            y6 = centerY_o + (radius * sin(angle6)) + 25;
            ~octagonS6Hit = UserView(~layoutOverlay, Rect(x6 - 10, y6 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s6On] ? 1);
                    ~octagonState[\s6On] = newState;
                    if(~synth.notNil) { ~synth.set(\s6On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS6Hit.front;

            speaker7Index = 4;
            angle7 = startAngle + (speaker7Index * angleStep);
            x7 = centerX_o + (radius * cos(angle7));
            y7 = centerY_o + (radius * sin(angle7)) + 25;
            ~octagonS7Hit = UserView(~layoutOverlay, Rect(x7 - 10, y7 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s7On] ? 1);
                    ~octagonState[\s7On] = newState;
                    if(~synth.notNil) { ~synth.set(\s7On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS7Hit.front;

            speaker8Index = 5;
            angle8 = startAngle + (speaker8Index * angleStep);
            x8 = centerX_o + (radius * cos(angle8));
            y8 = centerY_o + (radius * sin(angle8)) + 25;
            ~octagonS8Hit = UserView(~layoutOverlay, Rect(x8 - 10, y8 - 10, 20, 20))
                .background_(Color.clear)
                .mouseDownAction_({ |view, x, y, mod, button, count|
                    var newState = 1 - (~octagonState[\s8On] ? 1);
                    ~octagonState[\s8On] = newState;
                    if(~synth.notNil) { ~synth.set(\s8On, newState); };
                    if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                });
            ~octagonS8Hit.front;
        });

            if(~dmenu.value == 2) {
                var layoutBounds_c = ~layoutOverlay.bounds;
                var centerX_c = layoutBounds_c.width / 2;
                var centerY_c = layoutBounds_c.height / 2;
                var moveUp_c = 16;
                var earCupWidth_c = 20;
                var earCupHeight_c = 27;
                var earCupOffset_c = 55;
                var leftEarX_c = centerX_c - earCupOffset_c - (earCupWidth_c / 2);
                var leftEarY_c = centerY_c + 25 + 25 - moveUp_c;
                var rightEarX_c = centerX_c + earCupOffset_c - (earCupWidth_c / 2);
                var rightEarY_c = centerY_c + 25 + 25 - moveUp_c;
                var labelWidth_c, dropdownWidth_c, totalWidth_c, groupStartX_c, labelX_c, dropdownX_c, buttonH_c, gridRows_c, gridSpacing_c, yPos_c;

                if(~binauralCIPICIds.isNil) {
                    ~binauralCIPICIds = [3, 8, 9, 10, 11, 12, 15, 17, 18, 19, 20, 21, 27, 28, 33, 40, 44, 48, 50, 51, 58, 59, 60, 61, 65, 119, 124, 126, 127, 131, 133, 134, 135, 137, 147, 148, 152, 153, 154, 155, 156, 158, 162, 163, 165];
                };
                ~binauralCIPICPendingId = ~binauralCIPICId;

                gridRows_c = 8;
                gridSpacing_c = 3;
                buttonH_c = ((layoutBounds_c.height - 3 - (9 * gridSpacing_c)) / gridRows_c).floor;
                labelWidth_c = 90;
                dropdownWidth_c = 80;
                totalWidth_c = labelWidth_c + dropdownWidth_c;
                groupStartX_c = (320 - totalWidth_c) / 2;
                labelX_c = groupStartX_c;
                dropdownX_c = groupStartX_c + labelWidth_c;
                yPos_c = 240 - 7;

                ~binauralCipicProfileLabel = StaticText(~layoutOverlay, Rect(labelX_c, yPos_c, labelWidth_c, buttonH_c))
                    .string_("PROFILE")
                    .stringColor_(Color.cyan)
                    .font_(Font("LCD 5x7 Segment Monospace", 13))
                    .align_(\left)
                    .background_(Color.clear);
                ~binauralCipicProfileLabel.front;

                ~binauralCipicSelectBtn = Button(~layoutOverlay, Rect(dropdownX_c, yPos_c, dropdownWidth_c, buttonH_c))
                    .states_([[ (~binauralCIPICPendingId.asString.padLeft(4, "0")), Color.cyan, Color.black ],
                              [ (~binauralCIPICPendingId.asString.padLeft(4, "0")), Color.cyan, Color.black ]])
                    .font_(Font("LCD 5x7 Segment Monospace", 11))
                    .focusColor_(Color.clear)
                    .canFocus_(false)
                    .action_({
                        var layoutBounds_c, winWidth_c, winHeight_c, mainViewBounds_c, winBounds_c, winX_c, winY_c, cols_c, rows_c, spacing_c, buttonW_c, totalUsedW_c, totalUsedH_c, extraW_c, extraH_c, startX_c, startY_c, chooserView_c;

                        if(~binauralCipicChooserWin.notNil) { try { ~binauralCipicChooserWin.close; }; ~binauralCipicChooserWin = nil; };
                        ~octagonS1Hit = nil;
                        ~octagonS2Hit = nil;
                        ~octagonS3Hit = nil;
                        ~octagonS4Hit = nil;
                        ~octagonS5Hit = nil;
                        ~octagonS6Hit = nil;
                        ~octagonS7Hit = nil;
                        ~octagonS8Hit = nil;

                        layoutBounds_c = ~layoutOverlay.bounds;
                        winWidth_c = layoutBounds_c.width - 3;
                        winHeight_c = layoutBounds_c.height - 3;
                        mainViewBounds_c = mainView.bounds;
                        winBounds_c = win.bounds;
                        winX_c = winBounds_c.left + mainViewBounds_c.left + layoutBounds_c.left + 2;
                        winY_c = winBounds_c.top + mainViewBounds_c.top + layoutBounds_c.top - 8;
                        cols_c = 6; rows_c = 8; spacing_c = 3;
                        buttonW_c = ((winWidth_c - (7 * spacing_c)) / cols_c).floor;
                        buttonH_c = ((winHeight_c - (9 * spacing_c)) / rows_c).floor;
                        totalUsedW_c = (cols_c * buttonW_c) + ((cols_c - 1) * spacing_c);
                        totalUsedH_c = (rows_c * buttonH_c) + ((rows_c - 1) * spacing_c);
                        extraW_c = (winWidth_c - totalUsedW_c) / 2;
                        extraH_c = (winHeight_c - totalUsedH_c) / 2;
                        startX_c = extraW_c.floor;
                        startY_c = extraH_c.floor;

                        ~binauralCipicChooserWin = Window.new("CIPIC IDs", Rect(winX_c, winY_c, winWidth_c, winHeight_c), border: false)
                            .alwaysOnTop_(true);
                        chooserView_c = CompositeView(~binauralCipicChooserWin, ~binauralCipicChooserWin.view.bounds)
                            .background_(Color.black);

                        ~binauralCIPICIds.do({ |id, i|
                            var r = (i / cols_c).floor;
                            var c = i % cols_c;
                            if(r < rows_c) {
                                var x = startX_c + (c * (buttonW_c + spacing_c));
                                var y = startY_c + (r * (buttonH_c + spacing_c));
                                var isLoaded = (id == ~binauralCIPICId);
                                Button(chooserView_c, Rect(x, y, buttonW_c, buttonH_c))
                                    .states_([[id.asString.padLeft(4, "0"), Color.cyan, Color.black],
                                              [id.asString.padLeft(4, "0"), Color.black, Color.cyan]])
                                    .value_(if(isLoaded, 1, 0))
                                    .font_(Font("LCD 5x7 Segment Monospace", 11))
                                    .focusColor_(Color.clear)
                                    .canFocus_(false)
                                    .action_({
                                        ~binauralCIPICId = id;
                                        ~binauralCIPICPendingId = id;
                                        if(~binauralCipicSelectBtn.notNil) {
                                            ~binauralCipicSelectBtn.states_([[ (id.asString.padLeft(4, "0")), Color.cyan, Color.black ],
                                                                              [ (id.asString.padLeft(4, "0")), Color.cyan, Color.black ]]);
                                        };
                                        if(~binauralCipicChooserWin.notNil) {
                                            ~binauralCipicChooserWin.close;
                                            ~binauralCipicChooserWin = nil;
                                        };
                                        ~saveSynthParams.value();
                                        ~initAudioEngine.value();
                                    });
                            };
                        });

                        if(~binauralCipicChooserWin.notNil) {
                            ~binauralCipicChooserWin.front;
                        };
                    });
                ~binauralCipicSelectBtn.front;

                if(~binauralLeftHit.notNil) { try { ~binauralLeftHit.remove; }; ~binauralLeftHit = nil; };
                if(~binauralRightHit.notNil) { try { ~binauralRightHit.remove; }; ~binauralRightHit = nil; };

                ~binauralLeftHit = UserView(~layoutOverlay, Rect(leftEarX_c, leftEarY_c, earCupWidth_c, earCupHeight_c))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~binauralState[\lOn] ? 1);
                        ~binauralState[\lOn] = newState;
                        if(~synth.notNil) { ~synth.set(\lOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~binauralLeftHit.front;

                ~binauralRightHit = UserView(~layoutOverlay, Rect(rightEarX_c, rightEarY_c, earCupWidth_c, earCupHeight_c))
                    .background_(Color.clear)
                    .mouseDownAction_({ |view, x, y, mod, button, count|
                        var newState = 1 - (~binauralState[\rOn] ? 1);
                        ~binauralState[\rOn] = newState;
                        if(~synth.notNil) { ~synth.set(\rOn, newState); };
                        if(~layoutDiagramView.notNil) { ~layoutDiagramView.refresh; };
                    });
                ~binauralRightHit.front;
            };
        } {
            if(~layoutOverlay.notNil) { 
                ~layoutOverlay.remove; 
                ~layoutOverlay = nil;
                ~layoutDiagramView = nil;
                ~layoutTitleText = nil;
                ~stereoLeftHit = nil; 
                ~stereoRightHit = nil;
                ~binauralLeftHit = nil;
                ~binauralRightHit = nil;
                ~binauralIrcamProfileLabel = nil;
                ~binauralIrcamSelectBtn = nil;
                if(~binauralIrcamChooserWin.notNil) { try { ~binauralIrcamChooserWin.close; }; ~binauralIrcamChooserWin = nil; };
                ~binauralCipicProfileLabel = nil;
                ~binauralCipicSelectBtn = nil;
                if(~binauralCipicChooserWin.notNil) { try { ~binauralCipicChooserWin.close; }; ~binauralCipicChooserWin = nil; };
            };
        }
    });
// --- DIMENSION / MAPLIN OVERLAY BUTTON ---
~dimensionBtn = Button(mainView, Rect(316, 410, 96, 35))
    .states_([["DIMENSION", Color.cyan, Color.black], ["DIMENSION", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({ |btn|
        var dimKnobSize, dimKnobY, dimLabelY, dimValueY;
        var maplinKnobSize, maplinKnobY, maplinLabelY, maplinValueY, maplinSavedVals;
        var savedVals;
        if(btn.value == 0) {
            btn.value_(1);
            btn.focus(nil);
            ^nil;
        };
        if(btn.value == 1) {
            if(~eqOverlay.notNil) { 
                ~saveEqState.value();
                ~eqOverlay.remove; ~eqOverlay = nil; ~eqBtn.value_(0); 
            };
            if(~ambienceOverlay.notNil) { 
                ~saveAmbienceState.value();
                ~ambienceOverlay.remove; ~ambienceOverlay = nil; ~ambienceBtn.value_(0); 
            };
            if(~layoutOverlay.notNil) { 
                ~layoutOverlay.remove; 
                ~layoutOverlay = nil;
                ~layoutDiagramView = nil;
                ~layoutTitleText = nil;
                ~stereoLeftHit = nil; 
                ~stereoRightHit = nil;
                ~binauralLeftHit = nil;
                ~binauralRightHit = nil;
                ~binauralIrcamProfileLabel = nil;
                ~binauralIrcamSelectBtn = nil;
                if(~binauralIrcamChooserWin.notNil) { try { ~binauralIrcamChooserWin.close; }; ~binauralIrcamChooserWin = nil; };
                ~binauralCipicProfileLabel = nil;
                ~binauralCipicSelectBtn = nil;
                if(~binauralCipicChooserWin.notNil) { try { ~binauralCipicChooserWin.close; }; ~binauralCipicChooserWin = nil; };
            };
            if(~metersOverlay.notNil) {
                ~metersOverlay.remove; ~metersOverlay = nil; ~metersBtn.value_(0);
            };
            ~eqBtn.value_(0);
            ~ambienceBtn.value_(0);
            ~layoutBtn.value_(0);
            if(~playerOverlay.notNil) { 
                if(~playerPlayBtn.notNil, { ~savedPlayerPlayState = ~playerPlayBtn.value; });
                if(~playerLoopBtn.notNil, { ~savedPlayerLoopState = ~playerLoopBtn.value; });
                ~playerOverlay.remove; ~playerOverlay = nil;
            };
            ~playerBtn.value_(0);
            
            if(~metersOverlay.notNil) { 
                ~metersOverlay.remove; ~metersOverlay = nil; 
            };

            ~dimensionOverlay = View(mainView, Rect(180, 107, 320, 275)).background_(Color.black);

            UserView(~dimensionOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.white;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });

            dimKnobSize = 60;
            dimKnobY = 32; dimLabelY = 10; dimValueY = 97;
            
            savedVals = ~dimensionState[\sliderValues] ? [0.0, 0.5, 0.5];
            
            StaticText(~dimensionOverlay, Rect(35, dimLabelY, dimKnobSize, 16))
                .string_("WIDTH")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11).boldVariant)
                .background_(Color.clear);

            StaticText(~dimensionOverlay, Rect(130, dimLabelY, dimKnobSize, 16))
                .string_("W HPF")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11).boldVariant)
                .background_(Color.clear);
            
            StaticText(~dimensionOverlay, Rect(225, dimLabelY, dimKnobSize, 16))
                .string_("TRIM")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11).boldVariant)
                .background_(Color.clear);
            ~dimensionWidthKnob = Knob(~dimensionOverlay, Rect(35, dimKnobY, dimKnobSize, dimKnobSize))
                .value_(savedVals[0])
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    var val = knob.value * 0.70;
                    ~dimensionWidthValue.string_(val.round(0.01).asString);
                    ~dimensionState[\sliderValues][0] = knob.value;
                    if(~synth.notNil) { ~synth.set(\dimensionWidth, val); };
                });
            
            ~dimensionWidthHPFKnob = Knob(~dimensionOverlay, Rect(130, dimKnobY, dimKnobSize, dimKnobSize))
                .value_(savedVals[1])
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    var val = knob.value.linlin(0, 1, 80, 400);
                    ~dimensionWidthHPFValue.string_(val.round(1).asString ++ "Hz");
                    ~dimensionState[\sliderValues][1] = knob.value;
                    if(~synth.notNil) { ~synth.set(\dimensionWidthHPF, val); };
                });
            ~dimensionTrimKnob = Knob(~dimensionOverlay, Rect(225, dimKnobY, dimKnobSize, dimKnobSize))
                .value_(savedVals[2])
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    var val = knob.value.linlin(0, 1, -6, 6);
                    var displayVal = if(val >= 0, "+" ++ val.round(0.1).asString, val.round(0.1).asString);
                    ~dimensionTrimValue.string_(displayVal ++ "dB");
                    ~dimensionState[\sliderValues][2] = knob.value;
                    if(~synth.notNil) { ~synth.set(\dimensionOutputTrim, val); };
                });
            
            ~dimensionWidthValue = StaticText(~dimensionOverlay, Rect(35, dimValueY - 3, dimKnobSize, 16))
                .string_("0.00")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            
            ~dimensionWidthHPFValue = StaticText(~dimensionOverlay, Rect(130, dimValueY - 3, dimKnobSize, 16))
                .string_("180Hz")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            
            ~dimensionTrimValue = StaticText(~dimensionOverlay, Rect(225, dimValueY - 3, dimKnobSize, 16))
                .string_("0.0dB")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            
            maplinKnobSize = 60; maplinKnobY = 139; maplinLabelY = 118; maplinValueY = 203;
            maplinSavedVals = ~maplinState;
            
            StaticText(~dimensionOverlay, Rect(33, maplinLabelY, 64, 16))
                .string_("SURROUND")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11).boldVariant)
                .background_(Color.clear);
            
            StaticText(~dimensionOverlay, Rect(130, maplinLabelY, maplinKnobSize, 16))
                .string_("EFFECT")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11).boldVariant)
                .background_(Color.clear);
            
            StaticText(~dimensionOverlay, Rect(225, maplinLabelY, maplinKnobSize, 16))
                .string_("DELAY")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11).boldVariant)
                .background_(Color.clear);
            
            ~maplinSurroundKnob = Knob(~dimensionOverlay, Rect(35, maplinKnobY, maplinKnobSize, maplinKnobSize))
                .value_(maplinSavedVals[\surround] ? 0.8)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    ~setMaplinSurround.(knob.value);
                    ~maplinSurroundValue.string_((knob.value * 100).round(1).asString ++ "%");
                });
            
            ~maplinEffectKnob = Knob(~dimensionOverlay, Rect(130, maplinKnobY, maplinKnobSize, maplinKnobSize))
                .value_(maplinSavedVals[\effect] ? 0.8)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    ~setMaplinEffect.(knob.value);
                    ~maplinEffectValue.string_((knob.value * 100).round(1).asString ++ "%");
                });
            
            ~maplinDelayKnob = Knob(~dimensionOverlay, Rect(225, maplinKnobY, maplinKnobSize, maplinKnobSize))
                .value_(maplinSavedVals[\delay] ? 0.4)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    ~setMaplinDelay.(knob.value);
                    ~maplinDelayValue.string_((knob.value.linlin(0, 1, 5, 50).round(1).asString ++ " ms"));
                });
            
            ~maplinSurroundValue = StaticText(~dimensionOverlay, Rect(35, maplinValueY - 3, maplinKnobSize, 16))
                .string_("80%")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            
            ~maplinEffectValue = StaticText(~dimensionOverlay, Rect(130, maplinValueY - 3, maplinKnobSize, 16))
                .string_("80%")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);
            ~maplinDelayValue = StaticText(~dimensionOverlay, Rect(225, maplinValueY - 3, maplinKnobSize, 16))
                .string_("25 ms")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 11))
                .background_(Color.clear);

            ~dimensionWidthKnob.action.value(~dimensionWidthKnob);
            ~dimensionWidthHPFKnob.action.value(~dimensionWidthHPFKnob);
            ~dimensionTrimKnob.action.value(~dimensionTrimKnob);
            ~maplinSurroundKnob.action.value(~maplinSurroundKnob);
            ~maplinEffectKnob.action.value(~maplinEffectKnob);
            ~maplinDelayKnob.action.value(~maplinDelayKnob);

            ~maplinActiveBtn = Button(~dimensionOverlay, Rect(18, 230, 80, 28))
                .states_([
                    ["ON", Color.black, Color.cyan],
                    ["ON", Color.cyan, Color.black]
                ])
                .action_({ |button|
                    ~setMaplinActive.(button.value == 0);
                })
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .value_(if((maplinSavedVals[\active] ? 1) == 1, 0, 1));

            Button(~dimensionOverlay, Rect(222, 230, 80, 28))
                .states_([["RESET", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .focusColor_(Color.clear)
                .action_({
                    ~dimensionWidthKnob.value_(0.0);
                    ~dimensionWidthHPFKnob.value_(0.5);
                    ~dimensionTrimKnob.value_(0.5);
                    ~dimensionWidthKnob.action.value(~dimensionWidthKnob);
                    ~dimensionWidthHPFKnob.action.value(~dimensionWidthHPFKnob);
                    ~dimensionTrimKnob.action.value(~dimensionTrimKnob);
                    ~maplinSurroundKnob.value_(0.8);
                    ~maplinEffectKnob.value_(0.8);
                    ~maplinDelayKnob.value_(0.4);
                    if(~maplinActiveBtn.notNil) {
                        ~maplinActiveBtn.value_(0);
                        ~dimensionActive = 1;
                    };
                    ~maplinSurroundKnob.action.value(~maplinSurroundKnob);
                    ~maplinEffectKnob.action.value(~maplinEffectKnob);
                    ~maplinDelayKnob.action.value(~maplinDelayKnob);
                    if(~maplinActiveBtn.notNil) {
                        ~maplinActiveBtn.action.value(~maplinActiveBtn);
                    };
                });

            ~dimensionOverlay.front;
            ~dimensionBtn.value_(1);
            
            ~restoreDimensionState.value();
            ~restoreMaplinState.value();
            ~updateDimensionOverlayVisibility.value();
            
            if(configKeyE == \maplin and: { ~maplinSurroundKnob.notNil }) {
                ~maplinSurroundKnob.action.value(~maplinSurroundKnob);
                ~maplinEffectKnob.action.value(~maplinEffectKnob);
                ~maplinDelayKnob.action.value(~maplinDelayKnob);
            };

        } {
            if(~dimensionOverlay.notNil) {
                ~saveDimensionState.value();
                ~saveMaplinState.value();
                if(~dimensionRowOverlay.notNil) { ~dimensionRowOverlay.remove; ~dimensionRowOverlay = nil; };
                if(~maplinRowOverlay.notNil) { ~maplinRowOverlay.remove; ~maplinRowOverlay = nil; };
                ~dimensionOverlay.remove;
                ~dimensionOverlay = nil;
                ~dimensionBtn.value_(0);
            };
        }
    });


// --- OUTPUT FADER (GRAPHICAL ONLY, GUIPrototype style) ---
StaticText(mainView, Rect(544, 40, 24, 24))
    .string_("dB")
    .align_(\center)
    .stringColor_(Color.cyan)
    .font_(Font("Helvetica", 13));
StaticText(mainView, Rect(520, 10, 72, 28))
    .string_("OUTPUT")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

~outputSlider = Slider(mainView, Rect(544, 70, 24, 300))
    .orientation_(\vertical)
    .background_(Color.black)
    .focusColor_(Color.clear)
    .knobColor_(Color.cyan)
    .action_({ |sl|
        var db = sl.value.linlin(0, 1, -60, 0).round(1).asInteger;
        ~outputValue.string_(db.asString); // No decimal
        if(~synth.notNil) {
            var amp = 10.pow(db / 20);
            ~synth.set(\amp, amp);
        };
        // Persist current amp so decoder/server reboot starts new synth at same level
        voltmp = 10.pow(db / 20);
    });

~outputValue = StaticText(mainView, Rect(544, 380, 24, 24))
    .string_("0")
    .align_(\center)
    .stringColor_(Color.cyan)
    .font_(Font("Helvetica", 13));

// Ensure output fader starts at top (0dB) to match SynthDef default
~outputSlider.valueAction_(1.0); // Set to 0dB position (top)

// Tick marks for output fader (3px further from fader)
UserView(mainView, Rect(537, 70, 4, 300))
    .background_(Color.clear)
    .drawFunc_({ |view|
        Pen.color = Color.cyan;
        Pen.width = 1;
        // Major tick marks every 50 pixels
        [0, 50, 100, 150, 200, 250, 300].do({ |y|
            Pen.line(Point(0, y), Point(4, y));
            Pen.stroke;
        });
        // Minor tick marks every 25 pixels (between majors)
        [25, 75, 125, 175, 225, 275].do({ |y|
            Pen.line(Point(1, y), Point(3, y));
            Pen.stroke;
        });
    });
UserView(mainView, Rect(571, 70, 4, 300))
    .background_(Color.clear)
    .drawFunc_({ |view|
        Pen.color = Color.cyan;
        Pen.width = 1;
        // Major tick marks every 50 pixels
        [0, 50, 100, 150, 200, 250, 300].do({ |y|
            Pen.line(Point(0, y), Point(4, y));
            Pen.stroke;
        });
        // Minor tick marks every 25 pixels (between majors)
        [25, 75, 125, 175, 225, 275].do({ |y|
            Pen.line(Point(1, y), Point(3, y));
            Pen.stroke;
        });
    });

// ... existing code ...
// ... existing 

// --- POWER BUTTON (bottom right corner) ---
~powerBtn = Button(mainView, Rect(760, 445, 20, 20))
    .states_([["X", Color.cyan, Color.black]]) // Match headtracking button style, uppercase X
    .font_(Font("Helvetica", 10)) // Same size as RESET button
    .focusColor_(Color.clear)
    .mouseDownAction_({ |view, x, y, modifiers, buttonNumber, clickCount|
        "Rebooting system...".postln;
        "sudo reboot".unixCmd;
    });
    
// Add touch support only if touchscreen is available
if(Platform.case(\linux, { true }, { false })) {
    // Check if touchscreen is available by looking for touch devices
    var touchDevices = "ls /dev/input/by-path/ | grep touch".unixCmdGetStdOut;
    if(touchDevices.notEmpty) {
        ~rebootBtn.touchBeginAction_({ |view, x, y, pressure, id|
            "Rebooting system...".postln;
            "sudo reboot".unixCmd;
        });
    };
};

// --- Binaural profile selection state ---
~binauralIRCAMId = 1053;
~binauralCIPICId = 12;
~binauralIRCAMPendingId = ~binauralIRCAMId;
~binauralCIPICPendingId = ~binauralCIPICId;
~binauralIrcamSelectBtn = nil; ~binauralCipicSelectBtn = nil;
~binauralIrcamChooserWin = nil; ~binauralCipicChooserWin = nil;
~binauralIRCAMIds = nil; ~binauralCIPICIds = nil;

// --- Ambience routing defaults ---
~reverbTarget = \all;