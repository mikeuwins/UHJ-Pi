#!/bin/bash

# Minimal headtracker pairing script - matches manual process
DEVICE_NAME="HT"

echo "=== Simple Headtracker Pairing ==="
echo "Looking for headtracker '$DEVICE_NAME'..."

# Simple scan to find devices
{
    echo "scan on"
    sleep 5
    echo "scan off"
    echo "exit"
} | bluetoothctl > /dev/null

# Find the HT device MAC address
DEVICE_MAC=$(bluetoothctl devices | grep "$DEVICE_NAME" | awk '{print $2}')

if [ -z "$DEVICE_MAC" ]; then
    echo "Headtracker '$DEVICE_NAME' not found"
    echo "PAIRING_FAILED"
    exit 1
fi

echo "Found headtracker at $DEVICE_MAC"

# Pair with the found device
{
    echo "pair $DEVICE_MAC"
    sleep 3
    echo "exit"
} | bluetoothctl

# Check if pairing succeeded
if bluetoothctl info "$DEVICE_MAC" | grep -q "Paired: yes"; then
    echo "PAIRED_AND_CONNECTED"
    exit 0
else
    echo "PAIRING_FAILED"
    exit 1
fi