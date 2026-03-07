#!/usr/bin/env python3
"""
plot_lps.py
Plots MWI output vs Low-Pass Smoothing filter output.
Reads: out_mwi.hex (unsigned input), out_lps.hex (unsigned output)
Key visual: residual ripple removed, clean envelope ready for thresholding.
"""

import numpy as np
import matplotlib.pyplot as plt

FS = 360
FC = 8   # LP cutoff frequency in Hz

def read_hex(filename, signed=False):
    values = []
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            val = int(line, 16)
            if signed and val >= 0x8000:
                val -= 0x10000
            values.append(val)
    return np.array(values, dtype=np.int16 if signed else np.uint16)

def norm(x):
    m = np.max(np.abs(x.astype(float)))
    return x.astype(float) / m if m != 0 else x.astype(float)

print("Loading out_mwi.hex (LP smoothing input)...")
mwi = read_hex('out_mwi.hex', signed=False)   # Unsigned MWI output

print("Loading out_lps.hex (LP smoothing output)...")
lps = read_hex('out_lps.hex', signed=False)   # Unsigned LP output

N = min(len(mwi), len(lps))
t = np.arange(N) / FS

print(f"Plotting {N} samples ({N/FS:.1f} s)")

# ---------------------------------------------------------------
#  FIGURE 1: Full length — 3 panels
# ---------------------------------------------------------------
fig, axes = plt.subplots(3, 1, figsize=(14, 8), sharex=True)
fig.suptitle(f'Stage 5: LP Smoothing Filter — Before vs After\n'
             f'2nd-order Butterworth, fc={FC} Hz @ {FS} Hz', fontsize=13, fontweight='bold')

axes[0].plot(t, norm(mwi[:N]), color='darkorchid', linewidth=0.8, label='MWI Output (Input)')
axes[0].set_title('Before — MWI Output (may have residual ripple)')
axes[0].set_ylabel('Norm. Amp.')
axes[0].legend(loc='upper right', fontsize=9); axes[0].grid(True, alpha=0.3)

axes[1].plot(t, norm(lps[:N]), color='teal', linewidth=0.8, label=f'LP Smoothed (fc={FC} Hz)')
axes[1].set_title(f'After — LP Smoothed Envelope (clean, ready for thresholding)')
axes[1].set_ylabel('Norm. Amp.')
axes[1].legend(loc='upper right', fontsize=9); axes[1].grid(True, alpha=0.3)

axes[2].plot(t, norm(mwi[:N]), color='darkorchid', linewidth=0.6, alpha=0.7, label='MWI')
axes[2].plot(t, norm(lps[:N]), color='teal',       linewidth=1.0, alpha=0.9, label='LP Smoothed')
axes[2].set_title('Overlay — MWI vs LP Smoothed (ripple reduction)')
axes[2].set_ylabel('Norm. Amp.'); axes[2].set_xlabel('Time (s)')
axes[2].legend(loc='upper right', fontsize=9); axes[2].grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_lps_full.png', dpi=150, bbox_inches='tight')
print("Saved: plot_lps_full.png")

# ---------------------------------------------------------------
#  FIGURE 2: Zoomed — shows ripple removal around QRS peaks
# ---------------------------------------------------------------
t1, t2 = 1.0, 3.0
idx = (t >= t1) & (t <= t2); tz = t[idx]

fig2, (ax_a, ax_b) = plt.subplots(2, 1, figsize=(12, 6), sharex=True)
fig2.suptitle(f'Stage 5: LP Smoothing — Zoomed (1.0–3.0 s)\n'
              f'Final preprocessing output: clean envelope per heartbeat', fontsize=11)

ax_a.plot(tz, norm(mwi[:N][idx]), color='darkorchid', linewidth=1.0)
ax_a.set_title('Before — MWI Output')
ax_a.set_ylabel('Norm. Amp.'); ax_a.grid(True, alpha=0.3)

ax_b.plot(tz, norm(lps[:N][idx]), color='teal', linewidth=1.2)
ax_b.set_title(f'After — LP Smoothed (fc={FC} Hz) — final output for R-peak detection')
ax_b.set_ylabel('Norm. Amp.'); ax_b.set_xlabel('Time (s)'); ax_b.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_lps_zoom.png', dpi=150, bbox_inches='tight')
print("Saved: plot_lps_zoom.png")

# ---------------------------------------------------------------
#  FIGURE 3: Final pipeline summary — raw ECG vs final envelope
# ---------------------------------------------------------------
print("Loading ecg_record100.hex for final comparison...")
try:
    raw_vals = []
    with open('ecg_record100.hex', 'r') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            val = int(line, 16)
            if val >= 0x8000: val -= 0x10000   # Signed
            raw_vals.append(val)
    raw = np.array(raw_vals, dtype=np.int16)
    N3  = min(len(raw), N)

    fig3, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 6), sharex=True)
    fig3.suptitle('Full Pipeline: Raw ECG → Final Preprocessed Envelope\n'
                  '(Suitable for adaptive R-peak threshold detection)', fontsize=12)

    ax1.plot(t[:N3], norm(raw[:N3]), 'steelblue', linewidth=0.7)
    ax1.set_title('Raw ECG Input'); ax1.set_ylabel('Norm. Amp.'); ax1.grid(True, alpha=0.3)

    ax2.plot(t[:N],  norm(lps[:N]), 'teal', linewidth=1.0)
    ax2.set_title('Final Preprocessed Envelope (LP Smoothed)')
    ax2.set_ylabel('Norm. Amp.'); ax2.set_xlabel('Time (s)'); ax2.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('plot_raw_vs_envelope.png', dpi=150, bbox_inches='tight')
    print("Saved: plot_raw_vs_envelope.png")
except FileNotFoundError:
    print("ecg_record100.hex not found — skipping raw vs envelope plot")

print(f"\nMWI — min: {mwi[:N].min():6d}  max: {mwi[:N].max():6d}")
print(f"LPS — min: {lps[:N].min():6d}  max: {lps[:N].max():6d}")

plt.show()