# ATK MaplinSM333 FOA vs SuperCollider MaplinMatrix — Comparison

**Date:** 2025  
**Context:** Architectural and implementation differences between the REAPER JSFX FOA wrapper and the original SuperCollider stereo-to-quad processor.

---

## Summary

| Aspect | SuperCollider MaplinMatrix | REAPER ATK MaplinSM333 (FOA) |
|--------|---------------------------|------------------------------|
| **Interface** | Stereo-to-Quad | FOA-to-FOA (B-format) |
| **Input** | `[leftIn, rightIn]` (2 ch) | `[W, X, Y, Z]` (4 ch B-format) |
| **Output** | `[FL, FR, RL, RR]` (4 ch quad) | `[W', X', Y', Z']` (4 ch B-format) |
| **Dependency** | Standalone processor | Requires decode/encode |
| **Complexity** | Circuit-accurate emulation | Simplified for performance |
| **Platform** | SuperCollider | REAPER JSFX |
| **Use Case** | App-level quad generation | Effect insert in B-format chain |

---

## SuperCollider: MaplinMatrix

### Architecture

```supercollider
// In UHJ_v27 app:
stereoIn = [left, right];
maplinQuad = MaplinMatrix.ar(
    stereoIn[0], stereoIn[1],
    surroundLevel: maplinSurround,
    effectLevel: maplinEffect,
    delayTime: maplinDelay,
    active: maplinActive
);
// Returns: [FL, FR, RL, RR]
encode = FoaEncode.ar(maplinQuad, encoder);
```

**Flow:** Stereo → MaplinMatrix → Quad → FoaEncode → B-format

### Implementation Details

**File:** `supercollider/extensions/MaplinMatrix/classes/MaplinMatrix.sc`

**Key Features:**

1. **Circuit-Accurate Processing**
   - Thermal noise injection (`WhiteNoise.ar(0.00001) * 0.1`)
   - Bandwidth limiting (`LPF.ar(20000Hz)`)
   - Op-amp saturation modeling (`tanh`)
   - BBD (Bucket Brigade Delay) noise (`WhiteNoise.ar(0.0003)`)
   - LFNoise modulation on delay

2. **Multi-Stage Phase Shifting**
   ```supercollider
   phaseDiff = AllpassN.ar(phaseDiff, 0.01, 0.0015, 0.7);
   phaseDiff = AllpassN.ar(phaseDiff, 0.01, 0.0033, 0.7);
   phaseDiff = AllpassN.ar(phaseDiff, 0.01, 0.0072, 0.7);
   phaseDiff = AllpassN.ar(phaseDiff, 0.01, 0.0156, 0.7);
   ```

3. **Band Splitting**
   - Low band: `LPF.ar(phaseDiff, 800)` with 22 ms delay
   - Mid band: `BPF.ar(phaseDiff, 2000, 1.5)` with 18 ms delay
   - High band: `HPF.ar(phaseDiff, 4000)` with 12 ms delay
   - Combined with 0.6× scaling

4. **Rear Channels**
   ```supercollider
   rearLeft  = (processedDiff * -1.8 * effectLevel) + (sum * 0.2);
   rearRight = (processedDiff *  1.8 * effectLevel) + (sum * 0.2);
   ```

5. **Final Saturation**
   - All channels: `(dry * 0.9) + (dry.tanh * 0.1)`

6. **Level Matching**
   - Surround level with 2.2× boost: `rear * surroundLevel * 2.2`

**Controls:**
- `surroundLevel` (0–1): Rear channel amplitude
- `effectLevel` (0–1): Amount of Maplin processing
- `delayTime` (0–1): Maps to 5–50 ms
- `active` (0/1): Bypass blend

---

## REAPER: ATK MaplinSM333 (FOA)

### Architecture

```jsfx
// In REAPER JSFX:
// Input: W, X, Y, Z (B-format)
(LF, RF, RL, RR) = decode_FOA(W, X, Y, Z);
(LFp, RFp, RL_eff, RR_eff) = maplin_process(LF, RF);
(W', X', Y', Z') = encode_FOA(LFp, RFp, RL_eff, RR_eff);
```

