#!/bin/bash

# UHJ-Pi Raspberry Pi Setup Script - Behringer Touch Version
# Based on install-esi-touch.sh with Behringer audio setup integrated

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Get the actual username (the user who ran sudo)
ACTUAL_USER=${SUDO_USER:-$(logname)}
if [ -z "$ACTUAL_USER" ]; then
    echo "Error: Could not determine username. Please run with: sudo -E ./install-beh-touch.sh"
    exit 1
fi

echo "UHJ-Pi Raspberry Pi Setup Script - Behringer Touch Version"
echo "Installing for user: $ACTUAL_USER"
echo "This version includes Behringer audio setup with zita bridges"

# Configure non-interactive package installation
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none
echo "initramfs-tools initramfs-tools/update_initramfs boolean false" | debconf-set-selections
echo "jackd jackd/tweak_rt_limits boolean true" | debconf-set-selections

# STEP 1: System Update
echo "Step 1: System Update..."
apt-get update
# Skip upgrade - go straight to installing what we need
# apt-get upgrade -y  # Commented out - causes hooks hang
# apt-get dist-upgrade -y  # Commented out - can cause hangs, test without first

# STEP 2: Disable Onboard and HDMI Audio
echo "Step 2: Disabling onboard and HDMI audio..."
if ! grep -q "dtparam=audio=off" /boot/firmware/config.txt; then
    echo "dtparam=audio=off" >> /boot/firmware/config.txt
fi
if ! grep -q "dtoverlay=vc4-kms-v3d,noaudio" /boot/firmware/config.txt; then
    echo "dtoverlay=vc4-kms-v3d,noaudio" >> /boot/firmware/config.txt
fi

# STEP 3: Install SuperCollider Dependencies
echo "Step 3: Installing SuperCollider Dependencies..."
apt-get install -y build-essential cmake libjack-jackd2-dev libsndfile1-dev \
    libfftw3-dev libxt-dev libavahi-client-dev libudev-dev libasound2-dev \
    libreadline-dev libxkbcommon-dev git jackd2 libhidapi-dev qt6-base-dev \
    qt6-svg-dev qt6-tools-dev qt6-wayland qt6-websockets-dev qt6-webengine-dev

# STEP 4: Clone SuperCollider
echo "Step 4: Cloning SuperCollider..."
cd /home/$ACTUAL_USER
if [ ! -d "supercollider" ]; then
    git clone --branch main --recurse-submodules https://github.com/supercollider/supercollider.git
fi
cd supercollider
mkdir -p build
cd build

# STEP 5: Configure SuperCollider Build - FIXED: SC_QT=ON for Qt support without X11
echo "Step 5: Configuring SuperCollider build..."
if cmake -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF -DSC_EL=OFF -DSC_VIM=ON \
    -DNATIVE=ON -DSC_IDE=OFF -DNO_X11=ON -DSC_QT=ON ..; then
    echo "SuperCollider configuration successful"
else
    echo "ERROR: SuperCollider configuration failed!"
    exit 1
fi

# STEP 6: Build SuperCollider
echo "Step 6: Building SuperCollider..."
if make -j2; then
    echo "SuperCollider build successful"
else
    echo "ERROR: SuperCollider build failed!"
    exit 1
fi

# STEP 7: Install SuperCollider
echo "Step 7: Installing SuperCollider..."
if make install; then
    echo "SuperCollider installation successful"
    ldconfig
else
    echo "ERROR: SuperCollider installation failed!"
    exit 1
fi

# STEP 8: Set up udev rules for HID and audio permissions
echo "Step 8: Setting up udev rules..."
cat > /etc/udev/rules.d/99-phonorama.rules << 'EOF'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="plugdev", MODE="0660"
SUBSYSTEM=="audio", MODE="0666"
EOF

