#!/usr/bin/env bash

CONFIG_FILE="$HOME/.uhj-generic-audio.conf"
clear
echo "Starting UHJ-Pi generic audio setup..."

show_device_info() {
    local card_num=$1
    local card_name=$2
    echo "Device Information:"
    echo "  Name: $card_name"
    echo "  Card: hw:$card_num"
    if aplay -l | grep -q "card $card_num:"; then
        echo "  Playback: Available"
    else
        echo "  Playback: Not available"
    fi
    if arecord -l | grep -q "card $card_num:"; then
        echo "  Capture: Available"
    else
        echo "  Capture: Not available"
    fi
    if command -v amixer >/dev/null 2>&1; then
        local controls=$(amixer -c $card_num controls 2>/dev/null | wc -l)
        if [ "$controls" -gt 0 ]; then
            echo "  Controls: $controls available"
        fi
    fi
    echo ""
}

detect_generic_devices() {
    local input_card=""
    local input_name=""
    local output_card=""
    local output_name=""

    echo "=== Input Device Setup ==="
    echo ""
    echo "Step 1: Connect your input device (turntable, mic, line-in, etc.)"
    read -p "Press Enter when your input device is connected..." _
    echo "Scanning for audio devices..."
    sleep 2

    # Prefer a device that has capture capability
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\] ]]; then
            local card_num="${BASH_REMATCH[1]}"
            local card_name="${BASH_REMATCH[2]}"
            if arecord -l | grep -q "card $card_num:"; then
                input_card="$card_num"; input_name="$card_name"; break
            fi
        fi
    done < /proc/asound/cards

    # Fallback to first card
    if [ -z "$input_card" ]; then
        input_card="0"
        input_name=$(sed -n '1{s/.*\[\([^]]*\)\].*/\1/p;}' /proc/asound/cards)
    fi
    echo "✓ Using input: hw:$input_card ($input_name)"; show_device_info "$input_card" "$input_name"

    echo "=== Output Device Setup ==="
    echo ""
    echo "Step 2: Connect your output device (USB audio interface, etc.)"
    read -p "Press Enter when your output device is connected..." _
    echo "Scanning for output interface..."; sleep 2
    echo "Available devices:"; cat /proc/asound/cards; echo ""; sleep 1

    # Prefer a device that has playback capability and is not the chosen input
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\] ]]; then
            local card_num="${BASH_REMATCH[1]}"
            local card_name="${BASH_REMATCH[2]}"
            if [ "$card_num" != "$input_card" ] && aplay -l | grep -q "card $card_num:"; then
                output_card="$card_num"; output_name="$card_name"; break
            fi
        fi
    done < /proc/asound/cards

    # If none found, use the same card for both
    if [ -z "$output_card" ]; then
        output_card="$input_card"; output_name="$input_name"
        echo "No separate output found; using same card for input and output"
    fi

    echo "✓ Using output: hw:$output_card ($output_name)"; show_device_info "$output_card" "$output_name"

    # Probe input gain availability (simple heuristic: any Capture control)
    local has_input_gain=0
    if command -v amixer >/dev/null 2>&1; then
        if amixer -c "$input_card" scontrols 2>/dev/null | grep -qi 'Capture'; then
            has_input_gain=1
        fi
    fi

    echo "INPUT_CARD=$input_card" > "$CONFIG_FILE"
    echo "INPUT_NAME=$input_name" >> "$CONFIG_FILE"
    echo "OUTPUT_CARD=$output_card" >> "$CONFIG_FILE"
    echo "OUTPUT_NAME=$output_name" >> "$CONFIG_FILE"
    echo "HAS_INPUT_GAIN=$has_input_gain" >> "$CONFIG_FILE"
    echo "Device configuration saved to $CONFIG_FILE"
    echo ""
    echo "=== Configuration Complete ==="
    echo "✓ Input:  hw:$input_card ($input_name)"
    echo "✓ Output: hw:$output_card ($output_name)"
    if [ "$has_input_gain" -eq 1 ]; then
        echo "✓ Input gain control detected"
    else
        echo "• No input gain control detected"
    fi
    echo ""
}

echo "Stopping existing audio processes..."
killall jackd 2>/dev/null
killall sclang 2>/dev/null
sleep 2

detect_generic_devices
source "$CONFIG_FILE"

echo "Starting JACK with:"
echo "  Input:  hw:$INPUT_CARD ($INPUT_NAME)"
echo "  Output: hw:$OUTPUT_CARD ($OUTPUT_NAME)"

jackd -P75 -d alsa -C hw:$INPUT_CARD -P hw:$OUTPUT_CARD -r 44100 -p 1024 -n 3 -S &
sleep 3
if ! pgrep jackd > /dev/null; then
    echo "ERROR: JACK failed to start."
    exit 1
fi
echo "✓ JACK started successfully"

echo "Available JACK ports:"; jack_lsp 2>/dev/null || echo "jack_lsp not available"; echo ""

# Export capability flag to the app environment
export HAS_INPUT_GAIN

echo "Launching SuperCollider app..."
exec sclang "$HOME/UHJ-Pi/supercollider/app/UHJ_v23_VIN_PAIR.scd"


