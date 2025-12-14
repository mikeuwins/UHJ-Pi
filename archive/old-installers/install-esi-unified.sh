#!/bin/bash

# UHJ-Pi Unified Intelligent Setup Script
# Automatically detects display type and configures optimal settings
# Supports: Touch Screen, HDMI Monitor, and Headless configurations
# Based on install-esi-touch-hybrid.sh with latest SuperCollider fixes
# Updated: August 2025

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Get the actual username (the user who ran sudo)
ACTUAL_USER=${SUDO_USER:-$(logname)}
if [ -z "$ACTUAL_USER" ]; then
    echo "Error: Could not determine username. Please run with: sudo -E ./install-esi-unified.sh"
    exit 1
fi

echo "UHJ-Pi Unified Intelligent Setup Script"
echo "Automatically detecting display configuration..."
echo "Installing for user: $ACTUAL_USER"

# ============================================================================
# RUNTIME DETECTION INFRASTRUCTURE SETUP
# ============================================================================

echo "Phase 1: Setting up runtime display detection infrastructure..."

# Create the runtime detection script
cat > /usr/local/bin/detect-display.sh << 'EOF'
#!/bin/bash

# UHJ-Pi Runtime Display Detection Script
# Runs on every boot to automatically configure optimal display settings

# Get the actual username
ACTUAL_USER=$(logname 2>/dev/null || echo "pi")
if [ -z "$ACTUAL_USER" ] || [ "$ACTUAL_USER" = "root" ]; then
    ACTUAL_USER="pi"
fi

# Function to detect display type
detect_display_type() {
    # Check for touch screen overlays in boot config
    if grep -q "dtoverlay.*lcd\|dtoverlay.*touch" /boot/firmware/config.txt 2>/dev/null; then
        echo "touch"
        return 0
    fi

    # Check for HDMI connection
    if command -v tvservice >/dev/null 2>&1; then
        if tvservice -n 2>/dev/null | grep -q "HDMI"; then
            echo "hdmi"
            return 0
        fi
    fi

    # Check for HDMI in sysfs
    if [ -e /sys/class/drm/card0-HDMI-A-1 ] || [ -e /sys/class/drm/card0-HDMI-A-2 ]; then
        echo "hdmi"
        return 0
    fi

    # Default to touch if no specific display detected
    echo "touch"
    return 0
}

# Function to configure display
configure_display() {
    local display_type=$1
    
    case $display_type in
        "touch")
            echo "Configuring for Touch Screen + EGLFS..."
            export QT_QPA_PLATFORM=eglfs
            export QT_QPA_EGLFS_PHYSICAL_WIDTH=800
            export QT_QPA_EGLFS_PHYSICAL_HEIGHT=480
            unset DISPLAY
            ;;
        "hdmi")
            echo "Configuring for HDMI Monitor + EGLFS..."
            export QT_QPA_PLATFORM=eglfs
            export QT_QPA_EGLFS_PHYSICAL_WIDTH=1920
            export QT_QPA_EGLFS_PHYSICAL_HEIGHT=1080
            unset DISPLAY
            ;;
    esac
    
    # Apply to current session
    export QT_QPA_PLATFORM
    export QT_QPA_EGLFS_PHYSICAL_WIDTH
    export QT_QPA_EGLFS_PHYSICAL_HEIGHT
    
    # Update user's environment files
    cat > /home/$ACTUAL_USER/.uhj-display-env << EOF2
export QT_QPA_PLATFORM=$QT_QPA_PLATFORM
export QT_QPA_EGLFS_PHYSICAL_WIDTH=$QT_QPA_EGLFS_PHYSICAL_HEIGHT
export QT_QPA_EGLFS_PHYSICAL_HEIGHT=$QT_QPA_EGLFS_PHYSICAL_HEIGHT
unset DISPLAY
EOF2
    
    echo "Display configured for: $display_type"
}

# Main detection and configuration
DISPLAY_TYPE=$(detect_display_type)
echo "UHJ-Pi: Detected display type: $DISPLAY_TYPE"
configure_display $DISPLAY_TYPE
EOF

# Make the detection script executable
chmod +x /usr/local/bin/detect-display.sh

# Create a systemd service to run detection on boot
cat > /etc/systemd/system/uhj-display-detect.service << 'EOF'
[Unit]
Description=UHJ-Pi Display Detection
After=graphical.target
Before=supercollider.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/detect-display.sh
User=root
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
systemctl enable uhj-display-detect.service

# Create a user-level script that sources the environment
cat > /home/$ACTUAL_USER/.uhj-display-env << 'EOF'
# UHJ-Pi Display Environment Variables
# This file is updated by the detection service on each boot
export QT_QPA_PLATFORM=eglfs
export QT_QPA_EGLFS_PHYSICAL_WIDTH=800
export QT_QPA_EGLFS_PHYSICAL_HEIGHT=480
unset DISPLAY
EOF

# Add source command to user's shell profiles
echo "source ~/.uhj-display-env" >> /home/$ACTUAL_USER/.bashrc
echo "source ~/.uhj-display-env" >> /home/$ACTUAL_USER/.profile

echo "Runtime detection infrastructure installed successfully!"
echo "Display will be automatically detected and configured on every boot."
echo ""

# ============================================================================
# ORIGINAL INSTALLATION PROCESS (UNCHANGED)
# ============================================================================

echo "Phase 2: Installing SuperCollider and dependencies (unchanged process)..."

# Configure non-interactive package installation
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none
echo "initramfs-tools inthat itramfs-tools/update_initramfs boolean false" | debconf-set-selections
echo "jackd jackd/tweak_rt_limits boolean true" | debconf-set-selections

