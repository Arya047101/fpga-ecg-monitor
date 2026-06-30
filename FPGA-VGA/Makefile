# =============================================================================
# Makefile — ECG Monitor Project
# Works on macOS with Icarus Verilog + GTKWave
#
# Install dependencies (one time):
#   brew install icarus-verilog
#   brew install --cask gtkwave
#
# Usage:
#   make preprocess     — simulate all 5 preprocessing stages in sequence
#   make qrs            — simulate full QRS detection pipeline
#   make vga_tb         — simulate full top-level with VGA (takes ~2 min)
#   make all            — run everything in order
#   make wave_preproc   — open GTKWave for preprocessing
#   make wave_qrs       — open GTKWave for QRS pipeline
#   make wave_vga       — open GTKWave for full system
#   make plot           — run all Python plots (requires numpy/matplotlib)
#   make clean          — remove generated files
# =============================================================================

IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave
PYTHON   = python3

# All RTL source files (no testbenches)
RTL_PREPROC = bandpass_filter.v derivative_filter.v squaring.v \
              moving_window_integrator.v lowpass_filter.v

RTL_QRS     = centered_derivative.v adaptive_threshold.v \
              peak_detector.v rr_calculator.v qrs_detector.v

RTL_VGA     = vga_controller.v vga_waveform.v seg7_driver.v

RTL_ALL     = $(RTL_PREPROC) $(RTL_QRS) $(RTL_VGA) top_ecg_monitor.v

# ── Preprocessing stage simulations ──────────────────────────────────────────
preprocess: sim_bpf sim_deriv sim_sq sim_mwi sim_lps
	@echo "All preprocessing stages complete."
	@echo "Output files: out_bpf.hex out_deriv.hex out_sq.hex out_mwi.hex out_lps.hex"

sim_bpf: tb_bandpass_filter.v bandpass_filter.v ecg_record100.hex
	$(IVERILOG) -o $@ tb_bandpass_filter.v bandpass_filter.v
	$(VVP) $@
	@echo "BPF done -> out_bpf.hex"

sim_deriv: tb_derivative_filter.v derivative_filter.v out_bpf.hex
	$(IVERILOG) -o $@ tb_derivative_filter.v derivative_filter.v
	$(VVP) $@
	@echo "Derivative done -> out_deriv.hex"

sim_sq: tb_squaring.v squaring.v out_deriv.hex
	$(IVERILOG) -o $@ tb_squaring.v squaring.v
	$(VVP) $@
	@echo "Squaring done -> out_sq.hex"

sim_mwi: tb_mwi.v moving_window_integrator.v out_sq.hex
	$(IVERILOG) -o $@ tb_mwi.v moving_window_integrator.v
	$(VVP) $@
	@echo "MWI done -> out_mwi.hex"

sim_lps: tb_lowpass_filter.v lowpass_filter.v out_mwi.hex
	$(IVERILOG) -o $@ tb_lowpass_filter.v lowpass_filter.v
	$(VVP) $@
	@echo "LPS done -> out_lps.hex"

# ── QRS detection pipeline ─────────────────────────────────────────────────────
qrs: sim_qrs
	@echo "QRS pipeline complete."
	@echo "Output: out_cderiv.hex out_threshold.hex out_peaks.hex out_heartrate.hex out_rr.hex"

sim_qrs: tb_qrs_full_pipeline.v $(RTL_QRS) out_lps.hex
	$(IVERILOG) -o $@ tb_qrs_full_pipeline.v $(RTL_QRS)
	$(VVP) $@

# ── Full top-level with VGA ───────────────────────────────────────────────────
# NOTE: This runs for 12 simulated seconds — may take 2-5 minutes on Mac
vga_tb: sim_top
	@echo "Full system simulation complete."

sim_top: tb_top_ecg_monitor.v $(RTL_ALL) ecg_record100.hex
	$(IVERILOG) -o $@ tb_top_ecg_monitor.v $(RTL_ALL)
	@echo "Starting simulation (12 simulated seconds = ~3 min real time)..."
	$(VVP) $@

# ── GTKWave waveform viewers ──────────────────────────────────────────────────
wave_preproc: bpf_wave.vcd
	$(GTKWAVE) bpf_wave.vcd &

wave_qrs: qrs_pipeline.vcd
	$(GTKWAVE) qrs_pipeline.vcd &

wave_vga: top_ecg.vcd
	$(GTKWAVE) top_ecg.vcd &

# ── Python plots ──────────────────────────────────────────────────────────────
plot: plot_preproc plot_qrs

plot_preproc: out_lps.hex
	$(PYTHON) bpplot.py &
	$(PYTHON) plotder.py &
	$(PYTHON) plotsqr.py &
	$(PYTHON) plotmwi.py &
	$(PYTHON) plotlpf.py &

plot_qrs: out_peaks.hex
	$(PYTHON) plot_qrs_full_pipeline.py

# ── Run all stages in order ────────────────────────────────────────────────────
all: preprocess qrs vga_tb
	@echo "============================================"
	@echo " All simulations complete!"
	@echo " Run 'make plot' to visualise results."
	@echo "============================================"

# ── Check hex file exists (ecg download) ─────────────────────────────────────
ecg_record100.hex:
	@echo "ERROR: ecg_record100.hex not found."
	@echo "Run: python3 download_and_convert.py"
	@exit 1

# ── Clean ─────────────────────────────────────────────────────────────────────
clean:
	rm -f sim_bpf sim_deriv sim_sq sim_mwi sim_lps sim_qrs sim_top
	rm -f out_bpf.hex out_deriv.hex out_sq.hex out_mwi.hex out_lps.hex
	rm -f out_cderiv.hex out_threshold.hex out_peaks.hex out_heartrate.hex out_rr.hex
	rm -f out_fpga_*.hex out_pipe_*.hex
	rm -f *.vcd
	rm -f *.png
	@echo "Clean done."

.PHONY: preprocess qrs vga_tb all plot plot_preproc plot_qrs clean \
        wave_preproc wave_qrs wave_vga
