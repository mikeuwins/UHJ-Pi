#!/usr/bin/env bash

CONFIG_FILE="$HOME/.uhj-vin-audio.conf"
echo "Starting Vinyl Deck audio setup..."

# Function to show device information
show_device_info() {
    local card_num=$1
    local card_name=$2
    
    echo "Device Information:"
    echo "  Name: $card_name"
    echo "  Card: hw:$card_num"
    
    # Show playback capabilities
    if aplay -l | grep -q "card $card_num:"; then
        local playback_info=$(aplay -l | grep "card $card_num:" | head -1)
        echo "  Playback: Available"
    else
        echo "  Playback: Not available"
    fi
    
    # Show capture capabilities  
    if arecord -l | grep -q "card $card_num:"; then
        local capture_info=$(arecord -l | grep "card $card_num:" | head -1)
        echo "  Capture: Available"
    else
        echo "  Capture: Not available"
    fi
    
    # Try to get more detailed info from amixer
    if command -v amixer >/dev/null 2>&1; then
        local controls=$(amixer -c $card_num controls 2>/dev/null | wc -l)
        if [ "$controls" -gt 0 ]; then
            echo "  Controls: $controls available"
        fi
    fi
    echo ""
}

# Interactive device detection
detect_vinyl_devices() {
    local vinyl_card=""
    local output_card=""
    local output_name=""
    
    echo "=== USB Turntable Setup ==="
    echo ""
    echo "Step 1: Connect your USB turntable/vinyl deck"
    read -p "Press Enter when your USB turntable is connected..."
    
    # Look for newly connected audio devices
    echo "Scanning for audio devices..."
    sleep 2
    
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\] ]]; then
            local card_num="${BASH_REMATCH[1]}"
            local card_name="${BASH_REMATCH[2]}"
            
            # Look for likely turntable/vinyl deck names
            if [[ $card_name =~ CODEC|Turntable|Vinyl|DJ ]]; then
                vinyl_card="$card_num"
                echo "✓ Found USB turntable: hw:$vinyl_card ($card_name)"
                show_device_info "$card_num" "$card_name"
                break
            fi
        fi
    done < /proc/asound/cards
    
    # If no obvious turntable found, show all devices and let user choose
    if [ -z "$vinyl_card" ]; then
        echo "Could not automatically detect turntable. Available audio devices:"
        echo ""
        cat /proc/asound/cards
        echo ""
        read -p "Enter the card number for your turntable: " vinyl_card
        
        # Get the name for the chosen card
        while IFS= read -r line; do
            if [[ $line =~ ^[[:space:]]*${vinyl_card}[[:space:]]*\[([^]]+)\] ]]; then
                local card_name="${BASH_REMATCH[1]}"
                echo "✓ Selected turntable: hw:$vinyl_card ($card_name)"
                show_device_info "$vinyl_card" "$card_name"
                break
            fi
        done < /proc/asound/cards
    fi
    
    echo "=== USB Audio Interface Setup ==="
    echo ""
    echo "Step 2: Connect your USB audio interface for output"
    echo "(This can be any USB soundcard - Behringer, UMC, etc.)"
    read -p "Press Enter when your USB audio interface is connected..."
    
    # Look for the output device (any card that's not the turntable)
    echo "Scanning for output interface..."
    sleep 2
    
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\] ]]; then
            local card_num="${BASH_REMATCH[1]}"
            local card_name="${BASH_REMATCH[2]}"
            
            # Skip the turntable card
            if [ "$card_num" != "$vinyl_card" ]; then
                output_card="$card_num"
                output_name="$card_name"
                echo "✓ Found output interface: hw:$output_card ($card_name)"
                show_device_info "$card_num" "$card_name"
                break
            fi
        fi
    done < /proc/asound/cards
    
    if [ -z "$vinyl_card" ]; then
        echo "ERROR: Turntable not configured"
        exit 1
    fi
    
    if [ -z "$output_card" ]; then
        echo "ERROR: No output interface found"
        echo "Please connect a USB audio interface and try again"
        exit 1
    fi
    
    echo "VINYL_CARD=$vinyl_card" > "$CONFIG_FILE"
    echo "OUTPUT_CARD=$output_card" >> "$CONFIG_FILE"
    echo "OUTPUT_NAME=$output_name" >> "$CONFIG_FILE"
    echo "Device configuration saved to $CONFIG_FILE"
    
    echo ""
    echo "=== Configuration Complete ==="
    echo "✓ Turntable: hw:$vinyl_card (input)"
    echo "✓ Audio Interface: hw:$output_card ($output_name) (output)"
    echo ""
}

# Kill any existing audio processes
echo "Stopping existing audio processes..."
killall jackd 2>/dev/null
killall sclang 2>/dev/null
sleep 2

# Audio performance optimizations already applied during installation

# Detect devices
detect_vinyl_devices

# Load configuration
source "$CONFIG_FILE"

echo "Starting JACK with:"
echo "  Input: hw:$VINYL_CARD (Vinyl Deck)"
echo "  Output: hw:$OUTPUT_CARD ($OUTPUT_NAME)"

# Start JACK - simple input/output configuration like ESI  
# Large buffer for stability (1024 frames = ~23ms latency, 3 periods)
jackd -P75 -d alsa -C hw:$VINYL_CARD -P hw:$OUTPUT_CARD -r 44100 -p 1024 -n 3 -S &

# Wait for JACK to start
sleep 3

# Check if JACK started successfully
if ! pgrep jackd > /dev/null; then
    echo "ERROR: JACK failed to start. Check /tmp/jack.log for details."
    exit 1
fi

echo "✓ JACK started successfully"

# Show available JACK ports
echo ""
echo "Available JACK ports:"
jack_lsp 2>/dev/null || echo "jack_lsp not available"

echo ""
echo "🎵 Audio setup complete! Starting SuperCollider application..."

# Launch SuperCollider with vinyl deck application
exec sclang /home/michael-uwins/UHJ-Pi/supercollider/app/UHJ_v23_VIN_PAIR.scd
