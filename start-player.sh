#!/usr/bin/env bash

clear
echo "Starting UHJ-Pi Player Mode..."
echo "Player Mode uses SuperCollider's built-in audio server"

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

detect_flac_devices() {
    input_card=""
    input_name=""
    output_card=""
    output_name=""

    echo "=== Audio Device Setup ==="
    echo ""
    echo "Step 1: Connect your USB audio output device"
    read -p "Press Enter when your output device is connected..." _
    echo "Scanning for output devices..."
    sleep 2

    # Find output device first (required)
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\]: ]]; then
            local card_num="${BASH_REMATCH[1]}"
            local card_name="${BASH_REMATCH[2]}"
            if aplay -l | grep -q "card $card_num:"; then
                output_card="$card_num"; output_name="$card_name"; break
            fi
        fi
    done < /proc/asound/cards

    # Check if any output device was found
    if [ -z "$output_card" ]; then
        echo "❌ No output audio device found!"
        echo "Please connect a USB audio output device and try again."
        echo ""
        read -p "Press Enter to retry..." _
        detect_flac_devices  # Recursive call to retry
        return
    fi
    echo "✓ Using output: hw:$output_card ($output_name)"; show_device_info "$output_card" "$output_name" "output"

    echo ""
    echo "Step 2: Optional - Connect an input device (or press Enter to skip)"
    read -p "Press Enter when your input device is connected (or Enter to skip)..." _
    
    # Check if user wants to configure input
    if [ -n "$_" ]; then
        echo "Scanning for input devices..."
        sleep 2
        
        # Find input device (optional)
        while IFS= read -r line; do
            if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\]: ]]; then
                local card_num="${BASH_REMATCH[1]}"
                local card_name="${BASH_REMATCH[2]}"
                if [ "$card_num" != "$output_card" ] && arecord -l | grep -q "card $card_num:"; then
                    input_card="$card_num"; input_name="$card_name"; break
                fi
            fi
        done < /proc/asound/cards

        # If none found, use the same card for both input and output
        if [ -z "$input_card" ]; then
            if arecord -l | grep -q "card $output_card:"; then
                input_card="$output_card"; input_name="$output_name"
                echo "Using same card for input and output"
            else
                echo "No input capability found on output device"
            fi
        fi

        if [ -n "$input_card" ]; then
            echo "✓ Using input: hw:$input_card ($input_name)"; show_device_info "$input_card" "$input_name" "input"
            
            # Configure input controls if available
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
                        
                        # Skip enum-only controls that are routing selectors
                        if echo "$control_info" | grep -A 20 "Simple mixer control '$full_control_name'" | grep -q "Capabilities.*enum" && ! echo "$control_info" | grep -A 20 "Simple mixer control '$full_control_name'" | grep -q "cvolume"; then
                            if [[ "$control_name" != "IEC958 In" ]]; then
                                continue
                            fi
                        fi
                        
                        # Check if this control has capture volume (cvolume)
                        if echo "$control_info" | grep -A 20 "Simple mixer control '$full_control_name'" | grep -q "cvolume"; then
                            if echo "$control_info" | grep -A 20 "Simple mixer control '$full_control_name'" | grep -q "Capture channels"; then
                                input_options+=("$control_name")
                                seen_controls+=("$control_name")
                            fi
                        fi
                    fi
                done <<< "$control_info"
                
                # Configure input if options available
                if [ ${#input_options[@]} -gt 1 ]; then
                    echo "Multiple input options detected:"
                    for i in "${!input_options[@]}"; do
                        echo "  $((i+1)). ${input_options[$i]}"
                    done
                    echo ""
                    read -p "Choose input source (1-${#input_options[@]}) or Enter for first: " choice
                    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#input_options[@]} ]; then
                        input_source="${input_options[$((choice-1))]}"
                    else
                        input_source="${input_options[0]}"
                    fi
                elif [ ${#input_options[@]} -eq 1 ]; then
                    input_source="${input_options[0]}"
                    echo "✓ Selected input: ${input_source}"
                fi
                
                if [ -n "$input_source" ]; then
                    input_control="$input_source"
                    input_pair="$input_source"
                    has_input_gain=1
                    
                    # Check for input mute capability
                    has_input_mute=0
                    if echo "$control_info" | grep -A 20 "Simple mixer control '$input_control'" | grep -q "cswitch"; then
                        has_input_mute=1
                        echo "✓ Input mute control detected on $input_control"
                    fi
                    
                    # Configure the input
                    echo "Configuring input: $input_source"
                    capture_source_control=$(amixer -c "$input_card" scontents 2>/dev/null | grep -i "capture source" | head -1 | sed "s/.*'\([^']*\)'.*/\1/")
                    if [ -n "$capture_source_control" ]; then
                        amixer -c "$input_card" sset "$capture_source_control" "$input_source" >/dev/null 2>&1 || true
                    fi
                    amixer -c "$input_card" sset "$input_source" cap >/dev/null 2>&1 || true
                    amixer -c "$input_card" sset "$input_source" 80% >/dev/null 2>&1 || true
                    echo "✓ Input configured"
                else
                    has_input_gain=0
                    has_input_mute=0
                    echo "• No input volume controls detected"
                fi
            fi
        fi
    else
        echo "Skipping input device configuration"
        has_input_gain=0
        has_input_mute=0
    fi

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
    if [ -n "$input_card" ]; then
        echo "✓ Input:  hw:$input_card ($input_name)"
        if [ -n "$input_source" ]; then
            echo "  Source: $input_source"
        fi
    else
        echo "• Input:  Not configured (output-only mode)"
    fi
    echo "✓ Output: hw:$output_card ($output_name)"
    if [ "$has_input_gain" -eq 1 ]; then
        echo "✓ Input gain control: $input_control"
    else
        echo "• No input gain control"
    fi
    if [ "$has_input_mute" -eq 1 ]; then
        echo "✓ Input mute control: $input_control"
    else
        echo "• No input mute control"
    fi
    echo ""
}

echo "Preparing Player Mode..."
killall sclang >/dev/null 2>&1 || true
sleep 1

echo "Starting Player application..."
cd /home/$USER/UHJ-Pi
exec sclang supercollider/app/UHJ_v26_PLAYER_SF.scd
