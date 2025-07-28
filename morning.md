# Morning Chat Session - Decoder Synchronization Issue

## Summary
This morning's session focused on debugging a critical issue with the UHJ Ambisonic System v22 where the decoder selection was out of sync - the system was using the previous decoder setting instead of the current one selected in the GUI.

## Key Issues Identified

### Main Problem
- **Decoder selection out of sync**: When selecting different decoders (e.g., QUAD SQUARE, QUAD NARROW), the system was using the previous decoder setting instead of the current one
- **Binaural behavior with quad selection**: Even when QUAD NARROW was selected, the system was still using binaural decoder behavior
- **Audio engine initialization timing**: The audio engine was being initialized with stale/previous values instead of current menu selections

### Technical Details
- The issue was identified as a timing problem where `configKeyD` variable wasn't being updated properly
- Debug output showed menu actions were working correctly but audio engine was using wrong decoder
- Attempted fixes included:
  - Removing conditional checks in decoder menu `globalAction`
  - Adding parameter passing to `~initAudioEngine` function
  - Converting `configKeyD` and `configKeyE` to global variables with `~` prefix
  - Various debug message additions to trace the issue

### Current State
- The decoder menu actions are working (setting `~configKeyD` correctly)
- Audio engine reinitialization is being triggered
- But the decoder being created is still wrong (showing `FoaDecoderKernel(listen, 3, 2, 1053, nil)` instead of quad decoder)
- Latest error: `Balance2 input 1 is not audio rate: nil audio` due to binaural decoder being used in quad setup

## Files Modified
- `supercollider/app/UHJ_Ambisonic_System_v22.scd` - Main application file with Maplin integration
- `supercollider/extensions/MaplinSM333/classes/MaplinSM333.sc` - Maplin B-format processing class
- `~/.local/share/SuperCollider/Extensions/MaplinSM333/classes/MaplinSM333.sc` - Local copy of Maplin class

## Next Steps Needed
1. Debug why `currentDecoderKey` parameter isn't being passed correctly to audio engine
2. Verify decoder dictionary lookup is working properly
3. Check if there are scope issues with global variable access
4. Consider reverting to working v12 approach if current fixes don't resolve the issue

## Key Insight
The user correctly identified: "The decoder is selecting the option that it WAS on rather than IS on" - this is the core issue that needs to be resolved. 