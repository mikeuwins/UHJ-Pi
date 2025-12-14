#!/bin/bash
# Mac Mini Fan Control Script
# This script sets the fan to manual control and disables thermal management

# Wait for system to fully boot
sleep 10

# Disable thermal zone 0 (prevents automatic fan control)
echo disabled | tee /sys/class/thermal/thermal_zone0/mode

# Enable manual fan control
echo 1 | tee /sys/devices/platform/applesmc.768/fan1_manual

# Set fan speed (adjust RPM as needed: 1500=very quiet, 2000=quiet, 2500=moderate)
echo 2000 | tee /sys/devices/platform/applesmc.768/fan1_output

echo "Fan control set to manual mode at 2000 RPM"

