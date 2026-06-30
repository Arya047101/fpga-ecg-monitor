// =============================================================================
// qrs_detector.v
// QRS Detection Stage — Top-Level Integration Module
// Purpose : Connects all QRS detection sub-modules in sequence:
//           LPS Envelope → Centered Derivative → Peak Detector (+ Adaptive
//           Threshold) → RR Calculator → Heart Rate / Arrhythmia Output
//
//  Pipeline latency: 2 samples (centered derivative delay)
//
//  Outputs:
//    peak_flag      — 1-cycle pulse when an R-peak is detected
//    heart_rate     — instantaneous HR in BPM (10-bit, 0-1023)
//    rr_interval    — RR interval in samples (12-bit)
//    arrhythmia_flag— 1 when rhythm is abnormal
//    threshold_out  — adaptive threshold (for monitoring/debugging)
// =============================================================================
`timescale 1ns / 1ps

module qrs_detector (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [15:0] envelope_in,       // LPS output (unsigned 16-bit)

    output wire        peak_flag,         // R-peak detected
    output wire [15:0] peak_value,        // Amplitude at R-peak
    output wire [9:0]  heart_rate,        // Heart rate (BPM)
    output wire [11:0] rr_interval,       // RR interval (samples)
    output wire        arrhythmia_flag,   // Arrhythmia indicator
    output wire [15:0] threshold_out,     // Adaptive threshold level
    output wire        valid_out          // Output valid
);

// ── Internal wires ──────────────────────────────────────────────────────────
wire signed [16:0] deriv_out;
wire               deriv_valid;

wire [15:0]        thresh_out;
wire               thresh_valid;

wire               peak_f;
wire [15:0]        peak_v;
wire               peak_valid;

wire               rr_valid;

// ── Stage 1: Centered Derivative ─────────────────────────────────────────
centered_derivative u_cderiv (
    .clk       (clk),
    .rst_n     (rst_n),
    .valid_in  (valid_in),
    .x_in      (envelope_in),
    .y_out     (deriv_out),
    .valid_out (deriv_valid)
);

// ── Stage 2: Adaptive Threshold ──────────────────────────────────────────
// Feedback: is_qrs comes from peak_flag (one cycle behind — acceptable)
adaptive_threshold u_thresh (
    .clk           (clk),
    .rst_n         (rst_n),
    .valid_in      (valid_in),   // Uses raw envelope timing (parallel with deriv)
    .x_in          (envelope_in),
    .is_qrs        (peak_f),     // Feed back from peak detector
    .threshold_out (thresh_out),
    .valid_out     (thresh_valid)
);

// ── Stage 3: Peak Detector ───────────────────────────────────────────────
peak_detector #(.REFRACTORY(72)) u_peak (
    .clk          (clk),
    .rst_n        (rst_n),
    .valid_in     (deriv_valid),
    .envelope_in  (envelope_in),
    .deriv_in     (deriv_out),
    .threshold_in (thresh_out),
    .peak_flag    (peak_f),
    .peak_value   (peak_v),
    .valid_out    (peak_valid)
);

// ── Stage 4: RR Interval & Heart Rate ────────────────────────────────────
rr_calculator #(.FS(360), .RR_MAX(1440), .RR_MIN(72)) u_rr (
    .clk             (clk),
    .rst_n           (rst_n),
    .valid_in        (peak_valid),
    .peak_flag       (peak_f),
    .rr_interval     (rr_interval),
    .heart_rate      (heart_rate),
    .arrhythmia_flag (arrhythmia_flag),
    .rr_valid        (rr_valid)
);

// ── Output assignments ───────────────────────────────────────────────────
assign peak_flag     = peak_f;
assign peak_value    = peak_v;
assign threshold_out = thresh_out;
assign valid_out     = peak_valid;

endmodule
