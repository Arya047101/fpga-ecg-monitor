#!/usr/bin/env python3
"""
plot_heartrate.py
Plots instantaneous heart rate and RR intervals from rr_calculator output.
Reads: out_heartrate.hex (10-bit BPM), out_rr.hex (12-bit samples)
Also overlays the raw ECG for context.
"""
import numpy as np
import matplotlib.pyplot as plt

FS = 360

def read_hex_16(filename):
    vals = []
    with open(filename) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            vals.append(int(line, 16))
    return np.array(vals, dtype=np.uint16)

try:
    hr_data = read_hex_16('out_heartrate.hex')
    rr_data = read_hex_16('out_rr.hex')
    print(f"Heart rate beats: {len(hr_data)}, RR intervals: {len(rr_data)}")
except FileNotFoundError as e:
    print(f"ERROR: {e}"); exit(1)

# Convert RR samples → milliseconds
rr_ms = rr_data.astype(float) * 1000.0 / FS

n_beats = min(len(hr_data), len(rr_data))
beat_num = np.arange(1, n_beats + 1)

print(f"\n=== Heart Rate Statistics ({n_beats} beats) ===")
print(f"  Mean HR  : {hr_data[:n_beats].mean():.1f} BPM")
print(f"  Min HR   : {hr_data[:n_beats].min()} BPM")
print(f"  Max HR   : {hr_data[:n_beats].max()} BPM")
print(f"  Mean RR  : {rr_ms[:n_beats].mean():.1f} ms")
print(f"  RR range : {rr_ms[:n_beats].min():.0f}–{rr_ms[:n_beats].max():.0f} ms")

fig, axes = plt.subplots(3, 1, figsize=(12, 9))
fig.suptitle(f'QRS Detection Stage — Heart Rate Analysis\n'
             f'{n_beats} beats detected, Mean HR = {hr_data[:n_beats].mean():.1f} BPM',
             fontsize=13, fontweight='bold')

# Top: HR per beat
axes[0].step(beat_num, hr_data[:n_beats], color='crimson', lw=1.2, where='post')
axes[0].axhspan(60, 100, color='green', alpha=0.1, label='Normal range (60–100 BPM)')
axes[0].axhline(hr_data[:n_beats].mean(), color='green', lw=0.8, ls='--',
                label=f'Mean = {hr_data[:n_beats].mean():.1f} BPM')
axes[0].set_title('Instantaneous Heart Rate (BPM per beat)')
axes[0].set_ylabel('Heart Rate (BPM)'); axes[0].set_xlabel('Beat #')
axes[0].legend(fontsize=9); axes[0].grid(True, alpha=0.3)

# Middle: RR intervals
axes[1].bar(beat_num, rr_ms[:n_beats], color='steelblue', alpha=0.7, width=0.6)
axes[1].axhline(rr_ms[:n_beats].mean(), color='orange', lw=1.2, ls='--',
                label=f'Mean RR = {rr_ms[:n_beats].mean():.1f} ms')
axes[1].set_title('RR Intervals (ms)')
axes[1].set_ylabel('RR Interval (ms)'); axes[1].set_xlabel('Beat #')
axes[1].legend(fontsize=9); axes[1].grid(True, alpha=0.3)

# Bottom: Poincaré plot (RR[n] vs RR[n+1]) — standard arrhythmia check
if n_beats > 2:
    axes[2].scatter(rr_ms[:n_beats-1], rr_ms[1:n_beats],
                    color='purple', alpha=0.7, s=30, label='RR[n] vs RR[n+1]')
    rmin, rmax = rr_ms.min()-20, rr_ms.max()+20
    axes[2].plot([rmin, rmax], [rmin, rmax], 'k--', lw=0.7, alpha=0.5, label='Identity line')
    axes[2].set_title('Poincaré Plot (RR[n] vs RR[n+1]) — HRV assessment')
    axes[2].set_xlabel('RR[n] (ms)'); axes[2].set_ylabel('RR[n+1] (ms)')
    axes[2].legend(fontsize=9); axes[2].grid(True, alpha=0.3)
    axes[2].set_aspect('equal', 'box')
else:
    axes[2].text(0.5, 0.5, 'Insufficient beats for Poincaré plot',
                 ha='center', va='center', transform=axes[2].transAxes)

plt.tight_layout()
plt.savefig('plot_heartrate.png', dpi=150, bbox_inches='tight')
print("Saved: plot_heartrate.png")
plt.show()
