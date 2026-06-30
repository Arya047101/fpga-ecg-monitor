// =============================================================================
// adaptive_threshold.v
// QRS Detection Stage — Module 2: Adaptive Amplitude Threshold
// Purpose : Maintain two running thresholds (signal peak & noise peak) and
//           compute a decision threshold midway between them.
//           Based on Pan-Tompkins adaptive learning thresholds:
//             SPKI = 0.125 * peak_i + 0.875 * SPKI  (signal peak)
//             NPKI = 0.125 * peak_i + 0.875 * NPKI  (noise peak)
//             Threshold = NPKI + 0.25 * (SPKI - NPKI)
//           All arithmetic in Q8.8 unsigned fixed-point (×256 scale).
// Input   : 16-bit unsigned LPS envelope sample + beat flag from peak detector
// Output  : 16-bit unsigned threshold level
// =============================================================================
`timescale 1ns / 1ps

module adaptive_threshold (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,       // One pulse per new sample
    input  wire [15:0] x_in,          // LPS envelope sample (unsigned)
    input  wire        is_qrs,        // 1 = this sample was classified as QRS peak
    output reg  [15:0] threshold_out, // Adaptive threshold level (same scale as x_in)
    output reg         valid_out
);

// Running peak estimates (×256 for fractional update)
reg [23:0] spki;   // Signal peak index (Q8.8 × 256 = Q8.16, 24-bit)
reg [23:0] npki;   // Noise peak index

// Initialise thresholds at 25% of full scale to avoid false positives on startup
localparam [23:0] INIT_SPKI = 24'd4096;   // ~16 in original scale
localparam [23:0] INIT_NPKI = 24'd1024;

always @(posedge clk) begin
    if (!rst_n) begin
        spki          <= INIT_SPKI;
        npki          <= INIT_NPKI;
        threshold_out <= 16'd512;
        valid_out     <= 1'b0;
    end
    else if (valid_in) begin
        // Scaled input (left-shift 8 to give sub-integer precision)
        // SPKI  = 0.875*SPKI + 0.125*peak  → SPKI = SPKI - SPKI/8 + peak/8
        // NPKI  = 0.875*NPKI + 0.125*peak  → same formula

        if (is_qrs) begin
            spki <= spki - (spki >>> 3) + ({8'b0, x_in} >>> 3);
        end else begin
            npki <= npki - (npki >>> 3) + ({8'b0, x_in} >>> 3);
        end

        // Threshold = NPKI + 0.25*(SPKI - NPKI)
        // Use registered SPKI/NPKI (one cycle latency is acceptable)
        if (spki > npki)
            threshold_out <= (npki[23:8] + ((spki - npki) >>> 10));
        else
            threshold_out <= npki[23:8];

        valid_out <= valid_in;
    end
    else begin
        valid_out <= 1'b0;
    end
end

endmodule
