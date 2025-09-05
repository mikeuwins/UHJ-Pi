#!/bin/bash

# Automated headtracker pairing script using EOF approach
DEVICE_NAME="HT"

echo "=== Headtracker Pairing ==="
echo "Looking for headtracker '$DEVICE_NAME'..."

# Scan for devices using EOF
bluetoothctl << EOF
scan on
sleep 5
scan off
exit
EOF

# Find the HT device MAC address
DEVICE_MAC=$(bluetoothctl devices | grep "$DEVICE_NAME" | awk '{print $2}')

if [ -z "$DEVICE_MAC" ]; then
    echo "Headtracker '$DEVICE_NAME' not found"
    echo "PAIRING_FAILED"
    exit 1
fi

echo "Found headtracker at $DEVICE_MAC"

# Pair with the found device using EOF
bluetoothctl << EOF
pair $DEVICE_MAC
sleep 3
exit
EOF

# Check if pairing succeeded
if bluetoothctl info "$DEVICE_MAC" | grep -q "Paired: yes"; then
    echo "PAIRED_AND_CONNECTED"
    exit 0
else
    echo "PAIRING_FAILED"
    exit 1
fi