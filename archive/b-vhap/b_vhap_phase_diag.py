#!/usr/bin/env python3
import os, sys, numpy as np, soundfile as sf, matplotlib.pyplot as plt
from pathlib import Path
from matplotlib.backends.backend_pdf import PdfPages

ROOT = Path("~/Library/Application Support/ATK/kernels/FOA/transforms/b-vhap").expanduser()
MID = (900.0, 4000.0)
HI  = (4000.0, 12000.0)

def rfft(h, fs, nfft=262144):
    return np.fft.rfftfreq(nfft, 1/fs), np.fft.rfft(h, nfft)
def mag_db(z):
    return 20*np.log10(np.maximum(np.abs(z), 1e-18))
def load(folder):
    files = {nm: folder/f"BVHAP_{nm}.wav" for nm in ["W","X","Y","Z"]}
    W, fs = sf.read(files["W"], dtype="float32", always_2d=True)
    X,_ = sf.read(files["X"], dtype="float32", always_2d=True)
    Y,_ = sf.read(files["Y"], dtype="float32", always_2d=True)
    Z,_ = sf.read(files["Z"], dtype="float32", always_2d=True)
    return (Z[:,0], Z[:,1], Z[:,2], Z[:,3]), int(fs)
def band_mask(f, lo, hi, fs):
    inside = (f >= lo) & (f <= hi) & (f <= fs*0.49)
    outside = ~inside & (f >= 20) & (f <= fs*0.49)
    return inside, outside
def phase_after_derotation(H, f, delay_s, mask, gate_db=None):
    z = H * np.exp(1j*2*np.pi*f*delay_s)
    sel = mask.copy()
    if gate_db is not None:
        sel = sel & (mag_db(H) >= gate_db)
    if not np.any(sel):
        return np.array([]), np.array([])
    ang = np.unwrap(np.angle(z[sel]))
    ff  = f[sel]
    A = np.vstack([ff, np.ones_like(ff)]).T
    a, b = np.linalg.lstsq(A, ang, rcond=None)[0]
    ang_corr = ang - (a*ff)
    return ff, np.degrees(ang_corr)
def main():
    fs_list = sorted([p.name for p in ROOT.iterdir() if p.is_dir() and p.name.isdigit()], key=lambda s:int(s))
    print("Pick sample rate:")
    for i,fs in enumerate(fs_list,1): print(f" {i}) {fs}")
    fs = fs_list[int(input("Select: "))-1]
    N_list = sorted([p.name for p in (ROOT/fs).iterdir() if p.is_dir() and p.name.isdigit()], key=lambda s:int(s))
    print("Pick partition size:")
    for i,n in enumerate(N_list,1): print(f" {i}) {n}")
    N = N_list[int(input("Select: "))-1]
    folder = ROOT/str(fs)/str(N)/"0100"
    (Zw, Zx, Zy, Zz), fsN = load(folder)
    fZw, HZw = rfft(Zw, fsN)
    fZx, HZx = rfft(Zx, fsN)
    fZy, HZy = rfft(Zy, fsN)
    lanes = [
        ("Zw MID", fZw, HZw, MID, 0.0045),
        ("Zw HI",  fZw, HZw, HI,  0.0055),
        ("Zx MID", fZx, HZx, MID, 0.0045),
        ("Zy HI",  fZy, HZy, HI,  0.0055),
    ]
    pdf_path = Path.cwd()/f"bvhap_phase_diag_{fs}_{N}.pdf"
    with PdfPages(pdf_path) as pdf:
        fig = plt.figure(figsize=(11.69, 8.27), dpi=120)
        for i,(name, f, H, band, dlay) in enumerate(lanes, start=1):
            inside,_ = band_mask(f, band[0], band[1], fsN)
            md = mag_db(H)
            n_inside = int(np.sum(inside))
            med_db = float(np.median(md[inside])) if n_inside else float("nan")
            min_db = float(np.min(md[inside])) if n_inside else float("nan")
            print(f"{name}: in-band bins={n_inside}, median={med_db:.1f} dB, min={min_db:.1f} dB")
            ax = fig.add_subplot(2,2,i)
            ff0, ph0 = phase_after_derotation(H, f, dlay, inside, gate_db=None)
            ff1, ph1 = phase_after_derotation(H, f, dlay, inside, gate_db=-120.0)
            if len(ff0): ax.plot(ff0, ph0, lw=1.0, label="no gate")
            if len(ff1): ax.plot(ff1, ph1, lw=1.0, ls="--", label="gate -120 dB")
            ax.axhline(90,  color="k", ls=":", lw=0.8)
            ax.axhline(-90, color="k", ls=":", lw=0.8)
            ax.set_xscale("log"); ax.set_xlim(band[0], band[1]); ax.set_ylim(-180, 180)
            ax.set_title(f"{name}  (bins={n_inside})")
            ax.set_xlabel("Hz"); ax.set_ylabel("deg")
            ax.grid(True, which="both", alpha=0.3)
            if len(ff0) or len(ff1): ax.legend(loc="best", fontsize=8)
        fig.tight_layout(); pdf.savefig(fig); plt.close(fig)
    print(f"\nSaved phase diagnostic PDF: {pdf_path}")
if __name__ == "__main__":
    main()
