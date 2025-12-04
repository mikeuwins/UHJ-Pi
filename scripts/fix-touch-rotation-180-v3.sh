#!/bin/bash

# UHJ-Pi Touch Screen 180-Degree Rotation Fix Script (Version 3)
# More robust version that ensures udev rules are created
# Run with: sudo ./scripts/fix-touch-rotation-180-v3.sh

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Get the actual username
ACTUAL_USER=${SUDO_USER:-$(logname)}
if [ -z "$ACTUAL_USER" ]; then
    echo "Error: Could not determine username. Please run with: sudo -E ./scripts/fix-touch-rotation-180-v3.sh"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  UHJ-Pi Touch Screen 180-Degree Rotation Fix (Version 3)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Installing for user: $ACTUAL_USER"
echo ""

# Step 1: Find ALL input devices and create comprehensive udev rules
echo "Step 1: Detecting all input devices..."
INPUT_DEVICES=()
for dev in /dev/input/event*; do
    if [ -e "$dev" ]; then
        INPUT_DEVICES+=("$dev")
        echo "  Found: $dev"
        udevadm info "$dev" 2>/dev/null | grep -E "ID_VENDOR|ID_MODEL|NAME|ID_INPUT" | head -5
        echo ""
    fi
done

# Step 2: Create a comprehensive udev rule that matches all touch devices
echo "Step 2: Creating comprehensive udev rules..."
cat > /etc/udev/rules.d/99-touchscreen-rotation-180.rules << 'EOF'
# UHJ-Pi: Touch screen 180-degree rotation
# This rule applies to all input devices that could be touch screens
# Calibration matrix for 180-degree rotation: invert X and Y
# Matrix format: "a b c d e f" = "-1 0 1 0 -1 1"
# This means: new_x = -1*old_x + 0*old_y + 1, new_y = 0*old_x + -1*old_y + 1

# Match any input device (we'll be specific but broad)
ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ENV{LIBINPUT_CALIBRATION_MATRIX}="-1 0 1 0 -1 1"
EOF

# Also create device-specific rules for each detected device
RULE_COUNT=0
for dev in "${INPUT_DEVICES[@]}"; do
    VENDOR_ID=$(udevadm info "$dev" 2>/dev/null | grep -i "id_vendor" | cut -d'=' -f2 | head -1)
    PRODUCT_ID=$(udevadm info "$dev" 2>/dev/null | grep -i "id_product" | cut -d'=' -f2 | head -1)
    DEVICE_NAME=$(udevadm info "$dev" 2>/dev/null | grep -i "name=" | cut -d'=' -f2 | tr -d '"' | head -1)
    
    if [ -n "$VENDOR_ID" ] && [ -n "$PRODUCT_ID" ]; then
        cat >> /etc/udev/rules.d/99-touchscreen-rotation-180.rules << EOF

# Device-specific rule: $DEVICE_NAME
ACTION=="add", SUBSYSTEM=="input", ATTRS{idVendor}=="$VENDOR_ID", ATTRS{idProduct}=="$PRODUCT_ID", ENV{LIBINPUT_CALIBRATION_MATRIX}="-1 0 1 0 -1 1"
EOF
        RULE_COUNT=$((RULE_COUNT + 1))
        echo "  ✓ Added rule for device: $DEVICE_NAME (Vendor: $VENDOR_ID, Product: $PRODUCT_ID)"
    fi
done

echo "  ✓ Created udev rule file with $RULE_COUNT device-specific rules"
echo "  ✓ File location: /etc/udev/rules.d/99-touchscreen-rotation-180.rules"

# Step 3: Set environment variables
echo ""
echo "Step 3: Setting environment variables..."
if ! grep -q "LIBINPUT_CALIBRATION_MATRIX" "/home/$ACTUAL_USER/.bashrc"; then
    echo "export LIBINPUT_CALIBRATION_MATRIX=\"-1 0 1 0 -1 1\"" >> /home/$ACTUAL_USER/.bashrc
    echo "  ✓ Added to .bashrc"
fi

if ! grep -q "LIBINPUT_CALIBRATION_MATRIX" "/home/$ACTUAL_USER/.profile"; then
    echo "export LIBINPUT_CALIBRATION_MATRIX=\"-1 0 1 0 -1 1\"" >> /home/$ACTUAL_USER/.profile
    echo "  ✓ Added to .profile"
fi

# Step 4: System-wide environment
echo ""
echo "Step 4: Creating system-wide environment files..."
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/touch-rotation.conf << EOF
[Manager]
DefaultEnvironment="LIBINPUT_CALIBRATION_MATRIX=-1 0 1 0 -1 1"
EOF
echo "  ✓ Created /etc/systemd/system.conf.d/touch-rotation.conf"

if ! grep -q "LIBINPUT_CALIBRATION_MATRIX" /etc/environment 2>/dev/null; then
    echo 'LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"' >> /etc/environment
    echo "  ✓ Added to /etc/environment"
fi

# Step 5: Libinput quirks
echo ""
echo "Step 5: Creating libinput quirks file..."
mkdir -p /etc/libinput
cat > /etc/libinput/local-overrides.quirks << EOF
[UHJ-Pi Touch 180 Rotation]
MatchName=*
MatchUSBID=*:*
AttrCalibrationMatrix=-1 0 1 0 -1 1
EOF
echo "  ✓ Created /etc/libinput/local-overrides.quirks"

# Step 6: Update startup scripts
echo ""
echo "Step 6: Updating startup scripts..."
STARTUP_SCRIPTS=(
    "/home/$ACTUAL_USER/UHJ-Pi/start-esi.sh"
    "/home/$ACTUAL_USER/UHJ-Pi/start-vin.sh"
    "/home/$ACTUAL_USER/UHJ-Pi/start-beh.sh"
    "/home/$ACTUAL_USER/UHJ-Pi/start-gen.sh"
    "/home/$ACTUAL_USER/UHJ-Pi/start-player.sh"
)

for script in "${STARTUP_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        # Remove any existing LIBINPUT_CALIBRATION_MATRIX lines
        sed -i '/LIBINPUT_CALIBRATION_MATRIX/d' "$script"
        
        # Add export right before sclang launch
        if grep -q "^sclang" "$script"; then
            sed -i '/^sclang/i export LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"' "$script"
            echo "  ✓ Updated $(basename $script)"
        fi
    fi
done

# Step 7: Reload udev and verify
echo ""
echo "Step 7: Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger --subsystem-match=input
systemctl daemon-reload

echo ""
echo "Verifying udev rule file exists..."
if [ -f "/etc/udev/rules.d/99-touchscreen-rotation-180.rules" ]; then
    echo "  ✓ Udev rule file exists"
    echo "  File size: $(wc -l < /etc/udev/rules.d/99-touchscreen-rotation-180.rules) lines"
    echo ""
    echo "  First few lines of the rule file:"
    head -10 /etc/udev/rules.d/99-touchscreen-rotation-180.rules
else
    echo "  ✗ ERROR: Udev rule file was not created!"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Touch calibration fix (Version 3) complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Configuration applied:"
echo "  ✓ Comprehensive udev rule (matches all input devices)"
echo "  ✓ User profile environment variables"
echo "  ✓ System-wide environment files"
echo "  ✓ Libinput quirks file"
echo "  ✓ Startup scripts updated"
echo ""
echo "Next steps:"
echo "  1. Reboot: sudo reboot"
echo "  2. After reboot, verify with: ls -la /etc/udev/rules.d/*touch*"
echo "  3. Test touch screen"
echo ""

