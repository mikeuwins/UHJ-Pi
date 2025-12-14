let's#!/bin/bash

# UHJ-Pi ESI HDMI Hybrid Installation Script
# HDMI version with latest SuperCollider fixes from touch-hybrid
# Updated: August 2025

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

echo "UHJ-Pi ESI HDMI Hybrid Setup Script - Starting installation..."
echo "Installing for user: $ACTUAL_USER"
echo "HDMI version with latest SuperCollider fixes from touch-hybrid"

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

# STEP 2: Configure Boot Configuration for HDMI
echo "Step 2: Configuring boot configuration for HDMI..."
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

# STEP 3: Install X11 and Blackbox with all dependencies
echo "Step 3: Installing X11 and Blackbox..."
apt install -y xserver-xorg x11-xserver-utils xinit blackbox blackbox-themes \
    unclutter bsetroot x11-common x11-apps x11-session-utils

# STEP 4: Install SuperCollider Dependencies
echo "Step 4: Installing SuperCollider Dependencies..."
apt-get install -y build-essential cmake libjack-jackd2-dev libsndfile1-dev \
    libfftw3-dev libxt-dev libavahi-client-dev libudev-dev libasound2-dev \
    libreadline-dev libxkbcommon-dev git jackd2 libhidapi-dev qt6-base-dev \
    qt6-svg-dev qt6-tools-dev qt6-wayland qt6-websockets-dev qt6-webengine-dev

# STEP 5: Clone SuperCollider
echo "Step 5: Cloning SuperCollider..."
cd /home/$ACTUAL_USER
if [ ! -d "supercollider" ]; then
    git clone --branch main --recurse-submodules https://github.com/supercollider/supercollider.git
fi
cd supercollider
mkdir -p build
cd build

# STEP 6: Configure SuperCollider Build - Qt with X11 for HDMI
echo "Step 6: Configuring SuperCollider build..."
echo "Note: Qt6 runtime libraries are provided by dev packages on Pi OS Lite"
if cmake -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF -DSC_EL=OFF -DSC_VIM=ON \
    -DNATIVE=ON -DSC_IDE=OFF -DNO_X11=OFF -DSC_QT=ON ..; then
    echo "SuperCollider configuration successful"
else
    echo "ERROR: SuperCollider configuration failed!"
    exit 1
fi

# STEP 7: Build SuperCollider
echo "Step 7: Building SuperCollider..."
if make -j2; then
    echo "SuperCollider build successful"
else
    echo "ERROR: SuperCollider build failed!"
    exit 1
fi

# STEP 8: Install SuperCollider
echo "Step 8: Installing SuperCollider..."
if make install; then
    echo "SuperCollider installation successful"
    ldconfig
else
    echo "ERROR: SuperCollider installation failed!"
    exit 1
fi

# STEP 9: Set up ARM64 library paths and Qt environment
echo "Step 9: Setting up ARM64 library paths and Qt environment..."
# Detect architecture and set correct library paths
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    LIB_PATH="/usr/lib/aarch64-linux-gnu"
elif [ "$ARCH" = "armv7l" ]; then
    LIB_PATH="/usr/lib/arm-linux-gnueabihf"
else
    LIB_PATH="/usr/lib/x86_64-linux-gnu"
fi

# Set library paths for the user (but not Qt platform - let SuperCollider handle it automatically)
echo "export LD_LIBRARY_PATH=$LIB_PATH:\$LD_LIBRARY_PATH" >> /home/$ACTUAL_USER/.bashrc
echo "export QT_PLUGIN_PATH=$LIB_PATH/qt6/plugins" >> /home/$ACTUAL_USER/.bashrc

# Also set in .profile for login sessions
echo "export LD_LIBRARY_PATH=$LIB_PATH:\$LD_LIBRARY_PATH" >> /home/$ACTUAL_USER/.profile
echo "export QT_PLUGIN_PATH=$LIB_PATH/qt6/plugins" >> /home/$ACTUAL_USER/.profile

echo "ARM64 library paths and Qt environment configured for $ARCH"

