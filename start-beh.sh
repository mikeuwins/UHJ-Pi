#!/usr/bin/env bash

CONFIG_FILE="$HOME/.uhj-pi-audio.conf"
echo "Starting Behringer audio setup..."

# Function to detect USB audio devices
detect_usb_devices() {
    local devices=()
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[ ]]; then
            current_card="${BASH_REMATCH[1]}"
        elif [[ $line =~ usb- ]]; then
            # Extract USB path (e.g., usb-xhci-hcd.0-2)
            if [[ $line =~ usb-[^,]+ ]]; then
                usb_path="${BASH_REMATCH[0]}"
                devices+=("$current_card:$usb_path")
            fi
        fi
    done < /proc/asound/cards
    echo "${devices[@]}"
}

# Function to register devices step by step
register_devices() {
    echo "Device registration required..."
    echo ""
    
    # Step 1: Register UCA202
    echo "Step 1: Connect UCA202 (line input/output device) and press Enter"
    read -p "Press Enter when UCA202 is connected..."
    
    local uca_device=""
    local devices=$(detect_usb_devices)
    for device in $devices; do
        if [[ $device =~ ^([0-9]+):(.*)$ ]]; then
            local card="${BASH_REMATCH[1]}"
            local usb_path="${BASH_REMATCH[2]}"
            echo "Device detected: $usb_path (Card $card)"
            uca_device="$card:$usb_path"
            break
        fi
    done
    
    if [ -z "$uca_device" ]; then
        echo "ERROR: No USB audio device detected. Please check connection."
        exit 1
    fi
    
    echo "UCA202 registered as line input/outputs 1 & 2"
    echo ""
    
    # Step 2: Register UFO202
    echo "Step 2: Connect UFO202 (phono input/output device) and press Enter"
    read -p "Press Enter when UFO202 is connected..."
    
    local ufo_device=""
    devices=$(detect_usb_devices)
    for device in $devices; do
        if [[ $device =~ ^([0-9]+):(.*)$ ]]; then
            local card="${BASH_REMATCH[1]}"
            local usb_path="${BASH_REMATCH[2]}"
            if [ "$device" != "$uca_device" ]; then
                echo "Device detected: $usb_path (Card $card)"
                ufo_device="$card:$usb_path"
                break
            fi
        fi
    done
    
    if [ -z "$ufo_device" ]; then
        echo "ERROR: Second USB audio device not detected. Please check connection."
        exit 1
    fi
    
    echo "UFO202 registered as phono input/outputs 3 & 4"
    echo ""
    
    # Save configuration
    echo "Saving device configuration..."
    cat > "$CONFIG_FILE" << CONFIG_EOF
# UHJ-Pi Behringer Audio Configuration
# Generated on $(date)
UCA_DEVICE="$uca_device"
UFO_DEVICE="$ufo_device"
UCA_CARD=$(echo "$uca_device" | cut -d: -f1)
UFO_CARD=$(echo "$uca_device" | cut -d: -f1)
CONFIG_EOF
    
    echo "Configuration saved to $CONFIG_FILE"
    echo ""
    
    # Return the detected devices
    UCA_CARD=$(echo "$uca_device" | cut -d: -f1)
    UFO_CARD=$(echo "$ufo_device" | cut -d: -f1)
}

# Check if configuration exists and devices are still valid
if [ -f "$CONFIG_FILE" ]; then
    echo "Found existing configuration, checking devices..."
    source "$CONFIG_FILE"
    
    # Verify devices still exist
    local devices=$(detect_usb_devices)
    local uca_found=false
    local ufo_found=false
    
    for device in $devices; do
        if [[ $device =~ ^([0-9]+):(.*)$ ]]; then
            local card="${BASH_REMATCH[1]}"
            local usb_path="${BASH_REMATCH[2]}"
            if [ "$card:$usb_path" = "$UCA_DEVICE" ]; then
                uca_found=true
            elif [ "$card:$usb_path" = "$UFO_DEVICE" ]; then
                ufo_found=true
            fi
        fi
    done
    
    if [ "$uca_found" = true ] && [ "$ufo_found" = true ]; then
        echo "Using saved configuration:"
        echo "  UCA202: Card $UCA_CARD ($UCA_DEVICE)"
        echo "  UFO202: Card $UFO_CARD ($UFO_DEVICE)"
        echo ""
    else
        echo "Saved configuration invalid, re-registering devices..."
        rm "$CONFIG_FILE"
        register_devices
    fi
else
    echo "No configuration found, registering devices..."
    register_devices
fi

# Stop any existing audio processes
echo "Stopping existing audio processes..."
pkill jackd 2>/dev/null
pkill zita-a2j 2>/dev/null
pkill zita-j2a 2>/dev/null
sleep 2

# Start JACK on UCA202 (line device) as master
echo "Starting JACK server on UCA202 (Card $UCA_CARD)..."
jackd -d alsa -d hw:$UCA_CARD -r 44100 -p 256 -n 2 > /tmp/jack.log 2>&1 &
JACK_PID=$!

# Wait for JACK to initialize
sleep 3

# Check if JACK started successfully
if ! ps -p $JACK_PID > /dev/null; then
    echo "ERROR: JACK failed to start. Check /tmp/jack.log"
    exit 1
fi

echo "JACK server started successfully (PID: $JACK_PID)"

# Start zita bridges for UFO202
echo "Starting zita bridges for UFO202 (Card $UFO_CARD)..."

# Bridge UFO202 inputs to JACK (phono inputs)
echo "Starting zita-a2j for UFO202 inputs..."
zita-a2j -j ufo_phono -d hw:$UFO_CARD -r 44100 -p 256 -c 2 > /tmp/zita-a2j.log 2>&1 &
ZITA_A2J_PID=$!

# Bridge JACK outputs to UFO202 (additional outputs)
echo "Starting zita-j2a for UFO202 outputs..."
zita-j2a -j ufo_out -d hw:$UFO_CARD -r 44100 -p 256 -c 2 > /tmp/zita-j2a.log 2>&1 &
ZITA_J2A_PID=$!

# Wait for zita bridges to initialize
sleep 2

# Check if zita processes started successfully
if ! ps -p $ZITA_A2J_PID > /dev/null; then
    echo "ERROR: zita-a2j failed to start. Check /tmp/zita-a2j.log"
fi

if ! ps -p $ZITA_J2A_PID > /dev/null; then
    echo "ERROR: zita-j2a failed to start. Check /tmp/zita-j2a.log"
fi

echo "Zita bridges started successfully"

# Wait a moment for everything to sync
sleep 2

# Verify JACK ports
echo "Verifying JACK configuration..."
if command -v jack_lsp >/dev/null 2>&1; then
    PORTS=$(jack_lsp | wc -l)
    echo "Available JACK ports: $PORTS"
    if [ $PORTS -ge 8 ]; then
        echo "✅ SUCCESS: All ports available"
    else
        echo "⚠️  WARNING: Expected 8+ ports, found $PORTS"
    fi
fi

echo "Audio setup complete! Starting SuperCollider app..."
echo ""

# Start the SuperCollider app
exec sclang /home/$USER/UHJ-Pi/supercollider/app/UHJ_v23_BEH.scd > /home/$USER/post_output.log 2>&1
