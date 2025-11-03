# Upper Ring VHAP - Explanation

## What It Is

**"Upper Ring VHAP" is a multi-channel speaker-domain processor** that applies VHAP-style processing to enhance height speakers using ear-level speakers as "donors."

## What It Is NOT

1. ❌ **NOT an encoder** - It doesn't convert between formats
2. ❌ **NOT a replacement for "VHAP Only"** - They work in different domains
3. ❌ **NOT kernel-based** - It uses lightweight IIR filters and delay lines (no FIR convolution)
4. ❌ **NOT for B-Format** - It works on speaker channels (32 channels max)

## Key Characteristics

### Domain
- **Speaker Domain**: Works on individual speaker channels (not B-Format)
- **Input**: Multi-channel speaker array (up to 32 channels)
- **Output**: Multi-channel speaker array (same channels)

### Processing Method
- **Lightweight IIR filters** for band splitting (not FIR convolution)
- **Simple delay lines** for decorrelation (not kernel-based)
- **Per-sample processing** (no FFT, no delay)

### Operation
- **Lower ring channels (N+1 to 2N)**: Ear-level speakers (passthrough, used as "donors")
- **Upper ring channels (1-N)**: Height speakers (enhanced with VHAP processing)
- Uses lower ring mid/hi bands to enhance upper ring (VHAP theory)

## Where It Fits in the Chain

```
B-Format (W/X/Y/Z)
    ↓
[Optional: Dimension] (width processing)
    ↓
[Periphonic3D Decoder] ← Decodes to speaker array (e.g., 8 channels: ch1-4 upper, ch5-8 lower)
    ↓
[Upper Ring VHAP] ← Processes speaker channels (no delay!)
    ↓
[Periphonic3D Encoder] ← Re-encodes back to B-Format
    ↓
B-Format (W'/X'/Y'/Z') (with enhanced height)
```

## Comparison: "VHAP Only" vs "Upper Ring VHAP"

| Feature | VHAP Only | Upper Ring VHAP |
|---------|-----------|-----------------|
| **Domain** | B-Format (4 channels) | Speaker array (up to 32 channels) |
| **Input** | W/X/Y/Z (B-Format) | Speaker channels (decoded) |
| **Method** | Kernel-based FIR convolution (1024 taps) | IIR filters + delay lines |
| **Latency** | ~11.6ms (FFT chunks) | 0ms (per-sample) |
| **Kernels** | ✅ Yes (BVHAP_Z.wav) | ❌ No |
| **CPU** | Medium (FFT overlap-add) | Light (IIR filters) |
| **Use Case** | Process B-Format directly | Process after decode, before encode |
| **Theory** | B-VHAP (B-Format remapping) | Original VHAP (speaker-domain) |

## Why Both?

- **"VHAP Only"**: Works directly on B-Format (geometry-agnostic, works with any decoder)
  - ✅ No dependency on speaker geometry
  - ✅ Works for binaural, periphonic, etc.
  - ❌ Has FFT delay (~11.6ms)

- **"Upper Ring VHAP"**: Works in speaker domain (geometry-specific, zero delay)
  - ✅ Zero delay (per-sample processing)
  - ✅ Matches original VHAP theory (speaker-based)
  - ❌ Requires decode/encode (geometry-dependent)
  - ❌ Only works with periphonic setups

## When to Use Each

**Use "VHAP Only"** if:
- You want to process B-Format directly
- You're outputting to binaural
- You want geometry-agnostic processing
- The ~11ms delay is acceptable

**Use "Upper Ring VHAP"** if:
- You need zero delay processing
- You're already decoding to periphonic speakers
- You want to match original VHAP theory exactly
- You want to process in the speaker domain

## Current Status

⚠️ **"Upper Ring VHAP" is experimental** - The implementation may need refinement based on testing. The cross-feeding logic (lower ring → upper ring) follows VHAP principles but may need adjustment for the periphonic geometry.


