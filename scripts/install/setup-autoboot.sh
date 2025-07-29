#!/bin/bash

# UHJ-Pi Auto-boot Setup Script
# Sets up Raspberry Pi to boot directly to SuperCollider with full-screen GUI

echo "UHJ-Pi Auto-boot Setup"
echo "======================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

# Get the username
USERNAME=$SUDO_USER
USER_HOME=$(eval echo ~$USERNAME)

echo "Setting up auto-boot for user: $USERNAME"
echo ""

# 1. Install required packages
echo "Installing required packages..."
apt update
apt install -y \
    x11-common \
    x11-utils \
    xorg \
    openbox \
    xinit \
    xterm \
    dbus-x11 \
    libx11-dev \
    libxrandr-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxi-dev \
    libxext-dev \
    libxss-dev \
    unclutter \
    xdotool

# 2. Configure display for 7-inch LCD
echo "Configuring display settings..."
cat > /boot/config.txt << 'EOF'
# UHJ-Pi Display Configuration
# 7-inch LCD settings
hdmi_group=2
hdmi_mode=87
hdmi_cvt=800 480 60 6 0 0 0
hdmi_drive=2

# Audio settings - Disable onboard and HDMI audio
# dtoverlay=audio=on
# dtparam=audio=on
dtparam=audio=off

# Performance settings
gpu_mem=16
arm_freq=2000
over_voltage=2

# Disable unnecessary features
dtoverlay=disable-wifi
dtoverlay=disable-bt
EOF

# 3. Create .xinitrc for auto-start
echo "Creating .xinitrc for auto-start..."
cat > $USER_HOME/.xinitrc << 'EOF'
#!/bin/bash

# Hide cursor
unclutter -idle 0.1 -root &

# Disable screen saver
xset s off
xset -dpms
xset s noblank

# Set full-screen mode
xrandr --output HDMI-1 --mode 800x480

# Start JACK audio server with multi-device support
# Wait for USB audio devices to be ready
sleep 3

# Detect audio setup
echo "Detecting audio setup..."

# Check for ESI devices
ESI_PHONORAMA=$(aplay -l | grep -i "phonorama" | head -1 | sed 's/.*card \([0-9]*\).*/\1/')
ESI_GIGAPORT=$(aplay -l | grep -i "gigaport" | head -1 | sed 's/.*card \([0-9]*\).*/\1/')

# Check for Behringer devices (using persistent naming if available)
BEHRINGER_UFO=$(aplay -l | grep -E "(ufo202|UFO202)" | head -1 | sed 's/.*card \([0-9]*\).*/\1/')
if [ -z "$BEHRINGER_UFO" ]; then
    # Fallback to USB Codec detection by port
    BEHRINGER_UFO=$(aplay -l | grep -A 1 "USB Codec" | head -2 | tail -1 | sed 's/.*card \([0-9]*\).*/\1/')
fi

BEHRINGER_UCA=$(aplay -l | grep -E "(uca202|UCA202)" | head -1 | sed 's/.*card \([0-9]*\).*/\1/')
if [ -z "$BEHRINGER_UCA" ]; then
    # Fallback to second USB Codec
    BEHRINGER_UCA=$(aplay -l | grep -A 1 "USB Codec" | tail -1 | sed 's/.*card \([0-9]*\).*/\1/')
fi

# Determine setup and start JACK accordingly
if [ ! -z "$ESI_PHONORAMA" ] && [ ! -z "$ESI_GIGAPORT" ]; then
    echo "ESI setup detected: Phonorama (input) + Gigaport HD+ (output)"
    # Use Gigaport for output (8 channels), Phonorama for input
    jackd -d alsa -d hw:$ESI_GIGAPORT -r 48000 -p 256 -n 2 -P 95 -o 8 &
elif [ ! -z "$BEHRINGER_UFO" ] && [ ! -z "$BEHRINGER_UCA" ]; then
    echo "Behringer setup detected: UFO202 + UCA202"
    # Use ALSA multi-device configuration
    jackd -d alsa -d hw:$BEHRINGER_UFO -r 48000 -p 256 -n 2 -P 95 &
else
    echo "Single USB audio device or fallback"
    USB_DEVICE=$(aplay -l | grep -E "(ESI|Behringer|USB)" | head -1 | sed 's/.*card \([0-9]*\).*/\1/')
    if [ -z "$USB_DEVICE" ]; then
        USB_DEVICE=0  # Fallback to default
    fi
    jackd -d alsa -d hw:$USB_DEVICE -r 48000 -p 256 -n 2 -P 95 &
