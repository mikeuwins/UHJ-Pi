#!/bin/bash

# Debug version of ble-ht.sh with verbose output
DEVICE_NAME="HT"

echo "=== Simple Headtracker Pairing (DEBUG) ==="
echo "Looking for headtracker '$DEVICE_NAME'..."

# Simple scan to find devices
echo "Starting Bluetooth scan..."
{
    echo "scan on"
    sleep 5
    echo "scan off"
    echo "exit"
} | bluetoothctl > /dev/null
 
# Find the HT device MAC address
echo "Checking for devices..."
bluetoothctl devices
echo ""

DEVICE_MAC=$(bluetoothctl devices | grep "$DEVICE_NAME" | awk '{print $2}')

if [ -z "$DEVICE_MAC" ]; then
    echo "❌ Headtracker '$DEVICE_NAME' not found"
    echo "Available devices:"
    bluetoothctl devices
    echo "PAIRING_FAILED"
    exit 1
fi

echo "✓ Found headtracker at $DEVICE_MAC"
echo ""

# Check current status
echo "Current device status:"
bluetoothctl info "$DEVICE_MAC"
echo ""

# Try pairing (with automatic retry)
for attempt in 1 2; do
    echo "=== Pairing attempt $attempt ==="
    
    {
        echo "pair $DEVICE_MAC"
        sleep 3
        echo "exit"
    } | bluetoothctl
    
    echo ""
    echo "Status after attempt $attempt:"
    bluetoothctl info "$DEVICE_MAC" | grep -E "Paired:|Connected:"
    echo ""
    
    # Check if pairing succeeded
    if bluetoothctl info "$DEVICE_MAC" | grep -q "Paired: yes"; then
        echo "✓ PAIRED_AND_CONNECTED"
        exit 0
    fi
    
    if [ $attempt -eq 1 ]; then
        echo "First attempt failed, retrying..."
        sleep 1
    fi
done

echo "❌ PAIRING_FAILED"
echo ""
echo "Final device status:"
bluetoothctl info "$DEVICE_MAC"

