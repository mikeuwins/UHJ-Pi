#!/usr/bin/env bash

# Color definitions for terminal output
RED='\033[1;31m'        # Bright red
GREEN='\033[1;32m'      # Bright green
YELLOW='\033[1;33m'     # Bright yellow
BLUE='\033[0;34m'       # Blue
CYAN='\033[1;36m'       # Bright cyan
MAGENTA='\033[1;35m'    # Bright magenta
WHITE='\033[1;37m'      # Bright white
RESET='\033[0m'         # Reset to default

# Magic wand: uncomment the line below to make ALL text UPPERCASE
# echo() { command echo "$@" | tr '[:lower:]' '[:upper:]'; }

clear

# Create centered title box
get_terminal_width() {
    echo $(tput cols 2>/dev/null || echo 80)
}

create_title_box() {
    local width=$(get_terminal_width)
    local title="UHJ-Pi AMBISONIC PLAYER"
    local title_len=${#title}
    local padding=$(( (width - title_len - 4) / 2 ))
    
    # Simple clean box with asterisks
    printf "${CYAN}"
    printf "%*s" $width | tr ' ' '*'
    printf "\n"
    
    # Title line
    printf "*%*s  %s%*s*\n" $padding "" "$title" $padding
    
    # Bottom border
    printf "%*s" $width | tr ' ' '*'
    printf "${RESET}\n"
}

create_title_box

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
        echo "    • Single input detected"
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
}

