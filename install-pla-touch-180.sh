#!/bin/bash


# UHJ-Pi Raspberry Pi Setup Script - Player Touch Version (180-degree rotation)
# Based on install-gen-touch.sh with player-focused setup integrated

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
            # Look for various percentage formats: [45%], 45%, (45%), etc.
            # Also look for make progress: [ 45%] Building...
            local percent=$(tail -50 "$logfile" 2>/dev/null | grep -oE '\[\s*[0-9]+%\]|\[[0-9]+%\]|[0-9]+%' | tail -1 | grep -o '[0-9]\+' || echo "")
            if [ -n "$percent" ] && [ "$percent" -gt "$last_percent" ]; then
                last_percent=$percent
            fi
        fi
        
        # Show progress bar
        local completed=$((last_percent * width / 100))
        printf "\r$message ["
        printf "%*s" $completed | tr ' ' '='
        printf "%*s" $((width - completed))
        if [ $last_percent -gt 0 ]; then
            printf "] %d%%" $last_percent
        else
            printf "]"
        fi
        
        sleep 2
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
echo "🎵 UHJ-Pi Raspberry Pi Setup Script - Player Touch Version (180° Rotation) 🎵"
echo "Installing for user: $ACTUAL_USER"
echo "This version installs the standalone Player with dynamic device detection"
echo "Screen and touch will be configured for 180-degree rotation"
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

step_header "STEP 1/18: System Update"
echo "Updating package lists..."
if apt-get update >> $INSTALL_LOG 2>&1; then
    echo "✓ Package lists updated"
else
    echo "✗ Package update failed - check $INSTALL_LOG"
    exit 1
fi

step_header "STEP 2/18: Disable Onboard and HDMI Audio"
echo "Configuring audio settings..."
if ! grep -q "dtparam=audio=off" /boot/firmware/config.txt; then
    echo "dtparam=audio=off" >> /boot/firmware/config.txt
fi
if ! grep -q "dtoverlay=vc4-kms-v3d,noaudio" /boot/firmware/config.txt; then
    echo "dtoverlay=vc4-kms-v3d,noaudio" >> /boot/firmware/config.txt
fi
echo "✓ Audio settings configured"

# Configure display rotation for 180 degrees
echo "Configuring display rotation for 180 degrees..."
if ! grep -q "^display_rotate=2" /boot/firmware/config.txt; then
    # Remove any existing display_rotate lines
    sed -i '/^display_rotate=/d' /boot/firmware/config.txt
    # Add 180-degree rotation
    echo "display_rotate=2" >> /boot/firmware/config.txt
    echo "✓ Display rotation set to 180 degrees in config.txt"
else
    echo "✓ Display rotation already configured for 180 degrees"
fi

step_header "STEP 3/18: Install Dependencies"
echo "Installing build tools and audio dependencies..."

# Audio performance optimizations
echo "Configuring audio performance optimizations..."

# Set CPU governor to performance mode for better real-time performance
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [ -f "$cpu" ]; then
        echo "performance" > "$cpu" 2>/dev/null || true
    fi
done
echo "✓ CPU governor set to performance mode"

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
    "flac"
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

step_header "STEP 4/18: Clone SuperCollider"
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

step_header "STEP 5/18: Build SuperCollider"
echo "Configuring build (this may take a few minutes)..."
if cmake -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF -DSC_EL=OFF -DSC_VIM=ON \
    -DNATIVE=ON -DSC_IDE=OFF -DNO_X11=ON -DSC_QT=ON .. > /dev/null 2>&1; then
    echo "✓ Configuration successful"
else
    echo "✗ Configuration failed"
    exit 1
fi

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

echo -n "Installing SuperCollider "
make install >> $INSTALL_LOG 2>&1 &
INSTALL_PID=$!
while kill -0 $INSTALL_PID 2>/dev/null; do
    echo -n "."
    sleep 1
