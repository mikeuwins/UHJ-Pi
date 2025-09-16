#!/bin/bash
# Mac Mini Fan Control GUI
# Simple dialog-based fan control

# Function to set fan speed
set_fan_speed() {
    local speed=$1
    echo disabled | sudo tee /sys/class/thermal/thermal_zone0/mode > /dev/null
    echo 1 | sudo tee /sys/devices/platform/applesmc.768/fan1_manual > /dev/null
    echo $speed | sudo tee /sys/devices/platform/applesmc.768/fan1_output > /dev/null
    echo "Fan set to $speed RPM"
}

# Function to check current status
check_status() {
    local current_speed=$(cat /sys/devices/platform/applesmc.768/fan1_output)
    local manual_mode=$(cat /sys/devices/platform/applesmc.768/fan1_manual)
    
    # Get temperature info
    local temp_info=$(sensors | grep -E "(Package id 0|Core [0-9])" | head -5)
    
    echo "=== Fan Status ==="
    echo "Current Fan Speed: $current_speed RPM"
    echo "Manual Mode: $([ $manual_mode -eq 1 ] && echo "ON" || echo "OFF")"
    echo ""
    echo "=== Temperature ==="
    echo "$temp_info"
}

# Function to check fan speed only (for preset confirmations)
check_fan_speed() {
    local current_speed=$(cat /sys/devices/platform/applesmc.768/fan1_output)
    echo "Fan Speed: $current_speed RPM"
}

# Main menu loop
while true; do
    choice=$(whiptail --title "Mac Mini Fan Control" --menu "Select an option:

" 16 50 9 \
        "1" "Check Status" \
        "2" "Quiet Mode (1500 RPM)" \
        "3" "Normal Mode (2500 RPM)" \
        "4" "Cooling Mode (3500 RPM)" \
        "5" "Power Mode (5400 RPM)" \
        "6" "Uber Mode (7200 RPM)" \
        "7" "Manually Set Fan Speed" \
        "8" "Reset to Auto Control" \
        "9" "Exit" 3>&1 1>&2 2>&3)
    
    # Handle cancel/escape key
    if [ $? -ne 0 ]; then
        clear
        exit 0
    fi
    
    case $choice in
        1)
            status=$(check_status)
            whiptail --msgbox "$status" 15 70
            ;;
        2)
            set_fan_speed 1500
            whiptail --msgbox "Quiet Mode: Fan set to 1500 RPM" 8 60
            ;;
        3)
            set_fan_speed 2500
            current_speed=$(cat /sys/devices/platform/applesmc.768/fan1_output)
            whiptail --msgbox "Normal Mode: Fan set to $current_speed RPM" 8 60
            ;;
        4)
            set_fan_speed 3500
            current_speed=$(cat /sys/devices/platform/applesmc.768/fan1_output)
            whiptail --msgbox "Cooling Mode: Fan set to $current_speed RPM" 8 60
            ;;
        5)
            set_fan_speed 5400
            current_speed=$(cat /sys/devices/platform/applesmc.768/fan1_output)
            whiptail --msgbox "Power Mode: Fan set to $current_speed RPM" 8 60
            ;;
        6)
            set_fan_speed 7200
            current_speed=$(cat /sys/devices/platform/applesmc.768/fan1_output)
            whiptail --msgbox "Uber Mode: Fan set to $current_speed RPM" 8 60
            ;;
        7)
            speed=$(whiptail --inputbox "Enter fan speed (RPM):\n\nRange: 1000-7200 RPM" 10 50 "" 3>&1 1>&2 2>&3)
            if [ $? -eq 0 ]; then
                set_fan_speed $speed
            fi
            ;;
        8)
            echo enabled | sudo tee /sys/class/thermal/thermal_zone0/mode > /dev/null
            echo 0 | sudo tee /sys/devices/platform/applesmc.768/fan1_manual > /dev/null
            whiptail --msgbox "Reset to Auto Control" 8 60
            ;;
        9)
            clear
            exit 0
            ;;
    esac
done
