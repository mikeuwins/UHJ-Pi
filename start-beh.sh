#!/usr/bin/env bash

# Clear screen for clean output
clear

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
            uca_device="$card:$usb_path"
            break
        fi
    done
    
    if [ -z "$uca_device" ]; then
        echo "ERROR: No USB audio device detected. Please check connection."
        exit 1
    fi
    
    echo "UCA202 registered as line input/outputs 1 & 2 (Card $(echo "$uca_device" | cut -d: -f1))"
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
                ufo_device="$card:$usb_path"
                break
            fi
        fi
    done
    
    if [ -z "$ufo_device" ]; then
        echo "ERROR: Second USB audio device not detected. Please check connection."
        exit 1
    fi
    
    echo "UFO202 registered as phono input/outputs 3 & 4 (Card $(echo "$ufo_device" | cut -d: -f1))"
    echo ""
    
    # Save configuration
    cat > "$CONFIG_FILE" << CONFIG_EOF
# UHJ-Pi Behringer Audio Configuration
# Generated on $(date)
UCA_DEVICE="$uca_device"
UFO_DEVICE="$ufo_device"
UCA_CARD=$(echo "$uca_device" | cut -d: -f1)
UFO_CARD=$(echo "$ufo_device" | cut -d: -f1)
CONFIG_EOF
    
    # Return the detected devices
    UCA_CARD=$(echo "$uca_device" | cut -d: -f1)
    UFO_CARD=$(echo "$ufo_device" | cut -d: -f1)
}

# Check if configuration exists and devices are still valid
if [ -f "$CONFIG_FILE" ]; then
    echo "Found existing configuration, checking devices..."
    source "$CONFIG_FILE"
    
    # Smart verification: check that 2 USB audio devices exist and are accessible
    devices=$(detect_usb_devices)
    device_count=$(echo "$devices" | wc -w)
    
    if [ "$device_count" -eq 2 ]; then
        echo "✓ Found 2 USB audio devices"
        
        # Check if we can actually connect to the devices (verify they're working)
        test_success=true
        
        # Use the saved card numbers from configuration (already loaded above)
        
        # Test UCA202
        if [ -n "$UCA_CARD" ]; then
            echo "Testing UCA202 (Card $UCA_CARD)..."
            if ! amixer -c "$UCA_CARD" sget PCM >/dev/null 2>&1; then
                echo "⚠️  UCA202 (Card $UCA_CARD) not responding"
                test_success=false
            else
                echo "✓ UCA202 (Card $UCA_CARD) responding"
            fi
        else
            echo "⚠️  UCA202 not found"
            test_success=false
        fi
        
        # Test UFO202
        if [ -n "$UFO_CARD" ]; then
            echo "Testing UFO202 (Card $UFO_CARD)..."
            if ! amixer -c "$UFO_CARD" sget PCM >/dev/null 2>&1; then
                echo "⚠️  UFO202 (Card $UFO_CARD) not responding"
                test_success=false
            else
                echo "✓ UFO202 (Card $UFO_CARD) responding"
            fi
        else
            echo "⚠️  UFO202 not found"
            test_success=false
        fi
        
        if [ "$test_success" = true ]; then
            echo ""
            echo "✓ Devices verified and working - using saved configuration"
            echo "  UCA202: Card $UCA_CARD"
            echo "  UFO202: Card $UFO_CARD"
            echo ""
        else
            echo "⚠️  Device verification failed, re-registering..."
            rm "$CONFIG_FILE"
            register_devices
        fi
    else
        echo "⚠️  Expected 2 USB audio devices, found $device_count"
        echo "Re-registering devices..."
        rm "$CONFIG_FILE"
        register_devices
    fi
else
    echo "No configuration found, registering devices..."
    register_devices
fi

# Stop any existing audio processes
pkill jackd 2>/dev/null
pkill zita-a2j 2>/dev/null
pkill zita-j2a 2>/dev/null
sleep 2

# Start JACK on UCA202 (line device) as master
echo "Starting JACK server on UCA202 (Card $UCA_CARD)..."
jackd -d alsa -d hw:$UCA_CARD -r 44100 -p 256 -n 2 > /dev/null 2>&1 &
JACK_PID=$!

# Wait for JACK to initialize
sleep 3

# Check if JACK started successfully
if ! ps -p $JACK_PID > /dev/null; then
    echo "WARNING: JACK failed to start"
    echo "Audio setup will need to be configured manually after reboot"
fi

# Start zita bridges for UFO202
zita-a2j -j ufo_phono -d hw:$UFO_CARD -r 44100 -p 256 -c 2 > /dev/null 2>&1 &
ZITA_A2J_PID=$!

zita-j2a -j ufo_out -d hw:$UFO_CARD -r 44100 -p 256 -c 2 > /dev/null 2>&1 &
ZITA_J2A_PID=$!

# Wait for zita bridges to initialize
sleep 2

# Check if zita processes started successfully
if ! ps -p $ZITA_A2J_PID > /dev/null; then
    echo "WARNING: zita-a2j failed to start"
fi

if ! ps -p $ZITA_J2A_PID > /dev/null; then
    echo "WARNING: zita-j2a failed to start"
fi

# Wait a moment for everything to sync
sleep 2

# Verify JACK ports
echo "Verifying JACK configuration..."
if command -v jack_lsp >/dev/null 2>&1; then
    # Check specific port types
    SYSTEM_INPUTS=$(jack_lsp | grep "system:capture" | wc -l)
    UFO_INPUTS=$(jack_lsp | grep "ufo_phono:capture" | wc -l)
    SYSTEM_OUTPUTS=$(jack_lsp | grep "system:playback" | wc -l)
    UFO_OUTPUTS=$(jack_lsp | grep "ufo_out:playback" | wc -l)
    
    echo "Audio ports configured:"
    echo "  UCA202: $SYSTEM_INPUTS inputs, $SYSTEM_OUTPUTS outputs"
    echo "  UFO202: $UFO_INPUTS inputs, $UFO_OUTPUTS outputs"
    
    if [ $UFO_INPUTS -ge 2 ]; then
        echo "✓ SUCCESS: All audio ports available"
    else
        echo "⚠️  WARNING: Expected 2+ UFO inputs, found $UFO_INPUTS"
        echo "Full JACK port list:"
        jack_lsp | sort
    fi
fi

echo "Audio setup complete!"

# Start the SuperCollider app
echo "Starting SuperCollider app..."
exec sclang /home/$USER/UHJ-Pi/supercollider/app/UHJ_v23_BEH_PAIR.scd > /home/$USER/post_output.log 2>&1
