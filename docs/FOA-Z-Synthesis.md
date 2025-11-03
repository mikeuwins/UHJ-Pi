## FOA Z Synthesis – Design, Configuration, and Rationale

### Purpose
FOA Z Synthesis generates a plausible FOA `Z` (height) component from lateral energy when the original `Z` is missing or unsuitable (e.g., UHJ/PHJ material with weak or no Z). The plugin passes `W/X/Y` transparently and lets you switch between Original `Z` and Synthesised `Z`. The synthesised `Z` is gently decorrelated and can be blended with an ambience (reverb) return to enhance a height impression without intruding on direct sound.

### Quick Start
- Insert `FOA Z Synthesis` on a FOA track: channel order `W, X, Y, Z`.
- Set Height source to `Synthesised` if your input `Z` is weak/empty.
- Defaults tuned for smoothness vs presence:
  - Height amount 30%
  - Height delay 7 ms
  - Height trim 0 dB
  - Ambience size 2.5
  - Ambience damping 0.2
  - Ambience mix 70%

### Parameters
- **Height amount (%)** (`slider1`, default 30, range 0–100)
  - Scales the synthesised height energy derived from lateral components.

- **Height delay (ms)** (`slider2`, default 7, range 0–30)
  - Short decorrelation delay on the mid/high band of Synth `Z` to reduce inter-aural coherence and “fizz,” supporting a diffuse height impression.

- **Height trim (dB)** (`slider3`, default 0, range −12 to +12)
  - Final gain for the selected height channel (Original or Synth). Useful to match level to program material.

- **Height source** (`slider4`, default 1, options {Original, Synthesised})
  - Switch between the input `Z` and the Synthesised `Z`.

- **Ambience size** (`slider6`, default 2.5, range 0.1–3)
  - Controls the reverb time scaling and comb feedback normalization. Tuned to avoid metallic resonances while adding envelopment.

- **Ambience damping** (`slider7`, default 0.2, range 0–1)
  - High-frequency damping inside the ambience network to avoid brightness build‑up.

- **Ambience mix (%)** (`slider8`, default 70, range 0–100)
  - Linear wet/dry blend of the ambience return for the Synth path.

### Signal Flow (high level)
1. W/X/Y pass‑through unchanged. Original `Z` is also routed for selection.
2. Synth `Z` source: lateral energy from `X` and `Y` is combined; rectification removed to avoid distortion.
3. VHAP-style two‑band split on the Synth `Z` path: lows (below ~1.2 kHz) pass direct; mid/high band is decorrelated via short delay.
4. Mild soft limiter on Synth `Z` to avoid overload without harmonics.
5. Fixed −3 dB gain on Synth `Z` for headroom and blend parity vs Original `Z`.
6. High‑shelf attenuation on Synth `Z` (−5 dB at ~4 kHz) to reduce presence/edge.
7. B→A conversion: ambience processing runs in a simple Schroeder‑style network (multiple combs + allpasses), no predelay.
8. Post‑ambience shaping (A‑domain):
   - LPF at ~4.5 kHz to darken the return
   - Peaking EQ cut around 3 kHz (−8 dB, Q≈1) to tame mid harshness
9. A→B conversion: only `Z` is recomputed from the ambience stage; `W/X/Y` remain Original.
10. Height source selection (Original vs Synth), then Height trim is applied.

### Rationale and Design Notes
- **Why lateral energy (X+Y) for height?**
  - For typical content, lateral energy correlates with ambience and reverberant energy that psychoacoustically supports height when softly decorrelated and spectrally shaped.

- **Decorrelation delays**
  - Small delays (here ~7 ms by default) reduce coherence without producing discrete echoes; this increases spaciousness and reduces combing against the direct Z.

- **VHAP-style split (~1.2 kHz)**
  - Low frequencies are kept coherent (passed dry) to avoid LF mud or pumping in height. The mid/high band is decorrelated, which carries the spatial cues most effective for height impression.

