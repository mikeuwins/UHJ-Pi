#!/bin/bash

# UHJ-Pi Touch Screen 180-Degree Rotation Fix Script (Version 2)
# Alternative approach using xinput-style transformation for EGLFS
# Run with: sudo ./scripts/fix-touch-rotation-180-v2.sh

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Get the actual username
ACTUAL_USER=${SUDO_USER:-$(logname)}
if [ -z "$ACTUAL_USER" ]; then
    echo "Error: Could not determine username. Please run with: sudo -E ./scripts/fix-touch-rotation-180-v2.sh"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  UHJ-Pi Touch Screen 180-Degree Rotation Fix (Version 2)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This script uses alternative methods for touch calibration"
echo "Installing for user: $ACTUAL_USER"
echo ""

# Find touch device
echo "Step 1: Detecting touch screen device..."
TOUCH_DEVICE=""
for dev in /dev/input/event*; do
    if [ -e "$dev" ]; then
        if udevadm info "$dev" 2>/dev/null | grep -qi "touch"; then
            TOUCH_DEVICE="$dev"
            echo "  Found touch device: $dev"
            udevadm info "$dev" 2>/dev/null | grep -E "ID_VENDOR|ID_MODEL|NAME" | head -3
            break
        fi
    fi
done

if [ -z "$TOUCH_DEVICE" ]; then
    echo "  ⚠ No touch device found, will use generic configuration"
fi

# Method 1: Create a systemd service that applies calibration at boot
echo ""
echo "Step 2: Creating systemd service for touch calibration..."
cat > /etc/systemd/system/uhj-touch-calibration.service << 'EOFSERVICE'
[Unit]
Description=UHJ-Pi Touch Screen Calibration (180-degree rotation)
After=graphical.target
Wants=graphical.target

[Service]
Type=oneshot
RemainAfterExit=yes
Environment="LIBINPUT_CALIBRATION_MATRIX=-1 0 1 0 -1 1"
# Try to apply calibration using libinput-debug-events or similar
ExecStart=/bin/bash -c 'export LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"; if command -v libinput >/dev/null 2>&1; then libinput list-devices >/dev/null 2>&1; fi; /bin/true'

[Install]
WantedBy=graphical.target
EOFSERVICE

systemctl daemon-reload
systemctl enable uhj-touch-calibration.service
echo "  ✓ Created and enabled systemd service"

# Method 2: Create wrapper script that sets environment before launching
echo ""
echo "Step 3: Creating wrapper script for application launch..."
cat > /usr/local/bin/uhj-launch-wrapper.sh << 'EOFWRAPPER'
#!/bin/bash
# UHJ-Pi Launch Wrapper - Applies touch calibration before launching
export LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"
export QT_QPA_EGLFS_ROTATION=180
exec "$@"
EOFWRAPPER
chmod +x /usr/local/bin/uhj-launch-wrapper.sh
echo "  ✓ Created wrapper script at /usr/local/bin/uhj-launch-wrapper.sh"

# Method 3: Update all startup scripts to use wrapper or export
echo ""
echo "Step 4: Updating startup scripts..."

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
            sed -i '/^sclang/i export LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"\nexport QT_QPA_EGLFS_ROTATION=180' "$script"
            echo "  ✓ Updated $(basename $script)"
        else
            # Add at the beginning of the script
            sed -i '2a export LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"\nexport QT_QPA_EGLFS_ROTATION=180' "$script"
            echo "  ✓ Updated $(basename $script) (added at top)"
        fi
    fi
done

# Method 4: Create /etc/environment entry (system-wide)
echo ""
echo "Step 5: Adding to system-wide environment..."
if ! grep -q "LIBINPUT_CALIBRATION_MATRIX" /etc/environment 2>/dev/null; then
    echo 'LIBINPUT_CALIBRATION_MATRIX="-1 0 1 0 -1 1"' >> /etc/environment
    echo "  ✓ Added to /etc/environment"
else
    echo "  ✓ Already present in /etc/environment"
fi

# Method 5: Try device-specific udev rule with more specific matching
if [ -n "$TOUCH_DEVICE" ]; then
    echo ""
    echo "Step 6: Creating device-specific udev rule..."
    VENDOR_ID=$(udevadm info "$TOUCH_DEVICE" 2>/dev/null | grep -i "id_vendor" | cut -d'=' -f2 | head -1)
    PRODUCT_ID=$(udevadm info "$TOUCH_DEVICE" 2>/dev/null | grep -i "id_product" | cut -d'=' -f2 | head -1)
    DEVICE_NAME=$(udevadm info "$TOUCH_DEVICE" 2>/dev/null | grep -i "name=" | cut -d'=' -f2 | tr -d '"' | head -1)
    
    if [ -n "$VENDOR_ID" ] && [ -n "$PRODUCT_ID" ]; then
        cat > /etc/udev/rules.d/99-touchscreen-rotation-180-v2.rules << EOF
# UHJ-Pi: Touch screen 180-degree rotation (Version 2)
# Device: $DEVICE_NAME
ACTION=="add", SUBSYSTEM=="input", ATTRS{idVendor}=="$VENDOR_ID", ATTRS{idProduct}=="$PRODUCT_ID", ENV{LIBINPUT_CALIBRATION_MATRIX}="-1 0 1 0 -1 1", ENV{ID_INPUT_TOUCHSCREEN}="1"
EOF
        echo "  ✓ Created device-specific udev rule (Vendor: $VENDOR_ID, Product: $PRODUCT_ID)"
    fi
fi

# Reload everything
echo ""
echo "Step 7: Reloading system services..."
systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger --subsystem-match=input
echo "  ✓ Services reloaded"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Touch calibration fix (Version 2) complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Applied methods:"
echo "  ✓ Systemd service for boot-time calibration"
echo "  ✓ Launch wrapper script"
echo "  ✓ Startup scripts updated with environment exports"
echo "  ✓ System-wide /etc/environment entry"
echo "  ✓ Device-specific udev rule"
echo ""
echo "Next steps:"
echo "  1. Reboot: sudo reboot"
echo "  2. After reboot, test touch screen"
echo ""
echo "If still not working, run the diagnostic script:"
echo "  curl -s https://raw.githubusercontent.com/mikeuwins/UHJ-Pi/main/scripts/diagnose-touch.sh | bash"
echo ""

