#!/bin/bash

# Identify Behringer UFO202 vs UCA202 devices
# Uses USB port information to distinguish between identical USB Codec devices

echo "Identifying Behringer USB Codec devices..."
echo "=========================================="
echo ""

# Get detailed USB information
echo "USB Device Information:"
echo "----------------------"
lsusb -v 2>/dev/null | grep -A 20 -B 5 "USB Codec" | grep -E "(Bus|Device|idVendor|idProduct|bcdDevice|iProduct|iSerial)" | head -20

echo ""
echo "ALSA Device Information:"
echo "-----------------------"
aplay -l

echo ""
echo "USB Port Mapping:"
echo "----------------"
# Get USB port information
for bus in /sys/bus/usb/devices/usb*; do
    if [ -d "$bus" ]; then
        bus_num=$(basename "$bus" | sed 's/usb//')
        for device in $bus/*; do
            if [ -d "$device" ] && [ -f "$device/idVendor" ] && [ -f "$device/idProduct" ]; then
                vendor=$(cat "$device/idVendor")
                product=$(cat "$device/idProduct")
                if [ "$vendor" = "1397" ]; then
                    port=$(basename "$device")
                    echo "Bus $bus_num, Device $port: Vendor $vendor, Product $product"
                    if [ -f "$device/product" ]; then
                        echo "  Product: $(cat "$device/product")"
                    fi
                    if [ -f "$device/serial" ]; then
                        echo "  Serial: $(cat "$device/serial")"
                    fi
                    echo ""
                fi
            fi
        done
    fi
done

echo "ALSA Card Details:"
echo "-----------------"
# Get ALSA card details with USB information
for card in /proc/asound/card*; do
    if [ -d "$card" ]; then
        card_num=$(basename "$card" | sed 's/card//')
        if [ -f "$card/usbid" ]; then
            usbid=$(cat "$card/usbid")
            echo "Card $card_num: USB ID $usbid"
            if [ -f "$card/usbdev" ]; then
                usbdev=$(cat "$card/usbdev")
                echo "  USB Device: $usbdev"
            fi
        fi
    fi
done

echo ""
echo "Recommendation:"
echo "==============="
echo "1. Connect devices to different USB ports"
echo "2. Note the USB port numbers from the output above"
echo "3. Use the USB port information to create persistent device mapping"
echo ""
echo "To create persistent mapping, you can:"
echo "- Use udev rules with USB port information"
echo "- Use ALSA device names with USB port numbers"
echo "- Label devices physically and use consistent USB ports" 