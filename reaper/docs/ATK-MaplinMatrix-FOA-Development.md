# ATK MaplinMatrix (FOA) - Development Documentation

## Overview

The **ATK MaplinMatrix (FOA)** plugin is a circuit-accurate JSFX implementation of the SuperCollider `MaplinMatrix` class, adapted for B-format (FOA) audio workflows in REAPER.

## Rationale

The Maplin SM-333 was a vintage surround sound processor that used phase shifting and delayed high-frequency cross-feed to create a spatial effect. The SuperCollider implementation (`MaplinMatrix`) captures the circuit behavior, including:

- **Thermal noise**: Subtle random noise to simulate op-amp characteristics
- **Bandwidth limiting**: Frequency-dependent rolloff
- **Op-amp saturation**: Non-linear distortion via tanh approximation
- **Multi-stage all-pass**: Phase shifting for spatial effect
- **Band processing**: Frequency-dependent delays (LOW/MID/HIGH)
- **BBD delay**: Bucket-brigade delay with modulation for chorus-like effect
- **Final saturation**: Additional soft clipping

### Why FOA?

The plugin wraps the MaplinMatrix processing with FOA (B-format) decode/encode to integrate into B-format production pipelines. It:
1. Decodes B-format (WXYZ) to virtual quad speakers (front L/R)
2. Applies MaplinMatrix processing to create rear channels
3. Re-encodes the result back to B-format

This allows spatial audio workflows to benefit from the Maplin effect without leaving the B-format domain.

## Code Structure

### Header Section

```javascript
desc:ATK MaplinMatrix (FOA)
import ../../libraries/atk/atk.jsfx-inc
```

Standard JSFX header with FOA pin configuration.

### Controls

Four sliders match the SuperCollider implementation:
- **Surround Level**: Rear channel amplitude (0-100%, with 2.2× boost applied)
- **Effect Level**: Intensity of processed difference signal (0-100%)
- **BBD Delay**: Normalized delay (0-1 maps to 5-50ms)
- **Active**: Bypass control (0=Inactive, 1=Active)

### Initialization (@init)

**Decode Coefficients**: Pre-calculated cos/sin values for ±45° front speakers.

**Delay Buffers**: Six circular buffers at base slots 65536×1-6, each 1024 samples:
- `dlyBuf_LOW`, `dlyBuf_MID`, `dlyBuf_HIGH`: For band delays (22/18/12ms)
- `bbdL_BUF`, `bbdR_BUF`: For BBD delay processing

**Filter States**: Allocated at slots 65536×1030+ to avoid overlap with delay buffers. Each filter needs 2 floats (x1, y1) except the biquad BPF which needs 4 (x1, x2, y1, y2).

**Modulation**: Sine-based LFO (like REAPER Chorus) with separate phase accumulators for left/right.

**Coefficients**: Computed for 80Hz HPF, 800Hz LPF, 2kHz BPF, 4kHz HPF, 8kHz LPF, 20kHz LPF using one-pole or biquad methods.

**Delays**: Pre-calculated sample counts for LOW (22ms), MID (18ms), HIGH (12ms) bands.

### Signal Processing (@sample)

**1. Decode**: Extract L/R from FOA using orthonormal projection:
```javascript
L = kW*W + X*cos_LF + Y*sin_LF;
R = kW*W + X*cos_RF + Y*sin_RF;
```

**2. Input Processing**:
- Add thermal noise (simulates op-amp characteristics)
- Apply 0.7 gain (reduces level to prevent distortion)
- 20kHz LPF (bandwidth limiting)

**3. Matrix Processing**:
- Sum/diff matrix (L+R)/√2 and (L-R)/√2
- Apply tanh saturation (15% blend)

**4. Spatial Phase Shifting**:
- Four all-pass stages with coefficients [0.0015, 0.0033, 0.0072, 0.0156]
- This creates the signature Maplin phase effect

**5. Band Processing**:
- HPF at 80Hz
- Split into LOW (LPF 800Hz), MID (BPF 2kHz), HIGH (HPF 4kHz)
- Apply frequency-dependent delays
- Sum with 0.6 gain

**6. Output Matrix**:
- Front: `L + sum×0.1` (original signal plus small sum contribution)
- Rear: `processedDiff×±1.8×effect + sum×0.2` (processed diff dominates, plus sum contribution)

**7. BBD Processing**:
- Add noise
- 8kHz LPF
- Sine-based LFO modulation of delay time
- Apply delay via circular buffer

**8. Final Processing**:
- Soft tanh saturation (10% blend)
- Apply surround level with 2.2× boost
- Active/bypass blend: fronts use original L/R when inactive

**9. Encode**: Re-encode quad back to FOA using standard orthonormal formula.

## Key Implementation Details

### Modulation

The original SuperCollider uses `LFNoise2.kr()` (control rate). Initial implementation called `prng()` per sample, which caused static. Fixed by using a sine-based LFO (inspired by REAPER Chorus):

```javascript
rateadj = lfNoise_rate * 2 * $pi / srate;
lfNoise_L_mod = sin(lfNoise_L_phase += rateadj) * lfNoise_amount;
```

### Buffer Management

Critical to avoid overlaps:
- Delay buffers: slots 1-6 (each 1024 floats)
- Filter states: slots 1030-1057
- Proper memset initialization to prevent uninitialized noise

### Static Issue

Static was caused by multiple issues discovered during diagnostic testing:
1. **Buffer overlaps**: Fixed by proper slot allocation
2. **Missing saturation**: Front channels need final saturation to prevent clipping
3. **Per-sample prng()**: Replaced with sine LFO
4. **Variable overwrite**: Front channels were being overwritten before blend

Final fix required all four corrections to eliminate static completely.

### Level Behavior

The 0.7 input gain causes ~3dB reduction even when effect is off. This is circuit-accurate behavior from the Maplin hardware design.

## Testing Process

Diagnostic versioning was used to isolate the static issue:
- v3-v5: Progressive feature addition (no static)
- v6-v8: All-pass and band processing (no static)
- v9: BBD added (static appeared)
- v10-v11: Isolated to modulation
- v12: Fixed with proper saturation and variable management
- v18: Final fix with sine LFO modulation

## Compatibility

Matches SuperCollider `MaplinMatrix.ar` behavior for:
- Input gain: 0.7
- Op-amp saturation: 15%
- All-pass coefficients: [0.0015, 0.0033, 0.0072, 0.0156]
- Band delays: 22/18/12ms
- Rear boost: 2.2×
- Final saturation: 10%

## Differences from SuperCollider

1. **Modulation**: Sine LFO instead of LFNoise2.kr (same perceptual effect, no static)
2. **Tanh**: Polynomial approximation instead of native function
3. **Bypass**: Uses original L/R before processing (not after gain reduction)

## Future Improvements

- Optional makeup gain for level preservation
- Per-control modulation rates
- Band delay amount control
- Thermal noise amount control



