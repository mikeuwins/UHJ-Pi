#!/bin/bash

# Create udev rules for persistent Behringer device naming
# Uses USB port information to distinguish UFO202 from UCA202

echo "Creating udev rules for Behringer devices..."
echo "============================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

echo "Current Behringer devices:"
echo "-------------------------"
aplay -l | grep -A 1 -B 1 "USB Codec"

echo ""
echo "To create persistent device naming, you need to:"
echo "1. Connect UFO202 to a specific USB port (e.g., USB port 1-1)"
echo "2. Connect UCA202 to a different USB port (e.g., USB port 1-2)"
echo "3. Note the USB port numbers from the device identification script"
echo ""

read -p "Enter USB port for UFO202 (e.g., 1-1): " UFO_PORT
read -p "Enter USB port for UCA202 (e.g., 1-2): " UCA_PORT

if [ -z "$UFO_PORT" ] || [ -z "$UCA_PORT" ]; then
    echo "Error: Please provide both USB port numbers"
    exit 1
fi

echo ""
echo "Creating udev rules..."

# Create udev rules file
cat > /etc/udev/rules.d/60-behringer-audio.rules << EOF
# Behringer UFO202 and UCA202 persistent naming
# UFO202 on USB port $UFO_PORT
SUBSYSTEM=="sound", KERNEL=="card*", ATTRS{idVendor}=="1397", ATTRS{idProduct}=="0501", ENV{ID_PATH}=="*$UFO_PORT*", SYMLINK+="sound/ufo202"

# UCA202 on USB port $UCA_PORT  
SUBSYSTEM=="sound", KERNEL=="card*", ATTRS{idVendor}=="1397", ATTRS{idProduct}=="0502", ENV{ID_PATH}=="*$UCA_PORT*", SYMLINK+="sound/uca202"

# Alternative method using USB port directly
SUBSYSTEM=="sound", KERNEL=="card*", ATTRS{idVendor}=="1397", ENV{ID_PATH}=="*$UFO_PORT*", ENV{ALSA_NAME}="UFO202"
SUBSYSTEM=="sound", KERNEL=="card*", ATTRS{idVendor}=="1397", ENV{ID_PATH}=="*$UCA_PORT*", ENV{ALSA_NAME}="UCA202"
EOF

echo "Udev rules created at /etc/udev/rules.d/60-behringer-audio.rules"
echo ""

# Reload udev rules
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

echo ""
echo "Next steps:"
echo "1. Unplug and replug your Behringer devices"
echo "2. Check device naming: ls -la /dev/snd/"
echo "3. Test with: aplay -D hw:ufo202 -l"
echo "4. Test with: aplay -D hw:uca202 -l"
echo ""
echo "Note: You may need to adjust the USB port numbers if devices are not detected correctly." 