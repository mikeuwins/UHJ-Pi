#!/bin/bash
set -e
echo "🧹 UHJ-Pi Complete System Reset"
echo "================================"
echo "This will perform a COMPLETE system reset:"
echo "  - Remove ALL user data and applications"
echo "  - Clean package system and remove non-essential packages"
echo "  - Reset all system configurations to defaults"
echo "  - Clear all logs and temporary files"
echo "  - Remove audio performance limits and system optimizations"
echo "  - Reset Bluetooth and audio configurations"
echo ""
echo "Username: $USER"
echo ""
echo "Continue? (Y/N):"
read CONFIRM
if [ "$CONFIRM" != "Y" ] && [ "$CONFIRM" != "y" ]; then
    echo "Reset cancelled."
    exit 1
fi

echo "Starting complete system reset..."

# Stop all services first
echo "Stopping all services..."
sudo systemctl stop bluetooth 2>/dev/null || true
sudo systemctl stop jackd 2>/dev/null || true
sudo systemctl stop pulseaudio 2>/dev/null || true

# Remove all user data and reset to clean state
echo "Removing all user data..."
sudo rm -rf /home/$USER/*
sudo rm -rf /home/$USER/.* 2>/dev/null || true

# Reset system-level configurations
echo "Resetting system configurations..."
# Remove audio performance limits
sudo rm -f /etc/security/limits.d/audio.conf
sudo rm -f /etc/security/limits.d/99-audio.conf
# Remove audio optimizations
sudo rm -f /etc/sysctl.d/99-audio.conf
# Remove JACK configurations
sudo rm -f /etc/jackdrc
sudo rm -rf /etc/jack
# Remove ALSA configurations
sudo rm -f /etc/asound.conf
sudo rm -rf /etc/alsa
# Remove PulseAudio configurations
sudo rm -rf /etc/pulse
# Remove Bluetooth configurations
sudo rm -rf /etc/bluetooth
# Remove systemd user configurations
sudo rm -rf /etc/systemd/system/getty@tty1.service.d
# Remove sudo configurations
sudo rm -f /etc/sudoers.d/uhj-pi-reboot
sudo rm -f /etc/sudoers.d/uhj-pi-*
# Remove udev rules
sudo rm -f /etc/udev/rules.d/99-uhj-pi-*
sudo rm -f /etc/udev/rules.d/99-esi-*
sudo rm -f /etc/udev/rules.d/99-behringer-*
# Remove font configurations
sudo rm -rf /usr/local/share/fonts/truetype/uhj-pi
sudo fc-cache -f 2>/dev/null || true

# Reset package cache and remove installed packages
echo "Cleaning package system..."
sudo apt-get clean
sudo apt-get autoremove --purge -y
sudo apt-get autoclean

# Clear logs
echo "Clearing logs..."
sudo journalctl --vacuum-time=1s
sudo rm -rf /var/log/*

# Reset systemd services
echo "Resetting systemd services..."
sudo systemctl daemon-reload
sudo systemctl reset-failed

# Clear temporary files
echo "Clearing temporary files..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

echo "Reset complete! You can now clone fresh with: git clone https://github.com/mikeuwins/UHJ-Pi.git"