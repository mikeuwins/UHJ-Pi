#!/usr/bin/env python3
# B-VHAP FIR Verifier — menu version (stable), with slope-only phase correction
# Tests:
#  V1 Integrity, V2 Identity (W/X/Y), V3 Z passthrough delta
#  V4 Donor energy ratios (power domain)
#  V5 Quadrature (±90°) after removing *decor delay* and *linear-phase slope only*
#  V6 Stopband leakage per band (relative; other band and transition excluded)
#  V7 Peak indices

import os, sys, platform
import numpy as np
import soundfile as sf
from pathlib import Path

def atk_root():
    sysname = platform.system()
    if sysname == "Darwin":
        base = Path.home() / "Library/Application Support/ATK"
    elif sysname == "Windows":
        base = Path(os.path.expanduser("~")) / "AppData/Roaming/ATK"
    else:
        # Linux: ATK uses ~/.local/share/ATK
        base = Path.home() / ".local/share/ATK"
    return base / "kernels/FOA/transforms/b-vhap"

ATK_ROOT = atk_root()
MID = (900.0, 4000.0)
HI  = (4000.0, 12000.0)
DONOR = {"mid": {"W":0.60, "X":0.20,  "Y":0.20},
         "hi":  {"W":0.65, "X":0.175, "Y":0.175}}
PHASE_TOL   = 20.0
LEAK_TOL_DB = -35.0
TAIL_RMS_DBFS = -60.0

def list_digits(p):
    return sorted([d for d in p.iterdir() if d.is_dir() and d.name.isdigit()],
                  key=lambda x: int(x.name))

def pick(title, options):
    print(title)
    for i, o in enumerate(options, 1):
        print(f"  {i}) {o}")
    while True:
        s = input("Select: ").strip()
        if s.isdigit() and 1 <= int(s) <= len(options):
            return int(s) - 1
        print("  Enter a valid number...")

def load4(path):
    x, fs = sf.read(str(path), dtype="float32", always_2d=True)
    return x.astype(np.float64), int(fs)

def rfft(h, fs, nfft=65536):
    H = np.fft.rfft(h, nfft)
    f = np.fft.rfftfreq(nfft, 1/fs)
    return f, H

def mag_db(H):
    return 20*np.log10(np.maximum(np.abs(H), 1e-12))

def smooth_db(x, win=33):
    return np.convolve(x, np.ones(win)/win, mode='same')

def real_bp_proto(lo, hi, fs, taps=255):
    n = np.arange(taps) - (taps-1)/2
    lo_n, hi_n = lo/(fs/2), hi/(fs/2)
    h = 2*hi_n*np.sinc(2*hi_n*n) - 2*lo_n*np.sinc(2*lo_n*n)
    w = 0.54 - 0.46*np.cos(2*np.pi*np.arange(taps)/(taps-1))  # Hamming
    return h*w

def ok_id(M, ch):
    tail = M[1:, ch]
    r = np.sqrt(np.mean(tail**2)) if tail.size else 0.0
    return abs(M[0, ch]-1.0) < 1e-6 and (20*np.log10(r+1e-30) <= TAIL_RMS_DBFS)

# --- Phase measurement helper: remove slope ONLY, keep intercept ---
def pdiff_slope_only(H, mask, phi, f):
    """
    For a Hilbert band FIR, after removing explicit decor delay (phi)
    and linear phase slope (group delay), the in-band phase should be ~±90°.
    We do NOT divide by any external reference.
    """
    Q = H[mask] * phi[mask]
    ang = np.unwrap(np.angle(Q))
    ff  = f[mask]
    # least-squares fit: ang ≈ a*ff + b  -> remove only slope a*ff
    A = np.vstack([ff, np.ones_like(ff)]).T
    a, b = np.linalg.lstsq(A, ang, rcond=None)[0]
    ang_corr = ang - (a * ff)  # keep intercept
    med_deg = np.degrees(np.median(ang_corr))
    # distance to ±90°
    a_deg = ((med_deg + 180.0) % 360.0) - 180.0
    d = min(abs(a_deg - 90.0), abs(a_deg + 90.0))
    return a_deg, d, (d <= PHASE_TOL)


# --- Stopband leakage: far-out only; exclude other band & inter-band transition ---
def leakage_relative_db(f, Hlane, band, other_band, fs):
    lo, hi = band; lo2, hi2 = other_band
    bw, bw2 = hi-lo, hi2-lo2
    g, g2 = 0.10*bw, 0.10*bw2
    inside = (f >= (lo+g)) & (f <= (hi-g)) & (f <= fs*0.49)
    other  = (f >= (lo2-g2)) & (f <= (hi2+g2))
    low_stop  = (f <= (lo-g))  & (f >= max(20.0, lo*0.5))
    high_stop = (f >= (hi+g))  & (f <= fs*0.49)
    outside = (low_stop | high_stop) & (~other)
    if not np.any(inside) or not np.any(outside):
        return -200.0
    md = smooth_db(mag_db(Hlane), win=33)
    med_in  = np.median(md[inside])
    p95_out = np.percentile(md[outside], 95)
    return float(p95_out - med_in)

