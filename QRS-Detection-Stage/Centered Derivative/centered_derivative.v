// =============================================================================
// centered_derivative.v
// QRS Detection Stage — Module 1: Centered Derivative
// Purpose : Estimate the slope of the preprocessed envelope signal.
//           Uses a symmetric 5-point centered difference:
//           y[n] = (1/8) * (x[n+2] + 2*x[n+1] - 2*x[n-1] - x[n-2])
//           Introduces 2-sample latency (centred at x[n]).
// Input   : 16-bit unsigned output from lowpass_filter (out_lps.hex)
// Output  : 17-bit signed slope (positive = rising edge, negative = falling)
// Ref     : Pan-Tompkins modified — centered derivative for QRS localisation
// =============================================================================
`timescale 1ns / 1ps

module centered_derivative (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [15:0] x_in,          // Unsigned LPS envelope input
    output reg  signed [16:0] y_out,  // Signed slope output (17-bit to avoid overflow)
    output reg         valid_out
);

// Delay line: store last 4 samples (x[n], x[n-1], x[n-2], x[n-3], x[n-4])
// After 2-sample delay: centred at x[n-2]
reg [15:0] x_d1, x_d2, x_d3, x_d4;  // x[n-1] .. x[n-4]

reg signed [18:0] sum;  // Accumulator (wide enough: 4 * 16-bit = 18-bit safe)

always @(posedge clk) begin
    if (!rst_n) begin
        x_d1 <= 16'd0; x_d2 <= 16'd0;
        x_d3 <= 16'd0; x_d4 <= 16'd0;
        sum      <= 19'sd0;
        y_out    <= 17'sd0;
        valid_out <= 1'b0;
    end
    else if (valid_in) begin
        // Shift delay line
        x_d4 <= x_d3;
        x_d3 <= x_d2;
        x_d2 <= x_d1;
        x_d1 <= x_in;

        // Centred difference (output aligned to x[n-2]):
        //   y = x[n] - x[n-4] + 2*(x[n-1] - x[n-3])
        //   Divide by 8 after to get proper scale (right-shift 3)
        // Here x_in = x[n], x_d1 = x[n-1], x_d3 = x[n-3], x_d4 = x[n-4]
        sum <= ($signed({1'b0, x_in})  - $signed({1'b0, x_d4}))
             + (($signed({1'b0, x_d1}) - $signed({1'b0, x_d3})) <<< 1);

        // Arithmetic right-shift by 3 (divide by 8)
        y_out    <= sum[18:2];   // Take bits [18:2] = divide by 4; net /8 with the /2 above
        valid_out <= valid_in;
    end
    else begin
        valid_out <= 1'b0;
    end
end

endmodule
