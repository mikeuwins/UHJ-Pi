#!/bin/bash
# Script to disable Apple Thunderbolt Display Audio by unbinding USB devices

echo "Disabling Apple Thunderbolt Display Audio devices..."

# Unbind the Apple Thunderbolt Display Audio devices
# Both monitors show as ID 05ac:1107 Apple, Inc. Thunderbolt Display Audio

for device_path in /sys/bus/usb/devices/*/; do
    if [ -f "$device_path/idVendor" ] && [ -f "$device_path/idProduct" ]; then
        vendor=$(cat "$device_path/idVendor")
        product=$(cat "$device_path/idProduct")
        
        if [ "$vendor" = "05ac" ] && [ "$product" = "1107" ]; then
            device_name=$(basename "$device_path")
            echo "Found Apple Thunderbolt Display Audio: $device_name"
            
            # Unbind from USB audio driver
            if [ -f "$device_path/driver/unbind" ]; then
                echo "$device_name" > "$device_path/driver/unbind" 2>/dev/null && \
                echo "Unbound $device_name from driver" || \
                echo "Failed to unbind $device_name"
            fi
        fi
    fi
done

sleep 2
echo "Current audio devices after disable:"
aplay -l

