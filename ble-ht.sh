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

# Check if device is already paired and remove it first
echo "Checking if device is already paired..."
device_info=$(bluetoothctl info "$DEVICE_MAC" 2>/dev/null)
if echo "$device_info" | grep -q "Paired: yes"; then
    echo "Device is already paired - removing it first..."
    bluetoothctl disconnect "$DEVICE_MAC" > /dev/null 2>&1
    sleep 1
    bluetoothctl remove "$DEVICE_MAC" > /dev/null 2>&1
    sleep 2
    echo "Existing pairing removed"
    echo "Waiting for device to become available again..."
    sleep 3
    
    # Re-scan to make sure device is still discoverable
    echo "Re-scanning for device..."
    {
        echo "scan on"
        sleep 3
        echo "scan off"
        echo "exit"
    } | bluetoothctl > /dev/null 2>&1
fi

# Try pairing (with automatic retry)
for attempt in 1 2; do
    echo "Pairing attempt $attempt..."
    
    {
        echo "pair $DEVICE_MAC"
        sleep 5  # Increased wait time for pairing to complete
        echo "exit"
    } | bluetoothctl
    
    # Wait a bit for status to update
    sleep 2
    
    # Check if pairing succeeded
    if bluetoothctl info "$DEVICE_MAC" | grep -q "Paired: yes"; then
        echo "PAIRED_AND_CONNECTED"
        exit 0
    fi
    
    if [ $attempt -eq 1 ]; then
        echo "First attempt failed, retrying..."
        sleep 2  # Longer wait between attempts
    fi
done

echo "PAIRING_FAILED"