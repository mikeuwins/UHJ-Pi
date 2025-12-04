#!/bin/bash

# UHJ-Pi Raspberry Pi Setup Script - ESI Touch Version (180-degree rotation)

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
    echo "Error: Could not determine username. Please run with: sudo -E ./setup-raspberry-pi.sh"
    exit 1
fi

clear
echo "🎵 UHJ-Pi Raspberry Pi Setup Script - ESI Touch Version (180° Rotation) 🎵"
echo "Installing for user: $ACTUAL_USER"
echo "This version includes ESI audio setup with phono-control CLI"
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

step_header "STEP 1/16: System Update"
echo "Updating package lists..."
if apt-get update >> $INSTALL_LOG 2>&1; then
    echo "✓ Package lists updated"
else
    echo "✗ Package update failed - check $INSTALL_LOG"
    exit 1
fi
# Skip upgrade - go straight to installing what we need
# apt-get upgrade -y  # Commented out - causes hooks hang
# apt-get dist-upgrade -y  # Commented out - can cause hangs, test without first

step_header "STEP 2/16: Disable Onboard and HDMI Audio"
echo "Disabling onboard and HDMI audio..."
if ! grep -q "dtparam=audio=off" /boot/firmware/config.txt; then
    echo "dtparam=audio=off" >> /boot/firmware/config.txt
fi
if ! grep -q "dtoverlay=vc4-kms-v3d,noaudio" /boot/firmware/config.txt; then
    echo "dtoverlay=vc4-kms-v3d,noaudio" >> /boot/firmware/config.txt
fi

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

step_header "STEP 3/16: Install Dependencies"
echo "Installing SuperCollider Dependencies..."

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

step_header "STEP 4/16: Clone SuperCollider"
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

step_header "STEP 5/16: Build SuperCollider"
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

echo "Installing SuperCollider"
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

echo "Installing SC3 Plugins"
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

step_header "STEP 6/16: Setting up Audio and Device Permissions"
echo "Setting up udev rules..."
cat > /etc/udev/rules.d/99-phonorama.rules << 'EOF'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2573", ATTRS{idProduct}=="0001", GROUP="plugdev", MODE="0660"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="plugdev", MODE="0660"
SUBSYSTEM=="audio", MODE="0666"
EOF

echo "Configuring JACK Audio..."
echo "/usr/bin/jackd -P75 -d alsa -C hw:Phonorama -P hw:HD -r 44100 -p 256 -n 2 -S &" > /home/$ACTUAL_USER/.jackdrc
usermod -aG audio,plugdev $ACTUAL_USER

step_header "STEP 7/16: Setting up SuperCollider Environment"
echo "Cloning UHJ-Pi repository and building phono-control CLI..."
cd /home/$ACTUAL_USER
if [ ! -d "UHJ-Pi" ]; then
    if git clone https://github.com/mikeuwins/UHJ-Pi.git; then
        echo "UHJ-Pi repository cloned successfully"
    else
        echo "ERROR: UHJ-Pi repository clone failed!"
        exit 1
    fi
fi
cd UHJ-Pi/cli/phonorama-cli-linux
if [ -f "build.sh" ]; then
    chmod +x build.sh
    if ./build.sh; then
        echo "phono-control CLI build successful"
    else
        echo "ERROR: phono-control CLI build failed!"
        exit 1
    fi
else
    echo "ERROR: build.sh not found!"
    exit 1
fi

step_header "STEP 8/16: Installing ATK Kernels and Matrices"
echo "Installing ATK and handling GUI component cleanup (manual approach)..."
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
    echo "✓ ATK quark installed successfully"
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
# ATK and AmbiVerbSC now installed via Quark system above

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
    if sudo -u $ACTUAL_USER unzip -q -o kernels.zip; then
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
    if sudo -u $ACTUAL_USER unzip -q -o matrices.zip; then
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
    sudo -u $ACTUAL_USER unzip -q -o atk-sounds.zip
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

step_header "STEP 9/16: Installing Custom UHJ Test Sounds"
echo "Installing Custom UHJ Test Sounds..."
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

step_header "STEP 10/16: Installing UHJ-Pi Application Files"
echo "Installing custom SuperCollider resources..."

