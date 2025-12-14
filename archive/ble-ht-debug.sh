#!/bin/bash

# Debug version of ble-ht.sh with verbose output
DEVICE_NAME="HT"

echo "=== Bluetooth Debug Script ==="
echo ""

# Check Bluetooth controller status
echo "1. Checking Bluetooth controller status..."
bluetoothctl show
echo ""

# Power on if needed
echo "2. Ensuring Bluetooth is powered on..."
bluetoothctl power on
sleep 2
echo ""

# Check if powered on
echo "3. Controller status after power on:"
bluetoothctl show | grep -E "Powered|Discoverable|Pairable"
echo ""

# Set discoverable and pairable
echo "4. Setting discoverable and pairable..."
bluetoothctl discoverable on
bluetoothctl pairable on
sleep 1
echo ""

# Check for already paired devices
echo "5. Already paired devices:"
bluetoothctl devices Paired
echo ""

# Check for already known devices
echo "6. All known devices:"
bluetoothctl devices
echo ""

# Start scan
echo "7. Starting scan for 10 seconds..."
{
    echo "scan on"
    sleep 10
    echo "scan off"
    echo "exit"
} | bluetoothctl 2>&1 | tee /tmp/bt-scan-output.log

echo ""
echo "8. Devices found after scan:"
bluetoothctl devices
echo ""

# Look for HT device
echo "9. Searching for device containing '$DEVICE_NAME'..."
DEVICE_MAC=$(bluetoothctl devices | grep -i "$DEVICE_NAME" | awk '{print $2}')

if [ -z "$DEVICE_MAC" ]; then
    echo "❌ No device found with '$DEVICE_NAME' in name"
    echo ""
    echo "All available devices:"
    bluetoothctl devices
    echo ""
    echo "If your headtracker is listed above, note its MAC address and name"
    echo "PAIRING_FAILED"
    exit 1
fi

echo "✓ Found device at $DEVICE_MAC"
DEVICE_NAME_FULL=$(bluetoothctl devices | grep "$DEVICE_MAC" | cut -d' ' -f3-)
echo "  Full name: $DEVICE_NAME_FULL"
echo ""

# Check current status
echo "10. Current device status:"
bluetoothctl info "$DEVICE_MAC"
echo ""

# Try pairing
echo "11. Attempting to pair..."
{
    echo "pair $DEVICE_MAC"
    sleep 5
    echo "exit"
} | bluetoothctl 2>&1

echo ""
echo "12. Status after pairing attempt:"
bluetoothctl info "$DEVICE_MAC" | grep -E "Paired:|Connected:"
echo ""

# Check if paired
if bluetoothctl info "$DEVICE_MAC" | grep -q "Paired: yes"; then
    echo "✓ PAIRED_AND_CONNECTED"
    exit 0
else
    echo "❌ PAIRING_FAILED"
    echo ""
    echo "Full device info:"
    bluetoothctl info "$DEVICE_MAC"
    exit 1
fi
