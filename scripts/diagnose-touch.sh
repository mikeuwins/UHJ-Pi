#!/bin/bash

# UHJ-Pi Touch Screen Diagnostic Script
# This script helps diagnose touch screen issues

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  UHJ-Pi Touch Screen Diagnostic"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "1. Checking touch input devices..."
ls -la /dev/input/ | grep -E "event|mouse"
echo ""

echo "2. Checking for touch devices via udev..."
for dev in /dev/input/event*; do
    if [ -e "$dev" ]; then
        echo "Device: $dev"
        udevadm info "$dev" 2>/dev/null | grep -E "ID_INPUT_TOUCH|ID_VENDOR|ID_MODEL|NAME" | head -5
        echo ""
    fi
done

echo "3. Checking environment variables..."
echo "LIBINPUT_CALIBRATION_MATRIX: ${LIBINPUT_CALIBRATION_MATRIX:-not set}"
echo "QT_QPA_EGLFS_ROTATION: ${QT_QPA_EGLFS_ROTATION:-not set}"
echo ""

echo "4. Checking configuration files..."
echo "System-wide environment:"
cat /etc/systemd/system.conf.d/touch-rotation.conf 2>/dev/null || echo "  Not found"
echo ""

echo "Libinput quirks:"
cat /etc/libinput/local-overrides.quirks 2>/dev/null || echo "  Not found"
echo ""

echo "Udev rules:"
ls -la /etc/udev/rules.d/*touch* 2>/dev/null || echo "  No touch-related udev rules found"
echo ""

echo "5. Checking user profile files..."
grep -h "LIBINPUT_CALIBRATION_MATRIX" ~/.bashrc ~/.profile 2>/dev/null || echo "  Not found in .bashrc or .profile"
echo ""

echo "6. Checking startup scripts..."
for script in ~/UHJ-Pi/start-*.sh; do
    if [ -f "$script" ]; then
        echo "$(basename $script):"
        grep "LIBINPUT_CALIBRATION_MATRIX" "$script" || echo "  Not found"
    fi
done
echo ""

echo "7. Testing libinput tools (if available)..."
if command -v libinput >/dev/null 2>&1; then
    echo "libinput is installed"
    libinput list-devices 2>/dev/null | grep -A 10 -i "touch" || echo "  No touch devices found via libinput"
else
    echo "libinput tools not installed"
fi
echo ""

echo "8. Checking display rotation..."
grep "display_rotate" /boot/firmware/config.txt 2>/dev/null || echo "  Not found in config.txt"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Diagnostic complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

