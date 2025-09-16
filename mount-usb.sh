#!/usr/bin/env bash

# USB Mounting Script for UHJ-Pi
# Dynamically detects and mounts USB drives with proper user permissions

echo "Scanning for USB drives..."

# Get current user info (use SUDO_USER if running with sudo, otherwise whoami)
USER_NAME=${SUDO_USER:-$(whoami)}
USER_UID=$(id -u $USER_NAME)
USER_GID=$(id -g $USER_NAME)

# Find USB block devices
USB_DEVICES=$(lsblk -no NAME,TYPE,MOUNTPOINT | grep -E "sd[a-z][0-9]*.*part" | grep -v "/")

if [ -z "$USB_DEVICES" ]; then
    echo "No unmounted USB drives found."
    echo "Please insert a USB drive and try again."
    exit 1
fi

echo "Found USB devices:"
echo "$USB_DEVICES"
echo ""

# Process each USB device
echo "$USB_DEVICES" | while read -r device_info; do
    device_name=$(echo "$device_info" | awk '{print $1}')
    device_path="/dev/$device_name"
    
    echo "Attempting to mount $device_path..."
    
    # Create mount point
    mount_point="/media/$USER_NAME/$device_name"
    sudo mkdir -p "$mount_point"
    
    # Mount with proper permissions
    if sudo mount -o uid=$USER_UID,gid=$USER_GID,fmask=022,dmask=022 "$device_path" "$mount_point"; then
        echo "✓ Successfully mounted $device_path at $mount_point"
        
        # Make sure the user owns the mount point
        sudo chown $USER_NAME:$USER_NAME "$mount_point"
        echo "✓ Set ownership to $USER_NAME"
        
        # List contents to verify
        echo "Contents:"
        ls -la "$mount_point" | head -5
        echo "..."
        
    else
        echo "❌ Failed to mount $device_path"
        # Clean up failed mount point
        sudo rmdir "$mount_point" 2>/dev/null || true
    fi
done

echo ""
echo "USB mounting complete. Check /media/$USER_NAME/ for mounted drives."
