<!--BEGIN:MD-->
# B-VHAP FIR Structure — Real vs. Complex Design

## 1. Overview

In Ambisonic processing, some transforms (e.g. PHJ, UHJ, or analytic Hilbert filters) require **complex-valued** convolution kernels, where each signal path is represented by **real and imaginary components**.  
Other transforms, such as the **B-VHAP (Vertical Hemispheric Amplitude Panning)** process, operate entirely in the **real domain** and can therefore use **real-valued FIRs**.  

This note clarifies the distinction and explains why the B-VHAP FIRs are stored as **4-channel, real-only WAV files**.

---

## 2. Analytic (Complex) FIRs in PHJ

For PHJ encoding and decoding, the goal is to preserve **phase-quadrature relationships** among Ambisonic components.

To do this, each channel uses an *analytic* representation:

$$
x_a(t) = x(t) + j\, \hat{x}(t)
$$

where \( \hat{x}(t) \) is the **Hilbert transform** of \( x(t) \), phase-shifted by \( 90^\circ \) across the entire audio band.

A PHJ kernel must therefore store **both real and imaginary parts** of each transfer function:

$$
h_a(t) = h_\mathrm{re}(t) + j\,h_\mathrm{im}(t)
$$

and the convolution becomes:

$$
y(t) = x_\mathrm{re}(t) * h_\mathrm{re}(t)
      - x_\mathrm{im}(t) * h_\mathrm{im}(t)
      + j\,[x_\mathrm{re}(t) * h_\mathrm{im}(t)
      + x_\mathrm{im}(t) * h_\mathrm{re}(t)]
$$

Hence the **real/imaginary (RE/IM) channel pairs** in PHJ WAV files such as  
`[LR_r, LR_i, TQ_r, TQ_i]`.  
These filters maintain analytic continuity for phase-accurate Ambisonic reconstruction.

---

## 3. Real-Valued FIRs in B-VHAP

By contrast, B-VHAP (after Lee’s model of *vertical hemispheric amplitude panning*) operates on **amplitude differences** between hemispheres rather than analytic phase vectors.

The transform synthesises a perceived elevation by redistributing spectral energy and time cues:

$$
Z'(t) = Z(t) + W(t)*h_{ZW}(t) + X(t)*h_{ZX}(t) + Y(t)*h_{ZY}(t)
$$

where each donor kernel \( h_{Zk}(t) \) is a **real-valued, band-limited, odd-symmetric** FIR designed to emulate a Hilbert-like phase shift *within a restricted band* (typically 0.9–12 kHz).

### 3.1 Band-Limited Hilbert Behaviour

The build script (`b_vhap_build_full.py`) generates **Type-III odd-symmetric FIRs** using Remez or windowed-sinc design.  
These filters satisfy the approximate quadrature condition inside their passbands:

$$
\mathcal{H}\{x(t)\} \approx x(t) * h_\mathrm{odd}(t)
$$

where \( h_\mathrm{odd}(t) \) is a *real* impulse response such that:

$$
H_\mathrm{odd}(f) \approx j \cdot \mathrm{sgn}(f)
$$

but only for \( f_1 < |f| < f_2 \).  
Thus, a **single real FIR** can provide the required \( 90^\circ \) phase shift in the cue band, without carrying a separate imaginary component.

---

## 4. Implications for Implementation

| Property | PHJ / Analytic Kernels | B-VHAP Kernels |
|-----------|-----------------------|----------------|
| Stored Channels | Real / Imaginary pairs | Real-only |
| FIR Symmetry | Type IV (even for re, odd for im) | Type III (odd-symmetric) |
| Runtime Convolution | Complex pair-wise | Single real convolution |
| Output | Complex (analytic) | Real signal |
| Domain | Phase-accurate analytic | Amplitude + band-limited phase cue |
| Primary Function | Encode / Decode FOA / PHJ | Add perceptual height via hemispheric amplitude panning |

Because the B-VHAP FIRs already include the required **band-limited quadrature** and **micro-delay** cues, the runtime plugin only needs to perform *real* convolutions with each donor path (W, X, Y).  
No complex arithmetic is required.

---

## 5. Practical Notes

- Each B-VHAP kernel set contains a single **four-channel WAV**:

```
[ ZW , ZX , ZY , Δ ]
```

  where the last channel Δ (Greek delta) is a unity delta for the Z passthrough path.

- These are convolved in the plugin as:

$$
Z'(t) = Z(t) + \sum_{k \in \{W,X,Y\}} k(t) * h_{Zk}(t)
$$

- All processing is **real-valued**, so JSFX and SuperCollider implementations can use
  straightforward time-domain or FFT-based convolution.

---

## 6. Summary

B-VHAP kernels differ fundamentally from PHJ analytic kernels:

1. They are **real-valued** and self-contained.  
2. Their band-limited, odd-symmetric design embeds the necessary phase rotation.  
3. Runtime convolution therefore requires **no real / imag pairing** and **no recombination step**.

The result is a computationally efficient, psychoacoustically valid transform that can sit naturally within the ATK FOA family without introducing complex arithmetic or phase-vector bookkeeping.

---
<!--END:MD-->