detect_generic_devices() {
    input_card=""
    input_name=""
    output_card=""
    output_name=""
    
    # Retry counter for input device
    input_attempts=0
    max_attempts=3

    echo -e "${YELLOW}=== Input Device Setup ===${RESET}"
    echo ""
    
    while [ -z "$input_card" ] && [ $input_attempts -lt $max_attempts ]; do
        input_attempts=$((input_attempts + 1))
        
        if [ $input_attempts -gt 1 ]; then
            echo "No device found. Retrying... (attempt $input_attempts/$max_attempts)"
        fi
        
        # Countdown (interruptible)
        for i in {10..1}; do
            echo -ne "\rConnect USB Audio Input Device... ($i) [Enter to continue] "
            read -t 1 -n 1 key 2>/dev/null
            if [ $? -eq 0 ]; then
                break
            fi
        done
        echo "Detecting Audio Input Device..."
        echo ""
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
        echo "Try re-connecting the device and running the script again."
        echo ""
        echo "Exiting..."
        echo ""
        exit 1
    fi
    # Get input channel count
    input_channels=$(cat "/proc/asound/card$input_card/stream0" 2>/dev/null | grep -A 20 "Capture:" | grep "Channels:" | head -1 | grep -o "[0-9]*" || echo "2")
    echo -e "${GREEN}Found${RESET} ${input_name%-*} - $input_channels inputs"

    # Detect available input pairs and their controls FIRST
    input_source=""
    input_control=""
    input_pair=""
    has_input_gain=0
    
    if command -v amixer >/dev/null 2>&1; then
        
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
            echo ""
            echo -e "${YELLOW}Select Input:${RESET}"
            for i in "${!input_options[@]}"; do
                if [ $i -eq 0 ]; then
                    echo "$((i+1)). ${input_options[$i]} (Default)"
                else
                    echo "$((i+1)). ${input_options[$i]}"
                fi
            done
            echo ""
            for i in {10..1}; do
                echo -ne "\rChoose option... ($i) [Enter to continue] "
                read -t 1 -n 1 choice
                if [ $? -eq 0 ]; then
                    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#input_options[@]} ]; then
                        break
                    elif [ -z "$choice" ]; then
                        # Enter pressed, use default
                        choice=1
                        break
                    fi
                fi
            done
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#input_options[@]} ]; then
                input_source="${input_options[$((choice-1))]}"
            else
                input_source="${input_options[0]}"
            fi
        elif [ ${#input_options[@]} -eq 1 ]; then
            input_source="${input_options[0]}"
        fi
        
        # Use the selected input source directly
        input_source="$input_source"
        
        if [ -n "$input_source" ]; then
            # Use the selected input source for gain control
            input_control="$input_source"
            input_pair="$input_source"
            has_input_gain=1
            
            # Find the capture source control name dynamically
            capture_source_control=$(amixer -c "$input_card" scontents 2>/dev/null | grep -i "capture source" | head -1 | sed "s/.*'\([^']*\)'.*/\1/")
            if [ -n "$capture_source_control" ]; then
                amixer -c "$input_card" sset "$capture_source_control" "$input_source" >/dev/null 2>&1 || true
            fi
            
            # Then enable capture on that input
            amixer -c "$input_card" sset "$input_source" cap >/dev/null 2>&1 || true
            amixer -c "$input_card" sset "$input_source" 80% >/dev/null 2>&1 || true
        else
            echo "• Input device ready"
            has_input_gain=0
            has_input_mute=0
        fi
        
        # For cards with only physical controls (no software gain), don't use ALSA mute
        # Let the synth handle mute instead
        if [ "$has_input_gain" -eq 0 ]; then
            has_input_mute=0
            echo "• Input ready"
        fi
    fi

    echo ""
    echo -e "${YELLOW}=== Output Device Setup ===${RESET}"
    echo ""
    
    # Countdown (interruptible)
    for i in {10..1}; do
        echo -ne "\rConnect USB Audio Output Device... ($i) [Enter to continue] "
        read -t 1 -n 1 key 2>/dev/null
        if [ $? -eq 0 ]; then
            break
        fi
    done
    echo "Detecting Audio Output Device..."
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
        echo "• Using same device for input and output"
    else
        echo "• Found separate output device"
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
    echo -e "${GREEN}=== Configuration Complete ===${RESET}"
    echo ""
    echo "Input: $input_name"
    # Get input channel count
    input_channels=$(cat "/proc/asound/card$input_card/stream0" 2>/dev/null | grep -A 20 "Capture:" | grep "Channels:" | head -1 | grep -o "[0-9]*" || echo "2")
    if [ -n "$input_channels" ] && [ "$input_channels" -gt 0 ]; then
        echo "  Inputs: $input_channels channels"
    fi
    if [ -n "$input_source" ]; then
        echo "  Source: $input_source"
    fi
    echo ""
    echo "Output: $output_name"
    # Get output channel count
    output_channels=$(cat "/proc/asound/card$output_card/stream0" 2>/dev/null | grep -A 20 "Playback:" | grep "Channels:" | head -1 | grep -o "[0-9]*" || echo "2")
    if [ -n "$output_channels" ] && [ "$output_channels" -gt 0 ]; then
        echo "  Outputs: $output_channels channels"
    fi
    echo ""
}

echo ""
killall jackd >/dev/null 2>&1 || true
killall sclang >/dev/null 2>&1 || true
sleep 2

detect_generic_devices
source "$CONFIG_FILE"

jackd -P75 -d alsa -C hw:$INPUT_CARD -P hw:$OUTPUT_CARD -r 44100 -p 2048 -n 3 -S >/dev/null 2>&1 &
sleep 3
if ! pgrep jackd > /dev/null; then
    echo "ERROR: Audio system failed to start."
    echo ""
    exit 1
fi

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
clear
echo -e "${YELLOW}=== USB Drive Setup ===${RESET}"
echo ""
echo "Insert a USB drive containing your music files."
echo ""
echo "Organise your music like this:"
echo ""
echo "Parent Folder"
echo "  +-- Artist Name/"
echo "      +-- Album Name/"
echo "          |-- track01.wav (or .flac)"
echo "          |-- track02.wav (or .flac)"
echo "          |-- cover.jpg or artwork.jpg (optional)"
echo ""
echo "Note: Embedded .flac artwork and track ordering will be detected automatically"
echo ""
for i in {10..1}; do
    echo -ne "\rInsert USB drive containing music... ($i) [Enter to continue] "
    read -t 1 -n 1 key 2>/dev/null
    if [ $? -eq 0 ]; then
        break
    fi
done
echo "Scanning for USB drives..."
echo ""
# Capture mount output to check for success
mount_output=$(/usr/local/bin/mount-usb 2>&1)
mount_exit_code=$?

# Extract USB volume name from mount output
if echo "$mount_output" | grep -q "Successfully mounted"; then
    usb_name=$(echo "$mount_output" | grep "Successfully mounted" | sed 's/.*at \/media\/[^\/]*\///' | sed 's/.*✓ Successfully mounted.*at.*\/media\/[^\/]*\///')
    echo -e "${GREEN}Found USB volume '$usb_name'${RESET}"
elif [ $mount_exit_code -eq 0 ]; then
    echo -e "${GREEN}USB drive mounted${RESET}"
else
    echo "• No USB drives found"
fi
echo ""
for i in {5..1}; do
    echo -ne "\rUSB setup complete... ($i) [Enter to continue] "
    read -t 1 -n 1 key 2>/dev/null
    if [ $? -eq 0 ]; then
        break
    fi
done

# Initialize Bluetooth headtracker (if available)
clear
echo -e "${YELLOW}=== Headtracker Setup ===${RESET}"
echo ""
for i in {10..1}; do
    echo -ne "\rConnect compatible Bluetooth Headtracker... ($i) [Enter to continue] "
    read -t 1 -n 1 key 2>/dev/null
    if [ $? -eq 0 ]; then
        break
    fi
done
sleep 2  # Give Bluetooth controller time to initialize

# Show spinner while scanning
echo ""
{
    while true; do
        echo -ne "\rScanning for headtracker... | "
        sleep 0.1
        echo -ne "\rScanning for headtracker... / "
        sleep 0.1
        echo -ne "\rScanning for headtracker... - "
        sleep 0.1
        echo -ne "\rScanning for headtracker... \\ "
        sleep 0.1
    done
} &
spinner_pid=$!

ht_output=$(/usr/local/bin/ble-ht.sh 2>&1)
kill $spinner_pid 2>/dev/null
echo -e "\rScanning for headtracker... complete."
ht_exit_code=$?

echo ""
if echo "$ht_output" | grep -q "PAIRED_AND_CONNECTED"; then
    echo -e "${GREEN}Headtracker [HT] found and connected${RESET}"
elif echo "$ht_output" | grep -q "PAIRING_FAILED"; then
    if echo "$ht_output" | grep -q "not found"; then
        echo "• No compatible headtracker [HT] found"
    else
        echo "• Headtracker [HT] found but pairing failed"
    fi
else
    echo "• Headtracker scan completed (no device found)"
fi
echo ""

# Pause to show headtracker result
for i in {10..1}; do
    echo -ne "\rContinuing in $i... (Press Enter to continue) "
    read -t 1 -n 1 key 2>/dev/null
    if [ $? -eq 0 ]; then
        break
    fi
done

clear

# Launch SuperCollider application
echo -e "${YELLOW}=== Launching Player Application ===${RESET}"
cd /home/$USER/UHJ-Pi

# Give user a moment to see the message
sleep 2

# Launch SuperCollider and capture any errors
echo ""
echo "Launching SuperCollider..."
if ! sclang supercollider/app/UHJ_v26_PLAYER_SF.scd; then
    clear
    echo "=== APPLICATION LAUNCH FAILED ==="
    echo ""
    echo "❌ The Player application failed to start."
    echo ""
    echo "Possible causes:"
    echo ""
    echo "  • Audio system not ready"
    echo ""
    echo "  • Missing audio device"
    echo ""
    echo "  • SuperCollider configuration issue"
    echo ""
    echo "  • File permission problem"
    echo ""
    echo ""
    echo "Try these steps:"
    echo ""
    echo "  1. Check your USB audio device is connected"
    echo ""
    echo "  2. Make sure no other audio applications are running"
    echo ""
    echo "  3. Try running the startup script again"
    echo ""
    echo "If the problem persists, check the audio device"
    echo ""
    echo "connections and restart the Raspberry Pi."
    echo ""
    for i in {10..1}; do
        echo -ne "\rExiting in $i... (Press Enter to continue) "
        read -t 1 -n 1 key 2>/dev/null
        if [ $? -eq 0 ]; then
            break
        fi
    done
    exit 1
fi
