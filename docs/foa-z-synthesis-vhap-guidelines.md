### FOA Z Synthesis – VHAP-inspired practical guidelines

These notes summarise VHAP principles adapted for first-order Ambisonics (FOA) Z synthesis without a speaker-domain round trip, with suggested practical ranges you can dial in quickly.

- **Goal**: Add a subtle, decorrelated, band‑limited ambience component to `Z` that conveys height without affecting `W/X/Y` localisation.

### Band‑limiting and bands of interest
- **High‑pass cutoff (to keep bass out of height)**
  - Start: 500–800 Hz; raise if bass creeps in.
  - Typical working points: 600 Hz (music), 800 Hz (speech/FX clarity).
  - Implementation: 1‑pole HPF (gentle) or 2‑pole if needed; 6–12 dB/oct total.

- **Upper emphasis band (elevation cues)**
  - Strongest elevation cues: roughly 1.5–6 kHz.
  - Keep some energy up to 8–10 kHz, then gently roll off to avoid brittleness.
  - Practical: add a 1‑pole LPF at 8–12 kHz or a gentle HF tilt of about −1 to −3 dB/oct above 5 kHz.

### Source derivation for Z
- **Prefer lateral/ambient content over centre‑dry**
  - Derive from `X` and `Y` (lateral components) and subtract a little of `W`.
  - Practical formula: `z_src = 0.707*(X + Y) − 0.25*W`.
  - Rationale: avoid strong centre/direct content and bass lift from `W`.

### Decorrelation and diffusion
- **Delay decorrelation**
  - Single short delay: 5–12 ms (music), up to 15 ms (FX). Avoid >20 ms to prevent audible echo.
  - If duplicating paths, vary each delay by ±1–3 ms to avoid combing.

- **All‑pass diffusion (optional, softens transients)**
  - Single all‑pass: 2–4 ms with feedback gain 0.4–0.6.
  - Blend: 10–30% diffuse mixed with direct high‑passed path before the delay.

### Spectral shaping to avoid brittleness
- **HF softening on Z only**
  - 1‑pole LPF at 8–12 kHz, or a shelving EQ of −2 to −4 dB above 8 kHz.
  - Keep upper‑mid (2–5 kHz) intact; that’s where elevation cues live.

### Levels and dynamics
- **Amount (send to Z)**
  - Start at 15–35% of the derived Z signal; push to 40–50% cautiously.
  - Listen in stereo/5.x downmix to ensure it stays subtle and doesn’t pull focus.

- **Z trim**
  - Keep trim near 0 dB; adjust ±3 dB to taste. Large boosts often sound artificial.

- **Soft limiting (only on Z synth path)**
  - Gentle soft clip (e.g., `tanh(k*x)/tanh(k)` with `k≈1.2–1.8`).
  - Goal: catch occasional peaks without audible distortion.

### Behaviour across formats
- **PHJ (non‑zero Z present)**
  - If blending with existing Z, use small amounts and consider equal‑power blending.
  - Keep synth Z 6–12 dB below original Z RMS to avoid dominance.

- **UHJ (Z≈0)**
  - Treat synth Z as an add‑in path; use linear mix or on/off selection rather than crossfading tricks.
  - Start at low amounts (15–25%) and tune HPF upwards if bass sneaks in.

### Sanity checks
- **No LF in height**: Verify negligible content <500 Hz on Z with a spectrum meter.
- **Mono compatibility**: Collapse to mono; height should largely disappear without artefacts.
- **Comb filtering**: Toggle the decorrelator; if you hear strong timbral swings, increase delay diversity or diffusion mix.
- **Brittleness**: If Z sounds edgy, raise LPF soften (lower its cutoff) or reduce amount by 5–10%.

### Suggested initial preset
- HPF cutoff: 700 Hz
- Decorrelate delay: 8 ms
- Diffuse mix: 20% (single 3 ms all‑pass, feedback 0.5)
- HF soften LPF: 10 kHz
- Amount: 30%
- Z trim: 0 dB

These values are conservative and typically translate across music, VO, and FX beds with minor tweaks.


