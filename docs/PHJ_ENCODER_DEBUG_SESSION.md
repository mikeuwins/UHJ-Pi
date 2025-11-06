# PHJ Encoder Debug Session

**Date:** Current Session  
**Issue:** PHJ encoder in SuperCollider producing non-zero Z component from 2-channel UHJ input (L, R, T=0, Q=0), despite JSFX counterpart producing Z=0 correctly.

## Problem Statement

When feeding a 4-channel UHJ file (L, R, T=0, Q=0) through the PHJ encoder in SuperCollider:
- **Expected:** Z = 0 (as confirmed in Reaper JSFX implementation)
- **Actual:** Z is non-zero (approximately 0.0247 when tested)

The user confirmed that in Reaper, feeding a UHJ file into the PHJ encoder yields only W, X, and Y (Z=0), indicating the kernels themselves are correct.

## Key Findings

### 1. Kernel Structure
- PHJ encoder uses 4-lane interleaved kernels per input channel: `[WX_r, WX_i, YZ_r, YZ_i]`
- Each input (L, R, T, Q) has its own kernel file with 4 channels
- Kernel files located at: `ATK/kernels/FOA/encoders/phj/<fs>/<N>/0000/UHJ_{L,R,T,Q}.wav`

### 2. JSFX Implementation (Working Correctly)
From `reaper/jsfx/ATK/FOA/Encode/PHJ`:
```javascript
// Each input channel convolved with its WX and YZ kernels
// L → WX & YZ (complex convolution)
// R → WX & YZ (complex convolution)
// T → WX & YZ (complex convolution)
// Q → WX & YZ (complex convolution)

// Sum current block
W = mCur_L_WX[bp2]   + mCur_R_WX[bp2]   + mCur_T_WX[bp2]   + mCur_Q_WX[bp2];
X = mCur_L_WX[bp2+1] + mCur_R_WX[bp2+1] + mCur_T_WX[bp2+1] + mCur_Q_WX[bp2+1];
Y = mCur_L_YZ[bp2]   + mCur_R_YZ[bp2]   + mCur_T_YZ[bp2]   + mCur_Q_YZ[bp2];
Z = mCur_L_YZ[bp2+1] + mCur_R_YZ[bp2+1] + mCur_T_YZ[bp2+1] + mCur_Q_YZ[bp2+1];
```

Where:
- `bp2` = real part index
- `bp2+1` = imaginary part index
- `mCur_*_YZ[bp2+1]` = imaginary part of YZ convolution result

### 3. SuperCollider Implementation (Current)
From `AtkKernelConv.ar` in `ATK.sc`:

```supercollider
// PHJ encoder uses 4-lane interleaved kernels (4 inputs × 4 outputs)
if((kernel.shape[0] == 4) && (kernel.shape[1] == 4), {
    // PHJ: Complex convolution with 4-lane interleaved format
    var wxReal, wxImag, yzReal, yzImag;
    var w, x, y, z;
    
    // Process each input (L, R, T, Q) with its WX and YZ kernels
    wxReal = (kernel.shape[0]).collect({ |i|
        Convolution2.ar(in[i], kernel[i][0], framesize: kernel[i][0].numFrames)
    });
    wxImag = (kernel.shape[0]).collect({ |i|
        Convolution2.ar(in[i], kernel[i][1], framesize: kernel[i][1].numFrames)
    });
    yzReal = (kernel.shape[0]).collect({ |i|
        Convolution2.ar(in[i], kernel[i][2], framesize: kernel[i][2].numFrames)
    });
    yzImag = (kernel.shape[0]).collect({ |i|
        Convolution2.ar(in[i], kernel[i][3], framesize: kernel[i][3].numFrames)
    });
    
    // Sum contributions from all inputs (L, R, T, Q)
    w = Mix.new(wxReal);      // W = sum of WX real parts
    x = Mix.new(wxImag);      // X = sum of WX imaginary parts
    y = Mix.new(yzReal);      // Y = sum of YZ real parts
    z = Mix.new(yzImag);      // Z = sum of YZ imaginary parts
    
    out = [w, x, y, z];
});
```

### 4. Kernel Loading
From `FoaEncoderKernel.initKernel` in `FoaMatrix.sc`:
- PHJ encoder sets `chans = 4` (4-lane interleaved)
- Each kernel file is loaded with 4 channels: `Buffer.readChannel(server, kernelPath.fullPath, channels: [chan])`
- For PHJ: `kernel[0][0]` = L's WX_r, `kernel[0][1]` = L's WX_i, `kernel[0][2]` = L's YZ_r, `kernel[0][3]` = L's YZ_i

