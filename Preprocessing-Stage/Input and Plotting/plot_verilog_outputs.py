#!/usr/bin/env python3
"""
=================================================================
  plot_verilog_outputs.py
  Reads hex output files produced by Verilog testbenches and
  plots the waveform at each preprocessing stage.

  Input files (produced by testbenches):
    out_bpf.hex   — Bandpass filter output
    out_deriv.hex — Derivative filter output
    out_sq.hex    — Squaring stage output
    out_mwi.hex   — Moving Window Integrator output
    out_lps.hex   — Low-Pass Smoothing output
    ecg_record100.hex — Original input (for comparison)

  Requirements:
    pip install numpy matplotlib
=================================================================
"""

import numpy as np                    # Array and numeric operations
import matplotlib.pyplot as plt       # Plotting library
import matplotlib.gridspec as gridspec# Flexible subplot layout
import os                             # File existence checks

FS = 360   # Sampling frequency in Hz (360 Hz, no downsampling)

# ---------------------------------------------------------------
#  HELPER: Read a hex file and return numpy array
#  Handles both signed (BPF, Deriv) and unsigned (Sq, MWI, LPS) data.
# ---------------------------------------------------------------
def read_hex(filename, signed=True, bits=16):
    """
    Read one 16-bit hex value per line from filename.
    Returns numpy int16 (signed=True) or uint16 (signed=False) array.
    """
    if not os.path.exists(filename):
        print(f"  [WARNING] {filename} not found — skipping.")
        return None

    values = []
    with open(filename, 'r') as f:
        for line_num, line in enumerate(f):
            line = line.strip()               # Remove whitespace/newline
            if not line or line.startswith('/'):  # Skip empty/comment lines
                continue
            try:
                val = int(line, 16)           # Parse hex string to integer
                if signed and val >= (1 << (bits - 1)):  # Two's complement
                    val -= (1 << bits)        # Convert to negative if MSB set
                values.append(val)
            except ValueError:
                print(f"  [WARN] Could not parse line {line_num}: '{line}'")

    dtype = np.int16 if signed else np.uint16
    return np.array(values, dtype=dtype)

# ---------------------------------------------------------------
#  LOAD ALL STAGE OUTPUTS
# ---------------------------------------------------------------
print("Loading hex files from Verilog testbench outputs...")

stages = {
    'Raw Input (Q1.15)':      ('ecg_record100.hex',  True),   # Signed Q1.15
    'BPF Output':             ('out_bpf.hex',         True),   # Signed
    'Derivative Output':      ('out_deriv.hex',       True),   # Signed
    'Squaring Output':        ('out_sq.hex',           False),  # Unsigned
    'MWI Output':             ('out_mwi.hex',          False),  # Unsigned
    'LP Smoothing Output':    ('out_lps.hex',          False),  # Unsigned
}

data = {}
for label, (filename, is_signed) in stages.items():
    arr = read_hex(filename, signed=is_signed)
    if arr is not None:
        data[label] = arr
        print(f"  Loaded {filename}: {len(arr)} samples")
    else:
        data[label] = None

# ---------------------------------------------------------------
#  DETERMINE COMMON LENGTH (shortest valid array)
# ---------------------------------------------------------------
valid_arrays = [v for v in data.values() if v is not None]
if not valid_arrays:
    print("ERROR: No hex files found. Run testbenches first.")
    exit(1)

N = min(len(a) for a in valid_arrays)   # Use shortest for common x-axis
t = np.arange(N) / FS                   # Time axis in seconds

print(f"\nPlotting {N} samples ({N/FS:.2f} seconds) at {FS} Hz")

# ---------------------------------------------------------------
#  NORMALISE HELPER (for visual comparison on same scale)
# ---------------------------------------------------------------
def normalise(arr):
    """Normalise array to [-1, +1] range for display."""
    m = np.max(np.abs(arr.astype(np.float32)))
    if m == 0:
        return arr.astype(np.float32)
    return arr.astype(np.float32) / m

# ---------------------------------------------------------------
#  FIGURE 1: Full pipeline overview (all stages stacked)
# ---------------------------------------------------------------
n_panels = sum(1 for v in data.values() if v is not None)
fig1, axes = plt.subplots(n_panels, 1, figsize=(14, 2.5*n_panels),
                           sharex=True)
