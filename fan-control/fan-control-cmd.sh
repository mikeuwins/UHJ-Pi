#!/bin/bash
# Mac Mini Fan Control - Command Line
# Usage: ./fan-control-cmd.sh [speed] or ./fan-control-cmd.sh status

# Function to set fan speed
set_fan_speed() {
    local speed=$1
    echo disabled | sudo tee /sys/class/thermal/thermal_zone0/mode > /dev/null
    echo 1 | sudo tee /sys/devices/platform/applesmc.768/fan1_manual > /dev/null
    echo $speed | sudo tee /sys/devices/platform/applesmc.768/fan1_output > /dev/null
    echo "Fan set to $speed RPM"
}

# Function to check status
check_status() {
    local current_speed=$(cat /sys/devices/platform/applesmc.768/fan1_output)
    local manual_mode=$(cat /sys/devices/platform/applesmc.768/fan1_manual)
    local temp=$(sensors | grep "Package id 0" | awk '{print $4}' | cut -d'+' -f2 | cut -d'°' -f1)
    
    echo "=== Mac Mini Fan Status ==="
    echo "Current Fan Speed: $current_speed RPM"
    echo "Manual Mode: $([ $manual_mode -eq 1 ] && echo "ON" || echo "OFF")"
    echo "CPU Temperature: ${temp}°C"
    echo ""
    echo "Quick commands:"
    echo "  ./fan-control-cmd.sh 1500  # Quiet mode"
    echo "  ./fan-control-cmd.sh 2000  # Normal mode"
    echo "  ./fan-control-cmd.sh 3000  # Cooling mode"
    echo "  ./fan-control-cmd.sh status # Check status"
}

# Main logic
if [ "$1" = "status" ]; then
    check_status
elif [ -n "$1" ] && [ "$1" -eq "$1" ] 2>/dev/null; then
    set_fan_speed $1
else
    echo "Usage: $0 [RPM] or $0 status"
    echo "Examples:"
    echo "  $0 1500    # Set to 1500 RPM (quiet)"
    echo "  $0 2000    # Set to 2000 RPM (normal)"
    echo "  $0 3000    # Set to 3000 RPM (cooling)"
    echo "  $0 status  # Check current status"
fi

