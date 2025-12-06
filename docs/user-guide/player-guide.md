# UHJ-Pi Player User Guide

This guide covers the file playback version of UHJ-Pi, which allows you to play UHJ-encoded audio files from USB drives or the ATK library.

## Table of Contents

1. [Installation](#installation)
   - [Touchscreen Version](#touchscreen-version)
   - [HDMI Version](#hdmi-version)
   - [Screen Rotation (Optional)](#screen-rotation-optional)
2. [Getting Started](#getting-started)
   - [First Launch](#first-launch)
   - [Preparing Audio Files](#preparing-audio-files)
   - [USB Drive Setup](#usb-drive-setup)
3. [File Browser](#file-browser)
   - [Source Selection](#source-selection)
   - [Artist/Album Navigation](#artistalbum-navigation)
   - [Track Selection](#track-selection)
4. [Playback Controls](#playback-controls)
   - [Play/Pause/Stop](#playpausestop)
   - [Track Navigation](#track-navigation)
   - [Artwork Display](#artwork-display)
5. [Main Interface](#main-interface)
6. [Layouts & Decoders](#layouts--decoders)
7. [Controls](#controls)
8. [Advanced Features](#advanced-features)
9. [Troubleshooting](#troubleshooting)

---

## Installation

### Touchscreen Version

The player version is designed for touchscreen operation on a Raspberry Pi.

**Requirements:**
- Raspberry Pi (recommended: Pi 4 or later)
- Touchscreen display
- USB audio interface for output
- USB drive for audio files (optional - can use ATK library)
- MicroSD card (32GB minimum recommended)

**Installation Steps:**

1. **Prepare Raspberry Pi OS**
   - Download and flash Raspberry Pi OS (minimal, 64-bit recommended) to your microSD card
   - Boot the Pi and complete initial setup

2. **Clone the Repository**
   ```bash
   cd ~
   git clone https://github.com/mikeuwins/UHJ-Pi.git
   cd UHJ-Pi
   ```

3. **Run the Installer**
   - For **normal orientation**:
     ```bash
     sudo bash install-pla-touch.sh
     ```
   - For **180° rotated/flipped** screen:
     ```bash
     sudo bash install-pla-touch-180.sh
     ```

4. **Wait for Installation**
   - The installer will:
     - Update the system
     - Install dependencies (SuperCollider, JACK, ATK, FLAC tools, etc.)
     - Build SuperCollider from source
     - Install SFPlayer quark for file playback
     - Configure audio settings
     - Set up auto-boot
   - This process takes approximately 30-60 minutes

5. **Reboot**
   - The installer will prompt you to reboot
   - After reboot, log in and run: `start-player`

**What Gets Installed:**
- SuperCollider with Qt GUI support
- JACK audio server
- ATK (Ambisonic Toolkit) + AmbiVerbSC extensions
- SFPlayer quark (for audio file playback)
- FLAC tools (`metaflac` for metadata and artwork extraction)
- UHJ-Pi player application

**Player-Specific Features:**
- File browser with artist/album/track navigation
- Support for multiple audio formats (FLAC, WAV, MP3, AIF, OGG, M4A)
- FLAC metadata extraction (track info, artwork)
- USB drive support for external audio libraries
- ATK library integration
- Playback controls (play, pause, stop, skip)

---

### HDMI Version

*Note: HDMI version installer may not be available yet. Check repository for `install-pla-hdmi.sh`*

The HDMI version works with a standard monitor and mouse instead of a touchscreen.

**Installation Steps:**

1. **Prepare Raspberry Pi OS**
   - Same as touchscreen version

2. **Clone the Repository**
   ```bash
   cd ~
   git clone https://github.com/mikeuwins/UHJ-Pi.git
   cd UHJ-Pi
   ```

3. **Run the HDMI Installer**
   ```bash
   sudo bash install-pla-hdmi.sh
   ```

4. **Wait for Installation**
   - Same process as touchscreen version
   - Takes approximately 30-60 minutes

5. **Reboot and Launch**
   - After reboot, log in and run: `start-player`

**HDMI-Specific Notes:**
- Uses X11 windowing system instead of EGLFS
- Mouse control instead of touch
- Otherwise identical functionality to touchscreen version

---

### Screen Rotation (Optional)

If your case has the screen mounted in a different orientation than the installer configured, you can use the screen rotation utility to adjust the display without reinstalling.

**When to Use:**
- Your case has the screen flipped 180° from the installer's default
- You want to change screen orientation after installation
- Touch calibration is correct but display is wrong

**How to Use:**

1. **Run the Rotation Script**
   ```bash
   cd ~/UHJ-Pi
   bash scripts/set-screen-rotation.sh [0|180]
   ```
   - `0` = normal orientation
   - `180` = flipped upside-down
   - If no argument provided, defaults to 180°

2. **Reboot or Log Out/In**
   - Changes take effect after reboot or logout/login
   - Touch calibration is not affected (handled separately during install)

**Note:** This only affects the display rotation. Touch input calibration is configured during installation and requires the appropriate `-180` installer variant or manual touch calibration setup.

---

## Getting Started

### First Launch

After installation and reboot:

1. **Log In**
   - Log in to your Raspberry Pi (via SSH, local terminal, or directly)

2. **Launch the Player**
   ```bash
   start-player
   ```
   - The application will start and display the main interface
   - File browser will be empty until you select a source

3. **Connect Audio Output**
   - Ensure your USB audio interface is connected
   - Verify speakers/headphones are connected
   - Audio will route through JACK automatically

### Preparing Audio Files

The player supports UHJ-encoded audio files in various formats:

**Supported Formats:**
- **FLAC** (recommended - supports metadata and embedded artwork)
- **WAV** (uncompressed)
- **MP3** (compressed)
- **AIF/AIFF** (Apple format)
- **OGG** (Ogg Vorbis)
- **M4A** (AAC/MP4)

**File Organisation:**

The player expects files organised in a specific structure:

```
[Source Root]/
├── Artist Name/
│   ├── Album Name/
│   │   ├── Track 01.flac
│   │   ├── Track 02.flac
│   │   ├── artwork.jpg (optional)
│   │   └── ...
│   └── Another Album/
│       └── ...
└── Another Artist/
    └── ...
```

**For USB Drives:**
- Root of USB drive or in a `UHJ` folder
- Artist folders contain album folders
- Album folders contain track files

**For ATK Library:**
- Located at `~/.local/share/ATK/sounds/uhj/`
- Same folder structure as USB
- Can include a "Various" folder for compilation albums

**FLAC Metadata (Recommended):**

For best experience, use FLAC files with embedded metadata:
- **Artist**: Track artist
- **Album**: Album name
- **Title**: Track title
- **Track Number**: Track position in album
- **Artwork**: Embedded cover art (extracted automatically)

The player will extract this information and display it during playback.

### USB Drive Setup

To use a USB drive as your audio source:

1. **Format USB Drive**
   - Format as FAT32 or ext4 (FAT32 recommended for compatibility)
   - Label the drive (optional, but helpful)

2. **Organise Files**
   - Create the folder structure: `Artist/Album/Tracks`
   - Copy your UHJ-encoded audio files
   - Add artwork files (optional): `artwork.jpg`, `cover.jpg`, or `folder.jpg` in album folders

3. **Insert USB Drive**
   - Insert USB drive into Raspberry Pi
   - Wait for it to mount (usually automatic)

4. **Select USB Source**
   - In the player interface, toggle the source button to "USB"
   - The file browser will refresh and show USB contents

**USB Drive Location:**
- USB drives typically mount at `/media/[username]/[drive-label]`
- The player looks for files in the root or `UHJ` subfolder
- Check mount point: `lsblk` or `df -h`

---

## File Browser

The file browser allows you to navigate your audio library and select tracks for playback.

### Source Selection

The player supports two audio sources:

**ATK Library:**
- Built-in library location: `~/.local/share/ATK/sounds/uhj/`
- Pre-installed with ATK sounds
- Accessible without external drives

**USB Drive:**
- External USB drive for your own audio files
- Toggle between ATK and USB using the source button
- Automatically detects mounted USB drives

**Source Toggle Button:**
- Located in the file browser area
- Toggles between "ATK" and "USB"
- File browser refreshes when source changes

### Artist/Album Navigation

The file browser uses a hierarchical menu system:

1. **Artist Menu**
   - Dropdown menu showing all artists in the current source
   - Select an artist to view their albums
   - Menu updates when source changes

2. **Album Menu**
   - Dropdown menu showing albums for the selected artist
   - Select an album to view tracks
   - Updates automatically when artist selection changes

3. **Track List**
   - Scrollable list of tracks in the selected album
   - Tracks sorted by track number (if FLAC metadata available) or filename
   - Click a track to select it for playback

**Navigation Tips:**
- Use ▲ and ▼ buttons to scroll through track list
- Track list scrolls automatically when navigating
- Selected track is highlighted

### Track Selection

**Selecting a Track:**
- Click on a track in the track list
- Track is highlighted when selected
- Track information displays in the info area

**Track Information:**
- **Track Name**: From filename or FLAC metadata
- **Artist**: From FLAC metadata or folder structure
- **Album**: From FLAC metadata or folder structure
- **Track Number**: From FLAC metadata (if available)

**Playback:**
- Selected track loads into the player
- Press Play button to start playback
- Track information and artwork update during playback

---

## Playback Controls

The player includes standard playback controls for navigating your audio library.

### Play/Pause/Stop

**Play Button:**
- Starts playback of the selected track
- Button changes to "Pause" during playback
- Playback starts from the beginning of the track

**Pause Button:**
- Pauses playback (same button as Play)
- Button changes to "Play" when paused
- Resume by pressing Play again

**Stop Button:**
- Stops playback completely
- Resets to beginning of track
- Button remains as "Stop" when not playing

**Playback State:**
- Visual feedback shows current playback state
- Track information updates during playback
- Artwork displays if available

### Track Navigation

**Previous Track (◄◄):**
- Jumps to previous track in the current album
- Wraps to end of album if at first track
- Stops playback if pressed during play

**Next Track (►►):**
- Jumps to next track in the current album
- Wraps to beginning of album if at last track
- Continues playback if pressed during play

**Track List Navigation:**
- Use ▲ and ▼ buttons to move through track list
- Clicking a track in the list selects it
- Selected track can be played immediately

**Auto-Advance:**
- When a track finishes, playback stops
- Next track can be selected manually
- (Auto-play next track may be available in future versions)

### Artwork Display

The player automatically displays album artwork when available.

**Artwork Sources (Priority Order):**
1. **Embedded FLAC Artwork**: Extracted from FLAC file metadata
2. **Album Folder Artwork**: `artwork.jpg`, `cover.jpg`, or `folder.jpg` in album folder
3. **First Image in Folder**: Any PNG/JPG file in the album folder
4. **Default/None**: No artwork displayed if none found

**Artwork Display:**
- Artwork appears in the designated area of the interface
- Updates when track/album changes
- Scaled to fit display area
- Maintains aspect ratio

**FLAC Artwork Extraction:**
- Uses `metaflac` tool to extract embedded artwork
- Extracted artwork cached temporarily
- Works with standard FLAC cover art embedding

**Supported Artwork Formats:**
- **JPEG**: `.jpg`, `.jpeg`
- **PNG**: `.png`
- Embedded in FLAC files

---

## Main Interface

The main interface consists of several sections:

### File Browser Section
- **Source Toggle**: Switch between ATK library and USB drive
- **Artist Menu**: Select artist from library
- **Album Menu**: Select album from artist
- **Track List**: Scrollable list of tracks in album
- **Navigation Buttons**: ▲ and ▼ to scroll track list

### Playback Section
- **Play/Pause Button**: Control playback
- **Stop Button**: Stop playback
- **Previous/Next Buttons**: Navigate tracks
- **Track Information**: Current track details
- **Artwork Display**: Album cover art

### Top Section
- **Encoder Selection**: Choose input encoding (UHJ, Super Stereo, PHJ, Maplin)
- **Decoder Selection**: Choose output format (Stereo, Binaural, Quad, 5.1, 5.1.2, Octagon)
- **Headtracker Controls**: Pair button and reset controls (if headtracker supported)

### Center Section
- **Rotation/Tilt/Tumble Knobs**: Control soundfield orientation
- **Layout Diagram**: Visual representation of speaker layout

### Bottom Section
- **Overlay Buttons**: Access EQ, Ambience, Layout, Dimension controls
- **Power Button**: Shutdown the system

### Overlays
- **EQ Overlay**: 7-band parametric equaliser
- **Ambience Overlay**: Reverb and spatial effects
- **Layout Overlay**: Speaker layout visualisation and controls
- **Dimension Overlay**: Width and spatial processing controls

---

## Layouts & Decoders

The player supports the same output formats as the live input version:

### Stereo
- Standard 2-channel stereo output
- Uses standard stereo decoder

### Binaural
- **IRCAM**: IRCAM Listen binaural decoder
- **CIPIC**: CIPIC binaural decoder
- For headphone listening

### Quad
- **Square**: 45° speaker placement (square layout)
- **Narrow**: 30° speaker placement (narrow layout)
- **Wide**: 60° speaker placement (wide layout)
- 4-channel output

### Dolby 5.1
- Standard 5.1 surround sound
- 6-channel output (FL, FR, C, LFE, RL, RR)
- Individual speaker on/off controls
- Center and sub gain controls

### Dolby 5.1.2
- 5.1 with height speakers
- 8-channel output (FL, FR, C, LFE, RL, RR, TFL, TFR)
- Height speaker controls
- Z-synthesis for height channel generation

### Octagon
- 8-channel surround sound
- 45° speaker spacing
- Flat or elevated configurations

---

## Controls

### Rotation Controls

Three knobs control the soundfield orientation:

- **Rotation**: Rotate soundfield left/right (Z-axis)
- **Tilt**: Tilt soundfield up/down (Y-axis)
- **Tumble**: Tumble soundfield forward/back (X-axis)

**Control Methods:**
- **Mouse/Touch**: Click and drag knobs
- **Headtracker**: Automatic control when paired and active (if supported)
- **Knob Overlay**: Shows/hides knobs (for headtracker-only mode)

### Overlay Controls

#### EQ Overlay
- **7-Band Parametric EQ**: Adjust frequency response
- **Preset Menu**: Load EQ presets
- **Individual Band Sliders**: Control each frequency band

#### Ambience Overlay
- **Reverb Mix Slider**: Control reverb amount
- **Reverb Button**: Enable/disable reverb
- **Pre-Delay Slider**: Reverb pre-delay
- **Low RT Slider**: Low frequency reverb time
- **High RT Slider**: High frequency reverb time
- **Dispersion Slider**: Reverb dispersion
- **Modulation Controls**: Width and rate

#### Layout Overlay
- **Speaker Layout Diagram**: Visual representation
- **Speaker On/Off Buttons**: Individual speaker control
- **Gain Controls**: Center, sub, height gain adjustments
- **Layout-Specific Controls**: Vary by selected decoder

#### Dimension Overlay
- **Width Slider**: Spatial width control
- **Width HPF**: High-pass filter for width
- **Output Trim**: Overall output level
- **Preset Menu**: Dimension presets
- **Active Button**: Enable/disable dimension processing

---

## Advanced Features

### Z-Synthesis

The 5.1.2 decoder includes Z-synthesis for generating height information from 2D (W/X/Y) ambisonic signals:

- **Height Amount**: Amount of height synthesis
- **Height Delay**: Delay for height channel
- **Height Trim**: Gain adjustment for height
- **Height Source**: Source selection for height synthesis
- **Ambience Controls**: Size, dampening, mix for height ambience

### Maplin Encoder

Available in the player version, the Maplin encoder provides quad matrix encoding:

- **Surround Level**: Surround channel level
- **Effect Level**: Effect channel level
- **Delay Amount**: Delay processing
- **Active Button**: Enable/disable Maplin processing

### FLAC Metadata Support

The player fully supports FLAC metadata:

- **Track Information**: Artist, album, title, track number
- **Artwork Extraction**: Embedded cover art
- **Automatic Sorting**: Tracks sorted by track number when available
- **Metadata Display**: Shows track information during playback

### State Preservation

The application remembers:

- **EQ Settings**: Presets and band values
- **Ambience Settings**: Reverb and effect parameters
- **Layout Settings**: Speaker on/off states and gains
- **Dimension Settings**: Width and processing parameters
- **Z-Synthesis Settings**: Height processing parameters
- **Source Selection**: Last selected source (ATK/USB)
- **Artist/Album Selection**: Last browsed location

---

## Troubleshooting

### File Playback Issues

**No Files Showing:**
- Check source selection (ATK vs USB)
- Verify USB drive is mounted: `lsblk` or `df -h`
- Check folder structure matches expected format
- Verify files are in supported formats
- Check file permissions: `ls -la [path]`

**Files Not Playing:**
- Verify audio files are UHJ-encoded
- Check file format is supported
- Verify JACK is running: `pgrep jackd`
- Check audio output is connected
- Try a different file format (FLAC recommended)

**Artwork Not Displaying:**
- Check artwork file exists in album folder
- Verify artwork format (JPG/PNG)
- For FLAC: Verify artwork is embedded: `metaflac --list [file]`
- Check `metaflac` is installed: `which metaflac`
- Try extracting artwork manually: `metaflac --export-picture-to=artwork.jpg [file]`

**Metadata Not Showing:**
- Verify FLAC files have embedded metadata
- Check metadata: `metaflac --list [file]`
- Try re-embedding metadata if missing
- Non-FLAC files use filename/folder structure for info

### USB Drive Issues

**USB Not Detected:**
- Check USB drive is properly inserted
- Verify drive is mounted: `lsblk` or `df -h`
- Check drive format (FAT32 or ext4 recommended)
- Try different USB port
- Check USB drive power requirements

**Files Not Found on USB:**
- Verify folder structure: `Artist/Album/Tracks`
- Check files are in root or `UHJ` subfolder
- Verify file formats are supported
- Check file permissions
- Try refreshing source (toggle ATK/USB)

**USB Performance Issues:**
- Use USB 3.0 port if available
- Check USB drive speed (class 10 SD card or faster recommended)
- Avoid USB hubs if possible
- Check for USB bandwidth issues

### Application Issues

**App Won't Launch:**
- Check SuperCollider is installed: `which sclang`
- Check JACK is running: `pgrep jackd`
- Check logs: `~/.local/share/SuperCollider/SCLang_log.txt`
- Try launching manually: `sclang ~/UHJ-Pi/supercollider/app/UHJ_v28_PLAYER_SF.scd`

**GUI Not Displaying:**
- Check display is connected
- Verify Qt EGLFS rotation: `echo $QT_QPA_EGLFS_ROTATION`
- Check touch calibration (for touchscreen)
- Try HDMI version if touchscreen issues

**Playback Stuttering:**
- Check CPU usage: `top`
- Increase JACK buffer size (in start script)
- Close other applications
- Check USB drive speed
- Verify audio interface performance

**Controls Not Responding:**
- Check if overlay is covering controls
- Verify touch/mouse is working
- Try restarting application
- Check for error messages in console

### System Issues

**Pi Hangs on Exit:**
- This is a known issue with EGLFS
- Use power button for clean shutdown
- Or SSH in and reboot: `sudo reboot`

**Touch Not Working:**
- Check touch calibration: `xinput list`
- Verify LIBINPUT_CALIBRATION_MATRIX: `echo $LIBINPUT_CALIBRATION_MATRIX`
- Check udev rules: `ls -la /etc/udev/rules.d/*touch*`
- Re-run touch calibration fix script if needed

**Screen Rotation Wrong:**
- Use screen rotation utility: `bash ~/UHJ-Pi/scripts/set-screen-rotation.sh [0|180]`
- Reboot after changing
- For touch issues, reinstall with correct `-180` variant

---

## Additional Resources

- **Repository**: https://github.com/mikeuwins/UHJ-Pi
- **Developer Documentation**: See `docs/` folder in repository
- **ATK Documentation**: https://github.com/ambisonictoolkit/atk-sc3
- **FLAC Tools**: http://flac.sourceforge.net/

---

*Last Updated: 2025-01-30*