done
echo " done"
wait $INSTALL_PID
if [ $? -eq 0 ]; then
    echo "✓ SuperCollider installed"
    ldconfig >> $INSTALL_LOG 2>&1
else
    echo "✗ Installation failed - check $INSTALL_LOG"
    exit 1
fi

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

echo -n "Installing SC3 Plugins "
cmake --build . --config Release --target install >> $INSTALL_LOG 2>&1 &
INSTALL_PID=$!
while kill -0 $INSTALL_PID 2>/dev/null; do
    echo -n "."
    sleep 1
done
echo " done"
wait $INSTALL_PID
if [ $? -eq 0 ]; then
    echo "✓ SC3 Plugins installed"
else
    echo "✗ SC3 Plugins installation failed - check $INSTALL_LOG"
    exit 1
fi

step_header "STEP 6/18: Setting up Audio and Device Permissions"
echo "Setting up device permissions..."
cat > /etc/udev/rules.d/99-phonorama.rules << 'EOF'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="plugdev", MODE="0660"
SUBSYSTEM=="audio", MODE="0666"
EOF

echo "Configuring audio groups and permissions..."
cat > /home/$ACTUAL_USER/.jackdrc << 'EOF'
# USB Turntable JACK configuration - will be overridden by audio setup script
/usr/bin/jackd -P75 -d alsa -r 44100 -p 1024 -n 3 -S &
EOF
usermod -aG audio,plugdev $ACTUAL_USER > /dev/null 2>&1
echo "✓ Audio configuration complete"

step_header "STEP 7/18: Setting up SuperCollider Environment"
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
echo -n "Installing ATK quark "
sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");
0.exit;
EOF' >> $INSTALL_LOG 2>&1 &
QUARK_PID=$!
while kill -0 $QUARK_PID 2>/dev/null; do
    echo -n "."
    sleep 1
done
wait $QUARK_PID
if [ $? -eq 0 ]; then
    echo "✓ ATK quark installed"
else
    echo "✗ ATK quark installation failed - check $INSTALL_LOG"
    exit 1
fi

# Install AmbiVerbSC using Quark system
echo -n "Installing AmbiVerbSC quark "
sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.install("https://github.com/JamesWenlock/AmbiVerbSC");
0.exit;
EOF' >> $INSTALL_LOG 2>&1 &
QUARK_PID=$!
while kill -0 $QUARK_PID 2>/dev/null; do
    echo -n "."
    sleep 1
done
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

# Move ATK dependencies from downloaded-quarks to Extensions
echo "Moving ATK dependencies to Extensions..."
cd /home/$ACTUAL_USER/.local/share/SuperCollider
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

sudo chown -R $ACTUAL_USER:$ACTUAL_USER Extensions/
cd /home/$ACTUAL_USER


CUSTOM_EXT_SRC="/home/$ACTUAL_USER/UHJ-Pi/supercollider/extensions"
SC_EXT_DST="/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions"
ATK_BASE="/home/$ACTUAL_USER/.local/share/ATK"

echo "Installing custom SuperCollider extensions..."
sudo -u $ACTUAL_USER mkdir -p "$SC_EXT_DST"
sudo -u $ACTUAL_USER mkdir -p "$ATK_BASE"

EXTENSION_DIRS=(
    "ServerMeter2"
    "Knob360"
    "MaplinMatrix"
    "FoaDimension"
    "FoaZSynthesis"
    "SFPlayerMeter"
    "SFPlayerClass"
)

for ext_dir in "${EXTENSION_DIRS[@]}"; do
    if [ -d "$CUSTOM_EXT_SRC/$ext_dir" ]; then
        echo "Installing $ext_dir..."
        rm -rf "$SC_EXT_DST/$ext_dir"
        cp -r "$CUSTOM_EXT_SRC/$ext_dir" "$SC_EXT_DST/"
    else
        echo "WARNING: Extension directory $ext_dir not found, skipping"
    fi
done

