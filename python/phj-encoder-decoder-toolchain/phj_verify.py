#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PHJ FIR Verifier — ATK-only (fs→N), with Subcarrier Pattern (T4') and informative plots

Flow:
  1) Pick encoder sample rate (fs)
  2) Pick FFT length (N) available for that fs (encoders)
  3) Decoder N is auto-matched (same N)
  4) Tests:
     T1/T2  4-ch integrity + centring (≤ ±0.60 samples)
     T3     PHJ decoder vs LEGACY decoder spectral parity (W/X/Y on L/R)
             • legacy UHJ decoders may be 2-ch (L/R) or 4-ch
             • silence checks on PHJ lanes that should be near-silent
     T4'    Subcarrier pattern (presence/absence of T/Q lanes as designed)
             • Decoders:
                 UHJ_W/X/Y: T ≤ −35 dBFS and Q ≤ −50 dBFS (tiny T residue allowed)
                 UHJ_Z:     T ≤ −60 dBFS AND Q ≥ −40 dBFS
             • Encoders (per FOA lane W/X/Y/Z using UHJ_T.wav & UHJ_Q.wav):
                 - both < −50 dBFS → ℹ️ unused
                 - exactly one ≥ −35 dBFS (other ≤ −50 dBFS) → ✅
                 - both ≥ −35 dBFS → ❌ (unexpected dual activation)
                 - otherwise → ℹ️ borderline (−50..−35 dBFS)
     T5     FOA isolation via ENC∘DEC round-trip
             • L/R are displayed ×2 (undo UHJ ½) to judge mapping, not stereo gain

Output:
  • One combined PNG per run in ./phj_verify_plots/ (auto-opened with `open -g` on macOS)
  • Console shows ✓/✗/ℹ️ and brief reasons

ATK paths (fixed):
  encoders/phj/<fs>/<N>/0000/UHJ_{L,R,T,Q}.wav
  decoders/phj/None/<N>/0000/UHJ_{W,X,Y,Z}.wav
  decoders/uhj/None/<N>/0000/UHJ_{W,X,Y}.wav   (legacy decoders; 2-ch or 4-ch)

