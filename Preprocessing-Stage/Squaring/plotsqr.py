#!/usr/bin/env python3
"""
plot_sq.py
Plots Derivative output vs Squaring output.
Reads: out_deriv.hex (signed input), out_sq.hex (unsigned output)
Key visual: signal flips to all-positive; large peaks amplified non-linearly.
"""

import numpy as np
import matplotlib.pyplot as plt

FS = 360

def read_hex(filename, signed=True):
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

print("Loading out_deriv.hex (squaring stage input)...")
deriv = read_hex('out_deriv.hex', signed=True)    # Signed derivative

print("Loading out_sq.hex (squaring output)...")
sq    = read_hex('out_sq.hex',    signed=False)   # Unsigned — always >= 0

N = min(len(deriv), len(sq))
t = np.arange(N) / FS

print(f"Plotting {N} samples ({N/FS:.1f} s)")

# ---------------------------------------------------------------
#  FIGURE 1: Full length
# ---------------------------------------------------------------
fig, axes = plt.subplots(3, 1, figsize=(14, 8), sharex=True)
fig.suptitle('Stage 3: Squaring — Before vs After\n'
             'y[n] = x[n]²  →  all-positive, non-linear amplification', fontsize=13, fontweight='bold')

axes[0].plot(t, norm(deriv[:N]), color='crimson', linewidth=0.8, label='Derivative (signed)')
axes[0].axhline(0, color='k', linewidth=0.5, linestyle='--')   # Zero line to show sign flips
axes[0].set_title('Before — Derivative Output (bipolar, ±)'); axes[0].set_ylabel('Norm. Amp.')
axes[0].legend(loc='upper right', fontsize=9); axes[0].grid(True, alpha=0.3)

axes[1].plot(t, norm(sq[:N]),    color='mediumseagreen', linewidth=0.8, label='Squared (unsigned)')
axes[1].set_title('After — Squared Output (unipolar, ≥ 0)'); axes[1].set_ylabel('Norm. Amp.')
axes[1].legend(loc='upper right', fontsize=9); axes[1].grid(True, alpha=0.3)

# Overlay on shared axis (both normalised to show shape)
axes[2].plot(t, norm(np.abs(deriv[:N].astype(float))), color='crimson',
             linewidth=0.6, alpha=0.7, label='|Derivative| (for comparison)')
axes[2].plot(t, norm(sq[:N]), color='mediumseagreen',
             linewidth=0.8, alpha=0.9, label='Squared')
axes[2].set_title('Overlay — |Derivative| vs Squared  (note non-linear peak boost)')
axes[2].set_ylabel('Norm. Amp.'); axes[2].set_xlabel('Time (s)')
axes[2].legend(loc='upper right', fontsize=9); axes[2].grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_sq_full.png', dpi=150, bbox_inches='tight')
print("Saved: plot_sq_full.png")

# ---------------------------------------------------------------
#  FIGURE 2: Zoomed — shows negative derivative becoming positive peaks
# ---------------------------------------------------------------
t1, t2 = 1.0, 3.0
idx = (t >= t1) & (t <= t2); tz = t[idx]

fig2, (ax_a, ax_b) = plt.subplots(2, 1, figsize=(12, 6), sharex=True)
fig2.suptitle('Stage 3: Squaring — Zoomed (1.0–3.0 s)\n'
              'Negative slopes become positive peaks; large peaks grow non-linearly', fontsize=11)

ax_a.plot(tz, norm(deriv[:N][idx]), color='crimson', linewidth=1.0)
ax_a.axhline(0, color='k', linewidth=0.5, linestyle='--')
ax_a.set_title('Before — Derivative (bipolar)')
ax_a.set_ylabel('Norm. Amp.'); ax_a.grid(True, alpha=0.3)

ax_b.plot(tz, norm(sq[:N][idx]), color='mediumseagreen', linewidth=1.0)
ax_b.set_title('After — Squared (unipolar, large QRS peaks dominate)')
ax_b.set_ylabel('Norm. Amp.'); ax_b.set_xlabel('Time (s)'); ax_b.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_sq_zoom.png', dpi=150, bbox_inches='tight')
print("Saved: plot_sq_zoom.png")

print(f"\nDeriv — min: {deriv[:N].min():6d}  max: {deriv[:N].max():6d}")
print(f"Sq    — min: {sq[:N].min():6d}  max: {sq[:N].max():6d}  (always >= 0)")

plt.show()