module derivative_filter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire signed [15:0] x_in,
    output reg  signed [15:0] y_out,
    output reg         valid_out
);

reg signed [15:0] x_d1;  // x[n-1]
reg signed [15:0] x_d2;  // x[n-2]  
reg signed [15:0] x_d3;  // x[n-3]
reg signed [15:0] x_d4;  // x[n-4]

reg signed [31:0] sum;

always @(posedge clk) begin
    if (!rst_n) begin
        x_d1 <= 16'sd0; x_d2 <= 16'sd0;
        x_d3 <= 16'sd0; x_d4 <= 16'sd0;
        sum  <= 32'sd0;
        y_out     <= 16'sd0;
        valid_out <= 1'b0;
    end
    else if (valid_in) begin
        x_d4 <= x_d3;
        x_d3 <= x_d2;
        x_d2 <= x_d1;
        x_d1 <= x_in;


        sum <= {{16{x_in[15]}},  x_in}              // +1 * x[n]
             + ({{16{x_d1[15]}}, x_d1} <<< 1)       // +2 * x[n-1]
             - ({{16{x_d3[15]}}, x_d3} <<< 1)       // -2 * x[n-3]
             - {{16{x_d4[15]}},  x_d4};              // -1 * x[n-4]
        if      (sum > 32'sh00007FFF) y_out <= 16'sh7FFF;  
        else if (sum < 32'shFFFF8000) y_out <= 16'sh8000; 
        else                          y_out <= sum[15:0]; 

        valid_out <= valid_in;
    end
    else begin
        valid_out <= 1'b0;
    end
end

endmodule
