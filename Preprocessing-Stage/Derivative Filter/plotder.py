#!/usr/bin/env python3
"""
plot_deriv.py
Plots BPF output vs Derivative Filter output.
Reads: out_bpf.hex (input), out_deriv.hex (output)
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

print("Loading out_bpf.hex (derivative stage input)...")
bpf   = read_hex('out_bpf.hex',   signed=True)   # BPF output = deriv input

print("Loading out_deriv.hex (derivative output)...")
deriv = read_hex('out_deriv.hex', signed=True)   # Derivative output

N = min(len(bpf), len(deriv))
t = np.arange(N) / FS

print(f"Plotting {N} samples ({N/FS:.1f} s)")

# ---------------------------------------------------------------
#  FIGURE 1: Full length — 3 panels
# ---------------------------------------------------------------
fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(14, 8), sharex=True)
fig.suptitle('Stage 2: Derivative Filter — Before vs After\n'
             'H_D(z) = (1/8Ts)[1 + 2z⁻¹ - 2z⁻³ - z⁻⁴]', fontsize=13, fontweight='bold')

ax1.plot(t, norm(bpf[:N]),   color='darkorange', linewidth=0.8, label='BPF Output (Input)')
ax1.set_title('Before — BPF Output'); ax1.set_ylabel('Norm. Amp.')
ax1.legend(loc='upper right', fontsize=9); ax1.grid(True, alpha=0.3)

ax2.plot(t, norm(deriv[:N]), color='crimson',    linewidth=0.8, label='Derivative Output')
ax2.set_title('After — Derivative Filter (emphasises QRS slopes)')
ax2.set_ylabel('Norm. Amp.')
ax2.legend(loc='upper right', fontsize=9); ax2.grid(True, alpha=0.3)

ax3.plot(t, norm(bpf[:N]),   color='darkorange', linewidth=0.6, alpha=0.7, label='Before (BPF)')
ax3.plot(t, norm(deriv[:N]), color='crimson',    linewidth=0.8, alpha=0.9, label='After (Deriv)')
ax3.set_title('Overlay'); ax3.set_ylabel('Norm. Amp.'); ax3.set_xlabel('Time (s)')
ax3.legend(loc='upper right', fontsize=9); ax3.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_deriv_full.png', dpi=150, bbox_inches='tight')
print("Saved: plot_deriv_full.png")

# ---------------------------------------------------------------
#  FIGURE 2: Zoomed — note how P/T waves shrink, QRS spikes grow
# ---------------------------------------------------------------
t1, t2 = 1.0, 3.0
idx = (t >= t1) & (t <= t2); tz = t[idx]

fig2, (ax_a, ax_b) = plt.subplots(2, 1, figsize=(12, 6), sharex=True)
fig2.suptitle('Stage 2: Derivative Filter — Zoomed (1.0–3.0 s)\n'
              'Notice: P/T waves suppressed, QRS slope spikes amplified', fontsize=11)

ax_a.plot(tz, norm(bpf[:N][idx]),   color='darkorange', linewidth=1.0)
ax_a.set_title('Before — BPF Output'); ax_a.set_ylabel('Norm. Amp.'); ax_a.grid(True, alpha=0.3)

ax_b.plot(tz, norm(deriv[:N][idx]), color='crimson', linewidth=1.0)
ax_b.set_title('After — Derivative (QRS slopes emphasised)')
ax_b.set_ylabel('Norm. Amp.'); ax_b.set_xlabel('Time (s)'); ax_b.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_deriv_zoom.png', dpi=150, bbox_inches='tight')
print("Saved: plot_deriv_zoom.png")

print(f"\nBPF   — min: {bpf[:N].min():6d}  max: {bpf[:N].max():6d}")
print(f"Deriv — min: {deriv[:N].min():6d}  max: {deriv[:N].max():6d}")

plt.show()