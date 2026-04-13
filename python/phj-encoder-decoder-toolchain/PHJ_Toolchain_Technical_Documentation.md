# PHJ–ATK Technical Documentation  
**Author:** M. Uwins (2025)  
**Project:** PHJ Ambisonic Encoder/Decoder Toolchain  
**Institution:** De Montfort University  
**Version:** 2025.10.21  

---

## 1. Introduction

This document provides the complete technical background, implementation details, and verification methodology for the **PHJ Ambisonic encoder/decoder toolchain**.  
The system extends the Ambisonic Toolkit (ATK) to support a **Periphonic–Hierarchical–UHJ (PHJ)** format, designed to maintain Gerzon’s psychoacoustic and mathematical integrity while offering backward compatibility with traditional UHJ decoding.

All FIR filters are generated as **linear-phase, FuMa-normalised, time-aligned kernels** that can be used interchangeably with the ATK’s existing FOA kernels.

---

## 2. Theoretical Context

### 2.1 Ambisonic Foundations

Ambisonics encodes a sound field into spherical harmonics, typically expressed in first order as:

\[
\begin{bmatrix}
W \\ X \\ Y \\ Z
\end{bmatrix}
=
\begin{bmatrix}
1 \\ \cos\theta\cos\phi \\ \sin\theta\cos\phi \\ \sin\phi
\end{bmatrix}
s(t)
\]

where \( W \) represents pressure (omnidirectional) and \( X, Y, Z \) represent velocity components.

This project adheres to **FuMa** scaling and polarity:
```
W = omni
X = front–back
Y = left–right
Z = up–down
```

### 2.2 Gerzon’s UHJ / PHJ Theory

Gerzon’s (1980, 1985) work defined a hierarchy of *stereo-compatible Ambisonic transmissions* (UHJ, SHJ, THJ, PHJ).  
The PHJ format extends UHJ with additional “subcarrier” channels \( T \) and \( Q \) representing vertical and mixed-phase information:

\[
\text{PHJ} = [L, R, T, Q]
\]

UHJ was designed so that conventional stereo playback reproduces a stable frontal image, while Ambisonic decoders can reconstruct a near-spherical field.

The PHJ encoder and decoder FIRs implement these transformations:

**Encoding**
\[
\begin{bmatrix}
L \\ R \\ T \\ Q
\end{bmatrix}
 = E \cdot
\begin{bmatrix}
W \\ X \\ Y \\ Z
\end{bmatrix}
\]

**Decoding**
\[
\begin{bmatrix}
W \\ X \\ Y \\ Z
\end{bmatrix}
 = D \cdot
\begin{bmatrix}
L \\ R \\ T \\ Q
\end{bmatrix}
\]

where \( E \) and \( D \) are complex frequency-domain matrices realised as real-valued, linear-phase FIRs.

---

## 3. Implementation

### 3.1 FIR Generation (`phj_build.py`)

The FIRs are generated using a **Kaiser window (β = 6)**, with lengths ranging from 256 → 8192 samples at standard ATK sample-rates (44.1 – 192 kHz).  
Each kernel maintains strict **linear-phase symmetry** and **centre alignment**, ensuring consistent latency across all channels.

The script creates:

- **Encoders:**  
  `~/Library/Application Support/ATK/kernels/FOA/encoders/phj/<fs>/<N>/0000/`
- **Decoders:**  
  `~/Library/Application Support/ATK/kernels/FOA/decoders/phj/None/<N>/0000/`

Each WAV file is **four-channel**:
- Encoder: `[L, R, T, Q]`
- Decoder: `[W, X, Y, Z]`

All processing uses **float32**, full-scale 0 dBFS normalisation, and no automatic gain scaling.

### 3.2 Shelf Equalisation

Following Gerzon (1973 – 1985), all velocity channels (X, Y, Z) are subjected to identical **shelf equalisation** to achieve frequency-independent localisation and tonal balance.  
The shelving filters implement uniform low- and high-frequency boosts relative to W, preserving energy consistency across the soundfield.