# STEP 10: Set up udev rules for HID and audio permissions
echo "Step 10: Setting up udev rules..."
cat > /etc/udev/rules.d/99-phonorama.rules << 'EOF'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2573", ATTRS{idProduct}=="0001", GROUP="plugdev", MODE="0660"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="plugdev", MODE="0660"
SUBSYSTEM=="audio", MODE="0666"
EOF

# STEP 11: Configure JACK Audio
echo "Step 11: Configuring JACK Audio..."
echo "/usr/bin/jackd -P75 -d alsa -C hw:Phonorama -P hw:HD -r 44100 -p 256 -n 2 -S &" > /home/$ACTUAL_USER/.jackdrc
usermod -aG audio,plugdev $ACTUAL_USER

# STEP 12: Install SC3 Plugins
echo "Step 12: Installing SC3 Plugins..."
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

# STEP 13: Clone UHJ-Pi repository and build phono-control CLI
echo "Step 13: Cloning UHJ-Pi repository and building phono-control CLI..."
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

# STEP 14: Install ATK and handle GUI component cleanup (IMPROVED APPROACH)
echo "Step 14: Installing ATK and handling GUI component cleanup..."
cd /home/$ACTUAL_USER

# Create necessary directories
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/ATK
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions

# Install ATK using Quark system (more reliable)
echo "Installing ATK quark using Quark system..."
cd /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions
if sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.install("https://github.com/ambisonictoolkit/atk-sc3");
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
if [ -d "downloaded-quarks/atk-sc3" ]; then
    sudo -u $ACTUAL_USER mv downloaded-quarks/atk-sc3 Extensions/
    echo "Moved atk-sc3 to Extensions"
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
    echo "ATK sounds copied successfully - cleaning up temporary files..."
    sudo -u $ACTUAL_USER rm -rf atk-sounds-master
    sudo -u $ACTUAL_USER rm -f atk-sounds.zip
    echo "ATK sounds installed successfully and temporary files cleaned up"
else
    echo "ATK sounds download failed - continuing without sounds"
fi

# Ensure we're back in the right directory and clean up any leftover files
cd /home/$ACTUAL_USER/.local/share/ATK
# Final cleanup check - remove any leftover files in /tmp
if [ -f "/tmp/atk-sounds.zip" ]; then
    echo "Removing leftover atk-sounds.zip from /tmp..."
    rm -f /tmp/atk-sounds.zip
fi
if [ -d "/tmp/atk-sounds-master" ]; then
    echo "Removing leftover atk-sounds-master from /tmp..."
    rm -rf /tmp/atk-sounds-master
fi

# ATK classes are now directly in Extensions - no copying needed

# Return to ATK directory for custom sounds
cd /home/$ACTUAL_USER/.local/share/ATK

# STEP 15: Install Custom UHJ Test Sounds
echo "Step 15: Installing Custom UHJ Test Sounds..."
echo "Installing custom UHJ test sounds..."
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/ATK
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/AJH_eight-positions-uhj.wav /home/$ACTUAL_USER/.local/share/ATK/
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/hifi_sound_1981_ambisonic_tests.wav /home/$ACTUAL_USER/.local/share/ATK/
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/Sodium_Sunrise_UHJ.wav /home/$ACTUAL_USER/.local/share/ATK/
sudo -u $ACTUAL_USER cp /home/$ACTUAL_USER/UHJ-Pi/assets/audio-samples/uhj/UHJ_Mono_Pink_Noise_North.wav /home/$ACTUAL_USER/.local/share/ATK/
echo "Custom UHJ test sounds installed successfully"

# AmbiVerbSC already installed via Quark system above
echo "AmbiVerbSC installation completed via Quark system"

# STEP 16: Install custom user classes
echo "Step 16: Installing custom user classes..."
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

# STEP 17: Install custom fonts
echo "Step 17: Installing custom fonts..."
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

# STEP 18: Configure X11 and Blackbox with all refinements
echo "Step 18: Configuring X11 and Blackbox with all refinements..."

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

# STEP 19: Create custom Blackbox configuration
echo "Step 19: Creating custom Blackbox configuration..."

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

