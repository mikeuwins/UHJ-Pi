#!/usr/bin/env bash

CONFIG_FILE="$HOME/.uhj-esi-audio.conf"
clear
echo "Starting UHJ-Pi ESI audio setup..."

# Function to detect ESI devices
detect_esi_devices() {
    local phonorama_card=""
    local hd_card=""
    local phonorama_name=""
    local hd_name=""
    
    echo "Detecting ESI devices..."
    
    # First check if both devices are already connected
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\] ]]; then
            local card_num="${BASH_REMATCH[1]}"
            local card_name="${BASH_REMATCH[2]}"
            
            # Look for ESI Phonorama device
            if [[ $card_name =~ Phonorama ]]; then
                phonorama_card="$card_num"
                phonorama_name="$card_name"
            fi
            
            # Look for ESI HD device
            if [[ $card_name =~ HD ]]; then
                hd_card="$card_num"
                hd_name="$card_name"
            fi
        fi
    done < /proc/asound/cards
    
    # Check if both devices are already connected
    if [ -n "$phonorama_card" ] && [ -n "$hd_card" ]; then
        echo "✓ Found ESI Phonorama: hw:$phonorama_card ($phonorama_name)"
        echo "✓ Found ESI HD: hw:$hd_card ($hd_name)"
        echo "✓ Both ESI devices already connected - proceeding with setup"
        echo ""
        return 0
    fi
    
    # If not both connected, prompt for connection
    echo "=== ESI Phonorama Setup ==="
    echo ""
    echo "Step 1: Connect an ESI Phonorama (input device)"
    read -p "Press Enter when your ESI Phonorama is connected..."
    
    echo "Detecting ESI devices..."
    sleep 2
    
    # Look for ESI Phonorama and HD devices
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\] ]]; then
            local card_num="${BASH_REMATCH[1]}"
            local card_name="${BASH_REMATCH[2]}"
            
            # Look for ESI Phonorama device
            if [[ $card_name =~ Phonorama ]]; then
                phonorama_card="$card_num"
                phonorama_name="$card_name"
                echo "✓ Found ESI Phonorama: hw:$phonorama_card ($card_name)"
            fi
            
            # Look for ESI HD device
            if [[ $card_name =~ HD ]]; then
                hd_card="$card_num"
                hd_name="$card_name"
                echo "✓ Found ESI HD: hw:$hd_card ($card_name)"
            fi
        fi
    done < /proc/asound/cards
    
    # Check if Phonorama is found
    if [ -z "$phonorama_card" ]; then
        echo "ERROR: ESI Phonorama not detected. Please check connection and try again."
        exit 1
    fi
    
    echo "=== ESI HD Output Setup ==="
    echo ""
    echo "Step 2: Connect an ESI Gigaport HD (output device)"
    read -p "Press Enter when your ESI HD is connected..."
    
    echo "Detecting ESI HD..."
    sleep 2
    
    # Look for ESI HD device again
    hd_card=""
    hd_name=""
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\] ]]; then
            local card_num="${BASH_REMATCH[1]}"
            local card_name="${BASH_REMATCH[2]}"
            
            # Look for ESI HD device
            if [[ $card_name =~ HD ]]; then
                hd_card="$card_num"
                hd_name="$card_name"
                echo "✓ Found ESI HD: hw:$hd_card ($card_name)"
                break
            fi
        fi
    done < /proc/asound/cards
    
    # Check if HD is found
    if [ -z "$hd_card" ]; then
        echo "ERROR: ESI HD not detected. Please check connection and try again."
        exit 1
    fi
    
    echo "✓ Both ESI devices detected and ready"
    echo ""
}

# Detect devices
detect_esi_devices

echo "✓ ESI devices detected and ready"
echo "🎵 Starting SuperCollider application..."

# Launch SuperCollider with ESI application
exec sclang "$HOME/UHJ-Pi/supercollider/app/UHJ_v28_ESI_PAIR.scd"