Dependencies: numpy, soundfile, matplotlib
"""

import os, sys, math, glob, platform, subprocess
from typing import Dict, Tuple, List, Optional
import numpy as np
import soundfile as sf
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ====== ATK locations ======
ATK_ROOT = os.path.expanduser("~/Library/Application Support/ATK/kernels/FOA")
ENC_BASE = os.path.join(ATK_ROOT, "encoders", "phj")
DEC_BASE = os.path.join(ATK_ROOT, "decoders", "phj", "None")
LEG_DEC_BASE = os.path.join(ATK_ROOT, "decoders", "uhj", "None")

PLOT_DIR = os.path.abspath("./phj_verify_plots")

# ====== Thresholds / bands ======
CENTRE_MAX_ABS_SAMPLES = 0.60

# T3 parity vs legacy (for W/X/Y → L,R lanes)
PARITY_MEDIAN_DB = 0.5
PARITY_RIPPLE_DB = 0.5
SILENCE_RMS_DBFS = -40.0

# T4' subcarrier pattern thresholds (real-world, finite FIRs)
TQ_SILENT_TH = -50.0  # ≤ this = "silent"
TQ_ACTIVE_TH = -35.0  # ≥ this = "active"

# T5 isolation (ENC∘DEC with L/R ×2 display to undo UHJ ½)
F_LO = 50.0
MID_LO = 200.0
MID_HI = 10000.0
HI_FRAC = 0.49   # up to 0.49*fs to avoid Nyquist edge

DIAG_MID_TOL_DB = 1.0
DIAG_EDGE_TOL_DB = 1.5
XTALK_MID_MAX_DB = -30.0
XTALK_EDGE_MAX_DB = -25.0

DISPLAY_LR_X2 = True  # show L/R ×2 (undo UHJ ½) on plots to judge mapping, not stereo gain

# UI glyphs
TICK, CROSS, INFO = "✅", "❌", "ℹ️"

# ====== Helpers ======
def clear_screen():
    try: os.system("cls" if os.name == "nt" else "clear")
    except Exception: pass

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

def conv(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return np.convolve(np.asarray(a, np.float64), np.asarray(b, np.float64))

def listdir_digits(path: str) -> List[str]:
    try:
        return sorted([d for d in os.listdir(path) if d.isdigit()], key=lambda s:int(s))
    except FileNotFoundError:
        return []

def pick(title: str, options: List[str]) -> int:
    print(f"\n{title}")
    for i,op in enumerate(options, 1): print(f"  {i}) {op}")
    while True:
        s = input("Select: ").strip()
        if s.isdigit():
            k = int(s)
            if 1 <= k <= len(options): return k-1
        print("  Enter a valid number…")

# ====== Discovery ======
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
        # Legacy: accept stereo; require W/X/Y exist
        need = ["UHJ_W.wav","UHJ_X.wav","UHJ_Y.wav"]
        return {n: files[n] for n in files} if all(n in files for n in need) else {}
    else:
        need = ["UHJ_W.wav","UHJ_X.wav","UHJ_Y.wav","UHJ_Z.wav"]
        return {n: files[n] for n in need} if all(n in files for n in need) else {}

# ====== T1/T2 ======
def check_T1_T2(path: str, require_4ch: bool) -> Tuple[bool,str]:
    x, fs = load_any(path)
    ch_ok = (x.shape[1] == 4) if require_4ch else (x.shape[1] in (2,4))
    if not ch_ok:
        need = "4-ch" if require_4ch else "2-ch or 4-ch"
        return False, f"T1 {CROSS} expected {need}, got {x.shape[1]}"
    offenders = []
    for i in range(x.shape[1]):
        xi = x[:,i]; r = rms(xi); c = center_of_energy(xi)
        if r >= 1e-12 and (not np.isnan(c)) and abs(c) > CENTRE_MAX_ABS_SAMPLES:
            offenders.append(f"Ch{i+1} c={c:+.2f}")
    if offenders:
        return False, f"T2 {CROSS} centring off: {'; '.join(offenders)} (limit ±{CENTRE_MAX_ABS_SAMPLES:.2f})"
    return True, f"T1/T2 {TICK}"

# ====== T3: PHJ decoder vs legacy parity (legacy may be 2-ch) ======
def mag_db(h: np.ndarray, nfft: int) -> np.ndarray:
    H = np.fft.rfft(h, n=nfft, axis=0)
    return 20.0*np.log10(np.abs(H) + 1e-18)

def band_mask(freqs: np.ndarray, fs_hdr: int, lo=F_LO, hi_frac=HI_FRAC):
    return (freqs >= lo) & (freqs <= hi_frac*fs_hdr)

def t3_decoder_parity(phj_paths: Dict[str,str], leg_paths: Dict[str,str]) -> Tuple[bool, List[str], dict]:
    msgs = []
    ok_all = True

    y0, fs = load4(phj_paths["UHJ_W.wav"])
    nfft = choose_nfft(y0.shape[0])
    freqs = np.linspace(0.0, fs/2.0, nfft//2 + 1)
    m = band_mask(freqs, fs)

    compare = [("UHJ_W.wav",[0,1]), ("UHJ_X.wav",[0,1]), ("UHJ_Y.wav",[0,1])]
    silent_expect = {"UHJ_W.wav":[2,3], "UHJ_Z.wav":[0,1,2]}

    plot_curves = []

    for nm, lanes in compare:
        if nm not in leg_paths:
            msgs.append(f" {INFO} Skipping {nm} parity — legacy file missing")
            continue
        P, _ = load4(phj_paths[nm])     # 4-ch guaranteed
        Lg,_ = load_any(leg_paths[nm])  # 2-ch or 4-ch

        Pm = mag_db(P, nfft)
        Lm = mag_db(Lg, nfft)

        ok_nm = True
        for ch in lanes:  # 0=L, 1=R
            if Lm.shape[1] <= ch:
                msgs.append(f" {INFO} {nm} legacy missing ch{ch+1}; skipping that lane")
                continue
            d = Pm[:,ch] - Lm[:,ch]
            med = float(np.median(d[m]))
            rip = float(np.max(d[m]) - np.min(d[m]))
            if abs(med) <= PARITY_MEDIAN_DB and rip <= PARITY_RIPPLE_DB:
                msgs.append(f" {TICK} {nm} ch{ch+1}: median Δ {med:+.2f} dB, ripple {rip:.2f} dB")
            else:
                msgs.append(f" {CROSS} {nm} ch{ch+1}: median Δ {med:+.2f} dB (≤{PARITY_MEDIAN_DB}), ripple {rip:.2f} dB (≤{PARITY_RIPPLE_DB})")
                ok_nm = False
            plot_curves.append((f"{nm[:-4]} ch{ch+1}", freqs[m], d[m]))
        ok_all &= ok_nm

    # Silence checks on PHJ
    for nm, idxs in silent_expect.items():
        if nm in phj_paths:
            Y,_ = load4(phj_paths[nm])
            for ch in idxs:
                r = db(rms(Y[:,ch]))
                if r > SILENCE_RMS_DBFS:
                    msgs.append(f" {CROSS} {nm} ch{ch+1} expected silent, RMS {r:.1f} dBFS (>{SILENCE_RMS_DBFS:.0f})")
                    ok_all = False

    details = {"freqs": freqs, "m": m, "curves": plot_curves}
    return ok_all, msgs, details

# ====== T4': Subcarrier pattern (presence/absence) ======
def t4_subcarrier_pattern(enc_paths: Dict[str,str], dec_paths: Dict[str,str]) -> Tuple[bool, List[str], dict]:
    msgs = []
    ok = True
    details = {"dec": [], "enc": []}

    # --- Decoders: measure RMS of T (ch3), Q (ch4) for each file
    for nm in ["UHJ_W.wav","UHJ_X.wav","UHJ_Y.wav","UHJ_Z.wav"]:
        Y, _ = load4(dec_paths[nm])  # lanes L,R,T,Q
        t_db = db(rms(Y[:,2]))
        q_db = db(rms(Y[:,3]))
        details["dec"].append((nm, t_db, q_db))

        if nm in ["UHJ_W.wav","UHJ_X.wav","UHJ_Y.wav"]:
            # Realistic expectation with finite FIRs:
            #   T ≤ -35 dBFS (tiny residue allowed), Q ≤ -50 dBFS (silent)
            pass_ = (t_db <= -35.0) and (q_db <= -50.0)
            msgs.append(f" {TICK if pass_ else CROSS} {nm}: expect T ≤ -35 dBFS & Q ≤ -50 dBFS → "
                        f"T {t_db:.1f} dBFS, Q {q_db:.1f} dBFS")
            ok &= pass_
        else:
            # Z: expect T silent, Q active
            pass_ = (t_db <= -60.0) and (q_db >= -40.0)
            msgs.append(f" {TICK if pass_ else CROSS} {nm}: expect T ≤ -60 dBFS & Q ≥ -40 dBFS → "
                        f"T {t_db:.1f}, Q {q_db:.1f} dBFS")
            ok &= pass_

    # --- Encoders: per FOA lane W/X/Y/Z, compare UHJ_T vs UHJ_Q
    Tm, _ = load4(enc_paths["UHJ_T.wav"])  # cols=W,X,Y,Z
    Qm, _ = load4(enc_paths["UHJ_Q.wav"])
    for k, name in enumerate(["W","X","Y","Z"]):
        t_db = db(rms(Tm[:,k])); q_db = db(rms(Qm[:,k]))
        details["enc"].append((name, t_db, q_db))

        t_silent = (t_db <= TQ_SILENT_TH)
        q_silent = (q_db <= TQ_SILENT_TH)
        t_active = (t_db >= TQ_ACTIVE_TH)
        q_active = (q_db >= TQ_ACTIVE_TH)

        if t_silent and q_silent:
            msgs.append(f" {INFO} Enc lane {name}: both T/Q < {TQ_SILENT_TH:.0f} dBFS (unused lane)")
        elif t_active and q_silent:
            msgs.append(f" {TICK} Enc lane {name}: T active {t_db:.1f} dBFS, Q silent {q_db:.1f} dBFS")
        elif q_active and t_silent:
            msgs.append(f" {TICK} Enc lane {name}: Q active {q_db:.1f} dBFS, T silent {t_db:.1f} dBFS")
        elif t_active and q_active:
            msgs.append(f" {CROSS} Enc lane {name}: both T/Q active (T {t_db:.1f}, Q {q_db:.1f} dBFS)")
            ok &= False
        else:
            msgs.append(f" {INFO} Enc lane {name}: borderline (T {t_db:.1f}, Q {q_db:.1f} dBFS)")

    return ok, msgs, details

# ====== T5: isolation via ENC∘DEC ======
def build_roundtrip(enc_files: Dict[str,str], dec_files: Dict[str,str]) -> Tuple[np.ndarray,int]:
    enc_order = ["UHJ_L.wav","UHJ_R.wav","UHJ_T.wav","UHJ_Q.wav"]  # inputs: L,R,T,Q
    dec_order = ["UHJ_W.wav","UHJ_X.wav","UHJ_Y.wav","UHJ_Z.wav"]  # FOA: W,X,Y,Z (to outputs L,R,T,Q)

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

    # Data are unscaled; for display/criteria we add L/R ×2 later.
    return R_time, fs_e

def judge_isolation(R_time: np.ndarray, fs: int) -> Tuple[bool,str,dict]:
    L = R_time.shape[0]
    nfft = choose_nfft(L)
    F = nfft//2 + 1
    freqs = np.linspace(0.0, fs/2.0, F)
    H = np.zeros((4,4,F), dtype=np.complex128)
    for i in range(4):
        for j in range(4):
            H[i,j,:] = np.fft.rfft(R_time[:,i,j], n=nfft)

    # Apply L/R ×2 purely for display/criteria to undo UHJ ½
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
    reason = (f"T5 {'PASS' if ok else 'FAIL'} — isolation via ENC∘DEC (display L/R ×2 to undo UHJ ½):\n"
              f"    midband 200..10k Hz: diag ±{DIAG_MID_TOL_DB:.1f} dB "
              f"(max {diag_hi_mid:+.2f}/min {diag_lo_mid:+.2f}), "
              f"off-diag ≤ {XTALK_MID_MAX_DB:.0f} dB (max {od_max_mid:.1f})\n"
              f"    edges 50..200 & 10k..{int(HI_FRAC*fs)} Hz: diag ±{DIAG_EDGE_TOL_DB:.1f} dB "
              f"(max {diag_hi_edge:+.2f}/min {diag_lo_edge:+.2f}), "
              f"off-diag ≤ {XTALK_EDGE_MAX_DB:.0f} dB (max {od_max_edge:.1f})")
    details = {"freqs": freqs, "disp": disp, "m_mid": m_mid, "m_edge": m_edge}
    return ok, reason, details

# ====== Impulse thumbnails for plots ======
def impulse_thumbs(dec_files: Dict[str,str]) -> List[Tuple[str, np.ndarray]]:
    # Small windows around center for visual symmetry (looks like “FIRs”)
    names = [("W→L", "UHJ_W.wav", 0), ("W→R","UHJ_W.wav",1),
             ("X→L","UHJ_X.wav",0), ("X→R","UHJ_X.wav",1),
             ("Z→Q","UHJ_Z.wav",3)]
    th = []
    for label, nm, ch in names:
        y,_ = load4(dec_files[nm]); x = y[:,ch]
        c = center_of_energy(x); c = int(round((len(x)-1)/2 + c))
        w = 96  # ±48 samples around center
        i0 = max(0, c-48); i1 = min(len(x), c+48)
        s = np.zeros(2*48)
        seg = x[i0:i1]
        s[:len(seg)] = seg
        th.append((label, s))
    return th

# ====== Combined plot ======
def make_combined_plot(fs: str, N: str,
                       t3_details: Optional[dict],
                       t4_details: Optional[dict],
                       t5_details: dict,
                       outpath: str,
                       dec_files_for_impulses: Optional[Dict[str,str]] = None):
    os.makedirs(PLOT_DIR, exist_ok=True)
    fig = plt.figure(figsize=(13, 9))

    freqs = t5_details["freqs"]; disp = t5_details["disp"]
    m_mid = t5_details["m_mid"]; m_edge = t5_details["m_edge"]

    # A) Diagonals, tight scale
    axA = plt.subplot(2,2,1)
    labels = ["L→L","R→R","T→T","Q→Q"]
    for i in range(4): axA.plot(freqs[m_mid], disp[i,i,m_mid], label=labels[i])
    if np.any(m_edge):
        for i in range(4): axA.plot(freqs[m_edge], disp[i,i,m_edge], alpha=0.3)
    axA.axhline(+DIAG_MID_TOL_DB, ls="--"); axA.axhline(-DIAG_MID_TOL_DB, ls="--")
    axA.set_ylim(-2.2, 2.2)
    axA.set_title("A) Round-trip diagonals (L/R shown ×2)")
    axA.set_xlabel("Frequency (Hz)"); axA.set_ylabel("Magnitude (dB)")
    axA.legend(loc="best", fontsize=9)

    # B) Max off-diagonal, useful y-range
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
    axB.set_xlabel("Frequency (Hz)"); axB.set_ylabel("Max off-diag (dB)")
    axB.legend(loc="best", fontsize=9)

    # C) PHJ vs LEGACY parity curves (Δ dB) if present
    axC = plt.subplot(2,2,3)
    if t3_details and t3_details.get("curves"):
        for label, f, d in t3_details["curves"]:
            axC.plot(f, d, label=label)
        axC.axhline(+PARITY_MEDIAN_DB, ls="--"); axC.axhline(-PARITY_MEDIAN_DB, ls="--")
        axC.set_title("C) PHJ vs LEGACY decoder (Δ dB, W/X/Y on L/R)")
        axC.set_xlabel("Frequency (Hz)"); axC.set_ylabel("Δ magnitude (dB)")
        axC.legend(loc="best", fontsize=8, ncols=2)
    else:
        axC.text(0.5,0.6,"T3 parity vs legacy: see console (PASS/FAIL)",
                 ha="center",va="center",fontsize=11)
        axC.set_axis_off()

    # D) Impulse symmetry thumbnails
    axD = plt.subplot(2,2,4); axD.set_title("Impulse symmetry thumbnails")
    axD.set_xlabel("samples"); axD.set_ylabel("amplitude")
    if dec_files_for_impulses:
        for name, h in impulse_thumbs(dec_files_for_impulses):
            axD.plot(h, alpha=0.85, label=name)
        axD.legend(fontsize=8)
    else:
        axD.text(0.5,0.5,"(not captured)",ha="center",va="center")

    fig.suptitle(f"PHJ Verify — fs={fs}  N={N}", fontsize=14)
    fig.tight_layout(rect=[0, 0.03, 1, 0.96])
    fig.savefig(outpath, dpi=120)
    plt.close(fig)

    if platform.system() == "Darwin":
        try: subprocess.run(["open", "-g", outpath], check=False)
        except Exception: pass

# ====== Orchestration ======
def main():
    clear_screen()
    print("PHJ FIR Verifier — ATK-only (fs→N)\n")
    print("Tests:\n"
          f"  T1/T2 {TICK}/{CROSS} 4-ch integrity + centring (≤ ±{CENTRE_MAX_ABS_SAMPLES:.2f} samp)\n"
          f"  T3    {TICK}/{CROSS} PHJ decoder vs LEGACY decoder parity (±{PARITY_MEDIAN_DB} dB median; ripple ≤ {PARITY_RIPPLE_DB} dB; silence lanes < {SILENCE_RMS_DBFS:.0f} dBFS)\n"
          f"  T4'   {TICK}/{CROSS} Subcarrier pattern (decoder: W/X/Y tiny T allowed; Z: Q-only active; enc lanes sane)\n"
          f"  T5    {TICK}/{CROSS} FOA isolation via ENC∘DEC (L/R displayed ×2 to undo UHJ ½): diag ±{DIAG_MID_TOL_DB:.1f} dB, off-diag ≤ {XTALK_MID_MAX_DB:.0f} dB\n")

    # Encoders grouped by fs
    enc_by_fs = discover_encoders_by_fs()
    if not enc_by_fs:
        print(f"{CROSS} No PHJ encoder sets under: {ENC_BASE}")
        sys.exit(1)

    # Menu 1: fs
    fs_list = sorted(enc_by_fs.keys(), key=lambda s:int(s))
    i_fs = pick("Pick encoder sample rate (fs):", [f"fs={fs}" for fs in fs_list])
    fs = fs_list[i_fs]

    # Menu 2: N for this fs
    Ns_list = sorted(enc_by_fs[fs].keys(), key=lambda s:int(s))
    i_N = pick("Pick encoder FFT length (N):", [f"N={N}" for N in Ns_list])
    N = Ns_list[i_N]
    enc_files = enc_by_fs[fs][N]

    # Decoders: PHJ and legacy at same N
    dec_files = discover_decoders(N, DEC_BASE)
    if not dec_files:
        print(f"{CROSS} PHJ decoders missing at: {os.path.join(DEC_BASE, N, '0000')}")
        sys.exit(1)
    leg_files = discover_decoders(N, LEG_DEC_BASE)
    if not leg_files:
        print(f"{CROSS} Legacy decoders missing at: {os.path.join(LEG_DEC_BASE, N, '0000')}")
        print("      Expected UHJ_W/X/Y.wav (2-ch or 4-ch).")
        sys.exit(1)

    # T1/T2 — enc + dec + legacy (legacy allows 2-ch)
    print(f"\n— T1/T2 file checks (fs={fs}, N={N}) —")
    t12_ok = True
    for name, path in {**enc_files, **dec_files}.items():
        ok, msg = check_T1_T2(path, require_4ch=True)
        print(f" {TICK if ok else CROSS} {name:10s} | {msg}"); t12_ok &= ok
    for nm in ["UHJ_W.wav","UHJ_X.wav","UHJ_Y.wav"]:
        if nm in leg_files:
            ok, msg = check_T1_T2(leg_files[nm], require_4ch=False)
            print(f" {TICK if ok else CROSS} LEG::{nm:6s} | {msg}"); t12_ok &= ok

    # T3 — decoder parity vs legacy
    print("\n— T3 PHJ decoder vs LEGACY decoder parity —")
    t3_ok, t3_msgs, t3_details = t3_decoder_parity(dec_files, leg_files)
    for m in t3_msgs: print(m)

    # T4' — subcarrier pattern (decoder & encoder)
    print("\n— T4' Subcarrier pattern —")
    t4_ok, t4_msgs, t4_details = t4_subcarrier_pattern(enc_files, dec_files)
    for m in t4_msgs: print(m)

    # T5 — isolation via ENC∘DEC round-trip (display L/R ×2)
    print("\n— T5 Isolation (ENC∘DEC) —")
    R_time, fsE = build_roundtrip(enc_files, dec_files)
    t5_ok, t5_reason, t5_details = judge_isolation(R_time, fs=fsE)
    print((" "+TICK if t5_ok else " "+CROSS) + " " + t5_reason)

    # Combined plot
    os.makedirs(PLOT_DIR, exist_ok=True)
    outfile = os.path.join(PLOT_DIR, f"PHJ_verify_fs{fs}_N{N}.png")
    make_combined_plot(fs, N, t3_details, t4_details, t5_details, outfile,
                       dec_files_for_impulses=dec_files)
    print(f"   Plot saved → {outfile}")

    overall = t12_ok and t3_ok and t4_ok and t5_ok
    print(f"\nOverall: {TICK if overall else CROSS} {'PASS' if overall else 'FAIL'}")

if __name__ == "__main__":
    main()