- **Presence control**
  - We added a high‑shelf attenuation (−5 dB @ ~4 kHz) on the Synth `Z` and further darkened the ambience return (LPF 4.5 kHz + −8 dB peaking at ~3 kHz). This combination removed mid‑range glare and top‑end sheen while preserving clarity.

- **Predelay removed**
  - An earlier ~15 ms predelay made the ambience behave like a chorus/doubler at higher wet levels. Removing the predelay tightened the impression and reduced modulation artifacts.

- **HPF location**
  - We removed the `Z` HPF from this plugin to prevent bass leakage decisions here. LF management is handled in the downstream 5.1.2 decoder’s height path, which is better situated for global bass routing decisions.

- **Mix law**
  - Ambience mix uses a linear crossfade for predictable gain staging within the network, with separate spectral shaping of the return to avoid perceived level dips.

### Testing and Listening Notes
- Compared Synth `Z` against Original `Z` from PHJ material; targeted a smoother, less forward tonality.
- Removed rectification and used summed lateral signal to reduce “fizz” on the Synth path.
- Tuned VHAP split and added a soft clipper to prevent sporadic overload on peaks without adding obvious harmonics.
- Darkened the Synth `Z` and ambience return progressively: added a −5 dB @ 4 kHz high‑shelf on Synth, deepened a −8 dB @ 3 kHz peaking cut on the ambience, and lowered the ambience LPF to ~4.5 kHz.
- Eliminated ambience predelay to remove chorus/doubler perception at higher wet mixes.
- Final defaults (size 2.5, damping 0.2, mix 70%) matched the smoother Original PHJ `Z` in blind comparisons while preserving a convincing height wash.

### Practical Tips
- If the Synth feels too forward, reduce Height amount or increase damping; if too dull, raise the LPF cutoff slightly or reduce the −8 dB mid cut to −6 dB.
- If you hear modulation, reduce Height delay and keep Ambience mix ≤ 70%.
- For bass‑heavy material, rely on downstream decoder HPFs for height channels to control LF translation to ceiling speakers.

### References (psychoacoustics and processing)
- Ambisonics overview (including FOA and B‑format): [Ambisonics – Wikipedia](https://en.wikipedia.org/wiki/Ambisonics)
- Lateral energy and spaciousness: Blauert, J. “Spatial Hearing” (MIT Press). Also see summaries of directional bands and vertical localization cues.
- Precedence (Haas) effect and decorrelation for apparent source width: [Precedence effect – Wikipedia](https://en.wikipedia.org/wiki/Precedence_effect)
- Schroeder reverberation topology (combs + allpasses): Schroeder, M. R. (1962), “Natural sounding artificial reverberation.” Also see: [Schroeder reverb – Wikipedia](https://en.wikipedia.org/wiki/Schroeder_reverberator)
- RT60 definition and usage in reverberation design: [Reverberation – Wikipedia](https://en.wikipedia.org/wiki/Reverberation)
- Ambisonic matrices and Gerzon’s UHJ/PHJ notes: Gerzon, M. A. AES papers; see curated resources: [Ambisonics resources – Wikipedia](https://en.wikipedia.org/wiki/Ambisonics#References)

### Current Defaults (as shipped)
- Height amount: 30%
- Height delay: 7 ms
- Height trim: 0 dB
- Height source: Synthesised (toggle)
- Ambience size: 2.5
- Ambience damping: 0.2
- Ambience mix: 70%

### Changelog highlights (sound‑quality driven)
- Removed rectification; use summed lateral source to reduce distortion.
- Added VHAP two‑band split with decorrelated mid/high.
- Soft limiter on Synth `Z` to prevent harsh overloads.
- Moved HPF responsibility to 5.1.2 decoder; removed from this effect.
- Removed reverb predelay to eliminate chorus/doubler perception.
- Darkened Synth `Z` (−5 dB shelf @ 4 kHz) and ambience return (LPF 4.5 kHz, −8 dB @ 3 kHz).
- Tuned ambience defaults to size 2.5, damping 0.2, mix 70%.


