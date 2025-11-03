## FOA Dimension Only – Design, Configuration, and Rationale

### Purpose
FOA Dimension Only applies Gerzon-style “Dimension” processing to FOA B-format (`W,X,Y,Z`) to enhance forward preference/width and apply simple psychoacoustic shelving. It outputs FOA again (`W',X',Y',Z'`) and is intended to be the last FOA-stage processor before decoding to speakers or binaural.

Key goals:
- Forward preference / width enhancement via a +90° phase-rotated `X` term injected into `Y` (Niemitalo 4× AP chain), with a protective HP on the injected path.
- Simple per-channel tilt shelves with optional Gerzon-inspired presets for 2D (`WXY`) or 3D (`WXYZ`).

### When to place in the chain
- Place immediately before FOA→speaker or FOA→binaural decoding. This ensures psycho shelves and dimension voicing affect the decoded scene consistently.
- Confirmed chain: `Z Synthesis → Dimension Only → 5.1.2/PHJ/binaural decoder`.

### Parameters (from JSFX)
- **Width (k)** (`slider1`, 0.00–0.70, default 0.00)
  - Scales the injected +90° `X` term into `Y`. Higher values increase forward preference and apparent width.

- **Width HP (Hz)** (`slider2`, 80–400 Hz, default 180)
  - One-pole high-pass applied to the injected path only, preventing LF tilt/pumping when emphasizing width.

- **Psycho Shelves Mode** (`slider3`, Off/2D/3D, default Off)
  - Off: no shelving.
  - 2D (WXY): tilt shelves on `W,X,Y` only.
  - 3D (WXYZ): includes `Z` shelves.
  - Recommendation: Use 2D for UHJ/Pantaphonic content, 3D for PHJ/Periphonic. Left Off by default so the user can choose per material.

- **Gerzon Presets** (`slider4`, Off/On, default 0=Off)
  - Enables channel-wise HF/LF offsets inspired by Gerzon’s psychoacoustics (see below).

- **Transition Freq (Hz)** (`slider5`, 100–3000 Hz, default 400)
  - Crossover for simple first-order tilt per channel. Below = LF band, above = HF band.
  - Confirmed preference: 400 Hz (per Gerzon’s recommendation in JAES, 1973).

- **LF Gain (dB)** (`slider6`, −6 to +6 dB, default 0)
- **HF Gain (dB)** (`slider7`, −6 to +6 dB, default 0)
  - Per-channel LF/HF gains are derived from these global gains plus preset offsets.

- **Output Trim (dB)** (`slider8`, −18 to +18 dB, default 0)
  - Post-processing gain on `W',X',Y',Z'`.

### Processing Flow (high level)
1. Inputs: `W,X,Y,Z`.
2. Compute `X` rotated by +90° using a 4× first-order all-pass cascade (Niemitalo constants).
3. Inject path HP (one-pole) at “Width HP (Hz)”.
4. Inject scaled term into `Y`: `inj = (x90 - HP(x90)) * k`; `Y' = Y + inj`; `W',X',Z'` pass through to this stage.
5. Simple per-channel tilt shelves:
   - First-order split around Transition Freq: lowpass state per channel.
   - Recombine with LF/HF gains for each channel.
   - Shelving on `Z` only when Psycho Shelves Mode is 3D.
6. Convert per-channel dB targets to linear gains once per @slider for efficiency; apply per-sample.
7. Output with Output Trim.

### Gerzon-inspired preset offsets (from code)
If presets are enabled:
- 3D HF targets: `W:+3.01 dB`, `X:+1.76 dB`, `Y:+1.76 dB`, `Z:+1.76 dB`.
- 2D HF targets: `W:+1.76 dB`, `X:−1.25 dB`, `Y:−1.25 dB`, `Z:+0.00 dB`.
- LF offsets: −60% of the HF offsets on each channel to maintain approximate power balance across the spectrum.

These are added to the global LF/HF gains before computing per-channel shelves.

### Rationale and Notes
- **Forward preference and width**: Injecting a +90° version of `X` into `Y` increases apparent width/ASW toward the front without strong coloration. The HP on the injected path keeps LF stable.
- **Simple shelves**: A gentle first-order tilt is used for transparency and to avoid phasey artifacts, with channel‑specific offsets to match Gerzon’s psychoacoustic guidance for 2D vs 3D images.
- **Efficiency**: All dB→linear conversions for shelves are precomputed in @slider, minimizing per-sample cost.

### Practical usage tips
- Start with `Width (k)=0.00` (default, no added width). Raise to `0.15–0.30` as needed; `Width HP=150–220 Hz` is a good range for subtle forward preference on music.
- Use `Psycho Shelves Mode=2D` for horizontal mixes; switch to `3D` when `Z` is prominent.
- If the scene gets bright/forward, reduce `HF Gain` or disable presets; if too dark, raise `HF Gain` by 1–2 dB and/or lower `Transition Freq` slightly.
- Keep this as the last FOA processor before decoding to preserve its global voicing.

### Testing and listening notes (session recap)
- Verified the Niemitalo AP chain (+90°) gave cleaner width than Hilbert approximations in this context.
- HP on the inject path reduced LF wobble when `k` is pushed.
- 3D preset provided a pleasant clarity lift when height content is active; 2D worked better for purely horizontal material.
- Works well upstream of both speaker and binaural decoders when placed last in FOA domain.

### References
- Gerzon, M. A. (1973), Periphony: With-Height Sound Reproduction, JAES.
- Pulkki, V. and others—ASW and spatial impression literature (overview in Blauert: Spatial Hearing).
- Niemitalo AP constants for wideband +90° phase rotation (public domain notes by Jarno Niemitalo).

### Defaults and recommendations
- Width (k): 0.00 by default (no added width unless required).
- Psycho Shelves Mode: Off by default. Use 2D for UHJ/Pantaphonic, 3D for PHJ/Periphonic.
- All other parameters: tune by ear for the program material.


