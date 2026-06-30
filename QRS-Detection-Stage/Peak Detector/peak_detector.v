// =============================================================================
// peak_detector.v
// QRS Detection Stage — Module 3: Peak Detector
// Purpose : Detect local maxima (peaks) in the LPS envelope signal.
//           A peak is flagged when:
//             1. The current sample exceeds adaptive_threshold.
//             2. The centered-derivative changes sign (positive → zero/negative).
//             3. A minimum refractory period (200 ms = 72 samples @ 360 Hz)
//                has elapsed since the last detected peak (avoids re-triggering).
// Inputs  : LPS envelope, centered derivative, adaptive threshold
// Output  : peak_flag (1 for one clock when a peak is found), peak_value
// =============================================================================
`timescale 1ns / 1ps

module peak_detector #(
    parameter REFRACTORY = 72  // Minimum samples between peaks (200 ms @ 360 Hz)
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [15:0] envelope_in,          // LPS envelope (unsigned)
    input  wire signed [16:0] deriv_in,      // Centered derivative output
    input  wire [15:0] threshold_in,         // Adaptive threshold
    output reg         peak_flag,            // 1 = QRS peak detected this cycle
    output reg  [15:0] peak_value,           // Amplitude of detected peak
    output reg         valid_out
);

reg signed [16:0] deriv_prev;               // Previous derivative sample
reg [$clog2(REFRACTORY+1)-1:0] refrac_cnt; // Refractory counter
reg in_refractory;                          // Refractory gate

always @(posedge clk) begin
    if (!rst_n) begin
        deriv_prev   <= 17'sd0;
        refrac_cnt   <= 0;
        in_refractory <= 1'b0;
        peak_flag    <= 1'b0;
        peak_value   <= 16'd0;
        valid_out    <= 1'b0;
    end
    else if (valid_in) begin
        peak_flag <= 1'b0;  // Default: no peak

        // Refractory counter management
        if (in_refractory) begin
            if (refrac_cnt == REFRACTORY - 1) begin
                refrac_cnt    <= 0;
                in_refractory <= 1'b0;
            end else begin
                refrac_cnt <= refrac_cnt + 1;
            end
        end

        // Peak detection: slope sign change (positive → non-positive) AND
        // above threshold AND not in refractory period
        if (!in_refractory
            && (deriv_prev > 17'sd0)        // Previous slope was rising
            && (deriv_in  <= 17'sd0)        // Current slope is flat/falling
            && (envelope_in > threshold_in) // Above threshold
        ) begin
            peak_flag     <= 1'b1;
            peak_value    <= envelope_in;
            in_refractory <= 1'b1;
            refrac_cnt    <= 0;
        end

        deriv_prev <= deriv_in;
        valid_out  <= valid_in;
    end
    else begin
        valid_out <= 1'b0;
        peak_flag <= 1'b0;
    end
end

endmodule
