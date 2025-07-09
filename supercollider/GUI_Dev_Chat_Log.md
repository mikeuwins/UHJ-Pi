# SuperCollider Ambisonic GUI Development Log

## Summary
This document records the key steps, issues, and solutions from the development and refinement of a modern SuperCollider GUI for an ambisonic audio system, including all major troubleshooting and design decisions.

---

## Key Requirements
- Modern, visually aligned interface for Raspberry Pi 7" screen
- Cyan/black theme, Helvetica font throughout
- Input faders, source selector buttons, mute/monitor/link controls
- Ambisonic/spatial controls, volume fader, encoder/decoder dropdowns
- Custom level meter (ServerMeter2View) with channel numbers and dB scale, all fonts matching main GUI
- EQ/AMBIENCE overlays, overlays and controls perfectly aligned

---

## Major Steps & Solutions

### 1. Diagnosing Font and GUI Issues
- Ensured all GUI elements in `GUIPrototype.scd` and `ServerMeter2.sc` use Helvetica (with .boldVariant or Helvetica-Bold fallback).
- Replaced Pen.font (for dB scale) with StaticText in ServerMeter2View for consistent font rendering.
- Created and ran test scripts (e.g., `FinalFontTest.scd`) to verify font consistency and class recompilation.

### 2. ServerMeter2View Not Updating
- Discovered changes to `/home/michael-uwins/UHJ-Pi/supercollider/extensions/ServerMeter2/classes/ServerMeter2.sc` were not taking effect.
- Diagnosed a duplicate/shadowed class file issue: SuperCollider was loading `/home/michael-uwins/.local/share/SuperCollider/Extensions/ServerMeter2/classes/ServerMeter2.sc` instead.
- Guided user to search for all `ServerMeter2.sc` files, delete duplicates, and confirm the correct file is loaded with a unique postln.

### 3. Final Font and Layout Fixes
- Updated all font settings in the active `ServerMeter2.sc` to use Helvetica.
- Confirmed all channel numbers, dB scale, and labels now match the main GUI.
- Adjusted meter window position in `GUIPrototype.scd` for perfect centering between dropdowns and bottom buttons.

### 4. General GUI Refinement
- Ensured overlays (EQ, Ambience) and all controls are visually aligned.
- Maintained a consistent cyan/black theme and Helvetica font throughout.
- Provided shell and SuperCollider commands for file management and debugging.

---

## 2025-07-02

### Overlay/Knob State Bugfix and Review
- Fixed bug: After selecting a dim decoder (QUAD, 5.1, OCTAGON), then switching back to a binaural decoder with HT ON, the ambisonic knobs were not re-enabled unless HT was toggled. Now, the decoder dropdown's globalAction explicitly re-enables the knobs if a non-dim decoder is selected and HT is ON.
- Confirmed: Overlay and knob state are always correct after any decoder or HT change. No need to toggle HT after switching decoders.
- User confirmed the fix works as intended.

### XY (Quad) Panner Integration and Overlay Logic
- Added a robust XY (Quad) panner (Slider2D) below the ambisonic knobs, with a cyan border and label.
- Integrated overlay logic for the panner, matching the ambisonic controls: overlays and enable/disable state are always in sync, controlled by decoder selection.
- Ensured overlays for both the ambisonic controls and panner are always removed before being recreated, and only present when needed.
- Overlay for ambisonic controls now robustly covers the Headtracker ON/OFF and RESET buttons; no extra overlay needed for those buttons.
- Used `.value_(0)` (not `.valueAction_(0)`) to force HT OFF for non-ambisonic decoders, avoiding recursion and GUI freeze.
- All overlay and enable/disable logic is now inside `outputMenu.globalAction` for clarity and robustness.
- User confirmed overlays and enable/disable logic are visually and functionally correct for all decoders.

### Cleanup and Best Practices
- User will delete experimental/test files (e.g., TestFonts.scd, meter test scripts) manually using Nemo.
- All legacy debug and redundant overlay logic has been removed from the codebase.

---

## Best Practices & Lessons Learned
- Always confirm which class file SuperCollider is loading when making changes to custom extensions.
- Use diagnostic postlns and visible labels to verify active code.
- Keep all font and color settings consistent for a professional look.
- Back up and sync user extension changes to the main project repo to avoid confusion.
- Place all overlay and enable/disable logic in a single, well-documented location (e.g., `outputMenu.globalAction`) for maintainability.

---

## Next Steps
- Copy the working `ServerMeter2.sc` from the user extensions folder back to the repository at `UHJ-Pi/supercollider/extensions/ServerMeter2/classes/ServerMeter2.sc`.
- Continue refining GUI as needed, using the same diagnostic and design approach.
- Integrate live DSP/EQ parameter mapping, SCAmbiVerb, and headtracking data if desired.
- Add persistent storage for EQ presets if required.

---

## End of Log

# SuperCollider GUI Development Chat Log

**Date:** 9 July 2025

---

## Key Topics & Actions

- Integrated and refined the Ambience overlay and output fader in the SuperCollider GUI app.
- Ensured GUI and audio logic match the GUIPrototype and MainApp2, respectively.
- Corrected fader mapping, labels, and styling to match user requirements.
- Added output fader with dB scale, tick marks, and correct synth \amp parameter logic.
- Fixed startup value, tick mark spacing, and display formatting.
- Debugged and resolved issues with GUI element creation order and nil errors.
- Provided code snippets and best practices for SuperCollider GUI coding.

---

## How to Push to GitHub

1. **Open a terminal** in your project directory.
2. **Check status:**
   ```bash
   git status
   ```
3. **Add changes:**
   ```bash
   git add .
   ```
4. **Commit changes:**
   ```bash
   git commit -m "Describe your changes here"
   ```
5. **Push to GitHub:**
   ```bash
   git push
   ```

If you haven't set up a remote or branch, let me know and I can guide you through that as well.

---

**End of session.**
