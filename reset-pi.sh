#!/bin/bash
set -e
echo "🧹 UHJ-Pi Complete System Reset"
echo "================================"
echo "This will perform a COMPLETE system reset:"
echo "  - Remove ALL user data and applications"
echo "  - Clean package system and remove non-essential packages"
echo "  - Reset all configurations to defaults"
echo "  - Clear all logs and temporary files"
echo ""
echo "Username: $USER"
echo ""

echo "Starting complete system reset..."

# Remove all user data and reset to clean state
echo "Removing all user data..."
sudo rm -rf /home/$USER/*
sudo rm -rf /home/$USER/.* 2>/dev/null || true

# Reset package cache and remove installed packages
echo "Cleaning package system..."
sudo apt-get clean
sudo apt-get autoremove --purge -y
sudo apt-get autoclean

# Clear logs
echo "Clearing logs..."
sudo journalctl --vacuum-time=1s
sudo rm -rf /var/log/*

echo "Reset complete! You can now clone fresh with: git clone https://github.com/mikeuwins/UHJ-Pi.git"