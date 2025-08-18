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
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none
export DPKG_OPTS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
# Preseed to prevent interactive prompts
echo "initramfs-tools initramfs-tools/update_initramfs boolean false" | debconf-set-selections
echo "jackd jackd/tweak_rt_limits boolean true" | debconf-set-selections

# STEP 1: System Update
apt-get update
apt-get upgrade -y $DPKG_OPTS
apt-get dist-upgrade -y $DPKG_OPTS

# STEP 2: Disable Onboard and HDMI Audio
if ! grep -q "dtparam=audio=off" /boot/firmware/config.txt; then
    echo "dtparam=audio=off" >> /boot/firmware/config.txt
fi
if ! grep -q "dtoverlay=vc4-kms-v3d,noaudio" /boot/firmware/config.txt; then
    echo "dtoverlay=vc4-kms-v3d,noaudio" >> /boot/firmware/config.txt
fi

# STEP 3: Install X11 and Blackbox
apt install -y xserver-xorg x11-xserver-utils xinit blackbox

# Configure display environment for Qt
export DISPLAY=:0
export QT_QPA_PLATFORM=eglfs

# STEP 4: Install SuperCollider Dependencies (including Qt)
apt-get install -y build-essential cmake libjack-jackd2-dev libsndfile1-dev libfftw3-dev libxt-dev libavahi-client-dev libudev-dev libasound2-dev libreadline-dev libxkbcommon-dev git jackd2 libhidapi-dev qt6-base-dev qt6-svg-dev qt6-tools-dev qt6-wayland qt6-websockets-dev qt6-webengine-dev

# STEP 5: Clone SuperCollider
cd /home/$ACTUAL_USER
if [ ! -d "supercollider" ]; then
    git clone --branch main --recurse-submodules https://github.com/supercollider/supercollider.git
fi
cd supercollider
mkdir -p build
cd build

# STEP 6: Configure SuperCollider Build (with Qt support)
cmake -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF -DSC_EL=OFF -DSC_VIM=ON -DNATIVE=ON -DSC_IDE=OFF -DNO_X11=OFF -DSC_QT=ON ..

# STEP 7: Build SuperCollider
make -j3

# STEP 8: Install SuperCollider
sudo make install
sudo ldconfig

# STEP 9: Set up udev rules for HID and audio permissions
cat > /etc/udev/rules.d/99-phonorama.rules << 'EOF'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2573", ATTRS{idProduct}=="0001", GROUP="plugdev", MODE="0660"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", GROUP="plugdev", MODE="0660"
SUBSYSTEM=="audio", MODE="0666"
EOF

# STEP 10: Configure JACK Audio
echo "/usr/bin/jackd -P75 -d alsa -C hw:Phonorama -P hw:HD -r 44100 -p 256 -n 2 -S &" > /home/$ACTUAL_USER/.jackdrc
usermod -aG audio,plugdev,video,render $ACTUAL_USER

# STEP 11: Install SC3 Plugins
cd /home/$ACTUAL_USER
if [ ! -d "sc3-plugins" ]; then
    git clone --recursive https://github.com/supercollider/sc3-plugins.git
fi
cd sc3-plugins
mkdir build && cd build
cmake -DSC_PATH=/home/$ACTUAL_USER/supercollider -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF ..
cmake --build . --config Release
sudo cmake --build . --config Release --target install

# STEP 12: Clone UHJ-Pi repository and build phono-control CLI
cd /home/$ACTUAL_USER
if [ ! -d "UHJ-Pi" ]; then
    git clone https://github.com/mikeuwins/UHJ-Pi.git
fi
cd UHJ-Pi/cli/phonorama-cli-linux
chmod +x build.sh
./build.sh

# STEP 13: Install ATK and handle GUI component cleanup
echo "Installing ATK and handling GUI component cleanup..."
cd /home/$ACTUAL_USER

# Install ATK quark (headless to avoid display issues)
sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");
0.exit;
EOF'

# Remove problematic GUI components
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/PointView/
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/GUI/
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main\ Features/Interpolation/extPen-splineCurve.sc
rm ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main\ Features/SVGFile/extColPen-asSVGFile.sc

# Uninstall PointView quark (headless)
sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.uninstall("PointView");
0.exit;
EOF'

# Download ATK kernels, matrices, and sounds (headless)
sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Atk.downloadKernels();
Atk.downloadMatrices();
Atk.downloadSounds();
0.exit;
EOF'

# Install AmbiVerbSC (headless)
sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.install("https://github.com/JamesWenlock/AmbiVerbSC");
0.exit;
EOF'

# STEP 14: Install custom user classes
echo "Installing custom user classes..."
cd /home/$ACTUAL_USER/UHJ-Pi/supercollider/extensions

# Copy custom extensions to SuperCollider Extensions directory
cp -r ServerMeter2 /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
cp -r Knob360 /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
cp -r MaplinMatrix /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
cp -r MaplinSM333 /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/

# Set proper ownership
chown -R $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/

echo "Installation completed successfully!"
echo ""
echo "To run the UHJ Ambisonic System:"
echo "  sclang ~/UHJ-Pi/supercollider/app/UHJ_v21.scd"