# b_vhap_build.py
# Build ATK-style FOA transform kernels for B-VHAP (analytic Hilbert band-pass Z injection)
# Writes to ~/Library/Application Support/ATK/kernels/FOA/transforms/b-vhap/<fs>/<N>/0100/
#
# ---------------------------------------------------------------------------
# THEORY REFERENCE (derivation of defaults from Hyunkook Lee's VHAP research)
# ---------------------------------------------------------------------------
# Goal: Synthesize a pseudo Z (vertical velocity) component from FOA (W,X,Y),
#       such that after decoding the percept matches VHAP "height" illusions.
#
# Core VHAP mechanisms (Lee 2011–2017):
#   • Elevation cues reside primarily above ~700–800 Hz; low-mid (<700 Hz) anchors base.
#   • Phase relation: ≈ +90° (quadrature) between base and height feeds in upper bands.
#   • Small inter-layer delays (≈ 3–6 ms) promote elevation/spaciousness without echoes.
#   • High band energy (>4 kHz) contributes "air" and perceived elevation spread.
#
# Mapping to B-VHAP (FOA component domain):
#   • Bands:
#       MID  = 900–4000 Hz  (main elevation sensitivity region)
#       HIGH = 4000–12000 Hz (air/brightness cues; upper limit non-critical >10 kHz)
#     -> Enforces exclusion of the boxy 400–800 Hz region from Z synthesis.
#   • Phase:
#       Implemented with analytic (Hilbert) band-pass FIRs → ~+90° across each band.
#   • Delays (post-quadrature):
#       MID  ≈ 4.5 ms, HIGH ≈ 5.5 ms (within 3–6 ms optimum; >7 ms risks echo/separation).
#   • Level (β scalars):
#       Perceptual "amount" controlled at runtime; default caps around 0.6–1.0 are typical.
#   • Guard HPF:
#       Runtime ≥900 Hz on injected Z (mirrors effective low-cut in VHAP stimuli).
#   • Velocity shelf parity (Gerzon):
#       Apply same LF/HF shelving to X, Y, and synthesized Z for timbral parity.
#
# Implementation notes:
#   • Each 4ch WAV maps input lanes [W,X,Y,Z] → the named FOA output (W/X/Y/Z).
#   • W/X/Y files are identities (delta impulses); Z file contains Z passthrough (delta)
#     plus delayed quadrature band-pass injections from W, X, Y lanes.
#   • Use one kernel pack per fs/N; control "amount" (β) at runtime in your JSFX/host.
#
# These defaults provide a literature-grounded starting point; fine-tune by ear per content.
# ---------------------------------------------------------------------------

import os, json, struct, numpy as np
from pathlib import Path

SR    = 48000
TAPS  = 97
BANDS = {"mid": (900.0, 4000.0), "hi": (4000.0, 12000.0)}
# Donor balances (W,X,Y) per band
aWm, aXm, aYm = 0.60, 0.20, 0.20
aWh, aXh, aYh = 0.65, 0.175, 0.175
# β scalars (leave =1.0; control "amount" at runtime in JSFX)
beta_m, beta_h = 1.0, 1.0
# Post-quadrature decor delays (ms)
Dmid_ms, Dhi_ms = 4.5, 5.5

def atk_root():
    import platform
    sys = platform.system()
    if sys == "Darwin":
        base = Path.home()/ "Library/Application Support/ATK"
    elif sys == "Windows":
        base = Path(os.path.expanduser("~")) / "AppData/Roaming/ATK"
    else:
        base = Path(os.path.expanduser("~/.config/ATK"))
    return base / "kernels/FOA/transforms/b-vhap"

def hamming(M):
    n = np.arange(M)
    return 0.54 - 0.46*np.cos(2*np.pi*n/(M-1))

def fir_bandpass(f1, f2, taps, sr):
    M = taps
    n = np.arange(M) - (M-1)/2
    fn1, fn2 = f1/(sr/2), f2/(sr/2)
    h = 2*fn2*np.sinc(2*fn2*n) - 2*fn1*np.sinc(2*fn1*n)
    h *= hamming(M)
    h /= np.sqrt(np.sum(h*h) + 1e-12)
    return h

def fir_hilbert(taps):
    M = taps
    n = np.arange(M) - (M-1)/2
    h = np.zeros(M)
    for i, k in enumerate(n):
        if abs(k) < 1e-12:
            h[i] = 0.0
        elif int(abs(k)) % 2 == 1:
            h[i] = 2.0/(np.pi*k)
        else:
            h[i] = 0.0
    h *= hamming(taps)
    h /= np.sqrt(np.sum(h*h) + 1e-12)
    return h

