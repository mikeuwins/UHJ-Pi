#!/bin/bash

# UHJ-Pi Raspberry Pi Setup Script - Behringer + HDMI Version
# Combines HDMI display setup with Behringer audio configuration

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
        if [ $completed -lt $width ]; then
            printf ">"
            printf "%*s" $((width - completed - 1))
        fi
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
echo "🎵 UHJ-Pi Raspberry Pi Setup Script - Behringer + HDMI Version 🎵"
echo "Installing for user: $ACTUAL_USER"
echo "This version combines HDMI display setup with Behringer audio configuration"
echo

# Configure non-interactive package installation
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none
echo "initramfs-tools initramfs-tools/update_initramfs boolean false" | debconf-set-selections
echo "jackd jackd/tweak_rt_limits boolean true" | debconf-set-selections

step_header "STEP 1/24: System Update"
echo "Updating package lists..."
apt-get update
# Skip upgrade - go straight to installing what we need
# apt-get upgrade -y  # Commented out - causes hooks hang
# apt-get dist-upgrade -y  # Commented out - can cause hangs, test without first

step_header "STEP 2/24: Configure Boot Configuration for HDMI"
echo "Configuring boot configuration for HDMI..."
# Backup existing config
cp /boot/firmware/config.txt /boot/firmware/config.txt.backup

# Add HDMI-specific configuration
cat >> /boot/firmware/config.txt << 'EOF'

# UHJ-Pi HDMI Configuration
# Disable onboard audio
dtparam=audio=off

# Enable DRM VC4 V3D driver for HDMI
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Don't have the firmware create an initial video= setting in cmdline.txt
# Use the kernel's default instead
disable_fw_kms_setup=1

# Run in 64-bit mode
arm_64bit=1

# Disable compensation for displays with overscan
disable_overscan=1

# Run as fast as firmware / board allows
arm_boost=1

# Enable host mode on the 2711 built-in XHCI USB controller
[cm4]
otg_mode=1

[cm5]
dtoverlay=dwc2,dr_mode=host

[all]
dtoverlay=vc4-kms-v3d,noaudio
EOF

echo "Boot configuration updated for HDMI"

step_header "STEP 3/24: Install X11 and Desktop Environment"
echo "Installing X11 and Blackbox..."
apt install -y xserver-xorg x11-xserver-utils xinit blackbox blackbox-themes

echo "Installing additional X11 utilities..."
apt install -y unclutter unclutter-xfixes bsetroot

step_header "STEP 4/24: Install SuperCollider Dependencies"
echo "Installing SuperCollider Dependencies..."
apt-get install -y build-essential cmake libjack-jackd2-dev libsndfile1-dev \
    libfftw3-dev libxt-dev libavahi-client-dev libudev-dev libasound2-dev \
    libreadline-dev libxkbcommon-dev git jackd2 libhidapi-dev qt6-base-dev \
    qt6-svg-dev qt6-tools-dev qt6-wayland qt6-websockets-dev qt6-webengine-dev

step_header "STEP 5/24: Clone SuperCollider"
echo "Cloning SuperCollider..."
cd /home/$ACTUAL_USER
if [ ! -d "supercollider" ]; then
    git clone --branch main --recurse-submodules https://github.com/supercollider/supercollider.git
fi
cd supercollider
mkdir -p build
cd build

step_header "STEP 6/24: Configure SuperCollider Build"
echo "Configuring SuperCollider build (Qt with X11 for HDMI)..."
echo "Note: Qt6 runtime libraries are provided by dev packages on Pi OS Lite"
if cmake -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF -DSC_EL=OFF -DSC_VIM=ON \
    -DNATIVE=ON -DSC_IDE=OFF -DNO_X11=OFF -DSC_QT=ON ..; then
    echo "SuperCollider configuration successful"
else
    echo "ERROR: SuperCollider configuration failed!"
    exit 1
fi

step_header "STEP 7/24: Build SuperCollider"
echo "Building SuperCollider..."
if make -j2; then
    echo "SuperCollider build successful"
else
    echo "ERROR: SuperCollider build failed!"
    exit 1
fi

