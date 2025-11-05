# Developer Quick Reference: ATK Extensions

Quick reference guide for developers working with the ATK extensions in this project.

## Core ATK Modifications

### PHJ Encoder Support (`AtkKernelConv`)

**Location:** `ATK.sc` → `AtkKernelConv.ar`

**Detection:** `kernel.shape[0] == 4 && kernel.shape[1] == 4`

**How it works:**
- PHJ uses 4-lane interleaved kernels: `[WX_r, WX_i, YZ_r, YZ_i]` per input
- WX lanes (0,1) → W and X outputs
- YZ lanes (2,3) → Y and Z outputs
- Sums contributions from all inputs (L, R, T, Q)

**Testing:**
```supercollider
// Should produce Z=0 for UHJ input (L,R with T=0,Q=0)
encoder = FoaEncoderKernel.newPHJ;
in = [PlayBuf.ar(1, lBuf), PlayBuf.ar(1, rBuf), Silent.ar, Silent.ar];
bfmt = FoaEncode.ar(in, encoder);
bfmt[3].amp // Should be ~0 for UHJ input
```

---

### 5.1.2 Decoder (`FoaDecoderMatrix.new5_2`)

**Location:** `FoaMatrix.sc` → `FoaDecoderMatrix` class

**Method Signature:**
```supercollider
*new5_2 { |mode = \equal, heightElevation = 45, outputLayout = \uhjpi|
```

**Parameters:**
- `mode`: `\equal`, `\focus`, or `\four`
- `heightElevation`: Height speaker elevation in degrees (default: 45)
- `outputLayout`: Layout identifier (default: `\uhjpi`)

**Output Channels:** 8 channels
1. FL (Front Left)
2. FR (Front Right)
3. C (Center)
4. RL (Rear Left)
5. RR (Rear Right)
6. LFE (Low Frequency Effects - derived from FL+FR)
7. TFL (Top Front Left)
8. TFR (Top Front Right)

**Usage:**
```supercollider
decoder = FoaDecoderMatrix.new5_2(\equal, 45, \uhjpi);
decoded = FoaDecode.ar(bfmt, decoder);
Out.ar(0, decoded); // 8 channels
```

**Height Channel Processing:**
- Full periphonic decode (W, X, Y, Z)
- Z-scaling applied to X and Y contributions
- Elevation-dependent scaling

---

## Custom Extension Classes

### FoaDimension

**Purpose:** Forward preference / width enhancement

**Key Methods:**
```supercollider
FoaDimension.ar(bformat, forward: 0.5, width: 0.5)
```

**Implementation Notes:**
- Uses `AllpassN.ar` for 4-stage allpass
- Psychoacoustic shelves disabled in this implementation
- All outputs include `DC.ar(0)` to maintain audio-rate

---

### FoaZSynthesis

**Purpose:** Synthesize Z channel from X/Y with decorrelation

**Key Methods:**
```supercollider
FoaZSynthesis.ar(bformat, 
    height: 0.5,
    delay: 0.01,
    reverb: 0.3,
    size: 0.5,
    spread: 0.5
)
```

**Implementation Notes:**
- Simplified Schroeder reverb (2 comb + 1 allpass per channel)
- Auto-compression/limiting to prevent distortion
- Decorrelates X/Y signals for height synthesis

---

### FoaVHAP

**Purpose:** Virtual Height Ambisonic Processing

**Key Methods:**
```supercollider
FoaVHAP.ar(bformat, trim: 0, morph: 1, solo: 0)
```

**Implementation Notes:**
- Multiple implementations available (Simple, ATK-style)
- Solo mode switches to height-only output
- Trim in dB, morph for blending

---

### MaplinMatrix

**Purpose:** Stereo-to-quad Maplin encoder

**Key Methods:**
```supercollider
encoder = MaplinMatrix.new(
    surround: 0.5,
    effect: 0.5,
    delay: 0.01
);
```

**Implementation Notes:**
- Based on Maplin SM333 hardware
- Supports layout switching (square, narrow, wide)
- Separate surround, effect, and delay controls

---

## Common Patterns

### Kernel Encoder Usage

