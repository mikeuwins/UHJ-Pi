#!/usr/bin/env bash

CONFIG_FILE="$HOME/.uhj-player-audio.conf"
clear
echo "Starting UHJ-Pi Player..."

# Kill any existing JACK processes
killall jackd >/dev/null 2>&1 || true

# Simple JACK configuration for file playback
echo "Starting JACK server for file playback..."
jackd -P75 -d alsa -r 44100 -p 1024 -n 3 -S > /dev/null 2>&1 &

# Wait for JACK to start
sleep 2

# Check if JACK started successfully
if ! pgrep jackd > /dev/null; then
    echo "ERROR: JACK failed to start"
    exit 1
fi

echo "✓ JACK started successfully"

# Show available JACK ports
echo "Available JACK ports:"
jack_lsp 2>/dev/null || echo "jack_lsp not available"

echo ""
echo "Starting SuperCollider Player..."
echo ""

# Start SuperCollider with the PLAYER app
sclang supercollider/app/UHJ_v23_PLAYER.scd
