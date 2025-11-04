# Chat Backup - UHJ-Pi Development Session
## Date: January 30, 2025

## Summary
This session focused on integrating FoaDimension and FoaZSynthesis SuperCollider classes into the UHJ_v28_ESI_PAIR.scd application, including UI development, parameter management, and bug fixes.

---

## Key Changes Made

### 1. Dimension Overlay Integration
- **Added Dimension overlay** with controls for Forward Preference (Width) and Output Trim
- **Removed LF/HF Gain controls** - These were tied to psychoacoustic shelves which are disabled (`shelvesMode = 0`)
- **Added Width HPF control** - High-pass filter for Forward Preference injection (80-400 Hz, default 180 Hz)
- **Layout**: 3 knobs on Row 1: Width (60px), W HPF (130px), Trim (200px)

### 2. Unified ON/OFF Button
- **Single ON/OFF button** now controls both Maplin and Dimension processing
- Button always visible (not covered by overlays)
- When OFF: both Maplin and Dimension are bypassed
- When ON: both are active
- Button positioned at (18, 241, 80, 25)

### 3. Overlay Visibility Logic
- **Dimension row overlay**: Covers Dimension controls when Maplin encoder is selected
- **Maplin row overlay**: Covers Maplin controls when UHJ/SUPERSTEREO/PHJ encoders are selected
- **ON/OFF and RESET buttons**: Always visible (work for both processors)
- Overlays positioned to stop before buttons at y=241

### 4. UI Positioning Adjustments
- **Moved all elements up by 4px**:
  - Dimension labels: y=30 → y=26
  - Dimension knobs: y=52 → y=48
  - Dimension values: y=117 → y=113
  - Maplin labels: y=140 → y=136
  - Maplin knobs: y=161 → y=157
  - Maplin values: y=225 → y=221
  - Buttons: y=245 → y=241

### 5. Parameter Range Adjustments
- **Output Trim**: Reduced from -18/+18 dB to -6/+6 dB (more reasonable range)
- **Width HPF**: 80-400 Hz range (matches JSFX plugin)

### 6. State Management
- **Dimension state**: Now stores 3 values `[width, widthHPF, outputTrim]` (normalized 0-1)
- **Legacy support**: Handles old 2-value and 4-value formats gracefully
- **State preservation**: All controls save/restore their values correctly

### 7. 5.1.2 Layout Graphic Updates (v27)
- Updated title to "LAYOUT - DOLBY 5.1.2" (centered)
- Adjusted subtitle positioning and formatting
- Aligned ceiling speakers (7 and 8) directly above front speakers (1 and 2)

---

## Files Modified

### SuperCollider Application
- `supercollider/app/UHJ_v28_ESI_PAIR.scd` - Main application with Dimension/ZSynth integration
- `supercollider/app/UHJ_v27_ESI_PAIR.scd` - 5.1.2 layout graphic updates

### SuperCollider Extensions
- `supercollider/extensions/FoaDimension/classes/FoaDimension.sc` - Minor fixes
- `supercollider/extensions/FoaZSynthesis/classes/FoaZSynthesis.sc` - Minor fixes

---

## Technical Details

### Dimension Processing Chain
```
Input → Encode BFormat → EQ → Dimension → ZSynth → AmbiVerbSC → FoaRTT → Decode
```

### Dimension Parameters
- `dimensionWidth`: 0.0 to 0.70 (Forward Preference amount)
- `dimensionWidthHPF`: 80 to 400 Hz (HPF cutoff for injection term)
- `dimensionOutputTrim`: -6 to +6 dB (output gain)
- `dimensionShelvesMode`: 0 (hardcoded OFF - handled in decoders)
- `dimensionGerzonPresets`: 0 (hardcoded OFF - handled in decoders)
- `dimensionActive`: 1 = active, 0 = bypass

### Maplin Parameters
- `maplinSurround`: 0.0 to 1.0 (normalized)
- `maplinEffect`: 0.0 to 1.0 (normalized)
- `maplinDelay`: 0.0 to 1.0 (normalized, maps to 5-50ms)
- `maplinActive`: 1 = active, 0 = bypass (shared with Dimension)

---

## Issues Resolved

1. **Missing "W HPF" label** - Added label at position 130px
2. **LF/HF Gain controls not working** - Removed (shelves disabled)
3. **Output Trim range too wide** - Reduced from -18/+18 to -6/+6 dB
4. **ON/OFF button visibility** - Made always visible, controls both Maplin and Dimension
5. **Overlay covering buttons** - Adjusted overlay heights to stop before buttons
6. **UI spacing** - Moved all elements up by 4px for better layout

---

## Git Commit
- **Commit hash**: `f474204`
- **Message**: "Integrate FoaDimension and FoaZSynthesis into v28 app"
- **Files changed**: 4 files, 463 insertions(+), 293 deletions(-)
- **Status**: Pushed to `origin/main`

---

## Next Steps (For Tomorrow)
- Continue testing Dimension and ZSynth integration
- Verify audio processing chain works correctly
- Test preset save/recall functionality
- Consider adding ZSynth controls to Ambience overlay (as discussed)

---

## Notes
- Dimension processing should be last before decoding (Gerzon shelves), but shelves are handled in decoders
- Maplin controls only affect audio when Maplin encoder is selected
- Dimension controls work with all encoders (Ambisonic material)
- ON/OFF button provides unified control for both processors

---

## Good Night! 🌙
All work committed and pushed successfully. Ready to continue tomorrow!


