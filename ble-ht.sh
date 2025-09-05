#!/bin/bash

# Automated headtracker pairing script using timeout approach
DEVICE_NAME="HT"

echo "=== Headtracker Pairing ==="
echo "Looking for headtracker '$DEVICE_NAME'..."

# Scan for devices with timeout
timeout 5 bluetoothctl scan on > /dev/null 2>&1

# Find the HT device MAC address
DEVICE_MAC=$(bluetoothctl devices | grep "$DEVICE_NAME" | awk '{print $2}')

if [ -z "$DEVICE_MAC" ]; then
    echo "Headtracker '$DEVICE_NAME' not found"
    echo "PAIRING_FAILED"
    exit 1
fi

echo "Found headtracker at $DEVICE_MAC"

# Pair with the found device using timeout
timeout 10 bluetoothctl pair "$DEVICE_MAC" > /dev/null 2>&1

# Check if pairing succeeded
if bluetoothctl info "$DEVICE_MAC" | grep -q "Paired: yes"; then
    echo "PAIRED_AND_CONNECTED"
    exit 0
else
    echo "PAIRING_FAILED"
    exit 1
fi