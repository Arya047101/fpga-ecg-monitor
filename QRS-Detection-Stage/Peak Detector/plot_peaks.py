#!/usr/bin/env python3
"""
plot_peaks.py
Plots LPS envelope with R-peak detections overlaid.
Reads: out_lps.hex, out_peaks.hex (non-zero = peak, value = amplitude), out_threshold.hex
Key visual: red triangles at R-peak locations; threshold shown as dashed.
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

lps    = read_hex('out_lps.hex',    signed=False)
peaks  = read_hex('out_peaks.hex',  signed=False)
thresh = read_hex('out_threshold.hex', signed=False)

N = min(len(lps), len(peaks), len(thresh))
t = np.arange(N) / FS

# Find peak locations (non-zero entries in peaks file)
peak_idx  = np.where(peaks[:N] > 0)[0]
peak_times = peak_idx / FS
peak_amps  = lps[peak_idx] if len(peak_idx) > 0 else np.array([])

print(f"Detected {len(peak_idx)} R-peaks in {N/FS:.1f} s")
if len(peak_idx) > 1:
    rr = np.diff(peak_idx) / FS  # RR in seconds
    hr = 60.0 / rr               # Instantaneous HR
    print(f"Mean HR = {hr.mean():.1f} BPM  |  Std = {hr.std():.1f} BPM")
    print(f"RR range: {rr.min()*1000:.0f}–{rr.max()*1000:.0f} ms")

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 8), sharex=True)
fig.suptitle(f'QRS Stage 3: Peak Detector — {len(peak_idx)} R-peaks detected in {N/FS:.1f} s\n'
             f'Adaptive threshold with 200 ms refractory period', fontsize=13, fontweight='bold')

ax1.plot(t, lps[:N],   color='teal',  lw=0.8, label='LPS Envelope')
ax1.plot(t, thresh[:N], color='red',  lw=1.0, ls='--', alpha=0.7, label='Adaptive Threshold')
ax1.scatter(peak_times, peak_amps, color='crimson', s=60, zorder=5,
            marker='^', label=f'R-peaks ({len(peak_idx)} detected)')
ax1.set_title('LPS Envelope with Detected R-peaks and Adaptive Threshold')
ax1.set_ylabel('Amplitude (counts)'); ax1.legend(loc='upper right', fontsize=9)
ax1.grid(True, alpha=0.3)

# Instantaneous HR plot
if len(peak_idx) > 1:
    hr_times = (peak_idx[1:] + peak_idx[:-1]) / 2 / FS  # Midpoint times
    ax2.step(hr_times, hr, color='darkorange', lw=1.2, where='mid', label='Instantaneous HR')
    ax2.axhline(hr.mean(), color='green', lw=0.8, ls='--', label=f'Mean HR = {hr.mean():.1f} BPM')
    ax2.axhspan(60, 100, color='green', alpha=0.05, label='Normal range (60–100 BPM)')
    ax2.set_ylim([0, max(200, hr.max()+20)])
    ax2.set_title('Instantaneous Heart Rate (BPM)')
    ax2.set_ylabel('Heart Rate (BPM)'); ax2.set_xlabel('Time (s)')
    ax2.legend(loc='upper right', fontsize=9); ax2.grid(True, alpha=0.3)
else:
    ax2.text(0.5, 0.5, 'Insufficient peaks for HR calculation',
             ha='center', va='center', transform=ax2.transAxes)

plt.tight_layout()
plt.savefig('plot_peaks_full.png', dpi=150, bbox_inches='tight')
print("Saved: plot_peaks_full.png")

# Zoomed view showing 2-3 beats clearly
t1, t2 = 1.0, 4.0
idx = (t >= t1) & (t <= t2); tz = t[idx]
pidx_z = peak_times[(peak_times >= t1) & (peak_times <= t2)]
pamp_z = lps[peak_idx[(peak_times >= t1) & (peak_times <= t2)]]

fig2, ax = plt.subplots(figsize=(12, 5))
ax.plot(tz, lps[:N][idx],   color='teal', lw=1.0)
ax.plot(tz, thresh[:N][idx], color='red', lw=1.2, ls='--', alpha=0.7)
ax.scatter(pidx_z, pamp_z, color='crimson', s=80, zorder=5, marker='^')
ax.set_title('QRS Stage 3: Peak Detector — Zoomed (1.0–4.0 s)')
ax.set_ylabel('Amplitude'); ax.set_xlabel('Time (s)'); ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('plot_peaks_zoom.png', dpi=150, bbox_inches='tight')
print("Saved: plot_peaks_zoom.png")
plt.show()
