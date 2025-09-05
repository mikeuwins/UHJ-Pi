#!/usr/bin/env bash

CONFIG_FILE="$HOME/.uhj-generic-audio.conf"
clear
echo "Starting UHJ-Pi generic audio setup..."

show_device_info() {
    local card_num=$1
    local card_name=$2
    local device_type=$3  # "input" or "output"
    
    echo "✓ Selected: $card_name"
    
    # Show only relevant channel count for the device type
    if [ "$device_type" = "input" ]; then
        # Get input channel count from stream info (most reliable)
        local input_channels=$(cat "/proc/asound/card$card_num/stream0" 2>/dev/null | grep -A 20 "Capture:" | grep "Channels:" | head -1 | grep -o "[0-9]*" || echo "2")
        if [ -n "$input_channels" ] && [ "$input_channels" -gt 0 ]; then
            echo "  Inputs: $input_channels channels"
        fi
    elif [ "$device_type" = "output" ]; then
        # Get output channel count from stream info (most reliable)
        local output_channels=$(cat "/proc/asound/card$card_num/stream0" 2>/dev/null | grep -A 20 "Playback:" | grep "Channels:" | head -1 | grep -o "[0-9]*" || echo "2")
        if [ -n "$output_channels" ] && [ "$output_channels" -gt 0 ]; then
            echo "  Outputs: $output_channels channels"
        fi
    fi
    echo ""
}