for ext_file in "ATK.sc" "FoaMatrix.sc"; do
    if [ -f "$CUSTOM_EXT_SRC/$ext_file" ]; then
        echo "Patching $ext_file in atk-sc3..."
        sudo -u $ACTUAL_USER mkdir -p "$SC_EXT_DST/atk-sc3/Classes"
        cp "$CUSTOM_EXT_SRC/$ext_file" "$SC_EXT_DST/atk-sc3/Classes/$ext_file"
    fi
done

sudo chown -R $ACTUAL_USER:$ACTUAL_USER "$SC_EXT_DST"
sudo chown -R $ACTUAL_USER:$ACTUAL_USER "$ATK_BASE"

cd /home/$ACTUAL_USER/.local/share/ATK

# STEP 13: Install Custom UHJ Test Sounds
# Custom UHJ test sounds will be installed after ATK sounds (step 10)

# STEP 14: Install custom user classes
step_header "STEP 8/18: Installing Custom User Classes"
echo "Installing custom user classes..."
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

# Install SFPlayerMeter and SFPlayer extensions
for ext_dir in SFPlayerMeter SFPlayerClass; do
    if [ ! -d "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/$ext_dir" ]; then
        echo "Installing $ext_dir..."
        cp -r "$ext_dir" "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/"
        echo "$ext_dir installation completed"
else
        echo "$ext_dir already exists, skipping"
fi
done

# Set proper ownership
chown -R $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/

# STEP 10: Install ATK kernels and matrices
step_header "STEP 9/18: Installing ATK Kernels and Matrices"
echo "Downloading ATK kernels and matrices..."
cd /home/$ACTUAL_USER/.local/share/ATK

# Download kernels
echo "Downloading ATK kernels v1.2.1..."
if sudo -u $ACTUAL_USER curl -L "https://github.com/ambisonictoolkit/atk-kernels/releases/download/v1.2.1/kernels.zip" -o kernels.zip; then
    # Verify the download is a valid ZIP file
    if ! sudo -u $ACTUAL_USER unzip -t kernels.zip >/dev/null 2>&1; then
        echo "✗ ATK kernels download appears corrupted - retrying..."
        sudo -u $ACTUAL_USER rm -f kernels.zip
        if sudo -u $ACTUAL_USER curl -L "https://github.com/ambisonictoolkit/atk-kernels/releases/download/v1.2.1/kernels.zip" -o kernels.zip; then
            if ! sudo -u $ACTUAL_USER unzip -t kernels.zip >/dev/null 2>&1; then
                echo "✗ ATK kernels download still corrupted after retry!"
                exit 1
            fi
        else
            echo "✗ ATK kernels download failed on retry!"
            exit 1
        fi
    fi
    echo "Extracting kernels..."
    if sudo -u $ACTUAL_USER unzip -q -o kernels.zip; then
        sudo -u $ACTUAL_USER rm kernels.zip
        echo "✓ ATK kernels installed"
    else
        echo "✗ ATK kernels extraction failed!"
        exit 1
    fi
else
    echo "✗ ATK kernels download failed!"
    exit 1
fi

# Download matrices  
echo "Downloading ATK matrices v1.0.3..."
if sudo -u $ACTUAL_USER curl -L "https://github.com/ambisonictoolkit/atk-matrices/releases/download/v1.0.3/matrices.zip" -o matrices.zip; then
    # Verify the download is a valid ZIP file
    if ! sudo -u $ACTUAL_USER unzip -t matrices.zip >/dev/null 2>&1; then
        echo "✗ ATK matrices download appears corrupted - retrying..."
        sudo -u $ACTUAL_USER rm -f matrices.zip
        if sudo -u $ACTUAL_USER curl -L "https://github.com/ambisonictoolkit/atk-matrices/releases/download/v1.0.3/matrices.zip" -o matrices.zip; then
            if ! sudo -u $ACTUAL_USER unzip -t matrices.zip >/dev/null 2>&1; then
                echo "✗ ATK matrices download still corrupted after retry!"
                exit 1
            fi
        else
            echo "✗ ATK matrices download failed on retry!"
            exit 1
        fi
    fi
    echo "Extracting matrices..."
    if sudo -u $ACTUAL_USER unzip -q -o matrices.zip; then
        sudo -u $ACTUAL_USER rm matrices.zip
        echo "✓ ATK matrices installed"
    else
        echo "✗ ATK matrices extraction failed!"
        exit 1
    fi
