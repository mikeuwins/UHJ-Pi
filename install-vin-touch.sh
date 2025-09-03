#!/bin/bash

# UHJ-Pi Raspberry Pi Setup Script - Vinyl Deck Touch Version
# Based on install-beh-touch.sh with Vinyl Deck audio setup integrated

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    
    printf "\r["
    printf "%*s" $completed | tr ' ' '='
    printf "%*s" $((width - completed))
    printf "] %d%% (%d/%d)" $percentage $current $total
}

# Build progress indicator with percentage and progress bar
show_build_progress() {
    local message=$1
    local logfile=$2
    local pid=$3
    local last_percent=0
    local width=30
    
    while kill -0 $pid 2>/dev/null; do
        # Try to extract percentage from make output
        if [ -f "$logfile" ]; then
            local percent=$(tail -20 "$logfile" 2>/dev/null | grep -o '\[[0-9]\+%\]' | tail -1 | grep -o '[0-9]\+' || echo "")
            if [ -n "$percent" ] && [ "$percent" -gt "$last_percent" ]; then
                last_percent=$percent
            fi
        fi
        
        # Show progress bar
        local completed=$((last_percent * width / 100))
        printf "\r$message ["
        printf "%*s" $completed | tr ' ' '='
        if [ $completed -lt $width ]; then
            printf ">"
            printf "%*s" $((width - completed - 1))
        fi
        printf "] %d%%" $last_percent
        
        sleep 3
    done
    printf "\r$message ["
    printf "%*s" $width | tr ' ' '='
    printf "] 100%% ✓\n"
}

# Step header function
step_header() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Get the actual username (the user who ran sudo)
ACTUAL_USER=${SUDO_USER:-$(logname)}
if [ -z "$ACTUAL_USER" ]; then
    echo "Error: Could not determine username. Please run with: sudo -E ./install-vin-touch.sh"
    exit 1
fi

clear
echo "🎵 UHJ-Pi Raspberry Pi Setup Script - Vinyl Deck Touch Version 🎵"
echo "Installing for user: $ACTUAL_USER"
echo "This version includes Vinyl Deck audio setup with dynamic device detection"
echo

# Configure non-interactive package installation
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none
echo "initramfs-tools initramfs-tools/update_initramfs boolean false" | debconf-set-selections
echo "jackd jackd/tweak_rt_limits boolean true" | debconf-set-selections

# Set up logging
INSTALL_LOG="/tmp/uhj-pi-install.log"
echo "Installation started at $(date)" > $INSTALL_LOG
echo "Log file: $INSTALL_LOG"

step_header "STEP 1/7: System Update"
echo "Updating package lists..."
if apt-get update >> $INSTALL_LOG 2>&1; then
    echo "✓ Package lists updated"
else
    echo "✗ Package update failed - check $INSTALL_LOG"
    exit 1
fi

step_header "STEP 2/7: Disable Onboard and HDMI Audio"
echo "Configuring audio settings..."
if ! grep -q "dtparam=audio=off" /boot/firmware/config.txt; then
    echo "dtparam=audio=off" >> /boot/firmware/config.txt
fi
if ! grep -q "dtoverlay=vc4-kms-v3d,noaudio" /boot/firmware/config.txt; then
    echo "dtoverlay=vc4-kms-v3d,noaudio" >> /boot/firmware/config.txt
fi
echo "✓ Audio settings configured"

step_header "STEP 3/7: Install Dependencies"
echo "Installing build tools and audio dependencies..."

# Audio performance optimizations
echo "Configuring audio performance optimizations..."

# Set CPU governor to performance mode for better real-time performance
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo "performance" > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || echo "Note: Could not set CPU governor"
fi

# Configure audio thread priority limits
if [ -f /etc/security/limits.conf ]; then
    # Check if audio limits already exist
    if ! grep -q "@audio.*rtprio" /etc/security/limits.conf; then
        echo "Adding audio performance limits to /etc/security/limits.conf..."
        echo "@audio   -  rtprio     95" >> /etc/security/limits.conf
        echo "@audio   -  memlock    unlimited" >> /etc/security/limits.conf
        echo "✓ Audio performance limits configured"
    else
        echo "✓ Audio performance limits already configured"
    fi
