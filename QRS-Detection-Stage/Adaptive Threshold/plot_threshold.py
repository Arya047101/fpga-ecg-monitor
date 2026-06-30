#!/usr/bin/env python3
"""
plot_threshold.py
Plots LPS envelope overlaid with adaptive threshold.
Reads: out_lps.hex (unsigned), out_threshold.hex (unsigned)
Key visual: threshold tracks signal/noise level; QRS peaks exceed it.
"""
import numpy as np
import matplotlib.pyplot as plt

FS = 360

def read_hex(filename, signed=False):
    vals = []
    with open(filename) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            v = int(line, 16)
            if signed and v >= 0x8000: v -= 0x10000
            vals.append(v)
    return np.array(vals, dtype=np.int16 if signed else np.uint16)

print("Loading out_lps.hex...")
lps   = read_hex('out_lps.hex',    signed=False)
print("Loading out_threshold.hex...")
thresh = read_hex('out_threshold.hex', signed=False)

N = min(len(lps), len(thresh))
t = np.arange(N) / FS

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 7), sharex=True)
fig.suptitle('QRS Stage 2: Adaptive Threshold\n'
             'Threshold tracks signal/noise boundary; R-peaks cross it', fontsize=13, fontweight='bold')

ax1.plot(t, lps[:N],   color='teal',     lw=0.8, label='LPS Envelope')
ax1.plot(t, thresh[:N], color='red',     lw=1.0, ls='--', label='Adaptive Threshold')
ax1.fill_between(t, lps[:N], thresh[:N],
                 where=(lps[:N] > thresh[:N]),
                 color='lime', alpha=0.3, label='Above threshold (QRS candidate)')
ax1.set_title('LPS Envelope with Adaptive Threshold Overlay')
ax1.set_ylabel('Amplitude (counts)'); ax1.legend(loc='upper right', fontsize=9); ax1.grid(True, alpha=0.3)

ax2.plot(t, thresh[:N], color='red', lw=1.0, label='Threshold value')
ax2.set_title('Adaptive Threshold Over Time (tracks SPKI and NPKI)')
ax2.set_ylabel('Threshold'); ax2.set_xlabel('Time (s)')
ax2.legend(loc='upper right', fontsize=9); ax2.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_threshold_full.png', dpi=150, bbox_inches='tight')
print("Saved: plot_threshold_full.png")

t1, t2 = 1.0, 3.0
idx = (t >= t1) & (t <= t2); tz = t[idx]
fig2, ax = plt.subplots(figsize=(12, 5))
ax.plot(tz, lps[:N][idx],    color='teal', lw=1.0, label='LPS Envelope')
ax.plot(tz, thresh[:N][idx], color='red',  lw=1.2, ls='--', label='Adaptive Threshold')
ax.fill_between(tz, lps[:N][idx], thresh[:N][idx],
                where=(lps[:N][idx] > thresh[:N][idx]),
                color='lime', alpha=0.3)
ax.set_title('QRS Stage 2: Adaptive Threshold — Zoomed (1.0–3.0 s)')
ax.set_ylabel('Amplitude'); ax.set_xlabel('Time (s)')
ax.legend(loc='upper right'); ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('plot_threshold_zoom.png', dpi=150, bbox_inches='tight')
print("Saved: plot_threshold_zoom.png")
plt.show()
