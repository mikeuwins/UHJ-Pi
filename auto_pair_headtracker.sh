#!/bin/bash
echo "[PAIR] Starting headtracker pairing..."

# Simple approach for headless Pi
bluetoothctl <<EOF
power on
agent NoInputNoOutput
default-agent
pairable on
EOF

# Wait for adapter to be ready
sleep 3

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
    
    # Check if already paired
    if bluetoothctl info "$MAC" | grep -q "Paired: yes"; then
        echo "[PAIR] Device already paired, attempting to connect..."
        bluetoothctl <<EOF
trust $MAC
EOF
        sleep 2
        
        bluetoothctl connect $MAC
        sleep 5
        
        if bluetoothctl info "$MAC" | grep -q "Connected: yes"; then
            echo "[PAIR] Successfully connected to paired device!"
            exit 0
        else
            echo "[PAIR] Failed to connect to paired device"
            exit 1
        fi
    fi
    
    # Device not paired, need to pair first
    echo "[PAIR] Device not paired, starting pairing process..."
    
    # First, just pair (don't try to trust/connect yet)
    bluetoothctl <<EOF
pair $MAC
EOF
    
    # Wait for pairing to complete
    echo "[PAIR] Waiting for pairing to complete..."
    for i in {1..15}; do
        if bluetoothctl info "$MAC" | grep -q "Paired: yes"; then
            echo "[PAIR] Pairing completed successfully!"
            break
        fi
        echo "[PAIR] Waiting for pairing... (attempt $i/15)"
        sleep 2
    done
    
    # Check if pairing succeeded
    if ! bluetoothctl info "$MAC" | grep -q "Paired: yes"; then
        echo "[PAIR] Pairing failed after multiple attempts"
        exit 1
    fi
    
    # Now that pairing is complete, trust the device
    echo "[PAIR] Pairing complete, now trusting device..."
    bluetoothctl <<EOF
trust $MAC
EOF
    sleep 3
    
    # Finally, attempt to connect
    echo "[PAIR] Trusting complete, now attempting to connect..."
    bluetoothctl connect $MAC
    sleep 5
    
    if bluetoothctl info "$MAC" | grep -q "Connected: yes"; then
        echo "[PAIR] Successfully paired and connected!"
        exit 0
    else
        echo "[PAIR] Failed to connect after successful pairing"
        exit 1
    fi
else
    echo "[PAIR] No HT device found"
    exit 1
fi
