# SuperCollider ATK Extensions and Modifications

This document describes all modifications and extensions made to the Ambisonic Toolkit (ATK) for SuperCollider in this project.

## Table of Contents

1. [Core ATK Modifications](#core-atk-modifications)
2. [Custom Extensions](#custom-extensions)
3. [Installation Instructions](#installation-instructions)
4. [Dependencies](#dependencies)
5. [File Locations](#file-locations)

---

## Core ATK Modifications

### 1. `AtkKernelConv` - PHJ Encoder Support

**File:** `~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/ATK.sc`

**Modification:** Extended `AtkKernelConv.ar` to handle PHJ encoder's 4-lane interleaved kernel format.

**What Changed:**
- Added detection for PHJ encoder kernels (4 inputs × 4 outputs)
- Implements complex convolution for PHJ's interleaved format:
  - WX lanes (channels 0,1) → W and X outputs
  - YZ lanes (channels 2,3) → Y and Z outputs
- Maintains backward compatibility with all other encoders (UHJ, Super, Spread, Diffuse)

**Why:** PHJ encoder uses a unique 4-lane interleaved kernel format that requires special handling. The standard `Convolution2.ar` approach doesn't correctly process this format, causing incorrect Z-channel output from UHJ inputs.

**Compatibility:** ✅ Safe - Only affects PHJ encoder (uniquely identified by 4×4 kernel shape). All other encoders use unchanged path.

---

### 2. `FoaDecoderMatrix.new5_2` - 5.1.2 Decoder Method

**File:** `~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc`

**Modification:** Added `*new5_2` class method to `FoaDecoderMatrix` class.

**What Changed:**
- Added `FoaDecoderMatrix.new5_2` method (similar to existing `new5_0`)
- Supports 8-channel 5.1.2 speaker layout (FL, FR, C, RL, RR, LFE, TFL, TFR)
- Loads decoder matrices from files or uses hardcoded fallback
- Handles height channels with full periphonic decoding (W, X, Y, Z)
- Includes elevation-dependent scaling for height channels

**Usage:**
```supercollider
decoder = FoaDecoderMatrix.new5_2(
    mode: \equal,              // \equal, \focus, or \four
    heightElevation: 45,       // Height speaker elevation in degrees
    outputLayout: \uhjpi       // Layout identifier
);
```

**Why:** Provides proper 5.1.2 decoder support following ATK patterns, matching the JSFX implementation.

**Compatibility:** ✅ Safe - New method, doesn't affect existing functionality.

---

## Custom Extensions

All custom extensions are located in: `supercollider/extensions/`

### 1. `FoaDimension`

**Location:** `supercollider/extensions/FoaDimension/`

**Purpose:** Implements the "Dimension" effect (forward preference) for Ambisonic signals.

**Key Features:**
- Enhances perceived width of sound field
- Psychoacoustic processing (initially disabled in this implementation)
- 4-stage allpass filter implementation

**Usage:**
```supercollider
dimensioned = FoaDimension.ar(
    bformat,
    forward: 0.5,    // Forward preference amount (0-1)
    width: 0.5       // Width control (0-1)
);
```

---

### 2. `FoaZSynthesis`

**Location:** `supercollider/extensions/FoaZSynthesis/`

**Purpose:** Synthesizes Z (height) channel from X/Y components with decorrelation and ambience.

**Key Features:**
- Decorrelates X/Y signals to create height information
- Includes Schroeder reverb (simplified to 2 comb + 1 allpass per channel)
- Auto-compression/limiting to prevent distortion

**Usage:**
```supercollider
zsynthesized = FoaZSynthesis.ar(
    bformat,
    height: 0.5,         // Height amount (0-1)
    delay: 0.01,         // Delay time (seconds)
    reverb: 0.3,         // Reverb amount (0-1)
    size: 0.5,           // Reverb size (0-1)
    spread: 0.5          // Spread (0-1)
);
```

---

### 3. `FoaVHAP`

**Location:** `supercollider/extensions/FoaVHAP/`

**Purpose:** VHAP (Virtual Height Ambisonic Processing) transform for height channel processing.

**Key Features:**
- Multiple implementations: Simple, ATK-style, and full versions
- Trim and morph controls
- Solo mode for height-only output

**Usage:**
```supercollider
vhap = FoaVHAP.ar(
    bformat,
    trim: 0,        // Trim in dB
    morph: 1,       // Morph amount (0-1)
    solo: 0         // Solo mode (0=normal, 1=height only)
);
```

---

### 4. `MaplinMatrix` / `MaplinSM333`

**Location:** `supercollider/extensions/MaplinMatrix/` and `supercollider/extensions/MaplinSM333/`

**Purpose:** Maplin matrix encoder for stereo-to-quad encoding.

**Key Features:**
- Surround, effect, and delay controls
- Layout switching (square, narrow, wide)
- Based on Maplin SM333 hardware encoder

**Usage:**
```supercollider
encoder = MaplinMatrix.new(
    surround: 0.5,   // Surround amount (0-1)
    effect: 0.5,     // Effect amount (0-1)
    delay: 0.01      // Delay time (seconds)
);
```

---

### 5. `PHJEncoder` Extension

**Location:** `supercollider/extensions/PHJEncoder/`

**Purpose:** Extension for PHJ (Periphonic UHJ) encoding support.

**Note:** This extension originally duplicated `FoaEncoderKernel.newPHJ`, but the main ATK library now includes this method. The extension may be redundant but kept for compatibility.

**Status:** ⚠️ May be deprecated - Check if main ATK includes `newPHJ` before using.

---

### 6. `Foa512Matrix`

**Location:** `supercollider/extensions/Foa512Matrix/`

**Purpose:** 5.1.2 decoder matrix implementation.

**Status:** ⚠️ **DEPRECATED** - Functionality moved to `FoaDecoderMatrix.new5_2` in main ATK.

**Note:** This class was created initially but later replaced by the `new5_2` method in `FoaDecoderMatrix`. The extension may still exist but should not be used.

---

### 7. `ServerMeter2` / `SFPlayerMeter`

**Location:** `supercollider/extensions/ServerMeter2/` and `supercollider/extensions/SFPlayerMeter/`

**Purpose:** Audio metering and visualization classes.

**Usage:**
```supercollider
ServerMeter2View.new(s, window, bounds);
SFPlayerMeterView.new(buffer, window, bounds);
```

---

### 8. `Knob360`

**Location:** `supercollider/extensions/Knob360/`

**Purpose:** 360-degree rotary knob GUI component.

**Note:** Requires Qt support - may not work on headless systems.

---

## Installation Instructions

### Prerequisites

1. **SuperCollider** installed and configured
2. **ATK Quark** installed via Quarks:
   ```supercollider
   Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");
   ```
3. **ATK Assets** downloaded:
   ```supercollider
   Atk.downloadKernels();
   Atk.downloadMatrices();
   Atk.downloadSounds();
   ```
4. **AmbiVerbSC** Quark:
   ```supercollider
   Quarks.install("https://github.com/JamesWenlock/AmbiVerbSC");
   ```

### Step 1: Apply Core ATK Modifications

**⚠️ IMPORTANT:** These modifications change core ATK files. Backup original files first!

1. **Backup original ATK files:**
   ```bash
   cp ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/ATK.sc \
      ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/ATK.sc.backup
   
   cp ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc \
      ~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc.backup
   ```

2. **Apply modifications:**
   - Copy modified `ATK.sc` to replace the original
   - Copy modified `FoaMatrix.sc` to replace the original
   
   Or use the provided patch files (if available).

3. **Recompile SuperCollider class library:**
   - Open SuperCollider IDE
   - Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
   - Select "Recompile Class Library"

### Step 2: Install Custom Extensions

1. **Copy extensions to SuperCollider Extensions directory:**
   ```bash
   cd ~/UHJ-Pi/supercollider/extensions
   cp -r FoaDimension ~/.local/share/SuperCollider/Extensions/
   cp -r FoaZSynthesis ~/.local/share/SuperCollider/Extensions/
   cp -r FoaVHAP ~/.local/share/SuperCollider/Extensions/
   cp -r MaplinMatrix ~/.local/share/SuperCollider/Extensions/
   cp -r MaplinSM333 ~/.local/share/SuperCollider/Extensions/
   cp -r ServerMeter2 ~/.local/share/SuperCollider/Extensions/
   cp -r SFPlayerMeter ~/.local/share/SuperCollider/Extensions/
   ```

2. **Recompile Class Library** (as above)

### Step 3: Verify Installation

Test in SuperCollider:

```supercollider
// Test PHJ encoder
encoder = FoaEncoderKernel.newPHJ;
encoder.kind; // Should return: phj

// Test 5.1.2 decoder
decoder = FoaDecoderMatrix.new5_2;
decoder.class; // Should return: FoaDecoderMatrix

// Test custom extensions
FoaDimension; // Should not error
FoaZSynthesis; // Should not error
FoaVHAP; // Should not error
MaplinMatrix; // Should not error
```

---

## Dependencies

### Required Quarks

1. **ATK (Ambisonic Toolkit)**
   - Repository: `https://github.com/ambisonictoolkit/atk-sc3.git`
   - Version: Latest from GitHub

2. **AmbiVerbSC**
   - Repository: `https://github.com/JamesWenlock/AmbiVerbSC`
   - Purpose: Spatial reverb for Ambisonic signals

### Required ATK Assets

1. **Kernels:**
   - FOA encoders: `uhj/`, `phj/`, `super/`
   - FOA decoders: `uhj/`, `phj/`
   - Location: `~/.local/share/ATK/kernels/FOA/`

2. **Matrices:**
   - 5.1.2 decoder matrices: `decoders/5_1_2/`
   - Location: `~/.local/share/ATK/matrices/FOA/`

3. **Sounds:**
   - Optional test files
   - Location: `~/.local/share/ATK/sounds/`

---

## File Locations

### Core ATK Files (Modified)

- `~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/ATK.sc`
- `~/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc`

### Custom Extensions

- `~/.local/share/SuperCollider/Extensions/FoaDimension/`
- `~/.local/share/SuperCollider/Extensions/FoaZSynthesis/`
- `~/.local/share/SuperCollider/Extensions/FoaVHAP/`
- `~/.local/share/SuperCollider/Extensions/MaplinMatrix/`
- `~/.local/share/SuperCollider/Extensions/MaplinSM333/`
- `~/.local/share/SuperCollider/Extensions/ServerMeter2/`
- `~/.local/share/SuperCollider/Extensions/SFPlayerMeter/`

### ATK Assets

- Kernels: `~/.local/share/ATK/kernels/`
- Matrices: `~/.local/share/ATK/matrices/`
- Sounds: `~/.local/share/ATK/sounds/`

---

## Troubleshooting

### "Message 'new5_2' not understood"

**Cause:** Class library not recompiled after modification.

**Solution:** Recompile SuperCollider class library (Ctrl+Shift+P / Cmd+Shift+P).

### "PHJ encoder produces Z output from UHJ input"

**Cause:** `AtkKernelConv` modification not applied or class library not recompiled.

**Solution:** 
1. Verify `ATK.sc` contains PHJ detection code
2. Recompile class library
3. Restart SuperCollider

### "Extension class not found"

**Cause:** Extension not copied to Extensions directory.

**Solution:** Verify extensions are in `~/.local/share/SuperCollider/Extensions/` and recompile.

---

## Version History

- **2024-11-04**: Initial documentation
  - Added PHJ encoder support to `AtkKernelConv`
  - Added `FoaDecoderMatrix.new5_2` method
  - Documented all custom extensions

---

## License

These modifications extend the ATK library, which is licensed under GPL v3. Custom extensions follow the same license unless otherwise specified.

---

## Support

For issues or questions:
1. Check this documentation
2. Verify file locations and installations
3. Check SuperCollider post window for errors
4. Review ATK documentation: http://ambisonictoolkit.net/

