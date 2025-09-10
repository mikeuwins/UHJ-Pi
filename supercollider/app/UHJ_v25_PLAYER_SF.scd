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
~eqOverlay = nil; ~ambienceOverlay = nil; ~layoutOverlay = nil; ~maplinOverlay = nil;
~eqBtn = nil; ~ambienceBtn = nil; ~layoutBtn = nil; ~maplinBtn = nil;
// --- EQ overlay variables (from GUIPrototype) ---
~eqPresetMenu = nil; ~eqPresetNames = nil; ~eqPresetDict = nil; ~eqSliders = nil; ~eqValues = nil;
// --- Maplin overlay variables ---
~maplinSurroundKnob = nil; ~maplinEffectKnob = nil; ~maplinDelayKnob = nil; ~maplinActiveBtn = nil;
~maplinSurroundValue = nil; ~maplinEffectValue = nil; ~maplinDelayValue = nil;
// --- Headtracker overlays ---
~knobOverlay = nil; ~htBtnOverlay = nil; ~htResetOverlay = nil; ~htPairOverlay = nil;                                                                                                                                                                                                                                                                                                                
// --- Headtracker pairing button reference ---
~headtrackPairBtn = nil;
// --- Headtracker MAC address (detected at startup) ---
~headtrackerMac = "bluetoothctl devices | grep 'HT' | awk '{print $2}'".unixCmdGetStdOut.stripWhiteSpace;
// --- Maplin button overlay --- grep hid, i get uhid 4
~maplinBtnOverlay = nil;
// --- Power button state ---
~powerBtnPressed = false;
// --- AmbiVerbSC preset system variables ---
~ambiencePresetNames = nil; ~ambiencePresetDict = nil; ~ambiencePresetMenu = nil;

// --- Ambience state preservation variables ---
~ambienceState = Dictionary.newFrom([
    \sliderValues, [0.0, 0.2, 0.2, 0.2, 0.0, 0.0, 0.0],  // Default values
    \presetIndex, 0,  // Default preset index
    \lastMix, 0.5     // Remember last nonzero mix value
]);

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
    \active, 0        // Active/bypass (default OFF)
]);



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

// Artist and Album menus (will be created after window is visible)


