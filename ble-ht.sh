#!/bin/bash

# Minimal headtracker pairing script - matches manual process
DEVICE_NAME="HT"

echo "=== Simple Headtracker Pairing ==="
echo "Looking for headtracker '$DEVICE_NAME'..."

# First, check if device is already paired and remove it BEFORE scanning
echo "Checking for existing paired devices..."
PAIRED_MAC=$(bluetoothctl devices Paired | grep -i "$DEVICE_NAME" | awk '{print $2}')
if [ -n "$PAIRED_MAC" ]; then
    echo "Found already paired device at $PAIRED_MAC - removing it first..."
    bluetoothctl disconnect "$PAIRED_MAC" > /dev/null 2>&1
    sleep 1
    bluetoothctl remove "$PAIRED_MAC" > /dev/null 2>&1
    sleep 2
    echo "Existing pairing removed"
    echo "Waiting for device to become available again..."
    sleep 3
fi

# Simple scan to find devices
echo "Scanning for devices..."
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
    device_info=$(bluetoothctl info "$DEVICE_MAC" 2>/dev/null)
    is_paired=$(echo "$device_info" | grep -c "Paired: yes" || echo "0")
    is_connected=$(echo "$device_info" | grep -c "Connected: yes" || echo "0")
    
    if [ "$is_paired" -gt 0 ]; then
        if [ "$is_connected" -gt 0 ]; then
            echo "PAIRED_AND_CONNECTED"
            exit 0
        else
            # Paired but not connected - try to connect
            echo "Device paired but not connected - attempting to connect..."
            bluetoothctl connect "$DEVICE_MAC" 2>&1
            sleep 4  # Wait longer for connection to establish
            
            # Check again
            device_info=$(bluetoothctl info "$DEVICE_MAC" 2>/dev/null)
            if echo "$device_info" | grep -q "Connected: yes"; then
                echo "PAIRED_AND_CONNECTED"
                exit 0
            fi
            # If still not connected, continue to next attempt or exit with failure
        fi
    fi
    
    if [ $attempt -eq 1 ]; then
        echo "First attempt failed, retrying..."
        sleep 2  # Longer wait between attempts
    fi
done

echo "PAIRING_FAILED"