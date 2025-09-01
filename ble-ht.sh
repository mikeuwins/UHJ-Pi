#!/bin/bash

# Prevent script from exiting on errors
set +e

DEVICE_NAME="${1:-HT}"
SCAN_TIME=3
MAX_RETRIES=3

log() {
    echo "[$(date '+%H:%M:%S')] $1" >&2
}

# Simple function to run bluetoothctl commands
run_bt_cmd() {
    local cmd="$1"
    bluetoothctl "$cmd"
}

# Check bluetooth
check_bluetooth() {
    log "Initializing Bluetooth..."
    
    if ! systemctl is-active --quiet bluetooth; then
        log "Starting Bluetooth service..."
        sudo systemctl start bluetooth
        sleep 2
    fi
    
    log "Powering on Bluetooth..."
    bluetoothctl power on >/dev/null 2>&1
    sleep 1
}

# Find ONLY the headtracker
find_headtracker() {
    log "Scanning for headtracker '$DEVICE_NAME'..."
    
    # Start scan
    run_bt_cmd "scan on" >/dev/null &
    sleep $SCAN_TIME
    run_bt_cmd "scan off" >/dev/null
    
    # Get all devices and check each one
    local devices=$(run_bt_cmd "devices")
    log "Checking discovered devices..."
    
    # Look through each device
    while read -r line; do
        if [[ "$line" == Device* ]]; then
            local mac=$(echo "$line" | awk '{print $2}')
            local name=$(echo "$line" | cut -d' ' -f3-)
            
            # Check if this device matches our target
            if [[ "$name" == *"$DEVICE_NAME"* ]] || [[ -z "$name" ]]; then
                # For devices with no name, check the device info
                local info=$(run_bt_cmd "info $mac" 2>/dev/null)
                local actual_name=$(echo "$info" | grep "Name:" | cut -d: -f2 | xargs)
                
                if [[ "$actual_name" == *"$DEVICE_NAME"* ]]; then
                    log "Found headtracker: $mac (name: '$actual_name')"
                    echo "$mac"
                    return 0
                elif [[ "$name" == *"$DEVICE_NAME"* ]]; then
                    log "Found headtracker: $mac (name: '$name')"
                    echo "$mac"
                    return 0
                fi
            fi
        fi
    done <<< "$devices"
    
    log "Headtracker '$DEVICE_NAME' not found. Available devices:"
    echo "$devices" | grep "Device" | while read -r line; do
        local mac=$(echo "$line" | awk '{print $2}')
        local name=$(echo "$line" | cut -d' ' -f3-)
        log "  $mac: $name"
    done >&2
    
    return 1
}

# Connect to headtracker only
connect_headtracker() {
    local mac="$1"
    local attempt=1
    
    log "TARGET DEVICE: $mac"
    
    while [ $attempt -le $MAX_RETRIES ]; do
        log "--- CONNECTION ATTEMPT $attempt of $MAX_RETRIES ---"
        log "Connecting to headtracker at $mac..."
        
        # Check current connection status
        log "Checking current device status for $mac..."
        local device_info=$(bluetoothctl info "$mac" 2>/dev/null)
        
        if echo "$device_info" | grep -q "Connected: yes"; then
            log "✓ Device is already connected!"
            log "SUCCESS: Headtracker ready at $mac"
            return 0
        elif echo "$device_info" | grep -q "Paired: yes"; then
            log "Device is paired but not connected, attempting to connect..."
            # Skip pairing, go straight to connect
        else
            log "Device not found or not paired, will attempt pairing..."
            
            # Pair headtracker
            log "Attempting to pair with $mac..."
            local pair_output=$(timeout 30 bluetoothctl pair "$mac" 2>&1)
            local pair_status=$?
            log "Pair result: $pair_output"
            
            if [ $pair_status -eq 124 ]; then
                log "✗ Pairing timed out after 30 seconds"
                continue
            elif [ $pair_status -ne 0 ]; then
                log "✗ Pairing command failed with status $pair_status"
                continue
            fi
            
            if echo "$pair_output" | grep -q "successful\|AlreadyExists"; then
                log "✓ Pairing successful"
                sleep 3
                
                # Trust headtracker
                log "Setting device as trusted..."
                bluetoothctl trust "$mac" >/dev/null
                sleep 2
            else
                log "✗ Pairing failed"
                continue
            fi
        fi
        
        # Connect headtracker
        log "Attempting connection to $mac..."
        local connect_output=$(timeout 20 bluetoothctl connect "$mac" 2>&1)
        local connect_status=$?
        log "Connect result: $connect_output"
        
        if [ $connect_status -eq 124 ]; then
            log "✗ Connection timed out after 20 seconds"
            continue
        elif [ $connect_status -ne 0 ]; then
            log "✗ Connection command failed with status $connect_status"
        fi
        
        if echo "$connect_output" | grep -q "successful"; then
            log "✓ Connect command succeeded"
            log "SUCCESS: Headtracker ready at $mac"
            return 0
        else
            log "✗ Connect command failed"
        fi
        
        log "--- Attempt $attempt failed, waiting before retry ---"
        attempt=$((attempt + 1))
        sleep 3
    done
    
    log "✗ FINAL RESULT: Failed to connect after $MAX_RETRIES attempts"
    return 1
}

# Main
main() {
    log "=== Headtracker Connector ==="
    
    # Exit cleanly on Ctrl+C
    trap 'log "Interrupted"; run_bt_cmd "scan off" >/dev/null 2>&1; exit 1' INT
    
    check_bluetooth
    
    MAC=$(find_headtracker)
    if [ $? -eq 0 ]; then
        log "✓ FOUND HEADTRACKER: MAC = $MAC"
        log "Proceeding to connection attempts..."
        if connect_headtracker "$MAC"; then
            log "SUCCESS: Headtracker ready at $MAC"
            echo "PAIRED_AND_CONNECTED"
            exit 0
        else
            log "FAILED: Found headtracker at $MAC but could not connect"
            echo "CONNECTION_FAILED"
            exit 1
        fi
    else
        log "FAILED: Headtracker not found during scan"
        echo "DEVICE_NOT_FOUND"
        exit 1
    fi
}

main "$@"