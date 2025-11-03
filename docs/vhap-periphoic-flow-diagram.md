# VHAP Processing Flow via Periphonic Decode/Encode

## Proposed Flow in REAPER

```
┌─────────┐
│ UHJ L/R │ (stereo input, e.g., from files)
└────┬────┘
     │
     ▼
┌─────────────────────────────────────┐
│ UHJ Encoder                         │  UHJ L/R → B-Format W/X/Y/Z
│ (2 ch → 4 ch)                       │  ATK: anything to B-Format = Encoder
└────┬────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│ B-Format (W, X, Y, Z)               │
└────┬────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│ [Optional] Dimension (Width)        │  Forward Preference / Width injection
│ Transform                           │  (if needed, processes W/X/Y for width)
└────┬────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│ ATK FOA Decode Periphonic3D+        │  B-Format → Virtual Speaker Array
│ (Decoder)                            │  Output: Up to 32 channels (2 rings × 16 pairs)
│ Settings:                            │  - Number of speaker pairs (3-16)
│ - Orientation: Flat (regular quad)   │  - Orientation: Flat (matches encoder)
│ - Top ring elevation: 35° (default) │  - Top ring elevation: 35°
│ - Lower ring: ear level (0°)         │  - Lower ring: ear level
│ Channel Mapping:                     │  - Upper ring: ch 1-N (ant clockwise from front-left)
│                                      │  - Lower ring: ch N+1 to 2N
└────┬────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│ Virtual Speaker Array               │
│ - Lower ring (ch 1-16): ear level   │
│ - Upper ring (ch 17-32): elevated   │
└────┬────────────────────────────────┘
     │
     ├─────────────────────────┐
     │                         │
     ▼                         ▼
┌──────────────────┐   ┌──────────────────────────┐
│ Lower Ring       │   │ Upper Ring              │
│ (ch N+1 to 2N)   │   │ (ch 1-N)                │
│ Passthrough      │   │ VHAP Processing         │
│                  │   │ - Lower ring as donors  │
│                  │   │ - Band split: mid/hi   │
│                  │   │ - Cross-feed + decorr   │
│                  │   │ - Enhance upper ring     │
└──────────────────┘   └──────────────────────────┘
     │                         │
     └─────────────┬───────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│ ATK FOA Encode Periphonic3D         │  Virtual Speaker Array → B-Format
│ (Encoder)                            │  Sum speakers via periphonic encode matrix
└────┬────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│ B-Format (W', X', Y', Z')           │  Processed with height enhancement
└────┬────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│ [Optional] Additional B-Format      │  Dimension, other transforms
│ Transforms                          │
└────┬────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│ Binaural Decoder                    │  B-Format → Stereo (HRTF)
│ (if available)                      │
└────┬────────────────────────────────┘
     │
     ▼
┌─────────┐
│ Stereo  │  Final output
└─────────┘
```

## Available REAPER Plugins

✅ **Available:**
- `ATK FOA Encode PHJ` - UHJ L/R/T/Q → B-Format (4 ch → 4 ch)
- `ATK FOA Decode PHJ` - B-Format → UHJ L/R/T/Q (4 ch → 4 ch)
- `ATK FOA Decode Periphonic3D+` - B-Format → Virtual Speaker Array (4 ch → up to 32 ch)
- `ATK FOA Encode Periphonic3D` - Virtual Speaker Array → B-Format

❌ **Notes/Dependencies:**
1. If starting with stereo UHJ (L/R) only, ensure you have the correct UHJ → FOA encoder variant (some workflows use PHJ L/R/T/Q). If you already have PHJ (L/R/T/Q), use `ATK FOA Encode PHJ` or decode PHJ to FOA directly.

## Alternative Flow (Starting with PHJ-encoded files)

If you have PHJ-encoded files (L/R/T/Q), you can skip the UHJ decoder:

```
PHJ (L/R/T/Q) → [PHJ Decoder] → B-Format → [Periphonic Decoder] → Virtual Array → [Process Upper Ring] → [Periphonic Encoder] → B-Format → [Binaural]
```

## Implementation Notes

1. **Periphonic Encoder**: Available - matrix inverse operation to sum speakers back to B-Format
2. **VHAP Processing in Speaker Domain**: VHAP theory was originally designed for speaker arrays, not Ambisonics. The correct approach is:
   - **Decode B-Format to periphonic array** (lower ring at ear level, upper ring elevated)
   - **Apply VHAP processing on upper ring** using lower ring as donors:
     - Lower ring (ch N+1 to 2N) = "donor" speakers (horizontal)
     - Upper ring (ch 1-N) = "height" speakers to enhance
     - Process: band split (mid: 0.9-4 kHz, hi: 4-12 kHz), decorrelation delays, cross-feeding
   - **Channel mapping**: Upper ring = ch 1-N (ant clockwise from front-left)
   - **Channel mapping**: Lower ring = ch N+1 to 2N
   - Lower ring passthrough unchanged
   - Upper ring receives VHAP-enhanced signal
3. **No Temporal Delay Issues**: Processing in speaker domain (per-sample) avoids FFT delay problems
4. **Resource Requirements**: Requires routing 32+ channels through REAPER
5. **Plugin**: `ATK Upper Ring VHAP` applies VHAP-style processing using lower ring as donors

## Important Clarification: VHAP → B-VHAP Mapping

**Lee's Original VHAP (2015):**
- Achieved over **4 ear-height speakers** (2D layout, not elevated)
- Creates height illusion from horizontal-only playback
- Processing optimized for that specific 4-speaker geometry

**B-VHAP (Current Implementation):**
- **Remaps VHAP illusion INTO B-Format domain**
- Enables the height effect to work with ANY decoder/geometry (binaural, periphonic, etc.)
- Geometry-agnostic: works regardless of final playback configuration

**Periphonic Approach:**
- Goes **backwards**: B-Format → Speaker Domain → Process → Re-encode
- Uses **cylindrical dual-ring** layout (different from Lee's 4-speaker setup)
- ⚠️ Geometry mismatch: May not replicate VHAP's intended behavior

**Implications:**
- **B-VHAP (current)**: ✅ Already implements VHAP→B-Format remapping. Geometry-agnostic.
- **Periphonic approach**: ⚠️ Geometry-dependent, may deviate from original VHAP principles

## Comparison with Current Approach

**Current (B-VHAP in B-Format):**
- ✅ Single plugin, works directly on B-Format (geometry-agnostic)
- ❌ Has FFT delay (~11.6ms) that shifts temporal relationships
- ❌ Synthesizes Z' via convolution (B-VHAP kernels)
- ⚠️ VHAP theory was designed for speaker arrays, not Ambisonics

**Proposed (Periphonic Processing Chain):**
- Decode B-Format to periphonic array (geometry-specific)
- **Apply VHAP processing in speaker domain** (matches original theory):
  - Lower ring (ear-level) = donors
  - Upper ring (elevated) = enhanced with VHAP-style processing
  - Band splitting, decorrelation, cross-feeding
- Re-encode to B-Format
- ✅ No delay issues (per-sample processing, no FFT)
- ✅ Aligned with original VHAP theory (speaker-based processing)
- ✅ Can fine-tune height emphasis per-speaker if needed
- ❌ Requires multi-channel routing (32+ channels)
- ✅ Encoder/Decoder pair available (Periphonic3D Encode/Decode)
- ✅ Plugin: `ATK Upper Ring VHAP` handles the processing