# Create .blackboxrc with all the refined settings
cat > /home/$ACTUAL_USER/.blackboxrc << 'EOF'
session.screen0.toolbar.autoHide:       True
session.screen0.toolbar.onTop:  False
session.screen0.toolbar.placement:      BottomCenter
session.screen0.toolbar.widthPercent:   66
session.screen0.slit.placement: CenterRight
session.screen0.slit.direction: Vertical
session.screen0.slit.onTop:     False
session.screen0.slit.autoHide:  False
session.screen0.enableToolbar:  False
session.screen0.workspaces:     1
session.screen0.strftimeFormat: %I:%M %p
session.screen0.workspaceNames: Workspace 1
session.screen0.fullMaximization:       True
session.focusNewWindows:        True
session.colPlacementDirection:  TopToBottom
session.doubleClickInterval:    250
session.styleFile:      /home/uhj-pi/.blackbox/styles/NoDecorations
session.focusModel:     ClickToFocus
session.windowSnapThreshold:    0
session.focusLastWindow:        True
session.placementIgnoresShaded: True
session.autoRaiseDelay: 400
session.menuFile:       /etc/X11/blackbox/blackbox-menu
session.changeWorkspaceWithMouseWheel:  True
session.opaqueMove:     True
session.imageDither:    OrderedDither
session.windowPlacement:        RowSmartPlacement
session.shadeWindowWithMouseWheel:      True
session.opaqueResize:   True
session.toolbarActionsWithMouseWheel:   True
session.maximumColors:  0
session.rowPlacementDirection:  LeftToRight
session.disableBindingsWithScrollLock:  False
session.fullMaximization:       True
session.edgeSnapThreshold:      0
EOF

# Update the username in the blackboxrc file
sed -i "s/uhj-pi/$ACTUAL_USER/g" /home/$ACTUAL_USER/.blackboxrc

# STEP 20: Create refined .xinitrc with proper startup sequence
echo "Step 20: Creating refined .xinitrc..."

cat > /home/$ACTUAL_USER/.xinitrc << 'EOF'
export QT_QPA_PLATFORM=xcb
unclutter -idle 1 -root &
blackbox &
sleep 1
bsetroot -solid black
sleep 0.5
exec sclang ~/UHJ-Pi/supercollider/app/UHJ_v21_HDMI.scd
EOF

# Set ownership of the new files
chown $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/.xinitrc
chown $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/.blackboxrc
chown -R $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/.blackbox

# STEP 21: Create systemd service for X11 auto-start (disabled by default for debugging)
echo "Step 21: Creating systemd service for X11 auto-start (disabled by default for debugging)..."

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

# STEP 22: Set up X11 session environment
echo "Step 22: Setting up X11 session environment..."

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

echo "Installation completed successfully!"
echo ""
echo "🎉 UHJ-Pi ESI HDMI Hybrid Installation Complete! 🎉"
echo ""
echo "📱 Display: X11/HDMI compatible (proven working configuration)"
echo "⚡ SuperCollider: Latest fixes from touch-hybrid version"
echo "🎨 Interface: Clean Blackbox theme with minimal decorations"
echo "🔧 ATK: Improved installation via Quark system"
echo ""
echo "✅ What This Script Provides:"
echo "  ✅ HDMI display support (proven working)"
echo "  ✅ Latest SuperCollider fixes and optimizations"
echo "  ✅ Improved ATK and AmbiVerbSC installation"
echo "  ✅ Clean, professional X11 interface"
echo "  ✅ All custom extensions and audio support"
echo ""
echo "🔄 Reboot required for changes to take effect:"
echo "  sudo reboot"
echo ""
echo "🎵 After reboot, run:"
echo "  sclang ~/UHJ-Pi/supercollider/app/UHJ_v21_HDMI.scd"
echo ""
echo "💡 This combines the best of both worlds:"
echo "  ✅ Working HDMI configuration (proven)"
echo "  ✅ Latest SuperCollider fixes (improved)"
echo "  ✅ Professional X11 interface (polished)" 