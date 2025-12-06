# UHJ-Pi Live Input User Guide

This guide covers the live input versions of UHJ-Pi for ESI Phonorama, Generic USB Audio, Vinyl/Turntable, and Behringer audio interfaces.

## Table of Contents

1. [Installation](#installation)
   - [ESI Phonorama](#esi-phonorama)
   - [Generic USB Audio](#generic-usb-audio)
   - [Vinyl/Turntable](#vinylturntable)
   - [Behringer](#behringer)
   - [Screen Rotation (Optional)](#screen-rotation-optional)
2. [Getting Started](#getting-started)
   - [First Launch](#first-launch)
   - [Audio Setup](#audio-setup)
   - [Headtracker Pairing](#headtracker-pairing)
3. [Main Interface](#main-interface)
4. [Layouts & Decoders](#layouts--decoders)
5. [Controls](#controls)
6. [Advanced Features](#advanced-features)
7. [Troubleshooting](#troubleshooting)

---

## Installation

### ESI Phonorama

The ESI Phonorama version provides hardware control for the ESI Phonorama USB audio interface, including phono pre-amp switching (Line, Moving Coil, Moving Magnet) and input monitoring.

**Requirements:**
- Raspberry Pi (recommended: Pi 4 or later)
- ESI Phonorama USB audio interface
- Touchscreen (for touch version) or HDMI monitor + mouse (for HDMI version)
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
   - For **touchscreen** (normal orientation):
     ```bash
     sudo bash install-esi-touch.sh
     ```
   - For **touchscreen** (180° rotated/flipped):
     ```bash
     sudo bash install-esi-touch-180.sh
     ```
   - For **HDMI monitor**:
     ```bash
     sudo bash install-esi-hdmi.sh
     ```

4. **Wait for Installation**
   - The installer will:
     - Update the system
     - Install dependencies (SuperCollider, JACK, ATK, etc.)
     - Build SuperCollider from source
     - Configure audio settings
     - Set up auto-boot
   - This process takes approximately 30-60 minutes

5. **Reboot**
   - The installer will prompt you to reboot
   - After reboot, log in and run: `start`

**What Gets Installed:**
- SuperCollider with Qt GUI support
- JACK audio server
- ATK (Ambisonic Toolkit) + AmbiVerbSC extensions
- ESI Phonorama control utility (`phono-control`)
- UHJ-Pi application configured for ESI Phonorama

**ESI-Specific Features:**
- Hardware phono pre-amp control (Line/MM/MC switching)
- Input gain and mute controls
- Input monitoring toggle
- Link/unlink left-right gain controls

---

### Generic USB Audio

The Generic USB Audio version works with any USB audio interface that provides separate input and output devices. It automatically detects and configures your audio hardware.

**Requirements:**
- Raspberry Pi (recommended: Pi 4 or later)
- USB audio interface with separate input and output
- Touchscreen (for touch version) or HDMI monitor + mouse (for HDMI version)
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
   - For **touchscreen** (normal orientation):
     ```bash
     sudo bash install-gen-touch.sh
     ```
   - For **touchscreen** (180° rotated/flipped):
     ```bash
     sudo bash install-gen-touch-180.sh
     ```
   - For **HDMI monitor**:
     ```bash
     sudo bash install-gen-hdmi.sh
     ```

4. **Wait for Installation**
   - Same process as ESI installation
   - Takes approximately 30-60 minutes

5. **Reboot and Launch**
   - After reboot, log in and run: `start`
   - On first launch, you'll be prompted to select your input and output audio devices

**What Gets Installed:**
- SuperCollider with Qt GUI support
- JACK audio server
- ATK (Ambisonic Toolkit) + AmbiVerbSC extensions
- UHJ-Pi application with generic USB audio support

**Generic-Specific Features:**
- Automatic audio device detection
- Software input gain control (when available)
- Input mute control (when available)
- Flexible device pairing (any input + any output)

---

### Vinyl/Turntable

The Vinyl/Turntable version is optimised for turntable input with any USB audio output. It provides software input gain control and is designed for vinyl playback scenarios.

**Requirements:**
- Raspberry Pi (recommended: Pi 4 or later)
- USB audio interface for turntable input
- USB audio interface for output (can be same or different device)
- Touchscreen (for touch version) or HDMI monitor + mouse (for HDMI version)
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
   - For **touchscreen** (normal orientation):
     ```bash
     sudo bash install-vin-touch.sh
     ```
   - For **touchscreen** (180° rotated/flipped):
     ```bash
     sudo bash install-vin-touch-180.sh
     ```
   - For **HDMI monitor**:
     ```bash
     sudo bash install-vin-hdmi.sh
     ```

4. **Wait for Installation**
   - Same process as other installations
   - Takes approximately 30-60 minutes

5. **Reboot and Launch**
   - After reboot, log in and run: `start`
   - Configure your turntable input and output devices on first launch

**What Gets Installed:**
- SuperCollider with Qt GUI support
- JACK audio server
- ATK (Ambisonic Toolkit) + AmbiVerbSC extensions
- UHJ-Pi application optimised for turntable input

**Vinyl-Specific Features:**
- Optimised for turntable input levels
- Software input gain control
- Low-latency audio processing
- Stable buffer settings for vinyl playback

---

### Behringer

The Behringer version is configured for Behringer USB audio interfaces with custom JACK routing and device-specific optimisations.

**Requirements:**
- Raspberry Pi (recommended: Pi 4 or later)
- Behringer USB audio interface
- Touchscreen (for touch version) or HDMI monitor + mouse (for HDMI version)
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
   - For **touchscreen** (normal orientation):
     ```bash
     sudo bash install-beh-touch.sh
     ```
   - For **touchscreen** (180° rotated/flipped):
     ```bash
     sudo bash install-beh-touch-180.sh
     ```
   - For **HDMI monitor**:
     ```bash
     sudo bash install-beh-hdmi.sh
     ```

4. **Wait for Installation**
   - Same process as other installations
   - Takes approximately 30-60 minutes

5. **Reboot and Launch**
   - After reboot, log in and run: `start`

**What Gets Installed:**
- SuperCollider with Qt GUI support
- JACK audio server with Behringer-specific routing
- ATK (Ambisonic Toolkit) + AmbiVerbSC extensions
- UHJ-Pi application configured for Behringer interfaces

**Behringer-Specific Features:**
- Custom JACK port routing
- Device-specific audio optimisations
- Maplin encoder support (quad matrix encoding)

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

2. **Launch the Application**
   ```bash
   start
   ```
   - For Generic/Vinyl versions, you'll be prompted to select audio devices on first launch
   - The application will start and display the main interface

3. **Check Audio**
   - Ensure your input source is connected and active
   - Verify output is connected to your speakers/headphones
   - The input level meters should show activity when audio is present

### Audio Setup

#### ESI Phonorama

The ESI version includes hardware controls in the GUI:

- **Input Source Selection:**
  - **LINE**: Line-level input
  - **MM**: Moving Magnet phono input
  - **MC**: Moving Coil phono input
  - **MUTE**: Mute input

- **Input Controls:**
  - **Left/Right Gain Sliders**: Adjust input gain for each channel
  - **LINK Button**: Link left and right gain controls together
  - **MON Button**: Enable/disable input monitoring
  - **MUTE Button**: Mute/unmute input

#### Generic USB Audio

On first launch, you'll be prompted to:

1. **Select Input Device**
   - Choose your USB audio input device from the list
   - The system will detect available gain/mute controls

2. **Select Output Device**
   - Choose your USB audio output device from the list
   - Can be the same device or a different one

3. **Configuration Saved**
   - Settings are saved to `~/.uhj-pi-config`
   - Future launches use these settings automatically
   - To reconfigure, delete the config file and relaunch

#### Vinyl/Turntable

Similar to Generic, but optimised for turntable input:

- Select your turntable's USB audio interface as input
- Select your output device
- Software gain control available if supported by your interface

#### Behringer

Behringer interfaces are automatically configured with custom JACK routing. No manual device selection required.

### Headtracker Pairing

The application supports Bluetooth headtracker pairing for spatial control.

**Pairing Process:**

1. **Press the PAIR Button**
   - Located in the headtracker control area (top-right of interface)
   - Button will show "PAIR" when no device is connected

2. **Wait for Pairing**
   - The button will show "..." while pairing
   - Pairing typically takes 5-15 seconds
   - On success, button shows "PAIR" (connected state)
   - On failure, button shows "FAIL"

3. **Automatic Connection**
   - Once paired, the headtracker should connect automatically on future launches
   - The connection monitor runs in the background

4. **Disconnect/Unpair**
   - Press PAIR button when connected to disconnect and unpair
   - Press again to re-pair

**Troubleshooting Pairing:**
- Ensure headtracker is powered on and in pairing mode
- Check Bluetooth is enabled: `bluetoothctl show`
- Try manual pairing: `/usr/local/bin/ble-ht.sh`
- Check device is visible: `bluetoothctl scan on`

---

## Main Interface

The main interface consists of several sections:

### Top Section
- **Encoder Selection**: Choose input encoding (UHJ, Super Stereo, PHJ, Maplin)
- **Decoder Selection**: Choose output format (Stereo, Binaural, Quad, 5.1, 5.1.2, Octagon)
- **Headtracker Controls**: Pair button and reset controls

### Center Section
- **Rotation/Tilt/Tumble Knobs**: Control soundfield orientation
- **Input Level Meters**: Visual feedback for input levels
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

The application supports multiple output formats:

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
- **Mouse**: Click and drag knobs
- **Headtracker**: Automatic control when paired and active
- **Knob Overlay**: Shows/hides knobs (for headtracker-only mode)

### Input Controls

#### ESI Phonorama
- **Input Source Buttons**: LINE, MM, MC, MUTE
- **Gain Sliders**: Left and right input gain
- **LINK Button**: Link/unlink gain controls
- **MON Button**: Input monitoring toggle
- **MUTE Button**: Input mute toggle

#### Generic/Vinyl
- **Input Gain Slider**: Software gain control (when available)
- **Input Mute Button**: Mute input (when available)

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

Available in some versions (Behringer, Player), the Maplin encoder provides quad matrix encoding:

- **Surround Level**: Surround channel level
- **Effect Level**: Effect channel level
- **Delay Amount**: Delay processing
- **Active Button**: Enable/disable Maplin processing

### Headtracker Drift Compensation

The headtracker includes drift compensation:

- **Exponential Smoothing**: Reduces jitter
- **Dead Zone**: Prevents drift when stationary
- **Change Threshold**: Filters micro-movements
- **Wrap-Around Detection**: Handles full rotations

### State Preservation

The application remembers:

- **EQ Settings**: Presets and band values
- **Ambience Settings**: Reverb and effect parameters
- **Layout Settings**: Speaker on/off states and gains
- **Dimension Settings**: Width and processing parameters
- **Z-Synthesis Settings**: Height processing parameters

---

## Troubleshooting

### Audio Issues

**No Input Signal:**
- Check input device is connected and selected
- Verify input levels in meters
- Check JACK connections: `jack_lsp -c`
- For ESI: Verify phono pre-amp setting (LINE/MM/MC)

**No Output:**
- Check output device is connected
- Verify speaker/headphone connections
- Check JACK connections: `jack_lsp -c`
- Verify decoder is set correctly for your output configuration

**Audio Dropouts:**
- Check CPU usage: `top`
- Increase JACK buffer size (in start script)
- Close other applications
- Check for USB bandwidth issues (try different USB port)

### Application Issues

**App Won't Launch:**
- Check SuperCollider is installed: `which sclang`
- Check JACK is running: `pgrep jackd`
- Check logs: `~/.local/share/SuperCollider/SCLang_log.txt`
- Try launching manually: `sclang ~/UHJ-Pi/supercollider/app/UHJ_v28_ESI_PAIR.scd`

**GUI Not Displaying:**
- Check display is connected
- Verify Qt EGLFS rotation: `echo $QT_QPA_EGLFS_ROTATION`
- Check touch calibration (for touchscreen)
- Try HDMI version if touchscreen issues

**Controls Not Responding:**
- Check if overlay is covering controls
- Verify headtracker isn't interfering (if paired)
- Try mouse control to verify GUI is responsive
- Check for error messages in console

### Headtracker Issues

**Pairing Fails:**
- Ensure headtracker is in pairing mode
- Check Bluetooth is enabled: `bluetoothctl show`
- Try manual pairing: `/usr/local/bin/ble-ht.sh`
- Check device is visible: `bluetoothctl scan on`
- Remove old pairing: `bluetoothctl remove [MAC]`

**Connection Drops:**
- Check headtracker battery
- Verify Bluetooth signal strength
- Check for interference
- Try re-pairing

**Headtracker Not Controlling:**
- Verify headtracker is connected (PAIR button state)
- Check knob overlay isn't hiding knobs
- Verify headtracker is sending data (check console)
- Try resetting headtracker controls

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

---

*Last Updated: 2025-01-30*

