
# b_vhap_plots.py — make a 4-up verification figure PDF for B‑VHAP kernels
# Usage example:
#   python3 b_vhap_plots.py --root "/Users/you/Library/Application Support/ATK/kernels/FOA/transforms/b-vhap" --fs 44100 --N 2048 --out bvhap_verif_44100_2048.pdf
#
# Pages:
#   1) Impulses (Zw, Zx, Zy) + zoomed Zw impulse showing anti‑symmetry (Type‑III Hilbert)
#   2) Magnitude responses with passband shading (MID=[900,4k], HI=[4k,12k])
#   3) In‑band phase after slope removal (should sit near ±90°)
#   4) Stopband leakage overview with annotations (p95(out) – median(in) per band)
#
import argparse, os
from pathlib import Path
import numpy as np
import soundfile as sf
import matplotlib.pyplot as plt

MID = (900.0, 4000.0)
HI  = (4000.0, 12000.0)

def rfft(h, fs, nfft=131072):
    H = np.fft.rfft(h, nfft)
    f = np.fft.rfftfreq(nfft, 1/fs)
    return f, H

def mag_db(x):
    return 20*np.log10(np.maximum(np.abs(x), 1e-12))

def slope_removed_phase(H, f, decor_delay_s=0.0, mask=None):
    z = H * np.exp(1j*2*np.pi*f*decor_delay_s)
    if mask is None:
        mask = np.ones_like(f, dtype=bool)
    ang = np.unwrap(np.angle(z[mask]))
    ff  = f[mask]
    A = np.vstack([ff, np.ones_like(ff)]).T
    a, b = np.linalg.lstsq(A, ang, rcond=None)[0]
    ang_corr = ang - (a*ff)
    return ff, np.degrees(ang_corr)

def band_mask(f, lo, hi, fs):
    g = 0.10*(hi-lo)
    inside = (f >= (lo+g)) & (f <= (hi-g)) & (f <= fs*0.49)
    low_stop  = (f <= (lo-g)) & (f >= max(20.0, lo*0.5))
    high_stop = (f >= (hi+g)) & (f <= fs*0.49)
    outside = low_stop | high_stop
    return inside, outside

def stopband_leak_db(md, f, lo, hi, fs):
    inside, outside = band_mask(f, lo, hi, fs)
    if not np.any(inside) or not np.any(outside):
        return np.nan
    med_in  = np.median(md[inside])
    p95_out = np.percentile(md[outside], 95)
    return float(p95_out - med_in)

