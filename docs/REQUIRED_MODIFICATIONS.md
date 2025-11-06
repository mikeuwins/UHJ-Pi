# Required Modifications for SuperCollider and Reaper

This document lists all modifications required to make PHJ encoding/decoding work correctly in this project.

## SuperCollider Modifications

### 1. ATK.sc - PHJ Encoder Support

**File:** `~/Library/Application Support/SuperCollider/downloaded-quarks/atk-sc3/Classes/ATK.sc`

**Method:** `AtkKernelConv.ar`

**Required Change:** Add PHJ-specific handling for 4-lane interleaved kernels.

**Location:** Around line 1025-1054

**Code:**
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
    w = Mix.new(wxReal);
    x = Mix.new(wxImag);
    y = Mix.new(yzReal);
    z = Mix.new(yzImag);
    
    out = [w, x, y, z];
}, {
    // Standard kernel convolution for all other encoders
    // ... existing code ...
});
```

**Why:** PHJ encoder uses unique 4-lane interleaved format that requires special handling.

---

### 2. FoaMatrix.sc - Kernel Loading Order Fix

**File:** `~/Library/Application Support/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc`

**Method:** `FoaEncoderKernel.initKernel` and `FoaDecoderKernel.initKernel`

**Required Change:** Explicitly sort PHJ kernel files to ensure correct order.

**Location:** Around line 1967-1974 (encoder) and 2287-2294 (decoder)

**Code:**
```supercollider
// For PHJ, sort files to ensure correct order
// Encoder: L, R, T, Q (not alphabetical L, Q, R, T)
// Decoder: W, X, Y, Z (already alphabetical, but explicit is safer)
var kernelFiles = subjectPath.files;
if(this.kind == \phj, {
    var encoderOrder = ["UHJ_L.wav", "UHJ_R.wav", "UHJ_T.wav", "UHJ_Q.wav"];
    var decoderOrder = ["UHJ_W.wav", "UHJ_X.wav", "UHJ_Y.wav", "UHJ_Z.wav"];
    var order;
    // Check which files exist to determine encoder vs decoder
    if(kernelFiles.any({ |f| f.fileName == encoderOrder[0] }), {
        order = encoderOrder;
    }, {
        order = decoderOrder;
    });
    kernelFiles = order.collect({ |name|
        kernelFiles.detect({ |f| f.fileName == name })
    }).select(_.notNil);
});
kernel = kernelFiles.collect({ |kernelPath|
    // ... existing kernel loading code ...
});
```

**Why:** Filesystem returns files in alphabetical order, but PHJ encoder requires L, R, T, Q order. Without this fix, R input uses Q's kernels, causing Z-leak and routing issues.

---

### 3. FoaMatrix.sc - 5.0.2 Decoder Method

**File:** `~/Library/Application Support/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc`

**Method:** `FoaDecoderMatrix.new5_0_2`

**Required Change:** Add new class method for 5.1.2 decoder.

**Location:** Around line 565-570

**Code:**
```supercollider
*new5_0_2 { |irregKind = \equal|
    ^super.new('5_0_2').loadFromLib(irregKind);
}
```

**Why:** Provides 5.1.2 decoder support matching JSFX implementation.

---

### 4. FoaMatrix.sc - PHJ Encoder Method

**File:** `~/Library/Application Support/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc`

**Method:** `FoaEncoderKernel.newPHJ`

**Required Change:** Add new class method for PHJ encoder.

**Location:** Around line 2086-2088

**Code:**
```supercollider
*newPHJ { |kernelSize = nil, server = (Server.default), sampleRate, score|
    ^super.newCopyArgs(\phj, 0).initKernel(kernelSize, server, sampleRate, score);
}
```

**Why:** Provides PHJ encoder support.

---

### 5. FoaMatrix.sc - PHJ Case in initKernel

**File:** `~/Library/Application Support/SuperCollider/downloaded-quarks/atk-sc3/Classes/FoaMatrix.sc`

**Method:** `FoaEncoderKernel.initKernel`

**Required Change:** Add `\phj` case to switch statement.

**Location:** Around line 2325-2331

**Code:**
```supercollider
\phj, {
    dirChannels = [inf, inf, inf, inf];
    if(sampleRateStr.isNil, {
        sampleRateStr = server.sampleRate.asInteger.asString
    });
    chans = 4					// [w, x, y, z]
}
```

**Why:** Enables PHJ encoder to correctly derive sample rate and set channel count.

---

## Reaper Modifications

No modifications to Reaper JSFX plugins are required. The JSFX implementations are correct and serve as the reference for SuperCollider fixes.

**JSFX Plugins Used:**
- `reaper/jsfx/ATK/FOA/Encode/PHJ` - PHJ encoder (working correctly)
- `reaper/jsfx/ATK/FOA/Decode/5.1.2 Matrix Decode` - 5.1.2 decoder (working correctly)

---

## Installation Checklist

After applying modifications:

1. ✅ Recompile SuperCollider class library (Language → Recompile Class Library)
2. ✅ Verify PHJ encoder works: `FoaEncoderKernel.newPHJ` should load kernels
3. ✅ Verify 5.0.2 decoder works: `FoaDecoderMatrix.new5_0_2` should load matrices
4. ✅ Test with UHJ input: Should produce Z=0
5. ✅ Test with PHJ input: Should produce all 8 channels correctly

---

## Verification Commands

```supercollider
// Check PHJ encoder
encoder = FoaEncoderKernel.newPHJ;
encoder.kernel.shape; // Should be [4, 4]

// Check 5.0.2 decoder
decoder = FoaDecoderMatrix.new5_0_2(\equal);
decoder.matrix.shape; // Should be [7, 4] or [8, 4]

// Test encoder with UHJ input (should produce Z=0)
s.boot;
{
    var sig = PinkNoise.ar(0.1);
    var in = [sig, sig, Silent.ar, Silent.ar]; // L, R, T=0, Q=0
    var encoder = FoaEncoderKernel.newPHJ;
    var bfmt = FoaEncode.ar(in, encoder);
    // Monitor Z - should be ~0
    Out.ar(0, [bfmt[3], bfmt[3]]);
}.play;
```

---

## Troubleshooting

### "Kernel files not loading in correct order"
- **Fix:** Verify the kernel loading order fix is applied in `FoaMatrix.sc`
- **Check:** Kernel file names should match exactly: `UHJ_L.wav`, `UHJ_R.wav`, `UHJ_T.wav`, `UHJ_Q.wav`

### "R input only produces Z"
- **Fix:** This indicates kernel loading order is wrong. R should be using R's kernels, not Q's.
- **Check:** Verify the explicit sorting code is in place in `FoaEncoderKernel.initKernel`

### "Height channels active when Z=0"
- **Fix:** This is expected behavior from the decoder matrix (W/X/Y coefficients). Apply height gate in your application code based on Z magnitude.

---

## Last Updated

**2025-11-05** - All fixes verified and working correctly.





