// =============================================================================
// rr_calculator.v
// QRS Detection Stage — Module 4: RR Interval & Heart Rate Calculator
// Purpose : Measure the time between consecutive R-peaks (RR interval) and
//           compute instantaneous heart rate.
//           RR Interval (samples) → Heart Rate (BPM) = 60 * FS / RR_samples
//           At FS=360 Hz: HR = 21600 / RR_samples
//           Also flags arrhythmia if RR deviates >20% from running average.
// Inputs  : peak_flag (from peak_detector), valid_in
// Outputs : rr_interval (samples), heart_rate (BPM), arrhythmia flag
// =============================================================================
`timescale 1ns / 1ps

module rr_calculator #(
    parameter FS      = 360,             // Sampling frequency (Hz)
    parameter RR_MAX  = 1440,            // Max RR = 4 s (25 BPM) at 360 Hz
    parameter RR_MIN  = 72,              // Min RR = 0.2 s (300 BPM) at 360 Hz
    parameter ARRHY_THRESH_PCT = 20      // % deviation to flag arrhythmia
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire        peak_flag,         // 1-cycle pulse from peak_detector
    output reg  [11:0] rr_interval,       // RR interval in samples (0–4095)
    output reg  [9:0]  heart_rate,        // Heart rate in BPM (0–1023)
    output reg         arrhythmia_flag,   // 1 = abnormal rhythm detected
    output reg         rr_valid           // 1 when rr_interval/heart_rate are valid
);

reg [11:0] sample_counter;   // Counts samples between peaks
reg [11:0] last_rr;          // Previous RR interval
reg [15:0] avg_rr;           // Running average RR (×8 for precision)
reg        first_peak;       // Set after first peak detected

// Heart rate = 60 * FS / RR = 21600 / RR (for FS=360)
localparam [21:0] HR_CONST = 22'd21600;  // 60 × 360

always @(posedge clk) begin
    if (!rst_n) begin
        sample_counter  <= 12'd0;
        last_rr         <= 12'd0;
        avg_rr          <= 16'd0;
        first_peak      <= 1'b0;
        rr_interval     <= 12'd0;
        heart_rate      <= 10'd0;
        arrhythmia_flag <= 1'b0;
        rr_valid        <= 1'b0;
    end
    else if (valid_in) begin
        rr_valid        <= 1'b0;
        arrhythmia_flag <= 1'b0;

        // Always increment counter; cap at RR_MAX to avoid rollover
        if (sample_counter < RR_MAX)
            sample_counter <= sample_counter + 1;
        else
            sample_counter <= RR_MAX;  // Flatline / extreme bradycardia

        if (peak_flag) begin
            if (!first_peak) begin
                // First peak ever — just record, no RR available yet
                first_peak     <= 1'b1;
                sample_counter <= 12'd1;
            end
            else if (sample_counter >= RR_MIN) begin
                // Valid RR interval detected
                rr_interval    <= sample_counter;
                last_rr        <= sample_counter;
                sample_counter <= 12'd1;   // Restart (count includes this peak sample)

                // Heart rate (BPM) = 21600 / RR_samples
                heart_rate <= HR_CONST / sample_counter;

                // Running average: avg_rr = 0.875*avg_rr + 0.125*rr
                if (avg_rr == 16'd0)
                    avg_rr <= {4'b0, sample_counter};    // Initialise
                else
                    avg_rr <= avg_rr - (avg_rr >>> 3) + ({4'b0, sample_counter} >>> 3);

                // Arrhythmia check: deviation from running average > 20%
                // |rr - avg_rr| > 0.20 * avg_rr  →  5*|rr - avg_rr| > avg_rr
                if (avg_rr != 16'd0) begin
                    if (sample_counter > avg_rr[15:4]) begin  // avg_rr >> 4 = /16 to de-scale
                        if ((sample_counter - avg_rr[15:4]) * 5 > avg_rr[15:4])
                            arrhythmia_flag <= 1'b1;
                    end else begin
                        if ((avg_rr[15:4] - sample_counter) * 5 > avg_rr[15:4])
                            arrhythmia_flag <= 1'b1;
                    end
                end

                rr_valid <= 1'b1;
            end
        end
    end
end

endmodule
