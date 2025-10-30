# ATK MaplinSM333 (FOA) — REAPER JSFX Plugin

**Version:** 2.0  
**Author:** Michael Uwins (with ChatGPT)  
**Date:** 2025

---

## Overview

`ATK MaplinSM333 (FOA)` is a REAPER JSFX plugin that emulates the classic Maplin SM-333 surround processor within a First-Order Ambisonic (FOA) workflow. Unlike traditional implementations that process stereo signals, this plugin operates entirely in B-format (WXYZ), making it ideal for integration into ambisonic production pipelines.

### Key Features

- **FOA-Native Operation**: Processes B-format audio with full decode/encode integration
- **Dual Source Modes**: Optimized processing for stereo and spatial (surround) sources
- **Classic Maplin Effect**: Delay, high-pass filtering, and all-pass phase shifting
- **Preserves Localization**: Clean spatial steering without crossfeed degradation
- **Rear Solo Monitoring**: Audition rear channels independently post-encode

---

## Processing Architecture

```
Input: FOA B-Format (W, X, Y, Z)
        ↓
    Decode to Quad (LF, RF, RL, RR)
        ↓
  Fronts: Passthrough (LF, RF unchanged)
  Rears:  Maplin Processing Only
        ↓
    Encode to FOA B-Format
        ↓
Output: FOA B-Format (W', X', Y', Z')
```

### Front Channel Processing

Front channels (LF, RF) remain **dry** and pass through unchanged. They serve as the spatial reference for the Maplin effect on the rears.

### Rear Channel Processing

Rear channels (RL, RR) are synthesized from the front channels using two modes:

#### **Stereo Mode** (for stereo sources like UHJ)
- **RL**: Primary signal from LF (0.707×) + 20% L−R difference crossfeed
- **RR**: Primary signal from RF (0.707×) + 20% R−L difference crossfeed
- **HPF**: 800 Hz (classic Maplin)
- **Boost**: 1.8× per channel

#### **Spatial Mode** (for surround/B-format content)
- **RL**: Direct steering from LF (no crossfeed)
- **RR**: Direct steering from RF (no crossfeed)
- **HPF**: 1200 Hz (reduces smearing on spatial sources)
- **Boost**: 1.8× per channel

Both modes apply:
1. **User-defined delay** (5–50 ms, adjustable)
2. **High-pass filter** (frequency set by mode)
3. **All-pass phase shift** (single-stage, coefficient 0.2)
4. **Scaled by Effect Level** (0–100%)
5. **Scaled by Surround Level** (0–100%)

---

## Controls

| Slider | Range | Default | Description |
|--------|-------|---------|-------------|
| **Surround Level (%)** | 0–100 | 80% | Rear dry/wet. 0 = rears off; 100 = full effect |
| **Effect Level (%)** | 0–100 | 80% | Intensity of Maplin processing (delay, HPF, phase) |
| **Delay (ms)** | 5–50 | 25 ms | Short delay on effect path |
| **Source Type** | Stereo / Spatial | Stereo | Selects processing mode and HPF |
| **Rear Solo** | Off / On | Off | Mutes fronts, forces rears to full effect |

---

## Usage Guide

### 1. **Insertion in REAPER**

Insert the plugin on a track or bus that carries FOA B-format audio:

```
Track/Bus → ATK MaplinSM333 (FOA) → (further FOA processing) → Decoder
```

### 2. **Source Type Selection**

- **Stereo**: Use for stereo sources (UHJ, standard stereo files)
  - Applies 20% crossfeed for width
  - HPF at 800 Hz
  - Recommended for traditional stereo material
  
- **Spatial**: Use for surround/ambisonic sources (B-format, PHJ, etc.)
  - Pure steering (LF→RL, RF→RR)
  - HPF at 1200 Hz
  - Better for solo monitoring
  - Prevents localization smearing

### 3. **Effect Adjustment**

1. **Surround Level**: Start at 80%, adjust to taste
   - Lower for subtle effect, higher for more rear presence
   - 0% = no rear channels in output
   