show_input_options() {
    local card_num=$1
    local card_name=$2
    echo "  Available inputs:"
    
    # Get input options from amixer
    local input_options=()
    local control_info=$(amixer -c "$card_num" scontents 2>/dev/null)
    
    while IFS= read -r line; do
        if [[ $line =~ ^Simple\ mixer\ control\ \'([^\']+)\' ]]; then
            local control_name="${BASH_REMATCH[1]}"
            # Check if this control has capture volume
            if echo "$control_info" | grep -A 20 "Simple mixer control '$control_name'" | grep -q "cvolume"; then
                # Check if it has capture channels (not just playback)
                if echo "$control_info" | grep -A 20 "Simple mixer control '$control_name'" | grep -q "Capture channels"; then
                    input_options+=("$control_name")
                fi
            fi
        fi
    done <<< "$control_info"
    
    if [ ${#input_options[@]} -gt 0 ]; then
        for option in "${input_options[@]}"; do
            echo "    • $option"
        done
    else
        echo "    • No software-controllable inputs detected"
    fi
}

show_output_options() {
    local card_num=$1
    local card_name=$2
    echo "  Available outputs:"
    
    # Get output options from aplay
    output_devices=$(aplay -l | grep "card $card_num:" | sed 's/.*card [0-9]*: \([^,]*\).*/\1/')
    if [ -n "$output_devices" ]; then
        echo "$output_devices" | while read -r device; do
            echo "    • $device"
        done
    else
        echo "    • No output devices detected"
    fi
}

detect_generic_devices() {
    input_card=""
    input_name=""
    output_card=""
    output_name=""

    echo "=== Input Device Setup ==="
    echo ""
    echo "Step 1: Connect the USB audio device you want to use for input"
    read -p "Press Enter when your input device is connected..." _
    echo "Scanning for audio devices..."
    sleep 2

    # Prefer a device that has capture capability
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\]: ]]; then
            local card_num="${BASH_REMATCH[1]}"
            local card_name="${BASH_REMATCH[2]}"
            if arecord -l | grep -q "card $card_num:"; then
                input_card="$card_num"; input_name="$card_name"; break
            fi
        fi
    done < /proc/asound/cards

    # Check if any input device was found
    if [ -z "$input_card" ]; then
        echo "❌ No input audio device found!"
        echo "Please connect a USB audio device and try again."
        echo ""
        read -p "Press Enter to retry..." _
        detect_generic_devices  # Recursive call to retry
        return
    fi
    echo "✓ Using input: hw:$input_card ($input_name)"; show_device_info "$input_card" "$input_name" "input"

    # Detect available input pairs and their controls FIRST
    input_source=""
    input_control=""
    input_pair=""
    has_input_gain=0
    
    if command -v amixer >/dev/null 2>&1; then
        echo "Detecting input options on $input_name..."
        
        # Parse amixer output to find input pairs with capture volume
        input_options=()
        control_info=$(amixer -c "$input_card" scontents 2>/dev/null)
        
        # Look for controls with capture volume (cvolume)
        seen_controls=()
        while IFS= read -r line; do
            if [[ $line =~ ^Simple\ mixer\ control\ \'([^\']+)\' ]]; then
                full_control_name="${BASH_REMATCH[1]}"
                control_name=$(echo "$full_control_name" | sed 's/,[0-9]*$//')
                
                # Skip if we've already processed this control name
                if [[ " ${seen_controls[@]} " =~ " ${control_name} " ]]; then
                    continue
                fi
                
                # Skip PCM controls - these are routing/processing, not physical inputs
                if [[ "$control_name" == "PCM" ]] || [[ "$control_name" == *"PCM"* ]]; then
                    continue
                fi
                
                # Skip Speaker controls - these are output controls, not input sources
                if [[ "$control_name" == "Speaker" ]]; then
                    continue
                fi
                
                # Skip enum-only controls that are routing selectors (like "PCM Capture Source")
                # but keep physical inputs like "IEC958 In" even if they're enum
                if echo "$control_info" | grep -A 20 "Simple mixer control '$full_control_name'" | grep -q "Capabilities.*enum" && ! echo "$control_info" | grep -A 20 "Simple mixer control '$full_control_name'" | grep -q "cvolume"; then
                    # Allow IEC958 In (SPDIF) as it's a physical input
                    if [[ "$control_name" != "IEC958 In" ]]; then
                        continue
                    fi
                fi
                
                # Check if this control has capture volume (cvolume) - needed for input faders
                if echo "$control_info" | grep -A 20 "Simple mixer control '$full_control_name'" | grep -q "cvolume"; then
                    # Check if it has capture channels (not just playback)
                    if echo "$control_info" | grep -A 20 "Simple mixer control '$full_control_name'" | grep -q "Capture channels"; then
                        # Get channel info to distinguish between stereo/mono
                        local channel_info=$(echo "$control_info" | grep -A 5 "Simple mixer control '$full_control_name'" | grep "Capture channels:" | head -1)
                        if echo "$channel_info" | grep -q "Front Left - Front Right"; then
                            input_options+=("$control_name")
                            seen_controls+=("$control_name")
                        elif echo "$channel_info" | grep -q "Mono"; then
                            input_options+=("$control_name")
                            seen_controls+=("$control_name")
                        else
                            input_options+=("$control_name")
                            seen_controls+=("$control_name")
                        fi
                    fi
                fi
            fi
        done <<< "$control_info"
        
        # Always ask user to choose if multiple options available
        if [ ${#input_options[@]} -gt 1 ]; then
            echo "Multiple input options detected:"
            for i in "${!input_options[@]}"; do
                echo "  $((i+1)). ${input_options[$i]}"
            done
            echo ""
            read -p "Choose input source (1-${#input_options[@]}): " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#input_options[@]} ]; then
                input_source="${input_options[$((choice-1))]}"
            else
                input_source="${input_options[0]}"
            fi
        elif [ ${#input_options[@]} -eq 1 ]; then
            input_source="${input_options[0]}"
            echo "✓ Selected input: ${input_source}"
        fi
        
        # Use the selected input source directly
        input_source="$input_source"
        
        if [ -n "$input_source" ]; then
            # Use the selected input source for gain control
            input_control="$input_source"
            input_pair="$input_source"
            has_input_gain=1
            echo "✓ Selected input: $input_source"
            
            # Check if the input control (PCM or fallback) has a mute/capture switch
            has_input_mute=0
            if echo "$control_info" | grep -A 20 "Simple mixer control '$input_control'" | grep -q "cswitch"; then
                has_input_mute=1
                echo "✓ Input mute control detected on $input_control"
            else
                echo "• No input mute control detected on $input_control"
            fi
            
            # Actually switch ALSA to use the selected input source
            echo "Switching to $input_source input..."
            
            # Find the capture source control name dynamically
            capture_source_control=$(amixer -c "$input_card" scontents 2>/dev/null | grep -i "capture source" | head -1 | sed "s/.*'\([^']*\)'.*/\1/")
            if [ -n "$capture_source_control" ]; then
                echo "Setting $capture_source_control to: $input_source"
                amixer -c "$input_card" sset "$capture_source_control" "$input_source" >/dev/null 2>&1 || true
            fi
            
            # Then enable capture on that input
            echo "Enabling capture on: $input_source"
            amixer -c "$input_card" sset "$input_source" cap >/dev/null 2>&1 || true
            amixer -c "$input_card" sset "$input_source" 80% >/dev/null 2>&1 || true
            echo "✓ Input switched to $input_source"
        else
            echo "• No input volume controls detected"
            has_input_gain=0
            has_input_mute=0
        fi
        
        # For cards with only physical controls (no software gain), don't use ALSA mute
        # Let the synth handle mute instead
        if [ "$has_input_gain" -eq 0 ]; then
            has_input_mute=0
            echo "• Using synth mute (no software input controls detected)"
        fi
    fi

    echo ""
    echo "=== Output Device Setup ==="
    echo ""
    echo "Step 2: Connect the USB audio device you want to use for output"
    echo "(or just press Enter if using the same device for input and output)"
    read -p "Press Enter when your output device is connected..." _
    echo "Scanning for output interface..."; sleep 2
    echo "Available devices:"; cat /proc/asound/cards; echo ""; sleep 1

    # Prefer a device that has playback capability and is not the chosen input
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\]: ]]; then
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

    echo "✓ Using output: hw:$output_card ($output_name)"; show_device_info "$output_card" "$output_name" "output"


    echo "INPUT_CARD=$input_card" > "$CONFIG_FILE"
    echo "INPUT_NAME=$input_name" >> "$CONFIG_FILE"
    echo "INPUT_SOURCE=$input_source" >> "$CONFIG_FILE"
    echo "INPUT_CONTROL=$input_control" >> "$CONFIG_FILE"
    echo "INPUT_PAIR=$input_pair" >> "$CONFIG_FILE"
    echo "OUTPUT_CARD=$output_card" >> "$CONFIG_FILE"
    echo "OUTPUT_NAME=$output_name" >> "$CONFIG_FILE"
    echo "HAS_INPUT_GAIN=$has_input_gain" >> "$CONFIG_FILE"
    echo "HAS_INPUT_MUTE=$has_input_mute" >> "$CONFIG_FILE"
    echo ""
    echo "=== Configuration Complete ==="
    echo "✓ Input:  hw:$input_card ($input_name)"
    if [ -n "$input_source" ]; then
        echo "  Source: $input_source"
    fi
    echo "✓ Output: hw:$output_card ($output_name)"
    if [ "$has_input_gain" -eq 1 ]; then
        echo "✓ Input gain control: $input_control"
    else
        echo "• No input gain control detected"
    fi
    if [ "$has_input_mute" -eq 1 ]; then
        echo "✓ Input mute control: $input_control"
    else
        echo "• No input mute control detected"
    fi
    echo ""
}

echo "Preparing audio system..."
killall jackd >/dev/null 2>&1 || true
killall sclang >/dev/null 2>&1 || true
sleep 2

detect_generic_devices
source "$CONFIG_FILE"

echo "Starting audio system..."

jackd -P75 -d alsa -C hw:$INPUT_CARD -P hw:$OUTPUT_CARD -r 44100 -p 1024 -n 3 -S >/dev/null 2>&1 &
sleep 3
if ! pgrep jackd > /dev/null; then
    echo "ERROR: Audio system failed to start."
    exit 1
fi
echo "✓ Audio system ready"

# Set and export capability flags and input details to the app environment
HAS_INPUT_GAIN=$has_input_gain
HAS_INPUT_MUTE=$has_input_mute
INPUT_CARD=$input_card
INPUT_SOURCE=$input_source
INPUT_CONTROL=$input_control
INPUT_PAIR=$input_pair
export HAS_INPUT_GAIN
export HAS_INPUT_MUTE
export INPUT_CARD
export INPUT_SOURCE
export INPUT_CONTROL
export INPUT_PAIR

# Debug: print what we're exporting
echo "DEBUG - Exporting variables:"
echo "HAS_INPUT_GAIN=$HAS_INPUT_GAIN"
echo "INPUT_CARD=$INPUT_CARD"
echo "INPUT_CONTROL=$INPUT_CONTROL"

# Launch SuperCollider application
echo "Starting application..."
exec sclang "$HOME/UHJ-Pi/supercollider/app/UHJ_v23_GEN_PAIR.scd"


