#!/bin/bash
echo "[PAIR] Starting headtracker pairing..."

# Simple approach for headless Pi
bluetoothctl <<EOF
power on
agent NoInputNoOutput
default-agent
pairable on
EOF

# Scan for HT devices
echo "[PAIR] Scanning for HT devices..."
bluetoothctl scan on >/dev/null 2>&1 &
sleep 5
bluetoothctl scan off >/dev/null 2>&1

# Find HT device
MAC=$(bluetoothctl devices | grep -i "ht" | awk '{print $2}' | head -1)

if [ -n "$MAC" ]; then
    echo "[PAIR] Found HT device at $MAC"
    
    # Check if already connected
    if bluetoothctl info "$MAC" | grep -q "Connected: yes"; then
        echo "[PAIR] Device already connected"
        exit 0
    fi
    
    # Try to connect
    echo "[PAIR] Attempting to connect..."
    bluetoothctl <<EOF
trust $MAC
connect $MAC
EOF
    
    # Wait for connection
    sleep 3
    
    if bluetoothctl info "$MAC" | grep -q "Connected: yes"; then
        echo "[PAIR] Successfully connected!"
        exit 0
    else
        echo "[PAIR] Connection failed, trying to pair first..."
        bluetoothctl <<EOF
pair $MAC
trust $MAC
connect $MAC
EOF
        
        sleep 5
        
        if bluetoothctl info "$MAC" | grep -q "Connected: yes"; then
            echo "[PAIR] Successfully paired and connected!"
            exit 0
        else
            echo "[PAIR] Failed to pair and connect"
            exit 1
        fi
    fi
else
    echo "[PAIR] No HT device found"
    exit 1
fi