```supercollider
// Create encoder
encoder = FoaEncoderKernel.newPHJ; // or newUHJ, newSuper

// Encode
bfmt = FoaEncode.ar(inputChannels, encoder);

// Process
processed = FoaDimension.ar(bfmt);
// or
processed = FoaZSynthesis.ar(bfmt);

// Decode
decoder = FoaDecoderMatrix.new5_2;
output = FoaDecode.ar(processed, decoder);
```

### Matrix Encoder Usage

```supercollider
// Create encoder
encoder = MaplinMatrix.new(surround: 0.5);

// Encode (same as kernel)
bfmt = FoaEncode.ar(inputChannels, encoder);
```

### Testing PHJ Encoder

```supercollider
// Test with UHJ input (should produce Z=0)
s.boot;
b = Buffer.read(s, "/path/to/uhj/file.wav");
encoder = FoaEncoderKernel.newPHJ;

(
SynthDef(\testPHJ, {
    var in = PlayBuf.ar(2, b, loop: 1);
    var phj = [in[0], in[1], Silent.ar, Silent.ar]; // L, R, T=0, Q=0
    var bfmt = FoaEncode.ar(phj, encoder);
    // Monitor Z channel - should be silent for UHJ input
    Out.ar(0, [bfmt[3], bfmt[3]]); // Z channel to both outputs
}).play;
)
```

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

### Project Files
- Extensions source: `supercollider/extensions/`
- Patches: `scripts/patches/atk/`
- Documentation: `docs/`

---

## Debugging Tips

### Check if PHJ Support is Active

```supercollider
// Check AtkKernelConv code
AtkKernelConv.class.methods.select({ |m| m.name == 'ar' }).first.sourceCode.postln;
// Should contain "PHJ encoder uses 4-lane interleaved"
```

### Check if 5.1.2 Decoder Exists

```supercollider
FoaDecoderMatrix.respondsTo('new5_2'); // Should return true
```

### Verify Kernel Shapes

```supercollider
encoder = FoaEncoderKernel.newPHJ;
encoder.kernel.shape; // Should be [4, 4] for PHJ
```

### Test Encoder Output

```supercollider
// Create test signal
s.boot;
synth = {
    var sig = PinkNoise.ar(0.1);
    var encoder = FoaEncoderKernel.newPHJ;
    var in = [sig, sig, Silent.ar, Silent.ar]; // L, R, T=0, Q=0
    var bfmt = FoaEncode.ar(in, encoder);
    // Monitor Z - should be ~0 for this input
    Out.ar(0, [bfmt[3], bfmt[3]]);
}.play;

synth.free;
```

---

## Common Issues

### "Message 'new5_2' not understood"
- **Cause:** Class library not recompiled
- **Fix:** Recompile (Ctrl+Shift+P / Cmd+Shift+P)

### "PHJ produces Z from UHJ input"
- **Cause:** `AtkKernelConv` patch not applied
- **Fix:** Verify `ATK.sc` contains PHJ detection code

### "Extension class not found"
- **Cause:** Extension not in Extensions directory
- **Fix:** Copy extension to `~/.local/share/SuperCollider/Extensions/`

### "Convolution2 arg: 'framesize' has bad input"
- **Cause:** Kernel not loaded or buffer issue
- **Fix:** Ensure encoder kernels are properly loaded before use

---

## Integration with Install Scripts

The patch script `scripts/install/apply-atk-patches.sh` should be called after ATK installation:

```bash
# In installer script:
# 1. Install ATK
Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");

# 2. Apply patches
bash "$PROJECT_ROOT/scripts/install/apply-atk-patches.sh"

# 3. Recompile (user must do this manually in SC IDE)
```

---

## Version Compatibility

- **ATK Version:** Latest from GitHub (as of 2024-11-04)
- **SuperCollider:** 3.13+ (tested on 3.13.x)
- **Platform:** Linux (Raspberry Pi), macOS, Windows

---

## Contributing

When modifying core ATK files:
1. Always create backup before modifying
2. Test with all encoder types (UHJ, Super, PHJ)
3. Verify backward compatibility
4. Update this document if API changes
5. Create patch files for distribution

---

## See Also

- Full documentation: `docs/SUPERCOLLIDER_EXTENSIONS.md`
- ATK documentation: http://ambisonictoolkit.net/
- Project repository: (add your repo URL)

