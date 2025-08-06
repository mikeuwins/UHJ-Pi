#!/bin/bash

# Behringer UCA202/UFO202 Audio Setup Script
# Sets up 4in/4out JACK configuration with zita bridges
# for SuperCollider Ambisonic processing

echo "===== Behringer Audio Setup ====="
echo "Setting up UFO202 (phono) + UCA202 (line) for SuperCollider..."

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies
echo "Checking dependencies..."
if ! command_exists jackd; then
    echo "ERROR: JACK not installed. Run: sudo apt install jackd2"
    exit 1
fi



# Stop any existing audio processes
echo "Stopping existing audio processes..."
pkill jackd 2>/dev/null
pkill zita-a2j 2>/dev/null
pkill zita-j2a 2>/dev/null
pkill qjackctl 2>/dev/null
sleep 2

# Detect Behringer devices by USB controller
echo "Detecting Behringer devices..."

# Simple method: extract card number from the line that contains the USB controller
UCA_CARD=""
UFO_CARD=""

# Parse /proc/asound/cards line by line
while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*([0-9]+)[[:space:]]*\[ ]]; then
        current_card="${BASH_REMATCH[1]}"
    elif [[ $line =~ 1d\.7 ]]; then
        UCA_CARD="$current_card"
    elif [[ $line =~ 1a\.7 ]]; then
        UFO_CARD="$current_card"
    fi
done < /proc/asound/cards

if [ -z "$UCA_CARD" ] || [ -z "$UFO_CARD" ]; then
    echo "ERROR: Could not detect both Behringer devices"
    echo "Make sure both UFO202 and UCA202 are connected"
    echo "Current audio cards:"
    cat /proc/asound/cards
    exit 1
fi

echo "Detected devices:"
echo "  UCA202 (Line Input) = Card $UCA_CARD (USB controller 0000:00:1d.7)"
echo "  UFO202 (Phono Input) = Card $UFO_CARD (USB controller 0000:00:1a.7)"

# Start JACK on UCA202 (line device) as master
echo "Starting JACK server on UCA202 (Card $UCA_CARD) at 44100 Hz..."
jackd -d alsa -d hw:$UCA_CARD -r 44100 -p 256 -n 2 > /tmp/jack.log 2>&1 &
JACK_PID=$!

# Wait for JACK to initialize
sleep 3

# Check if JACK started successfully
if ! ps -p $JACK_PID > /dev/null; then
    echo "ERROR: JACK failed to start. Check /tmp/jack.log"
    exit 1
fi

echo "JACK server started successfully (PID: $JACK_PID)"

# Start zita bridges for UFO202
echo "Starting zita bridges for UFO202 (Card $UFO_CARD)..."

# Bridge UFO202 inputs to JACK (phono inputs)
echo "Starting zita-a2j for UFO202 inputs..."
zita-a2j -j ufo_phono -d hw:$UFO_CARD -r 44100 -p 256 -c 2 > /tmp/zita-a2j.log 2>&1 &
ZITA_A2J_PID=$!

# Bridge JACK outputs to UFO202 (additional outputs)
echo "Starting zita-j2a for UFO202 outputs..."
zita-j2a -j ufo_out -d hw:$UFO_CARD -r 44100 -p 256 -c 2 > /tmp/zita-j2a.log 2>&1 &
ZITA_J2A_PID=$!

# Wait for zita bridges to initialize
sleep 2

# Check if zita processes started successfully
if ! ps -p $ZITA_A2J_PID > /dev/null; then
    echo "ERROR: zita-a2j failed to start. Check /tmp/zita-a2j.log"
    exit 1
fi

if ! ps -p $ZITA_J2A_PID > /dev/null; then
    echo "ERROR: zita-j2a failed to start. Check /tmp/zita-j2a.log"
    exit 1
fi

echo "Zita bridges started successfully"



# Wait a moment for everything to sync
sleep 2



# Verify JACK ports
echo "Verifying JACK configuration..."
if command_exists jack_lsp; then
    PORTS=$(jack_lsp | wc -l)
    echo "Available JACK ports:"
    jack_lsp | sort

    if [ $PORTS -ge 8 ]; then
        echo "✅ SUCCESS: All ports available ($PORTS total)"
    else
        echo "⚠️  WARNING: Expected 8+ ports, found $PORTS"
    fi
else
    echo "jack_lsp not available, cannot verify ports"
fi

# Display configuration summary
echo ""
echo "===== Setup Complete ====="
echo "Audio Configuration:"
echo "  Sample Rate: 44100 Hz"
echo "  Buffer Size: 256 samples"
echo "  JACK Master: UCA202 (Card $UCA_CARD) - Line inputs"
echo "  Zita Bridge: UFO202 (Card $UFO_CARD) - Phono inputs"
echo ""
echo "JACK Port Mapping:"
echo "  LINE INPUTS (UCA202):"
echo "    system:capture_1 (UCA202 Left) → jack_quad:in_1"
echo "    system:capture_2 (UCA202 Right) → jack_quad:in_2"
echo "  PHONO INPUTS (UFO202):"
echo "    ufo_phono:capture_1 (UFO202 Left) → jack_quad:in_3"
echo "    ufo_phono:capture_2 (UFO202 Right) → jack_quad:in_4"
echo "  QUAD OUTPUTS:"
echo "    system:playback_1 → system:playback_1 (UCA202 Left)"
echo "    system:playback_2 → system:playback_2 (UCA202 Right)"
echo "    system:playback_3 → ufo_out:playback_1 (UFO202 Left)"
echo "    system:playback_4 → ufo_out:playback_2 (UFO202 Right)"
echo ""
echo "SuperCollider Configuration:"
echo "  - LINE mode: Uses jack_quad:in_1-2 (UCA202 line inputs)"
echo "  - PHONO mode: Uses jack_quad:in_3-4 (UFO202 phono inputs)"
echo "  - Quad outputs: All 4 channels for ambisonic decoding"
echo ""
echo "Process IDs:"
echo "  JACK: $JACK_PID"
echo "  zita-a2j: $ZITA_A2J_PID"
echo "  zita-j2a: $ZITA_J2A_PID"
echo ""
echo "Log files:"
echo "  /tmp/jack.log"
echo "  /tmp/zita-a2j.log"
echo "  /tmp/zita-j2a.log"
echo ""
echo "To stop this setup: pkill jackd; pkill zita-a2j; pkill zita-j2a"
echo "Ready for SuperCollider!"
