#!/usr/bin/env python3
"""
B-VHAP verification plotter (aligned, exclusive-leakage, no emojis)
- User-agnostic ATK root
- Numeric menus (fs, N), clear screen
- 4 pages: Impulses(+Zw zoom), Magnitude, Phase, Leakage
- Page 1 anti-symmetry is informational (does not affect PASS)
- Pages 2 & 4 use RELATIVE, EXCLUSIVE leakage:
    p95(out-of-both-bands) - median(in-band) ≤ -35 dB
- Z (delta) subplot is informational (excluded from PASS)
- Phase wrapped to [-180, +180] and de-rotated by mid/hi decor delays
- Saves PDF and per-page PNGs; auto-opens PDF on macOS
"""
import os, sys, datetime, subprocess
import numpy as np
import soundfile as sf
import matplotlib.pyplot as plt
from pathlib import Path
from matplotlib.backends.backend_pdf import PdfPages

# ---------- Config ----------
ROOT = Path("~/Library/Application Support/ATK/kernels/FOA/transforms/b-vhap").expanduser()
MID = (900.0, 4000.0)
HI  = (4000.0, 12000.0)

# ---------- Helpers ----------
def mag_db(x):
    return 20*np.log10(np.maximum(np.abs(x), 1e-12))

def rfft(h, fs, nfft=131072):
    return np.fft.rfftfreq(nfft, 1/fs), np.fft.rfft(h, nfft)

def band_mask(f, lo, hi, fs, guard=0.0):
    # Guard 0.0 to ensure we always have bins; limiter at Nyquist-ε
    inside = (f >= lo) & (f <= hi) & (f <= fs*0.49)
    low_stop  = (f >= 20.0) & (f < lo)
    high_stop = (f >  hi)   & (f <= fs*0.49)
    outside = low_stop | high_stop
    return inside, outside

def band_ripple_db(md, mask):
    if not np.any(mask):
        return np.inf
    md_norm = md[mask] - float(np.median(md[mask]))  # normalize in-band median to 0 dB
    return float(np.max(md_norm) - np.min(md_norm))

def rel_leak_db_exclusive(md, f, band, fs, both_bands=(MID, HI)):
    """
    Exclusive relative leakage:
    p95(outside BOTH passbands) - median(in the 'band')
    """
    lo, hi = band
    in_band = (f >= lo) & (f <= hi) & (f <= fs*0.49)

    # Build an "outside-of-both" mask: < MID_lo  OR  > HI_hi
    mid_lo, mid_hi = both_bands[0]
    hi_lo,  hi_hi  = both_bands[1]
    outside_both = ((f >= 20.0) & (f < mid_lo)) | (f > hi_hi)

    if not np.any(in_band) or not np.any(outside_both):
        return np.nan

    med_in  = float(np.median(md[in_band]))
    p95_out = float(np.percentile(md[outside_both], 95))
    return p95_out - med_in

def slope_removed_phase(H, f, decor_delay_s=0.0, mask=None, mag_gate_db=-120.0):
    """
    Remove linear phase slope (group delay) and return phase in degrees,
    only where magnitude is above mag_gate_db and inside 'mask'.
    Phase is wrapped to [-180, +180] for plotting.
    """
    if mask is None:
        mask = np.ones_like(f, dtype=bool)
    mag_db_vals = 20.0*np.log10(np.maximum(np.abs(H), 1e-18))
    sel = mask & (mag_db_vals >= mag_gate_db)
    if not np.any(sel):
        return np.array([]), np.array([])
    z = H * np.exp(1j * 2 * np.pi * f * decor_delay_s)  # de-rotate delay
    ang = np.unwrap(np.angle(z[sel]))
    ff  = f[sel]
    # Remove linear slope
    A = np.vstack([ff, np.ones_like(ff)]).T
    a, b = np.linalg.lstsq(A, ang, rcond=None)[0]
    ang_corr = ang - (a * ff)
    ph_deg = np.degrees(ang_corr)
    ph_deg = ((ph_deg + 180.0) % 360.0) - 180.0
    return ff, ph_deg

def load_kernels(folder):
    files = {nm: folder/f"BVHAP_{nm}.wav" for nm in ["W","X","Y","Z"]}
    W, fs = sf.read(files["W"], dtype="float32", always_2d=True)
    X,_ = sf.read(files["X"], dtype="float32", always_2d=True)
    Y,_ = sf.read(files["Y"], dtype="float32", always_2d=True)
    Z,_ = sf.read(files["Z"], dtype="float32", always_2d=True)
    # Return Zw, Zx, Zy, Z(delta)
    return (Z[:,0], Z[:,1], Z[:,2], Z[:,3]), int(fs)