def make_analytic_bp(f1, f2, taps=TAPS, sr=SR):
    bp = fir_bandpass(f1, f2, taps, sr)
    hh = fir_hilbert(taps)
    h_im_full = np.convolve(bp, hh, mode="full")
    mid = len(h_im_full)//2
    half = taps//2
    h_im = h_im_full[mid-half:mid-half+taps].copy()
    h_im *= hamming(taps)
    # normalise approx unity in passband
    N=16384
    H = np.fft.rfft(h_im, N)
    freqs = np.fft.rfftfreq(N, 1/sr)
    m = (freqs>=f1)&(freqs<=min(f2, sr*0.49))
    scale = np.median(np.abs(H[m])) + 1e-12
    h_im /= scale
    return h_im.astype(np.float32)

def place_with_delay(dst, kernel, delay_samps):
    L = len(kernel)
    if delay_samps + L > len(dst):
        raise ValueError("Kernel exceeds destination length; increase L_out")
    dst[delay_samps:delay_samps+L] += kernel

def write_wav_float32(path, multich_data, sr):
    import wave
    L, C = multich_data.shape
    with wave.open(str(path), 'wb') as wf:
        wf.setnchannels(C)
        wf.setsampwidth(4)
        wf.setframerate(sr)
        wf.writeframes(multich_data.reshape(-1).tobytes())

def main():
    root = atk_root() / f"{SR}" / f"{TAPS}" / "0100"
    root.mkdir(parents=True, exist_ok=True)

    mid_lo, mid_hi = BANDS["mid"]
    hi_lo,  hi_hi  = BANDS["hi"]
    h_mid_im = make_analytic_bp(mid_lo, mid_hi, TAPS, SR)
    h_hi_im  = make_analytic_bp(hi_lo,  hi_hi,  TAPS, SR)

    Dmid = int(round(Dmid_ms*0.001*SR))
    Dhi  = int(round(Dhi_ms*0.001*SR))
    L_out = TAPS + max(Dmid, Dhi) + 1

    delta = np.zeros(L_out, dtype=np.float32); delta[0] = 1.0

    W = np.stack([delta, np.zeros_like(delta), np.zeros_like(delta), np.zeros_like(delta)], axis=1)
    X = np.stack([np.zeros_like(delta), delta, np.zeros_like(delta), np.zeros_like(delta)], axis=1)
    Y = np.stack([np.zeros_like(delta), np.zeros_like(delta), delta, np.zeros_like(delta)], axis=1)

    ZW = np.zeros(L_out, dtype=np.float32)
    ZX = np.zeros(L_out, dtype=np.float32)
    ZY = np.zeros(L_out, dtype=np.float32)

    place_with_delay(ZW, beta_m*aWm*h_mid_im, Dmid)
    place_with_delay(ZW, beta_h*aWh*h_hi_im,  Dhi)
    place_with_delay(ZX, beta_m*aXm*h_mid_im, Dmid)
    place_with_delay(ZX, beta_h*aXh*h_hi_im,  Dhi)
    place_with_delay(ZY, beta_m*aYm*h_mid_im, Dmid)
    place_with_delay(ZY, beta_h*aYh*h_hi_im,  Dhi)

    Z = np.stack([ZW, ZX, ZY, delta], axis=1)

    write_wav_float32(root/"BVHAP_W.wav", W, SR)
    write_wav_float32(root/"BVHAP_X.wav", X, SR)
    write_wav_float32(root/"BVHAP_Y.wav", Y, SR)
    write_wav_float32(root/"BVHAP_Z.wav", Z, SR)

    manifest = {
        "algo": "B-VHAP-analytic",
        "version": "1.0",
        "sr": SR,
        "taps": TAPS,
        "bands_hz": BANDS,
        "delays_ms": {"mid": Dmid_ms, "hi": Dhi_ms},
        "donor_gains": {
            "mid": {"W": aWm, "X": aXm, "Y": aYm},
            "hi":  {"W": aWh, "X": aXh, "Y": aYh}
        },
        "beta": {"mid": beta_m, "hi": beta_h},
        "lanes": "Each 4ch WAV maps inputs [W,X,Y,Z] → output; Z has Z passthrough + delayed quadrature W/X/Y injections."
    }
    (root/"manifest.json").write_text(json.dumps(manifest, indent=2))
    print("Wrote:", root)

if __name__ == "__main__":
    main()