2. **Effect Level**: Start at 80%, adjust for intensity
   - Controls delay, HPF, and phase effect strength
   - 100% = full Maplin character
   
3. **Delay**: Start at 25 ms, fine-tune for timing
   - Too short: less spacious, more focused
   - Too long: can cause echoes or phase issues
   - Typical range: 20–35 ms

### 4. **Monitoring**

- **Normal mode**: Full mix with fronts and rears
- **Rear Solo**: Audition only the synthesized rear channels
  - Useful for verifying effect and checking for artifacts
  - In Spatial mode, should retain full width
  - In Stereo mode, may sound narrow (by design)

### 5. **Optimization Tips**

- **Avoid excessive Effect Level** (>90%) on dense material
- **Increase Delay** for larger room impressions
- **Use Spatial mode** when monitoring in surround
- **Gate low settings**: Combined effect <5% automatically mutes rears

---

## Technical Details

### Decode/Encode

The plugin uses orthonormal FOA decode/encode:

- **Decode**: `Speaker = 0.707×W + X×cos(az) + Y×sin(az)`
- **Encode**: `W = 0.5×(LF+RF+RL+RR)`, `X/Y` recomputed from quad

Speaker azimuths (deg): LF=45, RF=-45, RL=135, RR=-135

### Filters

- **HPF**: One-pole IIR, `y[n] = b0×x[n] + b1×x[n-1] + a1×y[n-1]`
- **Coefficients**: `a = exp(-2π×fc/sr)`, `b0 = (1+a)/2`, `b1 = -b0`

### All-Pass

Single-stage all-pass for phase shift:
- `y[n] = 0.2×x[n] + x[n-1] - 0.2×y[n-1]`
- Adds ~25 ms of phase delay without amplitude change

### Delay

Linear interpolation delay line (power-of-two buffer):
- Range: 5–50 ms
- Sample-accurate to within buffer size
- No feedback (not a reverb)

---

## Compatibility

- **REAPER**: 6.0+
- **Sample Rates**: 44.1 kHz, 48 kHz, 88.2 kHz, 96 kHz
- **Latency**: Minimal (dependent on delay setting)
- **CPU**: Low (~0.5% per instance on modern systems)

---

## Comparison with SuperCollider MaplinMatrix

The SuperCollider `MaplinMatrix` class is a **standalone stereo-to-quad processor** without B-format integration. It features:

- **Circuit-accurate emulation**: Multi-stage all-pass, band splitting, BBD noise
- **Stereo input**: Left/Right in, Quad out
- **Direct quad output**: Returns [FL, FR, RL, RR] array

The REAPER plugin is **FOA-aware** and designed for B-format pipelines:

- **B-format I/O**: WXYZ in and out
- **Integrated decode/encode**: Seamless FOA workflow
- **Simplified processing**: Focus on real-time performance
- **Dual modes**: Optimized for stereo and spatial sources

See `ATK-MaplinSM333-FOA-Comparison.md` for detailed differences.

---

## License

This plugin is part of the UHJ-Pi project. See project LICENSE for details.

---

## Credits

- **Original Circuit**: Maplin SM-333 stereo-to-quad processor
- **Theory**: Based on examination of physical unit circuitry
- **Implementation**: Adapted for FOA by Michael Uwins with ChatGPT
- **Ambisonic Framework**: Built on ATK (Ambisonic Toolkit) standards

---

## Changelog

### Version 2.0 (2025-01-XX)
- Removed Bypass slider (REAPER provides native bypass)
- Fixed stereo mode steering for proper localization
- Eliminated crosstalk rejection (caused smearing in spatial mode)
- Improved rear solo monitoring
- Simplified UI to 5 controls

### Version 1.x (Development)
- Initial implementation
- Source type modes
- Basic FOA integration

---

## Support

For questions, bugs, or feature requests, see project documentation at:
`docs/vhap-periphoic-flow-diagram.md`

