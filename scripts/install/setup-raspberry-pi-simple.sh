#!/bin/bash

# UHJ-Pi Raspberry Pi Setup Script (Simple Version - No Auto-prompts)

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Get the actual username (the user who ran sudo)
ACTUAL_USER=${SUDO_USER:-$(logname)}
if [ -z "$ACTUAL_USER" ]; then
    echo "Error: Could not determine username. Please run with: sudo -E ./setup-raspberry-pi-simple.sh"
    exit 1
fi

echo "UHJ-Pi Raspberry Pi Setup Script (Simple Version) - Starting installation..."
echo "Installing for user: $ACTUAL_USER"

# Configure non-interactive package installation
export DEBIAN_FRONTEND=noninteractive
echo "initramfs-tools initramfs-tools/update_initramfs boolean false" | debconf-set-selections
echo "jackd jackd/tweak_rt_limits boolean true" | debconf-set-selections

# STEP 1: System Update
echo "Step 1: Updating system packages..."
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y

# STEP 2: Disable Onboard and HDMI Audio
echo "Step 2: Configuring audio settings..."
if ! grep -q "dtparam=audio=off" /boot/firmware/config.txt; then
    echo "dtparam=audio=off" >> /boot/firmware/config.txt
fi
if ! grep -q "dtoverlay=vc4-kms-v3d,noaudio" /boot/firmware/config.txt; then
    echo "dtoverlay=vc4-kms-v3d,noaudio" >> /boot/firmware/config.txt
fi

# STEP 3: Install minimal X11 (required for SuperCollider)
echo "Step 3: Installing minimal X11 environment..."
apt install -y xserver-xorg x11-xserver-utils xinit openbox

# STEP 4: Install SuperCollider Dependencies
echo "Step 4: Installing SuperCollider dependencies..."
apt-get install -y build-essential cmake libjack-jackd2-dev libsndfile1-dev libfftw3-dev libxt-dev libavahi-client-dev libudev-dev libasound2-dev libreadline-dev libxkbcommon-dev git jackd2 libhidapi-dev

# STEP 5: Clone SuperCollider
echo "Step 5: Building SuperCollider..."
cd /home/$ACTUAL_USER
if [ ! -d "supercollider" ]; then
    git clone --branch main --recurse-submodules https://github.com/supercollider/supercollider.git
fi
cd supercollider
mkdir -p build
cd build

# Configure SuperCollider Build without Qt
cmake -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF -DSC_EL=OFF -DSC_VIM=ON -DNATIVE=ON -DSC_IDE=OFF -DNO_X11=ON -DSC_QT=OFF ..

# Build SuperCollider
make -j2

# Install SuperCollider
make install
ldconfig

# STEP 6: Set up udev rules for HID and audio permissions
echo "Step 6: Setting up udev rules..."
cat > /etc/udev/rules.d/99-phonorama.rules << 'EOF'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2573", ATTRS{idProduct}=="0001", GROUP="plugdev", MODE="0660"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="plugdev", MODE="0660"
SUBSYSTEM=="audio", MODE="0666"
EOF

# Create general SuperCollider HID rule
cat > /etc/udev/rules.d/99-supercollider-hid.rules << 'EOF'
# Generic HID access for SuperCollider (headtrackers, controllers, etc.)
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="plugdev"
EOF

# Reload udev rules
udevadm control --reload-rules
udevadm trigger

# STEP 7: Configure JACK Audio
echo "Step 7: Configuring JACK audio..."
echo "/usr/bin/jackd -P75 -d alsa -C hw:Phonorama -P hw:HD -r 44100 -p 256 -n 2 -S &" > /home/$ACTUAL_USER/.jackdrc
usermod -aG audio,plugdev $ACTUAL_USER

# STEP 8: Install SC3 Plugins
echo "Step 8: Installing SC3 plugins..."
cd /home/$ACTUAL_USER
if [ ! -d "sc3-plugins" ]; then
    git clone --recursive https://github.com/supercollider/sc3-plugins.git
fi
cd sc3-plugins
mkdir build && cd build
cmake -DSC_PATH=/home/$ACTUAL_USER/supercollider -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF ..
cmake --build . --config Release
cmake --build . --config Release --target install

