#!/bin/bash

# UHJ-Pi Raspberry Pi Setup Script

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

echo "UHJ-Pi Raspberry Pi Setup Script - Starting installation..."
echo "Installing for user: $ACTUAL_USER"

# Configure non-interactive package installation
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none
echo "initramfs-tools initramfs-tools/update_initramfs boolean false" | debconf-set-selections
echo "jackd jackd/tweak_rt_limits boolean true" | debconf-set-selections

# STEP 1: System Update

apt-get update
# Skip upgrade - go straight to installing what we need
# apt-get upgrade -y  # Commented out - causes hooks hang
# apt-get dist-upgrade -y  # Commented out - can cause hangs, test without first

# STEP 2: Disable Onboard and HDMI Audio
if ! grep -q "dtparam=audio=off" /boot/firmware/config.txt; then
    echo "dtparam=audio=off" >> /boot/firmware/config.txt
fi
if ! grep -q "dtoverlay=vc4-kms-v3d,noaudio" /boot/firmware/config.txt; then
    echo "dtoverlay=vc4-kms-v3d,noaudio" >> /boot/firmware/config.txt
fi

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

# Install ATK quark manually (clone repo)
echo "Installing ATK quark manually..."
cd /home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks
if sudo -u $ACTUAL_USER git clone https://github.com/ambisonictoolkit/atk-sc3.git; then
    echo "ATK quark cloned successfully"
else
    echo "ERROR: ATK quark clone failed!"
    exit 1
fi

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
    sudo -u $ACTUAL_USER rm -rf atk-sounds-master atk-sounds.zip
    echo "ATK sounds installed successfully"
else
    echo "ATK sounds download failed - continuing without sounds"
fi

# Copy ATK classes to SuperCollider Extensions so they can be found
echo "Copying ATK classes to SuperCollider Extensions..."
sudo -u $ACTUAL_USER mkdir -p /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/atk-sc3
sudo -u $ACTUAL_USER cp -r /home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/* /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/atk-sc3/
echo "ATK classes copied to Extensions successfully"

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

# Install AmbiVerbSC manually
echo "Installing AmbiVerbSC manually..."

# Return to SuperCollider directory for AmbiVerbSC installation
cd /home/$ACTUAL_USER/.local/share/SuperCollider/downloaded-quarks

# Clean up any existing failed installation
if [ -d "AmbiVerbSC" ]; then
    echo "Removing existing AmbiVerbSC directory..."
    sudo -u $ACTUAL_USER rm -rf AmbiVerbSC
fi

sudo -u $ACTUAL_USER git clone https://github.com/JamesWenlock/AmbiVerbSC.git

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

# STEP 15: Configure Qt platform for headless operation
echo "Step 15: Configuring Qt platform for headless operation..."
# Set Qt platform to eglfs for the user's shell
echo 'export QT_QPA_PLATFORM=eglfs' >> /home/$ACTUAL_USER/.bashrc
echo 'export QT_QPA_PLATFORM=eglfs' >> /home/$ACTUAL_USER/.profile

echo "Installation completed successfully!"
echo ""
echo "Reboot required. After reboot and login, run:"
echo "  sclang ~/UHJ-Pi/supercollider/app/UHJ_v21.scd" 