**Flow:** B-format → Decode → Quad → Maplin Processing → Encode → B-format

### Implementation Details

**File:** `/home/michael-uwins/.config/REAPER/Effects/ATK/FOA/Transform/MaplinSM333 FOA`

**Key Features:**

1. **FOA Integration**
   - Orthonormal decode/encode for seamless B-format workflow
   - Speaker azimuths: LF=45°, RF=-45°, RL=135°, RR=-135°
   - Fronts pass through dry
   - Rears synthesized from fronts via Maplin-style processing

2. **Simplified Processing**
   - One-pole HPF (800/1200 Hz, based on mode)
   - Single-stage all-pass (coefficient 0.2)
   - Simple delay line (5–50 ms, no modulation)
   - No thermal/BBD noise
   - No bandwidth limiting
   - No explicit saturation (relies on JSFX soft clipping)

3. **Dual Modes**

   **Stereo Mode:**
   - RL from LF (0.707×) + 20% L−R crossfeed
   - RR from RF (0.707×) + 20% R−L crossfeed
   - HPF at 800 Hz

   **Spatial Mode:**
   - RL from LF (steering)
   - RR from RF (steering)
   - HPF at 1200 Hz

4. **Rear Channels**
   ```jsfx
   RL_eff = effect * (1.8 * Ldel_hp);
   RR_eff = effect * (1.8 * Rdel_hp);
   // Applied per mode
   ```

5. **Levels**
   - Surround and Effect scale independently
   - Gate at <5% combined effect
   - No final boost (rely on user trim)

**Controls:**
- **Surround Level** (0–100%): Rear dry/wet
- **Effect Level** (0–100%): Processing intensity
- **Delay** (5–50 ms): Single delay time
- **Source Type** (Stereo/Spatial): Mode selector
- **Rear Solo** (On/Off): Monitoring toggle

---

## Key Differences

### 1. **Processing Complexity**

| Feature | MaplinMatrix | ATK MaplinSM333 FOA |
|---------|--------------|---------------------|
| Phase shift stages | 4× all-pass | 1× all-pass |
| Band splitting | Yes (3 bands) | No (simple HPF) |
| Noise injection | Yes (thermal + BBD) | No |
| Saturation | Yes (tanh) | No |
| BBD modulation | Yes (LFNoise) | No |
| 80 Hz HPF | Yes | No |
| Sum feed to fronts | Yes (0.1×) | No |
| Sum feed to rears | Yes (0.2×) | No |

**Rationale:** REAPER plugin prioritizes real-time performance and CPU efficiency. Circuit-accurate modeling adds complexity that may not be perceivable in typical use.

### 2. **Source Handling**

**MaplinMatrix:**
- Processes stereo (L/R) signals
- Assumes L−R difference creates directional cues
- Classic ±1.8 polarity assignment

**ATK MaplinSM333 FOA:**
- Processes quad signals (LF, RF, RL, RR from decode)
- Dual modes: Classic L−R (stereo) and pure steering (spatial)
- Spatial mode avoids crossfeed that degrades localization

**Rationale:** B-format sources may already have spatial information that L−R mixing would corrupt. Dual modes allow optimal processing per source type.

### 3. **Encoder Integration**

**MaplinMatrix:**
- Separate encoder step: `FoaEncode.ar(maplinQuad, encoder)`
- Quad intermediate format
- User must handle encoding

**ATK MaplinSM333 FOA:**
- Integrated decode/encode
- No intermediate format exposure
- Transparent in B-format chain

**Rationale:** User experience in REAPER: insert on B-format track, no manual encode/decode steps.

### 4. **Level Management**

**MaplinMatrix:**
- Internal 2.2× boost on rears
- Saturation to prevent clipping
- Bypass blend preserves fronts

**ATK MaplinSM333 FOA:**
- No automatic boost
- Rely on soft clipping or downstream limiting
- Bypass handled by REAPER (no plugin bypass)

**Rationale:** REAPER users have access to trim/gain plugins. Let them control final levels.

### 5. **Use Cases**

**MaplinMatrix:**
- Standalone quad generation from stereo
- Analog modeling and preservation of Maplin character
- Testing and analysis (circuit behavior)

