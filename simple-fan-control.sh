#!/bin/bash
echo "Mac Mini Fan Control"
echo "==================="
echo "1. Set to 1500 RPM (Quiet)"
echo "2. Set to 2000 RPM (Normal)"
echo "3. Set to 3000 RPM (Cooling)"
echo "4. Check status"
echo "5. Exit"
echo ""
read -p "Choose option (1-5): " choice

case $choice in
    1) echo "Setting fan to 1500 RPM..."; echo disabled | sudo tee /sys/class/thermal/thermal_zone0/mode > /dev/null; echo 1 | sudo tee /sys/devices/platform/applesmc.768/fan1_manual > /dev/null; echo 1500 | sudo tee /sys/devices/platform/applesmc.768/fan1_output > /dev/null; echo "Done!" ;;
    2) echo "Setting fan to 2000 RPM..."; echo disabled | sudo tee /sys/class/thermal/thermal_zone0/mode > /dev/null; echo 1 | sudo tee /sys/devices/platform/applesmc.768/fan1_manual > /dev/null; echo 2000 | sudo tee /sys/devices/platform/applesmc.768/fan1_output > /dev/null; echo "Done!" ;;
    3) echo "Setting fan to 3000 RPM..."; echo disabled | sudo tee /sys/class/thermal/thermal_zone0/mode > /dev/null; echo 1 | sudo tee /sys/devices/platform/applesmc.768/fan1_manual > /dev/null; echo 3000 | sudo tee /sys/devices/platform/applesmc.768/fan1_output > /dev/null; echo "Done!" ;;
    4) 
        echo "=== Fan Status ==="
        echo "Current fan speed: $(cat /sys/devices/platform/applesmc.768/fan1_output) RPM"
        echo "Manual mode: $(cat /sys/devices/platform/applesmc.768/fan1_manual)"
        echo ""
        echo "=== Temperature ==="
        sensors | grep -E "(Package id 0|Core [0-9])" | head -5
        echo ""
        read -p "Press Enter to continue..."
        ;;
    5) exit 0 ;;
    *) echo "Invalid option" ;;
esac
