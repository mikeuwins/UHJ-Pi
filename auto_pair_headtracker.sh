#!/bin/bash
echo "[BT] Starting headtracker Bluetooth setup..."

# Kill any desktop Bluetooth agents that might interfere
pkill -x blueman-applet >/dev/null 2>&1 || true
pkill -x blueberry-tray >/dev/null 2>&1 || true
pkill -x gsd-bluetooth >/dev/null 2>&1 || true

# Set environment to force non-interactive mode
export BLUEZ_AGENT_AUTO_CONFIRM=true
export BLUEZ_AGENT_AUTO_ACCEPT=true

# Basic Bluetooth setup
bluetoothctl power on
bluetoothctl agent off
bluetoothctl agent NoInputNoOutput
bluetoothctl default-agent
bluetoothctl pairable on

# Scan for HT devices
echo "[BT] Scanning for HT devices..."
timeout 5s bluetoothctl scan on
bluetoothctl scan off

# Find HT device
MAC=$(bluetoothctl devices | grep -i "ht" | awk '{print $2}' | head -1)

if [ -n "$MAC" ]; then
    echo "[BT] Found HT device at $MAC"
    
    # Check if already connected
    if bluetoothctl info "$MAC" | grep -q "Connected: yes"; then
        echo "[BT] Device already connected"
        exit 0
    fi
    
    # Check if already paired
    if bluetoothctl info "$MAC" | grep -q "Paired: yes"; then
        echo "[BT] Device already paired, connecting..."
        bluetoothctl connect $MAC
        sleep 3
        if bluetoothctl info "$MAC" | grep -q "Connected: yes"; then
            echo "[BT] Successfully connected!"
            exit 0
        fi
    fi
    
    # Device not paired, pair it
    echo "[BT] Pairing device..."
    bluetoothctl <<EOF
pair $MAC
EOF
    sleep 3
    
    # Check if pairing succeeded
    if bluetoothctl info "$MAC" | grep -q "Paired: yes"; then
        echo "[BT] Pairing successful, now connecting..."
        bluetoothctl connect $MAC
        sleep 3
        
        if bluetoothctl info "$MAC" | grep -q "Connected: yes"; then
            echo "[BT] Successfully paired and connected!"
            exit 0
        else
            echo "[BT] Connected but connection failed"
            exit 1
        fi
    else
        echo "[BT] Pairing failed"
        exit 1
    fi
else
    echo "[BT] No HT device found"
    exit 1
fi
