# GUI EQ/Ambience Integration Log - 2025-07-08

## Summary
- Attempted to integrate AmbiVerbSC (Ambience overlay) into the SuperCollider app, matching GUIPrototype style and parameter set.
- Persistent issues: syntax errors (mainly var placement, code block structure), server boot/runtime errors, AmbiVerbSC parameter handling, and audio output loss after integration.
- Provided step-by-step troubleshooting for Jack server, channel count, AmbiVerbSC "size" parameter, and SuperCollider best practices.
- User rolled back to a previous working version after persistent errors.
- Plan: Try again tomorrow, ensuring all var declarations are at the top, code is wrapped in a single code block, and AmbiVerbSC "size" is hardcoded at SynthDef definition time.

## Key Files
- `app/IntegratedApp_Stage2.scd` (active file, Ambience overlay TODO)
- `app/IntegratedApp_Stage4_Ambience.scd` (main file for AmbiVerbSC overlay integration)
- `prototypes/GUIPrototype.scd` (reference for GUI style/layout)

## Pending Tasks
- Robust, error-free AmbiVerbSC overlay integration with correct variable scope and code block structure.
- Ensure no syntax errors related to variable placement or code block structure.
- Ensure audio output is not lost after AmbiVerbSC integration/refactor.
- Implement Ambience overlay in `IntegratedApp_Stage2.scd`.

## Troubleshooting Notes
- Jack server must be set to 2 inputs, 8 outputs for multi-channel output.
- AmbiVerbSC "size" must be a Symbol at SynthDef definition time, not a String or control argument.
- All var and ~global assignments must be at the top of the code block.
- Only call `s.boot` if the server is neither running nor booting.

## Next Steps
- Resume integration tomorrow, following best practices and lessons learned from today.

---