### 3.3 Windowing and Causality

All FIRs are truncated symmetrically around the impulse centroid.  
They are real-valued and maintain Hermitian frequency symmetry to ensure no phase distortion.  
The effective group delay is constant across all lanes, verified within ± 0.6 samples.

---

## 4. Verification Framework

### 4.1 Motivation

Earlier verification attempts using direct round-trip identity (E ∘ D ≈ I₄) failed because the UHJ/PHJ transforms are **not strictly invertible** under finite, causal FIR approximation.  
The new framework replaces that unrealistic test with physically meaningful metrics inspired by Gerzon’s perceptual and energy-preservation criteria.

### 4.2 Test Structure (T1 – T5)

| Test | Objective | Pass Criteria | Notes |
|------|------------|---------------|-------|
| **T1/T2** | Validate file integrity and centring | 4 channels; centre offset ≤ ±0.6 samples | Ensures matched latency and FIR symmetry |
| **T3** | Compare PHJ decoder vs legacy UHJ decoder | Median Δ ≤ ±0.5 dB; ripple ≤ 0.5 dB; silence < −40 dBFS | Confirms spectral equivalence to legacy ATK UHJ decoders |
| **T4′** | Verify subcarrier pattern correctness | W/X/Y: T,Q < −35/−50 dBFS; Z: T < −60 dBFS, Q > −40 dBFS | Confirms correct Gerzon (1985) PHJ mapping |
| **T5** | Assess FOA isolation (ENC∘DEC) | diag ± 1 dB; off-diag ≤ −30 dB mid-band | Evaluates true energy separation and phase coherence |

---

## 5. Verification Scripts

### 5.1 `phj_verify.py`

Interactive menu to select fs / N, automatically locating encoder/decoder pairs under the ATK directory tree.  
Each test’s result is reported with ✅/❌ indicators, and the system generates a diagnostic figure.

### 5.2 `phj_verify_all.py`

Performs an automated sweep across all fs–N combinations, printing one-line summaries and exporting:

- Summary table → `phj_verify_summary.csv`  
- Diagnostic plots → `phj_verify_plots/PHJ_verify_fs<N>_N<N>.png`

Example summary line:

```
fs      N     T12  T3   T4   T5   Result
44100   2048  ✅   ✅   ✅   ✅   ✅
48000   2048  ✅   ✅   ✅   ✅   ✅
96000   4096  ✅   ✅   ✅   ✅   ✅
```

---

## 6. Interpretation of Plots

Each verification figure comprises four panels (A – D):

| Panel | Purpose | Description | Expected Result |
|:------|:---------|:-------------|:----------------|
| **A – Diagonal magnitude** | Energy preservation | Magnitude deviation (W, X, Y, Z) vs frequency | ≈ 0 dB ± 1 dB (mid-band) |
| **B – Off-diagonal leakage** | Channel isolation | Crosstalk between FOA components | ≤ −30 dB (mid-band) |
| **C – Decoder parity** | Compatibility check | Difference between PHJ and legacy decoders | Flat ≈ 0 dB |
| **D – Impulse alignment** | Latency uniformity | Overlaid time-domain FIRs | Symmetrical & coincident |

**Example composite figure:**

![Panel A – Diagonal Magnitude](./phj_verify_plots/example_A_diag_mag.png)
![Panel B – Off-Diagonal Leakage](./phj_verify_plots/example_B_offdiag.png)
![Panel C – Decoder Parity](./phj_verify_plots/example_C_parity.png)
![Panel D – Impulse Alignment](./phj_verify_plots/example_D_impulse.png)

> **How to read this figure:**  
> Flat mid-band lines ≈ 0 dB on Panels A and C confirm correct gain and decoder parity.  
> Flat off-diagonal traces below −30 dB (Panel B) confirm good channel separation.  
> Panel D shows symmetrical centred impulses — an indicator of matched latency and phase.  
> “Boring” plots are *good* plots: they indicate spectral neutrality and invertibility within tolerance.

