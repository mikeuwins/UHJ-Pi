#!/bin/bash

# UHJ-Pi Complete System Reset Script
# This script performs a complete system reset without reflashing
# Run with: sudo ./reset-pi.sh

set -e

echo "🧹 UHJ-Pi Complete System Reset"
echo "================================"
echo "This will perform a COMPLETE system reset:"
echo "  - Remove ALL user data and applications"
echo "  - Clean package system and remove non-essential packages"
echo "  - Reset all configurations to defaults"
echo "  - Clear all logs and temporary files"
echo ""
echo "Username: $USER"
echo ""

# Confirm before proceeding
echo -n "⚠️  WARNING: This will delete EVERYTHING! Are you absolutely sure? (y/N): "
read -r REPLY
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Reset cancelled."
    exit 1
fi

echo "Starting complete system reset..."

# Stop all services
echo "Stopping all services..."
systemctl stop bluetooth 2>/dev/null || true
systemctl stop jackd 2>/dev/null || true
killall jackd 2>/dev/null || true
killall sclang 2>/dev/null || true
killall phono-control 2>/dev/null || true
killall zita-ajbridge 2>/dev/null || true

# Remove ALL user data
echo "Removing all user data..."
rm -rf /home/$USER/*
rm -rf /home/$USER/.* 2>/dev/null || true

# Remove UHJ-Pi specific system files
echo "Removing UHJ-Pi system files..."
rm -rf /usr/local/bin/start
rm -rf /usr/local/bin/ble-ht.sh
rm -rf /usr/local/bin/phono-control
rm -rf /usr/local/bin/zita-ajbridge

# Remove all udev rules
echo "Removing udev rules..."
rm -f /etc/udev/rules.d/99-phonorama.rules
rm -f /etc/udev/rules.d/60-behringer-audio.rules
rm -f /etc/udev/rules.d/60-uhj-pi.rules

# Reset autologin
echo "Resetting autologin..."
rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
systemctl disable getty@tty1.service 2>/dev/null || true

# Remove all non-essential packages (keep only core system)
echo "Removing non-essential packages..."
apt-get update
apt-get remove --purge -y \
    build-essential cmake git curl wget unzip \
    libjack-jackd2-dev libsndfile1-dev libasound2-dev \
    libavcodec-dev libavformat-dev libavutil-dev libswresample-dev \
    libfftw3-dev libsndfile1-dev libsamplerate0-dev \
    libqt5gui5 libqt5widgets5 libqt5core5a \
    zita-ajbridge \
    supercollider \
    sc3-plugins \
    bluetooth bluez \
    fonts-* \
    || true

# Clean package system completely
echo "Cleaning package system..."
apt-get autoremove --purge -y
apt-get autoclean
apt-get clean

# Clear all logs
echo "Clearing all logs..."
journalctl --vacuum-time=1s
rm -rf /var/log/*
rm -rf /tmp/*
rm -rf /var/tmp/*

# Reset Bluetooth completely
echo "Resetting Bluetooth..."
bluetoothctl power off 2>/dev/null || true
bluetoothctl remove * 2>/dev/null || true
systemctl disable bluetooth 2>/dev/null || true

# Clear all SuperCollider and audio data
echo "Clearing audio data..."
rm -rf /home/$USER/.local/share/SuperCollider
rm -rf /home/$USER/.local/share/ATK
rm -rf /home/$USER/.local/share/atk-sc3
rm -rf /home/$USER/.local/share/AmbiVerbSC
rm -rf /home/$USER/.local/share/atk-sounds
rm -rf /home/$USER/.local/share/atk-kernels
rm -rf /home/$USER/.local/share/atk-matrices

# Reset audio configuration
echo "Resetting audio configuration..."
rm -f /home/$USER/.jackdrc
rm -f /etc/asound.conf
rm -f /etc/modprobe.d/alsa-base.conf

# Reset Qt platform settings
echo "Resetting Qt platform settings..."
sed -i '/QT_QPA_PLATFORM/d' /home/$USER/.bashrc
sed -i '/QT_QPA_PLATFORM/d' /home/$USER/.profile
sed -i '/unset DISPLAY/d' /home/$USER/.bashrc
sed -i '/unset DISPLAY/d' /home/$USER/.profile

# Reset audio performance settings
echo "Resetting audio performance settings..."
sed -i '/audio.*performance/d' /etc/security/limits.conf
sed -i '/rtprio/d' /etc/security/limits.conf
sed -i '/memlock/d' /etc/security/limits.conf

# Clear font cache
echo "Clearing font cache..."
fc-cache -f

# Reset udev rules
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

# Reset network (optional)
echo "Resetting network configuration..."
rm -f /etc/wpa_supplicant/wpa_supplicant.conf

# Clear bash history
echo "Clearing bash history..."
rm -f /home/$USER/.bash_history
history -c

# Reset permissions
echo "Resetting permissions..."
chown -R $USER:$USER /home/$USER

echo ""
echo "✅ Complete system reset finished!"
echo "The Pi is now in a completely clean state."
echo ""
echo "To reinstall UHJ-Pi:"
echo "1. git clone https://github.com/mikeuwins/UHJ-Pi.git"
echo "2. cd UHJ-Pi"
echo "3. sudo ./install-[version]-touch.sh"
echo ""
echo "Available installers:"
echo "  - install-gen-touch.sh"
echo "  - install-esi-touch.sh" 
echo "  - install-vin-touch.sh"
echo "  - install-beh-touch.sh"
echo ""
echo "⚠️  You may need to reboot for all changes to take effect."
