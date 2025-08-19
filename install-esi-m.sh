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
echo "initramfs-tools initramfs-tools/update_initramfs boolean false" | debconf-set-selections
echo "jackd jackd/tweak_rt_limits boolean true" | debconf-set-selections

# STEP 1: System Update
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y

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
cmake -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF -DSC_EL=OFF -DSC_VIM=ON -DNATIVE=ON -DSC_IDE=OFF -DNO_X11=ON -DSC_QT=ON ..

# STEP 7: Build SuperCollider
make -j2

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
usermod -aG audio,plugdev $ACTUAL_USER

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

# STEP 13: Install ATK and handle GUI component cleanup (MANUAL APPROACH)
echo "Installing ATK and handling GUI component cleanup (manual approach)..."
cd /home/$ACTUAL_USER

# Create necessary directories
sudo -u $ACTUAL_USER mkdir -p ~/.local/share/SuperCollider/downloaded-quarks
sudo -u $ACTUAL_USER mkdir -p ~/.local/share/ATK

# Install ATK quark manually (clone repo)
echo "Installing ATK quark manually..."
cd ~/.local/share/SuperCollider/downloaded-quarks
sudo -u $ACTUAL_USER git clone https://github.com/ambisonictoolkit/atk-sc3.git

# Remove problematic GUI components (keeping PointView as it works in the system)
echo "Removing problematic GUI components..."
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/GUI/
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main\ Features/Interpolation/extPen-splineCurve.sc
rm ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main\ Features/SVGFile/extColPen-asSVGFile.sc

# Download ATK assets manually (kernels and matrices only)
echo "Downloading ATK kernels and matrices manually..."
cd ~/.local/share/ATK

# Download kernels
sudo -u $ACTUAL_USER curl -L "https://github.com/ambisonictoolkit/atk-sc3/releases/download/v2.2.0/ATK-kernels-v2.2.0.zip" -o kernels.zip
sudo -u $ACTUAL_USER unzip -o kernels.zip
sudo -u $ACTUAL_USER rm kernels.zip

# Download matrices  
sudo -u $ACTUAL_USER curl -L "https://github.com/ambisonictoolkit/atk-sc3/releases/download/v2.2.0/ATK-matrices-v2.2.0.zip" -o matrices.zip
sudo -u $ACTUAL_USER unzip -o matrices.zip
sudo -u $ACTUAL_USER rm matrices.zip

# Download ATK sounds (optional - increases installation time)
echo "Downloading ATK sounds manually..."
sudo -u $ACTUAL_USER curl -L "https://github.com/ambisonictoolkit/atk-sc3/releases/download/v2.2.0/ATK-sounds-v2.2.0.zip" -o sounds.zip
sudo -u $ACTUAL_USER unzip -o sounds.zip
sudo -u $ACTUAL_USER rm sounds.zip

# Install AmbiVerbSC manually
echo "Installing AmbiVerbSC manually..."
cd ~/.local/share/SuperCollider/downloaded-quarks
sudo -u $ACTUAL_USER git clone https://github.com/JamesWenlock/AmbiVerbSC.git

# STEP 14: Install custom user classes
echo "Installing custom user classes..."
cd /home/$ACTUAL_USER/UHJ-Pi/supercollider/extensions

# Copy custom extensions to SuperCollider Extensions directory (only if they don't exist)
if [ ! -d "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/ServerMeter2" ]; then
    cp -r ServerMeter2 /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
fi
if [ ! -d "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/Knob360" ]; then
    cp -r Knob360 /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
fi
if [ ! -d "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/MaplinMatrix" ]; then
    cp -r MaplinMatrix /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
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
echo "  sclang ~/UHJ-Pi/supercollider/app/UHJ_v20.scd" 