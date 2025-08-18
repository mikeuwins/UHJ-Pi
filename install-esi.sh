#!/bin/bash

# UHJ-Pi Raspberry Pi Setup Script (Qt Version)

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Get the actual username (the user who ran sudo)
ACTUAL_USER=${SUDO_USER:-$(logname)}
if [ -z "$ACTUAL_USER" ]; then
    echo "Error: Could not determine username. Please run with: sudo -E ./setup-raspberry-pi-qt.sh"
    exit 1
fi

echo "UHJ-Pi Raspberry Pi Setup Script (Qt Version) - Starting installation..."
echo "Installing for user: $ACTUAL_USER"

# Configure non-interactive package installation BEFORE any apt commands
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none
# Prefer keeping existing config files automatically
export DPKG_OPTS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
# Preseed to prevent interactive initramfs prompts and disable updates during install
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

# Configure HDMI display for better external monitor quality
if ! grep -q "hdmi_group=1" /boot/firmware/config.txt; then
    echo "hdmi_group=1" >> /boot/firmware/config.txt
fi
if ! grep -q "hdmi_mode=16" /boot/firmware/config.txt; then
    echo "hdmi_mode=16" >> /boot/firmware/config.txt
fi
if ! grep -q "disable_overscan=1" /boot/firmware/config.txt; then
    echo "disable_overscan=1" >> /boot/firmware/config.txt
fi
if ! grep -q "hdmi_force_hotplug=1" /boot/firmware/config.txt; then
    echo "hdmi_force_hotplug=1" >> /boot/firmware/config.txt
fi

# STEP 3: Install X11 and Blackbox
apt install -y xserver-xorg x11-xserver-utils xinit blackbox xvfb

# Configure display environment for Qt
export DISPLAY=:0
export QT_QPA_PLATFORM=eglfs

# Kill any existing Xvfb processes
pkill Xvfb 2>/dev/null || true

# Note: eglfs doesn't need Xvfb as it connects directly to the graphics hardware
# Remove Xvfb startup since we're using eglfs for embedded display

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

# STEP 6: Configure SuperCollider Build
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

# Create general SuperCollider HID rule for headtrackers and other HID devices
cat > /etc/udev/rules.d/99-supercollider-hid.rules << 'EOF'
# Generic HID access for SuperCollider (headtrackers, controllers, etc.)
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="plugdev"
EOF

# Reload udev rules
udevadm control --reload-rules
udevadm trigger

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

# Note: We'll remove problematic GUI components after ATK installation
# to avoid conflicts with ATK's dependencies

# STEP 12: Clone UHJ-Pi repository and build phono-control CLI
cd /home/$ACTUAL_USER
if [ ! -d "UHJ-Pi" ]; then
    git clone https://github.com/mikeuwins/UHJ-Pi.git
fi
cd UHJ-Pi/cli/phonorama-cli-linux
chmod +x build.sh
./build.sh

# STEP 13: Install ATK and download assets
echo "Installing ATK and downloading assets..."
cd /home/$ACTUAL_USER

# Note: eglfs doesn't need Xvfb as it connects directly to the graphics hardware
# Remove Xvfb checks since we're using eglfs for embedded display

# Note: We'll install ATK after removing problematic components
# so sclang can run properly

# STEP 14: Remove problematic GUI components (fixes sclang display issues)
echo "Removing problematic GUI components..."
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/PointView/
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/GUI/
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main\ Features/Interpolation/extPen-splineCurve.sc
rm ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main\ Features/SVGFile/extColPen-asSVGFile.sc

# Note: PointView is now installed by ATK, so we can remove it if needed

# STEP 15: Install ATK and AmbiVerbSC (now that sclang can run properly)
echo "Installing ATK and AmbiVerbSC..."
sudo -u $ACTUAL_USER bash -c 'export DISPLAY=:0; export QT_QPA_PLATFORM=eglfs; echo "Quarks.install(\"https://github.com/ambisonictoolkit/atk-sc3.git\"); 0.exit;" | sclang -l /dev/null'
sudo -u $ACTUAL_USER bash -c 'export DISPLAY=:0; export QT_QPA_PLATFORM=eglfs; echo "Quarks.install(\"https://github.com/JamesWenlock/AmbiVerbSC\"); 0.exit;" | sclang -l /dev/null'

# Now uninstall PointView (since ATK has what it needs)
sudo -u $ACTUAL_USER sclang -l /dev/null -e 'Quarks.uninstall("PointView"); 0.exit;'

# STEP 16: Download ATK assets (now that sclang can run properly)
echo "Downloading ATK assets..."
sudo -u $ACTUAL_USER bash -c 'export DISPLAY=:0; export QT_QPA_PLATFORM=eglfs; echo "Atk.downloadKernels(); Atk.downloadMatrices(); Atk.downloadSounds(); 0.exit;" | sclang -l /dev/null'

# STEP 17: Install custom user classes
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

# STEP 18: Create simple launcher script
echo "Creating simple launcher script..."
cat > /usr/local/bin/uhj << 'EOF'
#!/bin/bash
cd ~/UHJ-Pi/supercollider/app
export DISPLAY=:0
export QT_QPA_PLATFORM=eglfs
sclang UHJ_v21.scd
EOF
chmod +x /usr/local/bin/uhj

# STEP 19: Install custom fonts
echo "Installing custom fonts..."
cd /home/$ACTUAL_USER/UHJ-Pi/assets/fonts

# Create fonts directory if it doesn't exist
mkdir -p /usr/local/share/fonts/truetype/uhj-pi

# Copy custom fonts to system font directory
cp lcd_segment_monospace/lcd-5x7-segment-monospace.ttf /usr/local/share/fonts/truetype/uhj-pi/
cp led_dot_matrix/LED\ Dot-Matrix.ttf /usr/local/share/fonts/truetype/uhj-pi/

# Install Arial font for power button
echo "Installing Arial font..."
apt-get install -y cabextract
mkdir -p /usr/share/fonts/truetype/msttcorefonts
cd /usr/share/fonts/truetype/msttcorefonts
# Download just Arial font directly
wget -q https://github.com/matomo-org/travis-scripts/raw/master/fonts/Arial.ttf

# Update font cache
fc-cache -f -v

echo "Custom fonts installed:"
echo "  - lcd-5x7-segment-monospace.ttf"
echo "  - LED Dot-Matrix.ttf"
echo "  - Arial"

# Add display environment variables to user's .bashrc for future sessions
if ! grep -q "export DISPLAY=:0" /home/$ACTUAL_USER/.bashrc; then
    echo "" >> /home/$ACTUAL_USER/.bashrc
    echo "# SuperCollider Qt display environment" >> /home/$ACTUAL_USER/.bashrc
    echo "export DISPLAY=:0" >> /home/$ACTUAL_USER/.bashrc
    echo "export QT_QPA_PLATFORM=eglfs" >> /home/$ACTUAL_USER/.bashrc
fi

echo "Installation completed successfully!"
echo ""
echo "To run the UHJ Ambisonic System:"
echo "  sclang ~/UHJ-Pi/supercollider/app/UHJ_v21.scd"
echo ""
echo "Or use the simple launcher:"
echo "  uhj"