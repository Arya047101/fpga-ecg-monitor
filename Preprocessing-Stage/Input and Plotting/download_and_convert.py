import wfdb          
import numpy as np   

RECORD    = '100'            
DB_NAME   = 'mitdb'         
N_SECONDS = 10              
FS        = 360              
N_SAMPLES = N_SECONDS * FS   
CHANNEL   = 0                

HEX_FILE  = 'ecg_record100.hex'  

print(f"Downloading MIT-BIH record {RECORD} from PhysioNet...")

record_obj = wfdb.rdsamp(
    record_name=RECORD,
    pn_dir=DB_NAME,           
    sampto=N_SAMPLES         
)

p_signal = record_obj[0]     
fields   = record_obj[1]    

print(f"Record loaded: {fields['sig_len']} samples, "
      f"{fields['n_sig']} channels, fs={fields['fs']} Hz")
print(f"Units: {fields['units']}, Signal names: {fields['sig_name']}")

ecg_mv = p_signal[:, CHANNEL]   
ecg_mv = ecg_mv[:N_SAMPLES]      

print(f"\nRaw ECG stats (mV):")
print(f"  Min: {ecg_mv.min():.4f} mV")
print(f"  Max: {ecg_mv.max():.4f} mV")
print(f"  Std: {ecg_mv.std():.4f} mV")

max_val  = np.max(np.abs(ecg_mv))           
ecg_norm = ecg_mv / max_val                  
ecg_q15  = np.round(ecg_norm * 32767).astype(np.int16)  

print(f"\nFixed-Point (Q1.15) stats:")
print(f"  Min: {ecg_q15.min()} (0x{int(ecg_q15.min()) & 0xFFFF:04X})")
print(f"  Max: {ecg_q15.max()} (0x{int(ecg_q15.max()) & 0xFFFF:04X})")
print(f"  Samples: {len(ecg_q15)}")
print(f"\nWriting hex file: {HEX_FILE}")

with open(HEX_FILE, 'w') as f:
    for sample in ecg_q15:
        hex_str = f"{int(sample) & 0xFFFF:04X}\n"   
        f.write(hex_str)

print(f"Written {len(ecg_q15)} samples to {HEX_FILE}")
print(f"File size: {len(ecg_q15)*5} bytes (4 hex chars + newline per sample)")

print("\nFirst 10 samples (mV -> Q1.15 -> Hex):")
print(f"{'Index':>5}  {'mV':>10}  {'Q1.15':>8}  {'Hex':>6}")
print("-" * 35)
for i in range(10):
    print(f"{i:>5}  {ecg_mv[i]:>10.4f}  {ecg_q15[i]:>8d}  "
          f"0x{int(ecg_q15[i]) & 0xFFFF:04X}")

print("\nDone! Use ecg_record100.hex as $readmemh input in Verilog testbenches.")