# STEP 9: Clone UHJ-Pi repository and build phono-control CLI
echo "Step 9: Building phono-control CLI..."
cd /home/$ACTUAL_USER
if [ ! -d "UHJ-Pi" ]; then
    git clone https://github.com/mikeuwins/UHJ-Pi.git
fi
cd UHJ-Pi/cli/phonorama-cli-linux
chmod +x build.sh
./build.sh

# STEP 10: Install ATK and handle GUI component cleanup
echo "Step 10: Installing ATK and cleaning up GUI components..."
cd /home/$ACTUAL_USER

# Install ATK quark
sudo -u $ACTUAL_USER sclang -l /dev/null << 'EOF'
Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");
0.exit;
EOF'

# Remove problematic GUI components
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/PointView/
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/GUI/
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main\ Features/Interpolation/extPen-splineCurve.sc
rm ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main\ Features/SVGFile/extColPen-asSVGFile.sc

# Uninstall PointView quark
sudo -u $ACTUAL_USER sclang -l /dev/null << 'EOF'
Quarks.uninstall("PointView");
0.exit;
EOF'

# Download ATK kernels, matrices, and sounds
sudo -u $ACTUAL_USER sclang -l /dev/null << 'EOF'
Atk.downloadKernels();
Atk.downloadMatrices();
Atk.downloadSounds();
0.exit;
EOF'

# Install AmbiVerbSC
sudo -u $ACTUAL_USER sclang -l /dev/null << 'EOF'
Quarks.install("https://github.com/JamesWenlock/AmbiVerbSC");
0.exit;
EOF'

# STEP 11: Install custom user classes
echo "Step 11: Installing custom user classes..."
cd /home/$ACTUAL_USER/UHJ-Pi/supercollider/extensions

# Copy custom extensions to SuperCollider Extensions directory (only if they don't exist)
if [ ! -d "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/ServerMeter2" ]; then
    cp -r ServerMeter2 /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
fi
# Note: Knob360 requires UserView class which is not available without Qt support
# if [ ! -d "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/Knob360" ]; then
#     cp -r Knob360 /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
# fi
if [ ! -d "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/MaplinMatrix" ]; then
    cp -r MaplinMatrix /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
fi
if [ ! -d "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/MaplinSM333" ]; then
    cp -r MaplinSM333 /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
fi

# Set proper ownership
chown -R $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/

# STEP 12: Performance optimizations
echo "Step 12: Applying performance optimizations..."
# Set CPU governor to performance
echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils

# Optimize audio group priorities
echo "@audio - rtprio 95" >> /etc/security/limits.conf
echo "@audio - memlock unlimited" >> /etc/security/limits.conf

# Disable unnecessary services
systemctl disable bluetooth.service
systemctl disable wpa_supplicant.service
systemctl disable hciuart.service

# STEP 13: Create startup script
echo "Step 13: Creating startup script..."
cat > /home/$ACTUAL_USER/start-uhj-pi.sh << 'EOF'
#!/bin/bash
# UHJ-Pi startup script (Simple version)

cd ~/UHJ-Pi

# Check if SuperCollider is already running
if pgrep -f "sclang.*UHJ_v24_Behringer_Boot.scd" > /dev/null; then
    echo "UHJ-Pi is already running"
    exit 0
fi

# Start SuperCollider with UHJ-Pi
echo "Starting UHJ-Pi..."
sclang supercollider/app/UHJ_v24_Behringer_Boot.scd
EOF

chmod +x /home/$ACTUAL_USER/start-uhj-pi.sh
chown $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/start-uhj-pi.sh

echo "Installation completed successfully!"
echo ""
echo "To run the UHJ Ambisonic System:"
echo "  sclang ~/UHJ-Pi/supercollider/app/UHJ_v24_Behringer_Boot.scd"
echo ""
echo "Or use the startup script:"
echo "  ~/start-uhj-pi.sh"
echo ""
echo "Note: This is the simple version without Qt GUI support."
echo "For full GUI support, use setup-raspberry-pi-qt.sh instead."