# STEP 9: Configure JACK Audio for Behringer devices
echo "Step 9: Configuring JACK Audio for Behringer devices..."
# Create JACK configuration for Behringer setup
cat > /home/$ACTUAL_USER/.jackdrc << 'EOF'
# Behringer JACK configuration - will be overridden by audio setup script
/usr/bin/jackd -P75 -d alsa -r 44100 -p 256 -n 2 -S &
EOF
usermod -aG audio,plugdev $ACTUAL_USER

# STEP 10: Install SC3 Plugins
echo "Step 10: Installing SC3 Plugins..."
cd /home/$ACTUAL_USER
if [ ! -d "sc3-plugins" ]; then
    if git clone --recursive https://github.com/supercollider/sc3-plugins.git; then
        echo "SC3 Plugins cloned successfully"
    else
        echo "ERROR: SC3 Plugins clone failed!"
        exit 1
    fi
fi
cd sc3-plugins
mkdir build && cd build
if cmake -DSC_PATH=/home/$ACTUAL_USER/supercollider -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF ..; then
    echo "SC3 Plugins configuration successful"
else
    echo "ERROR: SC3 Plugins configuration failed!"
    exit 1
fi
if cmake --build . --config Release; then
    echo "SC3 Plugins build successful"
else
    echo "ERROR: SC3 Plugins build failed!"
    exit 1
fi
if sudo cmake --build . --config Release --target install; then
    echo "SC3 Plugins installation successful"
else
    echo "ERROR: SC3 Plugins installation failed!"
    exit 1
fi

# STEP 11: Clone UHJ-Pi repository
echo "Step 11: Cloning UHJ-Pi repository..."
cd /home/$ACTUAL_USER
if [ ! -d "UHJ-Pi" ]; then
    if git clone https://github.com/mikeuwins/UHJ-Pi.git; then
        echo "UHJ-Pi repository cloned successfully"
    else
        echo "ERROR: UHJ-Pi repository clone failed!"
        exit 1
    fi
fi

# STEP 12: Install ATK and handle GUI component cleanup (MANUAL APPROACH)
echo "Step 12: Installing ATK and handling GUI component cleanup..."
cd /home/$ACTUAL_USER

# Create necessary directories
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/ATK
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions

# Install ATK and AmbiVerbSC using Quark system (handles dependencies automatically)
echo "Installing ATK and AmbiVerbSC using Quark system..."
cd /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions

# Install ATK using Quark system (includes all dependencies)
echo "Installing ATK quark..."
if sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");
0.exit;
EOF'; then
    echo "ATK quark installed successfully"
else
    echo "ERROR: ATK quark installation failed!"
    exit 1
fi

# Install AmbiVerbSC using Quark system
echo "Installing AmbiVerbSC quark..."
if sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.install("https://github.com/JamesWenlock/AmbiVerbSC");
0.exit;
EOF'; then
    echo "AmbiVerbSC quark installed successfully"
else
    echo "ERROR: AmbiVerbSC quark installation failed!"
    exit 1
fi

# Remove problematic GUI components BEFORE moving to Extensions
echo "Removing problematic GUI components from downloaded-quarks..."
cd /home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks

# Remove problematic wslib components
if [ -d "wslib/wslib-classes/GUI/" ]; then
    sudo -u $ACTUAL_USER rm -rf wslib/wslib-classes/GUI/
    echo "Removed wslib GUI components"
fi
if [ -f "wslib/wslib-classes/Main Features/Interpolation/extPen-splineCurve.sc" ]; then
    sudo -u $ACTUAL_USER rm "wslib/wslib-classes/Main Features/Interpolation/extPen-splineCurve.sc"
    echo "Removed extPen-splineCurve.sc"
fi
if [ -f "wslib/wslib-classes/Main Features/SVGFile/extColPen-asSVGFile.sc" ]; then
    sudo -u $ACTUAL_USER rm "wslib/wslib-classes/Main Features/SVGFile/extColPen-asSVGFile.sc"
    echo "Removed extColPen-asSVGFile.sc"
fi

# Remove entire wslib directory if it exists (can cause conflicts)
if [ -d "wslib" ]; then
    sudo -u $ACTUAL_USER rm -rf wslib
    echo "Removed entire wslib directory (conflict-prone)"
