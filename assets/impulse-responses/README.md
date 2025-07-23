# Impulse Response Library

This folder contains impulse responses for the UHJ-Pi system's convolution-based spatialization.

## Folder Structure

### `a-format/`
- **Purpose**: Raw A-format ambisonic impulse responses
- **Format**: 4-channel WAV files (A-format: W, X, Y, Z)
- **Source**: Downloads from OpenAIR, ATK examples, etc.
- **Usage**: Convert to B-format using ATK tools

### `b-format/`
- **Purpose**: B-format ambisonic impulse responses (ready to use)
- **Format**: 4-channel WAV files (B-format: W, X, Y, Z)
- **Source**: Direct downloads, converted from A-format
- **Usage**: Direct loading into PSEUDO encoder convolution

### `converted/`
- **Purpose**: A-format to B-format converted files
- **Format**: 4-channel WAV files (B-format: W, X, Y, Z)
- **Source**: Converted from a-format/ using ATK
- **Usage**: Alternative to b-format/ for converted files

## File Naming Convention

### B-Format Files
- `W_omnidirectional.wav` - Omnidirectional component
- `X_frontback.wav` - Front-back component
- `Y_leftright.wav` - Left-right component
- `Z_updown.wav` - Up-down component

### Room-Specific Files
- `room_name_W.wav`, `room_name_X.wav`, etc.
- Example: `concert_hall_W.wav`, `church_X.wav`

## Usage in UHJ-Pi System

The PSEUDO encoder loads these files for convolution spatialization:

### Multichannel B-format (Recommended)
```supercollider
// Load single 4-channel B-format file (WXYZ order)
~spatialIRBuffer = Buffer.read(s, "assets/impulse-responses/b-format/room_name_44k.wav");
```

### Separate Files (Legacy)
```supercollider
~spatialIRs = [
    Buffer.read(s, "assets/impulse-responses/b-format/W_omnidirectional.wav"),
    Buffer.read(s, "assets/impulse-responses/b-format/X_frontback.wav"),
    Buffer.read(s, "assets/impulse-responses/b-format/Y_leftright.wav"),
    Buffer.read(s, "assets/impulse-responses/b-format/Z_updown.wav")
];
```

## Sources for Impulse Responses

1. **OpenAIR Database**: http://www.openairlib.net/
2. **ATK Examples**: Ambisonic Toolkit installation
3. **University Research**: York, IRCAM, etc.
4. **Custom Recordings**: B-format microphone measurements

## Conversion Tools

### OpenAIR 96kHz to 44.1kHz Conversion

**Prerequisites:**
- Install ffmpeg: `sudo apt-get install ffmpeg`

**Method 1: Command Line (Recommended)**
```bash
# Convert 96kHz B-format IR to 44.1kHz
ffmpeg -i input_96k.wav -ar 44100 output_44k.wav

# Example for OpenAIR files
ffmpeg -i ~/Downloads/openair_irs/rir_jack_lyons_lp1_96k.wav -ar 44100 assets/impulse-responses/b-format/rir_jack_lyons_lp1_96k_44k.wav
```

**Method 2: SuperCollider Analysis**
Use `analyze_bformat_channels.scd` to verify channel order and analyze B-format characteristics.

### A-format to B-format Conversion
Use ATK (Ambisonic Toolkit) to convert A-format to B-format:

```supercollider
// Convert A-format to B-format
var aFormat = Buffer.read(s, "a-format/room_name.wav");
var bFormat = FoaTransform.ar(aFormat, 'a2b');
bFormat.write("converted/room_name_bformat.wav");
```

### Channel Order Verification
Most modern B-format IRs use WXYZ order (Furse-Malham, ATK standard):
- Channel 0: W (omnidirectional)
- Channel 1: X (front-back)  
- Channel 2: Y (left-right)
- Channel 3: Z (up-down)

**Verifying Channel Order with sox:**
```bash
# Install sox if not available
sudo apt-get install sox

# Extract individual channels
sox input_4ch.wav -c 1 ch0.wav remix 1
sox input_4ch.wav -c 1 ch1.wav remix 2
sox input_4ch.wav -c 1 ch2.wav remix 3
sox input_4ch.wav -c 1 ch3.wav remix 4

# Analyze RMS levels (energy)
sox ch0.wav -n stat 2>&1 | grep "RMS"
sox ch1.wav -n stat 2>&1 | grep "RMS"
sox ch2.wav -n stat 2>&1 | grep "RMS"
sox ch3.wav -n stat 2>&1 | grep "RMS"

# Clean up
rm ch0.wav ch1.wav ch2.wav ch3.wav
```

**Expected Energy Pattern for WXYZ:**
- **W (Channel 0)**: Highest RMS - omnidirectional captures most energy
- **X (Channel 1)**: Second highest RMS - front-back directional
- **Y (Channel 2)**: Lower RMS - left-right directional  
- **Z (Channel 3)**: Lowest RMS - up-down directional

**Alternative: SuperCollider Analysis**
Use `analyze_bformat_channels.scd` for detailed channel analysis including energy, peak, and DC offset measurements.

## Troubleshooting

### Memory Issues with Large Files
If SuperCollider scripts fail with "Killed" errors when processing large IRs:
1. **Use ffmpeg command line** (recommended for large files)
2. **Reduce chunk size** in chunked processing scripts
3. **Use smaller test files** first to verify the process

### File Format Issues
- Ensure files are valid WAV format
- Check channel count (should be 4 for B-format)
- Verify sample rate (44.1kHz for UHJ-Pi system)
- Use `file filename.wav` to check file properties 