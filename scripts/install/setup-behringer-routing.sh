#!/bin/bash

# Behringer UFO202 + UCA202 Routing Setup
# This script sets up routing between UFO202 (input) and both UFO202 + UCA202 (output)

echo "Setting up Behringer UFO202 + UCA202 routing..."

# Wait for JACK to be running
while ! jack_control status | grep -q "started"; do
    echo "Waiting for JACK to start..."
    sleep 1
done

echo "JACK is running, setting up routing..."

# Get device names
UFO_CARD=$(aplay -l | grep -i "ufo202" | head -1 | sed 's/.*card \([0-9]*\).*/\1/')
UCA_CARD=$(aplay -l | grep -i "uca202" | head -1 | sed 's/.*card \([0-9]*\).*/\1/')

if [ -z "$UFO_CARD" ] || [ -z "$UCA_CARD" ]; then
    echo "Error: Could not find UFO202 or UCA202 devices"
    exit 1
fi

echo "UFO202 card: $UFO_CARD"
echo "UCA202 card: $UCA_CARD"

# Create ALSA multi-device for output
cat > /tmp/behringer_output.conf << EOF
pcm.behringer_multi {
    type multi
    slaves.a.pcm "hw:$UFO_CARD,0"
    slaves.b.pcm "hw:$UCA_CARD,0"
    bindings.0.slave a
    bindings.0.channel 0
    bindings.1.slave a
    bindings.1.channel 1
    bindings.2.slave b
    bindings.2.channel 0
    bindings.3.slave b
    bindings.3.channel 1
}
EOF

# Load the configuration
alsactl restore /tmp/behringer_output.conf 2>/dev/null || true

# Set up JACK connections
# Clear any existing connections first
jack_disconnect "system:capture_1" "SuperCollider:in_1" 2>/dev/null || true
jack_disconnect "system:capture_2" "SuperCollider:in_2" 2>/dev/null || true
jack_disconnect "uca_line:capture_1" "SuperCollider:in_3" 2>/dev/null || true
jack_disconnect "uca_line:capture_2" "SuperCollider:in_4" 2>/dev/null || true

# Input connections:
# UCA222 line inputs to channels 1 & 2 (SuperCollider in_1, in_2)
jack_connect "uca_line:capture_1" "SuperCollider:in_1"
jack_connect "uca_line:capture_2" "SuperCollider:in_2"

# UFO202 phono inputs to channels 3 & 4 (SuperCollider in_3, in_4)
jack_connect "system:capture_1" "SuperCollider:in_3"
jack_connect "system:capture_2" "SuperCollider:in_4"

# Output connections:
# UFO202 outputs (channels 1-2)
jack_connect "SuperCollider:out_1" "system:playback_1"
jack_connect "SuperCollider:out_2" "system:playback_2"

# UCA202 outputs (channels 3-4) - if available
if jack_lsp | grep -q "uca_out:playback_1"; then
    jack_connect "SuperCollider:out_3" "uca_out:playback_1"
    jack_connect "SuperCollider:out_4" "uca_out:playback_2"
fi

echo "Behringer routing setup complete!"
echo "Input: UCA222 line (channels 1-2) + UFO202 phono (channels 3-4)"
echo "Output: UFO202 (channels 1-2) + UCA202 (channels 3-4)" 