fi

# Download ATK assets manually (kernels and matrices only)
echo "Downloading ATK kernels and matrices manually..."
cd /home/$ACTUAL_USER/.local/share/ATK

# Download kernels
echo "Downloading ATK kernels v1.2.1..."
if sudo -u $ACTUAL_USER curl -L "https://github.com/ambisonictoolkit/atk-kernels/releases/download/v1.2.1/kernels.zip" -o kernels.zip; then
    if sudo -u $ACTUAL_USER unzip -o kernels.zip; then
        sudo -u $ACTUAL_USER rm kernels.zip
        echo "ATK kernels downloaded and extracted successfully"
    else
        echo "ERROR: ATK kernels extraction failed!"
        exit 1
    fi
else
    echo "ERROR: ATK kernels download failed!"
    exit 1
fi

# Download matrices  
echo "Downloading ATK matrices v1.0.3..."
if sudo -u $ACTUAL_USER curl -L "https://github.com/ambisonictoolkit/atk-matrices/releases/download/v1.0.3/matrices.zip" -o matrices.zip; then
    if sudo -u $ACTUAL_USER unzip -o matrices.zip; then
        sudo -u $ACTUAL_USER rm matrices.zip
        echo "ATK matrices downloaded and extracted successfully"
    else
        echo "ERROR: ATK matrices extraction failed!"
        exit 1
    fi
else
    echo "ERROR: ATK matrices download failed!"
    exit 1
fi

