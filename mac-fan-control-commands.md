# Mac Mini Fan Control Commands

## Quick Reference

### Check Current Status
```bash
# Check fan speed
cat /sys/devices/platform/applesmc.768/fan1_output

# Check temperature
sensors

# Check if macfanctld is running
sudo systemctl status macfanctld
```

### Manual Fan Control
```bash
# Stop automatic fan control
sudo systemctl stop macfanctld

# Enable manual mode
echo 1 | sudo tee /sys/devices/platform/applesmc.768/fan1_manual

# Set fan speed (RPM)
echo 1500 | sudo tee /sys/devices/platform/applesmc.768/fan1_output

# Check new speed
cat /sys/devices/platform/applesmc.768/fan1_output
```

### Recommended Fan Speeds
- **1200 RPM** - Very quiet (monitor temperature)
- **1500 RPM** - Quiet, good balance
- **2000 RPM** - Moderate noise, good cooling
- **3000+ RPM** - Loud but maximum cooling

### Permanent Setup
```bash
# Disable automatic fan control on boot
sudo systemctl disable macfanctld

# Re-enable automatic control if needed
sudo systemctl enable macfanctld
sudo systemctl start macfanctld
```

### Emergency Commands
```bash
# Reset to automatic control
sudo systemctl start macfanctld
echo 0 | sudo tee /sys/devices/platform/applesmc.768/fan1_manual

# Check all fan-related files
ls -la /sys/devices/platform/applesmc.768/fan*
```

## GUI Control
```bash
# Run the dialog-based GUI (recommended)
./fan-control-gui.sh

# Or simple text menu
./simple-fan-control.sh
```

## Scripts Available
- `fan-control-gui.sh` - Dialog-based GUI (best option)
- `simple-fan-control.sh` - Simple text menu
- `fan-control-cmd.sh` - Command line version

## Notes
- Mac mini 6,2 typically has one fan
- Monitor temperature with `sensors` when using manual control
- 67°C is a safe operating temperature
- Fan speed resets on reboot unless system service is enabled