step_header "STEP 8/24: Install SuperCollider"
echo "Installing SuperCollider..."
if make install; then
    echo "SuperCollider installation successful"
    ldconfig
else
    echo "ERROR: SuperCollider installation failed!"
    exit 1
fi

step_header "STEP 9/24: Set up ARM64 library paths and Qt environment"
echo "Setting up ARM64 library paths and Qt environment..."
# Detect architecture and set correct library paths
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    LIB_PATH="/usr/lib/aarch64-linux-gnu"
elif [ "$ARCH" = "armv7l" ]; then
    LIB_PATH="/usr/lib/arm-linux-gnueabihf"
else
    LIB_PATH="/usr/lib/x86_64-linux-gnu"
fi

# Set Qt environment variables for the user
echo "export LD_LIBRARY_PATH=$LIB_PATH:\$LD_LIBRARY_PATH" >> /home/$ACTUAL_USER/.bashrc
echo "export QT_PLUGIN_PATH=$LIB_PATH/qt6/plugins" >> /home/$ACTUAL_USER/.bashrc
echo "export QT_QPA_PLATFORM=xcb" >> /home/$ACTUAL_USER/.bashrc
echo "export DISPLAY=:0" >> /home/$ACTUAL_USER/.bashrc

# Also set in .profile for login sessions
echo "export LD_LIBRARY_PATH=$LIB_PATH:\$LD_LIBRARY_PATH" >> /home/$ACTUAL_USER/.profile
echo "export QT_PLUGIN_PATH=$LIB_PATH/qt6/plugins" >> /home/$ACTUAL_USER/.profile
echo "export QT_QPA_PLATFORM=xcb" >> /home/$ACTUAL_USER/.profile
echo "export DISPLAY=:0" >> /home/$ACTUAL_USER/.profile

echo "ARM64 library paths and Qt environment configured for $ARCH"

step_header "STEP 10/24: Set up udev rules for HID and audio permissions"
echo "Setting up udev rules..."
cat > /etc/udev/rules.d/99-phonorama.rules << 'EOF'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2573", ATTRS{idProduct}=="0001", GROUP="plugdev", MODE="0660"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="plugdev", MODE="0660"
SUBSYSTEM=="audio", MODE="0666"
EOF

step_header "STEP 11/24: Configure JACK Audio"
echo "Configuring JACK Audio..."
echo "/usr/bin/jackd -P75 -d alsa -C hw:Phonorama -P hw:HD -r 44100 -p 256 -n 2 -S &" > /home/$ACTUAL_USER/.jackdrc
usermod -aG audio,plugdev $ACTUAL_USER

step_header "STEP 12/24: Install SC3 Plugins"
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

step_header "STEP 13/24: Clone UHJ-Pi repository and install Behringer audio setup"
echo "Cloning UHJ-Pi repository and installing Behringer audio setup..."
cd /home/$ACTUAL_USER
if [ ! -d "UHJ-Pi" ]; then
    if git clone https://github.com/mikeuwins/UHJ-Pi.git; then
        echo "UHJ-Pi repository cloned successfully"
    else
        echo "ERROR: UHJ-Pi repository clone failed!"
        exit 1
    fi
fi

# Install zita-ajbridge for Behringer audio routing
echo "Installing zita-ajbridge for Behringer audio setup..."
apt-get install -y zita-ajbridge

# Create Behringer udev rules for persistent device naming
echo "Creating Behringer udev rules..."
cat > /etc/udev/rules.d/99-behringer-audio.rules << 'EOF'
# Behringer UCA202/UFO202 USB Audio Device Rules
# These rules ensure persistent device naming for Behringer USB audio devices

# UCA202 (Line input/output device)
SUBSYSTEM=="usb", ATTRS{idVendor}=="08bb", ATTRS{idProduct}=="2902", ATTRS{manufacturer}=="Behringer", ATTRS{product}=="UCA202", SYMLINK+="audio/uca202"

# UFO202 (Phono input/output device)  
SUBSYSTEM=="usb", ATTRS{idVendor}=="08bb", ATTRS{idProduct}=="2902", ATTRS{manufacturer}=="Behringer", ATTRS{product}=="UFO202", SYMLINK+="audio/ufo202"