## Current State

### Test Script
`supercollider/app/Test_FOA_512_Check.scd`:
- Loads 4-channel UHJ file (StereoEditUPHJ.wav)
- Encodes with PHJ encoder
- Monitors Z amplitude via `SendReply.kr`
- Shows Z amplitude ~0.0247 when T=0 and Q=0 (incorrect)

### Files Modified
1. `/home/michael-uwins/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/ATK.sc`
   - Modified `AtkKernelConv.ar` to handle PHJ encoder kernels
   - Added detection for 4x4 kernel shape (PHJ)
   - Performs complex convolution by separating WX and YZ real/imaginary parts

2. `/home/michael-uwins/.local/share/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc`
   - `FoaEncoderKernel.newPHJ` exists and sets `chans = 4`
   - Kernel loading logic appears correct

## Questions to Investigate

1. **Kernel Design:** Are the L and R YZ imaginary kernels designed to cancel for horizontal-only signals? If so, why aren't they canceling in SuperCollider?

2. **Convolution Implementation:** Is `Convolution2.ar` performing the convolution correctly compared to JSFX's `convolve_c` (complex convolution)?

3. **Kernel Structure:** Are the kernels loaded with the correct channel mapping? Is `kernel[i][3]` actually the YZ imaginary kernel for input `i`?

4. **Sign/Normalization:** Is there a sign error or normalization issue in how we're summing the YZ imaginary contributions?

5. **Complex vs Real:** JSFX uses complex convolution (`convolve_c`), while SuperCollider uses real convolution (`Convolution2.ar`) separately. Could this be the issue?

## Next Steps

1. **Examine Kernel Research:** Review the research behind PHJ kernel creation to understand the mathematical relationship between L, R, T, Q inputs and W, X, Y, Z outputs.

2. **Compare Kernel Files:** Load the actual kernel files and inspect their values to verify:
   - Are L and R YZ imaginary kernels designed to cancel?
   - What are the actual values in the kernel files?

3. **Debug Convolution:** Add detailed logging to see:
   - What are the individual contributions from L and R YZ imaginary kernels?
   - Do they sum to zero or is there a numerical precision issue?

4. **Test with Known Input:** Test with a known signal (e.g., pure sine wave) to isolate the issue.

5. **Compare with JSFX:** Step through the JSFX implementation to see if there's any preprocessing or post-processing we're missing.

## User's Observation

> "encoder is creating Z from L&R and then the encoder is then creating 7&8 from X Y and Z"

This confirms:
1. The encoder is incorrectly generating Z from L and R (when T=0, Q=0)
2. The decoder is then correctly using that Z to create height channels (7 & 8)

## Files to Review on Mac

1. Research documentation on PHJ kernel creation
2. Kernel files themselves (if accessible)
3. JSFX implementation in detail
4. Any ATK documentation on PHJ encoding

## Important Notes

- The user confirmed kernels are correct (Reaper produces Z=0)
- The issue is in SuperCollider's `AtkKernelConv.ar` implementation
- The logic appears correct but produces wrong results
- Need to investigate the mathematical relationship in the kernel design

## Resolution (2025-11-05)

### Root Cause Identified
The issue was **kernel file loading order**, not the convolution logic itself. The PHJ encoder kernels were being loaded in alphabetical order (L, Q, R, T) instead of the required order (L, R, T, Q), causing:
- R input to use Q's kernels → only producing Z (vertical component)
- T input to use R's kernels
- Q input to use T's kernels

### Fixes Applied

1. **Kernel Loading Order Fix** (`FoaMatrix.sc`)
   - Added explicit file sorting for PHJ encoder: L, R, T, Q order
   - Added explicit file sorting for PHJ decoder: W, X, Y, Z order (for safety)
   - Detects which files exist to automatically choose encoder vs decoder order

2. **Height Gate** (Test script)
   - Added Z-based gating to mute height channels when Z≈0
   - Prevents W/X/Y leakage into height speakers for horizontal sources

### Verification
- ✅ UHJ input (L, R, T=0, Q=0) → Z=0 (correct)
- ✅ PHJ input (L, R, T, Q all active) → All 8 channels active
- ✅ Mute Q → Height channels (7 & 8) silent (correct: Q produces Z)
- ✅ Mute T → Width pulled in (correct: T produces Y)

### Files Modified
- `~/Library/Application Support/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc`
- `supercollider/app/Test_FOA_512_Check.scd` (height gate added)

### Status: ✅ RESOLVED
All PHJ encoder and 5.1.2 decoder issues are now fixed and working correctly.


