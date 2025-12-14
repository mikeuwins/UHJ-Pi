#!/bin/bash

# UHJ-Pi Installation Completion Script
# Run this AFTER SuperCollider has been built and installed

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Get the actual username (the user who ran sudo)
ACTUAL_USER=${SUDO_USER:-$(logname)}
if [ -z "$ACTUAL_USER" ]; then
    echo "Error: Could not determine username. Please run with: sudo -E ./complete-uhj-pi-install.sh"
    exit 1
fi

echo "UHJ-Pi Installation Completion Script - Continuing from SuperCollider installation..."
echo "Installing for user: $ACTUAL_USER"

# STEP 1: Install SC3 Plugins
echo "Step 1: Installing SC3 plugins..."
cd /home/$ACTUAL_USER
if [ ! -d "sc3-plugins" ]; then
    echo "Error: sc3-plugins directory not found. Please run the main installation script first."
    exit 1
fi
cd sc3-plugins
mkdir -p build && cd build
cmake -DSC_PATH=/home/$ACTUAL_USER/supercollider -DCMAKE_BUILD_TYPE=Release -DSUPERNOVA=OFF ..
cmake --build . --config Release
cmake --build . --config Release --target install

# STEP 2: Build phono-control CLI
echo "Step 2: Building phono-control CLI..."
cd /home/$ACTUAL_USER
if [ ! -d "UHJ-Pi" ]; then
    echo "Error: UHJ-Pi directory not found. Please run the main installation script first."
    exit 1
fi
cd UHJ-Pi/cli/phonorama-cli-linux
chmod +x build.sh
./build.sh

# STEP 3: Install ATK and handle GUI component cleanup
echo "Step 3: Installing ATK and cleaning up GUI components..."
cd /home/$ACTUAL_USER

# Set headless Qt platform for sclang operations
export QT_QPA_PLATFORM=offscreen

# Install ATK quark
echo "Installing ATK quark..."
sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");
thisProcess.recompile;
0.exit;
EOF'

# Remove problematic GUI components
echo "Removing problematic GUI components..."
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/PointView/
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/GUI/
rm -rf ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main\ Features/Interpolation/extPen-splineCurve.sc
rm ~/.local/share/SuperCollider/downloaded-quarks/wslib/wslib-classes/Main\ Features/SVGFile/extColPen-asSVGFile.sc

# Uninstall PointView quark
echo "Uninstalling PointView quark..."
sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.uninstall("PointView");
0.exit;
EOF'

# Download ATK kernels, matrices, and sounds
echo "Downloading ATK assets..."
sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Atk.downloadKernels();
Atk.downloadMatrices();
Atk.downloadSounds();
0.exit;
EOF'

# Install AmbiVerbSC
echo "Installing AmbiVerbSC..."
sudo -u $ACTUAL_USER bash -c 'export QT_QPA_PLATFORM=offscreen; sclang -l /dev/null << EOF
Quarks.install("https://github.com/JamesWenlock/AmbiVerbSC");
0.exit;
EOF'

# STEP 4: Install custom user classes
echo "Step 4: Installing custom user classes..."
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
if [ ! -d "/home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/MaplinSM333" ]; then
    cp -r MaplinSM333 /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/
fi

# Set proper ownership
chown -R $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/.local/share/SuperCollider/Extensions/

# STEP 5: Set up udev rules for HID and audio permissions
echo "Step 5: Setting up udev rules..."
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

# STEP 6: Configure JACK Audio
echo "Step 6: Configuring JACK audio..."
echo "/usr/bin/jackd -P75 -d alsa -C hw:Phonorama -P hw:HD -r 44100 -p 256 -n 2 -S &" > /home/$ACTUAL_USER/.jackdrc
usermod -aG audio,plugdev $ACTUAL_USER

# STEP 7: Create control scripts
echo "Step 7: Creating control scripts..."

# Create startup script
cat > /home/$ACTUAL_USER/start-uhj-pi.sh << 'EOF'
#!/bin/bash
# UHJ-Pi startup script

cd ~/UHJ-Pi

# Check if SuperCollider is already running
if pgrep -f "sclang.*UHJ_v24_Behringer_Boot.scd" > /dev/null; then
    echo "UHJ-Pi is already running"
    exit 0
fi

# Start SuperCollider with UHJ-Pi
echo "Starting UHJ-Pi..."
export QT_QPA_PLATFORM=eglfs
sclang supercollider/app/UHJ_v24_Behringer_Boot.scd
EOF

chmod +x /home/$ACTUAL_USER/start-uhj-pi.sh
chown $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/start-uhj-pi.sh

# Create stop script
cat > /home/$ACTUAL_USER/stop-uhj-pi.sh << 'EOF'
#!/bin/bash
# UHJ-Pi stop script

echo "Stopping UHJ-Pi..."

# Kill SuperCollider processes
pkill -f "sclang.*UHJ_v24_Behringer_Boot.scd" 2>/dev/null || true
pkill sclang 2>/dev/null || true

echo "UHJ-Pi stopped"
EOF

chmod +x /home/$ACTUAL_USER/stop-uhj-pi.sh
chown $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/stop-uhj-pi.sh

echo "Installation completion finished successfully!"
echo ""
echo "To start UHJ-Pi:"
echo "  ~/start-uhj-pi.sh"
echo ""
echo "To stop UHJ-Pi:"
echo "  ~/stop-uhj-pi.sh"
echo ""
echo "To manually run the UHJ Ambisonic System:"
echo "  export QT_QPA_PLATFORM=eglfs"
echo "  sclang ~/UHJ-Pi/supercollider/app/UHJ_v24_Behringer_Boot.scd"
echo ""
echo "Note: Use QT_QPA_PLATFORM=eglfs for runtime (not offscreen)" 