# Set permissions for audio group
SUBSYSTEM=="usb", ATTRS{idVendor}=="08bb", ATTRS{idProduct}=="2902", GROUP="audio", MODE="0666"
EOF

# Reload udev rules
udevadm control --reload-rules
udevadm trigger

echo "Behringer audio setup completed successfully"

step_header "STEP 14/24: Install ATK and handle GUI component cleanup"
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

# Remove problematic GUI components (keeping PointView as it works in the system)
echo "Removing problematic GUI components..."
# Only remove if directories exist to prevent errors
if [ -d "/home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/GUI/" ]; then
    rm -rf /home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/GUI/
    echo "Removed wslib GUI components"
fi
if [ -f "/home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main Features/Interpolation/extPen-splineCurve.sc" ]; then
    rm "/home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main Features/Interpolation/extPen-splineCurve.sc"
    echo "Removed extPen-splineCurve.sc"
fi
if [ -f "/home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main Features/SVGFile/extColPen-asSVGFile.sc" ]; then
    rm "/home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main Features/SVGFile/extColPen-asSVGFile.sc"
    echo "Removed extColPen-asSVGFile.sc"
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

step_header "STEP 15/24: Install Custom UHJ Test Sounds"
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

step_header "STEP 16/24: Install custom user classes"
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

step_header "STEP 17/24: Install custom fonts"
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

step_header "STEP 18/24: Configure X11 and Blackbox with all refinements"
echo "Configuring X11 and Blackbox with all refinements..."

# Create X11 configuration directory
mkdir -p /etc/X11/xorg.conf.d

# Create X11 wrapper configuration
cat > /etc/X11/Xwrapper.config << 'EOF'
allowed_users=anybody
needs_root_rights=yes
EOF

# Configure unclutter for cursor management
cat > /etc/default/unclutter << 'EOF'
# Unclutter configuration for UHJ-Pi
UNCLUTTER_ARGS="-idle 1 -root"
EOF

# Set audio limits for real-time processing
cat > /etc/security/limits.d/audio.conf << 'EOF'
# Audio group real-time limits
@audio - rtprio 95
@audio - memlock unlimited
@audio - nice -19
EOF

step_header "STEP 19/24: Create custom Blackbox configuration"
echo "Creating custom Blackbox configuration..."

# Create blackbox directory and configuration
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.blackbox/styles

# Create the custom NoDecorations style
cat > /home/$ACTUAL_USER/.blackbox/styles/NoDecorations << 'EOF'
! NoDecorations style
window.title.marginWidth: 0
window.handleHeight: 0
window.grip.marginWidth: 0
window.frame.borderWidth: 0
borderWidth: 0
bevelWidth: 0
handleWidth: 0
frameWidth: 0
EOF

# Create .blackboxrc with working settings
cat > /home/$ACTUAL_USER/.blackboxrc << 'EOF'
session.screen0.enableToolbar:  False
session.screen0.workspaces:     1
session.screen0.fullMaximization:       True
session.styleFile:      /home/$ACTUAL_USER/.blackbox/styles/NoDecorations
session.focusModel:     ClickToFocus
EOF

# Username is already set correctly in blackboxrc

step_header "STEP 20/24: Create refined .xinitrc with proper startup sequence"
echo "Creating refined .xinitrc..."

cat > /home/$ACTUAL_USER/.xinitrc << 'EOF'
command -v unclutter >/dev/null 2>&1 && unclutter -idle 1 -root &
export QT_QPA_PLATFORM=xcb
export DISPLAY=:0
blackbox &
sleep 0.1
xsetroot -solid black
sleep 0.1
exec sclang ~/UHJ-Pi/supercollider/app/UHJ_v23_BEH_PAIR.scd > ~/post_output.log 2>&1
EOF

# Set ownership of the new files
chown $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/.xinitrc
chown $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/.blackboxrc
chown -R $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/.blackbox

step_header "STEP 21/24: Create systemd service for X11 auto-start"
echo "Creating systemd service for X11 auto-start (disabled by default for debugging)..."

