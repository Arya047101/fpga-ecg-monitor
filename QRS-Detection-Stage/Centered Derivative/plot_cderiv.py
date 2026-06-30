#!/usr/bin/env python3
"""
plot_cderiv.py
Plots LPS envelope vs Centered Derivative output.
Reads: out_lps.hex (unsigned, input), out_cderiv.hex (signed, output)
Key visual: slope of the envelope — zero-crossings mark peak centres.
"""
import numpy as np
import matplotlib.pyplot as plt

FS = 360

def read_hex(filename, signed=True):
    vals = []
    with open(filename) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            v = int(line, 16)
            if signed and v >= 0x8000: v -= 0x10000
            vals.append(v)
    return np.array(vals, dtype=np.int16 if signed else np.uint16)

def norm(x):
    m = np.max(np.abs(x.astype(float)))
    return x.astype(float) / m if m else x.astype(float)

print("Loading out_lps.hex...")
lps    = read_hex('out_lps.hex',    signed=False)
print("Loading out_cderiv.hex...")
cderiv = read_hex('out_cderiv.hex', signed=True)

N = min(len(lps), len(cderiv))
t = np.arange(N) / FS

fig, axes = plt.subplots(3, 1, figsize=(14, 8), sharex=True)
fig.suptitle('QRS Stage 1: Centered Derivative — Slope of LPS Envelope\n'
             'Zero-crossings (positive→negative) mark R-peak centres', fontsize=13, fontweight='bold')

axes[0].plot(t, norm(lps[:N]), color='teal', lw=0.8, label='LPS Envelope (input)')
axes[0].set_title('Before — LPS Envelope'); axes[0].set_ylabel('Norm. Amp.')
axes[0].legend(loc='upper right', fontsize=9); axes[0].grid(True, alpha=0.3)

axes[1].plot(t, norm(cderiv[:N]), color='royalblue', lw=0.8, label='Centered Derivative')
axes[1].axhline(0, color='k', lw=0.5, ls='--', label='Zero line')
axes[1].set_title('After — Centered Derivative (slope signal)')
axes[1].set_ylabel('Norm. Amp.')
axes[1].legend(loc='upper right', fontsize=9); axes[1].grid(True, alpha=0.3)

axes[2].plot(t, norm(lps[:N]),    color='teal',     lw=0.6, alpha=0.7, label='LPS')
axes[2].plot(t, norm(cderiv[:N]), color='royalblue', lw=0.8, alpha=0.9, label='Derivative')
axes[2].axhline(0, color='k', lw=0.4, ls=':')
axes[2].set_title('Overlay — Envelope with derivative (note derivative zero-crossing at peaks)')
axes[2].set_ylabel('Norm. Amp.'); axes[2].set_xlabel('Time (s)')
axes[2].legend(loc='upper right', fontsize=9); axes[2].grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_cderiv_full.png', dpi=150, bbox_inches='tight')
print("Saved: plot_cderiv_full.png")

t1, t2 = 1.0, 3.0
idx = (t >= t1) & (t <= t2); tz = t[idx]

fig2, (ax_a, ax_b) = plt.subplots(2, 1, figsize=(12, 6), sharex=True)
fig2.suptitle('QRS Stage 1: Centered Derivative — Zoomed (1.0–3.0 s)\n'
              'Zero-crossings align with R-peak maxima', fontsize=11)
ax_a.plot(tz, norm(lps[:N][idx]),    color='teal',      lw=1.0); ax_a.set_title('LPS Envelope')
ax_a.set_ylabel('Norm. Amp.'); ax_a.grid(True, alpha=0.3)
ax_b.plot(tz, norm(cderiv[:N][idx]), color='royalblue',  lw=1.0)
ax_b.axhline(0, color='k', lw=0.5, ls='--')
ax_b.set_title('Centered Derivative')
ax_b.set_ylabel('Norm. Amp.'); ax_b.set_xlabel('Time (s)'); ax_b.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_cderiv_zoom.png', dpi=150, bbox_inches='tight')
print("Saved: plot_cderiv_zoom.png")
print(f"\nLPS    — min: {lps[:N].min():6d}  max: {lps[:N].max():6d}")
print(f"CDeriv — min: {cderiv[:N].min():6d}  max: {cderiv[:N].max():6d}")
plt.show()
