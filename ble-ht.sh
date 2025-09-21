#!/bin/bash

# Minimal headtracker pairing script - matches manual process
DEVICE_NAME="HT"

echo "=== Simple Headtracker Pairing ==="
echo "Looking for headtracker '$DEVICE_NAME'..."

# Ensure Bluetooth controller is ready
echo "Powering on Bluetooth adapter..."
bluetoothctl power on
sleep 2  # Give time for power on to complete

echo "Setting discoverable and pairable..."
bluetoothctl discoverable on
bluetoothctl pairable on
sleep 1

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
    
    if [ $attempt -eq 1 ]; then
        echo "First attempt completed, checking status..."
        sleep 1
    fi
done

# Check device status after all pairing attempts
echo "Checking final device status..."
device_info=$(bluetoothctl info "$DEVICE_MAC")
if echo "$device_info" | grep -q "Paired: yes" && echo "$device_info" | grep -q "Connected: yes"; then
    echo "PAIRED_AND_CONNECTED"
    exit 0
elif echo "$device_info" | grep -q "Paired: yes" && echo "$device_info" | grep -q "Connected: no"; then
    echo "Attempting to connect to paired device..."
    bluetoothctl connect "$DEVICE_MAC" > /dev/null 2>&1
    sleep 2  # Give connection time to establish
    
    # Check again after connection attempt
    device_info=$(bluetoothctl info "$DEVICE_MAC")
    if echo "$device_info" | grep -q "Connected: yes"; then
        echo "PAIRED_AND_CONNECTED"
        exit 0
    else
        echo "PAIRED_NOT_CONNECTED"
        exit 0
    fi
fi

echo "PAIRING_FAILED"