// Initialize original menu text storage
~originalMenuText = Dictionary.new;

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

    paths = files.collect(_.fullPath);
    ~filePaths = paths; // store as strings
    files.collect({ |f| 
        var name = f.fileName.asString;
        var ext = f.extension;
        if(ext.notNil, {
            var endIdx = name.size - ext.asString.size - 2;
            if(endIdx >= 0, { name.copyRange(0, endIdx) }, { name });
        }, { name });
    }).sort;
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
            .background_(Color.black)
            .stringColor_(Color.cyan)
            .selectedStringColor_(Color.black)
            .hiliteColor_(Color.cyan)
            .canFocus_(false)
                .selectionAction_({ |view|
                    var idx = view.value ? -1;
                    if(idx >= 0 and: { ~filePaths.notNil and: { idx < ~filePaths.size } }, {
                        var path = ~filePaths[idx];
                        if(~sfp.notNil) {
                            ~sfp.stop;
                            ~sfp.load(path);
                            // Reset all timer state
                            ~playStartTime = 0;
                            ~pausedTime = 0;
                            ~isPlaying = false;
                            // Reset button states immediately
                            if(~playerPlayBtn.notNil, { 
                                ~playerPlayBtn.value_(1); // Pause state (cyan icon on black background)
                            });
                            if(~playerLoopBtn.notNil, { 
                                ~playerLoopBtn.value_(0); // Loop off
                            });
                            // Force immediate timer reset and refresh
                            { 
                                ~updateTimeDisplay.value; 
                                if(~playerOverlay.notNil, { ~playerOverlay.refresh; });
                            }.defer(0.1);
                        };
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
    // Debug output to see what we're getting
    "Formatting: ".post; seconds.post; " -> mins: ".post; mins.post; " secs: ".post; secs.postln;
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
        
        // Update player time display
        if(~playerTimeDisplay.notNil, {
            ~playerTimeDisplay.string_(elapsedStr ++ " / " ++ totalStr);
        });
        
        if(~playerPositionSlider.notNil and: { total > 0 }, {
            ~playerPositionSlider.value_(elapsed / total);
        });
    });
};

// Task to update time display more frequently using AppClock
~timeUpdateTask = AppClock.sched(0, {
    ~updateTimeDisplay.value;
    0.1; // return 0.1 second for next scheduling (10 times per second)
});
// ~fileList.front; // ensure on top of border

// Function to detect USB drives and get available folders
~detectUSBDir = {
    var usbPaths = ["/media/" ++ Platform.userHomeDir.basename ++ "/", "/media/pi/", "/mnt/", "/media/"];
    var foundPath;
    
    usbPaths.do { |path|
        if(File.exists(path), {
            // Look for mounted drives, excluding system SD card
            var dirs = PathName(path).entries.select { |entry| 
                entry.isFolder and: { 
                    // Exclude common system mount points
                    entry.folderName != "root" and: 
                    entry.folderName != Platform.userHomeDir.basename and:
                    entry.folderName != "pi" and:
                    // Only include directories that have content (not empty system mounts)
                    PathName(entry.fullPath).entries.size > 0
                }
            };
            if(dirs.size > 0, {
                // Return the USB drive directory itself, not the parent
                foundPath = dirs[0].fullPath;
            });
        });
    };
    
    foundPath ? "/tmp/"; // fallback to temp directory
};

// Function to get USB folder options
~getUSBFolderOptions = {
    var usbBase = ~detectUSBDir.value;
    var folders;
    
    if(usbBase == "/tmp/", {
        // No USB drive detected
        folders = ["<NO DRIVE>"];
    }, {
        // USB drive found - look inside it for artist folders (ignore drive name)
        folders = ["<PARENT>"];
        if(File.exists(usbBase), {
            // Look inside the USB drive for actual content folders
            var usbEntries = PathName(usbBase).entries.select { |entry| entry.isFolder };
            if(usbEntries.size > 0, {
                // Use the first folder inside the USB drive as the content directory
                var contentDir = usbEntries[0].fullPath;
                var entries = PathName(contentDir).entries.select { |entry| entry.isFolder };
                entries.do { |entry|
                    folders = folders.add(entry.folderName.asString.toUpper);
                };
            });
        });
    });
    
    folders;
};

// Function to get ATK folder options (mirror USB scan on local ATK tree)
~getATKFolderOptions = {
    var atkBase = Atk.userSoundsDir ++ "/uhj";
    var folders;
    
    if(File.exists(atkBase).not, {
        // No ATK directory found
        folders = ["<NO DRIVE>"];
    }, {
        // ATK directory found - look inside it for artist folders
        folders = ["<PARENT>"];
        if(File.exists(atkBase), {
            // Look inside the ATK directory for actual content folders
            var entries = PathName(atkBase).entries.select { |entry| entry.isFolder };
            entries.do { |entry|
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
        // USB mode - use detected USB directory with artist and album
        var usbBase = ~detectUSBDir.value;
        if(artistName == "<NO DRIVE>", {
            albumPath = "/tmp/"; // fallback path
        }, {
            if(artistName == "<PARENT>", {
                albumPath = usbBase;
            }, {
                // Use artist and album selections (account for USB drive name being ignored)
                var usbEntries = PathName(usbBase).entries.select { |entry| entry.isFolder };
                var contentDir = if(usbEntries.size > 0) { usbEntries[0].fullPath } { usbBase };
                
                if(albumName == "<NO FOLDER>", {
                    // No album folders, just files in artist folder
                    albumPath = contentDir +/+ artistName +/+ "/";
                }, {
                    // Use both artist and album
                    albumPath = contentDir +/+ artistName +/+ albumName +/+ "/";
                });
            });
        });
    }, {
        // ATK mode - use same logic as USB
        var atkBase = Atk.userSoundsDir ++ "/uhj";
        if(artistName == "<NO DRIVE>", {
            albumPath = "/tmp/"; // fallback path
        }, {
            if(artistName == "<PARENT>", {
                albumPath = atkBase;
            }, {
                // Find actual artist folder by case-insensitive matching
                var actualArtistName = PathName(atkBase).entries.select { |entry| entry.isFolder }.detect { |entry| 
                    entry.folderName.asString.toUpper == artistName 
                };
                var actualArtistPath = if(actualArtistName.notNil) { actualArtistName.fullPath } { atkBase +/+ artistName };
                
                if(albumName == "<NO FOLDER>", {
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
    });
    
    // Final safety check - ensure we always return a valid path
    albumPath ? "/tmp/";
};

// Initialize current album path and ensure file list populates after GUI is up
{ 
    ~currentAlbumPath = ~buildAlbumPath.value;
    "Initial current album path: ".post; ~currentAlbumPath.postln;
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
StaticText(mainView, Rect(180, 10, 140, 28))
    .string_("ENCODER")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

StaticText(mainView, Rect(360, 10, 140, 28))
    .string_("DECODER")
    .align_(\center)
    .font_(Font("LCD 5x7 Segment Monospace", 14))
    .stringColor_(Color.cyan);

// Encoder menu (Input format selection)
~emenu = EZPopUpMenu.new(
    mainView,
    Rect(180, 45, 140, 35),
    "",
    [
        \UHJ -> { |a| configKeyE = \uhj; ("Encoder: UHJ").postln; },
        \SUPERSTEREO -> { |a| configKeyE = \superstereo; ("Encoder: SUPERSTEREO").postln; },
        \MAPLIN -> { |a| configKeyE = \maplin; ("Encoder: MAPLIN").postln; }
    ],
    globalAction: { |menu|
        // Update maplinMode on existing synth if it exists
        if(~synth.notNil) {
            ~synth.set(\maplinMode, if(configKeyE == \maplin, 1, 0));
            ("Updated maplinMode to: " ++ if(configKeyE == \maplin, 1, 0)).postln;
        };
        
        // Show/hide SM-333 button overlay based on encoder selection
        if(~maplinBtn.notNil) {
            if(configKeyE == \maplin) {
                // Remove overlay to enable button
                ("Enabling SM-333 button for MAPLIN mode").postln;
                if(~maplinBtnOverlay.notNil) {
                    ~maplinBtnOverlay.remove;
                    ~maplinBtnOverlay = nil;
                    ("SM-333 button overlay removed").postln;
                };
            } {
                // Close maplin overlay if it's open when switching away from maplin encoder
                ("Disabling SM-333 button for non-MAPLIN mode").postln;
                if(~maplinOverlay.notNil) {
                    ~saveMaplinState.value();
                    ~maplinOverlay.remove;
                    ~maplinOverlay = nil;
                    ~maplinBtn.value_(0);
                };
                // Add overlay to dim button (only if not already present)
                if(~maplinBtnOverlay.isNil) {
                    ~maplinBtnOverlay = View(mainView, Rect(290, 410, 100, 35))
                        .background_(Color.black.alpha_(0.7))
                        .alpha_(1.0)
                        .front;
                    ("SM-333 button overlay added").postln;
                };
            };
        };
        ("Selected encoder: " ++ menu.item).postln;
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
    var availableOutputs, decoderItems;
    
    // Detect number of JACK playback ports
    availableOutputs = "jack_lsp | grep 'system:playback' | wc -l".unixCmdGetStdOut.asInteger;
    if(availableOutputs == 0) {
        // Fallback: assume at least stereo if detection fails
        availableOutputs = 2;
        ("Warning: Could not detect JACK outputs, assuming stereo").postln;
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
            \OCTAGON -> { |a| inputs = 2; outputs = 8; configKeyD = \octagon; }
        ];
    };
    
    decoderItems;
};

// Decoder menu (Output format selection) - dynamically built
~dmenu = EZPopUpMenu.new(
    mainView,
    Rect(360, 45, 140, 35),
    "",
    ~buildDecoderMenu.value,
    globalAction: { |menu|
        var idx, decoderNames, decoderName, htIsOff, isBinaural, shouldDim;
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
        decoderNames = ["STEREO", "BINAURAL IRCAM", "BINAURAL CIPIC", "QUAD SQUARE", "QUAD NARROW", "QUAD WIDE", "DOLBY 5.1", "OCTAGON"];
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
                    child.string_("LAYOUT - " ++ decoderName);
                };
            });
            ~layoutOverlay.children.do({ |child|
                if(child.class == UserView) { child.refresh; };
            });
        };
        // --- Audio engine reinitialization logic (must be last) ---
        if((configKeyD != (~prevConfigKeyD ? configKeyD)) or: ((inputs != (~prevInputs ? inputs)) or: (outputs != (~prevOutputs ? outputs)))) {
            // Save current synth parameters before reinitializing
            ~saveSynthParams.value();
            ~initAudioEngine.value();
            ~prevConfigKeyD = configKeyD;
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
// --- Track previous decoder and encoder key for always-reload logic ---
~prevConfigKeyD = configKeyD;
~prevConfigKeyE = configKeyE;

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
    // Always reload kernels and restart synth on decoder or encoder change
    needReboot = (inputs != (~prevInputs ? inputs)) or: (outputs != (~prevOutputs ? outputs)) or: (configKeyD != (~prevConfigKeyD ? configKeyD)) or: (configKeyE != (~prevConfigKeyE ? configKeyE));
    tryBoot = {
        if(s.serverBooting, {
            ("Server busy (booting), retrying audio engine init...").postln;
            AppClock.sched(0.2, { tryBoot.value });
        }, {
            if(s.serverRunning.not, {
                s.options.memSize = 65536;
                s.options.numOutputBusChannels = outputs;
                s.options.numInputBusChannels = inputs;
                s.boot;
                cond = Condition.new;
                s.waitForBoot({
                    // Set audio card volume after server boot (vinyl deck setup)
                    ("echo 'Audio volume controlled by output interface'").postln;
                    // Create player bus and start SFPlayer
                    ~playerBus = Bus.audio(s, 2);
                    ~sfp = SFPlayer.new(Atk.userSoundsDir ++ "/uhj/Various/AJH_eight-positions-uhj.wav", outbus: ~playerBus.index, server: s, autoBootServer: false, autoSetSampleRate: false, autoSetOutputChannels: false).gui;
                    ~sfp.loop = true;
                    // Don't start playback yet - wait for main synth to be ready 
                    
                    { if(~playBtn.notNil, { ~playBtn.value_(0); }); }.defer(0.1);
                    
                    // Define encoder kernels
                    encoderDict = Dictionary.newFrom([
                        \uhj, FoaEncoderKernel.newUHJ,
                        \superstereo, FoaEncoderKernel.newSuper,
                        \maplin, FoaEncoderMatrix.newDirections([-45, 45, -135, 135].degrad),  // MaplinMatrix quad encoder
                    ]);

                    // Define decoder kernels (matching MainApp2 exactly, excluding unused \none)
                    decoderDict = Dictionary.newFrom([
                        \binaural, FoaDecoderKernel.newListen(1053),
                        \binaurac, FoaDecoderKernel.newCIPIC(12),
                        \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                        \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                        \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual'),
                        \fivezero, FoaDecoderMatrix.new5_0(irregKind: 'focused'),
                        \octagon, FoaDecoderMatrix.newPanto(8, 'flat', k: 'single'),
                        \stereo, FoaDecoderMatrix.newStereo
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
                    SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, quadLR = 0, quadFR = 0, ambience = 0, preDelay = 0, lowRT = 0.2, highRT = 2, dispersion = 1, modWidth = 0.2, modRate = 0.3, eq1 = 0, eq2 = 0, eq3 = 0, eq4 = 0, eq5 = 0, eq6 = 0, eq7 = 0, maplinSurround = 0.8, maplinEffect = 0.8, maplinDelay = 0.4, maplinActive = 1, maplinMode = 0|
                        var out, src, trans, encode, ambient, eqed, frontStereo, rearStereo, quadOutFront, quadOutRear, maplinQuad, encodeInput;
                        // Audio source from SFPlayer bus
                        src = In.ar(~playerBus.index, 2);
                        // Amplitude scaling
                        src = src * \amp.kr(0.dbamp); // 0dB default
                        // --- 7-band graphic EQ before ambisonic encode ---
                        eqed = src;
                        eqed = BPeakEQ.ar(eqed, 63, 1, eq1);      // Band 1
                        eqed = BPeakEQ.ar(eqed, 160, 1, eq2);     // Band 2
                        eqed = BPeakEQ.ar(eqed, 400, 1, eq3);     // Band 3
                        eqed = BPeakEQ.ar(eqed, 1000, 1, eq4);    // Band 4
                        eqed = BPeakEQ.ar(eqed, 2500, 1, eq5);    // Band 5
                        eqed = BPeakEQ.ar(eqed, 6400, 1, eq6);    // Band 6
                        eqed = BPeakEQ.ar(eqed, 12000, 1, eq7);   // Band 7
                        
                        // Pre-processing for maplin encoder: stereo to quad via MaplinMatrix
                        maplinQuad = MaplinMatrix.ar(
                            eqed[0], eqed[1],
                            surroundLevel: maplinSurround,
                            effectLevel: maplinEffect,
                            delayTime: maplinDelay,
                            active: maplinActive
                        );
                        
                        // Select input for encoding: quad (if maplin) or stereo (others)
                        encodeInput = Select.ar(maplinMode, [eqed, maplinQuad]);
                        
                        // Encode to ambisonic using selected encoder
                        encode = FoaEncode.ar(encodeInput, encoder);
                        
                        // Ambience processing
                        ambient = AmbiVerbSC.ar(encode,
                            mix: ambience,
                            preDelay: preDelay,
                            crossoverFreq: 3000,
                            lowRT: lowRT,
                            highRT: highRT,
                            dispersion: dispersion,
                            size: \Brahmssaal, // Use a room that definitely exists in AmbiVerbSC
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
                        // Spatial transformations (rotation, tilt, tumble) - apply to all modes
                        trans = FoaRTT.ar(ambient, rotAngle: rotation, tilAngle: tilt, tumAngle: tumble);
                        // Decode using selected decoder
                        out = FoaDecode.ar(trans, decoder);
                        if(outputs == 4, {
                            // --- Q-PANNER LOGIC (Balance2) ---
                            // out[0]=LF, out[1]=FR, out[2]=RL, out[3]=RR
                            frontStereo = Balance2.ar(out[0], out[3], quadLR); // LF, FR
                            rearStereo  = Balance2.ar(out[1], out[2], quadLR); // RL, RR
                            quadOutFront = frontStereo * ((quadFR + 1) * 0.5); // scale front by 0..1
                            quadOutRear  = rearStereo  * ((1 - quadFR) * 0.5); // scale rear by 1..0
                            out = [
                                quadOutFront[0], // LF (Speaker 1)
                                quadOutFront[1], // FR (Speaker 2)
                                quadOutRear[0],  // RL (Speaker 3)
                                quadOutRear[1]   // RR (Speaker 4)
                            ];
                        });
                        if(outputs == 6, {
                            // --- DOLBY 5.1 OUTPUT MAPPING (Consumer Standard) ---
                            // ATK 5.0 decoder: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR
                            // Map to consumer standard: [1] FL, [2] FR, [3] C, [4] RL, [5] RR, [6] Sub
                            var lowpass = BLowPass.ar((out[1] + out[4]), 120, 1, 0.4); // Sum FL + FR for sub
                            out = [
                                out[1], // FL (Speaker 1) - Front Left
                                out[4], // FR (Speaker 2) - Front Right  
                                out[0], // C  (Speaker 3) - Center
                                out[2], // RL (Speaker 4) - Rear Left
                                out[3], // RR (Speaker 5) - Rear Right
                                lowpass // Sub (Speaker 6) - Subwoofer
                            ];
                        });
                        
                        if(outputs == 8, {
                            // --- OCTAGON OUTPUT MAPPING (Clockwise from Front Left) ---
                            // ATK 8.0 decoder: Anti-clockwise from front left out[0]
                            // Map to diagram: Clockwise from front left starting at Speaker 1
                            out = [
                                out[0], // Speaker 1: Front Left (FL)
                                out[7], // Speaker 2: Front Left Center (FLC)
                                out[6], // Speaker 3: Center (C)
                                out[5], // Speaker 4: Front Right Center (FRC)
                                out[4], // Speaker 5: Front Right (FR)
                                out[3], // Speaker 6: Rear Right Center (RRC)
                                out[2], // Speaker 7: Rear Right (RR)
                                out[1]  // Speaker 8: Rear Left Center (RLC)
                            ];
                        });
                        
                        // Output routing for all modes
                        Out.ar(0, out);
                    }).add;

                    s.sync(cond);

                    // Start the synth
                    ~synth = Synth(\kernelEncodeDecode, [\buffer, sndbuf, \amp, voltmp, 
                        \maplinSurround, ~maplinState[\surround], 
                        \maplinEffect, ~maplinState[\effect],
                        \maplinDelay, ~maplinState[\delay], 
                        \maplinActive, ~maplinState[\active],
                        \maplinMode, if(configKeyE == \maplin, 1, 0)]);
                    // Load first track from file list (if available) but don't start playing
                    { 
                        if(~filePaths.notNil and: { ~filePaths.size > 0 }, {
                            ~sfp.stop;
                            ~sfp.load(~filePaths[0]); // already a string
                            ~playStartTime = 0;
                            ~pausedTime = 0;
                            ~isPlaying = false;
                            // Reset button states
                            if(~playerPlayBtn.notNil, { 
                                ~playerPlayBtn.value_(1); // Pause state (cyan icon on black background)
                            });
                            if(~playerLoopBtn.notNil, { 
                                ~playerLoopBtn.value_(0); // Loop off
                            });
                            if(~fileList.notNil) { ~fileList.value_(0); }; // select first track in list
                            { 
                                if(~playerOverlay.notNil, { ~playerOverlay.refresh; });
                            }.defer(0.1); // Refresh button display
                        });
                    }.defer(0.2);
                    
                    // Restore saved parameters to new synth
                    ~restoreSynthParams.value();

                    // Create unified SFPlayerMeter (handles both input and output meters)
                    {
                        ~meter.remove; // Remove any existing meter
                        ("Creating unified SFPlayerMeter with outputs=" ++ outputs).postln;
                        ~meter = SFPlayerMeter.new(s, ~meterContainer, 68@0, 2, outputs, ~playerBus);
                    }.defer;

                    ("Audio synthesis started with level meter").postln;
                });
            }, {
                if(needReboot, {
                    s.options.memSize = 65536;
                    s.options.numOutputBusChannels = outputs;
                    s.options.numInputBusChannels = inputs;
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
                            ~sfp = SFPlayer.new(~filePaths[0], outbus: ~playerBus.index, server: s, autoBootServer: false, autoSetSampleRate: false, autoSetOutputChannels: false).gui;
                            ~sfp.loop = true;
                        });
                        
                        // Define encoder kernels
                        encoderDict = Dictionary.newFrom([
                            \uhj, FoaEncoderKernel.newUHJ,
                            \superstereo, FoaEncoderKernel.newSuper,
                            \maplin, FoaEncoderMatrix.newDirections([-45, 45, -135, 135].degrad),  // MaplinMatrix quad encoder
                        ]);

                        // Define decoder kernels (matching MainApp2 exactly, excluding unused \none)
                        decoderDict = Dictionary.newFrom([
                            \binaural, FoaDecoderKernel.newListen(1053),
                            \binaurac, FoaDecoderKernel.newCIPIC(12),
                            \quadsquare, FoaDecoderMatrix.newQuad(pi/4, k: 'dual'),
                            \quadnarrow, FoaDecoderMatrix.newQuad(pi/6, k: 'dual'),
                            \quadwide, FoaDecoderMatrix.newQuad(pi/3, k: 'dual'),
                            \fivezero, FoaDecoderMatrix.new5_0(irregKind: 'focused'),
                            \octagon, FoaDecoderMatrix.newPanto(8, 'flat', k: 'single'),
                            \stereo, FoaDecoderMatrix.newStereo
                        ]);

                        // Get selected encoder and decoder
                        encoder = encoderDict.at(configKeyE ? \uhj);
                        decoder = decoderDict.at(configKeyD ? \stereo);

                        ("Audio engine initialized with encoder: " ++ configKeyE ++ " and decoder: " ++ configKeyD).postln;

                        // Load test audio file (same as MainApp2)
                        // sndbuf = Buffer.read(s, Atk.userSoundsDir ++ "/uhj/Sodium_Sunrise_UHJ.wav");

                        s.sync(cond);

                        // Define the main audio processing SynthDef (adapted from MainApp2)
                        SynthDef(\kernelEncodeDecode, { |buffer, rotation = 0, tilt = 0, tumble = 0, quadLR = 0, quadFR = 0, ambience = 0, preDelay = 0, lowRT = 0.2, highRT = 2, dispersion = 1, modWidth = 0.2, modRate = 0.3, eq1 = 0, eq2 = 0, eq3 = 0, eq4 = 0, eq5 = 0, eq6 = 0, eq7 = 0, maplinSurround = 0.8, maplinEffect = 0.8, maplinDelay = 0.4, maplinActive = 1, maplinMode = 0|
                            var out, src, trans, encode, ambient, eqed, frontStereo, rearStereo, quadOutFront, quadOutRear, maplinQuad, encodeInput;
                            // Audio source from SFPlayer bus
                            src = In.ar(~playerBus.index, 2);
                            // Amplitude scaling
                            src = src * \amp.kr(0.dbamp); // 0dB default
                            // --- 7-band graphic EQ before ambisonic encode ---
                            eqed = src;
                            eqed = BPeakEQ.ar(eqed, 63, 1, eq1);      // Band 1
                            eqed = BPeakEQ.ar(eqed, 160, 1, eq2);     // Band 2
                            eqed = BPeakEQ.ar(eqed, 400, 1, eq3);     // Band 3
                            eqed = BPeakEQ.ar(eqed, 1000, 1, eq4);    // Band 4
                            eqed = BPeakEQ.ar(eqed, 2500, 1, eq5);    // Band 5
                            eqed = BPeakEQ.ar(eqed, 6400, 1, eq6);    // Band 6
                            eqed = BPeakEQ.ar(eqed, 12000, 1, eq7);   // Band 7
                            
                            // Pre-processing for maplin encoder: stereo to quad via MaplinMatrix
                            maplinQuad = MaplinMatrix.ar(
                                eqed[0], eqed[1],
                                surroundLevel: maplinSurround,
                                effectLevel: maplinEffect,
                                delayTime: maplinDelay,
                                active: maplinActive
                            );
                            
                            // Select input for encoding: quad (if maplin) or stereo (others)
                            encodeInput = Select.ar(maplinMode, [eqed, maplinQuad]);
                            
                            // Encode to ambisonic using selected encoder
                            encode = FoaEncode.ar(encodeInput, encoder);
                            // Ambience processing
                            ambient = AmbiVerbSC.ar(encode,
                                mix: ambience,
                                preDelay: preDelay,
                                crossoverFreq: 3000,
                                lowRT: lowRT,
                                highRT: highRT,
                                dispersion: dispersion,
                                size: \Brahmssaal, // Use a room that definitely exists in AmbiVerbSC
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
                            // Spatial transformations (rotation, tilt, tumble)
                            trans = FoaRTT.ar(ambient, rotAngle: rotation, tilAngle: tilt, tumAngle: tumble);
                            // Decode using selected decoder
                            out = FoaDecode.ar(trans, decoder);
                            if(outputs == 4, {
                                // --- Q-PANNER LOGIC (Balance2) ---
                                // out[0]=LF, out[1]=FR, out[2]=RL, out[3]=RR
                                frontStereo = Balance2.ar(out[0], out[3], quadLR); // LF, FR
                                rearStereo  = Balance2.ar(out[1], out[2], quadLR); // RL, RR
                                quadOutFront = frontStereo * ((quadFR + 1) * 0.5); // scale front by 0..1
                                quadOutRear  = rearStereo  * ((1 - quadFR) * 0.5); // scale rear by 1..0
                                out = [
                                    quadOutFront[0], // LF (Speaker 1)
                                    quadOutFront[1], // FR (Speaker 2)
                                    quadOutRear[0],  // RL (Speaker 3)
                                    quadOutRear[1]   // RR (Speaker 4)
                                ];
                            });
                            if(outputs == 6, {
                                // --- DOLBY 5.1 OUTPUT MAPPING (Consumer Standard) ---
                                // ATK 5.0 decoder: out[0]=C, out[1]=FL, out[2]=RL, out[3]=RR, out[4]=FR
                                // Map to consumer standard: [1] FL, [2] FR, [3] C, [4] RL, [5] RR, [6] Sub
                                var lowpass = BLowPass.ar((out[1] + out[4]), 120, 1, 0.4); // Sum FL + FR for sub
                                out = [
                                    out[1], // FL (Speaker 1) - Front Left
                                    out[4], // FR (Speaker 2) - Front Right  
                                    out[0], // C  (Speaker 3) - Center
                                    out[2], // RL (Speaker 4) - Rear Left
                                    out[3], // RR (Speaker 5) - Rear Right
                                    lowpass // Sub (Speaker 6) - Subwoofer
                                ];
                            });
                            
                            if(outputs == 8, {
                                // --- OCTAGON OUTPUT MAPPING (Clockwise from Front Left) ---
                                // ATK 8.0 decoder: Anti-clockwise from front left out[0]
                                // Map to diagram: Clockwise from front left starting at Speaker 1
                                out = [
                                    out[0], // Speaker 1: Front Left (FL)
                                    out[7], // Speaker 2: Front Left Center (FLC)
                                    out[6], // Speaker 3: Center (C)
                                    out[5], // Speaker 4: Front Right Center (FRC)
                                    out[4], // Speaker 5: Front Right (FR)
                                    out[3], // Speaker 6: Rear Right Center (RRC)
                                    out[2], // Speaker 7: Rear Right (RR)
                                    out[1]  // Speaker 8: Rear Left Center (RLC)
                                ];
                            });
                            
                            // Output routing for all modes
                            Out.ar(0, out);
                        }).add;

                        s.sync(cond);

                        // Start the synth
                        ~synth = Synth(\kernelEncodeDecode, [\buffer, sndbuf, \amp, voltmp, 
                            \maplinSurround, ~maplinState[\surround], 
                            \maplinEffect, ~maplinState[\effect],
                            \maplinDelay, ~maplinState[\delay], 
                            \maplinActive, ~maplinState[\active],
                            \maplinMode, if(configKeyE == \maplin, 1, 0)]);
                        
                        // Restore saved parameters to new synth
                        ~restoreSynthParams.value();

                    // Create unified SFPlayerMeter (handles both input and output meters)
                    {
                        ~meter.remove; // Remove any existing meter
                        ("Creating unified SFPlayerMeter with outputs=" ++ outputs).postln;
                        ~meter = SFPlayerMeter.new(s, ~meterContainer, 68@0, 2, outputs, ~playerBus);
                    }.defer;

                        ("Audio synthesis started with level meter").postln;
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

~xyPanner = Slider2D(mainView, Rect(629, 334, 110, 110))
    .x_(0.5).y_(0.5)
    .knobColor_(Color.cyan)
    .background_(Color.black)
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
                
                // Safety timeout - reset button after 15 seconds if script hangs
                AppClock.sched(15, { 
                    if (~pairingInProgress) {
                        ~pairingInProgress = false;  // Reset flag
                        ~headtrackPairBtn.value_(3); // Show failed if still in progress
                        AppClock.sched(3, { ~headtrackPairBtn.value_(0); nil });
                    };
                    nil 
                });
                
                // First attempt
                try {
                    result = ("timeout 15 bash -c '" ++ scriptPath ++ "'").unixCmdGetStdOut;
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
                        result = ("timeout 15 bash -c '" ++ scriptPath ++ "'").unixCmdGetStdOut;
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
        
        // Only check if button exists, shows paired status and not currently pairing
        // Use defer to access GUI elements from background thread
        {
            if ((~headtrackPairBtn.notNil) && (~headtrackPairBtn.value == 2) && (~pairingInProgress.not)) {
                if (~headtrackerMac.notEmpty) {
                    checkResult = ("bluetoothctl info " ++ ~headtrackerMac).unixCmdGetStdOut;
                    isConnected = checkResult.contains("Connected: yes");
                    isPaired = checkResult.contains("Paired: yes");
                    
                    if (isPaired.not || isConnected.not) {
                        // Device is disconnected/removed - reset button
                        ~headtrackPairBtn.value_(0);
                    };
                } {
                    // No headtracker MAC - reset button
                    ~headtrackPairBtn.value_(0);
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

// Store original menu text to preserve data integrity
~originalMenuText = Dictionary.new;
~scrollTasks = Dictionary.new; // Store scrolling tasks

// Automatic scrolling text for long menu items
~scrollMenuText = { |menu, text, maxWidth = 12|
    var menuKey = menu.hash.asString;
    ~originalMenuText[menuKey] = text; // Store original text
    
    // Stop any existing scrolling task for this menu
    if(~scrollTasks[menuKey].notNil, {
        ~scrollTasks[menuKey].stop;
        ~scrollTasks[menuKey] = nil;
    });
    
    if(text.size > maxWidth, {
        var scrollText = text ++ "    " ++ text; // Duplicate with spaces
        var scrollTask = Task({
            inf.do({
                // Wait before starting to scroll
                2.0.wait;
                // Scroll through the text
                (text.size + 5).do({ |i|
                    var displayText = scrollText.copyRange(i, i + maxWidth - 1);
                    var currentItems = menu.items.copy;
                    currentItems[0] = displayText;
                    // Schedule GUI update on AppClock
                    AppClock.sched(0, {
                        menu.items_(currentItems);
                        nil; // Don't reschedule
                    });
                    0.2.wait; // Scroll speed
                });
                // Pause at the end before restarting
                2.0.wait; // Pause duration
            });
        });
        ~scrollTasks[menuKey] = scrollTask; // Store the task
        scrollTask.start;
    });
};

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
        var isUSB = view.value == 1;
        var menuKey;
        "Source switched to: ".post; (isUSB ? "USB" : "ATK").postln;
        
        // Update artist menu based on source
        if(isUSB, {
            // USB mode - show actual folders found on USB drive
            ~artistMenu.items_(~getUSBFolderOptions.value);
        }, {
            // ATK mode - use same discovery logic as USB
            ~artistMenu.items_(~getATKFolderOptions.value);
        });
        
        // Reset artist menu selection and update album menu based on mode
        ~artistMenu.value_(0);
        
        // Stop any existing scrolling first
        menuKey = ~albumMenu.hash.asString;
        if(~scrollTasks[menuKey].notNil, {
            ~scrollTasks[menuKey].stop;
            ~scrollTasks[menuKey] = nil;
        });
        
        if(isUSB, {
            // USB mode - clear album menu
            ~albumMenu.items_(["..."]);
            ~albumMenu.value_(0);
        }, {
            // ATK mode - set up album menu
            ~albumMenu.items_(["THE LONGEST DAY"]);
            ~albumMenu.value_(0);
        });
        
        // Start scrolling for long text in both modes
        if(~albumMenu.items[0].size > 12, {
            ~scrollMenuText.value(~albumMenu, ~albumMenu.items[0]);
        });
        
        // Update file list and current path
        if(~fileList.notNil) { ~fileList.items_(~buildFileList.value); };
        ~currentAlbumPath = ~buildAlbumPath.value;
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
        var artistName, albumList, isUSB, oldAction, albumMenuKey;
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
                { artistName == "<PARENT>" } { albumList = ["..."]; }
                {
                    // Get actual subdirectories in the artist folder (account for USB drive name being ignored)
                    var usbBase = ~detectUSBDir.value;
                    var usbEntries = PathName(usbBase).entries.select { |entry| entry.isFolder };
                    var contentDir = if(usbEntries.size > 0) { usbEntries[0].fullPath } { usbBase };
                    var artistPath = contentDir +/+ artistName;
                    
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
                        // Add <NO FOLDER> if there are files outside album folders
                        if(audioFiles.size > 0) {
                            albumList = albumList ++ ["<NO FOLDER>"];
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
                { artistName == "<PARENT>" } { albumList = ["..."]; }
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
                        // Add <NO FOLDER> if there are files outside album folders
                        if(audioFiles.size > 0) {
                            albumList = albumList ++ ["<NO FOLDER>"];
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
            // Stop any existing scrolling first
            albumMenuKey = ~albumMenu.hash.asString;
            if(~scrollTasks[albumMenuKey].notNil, {
                ~scrollTasks[albumMenuKey].stop;
                ~scrollTasks[albumMenuKey] = nil;
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
            // Start scrolling for long text
            if(albumList[0].size > 12, {
                ~scrollMenuText.value(~albumMenu, albumList[0]);
            });
        };
        if(~fileList.notNil) { ~fileList.items_(~buildFileList.value); };
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

// Set initial values
~artistMenu.value_(0);
~albumMenu.value_(0);

// Trigger artist menu action to populate album menu
~artistMenu.doAction;


// --- Overlay Buttons (EQ, AMBIENCE, LAYOUT) below meter area ---
~eqBtn = Button(mainView, Rect(180, 410, 100, 35))
    .states_([ ["EQ", Color.cyan, Color.black], ["EQ", Color.black, Color.cyan] ])
    .font_(Font("Helvetica", 13))
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({ |btn|
        var freqs, eqWidth, sliderWidth, sliderHeight, startX, gap;
        if(btn.value == 1) {
            // --- RADIO BUTTON BEHAVIOR: Only one overlay/button active at a time ---
            if(~ambienceOverlay.notNil) { 
                ~saveAmbienceState.value(); // Save state before removing ambience overlay
                ~ambienceOverlay.remove; ~ambienceOverlay = nil; ~ambienceBtn.value_(0); 
            };
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; ~layoutBtn.value_(0); };
            if(~maplinOverlay.notNil) { 
                ~saveMaplinState.value(); // Save state before removing maplin overlay
                ~maplinOverlay.remove; ~maplinOverlay = nil; ~maplinBtn.value_(0); 
            };
            if(~playerOverlay.notNil) { ~playerOverlay.remove; ~playerOverlay = nil; ~playerBtn.value_(0); };
            // Set other buttons to 0 (radio group)
            ~ambienceBtn.value_(0);
            ~layoutBtn.value_(0);
            ~maplinBtn.value_(0);
            ~playerBtn.value_(0);
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
};

~restoreAmbienceState = {
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

// --- MAPLIN SM-333 CONTROL FUNCTIONS ---
~setMaplinSurround = { |level=0.8|
    if(~synth.notNil) { ~synth.set(\maplinSurround, level); };
    ~maplinState[\surround] = level;
    ("Maplin surround level: " ++ (level * 100).round(1) ++ "%").postln;
};

~setMaplinEffect = { |level=0.8|
    if(~synth.notNil) { ~synth.set(\maplinEffect, level); };
    ~maplinState[\effect] = level;
    ("Maplin effect level: " ++ (level * 100).round(1) ++ "%").postln;
};

~setMaplinDelay = { |time=0.4|
    var delayMs = time.linlin(0, 1, 5, 50);
    if(~synth.notNil) { ~synth.set(\maplinDelay, time); };
    ~maplinState[\delay] = time;
    ("Maplin delay time: " ++ delayMs.round(1) ++ "ms").postln;
};

~setMaplinActive = { |active=true|
    if(~synth.notNil) { ~synth.set(\maplinActive, if(active, 1, 0)); };
    ~maplinState[\active] = if(active, 1, 0);
    ("Maplin processing: " ++ if(active, "ACTIVE", "BYPASSED")).postln;
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
        ("Saved Maplin GUI state: surround=" ++ ~maplinState[\surround] ++ ", effect=" ++ ~maplinState[\effect] ++ ", delay=" ++ ~maplinState[\delay]).postln;
    };
};

~restoreMaplinState = {
    if(~maplinSurroundKnob.notNil) {
        ~maplinSurroundKnob.value_(~maplinState[\surround] ? 0.8);
        ~maplinEffectKnob.value_(~maplinState[\effect] ? 0.8);
        ~maplinDelayKnob.value_(~maplinState[\delay] ? 0.4);
        
        // Update value displays
        ~maplinSurroundValue.string_((~maplinState[\surround] * 100).round(1).asString ++ "%");
        ~maplinEffectValue.string_((~maplinState[\effect] * 100).round(1).asString ++ "%");
        ~maplinDelayValue.string_((~maplinState[\delay].linlin(0, 1, 5, 50).round(1).asString ++ " ms"));
        
        // Trigger actions to update synth
        if(~maplinSurroundKnob.action.notNil) { ~maplinSurroundKnob.action.value(~maplinSurroundKnob); };
        if(~maplinEffectKnob.action.notNil) { ~maplinEffectKnob.action.value(~maplinEffectKnob); };
        if(~maplinDelayKnob.action.notNil) { ~maplinDelayKnob.action.value(~maplinDelayKnob); };
        
        ("Restored Maplin GUI state: surround=" ++ ~maplinState[\surround] ++ ", effect=" ++ ~maplinState[\effect] ++ ", delay=" ++ ~maplinState[\delay]).postln;
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
        var params = ~ambienceState[\synthParams];
        if(params.size >= 7) {
            // Convert slider values (0-1) to synth parameter ranges (matching GUI slider actions)
            ~synth.set(
                \ambience, (params[0] ? 0).linlin(0, 1, 0, 0.2),    // Mix: 0-20%
                \preDelay, params[1] ? 0,                            // PreDelay: direct value
                \lowRT, (params[2] ? 0.2).linlin(0, 1, 0.2, 4),     // LowRT: 0.2-4s  
                \highRT, (params[3] ? 2).linlin(0, 1, 0.2, 4),      // HighRT: 0.2-4s
                \dispersion, params[4] ? 1,                          // Dispersion: direct value
                \modWidth, params[5] ? 0.2,                          // ModWidth: direct value
                \modRate, params[6] ? 0.3                            // ModRate: direct value
            );
            ("Restored synth ambience params (converted): mix=" ++ (params[0] ? 0).linlin(0, 1, 0, 0.2) ++ ", others=" ++ params[1..6]).postln;
        } {
            ("Warning: ambience params array too small: " ++ params).postln;
        };
    };
};

// --- AmbiVerbSC Preset Recall Function ---
~recallAmbiVerbSCPreset = { |presetName|
    var presetData, roomName;

    if(~ambiencePresetDict.notNil and: { ~ambiencePresetDict[presetName].notNil }) {
        presetData = ~ambiencePresetDict[presetName];
        roomName = presetData[\roomName];

        // Ensure roomName is not nil
        if(roomName.isNil) {
            ("Warning: No room name found in preset " ++ presetName ++ ", using Brahmssaal").postln;
            roomName = "Brahmssaal";
        };

        // Update sliders with preset values
        if(~ambienceSliders.notNil) {
            // Map preset values to slider ranges
            ~ambienceSliders[0].value_(presetData[\mix].linlin(0, 1, 0, 1)); // Mix
            ~ambienceSliders[1].value_(presetData[\preDelay].linlin(0, 0.5, 0, 1)); // PreDelay
            ~ambienceSliders[2].value_(presetData[\lowRT].linlin(0.01, 2, 0, 1)); // LowRT
            ~ambienceSliders[3].value_(presetData[\highRT].linlin(0.01, 4, 0, 1)); // HighRT
            ~ambienceSliders[4].value_(presetData[\dispersion].linlin(0.1, 2, 0, 1)); // Dispersion
            ~ambienceSliders[5].value_(presetData[\modWidth].linlin(0, 1, 0, 1)); // ModWidth
            ~ambienceSliders[6].value_(presetData[\modRate].linlin(0, 1, 0, 1)); // ModRate

            // Trigger slider actions to update synth
            ~ambienceSliders.do({ |slider, i|
                if(slider.action.notNil) {
                    slider.action.value(slider);
                };
            });
        };

        // Update synth with new room and parameters (without breaking audio)
        if(~synth.notNil) {
            // Use synth.set() instead of recreating to avoid signal break
            ~synth.set(
                \ambience, presetData[\mix].linlin(0, 1, 0, 0.2),
                \preDelay, presetData[\preDelay].linlin(0, 0.5, 0, 1),
                \lowRT, presetData[\lowRT].linlin(0.01, 2, 0.1, 2),
                \highRT, presetData[\highRT].linlin(0.01, 4, 0.2, 4),
                \dispersion, presetData[\dispersion].linlin(0.1, 2, 0.1, 2),
                \modWidth, presetData[\modWidth].linlin(0, 1, 0, 1),
                \modRate, presetData[\modRate].linlin(0, 1, 0, 1),
                \size, roomName.asSymbol
            );
        };

        ("Applied preset: " ++ presetName ++ " (Room: " ++ roomName ++ ")").postln;
    };
};

~ambienceBtn = Button(mainView, Rect(399, 410, 100, 35))
    .states_([["AMBIENCE", Color.cyan, Color.black], ["AMBIENCE", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({ |btn|
        var params, sliderLabels, sliderWidth, sliderHeight, startX, gap, x, slider, valDisp;
        if(btn.value == 1) {
            // --- RADIO BUTTON BEHAVIOR: Only one overlay/button active at a time ---
            if(~eqOverlay.notNil) { 
                ~saveEqState.value(); // Save state before removing EQ overlay
                ~eqOverlay.remove; ~eqOverlay = nil; ~eqBtn.value_(0); 
            };
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; ~layoutBtn.value_(0); };
            if(~maplinOverlay.notNil) { 
                ~saveMaplinState.value(); // Save state before removing maplin overlay
                ~maplinOverlay.remove; ~maplinOverlay = nil; ~maplinBtn.value_(0); 
            };
            if(~playerOverlay.notNil) { ~playerOverlay.remove; ~playerOverlay = nil; ~playerBtn.value_(0); };
            // Set other buttons to 0 (radio group)
            ~eqBtn.value_(0);
            ~layoutBtn.value_(0);
            ~maplinBtn.value_(0);
            ~playerBtn.value_(0);
            // --- Remove any previous Ambience overlay and controls to prevent duplicates ---
            if(~ambienceOverlay.notNil) { ~ambienceOverlay.remove; ~ambienceOverlay = nil; };
            // --- Initialize layout variables (fix nil error) ---
            sliderWidth = 32; sliderHeight = 140; startX = 12; gap = 44;
            // Create Ambience overlay directly in main window
            ~ambienceOverlay = View(mainView, Rect(180, 107, 320, 275)).background_(Color.black);
            UserView(~ambienceOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.white;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });
            StaticText(~ambienceOverlay, Rect(10, 5, 120, 22))
                .string_("AMBIENCE")
                .align_(\left)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);

            // Load AmbiVerbSC presets if not already loaded
            if(~ambiencePresetNames.isNil) {
                var presetData = ~loadAmbiVerbSCPresets.value();
                ~ambiencePresetNames = presetData[0];
                ~ambiencePresetDict = presetData[1];
            };

            // Preset selector (dropdown)
            ~ambiencePresetMenu = PopUpMenu(~ambienceOverlay, Rect(140, 7, 170, 20))
                .items_(["Default", "High Verb", "Huge Hall", "Large Hall", "Low Verb", "Mod Echo", "Spatial Delay", "Time Modulation"])
                .font_(Font("Helvetica", 11))
                .background_(Color.black)
                .stringColor_(Color.cyan)
                .value_(~ambienceState[\presetIndex] ? 0) // Use saved preset index
                .action_({ |menu|
                    var selectedPreset = ~ambiencePresetNames[menu.value];
                    ~recallAmbiVerbSCPreset.value(selectedPreset);
                });
            // Parameter labels and values (use saved state or defaults)
            sliderLabels = ["Reverb", "PreDly", "LoRT", "HiRT", "Disp", "MWid", "MRate"];
            params = ~ambienceState[\sliderValues] ? [0.0, 0.2, 0.2, 0.2, 0.0, 0.0, 0.0];
            ~ambienceLastMix = ~ambienceState[\lastMix] ? 0.5; // Remember last nonzero mix value
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
                        var val = (sl.value * 100).round(0.1);
                        ~ambienceValues[i].string = val.asString ++ "%";
                        if(~synth.notNil) {
                            switch(i,
                                0, {
                                    ~synth.set(\ambience, sl.value.linlin(0, 1, 0, 0.2));
                                    // --- Sync ON/OFF button with Mix slider ---
                                    if(sl.value > 0) {
                                        ~ambienceOnOffBtn.value_(1);
                                        ~ambienceLastMix = sl.value;
                                    } {
                                        ~ambienceOnOffBtn.value_(0);
                                    }
                                },
                                1, { ~synth.set(\preDelay, sl.value.linlin(0,1,0,0.5)); },
                                2, { ~synth.set(\lowRT, sl.value.linlin(0,1,0.1,2)); },
                                3, { ~synth.set(\highRT, sl.value.linlin(0,1,0.2,4)); },
                                4, { ~synth.set(\dispersion, sl.value.linlin(0,1,0.1,2)); },
                                5, { ~synth.set(\modWidth, sl.value); },
                                6, { ~synth.set(\modRate, sl.value); }
                            );
                        }
                    });
                ~ambienceSliders.add(slider);
                valDisp = StaticText(~ambienceOverlay, Rect(x, 200, sliderWidth, 16))
                    .string_((params[i] * 100).asString ++ "%")
                    .align_(\center)
                    .stringColor_(Color.cyan)
                    .font_(Font("Helvetica", 9))
                    .background_(Color.clear);
                ~ambienceValues.add(valDisp);
            });
            // --- ON/OFF toggle for Ambience (controls Mix sent to synth, but does NOT move slider) ---
            // (Removed stray .states_, .font_, .value_, .action_ lines that were not attached to a Button)
            // --- Mix slider action: always updates value label and, if ON, sends to synth ---
            ~ambienceSliders[0].action_({ |sl|
                var val = (sl.value * 100).round(0.1);
                ~ambienceValues[0].string = val.asString ++ "%";
                if(~synth.notNil) {
                    ~synth.set(\ambience, sl.value.linlin(0, 1, 0, 0.2));
                }
            });
            // --- Ensure ON/OFF button and Mix slider are visually independent on open ---
            if(~ambienceOnOffBtn.notNil) { ~ambienceOnOffBtn.value_(0); };
            if(~ambienceSliders.notNil and: { ~ambienceSliders[0].notNil }) { ~ambienceSliders[0].value = 0; };
            // Close button
            Button(~ambienceOverlay, Rect(222, 230, 80, 28))
                .states_([["CLOSE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~saveAmbienceState.value(); // Save state before closing
                    ~ambienceOverlay.remove;
                    ~ambienceOverlay = nil;
                    ~ambienceBtn.value_(0);
                });
            // Place RESET button before CLOSE button in the Ambience overlay:
            Button(~ambienceOverlay, Rect(18, 230, 80, 28))
                .states_([ ["RESET", Color.cyan, Color.black] ])
                .font_(Font("Helvetica", 11))
                .action_({
                    // Reset to default preset
                    if(~ambiencePresetNames.notNil and: { ~ambiencePresetNames.size > 0 }) {
                        ~ambiencePresetMenu.value_(0); // Select first preset
                        ~recallAmbiVerbSCPreset.value(~ambiencePresetNames[0]);
                    }
                });
            Button(~ambienceOverlay, Rect(222, 230, 80, 28))
                .states_([ ["CLOSE", Color.cyan, Color.black] ])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~saveAmbienceState.value(); // Save state before closing
                    ~ambienceOverlay.remove;
                    ~ambienceOverlay = nil;
                    ~ambienceBtn.value_(0);
                });
            ~ambienceOverlay.front;
            // Restore saved state or apply default preset on overlay open
            if(~ambienceState[\sliderValues].notNil and: { ~ambienceState[\sliderValues].size > 0 }) {
                ("Found saved state, restoring...").postln;
                ~restoreAmbienceState.value(); // Restore saved slider values
            } {
                ("No saved state, applying default preset...").postln;
                // Apply default preset if no saved state
                if(~ambiencePresetNames.notNil and: { ~ambiencePresetNames.size > 0 }) {
                    ~recallAmbiVerbSCPreset.value(~ambiencePresetNames[0]);
                }
            }
        } {
            if(~ambienceOverlay.notNil) { ~ambienceOverlay.remove; ~ambienceOverlay = nil; };
        }
    });

// PLAYER button - positioned to the left of EQ button
~playerBtn = Button(mainView, Rect(70, 410, 100, 35))
    .states_([["PLAYER", Color.cyan, Color.black], ["PLAYER", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
    .focusColor_(Color.clear)
    .canFocus_(false)
    .action_({ |btn|
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
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; ~layoutBtn.value_(0); };
            if(~maplinOverlay.notNil) { 
                ~saveMaplinState.value(); // Save state before removing maplin overlay
                ~maplinOverlay.remove; ~maplinOverlay = nil; ~maplinBtn.value_(0); 
            };
            // Set other buttons to 0 (radio group)
            ~eqBtn.value_(0);
            ~ambienceBtn.value_(0);
            ~layoutBtn.value_(0);
            ~maplinBtn.value_(0);
            
            // Create PLAYER overlay in central area
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
                    var artworkPath;
                    if(~currentAlbumPath.notNil, {
                        artworkPath = ~currentAlbumPath +/+ "artwork.png";
                        if(File.exists(artworkPath), {
                            try {
                                var image = Image.open(artworkPath);
                                if(image.notNil, {
                                    image.drawInRect(Rect(0, 0, view.bounds.width, view.bounds.height), 
                                                   Rect(0, 0, image.width, image.height), 2);
                                }, {
                                    Pen.color = Color.cyan;
                                    Pen.stringAtPoint("LOAD FAIL", Point(80, 100));
                                });
                            } { |error|
                                Pen.color = Color.cyan;
                                Pen.stringAtPoint("ERROR", Point(90, 100));
                            };
                        }, {
                            Pen.color = Color.cyan;
                            Pen.stringAtPoint("NO ART", Point(85, 100));
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
                        // Stop and restart to reset position
                        ~sfp.stop;
                        if(wasPlaying, { ~sfp.play; });
                        // Reset our timer
                        ~playStartTime = 0;
                        ~pausedTime = 0;
                    });
                });


            ~playerPlayBtn = Button(~playerOverlay, Rect(220, 88, 80, 35))
                .states_([["", Color.black, Color.cyan], ["", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 16).boldVariant)
                .canFocus_(false)
                .focusColor_(Color.clear)
                .action_({ |btn|
                    if(~sfp.notNil, {
                        if(btn.value == 0, {
                            // Play (black icon on cyan background)
                            ~sfp.play;
                            ~isPlaying = true;
                            ~playStartTime = SystemClock.seconds;
                            ~pausedTime = 0;
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
                        // SFPlayer.stop already resets the playhead to zero
                        ~sfp.stop;
                        ~playerPlayBtn.value_(1); // Pause state (cyan icon on black background)
                        ~isPlaying = false;
                        // Reset internal timer state to match SFPlayer's cursor at zero
                        ~playStartTime = 0;
                        ~pausedTime = 0;
                        // Refresh the play icon to update color
                        if(~playerOverlay.notNil, { ~playerOverlay.refresh; });
                    });
                });

            ~playerLoopBtn = Button(~playerOverlay, Rect(220, 184, 80, 35))
                .states_([["⟲", Color.cyan, Color.black], ["⟲", Color.black, Color.cyan]])
                .font_(Font("Helvetica", 20).boldVariant)
                .canFocus_(false)
                .focusColor_(Color.clear)
                .action_({ |btn|
                    if(~sfp.notNil, {
                        if(btn.value == 0, {
                            // Loop off (cyan icon on black background)
                            ~sfp.loop = false;
                        }, {
                            // Loop on (black icon on cyan background)
                            ~sfp.loop = true;
                        });
                    });
                })
                .value_(0);



            // Position slider - positioned below buttons
            ~playerPositionSlider = Slider(~playerOverlay, Rect(20, 235, 280, 20))
                .background_(Color.black)
                .knobColor_(Color.cyan)
                .value_(0)
                .action_({ |slider|
                    if(~sfp.notNil and: { ~sfp.sf.notNil and: { ~sfp.sf.duration > 0 } }, {
                        var seekTime = slider.value * ~sfp.sf.duration;
                        var wasPlaying = ~sfp.isPlaying;
                        // Set the start time to seek to position (like SFPlayer waveform click)
                        ~sfp.startTime = seekTime;
                        // Update our timer to match the seek position
                        ~playStartTime = SystemClock.seconds - seekTime;
                        ~pausedTime = 0;
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
            
        } {
            if(~playerOverlay.notNil) { ~playerOverlay.remove; ~playerOverlay = nil; };
        }
    });

~layoutBtn = Button(mainView, Rect(508, 410, 100, 35))
    .states_([["LAYOUT", Color.cyan, Color.black], ["LAYOUT", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
    .action_({ |btn|
        var currentDecoder, decoderNames, decoderName;
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
            if(~maplinOverlay.notNil) { 
                ~saveMaplinState.value(); // Save state before removing maplin overlay
                ~maplinOverlay.remove; ~maplinOverlay = nil; ~maplinBtn.value_(0); 
            };
            // Set other buttons to 0 (radio group)
            ~eqBtn.value_(0);
            ~ambienceBtn.value_(0);
            ~maplinBtn.value_(0);
            ~layoutOverlay = View(mainView, Rect(180, 107, 320, 275))
                .background_(Color.black); // Remove .alpha_(0.5) for full opacity
            // Add the title as StaticText at the top, centered
            StaticText(~layoutOverlay, Rect(10, 5, 300, 22))
                .string_("LAYOUT - " ++ (["STEREO", "BINAURAL IRCAM", "BINAURAL CIPIC", "QUAD SQUARE", "QUAD NARROW", "QUAD WIDE", "DOLBY 5.1", "OCTAGON"][~dmenu.value ? 0]))
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);
            UserView(~layoutOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |view|
                    var bounds = view.bounds;
                    var centerX = bounds.width / 2;
                    var centerY = bounds.height / 2;
                    var currentDecoderValue = ~dmenu.value;
                    // Draw cyan border
                    Pen.width = 0.5;
                    Pen.color = Color.white;
                    Pen.addRect(Rect(0.25, 0.25, bounds.width - 0.5, bounds.height - 0.5));
                    Pen.stroke;
                    Pen.width = 2;
                    switch(currentDecoderValue,
                        0, { // Stereo
                            var speakerWidth = 20, speakerHeight = 20, speakerSpacing = 120, leftSpeakerX, rightSpeakerX, speakerY;
                            var centerY_bottom = centerY + 80; // Center point further down at bottom of triangle
                            var leftRotationAngle, rightRotationAngle;
                            leftSpeakerX = centerX - (speakerSpacing / 2) - (speakerWidth / 2);
                            rightSpeakerX = centerX + (speakerSpacing / 2) - (speakerWidth / 2);
                            speakerY = centerY - 40; // Speakers at top of triangle
                            
                            // Calculate rotation angles
                            leftRotationAngle = atan2(centerY_bottom - speakerY, centerX - leftSpeakerX) + (pi / 2);
                            rightRotationAngle = atan2(centerY_bottom - speakerY, centerX - rightSpeakerX) + (pi / 2);
                            
                            // Draw triangle linestesting on 
                            Pen.color = Color.cyan; Pen.width = 1;
                            // Left diagonal from center to left speaker
                            Pen.line(Point(centerX, centerY_bottom), Point(leftSpeakerX + (speakerWidth / 2), speakerY + (speakerHeight / 2)));
                            Pen.stroke;
                            // Right diagonal from center to right speaker
                            Pen.line(Point(centerX, centerY_bottom), Point(rightSpeakerX + (speakerWidth / 2), speakerY + (speakerHeight / 2)));
                            Pen.stroke;
                            
                            // Speaker 1: Left (rotated to face center + 180° for upright text)
                            Pen.push;
                            Pen.translate(leftSpeakerX + (speakerWidth / 2), speakerY + (speakerHeight / 2));
                            Pen.rotate(leftRotationAngle + pi);
                            Pen.translate(-10, -10);
                            Pen.color = Color.black; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(7, 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.pop;
                            
                            // Speaker 2: Right (rotated to face center + 180° for upright text)
                            Pen.push;
                            Pen.translate(rightSpeakerX + (speakerWidth / 2), speakerY + (speakerHeight / 2));
                            Pen.rotate(rightRotationAngle + pi);
                            Pen.translate(-10, -10);
                            Pen.color = Color.black; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, speakerWidth, speakerHeight)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(7, 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.pop;
                            
                            Pen.stringAtPoint("[1] L (-30°) & [2] R (+30°)", Point(centerX - 75, 32), Font("Helvetica", 13), Color.cyan);
                            Pen.stringAtPoint("Optimum listening angles", Point(centerX - 70, 50), Font("Helvetica", 12, italic: true), Color.cyan);
                        },
                        1, { // IRCAM Binaural
                            var earCupWidth = 20, earCupHeight = 27, earCupOffset = 55, arcCenterY = centerY - 25 + 25, arcRadius = 47, leftEarX, leftEarY, rightEarX, rightEarY;
                            leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                            leftEarY = centerY + 25 + 25;
                            rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                            rightEarY = centerY + 25 + 25;
                            Pen.color = Color.cyan; Pen.width = 2;
                            Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi); Pen.stroke;
                            Pen.moveTo(Point(centerX - arcRadius, centerY - 30 + 25)); Pen.lineTo(Point(centerX - arcRadius, leftEarY)); Pen.stroke;
                            Pen.moveTo(Point(centerX + arcRadius, centerY - 30 + 25)); Pen.lineTo(Point(centerX + arcRadius, rightEarY)); Pen.stroke;
                            Pen.color = Color.black; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(leftEarX + 6, leftEarY + 5), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rightEarX + 6, rightEarY + 5), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Do NOT move the description text
                            Pen.stringAtPoint("Headphone Listening using IRCAM HTRF Library", Point(centerX - 140, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        2, { // CIPIC Binaural
                            var earCupWidth = 20, earCupHeight = 27, earCupOffset = 55, arcCenterY = centerY - 25 + 25, arcRadius = 47, leftEarX, leftEarY, rightEarX, rightEarY;
                            leftEarX = centerX - earCupOffset - (earCupWidth / 2);
                            leftEarY = centerY + 25 + 25;
                            rightEarX = centerX + earCupOffset - (earCupWidth / 2);
                            rightEarY = centerY + 25 + 25;
                            Pen.color = Color.cyan; Pen.width = 2;
                            Pen.addArc(Point(centerX, arcCenterY), arcRadius, pi, pi); Pen.stroke;
                            Pen.moveTo(Point(centerX - arcRadius, centerY - 25 + 25)); Pen.lineTo(Point(centerX - arcRadius, leftEarY)); Pen.stroke;
                            Pen.moveTo(Point(centerX + arcRadius, centerY - 25 + 25)); Pen.lineTo(Point(centerX + arcRadius, rightEarY)); Pen.stroke;
                            Pen.color = Color.black; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(leftEarX, leftEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(leftEarX + 6, leftEarY + 5), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.color = Color.black; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.fill;
                            Pen.color = Color.cyan; Pen.width = 2; Pen.addRect(Rect(rightEarX, rightEarY, earCupWidth, earCupHeight)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rightEarX + 6, rightEarY + 5), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("Headphone Listening using CIPIC HTRF Library", Point(centerX - 138, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        3, { // Quad Square
                            var squareSize = 140, halfSquare = squareSize / 2;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare, centerY - halfSquare + 25, squareSize, squareSize)); Pen.stroke;
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + 25, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + 25, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(centerX - halfSquare - 3, centerY - halfSquare - 9 + 25), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + 25, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + 25, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(centerX - halfSquare - 3 + squareSize, centerY - halfSquare - 9 + 25), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 3: Rear Left
                            Pen.color = Color.black; Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + squareSize + 25, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare - 10, centerY - halfSquare - 10 + squareSize + 25, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(centerX - halfSquare - 3, centerY - halfSquare - 10 + squareSize + 1 + 25), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 4: Rear Right
                            Pen.color = Color.black; Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + squareSize + 25, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX - halfSquare - 10 + squareSize, centerY - halfSquare - 10 + squareSize + 25, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(centerX - halfSquare - 3 + squareSize, centerY - halfSquare - 10 + squareSize + 1 + 25), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("[1] FL, [2] FR, [3] RL, [4] RR", Point(centerX - 82, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        4, { // Quad Narrow
                            var rectHeight = 140, rectWidth = (rectHeight * 0.75).asInteger, rectLeft = centerX - (rectWidth / 2), rectTop = centerY - (rectHeight / 2) + 25;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight)); Pen.stroke;
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(rectLeft - 3, rectTop - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rectLeft + rectWidth - 3, rectTop - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 3: Rear Left
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(rectLeft - 3, rectTop + rectHeight - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 4: Rear Right
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(rectLeft + rectWidth - 3, rectTop + rectHeight - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("[1] FL, [2] FR, [3] RL, [4] RR", Point(centerX - 82, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        5, { // Quad Wide
                            var rectWidth = 140, rectHeight = 105, rectLeft = centerX - (rectWidth / 2), totalHeight = rectHeight + 20, rectTop = centerY - (totalHeight / 2) + 10 + 25;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft, rectTop, rectWidth, rectHeight)); Pen.stroke;
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(rectLeft - 3, rectTop - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(rectLeft + rectWidth - 3, rectTop - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 3: Rear Left
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(rectLeft - 3, rectTop + rectHeight - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 4: Rear Right
                            Pen.color = Color.black; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(rectLeft + rectWidth - 10, rectTop + rectHeight - 10, 20, 20)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(rectLeft + rectWidth - 3, rectTop + rectHeight - 9), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("[1] FL, [2] FR, [3] RL, [4] RR", Point(centerX - 82, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        6, { // Dolby 5.1
                            var layoutSize = 140, layoutLeft = centerX - (layoutSize / 2), layoutTop = centerY - (layoutSize / 2) + 25, speakerSize = 20, frontLeftX = layoutLeft - 10, frontLeftY = layoutTop - 10, frontRightX = layoutLeft + layoutSize - 10, frontRightY = layoutTop - 10, centerX_speaker = layoutLeft + (layoutSize / 2) - 10, centerY_speaker = layoutTop - 10, surroundLeftX = layoutLeft - 10, surroundLeftY = layoutTop + layoutSize - 10, surroundRightX = layoutLeft + layoutSize - 10, surroundRightY = layoutTop + layoutSize - 10, subwooferX = layoutLeft + (layoutSize / 2) - 10, subwooferY = layoutTop + (layoutSize / 2) - 10;
                            Pen.color = Color.cyan; Pen.addRect(Rect(layoutLeft, layoutTop, layoutSize, layoutSize)); Pen.stroke;
                            // Speaker 1: Front Left
                            Pen.color = Color.black; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontLeftX, frontLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("1", Point(frontLeftX + 7, frontLeftY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 2: Front Right
                            Pen.color = Color.black; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(frontRightX, frontRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("2", Point(frontRightX + 7, frontRightY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 3: Center
                            Pen.color = Color.black; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(centerX_speaker, centerY_speaker, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("3", Point(centerX_speaker + 7, centerY_speaker + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 4: Surround Left
                            Pen.color = Color.black; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundLeftX, surroundLeftY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("4", Point(surroundLeftX + 7, surroundLeftY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 5: Surround Right
                            Pen.color = Color.black; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.fill;
                            Pen.color = Color.cyan; Pen.addRect(Rect(surroundRightX, surroundRightY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("5", Point(surroundRightX + 7, surroundRightY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            // Speaker 6: Subwoofer (Sub = 6)
                            Pen.color = Color.cyan; Pen.addRect(Rect(subwooferX, subwooferY, speakerSize, speakerSize)); Pen.stroke;
                            Pen.stringAtPoint("6", Point(subwooferX + 7, subwooferY + 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                            Pen.stringAtPoint("SUB", Point(subwooferX + 25, subwooferY + 3), Font("Helvetica", 10).boldVariant, Color.cyan);
                            Pen.stringAtPoint("[1] FL, [2] FR, [3] C, [4] RL, [5] RR, [6] Sub", Point(centerX - 124, 32), Font("Helvetica", 13), Color.cyan);
                        },
                        7, { // Octagon
                            var radius = 80, angleStep = 2 * pi / 8, startAngle = -22.5 * pi / 180, speakerPositions;
                            speakerPositions = Array.fill(8, { |i|
                                var angle = startAngle + (i * angleStep);
                                var x = centerX + (radius * cos(angle)) - 10;
                                var y = centerY + (radius * sin(angle)) - 10 + 25;
                                Point(x, y);
                            });
                            Pen.color = Color.cyan; Pen.addOval(Rect(centerX - radius, centerY - radius + 25, radius * 2, radius * 2)); Pen.stroke;
                            speakerPositions.do({ |pos, i|
                                var speakerNum = ((i + 2) % 8) + 1; // Shift so speaker 1 is at front-left position (consumer standard)
                                var angle = startAngle + (i * angleStep);
                                var rotationAngle = angle + (pi / 2);
                                Pen.push;
                                Pen.translate(pos.x + 10, pos.y + 10);
                                Pen.rotate(rotationAngle);
                                Pen.translate(-10, -10);
                                Pen.color = Color.black; Pen.addRect(Rect(0, 0, 20, 20)); Pen.fill;
                                Pen.color = Color.cyan; Pen.addRect(Rect(0, 0, 20, 20)); Pen.stroke;
                                Pen.stringAtPoint(speakerNum.asString, Point(7, 1), Font("Helvetica", 13).boldVariant, Color.cyan);
                                Pen.pop;
                            });
                            Pen.stringAtPoint("[1] FL (-22.5°), Clockwise @ 45°", Point(centerX - 84, 32), Font("Helvetica", 13), Color.cyan);
                        }
                    );
                });
            ~layoutOverlay.front;
        } {
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; };
        }
    });

// --- MAPLIN SM-333 OVERLAY BUTTON ---
~maplinBtn = Button(mainView, Rect(290, 410, 100, 35))
    .states_([["SM-333", Color.cyan, Color.black], ["SM-333", Color.black, Color.cyan]])
    .font_(Font("Helvetica", 13))
    .action_({ |btn|
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
            if(~layoutOverlay.notNil) { ~layoutOverlay.remove; ~layoutOverlay = nil; ~layoutBtn.value_(0); };
            // Set other buttons to 0 (radio group)
            ~eqBtn.value_(0);
            ~ambienceBtn.value_(0);
            ~layoutBtn.value_(0);

            // Create Maplin overlay
            ~maplinOverlay = View(mainView, Rect(180, 107, 320, 275)).background_(Color.black);

            // Border
            UserView(~maplinOverlay, Rect(0, 0, 320, 275))
                .background_(Color.clear)
                .drawFunc_({ |v|
                    Pen.width = 0.5;
                    Pen.color = Color.white;
                    Pen.addRect(Rect(0.25, 0.25, v.bounds.width - 0.5, v.bounds.height - 0.5));
                    Pen.stroke;
                });

            // Title
            StaticText(~maplinOverlay, Rect(10, 5, 200, 22))
                .string_("MAPLIN SM-333")
                .align_(\left)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);

            // Labels above knobs
            StaticText(~maplinOverlay, Rect(18, 80, 80, 20))
                .string_("SURROUND")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);
            
            StaticText(~maplinOverlay, Rect(120, 80, 80, 20))
                .string_("EFFECT")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);
            
            StaticText(~maplinOverlay, Rect(222, 80, 80, 20))
                .string_("DELAY")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13).boldVariant)
                .background_(Color.clear);
            
            // Three control knobs
            ~maplinSurroundKnob = Knob(~maplinOverlay, Rect(18, 110, 80, 80))
                .value_(~maplinState[\surround] ? 0.8)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    ~setMaplinSurround.(knob.value);
                    ~maplinSurroundValue.string_((knob.value * 100).round(1).asString ++ "%");
                });
            
            ~maplinEffectKnob = Knob(~maplinOverlay, Rect(120, 110, 80, 80))
                .value_(~maplinState[\effect] ? 0.8)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    ~setMaplinEffect.(knob.value);
                    ~maplinEffectValue.string_((knob.value * 100).round(1).asString ++ "%");
                });
            
            ~maplinDelayKnob = Knob(~maplinOverlay, Rect(222, 110, 80, 80))
                .value_(~maplinState[\delay] ? 0.4)
                .color_([Color.cyan(1, 0.1), Color.cyan(0.5), Color.cyan, Color.cyan])
                .action_({ |knob| 
                    ~setMaplinDelay.(knob.value);
                    ~maplinDelayValue.string_((knob.value.linlin(0, 1, 5, 50).round(1).asString ++ " ms"));
                });
            
            // Value displays below knobs
            ~maplinSurroundValue = StaticText(~maplinOverlay, Rect(18, 200, 80, 18))
                .string_("80%")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13))
                .background_(Color.clear);
            
            ~maplinEffectValue = StaticText(~maplinOverlay, Rect(120, 200, 80, 18))
                .string_("80%")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13))
                .background_(Color.clear);
            
            ~maplinDelayValue = StaticText(~maplinOverlay, Rect(222, 200, 80, 18))
                .string_("25 ms")
                .align_(\center)
                .stringColor_(Color.cyan)
                .font_(Font("Helvetica", 13))
                .background_(Color.clear);

            // On/Off button
            ~maplinActiveBtn = Button(~maplinOverlay, Rect(18, 40, 80, 28))
                .states_([
                    ["ON", Color.black, Color.cyan],
                    ["OFF", Color.cyan, Color.black]
                ])
                .action_({ |button|
                    ~setMaplinActive.(button.value == 0);
                })
                .font_(Font("Helvetica", 11))
                .value_(1); // Default to OFF (button state 1 = OFF)

            // Preset buttons
            Button(~maplinOverlay, Rect(120, 40, 80, 28))
                .states_([["BALANCED", Color.cyan, Color.black]])
                .action_({
                    ~maplinPresetBalanced.();
                    ~maplinSurroundKnob.value_(0.8);
                    ~maplinEffectKnob.value_(0.8);
                    ~maplinDelayKnob.value_(0.4);
                    ~maplinSurroundValue.string_("80%");
                    ~maplinEffectValue.string_("80%");
                    ~maplinDelayValue.string_("25 ms");
                })
                .font_(Font("Helvetica", 11))
                .background_(Color.black);

            Button(~maplinOverlay, Rect(222, 40, 80, 28))
                .states_([["MAXIMUM", Color.cyan, Color.black]])
                .action_({
                    ~maplinPresetMax.();
                    ~maplinSurroundKnob.value_(1.0);
                    ~maplinEffectKnob.value_(1.0);
                    ~maplinDelayKnob.value_(1.0);
                    ~maplinSurroundValue.string_("100%");
                    ~maplinEffectValue.string_("100%");
                    ~maplinDelayValue.string_("50 ms");
                })
                .font_(Font("Helvetica", 11))
                .background_(Color.black);

            // Close button
            Button(~maplinOverlay, Rect(222, 230, 80, 28))
                .states_([["CLOSE", Color.cyan, Color.black]])
                .font_(Font("Helvetica", 11))
                .action_({
                    ~saveMaplinState.value(); // Save state before closing
                    ~maplinOverlay.remove;
                    ~maplinOverlay = nil;
                    ~maplinBtn.value_(0);
                });

            ~maplinOverlay.front;
            ~maplinBtn.value_(1);
            
            // Restore saved state after overlay is created
            ~restoreMaplinState.value();

        } {
            if(~maplinOverlay.notNil) {
                ~maplinOverlay.remove;
                ~maplinOverlay = nil;
            };
        }
    });

// Set initial SM-333 button state based on current encoder
if(configKeyE != \maplin) {
    // Add overlay to dim button if not in maplin mode
    ~maplinBtnOverlay = View(mainView, Rect(290, 410, 100, 35))
        .background_(Color.black.alpha_(0.7))
        .alpha_(1.0)
        .front;
};

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
// --- Headtracker HID Integration (added as per MainApp2 model, always active) ---
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

// Map HID usages to GUI knobs (always active, no gating)
HIDdef.usage( \hidRotation, { |val|
    {
        //("Headtracker raw rotation: " ++ val).postln;  // <-- Add this line
        if(~rotateKnob.notNil and: { ~rotateKnob.enabled }) {
            ~rotateKnob.valueAction_(
                1 - val.linlin(0.060606062412262, 0.94037145376205, 0, 1)
            );
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