else
    echo "✗ ATK matrices download failed!"
    exit 1
fi

# Download ATK sounds (complete repository)
echo "Downloading ATK sounds repository..."
cd /tmp
if curl -s -L "https://github.com/ambisonictoolkit/atk-sounds/archive/refs/heads/master.zip" -o atk-sounds.zip; then
    echo "Extracting sounds..."
    sudo -u $ACTUAL_USER unzip -q -o atk-sounds.zip
    sudo -u $ACTUAL_USER cp -r atk-sounds-master/* /home/$ACTUAL_USER/.local/share/ATK/
    sudo -u $ACTUAL_USER rm -rf atk-sounds-master
    rm -f atk-sounds.zip
    echo "✓ ATK sounds installed"
    
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

# Re-apply patched FOA kernels and matrices (overwrites any stock files)
FOA_KERNEL_SRC="$CUSTOM_EXT_SRC/kernels/FOA"
FOA_KERNEL_DST="$ATK_BASE/kernels/FOA"
if [ -d "$FOA_KERNEL_SRC" ]; then
    echo "Reinstating custom FOA kernels..."
    sudo -u $ACTUAL_USER mkdir -p "$FOA_KERNEL_DST"
    sudo -u $ACTUAL_USER bash -c "cp -R \"$FOA_KERNEL_SRC\"/* \"$FOA_KERNEL_DST/\""
fi

FOA_MATRIX_SRC="$CUSTOM_EXT_SRC/matrices/FOA"
FOA_MATRIX_DST="$ATK_BASE/matrices/FOA"
if [ -d "$FOA_MATRIX_SRC" ]; then
    echo "Reinstating custom FOA matrices..."
    sudo -u $ACTUAL_USER mkdir -p "$FOA_MATRIX_DST"
    sudo -u $ACTUAL_USER bash -c "cp -R \"$FOA_MATRIX_SRC\"/* \"$FOA_MATRIX_DST/\""
fi

# ATK classes are now properly located in Extensions

# Return to ATK directory for custom sounds
cd /home/$ACTUAL_USER/.local/share/ATK

# STEP 10: Install Custom UHJ Test Sounds (after ATK sounds are downloaded and sounds/ directory exists)
step_header "STEP 10/18: Installing Custom UHJ Test Sounds"
echo "Installing custom UHJ test sounds..."
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/AJH_eight-positions-uhj.wav /home/$ACTUAL_USER/.local/share/ATK/
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/hifi_sound_1981_ambisonic_tests.wav /home/$ACTUAL_USER/.local/share/ATK/
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/Sodium_Sunrise_UHJ.wav /home/$ACTUAL_USER/.local/share/ATK/
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/UHJ_Mono_Pink_Noise_North.wav /home/$ACTUAL_USER/.local/share/ATK/
echo "Custom UHJ test sounds installed successfully"

# Move custom sounds to sounds subdirectory (now that it exists from ATK sounds download)
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

# Ensure demo library exists
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/ATK/sounds/uhj/Various
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/ATK/sounds/uhj/Rhombus

# Copy demo content
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/AJH_eight-positions-uhj.wav /home/$ACTUAL_USER/.local/share/ATK/sounds/uhj/Various/ 2>/dev/null || true
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/hifi_sound_1981_ambisonic_tests.wav /home/$ACTUAL_USER/.local/share/ATK/sounds/uhj/Various/ 2>/dev/null || true
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/UHJ_Mono_Pink_Noise_North.wav /home/$ACTUAL_USER/.local/share/ATK/sounds/uhj/Various/ 2>/dev/null || true

sudo -u $ACTUAL_USER cp "/home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/Sodium Sunrise.wav" /home/$ACTUAL_USER/.local/share/ATK/sounds/uhj/Rhombus/ 2>/dev/null || true
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/Sodium_Sunrise_UHJ.wav /home/$ACTUAL_USER/.local/share/ATK/sounds/uhj/Rhombus/ 2>/dev/null || true
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/artwork_sodium_sunrise.jpg /home/$ACTUAL_USER/.local/share/ATK/sounds/uhj/Rhombus/ 2>/dev/null || true
if [ ! -f /home/$ACTUAL_USER/.local/share/ATK/sounds/uhj/Rhombus/artwork.jpg ]; then
    sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/artwork.jpg /home/$ACTUAL_USER/.local/share/ATK/sounds/uhj/Rhombus/ 2>/dev/null || true
fi

# STEP 13: Install UHJ-Pi application files
step_header "STEP 11/18: Installing UHJ-Pi Application Files"
echo "Installing UHJ-Pi application files..."
cd /home/$ACTUAL_USER/UHJ-Pi/supercollider/app
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/UHJ-Pi/
sudo -u $ACTUAL_USER cp *.scd /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/UHJ-Pi/
echo "✓ UHJ-Pi application files installed"

# STEP 14: Configure JACK audio
step_header "STEP 12/18: Configuring JACK Audio"
echo "Configuring JACK audio..."
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.config/jack
cat > /home/$ACTUAL_USER/.config/jack/jackdrc << 'EOF'
/usr/bin/jackd -P75 -d alsa -r 44100 -p 1024 -n 3 -S
EOF
echo "✓ JACK configuration complete"

# STEP 15: Configure ALSA
step_header "STEP 13/18: Configuring ALSA"
echo "Configuring ALSA..."
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.asoundrc
cat > /home/$ACTUAL_USER/.asoundrc << 'EOF'
pcm.!default {
    type hw
    card 0
}
ctl.!default {
    type hw
    card 0
}
EOF
echo "✓ ALSA configuration complete"

# STEP 16: Configure Bluetooth
step_header "STEP 14/18: Configuring Bluetooth"
echo "Configuring Bluetooth..."
systemctl enable bluetooth >> $INSTALL_LOG 2>&1
systemctl start bluetooth >> $INSTALL_LOG 2>&1
echo "✓ Bluetooth configured"

# STEP 17: Configure Qt platform for headless operation
step_header "STEP 15/18: Configuring Qt Platform for Headless Operation"
echo "Configuring Qt platform for headless operation..."
# Set Qt platform to eglfs for the user's shell
echo 'export QT_QPA_PLATFORM=eglfs' >> /home/$ACTUAL_USER/.bashrc
echo 'export QT_QPA_PLATFORM=eglfs' >> /home/$ACTUAL_USER/.profile
# Clear X11 display variable to force EGLFS
echo 'unset DISPLAY' >> /home/$ACTUAL_USER/.bashrc
echo 'unset DISPLAY' >> /home/$ACTUAL_USER/.profile
echo "✓ Qt platform configured for headless operation"

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
step_header "STEP 16/18: Installing Bluetooth Pairing Scripts"
echo "Installing Bluetooth pairing scripts..."
cp /home/$ACTUAL_USER/UHJ-Pi/ble-ht.sh /usr/local/bin/
chmod +x /usr/local/bin/ble-ht.sh
chown $ACTUAL_USER:$ACTUAL_USER /usr/local/bin/ble-ht.sh
echo "✓ Bluetooth pairing script (ble-ht.sh) installed to /usr/local/bin/"

# Also install auto_pair_headtracker.sh if it exists
if [ -f "/home/$ACTUAL_USER/UHJ-Pi/auto_pair_headtracker.sh" ]; then
    cp /home/$ACTUAL_USER/UHJ-Pi/auto_pair_headtracker.sh /usr/local/bin/
    chmod +x /usr/local/bin/auto_pair_headtracker.sh
    chown $ACTUAL_USER:$ACTUAL_USER /usr/local/bin/auto_pair_headtracker.sh
    echo "✓ Auto pairing script (auto_pair_headtracker.sh) installed to /usr/local/bin/"
fi

# Configure passwordless sudo for reboot
echo "Configuring passwordless sudo for reboot..."
echo "$ACTUAL_USER ALL=(ALL) NOPASSWD: /sbin/reboot" >> /etc/sudoers.d/uhj-pi-reboot
chmod 440 /etc/sudoers.d/uhj-pi-reboot
echo "✓ Passwordless reboot configured"

# Configure automatic login
echo "Configuring automatic login..."
if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
    echo "Automatic login already configured"
else
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $ACTUAL_USER --noclear %I \$TERM
EOF
    systemctl enable getty@tty1.service
    echo "✓ Automatic login configured for user $ACTUAL_USER"
fi

# STEP 23: Install launcher script
step_header "STEP 17/18: Installing Launcher Script"
echo "Installing launcher script..."

echo "Installing USB mounting script..."
cp /home/$ACTUAL_USER/UHJ-Pi/mount-usb.sh /usr/local/bin/mount-usb
chmod +x /usr/local/bin/mount-usb
chown $ACTUAL_USER:$ACTUAL_USER /usr/local/bin/mount-usb
echo "✓ USB mounting script installed to /usr/local/bin/mount-usb"

cp /home/$ACTUAL_USER/UHJ-Pi/start-player.sh /usr/local/bin/start
chmod +x /usr/local/bin/start
chown $ACTUAL_USER:$ACTUAL_USER /usr/local/bin/start
echo "Launcher script installed to /usr/local/bin/start"

step_header "STEP 18/18: Configuring Screen and Touch Orientation (180 degrees)"
echo "Configuring screen and touch for 180-degree rotation..."

# Force 180-degree display rotation
ROTATION_VALUE="180"
echo "✓ Display rotation set to 180 degrees (flipped)"

# Set display rotation for Qt/EGLFS
echo "export QT_QPA_EGLFS_ROTATION=$ROTATION_VALUE" >> /home/$ACTUAL_USER/.bashrc
echo "export QT_QPA_EGLFS_ROTATION=$ROTATION_VALUE" >> /home/$ACTUAL_USER/.profile

# Configure touch screen rotation via libinput calibration matrix
# For 180-degree rotation: invert X and Y, translate by screen dimensions
# Matrix format: "a b c d e f" where a=-1, e=-1 for 180° rotation
# Using normalized coordinates (0-1), so translation is 1 for full width/height
echo "Configuring touch screen rotation..."

# Set environment variable in user profile files
echo "export LIBINPUT_CALIBRATION_MATRIX=\"-1 0 1 0 -1 1\"" >> /home/$ACTUAL_USER/.bashrc
echo "export LIBINPUT_CALIBRATION_MATRIX=\"-1 0 1 0 -1 1\"" >> /home/$ACTUAL_USER/.profile

# Create system-wide environment file for early loading
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/touch-rotation.conf << EOF
[Manager]
DefaultEnvironment="LIBINPUT_CALIBRATION_MATRIX=-1 0 1 0 -1 1"
EOF

# Create libinput quirks file for touch calibration (most reliable method)
mkdir -p /etc/libinput
cat > /etc/libinput/local-overrides.quirks << EOF
[UHJ-Pi Touch 180 Rotation]
MatchName=*
MatchUSBID=*:*
AttrCalibrationMatrix=-1 0 1 0 -1 1
EOF
echo "✓ Created libinput quirks file for touch calibration"

# Also add to /etc/environment for system-wide access
if ! grep -q "LIBINPUT_CALIBRATION_MATRIX" /etc/environment 2>/dev/null; then
    echo 'LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"' >> /etc/environment
    echo "✓ Added to /etc/environment"
fi

# Create comprehensive udev rule that matches all input devices
echo "Creating comprehensive udev rules..."
# First create a broad rule that matches all input devices
cat > /etc/udev/rules.d/99-touchscreen-rotation-180.rules << 'EOF'
# UHJ-Pi: Touch screen 180-degree rotation
# This rule applies to all input devices that could be touch screens
# Calibration matrix for 180-degree rotation: invert X and Y
# Matrix format: "a b c d e f" = "-1 0 1 0 -1 1"

# Match any input device (broad rule)
ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ENV{LIBINPUT_CALIBRATION_MATRIX}="-1 0 1 0 -1 1"
EOF

# Also add device-specific rules for detected devices
INPUT_DEVICES=()
for dev in /dev/input/event*; do
    if [ -e "$dev" ]; then
        INPUT_DEVICES+=("$dev")
    fi
done

RULE_COUNT=0
for dev in "${INPUT_DEVICES[@]}"; do
    VENDOR_ID=$(udevadm info "$dev" 2>/dev/null | grep -i "id_vendor" | cut -d'=' -f2 | head -1)
    PRODUCT_ID=$(udevadm info "$dev" 2>/dev/null | grep -i "id_product" | cut -d'=' -f2 | head -1)
    DEVICE_NAME=$(udevadm info "$dev" 2>/dev/null | grep -i "name=" | cut -d'=' -f2 | tr -d '"' | head -1)
    
    if [ -n "$VENDOR_ID" ] && [ -n "$PRODUCT_ID" ]; then
        cat >> /etc/udev/rules.d/99-touchscreen-rotation-180.rules << EOF

# Device-specific rule: $DEVICE_NAME
ACTION=="add", SUBSYSTEM=="input", ATTRS{idVendor}=="$VENDOR_ID", ATTRS{idProduct}=="$PRODUCT_ID", ENV{LIBINPUT_CALIBRATION_MATRIX}="-1 0 1 0 -1 1"
EOF
        RULE_COUNT=$((RULE_COUNT + 1))
    fi
done

echo "✓ Created comprehensive udev rule with $RULE_COUNT device-specific rules"

# Also update the startup script to export the environment variable before launching sclang
if [ -f "/home/$ACTUAL_USER/UHJ-Pi/start-player.sh" ]; then
    # Add export right before sclang launch if not already present
    if ! grep -q "LIBINPUT_CALIBRATION_MATRIX" "/home/$ACTUAL_USER/UHJ-Pi/start-player.sh"; then
        sed -i '/^sclang/i export LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"' "/home/$ACTUAL_USER/UHJ-Pi/start-player.sh"
        echo "✓ Updated start-player.sh to export touch calibration matrix before launching sclang"
    fi
fi

echo "✓ Screen and touch orientation configured for 180 degrees"

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎵 UHJ-Pi Player Installation Complete! 🎵"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Audio System:"
echo "   • Player-focused USB audio device detection and configuration"
echo "   • Automatic input/output device pairing"
echo "   • Software input gain control when available"
echo "   • JACK audio server with stable 1024-frame buffers"
echo "   • Optimized for turntable input + any USB audio output"
echo ""
echo "✅ SuperCollider:"
echo "   • SuperCollider with Qt GUI support"
echo "   • ATK (Ambisonic Toolkit) + AmbiVerbSC extensions"
echo "   • UHJ decoder with headtracker pairing support"
echo ""
echo "✅ Ready to use:"
echo "   • Launcher: /usr/local/bin/start (Player)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 INSTALLATION COMPLETE - REBOOT REQUIRED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "After reboot, log in and run: start"
echo ""
echo "The first time you run 'start', it will help you configure your"
echo "audio input and output devices. After that, just run 'start'"
echo "whenever you want to use the UHJ-Pi application."
echo ""
echo -n "Press any key to reboot... "
read -n 1

echo ""
echo "Rebooting now..."
sync
echo b > /proc/sysrq-trigger