cat > /etc/systemd/system/uhj-pi-x11.service << EOF
[Unit]
Description=UHJ-Pi X11 Session
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$ACTUAL_USER
Environment=DISPLAY=:0
Environment=QT_QPA_PLATFORM=xcb
ExecStart=/usr/bin/startx -- :0
Restart=no
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create the service but don't enable it yet (for debugging)
systemctl daemon-reload
echo "X11 auto-start service created but NOT enabled (for debugging)"
echo "To enable kiosk mode later, run: sudo systemctl enable uhj-pi-x11.service"

echo "Auto-start X11 session service created but NOT enabled (for debugging)"
echo "To enable kiosk mode later, run: sudo systemctl enable uhj-pi-x11.service"

step_header "STEP 22/24: Set up X11 session environment"
echo "Setting up X11 session environment..."

# Create X11 session directory
mkdir -p /etc/X11/Xsession.d

# Create Qt accessibility configuration
cat > /etc/X11/Xsession.d/90qt-a11y << 'EOF'
# -*- sh -*-
# Xsession.d script to set the env variables to enable accessibility for Qt
#
# This file is sourced by Xsession(5), not executed.

QT_ACCESSIBILITY=1

export QT_ACCESSIBILITY

if [ -x "/usr/bin/dbus-update-activation-environment" ]; then
        dbus-update-activation-environment --verbose --systemd QT_ACCESSIBILITY
fi
EOF

# Create environment configuration
mkdir -p /etc/environment.d
cat > /etc/environment.d/90qt-a11y.conf << 'EOF'
QT_ACCESSIBILITY=1
EOF

echo "X11 session environment configured"

step_header "STEP 23/24: Install Bluetooth pairing script"
echo "Installing Bluetooth pairing script..."
cp /home/$ACTUAL_USER/UHJ-Pi/ble-ht.sh /usr/local/bin/
chmod +x /usr/local/bin/ble-ht.sh
chown $ACTUAL_USER:$ACTUAL_USER /usr/local/bin/ble-ht.sh
echo "Bluetooth pairing script installed to /usr/local/bin/"

step_header "STEP 24/24: Install launcher script"
echo "Installing launcher script..."
cp /home/$ACTUAL_USER/UHJ-Pi/start-beh.sh /usr/local/bin/start
chmod +x /usr/local/bin/start
chown $ACTUAL_USER:$ACTUAL_USER /usr/local/bin/start
echo "Launcher script installed to /usr/local/bin/start"

echo "Installation completed successfully!"
echo ""
echo "Behringer + HDMI setup completed:"
echo "  ✅ HDMI display configuration"
echo "  ✅ Custom Blackbox style (NoDecorations)"
echo "  ✅ Refined .blackboxrc configuration"
echo "  ✅ Optimized .xinitrc startup sequence"
echo "  ✅ Systemd service for auto-start"
echo "  ✅ X11 session environment setup"
echo "  ✅ Audio limits and security configuration"
echo "  ✅ Behringer audio setup (JACK + zita bridges)"
echo "  ✅ Behringer udev rules for persistent device naming"
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
echo "  ✅ App configured: UHJ_v23_BEH_PAIR.scd"
echo "  ✅ Launcher created: /usr/local/bin/start"
echo ""
echo "Reboot required. Run: sudo reboot"
echo "After reboot:"
echo "  - X11 session will NOT start automatically (for debugging)"
echo "  - To start X11 manually: start"
echo "  - Blackbox will run with no window decorations"
echo "  - UHJ app will launch in fullscreen"
echo "  - To enable kiosk mode: sudo systemctl enable uhj-pi-x11.service"
echo ""
echo "Manual launch (if needed):"
echo "  start"
echo ""
echo "After reboot:"
echo "  1. Run: sudo reboot"
echo "  2. After reboot, run: start"
echo "  3. The start command will:"
echo "     - Detect and verify Behringer devices"
echo "     - Set up JACK + zita bridges"
echo "     - Launch X11 session with UHJ app"
echo "  4. Behringer audio setup will be handled automatically by the app"
echo ""
echo "Press any key to reboot the system..."
read -n 1 -s
echo ""
echo "Rebooting..."
reboot 