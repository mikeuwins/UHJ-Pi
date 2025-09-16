#!/usr/bin/env bash

# USB Mounting Script for UHJ-Pi
# Dynamically detects and mounts USB drives with proper user permissions

echo "Scanning for USB drives..."

# Get current user info (use SUDO_USER if running with sudo, otherwise whoami)
USER_NAME=${SUDO_USER:-$(whoami)}
USER_UID=$(id -u $USER_NAME)
USER_GID=$(id -g $USER_NAME)

# Find USB block devices (use --raw to avoid tree characters)
USB_DEVICES=$(lsblk --raw -no NAME,TYPE,MOUNTPOINT | grep -E "sd[a-z][0-9]*.*part" | grep -v "/")

if [ -z "$USB_DEVICES" ]; then
    echo "No unmounted USB drives found."
    echo "Please insert a USB drive and try again."
    exit 1
fi

echo "Found USB devices:"
echo "$USB_DEVICES"
echo ""

# Process each USB device
mounted_count=0
while IFS= read -r device_info; do
    device_name=$(echo "$device_info" | awk '{print $1}')
    device_path="/dev/$device_name"
    
    echo "Attempting to mount $device_path..."
    
    # Create mount point
    mount_point="/media/$USER_NAME/$device_name"
    sudo mkdir -p "$mount_point"
    
    # Detect filesystem type and mount with appropriate options
    fs_type=$(sudo blkid -o value -s TYPE "$device_path" 2>/dev/null || echo "unknown")
    echo "Detected filesystem: $fs_type"
    
    mount_options=""
    if [ "$fs_type" = "vfat" ] || [ "$fs_type" = "msdos" ]; then
        # VFAT/FAT32 needs different options
        mount_options="uid=$USER_UID,gid=$USER_GID,umask=000,utf8"
    else
        # Other filesystems (ext4, ntfs, etc.)
        mount_options="uid=$USER_UID,gid=$USER_GID,fmask=022,dmask=022"
    fi
    
    # Mount with proper permissions
    if sudo mount -o "$mount_options" "$device_path" "$mount_point" 2>/dev/null; then
        echo "✓ Successfully mounted $device_path at $mount_point"
        
        # Make sure the user owns the mount point
        sudo chown $USER_NAME:$USER_NAME "$mount_point"
        echo "✓ Set ownership to $USER_NAME"
        
        # List contents to verify
        echo "Contents:"
        ls -la "$mount_point" | head -5
        echo "..."
        
        mounted_count=$((mounted_count + 1))
        
    else
        echo "❌ Failed to mount $device_path"
        echo "   Trying alternative mount options..."
        
        # Try without user options for VFAT
        if [ "$fs_type" = "vfat" ] || [ "$fs_type" = "msdos" ]; then
            if sudo mount "$device_path" "$mount_point" 2>/dev/null; then
                echo "✓ Successfully mounted $device_path at $mount_point (default options)"
                sudo chown $USER_NAME:$USER_NAME "$mount_point"
                mounted_count=$((mounted_count + 1))
            else
                echo "❌ Failed to mount $device_path even with default options"
                sudo rmdir "$mount_point" 2>/dev/null || true
            fi
        else
            sudo rmdir "$mount_point" 2>/dev/null || true
        fi
    fi
done <<< "$USB_DEVICES"

echo ""
if [ $mounted_count -eq 0 ]; then
    echo "❌ No USB drives were successfully mounted."
    exit 1
else
    echo "✓ Successfully mounted $mounted_count USB drive(s)."
fi

echo ""
echo "USB mounting complete. Check /media/$USER_NAME/ for mounted drives."
