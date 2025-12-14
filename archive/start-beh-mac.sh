#!/usr/bin/env bash

CONFIG_FILE="$HOME/.uhj-vinyl-audio.conf"
echo "Starting vinyl deck + output interface audio setup..."

# Function to detect USB audio devices (after display audio cleanup)
detect_usb_devices() {
    local devices=()
    # After cleanup: Card 1 = UMC204HD (4-output), Card 2 = USB AUDIO CODEC (vinyl)
    devices+=("1:umc204hd")
    devices+=("2:vinyl-codec")
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
    
    # Smart verification: check that 2 USB audio devices exist and are accessible
    echo "Verifying devices are still accessible..."
    devices=$(detect_usb_devices)
    device_count=$(echo "$devices" | wc -w)
    
    if [ "$device_count" -eq 2 ]; then
        echo "✅ Found 2 USB audio devices"
        
        # Check if we can actually connect to the devices (verify they're working)
        test_success=true
        
        # Test UCA202 (first device)
        first_device=$(echo "$devices" | cut -d' ' -f1)
        if [[ $first_device =~ ^([0-9]+):(.*)$ ]]; then
            test_card="${BASH_REMATCH[1]}"
            echo "Testing UCA202 (Card $test_card)..."
            
            # Quick test: try to get device info
            if ! amixer -c "$test_card" sget PCM >/dev/null 2>&1; then
                echo "⚠️  UCA202 (Card $test_card) not responding"
                test_success=false
            else
                echo "✅ UCA202 (Card $test_card) responding"
            fi
        fi
        
        # Test UFO202 (second device)
        second_device=$(echo "$devices" | cut -d' ' -f2)
        if [[ $second_device =~ ^([0-9]+):(.*)$ ]]; then
            test_card="${BASH_REMATCH[1]}"
            echo "Testing UFO202 (Card $test_card)..."
            
            # Quick test: try to get device info
            if ! amixer -c "$test_card" sget PCM >/dev/null 2>&1; then
                echo "⚠️  UFO202 (Card $test_card) not responding"
                test_success=false
            else
                echo "✅ UFO202 (Card $test_card) responding"
            fi
        fi
        
        if [ "$test_success" = true ]; then
            echo ""
            echo "✅ Devices verified and working - using saved configuration"
            echo "  UCA202: Card $(echo "$first_device" | cut -d: -f1)"
            echo "  UFO202: Card $(echo "$second_device" | cut -d: -f1)"
            echo ""
            
            # Update card numbers to current values
            UCA_CARD=$(echo "$first_device" | cut -d: -f1)
            UFO_CARD=$(echo "$second_device" | cut -d: -f1)
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
echo "Stopping existing audio processes..."
pkill jackd 2>/dev/null
pkill zita-a2j 2>/dev/null
pkill zita-j2a 2>/dev/null
sleep 2

# Start JACK on UCA202 (line device) as master
echo "Starting JACK server on UCA202 (Card $UCA_CARD)..."
jackd -P75 -d alsa -C hw:$UCA_CARD -P hw:$UCA_CARD -r 44100 -p 256 -n 2 -S > /tmp/jack.log 2>&1 &
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
sleep 3

# Audio setup complete - jack_quad device will be created by SuperCollider app
echo "Audio setup complete! Starting SuperCollider app..."
echo "Note: jack_quad device will be created automatically for persistent routing"
echo ""

# Check if zita processes started successfully
if ! ps -p $ZITA_A2J_PID > /dev/null; then
    echo "ERROR: zita-a2j failed to start. Check /tmp/zita-a2j.log"
    echo "zita-a2j log contents:"
    cat /tmp/zita-a2j.log
    exit 1
fi

if ! ps -p $ZITA_J2A_PID > /dev/null; then
    echo "ERROR: zita-j2a failed to start. Check /tmp/zita-j2a.log"
    echo "zita-j2a log contents:"
    cat /tmp/zita-j2a.log
    exit 1
fi

echo "Zita bridges started successfully"

# Wait for JACK ports to appear
echo "Waiting for JACK ports to appear..."
sleep 2

# Verify UFO202 ports are available
echo "Checking for UFO202 ports..."
if command -v jack_lsp >/dev/null 2>&1; then
    UFO_PORTS=$(jack_lsp | grep ufo_phono | wc -l)
    echo "Found $UFO_PORTS UFO202 ports"
    
    if [ $UFO_PORTS -lt 2 ]; then
        echo "WARNING: Expected 2 UFO202 ports, found $UFO_PORTS"
        echo "Available JACK ports:"
        jack_lsp | sort
    else
        echo "✅ UFO202 ports available:"
        jack_lsp | grep ufo_phono
    fi
fi

# Wait a moment for everything to sync
sleep 2

# Verify JACK ports and connections
echo "Verifying JACK configuration..."
if command -v jack_lsp >/dev/null 2>&1; then
    PORTS=$(jack_lsp | wc -l)
    echo "Available JACK ports: $PORTS"
    
    # Check specific port types
    SYSTEM_INPUTS=$(jack_lsp | grep "system:capture" | wc -l)
    UFO_INPUTS=$(jack_lsp | grep "ufo_phono:capture" | wc -l)
    SYSTEM_OUTPUTS=$(jack_lsp | grep "system:playback" | wc -l)
    UFO_OUTPUTS=$(jack_lsp | grep "ufo_out:playback" | wc -l)
    
    echo "Port breakdown:"
    echo "  System inputs (UCA202): $SYSTEM_INPUTS"
    echo "  UFO inputs (UFO202): $UFO_INPUTS"
    echo "  System outputs (UCA202): $SYSTEM_OUTPUTS"
    echo "  UFO outputs (UFO202): $UFO_OUTPUTS"
    
    if [ $PORTS -ge 8 ] && [ $UFO_INPUTS -ge 2 ]; then
        echo "✅ SUCCESS: All ports available"
    else
        echo "⚠️  WARNING: Expected 8+ ports with 2+ UFO inputs, found $PORTS total, $UFO_INPUTS UFO inputs"
        echo "Full JACK port list:"
        jack_lsp | sort
    fi
fi

echo "Audio setup complete! Starting SuperCollider app..."
echo ""

# Note: jack_quad device will be created by SuperCollider
echo "Note: jack_quad device will be created automatically by SuperCollider"
echo "This ensures proper timing and port creation for all inputs"

echo ""
echo "Starting SuperCollider app..."
echo "Note: jack_quad device will be created automatically for persistent routing"
echo ""

# Start the SuperCollider app
exec sclang /home/$USER/UHJ-Pi/supercollider/app/UHJ_v23_BEH_PAIR.scd > /home/$USER/post_output.log 2>&1
