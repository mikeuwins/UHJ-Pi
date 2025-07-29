#!/bin/bash
# Simple UHJ-Pi autoboot for EGLFS
# This script auto-logs in and launches the UHJ Ambisonic System

# Wait for system to be ready
sleep 5

# Check for headtracker (optional - uncomment and add your device address)
# bluetoothctl info [YOUR_DEVICE_ADDRESS] >/dev/null 2>&1

# Launch UHJ app
cd ~/UHJ-Pi
sclang supercollider/app/UHJ_v19.scd 