#!/bin/bash

# UHJ-Pi Autostart Setup Script
# Configures the Pi to boot directly into the UHJ Ambisonic System

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Get the actual username (the user who ran sudo)
ACTUAL_USER=${SUDO_USER:-$(logname)}
if [ -z "$ACTUAL_USER" ]; then
    echo "Error: Could not determine username. Please run with: sudo -E ./setup-autostart.sh"
    exit 1
fi

echo "UHJ-Pi Autostart Setup - Configuring auto-start for user: $ACTUAL_USER"

# STEP 1: Enable auto-login for the user
echo "Enabling auto-login..."
systemctl set-default multi-user.target
systemctl enable getty@tty1.service

# Create override directory for getty service
mkdir -p /etc/systemd/system/getty@tty1.service.d/

# Create override file to enable auto-login
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $ACTUAL_USER --noclear %I \$TERM
Type=idle
EOF

# STEP 2: Create autostart script
echo "Creating autostart script..."
cat > /home/$ACTUAL_USER/uhj-autostart.sh << EOF
#!/bin/bash

# UHJ Ambisonic System Autostart Script

# Set display environment for eglfs
export DISPLAY=:0
export QT_QPA_PLATFORM=eglfs

# Wait for system to fully boot
sleep 10

# Start JACK audio server
/usr/bin/jackd -P75 -d alsa -C hw:Phonorama -P hw:HD -r 44100 -p 256 -n 2 -S &

# Wait for JACK to start
sleep 3

# Start the UHJ Ambisonic System
cd /home/$ACTUAL_USER/UHJ-Pi
sclang supercollider/app/UHJ_v18.scd

# If sclang exits, wait a moment then restart (optional)
# sleep 5
# exec \$0
EOF

# Make autostart script executable
chmod +x /home/$ACTUAL_USER/uhj-autostart.sh
chown $ACTUAL_USER:$ACTUAL_USER /home/$ACTUAL_USER/uhj-autostart.sh

# STEP 3: Add autostart script to user's .bashrc
echo "Adding autostart to .bashrc..."
if ! grep -q "uhj-autostart.sh" /home/$ACTUAL_USER/.bashrc; then
    echo "" >> /home/$ACTUAL_USER/.bashrc
    echo "# UHJ Autostart" >> /home/$ACTUAL_USER/.bashrc
    echo "if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then" >> /home/$ACTUAL_USER/.bashrc
    echo "    exec ~/uhj-autostart.sh" >> /home/$ACTUAL_USER/.bashrc
    echo "fi" >> /home/$ACTUAL_USER/.bashrc
fi

# STEP 4: Disable screen saver and power management
echo "Disabling screen saver and power management..."
apt-get install -y x11-xserver-utils

# Add to .bashrc to prevent screen blanking
if ! grep -q "xset s off" /home/$ACTUAL_USER/.bashrc; then
    echo "" >> /home/$ACTUAL_USER/.bashrc
    echo "# Prevent screen blanking" >> /home/$ACTUAL_USER/.bashrc
    echo "xset s off -dpms 2>/dev/null || true" >> /home/$ACTUAL_USER/.bashrc
fi

# STEP 5: Configure boot options to disable splash screen
echo "Configuring boot options..."
if ! grep -q "disable_splash=1" /boot/firmware/config.txt; then
    echo "disable_splash=1" >> /boot/firmware/config.txt
fi

# STEP 6: Reload systemd and enable services
echo "Reloading systemd configuration..."
systemctl daemon-reload
systemctl enable getty@tty1.service

echo ""
echo "Autostart configuration completed!"
echo ""
echo "The Pi will now:"
echo "  1. Boot directly to the UHJ Ambisonic System"
echo "  2. Start JACK audio automatically"
echo "  3. Launch the GUI on the 7-inch LCD"
echo "  4. Prevent screen blanking"
echo ""
echo "To test: sudo reboot"
echo ""
echo "To disable autostart later:"
echo "  sudo systemctl disable getty@tty1.service"
echo "  sudo rm /etc/systemd/system/getty@tty1.service.d/override.conf"