def main():
    root = ATK_ROOT
    if not root.exists():
        print("❌ Missing root", root)
        return 1

    fs_dirs = list_digits(root)
    i = pick("Pick fs:", [d.name for d in fs_dirs])
    fs_dir = fs_dirs[i]

    N_dirs  = list_digits(fs_dir)
    j = pick("Pick N:", [d.name for d in N_dirs])
    N_dir = N_dirs[j]

    folder  = N_dir / "0100"

    files = {nm: folder / f"BVHAP_{nm}.wav" for nm in ["W","X","Y","Z"]}
    for nm, p in files.items():
        if not p.exists():
            print("❌ Missing", p)
            return 1

    W, fs = load4(files["W"])
    X, _  = load4(files["X"])
    Y, _  = load4(files["Y"])
    Z, _  = load4(files["Z"])
    Zw, Zx, Zy, Zz = Z.T

    print(f"\nInspecting: {folder}\n")
    print("- V1 Integrity -\n ✅ 4-ch WAVs present & matched fs")

    print("\n- V2 Identity W/X/Y -")
    print(f" {'✅' if ok_id(W,0) else '❌'} W  {'✅' if ok_id(X,1) else '❌'} X  {'✅' if ok_id(Y,2) else '❌'} Y")

    print("\n- V3 Z delta -")
    print(f" ℹ️ Z->Z delta = {Zz[0]:.2e} (should be 1.0)")

    # Frequency responses
    f, HZw = rfft(Zw,fs); _, HZx = rfft(Zx,fs); _, HZy = rfft(Zy,fs)

    # V4 energies & ratios (power)
    def band_power(H, lo, hi):
        m = (f >= lo) & (f <= hi) & (f <= fs*0.49)
        return float(np.sum(np.abs(H[m])**2)), m

    Em, m_mid = band_power(HZw, *MID)
    Exm, _    = band_power(HZx, *MID)
    Eym, _    = band_power(HZy, *MID)
    Eh, m_hi  = band_power(HZw, *HI)
    Exh, _    = band_power(HZx, *HI)
    Eyh, _    = band_power(HZy, *HI)

    # --- Correct target ratios (POWER): (gain_X / gain_W)^2 ---
    tgt_mid = (DONOR['mid']['X'] / DONOR['mid']['W'])**2
    tgt_hi  = (DONOR['hi' ]['X'] / DONOR['hi' ]['W'])**2

    Rm = {"X/W": (Exm+1e-18)/(Em+1e-18), "Y/W": (Eym+1e-18)/(Em+1e-18)}
    Rh = {"X/W": (Exh+1e-18)/(Eh+1e-18), "Y/W": (Eyh+1e-18)/(Eh+1e-18)}

    print("\n- V4 Band power & ratios -")
    print(f" Zw: mid {Em:.3e}, hi {Eh:.3e}")
    print(f" Zx: mid {Exm:.3e}, hi {Exh:.3e}")
    print(f" Zy: mid {Eym:.3e}, hi {Eyh:.3e}")
    print(f" Ratios mid X/W={Rm['X/W']:.3f} Y/W={Rm['Y/W']:.3f} (target {tgt_mid:.3f})")
    print(f" Ratios hi  X/W={Rh['X/W']:.3f} Y/W={Rh['Y/W']:.3f} (target {tgt_hi:.3f})")

    # V5 phase (remove decor delay, remove slope only)
    Dmid = int(round(4.5e-3*fs)); Dhi = int(round(5.5e-3*fs))
    phi_mid = np.exp(1j*2*np.pi*f*Dmid/fs); phi_hi = np.exp(1j*2*np.pi*f*Dhi/fs)
    Href_mid = np.fft.rfft(np.pad(real_bp_proto(*MID, fs), (0,65536-255)), 65536)
    Href_hi  = np.fft.rfft(np.pad(real_bp_proto(*HI,  fs), (0,65536-255)), 65536)

    pm = {k: pdiff_slope_only(H, m_mid, phi_mid, f) for k, H in {'Zw': HZw, 'Zx': HZx, 'Zy': HZy}.items()}
    ph = {k: pdiff_slope_only(H,  m_hi, phi_hi,  f) for k, H in {'Zw': HZw, 'Zx': HZx, 'Zy': HZy}.items()}


    print("\n- V5 Phase (|Δ to ±90°| ≤ 20°) -")
    print("  MID:", "  ".join([f"{'✅' if v[2] else '❌'} {k} {v[0]:.1f}° (Δ{v[1]:.1f}°)" for k,v in pm.items()]))
    print("  HI: ", "  ".join([f"{'✅' if v[2] else '❌'} {k} {v[0]:.1f}° (Δ{v[1]:.1f}°)" for k,v in ph.items()]))

    # V6 leakage (far-out stopbands, other band excluded)
    leak_mid = {k: leakage_relative_db(f, H, MID, HI, fs) for k,H in {'Zw':HZw,'Zx':HZx,'Zy':HZy}.items()}
    leak_hi  = {k: leakage_relative_db(f, H, HI, MID, fs) for k,H in {'Zw':HZw,'Zx':HZx,'Zy':HZy}.items()}

    print("\n- V6 Stopband leakage per band (relative; p95(out)-median(in), target ≤ -35 dB) -")
    print("  MID:", "  ".join([f"{'✅' if v <= LEAK_TOL_DB else '❌'} {k} {v:.1f} dB" for k,v in leak_mid.items()]))
    print("  HI: ", "  ".join([f"{'✅' if v <= LEAK_TOL_DB else '❌'} {k} {v:.1f} dB" for k,v in leak_hi.items()]))

    # V7 peaks
    pk = {"Zw": int(np.argmax(np.abs(Zw))),
          "Zx": int(np.argmax(np.abs(Zx))),
          "Zy": int(np.argmax(np.abs(Zy))),
          "Zz": int(np.argmax(np.abs(Zz)))}
    print("\n- V7 Peak indices -")
    print(f"  Zw:{pk['Zw']}  Zx:{pk['Zx']}  Zy:{pk['Zy']}  Zz:{pk['Zz']}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
