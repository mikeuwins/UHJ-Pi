#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PHJ FIR builder (4-channel interleaved per tap)
- Encoder (UHJ -> FOA): lanes [WX_r, WX_i, YZ_r, YZ_i]
- Decoder (FOA -> UHJ): lanes [LR_r, LR_i, TQ_r, TQ_i]

Writes IEEE float WAVs using `soundfile` (libsndfile). Install:
    pip install soundfile numpy

Default output root:
    ~/Library/Application Support/ATK/kernels/FOA
"""

from __future__ import annotations
import argparse
from pathlib import Path
import math
import numpy as np

try:
    import soundfile as sf   # ensures IEEE float WAV (WAVE_FORMAT_IEEE_FLOAT)
except Exception as e:
    raise SystemExit("ERROR: python 'soundfile' package is required (pip install soundfile).") from e


# ==============================
# Tunable constants (Gerzon-ish)
# ==============================

# Encoder (UHJ -> FOA) coefficients
# W = kW_S*S + j*( kW_Dj*D + kW_Tj*T )
# X = kX_S*S + j*( -kX_Dj*D - kX_Tj*T )
# Y = kY_D*D + kY_T*T + j*( kY_Sj*S )
# Z = G_Z * Q      (real)
kW_S   = 0.982
kW_Dj  = 0.197 * 0.828   # 0.163116
kW_Tj  = 0.197 * 0.768   # 0.151296

kX_S   = 0.419
kX_Dj  = 0.828
kX_Tj  = 0.768

kY_D   = 0.796
kY_T   = -0.676
kY_Sj  = 0.187

G_Z    = 1.0233          # Z from Q, encoder

# Decoder (FOA -> UHJ) coefficients (S/D/T/Q from W/X/Y/Z)
# S = sW*W + sX*X
# D = j*( dW*W + dX*X ) + dY*Y
# T = j*( tW*W + tX*X ) + tY*Y
# Q = qZ*Z
sW = 0.9396926
sX = 0.1855740
dW = -0.3420201
dX =  0.5098604
dY =  0.6554516
tW = -0.1432
tX =  0.6512
tY = -0.7071
qZ =  0.9772

# ==============================
# FIR primitives
# ==============================

def hilbert_fir(N: int, window: str = "hann") -> np.ndarray:
    """
    Length-N antisymmetric (Type-III-like) Hilbert impulse approximation:
    h[n] = 2/(pi*n) for odd n, 0 for even n; windowed and centred.
    Works for even N (typical ATK sizes).
    """
    if N < 8 or (N % 2) != 0:
        raise ValueError("Choose even N (e.g., 256, 512, 1024, ...).")
    M = N // 2
    n = np.arange(-M, M, dtype=np.float64)  # length N, centre at index M
    h = np.zeros(N, dtype=np.float64)
    odd = (n % 2 != 0)
    h[odd] = 2.0 / (math.pi * n[odd])  # zero at n=0 and even offsets

    if window == "hann":
        w = 0.5 - 0.5 * np.cos(2 * math.pi * np.arange(N) / (N - 1))
    elif window == "blackman":
        idx = np.arange(N, dtype=np.float64)
        w = 0.42 - 0.5 * np.cos(2 * math.pi * idx / (N - 1)) + 0.08 * np.cos(4 * math.pi * idx / (N - 1))
    elif window == "none":
        w = np.ones(N, dtype=np.float64)
    else:
        raise ValueError("window must be one of: hann, blackman, none")

    return (h * w).astype(np.float32)


def delta_impulse(N: int, gain: float = 1.0) -> np.ndarray:
    d = np.zeros(N, dtype=np.float32)
    d[N // 2] = np.float32(gain)
    return d


def write_wav4(path: Path, lanes4: list[np.ndarray], fs: int):
    """
    Write a 4-channel IEEE float WAV: lanes4 = [ch0, ch1, ch2, ch3], each length N.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    arr = np.stack([np.asarray(x, dtype=np.float32).reshape(-1) for x in lanes4], axis=1)
    sf.write(str(path), arr, samplerate=int(fs), subtype="FLOAT", format="WAV")


# ==============================
# Kernel builders
# ==============================

def build_encoder_family(atk_root: Path, fs: int, N: int, window: str):
    """
    Build UHJ->FOA encoder kernels as 4-ch interleaved per file.
    Lanes per tap: [WX_r, WX_i, YZ_r, YZ_i]
    Files: UHJ_{L,R,T,Q}.wav
    """
    out = atk_root / "encoders" / "phj" / str(fs) / str(N) / "0000"
    out.mkdir(parents=True, exist_ok=True)

    d = delta_impulse(N, 1.0)
    h = hilbert_fir(N, window=window)

    # Helper to assemble lanes from S, D, T, Q "unit" choices
    def lanes_from_inputs(S: float, D: float, T: float, Q: float):
        # W impulse: real delta + Hilbert terms
        W_lane = (kW_S * S) * d + (kW_Dj * D + kW_Tj * T) * h
        # X impulse: real delta + Hilbert with negative sign per spec
        X_lane = (kX_S * S) * d + (-kX_Dj * D - kX_Tj * T) * h
        # Y impulse: real delta terms + Hilbert on S
        Y_lane = (kY_D * D + kY_T * T) * d + (kY_Sj * S) * h
        # Z impulse: only from Q, no Hilbert
        Z_lane = (G_Z * Q) * d
        return [W_lane, X_lane, Y_lane, Z_lane]

    # Inputs as unit impulses, but note S=(L+R)/2, D=(L-R)/2
    # L-only: S=+1/2, D=+1/2, T=0, Q=0
    lanes_L = lanes_from_inputs(S=0.5, D=+0.5, T=0.0, Q=0.0)
    write_wav4(out / "UHJ_L.wav", lanes_L, fs)

    # R-only: S=+1/2, D=-1/2
    lanes_R = lanes_from_inputs(S=0.5, D=-0.5, T=0.0, Q=0.0)
    write_wav4(out / "UHJ_R.wav", lanes_R, fs)

    # T-only
    lanes_T = lanes_from_inputs(S=0.0, D=0.0, T=1.0, Q=0.0)
    write_wav4(out / "UHJ_T.wav", lanes_T, fs)

    # Q-only
    lanes_Q = lanes_from_inputs(S=0.0, D=0.0, T=0.0, Q=1.0)
    write_wav4(out / "UHJ_Q.wav", lanes_Q, fs)


