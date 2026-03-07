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
    dtype = np.int16 if signed else np.uint16
    return np.array(values, dtype=dtype)

print("Loading ecg_record100.hex (raw input)...")
raw = read_hex('ecg_record100.hex', signed=True)   

print("Loading out_bpf.hex (BPF output)...")
bpf = read_hex('out_bpf.hex', signed=True)        

N = min(len(raw), len(bpf))  
t = np.arange(N) / FS         

print(f"Plotting {N} samples ({N/FS:.1f} s) at {FS} Hz")

def norm(x):
    m = np.max(np.abs(x.astype(float)))
    return x.astype(float) / m if m != 0 else x.astype(float)

fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(14, 8), sharex=True)
fig.suptitle('Stage 1: Bandpass Filter — Before vs After\n'
             '(5–15 Hz passband, LP+HP cascade)', fontsize=13, fontweight='bold')

# Top panel: raw input
ax1.plot(t, norm(raw[:N]), color='steelblue', linewidth=0.8, label='Raw ECG (Input)')
ax1.set_title('Before — Raw ECG (Q1.15, normalised)')
ax1.set_ylabel('Normalised Amplitude')
ax1.legend(loc='upper right', fontsize=9)
ax1.grid(True, alpha=0.3)

# Middle panel: BPF output
ax2.plot(t, norm(bpf[:N]), color='darkorange', linewidth=0.8, label='BPF Output')
ax2.set_title('After — Bandpass Filtered (5–15 Hz)')
ax2.set_ylabel('Normalised Amplitude')
ax2.legend(loc='upper right', fontsize=9)
ax2.grid(True, alpha=0.3)

# Bottom panel: overlay
ax3.plot(t, norm(raw[:N]), color='steelblue', linewidth=0.6, alpha=0.7, label='Raw ECG')
ax3.plot(t, norm(bpf[:N]), color='darkorange', linewidth=0.8, alpha=0.9, label='BPF Output')
ax3.set_title('Overlay — Input vs Output')
ax3.set_ylabel('Normalised Amplitude')
ax3.set_xlabel('Time (s)')
ax3.legend(loc='upper right', fontsize=9)
ax3.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_bpf_full.png', dpi=150, bbox_inches='tight')
print("Saved: plot_bpf_full.png")

t1, t2 = 1.0, 3.0                        # Zoom window
idx = (t >= t1) & (t <= t2)              # Boolean mask
tz  = t[idx]                             # Zoomed time axis

fig2, (ax_a, ax_b) = plt.subplots(2, 1, figsize=(12, 6), sharex=True)
fig2.suptitle('Stage 1: Bandpass Filter — Zoomed (1.0–3.0 s)', fontsize=12)

ax_a.plot(tz, norm(raw[:N][idx]), color='steelblue', linewidth=1.0)
ax_a.set_title('Before — Raw ECG'); ax_a.set_ylabel('Norm. Amp.'); ax_a.grid(True, alpha=0.3)

ax_b.plot(tz, norm(bpf[:N][idx]), color='darkorange', linewidth=1.0)
ax_b.set_title('After — BPF Output (5–15 Hz)')
ax_b.set_ylabel('Norm. Amp.'); ax_b.set_xlabel('Time (s)'); ax_b.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('plot_bpf_zoom.png', dpi=150, bbox_inches='tight')
print("Saved: plot_bpf_zoom.png")

# Stats
print(f"\nRaw   — min: {raw[:N].min():6d}  max: {raw[:N].max():6d}  std: {raw[:N].std():.1f}")
print(f"BPF   — min: {bpf[:N].min():6d}  max: {bpf[:N].max():6d}  std: {bpf[:N].std():.1f}")

plt.show()