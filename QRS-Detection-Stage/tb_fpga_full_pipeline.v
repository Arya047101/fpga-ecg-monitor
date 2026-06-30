// =============================================================================
// tb_fpga_full_pipeline.v
// FPGA Testbench — Complete Heart Rate Monitor (Pre-Processing + QRS Detection)
// Nexys 4 DDR (Artix-7) / Quartus Prime
//
// Full pipeline:
//   BRAM ECG → BPF → Derivative → Squaring → MWI → LPS →
//   Centered Derivative → Adaptive Threshold → Peak Detector →
//   RR Calculator → Heart Rate / Arrhythmia
//
// Also simulates:
//   - 7-segment display encoding (4 digits: HR in BPM)
//   - LED arrhythmia flag output
//   - VGA sync signals (simplified; toggle every 1/60 s)
//
// Clock: 100 MHz system clock
// ECG sample rate: 360 Hz (clock-divided internally)
// =============================================================================
`timescale 1ns / 1ps

module tb_fpga_full_pipeline;

// ── Parameters ──────────────────────────────────────────────────────────────
parameter SYS_CLK_PERIOD  = 10;          // 100 MHz
parameter ECG_CLK_DIV     = 27778;       // 360 Hz divider
parameter N_SAMPLES       = 3600;        // 10 s
parameter HEX_IN          = "ecg_record100.hex";
parameter HEX_OUT_HR      = "out_fpga_heartrate.hex";
parameter HEX_OUT_PEAKS   = "out_fpga_peaks.hex";
parameter DISPLAY_REFRESH = 1000;        // 7-seg mux period in sys clocks

// ── Clock ────────────────────────────────────────────────────────────────────
reg clk_100mhz, rst_n;
initial clk_100mhz = 0;
always #(SYS_CLK_PERIOD/2) clk_100mhz = ~clk_100mhz;

// ── ECG Rate Divider ─────────────────────────────────────────────────────────
reg [16:0] div_cnt;
reg        ecg_valid;

always @(posedge clk_100mhz) begin
    if (!rst_n) begin div_cnt <= 0; ecg_valid <= 0; end
    else begin
        ecg_valid <= 0;
        if (div_cnt == ECG_CLK_DIV - 1) begin div_cnt <= 0; ecg_valid <= 1; end
        else div_cnt <= div_cnt + 1;
    end
end

// ── ECG BRAM ─────────────────────────────────────────────────────────────────
reg [15:0] ecg_mem [0:N_SAMPLES-1];
reg [11:0] ecg_addr;
reg signed [15:0] ecg_sample;
reg pipeline_done;

always @(posedge clk_100mhz) begin
    if (!rst_n) begin ecg_addr <= 0; ecg_sample <= 0; pipeline_done <= 0; end
    else if (ecg_valid) begin
        if (ecg_addr < N_SAMPLES) begin
            ecg_sample <= $signed(ecg_mem[ecg_addr]);
            ecg_addr   <= ecg_addr + 1;
        end else begin
            ecg_sample    <= 0;
            pipeline_done <= 1;
        end
    end
end

// ── Pre-Processing Pipeline ──────────────────────────────────────────────────
wire signed [15:0] bpf_out; wire bpf_valid;
wire signed [15:0] deriv_pp_out; wire deriv_pp_valid;
wire [15:0] sq_out; wire sq_valid;
wire [15:0] mwi_out; wire mwi_valid;
wire [15:0] lps_out; wire lps_valid;

bandpass_filter         u_bpf  (.clk(clk_100mhz),.rst_n(rst_n),.valid_in(ecg_valid),  .x_in(ecg_sample),   .y_out(bpf_out),      .valid_out(bpf_valid));
derivative_filter       u_derp (.clk(clk_100mhz),.rst_n(rst_n),.valid_in(bpf_valid),  .x_in(bpf_out),      .y_out(deriv_pp_out), .valid_out(deriv_pp_valid));
squaring                u_sq   (.clk(clk_100mhz),.rst_n(rst_n),.valid_in(deriv_pp_valid),.x_in(deriv_pp_out),.y_out(sq_out),       .valid_out(sq_valid));
moving_window_integrator #(.N(30)) u_mwi (.clk(clk_100mhz),.rst_n(rst_n),.valid_in(sq_valid),.x_in(sq_out),.y_out(mwi_out),.valid_out(mwi_valid));
lowpass_filter          u_lps  (.clk(clk_100mhz),.rst_n(rst_n),.valid_in(mwi_valid),  .x_in(mwi_out),      .y_out(lps_out),      .valid_out(lps_valid));

// ── QRS Detection Pipeline ───────────────────────────────────────────────────
wire        qrs_peak_flag;
wire [15:0] qrs_peak_value;
wire [9:0]  qrs_heart_rate;
wire [11:0] qrs_rr_interval;
wire        qrs_arrhythmia;
wire [15:0] qrs_threshold;
wire        qrs_valid;

qrs_detector u_qrs (
    .clk(clk_100mhz), .rst_n(rst_n),
    .valid_in(lps_valid), .envelope_in(lps_out),
    .peak_flag(qrs_peak_flag), .peak_value(qrs_peak_value),
    .heart_rate(qrs_heart_rate), .rr_interval(qrs_rr_interval),
    .arrhythmia_flag(qrs_arrhythmia), .threshold_out(qrs_threshold),
    .valid_out(qrs_valid)
);

// ── 7-Segment Display Encoder (BPM, 3 digits) ───────────────────────────────
// Digit encoding: 7-seg common-anode (active low), segments abcdefg
// Real FPGA implementation multiplexes; here we just log the values
reg [3:0] seg_dig0, seg_dig1, seg_dig2;   // Hundreds, tens, units of BPM

always @(posedge clk_100mhz) begin
    if (!rst_n) begin seg_dig0<=0; seg_dig1<=0; seg_dig2<=0; end
    else if (qrs_peak_flag) begin
        seg_dig0 <= qrs_heart_rate / 100;
        seg_dig1 <= (qrs_heart_rate % 100) / 10;
        seg_dig2 <= qrs_heart_rate % 10;
    end
end

// ── LED Arrhythmia Indicator ─────────────────────────────────────────────────
// LD0 = arrhythmia, LD1 = peak detected, LD2 = pipeline active
wire [2:0] leds;
assign leds[0] = qrs_arrhythmia;
assign leds[1] = qrs_peak_flag;
assign leds[2] = lps_valid;

// ── Output Capture ───────────────────────────────────────────────────────────
integer f_hr, f_peaks;
integer beat_cnt, tot_hr;
real    start_time_s;

initial begin
    $dumpfile("fpga_full_pipeline.vcd");
    $dumpvars(0, clk_100mhz);
    $dumpvars(0, rst_n);
    $dumpvars(0, lps_valid);
    $dumpvars(0, lps_out);
    $dumpvars(0, qrs_peak_flag);
    $dumpvars(0, qrs_heart_rate);
    $dumpvars(0, qrs_arrhythmia);
    $dumpvars(0, leds);

    $readmemh(HEX_IN, ecg_mem);
    $display("[FPGA TB] Loaded ECG: %s (%0d samples)", HEX_IN, N_SAMPLES);

    f_hr    = $fopen(HEX_OUT_HR,    "w");
    f_peaks = $fopen(HEX_OUT_PEAKS, "w");
    if (f_hr == 0 || f_peaks == 0) begin
        $display("[FPGA TB] ERROR: Cannot open output files"); $finish;
    end
    beat_cnt   = 0;
    tot_hr     = 0;

    // Reset
    rst_n = 0; repeat(50) @(posedge clk_100mhz);
    rst_n = 1;
    $display("[FPGA TB] Reset released, pipeline starting...");
    start_time_s = $realtime * 1e-9;

    // Run until all ECG samples processed + pipeline flush
    repeat((N_SAMPLES + 300) * ECG_CLK_DIV) @(posedge clk_100mhz);

    $fclose(f_hr); $fclose(f_peaks);

    if (beat_cnt > 0) begin
        $display("[FPGA TB] === FINAL RESULTS ===");
        $display("[FPGA TB] Total beats detected : %0d", beat_cnt);
        $display("[FPGA TB] Average heart rate   : %0d BPM", tot_hr/beat_cnt);
        $display("[FPGA TB] Expected for MIT-BIH Record 100: ~70 BPM, ~12 beats in 10s");
    end else begin
        $display("[FPGA TB] WARNING: No beats detected — check threshold/pipeline");
    end
    $finish;
end

// ── Peak/HR logging ──────────────────────────────────────────────────────────
always @(posedge clk_100mhz) begin
    if (qrs_peak_flag) begin
        beat_cnt = beat_cnt + 1;
        $fwrite(f_peaks, "%04X\n", qrs_peak_value);
        $display("[FPGA TB] Beat #%0d: HR=%0d BPM  RR=%0d samples  Arrhy=%b  7seg=[%0d%0d%0d]",
                 beat_cnt, qrs_heart_rate, qrs_rr_interval, qrs_arrhythmia,
                 seg_dig0, seg_dig1, seg_dig2);
    end
end

always @(posedge clk_100mhz) begin
    if (qrs_peak_flag && qrs_heart_rate > 0) begin
        $fwrite(f_hr, "%04X\n", {6'b0, qrs_heart_rate});
        tot_hr = tot_hr + qrs_heart_rate;
    end
end

// ── Timeout watchdog ─────────────────────────────────────────────────────────
initial begin
    #((N_SAMPLES + 500) * ECG_CLK_DIV * SYS_CLK_PERIOD);
    $display("[FPGA TB] TIMEOUT — simulation exceeded maximum expected time");
    $finish;
end

endmodule