fi

# List of packages to install
packages=(
    "build-essential" "cmake" "libjack-jackd2-dev" "libsndfile1-dev"
    "libfftw3-dev" "libxt-dev" "libavahi-client-dev" "libudev-dev" 
    "libasound2-dev" "libreadline-dev" "libxkbcommon-dev" "git" 
    "jackd2" "libhidapi-dev" "qt6-base-dev" "qt6-svg-dev" 
    "qt6-tools-dev" "qt6-wayland" "qt6-websockets-dev" "qt6-webengine-dev"
)

total_packages=${#packages[@]}
current_package=0

for package in "${packages[@]}"; do
    current_package=$((current_package + 1))
    show_progress $current_package $total_packages
    apt-get install -y "$package" >> $INSTALL_LOG 2>&1
done
echo
echo "✓ All dependencies installed"

step_header "STEP 4/7: Clone SuperCollider"
echo "Downloading SuperCollider source code..."
cd /home/$ACTUAL_USER
if [ ! -d "supercollider" ]; then
    git clone --branch main --recurse-submodules https://github.com/supercollider/supercollider.git > /dev/null 2>&1
fi
echo "✓ SuperCollider source downloaded"

echo "Preparing build directory..."
cd supercollider
mkdir -p build
cd build

step_header "STEP 5/7: Build SuperCollider"
echo "Configuring build (this may take a few minutes)..."
if cmake -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF -DSC_EL=OFF -DSC_VIM=ON \
    -DNATIVE=ON -DSC_IDE=OFF -DNO_X11=ON -DSC_QT=ON .. > /dev/null 2>&1; then
    echo "✓ Configuration successful"
else
    echo "✗ Configuration failed"
    exit 1
fi

echo "Building SuperCollider..."
make -j2 >> $INSTALL_LOG 2>&1 &
BUILD_PID=$!
show_build_progress "Building SuperCollider" $INSTALL_LOG $BUILD_PID
wait $BUILD_PID
if [ $? -eq 0 ]; then
    echo "✓ Build successful"
else
    echo "✗ Build failed - check $INSTALL_LOG"
    exit 1
fi

echo "Installing SuperCollider..."
make install >> $INSTALL_LOG 2>&1 &
INSTALL_PID=$!
show_build_progress "Installing SuperCollider" $INSTALL_LOG $INSTALL_PID
wait $INSTALL_PID
if [ $? -eq 0 ]; then
    echo "✓ SuperCollider installed"
    ldconfig >> $INSTALL_LOG 2>&1
else
    echo "✗ Installation failed - check $INSTALL_LOG"
    exit 1
fi

step_header "STEP 6/7: System Configuration"
echo "Setting up device permissions..."
cat > /etc/udev/rules.d/99-phonorama.rules << 'EOF'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="plugdev", MODE="0660"
SUBSYSTEM=="audio", MODE="0666"
EOF

echo "Configuring audio groups and permissions..."
cat > /home/$ACTUAL_USER/.jackdrc << 'EOF'
# Vinyl Deck JACK configuration - will be overridden by audio setup script
/usr/bin/jackd -P75 -d alsa -r 44100 -p 1024 -n 3 -S &
EOF
usermod -aG audio,plugdev $ACTUAL_USER > /dev/null 2>&1
echo "✓ Audio configuration complete"

echo "Installing SC3 Plugins..."
cd /home/$ACTUAL_USER
if [ ! -d "sc3-plugins" ]; then
    git clone --recursive https://github.com/supercollider/sc3-plugins.git > /dev/null 2>&1
fi
cd sc3-plugins
mkdir -p build && cd build
if cmake -DSC_PATH=/home/$ACTUAL_USER/supercollider -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF .. > /dev/null 2>&1; then
    echo "✓ SC3 Plugins configured"
else
    echo "✗ SC3 Plugins configuration failed"
    exit 1
fi
cmake --build . --config Release >> $INSTALL_LOG 2>&1 &
BUILD_PID=$!
show_build_progress "Building SC3 Plugins" $INSTALL_LOG $BUILD_PID
wait $BUILD_PID
if [ $? -eq 0 ]; then
    echo "✓ SC3 Plugins built"
else
    echo "✗ SC3 Plugins build failed - check $INSTALL_LOG"
    exit 1
fi

cmake --build . --config Release --target install >> $INSTALL_LOG 2>&1 &
INSTALL_PID=$!
show_build_progress "Installing SC3 Plugins" $INSTALL_LOG $INSTALL_PID
wait $INSTALL_PID
if [ $? -eq 0 ]; then
    echo "✓ SC3 Plugins installed"
else
    echo "✗ SC3 Plugins installation failed - check $INSTALL_LOG"
    exit 1
fi

step_header "STEP 7/7: UHJ-Pi Application Setup"
echo "Checking UHJ-Pi application..."
cd /home/$ACTUAL_USER

# Check if we're already in the UHJ-Pi directory (likely case)
if [ -d "UHJ-Pi" ]; then
    echo "✓ UHJ-Pi repository already present"
elif [ -f "start-vin.sh" ] && [ -f "ble-ht.sh" ]; then
    echo "✓ UHJ-Pi files already present (running from repo directory)"
else
    echo "Downloading UHJ-Pi repository..."
    # Try shallow clone first (faster, less data)
    retry_count=0
    max_retries=3
    
    while [ $retry_count -lt $max_retries ]; do
        if git clone --depth 1 https://github.com/mikeuwins/UHJ-Pi.git; then
            echo "✓ UHJ-Pi repository downloaded"
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                echo "Download failed, retrying ($retry_count/$max_retries)..."
                sleep 5
                rm -rf UHJ-Pi 2>/dev/null
            else
                echo "✗ UHJ-Pi repository download failed after $max_retries attempts"
                echo "Please check your internet connection and try again"
                exit 1
            fi
        fi
    done
fi

echo "Installing SuperCollider extensions..."
cd /home/$ACTUAL_USER

# Create necessary directories
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/ATK
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions

# Install ATK and AmbiVerbSC using Quark system (handles dependencies automatically)
echo "Installing ATK and AmbiVerbSC using Quark system..."
cd /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions

# Install ATK using Quark system (includes all dependencies)
echo "Installing ATK quark (Ambisonic Toolkit)..."
sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");
0.exit;
EOF' >> $INSTALL_LOG 2>&1 &
QUARK_PID=$!
show_build_progress "Installing ATK quark" $INSTALL_LOG $QUARK_PID
wait $QUARK_PID
if [ $? -eq 0 ]; then
    echo "✓ ATK quark installed"
else
    echo "✗ ATK quark installation failed - check $INSTALL_LOG"
    exit 1
fi

# Install AmbiVerbSC using Quark system
echo "Installing AmbiVerbSC quark..."
sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.install("https://github.com/JamesWenlock/AmbiVerbSC");
0.exit;
EOF' >> $INSTALL_LOG 2>&1 &
QUARK_PID=$!
show_build_progress "Installing AmbiVerbSC quark" $INSTALL_LOG $QUARK_PID
wait $QUARK_PID
if [ $? -eq 0 ]; then
    echo "✓ AmbiVerbSC quark installed"
else
    echo "✗ AmbiVerbSC quark installation failed - check $INSTALL_LOG"
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

echo "Installing custom fonts..."
cd /home/$ACTUAL_USER/UHJ-Pi/assets/fonts

# Create fonts directory if it doesn't exist
mkdir -p /usr/local/share/fonts/truetype/uhj-pi >> $INSTALL_LOG 2>&1

# Copy custom fonts to system font directory
cp lcd_segment_monospace/lcd-5x7-segment-monospace.ttf /usr/local/share/fonts/truetype/uhj-pi/ >> $INSTALL_LOG 2>&1
cp "led_dot_matrix/LED Dot-Matrix.ttf" /usr/local/share/fonts/truetype/uhj-pi/ >> $INSTALL_LOG 2>&1

# Install Arial font for power button
apt-get install -y cabextract >> $INSTALL_LOG 2>&1
mkdir -p /usr/share/fonts/truetype/msttcorefonts >> $INSTALL_LOG 2>&1
cd /usr/share/fonts/truetype/msttcorefonts
wget -q https://github.com/matomo-org/travis-scripts/raw/master/fonts/Arial.ttf >> $INSTALL_LOG 2>&1

# Update font cache (quietly)
fc-cache -f >> $INSTALL_LOG 2>&1
echo "✓ Custom fonts installed"

# STEP 22: Install Bluetooth pairing script
echo "Step 22: Installing Bluetooth pairing script..."
cp /home/$ACTUAL_USER/UHJ-Pi/ble-ht.sh /usr/local/bin/
chmod +x /usr/local/bin/ble-ht.sh
chown $ACTUAL_USER:$ACTUAL_USER /usr/local/bin/ble-ht.sh
echo "Bluetooth pairing script installed to /usr/local/bin/"

# STEP 23: Create a launcher with persistent device configuration
echo "Step 23: Creating launcher with persistent audio setup..."
cat > /usr/local/bin/start << 'EOF'
#!/usr/bin/env bash

CONFIG_FILE="$HOME/.uhj-vin-audio.conf"
echo "Starting Vinyl Deck audio setup..."

# Function to show device information
show_device_info() {
    local card_num=$1
    local card_name=$2
    
    echo "Device Information:"
    echo "  Name: $card_name"
    echo "  Card: hw:$card_num"
    
    # Show playback capabilities
    if aplay -l | grep -q "card $card_num:"; then
        echo "  Playback: Available"
    else
        echo "  Playback: Not available"
    fi
    
    # Show capture capabilities  
    if arecord -l | grep -q "card $card_num:"; then
        echo "  Capture: Available"
    else
        echo "  Capture: Not available"
    fi
    
    # Try to get more detailed info from amixer
    if command -v amixer >/dev/null 2>&1; then
        local controls=$(amixer -c $card_num controls 2>/dev/null | wc -l)
        if [ "$controls" -gt 0 ]; then
            echo "  Controls: $controls available"
        fi
    fi
    echo ""
}

# Interactive device detection
detect_vinyl_devices() {
    local vinyl_card=""
    local output_card=""
    local output_name=""
    
    echo "=== USB Turntable Setup ==="
    echo ""
    echo "Step 1: Connect your turntable with USB audio output"
    echo "(This can be any USB audio interface with ALSA drivers)"
    read -p "Press Enter when your USB turntable is connected..."
    
    # Look for newly connected audio devices
    echo "Scanning for audio devices..."
    sleep 2
    
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\] ]]; then
            local card_num="${BASH_REMATCH[1]}"
            local card_name="${BASH_REMATCH[2]}"
            
            # Look for likely turntable names
            if [[ $card_name =~ CODEC|Turntable|Vinyl|DJ ]]; then
                vinyl_card="$card_num"
                echo "✓ Found USB turntable: hw:$vinyl_card ($card_name)"
                show_device_info "$card_num" "$card_name"
                break
            fi
        fi
    done < /proc/asound/cards
    
    # If no obvious turntable found, show all devices and let user choose
    if [ -z "$vinyl_card" ]; then
        echo "Could not automatically detect turntable. Available audio devices:"
        echo ""
        cat /proc/asound/cards
        echo ""
        read -p "Enter the card number for your turntable: " vinyl_card
        
        # Get the name for the chosen card
        while IFS= read -r line; do
            if [[ $line =~ ^[[:space:]]*${vinyl_card}[[:space:]]*\[([^]]+)\] ]]; then
                local card_name="${BASH_REMATCH[1]}"
                echo "✓ Selected turntable: hw:$vinyl_card ($card_name)"
                show_device_info "$vinyl_card" "$card_name"
                break
            fi
        done < /proc/asound/cards
    fi
    
    echo "=== USB Audio Interface Setup ==="
    echo ""
    echo "Step 2: Connect your USB audio interface for output"
    echo "(This can be any USB soundcard - Behringer, UMC, etc.)"
    read -p "Press Enter when your USB audio interface is connected..."
    
    # Look for the output device (any card that's not the turntable)
    echo "Scanning for output interface..."
    sleep 2
    
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\] ]]; then
            local card_num="${BASH_REMATCH[1]}"
            local card_name="${BASH_REMATCH[2]}"
            
            # Skip the turntable card
            if [ "$card_num" != "$vinyl_card" ]; then
                output_card="$card_num"
                output_name="$card_name"
                echo "✓ Found output interface: hw:$output_card ($card_name)"
                show_device_info "$card_num" "$card_name"
                break
            fi
        fi
    done < /proc/asound/cards
    
    if [ -z "$vinyl_card" ]; then
        echo "ERROR: Turntable not configured"
        exit 1
    fi
    
    if [ -z "$output_card" ]; then
        echo "ERROR: No output interface found"
        echo "Please connect a USB audio interface and try again"
        exit 1
    fi
    
    echo "VINYL_CARD=$vinyl_card" > "$CONFIG_FILE"
    echo "OUTPUT_CARD=$output_card" >> "$CONFIG_FILE"
    echo "OUTPUT_NAME=$output_name" >> "$CONFIG_FILE"
    echo "Device configuration saved to $CONFIG_FILE"
    
    echo ""
    echo "=== Configuration Complete ==="
    echo "✓ Turntable: hw:$vinyl_card (input)"
    echo "✓ Audio Interface: hw:$output_card ($output_name) (output)"
    echo ""
}

