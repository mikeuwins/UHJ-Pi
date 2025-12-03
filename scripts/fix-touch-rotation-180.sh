#!/bin/bash

# UHJ-Pi Touch Screen 180-Degree Rotation Fix Script
# This script applies touch calibration fixes to an existing installation
# Run with: sudo ./scripts/fix-touch-rotation-180.sh

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Get the actual username
ACTUAL_USER=${SUDO_USER:-$(logname)}
if [ -z "$ACTUAL_USER" ]; then
    echo "Error: Could not determine username. Please run with: sudo -E ./scripts/fix-touch-rotation-180.sh"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  UHJ-Pi Touch Screen 180-Degree Rotation Fix"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This script will configure touch screen calibration for 180-degree rotation"
echo "Installing for user: $ACTUAL_USER"
echo ""

# Step 1: Set environment variable in user profile files
echo "Step 1: Setting environment variable in user profile files..."
if ! grep -q "LIBINPUT_CALIBRATION_MATRIX" "/home/$ACTUAL_USER/.bashrc"; then
    echo "export LIBINPUT_CALIBRATION_MATRIX=\"-1 0 1 0 -1 1\"" >> /home/$ACTUAL_USER/.bashrc
    echo "  ✓ Added to .bashrc"
else
    echo "  ✓ Already present in .bashrc"
fi

if ! grep -q "LIBINPUT_CALIBRATION_MATRIX" "/home/$ACTUAL_USER/.profile"; then
    echo "export LIBINPUT_CALIBRATION_MATRIX=\"-1 0 1 0 -1 1\"" >> /home/$ACTUAL_USER/.profile
    echo "  ✓ Added to .profile"
else
    echo "  ✓ Already present in .profile"
fi

# Step 2: Create system-wide environment file for early loading
echo ""
echo "Step 2: Creating system-wide environment file..."
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/touch-rotation.conf << EOF
[Manager]
DefaultEnvironment="LIBINPUT_CALIBRATION_MATRIX=-1 0 1 0 -1 1"
EOF
echo "  ✓ Created /etc/systemd/system.conf.d/touch-rotation.conf"

# Step 3: Create libinput quirks file (most reliable method)
echo ""
echo "Step 3: Creating libinput quirks file..."
mkdir -p /etc/libinput
cat > /etc/libinput/local-overrides.quirks << EOF
[UHJ-Pi Touch 180 Rotation]
MatchName=*
MatchUSBID=*:*
AttrCalibrationMatrix=-1 0 1 0 -1 1
EOF
echo "  ✓ Created /etc/libinput/local-overrides.quirks"

# Step 4: Create udev rule for touch screen calibration
echo ""
echo "Step 4: Creating udev rule for touch screen calibration..."
# Find touch screen device
TOUCH_DEVICE_PATH=$(find /dev/input -name "event*" 2>/dev/null | head -1)
if [ -n "$TOUCH_DEVICE_PATH" ]; then
    VENDOR_ID=$(udevadm info "$TOUCH_DEVICE_PATH" 2>/dev/null | grep -i "id_vendor" | cut -d'=' -f2 | head -1)
    PRODUCT_ID=$(udevadm info "$TOUCH_DEVICE_PATH" 2>/dev/null | grep -i "id_product" | cut -d'=' -f2 | head -1)
    
    if [ -n "$VENDOR_ID" ] && [ -n "$PRODUCT_ID" ]; then
        cat > /etc/udev/rules.d/99-touchscreen-rotation-180.rules << EOF
# UHJ-Pi: Touch screen 180-degree rotation
# Calibration matrix for 180-degree rotation: invert X and Y
ACTION=="add", SUBSYSTEM=="input", ATTRS{idVendor}=="$VENDOR_ID", ATTRS{idProduct}=="$PRODUCT_ID", ENV{LIBINPUT_CALIBRATION_MATRIX}="-1 0 1 0 -1 1"
EOF
        echo "  ✓ Created udev rule (Vendor: $VENDOR_ID, Product: $PRODUCT_ID)"
    else
        echo "  ⚠ Could not determine touch device IDs, skipping udev rule"
    fi
else
    echo "  ⚠ Touch device not found, skipping udev rule"
fi

# Step 5: Update startup scripts
echo ""
echo "Step 5: Updating startup scripts..."

# Find and update all startup scripts
STARTUP_SCRIPTS=(
    "/home/$ACTUAL_USER/UHJ-Pi/start-esi.sh"
    "/home/$ACTUAL_USER/UHJ-Pi/start-vin.sh"
    "/home/$ACTUAL_USER/UHJ-Pi/start-beh.sh"
    "/home/$ACTUAL_USER/UHJ-Pi/start-gen.sh"
    "/home/$ACTUAL_USER/UHJ-Pi/start-player.sh"
)

for script in "${STARTUP_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        if ! grep -q "LIBINPUT_CALIBRATION_MATRIX" "$script"; then
            # Add export right before sclang launch
            sed -i '/^sclang/i export LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"' "$script"
            echo "  ✓ Updated $(basename $script)"
        else
            echo "  ✓ $(basename $script) already has touch calibration"
        fi
    fi
done

# Step 6: Reload systemd and udev
echo ""
echo "Step 6: Reloading systemd and udev rules..."
systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger
echo "  ✓ Systemd and udev rules reloaded"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Touch calibration fix complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Configuration applied:"
echo "  ✓ User profile environment variables (.bashrc, .profile)"
echo "  ✓ System-wide environment file (/etc/systemd/system.conf.d/touch-rotation.conf)"
echo "  ✓ Libinput quirks file (/etc/libinput/local-overrides.quirks)"
echo "  ✓ Udev rule (/etc/udev/rules.d/99-touchscreen-rotation-180.rules)"
echo "  ✓ Startup scripts updated"
echo ""
echo "Next steps:"
echo "  1. Reboot the system: sudo reboot"
echo "  2. After reboot, test the touch screen"
echo ""
echo "If touch is still not working correctly after reboot, you may need to:"
echo "  - Check which touch device is being used: ls -la /dev/input/"
echo "  - Verify the calibration matrix is correct for your screen size"
echo "  - Try manually exporting the variable: export LIBINPUT_CALIBRATION_MATRIX=\"-1 0 1 0 -1 1\""
echo ""