fi

# Wait for JACK to start
sleep 2

# Start SuperCollider with UHJ-Pi app
cd /home/pi/UHJ-Pi
sclang supercollider/app/UHJ_v19.scd &

# Start Openbox window manager
exec openbox-session
EOF

chown $USERNAME:$USERNAME $USER_HOME/.xinitrc
chmod +x $USER_HOME/.xinitrc

# 4. Configure Openbox for full-screen
echo "Configuring Openbox for full-screen..."
mkdir -p $USER_HOME/.config/openbox
cat > $USER_HOME/.config/openbox/autostart << 'EOF'
#!/bin/bash

# Remove window decorations
xprop -root -f _MOTIF_WM_HINTS 32c -set _MOTIF_WM_HINTS "0x2, 0x0, 0x0, 0x0, 0x0"

# Set window to full-screen
xdotool search --name "SuperCollider" windowactivate
xdotool key F11
EOF

chown -R $USERNAME:$USERNAME $USER_HOME/.config
chmod +x $USER_HOME/.config/openbox/autostart

# 5. Configure auto-login
echo "Setting up auto-login..."
systemctl set-default multi-user.target
systemctl enable getty@tty1.service

# Create auto-login service
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
Type=idle
EOF

# 6. Configure auto-start X11
echo "Setting up auto-start X11..."
cat > $USER_HOME/.bash_profile << 'EOF'
# Auto-start X11 if not already running
if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    startx
fi
EOF

chown $USERNAME:$USERNAME $USER_HOME/.bash_profile

# 7. Set up systemd service for audio optimization
echo "Setting up audio optimization..."
cat > /etc/systemd/system/uhj-pi-audio.service << 'EOF'
[Unit]
Description=UHJ-Pi Audio Optimization
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo performance > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
ExecStart=/bin/bash -c 'echo 95 > /proc/sys/vm/swappiness'
ExecStart=/bin/bash -c 'echo 0 > /proc/sys/vm/drop_caches'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable uhj-pi-audio.service

# 8. Configure real-time audio
echo "Setting up real-time audio..."
usermod -aG audio $USERNAME
usermod -aG realtime $USERNAME

cat > /etc/security/limits.d/audio.conf << 'EOF'
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@realtime -  rtprio     95
@realtime -  memlock    unlimited
EOF

# 9. Configure ALSA for multi-device setups
echo "Configuring ALSA audio..."
cat > /etc/asound.conf << 'EOF'
# UHJ-Pi ALSA Configuration
# Multi-device setup support

# ESI Setup: Phonorama (input) + Gigaport HD+ (output)
pcm.esi_input {
    type hw
    card Phonorama
    device 0
}

pcm.esi_output {
    type hw
    card "Gigaport HD+"
    device 0
}

# Behringer Setup: UFO202 + UCA202 combined output
pcm.behringer_input {
    type hw
    card UFO202
    device 0
}

# Multi-device output for Behringer (UFO + UCA)
pcm.behringer_output {
    type multi
    slaves.a.pcm "hw:UFO202,0"
    slaves.b.pcm "hw:UCA202,0"
    bindings.0.slave a
    bindings.0.channel 0
    bindings.1.slave a
    bindings.1.channel 1
    bindings.2.slave b
    bindings.2.channel 0
    bindings.3.slave b
    bindings.3.channel 1
}

# Default configuration (will be overridden by JACK)
pcm.!default {
    type hw
    card 1
}

ctl.!default {
    type hw
    card 1
}

# Blacklist onboard audio
blacklist snd_bcm2835
EOF

# 10. Disable unnecessary services
echo "Disabling unnecessary services..."
systemctl disable bluetooth
systemctl disable wifi-powersave
systemctl disable avahi-daemon
systemctl disable triggerhappy
systemctl disable hciuart

echo ""
echo "Setup complete!"
echo "=================="
echo "The Raspberry Pi will now:"
echo "1. Boot directly to console"
echo "2. Auto-login as $USERNAME"
echo "3. Start X11 automatically"
echo "4. Launch SuperCollider with UHJ-Pi app"
echo "5. Display in full-screen mode on 7-inch LCD"
echo ""
echo "To test: reboot the system"
echo "To disable auto-start: remove ~/.bash_profile"
echo ""
echo "Note: Make sure UHJ-Pi is cloned to /home/pi/UHJ-Pi" 