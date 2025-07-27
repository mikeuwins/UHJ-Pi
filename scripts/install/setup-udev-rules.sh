#!/bin/bash

# Udev Rules Setup Script for UHJ-Pi
# This script sets up appropriate udev rules based on the user's audio interface

echo "UHJ-Pi Udev Rules Setup"
echo "======================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Add user to plugdev group
echo "Adding current user to plugdev group..."
usermod -aG plugdev $SUDO_USER

# Create SuperCollider HID rule (always needed)
echo "Creating SuperCollider HID access rule..."
cat > /etc/udev/rules.d/99-supercollider-hid.rules << 'EOF'
# Generic HID access for SuperCollider (headtrackers, controllers, etc.)
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="plugdev"
EOF

# Ask user about their audio interface
echo ""
echo "Which audio interface are you using?"
echo "1) ESI Phonorama"
echo "2) Behringer UFO202/UCA202"
echo "3) Other (manual setup required)"
echo "4) Skip audio interface setup"
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo "Setting up ESI Phonorama udev rules..."
        cat > /etc/udev/rules.d/50-esi-phonorama.rules << 'EOF'
# ESI Phonorama HID access for phono-control
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2573", ATTRS{idProduct}=="0001", GROUP="plugdev", MODE="0660"
EOF
        echo "ESI Phonorama rules installed."
        ;;
    2)
        echo "Behringer UFO202/UCA202 are standard USB audio devices."
        echo "No special udev rules needed - they work with standard ALSA/amixer commands."
        echo "Example: amixer -c UFO202 sset 'Mic' 80%"
        echo "Example: amixer -c UCA202 sset 'PCM' 90%"
        ;;
    3)
        echo "For other audio interfaces, you'll need to:"
        echo "1. Find your device's vendor and product IDs using 'lsusb'"
        echo "2. Create a custom udev rule file"
        echo "3. Follow the pattern in the existing rule files"
        ;;
    4)
        echo "Skipping audio interface setup."
        ;;
    *)
        echo "Invalid choice. Skipping audio interface setup."
        ;;
esac

# Reload udev rules
echo ""
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

echo ""
echo "Setup complete!"
echo "Please log out and back in for group changes to take effect."
echo "Or run: newgrp plugdev"
echo ""
echo "If you have devices connected, unplug and replug them for the rules to take effect." 