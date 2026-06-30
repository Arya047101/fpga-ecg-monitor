// =============================================================================
// vga_waveform.v
// VGA Waveform Renderer — displays ECG pipeline stages on monitor
//
// Screen layout (640×480):
//
//   Y=0..30    Title bar: "ECG Heart Rate Monitor  HR: XXX BPM"
//   Y=30..195  Panel 1 — Raw ECG (blue)
//   Y=195..210 Divider
//   Y=210..375 Panel 2 — LPS Envelope + Adaptive Threshold (teal + red dashed)
//   Y=375..390 Divider
//   Y=390..470 Panel 3 — Detected R-peaks (vertical red bars on ECG)
//   Y=470..480 Status bar: arrhythmia warning if active
//
// Each waveform panel has 165 pixels of vertical space.
// The waveform buffer holds the last 640 samples (one per column).
// Samples are scaled to fit within their panel's pixel range.
//
// Inputs:
//   ecg_in    — raw ECG sample (signed 16-bit Q1.15)
//   lps_in    — LPS envelope sample (unsigned 16-bit)
//   thresh_in — adaptive threshold (unsigned 16-bit)
//   peak_flag — R-peak detected this sample
//   heart_rate— current HR in BPM (10-bit)
//   arrhythmia— arrhythmia flag
//   sample_valid — new sample ready (360 Hz strobe)
// =============================================================================
`timescale 1ns / 1ps

module vga_waveform #(
    parameter SCREEN_W = 640,
    parameter SCREEN_H = 480,
    parameter BUF_DEPTH = 640  // One sample per pixel column
) (
    input  wire        clk,          // System clock (100 MHz)
    input  wire        pclk,         // Pixel clock  (~25 MHz)
    input  wire        rst_n,

    // Data inputs (100 MHz domain — one sample per valid pulse)
    input  wire signed [15:0] ecg_in,
    input  wire        [15:0] lps_in,
    input  wire        [15:0] thresh_in,
    input  wire               peak_flag,
    input  wire        [9:0]  heart_rate,
    input  wire               arrhythmia,
    input  wire               sample_valid,

    // VGA outputs
    output wire        [3:0]  vga_r,
    output wire        [3:0]  vga_g,
    output wire        [3:0]  vga_b,
    output wire               vga_hsync,
    output wire               vga_vsync
);

// ── VGA timing ────────────────────────────────────────────────────────────────
wire [9:0] h_pos, v_pos;
wire active;

vga_controller u_vga (
    .pclk  (pclk),
    .rst_n (rst_n),
    .h_pos (h_pos),
    .v_pos (v_pos),
    .active(active),
    .hsync (vga_hsync),
    .vsync (vga_vsync)
);

// ── Circular sample buffers (written at 360 Hz, read at pixel rate) ───────────
// Stored as 8-bit scaled values to save BRAM
reg [7:0] buf_ecg   [0:BUF_DEPTH-1];
reg [7:0] buf_lps   [0:BUF_DEPTH-1];
reg [7:0] buf_thresh[0:BUF_DEPTH-1];
reg       buf_peak  [0:BUF_DEPTH-1];

reg [9:0] wr_ptr;   // Write pointer (advances with each new sample)

// Scale helpers: map 16-bit values to 8-bit display range
// ECG (signed -32768..32767) → 0..255
function [7:0] scale_ecg;
    input signed [15:0] s;
    reg [16:0] tmp;
    begin
        tmp = {1'b0, s[15:0]} + 17'd32768;  // Offset to unsigned 0..65535
        scale_ecg = tmp[15:8];               // Take top 8 bits = /256
    end
endfunction

// Unsigned 16-bit → 8-bit (take top 8 bits)
function [7:0] scale_u16;
    input [15:0] u;
    begin scale_u16 = u[15:8]; end
endfunction

// Write new samples into buffers (100 MHz domain)
always @(posedge clk) begin
    if (!rst_n) begin
        wr_ptr <= 10'd0;
    end else if (sample_valid) begin
        buf_ecg   [wr_ptr] <= scale_ecg(ecg_in);
        buf_lps   [wr_ptr] <= scale_u16(lps_in);
        buf_thresh[wr_ptr] <= scale_u16(thresh_in);
        buf_peak  [wr_ptr] <= peak_flag;
        wr_ptr <= (wr_ptr == BUF_DEPTH - 1) ? 10'd0 : wr_ptr + 1;
    end
end

// ── Read buffer at pixel clock (oldest sample at x=0, newest at x=639) ────────
wire [9:0] rd_ptr = (wr_ptr + h_pos) % BUF_DEPTH;

wire [7:0] ecg_val    = buf_ecg   [rd_ptr];
wire [7:0] lps_val    = buf_lps   [rd_ptr];
wire [7:0] thresh_val = buf_thresh[rd_ptr];
wire       peak_val   = buf_peak  [rd_ptr];

// ── Panel pixel bounds ─────────────────────────────────────────────────────────
// Panel 1 (ECG):      rows  35..194  = 160px tall, mid = 114
// Panel 2 (LPS):      rows 210..374  = 165px tall, mid = 292
// Panel 3 (Peaks):    rows 390..469  = 80px tall,  mid = 429
localparam P1_TOP = 35;  localparam P1_BOT = 194;  localparam P1_MID = 114;
localparam P2_TOP = 210; localparam P2_BOT = 374;  localparam P2_MID = 292;
localparam P3_TOP = 390; localparam P3_BOT = 469;

// Convert 8-bit sample value to pixel row within a panel
// val=0→bottom, val=255→top; panel height = BOT-TOP
function [9:0] to_row_p1;
    input [7:0] val;
    begin
        to_row_p1 = P1_BOT - ((val * (P1_BOT - P1_TOP)) >> 8);
    end
endfunction
function [9:0] to_row_p2;
    input [7:0] val;
    begin
        to_row_p2 = P2_BOT - ((val * (P2_BOT - P2_TOP)) >> 8);
    end
endfunction

// ── Pixel drawing logic ────────────────────────────────────────────────────────
// Draw a 2-pixel wide waveform line: highlight rows around the current sample value
wire [9:0] ecg_row    = to_row_p1(ecg_val);
wire [9:0] lps_row    = to_row_p2(lps_val);
wire [9:0] thresh_row = to_row_p2(thresh_val);

// Panel membership
wire in_p1 = (v_pos >= P1_TOP) && (v_pos <= P1_BOT);
wire in_p2 = (v_pos >= P2_TOP) && (v_pos <= P2_BOT);
wire in_p3 = (v_pos >= P3_TOP) && (v_pos <= P3_BOT);
wire in_title = (v_pos < 32);
wire in_divider = ((v_pos >= 195) && (v_pos <= 209)) ||
                  ((v_pos >= 375) && (v_pos <= 389));
wire in_status = (v_pos >= 470);

// Waveform pixel detection (2px thick)
wire draw_ecg    = in_p1 && ((v_pos == ecg_row) || (v_pos == ecg_row + 1));
wire draw_lps    = in_p2 && ((v_pos == lps_row) || (v_pos == lps_row + 1));
wire draw_thresh = in_p2 && ((v_pos == thresh_row) &&
                              (h_pos[2] == 1'b0));   // Dashed: draw every 4 pixels
// Midline (zero reference) — faint grid line
wire draw_midline_p1 = in_p1 && (v_pos == P1_MID) && (h_pos[3] == 1'b0);
wire draw_midline_p2 = in_p2 && (v_pos == P2_MID) && (h_pos[3] == 1'b0);

// Peak marker: vertical red bar when peak_val is set
wire draw_peak_line = peak_val && (in_p1 || in_p3);

// Border lines between panels
wire draw_border = (h_pos == 0) || (h_pos == SCREEN_W - 1) ||
                   (v_pos == P1_TOP - 1) || (v_pos == P1_BOT + 1) ||
                   (v_pos == P2_TOP - 1) || (v_pos == P2_BOT + 1) ||
                   (v_pos == P3_TOP - 1) || (v_pos == P3_BOT + 1);

// ── Colour assignment ──────────────────────────────────────────────────────────
reg [3:0] r, g, b;

always @(*) begin
    r = 4'h0; g = 4'h0; b = 4'h0;   // Default: black

    if (!active) begin
        r = 4'h0; g = 4'h0; b = 4'h0;   // Blanking
    end else if (in_title) begin
        // Dark blue title bar
        r = 4'h0; g = 4'h2; b = 4'h5;
    end else if (in_status) begin
        // Status bar: red if arrhythmia, dark blue otherwise
        r = arrhythmia ? 4'hA : 4'h0;
        g = arrhythmia ? 4'h0 : 4'h1;
        b = arrhythmia ? 4'h0 : 4'h4;
    end else if (in_divider) begin
        r = 4'h3; g = 4'h3; b = 4'h3;   // Dark grey divider
    end else if (draw_peak_line) begin
        r = 4'hF; g = 4'h2; b = 4'h2;   // Red peak marker
    end else if (draw_ecg) begin
        r = 4'h3; g = 4'h7; b = 4'hF;   // Blue ECG waveform
    end else if (draw_thresh) begin
        r = 4'hF; g = 4'h4; b = 4'h0;   // Orange dashed threshold
    end else if (draw_lps) begin
        r = 4'h0; g = 4'hD; b = 4'h9;   // Teal LPS envelope
    end else if (draw_midline_p1 || draw_midline_p2) begin
        r = 4'h2; g = 4'h2; b = 4'h2;   // Faint grey zero-line
    end else if (draw_border) begin
        r = 4'h4; g = 4'h4; b = 4'h4;   // Grey border
    end else if (in_p1 || in_p2 || in_p3) begin
        r = 4'h0; g = 4'h0; b = 4'h0;   // Black waveform background
    end else begin
        r = 4'h1; g = 4'h1; b = 4'h1;   // Very dark background elsewhere
    end
end

assign vga_r = r;
assign vga_g = g;
assign vga_b = b;

endmodule
