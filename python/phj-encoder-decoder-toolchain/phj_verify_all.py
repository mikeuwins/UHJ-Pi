#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PHJ Verify All — compact sweep with one-line ✓/✗ per (fs, N)

Scans:
  encoders/phj/<fs>/<N>/0000/UHJ_{L,R,T,Q}.wav
  decoders/phj/None/<N>/0000/UHJ_{W,X,Y,Z}.wav
  decoders/uhj/None/<N>/0000/UHJ_{W,X,Y}.wav

Runs tests:
  T1/T2  4-ch integrity + centring (≤ ±0.60 samples)
  T3     PHJ decoder vs LEGACY decoder parity (W/X/Y on L/R)
  T4'    Subcarrier pattern (decoder presence/absence + encoder sanity)
  T5     FOA isolation via ENC∘DEC (L/R shown ×2 for judging)

Outputs:
  • One compact line per set with ✓/✗ and plot name
  • CSV summary at ./phj_verify_summary.csv
  • Plot PNGs in ./phj_verify_plots/ (quiet: no auto-open)

Dependencies: numpy, soundfile, matplotlib
"""

import os, sys, math, glob, csv
from typing import Dict, Tuple, List, Optional
import numpy as np
import soundfile as sf
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ---------- Paths (ATK) ----------
ATK_ROOT     = os.path.expanduser("~/Library/Application Support/ATK/kernels/FOA")
ENC_BASE     = os.path.join(ATK_ROOT, "encoders", "phj")
DEC_BASE     = os.path.join(ATK_ROOT, "decoders", "phj", "None")
LEG_DEC_BASE = os.path.join(ATK_ROOT, "decoders", "uhj", "None")

PLOT_DIR = os.path.abspath("./phj_verify_plots")
CSV_PATH = os.path.abspath("./phj_verify_summary.csv")

# ---------- Thresholds (align with single-run verifier) ----------
CENTRE_MAX_ABS_SAMPLES = 0.60

# T3 parity vs legacy (for W/X/Y → L,R)
PARITY_MEDIAN_DB = 0.5
PARITY_RIPPLE_DB = 0.5
SILENCE_RMS_DBFS = -40.0

# T4' subcarrier pattern thresholds (realistic finite-FIR behaviour)
TQ_SILENT_TH = -50.0  # ≤ this = "silent"
TQ_ACTIVE_TH = -35.0  # ≥ this = "active"

# T5 isolation (ENC∘DEC with L/R ×2 display to undo UHJ ½)
F_LO   = 50.0
MID_LO = 200.0
MID_HI = 10000.0
HI_FRAC = 0.49   # up to 0.49*fs to avoid Nyquist edge

DIAG_MID_TOL_DB  = 1.0
DIAG_EDGE_TOL_DB = 1.5
XTALK_MID_MAX_DB = -30.0
XTALK_EDGE_MAX_DB = -25.0

DISPLAY_LR_X2 = True  # for plotting/judging only

# UI glyphs
TICK, CROSS = "✅", "❌"

# ---------- Utils ----------
def db(x: float, floor: float = 1e-30) -> float:
    return 20.0*math.log10(max(float(x), floor))

def rms(x: np.ndarray) -> float:
    x = np.asarray(x, np.float64)
    return math.sqrt(float(np.mean(x*x))) if x.size else 0.0

def center_of_energy(x: np.ndarray) -> float:
    x = np.asarray(x, np.float64)
    n = x.size
    if n == 0: return float("nan")
    e = x*x; s = float(np.sum(e))
    if s <= 0.0: return float("nan")
    idx = np.arange(n, dtype=np.float64)
    c = float(np.sum(idx*e)/s)
    return c - (n - 1.0)/2.0

def next_pow2(n: int) -> int:
    return 1 if n <= 1 else 1 << int(math.ceil(math.log2(n)))

def choose_nfft(L: int) -> int:
    return next_pow2(max(4096, 8*L))

def load_any(path: str) -> Tuple[np.ndarray, int]:
    x, fs = sf.read(path, always_2d=True)
    return x.astype(np.float64), int(fs)

def load4(path: str) -> Tuple[np.ndarray, int]:
    x, fs = load_any(path)
    if x.shape[1] != 4:
        raise RuntimeError(f"{os.path.basename(path)}: expected 4 channels, got {x.shape[1]}")
    return x, fs

def listdir_digits(path: str) -> List[str]:
    try:    return sorted([d for d in os.listdir(path) if d.isdigit()], key=lambda s:int(s))
    except FileNotFoundError: return []

def mag_db(h: np.ndarray, nfft: int) -> np.ndarray:
    H = np.fft.rfft(h, n=nfft, axis=0)
    return 20.0*np.log10(np.abs(H) + 1e-18)

def band_mask(freqs: np.ndarray, fs_hdr: int, lo=F_LO, hi_frac=HI_FRAC):
    return (freqs >= lo) & (freqs <= hi_frac*fs_hdr)

def conv(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return np.convolve(np.asarray(a, np.float64), np.asarray(b, np.float64))

# ---------- Discovery ----------
def discover_encoders_by_fs() -> Dict[str, Dict[str, Dict[str,str]]]:
    """
    Returns: { fs: { N: {filename: path, ...}, ... }, ... }
    """
    mapping: Dict[str, Dict[str, Dict[str,str]]] = {}
    if not os.path.isdir(ENC_BASE): return mapping
    for fs in listdir_digits(ENC_BASE):
        fsp = os.path.join(ENC_BASE, fs)
        Ns = {}
        for N in listdir_digits(fsp):
            d = os.path.join(fsp, N, "0000")
            files = {os.path.basename(p): p for p in glob.glob(os.path.join(d, "UHJ_*.wav"))}
            need = ["UHJ_L.wav","UHJ_R.wav","UHJ_T.wav","UHJ_Q.wav"]
            if all(n in files for n in need):
                Ns[N] = {n: files[n] for n in need}
        if Ns:
            mapping[fs] = Ns
    return mapping

def discover_decoders(N: str, base: str) -> Dict[str,str]:
    d = os.path.join(base, N, "0000")
    files = {os.path.basename(p): p for p in glob.glob(os.path.join(d, "UHJ_*.wav"))}
    if base == LEG_DEC_BASE:
        # Legacy: accept presence of W/X/Y (may be 2-ch or 4-ch)
        need = ["UHJ_W.wav","UHJ_X.wav","UHJ_Y.wav"]
        return {n: files[n] for n in files} if all(n in files for n in need) else {}
    else:
        need = ["UHJ_W.wav","UHJ_X.wav","UHJ_Y.wav","UHJ_Z.wav"]
        return {n: files[n] for n in need} if all(n in files for n in need) else {}

# ---------- T1/T2 ----------
def check_T1_T2(path: str, require_4ch: bool) -> bool:
    x, fs = load_any(path)
    ch_ok = (x.shape[1] == 4) if require_4ch else (x.shape[1] in (2,4))
    if not ch_ok: return False
    for i in range(x.shape[1]):
        xi = x[:,i]; r = rms(xi); c = center_of_energy(xi)
        if r >= 1e-12 and (not np.isnan(c)) and abs(c) > CENTRE_MAX_ABS_SAMPLES:
            return False
    return True

# ---------- T3: PHJ decoder vs legacy parity ----------
def t3_decoder_parity(phj_paths: Dict[str,str], leg_paths: Dict[str,str]) -> Tuple[bool, dict]:
    ok_all = True
    curves = []
    y0, fs = load4(phj_paths["UHJ_W.wav"])
    nfft = choose_nfft(y0.shape[0])
    freqs = np.linspace(0.0, fs/2.0, nfft//2 + 1)
    m = band_mask(freqs, fs)

    compare = [("UHJ_W.wav",[0,1]), ("UHJ_X.wav",[0,1]), ("UHJ_Y.wav",[0,1])]
    silent_expect = {"UHJ_W.wav":[2,3], "UHJ_Z.wav":[0,1,2]}

    for nm, lanes in compare:
        if nm not in leg_paths:
            ok_all = False
            continue
        P,_  = load4(phj_paths[nm])     # 4-ch
        Lg,_ = load_any(leg_paths[nm])  # 2-ch or 4-ch
        Pm = mag_db(P, nfft)
        Lm = mag_db(Lg, nfft)

        for ch in lanes:
            if Lm.shape[1] <= ch:  # legacy missing lane
                ok_all = False
                continue
            d = Pm[:,ch] - Lm[:,ch]
            med = float(np.median(d[m]))
            rip = float(np.max(d[m]) - np.min(d[m]))
            curves.append((f"{nm[:-4]} ch{ch+1}", freqs[m], d[m]))
            if not (abs(med) <= PARITY_MEDIAN_DB and rip <= PARITY_RIPPLE_DB):
                ok_all = False

    # Silence checks on PHJ expected-silent lanes
    for nm, idxs in silent_expect.items():
        if nm in phj_paths:
            Y,_ = load4(phj_paths[nm])
            for ch in idxs:
                if db(rms(Y[:,ch])) > SILENCE_RMS_DBFS:
                    ok_all = False

    details = {"freqs": freqs, "mask": m, "curves": curves}
    return ok_all, details

# ---------- T4': Subcarrier pattern ----------
def t4_subcarrier_pattern(enc_paths: Dict[str,str], dec_paths: Dict[str,str]) -> Tuple[bool, dict]:
    ok = True
    dec_levels = {}
    enc_levels = {}

    # Decoders: T (ch3), Q (ch4)
    for nm in ["UHJ_W.wav","UHJ_X.wav","UHJ_Y.wav","UHJ_Z.wav"]:
        Y,_ = load4(dec_paths[nm])
        t_db = db(rms(Y[:,2])); q_db = db(rms(Y[:,3]))
        dec_levels[nm] = (t_db, q_db)
        if nm in ["UHJ_W.wav","UHJ_X.wav","UHJ_Y.wav"]:
            if not ((t_db <= -35.0) and (q_db <= -50.0)): ok = False
        else:
            if not ((t_db <= -60.0) and (q_db >= -40.0)): ok = False

    # Encoders: for each FOA lane W/X/Y/Z, compare T vs Q
    Tm,_ = load4(enc_paths["UHJ_T.wav"])
    Qm,_ = load4(enc_paths["UHJ_Q.wav"])
    for k, name in enumerate(["W","X","Y","Z"]):
        t_db = db(rms(Tm[:,k])); q_db = db(rms(Qm[:,k]))
        enc_levels[name] = (t_db, q_db)
        t_silent = (t_db <= TQ_SILENT_TH)
        q_silent = (q_db <= TQ_SILENT_TH)
        t_active = (t_db >= TQ_ACTIVE_TH)
        q_active = (q_db >= TQ_ACTIVE_TH)
        if t_active and q_active: ok = False  # both active is not expected

    details = {"dec": dec_levels, "enc": enc_levels}
    return ok, details

# ---------- T5: isolation via ENC∘DEC ----------
def build_roundtrip(enc_files: Dict[str,str], dec_files: Dict[str,str]) -> Tuple[np.ndarray,int]:
    enc_order = ["UHJ_L.wav","UHJ_R.wav","UHJ_T.wav","UHJ_Q.wav"]  # inputs: L,R,T,Q
    dec_order = ["UHJ_W.wav","UHJ_X.wav","UHJ_Y.wav","UHJ_Z.wav"]  # FOA: W,X,Y,Z

    enc = {}; fs_e = None
    for nm in enc_order:
        x, fs = load4(enc_files[nm]); enc[nm] = x; fs_e = fs_e or fs
    dec = {}
    for nm in dec_order:
        x, _  = load4(dec_files[nm]); dec[nm] = x

    Nenc = next(iter(enc.values())).shape[0]
    Ndec = next(iter(dec.values())).shape[0]
    L = Nenc + Ndec - 1
    R_time = np.zeros((L,4,4), dtype=np.float64)  # [t, out i, in j]

    for j, nm_in in enumerate(enc_order):
        e = enc[nm_in]  # (Nenc,4) -> W,X,Y,Z
        for k, foa in enumerate(["W","X","Y","Z"]):
            a = e[:,k]
            d = dec[f"UHJ_{foa}.wav"]  # (Ndec,4) out L,R,T,Q
            for i in range(4):
                R_time[:,i,j] += conv(a, d[:,i])

    return R_time, fs_e

def judge_isolation(R_time: np.ndarray, fs: int) -> Tuple[bool, dict]:
    L = R_time.shape[0]
    nfft = choose_nfft(L)
    F = nfft//2 + 1
    freqs = np.linspace(0.0, fs/2.0, F)
    H = np.zeros((4,4,F), dtype=np.complex128)
    for i in range(4):
        for j in range(4):
            H[i,j,:] = np.fft.rfft(R_time[:,i,j], n=nfft)

    disp = 20.0*np.log10(np.abs(H)+1e-18)
    if DISPLAY_LR_X2:
        disp[0,:,:] += 20*np.log10(2.0)  # L row
        disp[1,:,:] += 20*np.log10(2.0)  # R row

    m_all  = (freqs >= F_LO) & (freqs <= HI_FRAC*fs)
    m_mid  = (freqs >= MID_LO) & (freqs <= min(MID_HI, HI_FRAC*fs))
    m_edge = m_all & ~m_mid

    diag_hi_mid = max(float(np.max(disp[i,i,m_mid])) for i in range(4)) if np.any(m_mid) else 0.0
    diag_lo_mid = min(float(np.min(disp[i,i,m_mid])) for i in range(4)) if np.any(m_mid) else 0.0
    diag_ok_mid = (diag_hi_mid <= +DIAG_MID_TOL_DB) and (diag_lo_mid >= -DIAG_MID_TOL_DB)

    diag_hi_edge = max(float(np.max(disp[i,i,m_edge])) for i in range(4)) if np.any(m_edge) else 0.0
    diag_lo_edge = min(float(np.min(disp[i,i,m_edge])) for i in range(4)) if np.any(m_edge) else 0.0
    diag_ok_edge = True if not np.any(m_edge) else ((diag_hi_edge <= +DIAG_EDGE_TOL_DB) and (diag_lo_edge >= -DIAG_EDGE_TOL_DB))

    od_max_mid = -999.0; od_max_edge = -999.0
    for i in range(4):
        for j in range(4):
            if i==j: continue
            if np.any(m_mid):  od_max_mid  = max(od_max_mid,  float(np.max(disp[i,j,m_mid])))
            if np.any(m_edge): od_max_edge = max(od_max_edge, float(np.max(disp[i,j,m_edge])))

    xt_ok_mid  = (od_max_mid  <= XTALK_MID_MAX_DB)  if np.any(m_mid) else True
    xt_ok_edge = (od_max_edge <= XTALK_EDGE_MAX_DB) if np.any(m_edge) else True

    ok = diag_ok_mid and xt_ok_mid and diag_ok_edge and xt_ok_edge
    details = {"freqs": freqs, "disp": disp, "m_mid": m_mid, "m_edge": m_edge}
    return ok, details

# ---------- Plot ----------
def impulse_thumbs(dec_files: Dict[str,str]) -> List[Tuple[str, np.ndarray]]:
    names = [("W→L", "UHJ_W.wav", 0), ("W→R","UHJ_W.wav",1),
             ("X→L","UHJ_X.wav",0), ("X→R","UHJ_X.wav",1),
             ("Z→Q","UHJ_Z.wav",3)]
    th = []
    for label, nm, ch in names:
        y,_ = load4(dec_files[nm]); x = y[:,ch]
        c = center_of_energy(x); c = int(round((len(x)-1)/2 + c))
        i0 = max(0, c-48); i1 = min(len(x), c+48)
        s = np.zeros(96); seg = x[i0:i1]
        s[:len(seg)] = seg
        th.append((label, s))
    return th

def make_plot(fs, N, t3_ok, t3d, t5d, outpath, dec_files):
    os.makedirs(PLOT_DIR, exist_ok=True)
    freqs = t5d["freqs"]; disp = t5d["disp"]; m_mid = t5d["m_mid"]; m_edge = t5d["m_edge"]

    fig = plt.figure(figsize=(13, 9))

    # A) Diagonals
    axA = plt.subplot(2,2,1)
    labels = ["L→L","R→R","T→T","Q→Q"]
    for i in range(4): axA.plot(freqs[m_mid], disp[i,i,m_mid], label=labels[i])
    if np.any(m_edge):
        for i in range(4): axA.plot(freqs[m_edge], disp[i,i,m_edge], alpha=0.3)
    axA.axhline(+DIAG_MID_TOL_DB, ls="--"); axA.axhline(-DIAG_MID_TOL_DB, ls="--")
    axA.set_ylim(-2.2, 2.2)
    axA.set_title("A) Round-trip diagonals (L/R shown ×2)")
    axA.set_xlabel("Hz"); axA.set_ylabel("dB"); axA.legend(fontsize=9)

    # B) Max off-diagonal
    axB = plt.subplot(2,2,2)
    F = disp.shape[2]; od = np.full(F, -999.0)
    for i in range(4):
        for j in range(4):
            if i==j: continue
            od = np.maximum(od, disp[i,j,:])
    axB.plot(freqs[m_mid], od[m_mid], label="midband")
    if np.any(m_edge): axB.plot(freqs[m_edge], od[m_edge], alpha=0.3, label="edges")
    axB.axhline(XTALK_MID_MAX_DB, ls="--")
    axB.set_ylim(-80, -15)
    axB.set_title("B) Max off-diagonal (dB)")
    axB.set_xlabel("Hz"); axB.set_ylabel("dB"); axB.legend(fontsize=9)

    # C) Parity curves (Δ magnitude vs freq) — restored
    axC = plt.subplot(2,2,3)
    curves = t3d.get("curves", [])
    if curves:
        for label, f, d in curves:
            axC.plot(f, d, label=label)
        axC.axhline(+PARITY_MEDIAN_DB, ls="--")
        axC.axhline(-PARITY_MEDIAN_DB, ls="--")
        axC.set_ylim(-1.5, 1.5)
        axC.set_title(f"C) Decoder vs legacy parity (Δ mag dB) — {'PASS' if t3_ok else 'FAIL'}")
        axC.set_xlabel("Hz"); axC.set_ylabel("Δ dB"); axC.legend(fontsize=8, ncols=2)
    else:
        axC.text(0.5,0.6,"T3 parity curves unavailable",ha="center",va="center",fontsize=11)
        axC.set_axis_off()

    # D) Impulse thumbnails
    axD = plt.subplot(2,2,4)
    axD.set_title("D) Impulse symmetry thumbnails")
    axD.set_xlabel("samples"); axD.set_ylabel("amplitude")
    for name, h in impulse_thumbs(dec_files):
        axD.plot(h, alpha=0.85, label=name)
    axD.legend(fontsize=8)

    fig.suptitle(f"PHJ Verify — fs={fs} N={N}",fontsize=14)
    fig.tight_layout(rect=[0,0.03,1,0.96])
    fig.savefig(outpath, dpi=120)
    plt.close(fig)

# ---------- Runner ----------
def run_one(fs: str, N: str,
            enc_files: Dict[str,str],
            dec_files: Dict[str,str],
            leg_files: Dict[str,str]) -> Tuple[bool,bool,bool,bool,str]:
    # T1/T2
    t12_ok = True
    for p in enc_files.values(): t12_ok &= check_T1_T2(p, True)
    for p in dec_files.values(): t12_ok &= check_T1_T2(p, True)
    for nm in ["UHJ_W.wav","UHJ_X.wav","UHJ_Y.wav"]:
        if nm in leg_files: t12_ok &= check_T1_T2(leg_files[nm], False)

    # T3
    t3_ok, t3_details = t3_decoder_parity(dec_files, leg_files)

    # T4'
    t4_ok, t4_details = t4_subcarrier_pattern(enc_files, dec_files)

    # T5
    R, fsE = build_roundtrip(enc_files, dec_files)
    t5_ok, t5_details = judge_isolation(R, fs=fsE)

    # Plot (quiet)
    os.makedirs(PLOT_DIR, exist_ok=True)
    out = os.path.join(PLOT_DIR, f"PHJ_verify_fs{fs}_N{N}.png")
    make_plot(fs, N, t3_ok, t3_details, t5_details, out, dec_files)

    return t12_ok, t3_ok, t4_ok, t5_ok, out

# ---------- Main ----------
def main():
    enc_by_fs = discover_encoders_by_fs()
    if not enc_by_fs:
        print(f"{CROSS} No encoders found at {ENC_BASE}")
        sys.exit(1)

    rows = []
    print("fs      N     T12  T3   T4   T5   plot")
    print("-------------------------------------------")

    for fs in sorted(enc_by_fs.keys(), key=lambda s:int(s)):
        for N in sorted(enc_by_fs[fs].keys(), key=lambda s:int(s)):
            enc = enc_by_fs[fs][N]
            dec = discover_decoders(N, DEC_BASE)
            leg = discover_decoders(N, LEG_DEC_BASE)

            if not dec or not leg:
                print(f"{fs:<7} {N:<5}  SKIP (missing decoders)")
                continue

            try:
                t12,t3,t4,t5,plot = run_one(fs, N, enc, dec, leg)
                print(f"{fs:<7} {N:<5}  {'✅' if t12 else '❌'}   {'✅' if t3 else '❌'}   {'✅' if t4 else '❌'}   {'✅' if t5 else '❌'}   {'✅' if os.path.exists(plot) else '❌'}  {os.path.basename(plot)}")
                rows.append([fs,N,int(t12),int(t3),int(t4),int(t5),plot])
            except Exception as e:
                print(f"{fs:<7} {N:<5}  ERROR {e}")

    # CSV
    with open(CSV_PATH,"w",newline="") as f:
        w = csv.writer(f)
        w.writerow(["fs","N","T12","T3","T4","T5","plot"])
        w.writerows(rows)

    print("\nSummary written:", CSV_PATH)

if __name__ == "__main__":
    main()
