#!/usr/bin/env python3
"""
plot_mwi.py
Plots Squaring output vs Moving Window Integrator output.
Reads: out_sq.hex (unsigned input), out_mwi.hex (unsigned output)
Key visual: spiky squared signal smoothed into broad QRS envelope.
"""

import numpy as np
import matplotlib.pyplot as plt

FS    = 360
N_WIN = 30    # MWI window = 30 samples = 83.3 ms

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

print("Loading out_sq.hex (MWI input)...")
sq  = read_hex('out_sq.hex',  signed=False)   # Unsigned squared

print("Loading out_mwi.hex (MWI output)...")
mwi = read_hex('out_mwi.hex', signed=False)   # Unsigned MWI envelope

N = min(len(sq), len(mwi))
t = np.arange(N) / FS

print(f"Plotting {N} samples ({N/FS:.1f} s)  |  Window = {N_WIN} samples = {N_WIN/FS*1000:.0f} ms")

# ---------------------------------------------------------------
#  FIGURE 1: Full length
# ---------------------------------------------------------------
fig, axes = plt.subplots(3, 1, figsize=(14, 8), sharex=True)
fig.suptitle(f'Stage 4: Moving Window Integrator — Before vs After\n'
             f'Window N={N_WIN} samples = {N_WIN/FS*1000:.0f} ms @ {FS} Hz', fontsize=13, fontweight='bold')

axes[0].plot(t, norm(sq[:N]),  color='mediumseagreen', linewidth=0.7, label='Squared Input')
axes[0].set_title('Before — Squared Output (spiky)'); axes[0].set_ylabel('Norm. Amp.')
axes[0].legend(loc='upper right', fontsize=9); axes[0].grid(True, alpha=0.3)

axes[1].plot(t, norm(mwi[:N]), color='darkorchid',    linewidth=0.8, label='MWI Output')
axes[1].set_title('After — MWI Output (smooth QRS envelope)'); axes[1].set_ylabel('Norm. Amp.')
axes[1].legend(loc='upper right', fontsize=9); axes[1].grid(True, alpha=0.3)

axes[2].plot(t, norm(sq[:N]),  color='mediumseagreen', linewidth=0.6, alpha=0.6, label='Squared')
axes[2].plot(t, norm(mwi[:N]), color='darkorchid',     linewidth=1.0, alpha=0.9, label='MWI')
axes[2].set_title('Overlay — spiky input smoothed to broad envelope')
axes[2].set_ylabel('Norm. Amp.'); axes[2].set_xlabel('Time (s)')
axes[2].legend(loc='upper right', fontsize=9); axes[2].grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_mwi_full.png', dpi=150, bbox_inches='tight')
print("Saved: plot_mwi_full.png")

# ---------------------------------------------------------------
#  FIGURE 2: Zoomed — 3 beats
# ---------------------------------------------------------------
t1, t2 = 1.0, 3.0
idx = (t >= t1) & (t <= t2); tz = t[idx]

fig2, (ax_a, ax_b) = plt.subplots(2, 1, figsize=(12, 6), sharex=True)
fig2.suptitle(f'Stage 4: MWI — Zoomed (1.0–3.0 s)\n'
              f'Notice: each QRS event grouped into one smooth peak', fontsize=11)

ax_a.plot(tz, norm(sq[:N][idx]),  color='mediumseagreen', linewidth=1.0)
ax_a.set_title('Before — Squared (multiple spikes per QRS)')
ax_a.set_ylabel('Norm. Amp.'); ax_a.grid(True, alpha=0.3)

ax_b.plot(tz, norm(mwi[:N][idx]), color='darkorchid', linewidth=1.2)
ax_b.set_title(f'After — MWI (single broad peak per QRS, window={N_WIN/FS*1000:.0f} ms)')
ax_b.set_ylabel('Norm. Amp.'); ax_b.set_xlabel('Time (s)'); ax_b.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_mwi_zoom.png', dpi=150, bbox_inches='tight')
print("Saved: plot_mwi_zoom.png")

print(f"\nSq  — min: {sq[:N].min():6d}  max: {sq[:N].max():6d}")
print(f"MWI — min: {mwi[:N].min():6d}  max: {mwi[:N].max():6d}")

plt.show()