# Kill any existing audio processes
echo "Stopping existing audio processes..."
killall jackd 2>/dev/null
killall sclang 2>/dev/null
sleep 2

# Audio performance optimizations already applied during installation

# Detect devices
detect_vinyl_devices

# Load configuration
source "$CONFIG_FILE"

echo "Starting JACK with:"
echo "  Input: hw:$VINYL_CARD (Vinyl Deck)"
echo "  Output: hw:$OUTPUT_CARD ($OUTPUT_NAME)"

# Start JACK - simple input/output configuration like ESI  
# Large buffer for stability (1024 frames = ~23ms latency, 3 periods)
jackd -P75 -d alsa -C hw:$VINYL_CARD -P hw:$OUTPUT_CARD -r 44100 -p 1024 -n 3 -S &

# Wait for JACK to start
sleep 3

# Check if JACK started successfully
if ! pgrep jackd > /dev/null; then
    echo "ERROR: JACK failed to start. Check /tmp/jack.log for details."
    exit 1
fi

echo "✓ JACK started successfully"

# Show available JACK ports
echo ""
echo "Available JACK ports:"
jack_lsp 2>/dev/null || echo "jack_lsp not available"

echo ""
echo "🎵 Audio setup complete! Starting SuperCollider application..."

# Launch SuperCollider with turntable application
exec sclang /home/$USER/UHJ-Pi/supercollider/app/UHJ_v23_VIN_PAIR.scd > /home/$USER/post_output.log 2>&1
EOF
chmod +x /usr/local/bin/start

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎵 UHJ-Pi Vinyl Deck Installation Complete! 🎵"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Audio System:"
echo "   • Dynamic device detection for turntables and output interfaces"
echo "   • JACK audio server with stable 1024-frame buffers"
echo "   • Optimized for turntable input + any USB audio output"
echo ""
echo "✅ SuperCollider:"
echo "   • SuperCollider with Qt GUI support"
echo "   • ATK (Ambisonic Toolkit) + AmbiVerbSC extensions"
echo "   • UHJ decoder with headtracker pairing support"
echo ""
echo "✅ Ready to use:"
echo "   • Launcher: /usr/local/bin/start"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 INSTALLATION COMPLETE - REBOOT REQUIRED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Your Pi will automatically reboot in 10 seconds..."
echo "After reboot, log in and run: start"
echo ""
echo "The first time you run 'start', it will help you configure your"
echo "turntable and output interface. After that, just run 'start'"
echo "whenever you want to use the UHJ-Pi application."
echo ""
echo -n "Press any key to cancel automatic reboot... "

# 10 second countdown with ability to cancel
for i in {10..1}; do
    if read -t 1 -n 1; then
        echo ""
        echo "Reboot cancelled. To reboot manually later, run: sudo reboot"
        exit 0
    fi
    printf "\rRebooting in %d seconds... (Press any key to cancel)" $i
done

echo ""
echo "Rebooting now..."
sleep 1
reboot