def build_decoder_family(atk_root: Path, N: int, window: str, fs_write: int = 44100):
    """
    Build FOA->UHJ decoder kernels as 4-ch interleaved per file.
    Lanes per tap: [LR_r, LR_i, TQ_r, TQ_i]  => L, R, T, Q
    Files under: decoders/phj/None/N/0000/UHJ_{W,X,Y,Z}.wav
    Note: WAV fs is nominal only; Rea convolution is time-invariant.
    """
    out = atk_root / "decoders" / "phj" / "None" / str(N) / "0000"
    out.mkdir(parents=True, exist_ok=True)

    d = delta_impulse(N, 1.0)
    h = hilbert_fir(N, window=window)

    # For a given FOA unit input, construct L, R, T, Q directly.
    # L = 0.5*S + 0.5*D ;  R = 0.5*S - 0.5*D
    # S real terms use delta; D's j-terms use Hilbert (h).
    def write_W():
        # S from W: sW * δ
        # D from W: j*dW * h
        L = 0.5 * sW * d + 0.5 * dW * h
        R = 0.5 * sW * d - 0.5 * dW * h
        # T from W: j*tW * h  (real lane carries T)
        T = tW * h
        # Q from W: 0
        Q = 0.0 * d
        write_wav4(out / "UHJ_W.wav", [L, R, T, Q], fs_write)

    def write_X():
        # S from X: sX * δ
        # D from X: j*dX * h
        L = 0.5 * sX * d + 0.5 * dX * h
        R = 0.5 * sX * d - 0.5 * dX * h
        # T from X: j*tX * h
        T = tX * h
        Q = 0.0 * d
        write_wav4(out / "UHJ_X.wav", [L, R, T, Q], fs_write)

    def write_Y():
        # S from Y: 0
        # D from Y: dY * δ  (real, no Hilbert)
        L = 0.5 * dY * d
        R = -0.5 * dY * d
        # T from Y: tY * δ (real)
        T = tY * d
        Q = 0.0 * d
        write_wav4(out / "UHJ_Y.wav", [L, R, T, Q], fs_write)

    def write_Z():
        # Only Q from Z: qZ * δ (imag lane of TQ pair carries Q)
        L = 0.0 * d
        R = 0.0 * d
        T = 0.0 * d
        Q = qZ * d
        write_wav4(out / "UHJ_Z.wav", [L, R, T, Q], fs_write)

    write_W(); write_X(); write_Y(); write_Z()


# ==============================
# CLI
# ==============================

def parse_args():
    p = argparse.ArgumentParser(description="Build PHJ FIR kernels (4-ch interleaved).")
    p.add_argument("--atk-foa-root",
                   default=str(Path.home() / "Library" / "Application Support" / "ATK" / "kernels" / "FOA"),
                   help="Root folder for ATK FOA kernels.")
    p.add_argument("--fs", nargs="+", type=int, default=[44100, 48000, 88200, 96000, 176400, 192000],
                   help="Sample rates to build (encoder only).")
    p.add_argument("--N", nargs="+", type=int, default=[256, 512, 1024, 2048, 4096, 8192],
                   help="Kernel sizes (even).")
    p.add_argument("--window", choices=["hann", "blackman", "none"], default="hann",
                   help="Window for Hilbert FIR.")
    return p.parse_args()


def main():
    args = parse_args()
    atk_foa_root = Path(args.atk_foa_root)

    print("PHJ build starting…")
    print(f"  ATK FOA root: {atk_foa_root}")
    print(f"  fs: {args.fs}")
    print(f"  N:  {args.N}")
    print(f"  Window: {args.window}\n")

    for N in args.N:
        # Decoder first (fs-agnostic)
        print(f"  Decoder  N={N:>5}  →  {atk_foa_root/'decoders'/'phj'/'None'/str(N)/'0000'}")
        build_decoder_family(atk_foa_root, N, window=args.window)

        # Encoders per fs
        for fs in args.fs:
            print(f"  Encoder  fs={fs:<6} N={N:<5} →  {atk_foa_root/'encoders'/'phj'/str(fs)/str(N)/'0000'}")
            build_encoder_family(atk_foa_root, fs, N, window=args.window)

    print("\nDone.")


if __name__ == "__main__":
    main()