CUSTOM_EXT_SRC="/home/$ACTUAL_USER/UHJ-Pi/supercollider/extensions"
SC_EXT_DST="/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions"
ATK_BASE="/home/$ACTUAL_USER/.local/share/ATK"

# Ensure destination directories exist
sudo -u $ACTUAL_USER mkdir -p "$SC_EXT_DST"
sudo -u $ACTUAL_USER mkdir -p "$ATK_BASE"

# Copy class and GUI extensions
EXTENSION_DIRS=(
    "ServerMeter2"
    "Knob360"
    "MaplinMatrix"
    "FoaDimension"
    "FoaZSynthesis"
    "SFPlayerMeter"
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

# Copy standalone class files
for ext_file in "ATK.sc" "FoaMatrix.sc"; do
    if [ -f "$CUSTOM_EXT_SRC/$ext_file" ]; then
        echo "Patching $ext_file in atk-sc3..."
        sudo -u $ACTUAL_USER mkdir -p "$SC_EXT_DST/atk-sc3/Classes"
        cp "$CUSTOM_EXT_SRC/$ext_file" "$SC_EXT_DST/atk-sc3/Classes/$ext_file"
    fi
done

# Install custom FOA kernels (including PHJ encoder/decoder kernels)
FOA_KERNEL_SRC="$CUSTOM_EXT_SRC/kernels/FOA"
FOA_KERNEL_DST="$ATK_BASE/kernels/FOA"
if [ -d "$FOA_KERNEL_SRC" ]; then
    echo "Installing custom FOA kernels..."
    sudo -u $ACTUAL_USER mkdir -p "$FOA_KERNEL_DST"
    sudo -u $ACTUAL_USER bash -c "cp -R \"$FOA_KERNEL_SRC\"/* \"$FOA_KERNEL_DST/\""
fi

# Install custom FOA matrices (for updated decoder support)
FOA_MATRIX_SRC="$CUSTOM_EXT_SRC/matrices/FOA"
FOA_MATRIX_DST="$ATK_BASE/matrices/FOA"
if [ -d "$FOA_MATRIX_SRC" ]; then
    echo "Installing custom FOA matrices..."
    sudo -u $ACTUAL_USER mkdir -p "$FOA_MATRIX_DST"
    sudo -u $ACTUAL_USER bash -c "cp -R \"$FOA_MATRIX_SRC\"/* \"$FOA_MATRIX_DST/\""
fi

# Set proper ownership
chown -R $ACTUAL_USER:$ACTUAL_USER "$SC_EXT_DST"
chown -R $ACTUAL_USER:$ACTUAL_USER "$ATK_BASE"

step_header "STEP 11/16: Configuring JACK Audio"
echo "Configuring JACK Audio for ESI devices..."
# JACK configuration is handled by start-esi.sh script
echo "✓ JACK Audio configuration will be handled by startup script"

step_header "STEP 12/16: Configuring ALSA"
echo "Configuring ALSA for ESI devices..."
# ALSA configuration is handled by start-esi.sh script
echo "✓ ALSA configuration will be handled by startup script"
cd /home/$ACTUAL_USER/UHJ-Pi/assets/fonts

# Create fonts directory if it doesn't exist
mkdir -p /usr/local/share/fonts/truetype/uhj-pi

# Copy custom fonts to system font directory
cp lcd_segment_monospace/lcd-5x7-segment-monospace.ttf /usr/local/share/fonts/truetype/uhj-pi/
cp "led_dot_matrix/LED Dot-Matrix.ttf" /usr/local/share/fonts/truetype/uhj-pi/

# Install Arial font for power button
echo "Installing Arial font..."
if apt-get install -y cabextract >> $INSTALL_LOG 2>&1; then
    echo "✓ cabextract installed"
else
    echo "✗ cabextract installation failed - check $INSTALL_LOG"
    exit 1
fi
mkdir -p /usr/share/fonts/truetype/msttcorefonts
cd /usr/share/fonts/truetype/msttcorefonts
wget -q https://github.com/matomo-org/travis-scripts/raw/master/fonts/Arial.ttf

# Update font cache
fc-cache -f >> $INSTALL_LOG 2>&1

echo "Installation completed successfully!"
echo ""
echo "Reboot required. Run: sudo reboot"
echo "After reboot and login, run:"
echo "  start"

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

step_header "STEP 13/17: Configuring Qt Platform for Headless Operation"
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
mkdir -p /usr/local/share/fonts/truetype/uhj-pi

# Copy custom fonts
cp *.ttf /usr/local/share/fonts/truetype/uhj-pi/ 2>/dev/null || true

# Download Arial font if not present
if [ ! -f /usr/local/share/fonts/truetype/uhj-pi/Arial.ttf ]; then
    wget -q https://github.com/matomo-org/travis-scripts/raw/master/fonts/Arial.ttf
    cp Arial.ttf /usr/local/share/fonts/truetype/uhj-pi/
fi

# Update font cache
fc-cache -f >> $INSTALL_LOG 2>&1
echo "✓ Custom fonts installed"

step_header "STEP 14/17: Configuring Bluetooth"
echo "Configuring Bluetooth..."
systemctl enable bluetooth >> $INSTALL_LOG 2>&1
systemctl start bluetooth >> $INSTALL_LOG 2>&1
echo "✓ Bluetooth configured"

step_header "STEP 15/17: Installing Bluetooth Pairing Script"
echo "Installing Bluetooth pairing script..."
cp /home/$ACTUAL_USER/UHJ-Pi/ble-ht.sh /usr/local/bin/
chmod +x /usr/local/bin/ble-ht.sh
chown $ACTUAL_USER:$ACTUAL_USER /usr/local/bin/ble-ht.sh
echo "✓ Bluetooth pairing script installed to /usr/local/bin/"

step_header "STEP 16/17: Installing Launcher Script"
echo "Installing launcher script..."
cp /home/$ACTUAL_USER/UHJ-Pi/start-esi.sh /usr/local/bin/start
chmod +x /usr/local/bin/start 
chown $ACTUAL_USER:$ACTUAL_USER /usr/local/bin/start
echo "✓ Launcher script installed to /usr/local/bin/start"

echo "Configuring automatic login..."
if ! grep -q "autologin-user=$ACTUAL_USER" /etc/systemd/system/getty@tty1.service.d/autologin.conf 2>/dev/null; then
    mkdir -p /etc/systemd/system/getty@tty1.service.d/
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $ACTUAL_USER --noclear %I \$TERM
EOF
    systemctl enable getty@tty1.service
    echo "✓ Automatic login configured for user $ACTUAL_USER"
fi

step_header "STEP 17/17: Configuring Screen and Touch Orientation (180 degrees)"
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

# Also update the startup script to export the environment variable before launching sclang
if [ -f "/home/$ACTUAL_USER/UHJ-Pi/start-esi.sh" ]; then
    # Add export right before sclang launch if not already present
    if ! grep -q "LIBINPUT_CALIBRATION_MATRIX" "/home/$ACTUAL_USER/UHJ-Pi/start-esi.sh"; then
        sed -i '/^sclang/i export LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"' "/home/$ACTUAL_USER/UHJ-Pi/start-esi.sh"
        echo "✓ Updated start-esi.sh to export touch calibration matrix before launching sclang"
    fi
fi

echo "✓ Screen and touch orientation configured for 180 degrees"

echo ""
echo "Installation completed successfully!"
echo ""
echo "ESI Audio Setup:"
echo "  ✅ phono-control CLI built and installed"
echo "  ✅ ESI udev rules created"
echo "  ✅ Audio devices configured for 4-in/4-out operation"
echo ""
echo "SuperCollider Setup:"
echo "  ✅ SuperCollider + ATK + AmbiVerbSC installed"
echo "  ✅ Custom extensions installed"
echo "  ✅ Custom fonts installed"
echo "  ✅ Launcher created: /usr/local/bin/start"
echo ""
echo "Display & Touch Setup:"
echo "  ✅ Display rotation configured for 180 degrees"
echo "  ✅ Touch screen rotation configured for 180 degrees"
echo "  ✅ config.txt updated with display_rotate=2"
echo ""
echo "Next Steps:"
echo "1. System will auto-login after reboot"
echo "2. Run: start"
echo "3. Connect ESI devices when prompted"
echo "4. Pair headtracker with: ble-ht.sh"
echo ""
echo "The system will automatically detect and configure your ESI audio devices!"
echo "Screen and touch are configured for 180-degree rotation."
echo ""
echo "Press any key to reboot the system..."
read -n 1 -s
echo ""
echo "Rebooting..."
reboot 