# Download ATK sounds (complete repository)
echo "Downloading ATK sounds repository..."
cd /tmp
if curl -L "https://github.com/ambisonictoolkit/atk-sounds/archive/refs/heads/master.zip" -o atk-sounds.zip; then
    echo "ATK sounds downloaded successfully - extracting..."
    sudo -u $ACTUAL_USER unzip -o atk-sounds.zip
    sudo -u $ACTUAL_USER cp -r atk-sounds-master/* /home/$ACTUAL_USER/.local/share/ATK/
            sudo -u $ACTUAL_USER rm -rf atk-sounds-master
        rm -f atk-sounds.zip
    echo "ATK sounds installed successfully"
    
    # Organize sounds into proper subdirectory structure (like working SD card)
    echo "Organizing sounds into proper directory structure..."
    cd /home/$ACTUAL_USER/.local/share/ATK
    if [ ! -d "sounds" ]; then
        sudo -u $ACTUAL_USER mkdir sounds
    fi
    # Move WAV files and documentation to sounds subdirectory
    sudo -u $ACTUAL_USER mv *.wav sounds/ 2>/dev/null || true
    sudo -u $ACTUAL_USER mv LICENSE.md sounds/ 2>/dev/null || true
    sudo -u $ACTUAL_USER mv README.md sounds/ 2>/dev/null || true
    echo "Sounds organized into sounds/ subdirectory"
else
    echo "ATK sounds download failed - continuing without sounds"
fi

# CRITICAL: Move ATK classes from downloaded-quarks to Extensions (Quark system puts them in wrong location)
echo "Moving ATK classes from downloaded-quarks to Extensions..."
cd /home/$ACTUAL_USER/.local/share/SuperCollider

# Move the clean, working classes to Extensions
echo "Moving ATK dependencies to Extensions..."
if [ -d "downloaded-quarks/MathLib" ]; then
    sudo -u $ACTUAL_USER mv downloaded-quarks/MathLib Extensions/
    echo "Moved MathLib to Extensions"
fi
if [ -d "downloaded-quarks/MatrixArray" ]; then
    sudo -u $ACTUAL_USER mv downloaded-quarks/MatrixArray Extensions/
    echo "Moved MatrixArray to Extensions"
fi
if [ -d "downloaded-quarks/SignalBox" ]; then
    sudo -u $ACTUAL_USER mv downloaded-quarks/SignalBox Extensions/
    echo "Moved SignalBox to Extensions"
fi
if [ -d "downloaded-quarks/SphericalDesign" ]; then
    sudo -u $ACTUAL_USER mv downloaded-quarks/SphericalDesign Extensions/
    echo "Moved SphericalDesign to Extensions"
fi
if [ -d "downloaded-quarks/atk-sc3" ]; then
    sudo -u $ACTUAL_USER mv downloaded-quarks/atk-sc3 Extensions/
    echo "Moved atk-sc3 to Extensions"
fi
if [ -d "downloaded-quarks/AmbiVerbSC" ]; then
    sudo -u $ACTUAL_USER mv downloaded-quarks/AmbiVerbSC Extensions/
    echo "Moved AmbiVerbSC to Extensions"
fi

# Set proper ownership for Extensions
echo "Setting proper ownership for Extensions..."
sudo chown -R $ACTUAL_USER:$ACTUAL_USER Extensions/

# ATK classes are now properly located in Extensions

# Return to ATK directory for custom sounds
cd /home/$ACTUAL_USER/.local/share/ATK

# STEP 13: Install Custom UHJ Test Sounds
echo "Step 13: Installing Custom UHJ Test Sounds..."
echo "Installing custom UHJ test sounds..."
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/ATK
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/AJH_eight-positions-uhj.wav /home/$ACTUAL_USER/.local/share/ATK/
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/hifi_sound_1981_ambisonic_tests.wav /home/$ACTUAL_USER/.local/share/ATK/
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/Sodium_Sunrise_UHJ.wav /home/$ACTUAL_USER/.local/share/ATK/
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/UHJ_Mono_Pink_Noise_North.wav /home/$ACTUAL_USER/.local/share/ATK/
echo "Custom UHJ test sounds installed successfully"

# Move custom sounds to sounds subdirectory to match working SD card structure
echo "Moving custom sounds to sounds/ subdirectory..."
cd /home/$ACTUAL_USER/.local/share/ATK
if [ -d "sounds" ]; then
    sudo -u $ACTUAL_USER mv *.wav sounds/ 2>/dev/null || true
    echo "Custom UHJ sounds moved to sounds/ subdirectory"
else
    echo "WARNING: sounds/ directory not found - creating it and moving sounds"
    sudo -u $ACTUAL_USER mkdir sounds
    sudo -u $ACTUAL_USER mv *.wav sounds/ 2>/dev/null || true
    echo "Custom UHJ sounds moved to sounds/ subdirectory"
fi

# AmbiVerbSC now installed via Quark system above

# STEP 14: Install custom user classes
echo "Step 14: Installing custom user classes..."
cd /home/$ACTUAL_USER/UHJ-Pi/supercollider/extensions

# Ensure SuperCollider Extensions directory exists
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/

# Copy custom extensions to SuperCollider Extensions directory (only if they don't exist)
echo "Installing custom extensions..."

if [ ! -d "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/ServerMeter2" ]; then
    echo "Installing ServerMeter2..."
    cp -r ServerMeter2 /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
    echo "ServerMeter2 installation completed"
else
    echo "ServerMeter2 already exists, skipping"
fi

if [ ! -d "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/Knob360" ]; then
    echo "Installing Knob360..."
    cp -r Knob360 /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
    echo "Knob360 installation completed"
else
    echo "Knob360 already exists, skipping"
fi

if [ ! -d "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/MaplinMatrix" ]; then
    echo "Installing MaplinMatrix..."
    cp -r MaplinMatrix /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
    echo "MaplinMatrix installation completed"
else
    echo "MaplinMatrix already exists, skipping"
fi

# Set proper ownership
chown -R $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/

# STEP 17: Install zita-ajbridge for Behringer audio setup
echo "Step 17: Installing zita-ajbridge..."
apt-get install -y zita-ajbridge

# STEP 18: Create Behringer udev rules for persistent device naming
echo "Step 18: Creating Behringer udev rules..."
cat > /etc/udev/rules.d/60-behringer-audio.rules << 'EOF'
# Behringer UFO202 and UCA202 persistent naming
# UFO202 on USB controller 0000:00:1a.7
SUBSYSTEM=="sound", KERNEL=="card*", ATTRS{idVendor}=="1397", ATTRS{idProduct}=="0501", ENV{ID_PATH}=="*1a.7*", SYMLINK+="sound/ufo202"

# UCA202 on USB controller 0000:00:1d.7
SUBSYSTEM=="sound", KERNEL=="card*", ATTRS{idVendor}=="1397", ATTRS{idProduct}=="0502", ENV{ID_PATH}=="*1d.7*", SYMLINK+="sound/uca202"

# Alternative method using USB port directly
SUBSYSTEM=="sound", KERNEL=="card*", ATTRS{idVendor}=="1397", ENV{ID_PATH}=="*1a.7*", ENV{ALSA_NAME}="UFO202"
SUBSYSTEM=="sound", KERNEL=="card*", ATTRS{idVendor}=="1397", ENV{ID_PATH}=="*1d.7*", ENV{ALSA_NAME}="UCA202"
EOF

# Reload udev rules
udevadm control --reload-rules
udevadm trigger

# STEP 19: Configure Behringer audio setup automatically
echo "Step 19: Configuring Behringer audio setup..."
echo "Setting up UFO202 (phono) + UCA202 (line) for SuperCollider..."

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies
echo "Checking audio dependencies..."
if ! command_exists jackd; then
    echo "ERROR: JACK not installed. Run: sudo apt install jackd2"
    exit 1
fi

if ! command_exists zita-a2j; then
    echo "ERROR: zita-ajbridge not installed. Run: sudo apt install zita-ajbridge"
    exit 1
fi

# Stop any existing audio processes
echo "Stopping existing audio processes..."
pkill jackd 2>/dev/null
pkill zita-a2j 2>/dev/null
pkill zita-j2a 2>/dev/null
pkill qjackctl 2>/dev/null
sleep 2

# Detect Behringer devices by USB controller
echo "Detecting Behringer devices..."

# Simple method: extract card number from the line that contains the USB controller
UCA_CARD=""
UFO_CARD=""

# Parse /proc/asound/cards line by line
while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[ ]]; then
        current_card="${BASH_REMATCH[1]}"
    elif [[ $line =~ 1d\.7 ]]; then
        UCA_CARD="$current_card"
    elif [[ $line =~ 1a\.7 ]]; then
        UFO_CARD="$current_card"
    fi
done < /proc/asound/cards

if [ -z "$UCA_CARD" ] || [ -z "$UFO_CARD" ]; then
    echo "WARNING: Could not detect both Behringer devices"
    echo "Make sure both UFO202 and UCA202 are connected"
    echo "Current audio cards:"
    cat /proc/asound/cards
    echo "Audio setup will need to be configured manually after reboot"
else
    echo "Detected devices:"
    echo "  UCA202 (Line Input) = Card $UCA_CARD (USB controller 0000:00:1d.7)"
    echo "  UFO202 (Phono Input) = Card $UFO_CARD (USB controller 0000:00:1a.7)"

    # Start JACK on UCA202 (line device) as master
    echo "Starting JACK server on UCA202 (Card $UCA_CARD) at 44100 Hz..."
    jackd -d alsa -d hw:$UCA_CARD -r 44100 -p 256 -n 2 > /tmp/jack.log 2>&1 &
    JACK_PID=$!

    # Wait for JACK to initialize
    sleep 3

    # Check if JACK started successfully
    if ! ps -p $JACK_PID > /dev/null; then
        echo "WARNING: JACK failed to start. Check /tmp/jack.log"
        echo "Audio setup will need to be configured manually after reboot"
    else
        echo "JACK server started successfully (PID: $JACK_PID)"

        # Start zita bridges for UFO202
        echo "Starting zita bridges for UFO202 (Card $UFO_CARD)..."

        # Bridge UFO202 inputs to JACK (phono inputs)
        echo "Starting zita-a2j for UFO202 inputs..."
        zita-a2j -j ufo_phono -d hw:$UFO_CARD -r 44100 -p 256 -c 2 > /tmp/zita-a2j.log 2>&1 &
        ZITA_A2J_PID=$!

        # Bridge JACK outputs to UFO202 (additional outputs)
        echo "Starting zita-j2a for UFO202 outputs..."
        zita-j2a -j ufo_out -d hw:$UFO_CARD -r 44100 -p 256 -c 2 > /tmp/zita-j2a.log 2>&1 &
        ZITA_J2A_PID=$!

        # Wait for zita bridges to initialize
        sleep 2

        # Check if zita processes started successfully
        if ! ps -p $ZITA_A2J_PID > /dev/null; then
            echo "WARNING: zita-a2j failed to start. Check /tmp/zita-a2j.log"
        fi

        if ! ps -p $ZITA_J2A_PID > /dev/null; then
            echo "WARNING: zita-j2a failed to start. Check /tmp/zita-j2a.log"
        fi

        if ps -p $ZITA_A2J_PID > /dev/null && ps -p $ZITA_J2A_PID > /dev/null; then
            echo "Zita bridges started successfully"
            
            # Wait a moment for everything to sync
            sleep 2

            # Verify JACK ports
            echo "Verifying JACK configuration..."
            if command_exists jack_lsp; then
                PORTS=$(jack_lsp | wc -l)
                echo "Available JACK ports:"
                jack_lsp | sort

                if [ $PORTS -ge 8 ]; then
                    echo "✅ SUCCESS: All ports available ($PORTS total)"
                else
                    echo "⚠️  WARNING: Expected 8+ ports, found $PORTS"
                fi
            else
                echo "jack_lsp not available, cannot verify ports"
            fi

            # Stop audio processes for now (will be restarted after reboot)
            echo "Stopping audio processes (will restart after reboot)..."
            pkill jackd 2>/dev/null
            pkill zita-a2j 2>/dev/null
            pkill zita-j2a 2>/dev/null
        fi
    fi
fi

# STEP 20: Configure Qt platform for headless operation
echo "Step 20: Configuring Qt platform for headless operation..."
# Set Qt platform to eglfs for the user's shell
echo 'export QT_QPA_PLATFORM=eglfs' >> /home/$ACTUAL_USER/.bashrc
echo 'export QT_QPA_PLATFORM=eglfs' >> /home/$ACTUAL_USER/.profile
# Clear X11 display variable to force EGLFS
echo 'unset DISPLAY' >> /home/$ACTUAL_USER/.bashrc
echo 'unset DISPLAY' >> /home/$ACTUAL_USER/.profile

# STEP 21: Install custom fonts
echo "Step 21: Installing custom fonts..."
cd /home/$ACTUAL_USER/UHJ-Pi/assets/fonts

# Create fonts directory if it doesn't exist
mkdir -p /usr/local/share/fonts/truetype/uhj-pi

# Copy custom fonts to system font directory
cp lcd_segment_monospace/lcd-5x7-segment-monospace.ttf /usr/local/share/fonts/truetype/uhj-pi/
cp "led_dot_matrix/LED Dot-Matrix.ttf" /usr/local/share/fonts/truetype/uhj-pi/

# Install Arial font for power button
echo "Installing Arial font..."
apt-get install -y cabextract
mkdir -p /usr/share/fonts/truetype/msttcorefonts
cd /usr/share/fonts/truetype/msttcorefonts
wget -q https://github.com/matomo-org/travis-scripts/raw/master/fonts/Arial.ttf

# Update font cache
fc-cache -f -v

# STEP 22: Create a launcher with persistent device configuration
echo "Step 22: Creating launcher with persistent audio setup..."
cat > /usr/local/bin/start << 'EOF'
#!/usr/bin/env bash

CONFIG_FILE="$HOME/.uhj-pi-audio.conf"
echo "Starting Behringer audio setup..."

# Function to detect USB audio devices
detect_usb_devices() {
    local devices=()
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[ ]]; then
            current_card="${BASH_REMATCH[1]}"
        elif [[ $line =~ usb- ]]; then
            # Extract USB path (e.g., usb-xhci-hcd.0-2)
            if [[ $line =~ usb-[^,]+ ]]; then
                usb_path="${BASH_REMATCH[0]}"
                devices+=("$current_card:$usb_path")
            fi
        fi
    done < /proc/asound/cards
    echo "${devices[@]}"
}

# Function to register devices step by step
register_devices() {
    echo "Device registration required..."
    echo ""
    
    # Step 1: Register UCA202
    echo "Step 1: Connect UCA202 (line input/output device) and press Enter"
    read -p "Press Enter when UCA202 is connected..."
    
    local uca_device=""
    local devices=$(detect_usb_devices)
    for device in $devices; do
        if [[ $device =~ ^([0-9]+):(.*)$ ]]; then
            local card="${BASH_REMATCH[1]}"
            local usb_path="${BASH_REMATCH[2]}"
            echo "Device detected: $usb_path (Card $card)"
            uca_device="$card:$usb_path"
            break
        fi
    done
    
    if [ -z "$uca_device" ]; then
        echo "ERROR: No USB audio device detected. Please check connection."
        exit 1
    fi
    
    echo "UCA202 registered as line input/outputs 1 & 2"
    echo ""
    
    # Step 2: Register UFO202
    echo "Step 2: Connect UFO202 (phono input/output device) and press Enter"
    read -p "Press Enter when UFO202 is connected..."
    
    local ufo_device=""
    devices=$(detect_usb_devices)
    for device in $devices; do
        if [[ $device =~ ^([0-9]+):(.*)$ ]]; then
            local card="${BASH_REMATCH[1]}"
            local usb_path="${BASH_REMATCH[2]}"
            if [ "$device" != "$uca_device" ]; then
                echo "Device detected: $usb_path (Card $card)"
                ufo_device="$card:$usb_path"
                break
            fi
        fi
    done
    
    if [ -z "$ufo_device" ]; then
        echo "ERROR: Second USB audio device not detected. Please check connection."
        exit 1
    fi
    
    echo "UFO202 registered as phono input/outputs 3 & 4"
    echo ""
    
    # Save configuration
    echo "Saving device configuration..."
    cat > "$CONFIG_FILE" << CONFIG_EOF
# UHJ-Pi Behringer Audio Configuration
# Generated on $(date)
UCA_DEVICE="$uca_device"
UFO_DEVICE="$ufo_device"
UCA_CARD=$(echo "$uca_device" | cut -d: -f1)
UFO_CARD=$(echo "$ufo_device" | cut -d: -f1)
CONFIG_EOF
    
    echo "Configuration saved to $CONFIG_FILE"
    echo ""
    
    # Return the detected devices
    UCA_CARD=$(echo "$uca_device" | cut -d: -f1)
    UFO_CARD=$(echo "$ufo_device" | cut -d: -f1)
}

# Check if configuration exists and devices are still valid
if [ -f "$CONFIG_FILE" ]; then
    echo "Found existing configuration, checking devices..."
    source "$CONFIG_FILE"
    
    # Verify devices still exist
    local devices=$(detect_usb_devices)
    local uca_found=false
    local ufo_found=false
    
    for device in $devices; do
        if [[ $device =~ ^([0-9]+):(.*)$ ]]; then
            local card="${BASH_REMATCH[1]}"
            local usb_path="${BASH_REMATCH[2]}"
            if [ "$card:$usb_path" = "$UCA_DEVICE" ]; then
                uca_found=true
            elif [ "$card:$usb_path" = "$UFO_DEVICE" ]; then
                ufo_found=true
            fi
        fi
    done
    
    if [ "$uca_found" = true ] && [ "$ufo_found" = true ]; then
        echo "Using saved configuration:"
        echo "  UCA202: Card $UCA_CARD ($UCA_DEVICE)"
        echo "  UFO202: Card $UFO_CARD ($UFO_DEVICE)"
        echo ""
    else
        echo "Saved configuration invalid, re-registering devices..."
        rm "$CONFIG_FILE"
        register_devices
    fi
else
    echo "No configuration found, registering devices..."
    register_devices
fi

# Stop any existing audio processes
echo "Stopping existing audio processes..."
pkill jackd 2>/dev/null
pkill zita-a2j 2>/dev/null
pkill zita-j2a 2>/dev/null
sleep 2

# Start JACK on UCA202 (line device) as master
echo "Starting JACK server on UCA202 (Card $UCA_CARD)..."
jackd -d alsa -d hw:$UCA_CARD -r 44100 -p 256 -n 2 > /tmp/jack.log 2>&1 &
JACK_PID=$!

# Wait for JACK to initialize
sleep 3

# Check if JACK started successfully
if ! ps -p $JACK_PID > /dev/null; then
    echo "ERROR: JACK failed to start. Check /tmp/jack.log"
    exit 1
fi

echo "JACK server started successfully (PID: $JACK_PID)"

# Start zita bridges for UFO202
echo "Starting zita bridges for UFO202 (Card $UFO_CARD)..."

# Bridge UFO202 inputs to JACK (phono inputs)
echo "Starting zita-a2j for UFO202 inputs..."
zita-a2j -j ufo_phono -d hw:$UFO_CARD -r 44100 -p 256 -c 2 > /tmp/zita-a2j.log 2>&1 &
ZITA_A2J_PID=$!

# Bridge JACK outputs to UFO202 (additional outputs)
echo "Starting zita-j2a for UFO202 outputs..."
zita-j2a -j ufo_out -d hw:$UFO_CARD -r 44100 -p 256 -c 2 > /tmp/zita-j2a.log 2>&1 &
ZITA_J2A_PID=$!

# Wait for zita bridges to initialize
sleep 2

# Check if zita processes started successfully
if ! ps -p $ZITA_A2J_PID > /dev/null; then
    echo "ERROR: zita-a2j failed to start. Check /tmp/zita-a2j.log"
fi

if ! ps -p $ZITA_J2A_PID > /dev/null; then
    echo "ERROR: zita-j2a failed to start. Check /tmp/zita-j2a.log"
fi

echo "Zita bridges started successfully"

# Wait a moment for everything to sync
sleep 2

# Verify JACK ports
echo "Verifying JACK configuration..."
if command -v jack_lsp >/dev/null 2>&1; then
    PORTS=$(jack_lsp | wc -l)
    echo "Available JACK ports: $PORTS"
    if [ $PORTS -ge 8 ]; then
        echo "✅ SUCCESS: All ports available"
    else
        echo "⚠️  WARNING: Expected 8+ ports, found $PORTS"
    fi
fi

echo "Audio setup complete! Starting SuperCollider app..."
echo ""

# Start the SuperCollider app
exec sclang /home/$USER/UHJ-Pi/supercollider/app/UHJ_v23_BEH.scd > /home/$USER/post_output.log 2>&1
EOF
chmod +x /usr/local/bin/start

echo "Installation completed successfully!"
echo ""
echo "Behringer Audio Setup:"
echo "  ✅ zita-ajbridge installed"
echo "  ✅ Behringer udev rules created"
echo "  ✅ Audio devices configured for 4-in/4-out operation"
echo ""
echo "SuperCollider Setup:"
echo "  ✅ SuperCollider + ATK + AmbiVerbSC installed"
echo "  ✅ Custom extensions installed"
echo "  ✅ Custom fonts installed"
echo "  ✅ Launcher created: /usr/local/bin/start"
echo ""
echo "Next Steps:"
echo "1. Reboot: sudo reboot"
echo "2. After reboot, run: start"
echo ""
echo "The 'start' command will:"
echo "  - Register your Behringer devices (first time only)"
echo "  - Save device configuration for future use"
echo "  - Start JACK server and zita bridges automatically"
echo "  - Launch the SuperCollider app"
echo ""
echo "Device registration is required only once - after that, the system"
echo "remembers your device setup and works automatically on each boot!"
echo ""
echo "Your Behringer devices are now configured for quad ambisonic operation!"