def load_kernels(folder):
    files = {nm: folder/f"BVHAP_{nm}.wav" for nm in ["W","X","Y","Z"]}
    for nm,p in files.items():
        if not p.exists():
            raise FileNotFoundError(f"Missing {p}")
    W, fs = sf.read(str(files["W"]), dtype="float32", always_2d=True)
    X,_ = sf.read(str(files["X"]), dtype="float32", always_2d=True)
    Y,_ = sf.read(str(files["Y"]), dtype="float32", always_2d=True)
    Z,_ = sf.read(str(files["Z"]), dtype="float32", always_2d=True)
    # Z is 4ch: Zw,Zx,Zy,Zz
    return (Z[:,0], Z[:,1], Z[:,2], Z[:,3]), int(fs)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True, help="ATK b-vhap root (…/FOA/transforms/b-vhap)")
    ap.add_argument("--fs", type=int, required=True, help="samplerate folder, e.g. 44100")
    ap.add_argument("--N", type=int, required=True, help="partition length folder, e.g. 2048")
    ap.add_argument("--variant", default="0100", help="subfolder (default 0100)")
    ap.add_argument("--out", default="bvhap_verification_plots.pdf", help="output PDF path")
    ap.add_argument("--mid_delay_ms", type=float, default=4.5)
    ap.add_argument("--hi_delay_ms",  type=float, default=5.5)
    args = ap.parse_args()

    folder = Path(args.root)/str(args.fs)/str(args.N)/args.variant
    (Zw, Zx, Zy, Zz), fs = load_kernels(folder)

    # Page 1 — Impulses
    fig = plt.figure(figsize=(11.69, 8.27), dpi=150)
    t = np.arange(len(Zw))/fs
    for i,(sig,label) in enumerate([(Zw,"Zw (mid+hi)"),(Zx,"Zx (mid+hi)"),(Zy,"Zy (mid+hi)")], start=1):
        ax = fig.add_subplot(2,2,i)
        ax.plot(t*1000, sig)
        ax.set_title(f"Impulse: {label}")
        ax.set_xlabel("Time (ms)"); ax.set_ylabel("Amplitude")
        ax.grid(True, alpha=0.3)
    ax = fig.add_subplot(2,2,4)
    n = len(Zw); c = n//2; span = min(800, n//2-4)
    n0, n1 = c-span, c+span
    ax.plot((np.arange(n0,n1)-c)/fs*1000.0, Zw[n0:n1])
    ax.set_title("Zw impulse (zoom around centre — anti‑symmetric Type‑III)")
    ax.set_xlabel("Time around centre (ms)"); ax.set_ylabel("Amplitude")
    ax.axvline(0, color='k', lw=0.8, alpha=0.5); ax.grid(True, alpha=0.3)
    fig.tight_layout()

    # Page 2 — Magnitude
    fig2 = plt.figure(figsize=(11.69, 8.27), dpi=150)
    for i,(sig,label) in enumerate([(Zw,"Zw"),(Zx,"Zx"),(Zy,"Zy"),(Zz,"Z (delta)")], start=1):
        f, H = rfft(sig, fs)
        md = mag_db(H)
        ax = fig2.add_subplot(2,2,i)
        ax.plot(f, md)
        for (lo,hi),col in [(MID,'#dddddd'),(HI,'#eeeeee')]:
            ax.axvspan(lo, hi, color=col, alpha=0.8, lw=0)
        ax.set_title(f"Magnitude: {label}")
        ax.set_xlabel("Frequency (Hz)"); ax.set_ylabel("Magnitude (dB)")
        ax.set_xlim(20, fs*0.49); ax.set_xscale('log'); ax.set_ylim(-100, 10)
        ax.grid(True, which='both', alpha=0.3)
    fig2.tight_layout()

    # Page 3 — Phase (slope‑removed)
    fig3 = plt.figure(figsize=(11.69, 8.27), dpi=150)
    for i,(sig,label,delay_ms,band) in enumerate([(Zw,"Zw MID", args.mid_delay_ms, MID),
                                                  (Zw,"Zw HI",  args.hi_delay_ms,  HI),
                                                  (Zx,"Zx MID", args.mid_delay_ms, MID),
                                                  (Zy,"Zy HI",  args.hi_delay_ms,  HI)], start=1):
        f, H = rfft(sig, fs)
        inside,_ = band_mask(f, band[0], band[1], fs)
        ff, ph = slope_removed_phase(H, f, decor_delay_s=delay_ms/1000.0, mask=inside)
        ax = fig3.add_subplot(2,2,i)
        ax.plot(ff, ph)
        ax.axhline(90, color='k', ls='--', lw=0.8, alpha=0.5)
        ax.axhline(-90, color='k', ls='--', lw=0.8, alpha=0.5)
        ax.set_title(f"Phase (slope‑removed): {label}")
        ax.set_xlabel("Frequency (Hz)"); ax.set_ylabel("Degrees")
        ax.set_xscale('log'); ax.set_xlim(band[0], band[1]); ax.set_ylim(-180, 180)
        ax.grid(True, which='both', alpha=0.3)
    fig3.tight_layout()

    # Page 4 — Leakage
    fig4 = plt.figure(figsize=(11.69, 8.27), dpi=150)
    for i,(sig,label) in enumerate([(Zw,"Zw"),(Zx,"Zx"),(Zy,"Zy"),(Zz,"Z (delta)")], start=1):
        f, H = rfft(sig, fs); md = mag_db(H)
        l_mid = stopband_leak_db(md, f, MID[0], MID[1], fs)
        l_hi  = stopband_leak_db(md, f, HI[0],  HI[1],  fs)
        ax = fig4.add_subplot(2,2,i)
        ax.plot(f, md)
        for (lo,hi),col in [(MID,'#dddddd'),(HI,'#eeeeee')]:
            ax.axvspan(lo, hi, color=col, alpha=0.8, lw=0)
        ax.set_title(f"Leakage: {label}  (mid {l_mid:.1f} dB, hi {l_hi:.1f} dB)")
        ax.set_xlabel("Frequency (Hz)"); ax.set_ylabel("Magnitude (dB)")
        ax.set_xlim(20, fs*0.49); ax.set_xscale('log'); ax.set_ylim(-100, 10)
        ax.grid(True, which='both', alpha=0.3)
        ax.text(0.03, 0.08, "Shaded = passbands\nTarget leakage ≤ −35 dB",
                transform=ax.transAxes, fontsize=9,
                bbox=dict(boxstyle="round", fc="white", ec="0.7", alpha=0.9))
    fig4.tight_layout()

    out = Path(args.out)
    from matplotlib.backends.backend_pdf import PdfPages
    with PdfPages(out) as pdf:
        for figno in plt.get_fignums():
            pdf.savefig(plt.figure(figno))
    print(f"Saved plots to", out.resolve())

if __name__ == "__main__":
    main()
