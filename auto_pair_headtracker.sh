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
        bluetoothctl connect $MAC
        sleep 5
        
        # Wait for full connection and services
        echo "[PAIR] Waiting for full connection and services..."
        for i in {1..20}; do
            INFO=$(bluetoothctl info "$MAC" 2>/dev/null)
            CONNECTED=$(echo "$INFO" | grep -q "Connected: yes" && echo "yes" || echo "no")
            SERVICES=$(echo "$INFO" | grep -q "ServicesResolved: yes" && echo "yes" || echo "no")
            
            if [ "$CONNECTED" = "yes" ] && [ "$SERVICES" = "yes" ]; then
                echo "[PAIR] Successfully connected with services resolved!"
                exit 0
            fi
            
            echo "[PAIR] Connection status: Connected=$CONNECTED, Services=$SERVICES (attempt $i/20)"
            
            if [ "$CONNECTED" = "no" ]; then
                echo "[PAIR] Connection lost, retrying..."
                bluetoothctl connect $MAC
            fi
            
            sleep 2
        done
        
        echo "[PAIR] Failed to establish full connection"
        exit 1
    fi
    
    # Device not paired, need to pair first
    echo "[PAIR] Device not paired, starting pairing process..."
    
    # Just pair, no trust command
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
    
    # Now attempt to connect (no trust command)
    echo "[PAIR] Pairing complete, now attempting to connect..."
    bluetoothctl connect $MAC
    sleep 5
    
    # Wait for full connection and services
    echo "[PAIR] Waiting for full connection and services after pairing..."
    for i in {1..20}; do
        INFO=$(bluetoothctl info "$MAC" 2>/dev/null)
        CONNECTED=$(echo "$INFO" | grep -q "Connected: yes" && echo "yes" || echo "no")
        SERVICES=$(echo "$INFO" | grep -q "ServicesResolved: yes" && echo "yes" || echo "no")
        
        if [ "$CONNECTED" = "yes" ] && [ "$SERVICES" = "yes" ]; then
            echo "[PAIR] Successfully paired and connected with services resolved!"
            exit 0
        fi
        
        echo "[PAIR] Connection status: Connected=$CONNECTED, Services=$SERVICES (attempt $i/20)"
        
        if [ "$CONNECTED" = "no" ]; then
            echo "[PAIR] Connection lost, retrying..."
            bluetoothctl connect $MAC
        fi
        
        sleep 2
    done
    
    echo "[PAIR] Failed to establish full connection after pairing"
    exit 1
else
    echo "[PAIR] No HT device found"
    exit 1
fi
