#!/bin/bash

echo "Starting simple headtracker pairing..."

# Scan for devices with timeout and capture output
echo "bluetoothctl --timeout 5 scan on"
SCAN_OUTPUT=$(bluetoothctl --timeout 5 scan on 2>&1)

# Extract MAC address from scan output
echo "Extracting MAC address from scan output..."
MAC=$(echo "$SCAN_OUTPUT" | grep "\[NEW\] Device.* HT" | awk '{print $3}')

if [ -z "$MAC" ]; then
    echo "ERROR: HT device not found in scan output"
    echo "Scan output:"
    echo "$SCAN_OUTPUT"
    echo "Trying alternative pattern..."
    # Try a simpler pattern
    MAC=$(echo "$SCAN_OUTPUT" | grep "HT" | grep "Device" | awk '{print $3}')
    if [ -z "$MAC" ]; then
        echo "Still not found with alternative pattern"
        exit 1
    fi
fi

echo "Found HT at MAC: $MAC"

# Pair the device
echo "Pairing device..."
bluetoothctl <<EOF
pair $MAC
trust $MAC
connect $MAC
EOF

echo "Done!"