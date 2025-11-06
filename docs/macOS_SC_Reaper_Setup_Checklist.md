## UHJ-Pi macOS Setup Checklist (SuperCollider + Reaper)

Use this to replicate your working environment on macOS. Tick each box as you go.

### 1) Prerequisites
- [ ] Install SuperCollider (latest stable) and launch it once
- [ ] Ensure you can recompile the class library (Cmd+Shift+P)
- [ ] Install Reaper (latest) and launch once

### 2) Install SuperCollider Quarks
- [ ] In SuperCollider, evaluate:
  ```supercollider
  Quarks.install("https://github.com/ambisonictoolkit/atk-sc3.git");
  Quarks.install("https://github.com/JamesWenlock/AmbiVerbSC");
  ```
- [ ] Recompile class library (Cmd+Shift+P)

### 3) Quark locations on macOS (no GUI conflicts)
- macOS SuperCollider resolves classes in both `downloaded-quarks/` and `Extensions/` reliably.
- wslib GUI conflicts are not an issue on this Mac.
- Action (optional): If you want to mirror the Pi layout, you may still move these from `downloaded-quarks/` to `Extensions/`:
  - [ ] `atk-sc3`
  - [ ] `AmbiVerbSC`
  - [ ] `MathLib`
  - [ ] `MatrixArray`
  - [ ] `SignalBox`
  - [ ] `SphericalDesign`
- [ ] Recompile class library (recommended after any move)

Paths:
- `downloaded-quarks`: `~/Library/Application Support/SuperCollider/downloaded-quarks`
- `Extensions`: `~/Library/Application Support/SuperCollider/Extensions`

### 4) Install custom SC extensions from this repo
- [ ] From `UHJ-Pi/supercollider/extensions/`, copy to `~/Library/Application Support/SuperCollider/Extensions/`:
  - [ ] `ServerMeter2/`
  - [ ] `Knob360/`
  - [ ] `MaplinMatrix/`
  - [ ] `MaplinSM333/`
  - Optional (only if you use them now): `FoaDimension/`, `FoaZSynthesis/`, `FoaVHAP/`
- [ ] Recompile class library

### 5) Apply core ATK edits (PHJ fix + 5.1.2)
- [ ] Replace ATK files with your modified versions (from your other machine or from this repo if present):
  - [ ] `ATK.sc` (contains `AtkKernelConv.ar` PHJ lane-aware convolution)
  - [ ] `FoaMatrix.sc` (adds `FoaDecoderMatrix.new5_2`)
- [ ] Target paths on macOS:
  - `~/Library/Application Support/SuperCollider/Extensions/atk-sc3/Classes/ATK.sc`
  - `~/Library/Application Support/SuperCollider/Extensions/atk-sc3/Classes/FoaMatrix.sc`
- [ ] Recompile class library and restart SC

Tip: backup originals first.

### 6) Install ATK assets (kernels, matrices, sounds)
Option A — Download via SC:
- [ ] In SC, evaluate:
  ```supercollider
  Atk.downloadKernels(); Atk.downloadMatrices(); Atk.downloadSounds();
  ```

Option B — Copy your known-good assets:
- [ ] Copy kernels/matrices to:
  - Kernels: `~/Library/Application Support/ATK/kernels/`
  - Matrices: `~/Library/Application Support/ATK/matrices/`
  - 5.1.2 path (example): `~/Library/Application Support/ATK/matrices/FOA/decoders/5_1_2/`
  - 5.0.2 path (new): `~/Library/Application Support/ATK/matrices/FOA/decoders/5_0_2/`
  - Sounds (optional tests): `~/Library/Application Support/ATK/sounds/`

### 7) Copy your custom PHJ/UHJ kernels (if different from stock)
- [ ] Copy your PHJ/UHJ kernel WAVs into the appropriate ATK folders, e.g.:
  - `~/Library/Application Support/ATK/kernels/FOA/encoders/phj/<fs>/<N>/0000/UHJ_{L,R,T,Q}.wav`
  - `~/Library/Application Support/ATK/kernels/FOA/encoders/uhj/...`

### 8) Install Reaper JSFX and matrices
- [ ] Copy JSFX to `~/Library/Application Support/REAPER/Effects/`:
  - [ ] `reaper/jsfx/ATK/...` (this repo)
  - [ ] Any custom PHJ encoder JSFX you used
- [ ] Copy decoder/encoder matrices (if used by JSFX) to your chosen folder, e.g.:
  - `~/Library/Application Support/REAPER/Data/ATK/` or within `Effects/ATK`

### 9) Verify SuperCollider
- [ ] In SC:
  ```supercollider
  FoaEncoderKernel.newPHJ;   // should succeed
  FoaDecoderMatrix.new5_2;   // should exist
  // Optional, if your build includes 5.0.2:
  // FoaDecoderMatrix.new5_0_2; // should exist
  ```
- [ ] Run your UHJ test (2‑ch L/R, T=0, Q=0) through PHJ encoder and check Z:
  - [ ] Confirm Z ≈ 0 for UHJ input (height silent)
  - If Z leaks, re‑check the `ATK.sc` PHJ section and kernel channel mapping.

### 10) Verify Reaper
- [ ] Load your test session or chain: UHJ → PHJ encoder → 5.1.2 decode
- [ ] Confirm: with UHJ input (L,R only), Z=0 and height channels are silent
 - [ ] If using 5.0.2, also verify your 5.0.2 decode matrices load and route correctly

### 11) Optional: App scripts/content
- [ ] Copy `UHJ-Pi/supercollider/app/*.scd` into your SC Extensions or run from repo
- [ ] Confirm GUI components (Knob360, ServerMeter2) load on macOS

### 12) Troubleshooting quick checks
- [ ] “new5_2 not understood” → ensure `FoaMatrix.sc` replaced and recompiled
- [ ] Z not zero on UHJ → verify `AtkKernelConv.ar` PHJ handling and kernel lane order
- [ ] Class not found → extension folder location and permissions

### 13) Files to provide from other machine (if not already here)
- [ ] Modified `ATK.sc` and `FoaMatrix.sc`
- [ ] Custom PHJ/UHJ kernel WAVs (if different from stock ATK)
- [ ] Reaper JSFX and matrices used in your workflow

---

When done, keep this checklist in `docs/` for future macOS setups.