# STEP 1: System Update

apt-get update
# Skip upgrade - go straight to installing what we need
# apt-get upgrade -y  # Commented out - causes hooks hang
# apt-get dist-upgrade -y  # Commented out - can cause hangs, test without first

# STEP 2: Generic Boot Configuration for EGLFS
echo "Step 2: Configuring boot for EGLFS (works with both touch and HDMI)..."

# Backup existing config
cp /boot/firmware/config.txt /boot/firmware/config.txt.backup

# Configure for EGLFS (works with both touch and HDMI)
if ! grep -q "dtparam=audio=off" /boot/firmware/config.txt; then
    echo "dtparam=audio=off" >> /boot/firmware/config.txt
fi
if ! grep -q "dtoverlay=vc4-kms-v3d,noaudio" /boot/firmware/config.txt; then
    echo "dtoverlay=vc4-kms-v3d,noaudio" >> /boot/firmware/config.txt
fi

# Add HDMI optimizations (won't hurt touch screen)
if ! grep -q "disable_overscan=1" /boot/firmware/config.txt; then
    echo "disable_overscan=1" >> /boot/firmware/config.txt
fi

echo "Boot configuration updated for EGLFS (universal display support)"

# STEP 3: Install X11 and Blackbox
apt install -y xserver-xorg x11-xserver-utils xinit blackbox

# STEP 4: Install SuperCollider Dependencies
apt-get install -y build-essential cmake libjack-jackd2-dev libsndfile1-dev libfftw3-dev libxt-dev libavahi-client-dev libudev-dev libasound2-dev libreadline-dev libxkbcommon-dev git jackd2 libhidapi-dev qt6-base-dev qt6-svg-dev qt6-tools-dev qt6-wayland qt6-websockets-dev qt6-webengine-dev

# STEP 5: Clone SuperCollider
cd /home/$ACTUAL_USER
if [ ! -d "supercollider" ]; then
    git clone --branch main --recurse-submodules https://github.com/supercollider/supercollider.git
fi
cd supercollider
mkdir -p build
cd build

# STEP 6: Configure SuperCollider Build - FIXED: SC_QT=ON for Qt support without X11
echo "Configuring SuperCollider build..."
if cmake -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF -DSC_EL=OFF -DSC_VIM=ON -DNATIVE=ON -DSC_IDE=OFF -DNO_X11=ON -DSC_QT=ON ..; then
    echo "SuperCollider configuration successful"
else
    echo "ERROR: SuperCollider configuration failed!"
    exit 1
fi

# STEP 7: Build SuperCollider
echo "Building SuperCollider..."
if make -j2; then
    echo "SuperCollider build successful"
else
    echo "ERROR: SuperCollider build failed!"
    exit 1
fi

# STEP 8: Install SuperCollider
echo "Installing SuperCollider..."
if make install; then
    echo "SuperCollider installation successful"
    ldconfig
else
    echo "ERROR: SuperCollider installation failed!"
    exit 1
fi

# STEP 9: Set up udev rules for HID and audio permissions
cat > /etc/udev/rules.d/99-phonorama.rules << 'EOF'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2573", ATTRS{idProduct}=="0001", GROUP="plugdev", MODE="0660"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="plugdev", MODE="0660"
SUBSYSTEM=="audio", MODE="0666"
EOF

# STEP 10: Configure JACK Audio
echo "/usr/bin/jackd -P75 -d alsa -C hw:Phonorama -P hw:HD -r 44100 -p 256 -n 2 -S &" > /home/$ACTUAL_USER/.jackdrc
usermod -aG audio,plugdev $ACTUAL_USER

# STEP 11: Install SC3 Plugins
echo "Installing SC3 Plugins..."
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

# STEP 12: Clone UHJ-Pi repository and build phono-control CLI
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

# STEP 13: Install ATK and handle GUI component cleanup (MANUAL APPROACH)
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
    sudo -u $ACTUAL_USER rm -rf atk-sounds-master atk-sounds.zip
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

# STEP 13.5: Install Custom UHJ Test Sounds
echo "Step 13.5: Installing Custom UHJ Test Sounds..."
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


# Set proper ownership
chown -R $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/

# STEP 15: Runtime display detection is already configured
echo "Step 15: Runtime display detection infrastructure is already configured..."
echo "The system will automatically detect and configure display settings on each boot."
echo "No manual environment variable configuration needed."

## STEP 16: Install custom fonts
echo "Installing custom fonts..."
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

echo "Installation completed successfully!"
echo ""
echo "🎉 UHJ-Pi Unified Installation Complete! 🎉"
echo ""
echo "🧠 Smart Display Detection: Runtime Auto-Configuration"
echo "⚡ Performance: EGLFS (Direct Framebuffer)"
echo "🔄 Auto-Detection: Every boot automatically detects and configures display"
echo ""
echo "💡 Benefits of this configuration:"
echo "  ✅ Maximum audio performance (EGLFS)"
echo "  ✅ Lower latency for real-time processing"
echo "  ✅ More CPU available for audio"
echo "  ✅ Stable timing for JACK audio"
echo "  ✅ Professional appearance"
echo "  ✅ Automatic display switching (no manual reconfiguration)"
echo "  ✅ Works with any display combination (touch, HDMI, or both)"
echo ""
echo "🔄 Reboot required for changes to take effect:"
echo "  sudo reboot"
echo ""
echo "🎯 After reboot, the system will:"
echo "  1. Auto-detect your display configuration"
echo "  2. Set optimal EGLFS settings"
echo "  3. Configure environment variables automatically"
echo "  4. Work with touch screen, HDMI, or both"
echo ""
echo "🎵 Happy audio processing! 🎵" 