#!/bin/bash
# Simple UHJ-Pi autoboot for EGLFS
# This script auto-logs in and launches the UHJ Ambisonic System

# Wait for system to be ready
sleep 5

# Safety window - press any key within 3 seconds to abort and get command prompt
echo "Press any key within 3 seconds to abort autoboot and get command prompt..."
read -t 3 -n 1
if [ $? -eq 0 ]; then
    echo "Autoboot aborted. You can now run commands manually."
    echo "To launch UHJ app: sclang supercollider/app/UHJ_v19.scd"
    exit 0
fi

# Check for headtracker (optional - uncomment and add your device address)
# bluetoothctl info [YOUR_DEVICE_ADDRESS] >/dev/null 2>&1

# Launch UHJ app
cd ~/UHJ-Pi
sclang supercollider/app/UHJ_v19.scd 