// =============================================================================
// tb_fpga_preprocessing_pipeline.v
// FPGA Testbench — Complete Pre-Processing Pipeline
// Nexys 4 DDR (Artix-7) / Quartus Prime
//
// Connects all 5 preprocessing stages in series:
//   ECG Input → BPF → Derivative → Squaring → MWI → LPS → Output
//
// Memory model: uses $readmemh to load ECG from BRAM (models Block RAM usage)
// Clock: 100 MHz system clock (Nexys 4 DDR on-board oscillator)
// Input rate: one valid ECG sample every 277,778 ns = 360 Hz
//
// OUTPUT FILES:
//   out_pipe_bpf.hex  — after BPF
//   out_pipe_lps.hex  — final LPS output (for QRS stage)
//
// Compile with all 5 module .v files + this testbench
// =============================================================================
`timescale 1ns / 1ps

module tb_fpga_preprocessing_pipeline;

// ── Clock & timing parameters ──────────────────────────────────────────────
parameter SYS_CLK_PERIOD = 10;          // 100 MHz = 10 ns
parameter ECG_CLK_DIV    = 27778;       // 100 MHz / 360 Hz = 277,778 ns / 10 = 27778 cycles
parameter N_SAMPLES      = 3600;        // 10 seconds @ 360 Hz
parameter HEX_IN         = "ecg_record100.hex";
parameter HEX_OUT_LPS    = "out_pipe_lps.hex";
parameter HEX_OUT_BPF    = "out_pipe_bpf.hex";

// ── Clock & control ────────────────────────────────────────────────────────
reg clk, rst_n;
initial clk = 0;
always #(SYS_CLK_PERIOD/2) clk = ~clk;

// ── ECG sample rate divider ─────────────────────────────────────────────────
reg [16:0] div_cnt;
reg        ecg_valid;      // Pulses once every ECG_CLK_DIV cycles

always @(posedge clk) begin
    if (!rst_n) begin
        div_cnt   <= 17'd0;
        ecg_valid <= 1'b0;
    end else begin
        ecg_valid <= 1'b0;
        if (div_cnt == ECG_CLK_DIV - 1) begin
            div_cnt   <= 17'd0;
            ecg_valid <= 1'b1;
        end else begin
            div_cnt <= div_cnt + 1;
        end
    end
end

// ── ECG BRAM model ──────────────────────────────────────────────────────────
reg [15:0] ecg_mem [0:N_SAMPLES-1];
reg [11:0] ecg_addr;
reg signed [15:0] ecg_sample;

always @(posedge clk) begin
    if (!rst_n) begin
        ecg_addr   <= 12'd0;
        ecg_sample <= 16'sd0;
    end else if (ecg_valid && ecg_addr < N_SAMPLES) begin
        ecg_sample <= $signed(ecg_mem[ecg_addr]);
        ecg_addr   <= ecg_addr + 1;
    end
end

// ── Stage 1: Bandpass Filter ─────────────────────────────────────────────
wire signed [15:0] bpf_out;
wire bpf_valid;

bandpass_filter u_bpf (
    .clk(clk), .rst_n(rst_n),
    .valid_in(ecg_valid), .x_in(ecg_sample),
    .y_out(bpf_out), .valid_out(bpf_valid)
);

// ── Stage 2: Derivative Filter ───────────────────────────────────────────
wire signed [15:0] deriv_out;
wire deriv_valid;

derivative_filter u_deriv (
    .clk(clk), .rst_n(rst_n),
    .valid_in(bpf_valid), .x_in(bpf_out),
    .y_out(deriv_out), .valid_out(deriv_valid)
);

// ── Stage 3: Squaring ────────────────────────────────────────────────────
wire [15:0] sq_out;
wire sq_valid;

squaring u_sq (
    .clk(clk), .rst_n(rst_n),
    .valid_in(deriv_valid), .x_in(deriv_out),
    .y_out(sq_out), .valid_out(sq_valid)
);

// ── Stage 4: Moving Window Integrator ────────────────────────────────────
wire [15:0] mwi_out;
wire mwi_valid;

moving_window_integrator #(.N(30)) u_mwi (
    .clk(clk), .rst_n(rst_n),
    .valid_in(sq_valid), .x_in(sq_out),
    .y_out(mwi_out), .valid_out(mwi_valid)
);

// ── Stage 5: Low-Pass Smoothing ───────────────────────────────────────────
wire [15:0] lps_out;
wire lps_valid;

lowpass_filter u_lps (
    .clk(clk), .rst_n(rst_n),
    .valid_in(mwi_valid), .x_in(mwi_out),
    .y_out(lps_out), .valid_out(lps_valid)
);

// ── File I/O ──────────────────────────────────────────────────────────────
integer f_lps, f_bpf;
integer sample_cnt_lps, sample_cnt_bpf;

// ── Simulation control ────────────────────────────────────────────────────
integer timeout_cnt;

initial begin
    $dumpfile("fpga_preproc_pipe.vcd");
    $dumpvars(0, tb_fpga_preprocessing_pipeline.clk);
    $dumpvars(0, tb_fpga_preprocessing_pipeline.rst_n);
    $dumpvars(0, tb_fpga_preprocessing_pipeline.ecg_valid);
    $dumpvars(0, tb_fpga_preprocessing_pipeline.bpf_out);
    $dumpvars(0, tb_fpga_preprocessing_pipeline.lps_out);
    $dumpvars(0, tb_fpga_preprocessing_pipeline.lps_valid);

    $readmemh(HEX_IN, ecg_mem);
    $display("[TB] Loaded %s", HEX_IN);

    f_lps = $fopen(HEX_OUT_LPS, "w");
    f_bpf = $fopen(HEX_OUT_BPF, "w");
    if (f_lps == 0 || f_bpf == 0) begin
        $display("[TB] ERROR: Cannot open output files"); $finish;
    end
    sample_cnt_lps = 0;
    sample_cnt_bpf = 0;

    // Reset
    rst_n = 0; repeat(20) @(posedge clk);
    rst_n = 1;
    $display("[TB] Reset released at t=%0t ns", $time);

    // Wait until all samples processed + pipeline flush time
    // N_SAMPLES * ECG_CLK_DIV cycles + 200 extra
    timeout_cnt = (N_SAMPLES + 200) * ECG_CLK_DIV;
    repeat(timeout_cnt) @(posedge clk);

    $fclose(f_lps);
    $fclose(f_bpf);
    $display("[TB] Done: BPF=%0d samples, LPS=%0d samples",
             sample_cnt_bpf, sample_cnt_lps);
    $finish;
end

// ── Output capture ────────────────────────────────────────────────────────
always @(posedge clk) begin
    if (bpf_valid && ecg_addr > 0) begin
        $fwrite(f_bpf, "%04X\n", bpf_out & 16'hFFFF);
        sample_cnt_bpf = sample_cnt_bpf + 1;
    end
end

always @(posedge clk) begin
    if (lps_valid && ecg_addr > 0) begin
        $fwrite(f_lps, "%04X\n", lps_out);
        sample_cnt_lps = sample_cnt_lps + 1;
        if (sample_cnt_lps % 360 == 0)
            $display("[TB] Preprocessing: %0d samples (%0d s done)",
                     sample_cnt_lps, sample_cnt_lps/360);
    end
end

endmodule