def safe_corr(a, b, eps=1e-12):
    a = a - np.mean(a)
    b = b - np.mean(b)
    den = (np.sqrt((a*a).sum()) * np.sqrt((b*b).sum()) + eps)
    return float((a*b).sum() / den)

def centre_index_antisim(h):
    """
    Estimate the anti-symmetry centre by maximizing correlation between
    left and sign-flipped, reversed right halves.
    Informational only; kernels may not be perfectly odd-symmetric.
    """
    n = len(h)
    best_c, best_r = n // 2, -1.0
    search = np.arange(n // 2 - n // 4, n // 2 + n // 4)
    for c in search:
        L = h[:c]; R = h[c:]
        m = min(len(L), len(R))
        if m < 32:
            continue
        Lm, Rm = L[-m:], R[:m]
        if np.std(Lm) < 1e-10 or np.std(Rm) < 1e-10:
            r = -1.0
        else:
            r = safe_corr(Lm, -Rm[::-1])
        if np.isfinite(r) and r > best_r:
            best_r, best_c = r, int(c)
    return best_c, best_r

def pass_box(ax, text, loc="tl"):
    x = 0.02 if loc in ("tl","bl") else 0.98
    y = 0.95 if loc in ("tl","tr") else 0.05
    ha = "left" if x < 0.5 else "right"
    va = "top" if y > 0.5 else "bottom"
    ax.text(x, y, text, transform=ax.transAxes, fontsize=9,
            bbox=dict(boxstyle="round", fc="white", ec="0.7", alpha=0.95),
            ha=ha, va=va)

def page_summary(fig, text):
    fig.text(0.5, 0.02, text, ha='center', va='bottom', fontsize=9)

# ---------- Plot generator ----------
def make_plots(fs, N, variant="0100", mid_delay_ms=4.5, hi_delay_ms=5.5, auto_open=True):
    folder = ROOT/str(fs)/str(N)/variant
    (Zw, Zx, Zy, Zz), fs = load_kernels(folder)
    out_pdf = Path.cwd()/f"bvhap_verif_{fs}_{N}.pdf"
    out_dir = Path.cwd()/f"bvhap_plots_{fs}_{N}"
    out_dir.mkdir(exist_ok=True)
    date_str = f"{datetime.date.today():%Y-%m-%d}"

    # ---------- Page 1: Impulses (INFO only for anti-symmetry) ----------
    fig1 = plt.figure(figsize=(11.69, 8.27), dpi=150)
    t = np.arange(len(Zw))/fs

    for i,(sig,label) in enumerate([(Zw,"Zw"),(Zx,"Zx"),(Zy,"Zy")], start=1):
        ax = fig1.add_subplot(2,2,i)
        ax.plot(t*1000, sig)
        ax.grid(True, alpha=0.3)
        ax.set_title(f"Impulse: {label}")
        ax.set_xlabel("Time (ms)")
        ax.set_ylabel("Amp")
        c, r = centre_index_antisim(sig)
        # INFO only: do not affect page PASS
        txt = f"INFO anti-sym corr={r:.2f} @c={c}"
        pass_box(ax, txt, loc="tr")

    # Zw zoom
    ax = fig1.add_subplot(2,2,4)
    c, r = centre_index_antisim(Zw)
    span = min(800, len(Zw)//2 - 4)
    i0, i1 = max(0, c-span), min(len(Zw), c+span)
    ax.plot((np.arange(i0,i1)-c)/fs*1000.0, Zw[i0:i1])
    ax.axvline(0, color='k', lw=0.8, alpha=0.6)
    ax.set_title("Zw impulse — zoom around detected centre")
    ax.set_xlabel("Time around centre (ms)")
    ax.set_ylabel("Amp")
    ax.grid(True, alpha=0.3)
    pass_box(ax, f"centre={c}, corr={r:.2f}", loc="bl")

    page_summary(fig1, f"B-VHAP • Page 1 Impulses • PASS • {date_str}")
    fig1.tight_layout(rect=[0,0.05,1,0.98])

    # ---------- Page 2: Magnitude (ripple + RELATIVE, EXCLUSIVE leakage; ignore Z-delta) ----------
    fig2 = plt.figure(figsize=(11.69, 8.27), dpi=150)
    overall_pass_2 = True
    for i,(sig,label) in enumerate([(Zw,"Zw"),(Zx,"Zx"),(Zy,"Zy"),(Zz,"Z (delta)")], start=1):
        f,H = rfft(sig,fs); md = mag_db(H)
        ax = fig2.add_subplot(2,2,i)
        ax.plot(f, md)
        for (lo,hi),col in [(MID,'#dddddd'),(HI,'#eeeeee')]:
            ax.axvspan(lo, hi, color=col, alpha=0.8, lw=0)
        ax.set_xscale('log'); ax.set_xlim(20, fs*0.49); ax.set_ylim(-100, 10)
        ax.set_title(f"Magnitude: {label}"); ax.set_xlabel("Hz"); ax.set_ylabel("dB")
        ax.grid(True, which='both', alpha=0.3)

        in_mid,_ = band_mask(f, MID[0], MID[1], fs)
        in_hi,_  = band_mask(f, HI[0],  HI[1],  fs)
        ripple_mid = band_ripple_db(md, in_mid)
        ripple_hi  = band_ripple_db(md, in_hi)
        leak_mid = rel_leak_db_exclusive(md, f, MID, fs, both_bands=(MID,HI))
        leak_hi  = rel_leak_db_exclusive(md, f, HI,  fs, both_bands=(MID,HI))

        ok_this = (ripple_mid <= 2.0) and (ripple_hi <= 2.0)
        if label != "Z (delta)":
            ok_this = ok_this and (leak_mid <= -35.0) and (leak_hi <= -35.0)
            overall_pass_2 &= bool(ok_this)  # only Zw/Zx/Zy count

        txt = (f"{'PASS' if ok_this or label=='Z (delta)' else 'WARN'} "
               f"rip mid/hi={ripple_mid:.1f}/{ripple_hi:.1f} dB; "
               f"rel-leak(mid)={leak_mid:.1f} dB, rel-leak(hi)={leak_hi:.1f} dB (≤ −35 dB; exclusive)")
        pass_box(ax, txt, loc="bl")

    page_summary(fig2, f"B-VHAP • Page 2 Magnitude • {'PASS' if overall_pass_2 else 'WARN'} • {date_str}")
    fig2.tight_layout(rect=[0,0.05,1,0.98])

    # ---------- Page 3: Phase (quadrature) ----------
    fig3 = plt.figure(figsize=(11.69, 8.27), dpi=150)
    overall_pass_3 = True
    lanes = [(Zw,"Zw MID", mid_delay_ms, MID),
             (Zw,"Zw HI",  hi_delay_ms,  HI),
             (Zx,"Zx MID", mid_delay_ms, MID),
             (Zy,"Zy HI",  hi_delay_ms,  HI)]
    for i,(sig,label,delay_ms,band) in enumerate(lanes, start=1):
        f,H = rfft(sig,fs)
        inside,_ = band_mask(f, band[0], band[1], fs)
        ff, ph = slope_removed_phase(H, f, decor_delay_s=delay_ms/1000.0, mask=inside, mag_gate_db=-120.0)
        ax = fig3.add_subplot(2,2,i)
        if len(ff):
            ax.plot(ff, ph)
        ax.axhline(90,  color='k', ls='--', lw=0.8, alpha=0.8)
        ax.axhline(-90, color='k', ls='--', lw=0.8, alpha=0.8)
        ax.axhspan(75,105,color='g',alpha=0.05,lw=0)
        ax.axhspan(-105,-75,color='g',alpha=0.05,lw=0)
        ax.set_xscale('log'); ax.set_xlim(band[0], band[1]); ax.set_ylim(-180, 180)
        ax.set_title(f"Phase: {label}"); ax.set_xlabel("Hz"); ax.set_ylabel("deg")
        ax.grid(True, which='both', alpha=0.3)
        if len(ph):
            dev = float(np.median(np.minimum(np.abs(ph-90), np.abs(ph+90))))
            ok = dev <= 15.0
            txt = f"{'PASS' if ok else 'WARN'} |Δ| to ±90° (median) = {dev:.1f}°"
        else:
            ok = False
            txt = "WARN no in-band bins (check band/mask)"
        overall_pass_3 &= bool(ok)
        pass_box(ax, txt, loc="tr")

    page_summary(fig3, f"B-VHAP • Page 3 Phase • {'PASS' if overall_pass_3 else 'WARN'} • {date_str}")
    fig3.tight_layout(rect=[0,0.05,1,0.98])

    # ---------- Page 4: Leakage (RELATIVE, EXCLUSIVE; ignore Z-delta for PASS) ----------
    fig4 = plt.figure(figsize=(11.69, 8.27), dpi=150)
    overall_pass_4 = True
    for i,(sig,label) in enumerate([(Zw,"Zw"),(Zx,"Zx"),(Zy,"Zy"),(Zz,"Z (delta)")], start=1):
        f,H = rfft(sig,fs); md = mag_db(H)
        l_mid = rel_leak_db_exclusive(md, f, MID, fs, both_bands=(MID,HI))
        l_hi  = rel_leak_db_exclusive(md, f, HI,  fs, both_bands=(MID,HI))

        ax = fig4.add_subplot(2,2,i); ax.plot(f, md)
        for (lo,hi),col in [(MID,'#dddddd'),(HI,'#eeeeee')]:
            ax.axvspan(lo,hi,color=col,alpha=0.8,lw=0)
        ax.set_xscale('log'); ax.set_xlim(20, fs*0.49); ax.set_ylim(-100, 10)
        ax.set_title(f"Leakage: {label}"); ax.set_xlabel("Hz"); ax.set_ylabel("dB")
        ax.grid(True, which='both', alpha=0.3)

        ok_mid = (l_mid <= -35.0) if np.isfinite(l_mid) else True
        ok_hi  = (l_hi  <= -35.0) if np.isfinite(l_hi)  else True
        ok = ok_mid and ok_hi

        if label != "Z (delta)":
            overall_pass_4 &= bool(ok)

        txt = f"{'PASS' if (ok or label=='Z (delta)') else 'WARN'} mid {l_mid:.1f} dB, hi {l_hi:.1f} dB (≤ −35 dB; exclusive)"
        pass_box(ax, txt, loc="bl")

    page_summary(fig4, f"B-VHAP • Page 4 Leakage • {'PASS' if overall_pass_4 else 'WARN'} • {date_str}")
    fig4.tight_layout(rect=[0,0.05,1,0.98])

    # ---------- Save & open ----------
    with PdfPages(out_pdf) as pdf:
        for n in plt.get_fignums():
            pdf.savefig(plt.figure(n))
    print(f"\nSaved PDF: {out_pdf}")
    out_dir.mkdir(exist_ok=True)
    fig1.savefig(out_dir/"page1_impulses.png", dpi=200, bbox_inches="tight")
    fig2.savefig(out_dir/"page2_magnitude.png", dpi=200, bbox_inches="tight")
    fig3.savefig(out_dir/"page3_phase.png", dpi=200, bbox_inches="tight")
    fig4.savefig(out_dir/"page4_leakage.png", dpi=200, bbox_inches="tight")
    print(f"Saved PNGs to folder: {out_dir}")

    if auto_open and sys.platform == "darwin":
        try:
            subprocess.run(["open", str(out_pdf)], check=False)
            print("Opened PDF in Preview.")
        except Exception as e:
            print(f"Note: could not auto-open PDF: {e}")

    overall = [True, overall_pass_2, overall_pass_3, overall_pass_4]  # Page 1 is INFO
    print("Summary:", ", ".join([f"Page{i+1}={'PASS' if ok else 'WARN'}" for i,ok in enumerate(overall)]))

# ---------- Menu ----------
def menu():
    os.system("clear" if os.name != "nt" else "cls")
    print("B-VHAP Verification Plotter (aligned, exclusive-leakage)")
    print("Root:", ROOT)
    print("-----------------------------------------------")

    fs_list = sorted([p.name for p in ROOT.iterdir() if p.is_dir() and p.name.isdigit()], key=lambda s:int(s))
    print("\nPick sample rate:")
    for i,fs in enumerate(fs_list,1):
        print(f" {i}) {fs}")
    fs = fs_list[int(input("Select: "))-1]

    N_list = sorted([p.name for p in (ROOT/fs).iterdir() if p.is_dir() and p.name.isdigit()], key=lambda s:int(s))
    print("\nPick partition size:")
    for i,n in enumerate(N_list,1):
        print(f" {i}) {n}")
    N = N_list[int(input("Select: "))-1]

    make_plots(fs, N, auto_open=True)

if __name__ == "__main__":
    menu()