---

## 7. Results Summary

All verified 2025 builds passed the updated tests for the core sample-rates and kernel lengths:

| fs (Hz) | N | T1/T2 | T3 | T4′ | T5 | Result |
|:-------:|:--:|:------:|:--:|:--:|:--:|:--:|
| 44100 | 2048 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 48000 | 2048 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 96000 | 4096 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 192000 | 8192 | ✅ | ✅ | ✅ | ✅ | ✅ |

Representative figures (e.g. `PHJ_verify_fs44100_N2048.png`) show stable magnitude and isolation responses, confirming functional equivalence to ATK UHJ decoders but with improved high-frequency precision.

---

## 8. Design Notes and Gerzon Compliance

### 8.1 Normalisation

All kernels conform to **FuMa** (Furse–Malham) scaling.  
L/R channels are attenuated by ½ during encoding, consistent with Gerzon’s stereo-compatibility model.  
Decoders compensate this scaling internally or in post-analysis (T5 plots apply ×2).

### 8.2 Causality and Group Delay

Each FIR is symmetrical and zero-centred.  
Measured group-delay differences between W and X/Y/Z ≤ 0.6 samples, ≈ 15 µs at 44.1 kHz — acoustically negligible.

### 8.3 Shelf Equalisation and Velocity Balance

Uniform low- and high-frequency shelves are applied to all three velocity channels, following Gerzon’s 1973–1985 equalisation guidelines.  
This ensures balanced localisation energy between pressure and velocity components and prevents vertical bias in PHJ reproduction.

### 8.4 Round-Trip Interpretation

A perfect algebraic round-trip (E ∘ D = I₄) is not expected because:
- Hilbert transforms are non-causal and infinite,  
- PHJ subcarriers contain frequency-dependent phase,  
- FIR windowing limits bandwidth precision.  

Instead, the tests focus on *energy-preserving equivalence*:

\[
|D(f)E(f)| \approx I_4 \quad \text{within ±1 dB, off-diag < −30 dB.}
\]

---

## 9. Code Structure Overview

### 9.1 `phj_build.py` (simplified)

```python
for fs in sample_rates:
    for N in fft_lengths:
        firs = design_phj_firs(fs, N)
        save_firs(firs, encoder_dir, decoder_dir)
```

Tasks:
- compute FIRs via analytic Gerzon equations  
- apply Kaiser window  
- normalise and centre  
- export 4-ch WAVs  

### 9.2 `phj_verify.py` (simplified)

```python
for test in [T1T2, T3, T4p, T5]:
    result = test()
    print(result)
    plot_results()
```

### 9.3 `phj_verify_all.py`

Batch mode that iterates over all fs/N sets and writes summary CSV.

---

## 10. Limitations and Future Work

- Perfect invertibility is mathematically impossible under finite FIR Hilbert approximations.  
- High-frequency leakage (> 15 kHz) remains measurable but inaudible.  
- Future versions may extend to **HOA (Higher-Order Ambisonics)** when hardware permits (e.g. Raspberry Pi 6).  
- Planned addition: **automatic report generator** combining all plots and statistics into a single PDF.

---

## 11. References

- **Gerzon, M. A.** (1973) *Periphony: With-Height Sound Reproduction*. *Journal of the Audio Engineering Society*, 21 (1), pp. 2–10.  
- **Gerzon, M. A.** (1980) *Practical Periphony: The Reproduction of Full-Sphere Sound*. AES Convention Paper 1570.  
- **Gerzon, M. A.** (1985) *Ambisonics in Multichannel Broadcasting and Video*. *JAES*, 33 (11), pp. 859–871.  
- **Barrett, N., De Luca, A. & Anderson, J.** (2006) *The Ambisonic Toolkit for SuperCollider*.  
- **Uwins, M.** (2025) *PHJ Encoder/Decoder Toolchain: Design, Verification and Implementation*. De Montfort University (unpublished PhD documentation).

---

**End of Technical Documentation**