fig1.suptitle(f'Pan-Tompkins Preprocessing Pipeline (Verilog Output) @ {FS} Hz',
              fontsize=13, fontweight='bold')

colors = ['#1f77b4','#2ca02c','#d62728','#ff7f0e','#9467bd','#8c564b']
panel  = 0

for (label, arr), color in zip(data.items(), colors):
    if arr is None:
        continue
    ax = axes[panel] if n_panels > 1 else axes
    ax.plot(t[:N], normalise(arr[:N]), color=color, linewidth=0.8)
    ax.set_ylabel('Norm. Amp.', fontsize=8)
    ax.set_title(label, fontsize=9, pad=2)
    ax.grid(True, alpha=0.3)
    ax.set_xlim([0, t[-1]])
    panel += 1

axes[-1].set_xlabel('Time (s)', fontsize=10)
plt.tight_layout()
plt.savefig('pipeline_full.png', dpi=150, bbox_inches='tight')
print("\nSaved: pipeline_full.png")

# ---------------------------------------------------------------
#  FIGURE 2: Zoomed view — 3 heartbeats (~2 seconds)
# ---------------------------------------------------------------
t_start, t_end = 1.0, 3.0           # Zoom window in seconds
idx = (t >= t_start) & (t <= t_end) # Boolean index mask
t_zoom = t[idx]

fig2, axes2 = plt.subplots(n_panels, 1, figsize=(12, 2.5*n_panels),
                             sharex=True)
fig2.suptitle(f'Zoomed View ({t_start}–{t_end} s) — ~3 Heartbeats',
              fontsize=12, fontweight='bold')

panel = 0
for (label, arr), color in zip(data.items(), colors):
    if arr is None:
        continue
    ax = axes2[panel] if n_panels > 1 else axes2
    ax.plot(t_zoom, normalise(arr[:N][idx]), color=color, linewidth=1.0)
    ax.set_ylabel('Norm.', fontsize=8)
    ax.set_title(label, fontsize=9, pad=2)
    ax.grid(True, alpha=0.3)
    panel += 1

axes2[-1].set_xlabel('Time (s)', fontsize=10)
plt.tight_layout()
plt.savefig('pipeline_zoomed.png', dpi=150, bbox_inches='tight')
print("Saved: pipeline_zoomed.png")

# ---------------------------------------------------------------
#  FIGURE 3: Raw ECG vs Final LP Smoothing (overlay)
# ---------------------------------------------------------------
fig3, (ax_top, ax_bot) = plt.subplots(2, 1, figsize=(14, 5), sharex=True)
fig3.suptitle('Raw ECG vs Final Preprocessing Output', fontsize=12)

if data['Raw Input (Q1.15)'] is not None:
    ax_top.plot(t[:N], normalise(data['Raw Input (Q1.15)'][:N]),
                'b', linewidth=0.7, label='Raw ECG')
    ax_top.set_title('Raw ECG Input (Q1.15)'); ax_top.grid(True, alpha=0.3)
    ax_top.legend(); ax_top.set_ylabel('Norm. Amplitude')

if data['LP Smoothing Output'] is not None:
    ax_bot.plot(t[:N], normalise(data['LP Smoothing Output'][:N]),
                'g', linewidth=0.9, label='LP Smoothed Envelope')
    ax_bot.set_title('LP Smoothed Envelope (Final Pre-Processing Output)')
    ax_bot.grid(True, alpha=0.3); ax_bot.legend()
    ax_bot.set_ylabel('Norm. Amplitude'); ax_bot.set_xlabel('Time (s)')

plt.tight_layout()
plt.savefig('raw_vs_final.png', dpi=150, bbox_inches='tight')
print("Saved: raw_vs_final.png")

# ---------------------------------------------------------------
#  STATISTICS SUMMARY
# ---------------------------------------------------------------
print("\n=== Statistics Summary ===")
print(f"{'Stage':<28} {'Min':>8} {'Max':>8} {'Mean':>10} {'Std':>10}")
print("-" * 68)
for label, arr in data.items():
    if arr is None:
        print(f"  {label:<26}  FILE NOT FOUND")
        continue
    a = arr[:N].astype(np.float32)
    print(f"  {label:<26}  {a.min():>8.1f}  {a.max():>8.1f}  "
          f"{a.mean():>10.2f}  {a.std():>10.2f}")

plt.show()   # Display all figures interactively
print("\nDone! Review the saved PNG files and figure windows.")
