# 5.1.2 Matrix Decoder - Height Speaker Work

**Date:** Session backup
**Context:** Working on fixing height speaker decode in ATK FOA 5.1.2 Matrix Decode JSFX plugin

## Problem Statement

The height speakers (TFL, TFR) were sounding too similar to the front speakers. On test files with mostly ambient/reverberant content in the upper hemisphere, the height speakers were picking up too much direct/directional signal instead of sounding ambient and reverberant.

## Key Issues Identified

1. **Height speaker matrix coefficients were too directional:**
   - Original values: X=0.612, Y=±0.353, Z=0.707, W=0.0
   - These large X coefficients caused height speakers to sound like fronts
   - With only 2 height speakers for 5.1.2, they should represent the upper hemisphere more broadly, not specific positions

2. **Z scaling attempts caused problems:**
   - Tried various approaches to gate/scale X&Y contributions based on Z presence
   - All caused distortion/fizziness:
     - Hard threshold switching (0 or 1) → crackles/artifacts
     - Normalization (Z/|Z|) → instability
     - Smooth fade-in → fizziness
   - Eventually reverted to full periphonic decode for all cases

## Current Solution

Modified height speaker matrix to balance ambient vs. directional content:

```javascript
// Heights 2x4 matrix (TFL,TFR) - balanced for upper hemisphere ambience with spatial width
// Reduced X/Y by ~50% to lessen front-speaker similarity while preserving spatial directionality
// Added W for ambient content, kept Z for elevation
function set_heights_matrix() local(i) (
  i = 5; // TFL - reduced X/Y by ~50%, added W for ambience, preserves left-side spatial info
  matrixDSP[i*4+0] = 0.2; matrixDSP[i*4+1] = 0.306; matrixDSP[i*4+2] = -0.177; matrixDSP[i*4+3] = 0.70710678118655;
  i = 6; // TFR - reduced X/Y by ~50%, added W for ambience, preserves right-side spatial info
  matrixDSP[i*4+0] = 0.2; matrixDSP[i*4+1] = 0.306; matrixDSP[i*4+2] = 0.177; matrixDSP[i*4+3] = 0.70710678118655;
);
```

**Current values:**
- W = 0.2 (ambient/omnidirectional content)
- X = 0.306 (50% of original - preserves left/right spatial width)
- Y = ±0.177 (50% of original - preserves front/back spatial width)
- Z = 0.707 (unchanged - elevation)

## Requirements

1. **Height speakers should:**
   - Sound ambient/reverberant, not like fronts
   - Preserve spatial width (e.g., left-side splash cymbal reverb should favor left height speaker)
   - Represent upper hemisphere ambience when appropriate

2. **Future work needed:**
   - Implement file loading for matrices (currently hardcoded)
   - This will allow easier tweaking without recompiling plugin
   - Matrix files location: `/home/michael-uwins/.config/REAPER/Data/ATK/matrices/FOA/decoders/5_1_2/`
   - Files include: `equal.txt`, `focused.txt`, `four.txt`, `heights_topfront.txt`

## File Locations

- **Plugin source:** `reaper/jsfx/ATK/FOA/Decode/5.1.2 Matrix Decode`
- **Installed location:** `/home/michael-uwins/.config/REAPER/Effects/ATK/FOA/Decode/`
- **Matrix files:** `/home/michael-uwins/.config/REAPER/Data/ATK/matrices/FOA/decoders/5_1_2/`

## Testing Plan (Tomorrow)

1. Proper listening tests for:
   - Upper hemisphere panning effectiveness
   - Ambient/reverberant content in height speakers
   - Spatial width preservation (left/right directionality)
   - Comparison with front speakers

2. If matrix tweaking needed:
   - Implement file loading for matrices
   - Test different W/X/Y/Z balance values
   - Ensure matrices can be edited without recompiling

## Technical Notes

- Lower ring (5 speakers) uses standard 5_0 decode matrices with Z=0
- Height speakers need proper balance of W (ambient), X/Y (directionality), Z (elevation)
- Original height matrix file: `heights_topfront.txt` has values that are too directional
- Current hardcoded values are experimental and need proper listening tests

## Code Status

- Full periphonic decode implemented (no Z gating/scaling)
- Height speaker matrix modified with reduced X/Y, added W
- Output mapping works for both UHJ-Pi and Dolby layouts
- File loading for matrices not yet implemented (planned for tomorrow)

