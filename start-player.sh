#!/usr/bin/env bash

clear
echo "=== UHJ-PI AMBISONIC PLAYER SYSTEM ==="

show_device_info() {
    local card_num=$1
    local card_name=$2
    local device_type=$3  # "input" or "output"
    
    # Show channel count - useful info for users
    if [ "$device_type" = "input" ]; then
        local input_channels=$(cat "/proc/asound/card$card_num/stream0" 2>/dev/null | grep -A 20 "Capture:" | grep "Channels:" | head -1 | grep -o "[0-9]*" || echo "2")
        if [ -n "$input_channels" ] && [ "$input_channels" -gt 0 ]; then
            echo "  Inputs: $input_channels channels"
        fi
    elif [ "$device_type" = "output" ]; then
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
    read -t 10 -p "Press Enter when your output device is connected (auto-continuing in 10 seconds)..." _
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
        echo ""
        echo "Please check:"
        echo "  • USB audio device is connected"
        echo "  • Device is powered on"
        echo "  • USB cable is working"
        echo ""
        read -t 10 -p "Press Enter to retry (auto-continuing in 10 seconds)..." _
        detect_flac_devices  # Recursive call to retry
        return
    fi
    echo "✓ Using output: hw:$output_card ($output_name)"; show_device_info "$output_card" "$output_name" "output"

    echo ""
    echo "Step 2: Optional - Connect an input device (or press Enter to skip)"
    read -t 10 -p "Press Enter when your input device is connected (auto-continuing in 10 seconds to skip)..." _
    
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
                    echo "Select Input:"
                    echo ""
                    for i in "${!input_options[@]}"; do
                        if [ $i -eq 0 ]; then
                            echo "$((i+1)). ${input_options[$i]} (Default)"
                        else
                            echo "$((i+1)). ${input_options[$i]}"
                        fi
                    done
                    echo ""
                    read -t 10 -n 1 choice
                    echo ""
                    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#input_options[@]} ]; then
                        input_source="${input_options[$((choice-1))]}"
                    else
                        input_source="${input_options[0]}"
                    fi
                elif [ ${#input_options[@]} -eq 1 ]; then
                    input_source="${input_options[0]}"
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
    read -t 5 -p "Press Enter to continue (auto-continuing in 5 seconds)..." _
    clear
}

CONFIG_FILE="$HOME/.uhj-generic-audio.conf"

show_device_info() {
    local card_num=$1
    local card_name=$2
    local device_type=$3  # "input" or "output"
    
    # Show channel count - useful info for users
    if [ "$device_type" = "input" ]; then
        local input_channels=$(cat "/proc/asound/card$card_num/stream0" 2>/dev/null | grep -A 20 "Capture:" | grep "Channels:" | head -1 | grep -o "[0-9]*" || echo "2")
        if [ -n "$input_channels" ] && [ "$input_channels" -gt 0 ]; then
            echo "  Inputs: $input_channels channels"
        fi
    elif [ "$device_type" = "output" ]; then
        local output_channels=$(cat "/proc/asound/card$card_num/stream0" 2>/dev/null | grep -A 20 "Playback:" | grep "Channels:" | head -1 | grep -o "[0-9]*" || echo "2")
        if [ -n "$output_channels" ] && [ "$output_channels" -gt 0 ]; then
            echo "  Outputs: $output_channels channels"
        fi
    fi
    echo ""
}

detect_generic_devices() {
    input_card=""
    input_name=""
    output_card=""
    output_name=""
    
    # Retry counter for input device
    input_attempts=0
    max_attempts=3

    echo "=== Input Device Setup ==="
    echo ""
    echo "Connect your USB audio input device."
    
    while [ -z "$input_card" ] && [ $input_attempts -lt $max_attempts ]; do
        input_attempts=$((input_attempts + 1))
        
        if [ $input_attempts -gt 1 ]; then
            echo "No device found. Retrying... (attempt $input_attempts/$max_attempts)"
        fi
        
        # Countdown (interruptible)
        for i in {10..1}; do
            echo -ne "\rContinuing in $i... (press Enter to skip) "
            read -t 1 -n 1 key 2>/dev/null
            if [ $? -eq 0 ]; then
                break
            fi
        done
        echo ""
        echo "Scanning for Audio Input Device..."
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
    done

    # Check if max attempts reached without finding device
    if [ -z "$input_card" ]; then
        echo ""
        echo "❌ Failed to find audio input device after $max_attempts attempts."
        echo ""
        echo "Please check:"
        echo "  • USB audio device is connected"
        echo "  • Device is powered on"
        echo "  • USB cable is working"
        echo ""
        echo "Try connecting the device and running the script again."
        echo "Exiting..."
        exit 1
    fi
    echo "Found $input_name"
    show_device_info "$input_card" "$input_name" "input"
    echo ""

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
        
        # Default to first option unless user specifically chooses
        if [ ${#input_options[@]} -gt 1 ]; then
            echo "Multiple inputs available. Using first option: ${input_options[0]}"
            echo "Press Enter to continue or type a number 1-${#input_options[@]} to choose:"
            read -t 10 -n 1 choice
            echo ""
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#input_options[@]} ]; then
                input_source="${input_options[$((choice-1))]}"
                echo "✓ Selected: ${input_source}"
            else
                input_source="${input_options[0]}"
                echo "✓ Using: ${input_source}"
            fi
        elif [ ${#input_options[@]} -eq 1 ]; then
            input_source="${input_options[0]}"
            echo "✓ Selected: ${input_source}"
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
    echo "Checking for separate output device (or using same as input)..."
    
    # Countdown (interruptible)
    for i in {5..1}; do
        echo -ne "\rContinuing in $i... (press Enter to skip) "
        read -t 1 -n 1 key 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "\rSkipping countdown...                    "
            break
        fi
    done
    echo ""
    echo "Scanning for Audio Output Device..."
    sleep 1

    # Look for a separate output device first
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[([^]]+)\]: ]]; then
            local card_num="${BASH_REMATCH[1]}"
            local card_name="${BASH_REMATCH[2]}"
            if [ "$card_num" != "$input_card" ] && aplay -l | grep -q "card $card_num:"; then
                output_card="$card_num"; output_name="$card_name"; break
            fi
        fi
    done < /proc/asound/cards

    # If no separate output found, use the same card for both
    if [ -z "$output_card" ]; then
        output_card="$input_card"; output_name="$input_name"
        echo "Using same device for input and output"
    else
        echo "Found separate output device"
    fi

    echo "Found $output_name"
    show_device_info "$output_card" "$output_name" "output"

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

echo "Configuring Audio System"
echo ""
killall jackd >/dev/null 2>&1 || true
killall sclang >/dev/null 2>&1 || true
sleep 2

detect_generic_devices
source "$CONFIG_FILE"

clear
jackd -P75 -d alsa -C hw:$INPUT_CARD -P hw:$OUTPUT_CARD -r 44100 -p 2048 -n 3 -S >/dev/null 2>&1 &
sleep 3
if ! pgrep jackd > /dev/null; then
    echo "ERROR: Audio system failed to start."
    exit 1
fi
echo "✓ Audio system ready"
echo ""

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

# Mount USB drives before starting the application
echo "=== USB Drive Setup ==="
echo ""
echo "Insert a USB drive with music files."
echo "Supported formats: WAV, FLAC"
echo "Required structure: Artist folders containing Album folders"
echo "Example: /Artist Name/Album Name/track01.wav"
echo ""
read -t 10 -p "Press Enter when ready (auto-continuing in 10 seconds to skip)..." _
echo ""
echo "Scanning for USB drives..."
# Capture mount output to check for success
mount_output=$(/usr/local/bin/mount-usb 2>&1)
mount_exit_code=$?

# Extract USB volume name from mount output
if echo "$mount_output" | grep -q "Successfully mounted"; then
    usb_name=$(echo "$mount_output" | grep "Successfully mounted" | sed 's/.*at \/media\/[^\/]*\///' | sed 's/.*✓ Successfully mounted.*at.*\/media\/[^\/]*\///')
    echo "Found USB volume '$usb_name'"
elif [ $mount_exit_code -eq 0 ]; then
    echo "✓ USB drive mounted"
else
    echo "• No USB drives found"
fi
echo ""
read -t 5 -p "Press Enter to continue (auto-continuing in 5 seconds)..." _
clear

# Initialize Bluetooth headtracker (if available)
echo "=== Headtracker Setup ==="
echo ""
echo "If you have a Bluetooth headtracker, turn it on now."
echo ""
read -t 10 -p "Press Enter when ready (auto-continuing in 10 seconds to skip)..." _
echo ""
echo "Scanning for headtracker..."
ht_output=$(/usr/local/bin/ble-ht 2>&1)
ht_exit_code=$?

if echo "$ht_output" | grep -q "PAIRED_AND_CONNECTED"; then
    echo "✓ Headtracker detected and connected"
elif echo "$ht_output" | grep -q "PAIRING_FAILED"; then
    echo "• No headtracker found"
else
    echo "• Headtracker scan complete"
fi
echo ""
clear

# Launch SuperCollider application
echo "=== Launching Player Application ==="
echo ""
echo "Starting Player application..."
cd /home/$USER/UHJ-Pi

# Give user a moment to see the message
sleep 2

# Launch SuperCollider and capture any errors
echo "Launching SuperCollider..."
if ! sclang supercollider/app/UHJ_v26_PLAYER_SF.scd; then
    clear
    echo "=== APPLICATION LAUNCH FAILED ==="
    echo ""
    echo "❌ The Player application failed to start."
    echo ""
    echo "Possible causes:"
    echo "  • Audio system not ready"
    echo "  • Missing audio device"
    echo "  • SuperCollider configuration issue"
    echo "  • File permission problem"
    echo ""
    echo "Try these steps:"
    echo "  1. Check your USB audio device is connected"
    echo "  2. Make sure no other audio applications are running"
    echo "  3. Try running the startup script again"
    echo ""
    echo "If the problem persists, check the audio device"
    echo "connections and restart the Raspberry Pi."
    echo ""
    read -t 10 -p "Press Enter to exit (auto-exiting in 10 seconds)..." _
    exit 1
fi