**ATK MaplinSM333 FOA:**
- Effect insert in existing B-format pipeline
- Real-time performance (DJ/live)
- Simplification-focused processing

---

## Compatibility Considerations

### Porting from SuperCollider to REAPER

If you have existing SuperCollider workflows using `MaplinMatrix.ar`:

1. **Stereo Sources:**
   - Move `MaplinMatrix.ar` to quad generation step
   - Replace with UHJ/Super/PHJ encoder if needed
   - Use REAPER plugin on resulting B-format for further processing

2. **Timbre Match:**
   - REAPER plugin will sound **brighter** (no 80 Hz HPF)
   - REAPER plugin will sound **cleaner** (no noise, no saturation)
   - REAPER plugin will sound **less colored** (no multi-stage all-pass)
   - Expected difference: ~2–3 dB in character

3. **Controls:**
   - `surroundLevel` maps to "Surround Level %"
   - `effectLevel` maps to "Effect Level %"
   - `delayTime.linlin(0,1,5,50)` maps to "Delay (ms)"
   - `active` controlled by REAPER bypass

### Porting from REAPER to SuperCollider

If you have REAPER workflows using ATK MaplinSM333 (FOA):

1. **Source Type:**
   - Stereo mode ≈ classic MaplinMatrix
   - Spatial mode ≈ new behavior (not in original)

2. **Integration:**
   ```supercollider
   // REAPER-style wrapper:
   ~maplinFOA = { |signal|
       var quad = FoaDecode.ar(signal, maplinDecoder);
       var processed = MaplinMatrix.ar(quad[0], quad[1], ...);
       var encoded = FoaEncode.ar(processed, encoder);
       encoded;
   };
   ```

3. **Timbre Match:**
   - May need to add HPF, noise, or saturation for closer match
   - Consider creating a hybrid implementation

---

## Recommendations

### When to Use SuperCollider MaplinMatrix

- **Offline rendering** where accuracy > speed
- **Research/analysis** of Maplin circuit behavior
- **Stereo-to-quad** conversion without B-format
- **Emulation preservation** of vintage character

### When to Use REAPER ATK MaplinSM333 (FOA)

- **Live performance** or real-time processing
- **B-format pipelines** with existing FOA workflow
- **CPU-limited** environments
- **Modern, clean** tonal character preferred
- **Spatial sources** (B-format, PHJ, etc.)

---

## Future Work

1. **Convergence Options:**
   - Add noise/saturation controls to REAPER plugin
   - Add multi-stage all-pass option
   - Add 80 Hz HPF toggle
   - Parameterize circuit modeling depth

2. **Testing:**
   - A/B comparison of both implementations
   - Blind listening tests for perceptual differences
   - Spectral analysis of outputs

3. **Hybrid:**
   - Create "Enhanced" version with optional circuit modeling
   - Preset system: "Clean", "Classic", "Circuit-Accurate"

---

## References

- **SuperCollider Implementation:** `supercollider/extensions/MaplinMatrix/classes/MaplinMatrix.sc`
- **REAPER Implementation:** `/home/michael-uwins/.config/REAPER/Effects/ATK/FOA/Transform/MaplinSM333 FOA`
- **Usage in v27:** `supercollider/app/UHJ_v27_PLAYER_SF.scd` (lines 1304–1316)
- **Original Circuit:** Maplin SM-333 stereo-to-quad processor (physical unit examination)

---

## Appendix: Circuit Details

### Original Maplin SM-333 Circuit (Physical Analysis)

1. **L−R Matrix:** Differential extraction from L/R
2. **Phase Shifter:** Multi-stage all-pass chain
3. **HPF:** ~80 Hz to remove LF artifacts
4. **Band Splitters:** LPF 800 Hz, BPF 2 kHz, HPF 4 kHz
5. **Delays:** Different per band (22, 18, 12 ms typical)
6. **Polarity Inversion:** R−L to rear left, L−R to rear right
7. **Sum Mix:** Small amount of sum to all channels (0.1 front, 0.2 rear)
8. **BBD Noise:** Characteristic analog delay noise

**Verification:** Examination of physical unit circuit board, component values, and signal routing.



