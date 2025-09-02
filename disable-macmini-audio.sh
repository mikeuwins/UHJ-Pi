#!/usr/bin/env bash

echo "Disabling onboard and monitor audio devices..."

# Create blacklist file for unwanted audio modules
sudo tee /etc/modprobe.d/blacklist-onboard-audio.conf > /dev/null << EOF
# Disable onboard HDA audio
blacklist snd_hda_intel
blacklist snd_hda_codec_hdmi
blacklist snd_hda_codec_realtek

# Disable USB display audio (monitors)
# Note: This is more tricky as it's USB audio class, but we can try
# blacklist snd_usb_audio would disable ALL USB audio, so we'll handle this differently
EOF

echo "Audio blacklist created in /etc/modprobe.d/blacklist-onboard-audio.conf"

# Create systemd service to disable Thunderbolt display audio at boot
sudo tee /home/michael-uwins/UHJ-Pi/disable-thunderbolt-audio.sh > /dev/null << 'SCRIPT_EOF'
#!/bin/bash
# Script to disable Apple Thunderbolt Display Audio by unbinding USB devices

echo "Disabling Apple Thunderbolt Display Audio devices..."

# Unbind the Apple Thunderbolt Display Audio devices
# Both monitors show as ID 05ac:1107 Apple, Inc. Thunderbolt Display Audio

for device_path in /sys/bus/usb/devices/*/; do
    if [ -f "$device_path/idVendor" ] && [ -f "$device_path/idProduct" ]; then
        vendor=$(cat "$device_path/idVendor")
        product=$(cat "$device_path/idProduct")
        
        if [ "$vendor" = "05ac" ] && [ "$product" = "1107" ]; then
            device_name=$(basename "$device_path")
            echo "Found Apple Thunderbolt Display Audio: $device_name"
            
            # Unbind from USB audio driver
            if [ -f "$device_path/driver/unbind" ]; then
                echo "$device_name" > "$device_path/driver/unbind" 2>/dev/null && \
                echo "Unbound $device_name from driver" || \
                echo "Failed to unbind $device_name"
            fi
        fi
    fi
done

sleep 2
echo "Current audio devices after disable:"
aplay -l
SCRIPT_EOF

chmod +x /home/michael-uwins/UHJ-Pi/disable-thunderbolt-audio.sh

# Create systemd service
sudo tee /etc/systemd/system/disable-thunderbolt-audio.service > /dev/null << EOF
[Unit]
Description=Disable Apple Thunderbolt Display Audio
After=sound.target
Wants=sound.target

[Service]
Type=oneshot
ExecStart=/home/michael-uwins/UHJ-Pi/disable-thunderbolt-audio.sh
RemainAfterExit=yes
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable disable-thunderbolt-audio.service

echo "Systemd service created to disable Thunderbolt display audio at boot"

echo ""
echo "⚠️  REBOOT REQUIRED for changes to take effect"
echo ""
echo "After reboot, your USB audio devices should be:"
echo "  Card 0: USB AUDIO CODEC (vinyl deck)"
echo "  Card 1: UMC204HD 192k (4-output interface)"
echo ""
echo "This will match the Pi's clean audio environment."
