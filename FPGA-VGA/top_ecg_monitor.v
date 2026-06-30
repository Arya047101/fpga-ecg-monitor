// =============================================================================
// top_ecg_monitor.v
// Top-Level FPGA Module — ECG Heart Rate Monitor
// Target: Nexys 4 DDR (Artix-7 XC7A100T-CSG324)
// Tool:   Vivado (for synthesis) — Quartus Prime (simulation only)
//
// Connects:
//   BRAM ECG playback → Preprocessing pipeline → QRS detection →
//   VGA waveform display + 7-seg BPM + LED arrhythmia indicators
//
// Clock:
//   clk_100mhz — 100 MHz on-board oscillator (W5)
//   pclk_25mhz — derived by dividing by 4 (simple counter, ~25 MHz)
//   ecg_strobe — 360 Hz enable pulse for ECG sample rate
//
// External ports match Nexys 4 DDR pinout exactly.
// =============================================================================
`timescale 1ns / 1ps

module top_ecg_monitor (
    // ── System ────────────────────────────────────────────────────────────────
    input  wire        clk_100mhz,     // W5 — 100 MHz SYSCLK
    input  wire        btnc,           // N17 — Centre button = reset (active high)

    // ── 7-Segment Display ─────────────────────────────────────────────────────
    output wire [7:0]  an,             // Anode select (active low)
    output wire [6:0]  seg,            // Segment cathodes (active low)

    // ── LEDs ──────────────────────────────────────────────────────────────────
    output wire [3:0]  led,            // LD0=arrhythmia, LD1=peak, LD2=active, LD3=heartbeat

    // ── VGA ───────────────────────────────────────────────────────────────────
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        vga_hs,
    output wire        vga_vs
);

// ── Reset (active LOW internally, BTNC is active HIGH on Nexys 4) ────────────
wire rst_n = ~btnc;

// ── Pixel clock: divide 100 MHz by 4 = 25 MHz ────────────────────────────────
reg [1:0] pclk_div;
reg       pclk_25;
always @(posedge clk_100mhz) begin
    if (!rst_n) begin pclk_div <= 2'd0; pclk_25 <= 1'b0; end
    else begin
        pclk_div <= pclk_div + 1;
        if (pclk_div == 2'd1) pclk_25 <= ~pclk_25;  // Toggle at half period
    end
end

// ── ECG sample rate: 100 MHz / 277778 ≈ 360 Hz ───────────────────────────────
localparam ECG_DIV = 277778;
reg [17:0] ecg_div_cnt;
reg        ecg_strobe;
always @(posedge clk_100mhz) begin
    if (!rst_n) begin ecg_div_cnt <= 0; ecg_strobe <= 0; end
    else begin
        ecg_strobe <= 0;
        if (ecg_div_cnt == ECG_DIV - 1) begin
            ecg_div_cnt <= 0;
            ecg_strobe  <= 1;
        end else
            ecg_div_cnt <= ecg_div_cnt + 1;
    end
end

// ── ECG BRAM playback ─────────────────────────────────────────────────────────
// In Vivado: initialise this BRAM from ecg_record100.coe
// In simulation: $readmemh fills it
localparam N_SAMPLES = 3600;
reg [15:0] ecg_bram [0:N_SAMPLES-1];
reg [11:0] ecg_addr;
reg signed [15:0] ecg_sample;

initial $readmemh("ecg_record100.hex", ecg_bram);  // Simulation only

always @(posedge clk_100mhz) begin
    if (!rst_n) begin
        ecg_addr   <= 12'd0;
        ecg_sample <= 16'sd0;
    end else if (ecg_strobe) begin
        ecg_sample <= $signed(ecg_bram[ecg_addr]);
        ecg_addr   <= (ecg_addr == N_SAMPLES - 1) ? 12'd0 : ecg_addr + 1;
        // Loops continuously for demo — remove loop for single-pass
    end
end

// ── Pre-Processing Pipeline ───────────────────────────────────────────────────
wire signed [15:0] bpf_out;      wire bpf_valid;
wire signed [15:0] deriv_pp_out; wire deriv_pp_valid;
wire        [15:0] sq_out;       wire sq_valid;
wire        [15:0] mwi_out;      wire mwi_valid;
wire        [15:0] lps_out;      wire lps_valid;

bandpass_filter         u_bpf  (.clk(clk_100mhz),.rst_n(rst_n),.valid_in(ecg_strobe),    .x_in(ecg_sample),   .y_out(bpf_out),      .valid_out(bpf_valid));
derivative_filter       u_dpp  (.clk(clk_100mhz),.rst_n(rst_n),.valid_in(bpf_valid),     .x_in(bpf_out),      .y_out(deriv_pp_out), .valid_out(deriv_pp_valid));
squaring                u_sq   (.clk(clk_100mhz),.rst_n(rst_n),.valid_in(deriv_pp_valid), .x_in(deriv_pp_out), .y_out(sq_out),       .valid_out(sq_valid));
moving_window_integrator #(.N(30)) u_mwi (.clk(clk_100mhz),.rst_n(rst_n),.valid_in(sq_valid),.x_in(sq_out),.y_out(mwi_out),.valid_out(mwi_valid));
lowpass_filter          u_lps  (.clk(clk_100mhz),.rst_n(rst_n),.valid_in(mwi_valid),     .x_in(mwi_out),      .y_out(lps_out),      .valid_out(lps_valid));

// ── QRS Detection ─────────────────────────────────────────────────────────────
wire        peak_flag;
wire [15:0] peak_value;
wire [9:0]  heart_rate;
wire [11:0] rr_interval;
wire        arrhythmia_flag;
wire [15:0] threshold_out;
wire        qrs_valid;

qrs_detector u_qrs (
    .clk(clk_100mhz), .rst_n(rst_n),
    .valid_in    (lps_valid),
    .envelope_in (lps_out),
    .peak_flag       (peak_flag),
    .peak_value      (peak_value),
    .heart_rate      (heart_rate),
    .rr_interval     (rr_interval),
    .arrhythmia_flag (arrhythmia_flag),
    .threshold_out   (threshold_out),
    .valid_out       (qrs_valid)
);

// ── 7-Segment Display ─────────────────────────────────────────────────────────
seg7_driver u_seg7 (
    .clk        (clk_100mhz),
    .rst_n      (rst_n),
    .heart_rate (heart_rate),
    .arrhythmia (arrhythmia_flag),
    .an         (an),
    .seg        (seg)
);

// ── Heartbeat LED (toggles at each R-peak — visual ~1 Hz blink) ───────────────
reg led_heartbeat;
always @(posedge clk_100mhz) begin
    if (!rst_n)      led_heartbeat <= 1'b0;
    else if (peak_flag) led_heartbeat <= ~led_heartbeat;
end

assign led[0] = arrhythmia_flag;   // LD0 — arrhythmia warning
assign led[1] = peak_flag;         // LD1 — R-peak pulse (brief flash)
assign led[2] = lps_valid;         // LD2 — pipeline active
assign led[3] = led_heartbeat;     // LD3 — heartbeat toggle

// ── VGA Waveform Display ──────────────────────────────────────────────────────
vga_waveform u_vga_wave (
    .clk          (clk_100mhz),
    .pclk         (pclk_25),
    .rst_n        (rst_n),
    .ecg_in       (ecg_sample),
    .lps_in       (lps_out),
    .thresh_in    (threshold_out),
    .peak_flag    (peak_flag),
    .heart_rate   (heart_rate),
    .arrhythmia   (arrhythmia_flag),
    .sample_valid (ecg_strobe),
    .vga_r        (vga_r),
    .vga_g        (vga_g),
    .vga_b        (vga_b),
    .vga_hsync    (vga_hs),
    .vga_vsync    (vga_vs)
);

endmodule
