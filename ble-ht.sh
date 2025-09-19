#!/bin/bash

# Minimal headtracker pairing script - matches manual process
DEVICE_NAME="HT"

echo "=== Simple Headtracker Pairing ==="
echo "Looking for headtracker '$DEVICE_NAME'..."

# Ensure Bluetooth controller is ready
bluetoothctl power on > /dev/null 2>&1
bluetoothctl discoverable on > /dev/null 2>&1
bluetoothctl pairable on > /dev/null 2>&1

# Simple scan to find devices
echo "Starting Bluetooth scan..."
{
    echo "scan on"
    sleep 5
    echo "scan off"
    echo "exit"
} | bluetoothctl > /tmp/bt-scan-process.log 2>&1

# Find the HT device MAC address
DEVICE_MAC=$(bluetoothctl devices | grep "$DEVICE_NAME" | awk '{print $2}')

if [ -z "$DEVICE_MAC" ]; then
    echo "Headtracker '$DEVICE_NAME' not found"
    echo "Available devices:"
    bluetoothctl devices
    echo "PAIRING_FAILED"
    exit 1
fi

echo "Found headtracker at $DEVICE_MAC"

# Try pairing (with automatic retry)
for attempt in 1 2; do
    echo "Pairing attempt $attempt..."
    
    {
        echo "pair $DEVICE_MAC"
        sleep 3
        echo "exit"
    } | bluetoothctl
    
    # Check if pairing succeeded
    if bluetoothctl info "$DEVICE_MAC" | grep -q "Paired: yes"; then
        echo "PAIRED_AND_CONNECTED"
        exit 0
    fi
    
    if [ $attempt -eq 1 ]; then
        echo "First attempt failed, retrying..."
        sleep 1
    fi
done

echo "PAIRING_FAILED"